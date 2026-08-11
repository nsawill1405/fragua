local ReferencePolicy = {}

function ReferencePolicy.matches(actualType: string, expectedType: string, lookupType: ((string) -> any)?): boolean
	if actualType == expectedType then
		return true
	end
	if not lookupType then
		return false
	end
	local visited = {}
	local current = actualType
	while current and current ~= "" and not visited[current] do
		visited[current] = true
		local definition = lookupType(current)
		current = definition and definition.extends or nil
		if current == expectedType then
			return true
		end
	end
	return false
end

return ReferencePolicy
