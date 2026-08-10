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
		assert(hooks[1].caretOffset and hooks[1].caretOffset < 0, "hook completion should place the caret in its body")
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
		assert(items[1].caretOffset and items[1].caretOffset < 0, "method completion should place the caret in quotes")
	end,
	["does not flood the editor when there is no typed prefix"] = function()
		local source = "local value = "
		local items =
			CompletionEngine.complete({ source = source, cursor = #source + 1, schema = schema, typeIds = {} })
		assert(#items == 0, `expected no passive suggestions, got {#items}`)
	end,
	["completes custom type properties after instance member access"] = function()
		local source = "instance.Det"
		local items =
			CompletionEngine.complete({ source = source, cursor = #source + 1, schema = schema, typeIds = {} })
		assert(items[1] and items[1].label == "DetectRange")
		assert(items[1].detail:find("inherited", 1, true))
		assert(items[1].newText == 'GetAttribute("DetectRange")', items[1].newText)
	end,
	["completes function parameters as symbols"] = function()
		local source = "function Behavior.onStart(instance)\n\tins"
		local items =
			CompletionEngine.complete({ source = source, cursor = #source + 1, schema = schema, typeIds = {} })
		assert(items[1] and items[1].label == "instance")
	end,
	["completes common Luau library members"] = function()
		local mathItems = CompletionEngine.complete({ source = "math.cl", cursor = 8, schema = {}, typeIds = {} })
		assert(mathItems[1] and mathItems[1].label == "clamp")
		local tableItems = CompletionEngine.complete({ source = "table.ins", cursor = 10, schema = {}, typeIds = {} })
		assert(tableItems[1] and tableItems[1].label == "insert")
	end,
}
