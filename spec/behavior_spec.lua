local lfs = require("lfs") ---@type LuaFileSystem

local luarocks = {
	---@type luarocks.core.cfg
	cfg = require("luarocks.core.cfg") --[[@as luarocks.core.cfg]],
	fs = require("luarocks.fs") --[[@as luarocks.fs]],
	path = require("luarocks.path") --[[@as luarocks.path]],
	util = require("luarocks.util"),
	cmd = {
		init = require("luarocks.cmd.init"),
		make = require("luarocks.cmd.make"),
	},
}

require("luarocks.cmd.install") -- sets deps.installer
local json = require("luarocks.build.lls-addon.json-util")
local llsAddon = require("luarocks.build.lls-addon")
local log = require("luarocks.build.lls-addon.log")

local upgradeFinally = require("spec.util.upgrade-finally")

local TARGET_VERSION = "5.4"
assert(_VERSION == "Lua " .. TARGET_VERSION, "version is not Lua " .. TARGET_VERSION)

local SEP = package.config:sub(1, 1)
---@param ... string
---@return string
local function path(...)
	local parts = { ... }
	local removeCount = 0
	for i = #parts, 1, -1 do
		local s = parts[i]
		if s == "" or s == "." then
			table.remove(parts, i)
		elseif s == ".." then
			table.remove(parts, i)
			removeCount = removeCount + 1
		elseif removeCount > 0 then
			table.remove(parts, i)
			removeCount = removeCount - 1
		end
	end

	for _ = 1, removeCount do
		table.insert(parts, 1, "..")
	end

	return table.concat(parts, SEP)
end

---@type "lua_modules/lib/luarocks/rocks-5.4/types/0.1-1"
local INSTALL_DIR = path("lua_modules", "lib", "luarocks", "rocks-" .. TARGET_VERSION, "types", "0.1-1")
local LUA_DIR = path("lua_modules", "share", "lua", TARGET_VERSION) ---@type "lua_modules/share/lua/5.4"

---@param path string
---@return string? mode
local function mode(path)
	return lfs.attributes(path, "mode") --[[@as string?]]
end

local function assertNoRoot(filePath)
	assert(filePath:sub(1, 1) ~= "/" and not filePath:match("^%a%:"), "don't pass paths starting at root")
end

local rmDir
do
	local function rmDirHelper(dirPath)
		for name in lfs.dir(dirPath) do
			if name ~= "." and name ~= ".." then
				local subPath = path(dirPath, name)
				local subPathMode = mode(subPath)
				if subPathMode == "file" then
					assert(os.remove(subPath))
				elseif subPathMode == "directory" then
					rmDirHelper(subPath)
				end
			end
		end
		assert(lfs.rmdir(dirPath))
	end

	---@param dirPath string
	function rmDir(dirPath)
		assertNoRoot(dirPath)
		rmDirHelper(dirPath)
	end
end

---@param dirPath string
local function tryRmDir(dirPath)
	if mode(dirPath) == "directory" then
		rmDir(dirPath)
	end
end

---@param filePath string
local function rmFile(filePath)
	assertNoRoot(filePath)
	assert(os.remove(filePath))
end

---@param filePath string
local function tryRmFile(filePath)
	if mode(filePath) == "file" then
		rmFile(filePath)
	end
end

---@param projectDir? string
---@return boolean
local function tryCopyLuarc(projectDir)
	local prefix = projectDir or ""
	local baseLuarc = io.open(path(prefix, "base.luarc.json"), "r")
	if not baseLuarc then
		return false
	end

	local contents = assert(baseLuarc:read("a"))
	assert(baseLuarc:close())
	local luarc = assert(io.open(path(prefix, ".luarc.json"), "w")) --[[@as file*]]
	assert(luarc:write(contents))
	assert(luarc:close())
	return true
end

---@param projectDir? string
---@return boolean
local function tryCopySettings(projectDir)
	local prefix = projectDir or ""
	local baseSettings = io.open(path(prefix, ".vscode", "base.settings.json"), "r")
	if not baseSettings then
		return false
	end

	local contents = assert(baseSettings:read("a"))
	assert(baseSettings:close())
	local settings = assert(io.open(path(prefix, ".vscode", "settings.json"), "w")) --[[@as file*]]
	assert(settings:write(contents))
	finally(function()
		rmFile(path(prefix, ".vscode", "settings.json"))
	end)
	assert(settings:close())
	return true
end

---@class lls-addon.spec.makeProject.options
---@field noInstall? boolean
---@field projectDir? string
---@field rockspec? string

---@param dirPath string
local function pushDir(dirPath)
	local cd = lfs.currentdir()
	assert(lfs.chdir(dirPath))
	finally(function()
		assert(lfs.chdir(cd))
	end)
end

---@type "path/to/lls-addon-loader.lua"
local FAKE_LOADER_SOURCE = path("path", "to", "lls-addon-loader.lua")

