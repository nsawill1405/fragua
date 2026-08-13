local ok, Context = pcall(function()
	return require("../src/App/Runtime/ScriptContext")
end)

return {
	["selects the runtime facade from script class and location"] = function()
		assert(ok and Context, "ScriptContext should be available")
		assert(Context.select("Script", "ServerScriptService.Game") == "Server")
		assert(Context.select("LocalScript", "StarterPlayer.StarterPlayerScripts.Game") == "Client")
		assert(Context.select("ModuleScript", "ReplicatedStorage.Shared") == "Core")
		assert(Context.select("ModuleScript", "ServerStorage.Private") == "Server")
		assert(Context.select("ModuleScript", "ServerScriptService.Private") == "Server")
		assert(Context.select("ModuleScript", "Workspace.Ambiguous") == "Core")
	end,
}
