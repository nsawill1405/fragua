local DocumentStore = {}

function DocumentStore.new()
	return { nextId = 0, order = {}, documents = {}, activeId = nil }
end

function DocumentStore.open(state, descriptor)
	for _, id in state.order do
		local document = state.documents[id]
		if document.targetKey == descriptor.targetKey then
			state.activeId = id
			return state, id
		end
	end

	state.nextId += 1
	local id = `document-{state.nextId}`
	state.documents[id] = {
		id = id,
		targetKey = descriptor.targetKey,
		title = descriptor.title,
		source = descriptor.source,
		savedSource = descriptor.source,
		dirty = false,
		conflicted = false,
		typeId = descriptor.typeId,
		sharedCount = descriptor.sharedCount or 0,
		cursor = descriptor.cursor or 1,
		selectionStart = descriptor.selectionStart or -1,
		scrollY = descriptor.scrollY or 0,
	}
	table.insert(state.order, id)
	state.activeId = id
	return state, id
end

function DocumentStore.select(state, id: string)
	if state.documents[id] then
		state.activeId = id
	end
end

function DocumentStore.edit(state, id: string, source: string, cursor: number?, selectionStart: number?)
	local document = state.documents[id]
	if not document then
		return
	end
	document.source = source
	document.cursor = cursor or document.cursor
	document.selectionStart = selectionStart or document.selectionStart
	document.dirty = document.source ~= document.savedSource
end

function DocumentStore.markSaved(state, id: string, source: string?)
	local document = state.documents[id]
	if not document then
		return
	end
	if source ~= nil then
		document.source = source
	end
	document.savedSource = document.source
	document.dirty = false
	document.conflicted = false
end

function DocumentStore.markExternalChange(state, id: string, source: string)
	local document = state.documents[id]
	if not document then
		return
	end
	if document.dirty then
		document.conflicted = source ~= document.savedSource
	else
		document.source = source
		document.savedSource = source
		document.conflicted = false
	end
end

function DocumentStore.closeDecision(state, id: string): string
	local document = state.documents[id]
	if not document then
		return "missing"
	end
	return if document.dirty then "confirm" else "close"
end

function DocumentStore.close(state, id: string)
	state.documents[id] = nil
	local index = table.find(state.order, id)
	if index then
		table.remove(state.order, index)
	end
	if state.activeId == id then
		state.activeId = state.order[math.max(1, #state.order)]
	end
end

return DocumentStore
