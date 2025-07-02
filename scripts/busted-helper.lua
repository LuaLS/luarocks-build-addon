local luassert = require("luassert") ---@type luassert
local match = require("luassert.match") ---@type luassert.match
local say = require("say")

assert(os.execute("luarocks --local --lua-version=5.4 make"))

local function contains(state, arguments)
	assert(#arguments >= 2, "provide at least 2 arguments to 'contains'")
	local value, array, message = table.unpack(arguments)
	arguments[1], arguments[2] = arguments[2], arguments[1]
	if message ~= nil then
		state.failure_message = message
	end
	luassert.is_table(array)
	local sameAsValue = match.same(value)

	for _, v in ipairs(array) do
		if sameAsValue(v) then
			return true
		end
	end

	return false
end

say:set("assertion.contains.positive", "expected array to contain value:\npassed in:\n%s\nexpected:\n%s")
say:set("assertion.contains.negative", "did not expect array to contain value:\npassed in:\n%s\ndid not expect:\n%s")
luassert:register("assertion", "contains", contains, "assertion.contains.positive", "assertion.contains.negative")
