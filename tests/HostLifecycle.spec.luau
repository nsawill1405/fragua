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
		local loadStart = assert(source:find("local function loadBehavior", 1, true))
		local loadFinish = assert(source:find("\nlocal function callHook", loadStart, true))
		local body = source:sub(loadStart, loadFinish - 1)
		assert(body:find("ScriptHeader.strip(source)", 1, true))
		assert(body:find("loadstring(source", 1, true))
	end,
}
