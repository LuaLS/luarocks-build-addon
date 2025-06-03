local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local path = require("luarocks.path")

local M = {}

function M.run(rockspec)
	assert(rockspec:type() == "rockspec")

	local name = rockspec.package
	local version = rockspec.version

	local libraryDirectory = dir.path(fs.current_dir(), "library")
	local installDirectory = dir.path(path.install_dir(name, version), "library")
	assert(fs.make_dir(installDirectory))

	print("Building addon " .. name .. " @ " .. version)

	print("Installing " .. libraryDirectory .. " to " .. installDirectory)

	local success, error = fs.copy_contents(libraryDirectory, installDirectory)
	if not success then
		return false, "Failed to copy contents: " .. error
	end

	return true
end

return M
