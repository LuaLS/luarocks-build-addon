---@diagnostic disable-next-line: unknown-cast-variable
---@cast assert luassert

_G._TEST = true
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
local function copyLuarc(dir)
	local baseLuarc = assert(io.open(path(dir, "base.luarc.json"), "r")) --[[@as file*]]
	local contents = baseLuarc:read("a")
	baseLuarc:close()
	local luarc = assert(io.open(path(dir, ".luarc.json"), "w")) --[[@as file*]]
	luarc:write(contents)
	luarc:close()
end

---@param dir string
local function copySettings(dir)
	local baseSettings = assert(io.open(path(dir, ".vscode", "base.settings.json"), "r")) --[[@as file*]]
	local contents = baseSettings:read("a")
	baseSettings:close()
	local settings = assert(io.open(path(dir, ".vscode", "settings.json"), "w")) --[[@as file*]]
	settings:write(contents)
	settings:close()
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

describe("#slow behavior", function()
	setup(function()
		assert(lfs.chdir(path("spec", "projects")))
	end)

	teardown(function()
		assert(lfs.chdir(path("..", "..")))
	end)

	it("works when there is only a rockspec", function()
		local dir = "rockspec-only"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, {})
		end)
		assert.is_true(fileExists(path(dir, INSTALL_DIR)))
		assert.is_false(fileExists(path(dir, ".luarc.json")))
	end)

	it("works when there is a library included", function()
		local dir = "with-lib"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "library")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({ path(INSTALL_DIR, "library") }, luarc["workspace.library"])
	end)

	it("works when there is a config included", function()
		local dir = "with-config"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.is_true(luarc["example"])
	end)

	it("works when there is a plugin included", function()
		local dir = "with-plugin"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "plugin.lua")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_equal(path(INSTALL_DIR, "plugin.lua"), luarc["runtime.plugin"])
	end)

	it("works when there is a library and config included", function()
		local dir = "with-lib-config"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "library")))
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({ path(INSTALL_DIR, "library") }, luarc["workspace.library"])
		assert.is_true(luarc["example"])
	end)

	it("works when there is a library and plugin included", function()
		local dir = "with-lib-plugin"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "library")))
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "plugin.lua")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({ path(INSTALL_DIR, "library") }, luarc["workspace.library"])
		assert.are_equal(path(INSTALL_DIR, "plugin.lua"), luarc["runtime.plugin"])
	end)

	it("works when there is a config and plugin included", function()
		local dir = "with-config-plugin"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "plugin.lua")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.is_true(luarc["example"])
		assert.are_equal(path(INSTALL_DIR, "plugin.lua"), luarc["runtime.plugin"])
	end)

	it("works when there is a library, config, and plugin included", function()
		local dir = "with-lib-config-plugin"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "library")))
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "plugin.lua")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({ path(INSTALL_DIR, "library") }, luarc["workspace.library"])
		assert.is_true(luarc["example"])
		assert.are_equal(path(INSTALL_DIR, "plugin.lua"), luarc["runtime.plugin"])
	end)

	it("overwrites existing .luarc.json", function()
		local dir = "with-config-and-existing-luarc"
		copyLuarc(dir)
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			completion = { autoRequire = false },
			["hover.enable"] = false,
		}, luarc)
	end)

	it("overwrites existing .vscode/settings.json", function()
		local dir = "with-config-and-existing-vsc-settings"
		copySettings(dir)
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { path(".vscode", "settings.json"), ".luarc.json" })
		end)
		assert.is_true(fileExists(path(dir, INSTALL_DIR, "config.json")))
		assert.is_false(fileExists(path(dir, ".luarc.json")))
		local settings = readJsonFile(path(dir, ".vscode", "settings.json"))
		assert.are_same({
			["Lua.completion.autoRequire"] = false,
			["Lua.hover.enable"] = false,
		}, settings)
	end)

	it("overwrites .luarc.json and not .vscode/settings.json when former exists", function()
		local dir = "with-config-and-existing-luarc-and-vsc-settings"
		copyLuarc(dir)
		copySettings(dir)
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { path(".vscode", "settings.json"), ".luarc.json" })
		end)
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

	it("works when there is rockspec.build.settings", function()
		local dir = "with-rockspec-settings"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			["hover.enable"] = true,
		}, luarc)
	end)
	it("works when there is rockspec.build.settings", function()
		local dir = "with-rockspec-settings"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_false(fileExists(path(dir, INSTALL_DIR, "config.json")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			["hover.enable"] = true,
		}, luarc)
	end)
end)
