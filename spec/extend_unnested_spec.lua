---@diagnostic disable-next-line: unknown-cast-variable
---@cast assert luassert

_G._TEST = true

local tableUtil = require("luarocks.build.lls-addon.table-util")
local extendUnnested = tableUtil.extendUnnested
local unnest2 = tableUtil.unnest2

local jsonUtil = require("luarocks.build.lls-addon.json-util")
local array = jsonUtil.array
local object = jsonUtil.object

describe("array", function()
	it("gets replaced if it doesn't have an arrayMt", function()
		local arr = { "some" }
		local new = array({ "new" })
		arr = extendUnnested(arr, new)
		assert.are_equal(new, arr)
	end)

	it("inserts if an element doesn't exist", function()
		local arr = array({ "some" })
		arr = extendUnnested(arr, array({ "new" }))
		assert.are_same({ "some", "new" }, arr)
	end)

	it("doesn't insert if it exists", function()
		local arr = array({ "some" })
		arr = extendUnnested(arr, array({ "some" }))
		assert.are_same({ "some" }, arr)
	end)

	it("inserts multiple elements and filters out those that are equal", function()
		local arr = array({ "x", "y", "z" })
		arr = extendUnnested(arr, array({ "v", "w", "x" }))
		assert.are_same({ "x", "y", "z", "v", "w" }, arr)
	end)

	it("checks for existence by deep equality", function()
		local arr = array({ array({ "some" }) })
		arr = extendUnnested(arr, array({ array({ "some" }) }))
		assert.are_same({ { "some" } }, arr)
	end)
end)

describe("object", function()
	it("gets replaced if it doesn't have an objectMt", function()
		local obj = { key = "some" }
		local new = object({ other = "new" })
		obj = extendUnnested(obj, new)
		assert.are_equal(new, obj)
	end)

	it("writes all keys to the first argument", function()
		local obj = object({ key = "some" })
		local new = object({ key = "new", a = 1, b = 2, c = 3 })
		obj = extendUnnested(obj, new)
		assert.are_same({ key = "new", a = 1, b = 2, c = 3 }, obj)
	end)

	it("fills unnested keys", function()
		local obj = object({})
		local new = object({ ["some.key"] = "new value" })
		obj = extendUnnested(obj, new)
		assert.are_same({ ["some.key"] = "new value" }, obj)
	end)

	it("writes nested keys from unnested keys", function()
		local obj = object({ other = object({ key = "value" }) })
		local new = object({ ["other.key"] = "new value" })
		obj = extendUnnested(obj, new)
		assert.are_same({ other = { key = "new value" } }, obj)
	end)

	-- this test exists for documentation only, and is considered a bug!
	it("fails to write unnested keys from nested keys", function()
		local obj = object({ ["some.key"] = "value" })
		local new = object({ some = object({ key = "new value" }) })
		obj = extendUnnested(obj, new)
		assert.are_same({ ["some.key"] = "value", some = { key = "new value" } }, obj)
	end)

	it("writes unnested keys from nested keys that were unnested", function()
		local obj = object({ ["some.key"] = "value" })
		local new = object({ some = object({ key = "new value" }) })
		local unnested = unnest2(new)
		obj = extendUnnested(obj, unnested)
		assert.are_same({ ["some.key"] = "new value" }, obj)
	end)

	it("writes both nested and unnested keys", function()
		local obj = object({
			completion = object({ autoRequire = "value 1" }),
			["hover.enable"] = "value 2",
		})
		local new = object({
			["completion.autoRequire"] = "new value 1",
			hover = object({ enable = "new value 2" }),
		})
		local unnested = unnest2(new)
		obj = extendUnnested(obj, unnested)
		assert.are_same({
			completion = { autoRequire = "new value 1" },
			["hover.enable"] = "new value 2",
		}, obj)
	end)
end)
