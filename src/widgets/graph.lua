--- A collection of Basic Graph and indicator Widget classes
-- @module widget_graph
-- @alias wg

pcall(function() require('cairo') end)

local data = require('src/data')
local util = require('src/util')
local ch = require('src/cairo_helpers')
local core = require('src/widgets/core')
local Widget = core.Widget

-- lua 5.1 to 5.3 compatibility
local unpack = unpack or table.unpack  -- luacheck: read_globals unpack table

local sin, cos, tan, PI = math.sin, math.cos, math.tan, math.pi
local floor, ceil, clamp = math.floor, math.ceil, util.clamp

--- Progress-bar like box, similar to conky's bar.
-- Can have small and big ticks for visual clarity,
-- and a unit (static, up to 3 characters) written behind the end.
-- @type Bar
local Bar = util.class(Widget)
w.Bar = Bar

--- @tparam table args table of options
-- @tparam[opt=6] int args.thickness vertical size of the bar
-- @tparam ?string args.unit to be drawn behind the bar - 3 characters will fit
-- @tparam ?{number,...} args.ticks relative offsets (between 0 and 1) of ticks
-- @tparam ?int args.big_ticks multiple of ticks to be drawn longer
-- @tparam ?{number,number,number} args.color (default: `default_graph_color`)
function Bar:init(args)
    self._ticks = args.ticks
    self._big_ticks = args.big_ticks
    self._unit = args.unit
    self._thickness = (args.thickness or 4)
    self.height = self._thickness + 2
    self.color = args.color or current_theme.default_graph_color

    if self._ticks then
        self.height = self.height + (self._big_ticks and 3 or 2)
    end
    if self._unit then
        self.height = math.max(self.height, 8)  -- line_height
    end

    self._fraction = 0
end

function Bar:layout(width)
    self._width = width - (self._unit and 20 or 0) - 2
    self._tick_coordinates = {}
    if self._ticks then
        local x, tick_length
        for i, frac in ipairs(self._ticks) do
            x = math.floor(frac * self._width)
            tick_length = 3
            if self._big_ticks then
                if i % self._big_ticks == 0 then
                    tick_length = 3
                else
                    tick_length = 2
                end
            end
            table.insert(self._tick_coordinates, {x, self._thickness + 1, tick_length})
        end
    end
end

function Bar:render_background(cr)
    if self._unit then
        cairo_set_source_rgba(cr, unpack(current_theme.default_text_color))
        ch.set_font(cr, current_theme.default_font_family, current_theme.default_font_size)
        ch.write_left(cr, self._width + 5, 6, self._unit)
    end
    -- fake shadow border
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    cairo_set_line_width(cr, 1)
    cairo_rectangle(cr, 0, 0, self._width + 1, self._thickness + 1)
    cairo_set_source_rgba(cr, 0, 0, 0, .66)
    cairo_stroke(cr)
end

--- Set the fill-ratio of the bar
-- @number fraction between 0 and 1
function Bar:set_fill(fraction)
    self._fraction = fraction
end

function Bar:render(cr)
    local r, g, b = unpack(self.color)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    cairo_set_line_width(cr, 1)

    cairo_rectangle(cr, 0, 0, self._width, self._thickness)
    ch.alpha_gradient(cr, 0, 0, self._width, 0, r, g, b, {
        self._fraction - 0.33, 0.33,
        self._fraction - 0.08, 0.66,
        self._fraction - 0.01, 0.75,
        self._fraction, 1,
        self._fraction + 0.01,  0.2,
        self._fraction + 0.1,  0.1,
        1, 0.15,
    })
    cairo_fill(cr)

    -- border
    cairo_rectangle(cr, 1, 1, self._width - 1, self._thickness - 1)
    cairo_set_source_rgba(cr, r, g, b, .2)
    cairo_stroke(cr)

    -- ticks
    for _, tick in ipairs(self._tick_coordinates) do
        cairo_move_to(cr, tick[1], tick[2])
        cairo_rel_line_to(cr, 0, tick[3])
    end
    cairo_set_source_rgba(cr, r, g, b, .5)
    cairo_stroke(cr)
end

--- Track changing data; similar to conky's graphs.
-- @type Graph
local Graph = util.class(Widget)
w.Graph = Graph

--- @tparam table args table of options
-- @tparam number args.max maximum expected value to be represented;
--                         may be expanded automatically as need arises
-- @int[opt=60] args.data_points how many values to store
-- @bool[opt=false] args.upside_down Draw graph from top to bottom?
-- @number[opt=0.5] args.smoothness Bézier curves smoothness.
--                                  Set to 0 to draw straight lines instead,
--                                  which may be slightly faster.
-- @int[opt] args.width fix width in pixels
-- @int[opt] args.height fixeheight in pixels
-- @tparam ?{number,number,number} args.color (default: `default_graph_color`)
function Graph:init(args)
    self._max = args.max
    self._data = util.CycleQueue(args.data_points or 60)
    self._upside_down = args.upside_down or false
    self._smoothness = args.smoothness or 0.5
    self.color = args.color or current_theme.default_graph_color
    self.width = args.width
    self.height = args.height
end

function Graph:layout(width, height)
    self._width = width - 2
    self._height = height - 2
    self._x_scale = (width - 2) / (self._data.length - 1)
    self._y_scale = (height - 3) / self._max
    if self._upside_down then
        self._y_scale = -self._y_scale
        self._y = -0.5
    else
        self._y = self._height - 0.5
    end
end

