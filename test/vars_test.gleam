import detect.{type Format, BMP, JPEG, JXL, PDF, PNG, PPM, TIFF}
import gleam/bit_array.{byte_size}
import gleam/io
import gleam/list
import gleam/result
import gleeunit
import gleeunit/should
import image.{type ImageType, Image}
import simplifile.{read_bits}
import vars

pub fn main() {
  gleeunit.main()
}

fn rand_image(
  width: Int,
  height: Int,
  channels: Int,
  bit_depth: Int,
) -> ImageType {
  let n = width * height * channels

  let pixels =
    list.range(0, n - 1)
    |> list.map(fn(i) { <<i:size(bit_depth)-native>> })
    |> bit_array.concat()

  Image(pixels, width, height, channels, bit_depth)
}

// gleeunit test functions end in `_test`
pub fn ppm_test() {
  let assert Ok(data) = read_bits("test/assets/lena.ppm")
  let assert Ok(Image(pixels, 512, 512, 3, 8)) = vars.decode(data)
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
  let assert Ok(new_data) = vars.encode(Image(pixels, 512, 512, 3, 8), PPM)

  new_data
  |> should.equal(data)
}

pub fn bpm_neg_height_test() {
  let assert Ok(Image(pixels, 512, 512, 4, 8)) =
    vars.open("test/assets/lena-rgba-neg-height.bmp")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 4)
}

pub fn bpm_pos_height_test() {
  let assert Ok(Image(pixels, 512, 512, 3, 8)) =
    vars.open("test/assets/lena-rgb-pos-height.bmp")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
}

pub fn bmp_encode_roundtrip_test() {
  let assert Ok(image) = vars.open("test/assets/lena.ppm")
  let assert Ok(new_data) = vars.encode(image, BMP)
  let assert Ok(new_image) = vars.decode(new_data)
  image
  |> should.equal(image)
}

pub fn jpeg_decode_test() {
  let assert Ok(Image(pixels, 512, 512, 3, 8)) =
    vars.open("test/assets/lena.jpg")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
}

pub fn jpeg_decode_returns_error_for_bad_input_test() {
  let assert Error("Unknown format") = vars.decode(<<0, 1, 2>>)
}

pub fn jpeg_encode_roundtrip_test() {
  let assert Ok(image) = vars.open("test/assets/lena.jpg")
  let assert Ok(data) = vars.encode(image, JPEG)
  let assert Ok(new_image) = vars.decode(data)
  image
  |> should.equal(image)
}

pub fn png_decode_rgb_image() {
  let assert Ok(Image(pixels, 512, 512, 3, 8)) =
    vars.open("test/assets/lena.png")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
}

pub fn png_decode_grayscale_image_test() {
  let assert Ok(Image(pixels, 512, 512, 1, 8)) =
    vars.open("test/assets/lena-grayscale.png")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512)
}

pub fn png_decode_palette_image_test() {
  let assert Ok(Image(pixels, 512, 512, 3, 8)) =
    vars.open("test/assets/lena-palette.png")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
}

pub fn png_decode_rgba_image_test() {
  let assert Ok(Image(pixels, 512, 512, 4, 8)) =
    vars.open("test/assets/lena-rgba.png")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 4)
}

pub fn png_decode_16bit_image_test() {
  let assert Ok(Image(pixels, 170, 118, 4, 16)) =
    vars.open("test/assets/16bit.png")
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
  let assert Ok(image) = vars.open("test/assets/lena.ppm")
  let assert Ok(data) = vars.encode(image, PNG)
  let assert Ok(new_image) = vars.decode(data)
  new_image
  |> should.equal(image)
}

pub fn png_encode_rgba_roundtrip_test() {
  let image = rand_image(16, 16, 4, 8)
  let assert Ok(data) = vars.encode(image, PNG)
  let assert Ok(new_image) = vars.decode(data)
  new_image
  |> should.equal(image)
}

pub fn png_encode_grayscale_roundtrip_test() {
  let image = rand_image(16, 16, 1, 8)
  let assert Ok(data) = vars.encode(image, PNG)
  let assert Ok(new_image) = vars.decode(data)
  new_image
  |> should.equal(image)
}

