--Types
export type PropertyIdentityState = {
	typeId: string,
	nextIndex: number,
	reserved: { [string]: boolean },
}

--Constants
local PropertyIdentity = {}

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

return PropertyIdentity
