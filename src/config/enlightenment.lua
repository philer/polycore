--- conky config options for enlightenment
-- @module config_enlightenment
-- @alias cc

pcall(function() require('cairo') end)

config = {
    -- enlightenment wm --
    own_window = true,
    own_window_class = 'conky',
    own_window_type = 'normal',
    own_window_transparent = false,
    own_window_hints = 'undecorated,sticky,below,skip_taskbar,skip_pager',
}

return config
