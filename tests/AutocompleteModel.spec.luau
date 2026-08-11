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
		assert(find(items, "Health"))
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
		local request = { line = 'local ghost = Instance.new("Ghost")\nghost:', position = 46 }
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
}
