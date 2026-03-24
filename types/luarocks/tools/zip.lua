---@meta

---@class luarocks.tools.zip
local zip = {}

---Uncompress files from a .zip archive.
---@param zipfile string -- pathname of .zip archive to be extracted from
---@return true ok -- `true` on success, `false` and an error message on failure.
---@overload fun(zipfile: string): (ok: false, err: string)
function zip.unzip(zipfile) end

---Compress files in a .zip archive.
---@param zipfile string -- pathname of .zip archive to be created
---@param ... string -- Filenames to be stored in the archive
---@return boolean? ok, string? err -- `true` on success, `false, err` on failure
function zip.zip(zipfile, ...) end

return zip
