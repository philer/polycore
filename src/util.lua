--- Various helper functions
-- @module util

local util = {}

--- Class creation
-- @section class

--- simple class creation helper
-- @param[opt] parent parent class
function util.class(parent)
    local cls = setmetatable({}, {
        __index = parent,
        __call = function(cls, ...)
            local instance = setmetatable({}, cls)
            if cls.init then
                instance:init(...)
            end
            return instance
        end,
    })
    cls.__index = cls
    return cls
end


--- Memoization
-- @section memo

local memoization_clearers = {}

--- Wrap a function to store its results for fast access via identical arguments.
-- @tparam[opt] int delay number of updates that should pass before
--                    data is cleared; use 0/false/nil to never clear
-- @func fn function to be memoized; should only take stringable
--                     arguments and return a non-nil value
function util.memoize(delay, fn)
    if fn == nil then
        delay, fn = 0, delay
    end
    local results = {}
    if delay > 0 then
        table.insert(memoization_clearers, {delay, function()
            results = {}
        end})
    end
    return function(...)
        local key = table.concat({...}, ":")
        if results[key] == nil then
            results[key] = fn(...)
        end
        return results[key]
    end
end

--- Clear outdated data gathered via `util.memoize`.
-- Call this once per update cycle.
-- @int update_count conky's $update_count
function util.reset_data(update_count)
    for i = 1, #memoization_clearers do
        if update_count % memoization_clearers[i][1] == 0 then
            memoization_clearers[i][2]()
        end
    end
end


--- Circular queue implementation.
-- Adding new values causes old values to disappear.
-- @type CycleQueue
local CycleQueue = util.class()
util.CycleQueue = CycleQueue

--- @int length fixed number of items to be stored
function CycleQueue:init(length)
    self.length = length
    self.latest = length
    for i = 1, length do
        self[i] = 0
    end
end

--- Add a value, causing the oldest value to disappear.
-- @param item value to add
function CycleQueue:put(item)
    self.latest = self.latest % self.length + 1
    self[self.latest] = item
end

--- Apply a function to each item in order from oldest to newest.
-- @func fn
function CycleQueue:each(fn)
    for i = self.latest + 1, self.length do
        fn(self[i], i - self.latest % self.length)
    end
    for i = 1, self.latest do
        fn(self[i], i - self.latest + self.length)
    end
end


--- General utility functions
-- @section general

local log = math.log
local log2, log10 = log(2), log(10)

--- logarithm for an arbirary base
-- @number x
-- @number base
function util.log(x, base) return log(x) / log(base) end

--- logarithm for base 2
-- @number x
function util.log2(x) return log(x) / log2 end

--- logarithm for base 10
-- @number x
function util.log10(x) return log(x) / log10 end

--- Clamp a value between a minimum and a maximum
-- @number min minimum value returned
-- @number max maximum value returned
-- @number val target value
-- @treturn number
function util.clamp(min, max, val)
    if val < min then return min end
    if val > max then return max end
    return val
end


--- Turn a array style table into a {[value] = true} mapping table
-- @tab entries list of keys
-- @treturn table {key = true} mapping
function util.set(entries)
    local set = {}
    for i = 1, #entries do
        set[entries[i]] = true
    end
    return set
end

--- Array to Array map.
-- Calls a function on each item of a table. Collect the results in a table.
-- @func fn should take one argument and return one result
-- @tab items array
-- @treturn table array of results
function util.a2a_map(fn, items)
    local results = {}
    for i = 1, #items do
        results[i] = fn(items[i])
    end
    return results
end

--- Iterator to Array map.
-- Calls a function on each item of an iterator. Collect the results in a table.
-- @func fn should take one argument and return one result
-- @func iter iterator
-- @treturn table array of results
function util.i2a_map(fn, iter)
    local results = {}
    local i = 1
    for item in iter do
        results[i] = fn(item)
        i = i + 1
    end
    return results
end

--- Array to Iterator map.
-- Calls a function on each item of a table. Iterate the results.
-- @func fn should take one argument and return one result
-- @tab items array
-- @treturn func results iterator
function util.a2i_map(fn, items)
    local i, len = 0, #items
    return function()
        i = i + 1
        if i <= len then
            return fn(items[i])
        end
    end
end

--- Iterator to Iterator map.
-- Calls a function on each item of an iterator. Iterate the results.
-- @func fn should take one argument and return one result
-- @func iter iterator
-- @treturn func results iterator
function util.i2i_map(fn, iter)
    return function()
        local elem = iter()
        if elem then
            return fn(elem)
        end
    end
end

local maps = {
    ["table"] = util.a2a_map,
    ["function"] = util.i2a_map,
}

--- Call a function on each item of an array or iterator.
-- Collect the results in a table.
-- @func fn should take one argument and return one result
-- @tparam table|func items
-- @treturn table array of results
function util.map(fn, items)
    return maps[type(items)](fn, items)
end

local imaps = {
    ["table"] = util.a2i_map,
    ["function"] = util.i2i_map,
}

--- Calls a function on each item of an array or iterator.
-- Iterate the results.
-- @func fn should take one argument and return one result
-- @tparam table|func items
-- @treturn func results iterator
function util.imap(fn, items)
    return imaps[type(items)](fn, items)
end

--- Generate a table of numbers from start to stop with step size step,
-- like for i = start, stop, step do ...
-- @number start
-- @number stop
-- @number[opt=1] step
-- @treturn {number,...}
function util.range(start, stop, step)
    local arr = {}
    local i = 1
    for value = start, stop, step or 1 do
        arr[i] = value
        i = i + 1
    end
    return arr
end

--- Calculate the average of a table of numbers.
-- @tparam {number,...} arr
-- @treturn number
function util.avg(arr)
    local acc = 0
    for i = 1, #arr do
        acc = acc + arr[i]
    end
    return acc / #arr
end

--- Shuffle a table in-place using Fisher-Yates shuffle.
-- @tab array
function util.shuffle(array)
    for counter = #array, 2, -1 do
        local index = math.random(counter)
        array[index], array[counter] = array[counter], array[index]
    end
end

return util
