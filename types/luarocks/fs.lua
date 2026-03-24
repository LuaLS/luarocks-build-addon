---@meta

---@class luarocks.fs
local fs = {}

---patch io.popen and os.execute to display commands in verbose mode
function fs.verbose() end

function fs.init() end

---Change directory to root.
---
---allows leaving a directory (e.g. for deleting it) in a crossplatform way
---@return boolean
function fs.change_dir_to_root() end

---Test if `pathname` is a directory.
---@param pathname string -- pathname to test
---@return boolean is_dir -- `true` if it is a directory, `false` otherwise
function fs.is_dir(pathname) end

---Iterate over the contents of a directory.
---@param at? string -- directory to list (will be the current directory if none is given)
---@return (fun(): string?) dir -- an iterator function suitable for use with the `for` statement
function fs.dir(at) end

---Create a directory if it does not already exist.
---
---If any of the higher levels in the path name do not exist too, they are
---created as well.
---@param directory string -- pathname of directory to create
---@return boolean? ok, string? err -- `true` on success or `false, error message` on failure
function fs.make_dir(directory) end

---Test if pathname is a regular file.
---@param pathname string
---@return boolean is_file -- `true` if it is a file, `false` otherwise
function fs.is_file(pathname) end

---Obtain the current directory.
---
---uses the module's internal dir stack
---@return string current_dir -- the absolute pathname of the current directory
function fs.current_dir() end

---List the contents of a directory.
---@param at? string -- directory to list (will be the current directory if none is given)
---@return string[] -- an array of strings with the filenames representing the contents of a directory
function fs.list_dir(at) end

---Delete a file or a directory and all its contents.
---
---For safety, this only accepts absolute paths.
---@param arg string -- pathname of source
function fs.delete(arg) end

---Checks if the given tool is available.
---
---The tool is executed using a flag, usually just to ask its version.
---@param tool_cmd string -- The command to be used to check the tool's presence (e.g. hg in case of Mercurial)
---@param tool_name string -- The actual name of the tool (e.g. Mercurial)
---@return boolean ok, string? err
function fs.is_tool_available(tool_cmd, tool_name) end

---Run the given command, quoting its arguments.
---
---The command is executed in the current directory in the dir stack.
---@param command string -- The command to be executed. No quoting/escaping is applied.
---@param ... string -- strings containing additional arguments, which are quoted
---@return boolean ok -- `true` if command succeeds (status code 0), `false` otherwise
function fs.execute(command, ...) end

---Create a temporary directory.
---@param name_pattern string -- name pattern to use for avoiding conflicts when creating temporary directory
---@return string? temp_dir, string? err -- name of temporary directory or `nil, err` on failure
function fs.make_temp_dir(name_pattern) end

---Change the current directory.
---
---Uses the module's internal dir stack. This does not have exact semantics of
---`chdir`, as it does not handle errors the same way, but works well for our
---purposes for now.
---@param d string
---@return boolean ok, string? err
function fs.change_dir(d) end

---Change working directory to the previous in the dir stack.
---@return boolean -- `true` if a pop occurred, `false` if the stack was empty
function fs.pop_dir() end

---@param tooltype "downloader" | "md5checker"
---@return string? tool_name, string tool_command_or_err
function fs.which_tool(tooltype) end

---@return string
function fs.tmpname() end

---Run the given command.
---
---The command is executed in the current directory in the dir stack.
---@param cmd string -- No quoting/escaping is applied to the command.
---@return boolean -- `true` if command succeeds (status code 0), `false` otherwise
function fs.execute_string(cmd) end

---Quote argument for shell processing.
---
---fixes paths and adds double quotes and escapes on Windows
---
---adds single quotes and escapes on Unix
---@param unquoted_arg string
---@return string quoted_arg
function fs.Q(unquoted_arg) end

