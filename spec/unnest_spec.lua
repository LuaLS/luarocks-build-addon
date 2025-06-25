---@diagnostic disable-next-line: unknown-cast-variable
---@cast assert luassert

local jsonUtil = require("luarocks.build.lls-addon.json-util")
local object = jsonUtil.object
local array = jsonUtil.array

local tableUtil = require("luarocks.build.lls-addon.table-util")
local unnest2 = tableUtil.unnest2
local unnestKey = tableUtil.unnestKey

describe("unnestKey", function()
	it("acts the same regardless of merge order", function()
		local obj1 = object({
			runtime = object({
				special = object({ os = "disable" }),
			}),
			["runtime.special"] = object({ io = "enable" }),
		})
		local obj2 = object({
			runtime = object({
				special = object({ os = "disable" }),
			}),
			["runtime.special"] = object({ io = "enable" }),
		})
		local unnested1 = {}
		local unnested2 = {}
		unnestKey(obj1, "runtime", unnested1)
		unnestKey(obj1, "runtime.special", unnested1)
		unnestKey(obj2, "runtime.special", unnested2)
		unnestKey(obj2, "runtime", unnested2)
		assert.are_same({
			["runtime.special"] = {
				os = "disable",
				io = "enable",
			},
		}, unnested1)
		assert.are_same(unnested1, unnested2)
	end)
end)

it("unnests nested two-level objects", function()
	local obj = object({
		workspace = object({
			library = array({ "path" }),
		}),
		["workspace.another"] = true,
	})
	local unnested = unnest2(obj)
	assert.are_same({
		["workspace.library"] = { "path" },
		["workspace.another"] = true,
	}, unnested)
end)

it("unnests three-level objects correctly", function()
	local obj = object({
		runtime = object({
			special = object({
				os = "disable",
			}),
		}),
	})

	local unnested = unnest2(obj)
	assert.are_same({
		["runtime.special"] = { os = "disable" },
	}, unnested)
end)

it("leaves unnested objects unmodified", function()
	local obj = object({
		["runtime.special"] = object({ os = "disable" }),
	})

	local unnested = unnest2(obj)
	assert.are_same({
		["runtime.special"] = { os = "disable" },
	}, unnested)
end)

it("merges unnested and nested keys with object values", function()
	local obj = object({
		runtime = object({
			special = object({ os = "disable" }),
		}),
		["runtime.special"] = object({ io = "enable" }),
	})
	local unnested = unnest2(obj)
	assert.are_same({
		["runtime.special"] = {
			os = "disable",
			io = "enable",
		},
	}, unnested)
end)

it("merges unnested and nested keys with non-object values", function()
	local obj = object({
		hover = object({
			enable = array({ true }),
		}),
		["hover.enable"] = array({ false }),
	})
	local unnested = unnest2(obj)
	assert.are_same({ ["hover.enable"] = { true, false } }, unnested)
end)
