-- This is a lua script for use in conky --

require 'cairo'

-- lua's import system is retarded.
package.path = os.getenv("HOME") .. "/.config/conky/?.lua;" .. package.path
require 'util'


local font_family = "Ubuntu"
local font_size = 10

local min_freq = 0.75
local max_freq = 4.2

local temperature_colors = {
    {.4,  1,  1},
    {.5,  1, .8},
    {.7, .9, .6},
    {1,  .9, .4},
    {1,  .6, .2},
    {1,  .3, .1},
}

local s3 = math.sqrt(3)
local vert_hex_offsets = {
    {-1, -s3}, -- top left
    { 1, -s3}, -- top right
    { 2,   0}, -- right
    { 1,  s3}, -- bottom right
    {-1,  s3}, -- bottom left
    {-2,   0}, -- left
}
local hor_hex_offsets = {
    {  0, -2},
    { s3, -1},
    { s3,  1},
    {  0,  2},
    {-s3,  1},
    {-s3, -1},
}

---

local cr
local win_width, win_height
local r, g, b

-------------------
--+–––––––––––––+--
--| ENTRY POINT |--
--+–––––––––––––+--
-------------------
function conky_main()
    if not init_cairo() then
        return
    end

    --- DATA ---
    local result
    result = conky_parse("${cpu cpu0}|${cpu cpu1}|${cpu cpu2}|${cpu cpu3}|${cpu cpu4}|${cpu cpu5}")
    local cpu_usages = array_from_iterator(result:gmatch("%d+"))

    result = conky_parse("${freq_g 0}|${freq_g 1}|${freq_g 2}|${freq_g 3}|${freq_g 4}|${freq_g 5}")
    local cpu_frequencies = array_from_iterator(result:gmatch("%d+%,%d+"))

    local pipe = io.popen("sensors")
    result = pipe:read("*a")
    pipe:close()
    local cpu_temperatures = array_from_iterator(result:gmatch("Core %d: +%+(%d%d)"))


    r, g, b = temperature_color(avg(cpu_temperatures))

    win_width = conky_window.text_width
    win_height = conky_window.text_height

    local gap = 6
    for x = gap / 2, win_width, gap do
        for y = gap / 2, win_height, gap do
            polygon({x - 0, y - 0,
                     x - 0, y + .5,
                     x + .5, y + .5,
                     x + .5, y - 0,})
        end
    end
    cairo_set_line_width(cr, 1)
    cairo_set_source_rgba(cr, 1, 1, 1, .4)
    cairo_fill(cr)

    local y_offset = 110


    cairo_set_source_rgba(cr, 1, 1, 1, .8)
    write_centered(win_width / 2, y_offset,
                   table.concat(cpu_temperatures, "°  ") .. "°C")
    y_offset = y_offset + 20

    draw_hex_cpu(win_width / 2, y_offset + 55,
                 cpu_usages, cpu_frequencies, cpu_temperatures)
    y_offset = y_offset + 125

    cairo_set_source_rgba(cr, 1, 1, 1, .8)
    font_normal(10)
    write_centered(win_width - 16, y_offset + 8, "GHz")
    -- +.5 for sharp lines, see https://cairographics.org/FAQ/#sharp_lines
    draw_frequencies(cpu_frequencies,
                     12.5, win_width - 28.5,
                     y_offset + .5, y_offset + .5 + 16)
    -- y_offset = y_offset + 40

    -- cairo_set_source_rgba(cr, 1, 1, 1, .8)
    -- write_centered(win_width / 2, y_offset,
    --                table.concat(cpu_frequencies, " "))


    destruct_cairo()
end


function temperature_color(temp)
    return unpack(temperature_colors[math.max(1, math.floor((temp - 20) / 10))])
end


function draw_frequencies(frequencies, x_min, x_max, y_min, y_max)
    local width, height = x_max - x_min, y_max - y_min
    local df = max_freq - min_freq

    font_normal(10)
    cairo_set_source_rgba(cr, r, g, b, .6)

    function tic(freq, size, label)
        local x = x_min + width * (freq - min_freq) / df
        cairo_move_to(cr, math.floor(x) + .5, y_max + .5)
        cairo_line_to(cr, math.floor(x) + .5, y_max + size + .5)
        cairo_set_line_width(cr, 1)
        cairo_stroke(cr)
        if label then
            write_centered(x, y_max + 7.5, freq)
        end
    end
    for freq = 1, 4 do
        tic(freq, 3, freq)
    end
    for freq = 1, 4, .25 do
        tic(freq, 2)
    end

    polygon({
        x_min, y_max - height * min_freq / max_freq,
        x_max, y_min,
        x_max, y_max,
        x_min, y_max,
    })
    cairo_set_source_rgba(cr, r, g, b, .1)
    cairo_set_line_width(cr, 1)
    cairo_fill_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, .3)
    cairo_stroke_preserve(cr)

    -- frequencies
    for id = 1, 6 do
        local stop = (frequencies[id] - min_freq) / df
        local pat = cairo_pattern_create_linear(x_min, 0, x_max, 0)
        cairo_pattern_add_color_stop_rgba(pat, stop - .2,  r, g, b, .01)
        cairo_pattern_add_color_stop_rgba(pat, stop - .02, r, g, b, .2)
        cairo_pattern_add_color_stop_rgba(pat, stop,       r, g, b, .6)
        cairo_pattern_add_color_stop_rgba(pat, stop,       r, g, b, 0)
        cairo_set_source(cr, pat);
        cairo_fill_preserve(cr)
        cairo_pattern_destroy(pat);
    end
    cairo_new_path(cr)
end

