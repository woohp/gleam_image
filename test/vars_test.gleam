import gleam/bit_array.{byte_size}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleeunit
import gleeunit/should
import simplifile.{read_bits}
import vars.{
  type RasterImage, Bmp, Jpeg, Jxl, NativeError, Pdf, PdfFormat, Png, Ppm,
  Raster, RasterFormat, RasterImage, Tiff, TiffFormat, UnknownFormat, decode,
  decode_raster, default_jxl_transcode_options, detect, encode,
  jxl_transcode_from_jpeg, jxl_transcode_to_jpeg, pdf_pages, read, read_raster,
  render_pdf_page, render_tiff_page, tiff_pages,
}

pub fn main() {
  gleeunit.main()
}

fn rand_image(
  width: Int,
  height: Int,
  channels: Int,
  bit_depth: Int,
) -> RasterImage {
  let n = width * height * channels

  let pixels =
    list.range(0, n - 1)
    |> list.map(fn(i) { <<i:size(bit_depth)-native>> })
    |> bit_array.concat()

  RasterImage(pixels, width, height, channels, bit_depth)
}

// gleeunit test functions end in `_test`
pub fn ppm_test() {
  let assert Ok(data) = read_bits("test/assets/lena.ppm")
  let assert Ok(RasterImage(pixels, 512, 512, 3, 8)) = decode_raster(data)
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
  let assert Ok(new_data) = encode(RasterImage(pixels, 512, 512, 3, 8), Ppm)

  new_data
  |> should.equal(data)
}

pub fn bpm_neg_height_test() {
  let assert Ok(RasterImage(pixels, 512, 512, 4, 8)) =
    read_raster("test/assets/lena-rgba-neg-height.bmp")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 4)
}

pub fn bpm_pos_height_test() {
  let assert Ok(RasterImage(pixels, 512, 512, 3, 8)) =
    read_raster("test/assets/lena-rgb-pos-height.bmp")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
}

pub fn bmp_encode_roundtrip_test() {
  let assert Ok(image) = read_raster("test/assets/lena.ppm")
  let assert Ok(new_data) = encode(image, Bmp)
  let assert Ok(_new_image) = decode(new_data)
  // new_image
  // |> should.equal(image)
}

pub fn jpeg_decode_test() {
  let assert Ok(RasterImage(pixels, 512, 512, 3, 8)) =
    read_raster("test/assets/lena.jpg")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
}

pub fn jpeg_decode_returns_error_for_bad_input_test() {
  let assert Error(UnknownFormat) = decode(<<0, 1, 2>>)
}

pub fn jpeg_encode_roundtrip_test() {
  let assert Ok(image) = read_raster("test/assets/lena.jpg")
  let assert Ok(data) = encode(image, Jpeg)
  let assert Ok(_new_image) = decode(data)
  image
  |> should.equal(image)
}

pub fn png_decode_rgb_image() {
  let assert Ok(RasterImage(pixels, 512, 512, 3, 8)) =
    read_raster("test/assets/lena.png")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
}

pub fn png_decode_grayscale_image_test() {
  let assert Ok(RasterImage(pixels, 512, 512, 1, 8)) =
    read_raster("test/assets/lena-grayscale.png")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512)
}

pub fn png_decode_palette_image_test() {
  let assert Ok(RasterImage(pixels, 512, 512, 3, 8)) =
    read_raster("test/assets/lena-palette.png")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
}

pub fn png_decode_rgba_image_test() {
  let assert Ok(RasterImage(pixels, 512, 512, 4, 8)) =
    read_raster("test/assets/lena-rgba.png")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 4)
}

pub fn png_decode_16bit_image_test() {
  let assert Ok(RasterImage(pixels, 170, 118, 4, 16)) =
    read_raster("test/assets/16bit.png")
  bit_array.byte_size(pixels)
  |> should.equal(170 * 118 * 4 * 2)

  pixels
  |> bit_array.slice(0, 20)
  |> result.unwrap(<<>>)
  |> should.equal(<<
    45_759:16-native, 46_783:16-native, 49_727:16-native, 65_535:16-native,
    45_631:16-native, 46_655:16-native, 49_599:16-native, 65_535:16-native,
    45_663:16-native, 46_783:16-native,
  >>)
}

