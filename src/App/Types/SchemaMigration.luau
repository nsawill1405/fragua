local SchemaMigration = {}

local function byName(properties)
	local result = {}
	for _, property in properties or {} do
		result[property.name] = property
	end
	return result
end

function SchemaMigration.plan(previous, nextDefinition)
	local previousByName = byName(if previous then previous.properties else {})
	local nextByName = byName(nextDefinition.properties)
	local plan = { add = {}, remove = {}, rename = {}, warnings = {} }

	for name, property in nextByName do
		local old = previousByName[name]
		if not old then
			table.insert(plan.add, property)
		elseif old.valueType ~= property.valueType then
			table.insert(plan.warnings, {
				code = "property-type-change",
				name = name,
				from = old.valueType,
				to = property.valueType,
			})
		end
	end
	for name in previousByName do
		if not nextByName[name] then
			table.insert(plan.remove, name)
		end
	end

	table.sort(plan.add, function(a, b)
		return a.name < b.name
	end)
	table.sort(plan.remove)
	table.sort(plan.warnings, function(a, b)
		return a.name < b.name
	end)

	if #plan.add == 1 and #plan.remove == 1 then
		local added = plan.add[1]
		local removed = previousByName[plan.remove[1]]
		if added.valueType == removed.valueType then
			table.insert(plan.rename, { from = removed.name, to = added.name })
			table.clear(plan.add)
			table.clear(plan.remove)
		end
	end

	return plan
end

return SchemaMigration
