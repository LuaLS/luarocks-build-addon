local json
if _TEST then
	json = require("dkjson")
else
	json = require("luarocks.vendor.dkjson")
end

local M = {}

local function assertContext(context, ...)
	local s, msg = ...
	if not s then
		error(context .. ": " .. msg)
	end
	return ...
end

local arrayMt = { __jsontype = "array" }
local objectMt = { __jsontype = "object" }
M.arrayMt = arrayMt
M.objectMt = objectMt

---@param t any[]
---@return any[]
function M.array(t)
	return setmetatable(t, arrayMt)
end

---@param t { [string]: any }
---@return { [string]: any }
function M.object(t)
	return setmetatable(t, objectMt)
end

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

---@param sourcePath string
---@return any
function M.readJsonFile(sourcePath)
	local file <close> = assertContext("when opening " .. sourcePath, io.open(sourcePath))
	local contents = file:read("a")
	return json.decode(contents, nil, json.null, objectMt, arrayMt)
end

return M