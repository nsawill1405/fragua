local fs = require("@lune/fs")
local serverSource = require("../src/App/Runtime/BootstrapSource")
local clientSource = require("../src/App/Runtime/ClientBootstrapSource")

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
	["managed module sync covers gateway and both runtime hosts without redundant writes"] = function()
		local source = fs.readFile("src/App/Runtime/EnsurePlaceModules.luau")
		assert(source:find('"FraguaRuntime"', 1, true))
		assert(source:find('"FraguaClientRuntime"', 1, true))
		assert(source:find('"StarterPlayerScripts"', 1, true))
		assert(source:find("Source ~= source", 1, true))
	end,
}
