local jsonUtil = require("src.luarocks.build.lls-addon.json-util")
local contains = require("luarocks.build.lls-addon.contains")

local object = jsonUtil.object
local isJsonArray = jsonUtil.isJsonArray
local isJsonObject = jsonUtil.isJsonObject

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
			local firstKey, rest = string.match(k, "^(.-)%.(.*)$")
			local oldFirstValue = old[firstKey] -- this is nil if firstKey is nil
			if oldFirstValue ~= nil then
				old[firstKey] = extend(oldFirstValue, object({ [rest] = v }))
			else
				old[k] = extend(old[k], v)
			end
		end
		return old
	else
		return new
	end
end

return extend
