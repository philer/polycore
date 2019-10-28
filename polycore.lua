-- This is a lua script for use in conky --

require 'cairo'

-- lua's import system is confusing.
package.path = os.getenv("HOME") .. "/.config/conky/polycore/?.lua;" .. package.path
local data = require 'data'
local util = require 'util'
local widget = require 'widget'

-- global defaults
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


os.setlocale("C")  -- decimal dot

local wili
local fan_rpm_text, cpu_temps_text
local downspeed_graph, upspeed_graph

-- Called once on startup to initialize widgets etc.
local function setup()
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

-- Called once per update cycle to (re-)draw the entire surface.
local function update(cr, update_count)
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


-- Simple error handler to show a stacktrace.
-- Stacktrace will also include conky_main and this error_handler.
local function error_handler(err)
    print(debug.traceback("\027[31m" .. err .. "\027[0m"))
end

-- Global update cycle entry point, called by conky as per conkyrc.lua
-- Takes care of managing the primary cairo drawing context plus some
-- error handling on calling the update function.
function conky_main()
    if conky_window == nil then
        return
    end

    local cs = cairo_xlib_surface_create(conky_window.display,
                                         conky_window.drawable,
                                         conky_window.visual,
                                         conky_window.text_width,
                                         conky_window.text_height)
    local cr = cairo_create(cs)
    cairo_surface_destroy(cs)

    local update_count = tonumber(conky_parse('${updates}'))
    -- Lua 5.1 requires xpcall to use a wrapper function
    local status, err = xpcall(function() update(cr, update_count) end, error_handler)

    cairo_destroy(cr)
end

xpcall(setup, error_handler)
