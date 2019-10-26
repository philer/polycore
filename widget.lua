local data = require 'data'
local util = require 'util'

local WidgetList = util.class()

function WidgetList:init(width, height, padding)
    self.width = width
    self.height = height
    self.padding = padding

    self._widgets = {}
    self._render_widgets = {}
    self._background_surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, width, height)
end

function WidgetList:add(w)
    table.insert(self._widgets, w)
    if w.render then
        table.insert(self._render_widgets, w)
    end
end

function WidgetList:layout()
    local x_offset, y_offset = self.padding, self.padding
    local width = self.width - 2 * self.padding
    local x_max = self.width - self.padding
    local background_cr = cairo_create(self._background_surface)
    cairo_set_antialias(background_cr, CAIRO_ANTIALIAS_NONE)
    for _, w in ipairs(self._widgets) do
        if w.layout then
            w:layout{x_offset=x_offset, y_offset=y_offset, width=width, x_max=x_max}
        end
        y_offset = y_offset + w.height
        if w.render_background then
            w:render_background(background_cr)
        end
    end
    cairo_destroy(background_cr)
    background_cr = nil
end

function WidgetList:render(cr)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    cairo_set_source_surface(cr, self._background_surface, 0, 0);
    cairo_paint(cr);
    for _, w in ipairs(self._render_widgets) do
        w:render(cr)
    end
end


local Widget = util.class()
Widget.height = 0
-- function Widget:init(y) end
function Widget:layout(container) end
function Widget:render_background(cr) end
-- function Widget:update(...) end
-- function Widget:render(cr) end


local WidgetGroup = util.class(Widget)

function WidgetGroup:init(widgets)
    self.widgets = widgets
    self.render_widgets = util.filter(function(w) return w.render end, widgets)
end

function WidgetGroup:layout(container)
    local y_offset = container.y_offset
    for _, w in ipairs(self.widgets) do
        if w.layout then
            w:layout{x_offset = container.x_offset,
                     y_offset = y_offset,
                     width = container.width,
                     x_max = container.x_max}
        end
        y_offset = y_offset + w.height
    end
    self.height = y_offset - container.y_offset
end

function WidgetGroup:render_background(cr)
    for _, w in ipairs(self.widgets) do
        w:render_background(cr)
    end
end

function WidgetGroup:render(cr)
    for _, w in ipairs(self.render_widgets) do
        w:render(cr)
    end
end


local Gap = util.class(Widget)

function Gap:init(height)
    self.height = height
end


local Bar = util.class(Widget)

function Bar:init(ticks, big_ticks, unit, thickness, color)
    self.ticks = ticks
    self.big_ticks = big_ticks
    self.unit = unit
    self.thickness = thickness or 5
    self.color = color or graph_color
end

function Bar:layout(container)
    self.height = 5
    self.x_offset = container.x_offset
    self.y_offset = container.y_offset
    if self.unit then
        self.x_max = container.x_max - 20
        self.height = 7
    else
        self.x_max = container.x_max
    end

    if self.ticks then
        self.height = self.height + (self.big_ticks and 4 or 3)
        self._ticks = {}
        local x, tick_length
        for offset, frac in ipairs(self.ticks) do
            x = math.floor(self.x_offset + frac * (self.x_max - self.x_offset)) + 0.5
            tick_length = 3
            if self.big_ticks then
                if self.big_ticks[offset] then
                    tick_length = 4
                else
                    tick_length = 2
                end
            end
            table.insert(self._ticks, {x, self.y_offset + self.thickness + 0.5, tick_length})
        end
    end
end

function Bar:render_background(cr)
    if self.unit then
        font_normal(cr)
        cairo_set_source_rgba(cr, unpack(text_color))
        write_left(cr, self.x_max + 5, self.y_offset + 6, self.unit)
    end
end

function Bar:update(fraction)
    self.fraction = fraction
end

