require 'util'

local function read_cmd(cmd)
    local pipe = io.popen(cmd)
    local result = pipe:read("*a")
    pipe:close()
    return result
end


function cpu_percentages(cores)
    -- local conky_string = string.format(string.rep("${cpu cpu%s}|"),)
    local conky_string = "${cpu cpu1}"
    for i = 2, cores do
        conky_string = conky_string .. "|${cpu cpu" .. i .. "}"
    end
    return map(tonumber, conky_parse(conky_string):gmatch("%d+"))
end

function cpu_frequencies(cores)
    local conky_string = "${freq_g 1}"
    for i = 2, cores do
        conky_string = conky_string .. "|${freq_g " .. i .. "}"
    end
    return map(tonumber, conky_parse(conky_string):gmatch("%d+[,.]?%d*"))
end

function cpu_temperatures()
    return map(tonumber, read_cmd("sensors"):gmatch("Core %d: +%+(%d%d)"))
end

function fan_rpm()
    return map(tonumber, read_cmd("sensors"):gmatch("fan%d: +(%d+) RPM"))
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
    local result = read_cmd("nc localhost 7634 -d")
    local temperatures = {}
    for _, device_name, temp in result:gmatch("|([^|]+)|([^|]+)|(%d+)|C|") do
        temperatures[device_name] = tonumber(temp)
    end
    -- experimental: nvme drives, currently requires sudo
    result = read_cmd("sudo nvme smart-log /dev/nvme0")
    temperatures["/dev/nvme0"] = tonumber(result:match("temperature%s+: (%d+) C"))
    return temperatures
end)
