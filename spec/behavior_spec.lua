local lfs = require("lfs") ---@type LuaFileSystem

local luarocks = {
	cfg = require("luarocks.core.cfg"),
	fs = require("luarocks.fs"),
	path = require("luarocks.path"),
	util = require("luarocks.util"),
	cmd = {
		init = require("luarocks.cmd.init"),
		make = require("luarocks.cmd.make"),
	},
}

local json = require("luarocks.build.lls-addon.json-util")
local log = require("luarocks.build.lls-addon.log")

assert(_VERSION == "Lua 5.4", "version is not Lua 5.4")

local SEP = package.config:sub(1, 1)
---@param ... string
---@return string
local function path(...)
	return table.concat({ ... }, SEP)
end

---@param path string
---@return boolean
local function fileExists(path)
	local attrs = lfs.attributes(path)
	return attrs ~= nil and attrs.mode == "file"
end

---@param path string
---@return boolean
local function folderExists(path)
	local attrs = lfs.attributes(path)
	return attrs ~= nil and attrs.mode == "directory"
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
	local lock = assert(luarocks.fs.lock_access(luarocks.fs.current_dir()))
	finally(function()
		luarocks.fs.unlock_access(lock)
	end)
	stub(luarocks.util, "printout")
	stub(luarocks.util, "warning")
	stub(luarocks.util, "printerr")
	local logMock = mock(log, --[[stub:]] true)

	assert(luarocks.cmd.init.command({ no_wrapper_scripts = true, no_gitignore = true }))
	luarocks.path.use_tree(path(luarocks.fs.current_dir(), "lua_modules"))
	assert(luarocks.cmd.make.command({}))
	mock.revert(logMock)
end

---@param dirPath string
local function rmDir(dirPath)
	for name in lfs.dir(dirPath) do
		if name ~= "." and name ~= ".." then
			local subPath = path(dirPath, name)
			local mode = lfs.attributes(subPath, "mode")
			if mode == "file" then
				assert(os.remove(subPath))
			elseif mode == "directory" then
				rmDir(subPath)
			end
		end
	end
	assert(lfs.rmdir(dirPath))
end

---@param dirPaths string[]
---@param filePaths string[]
local function cleanProject(dirPaths, filePaths)
	for _, dirPath in ipairs(dirPaths) do
		assert(dirPath:sub(1, 1) ~= "/", "don't pass paths starting at root")
		if folderExists(dirPath) then
			rmDir(dirPath)
		end
	end
	for _, filePath in ipairs(filePaths) do
		assert(filePath:sub(1, 1) ~= "/", "don't pass paths starting at root")
		if fileExists(filePath) then
			assert(os.remove(filePath))
		end
	end
end

---@param dir string
---@param handler fun(finally: fun(block: fun()))
local function withProject(dir, handler)
	assert(dir:sub(1, 1) ~= "/", "don't pass paths starting at root")
	return function()
		local cleanupAll = {} ---@type (fun())[]
		---@param fun fun()
		local function newFinally(fun)
			table.insert(cleanupAll, fun)
		end
		finally(function()
			local result = true
			local message = nil
			for i = #cleanupAll, 1, -1 do
				local s, msg = pcall(cleanupAll[i])
				result = result and s
				message = message or msg
			end

			assert(result, message)
		end)
		finally = newFinally
		local cd = assert(lfs.currentdir())
		assert(lfs.chdir(dir))
		finally(function()
			assert(lfs.chdir(cd))
		end)
		tryCopyLuarc()
		tryCopySettings()
		makeProject()
		finally(function()
			cleanProject({ ".luarocks", "lua_modules" }, { ".luarc.json", path(".vscode", "settings.json") })
		end)
		handler(newFinally)
	end
end

describe("behavior", function()
	local cd = assert(lfs.currentdir())
	lazy_setup(function()
		luarocks.cfg.init()
		luarocks.fs.init()
		assert(lfs.chdir(path("spec", "projects")))
	end)

	lazy_teardown(function()
		assert(lfs.chdir(cd))
	end)

	it(
		"works when there is only a rockspec",
		withProject("rockspec-only", function()
			assert.is_true(folderExists(INSTALL_DIR))
			assert.is_false(fileExists(".luarc.json"))
		end)
	)

	it(
		"works when there is a library included",
		withProject("with-lib", function()
			assert.is_true(folderExists(path(INSTALL_DIR, "library")))
			local luarc = json.read(".luarc.json")
			assert.are_same({
				workspace = { library = { path(INSTALL_DIR, "library") } },
			}, luarc)
		end)
	)

	it(
		"works when there is a config included",
		withProject("with-config", function()
			assert.is_true(fileExists(path(INSTALL_DIR, "config.json")))
			local luarc = json.read(".luarc.json")
			assert.are_same({
				example = true,
			}, luarc)
		end)
	)

	it(
		"works when there is a plugin included",
		withProject("with-plugin", function()
			assert.is_true(fileExists(path(INSTALL_DIR, "plugin.lua")))
			local luarc = json.read(".luarc.json")
			assert.are_same({
				runtime = { plugin = path(INSTALL_DIR, "plugin.lua") },
			}, luarc)
		end)
	)

	it(
		"works when there is a library and config included",
		withProject("with-lib-config", function()
			assert.is_true(folderExists(path(INSTALL_DIR, "library")))
			assert.is_true(fileExists(path(INSTALL_DIR, "config.json")))
			local luarc = json.read(".luarc.json")
			assert.are_same({
				workspace = { library = { path(INSTALL_DIR, "library") } },
				example = true,
			}, luarc)
		end)
	)

	it(
		"works when there is a library and plugin included",
		withProject("with-lib-plugin", function()
			assert.is_true(folderExists(path(INSTALL_DIR, "library")))
			assert.is_true(fileExists(path(INSTALL_DIR, "plugin.lua")))
			local luarc = json.read(".luarc.json")
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
			local luarc = json.read(".luarc.json")
			assert.are_same({
				example = true,
				runtime = { plugin = path(INSTALL_DIR, "plugin.lua") },
			}, luarc)
		end)
	)

	it(
		"works when there is a library, config, and plugin included",
		withProject("with-lib-config-plugin", function()
			assert.is_true(folderExists(path(INSTALL_DIR, "library")))
			assert.is_true(fileExists(path(INSTALL_DIR, "config.json")))
			assert.is_true(fileExists(path(INSTALL_DIR, "plugin.lua")))
			local luarc = json.read(".luarc.json")
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
			local luarc = json.read(".luarc.json")
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
			local settings = json.read(path(".vscode", "settings.json"))
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
			local luarc = json.read(".luarc.json")
			assert.are_same({
				completion = { autoRequire = false },
				["hover.enable"] = false,
			}, luarc)
			local settings = json.read(path(".vscode", "settings.json"))
			assert.are_same({
				["Lua.completion.autoRequire"] = true,
				["Lua.hover.enable"] = true,
			}, settings)
		end)
	)

	it(
		"works when there is rockspec.build.settings",
		withProject("with-rockspec-settings", function()
			local luarc = json.read(".luarc.json")
			assert.are_same({
				hover = { enable = true },
			}, luarc)
		end)
	)

	it(
		"overwrites .luarc.json from rockspec.build.settings",
		withProject("with-rockspec-settings-luarc", function()
			local luarc = json.read(".luarc.json")
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
