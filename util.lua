--+–––––––––+--
--| UTILITY |--
--+–––––––––+--

local _memoization_clearers = {}

function memoize(delay, fn)
    if fn == nil then
        fn = delay
        delay = 1
    end
    local results = {}
    table.insert(_memoization_clearers, {delay, function()
        results = {}
    end})
    return function(...)
        local key = table.concat(arg, ":")
        if results[key] == nil then
            results[key] = fn(unpack(arg))
        end
        return results[key]
    end
end

function reset_data(update_count)
    for _, memclear in ipairs(_memoization_clearers) do
        if update_count % memclear[1] == 0 then
            memclear[2]()
        end
    end
end


-- class creation helper - takes a constructor as the only argument
function class(init)
    if init == nil then
        init = function () return {} end
    end
    local cls = setmetatable({}, {
        __call = function (cls, ...)
            return setmetatable(init(...), cls)
        end,
    })
    cls.__index = cls
    return cls
end


-- circular queue implementation
CycleQueue = class(function (length)
    return {length = length, latest = 1}
end)

function CycleQueue:head()
    return self[self.latest % self.length + 1] or 0
end

function CycleQueue:add(item)
    self.latest = self.latest % self.length + 1
    self[self.latest] = item
end

function CycleQueue:map(fn)
    for i = self.latest + 1, self.length do
        fn(self[i] or 0, i - self.latest)
    end
    for i = 1, self.latest do
        fn(self[i] or 0, self.length - self.latest + i)
    end
end


-- general utility functions --

function clamp(min, max, val)
    return math.max(min, math.min(val, max))
end

function map(fn, iter)
    local arr = {}
    for item in iter do
        table.insert(arr, fn(item))
    end
    return arr
end

function reduce(fn, init, arr)
    for _, item in ipairs(arr) do
        init = fn(init, item)
    end
    return init
end

function range(start, stop, step)
    local arr = {}
    for i = start, stop, step or 1 do
        table.insert(arr, i)
    end
    return arr
end

function avg(arr)
    local acc = 0
    for _, nr in ipairs(arr) do
        acc = acc + nr
    end
    return acc / #arr
end
