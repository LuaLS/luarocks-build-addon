---@class luarocks.Rockspec.build
---@field [string] any

---@class luarocks.Rockspec.query

---@class luarocks.Rockspec.description
---@field summary string
---@field detailed string
---@field homepage string
---@field issues_url string
---@field maintainer string
---@field license string
---@field labels string[]

---@class luarocks.Rockspec.source
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

---@class luarocks.Rockspec.test
---@field type string
---@field script string
---@field command string
---@field busted_executable string
---@field flags string[]

---@class luarocks.Rockspec.dependencies
---@field [number] string
---@field queries luarocks.Rockspec.query[]

---@class luarocks.Rockspec.hooks
---@field post_install string
---@field substituted_variables boolean

---@class luarocks.Rockspec.deploy
---@field wrap_bin_scripts boolean

---@class luarocks.Rockspec
---@field rockspec_format string
---@field name string -- not in the rockspec definition but used
---@field ["package"] string
---@field version string
---@field local_abs_filename string
---@field rocks_provided { [string]: string }
---@field source luarocks.Rockspec.source
---@field description luarocks.Rockspec.description
---@field build luarocks.Rockspec.build
---@field dependencies luarocks.Rockspec.dependencies
---@field build_dependencies luarocks.Rockspec.dependencies
---@field test_dependencies luarocks.Rockspec.dependencies
---@field supported_platforms string[]
---@field external_dependencies { [string]: { [string]: string } }
---@field variables { [string]: string }
---@field hooks luarocks.Rockspec.hooks
---@field test luarocks.Rockspec.test
---@field deploy luarocks.Rockspec.deploy
---@field format_is_at_least fun(self: luarocks.Rockspec, format: string): boolean
---@field type fun(self: luarocks.Rockspec): "rockspec"
