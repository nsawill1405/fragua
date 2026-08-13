--Types
export type PropertyIdentityState = {
	typeId: string,
	nextIndex: number,
	reserved: { [string]: boolean },
}

--Constants
local PropertyIdentity = {}
PropertyIdentity.DRAFT_TYPE_ID = "__FraguaDraft"

--Functions
local function advanceFromId(state: PropertyIdentityState, id: string)
	local suffix = string.match(id, ":property:(%d+)$")
	if not suffix then
		return
	end
	local index = tonumber(suffix)
	if index and index >= state.nextIndex then
		state.nextIndex = index + 1
	end
end

local function isDraftId(id: string): boolean
	return string.match(id, `^{PropertyIdentity.DRAFT_TYPE_ID}:property:%d+$`) ~= nil
end

function PropertyIdentity.new(typeId: string, existingProps: { { id: string? } }?): PropertyIdentityState
	local state: PropertyIdentityState = {
		typeId = typeId,
		nextIndex = 1,
		reserved = {},
	}
	for _, prop in existingProps or {} do
		if typeof(prop.id) == "string" and prop.id ~= "" then
			PropertyIdentity.reserve(state, prop.id)
		end
	end
	return state
end

function PropertyIdentity.reserve(state: PropertyIdentityState, id: string)
	if id == "" then
		return
	end
	state.reserved[id] = true
	advanceFromId(state, id)
end

function PropertyIdentity.allocate(state: PropertyIdentityState): string
	while true do
		local id = `{state.typeId}:property:{state.nextIndex}`
		state.nextIndex += 1
		if not state.reserved[id] then
			state.reserved[id] = true
			return id
		end
	end
end

-- rewrite draft/unowned ids onto type-scoped identities; reserve inherited first
function PropertyIdentity.persistOwnedIds(
	typeId: string,
	ownProps: { { id: string? } },
	inheritedProps: { { id: string? } }?,
	rewriteAll: boolean
): { string }
	local state = PropertyIdentity.new(typeId, {})
	for _, prop in inheritedProps or {} do
		if typeof(prop.id) == "string" and prop.id ~= "" then
			PropertyIdentity.reserve(state, prop.id)
		end
	end
	local ids = {}
	for _, prop in ownProps do
		local id = prop.id
		local keep = not rewriteAll and typeof(id) == "string" and id ~= "" and not isDraftId(id)
		if keep then
			PropertyIdentity.reserve(state, id :: string)
			table.insert(ids, id :: string)
		else
			table.insert(ids, PropertyIdentity.allocate(state))
		end
	end
	return ids
end

return PropertyIdentity
