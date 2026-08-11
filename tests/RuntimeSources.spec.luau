local fs = require("@lune/fs")
local serverSource = require("../src/App/Runtime/BootstrapSource")
local clientSource = require("../src/App/Runtime/ClientBootstrapSource")

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
		for _, source in { serverSource, clientSource } do
			assert(source:find("started[instance]", 1, true))
			assert(source:find("pcall", 1, true))
			assert(source:find("onStart", 1, true))
			assert(source:find("onStop", 1, true))
			assert(source:find("GetInstanceAddedSignal", 1, true))
			assert(source:find("GetInstanceRemovedSignal", 1, true))
		end
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
