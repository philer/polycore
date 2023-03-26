--- Conky config script

-- Conky does not add our config directory to lua's PATH, so we do it manually
local script_dir = debug.getinfo(1, 'S').source:match("^@(.*/)") or "./"
package.path = script_dir .. "../?.lua;" .. package.path

local widget = require('src/widget')
local polycore = require('src/polycore')

-- Draw debug information
DEBUG = false


local conkyrc = conky or {}
conkyrc.config = {
    lua_load = script_dir .. "columns.lua",
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
    minimum_width = 800,
    maximum_width = 800,
    minimum_height = 170,

    draw_shades = false,
    draw_outline = false,
    draw_borders = false,
    border_width = 0,
    border_inner_margin = 0,
    border_outer_margin = 0,

    top_cpu_separate = true,
    top_name_width = 10,
    no_buffers = true,  -- include buffers in easyfree memory?
    cpu_avg_samples = 2,
    net_avg_samples = 1,

    -- font --
    use_xft = true,  -- Use Xft (anti-aliased font and stuff)
    font = 'Ubuntu:pixelsize=10',
    override_utf8_locale = true,
    xftalpha = 0,  -- Alpha of Xft font. Must be a value at or between 1 and 0.

    -- colors --
    own_window_colour = '131313',
    own_window_argb_visual = true,
    own_window_argb_value = 180,
    default_color = 'fafafa',
    color0 = '488',    -- titles
    color1 = 'b9b9b7', -- secondary text color


    -- drives: name dir --
    template5 = [[
${if_mounted \2}
${goto 652}${font Ubuntu:pixelsize=11:bold}${color0}· \1 ·#
${voffset 20}#
${goto 652}${color1}${font Ubuntu:pixelsize=10}${fs_used \2}  /  ${fs_size \2}#
${alignr 20}${fs_used_perc \2}%$font$color#
$endif]],
}

-----------------
----- START -----
-----------------

conkyrc.text = [[
${voffset 10}#
${alignc 312}${font TeXGyreChorus:pixelsize=20:bold}#
${color fff}P${color dff}o${color bee}l${color 9ee}y#
${color 7ee}c${color 5ee}o${color 4ee}r${color 3ee}e#
$color$font
#${alignc 320}${font Courier new:pixelsize=20}${color cff}Polycore${color}$font
${font Ubuntu:pixelsize=11:bold}${color0}#
${voffset -14}${alignc  247}[ mem ]
${voffset -14}${alignc  160}[ cpu ]
${voffset -14}${alignc    0}[ gpu ]
${voffset -14}${alignc -160}[ net ]
${voffset -14}${alignc -310}[ dev ]
$color$font${voffset 26}#
#
### top ###
${color1}
${goto 180}${top name 1}${alignr 490}${top cpu 1} %
${goto 180}${top name 2}${alignr 490}${top cpu 2} %
${goto 180}${top name 3}${alignr 490}${top cpu 3} %
${goto 180}${top name 4}${alignr 490}${top cpu 4} %
${goto 180}${top name 5}${alignr 490}${top cpu 5} %
${voffset -92}#
#
### net ###
${goto 495}${color1}Down$color${alignr 180}${downspeed enp0s31f6}
${goto 495}${color1}Total$color${alignr 180}${totaldown enp0s31f6}
${voffset 29}#
${goto 495}${color1}Up$color${alignr 180}${upspeed enp0s31f6}
${goto 495}${color1}Total$color${alignr 180}${totalup enp0s31f6}
${voffset -88}#
#
### drives ###
${template5 root /}#
${voffset 5}#
${template5 home /home}#
${voffset 5}#
${template5 blackstor /mnt/blackstor}#
]]


--- Called once on startup to initialize widgets.
-- @treturn widget.Renderer
function polycore.setup()

    local secondary_text_color = {.72, .72, .71, 1}  -- ~b9b9b7

    local root = widget.Frame(widget.Columns{
        widget.Rows{
            widget.Filler{},
            widget.Cpu{cores=6, inner_radius=28, gap=5, outer_radius=57},
            widget.Filler{},
        },
        widget.Filler{width=10},
        widget.MemoryGrid{columns=5},
        widget.Filler{width=20},
        widget.Rows{
            widget.CpuFrequencies{cores=6, min_freq=0.75, max_freq=4.3},
            widget.Filler{},
        },
        widget.Filler{width=30},
        widget.Rows{
            widget.Filler{height=5},
            widget.Gpu(),
            widget.Filler{height=5},
            widget.GpuTop{lines=5, color=secondary_text_color},
        },
        widget.Filler{width=30},
        widget.Rows{
            widget.Filler{height=26},
            widget.Network{interface="enp0s31f6", downspeed=5 * 1024, upspeed=1024},
        },
        widget.Filler{width=30},
        widget.Rows{
            widget.Drive("/"),
            widget.Filler{height=-9},
            widget.Drive("/home"),
            widget.Filler{height=-9},
            widget.Drive("/mnt/blackstor"),
        },
    }, {
        border_color={0.8, 1, 1, 0.05},
        border_width = 1,
        padding = {40, 20, 20, 10},
    })
    return widget.Renderer{root=root,
                           width=conkyrc.config.minimum_width,
                           height=conkyrc.config.minimum_height}
end
