--- Conky config script

local conkyrc = conky or {}

local script_dir = debug.getinfo(1, 'S').source:match("^@(.*/)") or "./"

conkyrc.config = {
    lua_load = script_dir .. "layout.lua",

    -- positioning --
    alignment = 'top_left',
    gap_x = 0,
    gap_y = 28,
    minimum_width = 140,
    maximum_width = 140,
    minimum_height = 1080 - 28,

    -- font --
    font = 'Ubuntu:pixelsize=10',
    draw_shades = true,
    default_shade_color = 'black',

    -- colors --
    own_window_colour = '131313',
    own_window_argb_visual = true,
    own_window_argb_value = 180,
    default_color = 'fafafa',
    color0 = '337777',  -- titles
    color1 = 'b9b9b7',  -- secondary text color
    color2 = 'bb5544',  -- high temperature warning color

    -----------------
    --- templates ---
    -----------------

    -- title: title
    template1 = [[
${template9}${offset 1}${font Ubuntu:pixelsize=11:bold}${color0}[ \1 ]$color$font]],

    -- top (cpu): number
    template2 = [[
${template9}${color1}${top name \1}${template8}${top cpu \1} %$color]],

    -- top (mem): number
    template3 = [[
${template9}${color1}${top_mem name \1}${template8}${top_mem mem_res \1}$color]],

    -- drives: name dir --
    template5 = [[
${if_mounted \2}
${template9}${offset 1}${font Ubuntu:pixelsize=11:bold}${color0}· \1 ·
${voffset 8}#
${template9}${color1}${font Ubuntu:pixelsize=10}${fs_used \2}  /  ${fs_size \2}#
${if_match ${fs_used_perc \2}>=85}${color2}$else$color$endif#
${template8}${fs_used_perc \2}%$font$color
$endif]],

    -- distance middle | right | left
    template7 = '${alignc}',
    template8 = '${alignr 10}',
    template9 = '${goto 10}',
}

core_config = require('src/config/core')

if os.getenv("DESKTOP") == "Enlightenment" then
    wm_config = require('src/config/enlightenment')
else
    wm_config = require('src/config/awesome')
end

tmp_config = util.merge_table(core_config, wm_config)
config = util.merge_table(tmp_config, script_config)

conkyrc.config = config
-----------------
----- START -----
-----------------

conkyrc.text = [[
${voffset 30}#
${font TeXGyreChorus:pixelsize=20:bold}${alignc}Linux ${color 44dddd}Mint$color$font

$color1#
${alignc}${time %d.%m.%Y}
${alignc}${time %H:%M}
$color#
#
### cpu ###
${voffset 200}
#
### top ###
${template1 top}${template8}cpu
${voffset 3}#
${template2 1}
${template2 2}
${template2 3}
${template2 4}
${template2 5}


### mem ###
${template1 mem} ${template8}$memperc %
${voffset 12}
### memtop ###
${template3 1}
${template3 2}
${template3 3}


### GPU ###
${template1 gpu}  ${nvidia gpufreq} MHz#
${template8}#
${if_match 75 <= ${nvidia temp}}${color2}${font Ubuntu:pixelsize=10:bold}$endif#
${nvidia temp}°C$color
${voffset 78}


### net ###
${template1 net}
${voffset 3}#
${template9}${color1}Down$color${template8}${downspeed enp0s31f6}
${template9}${color1}Total$color${template8}${totaldown enp0s31f6}
${voffset 29}#
${template9}${color1}Up$color${template8}${upspeed enp0s31f6}
${template9}${color1}Total$color${template8}${totalup enp0s31f6}




### drives ###
${template5 root /}#
${template5 blackstor /mnt/blackstor}#
${template5 bluestor /mnt/bluestor}#
#
${image ~/.config/conky/polycore/9blocks.png -p 60,990 -s 16x16}#
]]

return conkyrc
