conky.config = {
    update_interval = 1,
    total_run_times = 0,

    -- awesome wm --
    out_to_console = false,
    out_to_stderr = false,
    extra_newline = false,
    own_window = true,
    own_window_class = 'Conky',
    own_window_type = 'override',
    own_window_hints = 'undecorated,sticky,skip_taskbar,skip_pager',
    -- own_window_transparent = true,
    own_window_colour = '111111',
    own_window_argb_visual = true,
    own_window_argb_value = 180,

    background = false,

    double_buffer = true,
    no_buffers = true,
    override_utf8_locale = true,

    alignment = 'top_left',
    gap_x = 0,
    gap_y = 28,
    minimum_width = 140,
    maximum_width = 140,
    -- minimum_height = 732, -- 700 minus bar height
    minimum_height = 1080 - 24,
    -- maximum_height = 690, -- 700 minus bar height (Unknown setting)

    uppercase = false,
    --use_spacer left
    cpu_avg_samples = 2,
    net_avg_samples = 1,

    top_cpu_separate = true,
    top_name_width = 10,

    draw_shades = false,
    draw_outline = false,
    draw_borders = false,
    border_inner_margin = 0,
    border_outer_margin = 0,
    draw_graph_borders = false,
    border_width = 0,

    -- font --
    use_xft = true,
    font = 'Ubuntu:pixelsize=10',
    xftalpha = 0.1,

    -- bars --
    default_bar_width = 120,
    default_bar_height = 4,
    --default_graph_size 40 20
    default_graph_width = 120,
    default_graph_height = 16,

    ------------
    -- colors --
    ------------
    default_shade_color = '191919',
    --default_outline_color black

    default_color = 'fafafa',

    color0 = '366',    -- titles
    color1 = 'b9b9b7', -- secondary text color
    color2 = '466',    -- bar seperator
    color3 = '99c5c5', -- bar color
    color4 = '0A0A0A', -- bar borders
    color5 = '1f2c2b', -- bar background
    -- color6 = '393529', -- bar second
    -- color7 = '6df',    -- clock foreground
    -- color8 = '304150', -- clock background

    -- color0 = '752',    -- titles
    -- color1 = 'c9b9a7', -- secondary text color
    -- color2 = '654',    -- bar seperator
    -- color3 = 'ddc599', -- bar color
    -- color4 = '0A0A0A', -- bar borders
    -- color5 = '2c2b1f', -- bar background
    -- color6 = '393529', -- bar second
    -- color7 = '6df',    -- clock foreground
    -- color8 = '304150', -- clock background


    --- lua ---
    lua_load = "~/.config/conky/hexcore.lua",
    -- lua_startup_hook = "init",
    lua_draw_hook_post = "main",


    -----------------
    --- templates ---
    -----------------

    -- bars: bartype arg
    template0 = [[
${template9}$color5${execbar ~/bin/echo100.sh}$color3${template9}${\1 \2}${template9}$color4${execbar ~/bin/echo0.sh}$color]],

    -- bars: bartype arg1 arg2
    template1 = [[
${template9}$color5${execbar ~/bin/echo100.sh}$color3${template9}${\1 \2 \3}${template9}$color4${execbar ~/bin/echo0.sh}$color]],

    -- top: number
    template2 = [[
${template9}${color1}${top name \1}${template8}${top cpu \1}${top mem \1}$color]],

--     -- top (cpu): number
--     template3 = [[
-- ${template9}${color1}${top name \1}${template8}${top cpu \1}$color]],

    -- top (mem): number
    template4 = [[
${template9}${color1}${top_mem name \1}${template8}${top_mem mem_res \1}$color]],

    -- drives: name dir --
    template5 = [[
${if_mounted \2}
${template9}${offset 1}${font Ubuntu:pixelsize=11:bold}${color0}· \1 ·\n${color1}${font Ubuntu:pixelsize=10}${template9}${fs_used \2}  /   ${fs_size \2}${template8}${if_match ${fs_used_perc \2}>=85}${color b54}$endif${fs_used_perc \2}%$color$font\n${template0 fs_bar \2}$color
$endif]],

    -- title: title
    template6 = [[
${template9}${offset 1}${font Ubuntu:pixelsize=11:bold}${color0}[ \1 ]$color$font]],

    -- distance middle | right | left
    template7 = '${alignc}',
    template8 = '${alignr 10}',
    template9 = '${goto 10}',

};

-----------------
----- START -----
-----------------

