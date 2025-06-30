---@diagnostic disable-next-line: unknown-cast-variable
---@cast assert luassert

local fs = require("luarocks.fs")
local rockspecs = require("luarocks.rockspecs")
local cfg = require("luarocks.core.cfg")

local SEP = package.config:sub(1, 1)
local function path(...)
	return table.concat({ ... }, SEP)
end

local log = require("luarocks.build.lls-addon.log")
local llsAddon = require("luarocks.build.lls-addon")
local jsonUtil = require("luarocks.build.lls-addon.json-util")

---@return luarocks.rockspec
local function makeRockspec()
	local rockspec, msg = rockspecs.from_persisted_table("types-0.1-1.rockspec", {
		rockspec_format = "3.1",
		package = "test",
		version = "0.1-1",
		source = { url = "" },
		build = { type = "lls-addon" },
	}, --[[globals:]] {}, --[[quick:]] true)
	---@diagnostic disable-next-line: redundant-parameter
	assert.is_truthy(rockspec, msg)
	return rockspec --[[@as luarocks.rockspec]]
end

---@param t any
---@param newT any
---@return { [string]: luassert.spy }
local function stubAll(t, newT)
	for k, v in pairs(newT) do
		stub(t, k, v)
	end
	return t
end

describe("#only lls-addon", function()
	lazy_setup(function()
		cfg.init()
		fs.init()
	end)

	describe("compileLuarc", function()
		local compileLuarc = llsAddon.compileLuarc

		it("creates no luarc when nothing is added", function()
			mock(log, --[[stub:]] true)
			local installDir = path("E:", "path", "to", "rock")
			local currentDir = path("E:", "path", "to", "types")
			local stubFs = stubAll(fs, {
				-- key = handler / return value
				copy = true,
				copy_contents = true,
				make_dir = true,
				current_dir = currentDir,
				exists = false,
			})

			local luarc = compileLuarc(installDir, nil)
			assert.is_nil(luarc)
			assert.stub(stubFs.copy).was.called(0)
			assert.stub(stubFs.copy_contents).was.called(0)
			assert.stub(stubFs.exists).was.called_with(path(currentDir, "library"))
			assert.stub(stubFs.exists).was.called_with(path(currentDir, "plugin.lua"))
			assert.stub(stubFs.exists).was.called_with(path(currentDir, "config.json"))
		end)

		it("works when given a library", function()
			mock(log, --[[stubbing:]] true)
			local installDir = path("E:", "path", "to", "rock")
			local currentDir = path("E:", "path", "to", "types")

			local stubFs = stubAll(fs, {
				-- key = handler / return value
				copy = true,
				copy_contents = true,
				make_dir = true,
				current_dir = currentDir,
				exists = function(pathArg)
					return pathArg == path(currentDir, "library")
				end,
			})

			local luarc = compileLuarc(installDir, nil)
			assert.are_same({ ["workspace.library"] = { path(installDir, "library") } }, luarc)
			assert.stub(stubFs.make_dir).was.called(1)
			assert.stub(stubFs.make_dir).was.called_with(path(installDir, "library"))
			assert.stub(stubFs.copy_contents).was.called(1)
			assert.stub(stubFs.copy_contents).was.called_with(path(currentDir, "library"), path(installDir, "library"))
			assert.stub(stubFs.copy).was.called(0)
		end)

		it("works when given a plugin", function()
			mock(log, --[[stubbing:]] true)
			local installDir = path("E:", "path", "to", "rock")
			local currentDir = path("E:", "path", "to", "types")

			local stubFs = stubAll(fs, {
				-- key = handler / return value
				copy = true,
				copy_contents = true,
				make_dir = true,
				current_dir = currentDir,
				exists = function(pathArg)
					return pathArg == path(currentDir, "plugin.lua")
				end,
			})

			local luarc = compileLuarc(installDir, nil)
			assert.are_same({ ["runtime.plugin"] = path(installDir, "plugin.lua") }, luarc)
			assert.stub(stubFs.copy).was.called(1)
			assert.stub(stubFs.copy).was.called_with(path(currentDir, "plugin.lua"), path(installDir, "plugin.lua"))
		end)

		it("works when given rockspec settings", function()
			mock(log, --[[stubbing:]] true)
			local installDir = path("E:", "path", "to", "rock")
			local currentDir = path("E:", "path", "to", "types")

			stubAll(fs, {
				-- key = handler / return value
				copy = true,
				copy_contents = true,
				make_dir = true,
				current_dir = currentDir,
				exists = false,
			})

			local luarc = compileLuarc(installDir, --[[rockspecSettings:]] {
				["some.example"] = 42,
				another = {
					example = 100,
				},
			})
			assert.are_same({ ["some.example"] = 42, ["another.example"] = 100 }, luarc)
		end)

		pending("works when given a config.json", function()
			mock(log, --[[stubbing:]] true)
			local installDir = path("E:", "path", "to", "rock")
			local currentDir = path("E:", "path", "to", "types")

			stubAll(fs, {
				-- key = handler / return value
				copy = true,
				copy_contents = true,
				make_dir = true,
				current_dir = currentDir,
				exists = function(pathArg)
					return pathArg == path(currentDir, "config.json")
				end,
			})
			stub(jsonUtil, "readJsonFile", function(pathArg)
				assert.are_equal(path(currentDir, "config.json"), pathArg)
				return {
					["Lua.some.example"] = 42,
					["Lua.another.example"] = 100,
				}
			end)

			local luarc = compileLuarc(installDir, nil)
			assert.are_same({ ["some.example"] = 42, ["another.example"] = 100 }, luarc)
		end)
	end)
end)
