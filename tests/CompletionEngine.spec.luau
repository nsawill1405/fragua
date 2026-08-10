local CompletionEngine = require("../src/App/ScriptEditor/CompletionEngine")

local schema = {
	{ name = "Health", valueType = "number", category = "Health", default = 100 },
	{ name = "DetectRange", valueType = "number", category = "AI", default = 40, inherited = true },
}

local function labels(items)
	local result = {}
	for _, item in items do
		table.insert(result, item.label)
	end
	return table.concat(result, ",")
end

return {
	["completes custom properties inside GetAttribute strings"] = function()
		local source = 'local range = instance:GetAttribute("De'
		local items = CompletionEngine.complete({
			source = source,
			cursor = #source + 1,
			schema = schema,
			typeIds = { "Zombie" },
		})
		assert(items[1].label == "DetectRange")
		assert(items[1].detail:find("inherited", 1, true))
	end,
	["completes registered types inside Fragua create calls"] = function()
		local source = 'local zombie = Fragua.create("Zo'
		local items = CompletionEngine.complete({
			source = source,
			cursor = #source + 1,
			schema = schema,
			typeIds = { "Robot", "Zombie" },
		})
		assert(labels(items) == "Zombie")
	end,
	["completes behavior hooks and local symbols"] = function()
		local hookSource = "function Behavior.onC"
		local hooks =
			CompletionEngine.complete({ source = hookSource, cursor = #hookSource + 1, schema = schema, typeIds = {} })
		assert(hooks[1].label == "onCreated")
		local localSource = "local damage = 10\ndam"
		local locals = CompletionEngine.complete({
			source = localSource,
			cursor = #localSource + 1,
			schema = schema,
			typeIds = {},
		})
		assert(locals[1].label == "damage")
	end,
	["includes inherited origin in property details"] = function()
		local source = 'instance:GetAttribute("He'
		local items = CompletionEngine.complete({
			source = source,
			cursor = #source + 1,
			schema = { { name = "Health", valueType = "number", origin = "Character", inherited = true } },
			typeIds = { "Character" },
		})
		assert(items[1].label == "Health")
		assert(items[1].detail:find("Character", 1, true))
	end,
	["completes common Roblox members"] = function()
		local source = "game:GetS"
		local items = CompletionEngine.complete({ source = source, cursor = #source + 1, schema = {}, typeIds = {} })
		assert(items[1].label == "GetService")
	end,
}
