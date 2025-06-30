---@diagnostic disable-next-line: unknown-cast-variable
---@cast assert luassert

local tableUtil = require("luarocks.build.lls-addon.table-util")
local extend = tableUtil.extend
local unnest2 = tableUtil.unnest2

local jsonUtil = require("luarocks.build.lls-addon.json-util")
local array = jsonUtil.array
local object = jsonUtil.object

describe("extend", function()
	describe("array", function()
		for _, nested in ipairs({ true, false }) do
			describe("prefers" .. (nested and "nested" or "unnested"), function()
				it("gets replaced if it doesn't have an arrayMt", function()
					local arr = { "some" }
					local new = array({ "new" })
					arr = extend(nested, arr, new)
					assert.are_equal(new, arr)
				end)

				it("inserts if an element doesn't exist", function()
					local arr = array({ "some" })
					arr = extend(nested, arr, array({ "new" }))
					assert.are_same({ "some", "new" }, arr)
				end)

				it("doesn't insert if it exists", function()
					local arr = array({ "some" })
					arr = extend(nested, arr, array({ "some" }))
					assert.are_same({ "some" }, arr)
				end)

				it("inserts multiple elements and filters out those that are equal", function()
					local arr = array({ "x", "y", "z" })
					arr = extend(nested, arr, array({ "v", "w", "x" }))
					assert.are_same({ "x", "y", "z", "v", "w" }, arr)
				end)

				it("checks for existence by deep equality", function()
					local arr = array({ array({ "some" }) })
					arr = extend(nested, arr, array({ array({ "some" }) }))
					assert.are_same({ { "some" } }, arr)
				end)
			end)
		end
	end)

	describe("object", function()
		for _, prefer in ipairs({ "nested", "unnested" }) do
			describe("prefers " .. prefer, function()
				local nested = prefer == "nested"
				it("gets replaced if it doesn't have an objectMt", function()
					local obj = { key = "some" }
					local new = object({ other = "new" })
					obj = extend(nested, obj, new)
					assert.are_equal(new, obj)
				end)

				it("writes all keys to the first argument", function()
					local obj = object({ key = "some", existing = true })
					local new = object({ key = "new", a = 1, b = 2, c = 3 })
					obj = extend(nested, obj, new)
					assert.are_same({ key = "new", a = 1, b = 2, c = 3, existing = true }, obj)
				end)

				it("fails to write unnested keys from nested keys", function()
					local obj = object({ ["some.key"] = "value" })
					local new = object({ some = object({ key = "new value" }) })
					obj = extend(nested, obj, new)
					assert.are_same({ ["some.key"] = "value", some = { key = "new value" } }, obj)
				end)

				it("writes unnested keys from nested keys that were unnested", function()
					local obj = object({ ["some.key"] = "value" })
					local new = object({ some = object({ key = "new value" }) })
					local unnested = unnest2(new)
					obj = extend(nested, obj, unnested)
					assert.are_same({ ["some.key"] = "new value" }, obj)
				end)

				it("writes both nested and unnested keys", function()
					local obj = object({
						completion = object({ autoRequire = "value 1" }),
						["hover.enable"] = "value 2",
					})
					local new = object({
						["completion.autoRequire"] = "new value 1",
						["hover.enable"] = "new value 2",
					})
					local unnested = unnest2(new)
					obj = extend(nested, obj, unnested)
					assert.are_same({
						completion = { autoRequire = "new value 1" },
						["hover.enable"] = "new value 2",
					}, obj)
				end)
			end)
		end

		describe("with nested keys", function()
			it("prefers to fill nested keys", function()
				local obj = object({})
				local new = object({ ["some.key"] = "new value" })
				obj = extend(true, obj, new)
				assert.are_same({ some = { key = "new value" } }, obj)
			end)

			it("writes to unnested keys if they exist", function()
				local obj = object({ ["other.key"] = "value" })
				local new = object({ ["other.key"] = "new value" })
				obj = extend(true, obj, new)
				assert.are_same({ ["other.key"] = "new value" }, obj)
			end)

			it("merges conflicting unnested keys if they are encountered", function()
				local obj = object({
					["other.key"] = object({ a = true }),
					other = object({ key = object({ b = true }) }),
				})
				local new = object({ ["other.key"] = object({ c = true }) })
				obj = extend(true, obj, new)
				assert.are_same({ other = { key = { a = true, b = true, c = true } } }, obj)
			end)
		end)

		describe("with unnested keys", function()
			it("prefers to fill unnested keys", function()
				local obj = object({})
				local new = object({ ["some.key"] = "new value" })
				obj = extend(false, obj, new)
				assert.are_same({ ["some.key"] = "new value" }, obj)
			end)

			it("writes to nested keys if they exist", function()
				local obj = object({ other = object({ key = "value" }) })
				local new = object({ ["other.key"] = "new value" })
				obj = extend(false, obj, new)
				assert.are_same({ other = { key = "new value" } }, obj)
			end)

			it("merges conflicting nested keys if they are encountered", function()
				local obj = object({
					["other.key"] = object({ a = true }),
					other = object({ key = object({ b = true }) }),
				})
				local new = object({ ["other.key"] = object({ c = true }) })
				obj = extend(false, obj, new)

				assert.are_same({ ["other.key"] = { a = true, b = true, c = true } }, obj)
			end)
		end)
	end)
end)
