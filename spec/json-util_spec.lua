local json = require("luarocks.build.lls-addon.json-util")

local SEP = package.config:sub(1, 1)
local function path(...)
	return table.concat({ ... }, SEP)
end

describe("json-util", function()
	describe("encode", function()
		it("turns empty objects into object strings", function()
			assert.are_equal("{}", json.encode(json.object({})))
		end)
		it("turns empty arrays into array strings", function()
			assert.are_equal("[]", json.encode(json.array({})))
		end)
	end)

	describe("coerce", function()
		it("leaves non-tables alone", function()
			local function fun() end
			local co = coroutine.create(fun)
			assert.is_nil(json.coerce(nil))
			assert.is_false(json.coerce(false))
			assert.are_equal(54, json.coerce(54))
			assert.are_equal("a string", json.coerce("a string"))
			assert.are_equal(fun, json.coerce(fun))
			assert.are_equal(co, json.coerce(co))
		end)

		it("views tables with length > 0 as arrays", function()
			assert.are_equal(json.arrayMt, getmetatable(json.coerce({ 1, 2, 3 })))
		end)

		it("views tables with length <= 0 as objects", function()
			assert.are_equal(json.objectMt, getmetatable(json.coerce({})))
		end)
	end)

	describe("write", function()
		---@return file*
		local function getFileStub()
			local writeSpy = spy(function(self)
				return self
			end)
			local closeSpy = spy()
			return setmetatable({
				write = writeSpy,
				close = closeSpy,
			}, {
				__close = function(self)
					self:close()
				end,
			})
		end

		it("works", function()
			local fileStub = getFileStub()
			local writeSpy = fileStub.write --[[@as luassert.spy]]
			local closeSpy = fileStub.close --[[@as luassert.spy]]
			local openStub = stub(json, "openFile", fileStub)
			json.write(path("fake", "path"), json.object({}))
			assert.stub(openStub).was.called(1)
			assert.stub(openStub).was.called_with(path("fake", "path"), "w")
			assert.spy(writeSpy).was.called(1)
			assert.spy(writeSpy).was.called_with(fileStub, "{\n}")
			assert.spy(closeSpy).was.called(1)
			assert.spy(closeSpy).was.called_with(fileStub)
		end)

		it("can sort keys with the sortKeys option", function()
			local fileStub = getFileStub()
			local openStub = stub(json, "openFile", fileStub)
			json.write(path("fake", "path"), json.object({ a = true, b = true, c = true }), { sortKeys = true })
			assert.stub(openStub).was.called(1)
		end)
	end)
end)
