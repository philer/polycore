--+–––––––––+--
--| UTILITY |--
--+–––––––––+--

local util = {}

local _memoization_clearers = {}

function util.memoize(delay, fn)
    if fn == nil then
        fn = delay
        delay = 0
    end
    local results = {}
    if delay > 1 then
        table.insert(_memoization_clearers, {delay, function()
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

function util.reset_data(update_count)
    for _, memclear in ipairs(_memoization_clearers) do
        if update_count % memclear[1] == 0 then
            memclear[2]()
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
    self.latest = 0
    for i = 1, length do
        self[i] = 0
    end
end

function util.CycleQueue:head()
    return self[self.latest]
end

function util.CycleQueue:put(item)
    self.latest = self.latest % self.length + 1
    self[self.latest] = item
end

function util.CycleQueue:map(fn)
    for i = self.latest, self.length do
        fn(self[i], i - self.latest + 1)
    end
    for i = 1, self.latest - 1 do
        fn(self[i], self.length - self.latest + i + 1)
    end
end


-- general utility functions --

function util.pack(...)
    return {...}
end

function util.clamp(min, max, val)
    return math.max(min, math.min(val, max))
end

function util.map(fn, iter)
    local arr = {}
    for item in iter do
        table.insert(arr, fn(item))
    end
    return arr
end

function util.filter(fn, arr)
    local result = {}
    for _, item in ipairs(arr) do
        if fn(item) then
            table.insert(result, item)
        end
    end
    return result
end

function util.reduce(fn, init, arr)
    for _, item in ipairs(arr) do
        init = fn(init, item)
    end
    return init
end

function util.range(start, stop, step)
    local arr = {}
    for i = start, stop, step or 1 do
        table.insert(arr, i)
    end
    return arr
end

function util.avg(arr)
    local acc = 0
    for _, nr in ipairs(arr) do
        acc = acc + nr
    end
    return acc / #arr
end

-- Fisher-Yates shuffle
-- https://stackoverflow.com/a/17120745
function util.shuffle(array)
    local counter = #array
    while counter > 1 do
        local index = math.random(counter)
        array[index], array[counter] = array[counter], array[index]
        counter = counter - 1
    end
end

return util