function draw_hex_cpu(mx, my, usages, frequencies, temperatures)
    cairo_set_source_rgba(cr, r, g, b, .4)
    font_bold(16)
    write_centered(mx + 1, my, string.format("%d°", avg(temperatures)))
    -- font_normal(10)
    -- write_centered(mx + 1, my + 6, string.format("%d%%", avg(usages)))

    hexagon(mx, my, 12)
    cairo_set_line_width(cr, 6)
    cairo_set_source_rgba(cr, r, g, b, .2)
    cairo_stroke_preserve(cr)
    cairo_set_line_width(cr, 1)
    cairo_set_source_rgba(cr, 0, 0, 0, .66)
    cairo_stroke_preserve(cr)
    cairo_set_source_rgba(cr, r, g, b, .18)
    cairo_fill(cr)

    --- cores
    font_normal(10)
    for id = 1, 6 do
        draw_hex_cpu_segment(id,
                 usages[id] / 100,
                 frequencies[id],
                 temperatures[id],
                 mx, my, 14, 26, 2.5)
    end
end

function draw_hex_cpu_segment(id, usage, freq, temp, mx, my, min, max, gap)
    local r, g, b = temperature_color(temp)

    local gradient = hexagon_segment_gradient(id, mx, my, min, max, gap)
    cairo_set_line_width(cr, .5)
    cairo_set_source_rgba(cr, r, g, b, .4)
    cairo_stroke_preserve(cr)

    local h = math.sqrt(usage * (max*max - min*min) + min*min)
    local h_rel = (h - min) / (max - min)
    cairo_pattern_add_color_stop_rgba(gradient, 0, r, g, b, .5);
    cairo_pattern_add_color_stop_rgba(gradient, h_rel, r, g, b, .75);
    cairo_pattern_add_color_stop_rgba(gradient, h_rel + .05, r, g, b, .25);
    cairo_pattern_add_color_stop_rgba(gradient, h_rel + .3, r, g, b, .15);
    cairo_pattern_add_color_stop_rgba(gradient, 1, r, g, b, .15);
    cairo_set_source(cr, gradient)
    cairo_fill(cr)
    cairo_pattern_destroy(gradient);

    -- hexagon_segment(id, mx, my, min, h, gap)
    -- cairo_set_source_rgba(cr, r, g, b, .75)
    -- cairo_fill(cr)

    --- frequence outside in ---
    -- hexagon_segment(id, mx, my, max - freq, max, gap)
    -- cairo_set_source_rgba(cr, r, g, b, .25)
    -- cairo_fill(cr)

    --- text ---
    -- font_bold(10)
    -- cairo_set_source_rgba(cr, r, g, b, .2)
    -- write_centered(mx + hor_hex_offsets[id][1] * 22,
    --                my + hor_hex_offsets[id][2] * 22,
    --                id - 1)
    --                -- string.format("%.1f", freq))
    --                -- string.format("%d%%", usage * 100))
end


---------------------
--+–––––––––––––––+--
--| CAIRO HELPERS |--
--+–––––––––––––––+--
---------------------

function hexagon_segment(id, mx, my, min, max, gap)
    local offset1x, offset1y = unpack(vert_hex_offsets[id])
    local offset2x, offset2y = unpack(vert_hex_offsets[id % 6 + 1])
    local gapx, gapy = unpack(hor_hex_offsets[id])
    gapx, gapy = gapx * gap, gapy * gap
    polygon({
        mx + min * offset1x + gapx, my + min * offset1y + gapy,
        mx + max * offset1x + gapx, my + max * offset1y + gapy,
        mx + max * offset2x + gapx, my + max * offset2y + gapy,
        mx + min * offset2x + gapx, my + min * offset2y + gapy,
    })
end

function hexagon_segment_gradient(id, mx, my, min, max, gap)
    local offset1x, offset1y = unpack(vert_hex_offsets[id])
    local offset2x, offset2y = unpack(vert_hex_offsets[id % 6 + 1])
    local gapx, gapy = unpack(hor_hex_offsets[id])
    gapx, gapy = gapx * gap, gapy * gap
    local coords = {
        mx + min * offset1x + gapx, my + min * offset1y + gapy,
        mx + max * offset1x + gapx, my + max * offset1y + gapy,
        mx + max * offset2x + gapx, my + max * offset2y + gapy,
        mx + min * offset2x + gapx, my + min * offset2y + gapy,
    }
    polygon(coords)

    local inner_mid_x = (coords[1] + coords[7]) / 2
    local inner_mid_y = (coords[2] + coords[8]) / 2
    local outer_mid_x = (coords[3] + coords[5]) / 2
    local outer_mid_y = (coords[4] + coords[6]) / 2
    local pat = cairo_pattern_create_linear(inner_mid_x,
                                            inner_mid_y,
                                            outer_mid_x,
                                            outer_mid_y);
    return pat
end

function hexagon(mx, my, scale)
    local coords = {}
    for i = 1, 6 do
        table.insert(coords, mx + scale * vert_hex_offsets[i][1])
        table.insert(coords, my + scale * vert_hex_offsets[i][2])
    end
    polygon(coords)
end

function polygon(coordinates)
    cairo_move_to(cr, coordinates[1], coordinates[2])
    for i = 3, #coordinates, 2 do
        cairo_line_to(cr, coordinates[i], coordinates[i + 1])
    end
    cairo_close_path(cr)
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



function init_cairo()
    if conky_window == nil then
        return false
    end
    local cs = cairo_xlib_surface_create(conky_window.display,
                                         conky_window.drawable,
                                         conky_window.visual,
                                         win_width,
                                         win_height)
    cr = cairo_create(cs)
    font_normal()
    return true
end

function destruct_cairo()
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    cr = nil
end

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