---Download a remote file.
---
---This function attempts to detect the resulting local filename of the remote
---file as the basename of the URL; if that is not correct (due to a
---redirection, for example), the local filename can be given explicitly as the
---second argument.
---
---In case of success:
---- \* name
---- `nil`
---- `nil`
---- \* `true` if the file was retrieved from local cache, `nil` otherwise
---
---In case of failure:
---- `nil`
---- \* error message
---- \* error code
---@param url string -- URL to be fetched
---@param filename? string -- name of the downloaded file
---@param cache? boolean
---@return string filename
---@return string? err
---@return string? err_code
---@return boolean? is_from_cache
function fs.download(url, filename, cache) end

---@param filename string
---@param mode "read" | "exec"
---@param scope "user" | "all"
---@return boolean ok, string? err
function fs.set_permissions(filename, mode, scope) end

---Return an absolute pathname from a potentially relative one.
---@param pathname string -- pathname to convert
---@param relative_to? string -- path to prepend when making `pathname` absolute, or the current dir in the dir stack if not given
---@return string absolute
function fs.absolute_name(pathname, relative_to) end

---@param file string
---@param time integer | osdateparam
function fs.set_time(file, time) end

---Recursively scan the contents of a directory.
---@param at? string -- directory to scan (will be the current directory if none is given)
---@return string[] contents -- an array of strings with the filenames representing the contents of a directory
function fs.find(at) end

---@param fn fun(content: string): (content: string?, err: string?)
---@param input_filename string
---@param output_filename string
---@return true? ok, string? err
function fs.filter_file(fn, input_filename, output_filename) end

---@param filename string
---@return integer
function fs.file_age(filename) end

---Test for existence of a file.
---@param filename string
---@return boolean exists -- `true` if file exists, `false` otherwise
function fs.exists(filename) end

---@class luarocks.fs.lock

---@param dirname string
---@param force? boolean
---@return luarocks.fs.lock
function fs.lock_access(dirname, force) end

---@param lock luarocks.fs.lock
function fs.unlock_access(lock) end

---Copy a file.
---@param src string -- pathname of source
---@param dest string -- pathname of destination
---@param perms? "read" | "exec" -- permissions for destination file or `nil` to use the source file permissions
---@return boolean ok, string? err -- `true` on success, `false, err` on failure
function fs.copy(src, dest, perms) end

---Unpack an archive.
---
---Extract the contents of an archive, detecting its format by filename
---extension.
---@param archive string -- filename of archive
---@return boolean ok, string? err -- `true` on success, `false` and an error message on failure
function fs.unpack_archive(archive) end

---Uncompress files from a .zip archive.
---@param zipfile string -- pathname of .zip archive to be extracted from
---@return boolean ok, string? err -- `true` on success, `false` and an error message on failure.
function fs.unzip(zipfile) end

---Check the MD5 checksum for a file.
---@param file string -- the file to be checked
---@param md5sum string -- the string with the expected MD5 checksum
---@return boolean matches, string? msg -- `true` if the MD5 checksum for 'file' equals 'md5sum', `false, msg` if not; or if it could not perform the check for any reason.
function fs.check_md5(file, md5sum) end

---Adds prefix to command to make it run from a directory.
---@param directory string -- path to a directory
---@param cmd string -- a command-line string
---@param exit_on_error? boolean -- exits immediately if entering the directory failed; defaults to `false` on Windows; always `true` on Unix
---@return string cmd_prefixed
function fs.command_at(directory, cmd, exit_on_error) end