conky.text = [[
${voffset 40}#
#${font Ubuntu:pixelsize=14:bold}${alignc}Linux ${color fd9}Mint$color2${font}
${font TeXGyreChorus:pixelsize=20:bold}${alignc}Linux ${color 9dd}Mint$color2${font}
${voffset 10}#
$color1#
${alignc}${time %d.%m.%Y}
${alignc}${time %H:%M}
# ${alignc}$uptime_short
$color#
${voffset 20}#
#$uptime_short
#$kernel
#$sysname
#
#
### cpu ###
# ${voffset 0}${template6 cpu}  ${color1}${freq_g} GHz $color${template8}${cpu cpu0}%
# ${template0 cpubar cpu1} ${freq_g 1} GHz
# ${template0 cpubar cpu2} ${freq_g 2} GHz
# #${voffset -8}${template7}${color2}·${color}
# ${template0 cpubar cpu3} ${freq_g 3} GHz
# ${template0 cpubar cpu4} ${freq_g 4} GHz
# #${voffset -8}${template7}${color2}·${color}
# ${template0 cpubar cpu5} ${freq_g 5} GHz
# ${template0 cpubar cpu6} ${freq_g 6} GHz
# #${voffset -8}${template7}${color2}·${color}
# #${voffset -5}${template0 cpubar cpu7}
# #${voffset -6}${template0 cpubar cpu8}
# $alignc$color1${execi 2 ~/bin/temps.sh} °C
# #$template9$color5${execgraph ~/bin/echo100.sh}${offset -100}$color3${cpugraph cpu0 10,100}$color
#
#
#${voffset 5}#
#${goto 3}temp#
#${goto 55}${font Ubuntu:pixelsize=11:bold}${color0}[ cpu ]$color$font#
#${alignr 3}freq
${voffset 150}
#
#
### GPU ###
${voffset 30}${template6 gpu}  ${color1}${nvidia gpufreq} MHz#
${template8}#
${if_match 75 <= ${nvidia temp}}${color b54}${font Ubuntu:pixelsize=10:bold}$endif#
${nvidia temp}°C$color
${voffset 1}${template1 execibar 3 ~/bin/nvidia-usage.sh}
$color1${execpi 5 ~/bin/nvidia-top.sh}
#
##### temperature (nvidia) ###
##${voffset 10}$template9${offset 1}${font Ubuntu:pixelsize=11:bold}$color0[ tmp ]$color$font#
##${if_match 75 <= ${execi 2 ~/bin/nvidia-temp.sh}}${color b54}${font Ubuntu:pixelsize=10:bold}$endif#
##${template8}${execi 2 ~/bin/nvidia-temp.sh}°C$color
###$template9$color3${execigauge 1 ~/bin/nvidia-temp.sh}
###$template9$color3${execigraph ~/bin/nvidia-temp.sh}
##$template9$color5${execigraph ~/bin/echo100.sh 16,120}$color3$template9${execigraph ~/bin/nvidia-temp.sh 16,120}$color
#
#
### ram | mem ###
${voffset 30}${template9}${offset 1}${font Ubuntu:pixelsize=11:bold}${color0}[ mem ]$color$font#
#${template8}$memperc% ${color2}·${color} $swapperc% ${color2}·${color} ${execi 3 ~/bin/nvidia-vram-perc.sh}%
${template8}$memperc% ${color2}·${color} ${execi 3 ~/bin/nvidia-vram-perc.sh}%
${voffset 1}${template0 membar  }
#${voffset -8}${template7}${color2}·${color}
#${voffset -5}${template0 swapbar  }
${voffset -8}${template7}${color2}·${color}
${voffset -5}${template0 execibar 5\ ~/bin/nvidia-vram-perc.sh}
#
### memtop ###
# ${voffset 10}#
# ${template6 top_mem}
# ${voffset 3}#
${template4 1}
${template4 2}
${template4 3}
#
#
### top ###
${voffset 30}#
${template6 top}
${voffset 3}#
${template2 1}
${template2 2}
${template2 3}
${template2 4}
${template2 5}
#
#
#
#
### net ###
${voffset 30}#
${template6 net}
${voffset 3}#
${template9}${color1}Down$color${template8}${downspeed enp0s31f6}
${template9}${color1}Day$color${template8}${totaldown enp0s31f6}
${voffset 1}#
$template9$color5${execigraph ~/bin/echo100.sh 16,120}$template9$color3${downspeedgraph enp0s31f6 16,120 -l}$color
#${template9}$color3${downspeedgraph enp0s31f6 16,120 -l}$color
${voffset 3}#
${template9}${color1}Up$color${template8}${upspeed enp0s31f6}${color}
${template9}${color1}Day$color${template8}${totalup enp0s31f6}
${voffset 1}#
$template9$color5${execigraph ~/bin/echo100.sh 16,120}$template9$color3${upspeedgraph enp0s31f6 16,120 -l}$color
#${template9}$color3${upspeedgraph enp0s31f6 16,120 -l}$color
#
#
### sound ###
# ${voffset 30}${template6 clm}
# ${voffset 3}${color1}${execi 5 ~/.conkytheme/clementine-track.sh}$color
# ${template0 execibar 5\ ~/.conkytheme/clementine-progress.sh }
# ${template0 execibar 10\ qdbus\ org.mpris.clementine\ /Player\ org.freedesktop.MediaPlayer.VolumeGet }
#
# bottom space
${voffset 30}
#
### drives ###
#
${template5 root /}#
${template5 home /home}#
${template5 blackstor /mnt/blackstor}#
${template5 cryptstor /mnt/cryptstor}#
${template5 liliput /mnt/liliput}#
${template5 shire /mnt/shire}#
${image ~/.config/conky/9blocks.png -p 60,980 -s 16x16}#
]];
