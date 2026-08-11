local Roblox = require("@lune/roblox")
local EnumDefaults = require("../src/App/Types/EnumDefaults")
local PropertyMigration = require("../src/App/Types/PropertyMigration")
local TypeValue = require("../src/App/Types/TypeValue")
local DefaultEditor = require("../src/App/Types/DefaultEditor")

return {
	["FraguaType is live and enum values select persist read and write"] = function()
		local definitions = { { id = "Zombie" }, { id = "BossZombie" } }
		local names = EnumDefaults.names({ "Material", "NormalId" }, definitions)
		assert(table.find(names, "FraguaType"))
		assert(table.concat(EnumDefaults.items("FraguaType", definitions), ",") == "BossZombie,Zombie")
		local facade = EnumDefaults.facade(definitions)
		local selected = facade.FraguaType.Zombie
		assert(EnumDefaults.write(facade, "FraguaType", selected, { "Zombie" }) == "Zombie")
		assert(EnumDefaults.read(facade, "FraguaType", "Zombie") == selected)
		local persisted = TypeValue.deserialize(TypeValue.serialize(selected.Name))
		assert(persisted == "Zombie")
	end,
	["migration removes stale representations and reapplies defaults"] = function()
		local reference = Roblox.Instance.new("Folder")
		local scalar = PropertyMigration.apply(
			{ attributes = {}, references = { Target = reference } },
			{ { id = "p", name = "Target", valueType = "FraguaInstance" } },
			{ { id = "p", name = "Target", valueType = "number", default = 7 } }
		)
		assert(scalar.references.Target == nil and scalar.attributes.Target == 7)
		local again = PropertyMigration.apply(
			scalar,
			{ { id = "p", name = "Target", valueType = "number", default = 7 } },
			{ { id = "p", name = "Target", valueType = "FraguaInstance", default = nil } }
		)
		assert(again.attributes.Target == nil and again.references.Target == nil)
		local scalarAgain = PropertyMigration.apply(
			{ attributes = { Target = 9 }, references = {} },
			{ { id = "p", name = "Target", valueType = "number" } },
			{ { id = "p", name = "Target", valueType = "Instance", default = reference } }
		)
		assert(scalarAgain.attributes.Target == nil and scalarAgain.references.Target == reference)
		local final = PropertyMigration.apply(
			scalarAgain,
			{ { id = "p", name = "Target", valueType = "Instance" } },
			{ { id = "p", name = "Target", valueType = "number", default = 11 } }
		)
		assert(final.references.Target == nil and final.attributes.Target == 11)
	end,
	["stable identity preserves renamed reference amid unrelated edits"] = function()
		local reference = Roblox.Instance.new("Folder")
		local migrated = PropertyMigration.apply(
			{ attributes = { Removed = 3 }, references = { Leader = reference } },
			{
				{ id = "leader", name = "Leader", valueType = "FraguaInstance" },
				{ id = "removed", name = "Removed", valueType = "number" },
			},
			{
				{ id = "leader", originalName = "Leader", name = "Owner", valueType = "FraguaInstance" },
				{ id = "added", name = "Added", valueType = "boolean", default = true },
			}
		)
		assert(migrated.references.Leader == nil and migrated.references.Owner == reference)
		assert(migrated.attributes.Removed == nil and migrated.attributes.Added == true)
	end,
	["custom reference defaults accept descendants through injected lookup"] = function()
		local boss = Roblox.Instance.new("Folder")
		boss:SetAttribute("_FraguaType", "BossZombie")
		local valid = TypeValue.validate("FraguaInstance", boss, {
			referenceType = "Zombie",
			lookupType = function(id)
				if id == "BossZombie" then
					return { id = id, extends = "Zombie" }
				end
				if id == "Zombie" then
					return { id = id, extends = "Configuration" }
				end
			end,
		})
		assert(valid)
		local TypeDraft = require("../src/App/Types/TypeDraft")
		local draft = TypeDraft.new("Spawner")
		local category = TypeDraft.addCategory(draft, "Data")
		local property = TypeDraft.addProperty(draft, category, "Target", "FraguaInstance", boss)
		TypeDraft.updateProperty(draft, property, { referenceType = "Zombie" })
		local errors = TypeDraft.validate(draft, function(id)
			if id == "BossZombie" then
				return { id = id, extends = "Zombie", properties = {} }
			end
			if id == "Zombie" then
				return { id = id, extends = "Configuration", properties = {} }
			end
		end)
		assert(#errors == 0)
	end,
	["BrickColor display snaps to the value that is committed"] = function()
		local arbitrary = Roblox.Color3.new(0.123, 0.456, 0.789)
		local typed, display = DefaultEditor.colorValue("BrickColor", arbitrary)
		assert(typeof(typed) == "BrickColor" and display == typed.Color)
		assert(display ~= arbitrary)
	end,
}