---Check if a file (typically inside path.bin_dir) is an actual binary or a Lua
---wrapper.
---
---on Windows, does _not_ interact with the filesystem and only checks if the
---name would refer to a binary assuming it exists.
---@param filename string
---@return boolean is_actual_binary -- returns `true` if file is an actual binary (or if it couldn't check) or `false` if it is a Lua wrapper
function fs.is_actual_binary(filename) end

---Remove a directory if it is empty, and keep removing up to ten parent
---directories until a non-empty directory is encountered.
---@param d string -- pathname of directory to remove
function fs.remove_dir_tree_if_empty(d) end

---Create a wrapper to make a script executable from the command-line.
---@param script string --  pathname of script to be made executable
---@param target string -- wrapper target pathname (without wrapper suffix)
---@param deps_mode "one" | "all" | "order" | "none"
---@param name string -- rock name to be used in loader context
---@param version string -- rock version to be used in loader context
---@param ... string -- extra arguments passed to the script
function fs.wrap_script(script, target, deps_mode, name, version, ...) end

---Check whether a file is a Lua script.
---
---When the file can be successfully compiled by the configured Lua interpreter,
---it's considered to be a valid Lua file.
---@param filename string
---@return boolean is_lua -- `true` if it is a Lua script, `false` otherwise
function fs.is_lua(filename) end

---@param filename string
---@param dest string\
---@return boolean? ok, string? err
function fs.copy_binary(filename, dest) end

---Move a file.
---@param src string -- pathname of source
---@param dest string -- pathname of destination
---@param perms? "read" | "exec" -- permissions for destination or `nil` to use the source file permissions
---@return boolean ok, string? err -- `true` on success, `false, err` on failure
function fs.move(src, dest, perms) end

---Move a file on top of the other.
---
---The new file ceases to exist under its original name, and takes over the name
---of the old file.
---
---On Unix, this is done through a single rename operation. On Windows, this is
---done by removing the original file and renaming the new file to its original
---name.
---@param old_file string -- The name of the original file, which will be the new name of new_file
---@param new_file string -- The name of the new file, which will replace old_file
---@return boolean? ok, string? err -- `true` if succeeded, or `false` and an error message
function fs.replace_file(old_file, new_file) end

---Get the MD5 checksum for a file.
---@param file string -- the file to be computed
---@return string? md5sum, string? err -- the MD5 checksum or `nil, err`
function fs.get_md5(file) end

---Apply a patch.
---@param patch_name string -- the filename of the patch
---@param patch_data string -- the actual patch as a string
---@param create_delete boolean -- support creating and deleting files in a patch
---@return boolean? ok, string? err
function fs.apply_patch(patch_name, patch_data, create_delete) end

---Recursively copy the contents of a directory.
---@param src string -- pathname of source
---@param dest string -- pathname of destination
---@param perms? "read" | "exec" -- optional permissions
---@return boolean ok, string? err -- `true` on success, `false, err` on failure
function fs.copy_contents(src, dest, perms) end

---Remove a directory if it is empty.
---@param d string -- pathname of directory to remove
function fs.remove_dir_if_empty(d) end

---Execute a command with the given environment variables.
---@param env { [string]: string }
---@param command string
---@param ... string -- command arguments
---@return boolean -- `true` if command succeeds (status code 0), `false` otherwise
function fs.execute_env(env, command, ...) end

---Compress files in a .zip archive.
---@param zipfile string -- pathname of .zip archive to be created
---@param ... string -- Filenames to be stored in the archive
---@return boolean? ok, string? err -- `true` on success, `false, err` on failure
function fs.zip(zipfile, ...) end

---@return boolean is_superuser
function fs.is_superuser() end

---List the Lua modules at a specific require path.
---
---eg. `modules("luarocks.cmd")` would return a list of all LuaRocks command
---modules, in the current Lua path.
---@param at? string
---@return string[] modules
function fs.modules(at) end

---@return string system_cache_dir
function fs.system_cache_dir() end

---Check if user has write permissions for the command.
---
---assumes the configuration variables under `cfg` have been previously set up
---
---@param args table -- the `args` table passed to `run()` drivers.
---@return boolean? ok, string? err
function fs.check_command_permissions(args) end

---Test if file/dir is writable.
---
---Warning: testing if a file/dir is writable does not guarantee that it will
---remain writable and therefore it is no replacement for checking the result of
---subsequent operations.
---@param file string -- filename to test
---@return boolean is_writable -- `true` if file is writable, `false` otherwise
function fs.is_writable(file) end

---@param url string
---@return boolean ok -- `true` if browser command succeeds, `false` otherwise
function fs.browser(url) end

---Annotate command string for execution with quiet stderr.
---@param cmd string
---@return string quiet_cmd
function fs.quiet_stderr(cmd) end

---Create a command string that sets `var` to `val`.
---@param var string
---@param val string
---@return string export_cmd
function fs.export_cmd(var, val) end

return fs
