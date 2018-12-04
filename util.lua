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
function class()
    local cls = setmetatable({}, {
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
CycleQueue = class()

function CycleQueue:init(length)
    self.length = length
    self.latest = 0
    for i = 1, length do
        self[i] = 0
    end
end

function CycleQueue:head()
    return self[self.latest]
end

function CycleQueue:put(item)
    self.latest = self.latest % self.length + 1
    self[self.latest] = item
end

function CycleQueue:map(fn)
    for i = self.latest, self.length do
        fn(self[i], i - self.latest + 1)
    end
    for i = 1, self.latest - 1 do
        fn(self[i], self.length - self.latest + i + 1)
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
