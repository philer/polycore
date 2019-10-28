-- This is a lua script for use in conky --

require 'cairo'

-- lua's import system is retarded.
package.path = os.getenv("HOME") .. "/.config/conky/polycore/?.lua;" .. package.path
local data = require 'data'
local util = require 'util'
local widget = require 'widget'

default_font_family = "Ubuntu"
default_font_size = 10
default_text_color = {1, 1, 1, .8}

temperature_colors = {
    {.4,  1,  1},
    {.5,  1, .8},
    {.7, .9, .6},
    {1,  .9, .4},
    {1,  .6, .2},
    {1,  .2, .2},
}
default_graph_color = temperature_colors[1]
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
    wili:add(widget.BorderRight(wili))

    wili:add(widget.Gap(98))
    fan_rpm_text = wili:add(widget.TextLine("center"))
    wili:add(widget.Gap(2))
    cpu_temps_text = wili:add(widget.TextLine("center"))

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

    wili:add(widget.Gap(37))
    wili:add(widget.Drive("/", "/dev/nvme0"))
    wili:add(widget.Drive("/home", "/dev/nvme0"))
    wili:add(widget.Drive("/mnt/blackstor", "WDC WD2002FAEX-007BA0"))
    wili:add(widget.Drive("/mnt/bluestor", "WDC WD20EZRZ-00Z5HB0"))
    wili:add(widget.Drive("/mnt/cryptstor", "/dev/disk/by-uuid/9e340509-be93-42b5-9dcc-99bdbd428e22"))

    wili:layout()
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

    util.reset_data(update_count)
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
    cairo_select_font_face(cr, default_font_family, CAIRO_FONT_SLANT_NORMAL,
                                                    CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, size or default_font_size)
end

function font_bold(cr, size)
    cairo_select_font_face(cr, default_font_family, CAIRO_FONT_SLANT_NORMAL,
                                                    CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, size or default_font_size)
end

function text_extents(cr, text)
    local extents = cairo_text_extents_t:create()
    tolua.takeownership(extents)
    cairo_text_extents(cr, text, extents)
    return extents
end

font_extents = util.memoize(function(font_family, font_size)
    local tmp_surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 100, 100)
    local tmp_cr = cairo_create(tmp_surface)
    cairo_surface_destroy(tmp_surface)
    cairo_select_font_face(tmp_cr, font_family, CAIRO_FONT_SLANT_NORMAL,
                                                CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(tmp_cr, font_size)
    local extents = cairo_font_extents_t:create()
    tolua.takeownership(extents)
    cairo_font_extents(tmp_cr, extents)
    cairo_destroy(tmp_cr)
    return extents
end)

function write_left(cr, x, y, text)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

function write_right(cr, x, y, text)
    cairo_move_to(cr, x - text_extents(cr, text).width, y)
    cairo_show_text(cr, text)
end

function write_centered(cr, mx, y, text)
    local extents = text_extents(cr, text)
    local x = mx - (extents.width / 2 + extents.x_bearing)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

function write_middle(cr, mx, my, text)
    local extents = text_extents(cr, text)
    local x = mx - (extents.width / 2 + extents.x_bearing)
    local y = my - (extents.height / 2 + extents.y_bearing)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
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
