--- Conky config script

-- Conky does not add our config directory to lua's PATH, so we do it manually
local script_dir = debug.getinfo(1, 'S').source:match("^@(.*/)") or "./"
package.path = script_dir .. "../?.lua;" .. package.path

local widget = require('src/widget')
local polycore = require('src/polycore')

local width = 400
local height = 250

local LOREM_IPSUM = [[Lorem ipsum dolor sit amet, consectetur adipiscing elit,
sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad
minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea
commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit
esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat
cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est
laborum.]]

--- Called once on startup to initialize widgets.
-- @treturn widget.Renderer
function polycore.setup()
    local widgets = {
        -- heading
        widget.Frame(widget.StaticText("Text Demo", {
                font_size=20,
                font_weight=CAIRO_FONT_WEIGHT_BOLD,
                color=widget.default_graph_color,
            }), {
            margin={0, 0, 10},
            border_sides={"bottom"},
            border_width=1,
            border_color={1, 1, 1, .5},
        }),

        -- simple text
        widget.StaticText"Hello World!",
        widget.Filler{height=10},
        widget.StaticText("How are you doing?", {align="right"}),

        widget.Filler(),

        -- paragraph with newlines
        widget.StaticText(LOREM_IPSUM, {
            align="center",
            font_slant=CAIRO_FONT_SLANT_ITALIC,
        }),
    }

    -- news ticker style text line
    local ticker = widget.TextLine{align="center"}
    local line_width = 80  -- arbitrary estiamte
    local lipsum = LOREM_IPSUM:gsub("\n", " ")
    lipsum = lipsum .. " " .. lipsum:sub(1, line_width)
    function ticker:update(update_count)
        local offset = update_count % #lipsum
        self:set_text(lipsum:sub(offset, offset + line_width))
    end
    table.insert(widgets, widget.Filler())
    table.insert(widgets, widget.Frame(ticker, {
        border_sides={"top"},
        border_width=1,
        border_color={1, 1, 1, .5},
    }))

    local root = widget.Frame(widget.Group(widgets), {margin=10})
    return widget.Renderer{root=root, width=width, height=height}
end


local conkyrc = conky or {}
conkyrc.config = {
    lua_load = script_dir .. "text.lua",
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
    minimum_width = width,
    maximum_width = width,
    minimum_height = height,

    draw_shades = false,
    draw_outline = false,
    draw_borders = false,
    border_width = 0,
    border_inner_margin = 0,
    border_outer_margin = 0,

    net_avg_samples = 1,

    -- colors --
    own_window_colour = '131313',
    own_window_argb_visual = true,
    own_window_argb_value = 230,
    default_color = 'fafafa',
}
conkyrc.text = ""
