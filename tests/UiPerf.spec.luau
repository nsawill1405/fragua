local fs = require("@lune/fs")

local function read(path: string): string
	return fs.readFile(path)
end

return {
	["settings store caches decoded JSON and invalidates on write"] = function()
		local source = read("src/App/Settings/Store.luau")
		assert(source:find("local decoded", 1, true), "Store must cache decoded JSON")
		local setRaw = assert(source:find("local function setRaw", 1, true))
		local setRawEnd = assert(source:find("\nend", setRaw, true))
		assert(
			source:sub(setRaw, setRawEnd):find("decoded[key] = nil", 1, true),
			"setRaw must invalidate decoded cache"
		)
		assert(source:find("table.clear(decoded)", 1, true), "bind must reset decoded cache")
	end,
	["theme skips tween creation when animations are off"] = function()
		local source = read("src/App/Shared/Theme.luau")
		local play = assert(source:find("function Theme.play", 1, true))
		local create = assert(source:find("TweenService:Create", play, true))
		local body = source:sub(play, create)
		assert(body:find("animationsEnabled()", 1, true), "play must check animations before creating a tween")
		assert(body:find("return nil", 1, true), "play must return nil without creating a tween")
	end,
	["boolean toggle commits without a tween"] = function()
		local source = read("src/App/Properties/Controls.luau")
		assert(source:find("if trackTween then", 1, true), "toggle must handle Theme.play returning nil")
	end,
	["registry reuses parsed type JSON"] = function()
		local source = read("src/App/Types/Registry.luau")
		assert(source:find("parsedByContainer", 1, true))
		assert(source:find("cached.raw == raw", 1, true), "cache must be keyed on raw content")
		assert(not source:find("table.find(found, inst)", 1, true), "findInstances must use a seen set")
	end,
	["explorer hover repaints only affected rows"] = function()
		local source = read("src/App/Explorer/Tree.luau")
		assert(not source:find("refreshPlusVisibility", 1, true), "hover must not repaint every row")
		local hover = assert(source:find("local function setHovered", 1, true))
		local hoverEnd = assert(source:find("\n\tend", hover, true))
		assert(not source:sub(hover, hoverEnd):find("for ", 1, true), "setHovered must not loop over rows")
	end,
	["explorer memoises filter matches per rebuild"] = function()
		local source = read("src/App/Explorer/Tree.luau")
		assert(source:find("matchCache[instance] = result", 1, true))
		assert(source:find("table.clear(matchCache)", 1, true))
	end,
	["explorer rename disconnects escape listener"] = function()
		local source = read("src/App/Explorer/Tree.luau")
		assert(source:find("escapeConn:Disconnect()", 1, true))
	end,
	["explorer behavior menu items only for fragua instances"] = function()
		local source = read("src/App/Explorer/Tree.luau")
		local guard =
			assert(source:find("Registry.isFraguaInstance(instance) and Registry.getTypeId(instance)", 1, true))
		assert(source:find("Open {side} Behavior", guard, true))
	end,
	["search input is debounced"] = function()
		local source = read("src/App/Explorer/init.luau")
		assert(source:find("Util.debounce", 1, true), "search must debounce rebuilds")
	end,
	["properties coalesces rebuilds and watches tags once"] = function()
		local source = read("src/App/Properties/init.luau")
		assert(source:find("local function requestRebuild", 1, true))
		assert(not source:find("task.defer(rebuild)", 1, true), "use requestRebuild instead of task.defer(rebuild)")
		local rebuildStart = assert(source:find("function rebuild()", 1, true))
		local lifetimeStart = assert(source:find("local lifetime", rebuildStart, true))
		assert(
			not source:sub(rebuildStart, lifetimeStart):find("GetInstanceAddedSignal", 1, true),
			"tag signals must not be connected per rebuild"
		)
	end,
}