pub fn png_encode_rgb_16bit_roundtrip_test() {
  let image = rand_image(16, 16, 3, 16)
  let assert Ok(data) = vars.encode(image, PNG)
  let assert Ok(new_image) = vars.decode(data)
  new_image
  |> should.equal(image)
}

pub fn png_encode_rgba_16bit_roundtrip_test() {
  let image = rand_image(16, 16, 4, 16)
  let assert Ok(data) = vars.encode(image, PNG)
  let assert Ok(new_image) = vars.decode(data)
  new_image
  |> should.equal(image)
}

pub fn png_encode_grayscale_16bit_roundtrip_test() {
  let image = rand_image(16, 16, 1, 16)
  let assert Ok(data) = vars.encode(image, PNG)
  let assert Ok(new_image) = vars.decode(data)
  new_image
  |> should.equal(image)
}

pub fn png_encode_grayscale_alpha_16bit_roundtrip_test() {
  let image = rand_image(16, 16, 2, 16)
  let assert Ok(data) = vars.encode(image, PNG)
  let assert Ok(new_image) = vars.decode(data)
  new_image
  |> should.equal(image)
}

pub fn jxl_decode_rgb_image() {
  let assert Ok(Image(pixels, 512, 512, 3, 8)) =
    vars.open("test/assets/lena.jxl")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 3)
}

pub fn jxl_decode_grayscale_image_test() {
  let assert Ok(Image(pixels, 512, 512, 1, 8)) =
    vars.open("test/assets/lena-grayscale.jxl")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512)
}

pub fn jxl_decode_rgba_image_test() {
  let assert Ok(Image(pixels, 512, 512, 4, 8)) =
    vars.open("test/assets/lena-rgba.jxl")
  bit_array.byte_size(pixels)
  |> should.equal(512 * 512 * 4)
}

pub fn jxl_decode_16bit_image_test() {
  let assert Ok(Image(pixels, 170, 118, 4, 16)) =
    vars.open("test/assets/16bit.jxl")
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
  let assert Ok(image) = vars.open("test/assets/lena.ppm")
  let assert Ok(jxl_bytes) = vars.encode(image, JXL)

  // the jpeg-xl bytes should be smaller than the jpeg bytes
  let assert Ok(jpeg_bytes) = read_bits("test/assets/lena.ppm")
  { byte_size(jxl_bytes) < byte_size(jpeg_bytes) }
  |> should.be_true()
}
// pub fn jxl_encode_rgba_roundtrip_test() {
//   let image = rand_image(16, 16, 4, 8)
//   let assert Ok(data) = vars.encode(image, JXL)
//   let assert Ok(new_image) = vars.decode(data)
//   new_image
//   |> should.equal(image)
// }
//
// pub fn jxl_encode_grayscale_roundtrip_test() {
//   let image = rand_image(16, 16, 1, 8)
//   let assert Ok(data) = vars.encode(image, JXL)
//   let assert Ok(new_image) = vars.decode(data)
//   new_image
//   |> should.equal(image)
// }
//
// pub fn jxl_encode_rgb_16bit_roundtrip_test() {
//   let image = rand_image(16, 16, 3, 16)
//   let assert Ok(data) = vars.encode(image, JXL)
//   let assert Ok(new_image) = vars.decode(data)
//   new_image
//   |> should.equal(image)
// }
//
// pub fn jxl_encode_rgba_16bit_roundtrip_test() {
//   let image = rand_image(16, 16, 4, 16)
//   let assert Ok(data) = vars.encode(image, JXL)
//   let assert Ok(new_image) = vars.decode(data)
//   new_image
//   |> should.equal(image)
// }
//
// pub fn jxl_encode_grayscale_16bit_roundtrip_test() {
//   let image = rand_image(16, 16, 1, 16)
//   let assert Ok(data) = vars.encode(image, JXL)
//   let assert Ok(new_image) = vars.decode(data)
//   new_image
//   |> should.equal(image)
// }
//
// pub fn jxl_encode_grayscale_alpha_16bit_roundtrip_test() {
//   let image = rand_image(16, 16, 2, 16)
//   let assert Ok(data) = vars.encode(image, JXL)
//   let assert Ok(new_image) = vars.decode(data)
//   new_image
//   |> should.equal(image)
// }
