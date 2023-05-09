--- Core conky config that will likely be the same between polycore instances
-- @module config_core
-- @alias cc

pcall(function() require('cairo') end)

config = {
    lua_startup_hook = "conky_setup",
    lua_draw_hook_post = "conky_update",
    
    update_interval = 1,

    double_buffer = true,

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

    override_utf8_locale = true,
    xftalpha = 0,  -- Alpha of Xft font. Must be a value at or between 1 and 0.
}

return config
