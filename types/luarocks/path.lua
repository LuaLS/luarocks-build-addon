---@meta

local core_path = require("luarocks.core.path") --[[@as luarocks.core.path]]

---@class luarocks.path
local path = {}

path.rocks_tree_to_string = core_path.rocks_tree_to_string
path.deploy_lua_dir = core_path.deploy_lua_dir

---Get the local installation directory (prefix) for a package.
---@param name string -- the package name
---@param version string -- the package version
---@param tree? string | luarocks.core.Tree -- if given, specifies the local tree to use
---@return string install_dir -- the resulting path -- does not guarantee that the package (and by extension, the path) exists
function path.install_dir(name, version, tree) end

---Get the local installation directory for Lua modules of a package.
---@param name string -- the package name
---@param version string -- the package version
---@param tree? string | luarocks.core.Tree -- if given, specifies the local tree to use
---@return string lua_dir -- the resulting path -- does not guarantee that the package (and by extension, the path) exists
function path.lua_dir(name, version, tree) end

---@param tree string | luarocks.core.Tree
function path.use_tree(tree) end

return path
