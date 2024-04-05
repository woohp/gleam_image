import gleam/io
import gleam/option.{type Option, None, Some}
import simplifile.{read_bits}
import gleam/string
import gleam/erlang.{type Reference}
import gleam/result
import image.{type ImageType, Image, MultiImage}
import detect.{type Format, BMP, JPEG, JXL, PDF, PNG, PPM, TIFF, detect}
import bmp
import ppm

type DecompressResult =
  Result(#(BitArray, Int, Int, Int, Int, Option(BitArray)), String)

@external(erlang, "imagex_c", "jpeg_decompress")
fn jpeg_decompress(bytes: BitArray) -> DecompressResult

@external(erlang, "imagex_c", "jpeg_decompress")
fn jpeg_compress(
  pixels: BitArray,
  width: Int,
  height: Int,
  channels: Int,
  quality: Int,
) -> BitArray

@external(erlang, "imagex_c", "png_decompress")
fn png_decompress(bytes: BitArray) -> DecompressResult

@external(erlang, "imagex_c", "png_compress")
fn png_compress(
  pixels: BitArray,
  width: Int,
  height: Int,
  channels: Int,
) -> BitArray

@external(erlang, "imagex_c", "jxl_decompress")
fn jxl_decompress(bytes: BitArray) -> DecompressResult

@external(erlang, "imagex_c", "jxl_compress")
fn jxl_compress(
  pixels: BitArray,
  width: Int,
  height: Int,
  channels: Int,
  bit_depth: Int,
  distance: Int,
  lossless: Bool,
  effort: Int,
) -> BitArray

@external(erlang, "imagex_c", "jxl_transcode_from_jpeg")
fn jxl_transcode_from_jpeg(
  jepg_bytes: BitArray,
  effort: Int,
  store_jpeg_metadata: Bool,
) -> BitArray

@external(erlang, "imagex_c", "jxl_transcode_to_jpeg")
fn jxl_transcode_to_jpeg(jxl_bytes: BitArray) -> BitArray

@external(erlang, "imagex_c", "pdf_load_document")
fn pdf_load_document(bytes: BitArray) -> Result(#(Reference, Int), String)

@external(erlang, "imagex_c", "pdf_render_page")
fn pdf_render_page(ref: Reference, page_idx: Int, dpi: Int) -> DecompressResult

@external(erlang, "imagex_c", "tiff_load_document")
fn tiff_load_document(bytes: BitArray) -> Result(#(Reference, Int), String)

@external(erlang, "imagex_c", "tiff_render_page")
fn tiff_render_page(ref: Reference, page_idx: Int, dpi: Int) -> DecompressResult

pub fn decode(bytes: BitArray) -> Result(ImageType, String) {
  case detect.detect(bytes) {
    Some(JPEG) -> {
      use #(pixels, width, height, channels, bit_depth, _) <- result.try(
        jpeg_decompress(bytes),
      )
      Ok(Image(pixels, width, height, channels, bit_depth))
    }

    Some(PNG) -> {
      use #(pixels, width, height, channels, bit_depth, _) <- result.try(
        png_decompress(bytes),
      )
      Ok(Image(pixels, width, height, channels, bit_depth))
    }

    Some(JXL) -> {
      use #(pixels, width, height, channels, bit_depth, _) <- result.try(
        jxl_decompress(bytes),
      )
      Ok(Image(pixels, width, height, channels, bit_depth))
    }

    Some(BMP) -> {
      bmp.decode(bytes)
    }

    Some(PPM) -> {
      ppm.decode(bytes)
    }

    Some(TIFF) -> {
      use #(ref, num_pages) <- result.try(tiff_load_document(bytes))
      Ok(MultiImage(ref, num_pages))
    }

    Some(PDF) -> {
      use #(ref, num_pages) <- result.try(pdf_load_document(bytes))
      Ok(MultiImage(ref, num_pages))
    }

    None -> Error("Unknown format")
  }
}

pub fn main() {
  io.println("Hey there!")
  case read_bits("lena.jpg") {
    Ok(data) -> {
      case jpeg_decompress(data) {
        Ok(#(pixels, width, height, channels, quality, _)) -> {
          io.println("Done!")
        }
        Error(err) -> {
          io.println("Error!")
        }
      }
    }
    Error(err) -> {
      io.println(string.inspect(err))
    }
  }
}
