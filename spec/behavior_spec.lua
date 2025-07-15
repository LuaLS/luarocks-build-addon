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

local INSTALL_DIR = path("lua_modules", "lib", "luarocks", "rocks-5.4", "types", "0.1-1")

---@param path string
---@return string? mode
local function mode(path)
	return lfs.attributes(path, "mode") --[[@as string?]]
end

local rmDir
do
	local function rmDirHelper(dirPath)
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

	---@param dirPath string
	function rmDir(dirPath)
		assert(dirPath:sub(1, 1) ~= "/", "don't pass paths starting at root")
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
	assert(filePath:sub(1, 1) ~= "/", "don't pass paths starting at root")
	assert(os.remove(filePath))
end

---@param filePath string
local function tryRmFile(filePath)
	if mode(filePath) == "file" then
		rmFile(filePath)
	end
end

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
	finally(function()
		rmFile(path(".vscode", "settings.json"))
	end)
	assert(settings:close())
	return true
end

---@class lls-addon.spec.makeProject.options
---@field noInstall? boolean

---@param options? lls-addon.spec.makeProject.options
local function makeProject(options)
	options = options or {}
	tryCopyLuarc()
	tryCopySettings()
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
	luarocks.cfg.no_install = options.noInstall
	finally(function()
		rmDir(".luarocks")
		rmDir("lua_modules")
		tryRmFile(".luarc.json")
	end)
	assert(luarocks.cmd.make.command({ no_install = options.noInstall }))
	mock.revert(logMock)
end

local function upgradeFinally()
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
end

local function pushDir(dirPath)
	local cd = assert(lfs.currentdir())
	assert(lfs.chdir(dirPath))
	finally(function()
		assert(lfs.chdir(cd))
	end)
end

---@param dir string
---@param handler fun()
local function withProject(dir, handler)
	assert(dir:sub(1, 1) ~= "/", "don't pass paths starting at root")
	return function()
		upgradeFinally()
		pushDir(dir)
		makeProject()
		handler()
	end
end

describe("behavior", function()
	do
		local cd
		lazy_setup(function()
			luarocks.cfg.init()
			luarocks.fs.init()
			cd = assert(lfs.currentdir())
			assert(lfs.chdir(path("spec", "projects")))
		end)

		lazy_teardown(function()
			assert(lfs.chdir(cd))
		end)
	end

	it(
		"works when there is only a rockspec",
		withProject("rockspec-only", function()
			assert.are_equal("directory", mode(INSTALL_DIR))
			assert.is_nil(mode(".luarc.json"))
		end)
	)

	it(
		"works when there is a library included",
		withProject("with-lib", function()
			assert.are_equal("directory", mode(path(INSTALL_DIR, "library")))
			local luarc = json.read(".luarc.json")
			assert.are_same({
				workspace = { library = { path(INSTALL_DIR, "library") } },
			}, luarc)
		end)
	)

	it(
		"works when there is a config included",
		withProject("with-config", function()
			assert.are_equal("file", mode(path(INSTALL_DIR, "config.json")))
			local luarc = json.read(".luarc.json")
			assert.are_same({ example = true }, luarc)
		end)
	)

	it(
		"works when there is a plugin included",
		withProject("with-plugin", function()
			assert.are_equal("file", mode(path(INSTALL_DIR, "plugin.lua")))
			local luarc = json.read(".luarc.json")
			assert.are_same({
				runtime = { plugin = path(INSTALL_DIR, "plugin.lua") },
			}, luarc)
		end)
	)

	it(
		"works when there is a library and config included",
		withProject("with-lib-config", function()
			assert.are_equal("directory", mode(path(INSTALL_DIR, "library")))
			assert.are_equal("file", mode(path(INSTALL_DIR, "config.json")))
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
			assert.are_equal("directory", mode(path(INSTALL_DIR, "library")))
			assert.are_equal("file", mode(path(INSTALL_DIR, "plugin.lua")))
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
			assert.are_equal("file", mode(path(INSTALL_DIR, "config.json")))
			assert.are_equal("file", mode(path(INSTALL_DIR, "plugin.lua")))
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
			assert.are_equal("directory", mode(path(INSTALL_DIR, "library")))
			assert.are_equal("file", mode(path(INSTALL_DIR, "config.json")))
			assert.are_equal("file", mode(path(INSTALL_DIR, "plugin.lua")))
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
	)

	it(
		"overwrites existing .vscode/settings.json",
		withProject("with-config-vsc-settings", function()
			assert.are_equal("file", mode(path(INSTALL_DIR, "config.json")))
			assert.is_nil(mode(".luarc.json"))
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

	it("errors when given a bad luarc", function()
		upgradeFinally()
		pushDir("with-rockspec-settings-bad-luarc")

		assert.error(function()
			makeProject()
			finally(function()
				rmFile(".luarc.json")
			end)
		end)
	end)

	it("doesn't install when given --no-install", function()
		upgradeFinally()
		pushDir("no-install")
		makeProject({ noInstall = true })
		assert.is_nil(mode(path(INSTALL_DIR, "library")))
		assert.is_nil(mode(".luarc.json"))
		assert.is_nil(mode(path(INSTALL_DIR, "config.json")))
		assert.is_nil(mode(path(INSTALL_DIR, "plugin.lua")))
	end)

	it("installs to unique paths", function()
		upgradeFinally()
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
			tryRmDir("some")
			tryRmDir("another")
		end)
		assert.are_equal("file", mode(path("some", "path", "luarc-settings.json")))
		assert.are_equal("file", mode(path("another", "path", "luarc-settings.json")))
		assert.are_equal("file", mode(path("some", "path", "vscode-settings.json")))
		assert.are_equal("file", mode(path("another", "path", "vscode-settings.json")))
	end)
end)
