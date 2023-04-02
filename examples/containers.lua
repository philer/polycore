--- Conky config script

-- Conky does not add our config directory to lua's PATH, so we do it manually
local script_dir = debug.getinfo(1, 'S').source:match("^@(.*/)") or "./"
package.path = script_dir .. "../?.lua;" .. package.path

local util = require('src/util')
local data = require('src/data')
local widget = require('src/widget')
local polycore = require('src/polycore')

local width = 200
local height = 400

local dark_box_bg = {0.70, 0.70, 0.70, 1}
local light_box_bg = {0.83, 0.83, 0.83, 1}
local black = {0, 0, 0, 1}
local blackish = {0.2, 0.2, 0.2, 1}
local dark_grey = {0.5, 0.5, 0.5, 1}
local white = {1, 1, 1, 1}
local yellow = {1, 1, 0, 1}

local dark_box = {white, dark_box_bg}
local light_box = {dark_grey, light_box_bg}

local BoxStat = util.class(widget.Frame)

function BoxStat:init(box_color, title, stat)
    local title_color = box_color[1]
    local title_w = widget.StaticText(title, {font_size=32, font_weight=CAIRO_FONT_WEIGHT_BOLD, color=title_color})

    local stat_widget = widget.TextLine{align="right", font_size=30, color=blackish, margin={0, 0, 8, 0}}
    function stat_widget:update()
        self:set_text(data.conky_loader:get(stat))
    end

    local grp = {title_w, widget.Filler{height=12}, stat_widget}
    widget.Frame.init(self, widget.Rows(grp), {padding={10,12,18,6}, background_color=box_color[2]})
end

--- Called once on startup to initialize widgets.
-- @treturn widget.Renderer
function polycore.setup()

    local rambox = BoxStat(dark_box, "RAM", "$mem")
    local swapbox = BoxStat(light_box, "Swap", "$swap")

    -- Alternate between showing RAM usage and Swap usage
    local memory_container = widget.Container(rambox)
    function memory_container:update(count)
        if (count % 8) < 4 then
            self:set_content(rambox)
        else
            self:set_content(swapbox)
        end
        return widget.Container.update(self, count)
    end

    local warn_text = widget.StaticText("CPU load\nis high!!", {align="center", font_size=26, font_weight=CAIRO_FONT_WEIGHT_BOLD, color=black})
    local warn_frame = widget.Frame(widget.Rows{warn_text}, {})

    -- Show a message if the load average is over 4.
    -- Otherwise, hide it.
    local cpu_container = widget.Container(warn_frame, {})
    function cpu_container:update()
        if tonumber(data.conky_loader:get("${loadavg 1}")) < 4 then
            self:set_content(nil)
        else
            self:set_content(warn_frame)
        end
        return widget.Container.update(self, count)
    end

    local loadavg = BoxStat(dark_box, "CPU Load", "${loadavg 1}")

    local root = widget.Rows({memory_container, cpu_container, loadavg})
    return widget.Renderer{root=root, width=width, height=height}
end

local conkyrc = conky or {}
conkyrc.config = {
    lua_load = script_dir .. "containers.lua",
    lua_startup_hook = "conky_setup",
    lua_draw_hook_pre = "conky_paint_background",
    lua_draw_hook_post = "conky_update",
    alignment = "middle_right",
    background = false,
    double_buffer = true,
    use_xft = false,
    gap_x = -6,
    gap_y = -40,
    maximum_width = width,
    minimum_height = height,
    minimum_width = width,
    own_window = true,
    own_window_class = 'Conky',
    own_window_type = 'panel',
    own_window_transparent = true,
    times_in_seconds = true,
}
conkyrc.text = ""
