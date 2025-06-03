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
		local libraryDestination = dir.path(installDirectory, "library")
		print("Installing " .. librarySource .. " to " .. libraryDestination)

		assert(fs.make_dir(libraryDestination))
		assert(fs.copy_contents(librarySource, libraryDestination))
	end

	local configSource = dir.path(fs.current_dir(), "config.json")
	if fs.exists(configSource) then
		local configDestination = dir.path(installDirectory, "config.json")

		print("Installing " .. configSource .. " to " .. configDestination)
		assert(fs.copy(configSource, configDestination))

		-- also decode it and copy the settings into .luarc.json
		local config
		do
			local file = assert(io.open(configSource))
			local contents = file:read("a")
			file:close()
			config = json.decode(contents) --[[@as table]]
		end

		if not isJsonObject(config) then
			print("Root of 'config.json' is not an object, skipping")
		elseif config.settings then
			local luarcPath = dir.path(cfg.project_dir, ".luarc.json")
			print("Copying key 'settings' to " .. luarcPath)

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

			extend(luarc, config.settings)

			local contents = json.encode(luarc, { indent = 2 }) --[[@as string]]
			local file <close> = assert(io.open(luarcPath, "w"))
			file:write(contents)
		end
	end

	return true
end

return M
