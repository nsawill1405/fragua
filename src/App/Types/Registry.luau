local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local Constants = require(script.Parent.Parent.Shared.Constants)
local BehaviorTemplatePolicy = require(script.Parent.BehaviorTemplatePolicy)
local EngineSchemas = require(script.Parent.EngineSchemas)
local SchemaMigration = require(script.Parent.SchemaMigration)
local SchemaResolver = require(script.Parent.SchemaResolver)

export type PropDef = EngineSchemas.PropDef

export type TypeDef = {
	id: string,
	name: string,
	description: string,
	extends: string,
	icon: string,
	properties: { PropDef },
}

local Registry = {}

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

local function serializeDefault(value: any): any
	local t = typeof(value)
	if t == "Color3" then
		return { __typeof = "Color3", R = value.R, G = value.G, B = value.B }
	elseif t == "Vector3" then
		return { __typeof = "Vector3", X = value.X, Y = value.Y, Z = value.Z }
	end
	return value
end

local function deserializeDefault(value: any): any
	if typeof(value) == "table" and value.__typeof == "Color3" then
		return Color3.new(value.R, value.G, value.B)
	elseif typeof(value) == "table" and value.__typeof == "Vector3" then
		return Vector3.new(value.X, value.Y, value.Z)
	end
	return value
end

