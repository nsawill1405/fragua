local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local Constants = require(script.Parent.Parent.Shared.Constants)
local EngineSchemas = require(script.Parent.EngineSchemas)

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
				-- Prefer requiring the module (returns JSON string); fall back to source scrape.
				local ok, result = pcall(require, child)
				if ok and typeof(result) == "string" then
					raw = result
				else
					local source = child.Source
					local startPos = string.find(source, "[[", 1, true)
					local endPos = startPos and string.find(source, "]]", startPos + 2, true)
					if startPos and endPos then
						raw = string.sub(source, startPos + 2, endPos - 1)
					else
						raw = source
					end
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
	local existing = folder:FindFirstChild(def.id)
	if existing then
		existing:Destroy()
	end
	local module = Instance.new("ModuleScript")
	module.Name = def.id
	module.Source = typeModuleSource(def)
	module.Parent = folder
	fireChanged()
end

function Registry.delete(id: string): boolean
	local folder = Registry.typesFolder()
	local existing = folder:FindFirstChild(id)
	if not existing then
		return false
	end
	existing:Destroy()
	fireChanged()
	return true
end

local function mergeProps(base: { PropDef }, extra: { PropDef }): { PropDef }
	local byName: { [string]: PropDef } = {}
	local order: { string } = {}
	for _, prop in base do
		byName[prop.name] = prop
		table.insert(order, prop.name)
	end
	for _, prop in extra do
		if not byName[prop.name] then
			table.insert(order, prop.name)
		end
		byName[prop.name] = prop
	end
	local merged = {}
	for _, name in order do
		table.insert(merged, byName[name])
	end
	return merged
end

function Registry.resolvedSchema(def: TypeDef, visiting: { [string]: boolean }?): { PropDef }
	visiting = visiting or {}
	if visiting[def.id] then
		return table.clone(def.properties)
	end
	visiting[def.id] = true

	local baseProps: { PropDef }
	local parentCustom = Registry.get(def.extends)
	if parentCustom then
		baseProps = Registry.resolvedSchema(parentCustom, visiting)
	else
		baseProps = EngineSchemas.get(def.extends)
	end
	return mergeProps(baseProps, def.properties)
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

	local behavior = Instance.new("ModuleScript")
	behavior.Name = Constants.BEHAVIOR_NAME
	behavior.Source = table.concat({
		`-- Fragua edit-time / runtime behavior for {def.id}`,
		`local Behavior = {}`,
		``,
		`function Behavior.onCreated(instance)`,
		`\t-- Runs when the instance is created or loaded in Studio edit mode.`,
		`end`,
		``,
		`function Behavior.onSelected(instance)`,
		`end`,
		``,
		`function Behavior.onPropertyChanged(instance, key, value)`,
		`end`,
		``,
		`function Behavior.onAncestryChanged(instance)`,
		`end`,
		``,
		`return Behavior`,
		``,
	}, "\n")
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
	local module = Registry.typesFolder():FindFirstChild("Zombie")
	if module and module:IsA("ModuleScript") then
		-- behavior is on instances; seed template stored beside type
		local template = Instance.new("ModuleScript")
		template.Name = "ZombieBehavior"
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
		template.Parent = Registry.typesFolder()
	end
end

function Registry.getBehaviorSource(typeId: string): string?
	local template = Registry.typesFolder():FindFirstChild(typeId .. "Behavior")
	if template and template:IsA("ModuleScript") then
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

return Registry
