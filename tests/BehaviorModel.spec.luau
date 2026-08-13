local ok, Model = pcall(function()
	return require("../src/App/Types/BehaviorModel")
end)

local function requireModel()
	assert(ok and Model, "BehaviorModel should be available")
	return Model
end

return {
	["canonical names identify every execution side"] = function()
		local model = requireModel()
		assert(#model.SIDES == 3)
		assert(model.SIDES[1] == "Edit")
		assert(model.SIDES[2] == "Server")
		assert(model.SIDES[3] == "Client")
		assert(model.name("Zombie", "Edit") == "ZombieEditBehavior")
		assert(model.name("Zombie", "Server") == "ZombieServerBehavior")
		assert(model.name("Zombie", "Client") == "ZombieClientBehavior")
		local names = {
			model.name("Zombie", "Edit"),
			model.name("Zombie", "Server"),
			model.name("Zombie", "Client"),
		}
		assert(names[1] ~= names[2] and names[2] ~= names[3] and names[1] ~= names[3])
	end,
	["client skeleton has runtime hooks only"] = function()
		local source = requireModel().defaultSource("Zombie", "Client")
		assert(source:find("Behavior.onStart", 1, true))
		assert(source:find("Behavior.onStop", 1, true))
		assert(source:find("instance: Instance", 1, true))
		assert(not source:find("onSelected", 1, true))
		assert(not source:find("onPropertyChanged", 1, true))
	end,
	["server skeleton has runtime hooks only"] = function()
		local source = requireModel().defaultSource("Zombie", "Server")
		assert(source:find("Behavior.onStart", 1, true))
		assert(source:find("Behavior.onStop", 1, true))
		assert(not source:find("onCreated", 1, true))
		assert(not source:find("onAncestryChanged", 1, true))
	end,
	["edit skeleton has no play hooks"] = function()
		local source = requireModel().defaultSource("Zombie", "Edit")
		assert(source:find("Behavior.onCreated", 1, true))
		assert(source:find("Behavior.onSelected", 1, true))
		assert(source:find("Behavior.onPropertyChanged", 1, true))
		assert(source:find("Behavior.onAncestryChanged", 1, true))
		assert(not source:find("Behavior.onStart", 1, true))
		assert(not source:find("Behavior.onStop", 1, true))
	end,
	["server migration never requires edit behavior at play time"] = function()
		local model = requireModel()
		local edit = table.concat({
			"local Behavior = {}",
			"local function ensureNameplate(instance)",
			"end",
			"function Behavior.onCreated(instance)",
			"\tensureNameplate(instance)",
			"end",
			"function Behavior.onStart(instance)",
			"\tensureNameplate(instance)",
			"end",
			"function Behavior.onStop(_instance)",
			"end",
			"return Behavior",
			"",
		}, "\n")
		local source = model.serverMigrationSource("Zombie", edit)
		assert(not source:find("require(", 1, true))
		assert(not source:find("EditBehavior", 1, true))
		assert(not source:find("WaitForChild", 1, true))
		assert(source:find("function Behavior.onStart", 1, true))
		assert(source:find("ensureNameplate(instance)", 1, true))
		assert(not source:find("function Behavior.onCreated", 1, true))
		assert(
			model.isServerEditForwarder(
				'-- Fragua Server migration forwarder\nlocal EditBehavior = require(script.Parent:WaitForChild("ZombieEditBehavior"))\n'
			)
		)
		assert(not model.isServerEditForwarder(source))
	end,
	["edit source from legacy drops play hooks"] = function()
		local model = requireModel()
		local legacy = table.concat({
			"local Behavior = {}",
			"function Behavior.onCreated(instance)",
			"end",
			"function Behavior.onStart(instance)",
			"end",
			"function Behavior.onStop(instance)",
			"end",
			"return Behavior",
			"",
		}, "\n")
		local edit = model.editSourceFromLegacy(legacy, "Zombie")
		assert(edit:find("function Behavior.onCreated", 1, true))
		assert(not edit:find("function Behavior.onStart", 1, true))
		assert(not edit:find("function Behavior.onStop", 1, true))
	end,
	["type definitions and exact behavior identities cannot collide"] = function()
		local model = requireModel()
		local typeIds = { "Foo", "FooEditBehavior" }
		local definitionType, definitionSide = model.templateIdentity("FooEditBehavior", typeIds, true)
		assert(definitionType == nil and definitionSide == nil)
		local fooType, fooSide = model.templateIdentity("FooEditBehavior", typeIds, false)
		assert(fooType == "Foo" and fooSide == "Edit")
		local namedType, namedSide = model.templateIdentity("FooEditBehaviorEditBehavior", typeIds, false)
		assert(namedType == "FooEditBehavior" and namedSide == "Edit")
	end,
}
