local TypeCatalog = {}

local CATALOG_NAME = "FraguaTypes"

function TypeCatalog.snapshot(definitions, resolveSchema)
	local entries = {}
	for _, definition in definitions do
		local properties = {}
		for _, property in resolveSchema(definition) do
			table.insert(properties, table.clone(property))
		end
		table.insert(entries, {
			id = definition.id,
			name = definition.name,
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

function TypeCatalog.sync(registry)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local root = ensureChild(ReplicatedStorage, "Folder", CATALOG_NAME)
	root:SetAttribute("_FraguaManaged", true)

	local entries = TypeCatalog.snapshot(registry.list(), function(definition)
		return registry.resolvedSchema(definition)
	end)
	local active = {}
	for _, entry in entries do
		active[entry.id] = true
		local typeEntry = ensureChild(root, "Configuration", entry.id)
		typeEntry:SetAttribute("_FraguaManaged", true)
		typeEntry:SetAttribute("TypeId", entry.id)
		typeEntry:SetAttribute("DisplayName", entry.name)

		local defaults = ensureChild(typeEntry, "Folder", "Defaults")
		defaults:SetAttribute("_FraguaManaged", true)
		for attributeName in defaults:GetAttributes() do
			if attributeName ~= "_FraguaManaged" then
				defaults:SetAttribute(attributeName, nil)
			end
		end
		for _, property in entry.properties do
			if property.name ~= "Name" and property.name ~= "Archivable" and property.default ~= nil then
				local ok, err = pcall(defaults.SetAttribute, defaults, property.name, property.default)
				if not ok then
					warn(`[Fragua] Could not replicate default {entry.id}.{property.name}: {err}`)
				end
			end
		end

		local oldBehavior = typeEntry:FindFirstChild("Behavior")
		if oldBehavior then
			oldBehavior:Destroy()
		end
	end

	for _, child in root:GetChildren() do
		if child:GetAttribute("_FraguaManaged") == true and not active[child.Name] then
			child:Destroy()
		end
	end
	return root
end

return TypeCatalog
