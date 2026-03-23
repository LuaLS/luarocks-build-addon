---@meta

---@class luarocks.tools.patch
local patch = {}

---@class luarocks.tools.patch.Lineends
---@field lf integer
---@field crlf integer
---@field cr integer

---@class luarocks.tools.patch.Hunk
---@field startsrc integer
---@field linessrc integer
---@field starttgt integer
---@field linestgt integer
---@field invalid boolean
---@field text string[]

---@class luarocks.tools.patch.Files
---@field source string[]
---@field target string[]
---@field epoch boolean[]
---@field hunks luarocks.tools.patch.Hunk[][]
---@field fileends luarocks.tools.patch.Lineends[]
---@field hunkends luarocks.tools.patch.Lineends[]

---@param the_patch luarocks.tools.patch.Files
---@param strip? integer
---@param create_delete? boolean
---@return boolean? ok
function patch.apply_patch(the_patch, strip, create_delete) end

return patch
