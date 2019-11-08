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
-- @type Renderer
local Renderer = util.class()

---
-- @tparam table args table of options
-- @tparam Widget args.root The Widget subclass that should be rendered,
--                          usually a Group
-- @int args.width Width of the surface that should be covered
-- @int args.height Height of the surface that should be covered
function Renderer:init(args)
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
function Renderer:layout()
    print("layout reflow…")
    self._render_widgets = self._root:layout(self._width, self._height)
    if not self._render_widgets then
        self._render_widgets = {self._root, 0, 0}
    end

    local cr = cairo_create(self._background_surface)
    -- clear surface
    cairo_save(cr)
    cairo_set_source_rgba(cr, 0, 0, 0, 0)
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE)
    cairo_paint(cr)

    if DEBUG then
        cairo_set_source_rgba(cr, 1, 0, 0, 1)
        ch.set_font(cr, "Ubuntu", 8)
        ch.write_left(cr, 0, 8, table.concat{"conky ", conky_version, " ", _VERSION})
        for _, w in ipairs(self._render_widgets) do
            cairo_rectangle(cr, unpack(w, 2))
        end
        cairo_set_line_width(cr, 1)
        cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
        cairo_set_source_rgba(cr, 1, 0, 0, 0.33)
        cairo_stroke(cr)
    end
    cairo_restore(cr)

    for _, w in ipairs(self._render_widgets) do
        cairo_save(cr)
        cairo_translate(cr, w[2], w[3])
        w[1]:render_background(cr)
        cairo_restore(cr)
    end
    cairo_destroy(cr)
end

--- Update all Widgets
function Renderer:update()
    local reflow = false
    for _, w in ipairs(self._render_widgets) do
        reflow = w[1]:update(cr) or reflow
    end
    if reflow then
        self:layout()
    end
end

--- Render to the given context
-- @tparam cairo_t cr
function Renderer:render(cr)
    cairo_set_source_surface(cr, self._background_surface, 0, 0)
    cairo_paint(cr)
    for _, w in ipairs(self._render_widgets) do
        cairo_save(cr)
        cairo_translate(cr, w[2], w[3])
        w[1]:render(cr)
        cairo_restore(cr)
    end
end


--- Base Widget class.
-- @type Widget
local Widget = util.class()

--- Called at least once to inform the widget of its width and height.
-- @tparam int width
function Widget:layout(width, height) end

--- Called at least once to allow the widget to draw static content.
-- @tparam cairo_t cr Cairo context for background rendering
--                    (to be cached by the `Renderer`)
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


--- Basic collection of widgets.
-- Grouped widgets are drawn in a vertical stack,
-- starting at the top of the drawble surface.
-- @type Group
local Group = util.class(Widget)

--- @tparam {Widget,...} widgets
function Group:init(widgets)
    self._widgets = widgets
    local width = 0
    local fix_width = false
    self._min_height = 0
    self._fillers = 0
    for _, w in ipairs(widgets) do
        if w.width then
            fix_width = true
            if w.width > width then width = w.width end
        end
        if w.height then
            self._min_height = self._min_height + w.height
        else
            self._fillers = self._fillers + 1
        end
    end
    -- if fix_width then
    --     self.width = width
    -- end
    if self._fillers == 0 then
        self.height = self._min_height
    end
end

function Group:layout(width, height)
    self._width = width  -- used to draw debug lines
    local y = 0
    local children = {{self, 0, 0, 0, 0}}  -- include self for subclasses
    local filler_height = (height - self._min_height) / self._fillers
    for _, w in ipairs(self._widgets) do
        local widget_height = w.height or filler_height
        local sub_children = w:layout(width, widget_height)
        if sub_children then
            for _, child in ipairs(sub_children) do
                child[3] = child[3] + y
                table.insert(children, child)
            end
        else
            table.insert(children, {w, 0, y, width, widget_height})
        end
        y = y + widget_height
    end
    return children
end


--- Display Widgets side by side
-- @type Columns
local Columns = util.class(Widget)

-- reuse an identical function

