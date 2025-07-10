local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local fs = require("luarocks.fs")
local path = require("luarocks.path")

local json = require("luarocks.build.lls-addon.json-util")
local log = require("luarocks.build.lls-addon.log")
local tableUtil = require("luarocks.build.lls-addon.table-util")

local extend = tableUtil.extend
local unnest2 = tableUtil.unnest2

local M = {}

local DIR_SEP = string.sub(package.config, 1, 1)
local PATH_SEP = string.sub(package.config, 3, 3)
local PATH_SEP_PATTERN = "[^%" .. PATH_SEP .. "]+"

local FALSY_STRINGS = {
	["false"] = true,
	["no"] = true,
	["off"] = true,
	["0"] = true,
}

---@param val string?
---@return boolean
local function parseFlag(val)
	if val == nil then
		return false
	else
		return not FALSY_STRINGS[val]
	end
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

local function assertContext(context, ...)
	-- luacov: disable
	local s, msg = ...
	if not s then
		error(context .. ": " .. msg)
	end
	return ...
	-- luacov: enable
end

---reads .luarc.json into a table, or returns a new one if it doesn't exist
---@param sourcePath string
---@return { [string]: any } luarc
local function readOrCreateLuarc(sourcePath)
	if fs.exists(sourcePath) then
		log.info("Found " .. sourcePath)
		local luarc = json.read(sourcePath) --[[@as { [string]: any }]]
		if not json.isObject(luarc) then
			error("[BuildError]: Expected root of " .. sourcePath .. " to be an object")
		end
		return luarc
	else
		log.info(sourcePath .. " not found, generating a new one")
		return json.object({})
	end
end

---@return string
local function getProjectDir()
	local projectDir = cfg.project_dir --[[@as string]]
	if not projectDir then
		log.info("project directory not found, defaulting to working directory")
		assertContext("when changing to working directory", fs.change_dir("."))
		projectDir = fs.current_dir()
		assert(fs.pop_dir(), "directory stack underflow")
	end
	return projectDir
end
M.getProjectDir = getProjectDir

