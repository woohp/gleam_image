import gleam/erlang.{type Reference}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam_image/internal/bmp
import gleam_image/internal/detect as internal_detect
import gleam_image/internal/image.{type ImageType, Image, PDFImage, TIFFImage}
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

pub fn raster_image(
  pixels: BitArray,
  width width: Int,
  height height: Int,
  channels channels: Int,
  bit_depth bit_depth: Int,
) -> RasterImage {
  RasterImage(pixels:, width:, height:, channels:, bit_depth:)
}

pub fn pixels(image: RasterImage) -> BitArray {
  let RasterImage(pixels:, ..) = image
  pixels
}

pub fn width(image: RasterImage) -> Int {
  let RasterImage(width:, ..) = image
  width
}

pub fn height(image: RasterImage) -> Int {
  let RasterImage(height:, ..) = image
  height
}

pub fn channels(image: RasterImage) -> Int {
  let RasterImage(channels:, ..) = image
  channels
}

pub fn bit_depth(image: RasterImage) -> Int {
  let RasterImage(bit_depth:, ..) = image
  bit_depth
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
fn pdf_load_document(bytes: BitArray) -> Result(ImageType, String)

@external(erlang, "imagex_c", "pdf_render_page")
fn pdf_render_page_data(
  ref: Reference,
  page_index: Int,
  dpi: Int,
) -> DecompressResult

@external(erlang, "imagex_c", "tiff_load_document")
fn tiff_load_document(bytes: BitArray) -> Result(ImageType, String)

@external(erlang, "imagex_c", "tiff_render_page")
fn tiff_render_page_data(ref: Reference, page_index: Int) -> DecompressResult

pub fn detect(bytes: BitArray) -> Option(Format) {
  case internal_detect.detect(bytes) {
    Some(internal_detect.Jpeg) -> Some(RasterFormat(Jpeg))
    Some(internal_detect.Png) -> Some(RasterFormat(Png))
    Some(internal_detect.Jxl) -> Some(RasterFormat(Jxl))
    Some(internal_detect.Bmp) -> Some(RasterFormat(Bmp))
    Some(internal_detect.Ppm) -> Some(RasterFormat(Ppm))
    Some(internal_detect.Pdf) -> Some(PdfFormat)
    Some(internal_detect.Tiff) -> Some(TiffFormat)
    None -> None
  }
}

pub fn decode(bytes: BitArray) -> Result(Decoded, Error) {
  case detect(bytes) {
    Some(RasterFormat(Jpeg)) -> decompress(jpeg_decompress(bytes))
    Some(RasterFormat(Png)) -> decompress(png_decompress(bytes))
    Some(RasterFormat(Jxl)) -> decompress(jxl_decompress(bytes))
    Some(RasterFormat(Bmp)) -> decode_raster_format(bmp.decode(bytes))
    Some(RasterFormat(Ppm)) -> decode_raster_format(ppm.decode(bytes))
    Some(TiffFormat) -> decode_document(tiff_load_document(bytes))
    Some(PdfFormat) -> decode_document(pdf_load_document(bytes))
    None -> Error(UnknownFormat)
  }
}

pub fn decode_raster(bytes: BitArray) -> Result(RasterImage, Error) {
  use decoded <- result.try(decode(bytes))

  case decoded {
    Raster(image) -> Ok(image)
    Pdf(_) | Tiff(_) -> Error(InvalidImage("Expected a raster image"))
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
  render_page(pdf_render_page_data(ref, page_index, dpi))
}

pub fn render_tiff_page(
  document: TiffDocument,
  page_index: Int,
) -> Result(RasterImage, Error) {
  let TiffDocument(ref, _) = document
  render_page(tiff_render_page_data(ref, page_index))
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

fn to_text_chunk(chunk: PngTextChunk) -> TextChunk {
  let PngTextChunk(keyword, text, language_tag, translated_keyword) = chunk
  #(<<keyword:utf8>>, <<text:utf8>>, <<language_tag:utf8>>, <<
    translated_keyword:utf8,
  >>)
}

fn to_jxl_box(box: JxlBox) -> #(String, BitArray) {
  let JxlBox(name, contents) = box
  #(name, contents)
}

fn decompress(rendered: DecompressResult) -> Result(Decoded, Error) {
  use image <- result.try(render_page(rendered))
  Ok(Raster(image))
}

fn render_page(rendered: DecompressResult) -> Result(RasterImage, Error) {
  use #(pixels, width, height, channels, bit_depth, _, _, _, _) <- result.try(
    result.map_error(rendered, NativeError),
  )
  Ok(RasterImage(pixels:, width:, height:, channels:, bit_depth:))
}

fn decode_raster_format(
  image: Result(ImageType, String),
) -> Result(Decoded, Error) {
  use image <- result.try(result.map_error(image, InvalidImage))

  case image {
    Image(pixels:, width:, height:, channels:, bit_depth:) ->
      Ok(Raster(RasterImage(pixels:, width:, height:, channels:, bit_depth:)))
    _ -> Error(InvalidImage("Expected a raster image"))
  }
}

fn decode_document(
  document: Result(ImageType, String),
) -> Result(Decoded, Error) {
  use document <- result.try(result.map_error(document, NativeError))

  case document {
    PDFImage(ref, pages) -> Ok(Pdf(PdfDocument(ref:, pages:)))
    TIFFImage(ref, pages) -> Ok(Tiff(TiffDocument(ref:, pages:)))
    _ -> Error(InvalidImage("Expected a document"))
  }
}
