local lfs = require("lfs")
local json = require("cjson")
-- local inspect = require("inspect")

local SEP = package.config:sub(1, 1)
local RMDIR_CMD = SEP == "\\" and "rmdir /S /Q %s" or "rmdir -rf %s"
local RM_CMD = SEP == "\\" and "del %s" or "rm %s"

lfs.chdir("spec")

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

---@param path string
---@return any
local function readJson(path)
	local file = assert(io.open(path))
	local contents = file:read("a")
	file:close()
	return json.decode(contents)
end

---@param dir string
---@param ... string
---@return string
local function installDir(dir, ...)
	return path(dir, "lua_modules", "lib", "luarocks", "rocks-5.4", dir, "0.1-1", ...)
end

local function makeProject(dir)
	return os.execute(table.concat({
		("pushd %s"):format(dir),
		"luarocks init --no-wrapper-scripts --no-gitignore",
		"luarocks make",
		"popd",
	}, " && "))
end

---@param dir string
---@param dirPaths string[]
---@param filePaths string[]
local function cleanProject(dir, dirPaths, filePaths)
	local commands = { ("pushd %s"):format(dir) }
	for _, path in ipairs(dirPaths) do
		table.insert(commands, RMDIR_CMD:format(path))
	end
	for _, path in ipairs(filePaths) do
		table.insert(commands, RM_CMD:format(path))
	end
	table.insert(commands, "popd")

	return os.execute(table.concat(commands, " && "))
end

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
	local luarc = readJson(path(dir, ".luarc.json"))
	assert.are_same({
		path(lfs.currentdir(), installDir(dir, "library")),
	}, luarc["workspace.library"])
end)

it("works when there is a plugin included", function()
	local dir = "with-plugin"
	assert.is_true(makeProject(dir))
	finally(function()
		cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
	end)
	assert.is_true(fileExists(installDir(dir, "plugin.lua")))
	local luarc = readJson(path(dir, ".luarc.json"))
	assert.are_equal(path(lfs.currentdir(), installDir(dir, "plugin.lua")), luarc["runtime.plugin"])
end)

it("works when there is a config included", function()
    local dir = "with-config"
    assert.is_true(makeProject(dir))
    finally(function()
		cleanProject(dir, { ".luarocks", "lua_modules" }, { ".luarc.json" })
	end)
    assert.is_true(fileExists(installDir(dir, "config.json")))
    local luarc = readJson(path(dir, ".luarc.json"))
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
	local luarc = readJson(path(dir, ".luarc.json"))
	assert.are_same({
		path(lfs.currentdir(), installDir(dir, "library")),
	}, luarc["workspace.library"])
	assert.are_equal(path(lfs.currentdir(), installDir(dir, "plugin.lua")), luarc["runtime.plugin"])
end)