-- Run this test via conky: `conky -c test/test_layout.lua`

-- lua 5.1 to 5.3 compatibility
if unpack == nil then unpack = table.unpack end

-- Conky does not add our config directory to lua's PATH, so we do it manually
local script_path = debug.getinfo(1, 'S').source:match("^@(.*)")
local script_dir = script_path:match("^.*/")
if script_dir then
    package.path = script_dir .. "?.lua;" .. package.path
else
    script_dir = "./"
end

local _, widget = pcall(require, 'src/widget')

local win_width, win_height = 400, 500

local conkyrc = conky or {}
conkyrc.text = ""
conkyrc.config = {
    lua_load = script_path,
    lua_draw_hook_post = "main",
    total_run_times = 1,

    out_to_console = true,
    out_to_x = false,

    minimum_width = win_width,
    maximum_width = win_width,
    minimum_height = win_height,

    draw_borders = false,
    border_inner_margin = 0,
    border_outer_margin = 0,
    border_width = 0,

    no_buffers = true,  -- include buffers in used RAM
    override_utf8_locale = true,
}


local function render_to_image(root, path)
    local renderer = widget.Renderer{root=root, width=win_width, height=win_height}
    renderer:layout()
    renderer:update()

    local cs = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, win_width, win_height)
    local cr = cairo_create(cs)
    renderer:render(cr)
    local result = cairo_surface_write_to_png(cs, path)
    cairo_surface_destroy(cs)
    cairo_destroy(cr)
end

--- Check if two image files contain the same pixels
-- requires imagemagick
-- @string path1
-- @string path2
-- @treturn bool
local function images_equal(path1, path2)
    local command_template = 'compare -identify -metric MAE "%s" "%s" null'
    local result = os.execute(command_template:format(path1, path2))

    -- os.execute returns changed from 5.1 to 5.3
    return result == true or result == 0
end


local function mock_widget(args)
    return widget.Frame(widget.Filler({width=args.width, height=args.height}), {
        background_color=args.background_color or {0.2, 0.4, 0.9, 0.4},
        border_color=args.border_color or {0.3, 0.6, 0.9, 1},
        border_width=args.border_width or 2,
        margin=args.margin,
        padding=args.padding,
    })
end

local function text_widget(text)
    local w = widget.TextLine{color={1, 1, 1, 1}}
    w:set_text(text)
    return w
end

local function test_layout()
    local Frame, Filler, Group, Columns = widget.Frame, widget.Filler,
                                          widget.Group, widget.Columns
    local root = Frame(Group{
        mock_widget{},
        Filler{height=10},
        Columns{
            mock_widget{width=50, height=50},
            Filler{width=20},
            mock_widget{width=50, height=50},
            Filler{width=20},
            Group{text_widget("Hello world!"),
                  text_widget("How are you doing?"),
                  text_widget("Widgets are great.")},
            Filler{width=20},
            mock_widget{width=50, height=50},
        },
        Filler{height=10},
        Frame(Group{
            Columns{mock_widget{height=16, margin=2}},
            Columns{mock_widget{height=16, margin=2},
                    mock_widget{height=16, margin=2}},
            Columns{mock_widget{height=16, margin=2},
                    mock_widget{height=16, margin=2},
                    mock_widget{height=16, margin=2}},
            Columns{mock_widget{height=16, margin=2},
                    mock_widget{height=16, margin=2},
                    mock_widget{height=16, margin=2},
                    mock_widget{height=16, margin=2}},
            Columns{mock_widget{height=16, margin=2},
                    mock_widget{height=16, margin=2},
                    mock_widget{height=16, margin=2},
                    mock_widget{height=16, margin=2},
                    mock_widget{height=16, margin=2}},
        }, {
            background_color={0.2, 0.8, 0.2, 0.4},
            border_color={0.2, 0.8, 0.2, 1},
            border_width=2,
            padding=2,
        }),
        Filler{height=10},
        mock_widget{width=10},
        Filler{height=10},
        Columns{mock_widget{width=5}, Filler{width=5}, text_widget("TEXT")},
        Filler(),
        Filler(),
        Columns{Filler(), mock_widget{width=80, height=80}, Filler()},
    }, {
        background_color = {0.1, 0.1, 0.1, 1},
        border_color = {0, 0, 0, 0.5},
        border_width = 4,
        padding = {16, 4, 32}
    })

    local out_path = "/tmp/conky_layout_test.png"
    render_to_image(root, out_path)
    assert(images_equal(out_path, script_dir .. "layout.png"))
end


local ANSI_RED = "\027[31m"
local ANSI_GREEN = "\027[32m"
local ANSI_RED_BOLD = "\027[1;31m"
local ANSI_RESET = "\027[0m"
local function error_handler(err)
    print(debug.traceback(ANSI_RED .. err .. ANSI_RESET))
end

--- Entry point called by conky
function conky_main()
    local success = xpcall(test_layout, error_handler)
    print()
    if success then
        print(ANSI_GREEN .. "test_layout passed" .. ANSI_RESET)
    else
        print(ANSI_RED_BOLD .. "test_layout failed" .. ANSI_RESET)
    end
end
