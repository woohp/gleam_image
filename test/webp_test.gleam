import gleam/bit_array
import gleam/list
import gleam/option.{None, Some}
import gleam_image.{
  InvalidImage, InvalidOptions, NativeError, RasterFormat, RasterImage, Webp,
  WebpEncodeOptions, decode, decode_raster, decode_raster_with_metadata,
  default_webp_encode_options, detect, encode, encode_webp, read_raster,
}
import gleeunit/should
import simplifile.{read_bits}

@external(erlang, "webp_test_ffi", "fixture_expectations")
fn fixture_expectations() -> List(#(String, Int, Int, Int, String))

@external(erlang, "webp_test_ffi", "sha256")
fn sha256(bytes: BitArray) -> String

pub fn independent_fixtures_test() {
  list.each(fixture_expectations(), fn(expected) {
    let #(filename, width, height, channels, hash) = expected
    let assert Ok(bytes) = read_bits("test/assets/webp/" <> filename)
    detect(bytes) |> should.equal(Some(RasterFormat(Webp)))

    let assert Ok(RasterImage(
      pixels,
      actual_width,
      actual_height,
      actual_channels,
      8,
    )) = decode_raster(bytes)
    #(actual_width, actual_height, actual_channels)
    |> should.equal(#(width, height, channels))
    sha256(pixels) |> should.equal(hash)
  })
}

pub fn independent_exif_xmp_roundtrip_test() {
  let assert Ok(source) =
    read_bits(
      "test/assets/exif/exif-jpeg-thumbnail-sony-dsc-p150-inverted-colors.jpg",
    )
  // Extract the original JPEG APP1 payload, including the thumbnail, independently.
  let assert <<0xFF, 0xD8, 0xFF, 0xE1, size:16-big, rest:bytes>> = source
  let assert <<"Exif":utf8, 0, 0, exif:bytes-size(size - 8), _rest:bytes>> =
    rest
  let xmp = <<
    "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><fixture>imagex-webp</fixture></x:xmpmeta>":utf8,
  >>

  list.each(["lossy-exif.webp", "lossy-alpha-exif-xmp.webp"], fn(filename) {
    let assert Ok(bytes) = read_bits("test/assets/webp/" <> filename)
    let assert Ok(#(image, metadata)) = decode_raster_with_metadata(bytes)
    metadata.exif |> should.equal(Some(exif))
    let expected_xmp = case filename {
      "lossy-exif.webp" -> None
      _ -> Some(xmp)
    }
    metadata.xmp |> should.equal(expected_xmp)
    let options =
      WebpEncodeOptions(
        ..default_webp_encode_options(),
        lossless: True,
        exif: metadata.exif,
        xmp: metadata.xmp,
      )
    let assert Ok(encoded) = encode_webp(image, options)
    let assert Ok(#(decoded, decoded_metadata)) =
      decode_raster_with_metadata(encoded)
    decoded |> should.equal(image)
    decoded_metadata |> should.equal(metadata)
  })
}

pub fn independent_xmp_only_test() {
  let assert Ok(bytes) = read_bits("test/assets/webp/lossless-xmp.webp")
  let assert Ok(#(image, metadata)) = decode_raster_with_metadata(bytes)
  metadata.exif |> should.equal(None)
  let assert Some(xmp) = metadata.xmp
  let options =
    WebpEncodeOptions(
      ..default_webp_encode_options(),
      lossless: True,
      xmp: Some(xmp),
    )
  let assert Ok(encoded) = encode_webp(image, options)
  decode_raster_with_metadata(encoded) |> should.equal(Ok(#(image, metadata)))
}

pub fn nonuniform_lossless_roundtrip_test() {
  list.each(
    ["lossless_color_transform.webp", "lossless1.webp", "lossy_alpha1.webp"],
    fn(filename) {
      let assert Ok(image) = read_raster("test/assets/webp/" <> filename)
      let options =
        WebpEncodeOptions(..default_webp_encode_options(), lossless: True)
      let assert Ok(bytes) = encode_webp(image, options)
      decode_raster(bytes) |> should.equal(Ok(image))
    },
  )
}

pub fn lossless_transparent_colors_test() {
  let image = RasterImage(<<20, 80, 140, 0, 70, 90, 110, 128>>, 2, 1, 4, 8)
  let options =
    WebpEncodeOptions(..default_webp_encode_options(), lossless: True)
  let assert Ok(bytes) = encode_webp(image, options)
  decode_raster(bytes) |> should.equal(Ok(image))
}

pub fn grayscale_expansion_test() {
  let options =
    WebpEncodeOptions(..default_webp_encode_options(), lossless: True)
  list.each(
    [
      #(
        RasterImage(<<70, 90>>, 2, 1, 1, 8),
        RasterImage(<<70, 70, 70, 90, 90, 90>>, 2, 1, 3, 8),
      ),
      #(
        RasterImage(<<70, 128, 90, 0>>, 2, 1, 2, 8),
        RasterImage(<<70, 70, 70, 128, 90, 90, 90, 0>>, 2, 1, 4, 8),
      ),
    ],
    fn(pair) {
      let #(source, expected) = pair
      let assert Ok(bytes) = encode_webp(source, options)
      decode_raster(bytes) |> should.equal(Ok(expected))
    },
  )
}

pub fn lossy_default_encode_test() {
  let image =
    RasterImage(
      bit_array.concat(list.repeat(<<20, 80, 140>>, 256)),
      16,
      16,
      3,
      8,
    )
  let assert Ok(bytes) = encode(image, Webp)
  let assert Ok(RasterImage(pixels, 16, 16, 3, 8)) = decode_raster(bytes)
  list.each(
    list.zip(bytes_to_list(image.pixels), bytes_to_list(pixels)),
    fn(pair) {
      let #(expected, actual) = pair
      { actual - expected < 10 && expected - actual < 10 } |> should.be_true()
    },
  )
}

fn bytes_to_list(bytes: BitArray) -> List(Int) {
  case bytes {
    <<value, rest:bytes>> -> [value, ..bytes_to_list(rest)]
    _ -> []
  }
}

pub fn odd_metadata_padding_test() {
  let options =
    WebpEncodeOptions(
      ..default_webp_encode_options(),
      lossless: True,
      xmp: Some(<<"odd":utf8>>),
    )
  let image = RasterImage(<<10, 20, 30, 128>>, 1, 1, 4, 8)
  let assert Ok(bytes) = encode_webp(image, options)
  let assert Ok(#(decoded, metadata)) = decode_raster_with_metadata(bytes)
  decoded |> should.equal(image)
  metadata.xmp |> should.equal(options.xmp)
}

pub fn trailing_bytes_test() {
  let assert Ok(bytes) = read_bits("test/assets/webp/lossy-alpha-exif-xmp.webp")
  decode_raster_with_metadata(<<bytes:bits, "trailing bytes":utf8>>)
  |> should.equal(decode_raster_with_metadata(bytes))
}

pub fn truncated_file_test() {
  let assert Ok(bytes) = read_bits("test/assets/webp/lossy-alpha-exif-xmp.webp")
  let assert Ok(truncated) =
    bit_array.slice(bytes, 0, bit_array.byte_size(bytes) - 1)
  let assert Error(_) = decode_raster_with_metadata(truncated)
}

pub fn rejects_animation_test() {
  let assert Ok(bytes) = read_bits("test/assets/animated.webp")
  decode(bytes)
  |> should.equal(Error(NativeError("animated WebP is not supported")))
}

pub fn rejects_invalid_input_test() {
  let image = RasterImage(<<1, 2, 3>>, 1, 1, 3, 8)
  let defaults = default_webp_encode_options()
  encode_webp(image, WebpEncodeOptions(..defaults, quality: 101.0))
  |> should.equal(
    Error(InvalidOptions("WebP quality must be between 0 and 100")),
  )
  encode_webp(image, WebpEncodeOptions(..defaults, effort: 7))
  |> should.equal(Error(InvalidOptions("WebP effort must be between 0 and 6")))
  let assert Error(InvalidImage(_)) =
    encode_webp(RasterImage(..image, bit_depth: 16), defaults)
  let assert Error(InvalidImage(_)) =
    encode_webp(RasterImage(..image, pixels: <<1>>), defaults)
}
