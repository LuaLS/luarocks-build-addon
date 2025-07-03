local cfg = require("luarocks.core.cfg")
local fs = require("luarocks.fs")
local rockspecs = require("luarocks.rockspecs")

local json = require("luarocks.build.lls-addon.json-util")
local llsAddon = require("luarocks.build.lls-addon")
local log = require("luarocks.build.lls-addon.log")

local SEP = package.config:sub(1, 1)
local PATH_SEP = package.config:sub(3, 3)
local function path(...)
	return table.concat({ ... }, SEP)
end

---@return luarocks.rockspec
local function makeRockspec()
	local rockspec, msg = rockspecs.from_persisted_table("types-0.1-1.rockspec", {
		rockspec_format = "3.1",
		package = "test",
		version = "0.1-1",
		source = { url = "" },
		build = { type = "lls-addon" },
	}, --[[globals:]] {}, --[[quick:]] true)
	---@diagnostic disable-next-line: redundant-parameter
	assert.is_truthy(rockspec, msg)
	return rockspec --[[@as luarocks.rockspec]]
end

---@param t any
---@param newT any
---@return { [string]: luassert.spy }
local function stubAll(t, newT)
	for k, v in pairs(newT) do
		stub(t, k, v)
	end
	return t
end

---@param newStubs any
---@return { [string]: luassert.spy }
local function stubFs(newStubs)
	local stubs = {
		-- key = handler / return value
		copy = true,
		copy_contents = true,
		make_dir = true,
		exists = false,
	}

	for k, v in pairs(newStubs) do
		stubs[k] = v
	end

	return stubAll(fs, stubs)
end

