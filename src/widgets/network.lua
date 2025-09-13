--- A collection of Network Widget classes
-- @module widget_network
-- @alias wnet

pcall(function() require('cairo') end)

local data = require('src/data')
local util = require('src/util')
local ch = require('src/cairo_helpers')
local core = require('src/widgets/core')
local graph = require('src/widgets/graph')
local Widget = core.Widget

-- lua 5.1 to 5.3 compatibility
local unpack = unpack or table.unpack  -- luacheck: read_globals unpack table

local sin, cos, tan, PI = math.sin, math.cos, math.tan, math.pi
local floor, ceil, clamp = math.floor, math.ceil, util.clamp

--- Graphs for up- and download speed.
-- This widget assumes that your conky.text adds some text between the graphs.
-- @type Network
local Network = util.class(core.Rows)
w.Network = Network

--- @tparam table args table of options
-- @string args.interface e.g. "eth0"
-- @tparam ?int args.graph_height passed to `Graph:init`
-- @number[opt=1024] args.downspeed passed as args.max to download speed graph
-- @number[opt=1024] args.upspeed passed as args.max to upload speed graph
function Network:init(args)
    self.interface = args.interface
    self._downspeed_graph = graph.Graph{height=args.graph_height, max=args.downspeed or 1024}
    self._upspeed_graph = graph.Graph{height=args.graph_height, max=args.upspeed or 1024}
    core.Rows.init(self, {self._downspeed_graph, core.Filler{height=31}, self._upspeed_graph})
end

function Network:update()
    local down, up = data.network_speed(self.interface)
    self._downspeed_graph:add_value(down)
    self._upspeed_graph:add_value(up)
end

return w
