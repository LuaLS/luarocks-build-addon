package.preload["plugin.submodule"] = assert(load([=[
return [[
some text
]]

]=], "plugin.submodule"))

local submodule = require("plugin.submodule")

return submodule .. "!"
