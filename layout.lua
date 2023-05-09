--- Conky entry point script

-- Conky does not add our config directory to lua's PATH, so we do it manually
local script_dir = debug.getinfo(1, 'S').source:match("^@(.*/)") or "./"
package.path = script_dir .. "?.lua;" .. package.path

local conkyrc = require('conkyrc')
local polycore = require('src/polycore')
local data = require('src/data')
local core = require('src/widgets/core')
local cpu = require('src/widgets/cpu')
local drive = require('src/widgets/drive')
local gpu = require('src/widgets/gpu')
local mem = require('src/widgets/memory')
local net = require('src/widgets/network')
local text  = require('src/widgets/text')

-- Draw debug information
DEBUG = false


--- Called once on startup to initialize widgets.
-- @treturn core.Renderer
function polycore.setup()

    local secondary_text_color = {.72, .72, .71, 1}  -- ~b9b9b7

    -- Write fan speeds. This requires lm_sensors to be installed.
    -- Run `sensonrs` to see if any fans are reported. If not, remove
    -- this section and the corresponding line below.
    local fan_rpm_text = text.TextLine{align="center", color=secondary_text_color}
    fan_rpm_text.update = function(self)
        local fans = data.fan_rpm()
        self:set_text(table.concat{fans[1], " rpm   ·   ", fans[2], " rpm"})
    end

    -- Write individual CPU core temperatures as text.
    -- This also relies on lm_sensors.
    local cpu_temps_text = text.TextLine{align="center", color=secondary_text_color}
    cpu_temps_text.update = function(self)
        local cpu_temps = data.cpu_temperatures()
        self:set_text(table.concat(cpu_temps, " · ") .. " °C")
    end

    -- Write individual CPU core temperatures as text.
    -- This also relies on lm_sensors.
    local gpu_power_text = text.TextLine{align="right", font_size=10.1}
    gpu_power_text.update = function(self)
        local fans = data.fan_rpm()
        local gpu_power_draw = string.format("%.0f", data.gpu_power_draw())
        self:set_text(table.concat{gpu_power_draw, " W       ", fans[5], " rpm"})
    end

    local widgets = {
        fan_rpm_text,  -- see above
        cpu_temps_text,  -- see above
        core.Filler{height=3},

        -- Adjust the CPU core count to your system.
        -- Requires lm_sensors for CPU temperatures.
        cpu.Cpu{cores=8, inner_radius=28, gap=5, outer_radius=57},
        core.Filler{height=7},
        cpu.CpuFrequencies{cores=8, min_freq=0.75, max_freq=4.3},
        core.Filler{height=129},

        -- See also widget.MemoryBar
        mem.MemoryGrid{rows=5},
        core.Filler{height=78},

        -- Requires `nvidia-smi` to be installed. Does not work for AMD GPUs.
        gpu_power_text,  -- see above
        core.Filler{height=2},
        gpu.Gpu(),
        core.Filler{height=1},
        gpu.GpuTop{lines=5, color=secondary_text_color},
        core.Filler{height=66},

        -- Adjust the interface name for your system. Run `ifconfig` to find
        -- out yours. Common names are "eth0" and "wlan0".
        net.Network{interface="enp34s0u1u3u4", downspeed=5 * 1024, upspeed=1024,
                       graph_height=22},
        core.Filler{height=34},

        -- Mount paths. Devices that aren't mounted will not be rendered until
        -- they appear. That way external drives can be displayed automatically.
        drive.Drive("/"),
        drive.Drive("/mnt/blackstor"),
        drive.Drive("/mnt/bluestor"),
        core.Filler(),
    }
    local root = core.Frame(core.Rows(widgets), {
        padding={108, 9, 10, 10},
        border_color={0.8, 1, 1, 0.05},
        border_width = 1,
        border_sides = {"right"},
    })
    return core.Renderer{root=root,
                           width=conkyrc.config.minimum_width,
                           height=conkyrc.config.minimum_height}
end
