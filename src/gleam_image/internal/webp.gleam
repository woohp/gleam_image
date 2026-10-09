import gleam/bit_array
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

type Chunk =
  #(BitArray, BitArray)

pub fn prepare_pixels(
  pixels: BitArray,
  width: Int,
  height: Int,
  channels: Int,
  bit_depth: Int,
) -> Result(#(BitArray, Int), String) {
  let size = bit_array.byte_size(pixels)

  case bit_depth, channels {
    _, _ if bit_depth != 8 || channels < 1 || channels > 4 ->
      Error("WebP requires 1–4 channels and unsigned 8-bit pixels")
    _, _ if width <= 0 || height <= 0 || size != width * height * channels ->
      Error("Invalid WebP pixel buffer")
    _, 1 -> Ok(#(expand_grayscale(pixels, channels, []), 3))
    _, 2 -> Ok(#(expand_grayscale(pixels, channels, []), 4))
    _, _ -> Ok(#(pixels, channels))
  }
}

fn expand_grayscale(
  pixels: BitArray,
  channels: Int,
  acc: List(BitArray),
) -> BitArray {
  case pixels, channels {
    <<gray, rest:bytes>>, 1 ->
      expand_grayscale(rest, channels, [<<gray, gray, gray>>, ..acc])
    <<gray, alpha, rest:bytes>>, 2 ->
      expand_grayscale(rest, channels, [<<gray, gray, gray, alpha>>, ..acc])
    _, _ -> acc |> list.reverse |> bit_array.concat
  }
}

pub fn put_metadata(
  bytes: BitArray,
  width: Int,
  height: Int,
  alpha: Bool,
  exif: Option(BitArray),
  xmp: Option(BitArray),
) -> Result(BitArray, String) {
  case exif, xmp {
    None, None -> Ok(bytes)
    _, _ -> {
      use chunks <- result.try(read_chunks(bytes))

      // Simple VP8/VP8L output needs a VP8X header to advertise metadata.
      let flags =
        flag(alpha, 0x10) + flag(exif != None, 0x08) + flag(xmp != None, 0x04)
      let header = <<
        flags,
        0:24,
        { width - 1 }:24-little,
        { height - 1 }:24-little,
      >>
      let image_chunks =
        list.filter(chunks, fn(chunk) {
          let #(tag, _) = chunk
          tag != <<"VP8X":utf8>>
          && tag != <<"EXIF":utf8>>
          && tag != <<"XMP ":utf8>>
        })
      let chunks =
        list.append(
          [#(<<"VP8X":utf8>>, header), ..image_chunks],
          list.append(metadata_chunk("EXIF", exif), metadata_chunk("XMP ", xmp)),
        )
      let body = list.map(chunks, encode_chunk) |> bit_array.concat
      let size = bit_array.byte_size(body) + 4
      Ok(<<"RIFF":utf8, size:32-little, "WEBP":utf8, body:bits>>)
    }
  }
}

fn flag(present: Bool, value: Int) -> Int {
  case present {
    True -> value
    False -> 0
  }
}

fn metadata_chunk(tag: String, contents: Option(BitArray)) -> List(Chunk) {
  case contents {
    Some(data) -> [#(<<tag:utf8>>, data)]
    None -> []
  }
}

fn encode_chunk(chunk: Chunk) -> BitArray {
  let #(tag, data) = chunk
  let size = bit_array.byte_size(data)
  let padding = { size % 2 } * 8
  <<tag:bits, size:32-little, data:bits, 0:size(padding)>>
}

pub fn read_metadata(
  bytes: BitArray,
) -> Result(#(Option(BitArray), Option(BitArray)), String) {
  use chunks <- result.try(read_chunks(bytes))
  Ok(
    list.fold(chunks, #(None, None), fn(metadata, chunk) {
      let #(exif, xmp) = metadata
      case chunk {
        #(<<"EXIF":utf8>>, <<"Exif":utf8, 0, 0, tiff:bytes>>) -> #(
          Some(tiff),
          xmp,
        )
        #(<<"EXIF":utf8>>, tiff) -> #(Some(tiff), xmp)
        #(<<"XMP ":utf8>>, data) -> #(exif, Some(data))
        _ -> metadata
      }
    }),
  )
}

fn read_chunks(bytes: BitArray) -> Result(List(Chunk), String) {
  case bytes {
    <<"RIFF":utf8, size:32-little, "WEBP":utf8, rest:bytes>> if size >= 4 -> {
      // Ignore bytes outside the declared extent, but never tolerate truncation.
      case rest {
        <<chunks:bytes-size(size - 4), _trailing:bytes>> ->
          parse_chunks(chunks, [])
        _ -> Error("Invalid WebP container")
      }
    }
    _ -> Error("Invalid WebP container")
  }
}

fn parse_chunks(
  bytes: BitArray,
  acc: List(Chunk),
) -> Result(List(Chunk), String) {
  case bytes {
    <<>> -> Ok(list.reverse(acc))
    <<tag:bytes-size(4), size:32-little, rest:bytes>> -> {
      // Every odd-length RIFF chunk must include a zero padding byte.
      let padding = { size % 2 } * 8
      case rest {
        <<data:bytes-size(size), 0:size(padding), tail:bytes>> ->
          parse_chunks(tail, [#(tag, data), ..acc])
        _ -> Error("Invalid WebP chunk")
      }
    }
    _ -> Error("Invalid WebP chunk")
  }
}
