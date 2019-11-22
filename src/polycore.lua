--- polycore main module
-- @module polycore

pcall(function() require('cairo') end)

local util = require('src/util')

--- Draw debug information
-- @bool DEBUG
DEBUG = false

os.setlocale("C")  -- decimal dot

local polycore = {
    setup = function() print("You need to add a polycore.setup function.") end
}

--- Takes care of initializing the widget layout.
local function setup()
    polycore.renderer = polycore.setup()
    polycore.renderer:layout()
end

--- Called once per update cycle to (re-)draw the entire surface.
local function update()
    if conky_window == nil then
        return
    end

    polycore.renderer:update()

    local cs = cairo_xlib_surface_create(conky_window.display,
                                         conky_window.drawable,
                                         conky_window.visual,
                                         conky_window.text_width,
                                         conky_window.text_height)
    local cr = cairo_create(cs)
    cairo_surface_destroy(cs)
    polycore.renderer:render(cr)
    cairo_destroy(cr)

    util.reset_data(tonumber(conky_parse('${updates}')))
end


--- Simple error handler to show a stacktrace.
-- The printed stacktrace will also include this `error_handler` itself.
-- @param err the error to handle
local function error_handler(err)
    print(debug.traceback("\027[31m" .. err .. "\027[0m"))
end

--- Global setup entry point, called by conky as per conkyrc.lua.
function conky_setup()
    xpcall(setup, error_handler)
end

--- Global update cycle entry point, called by conky as per conkyrc.lua.
function conky_update()
    xpcall(update, error_handler)
end

return polycore
