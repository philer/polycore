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
    if w.render then table.insert(self._render_widgets, w) end
    return w
end

function WidgetList:layout()
    print("layout reflow…")
    local content_height = 0
    for _, w in ipairs(self._widgets) do
        content_height = content_height + w.height
    end
    if self.height - 2 * self.padding < content_height then
        print("Warning: Content too high, will be clipped.")
    end

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

function WidgetList:update()
    local reflow = false
    for _, w in ipairs(self._render_widgets) do
        reflow = w:update() or reflow
    end
    if reflow then self:layout() end
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
function Widget:update() return false end
-- function Widget:render(cr) end


local WidgetGroup = util.class(Widget)

function WidgetGroup:init(widgets)
    self._widgets = widgets
    self._render_widgets = util.filter(function(w) return w.render end, widgets)
    self.height = 0
    for _, w in ipairs(widgets) do
        self.height = self.height + w.height
    end
end

function WidgetGroup:layout(container)
    local y_offset = container.y_offset
    for _, w in ipairs(self._widgets) do
        if w.layout then
            w:layout{x_offset = container.x_offset,
                     y_offset = y_offset,
                     width = container.width,
                     x_max = container.x_max}
        end
        y_offset = y_offset + w.height
    end
end

function WidgetGroup:render_background(cr)
    for _, w in ipairs(self._widgets) do
        w:render_background(cr)
    end
end

function WidgetGroup:update()
    local reflow = false
    for _, w in ipairs(self._render_widgets) do
        reflow = w:update() or reflow
    end
    return reflow
end

function WidgetGroup:render(cr)
    for _, w in ipairs(self._render_widgets) do
        w:render(cr)
    end
end


local Gap = util.class(Widget)

function Gap:init(height)
    self.height = height
end


local BorderRight = util.class(Widget)

function BorderRight:init(block)
    self.block = block
end

function BorderRight:render_background(cr)
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    cairo_set_line_width(cr, 1)
    cairo_set_source_rgba(cr, 0.8, 1, 1, 0.05)
    cairo_move_to(cr, self.block.width - 0.5, 0)
    cairo_line_to(cr, self.block.width - 0.5, self.block.height)
    cairo_stroke(cr)
end


local TextLine = util.class(Widget)

function TextLine:init(align, font_family, font_size, color)
    self.align = align or "left"
    self.font_family = font_family or default_font_family
    self.font_size = font_size or default_font_size
    self.color = color or default_text_color

    local write_fns = {left = write_left, center = write_centered, right = write_right}
    self._write_fn = write_fns[align]

    local extents = font_extents(self.font_family, self.font_size)
    self.height = extents.height
    local line_spacing = extents.height - (extents.ascent + extents.descent)
    self._baseline_offset = extents.ascent + 0.5 * line_spacing
end

function TextLine:set_text(text)
    self.text = text
end

function TextLine:layout(container)
    self._y = container.y_offset + self._baseline_offset
    if self.align == "center" then
        self._x = container.x_offset + 0.5 * container.width
    elseif self.align == "left" then
        self._x = container.x_offset
    else
        self._x = container.x_max
    end
end

function TextLine:render(cr)
    cairo_select_font_face(cr, self.font_family, CAIRO_FONT_SLANT_NORMAL,
                                                 CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, self.font_size)
    cairo_set_source_rgba(cr, unpack(self.color))
    self._write_fn(cr, self._x, self._y, self.text)
end


local Bar = util.class(Widget)

function Bar:init(ticks, big_ticks, unit, thickness, color)
    self.ticks = ticks
    self.big_ticks = big_ticks
    self.unit = unit
    self.thickness = thickness or 5
    self.color = color or default_graph_color

    self.height = self.thickness
    if ticks then
        self.height = self.height + (big_ticks and 5 or 4)
    end
    if unit then
        self.height = math.max(self.height, 8)  -- line_height
    end
end

function Bar:layout(container)
    self.x_offset = container.x_offset
    self.y_offset = container.y_offset
    if self.unit then
        self.x_max = container.x_max - 20
    else
        self.x_max = container.x_max
    end

    self._ticks = {}
    if self.ticks then
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
        cairo_set_source_rgba(cr, unpack(default_text_color))
        write_left(cr, self.x_max + 5, self.y_offset + 6, self.unit)
    end
end

function Bar:set_fill(fraction)
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
    for _, tick in ipairs(self._ticks) do
        cairo_move_to(cr, tick[1], tick[2])
        cairo_rel_line_to(cr, 0, tick[3])
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

