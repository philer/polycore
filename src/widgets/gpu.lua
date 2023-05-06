--- A collection of GPU Widget classes
-- @module widget_gpu
-- @alias wgpu

pcall(function() require('cairo') end)

local data = require('src/data')
local util = require('src/util')
local ch = require('src/cairo_helpers')
local core = require('src/widgets/core')
local mem = require('src/widgets/memory')
local Widget = core.Widget

-- lua 5.1 to 5.3 compatibility
local unpack = unpack or table.unpack  -- luacheck: read_globals unpack table

local sin, cos, tan, PI = math.sin, math.cos, math.tan, math.pi
local floor, ceil, clamp = math.floor, math.ceil, util.clamp

--- Compound widget to display GPU and VRAM usage.
-- @type Gpu
local Gpu = util.class(core.Rows)
w.Gpu = Gpu

--- no options
function Gpu:init()
    self._usebar = core.Bar{ticks={.25, .5, .75}, unit="%"}

    local _, mem_total = data.gpu_memory()
    self._membar = mem.MemoryBar{total=mem_total / 1024}
    self._membar.update = function()
        self._membar:set_used(data.gpu_memory() / 1024)
    end
    core.Rows.init(self, {self._usebar, core.Filler{height=4}, self._membar})
end

function Gpu:update()
    self._usebar:set_fill(data.gpu_percentage() / 100)

    local color = {w.temperature_color(data.gpu_temperature(), 30, 80)}
    self._usebar.color = color
    self._membar.color = color
end

--- Table of processes for the GPU, sorted by VRAM usage
-- @type GpuTop
local GpuTop = util.class(Widget)
w.GpuTop = GpuTop

--- @tparam table args table of options
-- @tparam[opt=5] ?int args.lines how many processes to display
-- @tparam ?string args.font_family
-- @tparam ?number args.font_size
-- @tparam ?{number,number,number} args.color (default: `default_text_color`)
function GpuTop:init(args)
    self._lines = args.lines or 5
    self._font_family = args.font_family or current_theme.default_font_family
    self._font_size = args.font_size or current_theme.default_font_size
    self._color = args.color or current_theme.default_text_color

    local extents = ch.font_extents(self._font_family, self._font_size)
    self._line_height = extents.height
    self.height = self._lines * self._line_height
    local line_spacing = extents.height - (extents.ascent + extents.descent)
    -- try to match conky's line spacing:
    self._baseline_offset = extents.ascent + 0.5 * line_spacing + 1
end

function GpuTop:layout(width)
    self._width = width
end

function GpuTop:update()
    self._processes = data.gpu_top()
end

function GpuTop:render(cr)
    ch.set_font(cr, self._font_family, self._font_size)
    cairo_set_source_rgba(cr, unpack(self._color))
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)

    local lines = math.min(self._lines, #self._processes)
    local y = self._baseline_offset
    for i = 1, lines do
        ch.write_left(cr, 0, y, self._processes[i][1])
        ch.write_right(cr, self._width, y, self._processes[i][2] .. " MiB")
        y = y + self._line_height
    end
end

return w