function Bar:render(cr)
    local r, g, b = unpack(self.color)
    rectangle(cr, self.x_offset, self.y_offset, self.x_max, self.y_offset + self.thickness)
    alpha_gradient(cr, self.x_offset, 0, self.x_max, 0, r, g, b, {
        -- {0, .55}, {.1, .25},
        {self.fraction - .33, .33},
        {self.fraction - .08, .66},
        {self.fraction - .01, .75},
        {self.fraction,         1},
        -- {self.fraction + .01,  .1},
        {self.fraction + .01,  .2},
        {self.fraction + .1,  .1},

        {1,              .15},
    })
    cairo_fill_preserve(cr)

    cairo_set_line_width(cr, 1)

    --- fake shadow border ---
    cairo_set_source_rgba(cr, 0, 0, 0, .66)
    cairo_stroke(cr)

    --- border ---
    rectangle(cr, self.x_offset + 1, self.y_offset + 1, self.x_max - 1, self.y_offset + self.thickness - 1)
    cairo_set_source_rgba(cr, r, g, b, .2)
    cairo_stroke(cr)

    --- ticks ---
    for _, coords in ipairs(self._ticks) do
        cairo_move_to(cr, coords[1], coords[2])
        cairo_rel_line_to(cr, 0, coords[3])
    end
    cairo_set_source_rgba(cr, r, g, b, .5)
    cairo_stroke(cr)
end


local MemoryBar = util.class(Bar)

function MemoryBar:init(total, unit, color)
    local ticks = util.range(1 / total, math.floor(total) / total, 1 / total)
    -- ticks = util.range(1/16, 15/16, 1/16)
    Bar.init(self, ticks, nil, unit, color)

    self.total = math.ceil(total)
    if self.total > 8 then
        self.big_ticks = {}
        for offset = 4, self.total, 4 do
            self.big_ticks[offset] = offset
        end
    end
end

function MemoryBar:update(used)
    self.fraction = used / self.total
end


local Graph = util.class(Widget)

function Graph:init(height, max, data_points, color)
    self.height = height
    self.max = max
    self.data = util.CycleQueue(data_points or 90)
    self.color = color or graph_color
end

function Graph:layout(container)
    self.x_offset = container.x_offset
    self.y_offset = container.y_offset
    self.x_max = container.x_max
end

function Graph:render_background(cr)
    local r, g, b = unpack(self.color)
    cairo_set_line_width(cr, 1)

    --- background shadow ---
    rectangle(cr, self.x_offset - 1, self.y_offset - 1, self.x_max + 1, self.y_offset + self.height + 1)
    cairo_set_source_rgba(cr, 0, 0, 0, .33)
    cairo_stroke(cr)

    --- background ---
    rectangle(cr, self.x_offset, self.y_offset, self.x_max, self.y_offset + self.height)
    alpha_gradient(cr, 0, self.y_offset, 0, self.y_offset + self.height, r, g, b, {
        {.1, .14}, {.1, .06}, {.2, .06}, {.2, .14},
        {.3, .14}, {.3, .06}, {.4, .06}, {.4, .14},
        {.5, .14}, {.5, .06}, {.6, .06}, {.6, .14},
        {.7, .14}, {.7, .06}, {.8, .06}, {.8, .14},
        {.9, .14}, {.9, .06},
    })
    cairo_fill_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, .2)
    cairo_stroke(cr)
end

function Graph:update(value)
    self.data:put(value)
    if value > self.max then
        self.max = value
    end
end

function Graph:render(cr)
    local x_scale = 1 / self.data.length * (self.x_max - self.x_offset)
    local y_scale = 1 / self.max * self.height
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT)
    cairo_move_to(cr, self.x_offset + .5,
                  math.floor(self.y_offset + self.height - self.data:head() * y_scale) + .5)
    self.data:map(function(val, idx)
        cairo_line_to(cr, self.x_offset + idx * x_scale,
                          self.y_offset + self.height - val * y_scale)
    end)

    local r, g, b = unpack(self.color)
    cairo_set_source_rgba(cr, r, g, b, 1)
    cairo_set_line_width(cr, .5)
    cairo_stroke_preserve(cr)

    --- fill under graph ---
    cairo_line_to(cr, self.x_max + .5, self.y_offset + self.height + .5)
    cairo_line_to(cr, self.x_offset + .5, self.y_offset + self.height + .5)
    cairo_close_path(cr)
    alpha_gradient(cr, 0, self.y_offset + self.height - self.max * y_scale,
                       0, self.y_offset + self.height,
                       r, g, b, {{0, .66}, {.5, .33}, {1, .25}})
    cairo_fill(cr)
end


local Cpu = util.class(Widget)

