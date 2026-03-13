local rockspecs = require("luarocks.rockspecs")

---@class lls-addon.spec.make-rockspec
---@overload fun(rockspecEntries?: { [string]: any }): luarocks.Rockspec
local makeRockspec = {
	---@type string
	defaultPackage = "test",
	---@type string
	defaultVersion = "0.1-1",
}

---@param rockspecEntries? { [string]: any }
---@return luarocks.Rockspec
function makeRockspec.make(rockspecEntries)
	local values = {
		rockspec_format = "3.1",
		package = makeRockspec.defaultPackage,
		version = makeRockspec.defaultVersion,
		source = { url = "" },
		build = { type = "lls-addon" },
	}

	if rockspecEntries then
		for k, v in pairs(rockspecEntries) do
			values[k] = v
		end
	end

	local filename = values.package .. "-" .. values.version .. ".rockspec"

	local rockspec, msg = rockspecs.from_persisted_table(filename, values, --[[globals:]] {}, --[[quick:]] true)
	assert(rockspec, msg)
	return rockspec --[[@as luarocks.Rockspec]]
end

setmetatable(makeRockspec --[[@as table]], {
	__call = function(self, ...)
		return self.make(...)
	end,
})

return makeRockspec
