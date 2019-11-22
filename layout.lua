--- Conky entry point script

-- Conky does not add our config directory to lua's PATH, so we do it manually
local script_dir = debug.getinfo(1, 'S').source:match("^@(.*/)") or "./"
package.path = script_dir .. "?.lua;" .. package.path

local conkyrc = require('conkyrc')
local polycore = require('src/polycore')
local data = require('src/data')
local widget = require('src/widget')

-- Draw debug information
DEBUG = false


--- Called once on startup to initialize widgets.
-- @treturn widget.Renderer
function polycore.setup()

    local secondary_text_color = {.72, .72, .71, 1}  -- ~b9b9b7

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
        widget.Filler{height=8},
        widget.Cpu{cores=6, scale=23, gap=5, segment_size=24},
        widget.Filler{height=12},
        widget.CpuFrequencies{cores=6, min_freq=0.75, max_freq=4.3},
        widget.Filler{height=136},
        widget.MemoryGrid{rows=5},
        widget.Filler{height=82},
        widget.Gpu(),
        widget.Filler{height=1},
        widget.GpuTop{lines=5, color=secondary_text_color},
        widget.Filler{height=66},
        widget.Network{interface="enp0s31f6", downspeed=5 * 1024, upspeed=1024},
        widget.Filler{height=34},
        widget.Drive("/"),
        widget.Drive("/home"),
        widget.Drive("/mnt/blackstor"),
        widget.Drive("/mnt/bluestor"),
        widget.Drive("/mnt/cryptstor"),
        widget.Filler(),
    }
    local root = widget.Frame(widget.Group(widgets), {
        padding={108, 9, 10, 10},
        border_color={0.8, 1, 1, 0.05},
        border_width = 1,
        border_sides = {"right"},
    })
    return widget.Renderer{root=root,
                           width=conkyrc.config.minimum_width,
                           height=conkyrc.config.minimum_height}
end
