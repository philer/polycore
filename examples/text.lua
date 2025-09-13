--- Conky config script

-- Conky does not add our config directory to lua's PATH, so we do it manually
local script_dir = debug.getinfo(1, 'S').source:match("^@(.*/)") or "./"
package.path = script_dir .. "../?.lua;" .. package.path

local core = require('src/widgets/core')
local text = require('src/widgets/text')
local polycore = require('src/polycore')
local util = require('src/util')

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
-- @treturn core.Renderer
function polycore.setup()
    local widgets = {
        -- heading
        core.Frame(text.StaticText("Text Demo", {
                font_size=20,
                font_weight=CAIRO_FONT_WEIGHT_BOLD,
                color=core.default_graph_color,
            }), {
            margin={0, 0, 10},
            border_sides={"bottom"},
            border_width=1,
            border_color={1, 1, 1, .5},
        }),

        -- simple text
        text.StaticText"Hello World!",
        core.Filler{height=10},
        text.StaticText("How are you doing?", {align="right"}),

        core.Filler(),

        -- paragraph with newlines
        text.StaticText(LOREM_IPSUM, {
            align="center",
            font_slant=CAIRO_FONT_SLANT_ITALIC,
        }),
    }

    -- news ticker style text line
    local ticker = text.TextLine{align="center"}
    local line_width = 80  -- arbitrary estiamte
    local lipsum = LOREM_IPSUM:gsub("\n", " ")
    lipsum = lipsum .. " " .. lipsum:sub(1, line_width)
    function ticker:update(update_count)
        local offset = update_count % #lipsum
        self:set_text(lipsum:sub(offset, offset + line_width))
    end
    table.insert(widgets, core.Filler())
    table.insert(widgets, core.Frame(ticker, {
        border_sides={"top"},
        border_width=1,
        border_color={1, 1, 1, .5},
    }))

    local root = core.Frame(core.Rows(widgets), {margin=10})
    return core.Renderer{root=root, width=width, height=height}
end


local conkyrc = conky or {}
script_config = {
    lua_load = script_dir .. "text.lua",

    alignment = 'middle_middle',
    gap_x = 0,
    gap_y = 0,
    minimum_width = width,
    maximum_width = width,
    minimum_height = height,

    -- colors --
    own_window_colour = '131313',
    own_window_argb_visual = true,
    own_window_argb_value = 230,
    default_color = 'fafafa',
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

conkyrc.text = ""
