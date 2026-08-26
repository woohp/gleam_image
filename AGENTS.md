# AGENTS.md

## Project Shape
- This is a Gleam package targeting Erlang only; `gleam.toml` requires Gleam `>= 1.16.0`.
- Public API lives in `src/gleam_image.gleam`; BMP/PPM decoders are pure Gleam internals under `src/gleam_image/internal/`; format detection lives in the public module.
- Native image/PDF/TIFF work is routed through `src/imagex_c.erl`, which loads `priv/imagex_c.so`; the C++ NIF implementation is all in `native/src/imagex.cpp`.
- PDF and TIFF documents are opaque native resource handles; page indices are zero-based.

## Native Build Requirements
- Before tests that touch JPEG/PNG/JXL/PDF/TIFF, build the NIF with `make priv/imagex_c.so`.
- The native build links against libjpeg, libpng, libjxl, libtiff, and poppler-cpp.
- `Makefile` needs `expp.hpp` at `deps/expp/expp.hpp` or `../expp/expp.hpp`; otherwise set `EXPP_INCLUDE_DIR` to the directory containing it.
- Erlang headers are discovered from `ERL_EI_INCLUDE_DIR` or `erl`; set `ERTS_INCLUDE_DIR` only if that discovery is wrong.

## Commands
- Setup deps: `gleam deps download`.
- Build native backend: `make priv/imagex_c.so`.
- Run the test suite: `gleam test`.
- Check Gleam formatting like CI: `gleam format --check src test`.
- Format both native C++ and Gleam: `make fmt`.

## Testing Notes
- Gleeunit only runs test functions whose names end in `_test`; new tests must use that suffix.
- `gleam test` has no repo-provided single-test shortcut; it runs `gleam_image_test.main`, which discovers all `test/**/*.{gleam,erl}` modules.
- Test assets are committed under `test/assets/`; tests assume paths are run from the repository root.

## Formatting And Style
- Gleam/Erlang files use 2-space indentation from `.editorconfig`; Makefile recipes must use tabs.
- Native C++ follows `.clang-format`; `make fmt` is the shortest safe formatter.

## CI Gotcha
- `.github/workflows/test.yml` currently runs `gleam deps download`, `gleam test`, then `gleam format --check src test`, but its `gleam-version: "1.0.0"` conflicts with `gleam.toml` and README requiring `>= 1.16.0`; update the workflow if touching CI.
