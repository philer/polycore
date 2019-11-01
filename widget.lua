local data = require 'data'
local util = require 'util'
local ch = require 'cairo_helpers'


-- Root widget wrapper
-- Takes care of managing layout reflows and background caching.
local WidgetRenderer = util.class()

function WidgetRenderer:init(args)
    self.root = args.root
    self.width = args.width
    self.height = args.height
    self.padding = args.padding
    self._background_surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32,
                                                          args.width,
                                                          args.height)
end

function WidgetRenderer:layout()
    print("layout reflow…")
    self.root:layout(self.width - 2 * self.padding)

    local cr = cairo_create(self._background_surface)

    -- clear surface
    cairo_save (cr)
    cairo_set_source_rgba(cr, 0, 0, 0, 0)
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE)
    cairo_paint(cr)
    cairo_restore(cr)

    if DEBUG then
        cairo_set_source_rgba(cr, 1, 0, 0, 1)
        cairo_select_font_face(cr, "Ubuntu", CAIRO_FONT_SLANT_NORMAL,
                                             CAIRO_FONT_WEIGHT_NORMAL)
        cairo_set_font_size(cr, 8)
        ch.write_left(cr, 0, 8, table.concat{"conky ", conky_version, " ", _VERSION})
    end

    cairo_translate(cr, self.padding, self.padding)
    self.root:render_background(cr)
    cairo_destroy(cr)
end

function WidgetRenderer:update()
    if self.root:update() then self:layout() end
end

function WidgetRenderer:render(cr)
    cairo_set_source_surface(cr, self._background_surface, 0, 0)
    cairo_paint(cr)
    cairo_translate(cr, self.padding, self.padding)
    self.root:render(cr)
end


-- Base Widget class
local Widget = util.class()

-- Every widget needs a height used by the layout engine to correctly position
-- each widget
Widget.height = 0

-- Called at least once to inform the widget of its width
function Widget:layout(width) end

-- Called at least once to allow the widget to draw static content
function Widget:render_background(cr) end

-- Called before each call to :render(cr).
-- If this function returns a true-ish value, a reflow will be triggered.
-- Since this involves calls to all widgets' :layout functions,
-- reflows should be used sparingly.
function Widget:update() return false end

-- Called once per update to do draw dynamic content
function Widget:render(cr) end


-- Basic combination of widgets. Grouped widgets are drawn in a vertical stack,
-- starting at the top of the drawble surface.
local WidgetGroup = util.class(Widget)

function WidgetGroup:init(widgets)
    self._widgets = widgets
    self.height = 0
    for _, w in ipairs(widgets) do
        self.height = self.height + w.height
    end
end

function WidgetGroup:layout(width)
    self._width = width  -- used to draw debug lines
    for _, w in ipairs(self._widgets) do
        w:layout(width)
    end
end

function WidgetGroup:render_background(cr)
    if DEBUG then
        local y_offset = 0
        for _, w in ipairs(self._widgets) do
            cairo_rectangle(cr, 0, y_offset, self._width, w.height)
            y_offset = y_offset + w.height
        end
        cairo_set_line_width(cr, 1)
        cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
        cairo_set_source_rgba(cr, 1, 0, 0, 0.33)
        cairo_stroke(cr)
    end

    cairo_save(cr)
    for _, w in ipairs(self._widgets) do
        w:render_background(cr)
        cairo_translate(cr, 0, w.height)
    end
    cairo_restore(cr)
end

function WidgetGroup:update()
    local reflow = false
    for _, w in ipairs(self._widgets) do
        reflow = w:update() or reflow
    end
    return reflow
end

function WidgetGroup:render(cr)
    cairo_save(cr)
    for _, w in ipairs(self._widgets) do
        w:render(cr)
        cairo_translate(cr, 0, w.height)
    end
    cairo_restore(cr)
end


-- Leave some space between widgets
local Gap = util.class(Widget)

function Gap:init(height)
    self.height = height
end


-- Draw a border on the right side of the described area.
-- Arguments:
--   x_offset, height: described area
local BorderRight = util.class(Widget)

function BorderRight:init(args)
    self._x = args.x
    self._height = args.height
end

function BorderRight:render_background(cr)
    cairo_save(cr)
    cairo_identity_matrix(cr)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    cairo_set_line_width(cr, 1)
    cairo_set_source_rgba(cr, 0.8, 1, 1, 0.05)
    cairo_move_to(cr, self._x - 0.5, 0)
    cairo_line_to(cr, self._x - 0.5, self._height)
    cairo_stroke(cr)
    cairo_restore(cr)
end


-- Draw a single line changeable of text.
-- Use this widget for text that will be updated on each cycle.
local TextLine = util.class(Widget)

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


-- Progress-bar like box. Can have small and big ticks for visual clarity,
-- and a unit (static, up to 3 characters) written behind the end.
local Bar = util.class(Widget)

function Bar:init(args)
    self.ticks = args.ticks
    self.big_ticks = args.big_ticks
    self.unit = args.unit
    self.thickness = args.thickness or 5
    self.color = args.color or default_graph_color

    self.height = self.thickness
    if self.ticks then
        self.height = self.height + (self.big_ticks and 5 or 4)
    end
    if self.unit then
        self.height = math.max(self.height, 8)  -- line_height
    end
