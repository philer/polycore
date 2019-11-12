--- Data gathering facilities for conky widgets
-- @module data

local util = require 'src/util'

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
    for result in conky_output:gmatch("%d+%p?%d*%a") do
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
    return unpack(util.map(tonumber, result:gmatch("%d+%p?%d*")))
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


--- Detect mount points and their respective devices plus physical devices.
-- @function data.find_devices
-- @treturn table mapping of mount points (paths) to value pairs of
--                (logical) device and physical device
--                e.g. {["/"] = {"/dev/sda1", "/dev/sda"}}
data.find_devices = util.memoize(10, function()
    local lsblk = read_cmd("lsblk --ascii --noheadings --paths --output NAME,MOUNTPOINT")
    local lines = lsblk:gmatch("([^/]*)(%S+) +(%S*)%s*")
    local mounts = {}
    local physical_device
    for depth, device, path in lines do
        if depth == "" then physical_device = device end
        if path ~= "" then
            mounts[path] = {device, physical_device}
        end
    end
    return mounts
end)

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


local diskio_unit_map = {
    TiB = 1024 * 1024 * 1024 * 1024,
    GiB = 1024 * 1024 * 1024,
    MiB = 1024 * 1024,
    KiB = 1024,
    B = 1,
}
--- Get activity of a drive. If unit is specified the value will be converted
-- to that unit.
-- @string device e.g. /dev/sda1
-- @tparam ?string unit any of "B", "KiB", "MiB", "GiB" or "TiB"
-- @treturn number,string activity, unit
function data.diskio(device, unit)
    local result = conky_parse(("${diskio %s}"):format(device))
    local value, parsed_unit = result:match("(%d+%p?%d*)(%w+)")
    value = tonumber(value)
    if unit and parsed_unit ~= unit then
        value = value * diskio_unit_map[parsed_unit] / diskio_unit_map[unit]
    end
    return value, unit or parsed_unit
end

--- Get current HDD/SSD temperatures.
-- Relies on hddtemp to be running daemon mode. The results depend on what
-- hddtemp reports and may require manual configuration,
-- e.g. via /etc/default/hddtemp
-- For experimental NVME support, requires "nvme smart-log" to be available
-- and added as an exception in sudoers, hddtemp does not support NVME.
-- @function data.hddtemp
-- @treturn table mapping devices to temperature values
data.hddtemp = util.memoize(5, function()
    local hddtemp = read_cmd("nc localhost 7634 -d")
    local temperatures = {}
    for device, temp in hddtemp:gmatch("|([^|]+)|[^|]+|(%d+)|C|") do
        temperatures[device] = tonumber(temp)
    end

    -- experimental: nvme drives, currently requires sudo
    local lsblk = read_cmd("lsblk --nodeps --noheadings --paths --output NAME")
    for device in lsblk:gmatch("/dev/nvme%S+") do
        local nvme = read_cmd(("sudo nvme smart-log '%s'"):format(device))
        temperatures[device] = tonumber(nvme:match("temperature%s+: (%d+) C"))
    end
    return temperatures
end)

return data
