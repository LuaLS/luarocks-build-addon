---@param finally fun(finalizer: fun())
---@return fun(finalizer: fun()) finally
local function upgradeFinally(finally)
	local cleanupAll = {} ---@type (fun())[]
	---@param fun fun()
	local function newFinally(fun)
		table.insert(cleanupAll, fun)
	end
	finally(function()
		local result = true
		local message = nil
		for i = #cleanupAll, 1, -1 do
			local s, msg = pcall(cleanupAll[i])
			result = result and s
			message = message or msg
		end

		assert(result, message)
	end)
	return newFinally
end

return upgradeFinally
