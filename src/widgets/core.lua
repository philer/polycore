--- A collection of Widget classes
-- @module widget_core
-- @alias wc

pcall(function() require('cairo') end)

local data = require('src/data')
local util = require('src/util')
local ch = require('src/cairo_helpers')

-- lua 5.1 to 5.3 compatibility
local unpack = unpack or table.unpack  -- luacheck: read_globals unpack table

local sin, cos, tan, PI = math.sin, math.cos, math.tan, math.pi
local floor, ceil, clamp = math.floor, math.ceil, util.clamp

-- abort with an error if no theme is set
if not current_theme then
    error("No Theme Set, please set the current_theme variable")
end

w = {}
--- Generate a temperature based color.
-- Colors are chosen based on float offset in a pre-defined color gradient.
-- @number temperature current temperature (or any other type of numeric value)
-- @number low threshold for lowest temperature / coolest color
-- @number high threshold for highest temperature / hottest color
function w.temperature_color(temperature, low, high)
    -- defaults in case temperature is nil
    local cool = current_theme.temperature_colors[1]
    local hot = current_theme.temperature_colors[1]
    local weight = 0
    if type(temperature) == "number" and temperature > -math.huge and temperature < math.huge then
        local idx = (temperature - low) / (high - low) * (#current_theme.temperature_colors - 1) + 1
        weight = idx - floor(idx)
        cool = current_theme.temperature_colors[clamp(1, #current_theme.temperature_colors, floor(idx))]
        hot = current_theme.temperature_colors[clamp(1, #current_theme.temperature_colors, ceil(idx))]
    end
    return cool[1] + weight * (hot[1] - cool[1]),
           cool[2] + weight * (hot[2] - cool[2]),
           cool[3] + weight * (hot[3] - cool[3])
end


--- Root widget wrapper
-- Takes care of managing layout reflows and background caching.
-- @type Renderer
local Renderer = util.class()
w.Renderer = Renderer

---
-- @tparam table args table of options
-- @tparam Widget args.root The Widget subclass that should be rendered,
--                          usually a Rows widget
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
    local widgets = self._root:layout(self._width, self._height) or {}
    table.insert(widgets, 1, {self._root, 0, 0, self._width, self._height})

    local background_widgets = {}
    self._update_widgets = {}
    self._render_widgets = {}
    for widget, x, y, _width, _height in util.imap(unpack, widgets) do
        if widget.render_background then
            local wsr = cairo_surface_create_for_rectangle(self._background_surface,
                            floor(x),floor(y),floor(_width),floor(_height))
            table.insert(background_widgets, {widget, wsr})
        end
        if widget.render then
            local wsr = cairo_surface_create_for_rectangle(self._background_surface,
                            floor(x),floor(y),floor(_width),floor(_height))
            local wcr = cairo_create(wsr)
            table.insert(self._render_widgets, {widget, wsr})
        end
        if widget.update then
            table.insert(self._update_widgets, widget)
        end
    end

    local cr = cairo_create(self._background_surface)
    -- clear surface
    cairo_save(cr)
    cairo_set_source_rgba(cr, 0, 0, 0, 0)
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE)
    cairo_paint(cr)
    cairo_restore(cr)

    for widget, wsr in util.imap(unpack, background_widgets) do
        local wcr = cairo_create(wsr)
        cairo_save(wcr)
        widget:render_background(wcr)
        cairo_restore(wcr)
        cairo_destroy(wcr)
    end

    if DEBUG then
        local version_info = table.concat{"conky ", conky_version,
                                          "    ", _VERSION,
                                          "    cairo ", cairo_version_string()}
        cairo_set_source_rgba(cr, 1, 0, 0, 1)
        ch.set_font(cr, "Ubuntu", 8)
        ch.write_left(cr, 0, 8, version_info)
        for _, x, y, width, height in util.imap(unpack, widgets) do
            if width * height ~= 0 then
                cairo_rectangle(cr, x, y, width, height)
            end
        end
        cairo_set_line_width(cr, 1)
        cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
        cairo_set_source_rgba(cr, 1, 0, 0, 0.33)
        cairo_stroke(cr)
    end

    cairo_destroy(cr)
end

--- Update all Widgets
-- @int update_count Conky's $updates
function Renderer:update(update_count)
    local reflow = false
    for _, widget in ipairs(self._update_widgets) do
        reflow = widget:update(update_count) or reflow
    end
    if reflow then
        self:layout()
    end
end

function Renderer:paint_background(cr)
    cairo_set_source_surface(cr, self._background_surface, 0, 0)
    cairo_paint(cr)
end

--- Render to the given context
-- @tparam cairo_t cr
function Renderer:render(cr)
    for widget, wsr in util.imap(unpack, self._render_widgets) do
        local wcr = cairo_create(wsr)
        cairo_save(wcr)
        cairo_set_source_rgba (wcr, 0, 0, 0, 0);
        cairo_set_operator (wcr, CAIRO_OPERATOR_SOURCE);
        cairo_paint(wcr)
        -- Unfortunately the background gets cleared and needs to be
        -- redrawn otherwise the widget draws the new content over the old
        if widget.render_background then
            cairo_save(wcr)
            widget:render_background(wcr)
            cairo_restore(wcr)
        end
        widget:render(wcr)
        cairo_destroy(wcr)
    end
end


--- Base Widget class.
-- @type Widget
local Widget = util.class()
w.Widget = Widget

--- Set a width if the Widget should have a fixed width.
-- Omit (=nil) if width should be adjusted dynamically.
-- @int Widget.width

--- Set a height if the Widget should have a fixed height.
-- Omit (=nil) if height should be adjusted dynamically.
-- @int Widget.height

--- Called at least once to inform the widget of the width and height
-- it may occupy.
-- @tparam int width
-- @tparam int height
function Widget:layout(width, height) end  -- luacheck: no unused

--- Called at least once to allow the widget to draw static content.
-- @function Widget:render_background
-- @tparam cairo_t cr Cairo context for background rendering
--                    (to be cached by the `Renderer`)

--- Called before each call to `Widget:render`.
-- If this function returns a true-ish value, a reflow will be triggered.
-- Since this involves calls to all widgets' :layout functions,
-- reflows should be used sparingly.
-- @function Widget:update
-- @int update_count Conky's $updates
-- @treturn ?bool true(-ish) if a layout reflow should be triggered, causing
--                all `Widget:layout` and `Widget:render_background` methods
--                to be called again

--- Called once per update to do draw dynamic content.
-- @function Widget:render
-- @tparam cairo_t cr


--- Basic collection of widgets.
-- Rows are drawn in a vertical stack starting at the top of the drawble
-- surface.
-- @type Rows
local Rows = util.class(Widget)
w.Rows = Rows

--- @tparam {Widget,...} widgets
function Rows:init(widgets)
    self._widgets = widgets
    local width = 0
    self._min_height = 0
    self._fillers = 0
    for _, widget in ipairs(widgets) do
        if widget.width then
            if widget.width > width then width = widget.width end
        end
        if widget.height ~= nil then
            self._min_height = self._min_height + widget.height
        else
            self._fillers = self._fillers + 1
        end
    end
    if self._fillers == 0 then
        self.height = self._min_height
    end
end

function Rows:layout(width, height)
    self._width = width  -- used to draw debug lines
    local y = 0
    local children = {}
    local filler_height = (height - self._min_height) / self._fillers
    for _, widget in ipairs(self._widgets) do
        local widget_height = widget.height or filler_height
        table.insert(children, {widget, 0, y, width, widget_height})
        local sub_children = widget:layout(width, widget_height) or {}
        for _, child in ipairs(sub_children) do
            child[3] = child[3] + y
            table.insert(children, child)
        end
        y = y + widget_height
    end
    return children
end


--- Display Widgets side by side
-- @type Columns
local Columns = util.class(Widget)
w.Columns = Columns

-- reuse an identical function

--- @tparam {Widget,...} widgets
function Columns:init(widgets)
    self._widgets = widgets
    self._min_width = 0
    self._fillers = 0
    local height = 0
    local fix_height = false
    for _, widget in ipairs(widgets) do
        if widget.width ~= nil then
            self._min_width = self._min_width + widget.width
        else
            self._fillers = self._fillers + 1
        end
        if widget.height then
            fix_height = true
            if widget.height > height then height = widget.height end
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
    local children = {}
    local filler_width = (width - self._min_width) / self._fillers
    for _, widget in ipairs(self._widgets) do
        local widget_width = widget.width or filler_width
        table.insert(children, {widget, x, 0, widget_width, height})
        local sub_children = widget:layout(widget_width, height) or {}
        for _, child in ipairs(sub_children) do
            child[2] = child[2] + x
            table.insert(children, child)
        end
        x = x + widget_width
    end
    return children
end


--- Leave space between widgets.
-- If either height or width is not specified, the available space
-- inside a Rows or Columns widget will be distributed evenly between Fillers
-- with no fixed height/width.
-- A Filler may contain one other Widget which will have its dimensions
-- restricted to those of the Filler.
-- @type Filler
local Filler = util.class(Widget)
w.Filler = Filler

--- @tparam ?table args table of options
-- @tparam ?int args.width
-- @tparam ?int args.height
-- @tparam ?Widget args.widget
function Filler:init(args)
    if args then
        self._widget = args.widget
        self.height = args.height or (self._widget and self._widget.height)
        self.width = args.width or (self._widget and self._widget.width)
    end
end

function Filler:layout(width, height)
    if self._widget then
        local children = self._widget:layout(width, height) or {}
        table.insert(children, 1, {self._widget, 0, 0, width, height})
        return children
    end
end


local function side_widths(arg)
    arg = arg or 0
    if type(arg) == "number" then
        return {top=arg, right=arg, bottom=arg, left=arg}
    elseif #arg == 2 then
        return {top=arg[1], right=arg[2], bottom=arg[1], left=arg[2]}
    elseif #arg == 3 then
        return {top=arg[1], right=arg[2], bottom=arg[3], left=arg[2]}
    elseif #arg == 4 then
        return {top=arg[1], right=arg[2], bottom=arg[3], left=arg[4]}
    end
end


--- Draw a static border and/or background around/behind another widget.
-- @type Frame
local Frame = util.class(Widget)
w.Frame = Frame

--- @tparam Widget widget Widget to be wrapped
-- @tparam table args table of options
-- @tparam ?number|{number,...} args.padding Leave some space around the inside
--  of the frame.<br>
--  - number: same padding all around.<br>
--  - table of two numbers: {top & bottom, left & right}<br>
--  - table of three numbers: {top, left & right, bottom}<br>
--  - table of four numbers: {top, right, bottom, left}
-- @tparam ?number|{number,...} args.margin Like padding but outside the border.
-- @tparam ?{number,number,number,number} args.background_color
-- @tparam[opt=transparent] ?{number,number,number,number} args.border_color
-- @tparam[opt=0] ?number args.border_width border line width
-- @tparam ?{string,...} args.border_sides any combination of
--                                         "top", "right", "bottom" and/or "left"
--                                         (default: all sides)
function Frame:init(widget, args)
    self._widget = widget
    self._background_color = args.background_color or nil
    self._border_color = args.border_color or {0, 0, 0, 0}
    self._border_width = args.border_width or 0

    self._padding = side_widths(args.padding)
    self._margin = side_widths(args.margin)
    self._border_sides = util.set(args.border_sides or {"top", "right", "bottom", "left"})

    self._has_background = self._background_color and self._background_color[4] > 0
    self._has_border = self._border_width > 0
                       and (not args.border_sides or #args.border_sides > 0)

    self._x_left = self._margin.left + self._padding.left
                   + (self._border_sides.left and self._border_width or 0)
    self._y_top = self._margin.top + self._padding.top
                  + (self._border_sides.top and self._border_width or 0)
    self._x_right = self._margin.right + self._padding.right
                    + (self._border_sides.right and self._border_width or 0)
    self._y_bottom = self._margin.bottom + self._padding.bottom
                     + (self._border_sides.bottom and self._border_width or 0)

    if widget.width then
        self.width = widget.width + self._x_left + self._x_right
    end
    if widget.height then
        self.height = widget.height + self._y_top + self._y_bottom
    end
end

function Frame:layout(width, height)
    self._width = width - self._margin.left - self._margin.right
    self._height = height - self._margin.top - self._margin.bottom
    local inner_width = width - self._x_left - self._x_right
    local inner_height = height - self._y_top - self._y_bottom
    local children = self._widget:layout(inner_width, inner_height) or {}
    for _, child in ipairs(children) do
        child[2] = child[2] + self._x_left
        child[3] = child[3] + self._y_top
    end
    table.insert(children, 1, {self._widget, self._x_left, self._y_top, inner_width, inner_height})
    return children
end

function Frame:render_background(cr)
    if self._has_background then
        cairo_rectangle(cr, self._margin.left, self._margin.top, self._width, self._height)
        cairo_set_source_rgba(cr, unpack(self._background_color))
        cairo_fill(cr)
    end

    if self._has_border then
        cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
        cairo_set_line_cap(cr, CAIRO_LINE_CAP_SQUARE)
        cairo_set_source_rgba(cr, unpack(self._border_color))
        cairo_set_line_width(cr, self._border_width)
        local x_min = self._margin.left + 0.5 * self._border_width
        local y_min = self._margin.top + 0.5 * self._border_width
        local x_max = self._margin.left + self._width - 0.5 * self._border_width
        local y_max = self._margin.top + self._height - 0.5 * self._border_width
        local side, line, move = self._border_sides, cairo_line_to, cairo_move_to
        cairo_move_to(cr, x_min, y_min);
        (side.top and line or move)(cr, x_max, y_min);
        (side.right and line or move)(cr, x_max, y_max);
        (side.bottom and line or move)(cr, x_min, y_max);
        (side.left and line or move)(cr, x_min, y_min);
        cairo_stroke(cr, self._background_color)
    end
end

return w
