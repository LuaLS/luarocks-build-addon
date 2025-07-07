# Experimental LuaRocks Build Backend for LuaLS Addons

## Supported environment variables

> [!NOTE]
> The path separator used in these examples is `;`, but may change based on `package.config`, a.k.a. the operating system.

-   `LLSADDON_LUARCPATH="$path1;$path2;..."`: a list of paths indicating which `.luarc.json`-style files to modify when installing the addon.
-   `LLSADDON_VSCSETTINGSPATH="$path1;$path2;..."`: a list of paths indicating which `.vscode/settings.json`-style files to modify when installing the addon.
    -   If at least one of the above variables is set to `""` and the other is unset, no config files will be modified by the build process.
-   `LLSADDON_ABSPATH`: If defined as none of `"false"`, `"no"`, `"off"` or `"0"`, indicates any paths added to the config file should be absolute paths, rather than relative ones.

## Building

1. Start by cloning this repo.

2. `luarocks --local --lua-version=5.4 make` to build this rock and install it in the user-level rocks tree so it can be used to build other rocks.

3. For testing, clone an addon. I have been using the [cc-tweaked documentation addon](https://gitlab.com/carsakiller/cc-tweaked-documentation).

4. Within that cloned addon, create a `.rockspec`, like below:

`cc-tweaked-dev-1.rockspec`

```lua
rockspec_format = "3.0"
package = "cc-tweaked"
version = "dev-1"
source = {
    url = "https://gitlab.com/carsakiller/cc-tweaked-documentation",
}
description = {
    summary = "LuaCATS annotations for CC:Tweaked",
    detailed = "Manually created LuaCATS annotations for Minecraft's CC:Tweaked computer mod",
    homepage = "https://gitlab.com/carsakiller/cc-tweaked-documentation",
    license = "MIT",
}
build = {
    type = "lls-addon",
    settings = {
        runtime = {
            version = "Lua 5.3",
            builtin = {
                io = "disable",
                os = "disable",
            },
        },
    },
}
```

5. Try to install the repo by running `luarocks make`. This will use the custom build backend to copy some directories/files and modify/create the `.luarc.json` file to make LuaLS aware.

6. You should see that there is a `.luarc.json` in the `cc-tweaked`'s project directory with all the required keys filled in.

Now you should have types! This step obviously still needs a lot of work to automatically apply the path and deal with global/local installs, etc.

You can try adding plugins or other settings to see if everything is working as intended.

## Testing

```sh
# the build fails if this is not set to 5.4, I don't know why
echo 'return "5.4"' > .luarocks/default-lua-version.lua
luarocks test

# report coverage
luarocks test -- -c
./lua_modules/bin/luacov -r html && ./luacov.report.html
```

---

It isn't ideal, but it is using nothing but LuaRocks 🤷. I would love a `dev_dependencies` field in `.rockspec` files to allow the addon to be installed for dev work but not build/prod. Open to any suggestions on how to improve this, including not hacking around LuaRocks and just creating a separate CLI tool 😄