function Graph:render_background(cr)
    local r, g, b = unpack(self.color)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)

    -- background
    cairo_rectangle(cr, 0, 0, self._width + 1, self._height + 1)
    ch.alpha_gradient(cr, 0, 0, 0, self._height, r, g, b, {0, .15, 1, .03})
    cairo_fill(cr)

    -- grid
    cairo_set_line_width(cr, 1)
    cairo_set_source_rgba(cr, r, g, b, .0667)
    cairo_rectangle(cr, 1, 1, self._width - 1, self._height - 1)
    local gridsize = 5
    for row = gridsize + 1, self._height, gridsize do
        cairo_move_to(cr, 1, row)
        cairo_line_to(cr, self._width, row)
    end
    for column = gridsize + 1, self._width, gridsize do
        cairo_move_to(cr, column, 1)
        cairo_line_to(cr, column, self._height)
    end
    cairo_stroke(cr)
    for row = gridsize + 1, self._height, gridsize do
        for column = gridsize + 1, self._width, gridsize do
            cairo_rectangle(cr, column - 0.5, row - 0.5, 0.5, 0.5)
        end
    end
    cairo_set_source_rgba(cr, r, g, b, .15)
    cairo_stroke(cr)
end

--- Append the latest value to be shown - this will displace the oldest value
-- @number value if value > args.max then the graphs vertical scale will be
--               adjusted, causing it to get squished
function Graph:add_value(value)
    self._data:put(value)
    if value > self._max then
        self._max = value
        self:layout(self._width + 2, self._height + 2)
    end
end

function Graph:_line_path(cr)
    local current_max = 0
    cairo_move_to(cr, 0.5, self._y - self._data[1] * self._y_scale)
    for idx, val in self._data:__ipairs() do
        if current_max < val then current_max = val end
        if idx > 1 then
            cairo_line_to(cr, 0.5 + (idx - 1) * self._x_scale,
                              self._y - val * self._y_scale)
        end
    end
    return current_max
end

function Graph:_berzier_path(cr)
    local current_max = 0
    local prev_x, prev_y = 0.5, self._y - self._data[1] * self._y_scale
    cairo_move_to(cr, prev_x, prev_y)
    for idx, val in self._data:__ipairs() do
        if current_max < val then current_max = val end
        if idx > 1 then
            local current_x = 0.5 + (idx - 1) * self._x_scale
            local current_y = self._y - val * self._y_scale
            local x1 = prev_x + self._smoothness * self._x_scale
            local x2 = current_x - self._smoothness * self._x_scale
            cairo_curve_to(cr, x1, prev_y, x2, current_y, current_x, current_y)
            prev_x, prev_y = current_x, current_y
        end
    end
    return current_max
end

function Graph:render(cr)
    local r, g, b = unpack(self.color)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT)
    cairo_set_source_rgba(cr, r, g, b, 1)
    cairo_set_line_width(cr, 0.5)

    local current_max = self._smoothness > 0 and self:_berzier_path(cr)
                                              or self:_line_path(cr)

    if current_max > 0 then  -- fill under graph
        cairo_stroke_preserve(cr)
        cairo_line_to(cr, self._width, self._y)
        cairo_line_to(cr, 0, self._y)
        cairo_close_path(cr)
        ch.alpha_gradient(cr, 0, self._y - current_max * self._y_scale, 0, self._y,
                          r, g, b, {0, .66, .5, .33, 1, .25})
        cairo_fill(cr)
    else
        cairo_stroke(cr)
    end
end

--- Round light indicator for minimalistic feedback.
-- @type LED
local LED = util.class(Widget)
w.LED = LED

--- @tparam table args table of options
-- @number args.radius size of the LED
-- @number[opt=0] args.brightness between 0 and 1, how "on" should the LED be?
--                                Can be changed later with `LED:set_brightness`
-- @tparam ?{number,number,number} args.color color of the LED,
--                                can be changed later with `LED:set_color`.
--                                (default: `default_graph_color`)
-- @tparam ?{number,number,number,number} args.background_color mostly visible
--                                when the LED is off. This allows you to choose
--                                a neutral background if you plan on changing
--                                the light color via `LED:set_color`.
--                                (default: darkened `args.color`)
function LED:init(args)
    assert(args.radius)
    self._radius = args.radius
    self.width = self._radius * 2
    self.height = self._radius * 2
    self._brightness = args.brightness or 0
    self._color = args.color or current_theme.default_graph_color
    if args.background_color then
        self._background_color = args.background_color
    else
        local r, g, b = unpack(self._color)
        self._background_color = {0.2 * r, 0.2 * g, 0.2 * b, 0.75}
    end
end

--- @number brightness between 0 and 1
function LED:set_brightness(brightness)
    self._brightness = clamp(0, 1, brightness)
end

--- @tparam ?{number,number,number} color
function LED:set_color(color)
    self._color = color
end

function LED:layout(width, height)
    self._mx = width / 2
    self._my = height / 2
end

function LED:render_background(cr)
    cairo_arc(cr, self._mx, self._my, self._radius, 0, 360)
    cairo_set_source_rgba(cr, unpack(self._background_color))
    cairo_fill(cr)
end

function LED:render(cr)
    if self._brightness > 0 then
        local r, g, b = unpack(self._color)
        local gradient = cairo_pattern_create_radial(self._mx, self._my, 0,
                                                     self._mx, self._my, self._radius)
        cairo_pattern_add_color_stop_rgba(gradient, 0, r, g, b, 1 * self._brightness)
        cairo_pattern_add_color_stop_rgba(gradient, 0.5, r, g, b, 0.5 * self._brightness)
        cairo_pattern_add_color_stop_rgba(gradient, 1, r, g, b, 0.1 * self._brightness)
        cairo_set_source(cr, gradient)
        cairo_pattern_destroy(gradient)

        cairo_arc(cr, self._mx, self._my, self._radius, 0, 360)
        cairo_fill(cr)
    end
end

return w
