--- A collection of CPU Widget classes
-- @module widget_cpu
-- @alias wcpu

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

--- Polygon-style CPU usage & temperature indicator.
-- Looks best for CPUs with 4 to 8 cores but also works for higher numbers.
-- @type Cpu
local Cpu = util.class(Widget)
w.Cpu = Cpu

--- @tparam table args table of options
-- @int args.cores How many cores does your CPU have?
-- @int args.scale radius of central polygon
-- @int args.gap space between central polygon and outer segments
-- @int args.segment_size radial thickness of outer segments
function Cpu:init(args)
    self._cores = args.cores
    self._inner_radius = args.inner_radius
    self._outer_radius = args.outer_radius
    self._gap = args.gap or 4

    if self._outer_radius then
        self.height = 2 * self._outer_radius
        self.width = self.height
    end
end

function Cpu:layout(width, height)
    if not self._outer_radius then
        self._outer_radius = 0.5  * math.min(width, height)
    end
    if not self._inner_radius then
        self._inner_radius = 0.5 * self._outer_radius
    end
    self._mx = width / 2
    self._my = height / 2

    self._center_coordinates = {}
    self._segment_coordinates = {}
    self._gradient_coordinates = {}
    local sector_rad = 2 * PI / self._cores
    local center_scale = self._inner_radius - 2.5  -- thick stroke
    local min = self._inner_radius
    local max = self._outer_radius - self._gap
    for core = 1, self._cores do
        local rad_center = (core - 1) * sector_rad - PI / 2
        local rad_left = rad_center + sector_rad / 2
        local rad_right = rad_center - sector_rad / 2
        local dx_center, dy_center = cos(rad_center), sin(rad_center)
        local dx_left, dy_left = cos(rad_left), sin(rad_left)
        local dx_right, dy_right = cos(rad_right), sin(rad_right)
        self._center_coordinates[2 * core - 1] = self._mx + center_scale * dx_left
        self._center_coordinates[2 * core] = self._my + center_scale * dy_left

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
end

function Cpu:update()
    self._percentages = data.cpu_percentages(self._cores)
    self._temperatures = data.cpu_temperatures()
end

function Cpu:render(cr)
    local avg_temperature = util.avg(self._temperatures)
    local r, g, b = w.temperature_color(avg_temperature, 30, 80)

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
    ch.set_font(cr, current_theme.default_font_family, 16, nil, CAIRO_FONT_WEIGHT_BOLD)
    ch.write_middle(cr, self._mx + 1, self._my, string.format("%.0f°", avg_temperature))

    for core = 1, self._cores do
        ch.polygon(cr, self._segment_coordinates[core])
        local gradient = cairo_pattern_create_linear(unpack(self._gradient_coordinates[core]))
        r, g, b = w.temperature_color(self._temperatures[core], 30, 80)
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


--- Round CPU usage & temperature indicator.
-- Best suited for CPUs with high core counts.
-- @type CpuRound
local CpuRound = util.class(Widget)
w.CpuRound = CpuRound

CpuRound.update = Cpu.update

--- @tparam table args table of options
-- @int args.cores How many cores does your CPU have?
-- @int args.inner_radius Size of inner circle
-- @int args.outer_radius Max radius for core at 100%
-- @int[opt] args.grid Number of grid lines to draw in the background.
function CpuRound:init(args)
    self._cores = args.cores
    self._inner_radius = args.inner_radius
    self._outer_radius = args.outer_radius
    self._grid = args.grid
    self._graph_color = ch.convert_string_to_rgba(current_theme.default_graph_color)

    if self._outer_radius then
        self.height = 2 * self._outer_radius
        self.width = self.height
    end
end

function CpuRound:layout(width, height)
    if not self._outer_radius then
        self._outer_radius = 0.5  * math.min(width, height)
    end
    if not self._inner_radius then
        self._inner_radius = 0.75 * self._outer_radius
    end
    self._center = {width / 2, height / 2}
    local sector_rad = 2 * PI / self._cores

    -- choose control points that best approximate a circle, see
    -- https://stackoverflow.com/questions/1734745/how-to-create-circle-with-b%C3%A9zier-curves
    local ctrl_length = 1.3333 * tan(0.25 * sector_rad)
    self._points = {}
    for core = 1, self._cores do
        local rad = (core - 1) * sector_rad
        local dx, dy = cos(rad), sin(rad)
        self._points[core] = {
            dx = dx,
            dy = dy,
            ctrl_left_dx = dx - dy * ctrl_length,
            ctrl_left_dy = dy + dx * ctrl_length,
            ctrl_right_dx = dx + dy * ctrl_length,
            ctrl_right_dy = dy - dx * ctrl_length,
        }
    end
    self._points[self._cores + 1] = self._points[1]  -- easy cycling
end