function Cpu:init(cores, scale, gap, segment_size)
    self.cores = cores
    self.scale = scale
    self.gap = gap
    self.segment_size = segment_size
end

function Cpu:layout(container)
    local radius = self.scale + self.gap + self.segment_size
    self.height = 2 * radius
    self.mx = container.x_offset + container.width / 2
    self.my = container.y_offset + radius

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
        table.insert(self.center_coordinates, self.mx + self.scale * dx_left)
        table.insert(self.center_coordinates, self.my + self.scale * dy_left)

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
        table.insert(self.segment_coordinates, {x1, y1, x2, y2, x3, y3, x4, y4})
        table.insert(self.gradient_coordinates, {(x1 + x4) / 2,
                                                 (y1 + y4) / 2,
                                                 (x2 + x3) / 2,
                                                 (y2 + y3) / 2})
    end
end

function Cpu:render(cr)
    local temperatures = data.cpu_temperatures()
    local avg_temperature = util.avg(temperatures)
    local percentages = data.cpu_percentages(self.cores)
    local r, g, b = temp_color(avg_temperature, 30, 80)

    polygon(cr, self.center_coordinates)
    cairo_set_line_width(cr, 6)
    cairo_set_source_rgba(cr, r, g, b, .33)
    cairo_stroke_preserve(cr)
    cairo_set_line_width(cr, 1)
    cairo_set_source_rgba(cr, 0, 0, 0, .66)
    cairo_stroke_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, .18)
    cairo_fill(cr)

    font_bold(cr, 16)
    cairo_set_source_rgba(cr, r, g, b, .4)
    write_centered(cr, self.mx + 1, self.my, string.format("%d°", avg_temperature))

    font_normal(cr, 10)
    for core = 1, self.cores do
        polygon(cr, self.segment_coordinates[core])
        local gradient = cairo_pattern_create_linear(unpack(self.gradient_coordinates[core]))
        local r, g, b = temp_color(temperatures[core], 30, 80)
        cairo_set_source_rgba(cr, 0, 0, 0, .4)
        cairo_set_line_width(cr, 1.5)
        cairo_stroke_preserve(cr)
        cairo_set_source_rgba(cr, r, g, b, .4)
        cairo_set_line_width(cr, .75)
        cairo_stroke_preserve(cr)

        local h_rel = percentages[core]/100
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


local CpuFrequencies = util.class(Widget)

function CpuFrequencies:init(cores, min_freq, max_freq, height)
    self.cores = cores
    self.min_freq = min_freq
    self.max_freq = max_freq
    self._height = height
    self.height = height + 10
end

function CpuFrequencies:layout(container)
    self.x_min = container.x_offset + 2
    self.x_max = container.x_max - 20
    self.y_min = container.y_offset
    self.y_max = container.y_offset + self._height
    self._polygon_coordinates = {
        self.x_min, self.y_max - (self.y_max - self.y_min) * self.min_freq / self.max_freq,
        self.x_max, self.y_min,
        self.x_max, self.y_max,
        self.x_min, self.y_max,
    }
end

function CpuFrequencies:render_background(cr)
    font_normal(cr)
    cairo_set_source_rgba(cr, unpack(text_color))
    write_left(cr, self.x_max + 5, self.y_min + 0.5 * self._height + 3, "GHz")

    --- shadow outline
    polygon(cr, {
        self._polygon_coordinates[1] - 1, self._polygon_coordinates[2] - 1,
        self._polygon_coordinates[3] + 1, self._polygon_coordinates[4] - 1,
        self._polygon_coordinates[5] + 1, self._polygon_coordinates[6] + 1,
        self._polygon_coordinates[7] - 1, self._polygon_coordinates[8] + 1,
    })
    cairo_set_source_rgba(cr, 0, 0, 0, .4)
    cairo_set_line_width(cr, 1)
    cairo_stroke(cr)
end

