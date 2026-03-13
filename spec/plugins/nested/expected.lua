package.preload["plugin.some"] = assert(load([[
return "some"

]], "plugin.some"))

package.preload["plugin.subplugin.another"] = assert(load([[
return "another"

]], "plugin.subplugin.another"))

local another = require("plugin.subplugin.another")
local some = require("plugin.some")

return some .. " " .. another
