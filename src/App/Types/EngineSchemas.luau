-- Curated property schemas for common engine classes (inheritance bases).

export type PropDef = {
	name: string,
	valueType: string,
	default: any,
	category: string,
	readonly: boolean?,
	enumItems: { string }?,
}

local function props(list: { PropDef }): { PropDef }
	return list
end

local INSTANCE_PROPS = props({
	{ name = "Name", valueType = "string", default = "Instance", category = "Data" },
	{ name = "Archivable", valueType = "boolean", default = true, category = "Data" },
})

local SCHEMAS: { [string]: { PropDef } } = {
	Instance = INSTANCE_PROPS,
	Folder = INSTANCE_PROPS,
	Configuration = INSTANCE_PROPS,
	Part = props({
		{ name = "Name", valueType = "string", default = "Part", category = "Data" },
		{ name = "Anchored", valueType = "boolean", default = false, category = "Data" },
		{ name = "CanCollide", valueType = "boolean", default = true, category = "Data" },
		{ name = "CanQuery", valueType = "boolean", default = true, category = "Data" },
		{ name = "CanTouch", valueType = "boolean", default = true, category = "Data" },
		{ name = "CastShadow", valueType = "boolean", default = true, category = "Data" },
		{ name = "Transparency", valueType = "number", default = 0, category = "Appearance" },
		{ name = "Reflectance", valueType = "number", default = 0, category = "Appearance" },
		{ name = "Color", valueType = "Color3", default = Color3.fromRGB(163, 162, 165), category = "Appearance" },
		{ name = "Size", valueType = "Vector3", default = Vector3.new(4, 1, 2), category = "Transform" },
		{ name = "Position", valueType = "Vector3", default = Vector3.zero, category = "Transform", readonly = true },
		{ name = "Material", valueType = "string", default = "Plastic", category = "Appearance" },
		{ name = "Shape", valueType = "string", default = "Block", category = "Part" },
	}),
	MeshPart = props({
		{ name = "Name", valueType = "string", default = "MeshPart", category = "Data" },
		{ name = "Anchored", valueType = "boolean", default = false, category = "Data" },
		{ name = "CanCollide", valueType = "boolean", default = true, category = "Data" },
		{ name = "Transparency", valueType = "number", default = 0, category = "Appearance" },
		{ name = "Color", valueType = "Color3", default = Color3.fromRGB(163, 162, 165), category = "Appearance" },
		{ name = "Size", valueType = "Vector3", default = Vector3.new(4, 1, 2), category = "Transform" },
	}),
	Model = props({
		{ name = "Name", valueType = "string", default = "Model", category = "Data" },
		{ name = "PrimaryPart", valueType = "string", default = "", category = "Data", readonly = true },
	}),
	Humanoid = props({
		{ name = "Name", valueType = "string", default = "Humanoid", category = "Data" },
		{ name = "Health", valueType = "number", default = 100, category = "Health" },
		{ name = "MaxHealth", valueType = "number", default = 100, category = "Health" },
		{ name = "WalkSpeed", valueType = "number", default = 16, category = "Control" },
		{ name = "JumpPower", valueType = "number", default = 50, category = "Control" },
		{ name = "JumpHeight", valueType = "number", default = 7.2, category = "Control" },
		{ name = "HipHeight", valueType = "number", default = 0, category = "Control" },
		{ name = "AutoRotate", valueType = "boolean", default = true, category = "Control" },
		{ name = "DisplayDistanceType", valueType = "string", default = "Relative", category = "Display" },
		{ name = "HealthDisplayType", valueType = "string", default = "DisplayWhenDamaged", category = "Display" },
		{ name = "NameDisplayDistance", valueType = "number", default = 100, category = "Display" },
		{ name = "HealthDisplayDistance", valueType = "number", default = 100, category = "Display" },
		{ name = "DisplayName", valueType = "string", default = "", category = "Display" },
	}),
	Script = props({
		{ name = "Name", valueType = "string", default = "Script", category = "Data" },
		{ name = "Disabled", valueType = "boolean", default = false, category = "Data" },
		{ name = "RunContext", valueType = "string", default = "Legacy", category = "Data" },
	}),
	LocalScript = props({
		{ name = "Name", valueType = "string", default = "LocalScript", category = "Data" },
		{ name = "Disabled", valueType = "boolean", default = false, category = "Data" },
	}),
	ModuleScript = props({
		{ name = "Name", valueType = "string", default = "ModuleScript", category = "Data" },
	}),
	BillboardGui = props({
		{ name = "Name", valueType = "string", default = "BillboardGui", category = "Data" },
		{ name = "AlwaysOnTop", valueType = "boolean", default = false, category = "Data" },
		{ name = "Enabled", valueType = "boolean", default = true, category = "Data" },
		{ name = "Size", valueType = "string", default = "{0, 200},{0, 50}", category = "Data" },
		{ name = "StudsOffset", valueType = "Vector3", default = Vector3.new(0, 3, 0), category = "Data" },
	}),
	StringValue = props({
		{ name = "Name", valueType = "string", default = "Value", category = "Data" },
		{ name = "Value", valueType = "string", default = "", category = "Data" },
	}),
	BoolValue = props({
		{ name = "Name", valueType = "string", default = "Value", category = "Data" },
		{ name = "Value", valueType = "boolean", default = false, category = "Data" },
	}),
	NumberValue = props({
		{ name = "Name", valueType = "string", default = "Value", category = "Data" },
		{ name = "Value", valueType = "number", default = 0, category = "Data" },
	}),
	IntValue = props({
		{ name = "Name", valueType = "string", default = "Value", category = "Data" },
		{ name = "Value", valueType = "number", default = 0, category = "Data" },
	}),
}

local INSERTABLE_CLASSES = {
	"Folder",
	"Part",
	"MeshPart",
	"Model",
	"Humanoid",
	"Script",
	"LocalScript",
	"ModuleScript",
	"Configuration",
	"StringValue",
	"BoolValue",
	"NumberValue",
	"IntValue",
	"ObjectValue",
	"RemoteEvent",
	"RemoteFunction",
	"BindableEvent",
	"BindableFunction",
	"BillboardGui",
	"SurfaceGui",
	"Attachment",
	"Highlight",
	"ProximityPrompt",
	"ClickDetector",
	"Sound",
	"Decal",
	"Texture",
	"PointLight",
	"SpotLight",
	"Fire",
	"Smoke",
	"Sparkles",
	"ParticleEmitter",
	"Beam",
	"Trail",
	"WeldConstraint",
	"Motor6D",
	"SpawnLocation",
	"Seat",
	"Tool",
	"Camera",
	"UICorner",
	"UIListLayout",
	"UIPadding",
	"UIStroke",
	"Frame",
	"TextLabel",
	"TextButton",
	"TextBox",
	"ImageLabel",
	"ImageButton",
	"ScrollingFrame",
}

local EngineSchemas = {}

function EngineSchemas.get(className: string): { PropDef }
	return SCHEMAS[className] or INSTANCE_PROPS
end

function EngineSchemas.insertable(): { string }
	return INSERTABLE_CLASSES
end

function EngineSchemas.has(className: string): boolean
	return SCHEMAS[className] ~= nil
end

function EngineSchemas.baseClasses(): { string }
	local list = {}
	for name in SCHEMAS do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

return EngineSchemas
