--+–––––––––+--
--| UTILITY |--
--+–––––––––+--

local _memoization_clearers = {}

function reset_data(update_count)
    for _, memclear in ipairs(_memoization_clearers) do
        if update_count % memclear[1] == 0 then
            memclear[2]()
        end
    end
end

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

function clamp(min, max, val)
    return math.max(min, math.min(val, max))
end

--- array based functions ---

function array(iter)
    local arr = {}
    for item in iter do
        table.insert(arr, item)
    end
    return arr
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


--- iterator based functions ---

function iter(arr)
    local i = 0
    return function()
        i = i + 1
        return arr[i]
    end
end

function imap(fn, iter)
    return function()
        return fn(iter())
    end
end

function ireduce(fn, init, iter)
    for item in iter do
        init = fn(init, item)
    end
    return init
end

function irange(start, stop, step)
    step = step or 1
    local current = start - step
    return function()
        current = current + step
        if current > stop then
            return nil
        end
        return current
    end
end

function iavg(iter)
    local acc, count = 0, 0
    for nr in iter do
        acc = acc + nr
        count = count + 1
    end
    return acc / count
end


--- variadic functions ---

function navg(...)
    return sum(unpack(arg)) / #arg
end

function nsum(...)
    local result = 0
    for _, v in ipairs(arg) do
        result = result + v
    end
    return result
end


-- circular queue implementation --

local CycleQueueMeta = {}
CycleQueueMeta.__index = CycleQueueMeta

function CycleQueueMeta:add(item)
    self.latest = self.latest % self.length + 1
    self[self.latest] = item
end

function CycleQueueMeta:map(fn)
    for i = self.latest + 1, self.length do
        fn(self[i] or 0, i - self.latest)
    end
    for i = 1, self.latest do
        fn(self[i] or 0, self.length - self.latest + i)
    end
end

function CycleQueueMeta:head()
    return self[self.latest % self.length + 1] or 0
end

function CycleQueue(length)
   local queue = {length = length, latest = 1}
   setmetatable(queue, CycleQueueMeta)
   return queue
end
