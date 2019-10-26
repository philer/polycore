-- This is a lua script for use in conky --

require 'cairo'

-- lua's import system is retarded.
package.path = os.getenv("HOME") .. "/.config/conky/polycore/?.lua;" .. package.path
local data = require 'data'
local util = require 'util'
local widget = require 'widget'



local drives = {
    {"/", "/dev/nvme0"},
    {"/home", "/dev/nvme0"},
    {"/mnt/blackstor", "WDC WD2002FAEX-007BA0"},
    {"/mnt/bluestor", "WDC WD20EZRZ-00Z5HB0"},
    {"/mnt/cryptstor", "/dev/disk/by-uuid/9e340509-be93-42b5-9dcc-99bdbd428e22"},
}

local font_family = "Ubuntu"
local font_size = 10

local min_freq = 0.75
local max_freq = 4.3

local max_download = 10*1024
local max_upload = 1024

local temperature_colors = {
    {.4,  1,  1},
    {.5,  1, .8},
    {.7, .9, .6},
    {1,  .9, .4},
    {1,  .6, .2},
    {1,  .2, .2},
}
function temp_color(temp, low, high)
    local idx = (temp - low) / (high - low) * (#temperature_colors - 1) + 1
    local weight = idx - math.floor(idx)
    local cool = temperature_colors[util.clamp(1, #temperature_colors, math.floor(idx))]
    local hot = temperature_colors[util.clamp(1, #temperature_colors, math.ceil(idx))]
    return cool[1] + weight * (hot[1] - cool[1]),
           cool[2] + weight * (hot[2] - cool[2]),
           cool[3] + weight * (hot[3] - cool[3])
end

---

local cr, cs
local win_width = 140
local x_left = 10
local x_right = win_width - x_left
text_color = {1, 1, 1, .8}
graph_color = temperature_colors[1]
local r, g, b

-- local gpu_graph_data = util.CycleQueue(90)
local downspeed_graph_data = util.CycleQueue(90)
local upspeed_graph_data = util.CycleQueue(90)

os.setlocale("C")  -- decimal dot

local wili

function setup()
    wili = widget.WidgetList(140, 1080 - 28, 10)
    wili:add(widget.Gap(130))
    wili:add(widget.Cpu(6, 23, 5, 24))
    wili:add(widget.Gap(174))
    wili:add(widget.MemoryGrid(5, 40, 2, 1, true))
    wili:add(widget.Gap(82))
    wili:add(widget.Gpu())
    wili:layout()
end

function update(cr, update_count)
    font_normal(cr)
    wili:render(cr)


    local y_offset = 110

    local cpu_temps = data.cpu_temperatures()
    r, g, b = temp_color(util.avg(cpu_temps), 30, 80)

    cairo_set_source_rgba(cr, unpack(text_color))

    fans = data.fan_rpm()
    write_centered(cr, win_width / 2, y_offset,
                   fans[1] .. " rpm   ·   " .. fans[2] .. " rpm")
    y_offset = y_offset + 11

    write_centered(cr, win_width / 2, y_offset,
                   table.concat(cpu_temps, " · ") .. " °C")
    y_offset = y_offset + 10

    y_offset = y_offset + 125

    cairo_set_source_rgba(cr, unpack(text_color))
    font_normal(cr, 10)
    write_left(cr, x_right - 15, y_offset + 12, "GHz")
    draw_cpu_frequencies(data.cpu_frequencies(6),
                         x_left + 2, x_right - 20,
                         y_offset, y_offset + 16)

    -- draw_memory(437)

    -- draw_gpu(514)
    draw_network("enp0s31f6", 665)

    y_offset = 800 - 15
    local drive_height = 47
    for _, drive in ipairs(drives) do
        if data.is_mounted(drive[1]) then
            draw_drive(drive[1], drive[2], y_offset)
            y_offset = y_offset + drive_height
        end
    end

    draw_right_border(cr)
    util.reset_data(update_count)
end


--- DRAWING ---

function draw_cpu_frequencies(frequencies, x_min, x_max, y_min, y_max)
    cairo_set_line_width(cr, 1)
    font_normal(cr, 10)
    cairo_set_source_rgba(cr, r, g, b, .66)

    local df = max_freq - min_freq

    -- ticks --
    for freq = 1, max_freq, .25 do
        local x = x_min + (x_max - x_min) * (freq - min_freq) / df
        local big = math.floor(freq) == freq
        if big then
            write_centered(cr, x, y_max + 8.5, freq)
        end
        cairo_move_to(cr, math.floor(x) + .5, y_max + 1.5)
        cairo_rel_line_to(cr, 0, big and 3 or 2)
    end
    cairo_stroke(cr)

    --- shadow outline
    polygon(cr, {
        x_min - 1, y_max - (y_max - y_min) * min_freq / max_freq - 1,
        x_max + 1, y_min - 1,
        x_max + 1, y_max + 1,
        x_min - 1, y_max + 1,
    })
    cairo_set_source_rgba(cr, 0, 0, 0, .4)
    cairo_set_line_width(cr, 1)
    cairo_stroke(cr)

    -- background --
    polygon(cr, {
        x_min, y_max - (y_max - y_min) * min_freq / max_freq,
        x_max, y_min,
        x_max, y_max,
        x_min, y_max,
    })
    cairo_set_source_rgba(cr, r, g, b, .15)
    cairo_fill_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, .3)
    cairo_stroke_preserve(cr)

    -- frequencies --
    for _, frequency in ipairs(frequencies) do
        local stop = (frequency - min_freq) / df
        alpha_gradient(cr, x_min, 0, x_max, 0, r, g, b, {
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

function draw_network(interface, y_offset)
    local down, up = data.network_speed(interface)
    max_download = math.max(max_download, down)
    max_upload = math.max(max_upload, up)
    downspeed_graph_data:put(down)
    graph(downspeed_graph_data, max_download, y_offset, 20)
    upspeed_graph_data:put(up)
    graph(upspeed_graph_data, max_upload, y_offset + 53, 20)
    -- downspeed_graph_data:put(math.log10(math.max(1, down)))
    -- graph(downspeed_graph_data, math.log10(max_download), y_offset, 20)
    -- upspeed_graph_data:put(math.log10(math.max(1, up)))
    -- graph(upspeed_graph_data, math.log10(max_upload), y_offset + 51, 20)
end

function draw_drive(path, device_name, y_offset)
    local perc = data.drive_percentage(path)
    local temp = data.hddtemp()[device_name]
    cairo_set_source_rgba(cr, unpack(text_color))
    local r, g, b
    if temp == nil then
        write_left(cr, x_right - 21, y_offset, "––––")
        r, g, b = .8, .8, .8
    else
        write_left(cr, x_right - 24, y_offset, temp .. " °C")
        r, g, b = temp_color(temp, 35, 65)
    end
    y_offset = y_offset + 4
    bar(nil, perc / 100, {}, nil, y_offset, r, g, b)
end

function bar(unit, fraction, ticks, big_ticks, y_offset, r, g, b)
    if r == nil then
        r, g, b = unpack(graph_color)
    end
    local height = 5
    local x_max
    if unit then
        x_max = x_right - 20
        cairo_set_source_rgba(cr, unpack(text_color))
        write_left(cr, x_right - 15, y_offset + 6, unit)
    else
        x_max = x_right
    end

    rectangle(cr, x_left, y_offset, x_max, y_offset + height)
    alpha_gradient(cr, x_left, 0, x_max, 0, r, g, b, {
        -- {0, .55}, {.1, .25},
        {fraction - .33, .33},
        {fraction - .08, .66},
        {fraction - .01, .75},
        {fraction,         1},
        -- {fraction + .01,  .1},
        {fraction + .01,  .2},
        {fraction + .1,  .1},

        {1,              .15},
    })
    cairo_fill_preserve(cr)

    cairo_set_line_width(cr, 1)

    --- fake shadow border ---
    cairo_set_source_rgba(cr, 0, 0, 0, .66)
    cairo_stroke(cr)

    --- border ---
    rectangle(cr, x_left + 1, y_offset + 1, x_max - 1, y_offset + height - 1)
    cairo_set_source_rgba(cr, r, g, b, .2)
    cairo_stroke(cr)

    --- ticks ---
    -- cairo_set_source_rgba(cr, r, g, b, .66)  -- ticks text color
    for offset, frac in ipairs(ticks) do
        local x = math.floor(x_left + frac * (x_max - x_left)) + .5
        cairo_move_to(cr, x, y_offset + height + .5)
        if big_ticks then
            if big_ticks[offset] then
                cairo_rel_line_to(cr, 0, 4)
                -- write_centered(x, y_offset + height + 8.5, big_ticks[offset])
            else
                cairo_rel_line_to(cr, 0, 2)
            end
        else
            cairo_rel_line_to(cr, 0, 3)
        end
    end
    cairo_set_source_rgba(cr, r, g, b, .5)
    cairo_stroke(cr)
end

function graph(data, max, y_offset, height, r, g, b)
    if r == nil then
        r, g, b = unpack(graph_color)
    end
    cairo_set_line_width(cr, 1)

    --- background shadow ---
    rectangle(cr, x_left - 1, y_offset - 1, x_right + 1, y_offset + height + 1)
    cairo_set_source_rgba(cr, 0, 0, 0, .33)
    cairo_stroke(cr)

    --- background ---
    rectangle(cr, x_left, y_offset, x_right, y_offset + height)
    -- alpha_gradient(cr, 0, y_offset, 0, y_offset + height, r, g, b, {
    --     {0, .1}, {.5, .18}, {.51, .12},
    -- })
    alpha_gradient(cr, 0, y_offset, 0, y_offset + height, r, g, b, {
        {.1, .14}, {.1, .06}, {.2, .06}, {.2, .14},
        {.3, .14}, {.3, .06}, {.4, .06}, {.4, .14},
        {.5, .14}, {.5, .06}, {.6, .06}, {.6, .14},
        {.7, .14}, {.7, .06}, {.8, .06}, {.8, .14},
        {.9, .14}, {.9, .06},
    })
    cairo_fill_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, .2)
    cairo_stroke(cr)

    --- actual graph ---
    local x_scale = 1 / data.length * (x_right - x_left)
    local y_scale = 1 / max * height
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT)
    cairo_move_to(cr, x_left + .5,
                  math.floor(y_offset + height - data:head() * y_scale) + .5)
    data:map(function(val, idx)
        max = math.max(max, val)
        cairo_line_to(cr, x_left + idx * x_scale,
                          y_offset + height - val * y_scale)
    end)
    cairo_set_source_rgba(cr, r, g, b, 1)
    cairo_set_line_width(cr, .5)
    cairo_stroke_preserve(cr)

    --- fill under graph ---
    cairo_line_to(cr, x_right + .5, y_offset + height + .5)
    cairo_line_to(cr, x_left + .5, y_offset + height + .5)
    cairo_close_path(cr)
    alpha_gradient(cr, 0, y_offset + height - max * y_scale,
                       0, y_offset + height,
                       r, g, b, {{0, .66}, {.5, .33}, {1, .25}})
    cairo_fill(cr)

end

---------------------
--+–––––––––––––––+--
--| CAIRO HELPERS |--
--+–––––––––––––––+--
---------------------

function draw_right_border(cr)
    cairo_move_to(cr, win_width - .5, 0)
    cairo_line_to(cr, win_width - .5, conky_window.text_height)
    cairo_set_line_width(cr, 1)
    cairo_set_source_rgba(cr, 1, 1, 1, .05)
    cairo_stroke(cr)
end

function rectangle(cr, x1, y1, x2, y2)
    -- polygon({x1, y1, x2, y1, x2, y2, x1, y2})
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    cairo_rectangle(cr, x1, y1, x2 - x1, y2 - y1)
end

function polygon(cr, coordinates)
    -- +.5 for sharp lines, see https://cairographics.org/FAQ/#sharp_lines
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT)
    cairo_move_to(cr, math.floor(coordinates[1]) + .5,
                      math.floor(coordinates[2]) + .5)
    for i = 3, #coordinates, 2 do
        cairo_line_to(cr, math.floor(coordinates[i]) + .5,
                          math.floor(coordinates[i + 1]) + .5)
    end
    cairo_close_path(cr)
end


function alpha_gradient(cr, x1, y1, x2, y2, r, g, b, stops)
    local gradient = cairo_pattern_create_linear(x1, y1, x2, y2)
    for _, stop in ipairs(stops) do
        local rw, gw, bw = r, g, b
        -- additional brightness (white) for peaks
        if stop[2] > 0.5 then
            rw, gw, bw = r * 1.3, g * 1.3, b * 1.3
        end
        cairo_pattern_add_color_stop_rgba(gradient,
            stop[1], rw, gw, bw, stop[2])
    end
    cairo_set_source(cr, gradient)
    cairo_pattern_destroy(gradient)
end

function font_normal(cr, size)
    cairo_select_font_face(cr, font_family, CAIRO_FONT_SLANT_NORMAL,
                                            CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, size or font_size)
end

function font_bold(cr, size)
    cairo_select_font_face(cr, font_family, CAIRO_FONT_SLANT_NORMAL,
                                            CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, size or font_size)
end

function write_left(cr, x, y, text)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

function write_centered(cr, mx, my, text)
    cairo_move_to(cr, text_center_coordinates(cr, mx, my, text))
    cairo_show_text(cr, text)
end

local function text_extents(cr, text)
    local extents = cairo_text_extents_t:create()
    tolua.takeownership(extents)
    cairo_text_extents(cr, text, extents)
    return extents
end

function text_center_coordinates(cr, mx, my, text)
    local extents = text_extents(cr, text)
    return mx - (extents.width / 2 + extents.x_bearing),
           my - (extents.height / 2 + extents.y_bearing)
end

function text_height(cr, text)
    return text_extents(cr, text).height
end

function text_width(cr, text)
    return text_extents(cr, text).width
end



--+–––––––––––––+--
--| ENTRY POINT |--
--+–––––––––––––+--

local function error_handler(err)
    print(err)
    print(debug.traceback())
end

function conky_main()
    if conky_window == nil then
        return
    end

    cs = cairo_xlib_surface_create(conky_window.display,
                                   conky_window.drawable,
                                   conky_window.visual,
                                   conky_window.text_width,
                                   conky_window.text_height)
    cr = cairo_create(cs)

    local update_count = tonumber(conky_parse('${updates}'))

    local status, err = xpcall(function() update(cr, update_count) end, error_handler)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    cr = nil
    cs = nil
end

xpcall(setup, error_handler)
