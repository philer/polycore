--- A collection of Widget classes
-- @module widget

local data = require 'data'
local util = require 'util'
local ch = require 'cairo_helpers'

--- Defaults
-- @section defaults

--- Font used by most widgets if no other is specified.
-- @string default_font_family
local default_font_family = "Ubuntu"

--- Font size used by most widgets if no other is specified.
-- @int default_font_size
local default_font_size = 10

--- Text color used by most widgets if no other is specified.
-- @tfield {number,number,number,number} default_text_color
local default_text_color = ({.94, .94, .94, 1})  -- ~fafafa

local temperature_colors = {
    {.4,  1,  1},
    {.5,  1, .8},
    {.7, .9, .6},
    {1,  .9, .4},
    {1,  .6, .2},
    {1,  .2, .2},
}

--- Color used to draw some widgets if no other is specified.
-- @tfield {number,number,number,number} default_graph_color
local default_graph_color = temperature_colors[1]

--- Generate a temperature based color.
-- Colors are chosen based on float offset in a pre-defined color gradient.
-- @number temp current temperature (or any other type of numeric value)
-- @number low threshold for lowest temperature / coolest color
-- @number high threshold for highest temperature / hottest color
local function temp_color(temp, low, high)
    local idx = (temp - low) / (high - low) * (#temperature_colors - 1) + 1
    local weight = idx - math.floor(idx)
    local cool = temperature_colors[util.clamp(1, #temperature_colors, math.floor(idx))]
    local hot = temperature_colors[util.clamp(1, #temperature_colors, math.ceil(idx))]
    return cool[1] + weight * (hot[1] - cool[1]),
           cool[2] + weight * (hot[2] - cool[2]),
           cool[3] + weight * (hot[3] - cool[3])
end


--- Root widget wrapper
-- Takes care of managing layout reflows and background caching.
-- @type WidgetRenderer
local WidgetRenderer = util.class()

---
-- @tparam table args table of options
-- @tparam Widget args.root The Widget subclass that should be rendered,
--                          usually a WidgetGroup
-- @int args.width Width of the surface that should be covered
-- @int args.height Height of the surface that should be covered
function WidgetRenderer:init(args)
    self._root = args.root
    self._width = args.width
    self._height = args.height
    self._background_surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32,
                                                          args.width,
                                                          args.height)
end

--- Layout all Widgets and cache their backgrounds.
-- Call this once to create the initial layout.
-- Will be called again automatically each time the layout changes.
function WidgetRenderer:layout()
    print("layout reflow…")
    local content_height = self._root:layout(self._width)
    local fillers = self._root:_count_fillers()
    if fillers > 0 then
        local filler_height = (self._height - content_height) / fillers
        local added_height = self._root:_adjust_filler_height(filler_height)
        assert(content_height + added_height == self._height)
    end

    local cr = cairo_create(self._background_surface)

    -- clear surface
    cairo_save(cr)
    cairo_set_source_rgba(cr, 0, 0, 0, 0)
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE)
    cairo_paint(cr)

    if DEBUG then
        cairo_set_source_rgba(cr, 1, 0, 0, 1)
        cairo_select_font_face(cr, "Ubuntu", CAIRO_FONT_SLANT_NORMAL,
                                             CAIRO_FONT_WEIGHT_NORMAL)
        cairo_set_font_size(cr, 8)
        ch.write_left(cr, 0, 8, table.concat{"conky ", conky_version, " ", _VERSION})
    end
    cairo_restore(cr)

    self._root:render_background(cr)
    cairo_destroy(cr)
end

--- Update all Widgets
function WidgetRenderer:update()
    if self._root:update() then self:layout() end
end

--- Render to the given context
-- @tparam cairo_t cr
function WidgetRenderer:render(cr)
    cairo_set_source_surface(cr, self._background_surface, 0, 0)
    cairo_paint(cr)
    self._root:render(cr)
end


--- Base Widget class.
-- @type Widget
local Widget = util.class()
Widget._height = 0

--- Called at least once to inform the widget of its width.
-- Must return the Widget's height.
-- The default implementation returns `self._height` as a convenience.
-- @tparam int width
-- @treturn int height
function Widget:layout(width) return self._height end

--- Called at least once to allow the widget to draw static content.
-- @tparam cairo_t cr Cairo context for background rendering
--                    (to be cached by the `WidgetRenderer`)
function Widget:render_background(cr) end

--- Called before each call to `Widget:render`.
-- If this function returns a true-ish value, a reflow will be triggered.
-- Since this involves calls to all widgets' :layout functions,
-- reflows should be used sparingly.
-- @treturn ?bool true(-ish) if a layout reflow should be triggered, causing
--                all `Widget:layout` and `Widget:render_background` methods
--                to be called again
function Widget:update() return false end

--- Called once per update to do draw dynamic content.
-- @tparam cairo_t cr
function Widget:render(cr) end

-- Helper function for counting all fillers
function Widget:_count_fillers() return 0 end

-- Helper function for spreading unused space evenly.
-- @int height
-- @treturn int
function Widget:_adjust_filler_height(height) return 0 end


--- Leave enough vertical space between widgets to eventually fill the entire
-- height of the drawable surface. Available space will be distributed evenly
-- between all Filler Widgets.
-- @type Gap
local Filler = util.class(Widget)

function Filler:_count_fillers() return 1 end

function Filler:_adjust_filler_height(height) return height end


--- Basic collection of widgets.
-- Grouped widgets are drawn in a vertical stack,
-- starting at the top of the drawble surface.
-- @type WidgetGroup
local WidgetGroup = util.class(Widget)

---
-- @tparam {Widget,...} widgets
function WidgetGroup:init(widgets)
    self._widgets = widgets
end

function WidgetGroup:layout(width)
    self._width = width  -- used to draw debug lines
    local widget_height, total_height, heights = 0, 0, {}
    for i, w in ipairs(self._widgets) do
        widget_height = w:layout(width)
        heights[i] = widget_height
        total_height = total_height + widget_height
    end
    self._widget_heights = heights
    self._height = total_height
    return total_height
end

function WidgetGroup:_count_fillers()
    local count = 0
    for i = 1, #self._widgets do
        count = count + self._widgets[i]:_count_fillers()
    end
    return count
end

function WidgetGroup:_adjust_filler_height(height)
    local total_add_height = 0
    for i = 1, #self._widgets do
        local add_height = self._widgets[i]:_adjust_filler_height(height)
        self._widget_heights[i] = self._widget_heights[i] + add_height
        total_add_height = total_add_height + add_height
    end
    return total_add_height
end

function WidgetGroup:render_background(cr)

    if DEBUG then
        local y_offset = 0
        for _, h in ipairs(self._widget_heights) do
            cairo_rectangle(cr, 0, y_offset, self._width, h)
            y_offset = y_offset + h
        end
        cairo_set_line_width(cr, 1)
        cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
        cairo_set_source_rgba(cr, 1, 0, 0, 0.33)
        cairo_stroke(cr)
    end

    cairo_save(cr)
    for i = 1, #self._widgets do
        self._widgets[i]:render_background(cr)
        cairo_translate(cr, 0, self._widget_heights[i])
    end
    cairo_restore(cr)
end

function WidgetGroup:update()
    local reflow = false
    for i, w in ipairs(self._widgets) do
        reflow = reflow or w:update()
    end
    return reflow
end

function WidgetGroup:render(cr)
    cairo_save(cr)
    for i = 1, #self._widgets do
        self._widgets[i]:render(cr)
        cairo_translate(cr, 0, self._widget_heights[i])
    end
    cairo_restore(cr)
end


--- Leave some space between widgets.
-- @type Gap
local Gap = util.class(Widget)

--- @int height Amount of vertical space in pixels
function Gap:init(height)
    self._height = height
end


--- Draw a static border and/or background around/behind another widget.
-- @type Frame
local Frame = util.class(Widget)

--- @tparam Widget widget Widget to be wrapped
-- @tparam table args table of options
-- @tparam ?number|{number,...} args.padding Leave some space around the inside
--  of the frame.<br>
--  - number: same padding all around.<br>
--  - table of two numbers: {top & bottom, left & right}<br>
--  - table of three numbers: {top, left & right, bottom}<br>
--  - table of four numbers: {top, right, bottom, left}
-- @tparam ?{number,number,number,number} args.background_color
-- @tparam ?{number,number,number,number} args.border_color
-- @tparam ?number args.border_width border line width
-- @tparam ?{string,...} args.border_sides any combination of
--                                         "top", "right", "bottom" and/or "left"
--                                         (default: all sides)
function Frame:init(widget, args)
    self._widget = widget
    self._background_color = args.background_color or nil
    self._border_color = args.border_color or {0, 0, 0, 0}
    self._border_width = args.border_width or 0

    local pad = args.padding or 0
    if type(pad) == "number" then
        self._padding = {top=pad, right=pad, bottom=pad, left=pad}
    elseif #pad == 2 then
        self._padding = {top=pad[1], right=pad[2], bottom=pad[1], left=pad[2]}
    elseif #pad == 3 then
        self._padding = {top=pad[1], right=pad[2], bottom=pad[3], left=pad[2]}
    elseif #pad == 4 then
        self._padding = {top=pad[1], right=pad[2], bottom=pad[3], left=pad[4]}
    end

    self._has_border = self._border_width > 0
                       and (not args.border_sides or #args.border_sides > 0)
    self._has_background = self._background_color and self._background_color[4] > 0

    self._border_sides = util.set(args.border_sides or {"top", "right", "bottom", "left"})

    self._offset_top = self._padding.top
                       + (self._border_sides.top and self._border_width or 0)
    self._offset_left = self._padding.left
                       + (self._border_sides.left and self._border_width or 0)
end

function Frame:_count_fillers()
    return self._widget:_count_fillers()
end

function Frame:_adjust_filler_height(height)
    local add_height = self._widget:_adjust_filler_height(height)
    self._height = self._height + add_height
    return add_height
end

function Frame:layout(width)
    self._width = width
    local inner_width = width - self._offset_left - self._padding.left
                        - (self._border_sides.right and self._border_width or 0)
    local inner_height = self._widget:layout(inner_width)

    self._height = inner_height + self._offset_top + self._padding.bottom
                   + (self._border_sides.bottom and self._border_width or 0)
    return self._height
end

function Frame:render_background(cr)
    cairo_save(cr)

    if self._has_background then
        cairo_rectangle(cr, 0, 0, self._width, self._height)
        cairo_set_source_rgba(cr, unpack(self._background_color))
        cairo_fill(cr)
    end

    if self._has_border then
        cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
        cairo_set_line_cap(cr, CAIRO_LINE_CAP_SQUARE)
        cairo_set_source_rgba(cr, unpack(self._border_color))
        cairo_set_line_width(cr, self._border_width)
        local offset = 0.5 * self._border_width
        local x_max = self._width - offset
        local y_max = self._height - offset
        local side, line, move = self._border_sides, cairo_line_to, cairo_move_to
        cairo_move_to(cr, offset, offset);
        (side.top and line or move)(cr, x_max, offset);
        (side.right and line or move)(cr, x_max, y_max);
        (side.bottom and line or move)(cr, offset, y_max);
        (side.left and line or move)(cr, offset, offset);
        cairo_stroke(cr, self._background_color)
    end

    cairo_translate(cr, self._offset_left, self._offset_top)
    self._widget:render_background(cr)
    cairo_restore(cr)
end

function Frame:update()
    return self._widget:update()
end

function Frame:render(cr)
    if self._offset_top > 0 or self._offset_left > 0 then
        cairo_save(cr)
        cairo_translate(cr, self._offset_left, self._offset_top)
        self._widget:render(cr)
        cairo_restore(cr)
    else
        self._widget:render(cr)
    end
end


--- Draw a single line changeable of text.
-- Use this widget for text that will be updated on each cycle.
-- @type TextLine
local TextLine = util.class(Widget)

--- @tparam table args table of options
-- @tparam ?string args.align "left" (default), "center" or "right"
-- @tparam ?string args.font_family
-- @tparam ?number args.font_size
-- @tparam ?{number,number,number,number} args.color
function TextLine:init(args)
    self.align = args.align or "left"
    self.font_family = args.font_family or default_font_family
    self.font_size = args.font_size or default_font_size
    self.color = args.color or default_text_color

    local write_fns = {left = ch.write_left,
                       center = ch.write_centered,
                       right = ch.write_right}
    self._write_fn = write_fns[self.align]

    local extents = ch.font_extents(self.font_family, self.font_size)
    self._height = extents.height + 1
    local line_spacing = extents.height - (extents.ascent + extents.descent)
    -- try to match conky's line spacing:
    self._baseline_offset = extents.ascent + 0.5 * line_spacing + 1
end

--- Update the text line to be displayed.
-- @string text
function TextLine:set_text(text)
    self.text = text
end

function TextLine:layout(width)
    if self.align == "center" then
        self._x = 0.5 * width
    elseif self.align == "left" then
        self._x = 0
    else  -- self.align == "right"
        self._x = width
    end
    return self._height
end

function TextLine:render(cr)
    cairo_select_font_face(cr, self.font_family, CAIRO_FONT_SLANT_NORMAL,
                                                 CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, self.font_size)
    cairo_set_source_rgba(cr, unpack(self.color))
    self._write_fn(cr, self._x, self._baseline_offset, self.text)
end


--- Progress-bar like box, similar to conky's bar.
-- Can have small and big ticks for visual clarity,
-- and a unit (static, up to 3 characters) written behind the end.
-- @type Bar
local Bar = util.class(Widget)

--- @tparam table args table of options
-- @tparam[opt=6] int args.thickness vertical size of the bar
-- @tparam ?string args.unit to be drawn behind the bar - 3 characters will fit
-- @tparam ?{number,...} args.ticks relative offsets (between 0 and 1) of ticks
-- @tparam ?int args.big_ticks multiple of ticks to be drawn longer
-- @tparam ?{number,number,number,number} args.color
function Bar:init(args)
    self._ticks = args.ticks
    self._big_ticks = args.big_ticks
    self._unit = args.unit
    self._thickness = (args.thickness or 4)
    self._height = self._thickness + 2
    self.color = args.color or default_graph_color

    if self._ticks then
        self._height = self._height + (self._big_ticks and 3 or 2)
    end
    if self._unit then
        self._height = math.max(self._height, 8)  -- line_height
    end
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
    return self._height
end

function Bar:render_background(cr)
    if self._unit then
        cairo_set_source_rgba(cr, unpack(default_text_color))
        ch.set_font(cr, default_font_family, default_font_size)
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


--- Specialized unit-based Bar.
-- @type MemoryBar
local MemoryBar = util.class(Bar)

--- @tparam table args table of options
-- @tparam ?number args.total Total amount of memory to be represented
--                            by this bar. If greater than 8, ticks will be
--                            drawn. If omitted, total RAM will be used,
--                            however no ticks can be drawn.
-- @tparam[opt="GiB"] string args.unit passed to `Bar:init`
-- @tparam ?int args.thickness passed to `Bar:init`
-- @tparam ?{number,number,number,number} args.color passed to `Bar:init`
function MemoryBar:init(args)
    self.total = args.total
    local ticks, big_ticks
    if self.total then
        local max_tick = math.floor(self.total)
        ticks = util.range(1 / self.total, max_tick / self.total, 1 / self.total)
        big_ticks = max_tick > 8 and 4 or nil
    end
    Bar.init(self, {ticks=ticks,
                    big_ticks=big_ticks,
                    unit=args.unit or "GiB",
                    thickness=args.thickness,
                    color=args.color})
end

--- Set the amount of used memory as an absolute value.
-- @number used should be between 0 and args.total
function MemoryBar:set_used(used)
    self:set_fill(used / self.total)
end

function MemoryBar:update()
    local used, _, _, total = data.memory()
    self:set_fill(used / total)
end


--- Track changing data; similar to conky's graphs.
-- @type Graph
local Graph = util.class(Widget)

--- @tparam table args table of options
-- @tparam number args.max maximum expected value to be represented;
--                         may be expanded automatically as need arises
-- @int[opt=90] args.data_points how many values to store
-- @int[opt=22] args.height includes fake shadow border
-- @bool[opt=false] args.upside_down draw graph from top to bottom
-- @tparam ?{number,number,number,number} args.color
function Graph:init(args)
    self._max = args.max
    self._height = args.height or 22
    self._inner_height = self._height - 2
    self._upside_down = args.upside_down
    self._data = util.CycleQueue(args.data_points or 90)
    self.color = args.color or default_graph_color
end

function Graph:layout(width)
    self._width = width - 2
    self._x_scale = 1 / self._data.length * (self._width - 1)
    self._y_scale = 1 / self._max * (self._inner_height - 1)
    if self._upside_down then
        self._y_scale = -self._y_scale
        self._y = -0.5
    else
        self._y = self._inner_height - 0.5
    end
    return self._height
end

function Graph:render_background(cr)
    local r, g, b = unpack(self.color)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)

    -- background
    cairo_rectangle(cr, 0, 0, self._width, self._inner_height)
    ch.alpha_gradient(cr, 0, 0, 0, self._inner_height, r, g, b, {
        .1, .14, .1, .06, .2, .06, .2, .14,
        .3, .14, .3, .06, .4, .06, .4, .14,
        .5, .14, .5, .06, .6, .06, .6, .14,
        .7, .14, .7, .06, .8, .06, .8, .14,
        .9, .14, .9, .06,
    })
    cairo_fill(cr)

    -- border
    cairo_set_line_width(cr, 1)
    cairo_rectangle(cr, 1, 1, self._width - 1, self._inner_height - 1)
    cairo_set_source_rgba(cr, r, g, b, .2)
    cairo_stroke(cr)

    -- fake shadow border
    cairo_rectangle(cr, 0, 0, self._width + 1, self._inner_height + 1)
    cairo_set_source_rgba(cr, 0, 0, 0, .33)
    cairo_stroke(cr)
end

--- Append the latest value to be shown - this will displace the oldest value
-- @number value if value > args.max then the graphs vertical scale will be
--               adjusted, causing it to get squished
function Graph:add_value(value)
    self._data:put(value)
    if value > self._max then
        self._max = value
        self:layout(self._width + 2)
    end
end

function Graph:render(cr)
    local r, g, b = unpack(self.color)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT)

    cairo_move_to(cr, 0, self._y)
    local current_max = 0
    self._data:each(function(val, idx)
        cairo_line_to(cr, 0.5 + (idx - 1) * self._x_scale, self._y - val * self._y_scale)
        if val > current_max then current_max = val end
    end)
    cairo_line_to(cr, self._width, self._y)
    cairo_set_source_rgba(cr, r, g, b, 1)
    cairo_set_line_width(cr, .5)
    cairo_stroke_preserve(cr)

    -- fill under graph
    ch.alpha_gradient(cr, 0, self._y - current_max * self._y_scale, 0, self._y,
                      r, g, b, {0, .66, .5, .33, 1, .25})
    cairo_fill(cr)
end


--- Polygon-style CPU usage & temperature tracking.
-- Looks best for CPUs with 4 to 8 cores but also works for higher numbers
-- @type Cpu
local Cpu = util.class(Widget)

--- @tparam table args table of options
-- @int args.cores How many cores does your CPU have?
-- @int args.scale radius of central polygon
-- @int args.gap space between central polygon and outer segments
-- @int args.segment_size radial thickness of outer segments
function Cpu:init(args)
    self.cores = args.cores
    self.scale = args.scale
    self.gap = args.gap
    self.segment_size = args.segment_size
end

function Cpu:layout(width)
    local radius = self.scale + self.gap + self.segment_size
    self.height = 2 * radius
    self.mx = width / 2
    self.my = radius

    self.center_coordinates = {}
    self.segment_coordinates = {}
    self.gradient_coordinates = {}
    local sector_rad = 2 * math.pi / self.cores
    local min, max = self.scale + self.gap, radius

    for core = 1, self.cores do
        local rad_center = (core - 1) * sector_rad - math.pi/2
        local rad_left = rad_center + sector_rad/2
        local rad_right = rad_center - sector_rad/2
        local dx_center, dy_center = math.cos(rad_center), math.sin(rad_center)
        local dx_left, dy_left = math.cos(rad_left), math.sin(rad_left)
        local dx_right, dy_right = math.cos(rad_right), math.sin(rad_right)
        self.center_coordinates[2 * core - 1] = self.mx + self.scale * dx_left
        self.center_coordinates[2 * core] = self.my + self.scale * dy_left

        -- segment corners
        local dx_gap, dy_gap = self.gap * dx_center, self.gap * dy_center
        local x1 = self.mx + min * dx_left + dx_gap
        local y1 = self.my + min * dy_left + dy_gap
        local x2 = self.mx + max * dx_left + dx_gap
        local y2 = self.my + max * dy_left + dy_gap
        local x3 = self.mx + max * dx_right + dx_gap
        local y3 = self.my + max * dy_right + dy_gap
        local x4 = self.mx + min * dx_right + dx_gap
        local y4 = self.my + min * dy_right + dy_gap
        self.segment_coordinates[core] = {x1, y1, x2, y2, x3, y3, x4, y4}
        self.gradient_coordinates[core] = {(x1 + x4) / 2, (y1 + y4) / 2,
                                           (x2 + x3) / 2, (y2 + y3) / 2}
    end
    return self.height
end

function Cpu:update()
    self.percentages = data.cpu_percentages(self.cores)
    self.temperatures = data.cpu_temperatures()
end

function Cpu:render(cr)
    local avg_temperature = util.avg(self.temperatures)
    local r, g, b = temp_color(avg_temperature, 30, 80)

    ch.polygon(cr, self.center_coordinates)
    cairo_set_line_width(cr, 6)
    cairo_set_source_rgba(cr, r, g, b, .33)
    cairo_stroke_preserve(cr)
    cairo_set_line_width(cr, 1)
    cairo_set_source_rgba(cr, 0, 0, 0, .66)
    cairo_stroke_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, .18)
    cairo_fill(cr)

    cairo_set_source_rgba(cr, r, g, b, .4)
    ch.set_font(cr, default_font_family, 16, nil, CAIRO_FONT_WEIGHT_BOLD)
    ch.write_middle(cr, self.mx + 1, self.my, string.format("%.0f°", avg_temperature))

    for core = 1, self.cores do
        ch.polygon(cr, self.segment_coordinates[core])
        local gradient = cairo_pattern_create_linear(unpack(self.gradient_coordinates[core]))
        local r, g, b = temp_color(self.temperatures[core], 30, 80)
        cairo_set_source_rgba(cr, 0, 0, 0, .4)
        cairo_set_line_width(cr, 1.5)
        cairo_stroke_preserve(cr)
        cairo_set_source_rgba(cr, r, g, b, .4)
        cairo_set_line_width(cr, .75)
        cairo_stroke_preserve(cr)

        local h_rel = self.percentages[core]/100
        cairo_pattern_add_color_stop_rgba(gradient, 0,            r, g, b, .33)
        cairo_pattern_add_color_stop_rgba(gradient, h_rel - .045, r, g, b, .75)
        cairo_pattern_add_color_stop_rgba(gradient, h_rel,
                                          r * 1.2, g * 1.2, b * 1.2, 1)
        if h_rel < .95 then  -- prevent pixelated edge
            cairo_pattern_add_color_stop_rgba(gradient, h_rel + .045, r, g, b, .33)
            cairo_pattern_add_color_stop_rgba(gradient, h_rel + .33,  r, g, b, .15)
            cairo_pattern_add_color_stop_rgba(gradient, 1,            r, g, b, .15)
        end
        cairo_set_source(cr, gradient)
        cairo_pattern_destroy(gradient)
        cairo_fill(cr)
    end
end


--- Visualize cpu-frequencies in a style reminiscent of stacked progress bars.
-- @type CpuFrequencies
local CpuFrequencies = util.class(Widget)

--- @tparam table args table of options
-- @int args.cores How many cores does your CPU have?
-- @number args.min_freq What is your CPU's minimum frequency?
-- @number args.min_freq What is your CPU's maximum frequency?
-- @int[opt=16] args.height Maximum pixel height of the drawn shape
function CpuFrequencies:init(args)
    self.cores = args.cores
    self.min_freq = args.min_freq
    self.max_freq = args.max_freq
    self._height = args.height or 16
    self.height = self._height + 13
end

function CpuFrequencies:layout(width)
    self._width = width - 25
    self._polygon_coordinates = {
        0, self._height * (1 - self.min_freq / self.max_freq),
        self._width, 0,
        self._width, self._height,
        0, self._height,
    }
    self._ticks = {}
    self._tick_labels = {}

    local df = self.max_freq - self.min_freq
    for freq = 1, self.max_freq, .25 do
        local x = self._width * (freq - self.min_freq) / df
        local big = math.floor(freq) == freq
        if big then
            table.insert(self._tick_labels, {x, self._height + 11.5, ("%.0f"):format(freq)})
        end
        table.insert(self._ticks, {math.floor(x) + .5,
                                   self._height + 2,
                                   big and 3 or 2})
    end
    return self.height
end

function CpuFrequencies:render_background(cr)
    cairo_set_source_rgba(cr, unpack(default_text_color))
    ch.set_font(cr, default_font_family, default_font_size)
    ch.write_left(cr, self._width + 5, 0.5 * self._height + 3, "GHz")

    -- shadow outline
    ch.polygon(cr, {
        self._polygon_coordinates[1] - 1, self._polygon_coordinates[2] - 1,
        self._polygon_coordinates[3] + 1, self._polygon_coordinates[4] - 1,
        self._polygon_coordinates[5] + 1, self._polygon_coordinates[6] + 1,
        self._polygon_coordinates[7] - 1, self._polygon_coordinates[8] + 1,
    })
    cairo_set_source_rgba(cr, 0, 0, 0, .4)
    cairo_set_line_width(cr, 1)
    cairo_stroke(cr)
end

function CpuFrequencies:update()
    self.frequencies = data.cpu_frequencies(self.cores)
    self.temperatures = data.cpu_temperatures()
end

function CpuFrequencies:render(cr)
    local r, g, b = temp_color(util.avg(self.temperatures), 30, 80)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    cairo_set_line_width(cr, 1)

    -- ticks --
    cairo_set_source_rgba(cr, r, g, b, .66)
    for _, tick in ipairs(self._ticks) do
        cairo_move_to(cr, tick[1], tick[2])
        cairo_rel_line_to(cr, 0, tick[3])
    end
    cairo_stroke(cr)
    ch.set_font(cr, default_font_family, default_font_size)
    for _, label in ipairs(self._tick_labels) do
        ch.write_centered(cr, label[1], label[2], label[3])
    end

    -- background --
    ch.polygon(cr, self._polygon_coordinates)
    cairo_set_source_rgba(cr, r, g, b, .15)
    cairo_fill_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, .3)
    cairo_stroke_preserve(cr)

    -- frequencies --
    local df = self.max_freq - self.min_freq
    for _, frequency in ipairs(self.frequencies) do
        local stop = (frequency - self.min_freq) / df
        ch.alpha_gradient(cr, 0, 0, self._width, 0, r, g, b, {
             0, 0.01,
             stop - .4, 0.015,
             stop - .2, 0.05,
             stop - .1, 0.1,
             stop - .02, 0.2,
             stop, 0.6,
             stop, 0,
        })
        cairo_fill_preserve(cr)
    end
    cairo_new_path(cr)
