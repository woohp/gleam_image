import gleam/option.{type Option, None, Some}

pub type Format {
  JPEG
  PNG
  JXL
  BMP
  PPM
  TIFF
  PDF
}

pub fn detect(bytes: BitArray) -> Option(Format) {
  case bytes {
    <<0xFFD8:size(16), _rest:bits>> -> Some(JPEG)

    <<0x89, "PNG\r\n":utf8, 0x1A, 0x0A, _rest:bytes>> -> Some(PNG)

    <<0xFF, 0x0A, _rest:bytes>> -> Some(JXL)

    <<0x00, 0x00, 0x00, 0x0C, "JXL ":utf8, 0x0D, 0x0A, 0x87, 0x0A, _rest:bytes>> ->
      Some(JXL)

    <<"BM":utf8, _rest:bytes>> -> Some(BMP)

    <<"P":utf8, n:size(8), "\n":utf8, _rest:bytes>> if n == 53 || n == 54 ->
      Some(PPM)

    <<"II":utf8, 0x2A00:size(16), _rest:bytes>> -> Some(TIFF)

    <<"MM":utf8, 0x002A:size(16), _rest:bytes>> -> Some(TIFF)

    <<"%PDF-1.":utf8, n:size(8), "\n%":utf8, _rest:bytes>>
      if n >= 48 && n <= 57
    -> Some(PDF)

    _ -> None
  }
}