---@param projectDir string
---@param rockspec luarocks.rockspec
---@param env { [string]: string? }
---@return string
local function getInstallDir(projectDir, rockspec, env)
	local installDir = path.install_dir(rockspec.package, rockspec.version)
	if not parseFlag(env.ABSPATH) and installDir:sub(1, #projectDir) == projectDir then
		log.info("Making install directory relative to " .. projectDir)
		installDir = installDir:sub(#projectDir + 1)
		if installDir:sub(1, 1) == DIR_SEP then
			installDir = installDir:sub(2)
		end
	end

	return installDir
end
M.getInstallDir = getInstallDir

---merges ('config.json').settings into .luarc.json
---@param sourcePath string
---@param luarc { [string]: any }
---@return { [string]: any } luarc
local function copyConfigSettings(sourcePath, luarc)
	local config = json.read(sourcePath)

	if not json.isObject(config) then
		error("[BuildError]: root of " .. sourcePath .. " is not an object.")
	end
	---@cast config { [string]: any }

	local settings = config.settings
	if not json.isObject(settings) then
		error("[BuildError]: key 'settings' of " .. sourcePath .. " is not an object.")
	end
	---@cast settings { [string]: any }

	log.info("Merging 'settings' object into .luarc.json")
	local settingsNoPrefix = json.object({})
	for k, v in pairs(settings) do
		settingsNoPrefix[k:match("^Lua%.(.*)$") or k] = v
	end

	return extend(false, luarc, unnest2(settingsNoPrefix))
end

---@param settings { [string]: any }
---@param luarc { [string]: any }
---@return { [string]: any } luarc
local function copyBuildSettings(settings, luarc)
	settings = json.coerce(settings)
	if not json.isObject(settings) then
		error("'rockspec.build.settings' is not an object.")
	end

	log.info("Merging 'rockspec.build.settings' into .luarc.json")
	return extend(false, luarc, unnest2(settings))
end

---@param source string
---@param destination string
local function copyFile(source, destination)
	log.info("Installing " .. source .. " to " .. destination)
	assertContext("when copying into" .. destination, fs.copy(source, destination))
end

---@param source string
---@param destination string
local function copyDirectory(source, destination)
	log.info("Installing " .. source .. " to " .. destination)

	assertContext("when creating " .. destination, fs.make_dir(destination))
	assertContext("when copying files into " .. destination, fs.copy_contents(source, destination))
end

---@class lls-addon.install-entry
---@field type "file" | "directory"
---@field source string
---@field destination string

local function installFiles(installEntries)
	for _, entry in ipairs(installEntries) do
		local type = entry.type
		local source = entry.source
		local destination = entry.destination
		if type == "file" then
			copyFile(source, destination)
		elseif type == "directory" then
			copyDirectory(source, destination)
		else
			-- luacov: disable
			error("unknown install entry type: " .. type)
			-- luacov: enable
		end
	end
end

---@param installDir string
---@param rockspecSettings unknown
---@return { [string]: any }? luarc
---@return lls-addon.install-entry[] installEntries
local function compileLuarc(installDir, rockspecSettings)
	local luarc ---@type { [string]: any }
	local installEntries = {} ---@type lls-addon.install-entry[]

	local librarySource = dir.path(fs.current_dir(), "library")
	if fs.exists(librarySource) then
		local libraryDestination = dir.path(installDir, "library")

		luarc = luarc or json.object({})
		log.info("Adding " .. libraryDestination .. " to 'workspace.library' of .luarc.json")
		luarc["workspace.library"] = json.array({ libraryDestination })

		table.insert(installEntries, {
			type = "directory",
			source = librarySource,
			destination = libraryDestination,
		} --[[@as lls-addon.install-entry]])
	end

	local pluginSource = dir.path(fs.current_dir(), "plugin.lua")
	if fs.exists(pluginSource) then
		local pluginDestination = dir.path(installDir, "plugin.lua")

		-- also set 'runtime.plugin' in .luarc.json
		luarc = luarc or json.object({})
		log.info("Adding " .. pluginDestination .. " to 'runtime.plugin' of .luarc.json")
		luarc["runtime.plugin"] = pluginDestination

		table.insert(installEntries, {
			type = "file",
			source = pluginSource,
			destination = pluginDestination,
		} --[[@as lls-addon.install-entry]])
	end

	local configSource = dir.path(fs.current_dir(), "config.json")
	if rockspecSettings ~= nil then
		luarc = luarc or json.object({})
		luarc = copyBuildSettings(rockspecSettings, luarc)
	elseif fs.exists(configSource) then
		-- also merge 'settings' from 'config.json' into .luarc.json
		luarc = luarc or json.object({})
		luarc = copyConfigSettings(configSource, luarc)

		table.insert(installEntries, {
			type = "file",
			source = configSource,
			destination = dir.path(installDir, "config.json"),
		} --[[@as lls-addon.install-entry]])
	end

	return luarc, installEntries
end
M.compileLuarc = compileLuarc

---@class lls-addon.luarc-file
---@field type "luarc" | "vscode settings"
---@field path string

---@param projectDir string
---@param env { [string]: string? }
---@return lls-addon.luarc-file[]
local function findLuarcFiles(projectDir, env)
	local luarcFiles = {} ---@type lls-addon.luarc-file[]

	local luarcPaths = parsePathList(env.LUARCPATH)
	if luarcPaths then
		log.info("LLSADDON_LUARCPATH is defined")
		for _, luarcPath in ipairs(luarcPaths) do
			table.insert(luarcFiles, {
				type = "luarc",
				path = luarcPath,
			} --[[@as lls-addon.luarc-file]])
		end
	end

	local vscPaths = parsePathList(env.VSCSETTINGSPATH)
	if vscPaths then
		log.info("LLSADDON_VSCSETTINGSPATH is defined")
		for _, vscPath in ipairs(vscPaths) do
			table.insert(luarcFiles, {
				type = "vscode settings",
				path = vscPath,
			} --[[@as lls-addon.luarc-file]])
		end
	end

	if luarcPaths or vscPaths then
		return luarcFiles
	end

	local luarcPath = dir.path(projectDir, ".luarc.json")
	if fs.exists(luarcPath) then
		log.info("found .luarc.json in project directory")
		return { { type = "luarc", path = luarcPath } }
	end

	local vscPath = dir.path(projectDir, ".vscode", "settings.json")
	if fs.exists(vscPath) then
		log.info("found .vscode/settings.json in project directory")
		return { { type = "vscode settings", path = vscPath } }
	end

	-- generate a new .luarc.json if neither of the defaults exist
	log.info("generating new .luarc.json")
	return { { type = "luarc", path = luarcPath } }
end
M.findLuarcFiles = findLuarcFiles

---@param luarcFiles lls-addon.luarc-file[]
---@param luarc { [string]: any }
local function installLuarcFiles(luarcFiles, luarc)
	local newSettings

	for _, luarcFile in ipairs(luarcFiles) do
		local type = luarcFile.type
		local path = luarcFile.path
		log.info(string.format("writing to %s: %s", type, path))
		if type == "vscode settings" then
			if not newSettings then
				newSettings = json.object({})
				for k, v in pairs(luarc) do
					newSettings["Lua." .. k] = v
				end
			end

			local oldSettings = readOrCreateLuarc(path)
			extend(false, oldSettings, newSettings)
			json.write(path, oldSettings, { sortKeys = true })
		elseif type == "luarc" then
			local oldLuarc = readOrCreateLuarc(path)
			extend(true, oldLuarc, luarc)
			json.write(path, oldLuarc, { sortKeys = true })
		else
			-- luacov: disable
			error(string.format("unknown luarc path type '%s'", type))
			-- luacov: enable
		end
	end
end
M.installLuarcFiles = installLuarcFiles

---does two things:
---- copies the library/, config.json and plugin.lua into the rock's install
---  directory
---- modifies or creates a project-scoped `.luarc.json`, which will contain
---  references to the above copied files
---@param rockspec luarocks.rockspec
---@param env { [string]: string? }
local function installAddon(rockspec, env)
	log.info("Building addon " .. rockspec.package .. " @ " .. rockspec.version)

	local projectDir = getProjectDir()
	local installDir = getInstallDir(projectDir, rockspec, env)
	local luarc, installEntries = compileLuarc(installDir, rockspec.build["settings"])

	if luarc then
		local luarcFiles = findLuarcFiles(projectDir, env)
		installLuarcFiles(luarcFiles, luarc)

		-- for copying library, plugin.lua, and config.json
		installFiles(installEntries)
	else
		log.warn("addon has no features; no files written!")
	end
end
M.installAddon = installAddon

---@param rockspec luarocks.rockspec
---@param noInstall boolean
---@return boolean, string?
function M.run(rockspec, noInstall)
	assert(rockspec:type() == "rockspec", "argument is not a rockspec")

	local env = {
		ABSPATH = os.getenv("LLSADDON_ABSPATH"),
		LUARCPATH = os.getenv("LLSADDON_LUARCPATH"),
		VSCSETTINGSPATH = os.getenv("LLSADDON_VSCSETTINGSPATH"),
	}

	local s, msg = pcall(installAddon, rockspec, env)
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
