---@diagnostic disable-next-line: unknown-cast-variable
---@cast assert luassert

_G._TEST = true
local lfs = require("lfs")

local jsonUtil = require("luarocks.build.lls-addon.json-util")
local readJsonFile = jsonUtil.readJsonFile

assert(_VERSION == "Lua 5.4", "version is not Lua 5.4")

local SEP = package.config:sub(1, 1)
local RMDIR_CMD = SEP == "\\" and "rmdir /S /Q %s" or "rm -rf %s"
local RM_CMD = SEP == "\\" and "del %s" or "rm %s"
local NULL = SEP == "\\" and "NUL" or "/dev/null"

---@param ... string
---@return string
local function path(...)
	return table.concat({ ... }, SEP)
end

---@param path string
---@return boolean
local function fileExists(path)
	return lfs.attributes(path) ~= nil
end

---@param dir string
---@param ... string
---@return string
local function installDir(dir, ...)
	return path(dir, "lua_modules", "lib", "luarocks", "rocks-5.4", dir, "0.1-1", ...)
end

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
		lfs.chdir(path("spec", "projects"))
	end)

	teardown(function()
		lfs.chdir(path("..", ".."))
	end)

	it("works when there is only a rockspec", function()
		local dir = "rockspec-only"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, {})
		end)
		assert.is_true(fileExists(installDir(dir)))
		assert.is_false(fileExists(path(dir, ".luarc.json")))
	end)

	it("works when there is a library included", function()
		local dir = "with-lib"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(installDir(dir, "library")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			path(lfs.currentdir(), installDir(dir, "library")),
		}, luarc["workspace.library"])
	end)

	it("works when there is a config included", function()
		local dir = "with-config"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(installDir(dir, "config.json")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.is_true(luarc["example"])
	end)

	it("works when there is a plugin included", function()
		local dir = "with-plugin"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(installDir(dir, "plugin.lua")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_equal(path(lfs.currentdir(), installDir(dir, "plugin.lua")), luarc["runtime.plugin"])
	end)

	it("works when there is a library and config included", function()
		local dir = "with-lib-config"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(installDir(dir, "library")))
		assert.is_true(fileExists(installDir(dir, "config.json")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			path(lfs.currentdir(), installDir(dir, "library")),
		}, luarc["workspace.library"])
		assert.is_true(luarc["example"])
	end)

	it("works when there is a library and plugin included", function()
		local dir = "with-lib-plugin"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(installDir(dir, "library")))
		assert.is_true(fileExists(installDir(dir, "plugin.lua")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			path(lfs.currentdir(), installDir(dir, "library")),
		}, luarc["workspace.library"])
		assert.are_equal(path(lfs.currentdir(), installDir(dir, "plugin.lua")), luarc["runtime.plugin"])
	end)

	it("works when there is a config and plugin included", function()
		local dir = "with-config-plugin"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(installDir(dir, "config.json")))
		assert.is_true(fileExists(installDir(dir, "plugin.lua")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.is_true(luarc["example"])
		assert.are_equal(path(lfs.currentdir(), installDir(dir, "plugin.lua")), luarc["runtime.plugin"])
	end)

	it("works when there is a library, config, and plugin included", function()
		local dir = "with-lib-config-plugin"
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(installDir(dir, "library")))
		assert.is_true(fileExists(installDir(dir, "config.json")))
		assert.is_true(fileExists(installDir(dir, "plugin.lua")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			path(lfs.currentdir(), installDir(dir, "library")),
		}, luarc["workspace.library"])
		assert.is_true(luarc["example"])
		assert.are_equal(path(lfs.currentdir(), installDir(dir, "plugin.lua")), luarc["runtime.plugin"])
	end)

	it("overwrites existing .luarc.json", function()
		local dir = "with-config-and-existing-luarc"
		copyLuarc(dir)
		assert.is_true(makeProject(dir))
		finally(function()
			cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
		end)
		assert.is_true(fileExists(installDir(dir, "config.json")))
		local luarc = readJsonFile(path(dir, ".luarc.json"))
		assert.are_same({
			completion = { autoRequire = false },
			["hover.enable"] = false,
		}, luarc)
		assert.are_equal(path(lfs.currentdir(), installDir(dir, "plugin.lua")), luarc["runtime.plugin"])
	end)
end)
