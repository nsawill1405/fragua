local SchemaResolver = {}

local function cloneProperty(property, origin: string, inherited: boolean)
	local copy = table.clone(property)
	copy.origin = property.origin or origin
	copy.inherited = inherited
	return copy
end

function SchemaResolver.resolve(definition, lookupCustom, lookupEngine)
	local active = {}

	local function resolveOne(current)
		if active[current.id] then
			return {}, {
				code = "inheritance-cycle",
				message = `Inheritance cycle reaches "{current.id}".`,
			}
		end
		active[current.id] = true

		local base = {}
		local parent = lookupCustom(current.extends)
		if parent then
			local parentSchema, err = resolveOne(parent)
			if err then
				active[current.id] = nil
				return {}, err
			end
			for _, property in parentSchema do
				table.insert(base, cloneProperty(property, property.origin or parent.id, true))
			end
		else
			for _, property in lookupEngine(current.extends) or {} do
				table.insert(base, cloneProperty(property, current.extends, true))
			end
		end

		local indexes = {}
		for index, property in base do
			indexes[property.name] = index
		end
		for _, property in current.properties or {} do
			local resolved = cloneProperty(property, current.id, false)
			local existing = indexes[property.name]
			if existing then
				base[existing] = resolved
			else
				table.insert(base, resolved)
				indexes[property.name] = #base
			end
		end

		active[current.id] = nil
		return base, nil
	end

	return resolveOne(definition)
end

return SchemaResolver
