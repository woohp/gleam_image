import gleam/erlang.{type Reference}

pub type ImageType {
  Image(
    pixels: BitArray,
    width: Int,
    height: Int,
    channels: Int,
    bit_depth: Int,
  )
  PDFImage(ref: Reference, num_pages: Int)
  TIFFImage(ref: Reference, num_pages: Int)
}
