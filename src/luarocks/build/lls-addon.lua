local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local path = require("luarocks.path")
local cfg = require("luarocks.core.cfg")
local json = require("luarocks.vendor.dkjson")

local jsonUtil = require("luarocks.build.lls-addon.json-util")
local array = jsonUtil.array
local object = jsonUtil.object
local isJsonArray = jsonUtil.isJsonArray
local isJsonObject = jsonUtil.isJsonObject
local readJsonFile = jsonUtil.readJsonFile
local coerceJson = jsonUtil.coerceJson

local tableUtil = require("luarocks.build.lls-addon.table-util")
local extend = tableUtil.extend
local unnest2 = tableUtil.unnest2

local M = {}

local function assertContext(context, ...)
	local s, msg = ...
	if not s then
		error(context .. ": " .. msg)
	end
	return ...
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
		print(luarcPath .. " not found, generating a new one")
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

---@return string
local function getProjectDir()
	local projectDir = cfg.project_dir --[[@as string]]
	if not projectDir then
		print("project directory not found, defaulting to working directory")
		assertContext("when changing to working directory", fs.change_dir("."))
		projectDir = fs.current_dir()
		assert(fs.pop_dir(), "unable to find source directory")
	end
	return projectDir
end

---@param projectDir string
---@return string
local function getDefaultVscSettingsPath(projectDir)
	return dir.path(projectDir, ".vscode", "settings.json")
end

---@param projectDir string
---@return string
local function getDefaultLuarcPath(projectDir)
	return dir.path(projectDir, ".luarc.json")
end

local SEP = string.sub(package.config, 3, 3)
local SEP_PATTERN = "[^%" .. SEP .. "]+"

---@param envVariable string
---@return string[]? paths
local function readEnvPaths(envVariable)
	print("looking for paths in " .. envVariable)
	local PATH = os.getenv(envVariable)
	if not PATH then
		return nil
	end

	local paths = {}
	for luarcPath in string.gmatch(PATH, SEP_PATTERN) do
		table.insert(paths, luarcPath)
	end
	return paths
end

---merges ('config.json').settings into .luarc.json
---@param sourcePath string
---@param luarc { [string]: any }
---@return { [string]: any } luarc
local function copyConfigSettings(sourcePath, luarc)
	local config = readJsonFile(sourcePath)

	if not isJsonObject(config) then
		print("Root of 'config.json' is not an object, skipping")
		return luarc
	end
	---@cast config { [string]: any }

	local settings = config.settings
	if not isJsonObject(settings) then
		print("key 'settings' of " .. sourcePath .. " is not an object, skipping")
		return luarc
	end
	---@cast settings { [string]: any }

	print("Merging 'settings' object into .luarc.json")
	local settingsNoPrefix = object({})
	for k, v in pairs(settings) do
		settingsNoPrefix[k:match("^Lua%.(.*)$") or k] = v
	end

	return extend(luarc, unnest2(settingsNoPrefix))
end

---@param settings { [string]: any }
---@param luarc { [string]: any }
---@return { [string]: any } luarc
local function copyBuildSettings(settings, luarc)
	settings = coerceJson(settings)
	if not isJsonObject(settings) then
		error("'rockspec.build.settings' is not an object.")
	end

	print("Merging 'rockspec.build.settings' into .luarc.json")
	return extend(luarc, unnest2(settings))
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

	local rockspecSettings = rockspec.build["settings"]
	local configSource = dir.path(fs.current_dir(), "config.json")
	if rockspecSettings ~= nil then
		luarc = luarc or object({})
		luarc = copyBuildSettings(rockspecSettings, luarc)
	elseif fs.exists(configSource) then
		copyFile(configSource, dir.path(installDirectory, "config.json"))

		-- also merge 'settings' from 'config.json' into .luarc.json
		luarc = luarc or object({})
		luarc = copyConfigSettings(configSource, luarc)
	end

	if luarc then
		local luarcPaths = readEnvPaths("LLSADDON_LUARCPATH")
		local vscPaths = readEnvPaths("LLSADDON_VSCSETTINGSPATH")

		if luarcPaths then
			for _, luarcPath in ipairs(luarcPaths) do
				local oldLuarc = readLuarc(luarcPath)
				extend(oldLuarc, luarc)
				writeLuarc(oldLuarc, luarcPath)
			end
		end

		if vscPaths and #vscPaths > 0 then
			local newSettings = object({})
			for k, v in pairs(luarc) do
				newSettings["Lua." .. k] = v
			end

			for _, vscPath in ipairs(vscPaths) do
				local oldSettings = readLuarc(vscPath)
				extend(oldSettings, newSettings)
				writeLuarc(oldSettings, vscPath)
			end
		end

		if not luarcPaths and not vscPaths then
			local projectDir = getProjectDir()
			local luarcPath = getDefaultLuarcPath(projectDir)
			if fs.exists(luarcPath) then
				local oldLuarc = readLuarc(luarcPath)
				extend(oldLuarc, luarc)
				writeLuarc(oldLuarc, luarcPath)
				return
			end

			local vscPath = getDefaultVscSettingsPath(projectDir)
			if fs.exists(vscPath) then
				local newSettings = object({})
				for k, v in pairs(luarc) do
					newSettings["Lua." .. k] = v
				end

				local oldSettings = readLuarc(vscPath)
				extend(oldSettings, newSettings)
				writeLuarc(oldSettings, vscPath)
				return
			end

			-- generate a new .luarc.json if neither of the defaults exist
			writeLuarc(luarc, luarcPath)
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
