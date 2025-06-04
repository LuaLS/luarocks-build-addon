local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local path = require("luarocks.path")
local cfg = require("luarocks.core.cfg")
local json = require("luarocks.vendor.dkjson")

local M = {}

local arrayMt = { __jsontype = "array" }
local objectMt = { __jsontype = "object" }

---@param value any
---@return boolean
local function isJsonObject(value)
	return type(value) == "table" and getmetatable(value) == objectMt
end

---@param value any
---@return boolean
local function isJsonArray(value)
	return type(value) == "table" and getmetatable(value) == arrayMt
end

---checks if all fields of `a` is equal to all fields of `b`
---@param a any
---@param b any
local function deepEqual(a, b)
	if type(a) == "table" and type(b) == "table" then
		for k, v in pairs(a) do
			if b[k] ~= v then
				return false
			end
		end
		return true
	else
		return a == b
	end
end

---checks if there is any element in `array` that is deeply equal to `value`
---@param array any[]
---@param value any
---@return boolean
local function contains(array, value)
	for _, v in ipairs(array) do
		if deepEqual(v, value) then
			return true
		end
	end
	return false
end

---modifies `old` such that it contains all the properties of `new`. Arrays are
---treated like sets, so any new values will only be inserted if the array
---doesn't contain it.
---@param old any
---@param new any
---@return any
local function extend(old, new)
	if isJsonArray(old) and isJsonArray(new) then -- treat arrays like sets
		for _, v in ipairs(new) do
			if not contains(old, v) then
				table.insert(old, v)
			end
		end
		return old
	elseif isJsonObject(old) and isJsonObject(new) then
		for k, v in pairs(new) do
			old[k] = extend(old[k], v)
		end
		return old
	else
		return new
	end
end

---@param sourcePath string
---@return any
local function readJsonFile(sourcePath)
	local file <close> = assert(io.open(sourcePath))
	local contents = file:read("a")
	return json.decode(contents, nil, json.null, objectMt, arrayMt)
end

---reads .luarc.json into a table, or returns a new one if it doesn't exist
---@param luarcPath string
---@return { [string]: any } luarc
local function readLuarc(luarcPath)
	local luarc ---@type { [string]: any }
	if fs.exists(luarcPath) then
		print("Found " .. luarcPath)
		luarc = readJsonFile(luarcPath) --[[@as { [string]: any }]]
		if not isJsonObject(luarc) then
			error("[BuildError]: Expected root of '.luarc.json' to be an object")
		end
	else
		print(luarcPath .. " not found, generating...")
		luarc = setmetatable({}, objectMt)
	end

	return luarc
end

---gets all keys from a json object
---@param keyorder string[]
---@param obj { [string]: any }
local function getRecursiveKeys(keyorder, obj)
	if isJsonObject(obj) then
		for k, v in pairs(obj) do
			table.insert(keyorder, k)
			getRecursiveKeys(keyorder, v)
		end
	elseif isJsonArray(obj) then
		for _, v in ipairs(obj) do
			getRecursiveKeys(keyorder, v)
		end
	end
end

---writes the given table into .luarc.json
---@param luarc { [string]: any }
---@param luarcPath string
local function writeLuarc(luarc, luarcPath)
	local keyorder = {} ---@type string[]
	getRecursiveKeys(keyorder, luarc)
	table.sort(keyorder)
	local contents = json.encode(luarc, { indent = 2, keyorder = keyorder }) --[[@as string]]
	local file <close> = assert(io.open(luarcPath, "w"))
	file:write(contents)
end

---merges ('config.json').settings into .luarc.json
---@param source string
---@param luarc table
---@return table luarc
local function copyConfigSettings(source, luarc)
	-- also decode it and copy the settings into .luarc.json
	local config = readJsonFile(source) --[[@as { [string]: any }]]

	if not isJsonObject(config) then
		print("Root of 'config.json' is not an object, skipping")
		return luarc
	end

	local settings = config.settings
	if not isJsonObject(settings) then
		print("key 'settings' of " .. source .. " is not an object, skipping")
		return luarc
	end
	---@cast settings { [string]: any }

	print("Merging 'settings' object into .luarc.json")
	local settingsNoPrefix = setmetatable({}, objectMt) ---@type { [string]: any }
	for k, v in pairs(settings) do
		settingsNoPrefix[k:match("^Lua%.(.*)$") or k] = v
	end

	return extend(luarc, settingsNoPrefix)
end

---pushes the library/ path to the 'workspace.library' array
---@param destination string
---@param luarc { [string]: any }
local function insertLibrary(destination, luarc)
	print("Adding " .. destination .. " to 'workspace.library' of .luarc.json")
	local library = luarc["workspace.library"]
	if not isJsonArray(library) then
		luarc["workspace.library"] = setmetatable({ destination }, arrayMt)
	elseif not contains(library, destination) then
		table.insert(library, destination)
		table.sort(library)
	end
end

---@param source string
---@param destination string
local function copyFile(source, destination)
	print("Installing " .. source .. " to " .. destination)
	assert(fs.copy(source, destination))
end

---@param source string
---@param destination string
local function copyDirectory(source, destination)
	print("Installing " .. source .. " to " .. destination)

	assert(fs.make_dir(destination))
	assert(fs.copy_contents(source, destination))
end

---does two things:
---- copies the library/, config.json and plugin.lua into the rock's install
---  directory
---- modifies or creates a project-local `.luarc.json`, which will contain
---  references to the above copied files
---@param rockspec luarocks.rockspec
local function addFiles(rockspec)
	local name = rockspec.package
	local version = rockspec.version

	print("Building addon " .. name .. " @ " .. version)

	local installDirectory = path.install_dir(name, version)

	local luarcPath = dir.path(cfg.project_dir, ".luarc.json")

	local luarc ---@type { [string]: any }

	local librarySource = dir.path(fs.current_dir(), "library")
	if fs.exists(librarySource) then
		local libraryDestination = dir.path(installDirectory, "library")
		copyDirectory(librarySource, libraryDestination)

		-- also insert the library/ directory into 'workspace.library'
		luarc = luarc or readLuarc(luarcPath)
		insertLibrary(libraryDestination, luarc)
	end

	local pluginSource = dir.path(fs.current_dir(), "plugin.lua")
	if fs.exists(pluginSource) then
		local pluginDestination = dir.path(installDirectory, "plugin.lua")
		copyFile(pluginSource, pluginDestination)

		-- also set 'runtime.plugin' in .luarc.json
		luarc = luarc or readLuarc(luarcPath)
		luarc["runtime.plugin"] = pluginDestination
	end

	local configSource = dir.path(fs.current_dir(), "config.json")
	if fs.exists(configSource) then
		copyFile(configSource, dir.path(installDirectory, "config.json"))

		-- also merge 'settings' from 'config.json' into .luarc.json
		luarc = luarc or readLuarc(luarcPath)
		luarc = copyConfigSettings(configSource, luarc)
	end

	if luarc then
		writeLuarc(luarc, luarcPath)
	end
end

---@param rockspec luarocks.rockspec
---@return boolean?, string?
function M.run(rockspec)
	assert(rockspec:type() == "rockspec")

	local s, msg = pcall(addFiles, rockspec)
	if not s then
		---@cast msg string
		local match = msg:match("%[BuildError%]%: (.*)$")
		if match then
			return false, match
		else
			error(msg)
		end
	end
	return true
end

return M
