local util = require 'util'

local data = {}

local read_cmd = util.memoize(1, function(cmd)
    local pipe = io.popen(cmd)
    local result = pipe:read("*a")
    pipe:close()
    return result
end)

function data.cpu_percentages(cores)
    local conky_string = "${cpu cpu1}"
    for i = 2, cores do
        conky_string = conky_string .. "|${cpu cpu" .. i .. "}"
    end
    return util.map(tonumber, conky_parse(conky_string):gmatch("%d+"))
end

function data.cpu_frequencies(cores)
    local conky_string = "${freq_g 1}"
    for i = 2, cores do
        conky_string = conky_string .. "|${freq_g " .. i .. "}"
    end
    return util.map(tonumber, conky_parse(conky_string):gmatch("%d+[,.]?%d*"))
end

-- relies on lm_sensors to be installed
function data.cpu_temperatures()
    return util.map(tonumber, read_cmd("sensors"):gmatch("Core %d: +%+(%d%d)"))
end

-- relies on lm_sensors to be installed
function data.fan_rpm()
    return util.map(tonumber, read_cmd("sensors"):gmatch("fan%d: +(%d+) RPM"))
end

local unit_map = {
    T = 1024,
    G = 1,
    M = 1 / 1024,
    k = 1 / (1024 * 1024),
    B = 1 / (1024 * 1024 * 1024),
}
function data.memory()
    local conky_output = conky_parse("$mem|$memeasyfree|$memfree|$memmax")
    local results = {}
    for result in conky_output:gmatch("%d+[,.]?%d*%a") do
        local value, unit = result:sub(1, -2), result:sub(-1)
        table.insert(results, value * unit_map[unit])
    end
    return unpack(results)
end

function data.network_speed(interface)
    local result = conky_parse(string.format("${downspeedf %s}|${upspeedf %s}", interface, interface))
    return unpack(util.map(tonumber, result:gmatch("%d+[,.]?%d*")))
end

-- relies on nvidia-smi to be installed
local function cmd_nvidia_smi()
    return read_cmd("nvidia-smi -q -d UTILIZATION,MEMORY,TEMPERATURE")
end

function data.gpu_percentage()
    return tonumber(cmd_nvidia_smi():match("Gpu%s+: (%d+) %%"))
end

function data.gpu_frequency()
    return tonumber(conky_parse("${nvidia gpufreq}"))
end

function data.gpu_temperature()
    return tonumber(cmd_nvidia_smi():match("GPU Current Temp%s+: (%d+) C"))
end

function data.gpu_memory()
    return tonumber(cmd_nvidia_smi():match("Used%s+: (%d+) MiB")),
           tonumber(cmd_nvidia_smi():match("Total%s+: (%d+) MiB"))
end

function data.gpu_top()
    local output = read_cmd("nvidia-smi -q -d PIDS")
    local processes = {}
    for name, mem in output:gmatch("Name%s+: %S*/(%S+)[^\n]*\n%s+Used GPU Memory%s+: (%d+)") do
        processes[#processes + 1] = {name, tonumber(mem)}
    end
    table.sort(processes, function(proc1, proc2) return proc1[2] > proc2[2] end)
    return processes
end


data.drive_percentage = util.memoize(5, function(path)
    return tonumber(conky_parse(string.format("${fs_used_perc %s}", path)))
end)

data.is_mounted = util.memoize(5, function(path)
    return "1" == conky_parse(string.format("${if_mounted %s}1${else}0${endif}", path))
end)

-- relies on hddtemp to be running daemon mode
-- For NVME-Support, requires "nvme smart-log" to be available
-- and added as an exception in sudoers, hddtemp does not support NVME.
data.hddtemp = util.memoize(5, function()
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

return data
