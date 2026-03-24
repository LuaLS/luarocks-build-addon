---@meta

---@class luarocks.core.path
local path = {}

---@param tree string | luarocks.core.Tree
---@return string
function path.rocks_tree_to_string(tree) end

---@param tree string | luarocks.core.Tree
---@return string
function path.deploy_lua_dir(tree) end

---@param tree? string | luarocks.core.Tree
---@return string
function path.rocks_dir(tree) end

return path
