---@diagnostic disable-next-line: unknown-cast-variable
---@cast assert luassert

local lfs = require("lfs") ---@type LuaFileSystem

local jsonUtil = require("luarocks.build.lls-addon.json-util")
local readJsonFile = jsonUtil.readJsonFile

assert(_VERSION == "Lua 5.4", "version is not Lua 5.4")

local SEP = package.config:sub(1, 1)
local NULL = SEP == "\\" and "NUL" or "/dev/null"
local RMDIR_CMD = SEP == "\\" and "rmdir /S /Q %s" or "rm -rf %s"
local RM_CMD = SEP == "\\" and string.format("del %%s 2> %s", NULL) or "rm -f %s"

---@param ... string
---@return string
local function path(...)
	return table.concat({ ... }, SEP)
end

---@param path string
---@return boolean, string?
local function fileExists(path)
	return lfs.attributes(path) ~= nil
end

local INSTALL_DIR = path("lua_modules", "lib", "luarocks", "rocks-5.4", "types", "0.1-1")

---@param dir string
---@return boolean
local function tryCopyLuarc(dir)
	local baseLuarc = io.open(path(dir, "base.luarc.json"), "r")
	if not baseLuarc then
		return false
	end

	local contents = baseLuarc:read("a")
	baseLuarc:close()
	local luarc = assert(io.open(path(dir, ".luarc.json"), "w")) --[[@as file*]]
	luarc:write(contents)
	luarc:close()
	return true
end

---@param dir string
---@return boolean
local function tryCopySettings(dir)
	local baseSettings = io.open(path(dir, ".vscode", "base.settings.json"), "r")
	if not baseSettings then
		return false
	end

	local contents = baseSettings:read("a")
	baseSettings:close()
	local settings = assert(io.open(path(dir, ".vscode", "settings.json"), "w")) --[[@as file*]]
	settings:write(contents)
	settings:close()
	return true
end

---@param dir string
local function makeProject(dir)
	assert(dir:sub(1, 1) ~= "/", "don't pass paths starting at root")
	return os.execute(table.concat({
		("cd %s"):format(dir),
		("luarocks init --no-wrapper-scripts --no-gitignore > %s"):format(NULL),
		("luarocks make > %s 2>&1"):format(NULL),
		"cd ..",
	}, " && "))
end

---@param dir string
---@param dirPaths string[]
---@param filePaths string[]
local function cleanProject(dir, dirPaths, filePaths)
	assert(dir:sub(1, 1) ~= "/", "don't pass paths starting at root")
	local commands = { ("cd %s"):format(dir) }
	for _, dirPath in ipairs(dirPaths) do
		assert(dirPath:sub(1, 1) ~= "/", "don't pass paths starting at root")
		table.insert(commands, RMDIR_CMD:format(dirPath))
	end
	for _, filePath in ipairs(filePaths) do
		assert(filePath:sub(1, 1) ~= "/", "don't pass paths starting at root")
		table.insert(commands, RM_CMD:format(filePath))
	end
	table.insert(commands, "cd ..")

	return os.execute(table.concat(commands, " && "))
end

---@param name string
---@param dir string
---@param handler fun(dir: string)
local function itProject(name, dir, handler)
	it(name, function()
		local cleanFiles = { ".luarc.json" }
		tryCopyLuarc(dir)
		if tryCopySettings(dir) then
			table.insert(cleanFiles, path(".vscode", "settings.json"))
		end
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, cleanFiles)
		end)
		handler(dir)
	end)
end

describe("#slow behavior", function()
	setup(function()
		assert(lfs.chdir(path("spec", "projects")))
	end)

	teardown(function()
		assert(lfs.chdir(path("..", "..")))
	end)

	itProject("works when there is only a rockspec", "rockspec-only", function(dir)
		assert.is_true(fileExists(path(dir, INSTALL_DIR)))
		assert.is_false(fileExists(path(dir, ".luarc.json")))
	end)

	itProject("works when there is a library included", "with-lib", function(dir)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "library")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			workspace = { library = { path(INSTALL_DIR, "library") } },
		}, luarc)
	end)

	itProject("works when there is a config included", "with-config", function(dir)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			example = true,
		}, luarc)
	end)

	itProject("works when there is a plugin included", "with-plugin", function(dir)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "plugin.lua")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			runtime = { plugin = path(INSTALL_DIR, "plugin.lua") },
		}, luarc)
	end)

	itProject("works when there is a library and config included", "with-lib-config", function(dir)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "library")))
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			workspace = { library = { path(INSTALL_DIR, "library") } },
			example = true,
		}, luarc)
	end)

	itProject("works when there is a library and plugin included", "with-lib-plugin", function(dir)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "library")))
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "plugin.lua")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			workspace = { library = { path(INSTALL_DIR, "library") } },
			runtime = { plugin = path(INSTALL_DIR, "plugin.lua") },
		}, luarc)
	end)

	itProject("works when there is a config and plugin included", "with-config-plugin", function(dir)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "plugin.lua")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			example = true,
			runtime = { plugin = path(INSTALL_DIR, "plugin.lua") },
		}, luarc)
	end)

	itProject("works when there is a library, config, and plugin included", "with-lib-config-plugin", function(dir)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "library")))
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "plugin.lua")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			workspace = { library = { path(INSTALL_DIR, "library") } },
			example = true,
			runtime = { plugin = path(INSTALL_DIR, "plugin.lua") },
		}, luarc)
	end)

	itProject("overwrites existing .luarc.json", "with-config-luarc", function(dir)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			completion = {
				autoRequire = false,
				requireSeparator = "/",
			},
			["hover.enable"] = false,
		}, luarc)
	end)

	itProject("overwrites existing .vscode/settings.json", "with-config-vsc-settings", function(dir)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		assert.is_false(fileExists(path(dir, ".luarc.json")))
		local settings = readJsonFile(path(dir, ".vscode", "settings.json"))
		assert.are_same({
			["Lua.completion.autoRequire"] = false,
			["Lua.hover.enable"] = false,
		}, settings)
	end)

	itProject("overwrites .luarc.json and not .vscode/settings.json when former exists", "with-config-luarc-vsc-settings", function(dir)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			completion = { autoRequire = false },
			["hover.enable"] = false,
		}, luarc)
		local settings = readJsonFile(path(dir, ".vscode", "settings.json"))
		assert.are_same({
			["Lua.completion.autoRequire"] = true,
			["Lua.hover.enable"] = true,
		}, settings)
	end)

	itProject("works when there is rockspec.build.settings", "with-rockspec-settings", function(dir)
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			hover = { enable = true },
		}, luarc)
	end)

	itProject("overwrites .luarc.json from rockspec.build.settings", "with-rockspec-settings-luarc", function(dir)
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			completion = {
				autoRequire = true,
				requireSeparator = "/",
			},
			["hover.enable"] = false,
		}, luarc)
	end)
end)
