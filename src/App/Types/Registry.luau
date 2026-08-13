local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

local Constants = require(script.Parent.Parent.Shared.Constants)
local BehaviorModel = require(script.Parent.BehaviorModel)
local BehaviorTemplatePolicy = require(script.Parent.BehaviorTemplatePolicy)
local BackingClassResolver = require(script.Parent.BackingClassResolver)
local BackingUpgradePolicy = require(script.Parent.BackingUpgradePolicy)
local EngineSchemas = require(script.Parent.EngineSchemas)
local PropertyMigration = require(script.Parent.PropertyMigration)
local SchemaResolver = require(script.Parent.SchemaResolver)
local TypeValue = require(script.Parent.TypeValue)
local ScriptHeader = require(script.Parent.Parent.Runtime.ScriptHeader)
local WrapperPolicy = require(script.Parent.Parent.Runtime.WrapperPolicy)

export type PropDef = {
	id: string?,
	originalName: string?,
	name: string,
	valueType: string,
	default: any,
	category: string,
	readonly: boolean?,
	enumItems: { string }?,
	enumType: string?,
	minimum: number?,
	maximum: number?,
	step: number?,
	multiline: boolean?,
	referenceType: string?,
}

export type TypeDef = {
	id: string,
	name: string,
	description: string,
	extends: string,
	icon: string,
	properties: { PropDef },
}

local Registry = {}

local REFERENCE_PREFIX = "_FraguaRef_"
local MANAGED_ATTRIBUTE = "_FraguaManaged"

local changedBindable = Instance.new("BindableEvent")
Registry.Changed = changedBindable.Event

local function fireChanged()
	changedBindable:Fire()
end

function Registry.ensureRoot(): Folder
	local root = ServerStorage:FindFirstChild(Constants.ROOT_FOLDER)
	if not root then
		root = Instance.new("Folder")
		root.Name = Constants.ROOT_FOLDER
		root.Parent = ServerStorage
	end
	local types = root:FindFirstChild(Constants.TYPES_FOLDER)
	if not types then
		types = Instance.new("Folder")
		types.Name = Constants.TYPES_FOLDER
		types.Parent = root
	end
	return root :: Folder
end

function Registry.typesFolder(): Folder
	return Registry.ensureRoot():FindFirstChild(Constants.TYPES_FOLDER) :: Folder
end

local function encodeType(def: TypeDef): string
	local props = {}
	for _, prop in def.properties do
		local reference = prop.valueType == "Instance" or prop.valueType == "FraguaInstance"
		table.insert(props, {
			id = prop.id,
			originalName = prop.originalName,
			name = prop.name,
			valueType = prop.valueType,
			default = if reference then TypeValue.referenceMarker(prop.name) else TypeValue.serialize(prop.default),
			category = prop.category,
			readonly = prop.readonly,
			enumItems = prop.enumItems,
			enumType = prop.enumType,
			minimum = prop.minimum,
			maximum = prop.maximum,
			step = prop.step,
			multiline = prop.multiline,
			referenceType = prop.referenceType,
		})
	end
	return HttpService:JSONEncode({
		id = def.id,
		name = def.name,
		description = def.description,
		extends = def.extends,
		icon = def.icon,
		properties = props,
	})
end

local function hydrateReferenceDefaults(container: Instance, def: TypeDef): TypeDef
	for _, prop in def.properties do
		if prop.valueType == "Instance" or prop.valueType == "FraguaInstance" then
			local markerProperty = TypeValue.referenceProperty(prop.default)
			if markerProperty == prop.name or (markerProperty == nil and prop.default == nil) then
				local reference = container:FindFirstChild(REFERENCE_PREFIX .. prop.name)
				prop.default = if reference and reference:IsA("ObjectValue") then reference.Value else nil
			else
				prop.default = nil
			end
		end
	end
	return def
end

