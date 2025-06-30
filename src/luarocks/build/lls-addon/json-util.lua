local json = require("luarocks.vendor.dkjson")

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
local function array(t)
	return setmetatable(t, arrayMt)
end
M.array = array

---@param t { [string]: any }
---@return { [string]: any }
local function object(t)
	return setmetatable(t, objectMt)
end
M.object = object

---@param value any
---@return any t
local function coerceJson(value)
	if type(value) ~= "table" then
		return value
	end

	if #value > 0 then
		array(value)
		for _, v in ipairs(value) do
			coerceJson(v)
		end
	else
		object(value)
		for _, v in pairs(value) do
			coerceJson(v)
		end
	end
	return value
end
M.coerceJson = coerceJson

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
