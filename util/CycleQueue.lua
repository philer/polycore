-- circular queue implementation --

local CycleQueueMeta = {}
CycleQueueMeta.__index = CycleQueueMeta

function CycleQueue(length)
   local queue = {length = length, latest = 1}
   setmetatable(queue, CycleQueueMeta)
   return queue
end

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

return CycleQueue
