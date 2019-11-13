-- Run this test from the project root via `lua test/test_util.lua`

local util = require "src/util"

local test = {}

local function assert_arrays_equal(xs, ys)
    assert(#xs == #ys, ("arrays have different length (%s != %s)"):format(#xs, #ys))
    local msg = ("{%s} != {%s}"):format(table.concat(xs, ","), table.concat(ys, ","))
    for i = 1, #xs do
        assert(xs[i] == ys[i], msg)
    end
end

function test.CycleQueue()
    local function check_each(q, arr)
        local idx_msg = "CycleQueue:each gave incorrect index (%s instead of %s)"
        local val_msg = "CycleQueue:each gave incorrect value at index %s (%s instead of %s)"
        local expected_idx = 1
        q:each(function(val, idx)
            assert(idx == expected_idx, idx_msg:format(idx, expected_idx))
            expected_idx = expected_idx + 1
            assert(val == arr[idx], val_msg:format(idx, val, arr[idx]))
        end)
    end
    q = util.CycleQueue(3)
    check_each(q, {0, 0, 0})
    q:put(1)
    check_each(q, {0, 0, 1})
    for i = 2, 20 do
        q:put(i)
        check_each(q, {i - 2, i - 1, i})
    end
    q = util.CycleQueue(10)
    check_each(q, {0, 0, 0, 0, 0, 0, 0, 0, 0, 0})
    for i = 1, 5 do q:put(i) end
    check_each(q, {0, 0, 0, 0, 0, 1, 2, 3, 4, 5})
    for i = 6, 9 do q:put(i) end
    check_each(q, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9})
    q:put(0)  -- overwrite same value
    check_each(q, {1, 2, 3, 4, 5, 6, 7, 8, 9, 0})
    q:put(10)  -- overflow to start
    check_each(q, {2, 3, 4, 5, 6, 7, 8, 9, 0, 10})
    q:put(20)
    check_each(q, {3, 4, 5, 6, 7, 8, 9, 0, 10, 20})
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
    for name, test_fn in pairs(test) do
        local success = xpcall(test_fn, error_handler)
        if success then
            print(ANSI_GREEN .. "test " .. name .. " passed" .. ANSI_RESET)
        else
            print(ANSI_RED_BOLD .. "test " .. name .. " failed" .. ANSI_RESET)
        end
    end
end

run_tests()