end


--- Visualize memory usage in a randomized grid.
-- Does not represent actual distribution of used memory.
-- Also shows buffere/cache memory at reduced brightness.
-- @type MemoryGrid
local MemoryGrid = util.class(Widget)

--- @tparam table args table of options
-- @int[opt=5] args.rows number of rows to draw
-- @int[opt=2] args.point_size edge length of individual squares
-- @int[opt=1] args.gap space between squares
-- @bool[opt=true] args.shuffle randomize?
function MemoryGrid:init(args)
    self.rows = args.rows or 5
    self.point_size = args.point_size or 2
    self.gap = args.gap or 1
    self.shuffle = args.shuffle == nil and true or args.shuffle
    self.height = self.rows * self.point_size + (self.rows - 1) * self.gap
end

function MemoryGrid:layout(width)
    local point_plus_gap = self.point_size + self.gap
    local columns = math.floor(width / point_plus_gap)
    local left = 0.5 * (width - columns * point_plus_gap + self.gap)
    self.coordinates = {}
    for col = 0, columns - 1 do
        for row = 0, self.rows - 1 do
            table.insert(self.coordinates, {col * point_plus_gap + left,
                                            row * point_plus_gap,
                                            self.point_size, self.point_size})
        end
    end
    if shuffle == nil or shuffle then
        util.shuffle(self.coordinates)
    end
    return self.height
