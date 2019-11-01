--- Various helper functions
-- @module util

local util = {}

--- Class creation
-- @section class

--- simple class creation helper
-- @param parent parent class
function util.class(parent)
    local cls = setmetatable({}, {
        __index = parent,
        __call = function (cls, ...)
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

--- Get the oldest value.
-- @return oldest value
function CycleQueue:head()
    return self[self.latest % self.length + 1]
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

--- Opposite of unpack/table.unpack
-- DEPRECATED; use {...} instead
function util.pack(...)
    return {...}
end

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

--- Call a function on each item of an iterator. Collect the results in a table.
-- @func fn should take one argument and return one result
-- @param iter iterator
-- @treturn table list of results
function util.map(fn, iter)
    local arr = {}
    local i = 1
    for item in iter do
        arr[i] = fn(item)
        i = i + 1
    end
    return arr
end

--- Filter a table.
-- @func fn should take one argument and return bool
-- @tab arr
-- @treturn table list of remaining entries
function util.filter(fn, arr)
    local result = {}
    local k = 1
    for i = 1, #arr do
        if fn(arr[i]) then
            result[k] = arr[i]
            k = k + 1
        end
    end
    return result
end

--- Turn a table of values into one value.
-- @func fn should take two arguments and return one
-- @param init starting value
-- @tab arr values
-- @return result
function util.reduce(fn, init, arr)
    for i = 1, #arr do
        init = fn(init, arr[i])
    end
    return init
end

--- Generate a table of numbers from start to stop with step size step,
-- like for i = start, stop, step do ...
-- @number start
-- @number stop
-- @tparam ?number step (default: 1)
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
