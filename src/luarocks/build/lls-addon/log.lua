---this exists only so it can be stubbed out during testing.

-- luacov: disable
local M = {}

---@param msg string
function M.warn(msg)
	print(msg)
end

---@param msg string
function M.info(msg)
	print(msg)
end

return M
