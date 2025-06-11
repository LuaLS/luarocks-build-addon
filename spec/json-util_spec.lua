---@diagnostic disable-next-line: unknown-cast-variable
---@cast assert luassert

_G._TEST = true

local json = require("dkjson")
local jsonUtil = require("luarocks.build.lls-addon.json-util")
local object = jsonUtil.object
local array = jsonUtil.array

it("turns empty objects into object strings", function ()
    assert.are_equal("{}", json.encode(object({})))
end)
it("turns empty arrays into array strings", function ()
    assert.are_equal("[]", json.encode(array({})))
end)