--- @tparam {Widget,...} widgets
function Columns:init(widgets)
    self._widgets = widgets
    self._min_width = 0
    self._fillers = 0
    local height = 0
    local fix_height = false
    for _, w in ipairs(widgets) do
        if w.width then
            self._min_width = self._min_width + w.width
        else
            self._fillers = self._fillers + 1
        end
        if w.height then
            fix_height = true
            if w.height > height then height = w.height end
        end
    end
    if self._fillers == 0 then
        self.width = self._min_width
    end
    if fix_height then
        self.height = height
    end
end


function Columns:layout(width, height)
    self._height = height  -- used to draw debug lines
    local x = 0
    local children = {{self, 0, 0, 0, 0}}  -- include self for subclasses
    local filler_width = (width - self._min_width) / self._fillers
    for _, w in ipairs(self._widgets) do
        local widget_width = w.width or filler_width
        local sub_children = w:layout(widget_width, height)
        if sub_children then
            for _, child in ipairs(sub_children) do
                child[2] = child[2] + x
                table.insert(children, child)
            end
        else
            table.insert(children, {w, x, 0, widget_width, height})
        end
        x = x + widget_width
    end
    return children
end


--- Leave enough vertical space between widgets to eventually fill the entire
-- height of the drawable surface. Available space will be distributed evenly
-- between all Filler Widgets.
-- @type Filler
local Filler = util.class(Widget)

--- no options
-- @function Filler:init


--- Leave a fixed amount of space between widgets.
-- @type Gap
local Gap = util.class(Widget)

--- @int height Amount of vertical space in pixels
function Gap:init(size)
    self.height = size
    self.width = size
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

    self._x_offset = self._padding.left
                     + (self._border_sides.left and self._border_width or 0)
    self._y_offset = self._padding.top
                     + (self._border_sides.top and self._border_width or 0)
    self._horizontal_space = self._x_offset + self._padding.right
                             + (self._border_sides.right and self._border_width or 0)
    self._vertical_space = self._y_offset + self._padding.bottom
                           + (self._border_sides.bottom and self._border_width or 0)

    if widget.width then
        self.width = widget.width + self._horizontal_space
    end
    if widget.height then
        self.height = widget.height + self._vertical_space
    end
end

function Frame:layout(width, height)
    self._width = width
    self._height = height
    local inner_width = width - self._horizontal_space
    local inner_height = height - self._vertical_space
    local children = self._widget:layout(inner_width, inner_height)
    if children then
        for _, child in ipairs(children) do
            child[2] = child[2] + self._x_offset
            child[3] = child[3] + self._y_offset
        end
        table.insert(children, 1, {self, 0, 0, width, height})
        return children
    else
        return {
            {self, 0, 0, width, height},
            {self._widget, self._y_offset, self._x_offset,
                           inner_width, inner_height}
        }
    end
end

function Frame:render_background(cr)
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
    self.height = extents.height + 1
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
    self.height = self._thickness + 2
    self.color = args.color or default_graph_color

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
    self._total = args.total
    local ticks, big_ticks
    if self._total then
        local max_tick = math.floor(self._total)
        ticks = util.range(1 / self._total, max_tick / self._total, 1 / self._total)
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
    self:set_fill(used / self._total)
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
    self.height = args.height or 22
    self._inner_height = self.height - 2
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
    self._cores = args.cores
    self._scale = args.scale
    self._gap = args.gap
    self._segment_size = args.segment_size

    self.height = 2 * (self._scale + self._gap + self._segment_size)
    self.width = self.height
end

