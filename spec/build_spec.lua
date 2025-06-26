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

---@return boolean
local function tryCopyLuarc()
	local baseLuarc = io.open("base.luarc.json", "r")
	if not baseLuarc then
		return false
	end

	local contents = assert(baseLuarc:read("a"))
	assert(baseLuarc:close())
	local luarc = assert(io.open(".luarc.json", "w")) --[[@as file*]]
	assert(luarc:write(contents))
	assert(luarc:close())
	return true
end

---@return boolean
local function tryCopySettings()
	local baseSettings = io.open(path(".vscode", "base.settings.json"), "r")
	if not baseSettings then
		return false
	end

	local contents = assert(baseSettings:read("a"))
	assert(baseSettings:close())
	local settings = assert(io.open(path(".vscode", "settings.json"), "w")) --[[@as file*]]
	assert(settings:write(contents))
	assert(settings:close())
	return true
end

local function makeProject()
	return os.execute(table.concat({
		("luarocks init --no-wrapper-scripts --no-gitignore > %s"):format(NULL),
		("luarocks make > %s 2>&1"):format(NULL),
	}, " && "))
end

---@param dirPaths string[]
---@param filePaths string[]
local function cleanProject(dirPaths, filePaths)
	local commands = {}
	for _, dirPath in ipairs(dirPaths) do
		assert(dirPath:sub(1, 1) ~= "/", "don't pass paths starting at root")
		table.insert(commands, RMDIR_CMD:format(dirPath))
	end
	for _, filePath in ipairs(filePaths) do
		assert(filePath:sub(1, 1) ~= "/", "don't pass paths starting at root")
		table.insert(commands, RM_CMD:format(filePath))
	end

	return os.execute(table.concat(commands, " && "))
end

---@param dir string
---@param handler fun(finally: fun())
local function withProject(dir, handler)
	assert(dir:sub(1, 1) ~= "/", "don't pass paths starting at root")
	return function()
		local cleanupAll = {} ---@type (fun())[]
		---@param fun fun()
		local function newFinally(fun)
			table.insert(cleanupAll, fun)
		end
		finally(function()
			for i = #cleanupAll, 1, -1 do
				cleanupAll[i]()
			end
		end)
		local cd = assert(lfs.currentdir())
		assert(lfs.chdir(dir))
		newFinally(function()
			assert(lfs.chdir(cd))
		end)
		tryCopyLuarc()
		tryCopySettings()
		assert(makeProject())
		newFinally(function()
			assert(cleanProject({ ".luarocks", "lua_modules" }, { ".luarc.json", path(".vscode", "settings.json") }))
		end)
		handler(newFinally)
	end
end

