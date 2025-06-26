---@diagnostic disable-next-line: unknown-cast-variable
---@cast assert luassert

local SEP = package.config:sub(1, 1)
local function path(...)
    return table.concat({ ... }, SEP)
end

local jsonUtil = require("luarocks.build.lls-addon.json-util")
local readJsonFile = jsonUtil.readJsonFile

local tableUtil = require("luarocks.build.lls-addon.table-util")
local unnest2 = tableUtil.unnest2
local nest2 = tableUtil.nest2

describe(".luarc.json", function ()
    local nestedLuarc = readJsonFile(path("spec", "configs", "nested.luarc.json"))
    local unnestedLuarc = readJsonFile(path("spec", "configs", "unnested.luarc.json"))

    describe("under nest2", function ()
        it("returns the correct value", function ()
            local actualNested = nest2(unnestedLuarc)
            assert.are_same(nestedLuarc, actualNested)
        end)

        it("is the inverse of unnest2", function ()
            local actualNested = nest2(unnest2(nestedLuarc))
            assert.are_not_equal(nestedLuarc, actualNested)
            assert.are_same(nestedLuarc, actualNested)
        end)
    end)

    describe("under unnest2", function ()
        it("returns the correct value", function ()
            local actualUnnested = unnest2(nestedLuarc)
            assert.are_same(unnestedLuarc, actualUnnested)
        end)

        it("is the inverse of nest2", function ()
            local actualUnnested = unnest2(nest2(unnestedLuarc))
            assert.are_not_equal(unnestedLuarc, actualUnnested)
            assert.are_same(unnestedLuarc, actualUnnested)
        end)
    end)
end)