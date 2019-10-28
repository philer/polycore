local util = require 'util'

local cairo_helpers = {}

function cairo_helpers.polygon(cr, coordinates)
    -- +.5 for sharp lines, see https://cairographics.org/FAQ/#sharp_lines
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT)
    cairo_move_to(cr, math.floor(coordinates[1]) + .5,
                      math.floor(coordinates[2]) + .5)
    for i = 3, #coordinates, 2 do
        cairo_line_to(cr, math.floor(coordinates[i]) + .5,
                          math.floor(coordinates[i + 1]) + .5)
    end
    cairo_close_path(cr)
end

function cairo_helpers.alpha_gradient(cr, x1, y1, x2, y2, r, g, b, stops)
    local gradient = cairo_pattern_create_linear(x1, y1, x2, y2)
    for _, stop in ipairs(stops) do
        local rw, gw, bw = r, g, b
        -- additional brightness (white) for peaks
        if stop[2] > 0.5 then
            rw, gw, bw = r * 1.3, g * 1.3, b * 1.3
        end
        cairo_pattern_add_color_stop_rgba(gradient,
            stop[1], rw, gw, bw, stop[2])
    end
    cairo_set_source(cr, gradient)
    cairo_pattern_destroy(gradient)
end


function cairo_helpers.font_normal(cr)
    cairo_select_font_face(cr, default_font_family, CAIRO_FONT_SLANT_NORMAL,
                                                    CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, default_font_size)
end

cairo_helpers.font_extents = util.memoize(function(font_family, font_size)
    local tmp_surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 100, 100)
    local tmp_cr = cairo_create(tmp_surface)
    cairo_surface_destroy(tmp_surface)
    cairo_select_font_face(tmp_cr, font_family, CAIRO_FONT_SLANT_NORMAL,
                                                CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(tmp_cr, font_size)
    local extents = cairo_font_extents_t:create()
    tolua.takeownership(extents)
    cairo_font_extents(tmp_cr, extents)
    cairo_destroy(tmp_cr)
    return extents
end)

local function text_extents(cr, text)
    local extents = cairo_text_extents_t:create()
    tolua.takeownership(extents)
    cairo_text_extents(cr, text, extents)
    return extents
end

function cairo_helpers.write_left(cr, x, y, text)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

function cairo_helpers.write_right(cr, x, y, text)
    cairo_move_to(cr, x - text_extents(cr, text).width, y)
    cairo_show_text(cr, text)
end

function cairo_helpers.write_centered(cr, mx, y, text)
    local extents = text_extents(cr, text)
    local x = mx - (extents.width / 2 + extents.x_bearing)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

function cairo_helpers.write_middle(cr, mx, my, text)
    local extents = text_extents(cr, text)
    local x = mx - (extents.width / 2 + extents.x_bearing)
    local y = my - (extents.height / 2 + extents.y_bearing)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

return cairo_helpers