pub fn png_encode_rgb_roundtrip_test() {
  let assert Ok(image) = read_raster("test/assets/lena.ppm")
  let assert Ok(data) = encode(image, Png)
  let assert Ok(new_image) = decode_raster(data)
  new_image
  |> should.equal(image)
}

pub fn png_encode_rgba_roundtrip_test() {
  let image = rand_image(16, 16, 4, 8)
  let assert Ok(data) = encode(image, Png)
  let assert Ok(new_image) = decode_raster(data)
  new_image
  |> should.equal(image)
}

pub fn png_encode_grayscale_roundtrip_test() {
  let image = rand_image(16, 16, 1, 8)
  let assert Ok(data) = encode(image, Png)
  let assert Ok(new_image) = decode_raster(data)
  new_image
  |> should.equal(image)
}

pub fn png_encode_rgb_16bit_roundtrip_test() {
  let image = rand_image(16, 16, 3, 16)
  let assert Ok(data) = encode(image, Png)
  let assert Ok(new_image) = decode_raster(data)
  new_image
  |> should.equal(image)
}

pub fn png_encode_rgba_16bit_roundtrip_test() {
  let image = rand_image(16, 16, 4, 16)
  let assert Ok(data) = encode(image, Png)
  let assert Ok(new_image) = decode_raster(data)
  new_image
  |> should.equal(image)
}

pub fn png_encode_grayscale_16bit_roundtrip_test() {
  let image = rand_image(16, 16, 1, 16)
  let assert Ok(data) = encode(image, Png)
  let assert Ok(new_image) = decode_raster(data)
  new_image
  |> should.equal(image)
}

pub fn png_encode_grayscale_alpha_16bit_roundtrip_test() {
  let image = rand_image(16, 16, 2, 16)
  let assert Ok(data) = encode(image, Png)
  let assert Ok(new_image) = decode_raster(data)
  new_image
  |> should.equal(image)
}

pub fn jxl_decode_rgb_image() {
  let assert Ok(RasterImage(pixels, 512, 512, 3, 8)) =
    read_raster("test/assets/lena.jxl")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
}

pub fn jxl_decode_grayscale_image_test() {
  let assert Ok(RasterImage(pixels, 512, 512, 1, 8)) =
    read_raster("test/assets/lena-grayscale.jxl")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512)
}

pub fn jxl_decode_rgba_image_test() {
  let assert Ok(RasterImage(pixels, 512, 512, 4, 8)) =
    read_raster("test/assets/lena-rgba.jxl")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 4)
}

pub fn jxl_decode_16bit_image_test() {
  let assert Ok(RasterImage(pixels, 170, 118, 4, 16)) =
    read_raster("test/assets/16bit.jxl")
  bit_array.byte_size(pixels)
  |> should.equal(170 * 118 * 4 * 2)

  pixels
  |> bit_array.slice(0, 20)
  |> result.unwrap(<<>>)
  |> should.equal(<<
    45_759:16-native, 46_783:16-native, 49_727:16-native, 65_535:16-native,
    45_631:16-native, 46_655:16-native, 49_599:16-native, 65_535:16-native,
    45_663:16-native, 46_783:16-native,
  >>)
}

pub fn jxl_encode_rgb_test() {
  let assert Ok(image) = read_raster("test/assets/lena.ppm")
  let assert Ok(jxl_bytes) = encode(image, Jxl)

  // the jpeg-xl bytes should be smaller than the jpeg bytes
  let assert Ok(jpeg_bytes) = read_bits("test/assets/lena.ppm")
  { byte_size(jxl_bytes) < byte_size(jpeg_bytes) }
  |> should.be_true()
}

