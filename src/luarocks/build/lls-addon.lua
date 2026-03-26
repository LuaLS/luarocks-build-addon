local cfg = require("luarocks.core.cfg") --[[@as luarocks.core.cfg]]
local dir = require("luarocks.dir")
local fs = require("luarocks.fs") --[[@as luarocks.fs]]
local path = require("luarocks.path") --[[@as luarocks.path]]

local json = require("luarocks.build.lls-addon.json-util")
local log = require("luarocks.build.lls-addon.log")
local tableUtil = require("luarocks.build.lls-addon.table-util")

local extend = tableUtil.extend
local unnest2 = tableUtil.unnest2
local nestedPath = tableUtil.nestedPath

local unnestedPath = tableUtil.unnestedPath
local DIR_SEP = string.sub(package.config, 1, 1)
local PATH_SEP = string.sub(package.config, 3, 3)
local PATH_SEP_PATTERN = "[^%" .. PATH_SEP .. "]+"
local INTERROGATION_MARK = string.sub(package.config, 5, 5)

local M = {}

local FALSY_STRINGS = {
	["false"] = true,
	["no"] = true,
	["off"] = true,
	["0"] = true,
}

---@generic S, M
---@param context string
---@param s S
---@param msg? M
---@param ... any
---@return S s, M msg, any ...
local function assertContext(context, s, msg, ...)
	-- luacov: disable
	if not s then
		error(context .. ": " .. tostring(msg), 2)
	end
	return s, msg, ...
	-- luacov: enable
end

do
	---@param modulename string
	---@param path string
	---@param sep? string
	---@param rep? string
	---@return string searchPath
	local function getSearchPath(modulename, path, sep, rep)
		return (string.gsub(path, INTERROGATION_MARK, string.gsub(modulename, sep or "%.", rep or DIR_SEP)))
	end

	---@param modulename string
	---@param paths? string
	---@return string? filePath, string? errorMessage
	local function searchPaths(modulename, paths)
		paths = paths or package.path

		local root_dir = assert(cfg.root_dir, "root_dir not set")
		assert(fs.change_dir(path.rocks_tree_to_string(root_dir)))
		for p in string.gmatch(paths, PATH_SEP_PATTERN) do
			local filePath = getSearchPath(modulename, p)
			if fs.exists(filePath) then
				assert(fs.pop_dir())
				return filePath
			end
		end

		assert(fs.pop_dir())
		return nil, "unable to find file"
	end

	local loaderSource ---@type string
	function M.getLoaderSource()
		-- if `require('luarocks.build.lls-addon')` worked, this should always work
		if not loaderSource then
			loaderSource =
				assertContext("while finding 'luarocks.lls-addon-loader'", searchPaths("luarocks.lls-addon-loader")) --[[@as string]]
		end

		return loaderSource
	end
end

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
---@return (fun(): string?)? paths
local function parsePathList(pathsString)
	if pathsString == nil or pathsString == "" then
		return nil
	end

	return string.gmatch(pathsString, PATH_SEP_PATTERN)
end

---reads .luarc.json into a table, or returns a new one if it doesn't exist
---@param sourcePath string
---@return { [string]: any } luarc
local function readOrCreateLuarc(sourcePath)
	if not fs.exists(sourcePath) then
		log.info(sourcePath .. " not found, generating a new one")
		return json.object({})
	end

	log.info("Found " .. sourcePath)
	local luarc = json.read(sourcePath) --[[@as { [string]: any }]]
	if not json.isObject(luarc) then
		error("[BuildError]: Expected root of " .. sourcePath .. " to be an object.")
	end
	return luarc
end

---@return string
local function getProjectDir()
	local projectDir = cfg.project_dir --[[@as string]]
	if not projectDir then
		log.info("Project directory not found, defaulting to working directory")
		projectDir = fs.current_dir()
	end
	return projectDir
end
M.getProjectDir = getProjectDir

---@param self string
---@param target string
---@return string
local function makeDirRelativeTo(self, target)
	if string.sub(self, 1, string.len(target)) ~= target then
		return self
	end

	local result = string.sub(self, string.len(target) + 1)
	if string.sub(result, 1, 1) == DIR_SEP then
		return string.sub(result, 2)
	end

	return result
