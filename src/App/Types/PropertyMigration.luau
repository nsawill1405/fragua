local PropertyMigration = {}

local function reference(prop)
	return prop.valueType == "Instance" or prop.valueType == "FraguaInstance" or prop.referenceType ~= nil
end

local function copyMap(source)
	return table.clone(source or {})
end

local function matches(previous, nextProperties)
	local byId, byName = {}, {}
	for _, prop in previous do
		if prop.id then
			byId[prop.id] = prop
		end
		byName[prop.name] = prop
	end
	local result, used = {}, {}
	for _, prop in nextProperties do
		local old = (prop.id and byId[prop.id])
			or (prop.originalName and byName[prop.originalName])
			or byName[prop.name]
		if old and not used[old] then
			result[prop] = old
			used[old] = true
		end
	end
	return result, used
end

function PropertyMigration.plan(previous, nextProperties)
	local matched, used = matches(previous, nextProperties)
	local operations = {}
	for _, nextProp in nextProperties do
		table.insert(operations, { old = matched[nextProp], new = nextProp })
	end
	for _, old in previous do
		if not used[old] then
			table.insert(operations, { old = old })
		end
	end
	return operations
end

function PropertyMigration.apply(state, previous, nextProperties)
	local result = { attributes = copyMap(state.attributes), references = copyMap(state.references) }
	for _, operation in PropertyMigration.plan(previous, nextProperties) do
		local old, new = operation.old, operation.new
		if old and not new then
			result.attributes[old.name] = nil
			result.references[old.name] = nil
		elseif new then
			local oldRef, newRef = old and reference(old), reference(new)
			local preserved = old and oldRef == newRef
			local value = if preserved
				then (if newRef then result.references[old.name] else result.attributes[old.name])
				else nil
			if old then
				result.attributes[old.name] = nil
				result.references[old.name] = nil
			end
			result.attributes[new.name] = nil
			result.references[new.name] = nil
			if newRef then
				result.references[new.name] = if preserved then value else new.default
			else
				result.attributes[new.name] = if preserved and value ~= nil then value else new.default
			end
		end
	end
	return result
end

function PropertyMigration.isReference(prop)
	return reference(prop)
end

return PropertyMigration
