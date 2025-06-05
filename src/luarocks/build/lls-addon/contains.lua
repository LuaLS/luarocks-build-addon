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

return contains