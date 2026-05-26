import gleam/bit_array
import gleam/int
import gleam/result
import gleam/string
import vars/internal/image.{type ImageType, Image}

pub fn encode(
  pixels: BitArray,
  width: Int,
  height: Int,
  channels: Int,
  bit_depth: Int,
) -> Result(BitArray, String) {
  case channels, bit_depth {
    1, 8 -> {
      let header: String =
        "P5\n"
        <> int.to_string(width)
        <> " "
        <> int.to_string(height)
        <> "\n255\n"
      Ok(<<header:utf8, pixels:bits>>)
    }

    3, 8 -> {
      let header =
        "P6\n"
        <> int.to_string(width)
        <> " "
        <> int.to_string(height)
        <> "\n255\n"
      Ok(<<header:utf8, pixels:bits>>)
    }

    _, _ -> {
      Error("Only works with 1 or 3 channels")
    }
  }
}

pub fn decode(bytes: BitArray) -> Result(ImageType, String) {
  decode_impl(bytes)
  |> result.replace_error("Invalid PPM image")
}

pub fn decode_impl(bytes: BitArray) -> Result(ImageType, Nil) {
  case bytes {
    <<"P":utf8, n, "\n":utf8, rest:bytes>> if n == 53 || n == 54 -> {
      use #(line, rest) <- result.try(read_line(rest))

      case string.split(line, " ") {
        [width_str, height_str] -> {
          use width <- result.try(int.parse(width_str))
          use height <- result.try(int.parse(height_str))
          use #(_line, pixels) <- result.try(read_line(rest))
          Ok(Image(pixels:, width:, height:, channels: 3, bit_depth: 8))
        }

        _ -> {
          Error(Nil)
        }
      }
    }

    _ -> {
      Error(Nil)
    }
  }
}

fn read_line(bytes: BitArray) -> Result(#(String, BitArray), Nil) {
  read_line_impl(bytes, 0)
}

fn read_line_impl(bytes: BitArray, i: Int) -> Result(#(String, BitArray), Nil) {
  case bytes {
    <<line:bytes-size(i), "\n":utf8, rest:bytes>> -> {
      use str <- result.try(bit_array.to_string(line))
      Ok(#(str, rest))
    }

    _ -> {
      case i >= bit_array.byte_size(bytes) {
        True -> {
          use str <- result.try(bit_array.to_string(bytes))
          Ok(#(str, <<>>))
        }

        False -> read_line_impl(bytes, i + 1)
      }
    }
  }
}