end

function MemoryGrid:update()
    self.used, self.easyfree, self.free, self.total = data.memory()
end

function MemoryGrid:render(cr)
    local total_points = #self.coordinates
    local used_points = math.floor(total_points * self.used / self.total + 0.5)
    local cache_points = math.floor(total_points * (self.easyfree - self.free) / self.total + 0.5)
    local r, g, b = temp_color(self.used / self.total, 0.6, 0.9)

    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    for i = 1, used_points do
        cairo_rectangle(cr, unpack(self.coordinates[i]))
    end
    cairo_set_source_rgba(cr, r, g, b, .8)
    cairo_fill(cr)
    for i = used_points, used_points + cache_points do
        cairo_rectangle(cr, unpack(self.coordinates[i]))
    end
    cairo_set_source_rgba(cr, r, g, b, .35)
    cairo_fill(cr)
    for i = used_points + cache_points, total_points do
        cairo_rectangle(cr, unpack(self.coordinates[i]))
    end
    cairo_set_source_rgba(cr, r, g, b, .1)
    cairo_fill(cr)
end


--- Compound widget to display GPU and VRAM usage.
-- @type Gpu
local Gpu = util.class(WidgetGroup)

--- no options
function Gpu:init()
    self.usebar = Bar{ticks={.25, .5, .75}, unit="%"}
    local _, mem_total = data.gpu_memory()
    self.membar = MemoryBar{total=mem_total / 1024}
    WidgetGroup.init(self, {self.usebar, Gap(4), self.membar})
