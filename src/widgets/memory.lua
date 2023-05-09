--- A collection of Widget classes
-- @module widget_memory
-- @alias wmem

pcall(function() require('cairo') end)

local data = require('src/data')
local util = require('src/util')
local ch = require('src/cairo_helpers')
local core = require('src/widgets/core')
local ind = require('src/widgets/indicator')
local Widget = core.Widget

-- lua 5.1 to 5.3 compatibility
local unpack = unpack or table.unpack  -- luacheck: read_globals unpack table

local sin, cos, tan, PI = math.sin, math.cos, math.tan, math.pi
local floor, ceil, clamp = math.floor, math.ceil, util.clamp


--- Specialized unit-based Bar.
-- @type MemoryBar
local MemoryBar = util.class(ind.Bar)
w.MemoryBar = MemoryBar

--- @tparam table args table of options
-- @tparam ?number args.total Total amount of memory to be represented
--                            by this bar. If greater than 8, ticks will be
--                            drawn. If omitted, total RAM will be used,
--                            however no ticks can be drawn.
-- @tparam[opt="GiB"] string args.unit passed to `Bar:init`
-- @tparam ?int args.thickness passed to `Bar:init`
-- @tparam ?{number,number,number} args.color passed to `Bar:init`
function MemoryBar:init(args)
    self._total = args.total
    local ticks, big_ticks
    if self._total then
        local max_tick = floor(self._total)
        ticks = util.range(1 / self._total, max_tick / self._total, 1 / self._total)
        big_ticks = max_tick > 8 and 4 or nil
    end
    ind.Bar.init(self, {ticks=ticks,
                    big_ticks=big_ticks,
                    unit=args.unit or "GiB",
                    thickness=args.thickness,
                    color=args.color})
end

--- Set the amount of used memory as an absolute value.
-- @number used should be between 0 and args.total
function MemoryBar:set_used(used)
    self:set_fill(used / self._total)
end

function MemoryBar:update()
    local used, _, _, total = data.memory("GiB")
    self:set_fill(used / total)
end

--- Visualize memory usage in a randomized grid.
-- Does not represent actual distribution of used memory.
-- Also shows buffere/cache memory at reduced brightness.
-- @type MemoryGrid
local MemoryGrid = util.class(Widget)
w.MemoryGrid = MemoryGrid

--- @tparam table args table of options
-- @tparam ?int args.rows Number of rows to draw.
--                        For nil it will be determined based on Widget height.
-- @tparam ?int args.columns Number of columns to draw.
--                           For nil it will be determined based on Widget width.
-- @tparam[opt=2] ?int args.point_size edge length of individual squares
-- @tparam[opt=1] ?int args.gap space between squares
-- @tparam[opt=true] ?bool args.shuffle randomize?
-- @tparam ?{number,number,number} args.color (default: `default_graph_color`)
function MemoryGrid:init(args)
    self._rows = args.rows
    self._columns = args.columns
    self._point_size = args.point_size or 2
    self._gap = args.gap or 1
    self._shuffle = args.shuffle == nil and true or args.shuffle
    self._color = args.color or w.default_graph_color
    if self._rows then
        self.height = self._rows * self._point_size + (self._rows - 1) * self._gap
    end
    if self._columns then
        self.width = self._columns * self._point_size + (self._columns - 1) * self._gap
    end
end

function MemoryGrid:layout(width, height)
    local point_plus_gap = self._point_size + self._gap
    local columns = self._columns or math.floor(width / point_plus_gap)
    local rows = self._rows or math.floor(height / point_plus_gap)
    local left = 0.5 * (width - columns * point_plus_gap + self._gap)
    self._coordinates = {}
    for col = 0, columns - 1 do
        for row = 0, rows - 1 do
            table.insert(self._coordinates, {col * point_plus_gap + left,
                                             row * point_plus_gap,
                                             self._point_size, self._point_size})
        end
    end
    if self._shuffle == nil or self._shuffle then
        util.shuffle(self._coordinates)
    end
end

function MemoryGrid:update()
    self._used, self._easyfree, self._free, self._total = data.memory("GiB")
end

function MemoryGrid:render(cr)
    if self._total <= 0 then return end  -- TODO figure out why this happens
    local total_points = #self._coordinates
    local used_points = math.floor(total_points * self._used / self._total + 0.5)
    local free_points = math.floor(total_points * self._free / self._total + 0.5)
    local r, g, b = unpack(self._color)

    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)
    for i = 1, used_points do
        cairo_rectangle(cr, unpack(self._coordinates[i]))
    end
    cairo_set_source_rgba(cr, r, g, b, .8)
    cairo_fill(cr)
    for i = used_points, total_points - free_points do
        cairo_rectangle(cr, unpack(self._coordinates[i]))
    end
    cairo_set_source_rgba(cr, r, g, b, .35)
    cairo_fill(cr)
    for i = total_points - free_points, total_points do
        cairo_rectangle(cr, unpack(self._coordinates[i]))
    end
    cairo_set_source_rgba(cr, r, g, b, .1)
    cairo_fill(cr)
end

return w
