assert(type((...)) == "function", "attempt to require a plugin")

do
  local loaded = setmetatable({}, { __index = function() return false end })
  local preload = {}
  local oldRequire = require
  function require(path, ...)
    local loadedModule = loaded[path]
    if loadedModule ~= false then
      return loadedModule
    end

    local moduleLoader = preload[path]
    if not moduleLoader then
      return oldRequire(path, ...)
    end

    loadedModule = moduleLoader(path, ":preload:")
    loaded[path] = loadedModule
    return loadedModule
  end

  preload["plugin.submodule"] = assert(load([=[
return [[
some text
]]

]=], "plugin.submodule", "t"))

end

local submodule = require("plugin.submodule")

return submodule .. "!"
