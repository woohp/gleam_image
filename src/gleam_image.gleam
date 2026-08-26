import gleam/bit_array
import gleam/erlang.{type Reference}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam_image/internal/bmp
import gleam_image/internal/image.{
  type Image, type PdfHandle, type TiffHandle, Image, PDFImage, TIFFImage,
}
import gleam_image/internal/ppm
import simplifile.{type FileError, read_bits}

pub type RasterImage {
  RasterImage(
    pixels: BitArray,
    width: Int,
    height: Int,
    channels: Int,
    bit_depth: Int,
  )
}

/// Metadata extracted while decoding a raster image. Which fields are
/// populated depends on the source format: PNG can carry EXIF and text
/// chunks, JXL can carry EXIF and xml/jumb boxes. JPEG, BMP, and PPM
/// currently yield no metadata.
pub type RasterMetadata {
  RasterMetadata(
    exif: Option(BitArray),
    text_chunks: List(PngTextChunk),
    xml_boxes: List(BitArray),
    jumb_boxes: List(BitArray),
  )
}

pub opaque type PdfDocument {
  PdfDocument(ref: Reference, pages: Int)
}

pub opaque type TiffDocument {
  TiffDocument(ref: Reference, pages: Int)
}

pub type Format {
  RasterFormat(RasterFormat)
  PdfFormat
  TiffFormat
}

pub type Decoded {
  Raster(RasterImage)
  Pdf(PdfDocument)
  Tiff(TiffDocument)
}

pub type RasterFormat {
  Jpeg
  Png
  Jxl
  Bmp
  Ppm
}

pub type Error {
  UnknownFormat
  InvalidImage(String)
  InvalidOptions(String)
  FileError(FileError)
  NativeError(String)
}

pub type JpegEncodeOptions {
  JpegEncodeOptions(quality: Int, exif: Option(BitArray), xmp: Option(BitArray))
}

pub type PngTextChunk {
  PngTextChunk(
    keyword: String,
    text: String,
    language_tag: String,
    translated_keyword: String,
  )
}

pub type PngEncodeOptions {
  PngEncodeOptions(text_chunks: List(PngTextChunk))
}

pub type JxlBox {
  JxlBox(name: String, contents: BitArray)
}

pub type JxlEncodeOptions {
  JxlEncodeOptions(
    exif: Option(BitArray),
    boxes: List(JxlBox),
    distance: Float,
    lossless: Bool,
    effort: Int,
    progressive: Int,
    order: Int,
  )
}

pub type JxlTranscodeOptions {
  JxlTranscodeOptions(effort: Int, store_jpeg_metadata: Bool)
}

type TextChunk =
  #(BitArray, BitArray, BitArray, BitArray)

type DecompressResult =
  Result(
    #(
      BitArray,
      Int,
      Int,
      Int,
      Int,
      Option(BitArray),
      List(TextChunk),
      List(BitArray),
      List(BitArray),
    ),
    String,
  )

@external(erlang, "imagex_c", "jpeg_decompress")
fn jpeg_decompress(bytes: BitArray) -> DecompressResult

@external(erlang, "imagex_c", "jpeg_compress")
fn jpeg_compress(
  pixels: BitArray,
  width: Int,
  height: Int,
  channels: Int,
  quality: Int,
  exif: Option(BitArray),
  xmp: Option(BitArray),
) -> Result(BitArray, String)

@external(erlang, "imagex_c", "png_decompress")
fn png_decompress(bytes: BitArray) -> DecompressResult

@external(erlang, "imagex_c", "png_compress")
fn png_compress(
  pixels: BitArray,
  width: Int,
  height: Int,
  channels: Int,
  bit_depth: Int,
  text_chunks: List(TextChunk),
) -> Result(BitArray, String)

@external(erlang, "imagex_c", "jxl_decompress")
fn jxl_decompress(bytes: BitArray) -> DecompressResult