end

---@param projectDir string
---@param rockspec luarocks.Rockspec
---@param env { [string]: string? }
---@return string installDir, string formattedInstallDir
local function getInstallDir(projectDir, rockspec, env)
	local installDir = path.install_dir(rockspec.package, rockspec.version)

	if parseFlag(env.ABSPATH) then
		log.info("LLSADDON_ABSPATH is truthy, keeping install path absolute")
		return installDir, installDir
	end

	log.info("Attempt to make " .. installDir .. " relative to " .. projectDir)
	return installDir, makeDirRelativeTo(installDir, projectDir)
end
M.getInstallDir = getInstallDir

---@class lls-addon.install-entry
---@field type "file" | "directory"
---@field source string
---@field destination string

local installFiles
do
	---@param source string
	---@param destination string
	local function copyFile(source, destination)
		log.info("Installing " .. source .. " to " .. destination)

		local dirName = dir.dir_name(destination)
		if dirName ~= "" then
			assertContext("when creating intermediate folders for " .. destination, fs.make_dir(dirName))
		end
		assertContext("when copying into " .. destination, fs.copy(source, destination))
	end

	---@param source string
	---@param destination string
	local function copyDirectory(source, destination)
		log.info("Installing " .. source .. " to " .. destination)

		assertContext("when creating intermediate folders for " .. destination, fs.make_dir(destination))
		assertContext("when copying files into " .. destination, fs.copy_contents(source, destination))
	end

	---copies any files and directories listed in `installEntries`
	---@param installEntries lls-addon.install-entry[]
	function installFiles(installEntries)
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
				error("Unreachable: unknown install entry type: " .. type)
				-- luacov: enable
			end
		end
	end
end

---@class lls-addon.config-entry.append
---@field action "append"
---@field key string
---@field dedup boolean
---@field value unknown

---@class lls-addon.config-entry.prepend
---@field action "prepend"
---@field key string
---@field dedup boolean
---@field value unknown

---@class lls-addon.config-entry.set
---@field action "set"
---@field key string
---@field value unknown

---@class lls-addon.config-entry.merge
---@field action "merge"
---@field value { [string]: unknown }

---@class lls-addon.config-entry.remove-deleted-versions
---@field action "remove-deleted-versions"
---@field key string

---@alias lls-addon.config-entry
---| lls-addon.config-entry.append
---| lls-addon.config-entry.prepend
---| lls-addon.config-entry.set
---| lls-addon.config-entry.merge
---| lls-addon.config-entry.remove-deleted-versions