end

function Bar:layout(width)
    self._width = width - (self.unit and 20 or 0)

    self._ticks = {}
    if self.ticks then
        local x, tick_length
        for i, frac in ipairs(self.ticks) do
            x = math.floor(frac * self._width) + 0.5
            tick_length = 3
            if self.big_ticks then
                if self.big_ticks[i] then
                    tick_length = 4
                else
                    tick_length = 2
                end
            end
            table.insert(self._ticks, {x, self.thickness + 0.5, tick_length})
        end
    end
end

function Bar:render_background(cr)
    if self.unit then
        ch.font_normal(cr)
        cairo_set_source_rgba(cr, unpack(default_text_color))
        ch.write_left(cr, self._width + 5, 6, self.unit)
    end
end

function Bar:set_fill(fraction)
    self.fraction = fraction
end

function Bar:render(cr)
    local r, g, b = unpack(self.color)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    cairo_rectangle(cr, 0, 0, self._width, self.thickness)
    ch.alpha_gradient(cr, 0, 0, self._width, 0, r, g, b, {
        self.fraction - 0.33, 0.33,
        self.fraction - 0.08, 0.66,
        self.fraction - 0.01, 0.75,
        self.fraction, 1,
        self.fraction + 0.01,  0.2,
        self.fraction + 0.1,  0.1,
        1, 0.15,
    })
    cairo_fill_preserve(cr)

    cairo_set_line_width(cr, 1)

    --- fake shadow border ---
    cairo_set_source_rgba(cr, 0, 0, 0, .66)
    cairo_stroke(cr)

    --- border ---
    cairo_rectangle(cr, 1, 1, self._width - 2, self.thickness - 2)
    cairo_set_source_rgba(cr, r, g, b, .2)
    cairo_stroke(cr)

    --- ticks ---
    for _, tick in ipairs(self._ticks) do
        cairo_move_to(cr, tick[1], tick[2])
        cairo_rel_line_to(cr, 0, tick[3])
    end
    cairo_set_source_rgba(cr, r, g, b, .5)
    cairo_stroke(cr)
end


-- Specialized unit-based Bar
local MemoryBar = util.class(Bar)

function MemoryBar:init(args)
    local total = args.total
    local ticks = util.range(1 / total, math.floor(total) / total, 1 / total)
    -- ticks = util.range(1/16, 15/16, 1/16)
    Bar.init(self, {ticks=ticks, unit=args.unit or "GiB", color=args.color})

    self.total = math.ceil(total)
    if self.total > 8 then
        self.big_ticks = {}
        for offset = 4, self.total, 4 do
            self.big_ticks[offset] = offset
        end
    end
end

function MemoryBar:set_used(used)
    Bar:set_fill(used / self.total)
end


-- Track changing data
local Graph = util.class(Widget)

function Graph:init(args)
    self.height = args.height or 20
    self.max = args.max
    self.upside_down = args.upside_down
    self.data = util.CycleQueue(args.data_points or 90)
    self.color = args.color or default_graph_color
end

function Graph:layout(width)
    self.width = width
    self.x_scale = 1 / self.data.length * width
    self.y_scale = 1 / self.max * self.height
    if self.upside_down then
        self.y_scale = -self.y_scale
        self.y_start = -0.5
    else
        self.y_start = self.height - 0.5
    end
end

function Graph:render_background(cr)
    local r, g, b = unpack(self.color)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    cairo_set_line_width(cr, 1)

    --- background shadow ---
    cairo_rectangle(cr, -1, -1, self.width + 2, self.height + 2)
    cairo_set_source_rgba(cr, 0, 0, 0, .33)
    cairo_stroke(cr)

    --- background ---
    cairo_rectangle(cr, 0, 0, self.width, self.height)
    ch.alpha_gradient(cr, 0, 0, 0, self.height, r, g, b, {
        .1, .14, .1, .06, .2, .06, .2, .14,
        .3, .14, .3, .06, .4, .06, .4, .14,
        .5, .14, .5, .06, .6, .06, .6, .14,
        .7, .14, .7, .06, .8, .06, .8, .14,
        .9, .14, .9, .06,
    })
    cairo_fill_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, .2)
    cairo_stroke(cr)
end

function Graph:add_value(value)
    self.data:put(value)
    if value > self.max then
        self.max = value
        self:layout(self.width)
    end
end

function Graph:render(cr)
    local r, g, b = unpack(self.color)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT)

    cairo_move_to(cr, 0, self.y_start)
    local current_max = 0
    self.data:each(function(val, idx)
        cairo_line_to(cr, (idx - 1) * self.x_scale, self.y_start - val * self.y_scale)
        if val > current_max then current_max = val end
    end)
    cairo_line_to(cr, self.width, self.y_start)
    cairo_set_source_rgba(cr, r, g, b, 1)
    cairo_set_line_width(cr, .5)
    cairo_stroke_preserve(cr)

    --- fill under graph ---
    ch.alpha_gradient(cr, 0, self.y_start - current_max * self.y_scale,
                       0, self.y_start,
                       r, g, b, {0, .66, .5, .33, 1, .25})
    cairo_fill(cr)
