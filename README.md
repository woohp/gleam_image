# gleam_image

Load and save images from Gleam, using libjpeg, libpng, libjxl, libtiff, and poppler as native backends.
Formats supported include JPEG, PNG, BMP, JPEG XL, PPM, TIFF, and PDF.

Where possible, yielding NIFs are used so the native work plays nicely with the BEAM scheduler.

## Install

Please ensure that libjpeg, libpng, libjxl, libtiff, and libpoppler are installed.

```sh
gleam add gleam_image
```

This package targets Erlang and requires Gleam 1.16 or newer.

## Usage

To load a raster image file:

```gleam
import gleam_image.{RasterImage, read_raster}

pub fn main() {
  let assert Ok(RasterImage(pixels, width, height, channels, bit_depth)) =
    read_raster("lena.jpg")
}
```

Or load from memory:

```gleam
import simplifile
import gleam_image.{Raster, RasterImage, decode}

pub fn main() {
  let assert Ok(bytes) = simplifile.read_bits("lena.jpg")
  let assert Ok(Raster(RasterImage(_, _, _, _, _))) = decode(bytes)
}
```

`decode` detects the format from the input bytes. Explicit-format decoding is not currently exposed.

Detect a format without decoding:

```gleam
import gleam/option.{Some}
import gleam_image.{Jpeg, RasterFormat, detect}

pub fn is_jpeg(bytes) {
  detect(bytes) == Some(RasterFormat(Jpeg))
}
```

Save to memory in a specific raster format using default options:

```gleam
import gleam_image.{Bmp, Jpeg, Jxl, Png, Ppm, encode}

pub fn encode_examples(image) {
  let assert Ok(jpeg_bytes) = encode(image, Jpeg)
  let assert Ok(png_bytes) = encode(image, Png)
  let assert Ok(jxl_bytes) = encode(image, Jxl)
  let assert Ok(bmp_bytes) = encode(image, Bmp)
  let assert Ok(ppm_bytes) = encode(image, Ppm)
}
```

To write encoded bytes to a file, use `simplifile`:

```gleam
import simplifile
import gleam_image.{Png, encode}

pub fn save_png(image) {
  let assert Ok(bytes) = encode(image, Png)
  simplifile.write_bits(bytes, to: "out.png")
}
```

## Raster images

`RasterImage` stores raw pixel data and basic shape information:

```gleam
pub type RasterImage {
  RasterImage(
    pixels: BitArray,
    width: Int,
    height: Int,
    channels: Int,
    bit_depth: Int,
  )
}
```

Pixels are interleaved, row-major, and tightly packed with no stride or row padding. For example, an 8-bit RGB image is laid out as `RGBRGBRGB...` from the top-left pixel across each row.

Typical channel counts are 1, 2, 3, or 4. Typical bit depths are 8 or 16, depending on the source format and encoder support.

`RasterImage` is public data, so callers pattern match and construct pixel buffers directly.

## Decode results

`gleam_image.decode` and `gleam_image.read` return typed data:

```gleam
pub type Decoded {
  Raster(RasterImage)
  Pdf(PdfDocument)
  Tiff(TiffDocument)
}
```

Use `decode_raster` or `read_raster` when callers require a raster image. They return `Error(InvalidImage("Expected a raster image"))` for PDF and TIFF documents.

## Encoding options

For encoder-specific options use `encode_jpeg`, `encode_png`, or `encode_jxl` with their `default_*_encode_options` helpers.

### JPEG

```gleam
import gleam/option.{None}
import gleam_image.{JpegEncodeOptions, default_jpeg_encode_options, encode_jpeg}

pub fn encode_high_quality_jpeg(image) {
  let defaults = default_jpeg_encode_options()
  let options = JpegEncodeOptions(..defaults, quality: 90)

  encode_jpeg(image, options)
}
```

JPEG options:

```gleam
pub type JpegEncodeOptions {
  JpegEncodeOptions(
    quality: Int,
    exif: Option(BitArray),
    xmp: Option(BitArray),
  )
}
```

`quality` must be between 1 and 100. Invalid values return `InvalidOptions`.

### PNG

PNG text chunks use `String` fields:

```gleam
import gleam_image.{
  PngEncodeOptions, PngTextChunk, default_png_encode_options, encode_png,
}

pub fn encode_png_with_text(image) {
  let defaults = default_png_encode_options()
  let options =
    PngEncodeOptions(
      ..defaults,
      text_chunks: [
        PngTextChunk(
          keyword: "Author",
          text: "gleam_image",
          language_tag: "",
          translated_keyword: "",
        ),
      ],
    )

  encode_png(image, options)
}
```