function Cpu:layout(width, height)
    self._mx = width / 2
    self._my = height / 2

    self._center_coordinates = {}
    self._segment_coordinates = {}
    self._gradient_coordinates = {}
    local sector_rad = 2 * math.pi / self._cores
    local min = self._scale + self._gap
    local max = min + self._segment_size

    for core = 1, self._cores do
        local rad_center = (core - 1) * sector_rad - math.pi/2
        local rad_left = rad_center + sector_rad/2
        local rad_right = rad_center - sector_rad/2
        local dx_center, dy_center = math.cos(rad_center), math.sin(rad_center)
        local dx_left, dy_left = math.cos(rad_left), math.sin(rad_left)
        local dx_right, dy_right = math.cos(rad_right), math.sin(rad_right)
        self._center_coordinates[2 * core - 1] = self._mx + self._scale * dx_left
        self._center_coordinates[2 * core] = self._my + self._scale * dy_left

        -- segment corners
        local dx_gap, dy_gap = self._gap * dx_center, self._gap * dy_center
        local x1 = self._mx + min * dx_left + dx_gap
        local y1 = self._my + min * dy_left + dy_gap
        local x2 = self._mx + max * dx_left + dx_gap
        local y2 = self._my + max * dy_left + dy_gap
        local x3 = self._mx + max * dx_right + dx_gap
        local y3 = self._my + max * dy_right + dy_gap
        local x4 = self._mx + min * dx_right + dx_gap
        local y4 = self._my + min * dy_right + dy_gap
        self._segment_coordinates[core] = {x1, y1, x2, y2, x3, y3, x4, y4}
        self._gradient_coordinates[core] = {(x1 + x4) / 2, (y1 + y4) / 2,
                                           (x2 + x3) / 2, (y2 + y3) / 2}
    end
    return self._height
end

function Cpu:update()
    self._percentages = data.cpu_percentages(self._cores)
    self._temperatures = data.cpu_temperatures()
end

function Cpu:render(cr)
    local avg_temperature = util.avg(self._temperatures)
    local r, g, b = temp_color(avg_temperature, 30, 80)

    ch.polygon(cr, self._center_coordinates)
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
    ch.write_middle(cr, self._mx + 1, self._my, string.format("%.0f°", avg_temperature))

    for core = 1, self._cores do
        ch.polygon(cr, self._segment_coordinates[core])
        local gradient = cairo_pattern_create_linear(unpack(self._gradient_coordinates[core]))
        local r, g, b = temp_color(self._temperatures[core], 30, 80)
        cairo_set_source_rgba(cr, 0, 0, 0, .4)
        cairo_set_line_width(cr, 1.5)
        cairo_stroke_preserve(cr)
        cairo_set_source_rgba(cr, r, g, b, .4)
        cairo_set_line_width(cr, .75)
        cairo_stroke_preserve(cr)

        local h_rel = self._percentages[core]/100
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
    self._rows = args.rows or 5
    self._point_size = args.point_size or 2
    self._gap = args.gap or 1
    self._shuffle = args.shuffle == nil and true or args.shuffle
    self.height = self._rows * self._point_size + (self._rows - 1) * self._gap
end

function MemoryGrid:layout(width)
    local point_plus_gap = self._point_size + self._gap
    local columns = math.floor(width / point_plus_gap)
    local left = 0.5 * (width - columns * point_plus_gap + self._gap)
    self._coordinates = {}
    for col = 0, columns - 1 do
        for row = 0, self._rows - 1 do
            table.insert(self._coordinates, {col * point_plus_gap + left,
                                            row * point_plus_gap,
                                            self._point_size, self._point_size})
        end
    end
    if shuffle == nil or shuffle then
        util.shuffle(self._coordinates)
    end
end

function MemoryGrid:update()
    self._used, self._easyfree, self._free, self._total = data.memory()
end

function MemoryGrid:render(cr)
    if self._total <= 0 then return end  -- TODO figure out why this happens
    local total_points = #self._coordinates
    local used_points = math.floor(total_points * self._used / self._total + 0.5)
    local cache_points = math.floor(total_points * (self._easyfree - self._free) / self._total + 0.5)
    local r, g, b = temp_color(self._used / self._total, 0.6, 0.9)

    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    for i = 1, used_points do
        cairo_rectangle(cr, unpack(self._coordinates[i]))
    end
    cairo_set_source_rgba(cr, r, g, b, .8)
    cairo_fill(cr)
    for i = used_points, used_points + cache_points do
        cairo_rectangle(cr, unpack(self._coordinates[i]))
    end
    cairo_set_source_rgba(cr, r, g, b, .35)
    cairo_fill(cr)
    for i = used_points + cache_points, total_points do
        cairo_rectangle(cr, unpack(self._coordinates[i]))
    end
    cairo_set_source_rgba(cr, r, g, b, .1)
    cairo_fill(cr)
