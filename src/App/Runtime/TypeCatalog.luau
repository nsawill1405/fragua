local TypeCatalog = {}

local CATALOG_NAME = "FraguaTypes"
local PRIVATE_BEHAVIOR_NAMES = { "Behavior", "EditBehavior", "ServerBehavior" }
local REFERENCE_PREFIX = "_FraguaRef_"

local function cloneProperty(property)
	local copy = table.clone(property)
	if property.enumItems then
		copy.enumItems = table.clone(property.enumItems)
	end
	return copy
end

function TypeCatalog.snapshot(definitions, resolveSchema, resolveBackingClass)
	local definitionsById = {}
	for _, definition in definitions do
		definitionsById[definition.id] = definition
	end

	local entries = {}
	for _, definition in definitions do
		local properties = {}
		for _, property in resolveSchema(definition) do
			table.insert(properties, cloneProperty(property))
		end

		local ancestors = {}
		local visited = {}
		local ancestorId = definition.extends
		while definitionsById[ancestorId] and not visited[ancestorId] do
			visited[ancestorId] = true
			table.insert(ancestors, ancestorId)
			ancestorId = definitionsById[ancestorId].extends
		end

		local backingClass = nil
		if resolveBackingClass then
			backingClass = resolveBackingClass(definition.id)
		end
		table.insert(entries, {
			id = definition.id,
			name = definition.name,
			backingClass = backingClass,
			ancestors = ancestors,
			properties = properties,
		})
	end
	return entries
end

local function ensureChild(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function clearManagedAttributes(instance: Instance)
	for attributeName in instance:GetAttributes() do
		if attributeName ~= "_FraguaManaged" then
			instance:SetAttribute(attributeName, nil)
		end
	end
end

local function syncOrderedStrings(parent: Instance, values: { string })
	for _, child in parent:GetChildren() do
		child:Destroy()
	end
	for index, value in values do
		local item = Instance.new("StringValue")
		item.Name = string.format("%04d", index)
		item.Value = value
		item:SetAttribute("_FraguaManaged", true)
		item.Parent = parent
	end
end

local PROPERTY_ATTRIBUTES = {
	name = "Name",
	valueType = "ValueType",
	category = "Category",
	readonly = "Readonly",
	enumType = "EnumType",
	minimum = "Minimum",
	maximum = "Maximum",
	step = "Step",
	multiline = "Multiline",
	referenceType = "ReferenceType",
	origin = "Origin",
	inherited = "Inherited",
}

local function syncPropertyMetadata(propertiesFolder: Instance, properties)
	local active = {}
	for _, property in properties do
		active[property.name] = true
		local metadata = ensureChild(propertiesFolder, "Configuration", property.name)
		metadata:SetAttribute("_FraguaManaged", true)
		clearManagedAttributes(metadata)
		for field, attributeName in PROPERTY_ATTRIBUTES do
			local value = property[field]
			if value ~= nil then
				metadata:SetAttribute(attributeName, value)
			end
		end

		local enumItems = metadata:FindFirstChild("EnumItems")
		if property.enumItems then
			enumItems = ensureChild(metadata, "Folder", "EnumItems")
			enumItems:SetAttribute("_FraguaManaged", true)
			syncOrderedStrings(enumItems, property.enumItems)
		elseif enumItems then
			enumItems:Destroy()
		end
	end

	for _, child in propertiesFolder:GetChildren() do
		if child:GetAttribute("_FraguaManaged") == true and not active[child.Name] then
			child:Destroy()
		end
	end
end

local function isReference(property): boolean
	return property.valueType == "Instance" or property.referenceType ~= nil
end

local function syncDefaults(defaults: Instance, properties, typeId: string)
	clearManagedAttributes(defaults)
	local activeReferences = {}
	for _, property in properties do
		if property.name == "Name" or property.name == "Archivable" then
			continue
		end
		if isReference(property) then
			local referenceName = REFERENCE_PREFIX .. property.name
			activeReferences[referenceName] = true
			local reference = ensureChild(defaults, "ObjectValue", referenceName)
			reference:SetAttribute("_FraguaManaged", true)
			reference.Value = if typeof(property.default) == "Instance" then property.default else nil
		elseif property.default ~= nil then
			local ok, err = pcall(defaults.SetAttribute, defaults, property.name, property.default)
			if not ok then
				warn(`[Fragua] Could not replicate default {typeId}.{property.name}: {err}`)
			end
		end
	end

	for _, child in defaults:GetChildren() do
		if
			child:GetAttribute("_FraguaManaged") == true
			and child:IsA("ObjectValue")
			and not activeReferences[child.Name]
		then
			child:Destroy()
		end
	end
end

local function syncClientBehavior(typeEntry: Instance, registry, entry)
	for _, child in typeEntry:GetChildren() do
		if table.find(PRIVATE_BEHAVIOR_NAMES, child.Name) or child.Name == "ClientBehavior" then
			child:Destroy()
		end
	end
	local clientTemplate = registry.ensureBehaviorTemplate(entry.id, "Client")
	local clientBehavior = clientTemplate:Clone()
	clientBehavior.Name = "ClientBehavior"
	clientBehavior:SetAttribute("_FraguaManaged", true)
	clientBehavior.Parent = typeEntry
end

function TypeCatalog.sync(registry)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local root = ensureChild(ReplicatedStorage, "Folder", CATALOG_NAME)
	root:SetAttribute("_FraguaManaged", true)

	local entries = TypeCatalog.snapshot(registry.list(), function(definition)
		return registry.resolvedSchema(definition)
	end, function(typeId)
		return registry.getBackingClass(typeId)
	end)
	local active = {}
	for _, entry in entries do
		active[entry.id] = true
		local typeEntry = ensureChild(root, "Configuration", entry.id)
		typeEntry:SetAttribute("_FraguaManaged", true)
		typeEntry:SetAttribute("TypeId", entry.id)
		typeEntry:SetAttribute("DisplayName", entry.name)
		typeEntry:SetAttribute("BackingClass", entry.backingClass)

		local ancestors = ensureChild(typeEntry, "Folder", "FraguaAncestors")
		ancestors:SetAttribute("_FraguaManaged", true)
		syncOrderedStrings(ancestors, entry.ancestors)

		local properties = ensureChild(typeEntry, "Folder", "Properties")
		properties:SetAttribute("_FraguaManaged", true)
		syncPropertyMetadata(properties, entry.properties)

		local defaults = ensureChild(typeEntry, "Folder", "Defaults")
		defaults:SetAttribute("_FraguaManaged", true)
		syncDefaults(defaults, entry.properties, entry.id)
		syncClientBehavior(typeEntry, registry, entry)
	end

	for _, child in root:GetChildren() do
		if child:GetAttribute("_FraguaManaged") == true and not active[child.Name] then
			child:Destroy()
		end
	end
	return root
end

return TypeCatalog