end


-- Polygon-style CPU usage & temperature tracking
local Cpu = util.class(Widget)

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

    cairo_select_font_face(cr, default_font_family, CAIRO_FONT_SLANT_NORMAL,
                                                    CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, 16)
    cairo_set_source_rgba(cr, r, g, b, .4)
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


-- Visualize cpu-frequencies in a style reminiscent of stacked progress bars.
local CpuFrequencies = util.class(Widget)

function CpuFrequencies:init(args)
    self.cores = args.cores
    self.min_freq = args.min_freq
    self.max_freq = args.max_freq
    self._height = args.height or 16
    self.height = self._height + 10
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
            table.insert(self._tick_labels, {x, self._height + 10.5, freq})
        end
        table.insert(self._ticks, {math.floor(x) + .5,
                                   self._height + 1.5,
                                   big and 3 or 2})
    end
end

function CpuFrequencies:render_background(cr)
    ch.font_normal(cr)
    cairo_set_source_rgba(cr, unpack(default_text_color))
    ch.write_left(cr, self._width + 5, 0.5 * self._height + 3, "GHz")

    --- shadow outline
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
    ch.font_normal(cr)
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


-- Visualize memory usage in a randomized grid. Does not represent actual
-- distribution of used memory.
-- Also shows buffere/cache memory at reduced brightness.
local MemoryGrid = util.class(Widget)

function MemoryGrid:init(args)
    self.rows = args.rows
    self.columns = args.columns
    self.point_size = args.point_size or 2
    self.gap = args.gap or 1
    self.shuffle = args.shuffle == nil and true or args.shuffle
    self.height = self.rows * self.point_size + (self.rows - 1) * self.gap
end

function MemoryGrid:layout(width)
    self.coordinates = {}
    local point_plus_gap = self.point_size + self.gap
    for col = 0, self.columns - 1, 1 do
        for row = 0, self.rows - 1, 1 do
            table.insert(self.coordinates, {col * point_plus_gap,
                                            row * point_plus_gap,
                                            self.point_size, self.point_size})
        end
    end
    if shuffle == nil or shuffle then
        util.shuffle(self.coordinates)
    end
end

function MemoryGrid:update()
    self.used, self.easyfree, self.free, self.total = data.memory()
end

function MemoryGrid:render(cr)
    local total_points = #self.coordinates
    local used_points = math.floor(total_points * self.used / self.total + 0.5)
    local cache_points = math.floor(total_points * (self.easyfree - self.free) / self.total + 0.5)
    local r, g, b = unpack(default_graph_color)  -- TODO color manager

    if self.used / self.total > 0.7 then
        if self.used / self.total > 0.85 then
            r, g, b = unpack(temperature_colors[#temperature_colors])
        else
            r, g, b = unpack(temperature_colors[#temperature_colors - 1])
        end
    end

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


-- Compound widget to display GPU and VRAM usage.
local Gpu = util.class(WidgetGroup)

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

    local color = util.pack(temp_color(data.gpu_temperature(), 30, 80))
    self.usebar.color = color
    self.membar.color = color
end


local GpuTop = util.class(Widget)

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


local Network = util.class(WidgetGroup)

function Network:init(args)
    self.interface = args.interface
    self.downspeed_graph = Graph{height=args.graph_height, max=downspeed or 1024}
    self.upspeed_graph = Graph{height=args.graph_height, max=upspeed or 1024}
    WidgetGroup.init(self, {self.downspeed_graph, Gap(33), self.upspeed_graph})
end

function Network:update()
    local down, up = data.network_speed(self.interface)
    self.downspeed_graph:add_value(down)
    self.upspeed_graph:add_value(up)
end

-- Visualize drive usage and temperature in a colorized Bar.
-- Also writes temperature as text.
-- This widget is exptected to be combined with some special conky.text.
local Drive = util.class(WidgetGroup)

function Drive:init(path, device_name)
    self.path = path
    self.device_name = device_name

    self._temperature_text = TextLine{align="right"}
    self._bar = Bar{}
    WidgetGroup.init(self, {self._temperature_text,
                            Gap(3),
                            self._bar,
                            Gap(28)})
    self._height = self.height
    self.is_mounted = data.is_mounted(self.path)
    if not self.is_mounted then
        self.height = 0
    end
end

function Drive:render_background(cr)
    if self.is_mounted then
        WidgetGroup.render_background(self, cr)
    end
end

function Drive:update()
    local was_mounted = self.is_mounted
    self.is_mounted = data.is_mounted(self.path)
    if self.is_mounted then
        self._bar:set_fill(data.drive_percentage(self.path) / 100)
        self.temperature = data.hddtemp()[self.device_name]
        self.height = self._height
    else
        self.height = 0
    end
    return self.is_mounted ~= was_mounted
end

function Drive:render(cr)
    if not self.is_mounted then
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
    BorderRight = BorderRight,
    Cpu = Cpu,
    CpuFrequencies = CpuFrequencies,
    Drive = Drive,
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
