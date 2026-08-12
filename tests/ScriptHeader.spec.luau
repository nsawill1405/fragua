local ok, Header = pcall(function()
	return require("../src/App/Runtime/ScriptHeader")
end)

return {
	["adds context aliases and preserves user source"] = function()
		assert(ok and Header, "ScriptHeader should be available")
		local result, changed = Header.apply("print('hello')\n", "Client")
		assert(changed and result:find("local Fragua = FraguaGateway.Client", 1, true))
		assert(result:find("local Instance = Fragua.Instance", 1, true))
		assert(result:find("local Enum = Fragua.Enum", 1, true))
		assert(result:find("local type = Fragua.type", 1, true))
		assert(result:find("local typeof = Fragua.typeof", 1, true))
		assert(result:sub(-15) == "print('hello')\n")
	end,
	["is idempotent for an exact context header"] = function()
		assert(ok and Header, "ScriptHeader should be available")
		local once = Header.apply("return true", "Client")
		local twice, changed = Header.apply(once, "Client")
		assert(not changed and twice == once)
	end,
	["replaces only the first complete marked header block"] = function()
		assert(ok and Header, "ScriptHeader should be available")
		local source =
			"before\n-- Fragua imports begin\nold\n-- Fragua imports end\nafter\n-- Fragua imports begin\nkeep\n-- Fragua imports end\n"
		local updated = Header.apply(source, "Server")
		assert(updated:find("local Fragua = FraguaGateway.Server", 1, true))
		assert(not updated:find("\nold\n", 1, true))
		assert(updated:sub(-57) == "after\n-- Fragua imports begin\nkeep\n-- Fragua imports end\n")
	end,
	["skips managed runtime modules"] = function()
		assert(ok and Header, "ScriptHeader should be available")
		assert(Header.shouldSkip("ReplicatedStorage.Fragua"))
		assert(Header.shouldSkip("ServerScriptService.FraguaRuntime"))
		assert(Header.shouldSkip("StarterPlayer.StarterPlayerScripts.FraguaClientRuntime"))
		assert(not Header.shouldSkip("ServerScriptService.Gameplay"))
	end,
	["keeps Luau mode directives on the first line"] = function()
		assert(ok and Header, "ScriptHeader should be available")
		local result = Header.apply("--!strict\n--!optimize 2\nlocal value = 1\n", "Server")
		local directive = "--!strict\n--!optimize 2\n"
		assert(result:sub(1, #directive) == directive)
		assert(result:find("-- Fragua imports begin", #directive + 1, true) == #directive + 1)
	end,
	["preserves --!strict and stays idempotent"] = function()
		assert(ok and Header, "ScriptHeader should be available")
		local once = Header.apply("--!strict\nlocal x = 1\n", "Server")
		local twice, changed = Header.apply(once, "Server")
		-- plan snippet used sub(1, 8); --!strict is 9 chars
		assert(once:sub(1, 9) == "--!strict" and not changed and twice == once)
	end,
}
