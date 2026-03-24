local cfg = require("luarocks.core.cfg")
local fs = require("luarocks.fs") --[[@as luarocks.fs]]

local pathMod = require("luarocks.path") --[[@as luarocks.path]]

local json = require("luarocks.build.lls-addon.json-util")
local llsAddon = require("luarocks.build.lls-addon")
local log = require("luarocks.build.lls-addon.log")

local makeRockspec = require("spec.util.make-rockspec")

local SEP = package.config:sub(1, 1)
local PATH_SEP = package.config:sub(3, 3)

---@param ... string | number
---@return string
local function path(...)
	return table.concat({ ... }, SEP)
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
		is_dir = false,
		is_file = false,
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

describe("lls-addon", function()
	local PACKAGE = makeRockspec.defaultPackage --[[@as "test"]]
	local VERSION = makeRockspec.defaultVersion --[[@as "0.1-1"]]

	local CURRENT_DIR = path("fake", "path", "to", "types") --[[@as "fake/path/to/types"]]
	local ROCKS_DIR = path("fake", "path", "to", "rocks") --[[@as "fake/path/to/rocks"]]

	---@param package string
	---@param version string
	---@return string
	local function installDir(package, version)
		return path("lua_modules", "lib", "luarocks", "rocks-5.4", package, version)
	end
	local INSTALL_DIR = installDir(PACKAGE, VERSION) --[[@as "lua_modules/lib/luarocks/rocks-5.4/test/0.1-1"]]
	local LUA_DIR = path("lua_modules", "share", "lua", "5.4") --[[@as "lua_modules/share/lua/5.4"]]

	local LOADER_SOURCE = path("fake", "path", "to", "lls-addon-loader.lua")
	stub(llsAddon, "getLoaderSource", LOADER_SOURCE)

	lazy_setup(function()
		cfg.init()
		fs.init()
		pathMod.use_tree(path(ROCKS_DIR, "lua_modules"))
	end)

	describe("compileLuarc", function()
		do
			local logMock
			before_each(function()
				logMock = mock(log, --[[stub:]] true)
			end)
			after_each(function()
				mock.revert(logMock)
			end)
		end

		local compileLuarc = llsAddon.compileLuarc
		it("creates no luarc when nothing is added", function()
			local fs = stubFs({ current_dir = CURRENT_DIR })

			local rockspec = makeRockspec()

			local configEntries, installEntries = compileLuarc(rockspec, {})
			assert.are_equal(0, #configEntries)
			assert.are_equal(0, #installEntries)
			assert.stub(fs.copy).was.called(0)
			assert.stub(fs.copy_contents).was.called(0)
			assert.stub(fs.is_dir).was.called_with(path(CURRENT_DIR, "library"))
			assert.stub(fs.is_file).was.called_with(path(CURRENT_DIR, "plugin.lua"))
			assert.stub(fs.is_file).was.called_with(path(CURRENT_DIR, "config.json"))
		end)

		it("works when given a library", function()
			stubFs({
				-- key = handler / return value
				current_dir = CURRENT_DIR,
				is_dir = pathEquals(path(CURRENT_DIR, "library")),
			})
			local configEntries, installEntries = compileLuarc(makeRockspec(), {})
			assert.are_same({
				{
					action = "append",
					dedup = true,
					key = "workspace.library",
					value = path(ROCKS_DIR, INSTALL_DIR, "library"),
				} --[[@as lls-addon.config-entry.append]],
			}, configEntries)
			assert.are_same({
				{
					type = "directory",
					source = path(CURRENT_DIR, "library"),
					destination = path(ROCKS_DIR, INSTALL_DIR, "library"),
				},
			}, installEntries)
		end)

		it("works when given a plugin", function()
			stubFs({
				-- key = handler / return value
				current_dir = CURRENT_DIR,
				is_file = pathEquals(path(CURRENT_DIR, "plugin.lua")),
			})

			local rockspec = makeRockspec({ package = "lls-addon-types" })
			local configEntries, installEntries = compileLuarc(rockspec, {})
			assert.are_same({
				{
					action = "prepend",
					dedup = true,
					key = "runtime.plugin",
					value = LOADER_SOURCE,
				} --[[@as lls-addon.config-entry.prepend]],
				{
					action = "append",
					dedup = true,
					key = "runtime.plugin",
					value = path(ROCKS_DIR, installDir("lls-addon-types", VERSION), "plugin.lua"),
				} --[[@as lls-addon.config-entry.append]],
			}, configEntries)
			assert.are_same({
				{
					type = "file",
					source = path(CURRENT_DIR, "plugin.lua"),
					destination = path(ROCKS_DIR, installDir("lls-addon-types", VERSION), "plugin.lua"),
				} --[[@as lls-addon.install-entry]],
			}, installEntries)
		end)

		it("works when given a multi-file plugin", function()
			stubFs({
				-- key = handler / return value
				current_dir = CURRENT_DIR,
				is_file = pathEquals(path(CURRENT_DIR, "plugin.lua")),
				is_dir = pathEquals(path(CURRENT_DIR, "plugin")),
			})

			local rockspec = makeRockspec({ package = "lls-addon-types" })
			local configEntries, installEntries = compileLuarc(rockspec, {})
			assert.are_same({
				{
					action = "prepend",
					dedup = true,
					key = "runtime.plugin",
					value = LOADER_SOURCE,
				} --[[@as lls-addon.config-entry.prepend]],
				{
					action = "append",
					dedup = true,
					key = "runtime.plugin",
					value = path(ROCKS_DIR, installDir("lls-addon-types", VERSION), "plugin.lua"),
				} --[[@as lls-addon.config-entry.append]],
			}, configEntries)
			assert.are_same({
				{
					type = "file",
					source = path(CURRENT_DIR, "plugin.lua"),
					destination = path(ROCKS_DIR, installDir("lls-addon-types", VERSION), "plugin.lua"),
				} --[[@as lls-addon.install-entry]],
				{
					type = "directory",
					source = path(CURRENT_DIR, "plugin"),
					destination = path(ROCKS_DIR, installDir("lls-addon-types", VERSION), "plugin"),
				} --[[@as lls-addon.install-entry]],
			}, installEntries)
		end)

		it("works when given rockspec settings", function()
			stubFs({ current_dir = CURRENT_DIR })

			local rockspec = makeRockspec({
				build = {
					settings = {
						["some.example"] = 42,
						another = {
							example = 100,
						},
					},
				},
			})
			local configEntries, installEntries = compileLuarc(rockspec, {})
			assert.are_same({
				{
					action = "merge",
					value = {
						["some.example"] = 42,
						another = {
							example = 100,
						},
					},
				} --[[@as lls-addon.config-entry.merge]],
			}, configEntries)
			assert.are_equal(0, #installEntries)
		end)

		it("errors when rockspec settings is not an object", function()
			stubFs({ currentDir = CURRENT_DIR })

			local rockspec = makeRockspec({ build = { settings = { "some", "example" } } })
			assert.error(function()
				compileLuarc(rockspec, {})
			end)
		end)

		it("works when given a config.json", function()
			stubFs({
				-- key = handler / return value
				current_dir = CURRENT_DIR,
				is_file = pathEquals(path(CURRENT_DIR, "config.json")),
			})
			local jsonRead = stub(json, "read", function()
				return json.object({
					settings = json.object({
						["Lua.some.example"] = 42,
						["Lua.another.example"] = 100,
					}),
				})
			end)

			local rockspec = makeRockspec()
			local configEntries, installEntries = compileLuarc(rockspec, {})
			assert.are_same({
				{
					action = "merge",
					value = {
						["some.example"] = 42,
						["another.example"] = 100,
					},
				} --[[@as lls-addon.config-entry.merge]],
			}, configEntries)
			assert.are_same({
				{
					type = "file",
					source = path(CURRENT_DIR, "config.json"),
					destination = path(ROCKS_DIR, INSTALL_DIR, "config.json"),
				},
			}, installEntries)
			assert.stub(jsonRead).was.called(1)
			assert.stub(jsonRead).was.called_with(path(CURRENT_DIR, "config.json"))
		end)

		it("errors when config.json is not an object", function()
			stubFs({
				-- key = handler / return value
				current_dir = CURRENT_DIR,
				is_file = pathEquals(path(CURRENT_DIR, "config.json")),
			})
			local jsonRead = stub(json, "read", function()
				return false
			end)

			local rockspec = makeRockspec()

			assert.error(function()
				compileLuarc(rockspec, {})
			end)

			assert.stub(jsonRead).was.called(1)
			assert.stub(jsonRead).was.called_with(path(CURRENT_DIR, "config.json"))
		end)

		it("errors when config.json's settings key is not an object", function()
			stubFs({
				-- key = handler / return value
				current_dir = CURRENT_DIR,
				is_file = pathEquals(path(CURRENT_DIR, "config.json")),
			})
			local jsonRead = stub(json, "read", function()
				return json.object({ settings = false })
			end)

			local rockspec = makeRockspec()
			assert.error(function()
				compileLuarc(rockspec, {})
			end)

			assert.stub(jsonRead).was.called(1)
			assert.stub(jsonRead).was.called_with(path(CURRENT_DIR, "config.json"))
		end)

		it("only copies from rockspec settings when also given config.json", function()
			stubFs({
				-- key = handler / return value
				current_dir = CURRENT_DIR,
				is_file = pathEquals(path(CURRENT_DIR, "config.json")),
			})
			local jsonRead = stub(json, "read", function(pathArg)
				return nil, "this should not be called"
			end)

			local rockspec = makeRockspec({
				build = {
					settings = { ["different.example"] = 96 },
				},
			})
			local configEntries, installEntries = compileLuarc(rockspec, {})

			assert.are_same({
				{
					action = "merge",
					value = { ["different.example"] = 96 },
				},
			}, configEntries)
			assert.are_equal(0, #installEntries)
			assert.stub(jsonRead).was.called(0)
		end)

		it("lets rockspec settings overwrite library and plugin keys", function()
			stubFs({
				-- key = handler / return value
				current_dir = CURRENT_DIR,
				is_dir = pathEquals(path(CURRENT_DIR, "library")),
				is_file = pathEquals(path(CURRENT_DIR, "plugin.lua")),
			})

			local rockspec = makeRockspec({
				build = {
					settings = {
						["workspace.library"] = { "anotherLibrary" },
						["runtime.plugin"] = "anotherPlugin.lua",
					},
				},
			})

			local configEntries, installEntries = compileLuarc(rockspec, {})
			assert.are_same({
				{
					action = "append",
					dedup = true,
					key = "workspace.library",
					value = path(ROCKS_DIR, INSTALL_DIR, "library"),
				},
				{
					action = "prepend",
					dedup = true,
					key = "runtime.plugin",
					value = LOADER_SOURCE,
				},
				{
					action = "append",
					dedup = true,
					key = "runtime.plugin",
					value = path(ROCKS_DIR, INSTALL_DIR, "plugin.lua"),
				},
				{
					action = "merge",
					value = {
						["workspace.library"] = { "anotherLibrary" },
						["runtime.plugin"] = "anotherPlugin.lua",
					},
				},
			}, configEntries)
			assert.are_equal(2, #installEntries)
			assert.contains({
				type = "directory",
				source = path(CURRENT_DIR, "library"),
				destination = path(ROCKS_DIR, INSTALL_DIR, "library"),
			}, installEntries)
			assert.contains({
				type = "file",
				source = path(CURRENT_DIR, "plugin.lua"),
				destination = path(ROCKS_DIR, INSTALL_DIR, "plugin.lua"),
			}, installEntries)
		end)
	end)

	describe("findLuarcFiles", function()
		before_each(function()
			mock(log, --[[stub:]] true)
		end)

		local findLuarcFiles = llsAddon.findLuarcFiles
		local currentDir = path("fake", "path", "to", "types")

		it("gives .luarc.json when nothing is found", function()
			stubFs({ current_dir = currentDir })

			local files = findLuarcFiles(currentDir, {})
			assert.are_same({ { type = "luarc", path = path(currentDir, ".luarc.json") } }, files)
		end)

		it("looks for a .luarc.json", function()
			stubFs({
				current_dir = currentDir,
				is_file = pathEquals(path(currentDir, ".luarc.json")),
			})

			local files = findLuarcFiles(currentDir, {})
			assert.are_same({ { type = "luarc", path = path(currentDir, ".luarc.json") } }, files)
		end)

		it("looks for .vscode/settings.json", function()
			stubFs({
				current_dir = currentDir,
				is_file = pathEquals(path(currentDir, ".vscode", "settings.json")),
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
				is_file = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, {})
			assert.are_same({ { type = "luarc", path = path(currentDir, ".luarc.json") } }, files)
		end)

		it("prioritizes environment variables before looking in projectDir", function()
			stubFs({
				current_dir = currentDir,
				is_file = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
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

		it("looks in projectDir if environment variables are defined and empty", function()
			stubFs({
				current_dir = currentDir,
				is_file = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, { VSCSETTINGSPATH = "", LUARCPATH = "" })
			assert.are_equal(1, #files)
			assert.contains({ type = "luarc", path = path(currentDir, ".luarc.json") }, files)
		end)

		it("looks in projectDir if environment variables are defined and empty", function()
			stubFs({
				current_dir = currentDir,
				is_file = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, { VSCSETTINGSPATH = "", LUARCPATH = "" })
			assert.are_equal(1, #files)
			assert.contains({ type = "luarc", path = path(currentDir, ".luarc.json") }, files)
		end)

		it("looks in projectDir if only VSCSETTINGSPATH is defined and empty", function()
			stubFs({
				current_dir = currentDir,
				is_file = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, { VSCSETTINGSPATH = "" })
			assert.are_equal(1, #files)
			assert.contains({ type = "luarc", path = path(currentDir, ".luarc.json") }, files)
		end)

		it("looks in projectDir if only LUARCPATH is defined and empty", function()
			stubFs({
				current_dir = currentDir,
				is_file = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, { LUARCPATH = "" })
			assert.are_equal(1, #files)
			assert.contains({ type = "luarc", path = path(currentDir, ".luarc.json") }, files)
		end)

		it("does not look in projectDir if environment variables are defined as ';'", function()
			stubFs({
				current_dir = currentDir,
				is_file = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, { VSCSETTINGSPATH = ";", LUARCPATH = ";" })
			assert.are_same({}, files)
		end)

		it("does not look in projectDir if only VSCSETTINGSPATH is defined as ';'", function()
			stubFs({
				current_dir = currentDir,
				is_file = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, { VSCSETTINGSPATH = ";" })
			assert.are_same({}, files)
		end)

		it("does not look in projectDir if only LUARCPATH is defined as ';'", function()
			stubFs({
				current_dir = currentDir,
				is_file = pathEquals(path(currentDir, ".luarc.json"), path(currentDir, ".vscode", "settings.json")),
			})

			local files = findLuarcFiles(currentDir, { LUARCPATH = ";" })
			assert.are_same({}, files)
		end)
	end)

	describe("getProjectDir", function()
		local getProjectDir = llsAddon.getProjectDir
		it("returns the project dir if detected", function()
			cfg.project_dir = path("fake", "projectDir")
			local projectDir = getProjectDir()
			assert.are_same(path("fake", "projectDir"), projectDir)
		end)

		it("defaults to '.' if no project dir was detected", function()
			cfg.project_dir = nil
			stub(fs, "current_dir", path("fake", "currentDir"))
			local projectDir = getProjectDir()
			assert.are_same(path("fake", "currentDir"), projectDir)
		end)
	end)

	describe("getInstallDir", function()
		local getInstallDir = llsAddon.getInstallDir
		it("returns a relative install dir if it exists", function()
			local projectDir = path("fake", "projectDir")
			local rockspec = makeRockspec({ package = "types", version = "0.1-1" })
			local stubInstallPath = stub(pathMod, "install_dir", path("fake", "projectDir", "installDir"))
			local env = {}

			local installDir, formattedInstallDir = getInstallDir(projectDir, rockspec, env)
			assert.are_equal(path("fake", "projectDir", "installDir"), installDir)
			assert.are_equal(path("installDir"), formattedInstallDir)
			assert.stub(stubInstallPath).was.called(1)
			assert.stub(stubInstallPath).was.called_with("types", "0.1-1")
		end)

		it("returns absolute path if not relative to project dir", function()
			local projectDir = path("fake", "projectDir")
			local rockspec = makeRockspec({ package = "types", version = "0.1-1" })
			local stubInstallPath = stub(pathMod, "install_dir", path("fake", "some", "other", "installDir"))
			local env = {}

			local installDir, formattedInstallDir = getInstallDir(projectDir, rockspec, env)
			assert.are_equal(path("fake", "some", "other", "installDir"), installDir)
			assert.are_equal(path("fake", "some", "other", "installDir"), formattedInstallDir)
			assert.stub(stubInstallPath).was.called(1)
			assert.stub(stubInstallPath).was.called_with("types", "0.1-1")
		end)

		it("returns absolute path if LLSADDON_ABSPATH is truthy", function()
			local projectDir = path("fake", "projectDir")
			local rockspec = makeRockspec({ package = "types", version = "0.1-1" })
			local stubInstallPath = stub(pathMod, "install_dir", path("fake", "projectDir", "installDir"))
			local env = { ABSPATH = "true" }

			local installDir, formattedInstallDir = getInstallDir(projectDir, rockspec, env)
			assert.are_equal(path("fake", "projectDir", "installDir"), installDir)
			assert.are_equal(path("fake", "projectDir", "installDir"), formattedInstallDir)
			assert.stub(stubInstallPath).was.called(1)
			assert.stub(stubInstallPath).was.called_with("types", "0.1-1")
		end)

		for _, falsyString in ipairs({ "false", "no", "off", "0" }) do
			it(string.format("returns relative path if LLSADDON_ABSPATH is %q", falsyString), function()
				local projectDir = path("fake", "projectDir")
				local rockspec = makeRockspec({ package = "types", version = "0.1-1" })
				local stubInstallPath = stub(pathMod, "install_dir", path("fake", "projectDir", "installDir"))
				local env = { ABSPATH = falsyString }

				local installDir, formattedInstallDir = getInstallDir(projectDir, rockspec, env)
				assert.are_equal(path("fake", "projectDir", "installDir"), installDir)
				assert.are_equal(path("installDir"), formattedInstallDir)
				assert.stub(stubInstallPath).was.called(1)
				assert.stub(stubInstallPath).was.called_with("types", "0.1-1")
			end)
		end
	end)
end)
