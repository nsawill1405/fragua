local BackingClassResolver = {}

function BackingClassResolver.resolve(typeId: string, lookupType): (string?, string?)
	local visited = {}
	local current = typeId

	while true do
		local def = lookupType(current)
		if not def then
			return current, nil
		end
		if visited[current] then
			return nil, `Inheritance cycle at "{current}"`
		end
		visited[current] = true
		current = def.extends
	end
end

return BackingClassResolver