end

function Gpu:update()
    self.usebar:set_fill(data.gpu_percentage() / 100)

    local mem_used, _ = data.gpu_memory()
    self.membar:set_used(mem_used / 1024)

    local color = {temp_color(data.gpu_temperature(), 30, 80)}
    self.usebar.color = color
    self.membar.color = color
end

--- Table of processes for the GPU, sorted by VRAM usage
-- @type GpuTop
local GpuTop = util.class(Widget)

--- @tparam table args table of options
-- @int[opt=5] args.lines how many processes to display
-- @tparam ?string args.font_family
-- @tparam ?number args.font_size
-- @tparam ?{number,number,number,number} args.color
function GpuTop:init(args)
    self._lines = args.lines or 5
    self._font_family = args.font_family or default_font_family
    self._font_size = args.font_size or default_font_size
    self._color = args.color or default_text_color

    local extents = ch.font_extents(self._font_family, self._font_size)
    self._line_height = extents.height
    self._height = self._lines * self._line_height
    local line_spacing = extents.height - (extents.ascent + extents.descent)
    -- try to match conky's line spacing:
    self._baseline_offset = extents.ascent + 0.5 * line_spacing + 1
end

function GpuTop:layout(width)
    self._width = width
    return self._height
end

function GpuTop:update()
    self._processes = data.gpu_top()
