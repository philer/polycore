--- polycore main module
-- @module polycore

pcall(function() require('cairo') end)

local ch = require('src/cairo_helpers')
local data = require('src/data')
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

--- Called once per update cycle to (re-)draw the entire surface background.
local function paint_background()
    if conky_window ~= nil then
        local cr = ch.create_cr(conky_window)
        polycore.renderer:paint_background(cr)
        cairo_destroy(cr)
    end
end

--- Called once per update cycle to (re-)draw the entire surface foreground.
local function update()
    if conky_window == nil then
        return
    end

    data.conky_loader:load()
    local update_count = tonumber(data.conky_loader:get('$updates'))
    util.reset_data(update_count)
    data.nvidia_loader:load()

    polycore.renderer:update(update_count)

    local cr = ch.create_cr(conky_window)
    polycore.renderer:render(cr)
    cairo_destroy(cr)
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
function conky_paint_background()
    xpcall(paint_background, error_handler)
end

--- Global update cycle entry point, called by conky as per conkyrc.lua.
function conky_update()
    xpcall(update, error_handler)
end

return polycore