local function encodeType(def: TypeDef): string
	local props = {}
	for _, prop in def.properties do
		table.insert(props, {
			name = prop.name,
			valueType = prop.valueType,
			default = serializeDefault(prop.default),
			category = prop.category,
			readonly = prop.readonly,
			enumItems = prop.enumItems,
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
					name = prop.name,
					valueType = prop.valueType or "string",
					default = deserializeDefault(prop.default),
					category = prop.category or "Data",
					readonly = prop.readonly,
					enumItems = prop.enumItems,
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

function Registry.list(): { TypeDef }
	local folder = Registry.typesFolder()
	local types: { TypeDef } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") or child:IsA("StringValue") then
			local raw: string
			if child:IsA("StringValue") then
				raw = child.Value
			else
				-- Decode current Source first. require() caches old values after Source edits.
				local source = child.Source
				local startPos = string.find(source, "[[", 1, true)
				local endPos = startPos and string.find(source, "]]", startPos + 2, true)
				local sourceRaw = if startPos and endPos then string.sub(source, startPos + 2, endPos - 1) else source
				if decodeType(sourceRaw) then
					raw = sourceRaw
				else
					local ok, result = pcall(require, child)
					raw = if ok and typeof(result) == "string" then result else sourceRaw
				end
			end
			local def = decodeType(raw)
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

local function typeModuleSource(def: TypeDef): string
	local json = encodeType(def)
	return `-- Fragua type definition: {def.id}\nreturn [[\n{json}\n]]\n`
end

function Registry.save(def: TypeDef)
	assert(def.id ~= "", "Type id required")
	local folder = Registry.typesFolder()
	local source = typeModuleSource(def)
	local existing = folder:FindFirstChild(def.id)
	if existing and existing:IsA("ModuleScript") then
		existing.Source = source
	else
		local module = Instance.new("ModuleScript")
		module.Name = def.id
		module.Source = source
		module.Parent = folder
		if existing then
			existing:Destroy()
		end
	end
	Registry.ensureBehaviorTemplate(def.id)
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
	local existing = folder:FindFirstChild(id)
	if not existing then
		return false
	end

	ChangeHistoryService:SetWaypoint("Fragua Delete Type")

	local placed = Registry.findInstances(id)
	for _, inst in placed do
		inst:Destroy()
	end

	local behaviorTemplate = folder:FindFirstChild(id .. "Behavior")
	if behaviorTemplate then
		behaviorTemplate:Destroy()
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

local RESERVED_ATTRS = {
	Name = true,
	Archivable = true,
	[Constants.TYPE_ATTR] = true,
}

-- Migrate attributes on placed instances after a type schema change.
function Registry.migrateInstances(typeId: string, previous: TypeDef?, nextDef: TypeDef)
	local previousResolved = if previous then Registry.resolvedSchema(previous) else {}
	local nextResolved = Registry.resolvedSchema(nextDef)
	local migration = SchemaMigration.plan({ properties = previousResolved }, { properties = nextResolved })
	local oldNames: { [string]: boolean } = {}
	if previous then
		for _, prop in previousResolved do
			oldNames[prop.name] = true
		end
	end

	local newProps: { [string]: PropDef } = {}
	for _, prop in nextResolved do
		newProps[prop.name] = prop
	end

	local renameFrom = if migration.rename[1] then migration.rename[1].from else nil
	local renameTo = if migration.rename[1] then migration.rename[1].to else nil

	ChangeHistoryService:SetWaypoint("Fragua Migrate Type")
	local count = 0
	for _, inst in Registry.findInstances(typeId) do
		count += 1
		if renameFrom and renameTo then
			local value = inst:GetAttribute(renameFrom)
			if value ~= nil then
				inst:SetAttribute(renameTo, value)
			end
			inst:SetAttribute(renameFrom, nil)
		end
		for name in pairs(oldNames) do
			if not newProps[name] and not RESERVED_ATTRS[name] and name ~= renameTo then
				inst:SetAttribute(name, nil)
			end
		end
		for name, prop in pairs(newProps) do
			if not RESERVED_ATTRS[name] and inst:GetAttribute(name) == nil then
				inst:SetAttribute(name, prop.default)
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
		if prop.name ~= "Name" and prop.name ~= "Archivable" and instance:GetAttribute(prop.name) == nil then
			instance:SetAttribute(prop.name, prop.default)
		end
	end
	Registry.ensureBehaviorTemplate(def.id)
	Registry.applyBehaviorTemplate(instance, def.id)
	fireChanged()
	ChangeHistoryService:SetWaypoint("Fragua Change Type Done")
	return true
end

function Registry.createInstance(typeId: string, parent: Instance?): Instance
	local def = Registry.get(typeId)
	assert(def, `Unknown Fragua type: {typeId}`)

	local inst = Instance.new("Configuration")
	inst.Name = def.name
	inst:SetAttribute(Constants.TYPE_ATTR, def.id)
	CollectionService:AddTag(inst, Constants.TAG)

	for _, prop in Registry.resolvedSchema(def) do
		if prop.name ~= "Name" and prop.name ~= "Archivable" then
			inst:SetAttribute(prop.name, prop.default)
		end
	end

	Registry.ensureBehaviorTemplate(def.id)

	local behavior = Instance.new("ModuleScript")
	behavior.Name = Constants.BEHAVIOR_NAME
	behavior:SetAttribute("_FraguaInstanceBehavior", true)
	behavior.Parent = inst

	inst.Parent = parent
	Registry.applyBehaviorTemplate(inst, def.id)
	return inst
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
			{ name = "DisplayName", valueType = "string", default = "Zombie", category = "Display" },
			{ name = "WalkSpeed", valueType = "number", default = 12, category = "Control" },
			{ name = "MaxHealth", valueType = "number", default = 150, category = "Health" },
			{ name = "Health", valueType = "number", default = 150, category = "Health" },
			{ name = "IsHostile", valueType = "boolean", default = true, category = "AI" },
			{ name = "DetectRange", valueType = "number", default = 40, category = "AI" },
			{ name = "AttackDamage", valueType = "number", default = 15, category = "AI" },
		},
	})

	-- Replace default behavior with nameplate demo for Zombie
	local template = Registry.ensureBehaviorTemplate("Zombie")
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

function Behavior.onStart(instance)
	ensureNameplate(instance)
end

function Behavior.onStop(_instance)
end

return Behavior
]]
end

local function defaultBehaviorSource(typeId: string): string
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
	local existing = root:FindFirstChild("BehaviorBackups")
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "BehaviorBackups"
	folder.Parent = root
	return folder
end