local function decodeType(raw: string): TypeDef?
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(data) ~= "table" or typeof(data.id) ~= "string" then
		return nil
	end
	local props: { PropDef } = {}
	if typeof(data.properties) == "table" then
		for _, prop in data.properties do
			if typeof(prop) == "table" and typeof(prop.name) == "string" then
				table.insert(props, {
					id = prop.id,
					originalName = prop.originalName,
					name = prop.name,
					valueType = prop.valueType or "string",
					default = TypeValue.deserialize(prop.default),
					category = prop.category or "Data",
					readonly = prop.readonly,
					enumItems = prop.enumItems,
					enumType = prop.enumType,
					minimum = prop.minimum,
					maximum = prop.maximum,
					step = prop.step,
					multiline = prop.multiline,
					referenceType = prop.referenceType,
				})
			end
		end
	end
	return {
		id = data.id,
		name = data.name or data.id,
		description = data.description or "",
		extends = data.extends or "Configuration",
		icon = data.icon or "class_Configuration",
		properties = props,
	}
end

local function decodeTypeModule(module: ModuleScript): TypeDef?
	local source = module.Source
	local startPos = string.find(source, "[[", 1, true)
	local endPos = startPos and string.find(source, "]]", startPos + 2, true)
	local sourceRaw = if startPos and endPos then string.sub(source, startPos + 2, endPos - 1) else source
	return decodeType(sourceRaw)
end

local function decodeTypeContainer(container: Instance): TypeDef?
	if container:IsA("ModuleScript") then
		local def = decodeTypeModule(container)
		return if def then hydrateReferenceDefaults(container, def) else nil
	end
	if container:IsA("StringValue") then
		local def = decodeType(container.Value)
		return if def then hydrateReferenceDefaults(container, def) else nil
	end
	return nil
end

local function findTypeDefinition(folder: Folder, id: string): Instance?
	for _, child in folder:GetChildren() do
		if child.Name == id then
			local def = decodeTypeContainer(child)
			if def and def.id == id then
				return child
			end
		end
	end
	return nil
end

