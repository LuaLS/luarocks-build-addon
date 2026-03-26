# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed

- `require("luarocks.build.lls-addon").LOADER_SOURCE` is no longer set when calling `getLoaderSource`.

## [v0.2.0-1]

### Added

- `plugin/` installs to the same directory as `library/` and `plugin.lua`
- Plugins can access LuaRocks dependencies. It prepends a plugin file called `lls-addon-loader.lua` that sets up the required paths.
- Installing a new version of a pre-existing addon removes old versions from the `.luarc.json`

## [v0.1.1-1]

### Fixed

- `library/` and `plugin.lua` install to the correct directory when built from a different directory.

## [v0.1.0-8]

### Fixed

- Try to fix deployment issues with rockspec and CD (7)

## [v0.1.0-7]

### Fixed

- Try to fix deployment issues with rockspec and CD (6)

## [v0.1.0-6]

### Fixed

- Try to fix deployment issues with rockspec and CD (5)

## [v0.1.0-5]

### Fixed

- Try to fix deployment issues with rockspec and CD (4)

## [v0.1.0-4]

### Fixed

- Try to fix deployment issues with rockspec and CD (3)

## [v0.1.0-3]

### Fixed

- Try to fix deployment issues with rockspec and CD (2)

## [v0.1.0-2]

### Fixed

- Try to fix deployment issues with rockspec and CD

## [v0.1.0-1]

### Added

- Initial public release. See the [README](https://github.com/LuaLS/luarocks-build-addon/tree/v0.1.0-1) for the initial feature set.
