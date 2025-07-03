---@meta

_G.assert = assert --[[@as luassert]]

---@class luassert.internal
local internal

---@param value any
---@param array any[]
---@param message? string
function internal.contains(value, array, message) end

---@type luassert.stub
_G.stub = nil

---@type luassert.spy.factory
_G.spy = nil
