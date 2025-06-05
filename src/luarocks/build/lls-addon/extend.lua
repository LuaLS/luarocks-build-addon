local jsonCmp = require("luarocks.build.lls-addon.json-cmp")
local contains = require("luarocks.build.lls-addon.contains")

local isJsonArray = jsonCmp.isJsonArray
local isJsonObject = jsonCmp.isJsonObject

---modifies `old` such that it contains all the properties of `new`. Arrays are
---treated like sets, so any new values will only be inserted if the array
---doesn't contain it.
---@param old any
---@param new any
---@return any
local function extend(old, new)
	if isJsonArray(old) and isJsonArray(new) then -- treat arrays like sets
		for _, v in ipairs(new) do
			if not contains(old, v) then
				table.insert(old, v)
			end
		end
		return old
	elseif isJsonObject(old) and isJsonObject(new) then
		for k, v in pairs(new) do
			old[k] = extend(old[k], v)
		end
		return old
	else
		return new
	end
end

return extend