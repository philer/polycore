--- Conky config script

local conkyrc = conky or {}

local script_dir = debug.getinfo(1, 'S').source:match("^@(.*/)") or "./"

conkyrc.config = {
    lua_load = script_dir .. "layout.lua",
    lua_startup_hook = "conky_setup",
    lua_draw_hook_post = "conky_update",

    update_interval = 1,

    -- awesome wm --
    own_window = true,
    own_window_class = 'conky',
    own_window_type = 'override',
    own_window_hints = 'undecorated,sticky,skip_taskbar,skip_pager',

    double_buffer = true,

    alignment = 'top_left',
    gap_x = 0,
    gap_y = 28,
    minimum_width = 140,
    maximum_width = 140,
    minimum_height = 1080 - 28,

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
    color0 = '377',    -- titles
    color1 = 'b9b9b7', -- secondary text color

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
${if_match ${fs_used_perc \2}>=85}${color b54}$else$color$endif#
${template8}${fs_used_perc \2}%$font$color
$endif]],

    -- distance middle | right | left
    template7 = '${alignc}',
    template8 = '${alignr 10}',
    template9 = '${goto 10}',
}

-----------------
----- START -----
-----------------

conkyrc.text = [[
${voffset 30}#
${font TeXGyreChorus:pixelsize=20:bold}${alignc}Linux ${color 4dd}Mint$color$font

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
${if_match 75 <= ${nvidia temp}}${color b54}${font Ubuntu:pixelsize=10:bold}$endif#
${nvidia temp}°C$color
${voffset 68}


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
${template5 home /home}#
${template5 blackstor /mnt/blackstor}#
${template5 bluestor /mnt/bluestor}#
${template5 cryptstor /mnt/cryptstor}#
#
${image ~/.config/conky/polycore/9blocks.png -p 60,990 -s 16x16}#
]]

return conkyrc