function Registry.list(): { TypeDef }
	local folder = Registry.typesFolder()
	local types: { TypeDef } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") or child:IsA("StringValue") then
			-- Decode current Source first. require() caches old values after Source edits.
			local def = decodeTypeContainer(child)
			if
				not def
				and child:IsA("ModuleScript")
				and child:GetAttribute("_FraguaSharedBehavior") ~= true
				and child:GetAttribute("_FraguaBehaviorSide") == nil
			then
				local required, result = pcall(require, child)
				if required and typeof(result) == "string" then
					def = decodeType(result)
					if def then
						def = hydrateReferenceDefaults(child, def)
					end
				end
			end
			if def then
				table.insert(types, def)
			end
		end
	end
	table.sort(types, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
	return types
end

function Registry.get(id: string): TypeDef?
	for _, def in Registry.list() do
		if def.id == id then
			return def
		end
	end
	return nil
end

function Registry.getBackingClass(typeId: string): (string?, string?)
	return BackingClassResolver.resolve(typeId, Registry.get)
end

local function typeModuleSource(def: TypeDef): string
	local json = encodeType(def)
	return `-- Fragua type definition: {def.id}\nreturn [[\n{json}\n]]\n`
end

local function syncDefinitionReferences(container: Instance, def: TypeDef)
	local active = {}
	for _, prop in def.properties do
		if prop.valueType == "Instance" or prop.valueType == "FraguaInstance" then
			local name = REFERENCE_PREFIX .. prop.name
			active[name] = true
			local existing = container:FindFirstChild(name)
			local reference
			if existing and existing:IsA("ObjectValue") then
				reference = existing
			else
				if existing then
					existing:Destroy()
				end
				reference = Instance.new("ObjectValue")
				reference.Name = name
				reference.Parent = container
			end
			reference:SetAttribute(MANAGED_ATTRIBUTE, true)
			reference.Value = if typeof(prop.default) == "Instance" then prop.default else nil
		end
	end

	for _, child in container:GetChildren() do
		if
			child:IsA("ObjectValue")
			and child:GetAttribute(MANAGED_ATTRIBUTE) == true
			and string.sub(child.Name, 1, #REFERENCE_PREFIX) == REFERENCE_PREFIX
			and not active[child.Name]
		then
			child:Destroy()
		end
	end
end

function Registry.save(def: TypeDef)
	assert(def.id ~= "", "Type id required")
	local inheritedMembers = {}
	local parent = Registry.get(def.extends)
	local inheritedProperties = if parent then Registry.resolvedSchema(parent) else EngineSchemas.get(def.extends)
	for _, property in inheritedProperties do
		inheritedMembers[property.name] = true
	end
	local backingClass = BackingClassResolver.resolve(def.id, function(typeId)
		return if typeId == def.id then def else Registry.get(typeId)
	end)
	local backingProbe
	if backingClass then
		local created, result = pcall(Instance.new, backingClass)
		if created then
			backingProbe = result
		end
	end
	local collision
	for _, property in def.properties do
		if backingProbe then
			local native = pcall(function()
				local _ = backingProbe[property.name]
			end)
			if native then
				inheritedMembers[property.name] = true
			end
		end
		if WrapperPolicy.isReserved(property.name, inheritedMembers) then
			collision = property.name
			break
		end
	end
	if backingProbe then
		backingProbe:Destroy()
	end
	assert(not collision, `Property "{collision}" conflicts with an inherited or reserved property.`)
	local folder = Registry.typesFolder()
	local source = typeModuleSource(def)
	local existing = findTypeDefinition(folder, def.id)
	if existing and existing:IsA("ModuleScript") then
		existing.Source = source
		syncDefinitionReferences(existing, def)
	else
		local module = Instance.new("ModuleScript")
		module.Name = def.id
		module.Source = source
		module.Parent = folder
		syncDefinitionReferences(module, def)
		if existing then
			existing:Destroy()
		end
	end
	for _, side in BehaviorModel.SIDES do
		Registry.ensureBehaviorTemplate(def.id, side)
	end
	fireChanged()
end

function Registry.findInstances(typeId: string): { Instance }
	local found = {}
	for _, inst in CollectionService:GetTagged(Constants.TAG) do
		if inst:GetAttribute(Constants.TYPE_ATTR) == typeId then
			table.insert(found, inst)
		end
	end
	-- Fallback: attribute without tag (orphaned / older places)
	for _, serviceName in
		{
			"Workspace",
			"ReplicatedStorage",
			"ServerStorage",
			"ServerScriptService",
			"StarterGui",
			"StarterPack",
			"StarterPlayer",
		}
	do
		local ok, service = pcall(function()
			return game:GetService(serviceName)
		end)
		if ok and service then
			for _, inst in service:GetDescendants() do
				if inst:GetAttribute(Constants.TYPE_ATTR) == typeId and not table.find(found, inst) then
					-- Skip the type definition ModuleScripts under ServerStorage.Fragua
					if not (inst:IsA("ModuleScript") and inst:FindFirstAncestor(Constants.ROOT_FOLDER)) then
						table.insert(found, inst)
					end
				end
			end
		end
	end
	return found
end

function Registry.countInstances(typeId: string): number
	return #Registry.findInstances(typeId)
end

function Registry.delete(id: string): boolean
	local folder = Registry.typesFolder()
	local existing = findTypeDefinition(folder, id)
	if not existing then
		return false
	end

	ChangeHistoryService:SetWaypoint("Fragua Delete Type")

	local placed = Registry.findInstances(id)
	for _, inst in placed do
		inst:Destroy()
	end

	for _, side in BehaviorModel.SIDES do
		local behaviorName = BehaviorModel.name(id, side)
		for _, child in folder:GetChildren() do
			if child.Name == behaviorName and child:IsA("ModuleScript") and not decodeTypeModule(child) then
				child:Destroy()
			end
		end
	end
	for _, child in folder:GetChildren() do
		if child.Name == id .. "Behavior" and child:IsA("ModuleScript") and not decodeTypeModule(child) then
			child:Destroy()
		end
	end

	existing:Destroy()

	if #placed > 0 then
		print(`[Fragua] Deleted type "{id}" and {#placed} placed instance(s).`)
	else
		print(`[Fragua] Deleted type "{id}".`)
	end

	fireChanged()
	ChangeHistoryService:SetWaypoint("Fragua Delete Type Done")
	return true
end

-- Migrate attributes on placed instances after a type schema change.
function Registry.migrateInstances(typeId: string, previous: TypeDef?, nextDef: TypeDef)
	local previousResolved = if previous then Registry.resolvedSchema(previous) else {}
	local nextResolved = Registry.resolvedSchema(nextDef)
	local operations = PropertyMigration.plan(previousResolved, nextResolved)

	ChangeHistoryService:SetWaypoint("Fragua Migrate Type")
	local count = 0
	for _, inst in Registry.findInstances(typeId) do
		count += 1
		for _, operation in operations do
			local old, new = operation.old, operation.new
			local oldRef = old and PropertyMigration.isReference(old)
			local newRef = new and PropertyMigration.isReference(new)
			local oldObject = old and inst:FindFirstChild(REFERENCE_PREFIX .. old.name)
			local preserved = old and new and oldRef == newRef
			local attribute = if preserved and not oldRef then inst:GetAttribute(old.name) else nil
			local objectValue = if preserved
					and oldRef
					and oldObject
					and oldObject:IsA("ObjectValue")
				then oldObject.Value
				else nil
			if old then
				if not WrapperPolicy.isReserved(old.name, {}) then
					inst:SetAttribute(old.name, nil)
				end
				if oldObject and oldObject:IsA("ObjectValue") then
					oldObject:Destroy()
				end
			end
			if new then
				inst:SetAttribute(new.name, nil)
				local stale = inst:FindFirstChild(REFERENCE_PREFIX .. new.name)
				if stale and stale:IsA("ObjectValue") then
					stale:Destroy()
				end
				if newRef then
					local reference = Instance.new("ObjectValue")
					reference.Name = REFERENCE_PREFIX .. new.name
					reference:SetAttribute(MANAGED_ATTRIBUTE, true)
					reference.Value = if preserved
						then objectValue
						else if typeof(new.default) == "Instance" then new.default else nil
					reference.Parent = inst
				elseif not WrapperPolicy.isReserved(new.name, {}) then
					inst:SetAttribute(new.name, if preserved and attribute ~= nil then attribute else new.default)
				end
			end
		end
	end
	if count > 0 then
		print(`[Fragua] Migrated {count} instance(s) for type "{typeId}".`)
	end
	ChangeHistoryService:SetWaypoint("Fragua Migrate Type Done")
end

function Registry.resolvedSchema(def: TypeDef): { PropDef }
	local schema, err = SchemaResolver.resolve(def, Registry.get, EngineSchemas.get)
	if err then
		warn(`[Fragua] {err.message}`)
		return table.clone(def.properties)
	end
	return schema
end

function Registry.isFraguaInstance(instance: Instance): boolean
	return CollectionService:HasTag(instance, Constants.TAG) or instance:GetAttribute(Constants.TYPE_ATTR) ~= nil
end

function Registry.getTypeId(instance: Instance): string?
	local attr = instance:GetAttribute(Constants.TYPE_ATTR)
	if typeof(attr) == "string" and attr ~= "" then
		return attr
	end
	return nil
end

-- switch an existing fragua instance to another type id
function Registry.applyType(instance: Instance, typeId: string): boolean
	local def = Registry.get(typeId)
	if not def or not Registry.isFraguaInstance(instance) then
		return false
	end
	local prevId = Registry.getTypeId(instance)
	if prevId == typeId then
		return true
	end
	ChangeHistoryService:SetWaypoint("Fragua Change Type")
	instance:SetAttribute(Constants.TYPE_ATTR, def.id)
	CollectionService:AddTag(instance, Constants.TAG)
	for _, prop in Registry.resolvedSchema(def) do
		if prop.valueType == "Instance" or prop.valueType == "FraguaInstance" then
			if not instance:FindFirstChild(REFERENCE_PREFIX .. prop.name) then
				local reference = Instance.new("ObjectValue")
				reference.Name = REFERENCE_PREFIX .. prop.name
				reference:SetAttribute(MANAGED_ATTRIBUTE, true)
				reference.Value = if typeof(prop.default) == "Instance" then prop.default else nil
				reference.Parent = instance
			end
		elseif prop.name ~= "Name" and prop.name ~= "Archivable" and instance:GetAttribute(prop.name) == nil then
			instance:SetAttribute(prop.name, prop.default)
		end
	end
	for _, side in BehaviorModel.SIDES do
		Registry.ensureBehaviorTemplate(def.id, side)
	end
	fireChanged()
	ChangeHistoryService:SetWaypoint("Fragua Change Type Done")
	return true
end

local function newBackingInstance(typeId: string): (Instance?, string?)
	local backingClass, resolveErr = Registry.getBackingClass(typeId)
	if not backingClass then
		return nil, resolveErr
	end
	local ok, result = pcall(Instance.new, backingClass)
	if not ok then
		return nil, `Could not create backing class "{backingClass}": {result}`
	end
	return result, nil
end

local function hasEngineProperty(instance: Instance, name: string): boolean
	return pcall(function()
		local _ = (instance :: any)[name]
	end)
end

local function applySchemaAttributes(instance: Instance, def: TypeDef)
	for _, prop in Registry.resolvedSchema(def) do
		if prop.valueType == "Instance" or prop.valueType == "FraguaInstance" then
			local reference = Instance.new("ObjectValue")
			reference.Name = REFERENCE_PREFIX .. prop.name
			reference:SetAttribute(MANAGED_ATTRIBUTE, true)
			reference.Value = if typeof(prop.default) == "Instance" then prop.default else nil
			reference.Parent = instance
		elseif
			prop.name ~= "Name"
			and prop.name ~= "Archivable"
			and prop.name ~= "ClassName"
			and not hasEngineProperty(instance, prop.name)
			and instance:GetAttribute(prop.name) == nil
			and prop.default ~= nil
		then
			instance:SetAttribute(prop.name, prop.default)
		end
	end
end

function Registry.createInstance(typeId: string, parent: Instance?): Instance
	local def = Registry.get(typeId)
	assert(def, `Unknown Fragua type: {typeId}`)

	local inst, createErr = newBackingInstance(typeId)
	assert(inst, createErr)
	inst.Name = def.name
	inst:SetAttribute(Constants.TYPE_ATTR, def.id)
	CollectionService:AddTag(inst, Constants.TAG)
	applySchemaAttributes(inst, def)

	for _, side in BehaviorModel.SIDES do
		Registry.ensureBehaviorTemplate(def.id, side)
	end

	inst.Parent = parent
	return inst
end

local function setEngineProperty(instance: Instance, name: string, value: any): boolean
	return pcall(function()
		local current = (instance :: any)[name]
		if typeof(current) == "EnumItem" and typeof(value) == "string" then
			local item = (current.EnumType :: any)[value]
			if item then
				(instance :: any)[name] = item
				return
			end
		end
		(instance :: any)[name] = value
	end)
end

function Registry.upgradeBackingInstance(instance: Instance): (Instance?, string?)
	local typeId = Registry.getTypeId(instance)
	if not typeId then
		return nil, "Instance has no Fragua type"
	end
	local def = Registry.get(typeId)
	if not def then
		return nil, `Unknown Fragua type: {typeId}`
	end
	local backingClass, resolveErr = Registry.getBackingClass(typeId)
	if not backingClass then
		return nil, resolveErr
	end
	if instance.ClassName == backingClass then
		return instance, nil
	end

	local replacement, createErr = newBackingInstance(typeId)
	if not replacement then
		return nil, createErr
	end
	ChangeHistoryService:SetWaypoint("Fragua Upgrade Backing Instance")

	local oldParent = instance.Parent
	local oldSelection = Selection:Get()
	local replacementSelection = {}
	for _, selected in oldSelection do
		table.insert(replacementSelection, if selected == instance then replacement else selected)
	end

	replacement.Name = instance.Name
	replacement.Archivable = instance.Archivable
	local sourceAttributes = instance:GetAttributes()
	for name, value in sourceAttributes do
		replacement:SetAttribute(name, value)
	end
	for _, tag in CollectionService:GetTags(instance) do
		CollectionService:AddTag(replacement, tag)
	end
	for _, prop in Registry.resolvedSchema(def) do
		if prop.name == "Name" or prop.name == "Archivable" or prop.name == "ClassName" or prop.readonly then
			continue
		end
		local gotNative, nativeValue = pcall(function()
			return (instance :: any)[prop.name]
		end)
		local hasAttribute = sourceAttributes[prop.name] ~= nil
		local value, preserveAttribute =
			BackingUpgradePolicy.sourceValue(hasAttribute, sourceAttributes[prop.name], gotNative, nativeValue)
		if value ~= nil and hasEngineProperty(replacement, prop.name) then
			if setEngineProperty(replacement, prop.name, value) and not preserveAttribute then
				replacement:SetAttribute(prop.name, nil)
			end
		end
	end

	for _, child in instance:GetChildren() do
		child.Parent = replacement
	end
	replacement.Parent = oldParent
	Selection:Set(replacementSelection)
	instance:Destroy()
	for _, side in BehaviorModel.SIDES do
		Registry.ensureBehaviorTemplate(typeId, side)
	end
	fireChanged()
	ChangeHistoryService:SetWaypoint("Fragua Upgrade Backing Instance Done")
	return replacement, nil
end

function Registry.seedDefaults()
	Registry.ensureRoot()
	if Registry.get("Zombie") then
		return
	end
	Registry.save({
		id = "Zombie",
		name = "Zombie",
		description = "Humanoid-like custom NPC type with a Studio nameplate.",
		extends = "Humanoid",
		icon = "emoji_zombie",
		properties = {
			{ name = "IsHostile", valueType = "boolean", default = true, category = "AI" },
			{ name = "DetectRange", valueType = "number", default = 40, category = "AI" },
			{ name = "AttackDamage", valueType = "number", default = 15, category = "AI" },
		},
	})

	-- Replace default behavior with nameplate demo for Zombie
	local template = Registry.ensureBehaviorTemplate("Zombie", "Edit")
	template.Source = [[
local Behavior = {}

local function ensureNameplate(instance)
	local parent = instance.Parent
	if not parent then
		return
	end
	local adornee = parent:IsA("Model") and (parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")) or parent:FindFirstChildWhichIsA("BasePart")
	if not adornee then
		return
	end
	local existing = parent:FindFirstChild("_FraguaNameplate")
	if existing then
		local label = existing:FindFirstChildWhichIsA("TextLabel", true)
		if label then
			label.Text = tostring(instance:GetAttribute("DisplayName") or instance.Name)
		end
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "_FraguaNameplate"
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = adornee
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(120, 255, 120)
	label.TextStrokeTransparency = 0.4
	label.Text = tostring(instance:GetAttribute("DisplayName") or instance.Name)
	label.Parent = gui
end

function Behavior.onCreated(instance)
	ensureNameplate(instance)
end

function Behavior.onSelected(instance)
	ensureNameplate(instance)
end

function Behavior.onPropertyChanged(instance, key, value)
	if key == "DisplayName" or key == "Name" then
		ensureNameplate(instance)
	end
end

function Behavior.onAncestryChanged(instance)
	ensureNameplate(instance)
end

return Behavior
]]
end

local function legacyDefaultBehaviorSource(typeId: string): string
	return table.concat({
		"-- Fragua shared behavior for " .. typeId,
		"-- Edited once; synced to every instance of this type.",
		"local Behavior = {}",
		"",
		"function Behavior.onCreated(instance)",
		"end",
		"",
		"function Behavior.onSelected(instance)",
		"end",
		"",
		"function Behavior.onPropertyChanged(instance, key, value)",
		"end",
		"",
		"function Behavior.onAncestryChanged(instance)",
		"end",
		"",
		"function Behavior.onStart(instance)",
		"end",
		"",
		"function Behavior.onStop(instance)",
		"end",
		"",
		"return Behavior",
		"",
	}, "\n")
end

local function ensureBehaviorBackups(): Folder
	local root = Registry.ensureRoot()
	local conventional = root:FindFirstChild("BehaviorBackups")
	if conventional and conventional:IsA("Folder") then
		conventional:SetAttribute("_FraguaBehaviorBackups", true)
		return conventional
	end
	local existingNames = {}
	for _, child in root:GetChildren() do
		existingNames[child.Name] = child.ClassName
		if child:IsA("Folder") and child:GetAttribute("_FraguaBehaviorBackups") == true then
			return child
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = BehaviorTemplatePolicy.backupFolderName(existingNames)
	folder:SetAttribute("_FraguaBehaviorBackups", true)
	folder.Parent = root
	return folder
end

local function nextBackupName(backups: Folder, typeId: string): string
	local existing = {}
	for _, child in backups:GetChildren() do
		existing[child.Name] = true
	end
	return BehaviorTemplatePolicy.backupName(existing, typeId)
end

local function moveToBehaviorBackups(typeId: string, template: ModuleScript)
	template:SetAttribute("_FraguaSharedBehavior", nil)
	template:SetAttribute("_FraguaBehaviorSide", nil)
	local backups = ensureBehaviorBackups()
	template.Name = nextBackupName(backups, typeId)
	template.Parent = backups
end

local function preserveBehaviorBackup(typeId: string, template: ModuleScript)
	local backup = template:Clone()
	moveToBehaviorBackups(typeId, backup)
end

local function canonicalizeNamedBehavior(
	typeId: string,
	behaviorName: string,
	generatedSource: string,
	side: string?
): ModuleScript?
	local candidates = {}
	local sources = {}
	for _, child in Registry.typesFolder():GetChildren() do
		if child.Name == behaviorName and child:IsA("ModuleScript") and not decodeTypeModule(child) then
			table.insert(candidates, child)
			table.insert(sources, child.Source)
		end
	end
	if #candidates == 0 then
		return nil
	end

	local plan = BehaviorTemplatePolicy.plan(sources, generatedSource)
	local canonical = candidates[plan.keep]
	canonical.Name = behaviorName
	canonical:SetAttribute("_FraguaSharedBehavior", true)
	canonical:SetAttribute("_FraguaBehaviorSide", side)

	for _, index in plan.backup do
		moveToBehaviorBackups(typeId, candidates[index])
	end
	for _, index in plan.discard do
		candidates[index]:Destroy()
	end
	return canonical
end

local function canonicalizeLegacyBehavior(typeId: string): ModuleScript?
	return canonicalizeNamedBehavior(typeId, typeId .. "Behavior", legacyDefaultBehaviorSource(typeId), nil)
end

local function createBehaviorTemplate(typeId: string, side: string, source: string): ModuleScript
	local template = Instance.new("ModuleScript")
	template.Name = BehaviorModel.name(typeId, side)
	template.Source = source
	template:SetAttribute("_FraguaSharedBehavior", true)
	template:SetAttribute("_FraguaBehaviorSide", side)
	template.Parent = Registry.typesFolder()
	return template
end

function Registry.canonicalizeBehaviorTemplate(typeId: string, side: string): ModuleScript?
	return canonicalizeNamedBehavior(
		typeId,
		BehaviorModel.name(typeId, side),
		BehaviorModel.defaultSource(typeId, side),
		side
	)
end

local function migrateLegacyBehavior(typeId: string)
	local sidedTemplates = {}
	local sidedSources = {}
	for _, side in BehaviorModel.SIDES do
		local template = Registry.canonicalizeBehaviorTemplate(typeId, side)
		if template then
			sidedTemplates[side] = template
			sidedSources[side] = template.Source
		end
	end

	local legacy = canonicalizeLegacyBehavior(typeId)
	if not legacy then
		return
	end

	local editSource = BehaviorModel.editSourceFromLegacy(legacy.Source, typeId)
	local migration = BehaviorTemplatePolicy.legacyMigrationPlan(
		editSource,
		sidedSources,
		BehaviorModel.serverMigrationSource(typeId, legacy.Source),
		BehaviorModel.defaultSource(typeId, "Client")
	)

	-- Preserve the winning legacy source before it becomes the authoritative Edit template.
	preserveBehaviorBackup(typeId, legacy)

	for _, side in BehaviorModel.SIDES do
		local existing = sidedTemplates[side]
		if existing then
			if table.find(migration.backup, side) then
				moveToBehaviorBackups(typeId, existing)
			else
				existing:Destroy()
			end
		end
	end

	legacy.Name = BehaviorModel.name(typeId, "Edit")
	legacy:SetAttribute("_FraguaSharedBehavior", true)
	legacy:SetAttribute("_FraguaBehaviorSide", "Edit")
	createBehaviorTemplate(typeId, "Server", migration.sources.Server)
	createBehaviorTemplate(typeId, "Client", migration.sources.Client)
end

local function detachServerEditForwarders(typeId: string)
	local server = Registry.canonicalizeBehaviorTemplate(typeId, "Server")
	if not server or not BehaviorModel.isServerEditForwarder(server.Source) then
		return
	end
	local edit = Registry.canonicalizeBehaviorTemplate(typeId, "Edit")
	local editSource = if edit then edit.Source else ""
	server.Source = BehaviorModel.serverMigrationSource(typeId, editSource)
	if edit then
		edit.Source = BehaviorModel.editSourceFromLegacy(edit.Source, typeId)
	end
end

function Registry.ensureBehaviorTemplate(typeId: string, side: string): ModuleScript
	BehaviorModel.name(typeId, side)
	migrateLegacyBehavior(typeId)
	detachServerEditForwarders(typeId)
	local existing = Registry.canonicalizeBehaviorTemplate(typeId, side)
	if existing then
		return existing
	end
	return createBehaviorTemplate(typeId, side, BehaviorModel.defaultSource(typeId, side))
end

local function sanitizedBehaviorSource(template: ModuleScript): string
	local stripped, changed = ScriptHeader.strip(template.Source)
	if changed then
		-- scrub accidental managed headers off shared templates (edit host uses natives)
		template.Source = stripped
	end
	return stripped
end

function Registry.getBehaviorSource(typeId: string, side: string): string?
	BehaviorModel.name(typeId, side)
	migrateLegacyBehavior(typeId)
	local template = Registry.canonicalizeBehaviorTemplate(typeId, side)
	if template then
		return sanitizedBehaviorSource(template)
	end
	return nil
end

function Registry.setBehaviorSource(typeId: string, side: string, source: string)
	local template = Registry.ensureBehaviorTemplate(typeId, side)
	template.Source = ScriptHeader.strip(source)
	if side == "Edit" then
		-- Notify the edit-time host if present (avoid a hard require cycle).
		local ok, Host = pcall(function()
			return require(script.Parent.Parent.Behaviors.Host)
		end)
		if ok and Host and Host.invalidateType then
			Host.invalidateType(typeId)
		end
	end
end

local function registeredTypeIds(): { string }
	local typeIds = {}
	for _, def in Registry.list() do
		table.insert(typeIds, def.id)
	end
	return typeIds
end

local function behaviorTemplateIdentity(template: ModuleScript): (string?, string?)
	return BehaviorModel.templateIdentity(template.Name, registeredTypeIds(), decodeTypeModule(template) ~= nil)
end

local function legacyBehaviorTypeId(template: ModuleScript): string?
	if decodeTypeModule(template) then
		return nil
	end
	for _, typeId in registeredTypeIds() do
		if template.Name == typeId .. "Behavior" then
			return typeId
		end
	end
	return nil
end

function Registry.watchBehaviorTemplates()
	local connections: { RBXScriptConnection } = {}
	local watched = setmetatable({}, { __mode = "k" })
	local stopped = false

	local function watch(template: Instance)
		if stopped or watched[template] or not template:IsA("ModuleScript") then
			return
		end
		local typeId, side = behaviorTemplateIdentity(template)
		if not typeId or not side then
			return
		end
		local canonical = Registry.canonicalizeBehaviorTemplate(typeId, side)
		if not canonical then
			return
		end
		template = canonical
		if watched[template] then
			return
		end
		watched[template] = true
		table.insert(
			connections,
			template:GetPropertyChangedSignal("Source"):Connect(function()
				task.defer(function()
					if stopped or not template.Parent then
						return
					end
					if side == "Edit" then
						local ok, Host = pcall(function()
							return require(script.Parent.Parent.Behaviors.Host)
						end)
						if ok and Host and Host.invalidateType then
							Host.invalidateType(typeId)
						end
					end
					fireChanged()
				end)
			end)
		)
	end

	for _, def in Registry.list() do
		for _, side in BehaviorModel.SIDES do
			Registry.ensureBehaviorTemplate(def.id, side)
		end
	end

	local folder = Registry.typesFolder()
	for _, child in folder:GetChildren() do
		watch(child)
	end
	table.insert(
		connections,
		folder.ChildAdded:Connect(function(child)
			if child:IsA("ModuleScript") then
				local typeId, side = behaviorTemplateIdentity(child)
				if typeId and side then
					Registry.canonicalizeBehaviorTemplate(typeId, side)
					watch(child)
					return
				end
				local legacyTypeId = legacyBehaviorTypeId(child)
				if legacyTypeId then
					migrateLegacyBehavior(legacyTypeId)
					for _, migratedSide in BehaviorModel.SIDES do
						local migrated = Registry.canonicalizeBehaviorTemplate(legacyTypeId, migratedSide)
						if migrated then
							watch(migrated)
						end
					end
				end
			end
		end)
	)

	return {
		destroy = function()
			stopped = true
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
		end,
	}
end

return Registry
