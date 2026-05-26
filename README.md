# vars

Load and save images from Gleam, using libjpeg, libpng, libjxl, libtiff, and poppler as native backends.
Formats supported include: JPEG, PNG, BMP, JPEG XL, PPM, TIFF, and PDF.

Where possible, yielding NIFs are used so the native work plays nicely with the BEAM scheduler.

## Install

Please ensure that libjpeg, libpng, libjxl, libtiff, and libpoppler are installed.

```sh
gleam add vars
```

This package targets Erlang and requires Gleam 1.16 or newer.

## Usage

To load a raster image file:

```gleam
import vars.{RasterImage, read_raster}

pub fn main() {
  let assert Ok(RasterImage(pixels, width, height, channels, bit_depth)) =
    read_raster("lena.jpg")
}
```

Or load from memory:

```gleam
import simplifile
import vars.{Raster, RasterImage, decode}

pub fn main() {
  let assert Ok(bytes) = simplifile.read_bits("lena.jpg")
  let assert Ok(Raster(RasterImage(_, _, _, _, _))) = decode(bytes)
}
```

Detect a format without decoding:

```gleam
import vars.{Jpeg, RasterFormat, detect}

pub fn is_jpeg(bytes) {
  detect(bytes) == Some(RasterFormat(Jpeg))
}
```

Save to memory in a specific raster format using default options:

```gleam
import vars.{Bmp, Jpeg, Jxl, Png, Ppm, encode}

pub fn encode_examples(image) {
  let assert Ok(jpeg_bytes) = encode(image, Jpeg)
  let assert Ok(png_bytes) = encode(image, Png)
  let assert Ok(jxl_bytes) = encode(image, Jxl)
  let assert Ok(bmp_bytes) = encode(image, Bmp)
  let assert Ok(ppm_bytes) = encode(image, Ppm)
}
```

For encoder-specific options use `encode_jpeg`, `encode_png`, or `encode_jxl` with their `default_*_encode_options` helpers. PNG text chunks use `String` fields, and JPEG XL boxes use the named `JxlBox(name, contents)` type rather than raw tuples.

`vars.decode` returns typed data:

```gleam
pub type Decoded {
  Raster(RasterImage)
  Pdf(PdfDocument)
  Tiff(TiffDocument)
}
```

Errors are typed with `vars.Error` rather than returned as strings.

`RasterImage` is currently public data so callers can pattern match and construct pixel buffers directly. The API also includes `raster_image`, `pixels`, `width`, `height`, `channels`, and `bit_depth` helpers so callers can use an accessor style that will be easier to preserve if a future major API grows toward a richer tensor/metadata representation. For now metadata is intentionally not part of this type.

## Documents

PDF and TIFF files decode to opaque document handles. Page indices are zero-based. Valid page indices are `0 <= page_index < pdf_pages(pdf)` or `0 <= page_index < tiff_pages(tiff)`.

PDF pages render at the requested DPI. Rendered pages currently return raster pixels with the backend-provided channel count, normally 4 channels at 8-bit depth for the tested PDF/TIFF paths.

```gleam
import vars.{Pdf, RasterImage, pdf_pages, read, render_pdf_page}

pub fn render_pdf() {
  let assert Ok(Pdf(pdf)) = read("lena.pdf")
  let pages = pdf_pages(pdf)
  let assert Ok(RasterImage(_, _, _, _, _)) = render_pdf_page(pdf, 0, 144)
}
```

```gleam
import vars.{RasterImage, Tiff, read, render_tiff_page, tiff_pages}

pub fn render_tiff() {
  let assert Ok(Tiff(tiff)) = read("lena.tiff")
  let pages = tiff_pages(tiff)
  let assert Ok(RasterImage(_, _, _, _, _)) = render_tiff_page(tiff, 0)
}
```

## JPEG XL transcoding

JPEG XL lossless JPEG transcoding is exposed directly:

```gleam
import vars.{
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

The native backend is based on Imagex's current native implementation, including support for JPEG EXIF/XMP, PNG text chunks, and JXL boxes internally.

The current Gleam API does **not yet expose decoded metadata** on `vars.RasterImage`. Encode APIs expose a small set of metadata-related options where already supported by the backend. A fuller metadata model will require a Gleam metadata type/API and tests before it is considered public.

## Development

```sh
make priv/imagex_c.so
gleam test
```
