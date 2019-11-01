--- Data gathering facilities for conky widgets
-- @module data

local util = require 'util'

local data = {}

local read_cmd = util.memoize(1, function(cmd)
    local pipe = io.popen(cmd)
    local result = pipe:read("*a")
    pipe:close()
    return result
end)

--- Get the current usage percentages of individual CPU cores
-- @int cores number of CPU cores
-- @treturn {number,...}
function data.cpu_percentages(cores)
    local conky_string = "${cpu cpu1}"
    for i = 2, cores do
        conky_string = conky_string .. "|${cpu cpu" .. i .. "}"
    end
    return util.map(tonumber, conky_parse(conky_string):gmatch("%d+"))
end

--- Get the current frequencies at which individual CPU cores are running
-- @int cores number of CPU cores
-- @treturn {number,...}
function data.cpu_frequencies(cores)
    local conky_string = "${freq_g 1}"
    for i = 2, cores do
        conky_string = conky_string .. "|${freq_g " .. i .. "}"
    end
    return util.map(tonumber, conky_parse(conky_string):gmatch("%d+[,.]?%d*"))
end

--- Get the current CPU core temperatures
-- relies on lm_sensors to be installed
-- @treturn {number,...}
function data.cpu_temperatures()
    return util.map(tonumber, read_cmd("sensors"):gmatch("Core %d: +%+(%d%d)"))
end

--- Get the current speed of fans in the system
-- relies on lm_sensors to be installed
-- @treturn {number,...}
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
--- Get current memory usage info
-- @treturn number,number,number,number usage, easyfree, free, total
function data.memory()
    local conky_output = conky_parse("$mem|$memeasyfree|$memfree|$memmax")
    local results = {}
    for result in conky_output:gmatch("%d+[,.]?%d*%a") do
        local value, unit = result:sub(1, -2), result:sub(-1)
        table.insert(results, value * unit_map[unit])
    end
    return unpack(results)
end

--- Get volume of down- and uploaded data since last conky update cycle.
-- @string interface e.g. "eth0"
-- @treturn number,number downspeed and upspeed in KiB
function data.network_speed(interface)
    local result = conky_parse(string.format("${downspeedf %s}|${upspeedf %s}", interface, interface))
    return unpack(util.map(tonumber, result:gmatch("%d+[,.]?%d*")))
end

-- relies on nvidia-smi to be installed.
local function cmd_nvidia_smi()
    return read_cmd("nvidia-smi -q -d UTILIZATION,MEMORY,TEMPERATURE")
end

--- Get current GPU usage in percent.
-- Relies on nvidia-smi to be installed.
-- @treturn number
function data.gpu_percentage()
    return tonumber(cmd_nvidia_smi():match("Gpu%s+: (%d+) %%"))
end

--- Get current GPU frequency.
-- @treturn number
function data.gpu_frequency()
    return tonumber(conky_parse("${nvidia gpufreq}"))
end

--- Get current GPU temperature.
-- Relies on nvidia-smi to be installed.
-- @treturn number temperature in °C
function data.gpu_temperature()
    return tonumber(cmd_nvidia_smi():match("GPU Current Temp%s+: (%d+) C"))
end

--- Get current VRAM usage.
-- Relies on nvidia-smi to be installed.
-- @treturn number,number used, total in MiB
function data.gpu_memory()
    return tonumber(cmd_nvidia_smi():match("Used%s+: (%d+) MiB")),
           tonumber(cmd_nvidia_smi():match("Total%s+: (%d+) MiB"))
end

--- Get list of GPU processes with individual VRAM usage in MiB.
-- Relies on nvidia-smi to be installed.
-- @treturn {{string,number},...} list of {name, mem} value pairs.
function data.gpu_top()
    local output = read_cmd("nvidia-smi -q -d PIDS")
    local processes = {}
    for name, mem in output:gmatch("Name%s+: %S*/(%S+)[^\n]*\n%s+Used GPU Memory%s+: (%d+)") do
        processes[#processes + 1] = {name, tonumber(mem)}
    end
    table.sort(processes, function(proc1, proc2) return proc1[2] > proc2[2] end)
    return processes
end

--- Get the drive usage in percent for the given path.
-- @function data.drive_percentag
-- @string path
-- @treturn number
data.drive_percentage = util.memoize(5, function(path)
    return tonumber(conky_parse(string.format("${fs_used_perc %s}", path)))
end)


--- Is the given path a mount? (see conky's is_mounted)
-- @function data.is_mounted
-- @string path
-- @treturn bool
data.is_mounted = util.memoize(5, function(path)
    return "1" == conky_parse(string.format("${if_mounted %s}1${else}0${endif}", path))
end)

--- Get current HDD/SSD temperatures.
-- Relies on hddtemp to be running daemon mode. The results depend on what
-- hddtemp reports and may require manual configuration,
-- e.g. via /etc/default/hddtemp
-- For experimental NVME support, requires "nvme smart-log" to be available
-- and added as an exception in sudoers, hddtemp does not support NVME.
-- @function data.hddtemp
-- @treturn table mapping device names to temperature values
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
