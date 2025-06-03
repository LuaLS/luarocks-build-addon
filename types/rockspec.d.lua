---@class luarocks.rockspec.build

---@class luarocks.rockspec.query

---@class luarocks.rockspec.description
---@field summary string
---@field detailed string
---@field homepage string
---@field issues_url string
---@field maintainer string
---@field license string
---@field labels string[]

---@class luarocks.rockspec.source
---@field url string
---@field module string
---@field pathname string
---@field tag string
---@field md5 string
---@field file string
---@field dir string
---@field branch string
---@field cvs_tag string
---@field cvs_module string
---@field protocol string -- not in the rockspec definition but used
---@field dir_set boolean
---@field identifier string

---@class luarocks.rockspec.test
---@field type string
---@field script string
---@field command string
---@field busted_executable string
---@field flags string[]

---@class luarocks.rockspec.dependencies
---@field [number] string
---@field queries luarocks.rockspec.query[]

---@class luarocks.rockspec.hooks
---@field post_install string
---@field substituted_variables boolean

---@class luarocks.rockspec.deploy
---@field wrap_bin_scripts boolean

---@class luarocks.rockspec
---@field rockspec_format string
---@field name string -- not in the rockspec definition but used
---@field package string
---@field version string
---@field local_abs_filename string
---@field rocks_provided { [string]: string }
---@field source luarocks.rockspec.source
---@field description luarocks.rockspec.description
---@field build luarocks.rockspec.build
---@field dependencies luarocks.rockspec.dependencies
---@field build_dependencies luarocks.rockspec.dependencies
---@field test_dependencies luarocks.rockspec.dependencies
---@field supported_platforms string[]
---@field external_dependencies { [string]: { [string]: string } }
---@field variables { [string]: string }
---@field hooks luarocks.rockspec.hooks
---@field test luarocks.rockspec.test
---@field deploy luarocks.rockspec.deploy
---@field format_is_at_least fun(self: luarocks.rockspec, format: string): boolean
---@field type fun(self: luarocks.rockspec): "rockspec"