function CpuRound:render_background(cr)
    if not self._grid or self._grid < 1 then
        return
    end
    local mx, my = unpack(self._center)
    local gap = (self._outer_radius - self._inner_radius) / self._grid
    for line = 0, self._grid do
        local scale = self._inner_radius + gap * line
        cairo_move_to(cr, mx + self._points[1].dx * scale,
                          my + self._points[1].dy * scale)
        cairo_arc(cr, mx, my, scale, 0, 2 * PI)
    end
    for _, point in ipairs(self._points) do
        cairo_move_to(cr, mx + point.dx * self._inner_radius,
                          my + point.dy * self._inner_radius)
        cairo_line_to(cr, mx + point.dx * self._outer_radius,
                          my + point.dy * self._outer_radius)
    end
    local r, g, b = unpack(_graph_color)
    cairo_set_source_rgba(cr, r, g, b, 0.2)
    cairo_set_line_width(cr, 1)
    cairo_stroke(cr)
end

function CpuRound:render(cr)
    local avg_temperature = util.avg(self._temperatures)
    local avg_percentage = util.avg(self._percentages)
    local r, g, b = w.temperature_color(avg_temperature, 30, 80)
    local mx, my = unpack(self._center)

    -- glow
    ch.alpha_gradient_radial(cr, mx, my, self._inner_radius,
                                 mx, my,
                                 self._outer_radius * (1 + 0.5 * avg_percentage / 100),
                                 r, g, b, {0, 0, 0.05, 0.2, 1, 0})
    cairo_paint(cr)

    -- temperature text
    cairo_set_source_rgba(cr, r, g, b, 0.5)
    ch.set_font(cr, current_theme.default_font_family, 16, nil, CAIRO_FONT_WEIGHT_BOLD)
    ch.write_middle(cr, mx + 1, my, string.format("%.0f°", avg_temperature))

    -- inner fill
    cairo_new_path(cr)
    cairo_arc(cr, mx, my, self._inner_radius * 0.99, 0, 2 * PI)
    ch.alpha_gradient_radial(cr, mx - self._inner_radius * 0.5,
                                 my - self._inner_radius * 0.5,
                                 0,
                                 mx, my, self._inner_radius,
                                 r, g, b, {0, 0.4, 0.66, 0.15, 1, 0.1})
    cairo_fill(cr)

    -- usage curve
    local dr = self._outer_radius - self._inner_radius
    for core = 1, self._cores do
        local point = self._points[core]
        local scale = self._inner_radius + dr * self._percentages[core] / 100
        point.x = mx + point.dx * scale
        point.y = my + point.dy * scale
        point.ctrl_left_x = mx + point.ctrl_left_dx * scale
        point.ctrl_left_y = my + point.ctrl_left_dy * scale
        point.ctrl_right_x = mx + point.ctrl_right_dx * scale
        point.ctrl_right_y = my + point.ctrl_right_dy * scale
    end
    cairo_move_to(cr, self._points[1].x, self._points[1].y)
    for core = 1, self._cores do
        local current, next = self._points[core], self._points[core + 1]
        cairo_curve_to(cr, current.ctrl_left_x,
                           current.ctrl_left_y,
                           next.ctrl_right_x,
                           next.ctrl_right_y,
                           next.x,
                           next.y)
    end
    cairo_close_path(cr)

    ch.alpha_gradient_radial(cr, mx, my, self._inner_radius,
                                 mx, my, self._outer_radius,
                                 r, g, b, {0, 0, 0.05, 0.4, 1, 0.9})
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT)
    cairo_fill_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, 1)
    cairo_set_line_width(cr, 0.75)
    cairo_stroke(cr)
end


--- Visualize cpu-frequencies in a style reminiscent of stacked progress bars.
-- @type CpuFrequencies
local CpuFrequencies = util.class(Widget)
w.CpuFrequencies = CpuFrequencies

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
    self._text_color = ch.convert_string_to_rgba(current_theme.default_text_color)
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
    cairo_set_source_rgba(cr, unpack(self._text_color))
    ch.set_font(cr, current_theme.default_font_family, current_theme.default_font_size)
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
    local r, g, b = w.temperature_color(util.avg(self.temperatures), 30, 80)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    cairo_set_line_width(cr, 1)

    -- ticks --
    cairo_set_source_rgba(cr, r, g, b, .66)
    for _, tick in ipairs(self._ticks) do
        cairo_move_to(cr, tick[1], tick[2])
        cairo_rel_line_to(cr, 0, tick[3])
    end
    cairo_stroke(cr)
    ch.set_font(cr, current_theme.default_font_family, current_theme.default_font_size)
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

--- Compound widget to display GPU and VRAM usage.
-- @type CpuTop
local CpuTop = util.class(core.Rows)
w.CpuTop = CpuTop

--- no options
function CpuTop:init()
    self._usebar = core.Bar{ticks={.25, .5, .75}, unit="%"}

    local _, mem_total = data.gpu_memory()
    self._membar = mem.MemoryBar{total=mem_total / 1024}
    self._membar.update = function()
        self._membar:set_used(data.gpu_memory() / 1024)
    end
    core.Rows.init(self, {self._usebar, core.Filler{height=4}, self._membar})
end

return w