---@param options? lls-addon.spec.makeProject.options
local function makeProject(options)
	options = options or {}
	local cd = lfs.currentdir()
	tryCopyLuarc(options.projectDir)
	tryCopySettings(options.projectDir)
	local lock = assert(lfs.lock_dir(cd))
	finally(function()
		lock:free()
	end)
	stub(luarocks.util, "printout")
	stub(luarocks.util, "warning")
	stub(luarocks.util, "printerr")
	stub(llsAddon, "getLoaderSource", FAKE_LOADER_SOURCE)
	local logMock = mock(log, --[[stub:]] true)

	local oldProjectDir = luarocks.cfg.project_dir
	local newProjectDir = oldProjectDir or cd
	if options.projectDir then
		newProjectDir = path(cd, options.projectDir)
		luarocks.cfg.project_dir = newProjectDir

		lfs.chdir(options.projectDir)
		assert(luarocks.cmd.init.command({ no_wrapper_scripts = true, no_gitignore = true }))
		luarocks.path.use_tree(path(newProjectDir, "lua_modules"))
		finally(function()
			local cd = lfs.currentdir()
			lfs.chdir(newProjectDir)
			rmDir(".luarocks")
			rmDir("lua_modules")
			tryRmFile(".luarc.json")
			lfs.chdir(cd)
		end)
		lfs.chdir(cd)
	else
		assert(luarocks.cmd.init.command({ no_wrapper_scripts = true, no_gitignore = true }))
		luarocks.path.use_tree(path(cd, "lua_modules"))
		finally(function()
			rmDir(".luarocks")
			rmDir("lua_modules")
			tryRmFile(".luarc.json")
		end)
	end
	assert(luarocks.cmd.make.command({ no_install = options.noInstall, rockspec = options.rockspec }))
	luarocks.cfg.project_dir = oldProjectDir
	mock.revert(logMock)
end

---@param dir string
---@param options? lls-addon.spec.makeProject.options
local function setupProject(dir, options)
	assertNoRoot(dir)
	finally = upgradeFinally(finally)
	pushDir(dir)
	makeProject(options)
end

