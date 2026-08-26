import gleam/erlang.{type Reference}

/// A decoded raster image, produced by the pure-Gleam decoders.
pub type Image {
  Image(
    pixels: BitArray,
    width: Int,
    height: Int,
    channels: Int,
    bit_depth: Int,
  )
}

// The constructor names below must match the atoms produced by the NIF
// (`p_d_f_image` and `t_i_f_f_image`).

/// A native PDF document handle.
pub type PdfHandle {
  PDFImage(ref: Reference, num_pages: Int)
}

/// A native TIFF document handle.
pub type TiffHandle {
  TIFFImage(ref: Reference, num_pages: Int)
}