local compileLuarc
do
	---@param sourcePath string
	---@return { [string]: any } configSettings
	local function loadConfigSettings(sourcePath)
		local config = json.read(sourcePath)

		if not json.isObject(config) then
			error(
				"[BuildError]: root of " .. sourcePath .. " is not an object. Submit an issue to the addon developer."
			)
		end
		---@cast config { [string]: any }

		local settings = config.settings
		if not json.isObject(settings) then
			error(
				"[BuildError]: key 'settings' of "
					.. sourcePath
					.. " is not an object. Submit an issue to the addon developer."
			)
		end

		local settingsNoPrefix = json.object({})
		for k, v in pairs(settings) do
			settingsNoPrefix[k:match("^Lua%.(.*)$") or k] = v
		end

		return settingsNoPrefix
	end

	---@param settings { [string]: any }
	---@return { [string]: any } settings
	local function loadBuildSettings(settings)
		settings = json.coerce(settings)
		if not json.isObject(settings) then
			error("[BuildError]: 'rockspec.build.settings' is not an object. Submit an issue to the addon developer.")
		end

		return settings
	end

	---creates a "diffed" .luarc.json configuration that represents all the changes
	---to apply to the user's configuration files
	---@param rockspec luarocks.Rockspec
	---@param env { [string]: string? }
	---@return lls-addon.config-entry[] configEntries
	---@return lls-addon.install-entry[] installEntries
	function compileLuarc(rockspec, env)
		local projectDir = getProjectDir()
		local installDir, formattedInstallDir = getInstallDir(projectDir, rockspec, env)

		local configEntries = {} ---@type lls-addon.config-entry[]
		local installEntries = {} ---@type lls-addon.install-entry[]

		local librarySource = dir.path(fs.current_dir(), "library")
		if fs.is_dir(librarySource) then
			local libraryDestination = dir.path(installDir, "library")
			local formattedLibraryDestination = dir.path(formattedInstallDir, "library")

			log.info("Adding " .. formattedLibraryDestination .. " to 'workspace.library' of .luarc.json")
			table.insert(configEntries, {
				action = "append",
				key = "workspace.library",
				dedup = true,
				value = formattedLibraryDestination,
			} --[[@as lls-addon.config-entry.append]])

			table.insert(configEntries, {
				action = "remove-deleted-versions",
				key = "workspace.library",
			} --[[@as lls-addon.config-entry.remove-deleted-versions]])

			table.insert(installEntries, {
				type = "directory",
				source = librarySource,
				destination = libraryDestination,
			} --[[@as lls-addon.install-entry]])
		end

		local pluginSource = dir.path(fs.current_dir(), "plugin.lua")
		if fs.is_file(pluginSource) then
			local formattedLoaderSource = M.getLoaderSource()

			local pluginDestination = dir.path(installDir, "plugin.lua")
			local formattedPluginDestination = dir.path(formattedInstallDir, "plugin.lua")
			if parseFlag(env["ABSPATH"]) then
				log.info("LLSADDON_ABSPATH is truthy, keeping plugin path absolute.")
			else
				log.info("Attempt to make plugin paths relative to " .. projectDir)
				formattedLoaderSource = makeDirRelativeTo(formattedLoaderSource, projectDir)
			end

			-- also set 'runtime.plugin' in .luarc.json
			log.info("Adding " .. formattedPluginDestination .. " to 'runtime.plugin' of .luarc.json")

			table.insert(configEntries, {
				action = "prepend",
				key = "runtime.plugin",
				dedup = true,
				value = formattedLoaderSource,
			} --[[@as lls-addon.config-entry.prepend]])

			table.insert(configEntries, {
				action = "append",
				key = "runtime.plugin",
				dedup = true,
				value = formattedPluginDestination,
			} --[[@as lls-addon.config-entry.append]])

			table.insert(configEntries, {
				action = "remove-deleted-versions",
				key = "runtime.plugin",
			} --[[@as lls-addon.config-entry.remove-deleted-versions]])

			table.insert(installEntries, {
				type = "file",
				source = pluginSource,
				destination = pluginDestination,
			} --[[@as lls-addon.install-entry]])

			local pluginFolderSource = dir.path(fs.current_dir(), "plugin")
			if fs.is_dir(pluginFolderSource) then
				local pluginFolderDestination = dir.path(installDir, "plugin")
				table.insert(installEntries, {
					type = "directory",
					source = pluginFolderSource,
					destination = pluginFolderDestination,
				} --[[@as lls-addon.install-entry]])
			end
		end

		local rockspecSettings = rockspec.build["settings"]
		local configSource = dir.path(fs.current_dir(), "config.json")
		if rockspecSettings ~= nil then
			log.info("Merging 'rockspec.build.settings' into .luarc.json")

			table.insert(configEntries, {
				action = "merge",
				value = loadBuildSettings(rockspecSettings),
			} --[[@as lls-addon.config-entry.merge]])
		elseif fs.is_file(configSource) then
			log.info("Merging key 'settings' of config.json object into .luarc.json")

			table.insert(configEntries, {
				action = "merge",
				value = loadConfigSettings(configSource),
			} --[[@as lls-addon.config-entry.merge]])

			table.insert(installEntries, {
				type = "file",
				source = configSource,
				destination = dir.path(installDir, "config.json"),
			} --[[@as lls-addon.install-entry]])
		end

		return configEntries, installEntries
	end
	M.compileLuarc = compileLuarc
