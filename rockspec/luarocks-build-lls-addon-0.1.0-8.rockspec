rockspec_format = "3.0"
package = "luarocks-build-lls-addon"
version = "0.1.0-8"

local source_url = ("https://github.com/LuaLS/luarocks-build-addon/archive/v%s/luarocks-build-addon-%s.zip"):format(
	version,
	version
)
local source_dir = ("luarocks-build-addon-%s"):format(version)

source = {
	url = source_url,
	dir = source_dir,
}
description = {
	summary = "A build backend for LuaRocks that installs LuaLS addons",
	homepage = "https://github.com/LuaLS/luarocks-build-addon",
	license = "MIT",
}

test_dependencies = {
	"luarocks >= 3.11.1",
	"busted ~> 2.2",
	"luafilesystem ~> 1.8",
	"inspect ~> 3.1",
	"md5 ~> 1.3",
}
