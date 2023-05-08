--- A collection of Widget classes
-- @module polycore_theme
-- @alias pt

pcall(function() require('cairo') end)

-- Specified here so it can be used in multiple places
local default_graph_color = "66ffff"

theme = {
    --- Font used by widgets if no other is specified.
    -- @string default_font_family
    default_font_family = "Ubuntu",

    --- Font size used by widgets if no other is specified.
    -- @int default_font_size
    default_font_size = 10,

    --- Text color used by widgets if no other is specified.
    -- @string default_text_color a color hex string
    default_text_color = "fafafa",  -- ~fafafa

    --- A secondary color text color you can use in your themes
    -- currently it is not used by any of the widgets.
    -- @string secondary_text_color a color hex string
    secondary_text_color = "b9b9b7",  -- ~b9b9b7

    --- Color used to draw some widgets if no other is specified.
    -- @string default_graph_color a color hex string
    default_graph_color = default_graph_color,

    temperature_colors = {
        default_graph_color,
        "7fffcc",
        "b2e599",
        "ffe566",
        "ff9933",
        "ff3333",
    }
}

return theme
