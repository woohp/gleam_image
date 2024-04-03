import gleam/bit_array.{byte_size}
import gleam/io
import gleam/list
import image.{type ImageType, Image}

pub fn encode(
  pixels: BitArray,
  width: Int,
  height: Int,
  channels: Int,
) -> Result(BitArray, String) {
  let total_file_size = 14 + 40 + byte_size(pixels)

  case channels {
    3 -> {
      let out = <<
        // bitmap file header (14 bytes)
        "BM":utf8,
        total_file_size:32-little,
        0:16,
        0:16,
        52:32-little,
        // DIB header (40 bytes)
        40:32-little,
        width:32-little,
        height:32-little,
        1:16-little,
        24:16-little,
        0:32,
        0:32,
        2834:32-little,
        2834:32-little,
        0:32,
        0:32,
        // pixels
        pixels:bits,
      >>

      Ok(out)
    }

    _ -> {
      Error("Only works with 3 channels")
    }
  }
}

pub fn decode(bytes: BitArray) -> Result(ImageType, String) {
  case bytes {
    <<
      // bitmap file header
      "BM":utf8,
      _size_of_file:32,
      _:16,
      _:16,
      offset_to_pixels:32-little,
      // DIB header (we only parse a subset of it)
      _dib_header_size:32-little,
      width:signed-32-little,
      height:signed-32-little,
      1:16-little,
      bits_per_pixel:16-little,
      0:32,
      // everything else
      _rest:bytes,
    >> -> {
      // TODO: need to check that _dib_header_size is 40 or 56
      let assert <<_header:bytes-size(offset_to_pixels), pixels:bytes>> = bytes

      let channels = bits_per_pixel / 8

      // convert from bgr to rgb
      let pixels_exploded =
        pixels
        |> split_pixels(channels)
        |> list.map(to_rgb)

      let pixels = case height > 0 {
        True -> {
          list.sized_chunk(pixels_exploded, width)
          |> list.reverse()
          |> list.flatten()
          |> bit_array.concat()
        }

        False -> {
          bit_array.concat(pixels_exploded)
        }
      }

      Ok(Image(pixels, width, height, channels, bits_per_pixel))
    }

    _ -> {
      Error("Not a BMP file")
    }
  }
}

fn split_pixels(pixels: BitArray, channels: Int) -> List(BitArray) {
  case pixels {
    <<pixel:bytes-size(channels), rest:bits>> -> [
      pixel,
      ..split_pixels(rest, channels)
    ]

    <<>> -> []

    _ -> panic as "Could not split pixels"
  }
}

fn to_rgb(pixel: BitArray) -> BitArray {
  case pixel {
    <<b:8, g:8, r:8>> -> <<b:8, g:8, r:8>>

    <<b:8, g:8, r:8, a:8>> -> <<b:8, g:8, r:8, a:8>>

    _ -> pixel
  }
}
