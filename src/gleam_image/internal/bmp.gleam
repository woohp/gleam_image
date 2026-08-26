import gleam/bit_array.{byte_size}
import gleam/int
import gleam/list
import gleam_image/internal/image.{type Image, Image}

// BMP pixel rows are stored bottom-up, in BGR(A) order, and padded to a
// multiple of 4 bytes. Raster images are top-down RGB(A) with no padding.
// The red/blue swap and the row flip are both self-inverse, so encode and
// decode share them.

pub fn encode(
  pixels: BitArray,
  width: Int,
  height: Int,
  channels: Int,
  bit_depth: Int,
) -> Result(BitArray, String) {
  case channels, bit_depth {
    3, 8 | 4, 8 ->
      case byte_size(pixels) == width * height * channels {
        True -> Ok(encode_valid(pixels, width, height, channels))
        False -> Error("Pixel data does not match the image dimensions")
      }

    _, _ -> Error("Only works with 3 or 4 channels and 8 bit depth")
  }
}

fn encode_valid(
  pixels: BitArray,
  width: Int,
  height: Int,
  channels: Int,
) -> BitArray {
  let row_bytes = width * channels
  let stride = row_stride(width, channels)
  let padding_bits = { stride - row_bytes } * 8
  let bits_per_pixel = channels * 8
  let total_file_size = 14 + 40 + stride * height
  // 2834 pixels per meter is roughly 72 DPI
  let pixels_per_meter = 2834

  let bmp_pixels =
    split_rows(pixels, row_bytes, height)
    |> list.map(fn(row) {
      let bgr = swap_red_blue(row, channels)
      <<bgr:bits, 0:size(padding_bits)>>
    })
    |> list.reverse()
    |> bit_array.concat()

  <<
    // bitmap file header (14 bytes)
    "BM":utf8,
    total_file_size:32-little,
    0:16,
    0:16,
    54:32-little,
    // DIB header (40 bytes)
    40:32-little,
    width:32-little,
    height:32-little,
    1:16-little,
    bits_per_pixel:16-little,
    0:32,
    0:32,
    pixels_per_meter:32-little,
    pixels_per_meter:32-little,
    0:32,
    0:32,
    // pixels
    bmp_pixels:bits,
  >>
}

pub fn decode(bytes: BitArray) -> Result(Image, String) {
  case bytes {
    <<
      // bitmap file header
      "BM":utf8,
      _size_of_file:32,
      _:16,
      _:16,
      offset_to_pixels:32-little,
      // DIB header (we only parse a subset of it)
      dib_header_size:32-little,
      width:signed-32-little,
      height:signed-32-little,
      1:16-little,
      bits_per_pixel:16-little,
      0:32,
      // everything else
      _rest:bytes,
    >>
      if { dib_header_size == 40 || dib_header_size == 124 }
      && { bits_per_pixel == 24 || bits_per_pixel == 32 }
      && width > 0
    -> decode_pixels(bytes, offset_to_pixels, width, height, bits_per_pixel / 8)

    _ -> Error("Not a BMP file")
  }
}

fn decode_pixels(
  bytes: BitArray,
  offset_to_pixels: Int,
  width: Int,
  height: Int,
  channels: Int,
) -> Result(Image, String) {
  let stride = row_stride(width, channels)
  let abs_height = int.absolute_value(height)

  case bytes {
    <<_header:bytes-size(offset_to_pixels), pixels:bytes>> ->
      case byte_size(pixels) >= stride * abs_height {
        True -> {
          let rows =
            split_rows(pixels, stride, abs_height)
            |> list.map(decode_row(_, width * channels, channels))

          // a positive height means rows are stored bottom-up
          let rows = case height > 0 {
            True -> list.reverse(rows)
            False -> rows
          }

          Ok(Image(
            pixels: bit_array.concat(rows),
            width:,
            height: abs_height,
            channels:,
            bit_depth: 8,
          ))
        }

        False -> Error("Truncated BMP pixel data")
      }

    _ -> Error("Truncated BMP pixel data")
  }
}

fn decode_row(row: BitArray, row_bytes: Int, channels: Int) -> BitArray {
  // drop the row padding, then convert BGR(A) to RGB(A)
  let assert <<row_pixels:bytes-size(row_bytes), _padding:bytes>> = row
  swap_red_blue(row_pixels, channels)
}

/// Rows are padded to a multiple of 4 bytes.
fn row_stride(width: Int, channels: Int) -> Int {
  { width * channels + 3 } / 4 * 4
}

/// Split `count` rows of `row_bytes` each off the front of `pixels`,
/// ignoring any trailing bytes. Callers validate the buffer is big enough.
fn split_rows(pixels: BitArray, row_bytes: Int, count: Int) -> List(BitArray) {
  case count {
    0 -> []
    _ -> {
      let assert <<row:bytes-size(row_bytes), rest:bytes>> = pixels
      [row, ..split_rows(rest, row_bytes, count - 1)]
    }
  }
}

fn swap_red_blue(pixels: BitArray, channels: Int) -> BitArray {
  split_pixels(pixels, channels)
  |> list.map(swap_pixel)
  |> bit_array.concat()
}

fn split_pixels(pixels: BitArray, channels: Int) -> List(BitArray) {
  case pixels {
    <<>> -> []

    <<pixel:bytes-size(channels), rest:bits>> -> [
      pixel,
      ..split_pixels(rest, channels)
    ]

    // unreachable: callers validate sizes before splitting
    _ -> panic as "pixel data is not a whole number of pixels"
  }
}

fn swap_pixel(pixel: BitArray) -> BitArray {
  case pixel {
    <<b:8, g:8, r:8>> -> <<r:8, g:8, b:8>>

    <<b:8, g:8, r:8, a:8>> -> <<r:8, g:8, b:8, a:8>>

    _ -> pixel
  }
}
