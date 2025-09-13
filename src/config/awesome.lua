--- conky config options for awesomewm
-- @module config_awesomewm
-- @alias cc

pcall(function() require('cairo') end)

config = {
    -- awesome wm --
    own_window = true,
    own_window_class = 'conky',
    own_window_type = 'override',
    own_window_hints = 'undecorated,sticky,skip_taskbar,skip_pager',
}

return config
