local extend = require("luarocks.build.lls-addon.extend")
local jsonCmp = require("luarocks.build.lls-addon.json-cmp")

local arrayMt = jsonCmp.arrayMt
local function array(t)
	return setmetatable(t, arrayMt)
end

local objectMt = jsonCmp.objectMt
local function object(t)
    return setmetatable(t, objectMt)
end

describe("array", function ()
    it("gets replaced if it doesn't have an arrayMt", function()
        local arr = { "some" }
        local new = array({ "new" })
        arr = extend(arr, new)
        assert.are_equal(new, arr)
    end)

    it("inserts if an element doesn't exist", function()
        local arr = array({ "some" })
        arr = extend(arr, array({ "new" }))
        assert.are_same({ "some", "new" }, arr)
    end)

    it("doesn't insert if it exists", function()
        local arr = array({ "some" })
        arr = extend(arr, array({ "some" }))
        assert.are_same({ "some" }, arr)
    end)

    it("inserts multiple elements and filters out those that are equal", function()
        local arr = array({ "x", "y", "z" })
        arr = extend(arr, array({ "v", "w", "x" }))
        assert.are_same({ "x", "y", "z", "v", "w" }, arr)
    end)

    it("checks for existence by deep equality", function ()
        local arr = array({ array({ "some" }) })
        arr = extend(arr, array({ array({ "some" }) }))
        assert.are_same({ { "some" } }, arr)
    end)
end)

describe("object", function ()
    it("gets replaced if it doesn't have an objectMt", function ()
        local obj = { key = "some" }
        local new = object({ other = "new" })
        obj = extend(obj, new)
        assert.are_equal(new, obj)
    end)

    it("writes all keys to the first argument", function ()
        local obj = object({ key = "some" })
        local new = object({ key = "new", a = 1, b = 2, c = 3 })
        obj = extend(obj, new)
        assert.are_same({ key = "new", a = 1, b = 2, c = 3 }, obj)
    end)
end)