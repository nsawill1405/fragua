local EnginePropResolver = {}

function EnginePropResolver.resolve(className: string, isA, exact, families)
	local rows = {}
	local indexes = {}

	local function merge(layer)
		for _, property in layer or {} do
			local index = indexes[property.name]
			if index then
				rows[index] = property
			else
				table.insert(rows, property)
				indexes[property.name] = #rows
			end
		end
	end

	merge(exact.Instance)
	for _, family in families or {} do
		if isA(family.className) then
			merge(family.properties)
		end
	end
	if className ~= "Instance" then
		merge(exact[className])
	end
	return rows
end

return EnginePropResolver
