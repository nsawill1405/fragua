local PreviewCommit = {}

function PreviewCommit.new(initial, onPreview: ((any) -> ())?)
	return {
		original = initial,
		current = initial,
		committed = false,
		onPreview = onPreview,
	}
end

function PreviewCommit.preview(state, value)
	state.current = value
	if state.onPreview then
		state.onPreview(value)
	end
end

function PreviewCommit.commit(state)
	state.committed = true
	state.original = state.current
	return state.current
end

function PreviewCommit.cancel(state)
	state.current = state.original
	state.committed = false
	if state.onPreview then
		state.onPreview(state.original)
	end
	return state.original
end

return PreviewCommit