function Registry.canonicalizeBehaviorTemplate(typeId: string): ModuleScript?
	local behaviorName = typeId .. "Behavior"
	local candidates = {}
	local sources = {}
	for _, child in Registry.typesFolder():GetChildren() do
		if child.Name == behaviorName and child:IsA("ModuleScript") then
			table.insert(candidates, child)
			table.insert(sources, child.Source)
		end
	end
	if #candidates == 0 then
		return nil
	end

	local plan = BehaviorTemplatePolicy.plan(sources, defaultBehaviorSource(typeId))
	local canonical = candidates[plan.keep]
	canonical.Name = behaviorName
	canonical:SetAttribute("_FraguaSharedBehavior", true)

	for _, index in plan.backup do
		local backup = candidates[index]
		backup:SetAttribute("_FraguaSharedBehavior", nil)
		local backups = ensureBehaviorBackups()
		local suffix = 1
		local backupName = typeId .. "BehaviorBackup" .. tostring(suffix)
		while backups:FindFirstChild(backupName) do
			suffix += 1
			backupName = typeId .. "BehaviorBackup" .. tostring(suffix)
		end
		backup.Name = backupName
		backup.Parent = backups
	end
	for _, index in plan.discard do
		candidates[index]:Destroy()
	end
	return canonical
end

function Registry.getSharedBehavior(typeId: string): ModuleScript?
	return Registry.canonicalizeBehaviorTemplate(typeId)
end

function Registry.ensureBehaviorTemplate(typeId: string): ModuleScript
	local existing = Registry.getSharedBehavior(typeId)
	if existing then
		return existing
	end
	local template = Instance.new("ModuleScript")
	template.Name = typeId .. "Behavior"
	template.Source = defaultBehaviorSource(typeId)
	template:SetAttribute("_FraguaSharedBehavior", true)
	template.Parent = Registry.typesFolder()
	return template
end

function Registry.getBehaviorSource(typeId: string): string?
	local template = Registry.getSharedBehavior(typeId)
	if template then
		return template.Source
	end
	return nil
end

function Registry.applyBehaviorTemplate(instance: Instance, typeId: string)
	local source = Registry.getBehaviorSource(typeId)
	local behavior = instance:FindFirstChild(Constants.BEHAVIOR_NAME)
	if source and behavior and behavior:IsA("ModuleScript") then
		behavior.Source = source
	end
end

-- Push shared Behavior source onto every placed instance of this type
function Registry.syncBehaviorToInstances(typeId: string)
	local source = Registry.getBehaviorSource(typeId)
	if not source then
		return
	end
	for _, inst in Registry.findInstances(typeId) do
		local behavior = inst:FindFirstChild(Constants.BEHAVIOR_NAME)
		if behavior and behavior:IsA("ModuleScript") then
			behavior.Source = source
		end
	end
end

function Registry.setSharedBehaviorSource(typeId: string, source: string)
	local template = Registry.ensureBehaviorTemplate(typeId)
	template.Source = source
	Registry.syncBehaviorToInstances(typeId)
	-- notify edit-time host if present (avoid hard require cycle)
	local ok, Host = pcall(function()
		return require(script.Parent.Parent.Behaviors.Host)
	end)
	if ok and Host and Host.invalidateType then
		Host.invalidateType(typeId)
	end
end

function Registry.watchBehaviorTemplates()
	local connections: { RBXScriptConnection } = {}
	local watched = setmetatable({}, { __mode = "k" })
	local stopped = false

	local function watch(template: Instance)
		if stopped or watched[template] or not template:IsA("ModuleScript") then
			return
		end
		if template:GetAttribute("_FraguaSharedBehavior") ~= true then
			return
		end
		local typeId = template.Name:gsub("Behavior$", "")
		local canonical = Registry.canonicalizeBehaviorTemplate(typeId)
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
					Registry.syncBehaviorToInstances(typeId)
					local ok, Host = pcall(function()
						return require(script.Parent.Parent.Behaviors.Host)
					end)
					if ok and Host and Host.invalidateType then
						Host.invalidateType(typeId)
					end
					fireChanged()
				end)
			end)
		)
	end

	local folder = Registry.typesFolder()
	for _, child in folder:GetChildren() do
		watch(child)
	end
	table.insert(connections, folder.ChildAdded:Connect(watch))

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
