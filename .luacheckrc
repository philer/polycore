-- luacheck: globals std stds

-- custom globals defined by polycore
stds.polycore = {
    globals = {
        "DEBUG",
        "conky_setup",
        "conky_update",
    }
}

-- globals defined by conky/cairo
stds.conky = {
    read_globals = {
        "CAIRO_ANTIALIAS_DEFAULT",
        "CAIRO_ANTIALIAS_NONE",
        "cairo_arc",
        "cairo_close_path",
        "cairo_create",
        "cairo_curve_to",
        "cairo_destroy",
        "cairo_fill",
        "cairo_fill_preserve",
        "cairo_font_extents",
        "cairo_font_extents_t",
        "CAIRO_FONT_SLANT_ITALIC",
        "CAIRO_FONT_SLANT_NORMAL",
        "CAIRO_FONT_SLANT_OBLIQUE",
        "cairo_font_slant_t",
        "CAIRO_FONT_WEIGHT_BOLD",
        "CAIRO_FONT_WEIGHT_NORMAL",
        "cairo_font_weight_t",
        "CAIRO_FORMAT_ARGB32",
        "cairo_image_surface_create",
        "CAIRO_LINE_CAP_SQUARE",
        "cairo_line_to",
        "cairo_matrix_init_translate",
        "cairo_matrix_t",
        "cairo_move_to",
        "cairo_new_path",
        "CAIRO_OPERATOR_SOURCE",
        "cairo_paint",
        "cairo_pattern_add_color_stop_rgba",
        "cairo_pattern_create_linear",
        "cairo_pattern_create_radial",
        "cairo_pattern_destroy",
        "cairo_rectangle",
        "cairo_rel_line_to",
        "cairo_restore",
        "cairo_save",
        "cairo_select_font_face",
        "cairo_set_antialias",
        "cairo_set_font_size",
        "cairo_set_line_cap",
        "cairo_set_line_width",
        "cairo_set_matrix",
        "cairo_set_operator",
        "cairo_set_source",
        "cairo_set_source_rgba",
        "cairo_set_source_surface",
        "cairo_show_text",
        "cairo_stroke",
        "cairo_stroke_preserve",
        "cairo_surface_destroy",
        "cairo_surface_write_to_png",
        "cairo_t",
        "cairo_text_extents",
        "cairo_text_extents_t",
        "cairo_xlib_surface_create",
        "conky",  -- only in rc file
        "conky_parse",
        "conky_version",
        "conky_window",
        "tolua",
    },
}

std = "min+polycore+conky"
