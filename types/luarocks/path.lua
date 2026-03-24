local core_path = require("luarocks.core.path")

---@class luarocks.path
local path = {}

path.rocks_tree_to_string = core_path.rocks_tree_to_string

return path
