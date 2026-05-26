# Agent Notes

## Commands
- Install deps with `gleam deps download`.
- Build the native backend before running image/PDF/TIFF tests: `make priv/imagex_c.so`.
- Run tests with `gleam test`; gleeunit discovers public functions ending in `_test` from `test/vars_test.gleam` and there is no repo-specific single-test shortcut.
- Check formatting with `gleam format --check src test`; format Gleam and native C++ with `make fmt`.

## Native Backend
- `src/vars.gleam` is the public API and calls Erlang externals in `src/imagex_c.erl`; that Erlang module loads `priv/imagex_c` on startup.
- `native/src/imagex.cpp` implements the NIFs and links against libjpeg, libpng, libjxl, poppler-cpp, and libtiff; the Makefile also requires `expp.hpp` at `deps/expp` or `../expp`, or `EXPP_INCLUDE_DIR` must point at it.
- If tests fail with `nif_library_not_loaded`, rebuild `priv/imagex_c.so` before changing Gleam code.

## API Shape
- Decode/open return `vars.Decoded`: `Raster(RasterImage(...))` for JPEG/PNG/JXL/BMP/PPM and `Document(PdfDocument(...))` or `Document(TiffDocument(...))` for PDF/TIFF.
- Use `open_raster`/`read_raster` when callers require a `RasterImage`; they reject PDF/TIFF documents.
- `vars.encode` accepts only `RasterImage` plus `detect.RasterFormat`; PDF/TIFF are render-only through `render_pdf_page` and `render_tiff_page`.
- Metadata is parsed internally in the native result tuple but is not exposed by the public Gleam API.

## Style And Generated Files
- Do not edit `manifest.toml` by hand; Gleam generates it.
- Keep C++ formatted with the repo `.clang-format` via `make fmt`, not ad hoc clang-format defaults.
