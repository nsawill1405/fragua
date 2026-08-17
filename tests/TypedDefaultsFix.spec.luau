local Roblox = require("@lune/roblox")
local EnumDefaults = require("../src/App/Types/EnumDefaults")
local PropertyMigration = require("../src/App/Types/PropertyMigration")
local TypeValue = require("../src/App/Types/TypeValue")
local DefaultEditor = require("../src/App/Types/DefaultEditor")
local PropertyIdentity = require("../src/App/Types/PropertyIdentity")

return {
	["FraguaType is live and enum values select persist read and write"] = function()
		local definitions = { { id = "Zombie" }, { id = "BossZombie" } }
		local names = EnumDefaults.names({ "Material", "NormalId" }, definitions)
		assert(table.find(names, "FraguaType"))
		assert(table.concat(EnumDefaults.items("FraguaType", definitions), ",") == "BossZombie,Zombie")
		local customNames = EnumDefaults.names({ "Material" }, definitions, { { id = "Mood" } })
		assert(table.find(customNames, "Mood"))
		assert(
			table.concat(
				EnumDefaults.items("Mood", definitions, nil, { { id = "Mood", items = { "Happy", "Sad" } } }),
				","
			) == "Happy,Sad"
		)
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
	["editor identities stay unique across inheritance reopen delete and add"] = function()
		local parent = PropertyIdentity.new("Parent", {})
		local parentId = PropertyIdentity.allocate(parent)
		local reopened = PropertyIdentity.new("Child", { { id = parentId }, { id = "Child:property:1" } })
		local childId = PropertyIdentity.allocate(reopened)
		assert(parentId == "Parent:property:1")
		assert(childId == "Child:property:2")
		PropertyIdentity.reserve(reopened, childId)
		assert(PropertyIdentity.allocate(reopened) == "Child:property:3")
	end,
	["create parent then child remaps draft ids to unique type scoped identities"] = function()
		-- same draft-scope policy TypeEditor uses before first save
		local parentDraft = PropertyIdentity.new(PropertyIdentity.DRAFT_TYPE_ID, {})
		local parentOwn = {
			{ id = PropertyIdentity.allocate(parentDraft), name = "Health" },
			{ id = PropertyIdentity.allocate(parentDraft), name = "Speed" },
		}
		assert(parentOwn[1].id == "__FraguaDraft:property:1")
		assert(parentOwn[2].id == "__FraguaDraft:property:2")
		local parentIds = PropertyIdentity.persistOwnedIds("Zombie", parentOwn, {}, true)
		for index, prop in parentOwn do
			prop.id = parentIds[index]
		end
		assert(parentOwn[1].id == "Zombie:property:1")
		assert(parentOwn[2].id == "Zombie:property:2")

		-- child create also drafts under the shared scope then remaps with inherited reserved
		local childDraft = PropertyIdentity.new(PropertyIdentity.DRAFT_TYPE_ID, {})
		local childOwn = {
			{ id = PropertyIdentity.allocate(childDraft), name = "Armor" },
			{ id = PropertyIdentity.allocate(childDraft), name = "Damage" },
		}
		assert(childOwn[1].id == "__FraguaDraft:property:1")
		local childIds = PropertyIdentity.persistOwnedIds("BossZombie", childOwn, parentOwn, true)
		for index, prop in childOwn do
			prop.id = childIds[index]
		end

		-- reopen each and add a third prop the way TypeEditor seeds identity
		local parentEditor = PropertyIdentity.new("Zombie", parentOwn)
		table.insert(parentOwn, { id = PropertyIdentity.allocate(parentEditor), name = "Faction" })
		local childEditor = PropertyIdentity.new("BossZombie", childOwn)
		for _, prop in parentOwn do
			PropertyIdentity.reserve(childEditor, prop.id)
		end
		table.insert(childOwn, { id = PropertyIdentity.allocate(childEditor), name = "Rage" })

		local seen: { [string]: boolean } = {}
		for _, prop in parentOwn do
			assert(not seen[prop.id], `duplicate resolved id {prop.id}`)
			seen[prop.id] = true
		end
		for _, prop in childOwn do
			assert(not seen[prop.id], `duplicate resolved id {prop.id}`)
			seen[prop.id] = true
			assert(string.match(prop.id, "^BossZombie:property:%d+$"))
		end
		assert(#parentOwn + #childOwn == 6)
	end,
	["duplicate inherited identities cannot steal a mixed reference rename"] = function()
		local reference = Roblox.Instance.new("Folder")
		local duplicate = "legacy:property:1"
		local migrated = PropertyMigration.apply(
			{ attributes = { Health = 10 }, references = { Leader = reference } },
			{
				{ id = duplicate, name = "Health", valueType = "number" },
				{ id = duplicate, name = "Leader", valueType = "FraguaInstance" },
			},
			{
				{ id = duplicate, name = "Health", valueType = "number" },
				{ id = "Child:property:2", originalName = "Leader", name = "Owner", valueType = "FraguaInstance" },
				{ id = "Child:property:3", name = "Enabled", valueType = "boolean", default = true },
			}
		)
		assert(migrated.attributes.Health == 10 and migrated.attributes.Enabled == true)
		assert(migrated.references.Owner == reference and migrated.references.Leader == nil)
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
	["mounted row validation seam accepts descendant references"] = function()
		local boss = Roblox.Instance.new("Folder")
		boss:SetAttribute("_FraguaType", "BossZombie")
		local message = DefaultEditor.valueError(boss, {
			valueType = "FraguaInstance",
			referenceType = "Zombie",
		}, function(id)
			if id == "BossZombie" then
				return { id = id, extends = "Zombie" }
			end
			if id == "Zombie" then
				return { id = id, extends = "Configuration" }
			end
		end)
		assert(message == nil)
	end,
	["BrickColor display snaps to the value that is committed"] = function()
		local arbitrary = Roblox.Color3.new(0.123, 0.456, 0.789)
		local typed, display = DefaultEditor.colorValue("BrickColor", arbitrary)
		assert(typeof(typed) == "BrickColor" and display == typed.Color)
		assert(display ~= arbitrary)
	end,
}
