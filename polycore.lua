--- Conky entry point script
-- @module polycore

print(table.concat{"conky ", conky_version, " ", _VERSION})
-- lua 5.1 to 5.3 compatibility
if unpack == nil then unpack = table.unpack end


require 'cairo'

-- Conky does not change PWD to this directory, so we have to add it manually
package.path = os.getenv("HOME") .. "/.config/conky/polycore/?.lua;" .. package.path
local data = require 'data'
local util = require 'util'
local widget = require 'widget'

--- Draw debug information
-- @bool DEBUG
DEBUG = false

os.setlocale("C")  -- decimal dot

local secondary_text_color = {.72, .72, .71, 1}  -- ~b9b9b7
local win_width, win_height = 140, 1080 - 28
local renderer

--- Called once on startup to initialize widgets etc.
local function setup()
    local fan_rpm_text = widget.TextLine{align="center", color=secondary_text_color}
    fan_rpm_text.update = function(self)
        local fans = data.fan_rpm()
        self:set_text(table.concat{fans[1], " rpm   ·   ", fans[2], " rpm"})
    end

    local cpu_temps_text = widget.TextLine{align="center", color=secondary_text_color}
    cpu_temps_text.update = function(self)
        local cpu_temps = data.cpu_temperatures()
        self:set_text(table.concat(cpu_temps, " · ") .. " °C")
    end

    local widgets = {
        fan_rpm_text,
        cpu_temps_text,
        widget.Gap(8),
        widget.Cpu{cores=6, scale=23, gap=5, segment_size=24},
        widget.Gap(12),
        widget.CpuFrequencies{cores=6, min_freq=0.75, max_freq=4.3},
        widget.Gap(136),
        widget.MemoryGrid{rows=5},
        widget.Gap(82),
        widget.Gpu(),
        widget.Gap(1),
        widget.GpuTop{lines=5, color=secondary_text_color},
        widget.Gap(66),
        widget.Network{interface="enp0s31f6", downspeed=5 * 1024, upspeed=1024},
        widget.Gap(34),
        widget.Drive("/", "/dev/nvme0"),
        widget.Drive("/home", "/dev/nvme0"),
        widget.Drive("/mnt/blackstor", "WDC WD2002FAEX-007BA0"),
        widget.Drive("/mnt/bluestor", "WDC WD20EZRZ-00Z5HB0"),
        widget.Drive("/mnt/cryptstor", "/dev/disk/by-uuid/9e340509-be93-42b5-9dcc-99bdbd428e22"),
        widget.Filler(),
    }
    local root = widget.Frame(widget.Group(widgets), {
        padding={108, 9, 10, 10},
        border_color={0.8, 1, 1, 0.05},
        border_width = 1,
        border_sides = {"right"},
    })
    renderer = widget.Renderer{root=root, width=win_width, height=win_height}
    renderer:layout()
end

--- Called once per update cycle to (re-)draw the entire surface.
-- @tparam cairo_t cr
-- @int update_count conky's $update_count
local function update(cr, update_count)
    renderer:update()
    renderer:render(cr)

    util.reset_data(update_count)
end


--- Simple error handler to show a stacktrace.
-- The printed stacktrace will also include this `error_handler` itself.
-- @param err the error to handle
local function error_handler(err)
    print(debug.traceback("\027[31m" .. err .. "\027[0m"))
end

--- Global update cycle entry point, called by conky as per conkyrc.lua.
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
