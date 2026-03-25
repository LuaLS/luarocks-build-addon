local thisFunction = ...
assert(type(thisFunction) == "function", "must be loaded as a plugin from lua-language-server")

local fs = require("bee.filesystem")
local furi = require("file-uri")
local workspace = require("workspace")

-- this relies on the plugin module's behavior with modifying
-- package.path... very fragile
local luarocksLuaVersion, start = string.match(package.path, "(%d%.%d)()([/\\])luarocks%3%?%.lua$")
assert(start, "could not replace path")
package.path = string.sub(package.path, 1, start) .. "?.lua"

local cfg = require("luarocks.core.cfg") --[[@as luarocks.core.cfg]]

local workspaceRoot = fs.path(furi.decode(workspace.rootUri))
local lua_modules = workspaceRoot / "lua_modules"
if fs.exists(lua_modules:string()) then
	print("luarocks-build-lls-addon: configured workspace as project directory")
	-- re-initialize cfg with the project directory (loads in the project config from ./.luarocks)
	assert(cfg.init({ project_dir = workspaceRoot:string(), lua_version = luarocksLuaVersion }))
	cfg.init_package_paths()
	-- add ./lua_modules as one of the queryable rocks trees
	table.insert(cfg.rocks_trees, 1, { name = "project", root = lua_modules:string() } --[[@as luarocks.core.Tree]])
end

-- Stub out cfg.init() when `luarocks.loader` is running, since it calls the
-- function unconditionally with no arguments.
local oldInit = cfg.init
function cfg.init()
	return true
end
require("luarocks.loader")
cfg.init = oldInit

-- initialize it again with 5.5 so other plugins can use it
cfg.init()
cfg.init_package_paths()

-- because of how `plugin.dispatch` works, leaving these functions undefined
-- means plugins defined later can't use these callbacks!
-- all thanks to this line: https://github.com/LuaLS/lua-language-server/blob/0187ddf19f940d8b9b95d916d73f4660ec417471/script/plugin.lua#L35

function OnSetText() end
function OnTransformAst() end
function ResolveRequire() end

print("luarocks-build-lls-addon: loader finished!")
