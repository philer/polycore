--- Data gathering facilities for conky widgets
-- @module data

local util = require('src/util')

-- lua 5.1 to 5.3 compatibility
local unpack = unpack or table.unpack  -- luacheck: read_globals unpack table

local data = {}

local read_cmd = util.memoize(1, function(cmd)
    local pipe = io.popen(cmd)
    local result = pipe:read("*a")
    local success, exit_or_signal, n = pipe:close()
    if not success then
        print("\027[31mCommand '" .. cmd .. "' failed.\027[0m")
    end
    return result
end)

local unit_map = {
    B = 1,
    kB = 1000, KB = 1000, MB = 1000 ^ 2, GB = 1000 ^ 3, TB = 1000 ^ 4,
    kiB = 1024, KiB = 1024, MiB = 1024 ^ 2, GiB = 1024 ^ 3, TiB = 1024 ^ 4,
}

--- Convert memory value from one unit to another.
-- @string from like "B", "MiB", "kB", ...
-- @tparam string|nil to like "B", "MiB", "kB", ...
--                       For nil, no conversion happens.
-- @number value amount of memory in `from` unit
local function convert_unit(from, to, value)
    if to and from ~= to then
        return value * unit_map[from] / unit_map[to]
    end
    return value
end


-- Gather conky_parse calls and run them in bulk on the next update.
local EagerLoader = util.class()


--- Create an EagerLoader instance.
-- Pass a function that takes a list of keys and returns an iterator of values.
-- @tparam function
function EagerLoader:init(fetch_data)
    self.fetch_data = fetch_data
    self._vars = {}  -- maps vars to max age
    self._results = {}  -- maps vars to results
end

--- Run a bulk conky_parse with collected strings from previous updates.
-- Called at the begin of each update to greatly improve performance.
-- @function eager_loader:load
function EagerLoader:load()
    local vars = {}

    -- age remembered variables, queue outdated ones for evaluation
    local i = 1
    for var, remember in pairs(self._vars) do
        remember = remember > 1 and remember - 1 or nil
        self._vars[var] = remember
        if not remember then
            self._results[var] = nil
            vars[i] = var
            i = i + 1
        end
    end
    if i == 1 then return end

    -- parse collected variables
    i = 1
    for result in self.fetch_data(vars) do
        self._results[vars[i]] = result
        i = i + 1
    end
end

--- Retrieve a conky_parse result.
-- @usage
-- data.eager_loader:get("$update")
-- data.eager_loader:get("${cpu cpu%s}", 2)  -- usage of second CPU core
-- data.eager_loader:get(5, "${fs_used_perc %s}", "/home")  -- cached for 5 updates
-- @function eager_loader:get
-- @int[opt=1] remember
-- @string var string to be evaluated by `conky_parse`
-- @param[opt] ... Additional arguments passed to `var:format(...)`
-- @treturn string result of `conky_parse(var)`
function EagerLoader:get(remember, var, ...)
    if type(remember) == "string" then  -- skipped first argument
        var = var and remember:format(var, ...) or remember
        remember = 1
    elseif ... then
        var = var:format(...)
    end

    -- queue this variable for future updates
    if not self._vars[var] then
        self._vars[var] = remember or 1
    end

    -- retrieve the result
    if not self._results[var] then
        self._results[var] = self.fetch_data({var})()
    end
    return self._results[var]
end


-- local ConkyLoader = util.class(EagerLoader)
local conky_loader = EagerLoader(function(vars)
    local output = conky_parse("<|" .. table.concat(vars, "|><|") .. "|>")
    return output:gmatch("<|(.-)|>")
end)
data.conky_loader = conky_loader


local nvidia_loader = EagerLoader(function(vars)
    local output = read_cmd("nvidia-smi --format=csv,noheader,nounits --query-gpu=" .. table.concat(vars, ","))
    return (", " .. output):gmatch(", ([^,]+)")
end)
data.nvidia_loader = nvidia_loader


