local cfg = require("luarocks.core.cfg")
local fs = require("luarocks.fs")
local lfs = require("lfs") ---@type LuaFileSystem

local bundle = require("luarocks.build.lls-addon.bundle")
local log = require("luarocks.build.lls-addon.log")

local upgradeFinally = require("spec.util.upgrade-finally")

---@param path string
---@return string? mode
local function mode(path)
	return lfs.attributes(path, "mode") --[[@as string?]]
end

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

local expectedMany = [=[
package.preload["plugin.another"] = assert(load([[
return "another"

]], "plugin.another"))

package.preload["plugin.some"] = assert(load([[
return "some"

]], "plugin.some"))

local another = require("plugin.another")
local some = require("plugin.some")

return some .. " " .. another
]=]

describe("bundle", function()
	local logMock = mock(log, --[[doStubs:]] true)
	lazy_setup(function()
		cfg.init()
		fs.init()
		fs.change_dir(path("spec", "plugins"))
	end)

	lazy_teardown(function()
		mock.revert(logMock)
		fs.pop_dir()
	end)

	it("works with one plugin file", function()
		finally = upgradeFinally(finally)
		fs.change_dir("one")
		finally(function()
			fs.pop_dir()
		end)

		local destination = path("destination", "compiled.lua")
		bundle("plugin", destination)
		finally(function()
			os.remove(destination)
		end)

		assert.are_equal("file", mode(destination))
		assert.are_equal("-- does nothing\n", text(destination))
	end)

	it("works with several plugin files", function()
		finally = upgradeFinally(finally)
		fs.change_dir("many")
		finally(function()
			fs.pop_dir()
		end)

		local destination = path("destination", "compiled.lua")
		bundle("plugin", destination)
		finally(function()
			os.remove(destination)
		end)

		assert.are_equal("file", mode(destination))
		assert.are_equal(expectedMany, text(destination))
	end)
end)
