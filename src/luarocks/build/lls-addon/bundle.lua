local dir = require("luarocks.dir")
local fs = require("luarocks.fs")

local log = require("luarocks.build.lls-addon.log")

local OVERRIDE_REQUIRE = [[
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
  end]]

local PRELOAD_FORMAT = '  preload["%s"] = assert(load([%s[\n%s\n]%s], "%s", "t"))'

local OVERRIDE_REQUIRE_END = "end"

local function assertContext(context, ...)
	-- luacov: disable
	local s, msg = ...
	if not s then
		error(context .. ": " .. msg)
	end
	return ...
	-- luacov: enable
end

---@param path string
---@param moduleName string
---@return string
local function formatPreloadFile(path, moduleName)
	log.info("adding " .. moduleName .. " to bundle...")
	local f = assertContext("when opening bundled file", io.open(path, "r"))
	local text = assertContext("when reading from bundled file", f:read("a"))

	local maxChainEqs = -1
	for chain in string.gmatch(text, "%](%=*)%]") do
		maxChainEqs = math.max(maxChainEqs, string.len(chain))
	end

	local chainedEqs = string.rep("=", maxChainEqs + 1)
	return string.format(PRELOAD_FORMAT, moduleName, chainedEqs, text, chainedEqs, moduleName)
end

---@param strings string[]
---@param modulePath string[]
---@param dirName string
local function addDirectory(strings, modulePath, dirName)
	fs.change_dir(dirName)
	table.insert(modulePath, dirName)
	for entry in fs.dir(".") do
		if fs.is_file(entry) then
			local filename = string.match(entry, "^([^%.]+)%.lua$")
			if filename then
				table.insert(modulePath, filename)
				table.insert(
					strings,
					formatPreloadFile(dir.path(fs.current_dir(), entry), table.concat(modulePath, "."))
				)
				table.remove(modulePath)
			end
		elseif fs.is_dir(entry) then
			addDirectory(strings, modulePath, entry)
		end
	end
	table.remove(modulePath)
	fs.pop_dir()
end

---takes the `filename.lua` and `filename/` in the current directory and bundles
---it into one file using a technique I saw in a blog
---
---Source: https://sowophie.io/blog/lua-bundler.html
---@param filename string
---@param destination string
local function bundle(filename, destination)
	local strings = {} ---@type string[]
	if fs.is_dir(dir.path(fs.current_dir(), filename)) then
		log.info("found bundled files directory at " .. filename .. "/, adding to bundle...")
		table.insert(strings, OVERRIDE_REQUIRE)
		addDirectory(strings, {}, filename)
		table.insert(strings, OVERRIDE_REQUIRE_END)
	end

	log.info("adding main file " .. filename .. ".lua to bundle...")
	local mainFile =
		assertContext("when opening main file", io.open(dir.path(fs.current_dir(), filename .. ".lua"), "r")) --[[@as file*]]
	local text = assertContext("when reading from main file", mainFile:read("a"))
	table.insert(strings, text)
	assertContext("when closing main file", mainFile:close())

	log.info("sending bundled file to '" .. destination .. "'...")
	local destinationDir = dir.dir_name(destination)
	fs.make_dir(destinationDir)
	local destinationFile = assertContext("when opening destination file", io.open(destination, "w")) --[[@as file*]]
	assertContext("when writing to destination file", destinationFile:write(table.concat(strings, "\n\n")))
	assertContext("when closing destination file", destinationFile:close())
end

return bundle