describe("luarocks-build-lls-addon", function()
	do
		local cd
		lazy_setup(function()
			luarocks.cfg.init()
			luarocks.fs.init()
			cd = lfs.currentdir()
			assert(lfs.chdir(path("spec", "projects")))
		end)

		lazy_teardown(function()
			assert(lfs.chdir(cd))
		end)
	end

	it("works when there is only a rockspec", function()
		setupProject("rockspec-only")
		assert.are_equal("directory", mode(INSTALL_DIR))
		assert.is_nil(mode(".luarc.json"))
	end)

	it("works when there is a library included", function()
		setupProject("with-lib")
		assert.are_equal("directory", mode(path(INSTALL_DIR, "library")))
		local luarc = json.read(".luarc.json")
		assert.are_same({
			workspace = { library = { path(INSTALL_DIR, "library") } },
		}, luarc)
	end)

	it("works when there is a config included", function()
		setupProject("with-config")
		assert.are_equal("file", mode(path(INSTALL_DIR, "config.json")))
		local luarc = json.read(".luarc.json")
		assert.are_same({ example = true }, luarc)
	end)

	it("works when there is a plugin included", function()
		setupProject("with-plugin")
		assert.are_equal("file", mode(path(INSTALL_DIR, "plugin.lua")))
		local luarc = json.read(".luarc.json")
		assert.are_same({
			runtime = {
				plugin = {
					FAKE_LOADER_SOURCE,
					path(INSTALL_DIR, "plugin.lua"),
				},
			},
		}, luarc)
	end)

	it("works when there is a library and config included", function()
		setupProject("with-lib-config")
		assert.are_equal("directory", mode(path(INSTALL_DIR, "library")))
		assert.are_equal("file", mode(path(INSTALL_DIR, "config.json")))
		local luarc = json.read(".luarc.json")
		assert.are_same({
			workspace = { library = { path(INSTALL_DIR, "library") } },
			example = true,
		}, luarc)
	end)

	it("works when there is a library and plugin included", function()
		setupProject("with-lib-plugin")
		assert.are_equal("directory", mode(path(INSTALL_DIR, "library")))
		assert.are_equal("file", mode(path(INSTALL_DIR, "plugin.lua")))
		local luarc = json.read(".luarc.json")
		assert.are_same({
			workspace = { library = { path(INSTALL_DIR, "library") } },
			runtime = {
				plugin = {
					FAKE_LOADER_SOURCE,
					path(INSTALL_DIR, "plugin.lua"),
				},
			},
		}, luarc)
	end)

	it("works when there is a config and plugin included", function()
		setupProject("with-config-plugin")
		assert.are_equal("file", mode(path(INSTALL_DIR, "config.json")))
		assert.are_equal("file", mode(path(INSTALL_DIR, "plugin.lua")))
		local luarc = json.read(".luarc.json")
		assert.are_same({
			example = true,
			runtime = {
				plugin = {
					FAKE_LOADER_SOURCE,
					path(INSTALL_DIR, "plugin.lua"),
				},
			},
		}, luarc)
	end)

	it("works when there is a multi-file plugin included", function()
		setupProject("with-multi-file-plugin")
		assert.are_equal("file", mode(path(INSTALL_DIR, "plugin.lua")))
		assert.are_equal("directory", mode(path(INSTALL_DIR, "plugin")))
		assert.are_equal("file", mode(path(INSTALL_DIR, "plugin", "submodule.lua")))
		local luarc = json.read(".luarc.json")
		assert.are_same({
			runtime = {
				plugin = {
					FAKE_LOADER_SOURCE,
					path(INSTALL_DIR, "plugin.lua"),
				},
			},
		}, luarc)
	end)

	it("works when there is a library, config, and plugin included", function()
		setupProject("with-lib-config-plugin")
		assert.are_equal("directory", mode(path(INSTALL_DIR, "library")))
		assert.are_equal("file", mode(path(INSTALL_DIR, "config.json")))
		assert.are_equal("file", mode(path(INSTALL_DIR, "plugin.lua")))
		local luarc = json.read(".luarc.json")
		assert.are_same({
			workspace = { library = { path(INSTALL_DIR, "library") } },
			example = true,
			runtime = {
				plugin = {
					FAKE_LOADER_SOURCE,
					path(INSTALL_DIR, "plugin.lua"),
				},
			},
		}, luarc)
	end)

	it("overwrites existing .luarc.json", function()
		setupProject("with-config-luarc")
		assert.are_equal("file", mode(path(INSTALL_DIR, "config.json")))
		local luarc = json.read(".luarc.json")
		assert.are_same({
			completion = {
				autoRequire = false,
				requireSeparator = "/",
			},
			["hover.enable"] = false,
		}, luarc)
	end)

	it("overwrites existing .vscode/settings.json", function()
		setupProject("with-config-vsc-settings")
		assert.are_equal("file", mode(path(INSTALL_DIR, "config.json")))
		assert.is_nil(mode(".luarc.json"))
		local settings = json.read(path(".vscode", "settings.json"))
		assert.are_same({
			["Lua.completion.autoRequire"] = false,
			["Lua.hover.enable"] = false,
		}, settings)
	end)

	it("overwrites .luarc.json and not .vscode/settings.json when former exists", function()
		setupProject("with-config-luarc-vsc-settings")
		assert.are_equal("file", mode(path(INSTALL_DIR, "config.json")))
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

	it("works when there is rockspec.build.settings", function()
		setupProject("with-rockspec-settings")
		local luarc = json.read(".luarc.json")
		assert.are_same({
			hover = { enable = true },
		}, luarc)
	end)

	it("overwrites .luarc.json from rockspec.build.settings", function()
		setupProject("with-rockspec-settings-luarc")
		local luarc = json.read(".luarc.json")
		assert.are_same({
			completion = {
				autoRequire = true,
				requireSeparator = "/",
			},
			["hover.enable"] = false,
		}, luarc)
	end)

	it("can install files from a different project directory", function()
		setupProject(path("install-from-different-dir", "different-dir"), { projectDir = path("..", "project-dir") })
		pushDir(path("..", "project-dir"))
		local cd = lfs.currentdir()
		assert.are_equal("directory", mode(path(INSTALL_DIR, "library")))
		assert.is_nil(mode(path(INSTALL_DIR, "config.json")))
		assert.are_equal("file", mode(path(INSTALL_DIR, "plugin.lua")))
		local luarc = json.read(".luarc.json")
		assert.are_same({
			hover = { enable = true },
			workspace = { library = { path(cd, INSTALL_DIR, "library") } },
			runtime = {
				plugin = {
					FAKE_LOADER_SOURCE,
					path(cd, INSTALL_DIR, "plugin.lua"),
				},
			},
		}, luarc)
	end)

	it("errors when given a bad luarc", function()
		assert.error(function()
			setupProject("with-rockspec-settings-bad-luarc")
			finally(function()
				rmFile(".luarc.json")
			end)
		end)
	end)

	it("doesn't install when given --no-install", function()
		setupProject("no-install", { noInstall = true })

		assert.is_nil(mode(path(INSTALL_DIR, "library")))
		assert.is_nil(mode(".luarc.json"))
		assert.is_nil(mode(path(INSTALL_DIR, "config.json")))
		assert.is_nil(mode(path(LUA_DIR, "types.lua")))
	end)

	it("installs to unique paths", function()
		finally = upgradeFinally(finally)
		pushDir("no-install")
		luarocks.cfg.variables.LLSADDON_LUARCPATH = "some/path/luarc-settings.json;another/path/luarc-settings.json"
		luarocks.cfg.variables.LLSADDON_VSCSETTINGSPATH =
			"some/path/vscode-settings.json;another/path/vscode-settings.json"
		finally(function()
			luarocks.cfg.variables.LLSADDON_LUARCPATH = nil
			luarocks.cfg.variables.LLSADDON_VSCSETTINGSPATH = nil
		end)
		makeProject()
		finally(function()
			rmDir("some")
			rmDir("another")
		end)
		assert.are_equal("file", mode(path("some", "path", "luarc-settings.json")))
		assert.are_equal("file", mode(path("another", "path", "luarc-settings.json")))
		assert.are_equal("file", mode(path("some", "path", "vscode-settings.json")))
		assert.are_equal("file", mode(path("another", "path", "vscode-settings.json")))
	end)
end)
