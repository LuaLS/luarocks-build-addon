---@meta

---@class luarocks.core.Tree
---@field name string
---@field root string
---@field rocks_dir string?
---@field lua_dir string?
---@field lib_dir string?

---@class luarocks.core.cfg.cache
---@field luajit_version_checked boolean?
---@field luajit_version string?
---@field rocks_provided { [string]: string? }?

---@class luarocks.core.cfg.conf
---@field file string
---@field found boolean

---@class luarocks.core.cfg.UploadServer
---@field rsync string?
---@field http string?
---@field ftp string?
---@field sftp string?

---@class luarocks.core.cfg.external_map
---@field bin string | string[]
---@field lib string | string[]
---@field include string | string[]

---@class luarocks.core.cfg
---@field root_dir string | luarocks.core.Tree | nil
---@field rocks_dir string | nil
---@field rocks_subdir string
---@field lua_modules_path string
---@field lib_modules_path string
---@field aggressive_cache boolean | nil
---@field rocks_trees (string | luarocks.core.Tree)[]
---@field lua_version string
---@field deps_mode "one" | "all" | "none"
---@field deploy_bin_dir string
---@field deploy_lua_dir string
---@field deploy_lib_dir string
---@field lib_extension string
---@field local_cache string
---@field only_sources_from string | nil
---@field cache luarocks.core.cfg.cache
---@field variables { [string]: string? }
---@field rocks_provided luarocks.Rockspec[]
---@field home string
---@field arch string
---@field config_files.system luarocks.core.cfg.conf
---@field config_files.user luarocks.core.cfg.conf
---@field config_files.project luarocks.core.cfg.conf
---@field accept_unknown_fields boolean
---@field user_agent string
---@field connection_timeout number
---@field upload.server string
---@field upload.version string?
---@field upload.tool_version string
---@field upload.api_version string
---@field rocks_servers (string[] | string)[]
---@field disabled_servers { [string]: boolean }
---@field external_deps_patterns luarocks.core.cfg.external_map
---@field external_deps_subdirs luarocks.core.cfg.external_map
---@field runtime_external_deps_patterns luarocks.core.cfg.external_map
---@field runtime_external_deps_subdirs luarocks.core.cfg.external_map
---@field external_lib_extension string
---@field external_deps_dirs string[]
---@field hooks_enabled boolean
---@field wrap_bin_scripts boolean
---@field wrapper_suffix string
---@field no_manifest boolean
---@field accepted_build_types string[]
---@field gcc_rpath boolean?
---@field link_lua_explicitly boolean
---@field obj_extension string
---@field cmake_generator string?
---@field target_cpu string
---@field makefile string?
---@field make string?
---@field local_by_default boolean
---@field fs_use_modules boolean
---@field is_binary boolean?
---@field program_version string
---@field homeconfdir string?
---@field sysconfdir string?
---@field luajit_version string?
---@field lua_found boolean?
---@field project_dir string?
---@field verbose boolean?
---@field project_tree string?
---@field keep_other_versions boolean?
---@field export_path_separator string?
---used in luarocks-admin
---@field upload_server string?
---used in luarocks-admin
---@field upload_servers { [string]: luarocks.core.cfg.UploadServer? }?
---used in luarocks-admin
---@field upload_user string?
---used in luarocks-admin
---@field upload_password string?
local cfg = {}

---@param detected? { [string]: string }
---@param warning? fun(message: string)
---@return true? exit_ok, string? exit_err, string? exit_what
function cfg.init(detected, warning) end

function cfg.init_package_paths() end

---@param direction? "least-specific-first" | "most-specific-first"
function cfg.each_platform(direction) end

---@param platform string
---@return true?
function cfg.is_platform(platform) end

---@return string platforms
function cfg.print_platforms() end

---@param tree string | luarocks.core.Tree
---@return string LUA_PATH, string LUA_CPATH, string PATH
function cfg.package_paths(tree) end
