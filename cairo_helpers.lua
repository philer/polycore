local util = require 'util'

local cairo_helpers = {}

-- Draw a polygon with the given vertices.
function cairo_helpers.polygon(cr, coordinates)
    -- +.5 for sharp lines, see https://cairographics.org/FAQ/#sharp_lines
    local floor = math.floor
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT)
    cairo_move_to(cr, floor(coordinates[1]) + .5, floor(coordinates[2]) + .5)
    for i = 3, #coordinates, 2 do
        cairo_line_to(cr, floor(coordinates[i]) + .5,
                          floor(coordinates[i + 1]) + .5)
    end
    cairo_close_path(cr)
end

-- Set a gradient on the given cairo drawing context.
-- Arguments:
--   cr: cairo drawing context
--   x1, y1, x2, y2: Coordinates "from - to" for gradient position
--   r, g, b: base color
--   stops: array of (offset, alpha) value pairs.
--          offset between 0 and 1 describes position in the gradient
--          alpha between 0 and 1 describes opacity at given offset
--          Note: For high/low alpha values the brightness may be emphasized
--          by color variation
function cairo_helpers.alpha_gradient(cr, x1, y1, x2, y2, r, g, b, stops)
    local gradient = cairo_pattern_create_linear(x1, y1, x2, y2)
    for i = 1, #stops, 2 do
        local offset, alpha = stops[i], stops[i + 1]
        if alpha > 0.5 then
            -- additional brightness (white) for peaks
            cairo_pattern_add_color_stop_rgba(gradient, offset, r * 1.3, g * 1.3, b * 1.3, alpha)
        else
            cairo_pattern_add_color_stop_rgba(gradient, offset, r, g, b, alpha)
        end

    end
    cairo_set_source(cr, gradient)
    cairo_pattern_destroy(gradient)
end

-- Reset font settings to defaults on given cairo drawing context
function cairo_helpers.font_normal(cr)
    cairo_select_font_face(cr, default_font_family, CAIRO_FONT_SLANT_NORMAL,
                                                    CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, default_font_size)
end

-- Get cairo_font_extents_t for a given font with size.
-- Use this, for example, to determine line-height.
-- See https://cairographics.org/manual/cairo-cairo-scaled-font-t.html#cairo-font-extents-t
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

-- Get cairo_text_extents_t for given text on given cairo drawing surface
-- with its currently set font.
-- See https://cairographics.org/manual/cairo-cairo-scaled-font-t.html#cairo-text-extents-t
local function text_extents(cr, text)
    local extents = cairo_text_extents_t:create()
    tolua.takeownership(extents)
    cairo_text_extents(cr, text, extents)
    return extents
end

-- Write text left-aligned (to the right of given x).
-- y is the coordinate of the baseline on top of which the text will be written.
function cairo_helpers.write_left(cr, x, y, text)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

-- Write text right-aligned (to the left of given x).
-- y is the coordinate of the baseline on top of which the text will be written.
function cairo_helpers.write_right(cr, x, y, text)
    cairo_move_to(cr, x - text_extents(cr, text).width, y)
    cairo_show_text(cr, text)
end

-- Write text centered (spread evenly towards both sides of mx).
-- y is the coordinate of the baseline on top of which the text will be written.
function cairo_helpers.write_centered(cr, mx, y, text)
    local extents = text_extents(cr, text)
    local x = mx - (extents.width / 2 + extents.x_bearing)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

-- Write text centered horizontally and vertically on the given point mx, my.
function cairo_helpers.write_middle(cr, mx, my, text)
    local extents = text_extents(cr, text)
    local x = mx - (extents.width / 2 + extents.x_bearing)
    local y = my - (extents.height / 2 + extents.y_bearing)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

return cairo_helpers
