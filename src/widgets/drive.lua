--- A collection of Disk Drive Widget classes
-- @module widget_drive
-- @alias wdrive

pcall(function() require('cairo') end)

local data = require('src/data')
local util = require('src/util')
local ch = require('src/cairo_helpers')
local core = require('src/widgets/core')
local graph = require('src/widgets/graph')
local text = require('src/widgets/text')
local Widget = core.Widget

-- lua 5.1 to 5.3 compatibility
local unpack = unpack or table.unpack  -- luacheck: read_globals unpack table

local sin, cos, tan, PI = math.sin, math.cos, math.tan, math.pi
local floor, ceil, clamp = math.floor, math.ceil, util.clamp

--- Visualize drive usage and temperature in a colorized Bar.
-- Also writes temperature as text.
-- This widget is exptected to be combined with some special conky.text.
-- @type Drive
local Drive = util.class(Rows)
w.Drive = Drive

--- @string path e.g. "/home"
function Drive:init(path)
    self._path = path

    self._read_led = graph.LED{radius=2, color={0.4, 1, 0.4}}
    self._write_led = graph.LED{radius=2, color={1, 0.4, 0.4}}
    self._temperature_text = text.TextLine{align="right"}
    self._bar = core.Bar{}
    core.Rows.init(self, {
        core.Columns{
            core.Filler{},
            core.Filler{width=6, widget=core.Rows{
                core.Filler{},
                self._read_led,
                core.Filler{height=1},
                self._write_led,
            }},
            core.Filler{width=30, widget=self._temperature_text},
        },
        core.Filler{height=4},
        self._bar,
        core.Filler{height=25},
    })

    self._real_height = self.height
    self.height = 0
    self._is_mounted = false
end

function Drive:layout(...)
    return self._is_mounted and Rows.layout(self, ...) or {}
end

function Drive:update()
    local was_mounted = self._is_mounted
    self._is_mounted = data.is_mounted(self._path)
    if self._is_mounted then
        if not was_mounted then
            self._device, self._physical_device = unpack(data.find_devices()[self._path])
        end
        self._bar:set_fill(data.drive_percentage(self._path) / 100)

        local read = data.diskio(self._device, "read", "B")
        local read_magnitude = util.log2(read)
        self._read_led:set_brightness(read_magnitude / 30)

        local write = data.diskio(self._device, "write", "B")
        local write_magnitude = util.log2(write)
        self._write_led:set_brightness(write_magnitude / 30)

        local temperature = data.device_temperatures()[self._physical_device]
        if temperature then
            self._bar.color = {w.temperature_color(temperature, 35, 65)}
            self._temperature_text:set_text(math.floor(temperature + 0.5) .. "°C")
        else
            self._bar.color = {0.8, 0.8, 0.8}
            self._temperature_text:set_text("––––")
        end
        self.height = self._real_height
    else
        self.height = 0
    end
    return self._is_mounted ~= was_mounted
end

return w