### JPEG XL

```gleam
import gleam/option.{Some}
import gleam_image.{JxlEncodeOptions, default_jxl_encode_options, encode_jxl}

pub fn encode_lossless_jxl(image, exif) {
  let defaults = default_jxl_encode_options()
  let options =
    JxlEncodeOptions(
      ..defaults,
      exif: Some(exif),
      lossless: True,
      effort: 9,
    )

  encode_jxl(image, options)
}
```

JXL boxes use the named `JxlBox(name, contents)` type rather than raw tuples.

## Documents

PDF and TIFF files decode to opaque document handles. Page indices are zero-based. Valid page indices are `0 <= page_index < pdf_pages(pdf)` or `0 <= page_index < tiff_pages(tiff)`.

PDF pages render at the requested DPI. TIFF pages render at their stored resolution. Rendered pages currently return raster pixels with the backend-provided channel count, normally 4 channels at 8-bit depth for the tested PDF/TIFF paths.

```gleam
import gleam/list
import gleam_image.{Pdf, RasterImage, pdf_pages, read, render_pdf_page}

pub fn render_pdf() {
  let assert Ok(Pdf(pdf)) = read("lena.pdf")

  list.range(0, pdf_pages(pdf) - 1)
  |> list.each(fn(page_index) {
    let assert Ok(RasterImage(_, _, _, _, _)) =
      render_pdf_page(pdf, page_index, 144)
  })
}
```

```gleam
import gleam/list
import gleam_image.{RasterImage, Tiff, read, render_tiff_page, tiff_pages}

pub fn render_tiff() {
  let assert Ok(Tiff(tiff)) = read("lena.tiff")

  list.range(0, tiff_pages(tiff) - 1)
  |> list.each(fn(page_index) {
    let assert Ok(RasterImage(_, _, _, _, _)) = render_tiff_page(tiff, page_index)
  })
}
```

## JPEG XL transcoding

JPEG XL lossless JPEG transcoding is exposed directly:

```gleam
import gleam_image.{
  default_jxl_transcode_options, jxl_transcode_from_jpeg,
  jxl_transcode_to_jpeg,
}

pub fn transcode(jpeg_bytes) {
  let options = default_jxl_transcode_options()
  let assert Ok(jxl_bytes) = jxl_transcode_from_jpeg(jpeg_bytes, options)
  let assert Ok(roundtripped_jpeg) = jxl_transcode_to_jpeg(jxl_bytes)
}
```

## Metadata

Encode options accept metadata where the backend supports writing it:

- JPEG: EXIF and XMP via `JpegEncodeOptions`
- PNG: text chunks via `PngEncodeOptions`
- JPEG XL: EXIF and container boxes via `JxlEncodeOptions`

Use `decode_raster_with_metadata` to read metadata back when decoding:

```gleam
import gleam_image.{decode_raster_with_metadata}

pub fn read_exif(bytes) {
  let assert Ok(#(_image, metadata)) = decode_raster_with_metadata(bytes)
  metadata.exif
}
```

```gleam
pub type RasterMetadata {
  RasterMetadata(
    exif: Option(BitArray),
    text_chunks: List(PngTextChunk),
    xml_boxes: List(BitArray),
    jumb_boxes: List(BitArray),
  )
}
```

Which fields are populated depends on the source format:

- PNG fills `exif` and `text_chunks`.
- JPEG XL fills `exif`, `xml_boxes`, and `jumb_boxes`.
- JPEG, BMP, and PPM currently yield empty metadata (the native backend does not read JPEG EXIF yet).

## Errors

Errors are typed with `gleam_image.Error` rather than returned as strings:

```gleam
pub type Error {
  UnknownFormat
  InvalidImage(String)
  InvalidOptions(String)
  FileError(FileError)
  NativeError(String)
}
```

`UnknownFormat` means the input bytes did not match any supported signature. `InvalidImage` is used when decoded data has the wrong shape for the requested operation. `InvalidOptions` is used for invalid user-supplied encode options. `FileError` wraps errors from `simplifile`. `NativeError` wraps errors returned by the native backend.

## Development

Install dependencies:

```sh
gleam deps download
```

Build the native backend before running image, PDF, or TIFF tests:

```sh
make priv/imagex_c.so
```

Run tests:

```sh
gleam test
```

Check formatting:

```sh
gleam format --check src test
make fmt
```
