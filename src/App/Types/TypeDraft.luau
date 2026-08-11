local Util = if script then require(script.Parent.Parent.Shared.Util) else require("../Shared/Util")
local TypeValue = if script then require(script.Parent.TypeValue) else require("./TypeValue")
local EngineSchemas = if script then require(script.Parent.EngineSchemas) else nil
local WrapperPolicy = if script
	then require(script.Parent.Parent.Runtime.WrapperPolicy)
	else require("../Runtime/WrapperPolicy")

local TypeDraft = {}

local function nextId(draft, kind: string): string
	draft.nextId += 1
	return `{kind}-{draft.nextId}`
end

function TypeDraft.new(typeId: string, extends: string?)
	return {
		id = typeId,
		extends = extends or "Configuration",
		nextId = 0,
		categoryOrder = {},
		categories = {},
		propertyOrder = {},
		properties = {},
	}
end

function TypeDraft.addCategory(draft, name: string): string
	local id = nextId(draft, "category")
	draft.categories[id] = { id = id, name = name }
	table.insert(draft.categoryOrder, id)
	return id
end

function TypeDraft.renameCategory(draft, categoryId: string, name: string)
	local category = draft.categories[categoryId]
	if category then
		category.name = name
	end
end

function TypeDraft.setExtends(draft, extends: string)
	draft.extends = extends
end

function TypeDraft.removeCategory(draft, categoryId: string)
	draft.categories[categoryId] = nil
	local categoryIndex = table.find(draft.categoryOrder, categoryId)
	if categoryIndex then
		table.remove(draft.categoryOrder, categoryIndex)
	end
	for index = #draft.propertyOrder, 1, -1 do
		local propertyId = draft.propertyOrder[index]
		if draft.properties[propertyId].categoryId == categoryId then
			draft.properties[propertyId] = nil
			table.remove(draft.propertyOrder, index)
		end
	end
end

function TypeDraft.addProperty(draft, categoryId: string, name: string, valueType: string, defaultInput: any): string
	assert(draft.categories[categoryId], `Unknown category id: {categoryId}`)
	local id = nextId(draft, "property")
	local property = {
		id = id,
		categoryId = categoryId,
		name = name,
		valueType = valueType,
	}
	if typeof(defaultInput) == "string" and valueType ~= "string" and valueType ~= "enum" then
		property.defaultText = defaultInput
		local parsed, value = Util.parseValue(valueType, defaultInput)
		if parsed then
			property.defaultValue = value
		else
			property.defaultInputError = `Default is not a valid {valueType}.`
		end
	else
		property.defaultValue = defaultInput
		property.defaultText = Util.formatValue(defaultInput)
	end
	draft.properties[id] = property
	table.insert(draft.propertyOrder, id)
	return id
end

function TypeDraft.removeProperty(draft, propertyId: string)
	draft.properties[propertyId] = nil
	local index = table.find(draft.propertyOrder, propertyId)
	if index then
		table.remove(draft.propertyOrder, index)
	end
end

function TypeDraft.updateProperty(draft, propertyId: string, changes)
	local property = draft.properties[propertyId]
	if not property then
		return
	end
	for key, value in changes do
		property[key] = value
	end
	if changes.defaultText ~= nil then
		local parsed, value = Util.parseValue(property.valueType, property.defaultText or "")
		if parsed then
			property.defaultValue = value
			property.defaultInputError = nil
		else
			property.defaultValue = nil
			property.defaultInputError = `Default is not a valid {property.valueType}.`
		end
	elseif changes.defaultValue ~= nil then
		property.defaultInputError = nil
		property.defaultText = Util.formatValue(property.defaultValue)
	elseif changes.valueType ~= nil then
		property.defaultValue = TypeValue.default(property.valueType, property)
		property.defaultInputError = nil
		property.defaultText = Util.formatValue(property.defaultValue)
	end
end

function TypeDraft.snapshotCategoryOrder(draft): { string }
	return table.clone(draft.categoryOrder)
end

function TypeDraft.snapshotEditableProperties(draft)
	local snapshot = {}
	for _, categoryId in draft.categoryOrder do
		local category = draft.categories[categoryId]
		if category then
			for _, propertyId in draft.propertyOrder do
				local property = draft.properties[propertyId]
				if property and property.categoryId == categoryId then
					local copy = table.clone(property)
					copy.categoryName = category.name
					table.insert(snapshot, copy)
				end
			end
		end
	end
	return snapshot
end

local function reservedPropertyNames(draft, lookupType)
	local reserved = {}
	local visited = {}
	local currentId = draft.extends

	while currentId and currentId ~= "" do
		if visited[currentId] then
			break
		end
		visited[currentId] = true

		local definition = lookupType(currentId)
		if definition then
			for _, property in definition.properties or {} do
				reserved[property.name] = true
			end
			currentId = definition.extends
		elseif EngineSchemas then
			for _, property in EngineSchemas.get(currentId) do
				reserved[property.name] = true
			end
			break
		else
			break
		end
	end

	return reserved
end

function TypeDraft.validate(draft, lookupType)
	local errors = {}
	local seenNames = {}
	local reservedNames = reservedPropertyNames(draft, lookupType)

	for _, propertyId in draft.propertyOrder do
		local property = draft.properties[propertyId]
		if property then
			if not property.name:match("^[%a_][%w_]*$") then
				table.insert(errors, {
					fieldId = propertyId,
					code = "invalid-property-name",
					message = `"{property.name}" is not a valid property identifier.`,
				})
			elseif WrapperPolicy.isReserved(property.name, reservedNames) then
				table.insert(errors, {
					fieldId = propertyId,
					code = "reserved-property",
					message = `Property "{property.name}" conflicts with an inherited or reserved property.`,
				})
			elseif seenNames[property.name] then
				table.insert(errors, {
					fieldId = propertyId,
					code = "duplicate-property",
					message = `Property "{property.name}" is declared more than once.`,
				})
			else
				seenNames[property.name] = true
			end
			local validationMetadata = table.clone(property)
			validationMetadata.lookupType = lookupType
			local valid, message = TypeValue.validate(property.valueType, property.defaultValue, validationMetadata)
			if property.defaultInputError or not valid then
				table.insert(errors, {
					fieldId = propertyId,
					code = "invalid-default",
					message = message or `Default for "{property.name}" is not a valid {property.valueType}.`,
				})
			end
		end
	end

	local visited = { [draft.id] = true }
	local currentId = draft.extends
	while currentId and currentId ~= "" and currentId ~= "Configuration" do
		if visited[currentId] then
			table.insert(errors, {
				fieldId = "extends",
				code = "inheritance-cycle",
				message = `Extending "{draft.extends}" creates an inheritance cycle.`,
			})
			break
		end
		visited[currentId] = true
		local definition = lookupType(currentId)
		currentId = if definition then definition.extends else nil
	end

	return errors
end

return TypeDraft
