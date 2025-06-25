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
local extendNested = tableUtil.extendNested
local extendUnnested = tableUtil.extendUnnested
local nest2 = tableUtil.nest2
local unnest2 = tableUtil.unnest2

local M = {}

local DIR_SEP = string.sub(package.config, 1, 1)
local PATH_SEP = string.sub(package.config, 3, 3)
local PATH_SEP_PATTERN = "[^%" .. PATH_SEP .. "]+"

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

---@param pathsString string?
---@return string[]? paths
local function parsePathList(pathsString)
	if not pathsString then
		return nil
	end

	local paths = {}
	for luarcPath in string.gmatch(pathsString, PATH_SEP_PATTERN) do
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

	return extendNested(luarc, nest2(settingsNoPrefix))
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
	return extendNested(luarc, nest2(settings))
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

---@param projectDir string
---@param rockspec luarocks.rockspec
---@param env { [string]: string? }
---@return { [string]: any }? luarc
local function compileLuarc(projectDir, rockspec, env)
	local installDir = path.install_dir(rockspec.package, rockspec.version)
	if not env.ABSPATH and installDir:sub(1, #projectDir) == projectDir then
		print("Making install directory relative to " .. projectDir)
		installDir = installDir:sub(#projectDir + 1)
		if installDir:sub(1, 1) == DIR_SEP then
			installDir = installDir:sub(2)
		end
	end

	local luarc ---@type { [string]: any }

	local librarySource = dir.path(fs.current_dir(), "library")
	if fs.exists(librarySource) then
		local libraryDestination = dir.path(installDir, "library")
		copyDirectory(librarySource, libraryDestination)

		-- also insert the library/ directory into 'workspace.library'
		luarc = luarc or object({})
		print("Adding " .. libraryDestination .. " to 'workspace.library' of .luarc.json")
		luarc.workspace = object({ library = array({ libraryDestination }) })
	end

	local pluginSource = dir.path(fs.current_dir(), "plugin.lua")
	if fs.exists(pluginSource) then
		local pluginDestination = dir.path(installDir, "plugin.lua")
		copyFile(pluginSource, pluginDestination)

		-- also set 'runtime.plugin' in .luarc.json
		luarc = luarc or object({})
		print("Adding " .. pluginDestination .. " to 'runtime.plugin' of .luarc.json")
		luarc.runtime = object({ plugin = pluginDestination })
	end

	local rockspecSettings = rockspec.build["settings"]
	local configSource = dir.path(fs.current_dir(), "config.json")
	if rockspecSettings ~= nil then
		luarc = luarc or object({})
		luarc = copyBuildSettings(rockspecSettings, luarc)
	elseif fs.exists(configSource) then
		copyFile(configSource, dir.path(installDir, "config.json"))

		-- also merge 'settings' from 'config.json' into .luarc.json
		luarc = luarc or object({})
		luarc = copyConfigSettings(configSource, luarc)
	end

	return luarc
end

---@param projectDir string
---@param luarc { [string]: any }
---@param env { [string]: string? }
local function updateLuarcFiles(projectDir, luarc, env)
	print("Looking for paths in LLSADDON_LUARCPATH")
	local luarcPaths = parsePathList(env.LUARCPATH)

	if luarcPaths then
		for _, luarcPath in ipairs(luarcPaths) do
			local oldLuarc = readLuarc(luarcPath)
			extendNested(oldLuarc, luarc)
			writeLuarc(oldLuarc, luarcPath)
		end
	end

	print("Looking for paths in LLSADDON_VSCSETTINGSPATH")
	local vscPaths = parsePathList(env.VSCSETTINGSPATH)
	if vscPaths and #vscPaths > 0 then
		local newSettings = object({})
		for k, v in pairs(unnest2(luarc)) do
			newSettings["Lua." .. k] = v
		end

		for _, vscPath in ipairs(vscPaths) do
			local oldSettings = readLuarc(vscPath)
			extendUnnested(oldSettings, newSettings)
			writeLuarc(oldSettings, vscPath)
		end
	end

	if not luarcPaths and not vscPaths then
		print("No paths found, looking for .luarc.json in project directory")
		local luarcPath = dir.path(projectDir, ".luarc.json")
		if fs.exists(luarcPath) then
			local oldLuarc = readLuarc(luarcPath)
			extendNested(oldLuarc, luarc)
			writeLuarc(oldLuarc, luarcPath)
			return
		end

		print(".luarc.json not found, looking for .vscode/settings.json in project directory")
		local vscPath = dir.path(projectDir, ".vscode", "settings.json")
		if fs.exists(vscPath) then
			local newSettings = object({})
			for k, v in pairs(unnest2(luarc)) do
				newSettings["Lua." .. k] = v
			end

			local oldSettings = readLuarc(vscPath)
			extendUnnested(oldSettings, newSettings)
			writeLuarc(oldSettings, vscPath)
			return
		end

		-- generate a new .luarc.json if neither of the defaults exist
		print(".vscode/settings.json not found, generating new .luarc.json")
		writeLuarc(luarc, luarcPath)
	end
end

---does two things:
---- copies the library/, config.json and plugin.lua into the rock's install
---  directory
---- modifies or creates a project-scoped `.luarc.json`, which will contain
---  references to the above copied files
---@param rockspec luarocks.rockspec
---@param env { [string]: string? }
function M.addFiles(rockspec, env)
	print("Building addon " .. rockspec.package .. " @ " .. rockspec.version)

	local projectDir = getProjectDir()
	local luarc = compileLuarc(projectDir, rockspec, env)

	if luarc then
		updateLuarcFiles(projectDir, luarc, env)
	end
end

---@param rockspec luarocks.rockspec
---@return boolean, string?
function M.run(rockspec)
	assert(rockspec:type() == "rockspec", "argument is not a rockspec")

	local env = {
		ABSPATH = os.getenv("LLSADDON_ABSPATH"),
		LUARCPATH = os.getenv("LLSADDON_LUARCPATH"),
		VSCSETTINGSPATH = os.getenv("LLSADDON_VSCSETTINGSPATH"),
	}

	local s, msg = pcall(M.addFiles, rockspec, env)
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
