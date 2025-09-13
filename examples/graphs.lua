--- Conky config script

-- Conky does not add our config directory to lua's PATH, so we do it manually
local script_dir = debug.getinfo(1, 'S').source:match("^@(.*/)") or "./"
package.path = script_dir .. "../?.lua;" .. package.path

local data = require('src/data')
local polycore = require('src/polycore')
local core  = require('src/widgets/core')
local ind = require('src/widgets/indicator')
local text  = require('src/widgets/text')



local GRAPH_SMOOTHINGS = {0, 0.2, 0.5, 0.7, 1.0}

local width = 400 + 2 * 10
local height = (60 + 20) * #GRAPH_SMOOTHINGS + 2 * 10

--- Called once on startup to initialize widgets.
-- @treturn widget.Renderer
function polycore.setup()
    local graphs = {}
    local widgets = {}
    for _, smoothness in ipairs(GRAPH_SMOOTHINGS) do
        local graph = ind.Graph{
            smoothness=smoothness,
            data_points=90,
            max=5 * 1024,
        }
        table.insert(graphs, graph)

        local heading = text.TextLine{}
        heading:set_text(("Smoothness: %.1f"):format(smoothness))
        table.insert(widgets, core.Filler{height=5})
        table.insert(widgets, heading)
        table.insert(widgets, core.Filler{height=4})
        table.insert(widgets, graph)
    end

    local root = core.Frame(core.Rows(widgets), {padding={5, 10, 10}})

    function root.update()
        local downspeed, _ = data.network_speed("enp0s31f6")
        for i = 1, #graphs do
            graphs[i]:add_value(downspeed)
        end
    end

    return core.Renderer{root=root, width=width, height=height}
end


local conkyrc = conky or {}
conkyrc.config = {
    lua_load = script_dir .. "graphs.lua",
    lua_startup_hook = "conky_setup",
    lua_draw_hook_post = "conky_update",

    update_interval = 1,

    -- awesome wm --
    own_window = true,
    own_window_class = 'conky',
    own_window_type = 'override',
    own_window_hints = 'undecorated,sticky,skip_taskbar,skip_pager',

    double_buffer = true,

    alignment = 'middle_middle',
    gap_x = 0,
    gap_y = 0,
    minimum_width = width,
    maximum_width = width,
    minimum_height = height,

    draw_shades = false,
    draw_outline = false,
    draw_borders = false,
    border_width = 0,
    border_inner_margin = 0,
    border_outer_margin = 0,

    net_avg_samples = 1,

    -- colors --
    own_window_colour = '131313',
    own_window_argb_visual = true,
    own_window_argb_value = 230,
    default_color = 'fafafa',
}
conkyrc.text = ""
