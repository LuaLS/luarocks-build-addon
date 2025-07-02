local json = require("luarocks.vendor.dkjson")

local M = {
	encode = json.encode,
	decode = json.decode,
}

local function assertContext(context, ...)
	-- luacov: disable
	local s, msg = ...
	if not s then
		error(context .. ": " .. msg)
	end
	return ...
	-- luacov: enable
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
local function coerce(value)
	if type(value) ~= "table" then
		return value
	end

	if #value > 0 then
		array(value)
		for _, v in ipairs(value) do
			coerce(v)
		end
	else
		object(value)
		for _, v in pairs(value) do
			coerce(v)
		end
	end
	return value
end
M.coerce = coerce

---@param value any
---@return boolean
local function isObject(value)
	return type(value) == "table" and getmetatable(value) == objectMt
end
M.isObject = isObject

---@param value any
---@return boolean
local function isArray(value)
	return type(value) == "table" and getmetatable(value) == arrayMt
end
M.isArray = isArray

---@param sourcePath string
---@return any
function M.read(sourcePath)
	local file <close> = assertContext("when opening " .. sourcePath, io.open(sourcePath))
	local contents = file:read("a")
	return json.decode(contents, nil, json.null, objectMt, arrayMt)
end

---gets all keys from a json object
---@param keyorder string[]
---@param obj { [string]: any }
local function getRecursiveKeys(keyorder, obj)
	if isObject(obj) then
		for k, v in pairs(obj) do
			table.insert(keyorder, k)
			getRecursiveKeys(keyorder, v)
		end
	elseif isArray(obj) then
		for _, v in ipairs(obj) do
			getRecursiveKeys(keyorder, v)
		end
	end
end

---@class lls-addon.json-util.write-options
---@field sortKeys? boolean
---@field indent? number
---@field keyorder? any[]

---@param destinationPath string
---@param value any
---@param opt? lls-addon.json-util.write-options
function M.write(destinationPath, value, opt)
	local options = { indent = 2 }

	if opt then
		if opt.sortKeys then
			local keyorder = {} ---@type string[]
			getRecursiveKeys(keyorder, value)
			table.sort(keyorder)
			options.keyorder = keyorder
		end

		for k, v in pairs(opt) do
			options[k] = v
		end
	end

	local contents = json.encode(value, options) --[[@as string]]
	local file <close> = assertContext("when opening " .. destinationPath, io.open(destinationPath, "w")) --[[@as file*]]
	assertContext("when writing to .luarc.json", file:write(contents))
end

return M
