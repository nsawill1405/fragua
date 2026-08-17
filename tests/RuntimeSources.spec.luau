local fs = require("@lune/fs")
local serverSource = require("../src/App/Runtime/BootstrapSource")
local clientSource = require("../src/App/Runtime/ClientBootstrapSource")
local guideSource = require("../src/App/Runtime/GuideSource")

local function eachHost(callback)
	for side, source in { Server = serverSource, Client = clientSource } do
		callback(source, side)
	end
end

return {
	["runtime source strings compile as Luau"] = function()
		local serverChunk, serverError = loadstring(serverSource, "FraguaRuntime")
		local clientChunk, clientError = loadstring(clientSource, "FraguaClientRuntime")
		assert(serverChunk, serverError)
		assert(clientChunk, clientError)
	end,
	["runtime sources resolve only their own behavior side"] = function()
		assert(serverSource:find("ServerBehavior", 1, true))
		assert(not serverSource:find("ClientBehavior", 1, true))
		assert(not serverSource:find("EditBehavior", 1, true))
		assert(clientSource:find("ClientBehavior", 1, true))
		assert(not clientSource:find("ServerBehavior", 1, true))
		assert(not clientSource:find("EditBehavior", 1, true))
		assert(not clientSource:find("ServerStorage", 1, true))
	end,
	["runtime hosts never mutate behavior source during play"] = function()
		assert(not serverSource:find(".Source", 1, true))
		assert(not clientSource:find(".Source", 1, true))
	end,
	["runtime hosts isolate lifecycle failures and track started instances"] = function()
		eachHost(function(source)
			assert(source:find("started[instance]", 1, true))
			assert(source:find("pcall", 1, true))
			assert(source:find("onStart", 1, true))
			assert(source:find("onStop", 1, true))
			assert(source:find("GetInstanceAddedSignal", 1, true))
			assert(source:find("GetInstanceRemovedSignal", 1, true))
		end)
	end,
	["runtime hosts connect collection signals before initial enumeration"] = function()
		eachHost(function(source, side)
			local added = assert(source:find("GetInstanceAddedSignal(TAG):Connect(start)", 1, true))
			local removed = assert(source:find("GetInstanceRemovedSignal(TAG):Connect(stop)", 1, true))
			local initial = assert(source:find("for _, instance in CollectionService:GetTagged(TAG) do", 1, true))
			assert(added < initial, `{side} added signal must connect before initial enumeration`)
			assert(removed < initial, `{side} removed signal must connect before initial enumeration`)
		end)
	end,
	["client host waits for replicated type entries before failing"] = function()
		assert(clientSource:find("WaitForChild(typeId, 10)", 1, true))
		assert(clientSource:find("WaitForChild(TEMPLATE_NAME, 5)", 1, true))
		assert(clientSource:find("startTaggedOfType", 1, true))
		assert(clientSource:find("watchCatalog", 1, true))
	end,
	["runtime hosts clear started state after a failed load so a later catalog arrival can retry"] = function()
		eachHost(function(source, side)
			local failure = assert(source:find("if not ok then", 1, true))
			local clear = assert(source:find("started[instance] = nil", failure, true))
			local warnCall = assert(source:find("warnFailure(instance, typeId, phase, problem)", clear, true))
			assert(failure < clear and clear < warnCall, `{side} failed loads must clear started before warning`)
		end)
	end,
	["runtime hosts schedule protected loading outside the caller"] = function()
		eachHost(function(source, side)
			local spawn = assert(source:find("task.spawn(function()", 1, true))
			local protected = assert(source:find("pcall(function()", spawn, true))
			local load = assert(source:find("local template = findTemplate(typeId)", protected, true))
			assert(spawn < protected and protected < load, `{side} load must run in a protected spawned task`)
		end)
	end,
	["runtime hosts reject a delayed loader after its state is invalidated"] = function()
		eachHost(function(source, side)
			local load = assert(source:find("local behavior = require(template)", 1, true))
			local tokenCheck = assert(source:find("if started[instance] ~= state then", load, true))
			local onStart = assert(source:find("if typeof(behavior.onStart)", tokenCheck, true))
			local stop = assert(source:find("local function stop(instance: Instance)", 1, true))
			local invalidate = assert(source:find("started[instance] = nil", stop, true))
			assert(load < tokenCheck and tokenCheck < onStart, `{side} loader must validate its exact state token`)
			assert(stop < invalidate, `{side} stop must invalidate the active state`)
		end)
	end,
	["catalog sync removes private and legacy behavior children"] = function()
		local source = fs.readFile("src/App/Runtime/TypeCatalog.luau")
		assert(source:find("for _, child in typeEntry:GetChildren() do", 1, true))
		assert(source:find('"Behavior"', 1, true))
		assert(source:find('"EditBehavior"', 1, true))
		assert(source:find('"ServerBehavior"', 1, true))
		assert(source:find('"ClientBehavior"', 1, true))
	end,
	["managed module sync does not rewrite place modules during play"] = function()
		local source = fs.readFile("src/App/Runtime/EnsurePlaceModules.luau")
		assert(source:find("IsRunning", 1, true))
		assert(source:find("IsEdit", 1, true))
	end,
	["managed module sync covers gateway and both runtime hosts without redundant writes"] = function()
		local source = fs.readFile("src/App/Runtime/EnsurePlaceModules.luau")
		assert(source:find('"FraguaRuntime"', 1, true))
		assert(source:find('"FraguaClientRuntime"', 1, true))
		assert(source:find('"StarterPlayerScripts"', 1, true))
		-- recreate on source change so roblox require caches cannot keep a stale gateway
		assert(source:find("Source == source", 1, true))
		assert(source:find("existing:Destroy()", 1, true))
	end,
	["managed module sync injects an ai guide under the plugin root"] = function()
		local source = fs.readFile("src/App/Runtime/EnsurePlaceModules.luau")
		assert(source:find("GuideSource", 1, true))
		assert(source:find('"README"', 1, true))
		assert(source:find("ensurePluginRoot()", 1, true))
		assert(source:find("Constants.ROOT_FOLDER", 1, true))
	end,
	["ai guide source compiles and points mcp at types, tags, and managed paths"] = function()
		local chunk, compileError = loadstring(guideSource, "FraguaREADME")
		assert(chunk, compileError)
		local ok, text = pcall(chunk)
		assert(ok and typeof(text) == "string" and #text > 200, "guide module should return documentation text")
		for _, needle in
			{
				"Fragua",
				"MCP",
				"ServerStorage.Fragua.README",
				"ReplicatedStorage.Fragua",
				"ReplicatedStorage.FraguaTypes",
				"ServerScriptService.FraguaRuntime",
				"FraguaClientRuntime",
				"_FraguaType",
				"FraguaInstance",
				"EditBehavior",
				"ServerBehavior",
				"ClientBehavior",
				"_FraguaManaged",
				"search_game_tree",
				"script_read",
				"execute_luau",
				"Instance.new",
				"RefreshEditBehaviors",
				"FraguaEnums",
				"Create New Enum",
			}
		do
			assert(text:find(needle, 1, true), `guide should mention {needle}`)
		end
		assert(guideSource:find("_FraguaManaged", 1, true))
	end,
	["runtime hosts point at the ai guide without the client touching serverstorage"] = function()
		assert(serverSource:find("ServerStorage.Fragua.README", 1, true))
		assert(clientSource:find("README ModuleScript", 1, true))
		assert(not clientSource:find("ServerStorage", 1, true))
		local api = fs.readFile("src/App/Runtime/ApiSource.luau")
		assert(api:find("ServerStorage.Fragua.README", 1, true))
	end,
	["managed gateway sync builds from an optional type surface"] = function()
		local source = fs.readFile("src/App/Runtime/EnsurePlaceModules.luau")
		assert(source:find("function EnsurePlaceModules.sync(surface", 1, true))
		assert(source:find("ApiSource.build(surface or { types = {} })", 1, true))
	end,
	["registry storage protections consume the wrapper collision policy"] = function()
		local source = fs.readFile("src/App/Types/Registry.luau")
		assert(source:find("WrapperPolicy", 1, true))
		assert(source:find("WrapperPolicy.isReserved", 1, true))
	end,
	["default custom types do not redeclare inherited native properties"] = function()
		local source = fs.readFile("src/App/Types/Registry.luau")
		local seedStart = assert(source:find("function Registry.seedDefaults()", 1, true))
		local seedEnd = assert(source:find("-- Replace default behavior", seedStart, true))
		local seed = source:sub(seedStart, seedEnd - 1)
		assert(not seed:find('{ name = "DisplayName"', 1, true))
		assert(not seed:find('{ name = "WalkSpeed"', 1, true))
		assert(not seed:find('{ name = "MaxHealth"', 1, true))
		assert(not seed:find('{ name = "Health"', 1, true))
		assert(seed:find('{ name = "IsHostile"', 1, true))
	end,
	["registry validation probes concrete backing members before save"] = function()
		local source = fs.readFile("src/App/Types/Registry.luau")
		local save = assert(source:find("function Registry.save", 1, true))
		local probe = assert(source:find("local backingProbe", save, true))
		local read = assert(source:find("backingProbe[property.name]", probe, true))
		local policy = assert(source:find("WrapperPolicy.isReserved", read, true))
		assert(probe < read and read < policy)
	end,
}
