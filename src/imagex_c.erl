-module(imagex_c).
-export([jpeg_decompress/1, jpeg_compress/5, png_decompress/1, png_compress/5,
         jxl_decompress/1, jxl_read_exif/1, jxl_compress/8, jxl_transcode_from_jpeg/3,
         jxl_transcode_to_jpeg/1, pdf_load_document/1, pdf_render_page/3,
         tiff_load_document/1, tiff_render_page/2]).
-nifs([jpeg_decompress/1, jpeg_compress/5, png_decompress/1, png_compress/5,
         jxl_decompress/1, jxl_read_exif/1, jxl_compress/8, jxl_transcode_from_jpeg/3,
         jxl_transcode_to_jpeg/1, pdf_load_document/1, pdf_render_page/3,
         tiff_load_document/1, tiff_render_page/2]).
-on_load(init/0).

init() ->
    ok = erlang:load_nif("priv/imagex_c", 0).

jpeg_decompress(_bytes) ->
    exit(nif_library_not_loaded).

jpeg_compress(_pixels, _width, _height, _channels, _quality) ->
    exit(nif_library_not_loaded).

png_decompress(_bytes) ->
    exit(nif_library_not_loaded).

png_compress(_pixels, _width, _height, _channels, _bit_depth) ->
    exit(nif_library_not_loaded).

jxl_decompress(_bytes) ->
    exit(nif_library_not_loaded).

jxl_read_exif(_bytes) ->
    exit(nif_library_not_loaded).

jxl_compress(_pixels, _width, _height, _channels, _bit_depth, _distance, _lossless, _effort) ->
    exit(nif_library_not_loaded).

jxl_transcode_from_jpeg(_jpeg_bytes, _effort, _store_jpeg_metadata) ->
    exit(nif_library_not_loaded).

jxl_transcode_to_jpeg(_jxl_bytes) ->
    exit(nif_library_not_loaded).

pdf_load_document(_bytes) ->
    exit(nif_library_not_loaded).

pdf_render_page(_document, _page_idx, _dpi) ->
    exit(nif_library_not_loaded).

tiff_load_document(_bytes) ->
    exit(nif_library_not_loaded).

tiff_render_page(_document, _page_idx) ->
    exit(nif_library_not_loaded).
