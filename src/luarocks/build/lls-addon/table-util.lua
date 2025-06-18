local jsonUtil = require("luarocks.build.lls-addon.json-util")
local object = jsonUtil.object
local isJsonArray = jsonUtil.isJsonArray
local isJsonObject = jsonUtil.isJsonObject

local M = {}

---@param k string
---@return string[] path
local function parseSettingsPath(k)
	local path = {} ---@type string[]
	for subK in string.gmatch(k, "[^%.]+") do
		table.insert(path, subK)
	end
	return path
end

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

---@param old unknown
---@param new unknown
---@return any
local function extendSimple(old, new)
	if isJsonArray(old) and isJsonArray(new) then -- treat arrays like sets
		---@cast old unknown[]
		---@cast new unknown[]
		for _, v in ipairs(new) do
			if not contains(old, v) then
				table.insert(old, v)
			end
		end
		return old
	elseif isJsonObject(old) and isJsonObject(new) then
		---@cast old { [string]: unknown }
		---@cast new { [string]: unknown }
		for k, v in pairs(new) do
			old[k] = extendSimple(old[k], v)
		end
		return old
	else
		return new
	end
end

---- if both the nested and unnested key exists, delete the unnested
---  key and write to the nested key
---- if only the unnested key exists, write to that
---- otherwise, write to the nested key
---@param old { [string]: unknown }
---@param k string
---@param v unknown
local function extendNestedKey(old, k, v)
	local oldV = old[k]
	if isJsonObject(v) then
		---@cast v { [string]: unknown }
		if isJsonObject(oldV) then
			---@cast oldV { [string]: unknown }
			-- the nested key might exist
			-- - if the nested key exists, merge the unnested key and
			--   write to the nested key
			-- - if the nested key does not exist, check for an unnested key
			--   if that exists, write to it
			-- - otherwise, write to the nested key
			for subK, subV in pairs(v) do
				local oldSubV = oldV[subK]
				local unnestedK = k .. "." .. subK
				local unnestedOldSubV = old[unnestedK]
				if oldSubV ~= nil then
					old[unnestedK] = nil
					oldV[subK] = extendSimple(extendSimple(unnestedOldSubV, oldSubV), subV)
				elseif unnestedOldSubV ~= nil then
					old[unnestedK] = extendSimple(unnestedOldSubV, subV)
				else
					oldV[subK] = subV
				end
			end
		else
			-- there's no way the nested key exists
			-- write to the unnested key if it exists, otherwise write
			-- to the nested key
			for subK, subV in pairs(v) do
				local unnestedK = k .. "." .. subK
				local unnestedOldSubV = old[unnestedK]
				if unnestedOldSubV ~= nil then
					old[unnestedK] = extendSimple(unnestedOldSubV, subV)
				else
					-- write to the nested key
					if not isJsonObject(oldV) then
						oldV = object({})
						old[k] = oldV
					end
					oldV[subK] = subV
				end
			end
		end
	else
		old[k] = extendSimple(oldV, v)
	end
end

---modifies `old` such that it contains all the properties of `new`.
---
---Arrays are treated like sets, so any new values will only be inserted if the
---array doesn't contain it.
---
---If `old` and `new` are objects, all keys from `new` are copied into `old`,
---preferring to write to nested keys
---@param old unknown
---@param new unknown
---@return any
local function extendNested(old, new)
	if isJsonObject(old) and isJsonObject(new) then
		---@cast old { [string]: unknown }
		---@cast new { [string]: unknown }
		for k, v in pairs(new) do
			extendNestedKey(old, k, v)
		end
		return old
	else
		return extendSimple(old, new)
	end
end
M.extendNested = extendNested

---@param old { [string]: unknown }
---@param k string
---@param v unknown
local function extendUnnestedkey(old, k, v)
	local firstKey, rest = string.match(k, "^([^%.]+)%.(.*)$")
	if firstKey == nil then
		old[k] = extendSimple(old[k], v)
		return
	end

	local oldV = old[firstKey]
	if not isJsonObject(oldV) then
		old[k] = extendSimple(old[k], v)
		return
	end

	local oldSubV = oldV[rest]
	if oldSubV == nil then
		old[k] = extendSimple(old[k], v)
		return
	end

	local unnestedOldSubV = old[k]
	if unnestedOldSubV ~= nil then
		oldV[rest] = extendSimple(extendSimple(old[k], oldSubV), v)
	else
		oldV[rest] = extendSimple(oldSubV, v)
	end
end

---modifies `old` such that it contains all the properties of `new`.
---
---Arrays are treated like sets, so any new values will only be inserted if the
---array doesn't contain it.
---
---If `old` and `new` are objects, all keys in `new` must be unnested, i.e.
---`"workspace.library": []` instead of `"workspace": { "library": [] }`. Keys
---will not be copied correctly otherwise.
---@param old unknown
---@param new unknown
---@return any
local function extendUnnested(old, new)
	if isJsonObject(old) and isJsonObject(new) then
		---@cast old { [string]: unknown }
		---@cast new { [string]: unknown }
		for k, v in pairs(new) do
			-- if `old` has `firstKey`, merge settings in a nested way
			extendUnnestedkey(old, k, v)
		end

		return old
	else
		return extendSimple(old, new)
	end
end
M.extendUnnested = extendUnnested

---@param t { [string]: any }
---@param k string
---@param unnested { [string]: any }
local function unnestKey(t, k, unnested)
	local subT = t[k]
	if not isJsonObject(subT) then
		unnested[k] = extendSimple(unnested[k], subT)
		return
	end

	local path = parseSettingsPath(k)
	if #path >= 2 then
		unnested[k] = extendSimple(unnested[k], subT)
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
			extendSimple(v, oldV)
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
function M.unnest2(t)
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

---@param t { [string]: any }
---@param k string
---@param nested { [string]: any }
local function nestKey(t, k, nested)
	local firstKey, rest = string.match(k, "^([^%.]+)%.(.+)$")
	if not firstKey then
		nested[k] = extendSimple(nested[k], t[k])
		return
	end

	local obj = nested[firstKey]
	if not obj then
		obj = object({})
		nested[firstKey] = obj
	end
	obj[rest] = extendSimple(obj[rest], t[k])
end

---@param t { [string]: any }
---@return { [string]: any } nested
function M.nest2(t)
	local nested = object({})
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys)

	for _, k in ipairs(keys) do
		nestKey(t, k, nested)
	end
	return nested
end

return M
