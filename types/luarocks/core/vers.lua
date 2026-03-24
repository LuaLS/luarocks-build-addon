---@meta

---@class luarocks.core.vers.Version
---@field string string
---@field revision number
---@field [number] number

---@class luarocks.core.vers
local vers = {}

---@param vstring string
---@return luarocks.core.vers.Version
---@overload fun(vstring: nil): nil
function vers.parse_version(vstring) end

---@param a string
---@param b string
---@return boolean -- whether `a > b`
function vers.compare_versions(a, b) end

return vers
