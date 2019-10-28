conky.config = {
    update_interval = 1,
    total_run_times = 0,

    -- awesome wm --
    out_to_console = false,
    out_to_stderr = false,
    extra_newline = false,
    own_window = true,
    own_window_class = 'conky',
    own_window_type = 'override',
    own_window_hints = 'undecorated,sticky,skip_taskbar,skip_pager',
    -- own_window_transparent = true,
    own_window_colour = '131313',
    own_window_argb_visual = true,
    own_window_argb_value = 180,

    background = false,

    double_buffer = true,
    no_buffers = true,
    override_utf8_locale = true,

    alignment = 'top_left',
    gap_x = -1920,
    gap_y = 28,
    minimum_width = 140,
    maximum_width = 140,
    minimum_height = 1080 - 28,

    uppercase = false,
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
    xftalpha = 0.1,
    font = 'Ubuntu:pixelsize=10',

    -- bars --
    default_bar_width = 120,
    default_bar_height = 4,
    default_graph_width = 120,
    default_graph_height = 16,

    ------------
    -- colors --
    ------------

    default_color = 'fafafa',

    color0 = '377',    -- titles
    color1 = 'b9b9b7', -- secondary text color

    --- lua ---
    lua_load = os.getenv("HOME") .. "/.config/conky/polycore/polycore.lua",
    -- lua_startup_hook = "init",
    lua_draw_hook_post = "main",


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
${template9}${offset 1}${font Ubuntu:pixelsize=11:bold}${color0}· \1 ·\n${voffset 8}${color1}${font Ubuntu:pixelsize=10}${template9}${fs_used \2}  /  ${fs_size \2}${template8}${if_match ${fs_used_perc \2}>=85}${color b54}$else$color$endif${fs_used_perc \2}%$font$color
$endif]],

    -- distance middle | right | left
    template7 = '${alignc}',
    template8 = '${alignr 10}',
    template9 = '${goto 10}',

};

-----------------
----- START -----
-----------------

conky.text = [[
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
${voffset 20}
$color1${execpi 5 ~/bin/nvidia-top.sh}


### net ###
${template1 net}
${voffset 3}#
${template9}${color1}Down$color${template8}${downspeed enp0s31f6}
${template9}${color1}Total$color${template8}${totaldown enp0s31f6}
${voffset 49}#
${template9}${color1}Up$color${template8}${upspeed enp0s31f6}${color}
${template9}${color1}Total$color${template8}${totalup enp0s31f6}


### drives ###
${template5 root /}#
${template5 home /home}#
${template5 blackstor /mnt/blackstor}#
${template5 bluestor /mnt/bluestor}#
${template5 cryptstor /mnt/cryptstor}#
#
${image ~/.config/conky/polycore/9blocks.png -p 60,990 -s 16x16}#
]];