end


--- Compound widget to display GPU and VRAM usage.
-- @type Gpu
local Gpu = util.class(Group)

--- no options
function Gpu:init()
    self._usebar = Bar{ticks={.25, .5, .75}, unit="%"}

    local _, mem_total = data.gpu_memory()
    self._membar = MemoryBar{total=mem_total / 1024}
    self._membar.update = function()
        self._membar:set_used(data.gpu_memory() / 1024)
    end
    Group.init(self, {self._usebar, Gap(4), self._membar})
end

function Gpu:update()
    self._usebar:set_fill(data.gpu_percentage() / 100)

    local color = {temp_color(data.gpu_temperature(), 30, 80)}
    self._usebar.color = color
    self._membar.color = color
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
    self.height = self._lines * self._line_height
    local line_spacing = extents.height - (extents.ascent + extents.descent)
    -- try to match conky's line spacing:
    self._baseline_offset = extents.ascent + 0.5 * line_spacing + 1
end

function GpuTop:layout(width)
    self._width = width
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
local Network = util.class(Group)

--- @tparam table args table of options
-- @string args.interface e.g. "eth0"
-- @tparam ?int args.graph_height passed to `Graph:init`
-- @number[opt=1024] args.downspeed passed as args.max to download speed graph
-- @number[opt=1024] args.upspeed passed as args.max to upload speed graph
function Network:init(args)
    self.interface = args.interface
    self._downspeed_graph = Graph{height=args.graph_height, max=args.downspeed or 1024}
    self._upspeed_graph = Graph{height=args.graph_height, max=args.upspeed or 1024}
    Group.init(self, {self._downspeed_graph, Gap(31), self._upspeed_graph})
end

function Network:update()
    local down, up = data.network_speed(self.interface)
    self._downspeed_graph:add_value(down)
    self._upspeed_graph:add_value(up)
end

--- Visualize drive usage and temperature in a colorized Bar.
-- Also writes temperature as text.
-- This widget is exptected to be combined with some special conky.text.
-- @type Drive
local Drive = util.class(Group)

---
-- @string path e.g. "/home"
-- @string device_name e.g. "/dev/sda1"
function Drive:init(path, device_name)
    self.path = path
    self.device_name = device_name

    self._temperature_text = TextLine{align="right"}
    self._bar = Bar{}
    Group.init(self, {self._temperature_text,
                            Gap(4),
                            self._bar,
                            Gap(25)})
    self._real_height = self.height
    self._is_mounted = data.is_mounted(self.path)
    self.height = self._is_mounted and self._real_height or 0
end

function Drive:layout(...)
    if self._is_mounted then
        return {{self, 0, 0, 0, 0}, unpack(Group.layout(self, ...))}
    else
        return {{self, 0, 0, 0, 0}}
    end
end

function Drive:update()
    local was_mounted = self._is_mounted
    self._is_mounted = data.is_mounted(self.path)
    if self._is_mounted then
        self._bar:set_fill(data.drive_percentage(self.path) / 100)
        local temperature = data.hddtemp()[self.device_name]
        if temperature then
            self._bar.color = {temp_color(temperature, 35, 65)}
            self._temperature_text:set_text(temperature .. "°C")
        else
            self._bar.color = {0.8, 0.8, 0.8}
            self._temperature_text:set_text("––––")
        end
        self.height = self._real_height
    else
        self.height = 0
    end
    return self._is_mounted ~= was_mounted
end


return {
    Bar = Bar,
    Columns = Columns,
    Cpu = Cpu,
    CpuFrequencies = CpuFrequencies,
    Drive = Drive,
    Filler = Filler,
    Frame = Frame,
    Gap = Gap,
    Gpu = Gpu,
    GpuTop = GpuTop,
    Graph = Graph,
    Group = Group,
    MemoryBar = MemoryBar,
    MemoryGrid = MemoryGrid,
    Network = Network,
    Renderer = Renderer,
    TextLine = TextLine,
    Widget = Widget,
}
