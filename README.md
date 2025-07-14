# `luarocks-build-lls-addon`

A LuaRocks addon for installing [lua-language-server](https://github.com/LuaLS/lua-language-server) addons from a LuaRocks repository.

## Usage for End-users

End-users can manage addon installations using the LuaRocks CLI.

-   `luarocks install package-name` - add an addon named `package-name`
-   `luarocks remove package-name` - remove an addon named `package-name`
-   `luarocks doc package-name` - view information about an addon named `package-name`
-   etc.

Users can also browse addons online from https://luarocks.org/m/luacats.

### Variables

You can change the behavior of the installer by defining these variables in a `config-5.X.lua` file or on the command-line as `luarocks VAR=VALUE -- ...`

> [!NOTE]
> The path separator used in these examples is `;`, but may change based on `package.config`, a.k.a. the operating system.

-   `LLSADDON_LUARCPATH="$path1;$path2;..."` - a list of paths indicating which `.luarc.json`-style files to modify when installing the addon.
-   `LLSADDON_VSCSETTINGSPATH="$path1;$path2;..."` - a list of paths indicating which `.vscode/settings.json`-style files to modify when installing the addon.
    -   If at least one of the above variables is set to `""` and the other is unset, no config files will be modified by the build process.
-   `LLSADDON_ABSPATH` - If defined as none of `"false"`, `"no"`, `"off"` or `"0"`, indicates any paths added to the config file should be absolute paths, rather than relative ones.

## Usage for Addon Developers

Addon developers can should have a similar [addon file structure](https://luals.github.io/wiki/addons/#addon-anatomy) as an old-style addon, except the `config.json` can optionally be replaced with a rockspec file.

Addon developers can define their addon using a rockspec file with the following block:

```lua
build = {
    type = "lls-addon",
    -- build rules...
}
```

Addons can be developed in a similar way to any other rock. Dependencies to other addons can be specified in the `dependencies` table, and general information can be written in the `description` table.

### Build Rules

-   **build.settings** (table) - Contains a key-value dictionary of [settings](https://luals.github.io/wiki/settings/) to be merged into the LuaLS configuration. The `config.json` file will be ignored if this entry exists.

### Example

Here is an example rockspec for [carsakiller's CC Tweaked type definitions](https://gitlab.com/carsakiller/cc-tweaked-documentation):

```lua
-- ./cats-cc-tweaked-1.0.0-1.rockspec
rockspec_format = "3.0"
package = "cats-cc-tweaked"
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

# create a project-scoped rocks directory
luarocks init

# install the current source in the nearest rocks directory
luarocks --lua-version=5.4 make

# install the current source in the user's rocks directory
# helpful for installing local addons as rocks
luarocks --local --lua-version=5.4 make
```

## Testing

```sh
# the build fails if this is not set to 5.4, I don't know why
mkdir .luarocks
echo 'return "5.4"' > .luarocks/default-lua-version.lua
luarocks test

# report coverage
luarocks test -- -c
./luacov.report.html
```
