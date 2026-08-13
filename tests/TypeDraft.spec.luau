local TypeDraft = require("../src/App/Types/TypeDraft")

return {
	["stores typed property defaults"] = function()
		local draft = TypeDraft.new("Zombie")
		local categoryId = TypeDraft.addCategory(draft, "Data")
		local propertyId = TypeDraft.addProperty(draft, categoryId, "Enabled", "boolean", false)
		TypeDraft.updateProperty(draft, propertyId, { defaultValue = true })
		assert(TypeDraft.snapshotEditableProperties(draft)[1].defaultValue == true)
	end,
	["synchronizes compatibility text after typed default changes"] = function()
		local draft = TypeDraft.new("Zombie")
		local categoryId = TypeDraft.addCategory(draft, "Data")
		local propertyId = TypeDraft.addProperty(draft, categoryId, "Enabled", "boolean", false)
		TypeDraft.updateProperty(draft, propertyId, { defaultValue = true })
		assert(draft.properties[propertyId].defaultText == "true")
	end,
	["rejects core and inherited property name collisions"] = function()
		local draft = TypeDraft.new("Child", "Base")
		local categoryId = TypeDraft.addCategory(draft, "Data")
		local nameId = TypeDraft.addProperty(draft, categoryId, "Name", "string", "Child")
		local archivableId = TypeDraft.addProperty(draft, categoryId, "Archivable", "boolean", true)
		local coreId = TypeDraft.addProperty(draft, categoryId, "_FraguaType", "string", "Child")
		local inheritedId = TypeDraft.addProperty(draft, categoryId, "Health", "number", 100)
		local errors = TypeDraft.validate(draft, function(typeId)
			if typeId == "Base" then
				return {
					id = "Base",
					extends = "Configuration",
					properties = { { name = "Health" } },
				}
			end
			return nil
		end)
		local collided = {}
		for _, error in errors do
			if error.code == "reserved-property" then
				collided[error.fieldId] = true
			end
		end
		assert(collided[nameId] and collided[archivableId] and collided[coreId] and collided[inheritedId])
	end,
	["rejects wrapper and lifecycle property name collisions"] = function()
		local draft = TypeDraft.new("Zombie")
		local categoryId = TypeDraft.addCategory(draft, "Data")
		local destroyId = TypeDraft.addProperty(draft, categoryId, "Destroy", "string", "hidden")
		local lifecycleId = TypeDraft.addProperty(draft, categoryId, "onStart", "boolean", false)
		local errors = TypeDraft.validate(draft, function()
			return nil
		end)
		local collided = {}
		for _, error in errors do
			if error.code == "reserved-property" then
				collided[error.fieldId] = true
			end
		end
		assert(collided[destroyId] and collided[lifecycleId])
	end,
	["rejects inherited native method and event collisions"] = function()
		local draft = TypeDraft.new("Zombie")
		local categoryId = TypeDraft.addCategory(draft, "Data")
		local methodId = TypeDraft.addProperty(draft, categoryId, "FindFirstChild", "string", "hidden")
		local eventId = TypeDraft.addProperty(draft, categoryId, "AncestryChanged", "boolean", false)
		local errors = TypeDraft.validate(draft, function()
			return nil
		end)
		local collided = {}
		for _, error in errors do
			if error.code == "reserved-property" then
				collided[error.fieldId] = true
			end
		end
		assert(collided[methodId] and collided[eventId])
	end,
	["rejects current inherited Object and Instance member collisions"] = function()
		local draft = TypeDraft.new("Zombie")
		local categoryId = TypeDraft.addCategory(draft, "Data")
		local propertyIds = {}
		for _, name in { "Changed", "GetStyled", "QueryDescendants", "StyledPropertiesChanged", "PredictionMode" } do
			table.insert(propertyIds, TypeDraft.addProperty(draft, categoryId, name, "string", "hidden"))
		end
		local errors = TypeDraft.validate(draft, function()
			return nil
		end)
		local collided = {}
		for _, error in errors do
			if error.code == "reserved-property" then
				collided[error.fieldId] = true
			end
		end
		for _, propertyId in propertyIds do
			assert(collided[propertyId])
		end
	end,
	["keeps property category identity stable across rename"] = function()
		local draft = TypeDraft.new("Zombie")
		local categoryId = TypeDraft.addCategory(draft, "AI")
		local propertyId = TypeDraft.addProperty(draft, categoryId, "DetectRange", "number", "40")
		TypeDraft.renameCategory(draft, categoryId, "Senses")
		assert(draft.properties[propertyId].categoryId == categoryId)
		assert(draft.categories[categoryId].name == "Senses")
	end,
	["reports duplicate names across categories"] = function()
		local draft = TypeDraft.new("Zombie")
		local dataId = TypeDraft.addCategory(draft, "Data")
		local aiId = TypeDraft.addCategory(draft, "AI")
		TypeDraft.addProperty(draft, dataId, "Health", "number", "100")
		TypeDraft.addProperty(draft, aiId, "Health", "number", "150")
		local errors = TypeDraft.validate(draft, function()
			return nil
		end)
		assert(errors[1].code == "duplicate-property")
	end,
	["reports invalid defaults without changing the draft"] = function()
		local draft = TypeDraft.new("Zombie")
		local categoryId = TypeDraft.addCategory(draft, "Data")
		local propertyId = TypeDraft.addProperty(draft, categoryId, "WalkSpeed", "number", "fast")
		local errors = TypeDraft.validate(draft, function()
			return nil
		end)
		assert(errors[1].fieldId == propertyId)
		assert(errors[1].code == "invalid-default")
		assert(draft.properties[propertyId].defaultText == "fast")
	end,
	["reports inheritance cycles"] = function()
		local draft = TypeDraft.new("A", "B")
		local errors = TypeDraft.validate(draft, function(typeId)
			if typeId == "B" then
				return { id = "B", extends = "A" }
			end
			return nil
		end)
		assert(errors[1].code == "inheritance-cycle")
	end,
	["stable ids survive extends category and property changes"] = function()
		local draft = TypeDraft.new("Child")
		local categoryId = TypeDraft.addCategory(draft, "Data")
		local propertyId = TypeDraft.addProperty(draft, categoryId, "Health", "number", "100")
		TypeDraft.setExtends(draft, "Base")
		TypeDraft.renameCategory(draft, categoryId, "Stats")
		TypeDraft.updateProperty(draft, propertyId, { defaultText = "150" })
		local snapshot = TypeDraft.snapshotEditableProperties(draft)
		assert(draft.extends == "Base")
		assert(snapshot[1].id == propertyId and snapshot[1].categoryName == "Stats")
		assert(snapshot[1].defaultText == "150")
	end,
	["value type replacement preserves category order and uses its typed default"] = function()
		local Roblox = require("@lune/roblox")
		local draft = TypeDraft.new("Zombie")
		local dataId = TypeDraft.addCategory(draft, "Data")
		local aiId = TypeDraft.addCategory(draft, "AI")
		local propertyId = TypeDraft.addProperty(draft, aiId, "Spawn", "Vector3", Roblox.Vector3.zero)
		local order = TypeDraft.snapshotCategoryOrder(draft)
		TypeDraft.updateProperty(draft, propertyId, {
			valueType = "CFrame",
			defaultValue = Roblox.CFrame.identity,
		})
		local after = TypeDraft.snapshotCategoryOrder(draft)
		assert(#after == #order and after[1] == dataId and after[2] == aiId)
		assert(draft.properties[propertyId].defaultValue == Roblox.CFrame.identity)
		assert(draft.properties[propertyId].defaultInputError == nil)
	end,
	["category order snapshots cannot mutate the draft"] = function()
		local draft = TypeDraft.new("Zombie")
		local first = TypeDraft.addCategory(draft, "First")
		TypeDraft.addCategory(draft, "Second")
		local order = TypeDraft.snapshotCategoryOrder(draft)
		order[1] = "changed"
		assert(draft.categoryOrder[1] == first)
	end,
}
