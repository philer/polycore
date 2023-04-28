--- Conky config script

-- Conky does not add our config directory to lua's PATH, so we do it manually
local script_dir = debug.getinfo(1, 'S').source:match("^@(.*/)") or "./"
package.path = script_dir .. "../?.lua;" .. package.path

local widget = require('src/widget')
local util = require('src/util')
local data = require('src/data')
local polycore = require('src/polycore')


local width = 500
local height = 540

--- Called once on startup to initialize widgets.
-- @treturn widget.Renderer
function polycore.setup()

    -- dirty hack to pretend I have more cores than I actually do
    local real_cores = 6
    for _, data_fn in ipairs{"cpu_frequencies", "cpu_percentages", "cpu_temperatures"} do
        local fn = data[data_fn]
        data[data_fn] = function()
            local results = fn(real_cores)
            for i = real_cores + 1, 64 do
                results[i] = results[(i - 1) % real_cores + 1] * (math.random() * 0.5 + 0.75)
            end
            util.shuffle(results)
            return results
        end
    end

    local root = widget.Frame(widget.Rows{
        widget.Columns{
            widget.Rows{
                widget.Cpu{cores=6, outer_radius=52, inner_radius=26, gap=5},
                widget.Filler{height=20},
                widget.Cpu{cores=10, outer_radius=52, inner_radius=30, gap=3},
            },
            widget.Rows{
                widget.Cpu{cores=8, outer_radius=52, inner_radius=24, gap=7},
                widget.Filler{height=20},
                widget.Cpu{cores=12, outer_radius=52, inner_radius=36, gap=5},
            },
            widget.Filler{width=20},
            widget.Cpu{cores=6, gap=7, outer_radius=100},
        },
        widget.Filler{},
        widget.Columns{
            widget.Rows{
                widget.CpuRound{cores=6, outer_radius=52, inner_radius=26},
                widget.Filler{height=20},
                widget.CpuRound{cores=16, outer_radius=52, inner_radius=30},
            },
            widget.Rows{
                widget.CpuRound{cores=6, outer_radius=52, inner_radius=24, grid=5},
                widget.Filler{height=20},
                widget.CpuRound{cores=32, outer_radius=52, inner_radius=36, grid=4},
            },
            widget.Filler{width=20},
            widget.CpuRound{cores=64, outer_radius=100, grid=5},
        },

    }, {padding=20})
    return widget.Renderer{root=root, width=width, height=height}
end


local conkyrc = conky or {}
conkyrc.config = {
    lua_load = script_dir .. "cpu.lua",
    lua_startup_hook = "conky_setup",
    lua_draw_hook_pre = "conky_paint_background",
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
