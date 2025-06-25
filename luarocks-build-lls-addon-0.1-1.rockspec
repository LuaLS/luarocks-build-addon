rockspec_format = "3.0"
package = "luarocks-build-lls-addon"
version = "0.1-1"
source = {
   url = "https://github.com/LuaLS/luarocks-build-addon",
}
description = {
   summary = "A build backend for LuaRocks that installs LuaLS addons",
   homepage = "https://github.com/LuaLS/luarocks-build-addon",
   license = "MIT",
}

test_dependencies = {
   "busted ~> 2.2",
   "luafilesystem ~> 1.8",
   "inspect ~> 3.1",
   "dkjson ~> 2.8",
}