describe("#slow behavior", function()
	setup(function()
		assert(lfs.chdir(path("spec", "projects")))
	end)

	teardown(function()
		assert(lfs.chdir(path("..", "..")))
	end)

	it(
		"works when there is only a rockspec",
		withProject("rockspec-only", function()
			assert.is_true(fileExists(INSTALL_DIR))
			assert.is_false(fileExists(".luarc.json"))
		end)
	)

	it(
		"works when there is a library included",
		withProject("with-lib", function()
			assert.is_true(fileExists(path(INSTALL_DIR, "library")))
			local luarc = readJsonFile(".luarc.json")
			assert.are_same({
				workspace = { library = { path(INSTALL_DIR, "library") } },
			}, luarc)
		end)
	)

	it(
		"works when there is a config included",
		withProject("with-config", function()
			assert.is_true(fileExists(path(INSTALL_DIR, "config.json")))
			local luarc = readJsonFile(".luarc.json")
			assert.are_same({
				example = true,
			}, luarc)
		end)
	)

	it(
		"works when there is a plugin included",
		withProject("with-plugin", function()
			assert.is_true(fileExists(path(INSTALL_DIR, "plugin.lua")))
			local luarc = readJsonFile(".luarc.json")
			assert.are_same({
				runtime = { plugin = path(INSTALL_DIR, "plugin.lua") },
			}, luarc)
		end)
	)

	it(
		"works when there is a library and config included",
		withProject("with-lib-config", function()
			assert.is_true(fileExists(path(INSTALL_DIR, "library")))
			assert.is_true(fileExists(path(INSTALL_DIR, "config.json")))
			local luarc = readJsonFile(".luarc.json")
			assert.are_same({
				workspace = { library = { path(INSTALL_DIR, "library") } },
				example = true,
			}, luarc)
		end)
	)

	it(
		"works when there is a library and plugin included",
		withProject("with-lib-plugin", function()
			assert.is_true(fileExists(path(INSTALL_DIR, "library")))
			assert.is_true(fileExists(path(INSTALL_DIR, "plugin.lua")))
			local luarc = readJsonFile(".luarc.json")
			assert.are_same({
				workspace = { library = { path(INSTALL_DIR, "library") } },
				runtime = { plugin = path(INSTALL_DIR, "plugin.lua") },
			}, luarc)
		end)
	)

	it(
		"works when there is a config and plugin included",
		withProject("with-config-plugin", function()
			assert.is_true(fileExists(path(INSTALL_DIR, "config.json")))
			assert.is_true(fileExists(path(INSTALL_DIR, "plugin.lua")))
			local luarc = readJsonFile(".luarc.json")
			assert.are_same({
				example = true,
				runtime = { plugin = path(INSTALL_DIR, "plugin.lua") },
			}, luarc)
		end)
	)

	it(
		"works when there is a library, config, and plugin included",
		withProject("with-lib-config-plugin", function()
			assert.is_true(fileExists(path(INSTALL_DIR, "library")))
			assert.is_true(fileExists(path(INSTALL_DIR, "config.json")))
			assert.is_true(fileExists(path(INSTALL_DIR, "plugin.lua")))
			local luarc = readJsonFile(".luarc.json")
			assert.are_same({
				workspace = { library = { path(INSTALL_DIR, "library") } },
				example = true,
				runtime = { plugin = path(INSTALL_DIR, "plugin.lua") },
			}, luarc)
		end)
	)

	it(
		"overwrites existing .luarc.json",
		withProject("with-config-luarc", function()
			assert.is_true(fileExists(path(INSTALL_DIR, "config.json")))
			local luarc = readJsonFile(".luarc.json")
			assert.are_same({
				completion = {
					autoRequire = false,
					requireSeparator = "/",
				},
				["hover.enable"] = false,
			}, luarc)
		end)
	)

	it(
		"overwrites existing .vscode/settings.json",
		withProject("with-config-vsc-settings", function()
			assert.is_true(fileExists(path(INSTALL_DIR, "config.json")))
			assert.is_false(fileExists(".luarc.json"))
			local settings = readJsonFile(path(".vscode", "settings.json"))
			assert.are_same({
				["Lua.completion.autoRequire"] = false,
				["Lua.hover.enable"] = false,
			}, settings)
		end)
	)

	it(
		"overwrites .luarc.json and not .vscode/settings.json when former exists",
		withProject("with-config-luarc-vsc-settings", function()
			assert.is_true(fileExists(path(INSTALL_DIR, "config.json")))
			local luarc = readJsonFile(".luarc.json")
			assert.are_same({
				completion = { autoRequire = false },
				["hover.enable"] = false,
			}, luarc)
			local settings = readJsonFile(path(".vscode", "settings.json"))
			assert.are_same({
				["Lua.completion.autoRequire"] = true,
				["Lua.hover.enable"] = true,
			}, settings)
		end)
	)

	it(
		"works when there is rockspec.build.settings",
		withProject("with-rockspec-settings", function()
			local luarc = readJsonFile(".luarc.json")
			assert.are_same({
				hover = { enable = true },
			}, luarc)
		end)
	)

	it(
		"overwrites .luarc.json from rockspec.build.settings",
		withProject("with-rockspec-settings-luarc", function()
			local luarc = readJsonFile(".luarc.json")
			assert.are_same({
				completion = {
					autoRequire = true,
					requireSeparator = "/",
				},
				["hover.enable"] = false,
			}, luarc)
		end)
	)
end)
