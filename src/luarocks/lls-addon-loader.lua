local thisFunction = ...
assert(type(thisFunction) == "function", "must be loaded as a plugin from lua-language-server")

local fs = require("bee.filesystem")
local furi = require("file-uri")
local workspace = require("workspace")

local start, _, dir_sep = string.find(package.path, "([/\\])luarocks%1%?%.lua$")
assert(start, "could not replace path")
package.path = string.sub(package.path, 1, start - 1) .. dir_sep .. "?.lua"

local cfg = require("luarocks.core.cfg") --[[@as luarocks.core.cfg]]
require("luarocks.loader")

local workspaceRoot = fs.path(furi.decode(workspace.rootUri))
local lua_modules = workspaceRoot / "lua_modules"
if fs.exists(lua_modules:string()) then
	print("luarocks-build-lls-addon: configured workspace as project directory")
	-- re-initialize cfg with the project directory (loads in the project config from ./.luarocks)
	cfg.init({ project_dir = workspaceRoot:string() })
	-- add ./lua_modules as one of the queryable rocks trees
	table.insert(cfg.rocks_trees, 1, { name = "project", root = lua_modules:string() } --[[@as luarocks.core.Tree]])
end

print("luarocks-build-lls-addon: loader finished!")
