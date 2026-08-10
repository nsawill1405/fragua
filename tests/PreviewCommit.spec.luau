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
}
