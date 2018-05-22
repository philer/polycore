
-----------------------
--+–––––––––––––––––+--
--| GENERAL UTILITY |--
--+–––––––––––––––––+--
-----------------------

function array_from_iterator(iter)
    local arr = {}
    for item in iter do
        table.insert(arr, item)
    end
    return arr
end

function avg(numbers)
    local acc = 0
    for _, nr in ipairs(numbers) do
        acc = acc + nr
    end
    return acc / #numbers
end
