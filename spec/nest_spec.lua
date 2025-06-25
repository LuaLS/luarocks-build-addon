---@diagnostic disable-next-line: unknown-cast-variable
---@cast assert luassert

local jsonUtil = require("luarocks.build.lls-addon.json-util")
local object = jsonUtil.object
local array = jsonUtil.array

local tableUtil = require("luarocks.build.lls-addon.table-util")
local nest2 = tableUtil.nest2

it("nests two-level objects", function()
	local obj = object({
		workspace = object({ library = array({ "path" }) }),
		["workspace.another"] = true,
	})
	local nested = nest2(obj)
	assert.are_same({
		workspace = {
			library = { "path" },
			another = true,
		},
	}, nested)
end)

it("nests three-level objects correctly", function()
	-- this is undefined behavior. It could change if the need arises.
	local obj = object({ ["runtime.special.os"] = "disable" })

	local nested = nest2(obj)
	assert.are_same({
		runtime = {
			["special.os"] = "disable",
		},
	}, nested)
end)

it("merges unnested and nested keys with object values", function()
	local obj = object({
		runtime = object({
			special = object({ os = "disable" }),
		}),
		["runtime.special"] = object({ io = "enable" }),
	})
	local unnested = nest2(obj)
	assert.are_same({
		runtime = {
			special = {
				os = "disable",
				io = "enable",
			},
		},
	}, unnested)
end)

it("merges unnested and nested keys with non-object values", function()
	local obj = object({
		hover = object({ enable = array({ true }) }),
		["hover.enable"] = array({ false }),
	})
	local unnested = nest2(obj)
	assert.are_same({
		hover = { enable = { true, false } },
	}, unnested)
end)