@external(erlang, "imagex_c", "jxl_compress")
fn jxl_compress(
  pixels: BitArray,
  width: Int,
  height: Int,
  channels: Int,
  bit_depth: Int,
  exif: Option(BitArray),
  boxes: List(#(String, BitArray)),
  distance: Float,
  lossless: Bool,
  effort: Int,
  progressive: Int,
  order: Int,
) -> Result(BitArray, String)

@external(erlang, "imagex_c", "jxl_transcode_from_jpeg")
fn do_jxl_transcode_from_jpeg(
  jpeg_bytes: BitArray,
  effort: Int,
  store_jpeg_metadata: Bool,
) -> Result(BitArray, String)

@external(erlang, "imagex_c", "jxl_transcode_to_jpeg")
fn do_jxl_transcode_to_jpeg(jxl_bytes: BitArray) -> Result(BitArray, String)

@external(erlang, "imagex_c", "pdf_load_document")
fn pdf_load_document(bytes: BitArray) -> Result(PdfHandle, String)

@external(erlang, "imagex_c", "pdf_render_page")
fn pdf_render_page_data(
  ref: Reference,
  page_index: Int,
  dpi: Int,
) -> DecompressResult

@external(erlang, "imagex_c", "tiff_load_document")
fn tiff_load_document(bytes: BitArray) -> Result(TiffHandle, String)

@external(erlang, "imagex_c", "tiff_render_page")
fn tiff_render_page_data(ref: Reference, page_index: Int) -> DecompressResult

pub fn detect(bytes: BitArray) -> Option(Format) {
  case bytes {
    <<0xFFD8:size(16), _rest:bits>> -> Some(RasterFormat(Jpeg))

    <<0x89, "PNG\r\n":utf8, 0x1A, 0x0A, _rest:bytes>> -> Some(RasterFormat(Png))

    <<0xFF, 0x0A, _rest:bytes>> -> Some(RasterFormat(Jxl))

    <<0x00, 0x00, 0x00, 0x0C, "JXL ":utf8, 0x0D, 0x0A, 0x87, 0x0A, _rest:bytes>> ->
      Some(RasterFormat(Jxl))

    <<"BM":utf8, _rest:bytes>> -> Some(RasterFormat(Bmp))

    <<"P":utf8, n:size(8), "\n":utf8, _rest:bytes>> if n == 53 || n == 54 ->
      Some(RasterFormat(Ppm))

    <<"II":utf8, 0x2A00:size(16), _rest:bytes>> -> Some(TiffFormat)

    <<"MM":utf8, 0x002A:size(16), _rest:bytes>> -> Some(TiffFormat)

    <<"%PDF-1.":utf8, n:size(8), "\n%":utf8, _rest:bytes>>
      if n >= 48 && n <= 57
    -> Some(PdfFormat)

    _ -> None
  }
}

pub fn decode(bytes: BitArray) -> Result(Decoded, Error) {
  case detect(bytes) {
    Some(PdfFormat) -> load_pdf(bytes)
    Some(TiffFormat) -> load_tiff(bytes)
    Some(RasterFormat(_)) | None -> {
      use #(image, _metadata) <- result.try(decode_raster_with_metadata(bytes))
      Ok(Raster(image))
    }
  }
}

pub fn decode_raster(bytes: BitArray) -> Result(RasterImage, Error) {
  use #(image, _metadata) <- result.try(decode_raster_with_metadata(bytes))
  Ok(image)
}

pub fn decode_raster_with_metadata(
  bytes: BitArray,
) -> Result(#(RasterImage, RasterMetadata), Error) {
  case detect(bytes) {
    Some(RasterFormat(Jpeg)) -> to_raster_parts(jpeg_decompress(bytes))
    Some(RasterFormat(Png)) -> to_raster_parts(png_decompress(bytes))
    Some(RasterFormat(Jxl)) -> to_raster_parts(jxl_decompress(bytes))
    Some(RasterFormat(Bmp)) -> internal_raster_parts(bmp.decode(bytes))
    Some(RasterFormat(Ppm)) -> internal_raster_parts(ppm.decode(bytes))
    Some(PdfFormat) | Some(TiffFormat) ->
      Error(InvalidImage("Expected a raster image"))
    None -> Error(UnknownFormat)
  }
}

pub fn encode(
  image: RasterImage,
  format: RasterFormat,
) -> Result(BitArray, Error) {
  let RasterImage(pixels:, width:, height:, channels:, bit_depth:) = image

  case format {
    Jpeg -> encode_jpeg(image, default_jpeg_encode_options())
    Png -> encode_png(image, default_png_encode_options())
    Jxl -> encode_jxl(image, default_jxl_encode_options())
    Bmp ->
      bmp.encode(pixels, width, height, channels, bit_depth)
      |> result.map_error(NativeError)
    Ppm ->
      ppm.encode(pixels, width, height, channels, bit_depth)
      |> result.map_error(NativeError)
  }
}

pub fn default_jpeg_encode_options() -> JpegEncodeOptions {
  JpegEncodeOptions(quality: 75, exif: None, xmp: None)
}

pub fn encode_jpeg(
  image: RasterImage,
  options: JpegEncodeOptions,
) -> Result(BitArray, Error) {
  let RasterImage(pixels:, width:, height:, channels:, bit_depth: _) = image
  let JpegEncodeOptions(quality:, exif:, xmp:) = options

  case quality < 1 || quality > 100 {
    True -> Error(InvalidOptions("JPEG quality must be between 1 and 100"))
    False ->
      jpeg_compress(pixels, width, height, channels, quality, exif, xmp)
      |> result.map_error(NativeError)
  }
}

pub fn default_png_encode_options() -> PngEncodeOptions {
  PngEncodeOptions(text_chunks: [])
}

pub fn encode_png(
  image: RasterImage,
  options: PngEncodeOptions,
) -> Result(BitArray, Error) {
  let RasterImage(pixels:, width:, height:, channels:, bit_depth:) = image
  let PngEncodeOptions(text_chunks:) = options
  png_compress(
    pixels,
    width,
    height,
    channels,
    bit_depth,
    text_chunks |> list.map(to_text_chunk),
  )
  |> result.map_error(NativeError)
}

pub fn default_jxl_encode_options() -> JxlEncodeOptions {
  JxlEncodeOptions(
    exif: None,
    boxes: [],
    distance: 1.0,
    lossless: False,
    effort: 7,
    progressive: 1,
    order: 1,
  )
}

pub fn encode_jxl(
  image: RasterImage,
  options: JxlEncodeOptions,
) -> Result(BitArray, Error) {
  let RasterImage(pixels:, width:, height:, channels:, bit_depth:) = image
  let JxlEncodeOptions(
    exif:,
    boxes:,
    distance:,
    lossless:,
    effort:,
    progressive:,
    order:,
  ) = options

  case lossless, distance {
    False, 0.0 ->
      Error(InvalidOptions("JXL distance 0 requires lossless: True"))
    _, _ ->
      jxl_compress(
        pixels,
        width,
        height,
        channels,
        bit_depth,
        exif,
        list.map(boxes, to_jxl_box),
        distance,
        lossless,
        effort,
        progressive,
        order,
      )
      |> result.map_error(NativeError)
  }
}

pub fn render_pdf_page(
  document: PdfDocument,
  page_index: Int,
  dpi: Int,
) -> Result(RasterImage, Error) {
  let PdfDocument(ref, _) = document
  to_raster_image(pdf_render_page_data(ref, page_index, dpi))
}

pub fn render_tiff_page(
  document: TiffDocument,
  page_index: Int,
) -> Result(RasterImage, Error) {
  let TiffDocument(ref, _) = document
  to_raster_image(tiff_render_page_data(ref, page_index))
}

pub fn pdf_pages(document: PdfDocument) -> Int {
  let PdfDocument(_, pages) = document
  pages
}

pub fn tiff_pages(document: TiffDocument) -> Int {
  let TiffDocument(_, pages) = document
  pages
}

pub fn read(path: String) -> Result(Decoded, Error) {
  case read_bits(path) {
    Ok(data) -> decode(data)
    Error(error) -> Error(FileError(error))
  }
}

pub fn read_raster(path: String) -> Result(RasterImage, Error) {
  case read_bits(path) {
    Ok(data) -> decode_raster(data)
    Error(error) -> Error(FileError(error))
  }
}

pub fn default_jxl_transcode_options() -> JxlTranscodeOptions {
  JxlTranscodeOptions(effort: 7, store_jpeg_metadata: True)
}

pub fn jxl_transcode_from_jpeg(
  jpeg_bytes: BitArray,
  options: JxlTranscodeOptions,
) -> Result(BitArray, Error) {
  let JxlTranscodeOptions(effort:, store_jpeg_metadata:) = options
  do_jxl_transcode_from_jpeg(jpeg_bytes, effort, store_jpeg_metadata)
  |> result.map_error(NativeError)
}

pub fn jxl_transcode_to_jpeg(jxl_bytes: BitArray) -> Result(BitArray, Error) {
  do_jxl_transcode_to_jpeg(jxl_bytes)
  |> result.map_error(NativeError)
}

fn load_pdf(bytes: BitArray) -> Result(Decoded, Error) {
  use handle <- result.try(result.map_error(
    pdf_load_document(bytes),
    NativeError,
  ))
  let PDFImage(ref:, num_pages:) = handle
  Ok(Pdf(PdfDocument(ref:, pages: num_pages)))
}

fn load_tiff(bytes: BitArray) -> Result(Decoded, Error) {
  use handle <- result.try(result.map_error(
    tiff_load_document(bytes),
    NativeError,
  ))
  let TIFFImage(ref:, num_pages:) = handle
  Ok(Tiff(TiffDocument(ref:, pages: num_pages)))
}

fn to_raster_image(rendered: DecompressResult) -> Result(RasterImage, Error) {
  use #(image, _metadata) <- result.try(to_raster_parts(rendered))
  Ok(image)
}

fn to_raster_parts(
  rendered: DecompressResult,
) -> Result(#(RasterImage, RasterMetadata), Error) {
  use
    #(pixels, width, height, channels, bit_depth, exif, text_chunks, xml, jumb)
  <- result.try(result.map_error(rendered, NativeError))

  let image = RasterImage(pixels:, width:, height:, channels:, bit_depth:)
  let metadata =
    RasterMetadata(
      exif:,
      text_chunks: list.filter_map(text_chunks, from_text_chunk),
      xml_boxes: xml,
      jumb_boxes: jumb,
    )
  Ok(#(image, metadata))
}

fn internal_raster_parts(
  decoded: Result(Image, String),
) -> Result(#(RasterImage, RasterMetadata), Error) {
  case decoded {
    Ok(Image(pixels:, width:, height:, channels:, bit_depth:)) ->
      Ok(#(
        RasterImage(pixels:, width:, height:, channels:, bit_depth:),
        empty_metadata(),
      ))
    Error(reason) -> Error(InvalidImage(reason))
  }
}

fn empty_metadata() -> RasterMetadata {
  RasterMetadata(exif: None, text_chunks: [], xml_boxes: [], jumb_boxes: [])
}

fn to_text_chunk(chunk: PngTextChunk) -> TextChunk {
  let PngTextChunk(keyword, text, language_tag, translated_keyword) = chunk
  #(<<keyword:utf8>>, <<text:utf8>>, <<language_tag:utf8>>, <<
    translated_keyword:utf8,
  >>)
}

// Chunks whose fields are not valid UTF-8 are dropped.
fn from_text_chunk(chunk: TextChunk) -> Result(PngTextChunk, Nil) {
  let #(keyword, text, language_tag, translated_keyword) = chunk
  use keyword <- result.try(bit_array.to_string(keyword))
  use text <- result.try(bit_array.to_string(text))
  use language_tag <- result.try(bit_array.to_string(language_tag))
  use translated_keyword <- result.try(bit_array.to_string(translated_keyword))
  Ok(PngTextChunk(keyword:, text:, language_tag:, translated_keyword:))
}

fn to_jxl_box(box: JxlBox) -> #(String, BitArray) {
  let JxlBox(name, contents) = box
  #(name, contents)
}
