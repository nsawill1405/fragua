local ok, Model = pcall(function()
	return require("../src/App/Runtime/AutocompleteModel")
end)

local function find(items, label)
	for _, item in items do
		if item.label == label then
			return item
		end
	end
	return nil
end

local function surface()
	return {
		revision = 7,
		types = {
			{
				id = "Zombie",
				name = "Zombie",
				backingClass = "Part",
				properties = {
					{ name = "Health", typeName = "number", origin = "Enemy", inherited = true },
					{ name = "Mood", typeName = "EnumItem", enumType = "HumanoidStateType", origin = "Zombie" },
				},
				serverMethods = {
					{
						name = "Attack",
						parameters = {
							{ name = "target", typeName = "Instance" },
							{ name = "damage", typeName = "number" },
						},
						returns = "boolean",
					},
				},
				clientMethods = {
					{
						name = "PlayClientEffect",
						parameters = {},
						returns = "()",
					},
				},
			},
		},
	}
end

return {
	["suggests custom type ids in Instance.new string positions"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local item = find(Model.complete({ line = 'Instance.new("Zo', position = 16 }, surface(), "Server"), "Zombie")
		assert(item and item.kind == "Class")
		assert(item.textEdit and item.textEdit.newText == "Zombie")
	end,
	["infers typed locals from literal constructors and limits methods to the facade"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local request = {
			line = 'local zombie = Instance.new("Zombie")\nzombie:',
			position = 52,
		}
		local items = Model.complete(request, surface(), "Server")
		assert(find(items, "Attack"))
		assert(not find(items, "PlayClientEffect"))
		assert(not find(items, "Health"))
	end,
	["infers enum constructors and Fragua.Get local assignments"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local request = {
			line = "local raw = Instance.new(Enum.FraguaType.Zombie)\nlocal zombie = Fragua.Get(raw)\nzombie:Att",
			position = 88,
		}
		local item = find(Model.complete(request, surface(), "Server"), "Attack")
		assert(item and item.textEdit and item.textEdit.newText == "Attack")
	end,
	["follows simple local aliases"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local request = {
			line = 'local zombie = Instance.new("Zombie")\nlocal copy = zombie\ncopy:',
			position = 66,
		}
		assert(find(Model.complete(request, surface(), "Server"), "Attack"))
	end,
	["invalidates local inference when the catalogue revision changes"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local request = { line = 'local ghost = Instance.new("Ghost")\nghost.', position = 46 }
		local cachedSurface = surface()
		assert(not find(Model.complete(request, cachedSurface, "Server"), "Haunt"))
		table.insert(cachedSurface.types, {
			id = "Ghost",
			name = "Ghost",
			properties = { { name = "Haunt", typeName = "string" } },
		})
		cachedSurface.revision = 8
		assert(find(Model.complete(request, cachedSurface, "Server"), "Haunt"))
	end,
	["uses the editor's one-based line and character cursor position"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local source = 'local zombie = Instance.new("Zombie")\nzombie:Att'
		local item = find(
			Model.complete({ line = source, position = { line = 2, character = 10 } }, surface(), "Server"),
			"Attack"
		)
		assert(item and item.textEdit)
		assert(item.textEdit.replace["end"] == #source - 1)
	end,
	["suggests custom enum items and does not create edits for an empty member prefix"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local enumItems = Model.complete({ line = "Enum.FraguaType.", position = 16 }, surface(), "Core")
		assert(find(enumItems, "Zombie"))
		local memberItems = Model.complete(
			{ line = 'local zombie = Instance.new("Zombie")\nzombie:', position = 52 },
			surface(),
			"Server"
		)
		assert(find(memberItems, "Attack").textEdit == nil)
	end,
	["only scans the current line and 200 preceding lines"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local lines = { 'local zombie = Instance.new("Zombie")' }
		for _ = 1, 200 do
			table.insert(lines, "")
		end
		table.insert(lines, "zombie:")
		assert(
			not find(
				Model.complete(
					{ line = table.concat(lines, "\n"), position = #table.concat(lines, "\n") },
					surface(),
					"Server"
				),
				"Attack"
			)
		)
	end,
	["extracts at most the current line and 200 predecessors"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local lines = {}
		for index = 1, 1000 do
			table.insert(lines, "ignored" .. index)
		end
		table.insert(lines, "current")
		local extracted =
			Model.extractContext({ line = table.concat(lines, "\n"), position = #table.concat(lines, "\n") })
		assert(#extracted == 201)
		assert(extracted[1] == "ignored801")
		assert(extracted[#extracted] == "current")
	end,
	["uses dot access for properties with a partial replacement range"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local source = 'local zombie = Instance.new("Zombie")\nzombie.He'
		local items = Model.complete({ line = source, position = #source }, surface(), "Server")
		local health = find(items, "Health")
		assert(health and health.kind == "Property")
		assert(not find(items, "Attack"))
		assert(health.textEdit and health.textEdit.replace.start == #source - 2)
		assert(health.textEdit.replace["end"] == #source)
	end,
	["uses colon access only for methods"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local source = 'local zombie = Instance.new("Zombie")\nzombie:'
		local items = Model.complete({ line = source, position = #source }, surface(), "Server")
		local attack = find(items, "Attack")
		assert(attack and attack.kind == "Method")
		assert(not find(items, "Health"))
		assert(attack.textEdit == nil)
	end,
	["qualified constructors retain their explicit facade through aliases"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local source = 'local zombie = Fragua.Client.Instance.new("Zombie")\nlocal copy = zombie\ncopy:'
		local items = Model.complete({ line = source, position = #source }, surface(), "Server")
		assert(find(items, "PlayClientEffect"))
		assert(not find(items, "Attack"))
	end,
	["qualified Get calls select their invoked facade"] = function()
		assert(ok and Model, "AutocompleteModel should be available")
		local source = 'local raw = Fragua.Server.Instance.new("Zombie")\nlocal zombie = Fragua.Core.Get(raw)\nzombie:'
		local items = Model.complete({ line = source, position = #source }, surface(), "Server")
		assert(not find(items, "Attack"))
		assert(not find(items, "PlayClientEffect"))
		assert(find(items, "Destroy"))
	end,
}
