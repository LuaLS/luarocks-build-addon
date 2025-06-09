local jsonUtil = require("luarocks.build.lls-addon.json-util")
local object = jsonUtil.object
local isJsonArray = jsonUtil.isJsonArray
local isJsonObject = jsonUtil.isJsonObject

local M = {}

local tableDeepEqual ---@type fun(a: table, b: table): boolean

---checks if all fields of `a` is equal to all fields of `b` and vice-versa.
---@param a any
---@param b any
---@return boolean
local function deepEqual(a, b)
	if type(a) == "table" and type(b) == "table" then
		return tableDeepEqual(a, b) and tableDeepEqual(b, a)
	else
		return a == b
	end
end

---@param a table
---@param b table
---@return boolean
function tableDeepEqual(a, b)
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	return true
end

---checks if there is any element in `array` that is deeply equal to `value`
---@param array any[]
---@param value any
---@return boolean
local function contains(array, value)
	for _, v in ipairs(array) do
		if deepEqual(v, value) then
			return true
		end
	end
	return false
end
M.contains = contains

---modifies `old` such that it contains all the properties of `new`. Arrays are
---treated like sets, so any new values will only be inserted if the array
---doesn't contain it.
---@param old unknown
---@param new unknown
---@return any
local function extend(old, new)
	if isJsonArray(old) and isJsonArray(new) then -- treat arrays like sets
		---@cast old any[]
		---@cast new any[]
		for _, v in ipairs(new) do
			if not contains(old, v) then
				table.insert(old, v)
			end
		end
		return old
	elseif isJsonObject(old) and isJsonObject(new) then
		---@cast old { [string]: any }
		---@cast new { [string]: any }
		for k, v in pairs(new) do
			-- if `old` has `firstKey`, merge settings in a nested way
			local path = {} ---@type string[]
			for subKey in string.gmatch(k, "[^%.]+") do
				table.insert(path, subKey)
			end
			local keyFound = false
			for i = 1, #path - 1 do
				local firstKey = table.concat(path, ".", 1, i)
				local rest = table.concat(path, ".", i + 1, #path)
				local oldFirstValue = old[firstKey]
				if oldFirstValue ~= nil then
					old[firstKey] = extend(oldFirstValue, object({ [rest] = v }))
					keyFound = true
					break
				end
			end

			if not keyFound then
				-- otherwise, merge them in an unnested way
				old[k] = extend(old[k], v)
			end
		end
		return old
	else
		return new
	end
end
M.extend = extend

---@param t { [string]: any }
---@param k string
---@param unnested { [string]: any }
local function unnestKey(t, k, unnested)
	local subT = t[k]
	if not isJsonObject(subT) then
		unnested[k] = extend(unnested[k], subT)
		return
	end

	local path = {}
	for subK in string.gmatch(k, "[^%.]+") do
		table.insert(path, subK)
	end
	if #path >= 2 then
		unnested[k] = extend(unnested[k], subT)
		return
	end

	for subK, v in pairs(subT) do
		local oldLen = #path
		for subSubK in string.gmatch(subK, "[^%.]+") do
			table.insert(path, subSubK)
		end
		local newK = table.concat(path, ".")
		local oldV = t[newK]
		if oldV ~= nil then
			extend(v, oldV)
		end

		unnested[newK] = v
		while #path > oldLen do
			table.remove(path)
		end
	end
end
M.unnestKey = unnestKey

---@param t { [string]: any }
---@return { [string]: any } unnested
local function unnest2(t)
	local unnested = object({}) ---@type { [string]: any }
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys)

	for _, k in ipairs(keys) do
		unnestKey(t, k, unnested)
	end
	return unnested
end
M.unnest2 = unnest2

return M
