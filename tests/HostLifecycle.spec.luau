local fs = require("@lune/fs")

return {
	["runCreated delegates to watch without a second onCreated"] = function()
		local source = fs.readFile("src/App/Behaviors/Host.luau")
		local start = assert(source:find("function Host.runCreated", 1, true))
		local finish = assert(source:find("\nreturn Host", start, true))
		local body = source:sub(start, finish - 1)
		assert(body:find("watch(instance)", 1, true), "runCreated should call watch")
		assert(
			not body:find('callHook(instance, "onCreated")', 1, true),
			"runCreated must not call onCreated again; watch is the single entry"
		)
	end,
	["watch remains the sole onCreated entry for host lifecycle"] = function()
		local source = fs.readFile("src/App/Behaviors/Host.luau")
		local count = 0
		local offset = 1
		while true do
			local found = source:find('callHook(instance, "onCreated")', offset, true)
			if not found then
				break
			end
			count += 1
			offset = found + 1
		end
		assert(count == 1, `expected exactly one onCreated callHook, found {count}`)
	end,
	["edit host strips managed headers before loadstring"] = function()
		local source = fs.readFile("src/App/Behaviors/Host.luau")
		assert(source:find("ScriptHeader.strip", 1, true), "Host should strip managed headers")
		local compileStart = assert(source:find("local function compileBehavior", 1, true))
		local compileFinish = assert(source:find("\nlocal function loadBehavior", compileStart, true))
		local body = source:sub(compileStart, compileFinish - 1)
		assert(body:find("ScriptHeader.strip(source)", 1, true))
		assert(body:find("loadstring(wrapped", 1, true))
		assert(body:find("freshRequire", 1, true), "edit requires should bypass modulescript cache")
		assert(source:find("target.Parent", 1, true), "fresh require must parent the clone so script.Parent works")
	end,
	["edit host suspends while studio is playing"] = function()
		local source = fs.readFile("src/App/Behaviors/Host.luau")
		assert(source:find("function Host.suspend", 1, true))
		assert(source:find("function Host.resume", 1, true))
		assert(source:find("editSessionActive", 1, true))
		assert(source:find("RunState", 1, true))
		assert(source:find("IsRunMode", 1, true))
		assert(source:find("Host.suspend()", 1, true))
		assert(source:find("Host.resume()", 1, true))
	end,
	["edit host hot reloads from the open script document"] = function()
		local source = fs.readFile("src/App/Behaviors/Host.luau")
		assert(source:find("TextDocumentDidChange", 1, true))
		assert(source:find("GetEditorSource", 1, true))
		assert(source:find("refreshType", 1, true))
	end,
	["unload calls onStop so edit visuals dont leak into play"] = function()
		local source = fs.readFile("src/App/Behaviors/Host.luau")
		assert(source:find('behavior.onStop(instance)', 1, true))
	end,
	["invalidateType unloads tagged instances not just loaded cache"] = function()
		local source = fs.readFile("src/App/Behaviors/Host.luau")
		assert(source:find("matchingInstances", 1, true))
		assert(source:find("GetTagged", 1, true))
		local invalidate = assert(source:find("function Host.invalidateType", 1, true))
		local body = source:sub(invalidate, invalidate + 200)
		assert(body:find("rewatch(typeId)", 1, true))
		assert(source:find("function Host.refreshType", 1, true))
		assert(source:find("function Host.refreshAll", 1, true))
		assert(source:find("GetEditorSource", 1, true))
		assert(source:find("Registry.notifyChanged", 1, true))
		assert(source:find("BindableFunction", 1, true))
		assert(source:find("REFRESH_BINDABLE", 1, true))
	end,
	["properties exposes a refresh edit behavior action"] = function()
		local source = fs.readFile("src/App/Properties/init.luau")
		assert(source:find("Refresh Edit Behavior", 1, true))
		assert(source:find("Host.refreshType", 1, true))
	end,
}
