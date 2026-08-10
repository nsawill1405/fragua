local PreviewCommit = require("../src/App/Shared/PreviewCommit")

return {
	["multiple previews produce one final commit value"] = function()
		local state = PreviewCommit.new(10)
		PreviewCommit.preview(state, 20)
		PreviewCommit.preview(state, 30)
		assert(state.original == 10 and state.current == 30 and state.committed == false)
		assert(PreviewCommit.commit(state) == 30 and state.committed == true)
	end,
	["cancellation restores original value"] = function()
		local state = PreviewCommit.new("#FF0000")
		PreviewCommit.preview(state, "#00FF00")
		assert(PreviewCommit.cancel(state) == "#FF0000")
	end,
	["preview and cancel notify the live target without committing"] = function()
		local seen = {}
		local state = PreviewCommit.new("red", function(value)
			table.insert(seen, value)
		end)
		PreviewCommit.preview(state, "blue")
		PreviewCommit.cancel(state)
		assert(table.concat(seen, ",") == "blue,red", table.concat(seen, ","))
		assert(state.committed == false)
	end,
	["a later cancelled drag restores the most recent commit"] = function()
		local state = PreviewCommit.new(0)
		PreviewCommit.preview(state, 0.4)
		assert(PreviewCommit.commit(state) == 0.4)
		PreviewCommit.preview(state, 0.8)
		assert(PreviewCommit.cancel(state) == 0.4)
	end,
}
