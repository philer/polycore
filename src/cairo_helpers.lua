--- Cairo helper functions
-- @module cairo_helpers
-- @alias ch

pcall(function() require('cairo') end)

local util = require('src/util')

local ch = {}

--- Draw a polygon with the given vertices.
-- @tparam cairo_t cr
-- @tparam {number,...} coordinates of vertices (x1, y1, x2, y2, ...)
function ch.polygon(cr, coordinates)
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

--- Draw a little cross where a given point is. Useful for debugging.
-- By default the cross is red.
-- @tparam cairo_t cr
-- @number x x coordinate of point
-- @number y y coordinate of point
-- @number[opt=4] size line length of cross
-- @number[opt=1] r red color component
-- @number[opt=0] g green color component
-- @number[opt=0] b blue color component
-- @number[opt=0.7] a alpha color compnent (transparency)
function ch.show_point(cr, x, y, size, r, g, b, a)
    size = 0.5 * (size or 4)
    cairo_move_to(cr, x - size, y - size)
    cairo_line_to(cr, x + size, y + size)
    cairo_move_to(cr, x + size, y - size)
    cairo_line_to(cr, x - size, y + size)
    cairo_set_source_rgba(cr, r or 1, g or 0, b or 0, a or 0.7)
    cairo_set_line_width(cr, 0.75)
    cairo_stroke(cr)
end

--- Set a single color gradient with varying opacity
-- on the given cairo drawing context.
-- @tparam cairo_t cr
-- @number x1 x coordinate of gradient start
-- @number y1 y coordinate of gradient start
-- @number x2 x coordinate of gradient end
-- @number y2 y coordinate of gradient end
-- @number r red color component
-- @number g green color component
-- @number b blue color component
-- @tparam {number,...} stops list of offset & alpha value pairs
--          offset between 0 and 1 describes position in the gradient
--          alpha between 0 and 1 describes opacity at given offset.
--          Note: For high/low alpha values the brightness may be emphasized
--          by color variation.
function ch.alpha_gradient(cr, x1, y1, x2, y2, r, g, b, stops)
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

--- Set a radial single color gradient with varying opacity
-- on the given cairo drawing context.
-- @tparam cairo_t cr
-- @number x1 x coordinate of inner circle center point
-- @number y1 y coordinate of inner circle center point
-- @number inner_radius
-- @number x2 x coordinate of outer circle center point
-- @number y2 y coordinate of outer circle center point
-- @number outer_radius
-- @number r red color component
-- @number g green color component
-- @number b blue color component
-- @tparam {number,...} stops list of offset & alpha value pairs
--          offset between 0 and 1 describes position in the gradient
--          alpha between 0 and 1 describes opacity at given offset.
--          Note: For high/low alpha values the brightness may be emphasized
--          by color variation.
function ch.alpha_gradient_radial(cr, x1, y1, inner_radius, x2, y2, outer_radius,
                                      r, g, b, stops)
    local gradient = cairo_pattern_create_radial(x1, y1, inner_radius,
                                                 x2, y2, outer_radius)
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

--- Select font settings for given cairo drawing context
-- @tparam cairo_t cr
-- @tparam string font_family
-- @tparam int font_size
-- @tparam[opt] ?cairo_font_slant_t font_slant (default: CAIRO_FONT_SLANT_NORMAL)
-- @tparam[opt] ?cairo_font_weight_t font_weight (default: CAIRO_FONT_WEIGHT_NORMAL)
function ch.set_font(cr, font_family, font_size, font_slant, font_weight)
    cairo_select_font_face(cr, font_family,
                               font_slant or CAIRO_FONT_SLANT_NORMAL,
                               font_weight or CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, font_size)
end

--- Get cairo_font_extents_t for a given font with size.
-- Use this, for example, to determine line-height.
-- see https://cairographics.org/manual/cairo-cairo-scaled-font-t.html#cairo-font-extents-t
-- @function ch.font_extents
-- @tparam string font_family
-- @tparam int font_size
-- @tparam[opt] ?cairo_font_slant_t font_slant (default: CAIRO_FONT_SLANT_NORMAL)
-- @tparam[opt] ?cairo_font_weight_t font_weight (default: CAIRO_FONT_WEIGHT_NORMAL)
-- @treturn cairo_font_extents_t
ch.font_extents = util.memoize(function(font_family, font_size, font_slant, font_weight)
    local tmp_surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 100, 100)
    local tmp_cr = cairo_create(tmp_surface)
    cairo_surface_destroy(tmp_surface)
    ch.set_font(tmp_cr, font_family, font_size, font_slant, font_weight)
    local extents = cairo_font_extents_t:create()
    tolua.takeownership(extents)
    cairo_font_extents(tmp_cr, extents)
    cairo_destroy(tmp_cr)
    return extents
end)

--- Get cairo_text_extents_t for given text on given cairo drawing surface
-- with its currently set font.
-- See https://cairographics.org/manual/cairo-cairo-scaled-font-t.html#cairo-text-extents-t
-- @tparam cairo_t cr
-- @string text
-- @treturn cairo_text_extents_t
local function text_extents(cr, text)
    local extents = cairo_text_extents_t:create()
    tolua.takeownership(extents)
    cairo_text_extents(cr, text, extents)
    return extents
end

--- Round number to nearest integer, 0.5 goes to next upper value
--  @number a number to be rounded
local function round_value(a)
  return a + 0.5 - (a + 0.5) % 1
end

--- Round coordinates to even pixel values
-- @see https://www.cairographics.org/FAQ/#sharp_lines
-- @see https://scriptinghelpers.org/questions/4850/how-do-i-round-numbers-in-lua-answered
-- @tparam cairo_t cr
-- @number x horizontal pixel coord value
-- @number y vertical pixel coord value
local function round_coords(cr, x, y)
    x, y = cairo_user_to_device(cr, x, y)
    return cairo_device_to_user(cr, round_value(x), round_value(y))
end

--- Write text left-aligned (to the right of given x).
-- @tparam cairo_t cr
-- @number x start of the written text
-- @number y coordinate of the baseline on top of which the text will be written
-- @string text
function ch.write_left(cr, x, y, text)
    x, y = round_coords(cr, x, y)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

--- Write text right-aligned (to the left of given x).
-- @tparam cairo_t cr
-- @number x end of the written text
-- @number y coordinate of the baseline on top of which the text will be written
-- @string text
function ch.write_right(cr, x, y, text)
    x, y = round_coords(cr, x, y)
    cairo_move_to(cr, x - text_extents(cr, text).width, y)
    cairo_show_text(cr, text)
end

--- Write text centered (spread evenly towards both sides of mx).
-- @tparam cairo_t cr
-- @number mx horizontal center of the written text
-- @number y coordinate of the baseline on top of which the text will be written
-- @string text
function ch.write_centered(cr, mx, y, text)
    local extents = text_extents(cr, text)
    local x = mx - (extents.width / 2 + extents.x_bearing)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

--- Write text centered horizontally and vertically on the given point mx, my.
-- @tparam cairo_t cr
-- @number mx horizontal center of the written text
-- @number my vertical center of the written text
-- @string text
function ch.write_middle(cr, mx, my, text)
    local extents = text_extents(cr, text)
    local x = mx - (extents.width / 2 + extents.x_bearing)
    local y = my - (extents.height / 2 + extents.y_bearing)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

return ch
