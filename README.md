# `luarocks-build-lls-addon`

A build backend for installing [lua-language-server](https://github.com/LuaLS/lua-language-server) addons from LuaRocks.

## Usage for End-Users

> [!NOTE]
> End-users do not need to install `luarocks-build-lls-addon`. That will be done automatically when installing an addon for the first time.

End-users can manage addon installations using the LuaRocks CLI.

-   `luarocks install an-addon` - install `an-addon`
-   `luarocks remove an-addon` - remove `an-addon`
-   `luarocks doc an-addon` - view information about `an-addon`
-   etc.

Users can also browse addons online from https://luarocks.org/m/luacats.

### Variables

You can change the behavior of the installer by defining these variables in a `config-5.X.lua` file or on the command-line as `luarocks VAR=VALUE -- ...`. See the [config file format](https://github.com/luarocks/luarocks/blob/main/docs/config_file_format.md#variables) for more information.

-   **LLSADDON_LUARCPATH** (`;`-separated paths) - a list of paths indicating which `.luarc.json`-style files to modify when installing the addon.
-   **LLSADDON_VSCSETTINGSPATH** (`;`-separated paths) - a list of paths indicating which `.vscode/settings.json`-style files to modify when installing the addon. This is useful for creating VSCode settings files if they don't exist, since `.luarc.json` usually takes priority. Set this to `.vscode/settings.json` if you want this behavior.
    -   If at least one of the above variables is set, the installer will not look for default config locations. Set at least one variable to `""` or `";"` to prohibit modifying any config files.
-   **LLSADDON_ABSPATH** (boolean) - If defined as none of `"false"`, `"no"`, `"off"` or `"0"`, indicates any paths added to the config file should be absolute paths, rather than relative ones.

## Usage for Addon Developers

Addon developers should use a similar [addon file structure](https://luals.github.io/wiki/addons/#addon-anatomy) as an old-style addon.

The `config.json` file is considered deprecated when used with this installer. The `words` and `files` fields will not be read, and the `settings` field is superceded by the rockspec's `build.settings` field.

A rockspec file should be included with the following block:

```lua
build = {
    type = "lls-addon",
    -- build rules...
}
```

Addons can be developed in a similar way to any other rock. Dependencies to other addons can be specified in the [`dependencies`](https://github.com/luarocks/luarocks/blob/main/docs/rockspec_format.md#dependency-information) table, and general information can be written in the [`description`](https://github.com/luarocks/luarocks/blob/main/docs/rockspec_format.md#package-metadata) table.

### Build Rules

-   **build.settings** (table?) - May contain a key-value dictionary of [settings](https://luals.github.io/wiki/settings/) to be merged into the LuaLS configuration. The `config.json` file will be ignored if this entry exists.

### Example

Here is an example rockspec for [carsakiller's CC:Tweaked type definitions](https://gitlab.com/carsakiller/cc-tweaked-documentation):

```lua
-- ./luacats-cc-tweaked-1.0.0-1.rockspec
rockspec_format = "3.0"
package = "luacats-cc-tweaked"
version = "1.0.0-1"

source = {
    url = "git+https://gitlab.com/carsakiller/cc-tweaked-documentation.git",
    branch = "luarocks-build", -- this branch does not actually exist
}

description = {
    summary = "LuaCATS annotations for CC:Tweaked",
    detailed = [[
        This documentation covers the Lua API for ComputerCraft: Tweaked and is meant to be used with Sumneko's Lua Language Server as it uses its LuaCATS annotation system.
    ]],
    homepage = "https://gitlab.com/carsakiller/cc-tweaked-documentation",
    license = "MIT",
}

dependencies = { -- CC:Tweaked has no actual dependencies
    "luacats-luafilesystem ~> 1",
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

## Building

```sh
# clone the repository
git clone https://github.com/LuaLS/luarocks-build-addon luarocks-build-lls-addon
cd luarocks-build-lls-addon

# create a project-scoped rocks tree
luarocks init

# install the current source in the nearest rocks tree
luarocks --lua-version=5.4 make

# install the current source in the user's rocks tree
# helpful for testing on local addons
luarocks --local --lua-version=5.4 make
```

## Testing

```sh
# LuaRocks expects all its source code (which includes this addon) to be
# written for Lua 5.4.
mkdir .luarocks
echo 'return "5.4"' > .luarocks/default-lua-version.lua
luarocks test

# report coverage
luarocks test -- -c
./luacov.report.html
```
