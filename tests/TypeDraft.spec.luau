local TypeDraft = require("../src/App/Types/TypeDraft")

return {
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
}
