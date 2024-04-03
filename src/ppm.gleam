import image.{type ImageType, Image, MultiImage}
import gleam/int
import gleam/bit_array
import gleam/string
import gleam/result

pub fn encode(
  pixels: BitArray,
  width: Int,
  height: Int,
  channels: Int,
) -> Result(BitArray, String) {
  case channels {
    1 -> {
      let header: String =
        "P5\n"
        <> int.to_string(width)
        <> " "
        <> int.to_string(height)
        <> "\n255\n"
      Ok(<<header:utf8, pixels:bits>>)
    }

    3 -> {
      let header =
        "P6\n"
        <> int.to_string(width)
        <> " "
        <> int.to_string(height)
        <> "\n255\n"
      Ok(<<header:utf8, pixels:bits>>)
    }

    _ -> {
      Error("Only works with 1 or 3 channels")
    }
  }
}

pub fn decode(bytes: BitArray) -> Result(ImageType, String) {
  case bytes {
    <<"P":utf8, n, "\n":utf8, rest:bytes>> if n == 53 || n == 54 -> {
      case read_line(rest) {
        #(line, pixels) -> {
          case string.split(line, " ") {
            [width_str, height_str, _max_value_str] -> {
              case #(int.parse(width_str), int.parse(height_str)) {
                #(Ok(width), Ok(height)) -> {
                  Ok(Image(pixels, width, height, 3, 8))
                }

                _ -> {
                  Error("Invalid PPM")
                }
              }
            }

            _ -> {
              Error("Invalid PPM")
            }
          }
        }

        _ -> {
          Error("Invalid PPM")
        }
      }
    }

    _ -> {
      Error("Invalid PPM")
    }
  }
}

fn read_line(bytes: BitArray) -> #(String, BitArray) {
  read_line_impl(bytes, 0)
}

fn read_line_impl(bytes: BitArray, i: Int) -> #(String, BitArray) {
  case bytes {
    <<line:bytes-size(i), "\n":utf8, rest:bytes>> -> {
      case bit_array.to_string(line) {
        Ok(str) -> #(str, <<>>)
        Error(err) -> {
          #("", bytes)
        }
      }
    }

    _ -> {
      case i >= bit_array.byte_size(bytes) {
        True -> {
          case bit_array.to_string(bytes) {
            Ok(str) -> #(str, <<>>)
            Error(err) -> {
              #("", bytes)
            }
          }
        }

        False -> read_line_impl(bytes, i + 1)
      }
    }
  }
}