end

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
		for luarcPath in luarcPaths do
			table.insert(luarcFiles, {
				type = "luarc",
				path = luarcPath,
			} --[[@as lls-addon.luarc-file]])
		end
	end

	local vscPaths = parsePathList(env.VSCSETTINGSPATH)
	if vscPaths then
		log.info("LLSADDON_VSCSETTINGSPATH is defined")
		for vscPath in vscPaths do
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
	if fs.is_file(luarcPath) then
		log.info("found .luarc.json in project directory")
		return { { type = "luarc", path = luarcPath } }
	end

	local vscPath = dir.path(projectDir, ".vscode", "settings.json")
	if fs.is_file(vscPath) then
		log.info("found .vscode/settings.json in project directory")
		return { { type = "vscode settings", path = vscPath } }
	end

	-- generate a new .luarc.json if neither of the defaults exist
	log.info("generating new .luarc.json")
	return { { type = "luarc", path = luarcPath } }
end
M.findLuarcFiles = findLuarcFiles

local installLuarcFiles
do
	---@param list unknown[]
	---@param value unknown[]
	---@return integer?
	local function tableFind(list, value)
		for i, v in ipairs(list) do
			if v == value then
				return i
			end
		end

		return nil
	end

	---@param config { [string]: any }
	---@param key string
	---@param primary lls-addon.path-getter
	---@param secondary lls-addon.path-getter
	---@param nested boolean
	---@return any[]
	local function getConfigArray(config, key, primary, secondary, nested)
		local oldValue1 = primary.get(config, key)
		local oldValue1_isArray = json.isArray(oldValue1)
		local oldValue2 = secondary.get(config, key)
		local oldValue2_isArray = json.isArray(oldValue2)
		if oldValue1_isArray and oldValue2_isArray then
			secondary.set(config, key, nil)
			extend(nested, oldValue1, unnest2(oldValue2))
			return oldValue1
		elseif oldValue2_isArray then
			return oldValue2
		elseif oldValue1_isArray then
			return oldValue1
		else
			local list = json.array({})
			primary.set(config, key, list)
			return list
		end
	end

	---@param pointsToWrongVersion fun(path: string): boolean
	---@param config { [string]: any }
	---@param configEntries lls-addon.config-entry[]
	---@param luarcType "vscode settings" | "luarc"
	local function applyConfigEntries(pointsToWrongVersion, config, configEntries, luarcType)
		local prefix ---@type string
		local nested ---@type boolean
		if luarcType == "vscode settings" then
			prefix = "Lua."
			nested = false
		elseif luarcType == "luarc" then
			prefix = ""
			nested = true
		else
			-- luacov: disable
			error("Unreachable: Unknown config file type " .. tostring(luarcType))
			-- luacov: enable
		end

		local primary, secondary ---@type lls-addon.path-getter, lls-addon.path-getter
		if nested then
			primary, secondary = nestedPath, unnestedPath
		else
			primary, secondary = unnestedPath, nestedPath
		end

		local function getConfigArray2(key)
			return getConfigArray(config, key, primary, secondary, nested)
		end

		for _, entry in ipairs(configEntries) do
			local action = entry.action
			if action == "prepend" or action == "append" then
				---@cast entry lls-addon.config-entry.prepend | lls-addon.config-entry.append
				local key, value = prefix .. entry.key, entry.value
				local list = getConfigArray2(key)

				if not entry.dedup or not tableFind(list, value) then
					if action == "prepend" then
						table.insert(list, 1, value)
					else
						table.insert(list, value)
					end
				end
			elseif action == "merge" then
				---@cast entry lls-addon.config-entry.merge
				local value = unnest2(entry.value)
				if prefix ~= "" then
					local prefixedValue = json.object({})
					for k, v in pairs(value) do
						prefixedValue[prefix .. k] = v
					end
					extend(nested, config, prefixedValue)
				else
					extend(nested, config, value)
				end
			elseif action == "remove-deleted-versions" then
				---@cast entry lls-addon.config-entry.remove-deleted-versions
				local key = prefix .. entry.key

				local list = getConfigArray2(key) --[[@as unknown[] ]]
				for i = #list, 1, -1 do
					local v = list[i]
					if type(v) ~= "string" or pointsToWrongVersion(v) then
						table.remove(list, i)
					end
				end
			elseif action == "set" then
				---@cast entry lls-addon.config-entry.set
				local key, value = prefix .. entry.key, entry.value
				local oldValue1 = primary.get(config, key)
				local oldValue2 = secondary.get(config, key)
				if oldValue1 ~= nil and oldValue2 ~= nil then
					secondary.set(config, key, nil)
					primary.set(config, key, value)
				elseif oldValue2 ~= nil then
					secondary.set(config, key, value)
				else
					primary.set(config, key, value)
				end
			else
				-- luacov: disable
				error("Unreachable: unknown action " .. tostring(action))
				-- luacov: enable
			end
		end
	end

	---@param rockspec luarocks.Rockspec
	---@param luarcFiles lls-addon.luarc-file[]
	---@param configEntries lls-addon.config-entry[]
	function installLuarcFiles(rockspec, luarcFiles, configEntries)
		local pointsToWrongVersion
		do
			local projectDir = getProjectDir()
			local packageDir = dir.path(path.rocks_dir(), rockspec.package)
			local packageDirLen = string.len(packageDir)
			local currentVersionDir = dir.path(packageDir, rockspec.version)
			local currentVersionDirLen = string.len(currentVersionDir)

			function pointsToWrongVersion(installPath)
				local absPath = fs.absolute_name(installPath, projectDir)
				return string.sub(absPath, 1, packageDirLen) == packageDir
					and string.sub(absPath, 1, currentVersionDirLen) ~= currentVersionDir
			end
		end

		for _, luarcFile in ipairs(luarcFiles) do
			local type = luarcFile.type
			local path = luarcFile.path
			log.info(string.format("writing to %s: %s", type, path))
			local oldConfig = readOrCreateLuarc(path)
			applyConfigEntries(pointsToWrongVersion, oldConfig, configEntries, type)
			json.write(path, oldConfig, { sortKeys = true })
		end
	end
	M.installLuarcFiles = installLuarcFiles
