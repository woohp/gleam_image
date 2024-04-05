import gleeunit
import gleeunit/should
import simplifile.{read_bits}
import vars
import image.{Image}
import gleam/io

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn ppm_test() {
  let assert Ok(data) = read_bits("test/assets/lena.ppm")
  let assert Ok(image) = vars.decode(data)
  let assert Image(_pixels, 512, 512, 3, 8) = image
}