---@param ... string
---@return fun(path: string): boolean
local function pathEquals(...)
	local paths = { ... }
	assert.are_not_equal(0, #paths)

	if #paths == 1 then
		local val = paths[1]
		return function(p)
			return p == val
		end
	end

	return function(p)
		for _, val in ipairs(paths) do
			if p == val then
				return true
			end
		end

		return false
	end
end

describe("#only lls-addon", function()
	describe("compileLuarc", function()
		lazy_setup(function()
			cfg.init()
			fs.init()
		end)

		before_each(function()
			mock(log, --[[stub:]] true)
		end)

		local compileLuarc = llsAddon.compileLuarc
		local installDir = path("fake", "path", "to", "rock")
		local currentDir = path("fake", "path", "to", "types")

		it("creates no luarc when nothing is added", function()
			local fs = stubFs({ current_dir = currentDir })

			local luarc = compileLuarc(installDir, nil)
			assert.is_nil(luarc)
			assert.stub(fs.copy).was.called(0)
			assert.stub(fs.copy_contents).was.called(0)
			assert.stub(fs.exists).was.called_with(path(currentDir, "library"))
			assert.stub(fs.exists).was.called_with(path(currentDir, "plugin.lua"))
			assert.stub(fs.exists).was.called_with(path(currentDir, "config.json"))
		end)

		it("works when given a library", function()
			local fs = stubFs({
				-- key = handler / return value
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, "library")),
			})

			local luarc = compileLuarc(installDir, nil)
			assert.are_same({ ["workspace.library"] = { path(installDir, "library") } }, luarc)
			assert.stub(fs.make_dir).was.called(1)
			assert.stub(fs.make_dir).was.called_with(path(installDir, "library"))
			assert.stub(fs.copy_contents).was.called(1)
			assert.stub(fs.copy_contents).was.called_with(path(currentDir, "library"), path(installDir, "library"))
			assert.stub(fs.copy).was.called(0)
		end)

		it("works when given a plugin", function()
			local stubFs = stubAll(fs, {
				-- key = handler / return value
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, "plugin.lua")),
			})

			local luarc = compileLuarc(installDir, nil)
			assert.are_same({ ["runtime.plugin"] = path(installDir, "plugin.lua") }, luarc)
			assert.stub(stubFs.copy).was.called(1)
			assert.stub(stubFs.copy).was.called_with(path(currentDir, "plugin.lua"), path(installDir, "plugin.lua"))
		end)

		it("works when given rockspec settings", function()
			stubFs({ current_dir = currentDir })

			local luarc = compileLuarc(installDir, --[[rockspecSettings:]] {
				["some.example"] = 42,
				another = {
					example = 100,
				},
			})
			assert.are_same({ ["some.example"] = 42, ["another.example"] = 100 }, luarc)
		end)

		it("errors when rockspec settings is not an object", function()
			stubFs({ currentDir = currentDir })

			assert.error(function()
				compileLuarc(installDir, { "some", "example" })
			end)
		end)

		it("works when given a config.json", function()
			stubFs({
				-- key = handler / return value
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, "config.json")),
			})
			local jsonRead = stub(json, "read", function()
				return json.object({
					settings = json.object({
						["Lua.some.example"] = 42,
						["Lua.another.example"] = 100,
					}),
				})
			end)

			local luarc = compileLuarc(installDir, nil)
			assert.are_same({ ["some.example"] = 42, ["another.example"] = 100 }, luarc)
			assert.stub(jsonRead).was.called(1)
			assert.stub(jsonRead).was.called_with(path(currentDir, "config.json"))
		end)

		it("errors when config.json is not an object", function()
			stubFs({
				-- key = handler / return value
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, "config.json")),
			})
			local jsonRead = stub(json, "read", function()
				return false
			end)

			assert.error(function()
				compileLuarc(installDir, nil)
			end)

			assert.stub(jsonRead).was.called(1)
			assert.stub(jsonRead).was.called_with(path(currentDir, "config.json"))
		end)

		it("errors when config.json's settings key is not an object", function()
			stubFs({
				-- key = handler / return value
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, "config.json")),
			})
			local jsonRead = stub(json, "read", function()
				return json.object({ settings = false })
			end)

			assert.error(function()
				compileLuarc(installDir, nil)
			end)

			assert.stub(jsonRead).was.called(1)
			assert.stub(jsonRead).was.called_with(path(currentDir, "config.json"))
		end)

		it("only copies from rockspec settings when also given config.json", function()
			stubFs({
				-- key = handler / return value
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, "config.json")),
			})
			local jsonRead = stub(json, "read", function(pathArg)
				return nil, "this should not be called"
			end)

			local luarc = compileLuarc(installDir, { ["different.example"] = 96 })

			assert.are_same({ ["different.example"] = 96 }, luarc)
			assert.stub(jsonRead).was.called(0)
		end)
	end)

	describe("findLuarcFiles", function()
		lazy_setup(function()
			cfg.init()
			fs.init()
		end)

		before_each(function()
			mock(log, --[[stub:]] true)
		end)

		local findLuarcFiles = llsAddon.findLuarcFiles
		local currentDir = path("fake", "path", "to", "types")

		it("gives .luarc.json when nothing is found", function()
			stubFs({ current_dir = currentDir, exists = false })

			local files = findLuarcFiles(currentDir, {})
			assert.are_same({ { type = "luarc", path = path(currentDir, ".luarc.json") } }, files)
		end)

		it("looks for a .luarc.json", function()
			stubFs({
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, ".luarc.json")),
			})

			local files = findLuarcFiles(currentDir, {})
			assert.are_same({ { type = "luarc", path = path(currentDir, ".luarc.json") } }, files)
		end)

		it("looks for .vscode/settings.json", function()
			stubFs({
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, {})
			assert.are_same(
				{ { type = "vscode settings", path = path(currentDir, ".vscode", "settings.json") } },
				files
			)
		end)

		it("prioritizes .luarc.json before .vscode/settings.json", function()
			stubFs({
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, {})
			assert.are_same({ { type = "luarc", path = path(currentDir, ".luarc.json") } }, files)
		end)

		it("prioritizes environment variables before looking in projectDir", function()
			stubFs({
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local luarcPaths = table.concat({
				path("fake", "different.json"),
				path("fake", "yet_another.json"),
			}, PATH_SEP)

			local vscSettingsPaths = table.concat({
				path("fake", "foo.json"),
				path("fake", "another.json"),
			}, PATH_SEP)

			local files = findLuarcFiles(currentDir, { VSCSETTINGSPATH = vscSettingsPaths, LUARCPATH = luarcPaths })

			assert.are_equal(4, #files)
			assert.contains({ type = "luarc", path = path("fake", "different.json") }, files)
			assert.contains({ type = "luarc", path = path("fake", "yet_another.json") }, files)
			assert.contains({ type = "vscode settings", path = path("fake", "foo.json") }, files)
			assert.contains({ type = "vscode settings", path = path("fake", "another.json") }, files)
		end)

		it("does not look in projectDir if environment variables are defined and empty", function()
			stubFs({
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, { VSCSETTINGSPATH = "", LUARCPATH = "" })
			assert.are_same({}, files)
		end)

		it("does not look in projectDir if environment variables are defined as ';'", function()
			stubFs({
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, { VSCSETTINGSPATH = ";", LUARCPATH = ";" })
			assert.are_same({}, files)
		end)

		it("does not look in projectDir if only VSCSETTINGSPATH is defined", function()
			stubFs({
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, { VSCSETTINGSPATH = "" })
			assert.are_same({}, files)
		end)

		it("does not look in projectDir if only LUARCPATH is defined", function()
			stubFs({
				current_dir = currentDir,
				exists = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, { LUARCPATH = "" })
			assert.are_same({}, files)
		end)
	end)
end)
