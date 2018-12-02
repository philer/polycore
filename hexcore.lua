-- This is a lua script for use in conky --

require 'cairo'

-- lua's import system is retarded.
package.path = os.getenv("HOME") .. "/.config/conky/?.lua;" .. package.path
require 'data'
require 'util'



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
    local cool = temperature_colors[clamp(1, #temperature_colors, math.floor(idx))]
    local hot = temperature_colors[clamp(1, #temperature_colors, math.ceil(idx))]
    return cool[1] + weight * (hot[1] - cool[1]),
           cool[2] + weight * (hot[2] - cool[2]),
           cool[3] + weight * (hot[3] - cool[3])
end

---

local cr, cs
local win_width, win_height
local x_left, x_right
local text_color = {1, 1, 1, .8}
local graph_color = temperature_colors[1]
local r, g, b

-- local gpu_graph_data = CycleQueue(90)
local downspeed_graph_data = CycleQueue(90)
local upspeed_graph_data = CycleQueue(90)

os.setlocale("C")  -- decimal dot

-------------------
--+–––––––––––––+--
--| ENTRY POINT |--
--+–––––––––––––+--
-------------------
function conky_main()
    if not init_cairo() then
        return
    end

    win_width = conky_window.text_width
    win_height = conky_window.text_height
    x_left = 10
    x_right = win_width - x_left
    local y_offset = 110

    local cpu_temps = cpu_temperatures()
    r, g, b = temp_color(avg(cpu_temps), 30, 80)

    cairo_set_source_rgba(cr, unpack(text_color))

    fans = fan_rpm()
    write_centered(win_width / 2, y_offset,
                   fans[1] .. " rpm   ·   " .. fans[2] .. " rpm")
    y_offset = y_offset + 11

    write_centered(win_width / 2, y_offset,
                   table.concat(cpu_temps, " · ") .. " °C")
    y_offset = y_offset + 10

    draw_hex_cpu(win_width / 2, y_offset + 55, cpu_percentages(), cpu_temps)
    y_offset = y_offset + 125

    cairo_set_source_rgba(cr, unpack(text_color))
    font_normal(10)
    write_left(x_right - 15, y_offset + 12, "GHz")
    draw_cpu_frequencies(cpu_frequencies(),
                         x_left + 2, x_right - 20,
                         y_offset, y_offset + 16)

    draw_memory(420)
    draw_gpu(514)
    draw_network("enp0s31f6", 665)

    y_offset = 800 - 15
    local drive_height = 47
    for _, drive in ipairs(drives) do
        if is_mounted(drive[1]) then
            draw_drive(drive[1], drive[2], y_offset)
            y_offset = y_offset + drive_height
        end
    end

    draw_right_border()
    reset_data(tonumber(conky_parse('${updates}')))
    destruct_cairo()
end


--- DRAWING ---

function draw_hex_cpu(mx, my, percentages, temperatures)
    hexagon(mx, my, 11.5)
    cairo_set_line_width(cr, 6)
    cairo_set_source_rgba(cr, r, g, b, .33)
    cairo_stroke_preserve(cr)
    cairo_set_line_width(cr, 1)
    cairo_set_source_rgba(cr, 0, 0, 0, .66)
    cairo_stroke_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, .18)
    cairo_fill(cr)

    font_bold(16)
    cairo_set_source_rgba(cr, r, g, b, .4)
    write_centered(mx + 1, my, string.format("%d°", avg(temperatures)))

    --- cores
    font_normal(10)
    local min, max, gap = 14, 26, 2.5
    for id = 1, 6 do
        local gradient = hexagon_segment_gradient(id, mx, my, min, max, gap)

        local r, g, b = temp_color(temperatures[id], 30, 80)
        cairo_set_source_rgba(cr, 0, 0, 0, .4)
        cairo_set_line_width(cr, 1.5)
        cairo_stroke_preserve(cr)
        cairo_set_source_rgba(cr, r, g, b, .4)
        cairo_set_line_width(cr, .75)
        cairo_stroke_preserve(cr)

        -- local h_rel = percentages[id]/100 -- height relative bar
        -- area relative bar height --
        local h = math.sqrt(percentages[id] / 100 * (max * max - min * min)
                            + min * min)
        local h_rel = (h - min) / (max - min)
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

function draw_cpu_frequencies(frequencies, x_min, x_max, y_min, y_max)
    cairo_set_line_width(cr, 1)
    font_normal(10)
    cairo_set_source_rgba(cr, r, g, b, .66)

    local df = max_freq - min_freq

    -- ticks --
    for freq = 1, max_freq, .25 do
        local x = x_min + (x_max - x_min) * (freq - min_freq) / df
        local big = math.floor(freq) == freq
        if big then
            write_centered(x, y_max + 8.5, freq)
        end
        cairo_move_to(cr, math.floor(x) + .5, y_max + 1.5)
        cairo_rel_line_to(cr, 0, big and 3 or 2)
    end
    cairo_stroke(cr)

    --- shadow outline
    polygon({
        x_min - 1, y_max - (y_max - y_min) * min_freq / max_freq - 1,
        x_max + 1, y_min - 1,
        x_max + 1, y_max + 1,
        x_min - 1, y_max + 1,
    })
    cairo_set_source_rgba(cr, 0, 0, 0, .4)
    cairo_set_line_width(cr, 1)
    cairo_stroke(cr)

    -- background --
    polygon({
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
    for id = 1, 6 do
        local stop = (frequencies[id] - min_freq) / df
        alpha_gradient(x_min, 0, x_max, 0, r, g, b, {
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

function draw_gpu(y_offset)
    local r, g, b = temp_color(gpu_temperature(), 30, 80)
    bar("%", gpu_percentage() / 100, {.25, .5, .75}, nil, y_offset, r, g, b)
    local mem_used, mem_total = gpu_memory()
    memory_bar("GiB", mem_used / 1024, mem_total / 1024, y_offset + 12, r, g, b)
end

function draw_memory(y_offset)
    local used, total = memory()
    memory_bar("GiB", used, total, y_offset)
end

function draw_network(interface, y_offset)
    local down, up = network_speed(interface)
    max_download = math.max(max_download, down)
    max_upload = math.max(max_upload, up)
    downspeed_graph_data:add(down)
    graph(downspeed_graph_data, max_download, y_offset, 20)
    upspeed_graph_data:add(up)
    graph(upspeed_graph_data, max_upload, y_offset + 53, 20)
    -- downspeed_graph_data:add(math.log10(math.max(1, down)))
    -- graph(downspeed_graph_data, math.log10(max_download), y_offset, 20)
    -- upspeed_graph_data:add(math.log10(math.max(1, up)))
    -- graph(upspeed_graph_data, math.log10(max_upload), y_offset + 51, 20)
end

function draw_drive(path, device_name, y_offset)
    local perc = drive_percentage(path)
    local temp = hddtemp()[device_name]
    cairo_set_source_rgba(cr, unpack(text_color))
    local r, g, b
    if temp == nil then
        write_left(x_right - 21, y_offset, "––––")
        r, g, b = .8, .8, .8
    else
        write_left(x_right - 24, y_offset, temp .. " °C")
        r, g, b = temp_color(temp, 35, 65)
    end
    y_offset = y_offset + 4
    bar(nil, perc / 100, {}, nil, y_offset, r, g, b)
end



function memory_bar(unit, used, total, y_offset, r, g, b)
    local ticks = range(1 / total, math.floor(total) / total, 1 / total)
    -- ticks = range(1/16, 15/16, 1/16)
    local big_ticks = nil
    total = math.ceil(total)
    if total > 8 then
        big_ticks = {}
        for offset = 4, total, 4 do
            big_ticks[offset] = offset
        end
    end
    bar(unit, used / total, ticks, big_ticks, y_offset, r, g, b)
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
        write_left(x_right - 15, y_offset + 6, unit)
    else
        x_max = x_right
    end

    rectangle(x_left, y_offset, x_max, y_offset + height)
    alpha_gradient(x_left, 0, x_max, 0, r, g, b, {
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
    rectangle(x_left + 1, y_offset + 1, x_max - 1, y_offset + height - 1)
    cairo_set_source_rgba(cr, r, g, b, .2)
    cairo_stroke(cr)

    --- ticks ---
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
    rectangle(x_left - 1, y_offset - 1, x_right + 1, y_offset + height + 1)
    cairo_set_source_rgba(cr, 0, 0, 0, .33)
    cairo_stroke(cr)

    --- background ---
    rectangle(x_left, y_offset, x_right, y_offset + height)
    -- alpha_gradient(0, y_offset, 0, y_offset + height, r, g, b, {
    --     {0, .1}, {.5, .18}, {.51, .12},
    -- })
    alpha_gradient(0, y_offset, 0, y_offset + height, r, g, b, {
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
    alpha_gradient(0, y_offset + height - max * y_scale,
                   0, y_offset + height,
                   r, g, b, {{0, .66}, {.5, .33}, {1, .25}})
    cairo_fill(cr)

end

---------------------
--+–––––––––––––––+--
--| CAIRO HELPERS |--
--+–––––––––––––––+--
---------------------

-- local core_count = 6
-- local segment_offsets = {}
-- for id = 1, core_count do
--     local rad = math.pi * (2 * (id+.5) / core_count)
--     -- id = (id + 2) % 6 + 1
--     id = (id -1) % core_count + 1
--     segment_offsets[id] = {2*math.cos(rad), 2*math.sin(rad)}
-- end

local s3 = math.sqrt(3)
local hex_segment_offsets = {
    {-1, -s3}, -- top left
    { 1, -s3}, -- top right
    { 2,   0}, -- right
    { 1,  s3}, -- bottom right
    {-1,  s3}, -- bottom left
    {-2,   0}, -- left
}

function hexagon_segment_gradient(id, mx, my, min, max, gap)
    local offset1x, offset1y = unpack(hex_segment_offsets[id])
    local offset2x, offset2y = unpack(hex_segment_offsets[id % 6 + 1])
    local gapy, gapx = unpack(hex_segment_offsets[7 - id])
    gapx, gapy = gapx * gap, gapy * gap
    local coords = {
        mx + min * offset1x + gapx, my + min * offset1y + gapy,
        mx + max * offset1x + gapx, my + max * offset1y + gapy,
        mx + max * offset2x + gapx, my + max * offset2y + gapy,
        mx + min * offset2x + gapx, my + min * offset2y + gapy,
    }
    polygon(coords)
    return cairo_pattern_create_linear((coords[1] + coords[7]) / 2,
                                       (coords[2] + coords[8]) / 2,
                                       (coords[3] + coords[5]) / 2,
                                       (coords[4] + coords[6]) / 2)
end

function draw_right_border()
    cairo_move_to(cr, win_width - .5, 0)
    cairo_line_to(cr, win_width - .5, win_height)
    cairo_set_line_width(cr, 1)
    cairo_set_source_rgba(cr, 1, 1, 1, .05)
    cairo_stroke(cr)
end

function rectangle(x1, y1, x2, y2)
    return polygon({x1, y1, x2, y1, x2, y2, x1, y2})
end

function hexagon(mx, my, scale)
    local coords = {}
    for i = 1, 6 do
        table.insert(coords, mx + scale * hex_segment_offsets[i][1])
        table.insert(coords, my + scale * hex_segment_offsets[i][2])
    end
    polygon(coords)
end

function polygon(coordinates)
    -- +.5 for sharp lines, see https://cairographics.org/FAQ/#sharp_lines
    cairo_move_to(cr, math.floor(coordinates[1]) + .5,
                      math.floor(coordinates[2]) + .5)
    for i = 3, #coordinates, 2 do
        cairo_line_to(cr, math.floor(coordinates[i]) + .5,
                          math.floor(coordinates[i + 1]) + .5)
    end
    cairo_close_path(cr)
end


function alpha_gradient(x1, y1, x2, y2, r, g, b, stops)
    local gradient = cairo_pattern_create_linear(x1, y1, x2, y2)
    for _, stop in ipairs(stops) do
        local rw, gw, bw = r, g, b
        -- additional brightness (white) for peaks
        if stop[2] > .5 then
            -- local brightness = (stop[2] - .25) * .33
            -- rw, gw, bw = r + brightness, g + brightness, b + brightness
            rw, gw, bw = r * 1.3, g * 1.3, b * 1.3
        end
        cairo_pattern_add_color_stop_rgba(gradient,
            stop[1], rw, gw, bw, stop[2])
    end
    cairo_set_source(cr, gradient)
    cairo_pattern_destroy(gradient)
end


-- function inverse_clip()
--     cairo_new_sub_path(cr);
--     polygon({
--         0, 0,
--         0, win_height,
--         win_width, win_height,
--         win_width, 0,
--     })
--     cairo_clip(cr)
-- end


function font_normal(size)
    cairo_select_font_face(cr, font_family, CAIRO_FONT_SLANT_NORMAL,
                                            CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, size or font_size)
end

function font_bold(size)
    cairo_select_font_face(cr, font_family, CAIRO_FONT_SLANT_NORMAL,
                                            CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, size or font_size)
end

function write_left(x, y, text)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

function write_centered(mx, my, text)
    local x, y = text_center_coordinates(mx, my, text)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

function text_center_coordinates(mx, my, text)
    local extents = cairo_text_extents_t:create()
    tolua.takeownership(extents)
    cairo_text_extents(cr, text, extents)
    local x = mx - (extents.width / 2 + extents.x_bearing)
    local y = my - (extents.height / 2 + extents.y_bearing)
    return x, y
end

function text_width(text)
    local extents = cairo_text_extents_t:create()
    tolua.takeownership(extents)
    cairo_text_extents(cr, text, extents)
    return extents.width
end


function init_cairo()
    if conky_window == nil then
        return false
    end
    cs = cairo_xlib_surface_create(conky_window.display,
                                   conky_window.drawable,
                                   conky_window.visual,
                                   conky_window.text_width,
                                   conky_window.text_height)
    cr = cairo_create(cs)
    font_normal()
    return true
end

function destruct_cairo()
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    cr = nil
end
