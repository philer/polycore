--+–––––––––+--
--| UTILITY |--
--+–––––––––+--

local util = {}

local memoization_clearers = {}

-- Wrap a function to store its results for identical arguments
-- Arguments:
--   delay: int, optinal - number of updates that should pass before
--                         data is cleared; use 0/false/nil to never clear
--   fn:    function     - function to be memoized; should only take stringable
--                         arguments and return a non-nil value
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
        local key = table.concat(arg, ":")
        if results[key] == nil then
            results[key] = fn(unpack(arg))
        end
        return results[key]
    end
end

-- Clear outdated memoization data (see util.memoize)
-- Call this once per update cycle
function util.reset_data(update_count)
    for i = 1, #memoization_clearers do
        if update_count % memoization_clearers[i][1] == 0 then
            memoization_clearers[i][2]()
        end
    end
end


-- class creation helper - takes a parent class as the only argument
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


-- circular queue implementation
util.CycleQueue = util.class()

function util.CycleQueue:init(length)
    self.length = length
    self.latest = length
    for i = 1, length do
        self[i] = 0
    end
end

function util.CycleQueue:head()
    return self[self.latest % self.length + 1]
end

function util.CycleQueue:put(item)
    self.latest = self.latest % self.length + 1
    self[self.latest] = item
end

function util.CycleQueue:each(fn)
    for i = self.latest + 1, self.length do
        fn(self[i], i - self.latest % self.length)
    end
    for i = 1, self.latest do
        fn(self[i], i - self.latest + self.length)
    end
end


-- general utility functions --

function util.pack(...)
    return {...}
end

function util.clamp(min, max, val)
    if val < min then return min end
    if val > max then return max end
    return val
end

function util.map(fn, iter)
    local arr = {}
    local i = 1
    for item in iter do
        arr[i] = fn(item)
        i = i + 1
    end
    return arr
end

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

function util.reduce(fn, init, arr)
    for i = 1, #arr do
        init = fn(init, arr[i])
    end
    return init
end

function util.range(start, stop, step)
    local arr = {}
    local i = 1
    for value = start, stop, step or 1 do
        arr[i] = value
        i = i + 1
    end
    return arr
end

function util.avg(arr)
    local acc = 0
    for i = 1, #arr do
        acc = acc + arr[i]
    end
    return acc / #arr
end

-- Fisher-Yates shuffle
function util.shuffle(array)
    for counter = #array, 2, -1 do
        local index = math.random(counter)
        array[index], array[counter] = array[counter], array[index]
    end
end

return util
