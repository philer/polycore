-- Run this test from the project root via `lua test/test_util.lua`

local util = require("src/util")

local test = {}

local function assert_arrays_equal(xs, ys)
    assert(#xs == #ys, ("arrays have different length (%s != %s)"):format(#xs, #ys))
    local msg = ("{%s} != {%s}"):format(table.concat(xs, ","), table.concat(ys, ","))
    for i = 1, #xs do
        assert(xs[i] == ys[i], msg)
    end
end

function test.CycleQueue_init()
    local q1 = util.CycleQueue(5)
    assert_arrays_equal(q1, {0, 0, 0, 0, 0})
    for i = 10, 50, 10 do
        q1:put(i)
    end
    local q2 = util.CycleQueue{10, 20, 30, 40, 50}
    assert_arrays_equal(q1, q2)
end

function test.CycleQueue_put()
    local q = util.CycleQueue(5)
    for i = 10, 140, 10 do
        q:put(i)
    end
    assert_arrays_equal(q, {100, 110, 120, 130, 140})
end

function test.CycleQueue_index()
    local q = util.CycleQueue{10, 20, 30, 40, 50}
    for i = 1, 5 do
        assert(q[i] == i * 10)
    end
end

function test.CycleQueue_ipairs()
    local q = util.CycleQueue{10, 20, 30, 40, 50}
    local indeces, values = {}, {}
    local i = 1
    for idx, val in q:__ipairs() do
        indeces[i] = idx
        values[i] = val
        i = i + 1
    end
    assert_arrays_equal(indeces, {1, 2, 3, 4, 5})
    assert_arrays_equal(values, {10, 20, 30, 40, 50})
end


function test.clamp()
    assert(util.clamp(1, 10, 5) == 5)
    assert(util.clamp(-10, -1, 5) == -1)
    assert(util.clamp(1, 10, 15) == 10)
    assert(util.clamp(1, 10, -5) == 1)
end


local ANSI_RED = "\027[31m"
local ANSI_GREEN = "\027[32m"
local ANSI_RED_BOLD = "\027[1;31m"
local ANSI_RESET = "\027[0m"

local function error_handler(err)
    print(debug.traceback(ANSI_RED .. err .. ANSI_RESET))
end

local function run_tests()
    local all_successful = true
    for name, test_fn in pairs(test) do
        local success = xpcall(test_fn, error_handler)
        if success then
            print(ANSI_GREEN .. "test " .. name .. " passed" .. ANSI_RESET)
        else
            all_successful = false
            print(ANSI_RED_BOLD .. "test " .. name .. " failed" .. ANSI_RESET)
        end
    end
    return all_successful
end

os.exit(run_tests() and 0 or 1)
