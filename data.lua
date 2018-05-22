-- lua's import system is retarded.
package.path = os.getenv("HOME") .. "/.config/conky/?.lua;" .. package.path
require 'util.functions'

local read_cmd = memoize(function(cmd)
    local pipe = io.popen(cmd)
    local result = pipe:read("*a")
    pipe:close()
    return result
end)


function cpu_percentages()
    local result = conky_parse("${cpu cpu0}|${cpu cpu1}|${cpu cpu2}|${cpu cpu3}|${cpu cpu4}|${cpu cpu5}")
    return map(tonumber, result:gmatch("%d+"))
end

function cpu_frequencies()
    local result = conky_parse("${freq_g 0}|${freq_g 1}|${freq_g 2}|${freq_g 3}|${freq_g 4}|${freq_g 5}")
    return map(tonumber, result:gmatch("%d+[,.]?%d*"))
end

function cpu_temperatures()
    local result = read_cmd("sensors")
    return map(tonumber, result:gmatch("Core %d: +%+(%d%d)"))
end

function fan_rpm()
    local result = read_cmd("sensors")
    return map(tonumber, result:gmatch("fan%d: +(%d+) RPM"))
end


function memory()
    local result = conky_parse("$mem|$memmax")
    local used, total = unpack(map(tonumber, result:gmatch("%d+[,.]?%d*")))
    while used > total do
        used = used / 1024
    end
    return used, total
end


function network_speed(interface)
    local result = conky_parse(string.format("${downspeedf %s}|${upspeedf %s}", interface, interface))
    return unpack(map(tonumber, result:gmatch("%d+[,.]?%d*")))
end

local function cmd_nvidia_smi()
    return read_cmd("nvidia-smi -q -d UTILIZATION,MEMORY,TEMPERATURE")
end

function gpu_percentage()
    return tonumber(cmd_nvidia_smi():match("Gpu%s+: (%d+) %%"))
end

function gpu_frequency()
    return tonumber(conky_parse("${nvidia gpufreq}"))
end

function gpu_temperature()
    return tonumber(cmd_nvidia_smi():match("GPU Current Temp%s+: (%d+) C"))
end

function gpu_memory()
    return tonumber(cmd_nvidia_smi():match("Used%s+: (%d+) MiB")),
           tonumber(cmd_nvidia_smi():match("Total%s+: (%d+) MiB"))
end


drive_percentage = memoize(5, function(path)
    return tonumber(conky_parse(string.format("${fs_used_perc %s}", path)))
end)

is_mounted = memoize(5, function(path)
    return "1" == conky_parse(string.format("${if_mounted %s}1${else}0${endif}", path))
end)

hddtemp = memoize(5, function()
    local result = read_cmd("nc localhost 7634")
    local temperatures = {}
    for _, device_name, temp in result:gmatch("|([^|]+)|([^|]+)|(%d+)|C|") do
        temperatures[device_name] = tonumber(temp)
    end
    return temperatures
end)
