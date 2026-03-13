package.preload["plugin.another"] = assert(load([[
return "another"

]], "plugin.another"))

package.preload["plugin.some"] = assert(load([[
return "some"

]], "plugin.some"))

local another = require("plugin.another")
local some = require("plugin.some")

return some .. " " .. another
