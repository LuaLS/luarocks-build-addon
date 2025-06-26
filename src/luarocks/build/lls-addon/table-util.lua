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
local function extendNonObject(old, new)
	if isJsonArray(old) and isJsonArray(new) then -- treat arrays like sets
		---@cast old unknown[]
		---@cast new unknown[]
		for _, v in ipairs(new) do
			if not contains(old, v) then
				table.insert(old, v)
			end
		end
		return old
	else
		return new
	end
end

---@param old unknown
---@param new unknown
---@return any
local function extendSimple(old, new)
	if isJsonObject(old) and isJsonObject(new) then
		---@cast old { [string]: unknown }
		---@cast new { [string]: unknown }
		for k, v in pairs(new) do
			old[k] = extendSimple(old[k], v)
		end
		return old
	else
		return extendNonObject(old, new)
	end
end

---@class lls-addon.path-getter
---@field get fun(t: table, path: string): (v: any)
---@field set fun(t: table, path: string, v: any)

---@type lls-addon.path-getter
local nestedPath = {
	get = function(t, path)
		local v = t
		for k in string.gmatch(path, "[^%.]+") do
			if isJsonObject(v) then
				v = v[k]
			else
				return nil
			end
		end
		return v
	end,
	set = function(t, path, v)
		local keys = {}
		for k in string.gmatch(path, "[^%.]+") do
			table.insert(keys, k)
		end

		local subTs = { t }
		local subT = t
		for i = 1, #keys - 1 do
			local k = keys[i]
			local found = subT[k]
			if isJsonObject(found) then
				subT = found
			elseif v ~= nil then
				local newT = object({})
				subT, subT[k] = newT, newT
			else
				goto stopSettingKeys
			end
			table.insert(subTs, subT)
		end
		subT[keys[#keys]] = v
		::stopSettingKeys::

		if v == nil then
			-- remove any empty objects this created
			for i = #subTs, 2, -1 do
				if next(subTs[i]) == nil then
					subTs[i - 1][keys[i - 1]] = nil
				else
					break
				end
			end
		end
	end,
}

---@type lls-addon.path-getter
local unnestedPath = {
	get = function(t, path)
		return t[path]
	end,
	set = function(t, path, v)
		t[path] = v
	end,
}

---modifies `old` such that it contains all the properties of `new`.
---
---if `nested == true`, the algorithm will prefer setting nested keys, and
---unnested keys will be merged into nested keys if encountered.
---
---if `nested == false`, the algorithm will prefer setting unnested keys, and
---nested keys will be merged into unnested keys if encountered.
---
---Arrays are treated like sets, so any new values will only be inserted if the
---array doesn't contain it.
---
---If `old` and `new` are objects, all keys in `new` must be unnested, i.e.
---`"workspace.library": []` instead of `"workspace": { "library": [] }`. Keys
---will not be copied correctly otherwise.
---@param nested boolean -- whether to prefer setting keys in a nested way
---@param old unknown
---@param new unknown
---@return any -- the extended value
local function extend(nested, old, new)
	if isJsonObject(old) and isJsonObject(new) then
		---@cast old { [string]: unknown }
		---@cast new { [string]: unknown }
		local primary ---@type lls-addon.path-getter
		local secondary ---@type lls-addon.path-getter
		if nested then
			primary, secondary = nestedPath, unnestedPath
		else
			primary, secondary = unnestedPath, nestedPath
		end

		for k, v in pairs(new) do
			local primV = primary.get(old, k)
			local secV = secondary.get(old, k)
			if primV ~= nil and secV ~= nil then
				secondary.set(old, k, nil)
				primary.set(old, k, extendSimple(extendSimple(secV, primV), v))
			elseif primV ~= nil then
				primary.set(old, k, extendSimple(primV, v))
			elseif secV ~= nil then
				secondary.set(old, k, extendSimple(secV, v))
			else
				primary.set(old, k, v)
			end
		end

		return old
	else
		return extendNonObject(old, new)
	end
end
M.extend = extend

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

return M
