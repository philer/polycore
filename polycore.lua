-- This is a lua script for use in conky --

require 'cairo'

-- lua's import system is confusing.
package.path = os.getenv("HOME") .. "/.config/conky/polycore/?.lua;" .. package.path
local data = require 'data'
local util = require 'util'
local widget = require 'widget'

-- global defaults

DEBUG = false

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

local win_width, win_height = 140, 1080 - 28
local renderer

-- Called once on startup to initialize widgets etc.
local function setup()
    local fan_rpm_text = widget.TextLine{align="center"}
    fan_rpm_text.update = function(self)
        local fan1, fan2 = unpack(data.fan_rpm())
        self:set_text(fan1 .. " rpm   ·   " .. fan2 .. " rpm")
    end

    local cpu_temps_text = widget.TextLine{align="center"}
    cpu_temps_text.update = function(self)
        local cpu_temps = data.cpu_temperatures()
        self:set_text(table.concat(cpu_temps, " · ") .. " °C")
    end

    local root = widget.WidgetGroup({
        widget.BorderRight{x=win_width, height=win_height},
        widget.Gap(98),
        fan_rpm_text,
        widget.Gap(2),
        cpu_temps_text,
        widget.Gap(8),
        widget.Cpu{cores=6, scale=23, gap=5, segment_size=24},
        widget.Gap(12),
        widget.CpuFrequencies{cores=6, min_freq=0.75, max_freq=4.3},
        widget.Gap(138),
        widget.MemoryGrid{rows=5, columns=40},
        widget.Gap(84),
        widget.Gpu(),
        widget.Gap(132),
        widget.Network{interface="enp0s31f6", downspeed=5 * 1024, upspeed=1024},
        widget.Gap(37),
        widget.Drive("/", "/dev/nvme0"),
        widget.Drive("/home", "/dev/nvme0"),
        widget.Drive("/mnt/blackstor", "WDC WD2002FAEX-007BA0"),
        widget.Drive("/mnt/bluestor", "WDC WD20EZRZ-00Z5HB0"),
        widget.Drive("/mnt/cryptstor", "/dev/disk/by-uuid/9e340509-be93-42b5-9dcc-99bdbd428e22"),
    })
    renderer = widget.WidgetRenderer{root=root, width=win_width,
                                     height=win_height, padding=10}
    renderer:layout()
end

-- Called once per update cycle to (re-)draw the entire surface.
local function update(cr, update_count)
    renderer:update()
    renderer:render(cr)

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