end

---does two things:
---- copies the library/, config.json and plugin.lua into the rock's install
---  directory
---- modifies or creates a project-scoped `.luarc.json`, which will contain
---  references to the above copied files
---@param rockspec luarocks.Rockspec
---@param env { [string]: string? }
---@param noInstall boolean
local function installAddon(rockspec, env, noInstall)
	log.info("Building addon " .. rockspec.package .. " @ " .. rockspec.version)

	local projectDir = getProjectDir()
	local configEntries, installEntries = compileLuarc(rockspec, env)

	if #configEntries == 0 then
		log.warn("addon has no features; no files written!")
		return
	end

	local luarcFiles = findLuarcFiles(projectDir, env)
	if noInstall then
		log.info("--no-install option detected, stopping early")
		return
	end

	-- for copying library, plugin.lua, and config.json
	installFiles(installEntries)

	installLuarcFiles(rockspec, luarcFiles, configEntries)
end
M.installAddon = installAddon

local CRASH_MESSAGE = [[
An error occurred while running the lls-addon backend.
Please submit an issue at https://github.com/LuaLS/luarocks-build-addon/issues
]]

---@param rockspec luarocks.Rockspec
---@param noInstall boolean
---@return boolean, string?
function M.run(rockspec, noInstall)
	assert(rockspec:type() == "rockspec", "argument is not a rockspec")

	local env = {
		ABSPATH = cfg.variables["LLSADDON_ABSPATH"],
		LUARCPATH = cfg.variables["LLSADDON_LUARCPATH"],
		VSCSETTINGSPATH = cfg.variables["LLSADDON_VSCSETTINGSPATH"],
	}

	local s, msg = xpcall(installAddon, debug.traceback, rockspec, env, noInstall)
	if not s then
		---@cast msg string
		local match = msg:match("%[BuildError%]%: (.*)$")
		if match then
			return false, match
		else
			-- luacov: disable
			error(CRASH_MESSAGE .. msg)
			-- luacov: enable
		end
	end
	return true
end

return M