function CpuFrequencies:render(cr)
    local frequencies = data.cpu_frequencies(self.cores)
    local temperatures = data.cpu_temperatures()
    local r, g, b = temp_color(util.avg(temperatures), 30, 80)
    local df = self.max_freq - self.min_freq

    cairo_set_line_width(cr, 1)

    -- ticks --
    font_normal(cr)
    cairo_set_source_rgba(cr, r, g, b, .66)
    for freq = 1, self.max_freq, .25 do
        local x = self.x_min + (self.x_max - self.x_min) * (freq - self.min_freq) / df
        local big = math.floor(freq) == freq
        if big then
            write_centered(cr, x, self.y_max + 8.5, freq)
        end
        cairo_move_to(cr, math.floor(x) + .5, self.y_max + 1.5)
        cairo_rel_line_to(cr, 0, big and 3 or 2)
    end
    cairo_stroke(cr)


    -- background --
    polygon(cr, self._polygon_coordinates)
    cairo_set_source_rgba(cr, r, g, b, .15)
    cairo_fill_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, .3)
    cairo_stroke_preserve(cr)

    -- frequencies --
    for _, frequency in ipairs(frequencies) do
        local stop = (frequency - self.min_freq) / df
        alpha_gradient(cr, self.x_min, 0, self.x_max, 0, r, g, b, {
             {0,          .01},
             {stop - .4,  .015},
             {stop - .2,  .05},
             {stop - .1,  .1},
             {stop - .02, .2},
             {stop,       .6},
             {stop,       0},
        })
        cairo_fill_preserve(cr)
    end
    cairo_new_path(cr)
end




local MemoryGrid = util.class(Widget)

function MemoryGrid:init(rows, columns, point_size, gap, shuffle)
    self.rows = rows
    self.columns = columns
    self.point_size = point_size
    self.gap = gap
    self.shuffle = shuffle
    self.height = rows * point_size + (rows - 1) * gap
end

function MemoryGrid:layout(container)
    self.coordinates = {}
    local point_plus_gap = self.point_size + self.gap
    for col = 0, self.columns - 1, 1 do
        for row = 0, self.rows - 1, 1 do
            table.insert(self.coordinates, {container.x_offset + col * point_plus_gap,
                                            container.y_offset + row * point_plus_gap,
                                            container.x_offset + col * point_plus_gap + self.point_size,
                                            container.y_offset + row * point_plus_gap + self.point_size})
        end
    end
    if shuffle == nil or shuffle then
        math.randomseed(1069140724)
        util.shuffle(self.coordinates)
    end
end

function MemoryGrid:render(cr)
    local used, easyfree, free, total = data.memory()

    local total_points = #self.coordinates
    local used_points = math.floor(total_points * used / total + 0.5)
    local cache_points = math.floor(total_points * (easyfree - free) / total + 0.5)
    local r, g, b = unpack(graph_color)  -- TODO color manager

    if used / total > 0.8 then
        r, g, b = unpack(temperature_colors[#temperature_colors])
    end

    for i = 1, used_points do
        rectangle(cr, unpack(self.coordinates[i]))
        cairo_set_source_rgba(cr, r, g, b, .8)
        cairo_fill(cr)
    end
    for i = used_points, used_points + cache_points do
        rectangle(cr, unpack(self.coordinates[i]))
        cairo_set_source_rgba(cr, r, g, b, .35)
        cairo_fill(cr)
    end
    for i = used_points + cache_points, total_points do
        rectangle(cr, unpack(self.coordinates[i]))
        cairo_set_source_rgba(cr, r, g, b, .1)
        cairo_fill(cr)
    end
end


local Gpu = util.class(WidgetGroup)

function Gpu:init()
    self.usebar = Bar({.25, .5, .75}, nil, "%")
    local _, mem_total = data.gpu_memory()
    self.membar = MemoryBar(mem_total / 1024, "GiB")
    WidgetGroup.init(self, {self.usebar, Gap(2), self.membar})
end

function Gpu:render(cr)
    self.usebar:update(data.gpu_percentage() / 100)

    local mem_used, _ = data.gpu_memory()
    self.membar:update(mem_used / 1024)

    local color = util.pack(temp_color(data.gpu_temperature(), 30, 80))
    self.usebar.color = color
    self.membar.color = color

    WidgetGroup.render(self, cr)
end



return {
    WidgetList = WidgetList,
    Widget = Widget,
    WidgetGroup = WidgetGroup,
    Gap = Gap,
    Bar = Bar,
    MemoryBar = MemoryBar,
    Graph = Graph,
    Cpu = Cpu,
    CpuFrequencies = CpuFrequencies,
    MemoryGrid = MemoryGrid,
    Gpu = Gpu,
}
