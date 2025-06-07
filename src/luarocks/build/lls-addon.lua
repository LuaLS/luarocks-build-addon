local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local path = require("luarocks.path")
local cfg = require("luarocks.core.cfg")
local json = require("luarocks.vendor.dkjson")

local jsonCmp = require("luarocks.build.lls-addon.json-cmp")
local extend = require("luarocks.build.lls-addon.extend")
local contains = require("luarocks.build.lls-addon.contains")

local M = {}

local array = jsonCmp.array
local object = jsonCmp.object
local arrayMt = jsonCmp.arrayMt
local objectMt = jsonCmp.objectMt
local isJsonArray = jsonCmp.isJsonArray
local isJsonObject = jsonCmp.isJsonObject

local function assertContext(context, ...)
	local s, msg = ...
	if not s then
		error(context .. ": " .. msg)
	end
	return ...
end

---@param sourcePath string
---@return any
local function readJsonFile(sourcePath)
	local file <close> = assertContext("when opening " .. sourcePath, io.open(sourcePath))
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
		luarc = object({})
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
	local file <close> = assertContext("when opening " .. luarcPath, io.open(luarcPath, "w")) --[[@as file*]]
	assertContext("when writing to .luarc.json", file:write(contents))
end

---@return string[] luarcPaths
local function readLuarcPaths()
	local LUARC_PATH = os.getenv("LLSADDON_LUARCPATH")
	if LUARC_PATH then
		local luarcPaths = {}
		local sep = string.sub(package.config, 3, 3)
		for luarcPath in string.gmatch(LUARC_PATH, "[^%" .. sep .. "]+") do
			table.insert(luarcPaths, luarcPath)
		end
		return luarcPaths
	else
		local projectDir = cfg.project_dir --[[@as string]]
		if not projectDir then
			print("project directory not found, defaulting to working directory")
			assertContext("when changing to working directory", fs.change_dir("."))
			projectDir = fs.current_dir()
			assert(fs.pop_dir(), "unable to find source directory")
		end
		return { dir.path(projectDir, ".luarc.json") }
	end
end

---merges ('config.json').settings into .luarc.json
---@param source string
---@param luarc table
---@return table luarc
local function copyConfigSettings(source, luarc)
	local config = readJsonFile(source)

	if not isJsonObject(config) then
		print("Root of 'config.json' is not an object, skipping")
		return luarc
	end
	---@cast config { [string]: any }

	local settings = config.settings
	if not isJsonObject(settings) then
		print("key 'settings' of " .. source .. " is not an object, skipping")
		return luarc
	end
	---@cast settings { [string]: any }

	print("Merging 'settings' object into .luarc.json")
	local settingsNoPrefix = object({})
	for k, v in pairs(settings) do
		settingsNoPrefix[k:match("^Lua%.(.*)$") or k] = v
	end

	return extend(luarc, settingsNoPrefix)
end

---@param source string
---@param destination string
local function copyFile(source, destination)
	print("Installing " .. source .. " to " .. destination)
	assertContext("when copying into" .. destination, fs.copy(source, destination))
end

---@param source string
---@param destination string
local function copyDirectory(source, destination)
	print("Installing " .. source .. " to " .. destination)

	assertContext("when creating " .. destination, fs.make_dir(destination))
	assertContext("when copying files into " .. destination, fs.copy_contents(source, destination))
end

---does two things:
---- copies the library/, config.json and plugin.lua into the rock's install
---  directory
---- modifies or creates a project-scoped `.luarc.json`, which will contain
---  references to the above copied files
---@param rockspec luarocks.rockspec
local function addFiles(rockspec)
	-- a list of paths separated by `package.config:sub(3, 3)`
	local luarcPaths = readLuarcPaths()

	local name = rockspec.package
	local version = rockspec.version
	print("Building addon " .. name .. " @ " .. version)

	local installDirectory = path.install_dir(name, version)

	local luarc ---@type { [string]: any }

	local librarySource = dir.path(fs.current_dir(), "library")
	if fs.exists(librarySource) then
		local libraryDestination = dir.path(installDirectory, "library")
		copyDirectory(librarySource, libraryDestination)

		-- also insert the library/ directory into 'workspace.library'
		luarc = luarc or object({})
		print("Adding " .. libraryDestination .. " to 'workspace.library' of .luarc.json")
		luarc["workspace.library"] = array({ libraryDestination })
	end

	local pluginSource = dir.path(fs.current_dir(), "plugin.lua")
	if fs.exists(pluginSource) then
		local pluginDestination = dir.path(installDirectory, "plugin.lua")
		copyFile(pluginSource, pluginDestination)

		-- also set 'runtime.plugin' in .luarc.json
		luarc = luarc or object({})
		print("Adding " .. pluginDestination .. " to 'runtime.plugin' of .luarc.json")
		luarc["runtime.plugin"] = pluginDestination
	end

	local configSource = dir.path(fs.current_dir(), "config.json")
	if fs.exists(configSource) then
		copyFile(configSource, dir.path(installDirectory, "config.json"))

		-- also merge 'settings' from 'config.json' into .luarc.json
		luarc = luarc or object({})
		luarc = copyConfigSettings(configSource, luarc)
	end

	if luarc then
		for _, luarcPath in ipairs(luarcPaths) do
			local oldLuarc = readLuarc(luarcPath)
			extend(oldLuarc, luarc)
			writeLuarc(oldLuarc, luarcPath)
		end
	end
end

---@param rockspec luarocks.rockspec
---@return boolean, string?
function M.run(rockspec)
	assert(rockspec:type() == "rockspec", "argument is not a rockspec")

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
