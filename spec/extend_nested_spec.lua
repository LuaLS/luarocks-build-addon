---@diagnostic disable-next-line: unknown-cast-variable
---@cast assert luassert

local tableUtil = require("luarocks.build.lls-addon.table-util")
local extendNested = tableUtil.extendNested
local nest2 = tableUtil.nest2

local jsonUtil = require("luarocks.build.lls-addon.json-util")
local array = jsonUtil.array
local object = jsonUtil.object

describe("array", function()
	it("gets replaced if it doesn't have an arrayMt", function()
		local arr = { "some" }
		local new = array({ "new" })
		arr = extendNested(arr, new)
		assert.are_equal(new, arr)
	end)

	it("inserts if an element doesn't exist", function()
		local arr = array({ "some" })
		arr = extendNested(arr, array({ "new" }))
		assert.are_same({ "some", "new" }, arr)
	end)

	it("doesn't insert if it exists", function()
		local arr = array({ "some" })
		arr = extendNested(arr, array({ "some" }))
		assert.are_same({ "some" }, arr)
	end)

	it("inserts multiple elements and filters out those that are equal", function()
		local arr = array({ "x", "y", "z" })
		arr = extendNested(arr, array({ "v", "w", "x" }))
		assert.are_same({ "x", "y", "z", "v", "w" }, arr)
	end)

	it("checks for existence by deep equality", function()
		local arr = array({ array({ "some" }) })
		arr = extendNested(arr, array({ array({ "some" }) }))
		assert.are_same({ { "some" } }, arr)
	end)
end)

describe("object", function()
	it("gets replaced if it doesn't have an objectMt", function()
		local obj = { key = "some" }
		local new = object({ other = "new" })
		obj = extendNested(obj, new)
		assert.are_equal(new, obj)
	end)

	it("writes all keys to the first argument", function()
		local obj = object({ key = "some" })
		local new = object({ key = "new", a = 1, b = 2, c = 3 })
		obj = extendNested(obj, new)
		assert.are_same({ key = "new", a = 1, b = 2, c = 3 }, obj)
	end)

	it("fills nested keys when given nested keys", function()
		local obj = object({})
		local new = object({ some = object({ key = "new value" }) })
		obj = extendNested(obj, new)
		assert.are_same({ some = { key = "new value" } }, obj)
	end)

	it("merges conflicting nested and unnested keys it writes to", function()
		local obj = object({
			other = object({ key = object({ some = true }) }),
			["other.key"] = object({ other = 42 }),
		})
		local new = object({
			other = object({ key = object({ another = 13 }) }),
		})
		obj = extendNested(obj, new)
		assert.are_same({
			other = {
				key = { some = true, other = 42, another = 13 },
			},
		}, obj)
	end)

	it("writes unnested keys from nested keys", function()
		local obj = object({ ["other.key"] = "value" })
		local new = object({ other = object({ key = "new value" }) })
		obj = extendNested(obj, new)
		assert.are_same({ ["other.key"] = "new value" }, obj)
	end)

	-- this test exists for documentation only, and is considered a bug!
	it("fails to write nested keys from unnested keys", function()
		local obj = object({ some = object({ key = "value" }) })
		local new = object({ ["some.key"] = "new value" })
		obj = extendNested(obj, new)
		assert.are_same({ ["some.key"] = "new value", some = { key = "value" } }, obj)
	end)

	it("writes nested keys from unnested keys that were nested", function()
		local obj = object({ some = object({ key = "value" }) })
		local new = object({ ["some.key"] = "new value" })
		local nested = nest2(new)
		obj = extendNested(obj, nested)
		assert.are_same({ some = { key = "new value" } }, obj)
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
		local nested = nest2(new)
		obj = extendNested(obj, nested)
		assert.are_same({
			completion = { autoRequire = "new value 1" },
			["hover.enable"] = "new value 2",
		}, obj)
	end)
end)
