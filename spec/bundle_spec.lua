local cfg = require("luarocks.core.cfg") ---@type luarocks.core.cfg
local fs = require("luarocks.fs")
local lfs = require("lfs") ---@type LuaFileSystem

local bundle = require("luarocks.build.lls-addon.bundle")
local log = require("luarocks.build.lls-addon.log")

local upgradeFinally = require("spec.util.upgrade-finally")

local function text(path)
	local file = assert(io.open(path, "r"))
	local result = assert(file:read("a"))
	assert(file:close())
	return result
end

local DIR_SEP = package.config:sub(1, 1)

---@param ... string | number
---@return string
local function path(...)
	return table.concat({ ... }, DIR_SEP)
end

---@param p string
---@return fun(): string
local function dir(p)
	local iterator = lfs.dir(p)
	return function()
		local result = iterator:next()
		while result == "." or result == ".." do
			result = iterator:next()
		end

		return result
	end
end

describe("bundle", function()
	do
		local logMock ---@type luassert.mockeds
		local cd ---@type string
		lazy_setup(function()
			logMock = mock(log, --[[doStubs:]] true)
			cd = lfs.currentdir()
			cfg.init()
			fs.init()
			assert(lfs.chdir(path("spec", "plugins")))
		end)

		lazy_teardown(function()
			mock.revert(logMock)
			assert(lfs.chdir(cd))
		end)
	end

	for case in dir(path("spec", "plugins")) do
		it("works with the plugin file at spec/plugins/" .. case .. "/", function()
			finally = upgradeFinally(finally)
			assert(fs.change_dir(case))
			finally(function()
				assert(fs.pop_dir())
			end)

			local destination = path("destination", "compiled.lua")
			bundle("plugin", destination)
			finally(function()
				os.remove(destination)
			end)

			assert.are_equal(text("expected.lua"), text(destination))
		end)
	end
end)