function MemoryBar:set_used(used)
    Bar:set_fill(used / self.total)
end


local Graph = util.class(Widget)

function Graph:init(height, max, data_points, color)
    self.height = height
    self.max = max
    self.data = util.CycleQueue(data_points or 90)
    self.color = color or default_graph_color
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
    -- cairo_set_source_rgba(cr, 1, 0, 0, 1)
    cairo_stroke(cr)
end

function Graph:add_value(value)
    self.data:put(value)
    if value > self.max then
        self.max = value
    end
end

function Graph:render(cr)
    local r, g, b = unpack(self.color)
    local x_scale = 1 / self.data.length * (self.x_max - self.x_offset)
    local y_scale = 1 / self.max * self.height
    local y_bottom = self.y_offset + self.height - 0.5
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT)
    cairo_move_to(cr, self.x_offset, y_bottom - self.data:head() * y_scale)
    self.data:map(function(val, idx)
        cairo_line_to(cr, self.x_offset + (idx - 1) * x_scale, y_bottom - val * y_scale)
    end)

    cairo_set_source_rgba(cr, r, g, b, 1)
    cairo_set_line_width(cr, .5)
    cairo_stroke_preserve(cr)

    --- fill under graph ---
    cairo_line_to(cr, self.x_max, y_bottom)
    cairo_line_to(cr, self.x_offset, y_bottom)
    cairo_close_path(cr)
    alpha_gradient(cr, 0, y_bottom - self.max * y_scale,
                       0, y_bottom,
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

function Cpu:update()
    self.percentages = data.cpu_percentages(self.cores)
    self.temperatures = data.cpu_temperatures()
end

function Cpu:render(cr)
    local avg_temperature = util.avg(self.temperatures)
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
    write_middle(cr, self.mx + 1, self.my, string.format("%d°", avg_temperature))

    font_normal(cr, 10)
    for core = 1, self.cores do
        polygon(cr, self.segment_coordinates[core])
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
    self._ticks = {}
    self._tick_labels = {}

    local df = self.max_freq - self.min_freq
    local width = self.x_max - self.x_min
    for freq = 1, self.max_freq, .25 do
        local x = self.x_min + width * (freq - self.min_freq) / df
        local big = math.floor(freq) == freq
        if big then
            table.insert(self._tick_labels, {x, self.y_max + 10.5, freq})
        end
        table.insert(self._ticks, {math.floor(x) + .5,
                                   self.y_max + 1.5,
                                   big and 3 or 2})
    end
end

function CpuFrequencies:render_background(cr)
    font_normal(cr)
    cairo_set_source_rgba(cr, unpack(default_text_color))
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

function CpuFrequencies:update()
    self.frequencies = data.cpu_frequencies(self.cores)
    self.temperatures = data.cpu_temperatures()
end

function CpuFrequencies:render(cr)
    local r, g, b = temp_color(util.avg(self.temperatures), 30, 80)

    cairo_set_line_width(cr, 1)

    -- ticks --
    cairo_set_source_rgba(cr, r, g, b, .66)
    for _, tick in ipairs(self._ticks) do
        cairo_move_to(cr, tick[1], tick[2])
        cairo_rel_line_to(cr, 0, tick[3])
    end
    cairo_stroke(cr)
    font_normal(cr)
    for _, label in ipairs(self._tick_labels) do
        write_centered(cr, label[1], label[2], label[3])
    end


    -- background --
    polygon(cr, self._polygon_coordinates)
    cairo_set_source_rgba(cr, r, g, b, .15)
    cairo_fill_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, .3)
    cairo_stroke_preserve(cr)

    -- frequencies --
    local df = self.max_freq - self.min_freq
    for _, frequency in ipairs(self.frequencies) do
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


local Gpu = util.class(WidgetGroup)

function Gpu:init()
    self.usebar = Bar({.25, .5, .75}, nil, "%")
    local _, mem_total = data.gpu_memory()
    self.membar = MemoryBar(mem_total / 1024, "GiB")
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


local Drive = util.class(WidgetGroup)

function Drive:init(path, device_name)
    self.path = path
    self.device_name = device_name

    self._temperature_text = TextLine("right")
    self._bar = Bar()
    blah = TextLine("center")
    blah:set_text("blah")
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
    Graph = Graph,
    MemoryBar = MemoryBar,
    MemoryGrid = MemoryGrid,
    TextLine = TextLine,
    Widget = Widget,
    WidgetGroup = WidgetGroup,
    WidgetList = WidgetList,
}
