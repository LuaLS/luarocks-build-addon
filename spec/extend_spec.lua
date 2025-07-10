local json = require("luarocks.build.lls-addon.json-util")
local tableUtil = require("luarocks.build.lls-addon.table-util")

local extend = tableUtil.extend
local unnest2 = tableUtil.unnest2

local SEP = package.config:sub(1, 1)
local function path(...)
	return table.concat({ ... }, SEP)
end

describe("extend", function()
	describe("array", function()
		for _, prefer in ipairs({ "nested", "unnested" }) do
			local nested = prefer == "nested"
			describe("prefers " .. prefer, function()
				it("gets replaced if it doesn't have an arrayMt", function()
					local arr = { "some" }
					local new = json.array({ "new" })
					arr = extend(nested, arr, new)
					assert.are_equal(new, arr)
				end)

				it("inserts if an element doesn't exist", function()
					local arr = json.array({ "some" })
					arr = extend(nested, arr, json.array({ "new" }))
					assert.are_same({ "some", "new" }, arr)
				end)

				it("doesn't insert if it exists", function()
					local arr = json.array({ "some" })
					arr = extend(nested, arr, json.array({ "some" }))
					assert.are_same({ "some" }, arr)
				end)

				it("inserts multiple elements and filters out those that are equal", function()
					local arr = json.array({ "x", "y", "z" })
					arr = extend(nested, arr, json.array({ "v", "w", "x" }))
					assert.are_same({ "x", "y", "z", "v", "w" }, arr)
				end)

				it("checks for existence by deep equality", function()
					local arr = json.array({ json.array({ "some" }) })
					arr = extend(nested, arr, json.array({ json.array({ "some" }) }))
					assert.are_same({ { "some" } }, arr)
				end)

				it("checks for non-existence by deep equality", function()
					local arr = json.array({ json.array({ "some" }) })
					arr = extend(nested, arr, json.array({ json.array({ "new" }) }))
					assert.are_same({ { "some" }, { "new" } }, arr)
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
					local new = json.object({ other = "new" })
					obj = extend(nested, obj, new)
					assert.are_equal(new, obj)
				end)

				it("writes all keys to the first argument", function()
					local obj = json.object({ key = "some", existing = true })
					local new = json.object({ key = "new", a = 1, b = 2, c = 3 })
					obj = extend(nested, obj, new)
					assert.are_same({ key = "new", a = 1, b = 2, c = 3, existing = true }, obj)
				end)

				it("fails to write unnested keys from nested keys", function()
					local obj = json.object({ ["some.key"] = "value" })
					local new = json.object({ some = json.object({ key = "new value" }) })
					obj = extend(nested, obj, new)
					assert.are_same({ ["some.key"] = "value", some = { key = "new value" } }, obj)
				end)

				it("writes unnested keys from nested keys that were unnested", function()
					local obj = json.object({ ["some.key"] = "value" })
					local new = json.object({ some = json.object({ key = "new value" }) })
					local unnested = unnest2(new)
					obj = extend(nested, obj, unnested)
					assert.are_same({ ["some.key"] = "new value" }, obj)
				end)

				it("writes both nested and unnested keys", function()
					local obj = json.object({
						completion = json.object({ autoRequire = "value 1" }),
						["hover.enable"] = "value 2",
					})
					local new = json.object({
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
				local obj = json.object({})
				local new = json.object({ ["some.key"] = "new value" })
				obj = extend(true, obj, new)
				assert.are_same({ some = { key = "new value" } }, obj)
			end)

			it("writes to unnested keys if they exist", function()
				local obj = json.object({ ["other.key"] = "value" })
				local new = json.object({ ["other.key"] = "new value" })
				obj = extend(true, obj, new)
				assert.are_same({ ["other.key"] = "new value" }, obj)
			end)

			it("merges conflicting unnested keys if they are encountered", function()
				local obj = json.object({
					["other.key"] = json.object({ a = true }),
					other = json.object({ key = json.object({ b = true }) }),
				})
				local new = json.object({ ["other.key"] = json.object({ c = true }) })
				obj = extend(true, obj, new)
				assert.are_same({ other = { key = { a = true, b = true, c = true } } }, obj)
			end)
		end)

		describe("with unnested keys", function()
			it("prefers to fill unnested keys", function()
				local obj = json.object({})
				local new = json.object({ ["some.key"] = "new value" })
				obj = extend(false, obj, new)
				assert.are_same({ ["some.key"] = "new value" }, obj)
			end)

			it("writes to nested keys if they exist", function()
				local obj = json.object({ other = json.object({ key = "value" }) })
				local new = json.object({ ["other.key"] = "new value" })
				obj = extend(false, obj, new)
				assert.are_same({ other = { key = "new value" } }, obj)
			end)

			it("merges conflicting nested keys if they are encountered", function()
				local obj = json.object({
					["other.key"] = json.object({ a = true }),
					other = json.object({ key = json.object({ b = true }) }),
				})
				local new = json.object({ ["other.key"] = json.object({ c = true }) })
				obj = extend(false, obj, new)

				assert.are_same({ ["other.key"] = { a = true, b = true, c = true } }, obj)
			end)
		end)
	end)

	describe(".luarc.json config", function()
		local nestedLuarc = json.read(path("spec", "configs", "nested.luarc.json"))
		local unnestedLuarc = json.read(path("spec", "configs", "unnested.luarc.json"))

		it("works when preferring nested", function()
			local newObj = extend(true, json.object({}), unnestedLuarc)
			assert.are_same(nestedLuarc, newObj)
		end)

		it("works when preferring unnested", function()
			local newObj = extend(false, json.object({}), unnestedLuarc)
			assert.are_same(unnestedLuarc, newObj)
		end)
	end)
end)