--- Get the current usage percentages of individual CPU cores
-- @int cores number of CPU cores
-- @treturn {number,...}
function data.cpu_percentages(cores)
    local conky_string = "${cpu cpu1}"
    for i = 2, cores do
        conky_string = conky_string .. "|${cpu cpu" .. i .. "}"
    end
    return util.map(tonumber, conky_loader:get(conky_string):gmatch("%d+"))
end

--- Get the current frequencies at which individual CPU cores are running
-- @int cores number of CPU cores
-- @treturn {number,...}
function data.cpu_frequencies(cores)
    local conky_string = "${freq_g 1}"
    for i = 2, cores do
        conky_string = conky_string .. "|${freq_g " .. i .. "}"
    end
    return util.map(tonumber, conky_loader:get(conky_string):gmatch("%d+[,.]?%d*"))
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

--- Get current memory usage info
-- @tparam ?string unit like "B", "MiB", "kB", ...
-- @treturn number,number,number,number usage, easyfree, free, total
function data.memory(unit)
    local conky_output = conky_loader:get("$mem|$memeasyfree|$memfree|$memmax")
    local results = {}
    for value, parsed_unit in conky_output:gmatch("(%d+%p?%d*) ?(%w+)") do
        table.insert(results, convert_unit(parsed_unit, unit, tonumber(value)))
    end
    return unpack(results)
end

--- Get volume of down- and uploaded data since last conky update cycle.
-- @string interface e.g. "eth0"
-- @treturn number,number downspeed and upspeed in KiB
function data.network_speed(interface)
    local result = conky_loader:get("${downspeedf %s}|${upspeedf %s}", interface, interface)
    return unpack(util.map(tonumber, result:gmatch("%d+%p?%d*")))
end

--- Get current GPU usage in percent.
-- Relies on nvidia-smi to be installed.
-- @treturn number
function data.gpu_percentage()
    return tonumber(nvidia_loader:get("utilization.gpu"))
end

--- Get current GPU frequency.
-- @treturn number in MHz
function data.gpu_frequency()
    return tonumber(nvidia_loader:get("clocks.current.graphics"))
end

--- Get current GPU temperature.
-- Relies on nvidia-smi to be installed.
-- @treturn number temperature in °C
function data.gpu_temperature()
    return tonumber(nvidia_loader:get("temperature.gpu"))
end

--- Get current VRAM usage.
-- Relies on nvidia-smi to be installed.
-- @treturn number,number used, total in MiB
function data.gpu_memory()
    return tonumber(nvidia_loader:get("memory.used")),
           tonumber(nvidia_loader:get("memory.total"))
end

--- Get current GPU power draw.
-- Relies on nvidia-smi to be installed.
-- @treturn number power draw in W
function gpu_power_draw()
    return tonumber(nvidia_loader:get("power.draw"))
end

--- Get current GPU power draw.
-- Relies on nvidia-smi to be installed.
-- @treturn number power draw in W
function gpu_power_limit()
    return tonumber(nvidia_loader:get("power.limit"))
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


--- Is the given path a mount? (see conky's is_mounted)
-- @string path
-- @treturn bool
function data.is_mounted(path)
    return "1" == conky_loader:get(5, "${if_mounted %s}1${endif}", path)
end

--- Get the drive usage in percent for the given path.
-- @string path
-- @treturn number
function data.drive_percentage(path)
    return tonumber(conky_loader:get(5, "${fs_used_perc %s}", path))
end

--- Get activity of a drive. If unit is specified the value will be converted
-- to that unit.
-- @string device e.g. /dev/sda1
-- @string[opt] mode "read" or "write"; both if nil
-- @string[opt] unit like "B", "MiB", "kB", ...; no conversion if nil
-- @treturn number,string activity, unit
function data.diskio(device, mode, unit)
    mode = mode and "_" .. mode or ""
    local result = conky_loader:get("${diskio%s %s}", mode, device)
    local value, parsed_unit = result:match("(%d+%p?%d*) ?(%w+)")
    return convert_unit(parsed_unit, unit, tonumber(value)), unit or parsed_unit
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
