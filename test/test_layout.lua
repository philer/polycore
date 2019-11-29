-- Run this test via conky: `conky -c test/test_layout.lua`

-- Conky does not add our config directory to lua's PATH, so we do it manually
local script_dir = debug.getinfo(1, 'S').source:match("^@(.*/)") or "./"
package.path = script_dir .. "../?.lua;" .. package.path

local widget = require('src/widget')

-- minimal conky.config to run this script again once without opening a window
local conkyrc = conky or {}
conkyrc.text = ""
conkyrc.config = {
    lua_load = script_dir .. "test_layout.lua",
    lua_draw_hook_post = "conky_update",
    total_run_times = 1,
    out_to_console = false,
    out_to_x = false,
}


--- utilities ---

local TMP_PREFIX = "/tmp/conky_test_"

--- Render to an image file instead of conky's window canvas.
-- @tparam widget.Renderer renderer
-- @string path
local function render_to_image(renderer, path)
    renderer:layout()
    renderer:update()
    local cs = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, renderer._width,
                                                               renderer._height)
    local cr = cairo_create(cs)
    renderer:render(cr)
    cairo_surface_write_to_png(cs, path)
    cairo_surface_destroy(cs)
    cairo_destroy(cr)
end

--- Check if two image files contain the same pixels
-- requires imagemagick
-- @string candidate_path
-- @string expected_path
local function assert_images_equal(candidate_path, expected_path)
    local command_template = 'compare -identify -metric MAE "%s" "%s" null >/dev/null 2>&1'
    local result = os.execute(command_template:format(candidate_path, expected_path))

    -- os.execute returns changed from 5.1 to 5.3
    assert(result == true or result == 0,
           "render of at " .. candidate_path
           .. " does not match expected result at " .. expected_path)
end

--- Assert that the output of a given renderer matches an existing image.
-- @string name test name
-- @string widget.Renderer renderer
local function check_renderer(name, renderer)
    local out_path = TMP_PREFIX .. name .. ".png"
    local expected = script_dir .. "expected_outputs/" .. name .. ".png"
    render_to_image(renderer, out_path)
    assert_images_equal(out_path, expected)
end

local frame_opts = {
    background_color = {0.2, 0.4, 0.9, 0.4},
    border_color = {0.3, 0.6, 0.9, 1},
    border_width = 2,
}

--- Mock Widget that does nothing but has a background plus border.
local function dummy(args)
    return widget.Frame(widget.Filler({width=args.width, height=args.height}), {
        background_color=args.background_color or frame_opts.background_color,
        border_color=args.border_color or frame_opts.border_color,
        border_width=args.border_width or frame_opts.border_width,
        margin=args.margin,
        padding=args.padding,
    })
end

local function text_widget(text)
    local w = widget.TextLine{color={1, 1, 1, 1}}
    w:set_text(text)
    return w
end


--- test cases ---

local test = {}

function test.frame()
    local inner = widget.Frame(widget.Filler{},{
        margin = 2,
        background_color = {1, 0, 0, 0.8},
    })
    local root = widget.Frame(inner, {
        margin = {10, 12, 16, 0},
        padding = {0, 8, 12},
        border_width = 12,
        border_color = {1, 1, 1, 1},
        background_color = {0, 0, 0, 1},
    })
    check_renderer("frame", widget.Renderer{root=root, width=100, height=100})
end

function test.group()
    local root = widget.Group{
        widget.Frame(widget.Filler{}, frame_opts),
        widget.Frame(widget.Filler{width=20}, frame_opts),
        widget.Frame(widget.Filler{height=20}, frame_opts),
        widget.Frame(widget.Filler{width=20, height=20}, frame_opts),
    }
    check_renderer("group", widget.Renderer{root=root, width=40, height=100})
end

function test.columns()
    local root = widget.Columns{
        widget.Frame(widget.Filler{}, frame_opts),
        widget.Frame(widget.Filler{width=20}, frame_opts),
        widget.Frame(widget.Filler{height=20}, frame_opts),
        widget.Frame(widget.Filler{width=20, height=20}, frame_opts),
    }
    check_renderer("columns", widget.Renderer{root=root, width=100, height=40})
end

function test.complex_layout()
    local Frame, Filler, Group, Columns = widget.Frame, widget.Filler,
                                          widget.Group, widget.Columns
    local root = Frame(Group{
        dummy{},
        Filler{height=10},
        Columns{
            dummy{width=50, height=50},
            Filler{width=20},
            dummy{width=50, height=50},
            Filler{width=20},
            Group{text_widget("Hello world!"),
                  text_widget("How are you doing?"),
                  text_widget("Widgets are great.")},
            Filler{width=20},
            dummy{width=50, height=50},
        },
        Filler{height=10},
        Frame(Group{
            Columns{dummy{height=16, margin=2}},
            Columns{dummy{height=16, margin=2},
                    dummy{height=16, margin=2}},
            Columns{dummy{height=16, margin=2},
                    dummy{height=16, margin=2},
                    dummy{height=16, margin=2}},
            Columns{dummy{height=16, margin=2},
                    dummy{height=16, margin=2},
                    dummy{height=16, margin=2},
                    dummy{height=16, margin=2}},
            Columns{dummy{height=16, margin=2},
                    dummy{height=16, margin=2},
                    dummy{height=16, margin=2},
                    dummy{height=16, margin=2},
                    dummy{height=16, margin=2}},
        }, {
            background_color={0.2, 0.8, 0.2, 0.4},
            border_color={0.2, 0.8, 0.2, 1},
            border_width=2,
            padding=2,
        }),
        Filler{height=10},
        dummy{width=10},
        Filler{height=10},
        Columns{dummy{width=5}, Filler{width=5}, text_widget("TEXT")},
        Filler(),
        Filler(),
        Columns{Filler(), dummy{width=80, height=80}, Filler()},
    }, {
        background_color = {0.1, 0.1, 0.1, 1},
        border_color = {0, 0, 0, 0.5},
        border_width = 4,
        padding = {16, 4, 32}
    })
    check_renderer("complex_layout", widget.Renderer{root=root, width=400, height=500})
end


--- test running ---

local ANSI_RED = "\027[31m"
local ANSI_GREEN = "\027[32m"
local ANSI_RED_BOLD = "\027[1;31m"
local ANSI_RESET = "\027[0m"

local function error_handler(err)
    print(debug.traceback(ANSI_RED .. err .. ANSI_RESET))
end

--- Entry point called by conky
function conky_update()
    local all_successful = true
    for name, test_fn in pairs(test) do
        local success = xpcall(test_fn, error_handler)
        if success then
            print(ANSI_GREEN .. "test " .. name .. " passed" .. ANSI_RESET)
        else
            all_successful = false
            print(ANSI_RED_BOLD .. "test " .. name .. " failed" .. ANSI_RESET)
        end
    end
    os.exit(all_successful and 0 or 1)
end
