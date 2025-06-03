# Experimental LuaRocks Build Backend for LuaLS Addons

1. Start by cloning this repo.

2. `luarocks --local --lua-version=5.4 make` to build this rock locally so it can be used to build other rocks

3. For testing, clone an addon. I have been using the [cc-tweaked documentation addon](https://gitlab.com/carsakiller/cc-tweaked-documentation).

4. Within that cloned addon, create a `.rockspec`, like below:

`cc-tweaked-dev-1.rockspec`
```lua
rockspec_format = "3.0"
package = "cc-tweaked"
version = "dev-1"
source = {
   url = "git+ssh://git@gitlab.com/carsakiller/cc-tweaked-documentation"
}
description = {
   summary = "LuaCATS annotations for CC:Tweaked",
   detailed = "Manually created LuaCATS annotations for Minecraft's CC:Tweaked computer mod",
   homepage = "https://gitlab.com/carsakiller/cc-tweaked-documentation",
   license = "MIT"
}
build = {
   type = "lls-addon"
}
```

5. Now we need to create the final repo for the actual project that needs the addon's types. All it needs is a `.rockspec` like below:

`some-package-dev-1.rockspec`
```lua
rockspec_format = "3.0"
package = "some-package"
version = "dev-1"
source = {
   url = "some_link_not_important"
}
description = {
   summary = "***",
   detailed = "***",
   homepage = "***",
   license = "MIT"
}
build_dependencies = {
	"cc-tweaked"
}
build = {
	type = "builtin"
}
```

6. Now if we are to build this project (`luarocks build --local`) the custom backend is used to install the cc-tweaked addon.

7. Add install path to `.luarc.json` under [`workspace.library`](https://luals.github.io/wiki/settings/#workspacelibrary) to tell LuaLS where the types are. Example:

`.luarc.json`
```json
{
	"workspace.library": [
		"${env:HOME}/.luarocks/lib/luarocks/rocks-5.4/"
	]
}
```
Now you should have types! This step obviously still needs a lot of work to automatically apply the path and deal with global/local installs, etc.

Addon settings are not handled by this yet.

---

It isn't ideal, but it is using nothing but LuaRocks 🤷. I would love a `dev_dependencies` field in `.rockspec` files to allow the addon to be installed for dev work but not build/prod. Open to any suggestions on how to improve this, including not hacking around LuaRocks and just creating a separate CLI tool 😄
