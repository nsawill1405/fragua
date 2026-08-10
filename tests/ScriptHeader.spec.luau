local ok, Header = pcall(function()
	return require("../src/App/Runtime/ScriptHeader")
end)

return {
	["adds aliases and preserves user source"] = function()
		assert(ok and Header, "ScriptHeader should be available")
		local result, changed = Header.apply("print('hello')\n")
		assert(changed and result:find("local Instance = Fragua.Instance", 1, true))
		assert(result:sub(-15) == "print('hello')\n")
	end,
	["is idempotent and replaces old marked content"] = function()
		assert(ok and Header, "ScriptHeader should be available")
		local once = Header.apply("return true")
		local twice, changed = Header.apply(once)
		assert(not changed and twice == once)
		local updated = Header.apply("-- Fragua imports begin\nold\n-- Fragua imports end\nreturn true")
		assert(updated:find("local Enum = Fragua.Enum", 1, true))
		assert(not updated:find("\nold\n", 1, true))
	end,
	["skips managed runtime modules"] = function()
		assert(ok and Header, "ScriptHeader should be available")
		assert(Header.shouldSkip("ReplicatedStorage.Fragua"))
		assert(Header.shouldSkip("ServerScriptService.FraguaRuntime"))
		assert(not Header.shouldSkip("ServerScriptService.Gameplay"))
	end,
	["keeps Luau mode directives on the first line"] = function()
		assert(ok and Header, "ScriptHeader should be available")
		local result = Header.apply("--!strict\nlocal value = 1\n")
		local directive = "--!strict\n"
		assert(result:sub(1, #directive) == directive)
		assert(result:find("-- Fragua imports begin", #directive + 1, true) == #directive + 1)
	end,
}
