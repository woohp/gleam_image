import bmp
import detect.{type Format, BMP, JPEG, JXL, PDF, PNG, PPM, TIFF}
import gleam/erlang.{type Reference}
import gleam/option.{type Option, None, Some}
import gleam/result
import image.{type ImageType, Image, PDFImage, TIFFImage}
import ppm
import simplifile.{read_bits}

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
  boxes: Option(List(#(String, BitArray))),
  distance: Float,
  lossless: Bool,
  effort: Int,
  progressive: Int,
  order: Int,
) -> Result(BitArray, String)

@external(erlang, "imagex_c", "jxl_transcode_from_jpeg")
pub fn jxl_transcode_from_jpeg(
  jpeg_bytes: BitArray,
  effort: Int,
  store_jpeg_metadata: Bool,
) -> Result(BitArray, String)

@external(erlang, "imagex_c", "jxl_transcode_to_jpeg")
pub fn jxl_transcode_to_jpeg(jxl_bytes: BitArray) -> Result(BitArray, String)

@external(erlang, "imagex_c", "pdf_load_document")
fn pdf_load_document(bytes: BitArray) -> Result(ImageType, String)

@external(erlang, "imagex_c", "pdf_render_page")
fn pdf_render_page_data(
  ref: Reference,
  page_idx: Int,
  dpi: Int,
) -> DecompressResult

@external(erlang, "imagex_c", "tiff_load_document")
fn tiff_load_document(bytes: BitArray) -> Result(ImageType, String)

@external(erlang, "imagex_c", "tiff_render_page")
fn tiff_render_page_data(ref: Reference, page_idx: Int) -> DecompressResult

pub fn decode(bytes: BitArray) -> Result(ImageType, String) {
  case detect.detect(bytes) {
    Some(JPEG) -> {
      use #(pixels, width, height, channels, bit_depth, _, _, _, _) <- result.try(
        jpeg_decompress(bytes),
      )
      Ok(Image(pixels:, width:, height:, channels:, bit_depth:))
    }

    Some(PNG) -> {
      use #(pixels, width, height, channels, bit_depth, _, _, _, _) <- result.try(
        png_decompress(bytes),
      )
      Ok(Image(pixels:, width:, height:, channels:, bit_depth:))
    }

    Some(JXL) -> {
      use #(pixels, width, height, channels, bit_depth, _, _, _, _) <- result.try(
        jxl_decompress(bytes),
      )
      Ok(Image(pixels:, width:, height:, channels:, bit_depth:))
    }

    Some(BMP) -> {
      bmp.decode(bytes)
    }

    Some(PPM) -> {
      ppm.decode(bytes)
    }

    Some(TIFF) -> tiff_load_document(bytes)

    Some(PDF) -> pdf_load_document(bytes)

    None -> Error("Unknown format")
  }
}

pub fn encode(image: ImageType, format: Format) -> Result(BitArray, String) {
  case image {
    Image(pixels:, width:, height:, channels:, bit_depth:) -> {
      case format {
        JPEG -> jpeg_compress(pixels, width, height, channels, 75, None, None)
        PNG -> png_compress(pixels, width, height, channels, bit_depth, [])
        JXL ->
          jxl_compress(
            pixels,
            width,
            height,
            channels,
            bit_depth,
            None,
            None,
            1.0,
            False,
            7,
            1,
            1,
          )
        BMP -> bmp.encode(pixels, width, height, channels, bit_depth)
        PPM -> ppm.encode(pixels, width, height, channels, bit_depth)

        TIFF -> Error("Cannot encode TIFF images")
        PDF -> Error("Cannot encode PDF images")
      }
    }

    TIFFImage(_ref, _num_pages) -> Error("Cannot encode TIFF documents")

    PDFImage(_ref, _num_pages) -> Error("Cannot encode PDF documents")
  }
}

pub fn render_pdf_page(
  document: ImageType,
  page_idx: Int,
  dpi: Int,
) -> Result(ImageType, String) {
  case document {
    PDFImage(ref, _) -> render_page(pdf_render_page_data(ref, page_idx, dpi))
    _ -> Error("Expected a PDF document")
  }
}

pub fn render_tiff_page(
  document: ImageType,
  page_idx: Int,
) -> Result(ImageType, String) {
  case document {
    TIFFImage(ref, _) -> render_page(tiff_render_page_data(ref, page_idx))
    _ -> Error("Expected a TIFF document")
  }
}

pub fn open(path: String) -> Result(ImageType, String) {
  case read_bits(path) {
    Ok(data) -> decode(data)

    Error(_) -> Error("Error reading file")
  }
}

fn render_page(rendered: DecompressResult) -> Result(ImageType, String) {
  use #(pixels, width, height, channels, bit_depth, _, _, _, _) <- result.try(
    rendered,
  )
  Ok(Image(pixels:, width:, height:, channels:, bit_depth:))
}
