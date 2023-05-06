--- A collection of Widget classes
-- @module polycore_theme
-- @alias pt

pcall(function() require('cairo') end)

-- Specified here so it can be used in multiple places
default_graph_color = {.4, 1, 1, 1}

theme = {
    --- Font used by widgets if no other is specified.
    -- @string default_font_family
    default_font_family = "Ubuntu",

    --- Font size used by widgets if no other is specified.
    -- @int default_font_size
    default_font_size = 10,

    --- Text color used by widgets if no other is specified.
    -- @tfield {number,number,number,number} default_text_color
    default_text_color = {.94, .94, .94, 1},  -- ~fafafa

    --- Color used to draw some widgets if no other is specified.
    -- @tfield {number,number,number,number} default_graph_color
    default_graph_color = default_graph_color,

    temperature_colors = {
        default_graph_color,
        {.5,  1, .8},
        {.7, .9, .6},
        {1,  .9, .4},
        {1,  .6, .2},
        {1,  .2, .2},
    }
}

return theme
