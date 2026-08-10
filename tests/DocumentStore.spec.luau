local DocumentStore = require("../src/App/ScriptEditor/DocumentStore")

return {
	["reuses an open target instead of duplicating its tab"] = function()
		local state = DocumentStore.new()
		local _, firstId =
			DocumentStore.open(state, { targetKey = "ZombieBehavior", title = "Zombie", source = "return {}" })
		local _, secondId =
			DocumentStore.open(state, { targetKey = "ZombieBehavior", title = "Zombie", source = "changed" })
		assert(firstId == secondId)
		assert(#state.order == 1)
	end,
	["derives dirty state from saved source"] = function()
		local state = DocumentStore.new()
		local _, id = DocumentStore.open(state, { targetKey = "A", title = "A", source = "one" })
		DocumentStore.edit(state, id, "two", 4)
		assert(state.documents[id].dirty)
		DocumentStore.markSaved(state, id, "two")
		assert(not state.documents[id].dirty)
	end,
	["keeps dirty text when an external source changes"] = function()
		local state = DocumentStore.new()
		local _, id = DocumentStore.open(state, { targetKey = "A", title = "A", source = "one" })
		DocumentStore.edit(state, id, "mine", 5)
		DocumentStore.markExternalChange(state, id, "theirs")
		assert(state.documents[id].source == "mine")
		assert(state.documents[id].conflicted)
	end,
}