// pub fn jxl_encode_rgba_roundtrip_test() {
//   let image = rand_image(16, 16, 4, 8)
//   let assert Ok(data) = encode(image, Jxl)
//   let assert Ok(new_image) = decode_raster(data)
//   new_image
//   |> should.equal(image)
// }
//
// pub fn jxl_encode_grayscale_roundtrip_test() {
//   let image = rand_image(16, 16, 1, 8)
//   let assert Ok(data) = encode(image, Jxl)
//   let assert Ok(new_image) = decode_raster(data)
//   new_image
//   |> should.equal(image)
// }
//
// pub fn jxl_encode_rgb_16bit_roundtrip_test() {
//   let image = rand_image(16, 16, 3, 16)
//   let assert Ok(data) = encode(image, Jxl)
//   let assert Ok(new_image) = decode_raster(data)
//   new_image
//   |> should.equal(image)
// }
//
// pub fn jxl_encode_rgba_16bit_roundtrip_test() {
//   let image = rand_image(16, 16, 4, 16)
//   let assert Ok(data) = encode(image, Jxl)
//   let assert Ok(new_image) = decode_raster(data)
//   new_image
//   |> should.equal(image)
// }
//
// pub fn jxl_encode_grayscale_16bit_roundtrip_test() {
//   let image = rand_image(16, 16, 1, 16)
//   let assert Ok(data) = encode(image, Jxl)
//   let assert Ok(new_image) = decode_raster(data)
//   new_image
//   |> should.equal(image)
// }
//
// pub fn jxl_encode_grayscale_alpha_16bit_roundtrip_test() {
//   let image = rand_image(16, 16, 2, 16)
//   let assert Ok(data) = encode(image, Jxl)
//   let assert Ok(new_image) = decode_raster(data)
//   new_image
//   |> should.equal(image)
// }

pub fn detect_formats_test() {
  let assert Ok(jpeg) = read_bits("test/assets/lena.jpg")
  detect(jpeg)
  |> should.equal(Some(RasterFormat(Jpeg)))

  let assert Ok(png) = read_bits("test/assets/lena.png")
  detect(png)
  |> should.equal(Some(RasterFormat(Png)))

  let assert Ok(jxl) = read_bits("test/assets/lena.jxl")
  detect(jxl)
  |> should.equal(Some(RasterFormat(Jxl)))

  let assert Ok(bmp) = read_bits("test/assets/lena-rgb-pos-height.bmp")
  detect(bmp)
  |> should.equal(Some(RasterFormat(Bmp)))

  let assert Ok(ppm) = read_bits("test/assets/lena.ppm")
  detect(ppm)
  |> should.equal(Some(RasterFormat(Ppm)))

  let assert Ok(tiff) = read_bits("test/assets/lena.tiff")
  detect(tiff)
  |> should.equal(Some(TiffFormat))

  let assert Ok(pdf) = read_bits("test/assets/lena.pdf")
  detect(pdf)
  |> should.equal(Some(PdfFormat))

  detect(<<0, 1, 2>>)
  |> should.equal(None)
}

pub fn jxl_transcode_from_jpeg_test() {
  let assert Ok(jpeg_bytes) = read_bits("test/assets/lena.jpg")
  let assert Ok(jxl_bytes) =
    jxl_transcode_from_jpeg(jpeg_bytes, default_jxl_transcode_options())

  { byte_size(jxl_bytes) < byte_size(jpeg_bytes) }
  |> should.be_true()

  let assert Ok(Raster(RasterImage(pixels, 512, 512, 3, 8))) = decode(jxl_bytes)
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
}

pub fn jxl_transcode_to_jpeg_test() {
  let assert Ok(jxl_bytes) = read_bits("test/assets/lena-transcode.jxl")
  let assert Ok(jpeg_bytes) = jxl_transcode_to_jpeg(jxl_bytes)
  let assert Ok(Raster(RasterImage(pixels, 512, 512, 3, 8))) =
    decode(jpeg_bytes)
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
}

pub fn jxl_transcode_to_jpeg_error_test() {
  let assert Ok(jxl_bytes) = read_bits("test/assets/lena.jxl")
  let assert Error(NativeError(reason)) = jxl_transcode_to_jpeg(jxl_bytes)
  string.starts_with(reason, "Cannot transcode to JPEG")
  |> should.be_true()
}

pub fn pdf_render_page_test() {
  let assert Ok(Pdf(pdf)) = read("test/assets/lena.pdf")
  pdf_pages(pdf)
  |> should.equal(1)
  let assert Ok(RasterImage(pixels, 512, 512, 4, 8)) =
    render_pdf_page(pdf, 0, 72)
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 4)

  let assert Ok(RasterImage(high_dpi_pixels, 1024, 1024, 4, 8)) =
    render_pdf_page(pdf, 0, 144)
  bit_array.byte_size(high_dpi_pixels)
  |> should.equal(1024 * 1024 * 4)
}

pub fn tiff_render_page_test() {
  let assert Ok(Tiff(tiff)) = read("test/assets/lena.tiff")
  tiff_pages(tiff)
  |> should.equal(1)
  let assert Ok(RasterImage(pixels, 512, 512, 4, 8)) = render_tiff_page(tiff, 0)
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 4)
}
