local BehaviorSignatures = if script then require(script.Parent.BehaviorSignatures) else require("./BehaviorSignatures")

local TypeSurface = {}

local VALUE_TYPES = {
	string = "string",
	number = "number",
	integer = "number",
	boolean = "boolean",
	Color3 = "Color3",
	BrickColor = "BrickColor",
	Vector2 = "Vector2",
	Vector3 = "Vector3",
	UDim = "UDim",
	UDim2 = "UDim2",
	CFrame = "CFrame",
	enum = "EnumItem",
	Instance = "Instance",
}

local function propertyType(property, definitionsById, customEnumIds): string
	if property.valueType == "FraguaInstance" then
		local referenceType = property.referenceType
		if typeof(referenceType) == "string" and definitionsById[referenceType] then
			return referenceType
		end
		return "Instance"
	end
	if property.valueType == "enum" and property.enumType == "FraguaType" then
		return "FraguaTypeItem<string>"
	end
	if property.valueType == "enum" and typeof(property.enumType) == "string" and customEnumIds[property.enumType] then
		return `FraguaEnumItem<"{property.enumType}", string>`
	end
	return VALUE_TYPES[property.valueType] or "any"
end

local function resolvedProperties(definition, resolveSchema, definitionsById, customEnumIds)
	local byName = {}
	for _, property in resolveSchema(definition) or {} do
		if typeof(property.name) == "string" and property.name ~= "" then
			local copy = table.clone(property)
			copy.typeName = propertyType(copy, definitionsById, customEnumIds)
			byName[copy.name] = copy
		end
	end
	local properties = {}
	for _, property in byName do
		table.insert(properties, property)
	end
	table.sort(properties, function(a, b)
		return a.name < b.name
	end)
	return properties
end

local function defaultHasBackingMember(backingClass: string, memberName: string): boolean
	local created, probe = pcall(function()
		return Instance.new(backingClass)
	end)
	if not created or not probe then
		return false
	end
	local readable = pcall(function()
		local _ = probe[memberName]
	end)
	probe:Destroy()
	return readable
end

local function methodsFor(typeId: string, side: string, backingClass: string, getBehaviorSource, hasBackingMember)
	local methodsByName = {}
	local source = getBehaviorSource(typeId, side)
	if typeof(source) == "string" then
		for _, method in BehaviorSignatures.parse(source) do
			if not hasBackingMember(backingClass, method.name) then
				methodsByName[method.name] = method
			end
		end
	end
	local methods = {}
	for _, method in methodsByName do
		table.insert(methods, method)
	end
	table.sort(methods, function(a, b)
		return a.name < b.name
	end)
	return methods
end

local function ancestorsFor(definition, definitionsById)
	local ancestors = {}
	local visited = {}
	local ancestorId = definition.extends
	while definitionsById[ancestorId] and not visited[ancestorId] do
		visited[ancestorId] = true
		table.insert(ancestors, ancestorId)
		ancestorId = definitionsById[ancestorId].extends
	end
	return ancestors
end

function TypeSurface.build(definitions, resolveSchema, resolveBacking, getBehaviorSource, hasBackingMember, enums)
	hasBackingMember = hasBackingMember or defaultHasBackingMember
	local definitionsById = {}
	for _, definition in definitions do
		if typeof(definition.id) == "string" and definition.id ~= "" then
			definitionsById[definition.id] = definition
		end
	end

	local customEnumIds = {}
	local enumList = {}
	for _, enum in enums or {} do
		if typeof(enum.id) == "string" and enum.id ~= "" then
			customEnumIds[enum.id] = true
			local items = {}
			for _, item in enum.items or {} do
				if typeof(item) == "string" then
					table.insert(items, item)
				end
			end
			table.insert(enumList, {
				id = enum.id,
				name = enum.name or enum.id,
				items = items,
			})
		end
	end
	table.sort(enumList, function(a, b)
		return a.id < b.id
	end)

	local types = {}
	for _, definition in definitionsById do
		local backingClass = resolveBacking(definition.id)
		if typeof(backingClass) ~= "string" or backingClass:match("^[%a_][%w_]*$") == nil then
			backingClass = "Instance"
		end
		table.insert(types, {
			id = definition.id,
			name = definition.name or definition.id,
			backingClass = backingClass,
			ancestors = ancestorsFor(definition, definitionsById),
			properties = resolvedProperties(definition, resolveSchema, definitionsById, customEnumIds),
			serverMethods = methodsFor(definition.id, "Server", backingClass, getBehaviorSource, hasBackingMember),
			clientMethods = methodsFor(definition.id, "Client", backingClass, getBehaviorSource, hasBackingMember),
		})
	end
	table.sort(types, function(a, b)
		return a.id < b.id
	end)
	return { types = types, enums = enumList }
end

return TypeSurface
