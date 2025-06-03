local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local path = require("luarocks.path")
local cfg = require("luarocks.core.cfg")
local json = require("luarocks.vendor.dkjson")

local M = {}

local function deepEqual(a, b)
  if type(a) == "table" and type(b) == "table" then
    for k, v in pairs(a) do
      if b[k] ~= v then
        return false
      end
    end
    return true
  else
    return a == b
  end
end

local function contains(array, value)
  for _, v in ipairs(array) do
    if deepEqual(v, value) then
      return true
    end
  end
  return false
end

local function extend(old, new)
  if type(old) == "table" and type(new) == "table" then
    if #old > 0 and #new > 0 then -- treat arrays like sets
      for _, v in ipairs(new) do
        if not contains(old, v) then
          table.insert(old, v)
        end
      end
    else
      for k, v in pairs(new) do
        old[k] = extend(old[k], v)
      end
    end
    return old
  else
    return new
  end
end

local function isJsonObject(value)
	if type(value) ~= "table" then
		return false
	end

	local mt = getmetatable(value)
	return mt == nil or mt.__jsontype == "object"
end

---@param luarcPath string
---@return { [string]: any }
local function readLuarc(luarcPath)
	local luarc ---@type table
	if fs.exists(luarcPath) then
		print("Found " .. luarcPath)
		local file <close> = assert(io.open(luarcPath, "r"))
		local contents = file:read("a")
		luarc = json.decode(contents) --[[@as table]]
		if not isJsonObject(luarc) then
			error("Expected root of '.luarc.json' to be an object")
		end
	else
		print(luarcPath .. " not found, generating...")
		luarc = {}
	end

	return luarc
end

---@param keyorder string[]
---@param obj { [string]: any }
local function getRecursiveKeys(keyorder, obj)
	for k, v in pairs(obj) do
		table.insert(keyorder, k)
		if type(v) == "table" and #v <= 0 then
			getRecursiveKeys(keyorder, v)
		end
	end
end

---@param luarc { [string]: any }
---@param luarcPath string
local function writeLuarc(luarc, luarcPath)
	local keyorder = {} ---@type string[]
	getRecursiveKeys(keyorder, luarc)
	table.sort(keyorder)
	local contents = json.encode(luarc, { indent = 2, keyorder = keyorder }) --[[@as string]]
	local file <close> = assert(io.open(luarcPath, "w"))
	file:write(contents)
end

---@param source string
---@param luarc table
---@param luarcPath string
local function copyConfigSettings(source, luarc, luarcPath)
	-- also decode it and copy the settings into .luarc.json
	local config
	do
		local file = assert(io.open(source))
		local contents = file:read("a")
		file:close()
		config = json.decode(contents) --[[@as table]]
	end

	if not isJsonObject(config) then
		print("Root of 'config.json' is not an object, skipping")
		return
	end

	local settings = config.settings ---@type { [string]: any }
	if not isJsonObject(settings) then
		print("key 'settings' of " .. source .. " is not an object, skipping")
		return
	end

	print("Merging 'settings' object into " .. luarcPath)
	local settingsNoPrefix = {} ---@type { [string]: any }
	for k, v in pairs(settings) do
		local newK = k:match("^Lua%.(.*)$")
		settingsNoPrefix[newK] = v
	end

	extend(luarc, settingsNoPrefix)
end

local function copyFile(source, destination)
	print("Installing " .. source .. " to " .. destination)
	assert(fs.copy(source, destination))
end

---@param source string
---@param destination string
local function copyDirectory(source, destination)
	print("Installing " .. source .. " to " .. destination)

	assert(fs.make_dir(destination))
	assert(fs.copy_contents(source, destination))
end

---@param rockspec luarocks.rockspec
---@return boolean?, string?
function M.run(rockspec)
	assert(rockspec:type() == "rockspec")

	local name = rockspec.package
	local version = rockspec.version

	print("Building addon " .. name .. " @ " .. version)

	local installDirectory = path.install_dir(name, version)

	local librarySource = dir.path(fs.current_dir(), "library")
	if fs.exists(librarySource) then
		copyDirectory(librarySource, dir.path(installDirectory, "library"))
	end

	local luarcPath = dir.path(cfg.project_dir, ".luarc.json")

	local luarc ---@type table

	local pluginSource = dir.path(fs.current_dir(), "plugin.lua")
	if fs.exists(pluginSource) then
		local pluginDestination = dir.path(installDirectory, "plugin.lua")
		copyFile(pluginSource, pluginDestination)

		-- also set 'runtime.plugin' in .luarc.json
		luarc = luarc or readLuarc(luarcPath)
		luarc["runtime.plugin"] = pluginDestination
	end

	local configSource = dir.path(fs.current_dir(), "config.json")
	if fs.exists(configSource) then
		copyFile(configSource, dir.path(installDirectory, "config.json"))

		-- also merge 'settings' from 'config.json' into .luarc.json
		luarc = luarc or readLuarc(luarcPath)
		copyConfigSettings(configSource, luarc, luarcPath)
	end

	if luarc then
		writeLuarc(luarc, luarcPath)
	end

	return true
end

return M