end

function GpuTop:render(cr)
    cairo_select_font_face(cr, self._font_family, CAIRO_FONT_SLANT_NORMAL,
                                                 CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, self._font_size)
    cairo_set_source_rgba(cr, unpack(self._color))
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)

    local lines = math.min(self._lines, #self._processes)
    local y = self._baseline_offset
    for i = 1, lines do
        ch.write_left(cr, 0, y, self._processes[i][1])
        ch.write_right(cr, self._width, y, self._processes[i][2] .. " MiB")
        y = y + self._line_height
    end
end

--- Graphs for up- and download speed.
-- This widget assumes that your conky.text adds some text between the graphs.
-- @type Network
local Network = util.class(WidgetGroup)

--- @tparam table args table of options
-- @string args.interface e.g. "eth0"
-- @tparam ?int args.graph_height passed to `Graph:init`
-- @number[opt=1024] args.downspeed passed as args.max to download speed graph
-- @number[opt=1024] args.upspeed passed as args.max to upload speed graph
function Network:init(args)
    self.interface = args.interface
    self.downspeed_graph = Graph{height=args.graph_height, max=args.downspeed or 1024}
    self.upspeed_graph = Graph{height=args.graph_height, max=args.upspeed or 1024}
    WidgetGroup.init(self, {self.downspeed_graph, Gap(31), self.upspeed_graph})
end

function Network:update()
    local down, up = data.network_speed(self.interface)
    self.downspeed_graph:add_value(down)
    self.upspeed_graph:add_value(up)
end

--- Visualize drive usage and temperature in a colorized Bar.
-- Also writes temperature as text.
-- This widget is exptected to be combined with some special conky.text.
-- @type Drive
local Drive = util.class(WidgetGroup)

---
-- @string path e.g. "/home"
-- @string device_name e.g. "/dev/sda1"
function Drive:init(path, device_name)
    self.path = path
    self.device_name = device_name

    self._temperature_text = TextLine{align="right"}
    self._bar = Bar{}
    WidgetGroup.init(self, {self._temperature_text,
                            Gap(4),
                            self._bar,
                            Gap(25)})
    self._is_mounted = data.is_mounted(self.path)
end

function Drive:layout(width)
    local height = WidgetGroup.layout(self, width)
    return self._is_mounted and height or 0
end

function Drive:render_background(cr)
    if self._is_mounted then
        WidgetGroup.render_background(self, cr)
    end
end

function Drive:update()
    local was_mounted = self._is_mounted
    self._is_mounted = data.is_mounted(self.path)
    if self._is_mounted then
        self._bar:set_fill(data.drive_percentage(self.path) / 100)
        self.temperature = data.hddtemp()[self.device_name]
    end
    return self._is_mounted ~= was_mounted
end

function Drive:render(cr)
    if not self._is_mounted then
        return
    end
    if self.temperature then
        self._bar.color = {temp_color(self.temperature, 35, 65)}
        self._temperature_text:set_text(self.temperature .. "°C")
    else
        self._bar.color = {0.8, 0.8, 0.8}
        self._temperature_text:set_text("––––")
    end
    WidgetGroup.render(self, cr)
end


return {
    Bar = Bar,
    Border = Border,
    Cpu = Cpu,
    CpuFrequencies = CpuFrequencies,
    Drive = Drive,
    Filler = Filler,
    Frame = Frame,
    Gap = Gap,
    Gpu = Gpu,
    GpuTop = GpuTop,
    Graph = Graph,
    MemoryBar = MemoryBar,
    MemoryGrid = MemoryGrid,
    Network = Network,
    TextLine = TextLine,
    Widget = Widget,
    WidgetGroup = WidgetGroup,
    WidgetRenderer = WidgetRenderer,
}
