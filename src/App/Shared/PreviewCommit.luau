local PreviewCommit = {}

function PreviewCommit.new(initial)
	return {
		original = initial,
		current = initial,
		committed = false,
	}
end

function PreviewCommit.preview(state, value)
	state.current = value
end

function PreviewCommit.commit(state)
	state.committed = true
	return state.current
end

function PreviewCommit.cancel(state)
	state.current = state.original
	state.committed = false
	return state.original
end

return PreviewCommit
