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

To load an image file:

```gleam
import vars
import image.{Image}

pub fn main() {
  let assert Ok(Image(pixels, width, height, channels, bit_depth)) =
    vars.open("lena.jpg")
}
```

Or load from memory:

```gleam
import simplifile
import vars

pub fn main() {
  let assert Ok(bytes) = simplifile.read_bits("lena.jpg")
  let assert Ok(image) = vars.decode(bytes)
}
```

Save to memory in a specific format:

```gleam
import detect.{JPEG, PNG, JXL, BMP, PPM}
import vars

pub fn encode_examples(image) {
  let assert Ok(jpeg_bytes) = vars.encode(image, JPEG)
  let assert Ok(png_bytes) = vars.encode(image, PNG)
  let assert Ok(jxl_bytes) = vars.encode(image, JXL)
  let assert Ok(bmp_bytes) = vars.encode(image, BMP)
  let assert Ok(ppm_bytes) = vars.encode(image, PPM)
}
```

## Documents

PDF and TIFF files decode to document handles. Render individual pages to raster images:

```gleam
import image.{PDFImage}
import vars

pub fn render_pdf() {
  let assert Ok(PDFImage(_, num_pages) as pdf) = vars.open("lena.pdf")
  let assert Ok(page) = vars.render_pdf_page(pdf, 0, 144)
}
```

```gleam
import image.{TIFFImage}
import vars

pub fn render_tiff() {
  let assert Ok(TIFFImage(_, num_pages) as tiff) = vars.open("lena.tiff")
  let assert Ok(page) = vars.render_tiff_page(tiff, 0)
}
```

## JPEG XL transcoding

JPEG XL lossless JPEG transcoding is exposed directly:

```gleam
import vars

pub fn transcode(jpeg_bytes) {
  let assert Ok(jxl_bytes) = vars.jxl_transcode_from_jpeg(jpeg_bytes, 7, True)
  let assert Ok(roundtripped_jpeg) = vars.jxl_transcode_to_jpeg(jxl_bytes)
}
```

## Metadata

The native backend is based on Imagex's current native implementation, including support for JPEG EXIF/XMP, PNG text chunks, and JXL boxes internally.

The current Gleam API does **not yet expose metadata** on `image.ImageType`, nor metadata options for `vars.encode`. Decode returns raster pixels and image dimensions only. Metadata support will require a Gleam metadata type/API and tests before it is considered public.

## Development

```sh
make priv/imagex_c.so
gleam test
```
