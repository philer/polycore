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

text_color = {1, 1, 1, .8}
temperature_colors = {
    {.4,  1,  1},
    {.5,  1, .8},
    {.7, .9, .6},
    {1,  .9, .4},
    {1,  .6, .2},
    {1,  .2, .2},
}
graph_color = temperature_colors[1]
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

os.setlocale("C")  -- decimal dot

local cr, cs
local win_width = 140
local x_left = 10
local x_right = win_width - x_left

local wili
local fan_rpm_text, cpu_temps_text
local downspeed_graph, upspeed_graph

function setup()
    wili = widget.WidgetList(140, 1080 - 28, 10)
    wili:add(widget.Gap(100))
    fan_rpm_text = wili:add(widget.TextLine())
    cpu_temps_text = wili:add(widget.TextLine())
    wili:add(widget.Gap(8))
    wili:add(widget.Cpu(6, 23, 5, 24))
    wili:add(widget.Gap(12))
    wili:add(widget.CpuFrequencies(6, 0.75, 4.3, 16))
    wili:add(widget.Gap(138))
    wili:add(widget.MemoryGrid(5, 40, 2, 1, true))
    wili:add(widget.Gap(84))
    wili:add(widget.Gpu())
    wili:add(widget.Gap(130))
    downspeed_graph = wili:add(widget.Graph(20, 10*1024))
    wili:add(widget.Gap(33))
    upspeed_graph = wili:add(widget.Graph(20, 1024))
    wili:layout()

    -- hacky right border
    local bg_cr = cairo_create(wili._background_surface)
    cairo_move_to(bg_cr, wili.width - .5, 0)
    cairo_line_to(bg_cr, wili.width - .5, wili.height)
    cairo_set_antialias(bg_cr, CAIRO_ANTIALIAS_NONE)
    cairo_set_line_width(bg_cr, 1)
    cairo_set_source_rgba(bg_cr, 1, 1, 1, .05)
    cairo_stroke(bg_cr)
    cairo_destroy(bg_cr)
end

function update(cr, update_count)
    local fan1, fan2 = unpack(data.fan_rpm())
    fan_rpm_text:set_text(fan1 .. " rpm   ·   " .. fan2 .. " rpm")

    local cpu_temps = data.cpu_temperatures()
    cpu_temps_text:set_text(table.concat(cpu_temps, " · ") .. " °C")

    local down, up = data.network_speed("enp0s31f6")
    downspeed_graph:add_value(down)
    upspeed_graph:add_value(up)

    wili:update()
    wili:render(cr)

    local y_offset = 800 - 10
    font_normal(cr)
    cairo_set_source_rgba(cr, unpack(text_color))
    local drive_height = 47
    for _, drive in ipairs(drives) do
        if data.is_mounted(drive[1]) then
            draw_drive(drive[1], drive[2], y_offset)
            y_offset = y_offset + drive_height
        end
    end

    util.reset_data(update_count)
end


--- DRAWING ---

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


--+–––––––––––––––+--
--| CAIRO HELPERS |--
--+–––––––––––––––+--

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
