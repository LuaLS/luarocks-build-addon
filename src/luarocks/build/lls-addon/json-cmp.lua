local M = {}

local arrayMt = { __jsontype = "array" }
local objectMt = { __jsontype = "object" }
M.arrayMt = arrayMt
M.objectMt = objectMt

---@param value any
---@return boolean
function M.isJsonObject(value)
	return type(value) == "table" and getmetatable(value) == objectMt
end

---@param value any
---@return boolean
function M.isJsonArray(value)
	return type(value) == "table" and getmetatable(value) == arrayMt
end

return M