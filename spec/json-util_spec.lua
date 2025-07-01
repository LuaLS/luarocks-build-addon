---@diagnostic disable-next-line: unknown-cast-variable
---@cast assert luassert

local json = require("luarocks.build.lls-addon.json-util")

describe("json-util", function()
	it("turns empty objects into object strings", function()
		assert.are_equal("{}", json.encode(json.object({})))
	end)
	it("turns empty arrays into array strings", function()
		assert.are_equal("[]", json.encode(json.array({})))
	end)
end)
