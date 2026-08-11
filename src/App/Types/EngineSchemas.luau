-- Curated property schemas + insertable class categories.

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

local EngineClassSchemas = require(script.Parent.EngineClassSchemas)

local INSTANCE_PROPS = props({
	{ name = "Name", valueType = "string", default = "Instance", category = "Data" },
	{ name = "Archivable", valueType = "boolean", default = true, category = "Data" },
})

local MATERIALS = EngineClassSchemas.materials()

local SCHEMAS: { [string]: { PropDef } } = {
	Instance = INSTANCE_PROPS,
	Folder = INSTANCE_PROPS,
	Configuration = INSTANCE_PROPS,
	Part = props({
		{ name = "Name", valueType = "string", default = "Part", category = "Data" },
		{ name = "Anchored", valueType = "boolean", default = false, category = "Behavior" },
		{ name = "CanCollide", valueType = "boolean", default = true, category = "Behavior" },
		{ name = "Transparency", valueType = "number", default = 0, category = "Appearance" },
		{ name = "Color", valueType = "Color3", default = Color3.fromRGB(163, 162, 165), category = "Appearance" },
		{ name = "Material", valueType = "enum", default = "Plastic", category = "Appearance", enumItems = MATERIALS },
		{ name = "Size", valueType = "Vector3", default = Vector3.new(4, 1, 2), category = "Transform" },
		{ name = "Position", valueType = "Vector3", default = Vector3.zero, category = "Transform" },
	}),
	Humanoid = props({
		{ name = "Name", valueType = "string", default = "Humanoid", category = "Data" },
		{ name = "Health", valueType = "number", default = 100, category = "Health" },
		{ name = "MaxHealth", valueType = "number", default = 100, category = "Health" },
		{ name = "WalkSpeed", valueType = "number", default = 16, category = "Control" },
		{ name = "JumpPower", valueType = "number", default = 50, category = "Control" },
		{ name = "DisplayName", valueType = "string", default = "", category = "Display" },
	}),
	Script = props({
		{ name = "Name", valueType = "string", default = "Script", category = "Data" },
		{ name = "Disabled", valueType = "boolean", default = false, category = "Data" },
	}),
	LocalScript = props({
		{ name = "Name", valueType = "string", default = "LocalScript", category = "Data" },
		{ name = "Disabled", valueType = "boolean", default = false, category = "Data" },
	}),
	ModuleScript = props({
		{ name = "Name", valueType = "string", default = "ModuleScript", category = "Data" },
	}),
}

export type InsertSection = {
	title: string,
	classes: { string },
}

local INSERT_SECTIONS: { InsertSection } = {
	{
		title = "Structure",
		classes = {
			"Folder",
			"Model",
			"Configuration",
			"WorldModel",
			"Actor",
			"Camera",
			"TerrainRegion",
		},
	},
	{
		title = "Parts",
		classes = {
			"Part",
			"MeshPart",
			"WedgePart",
			"CornerWedgePart",
			"TrussPart",
			"SpawnLocation",
			"Seat",
			"VehicleSeat",
			"NegateOperation",
			"UnionOperation",
			"IntersectOperation",
		},
	},
	{
		title = "Scripts",
		classes = {
			"Script",
			"LocalScript",
			"ModuleScript",
		},
	},
	{
		title = "Values",
		classes = {
			"StringValue",
			"BoolValue",
			"NumberValue",
			"IntValue",
			"ObjectValue",
			"Vector3Value",
			"CFrameValue",
			"Color3Value",
			"BrickColorValue",
			"RayValue",
		},
	},
	{
		title = "Networking",
		classes = {
			"RemoteEvent",
			"RemoteFunction",
			"BindableEvent",
			"BindableFunction",
			"UnreliableRemoteEvent",
		},
	},
	{
		title = "UI",
		classes = {
			"ScreenGui",
			"BillboardGui",
			"SurfaceGui",
			"Frame",
			"ScrollingFrame",
			"CanvasGroup",
			"TextLabel",
			"TextButton",
			"TextBox",
			"ImageLabel",
			"ImageButton",
			"ViewportFrame",
			"VideoFrame",
			"UICorner",
			"UIPadding",
			"UIListLayout",
			"UIGridLayout",
			"UITableLayout",
			"UIPageLayout",
			"UIAspectRatioConstraint",
			"UISizeConstraint",
			"UITextSizeConstraint",
			"UIScale",
			"UIStroke",
			"UIGradient",
			"UIFlexItem",
		},
	},
	{
		title = "Effects & Lights",
		classes = {
			"PointLight",
			"SpotLight",
			"SurfaceLight",
			"Fire",
			"Smoke",
			"Sparkles",
			"ParticleEmitter",
			"Beam",
			"Trail",
			"Highlight",
			"Decal",
			"Texture",
			"SurfaceAppearance",
			"BloomEffect",
			"BlurEffect",
			"ColorCorrectionEffect",
			"DepthOfFieldEffect",
			"SunRaysEffect",
			"Atmosphere",
			"Sky",
			"Clouds",
		},
	},
	{
		title = "Gameplay",
		classes = {
			"Humanoid",
			"HumanoidDescription",
			"Tool",
			"ProximityPrompt",
			"ClickDetector",
			"DragDetector",
			"Sound",
			"SoundGroup",
			"Attachment",
			"Bone",
			"Accessory",
			"Hat",
			"Shirt",
			"Pants",
			"ShirtGraphic",
			"BodyColors",
			"ForceField",
			"Team",
		},
	},
	{
		title = "Animation",
		classes = {
			"Animation",
			"AnimationController",
			"Animator",
			"KeyframeSequence",
			"Keyframe",
			"Pose",
			"NumberPose",
		},
	},
	{
		title = "Constraints",
		classes = {
			"WeldConstraint",
			"Weld",
			"Snap",
			"ManualWeld",
			"Motor6D",
			"Motor",
			"RopeConstraint",
			"RodConstraint",
			"SpringConstraint",
			"HingeConstraint",
			"BallSocketConstraint",
			"PrismaticConstraint",
			"CylindricalConstraint",
			"UniversalConstraint",
			"PlaneConstraint",
			"RigidConstraint",
			"AlignPosition",
			"AlignOrientation",
			"VectorForce",
			"LineForce",
			"Torque",
			"AngularVelocity",
			"LinearVelocity",
			"NoCollisionConstraint",
		},
	},
	{
		title = "Physics",
		classes = {
			"Attachment",
			"Bone",
			"PathfindingModifier",
			"PathfindingLink",
			"SpecialMesh",
			"BlockMesh",
			"CylinderMesh",
			"FileMesh",
			"CharacterMesh",
		},
	},
}

local EngineSchemas = {}

function EngineSchemas.get(className: string): { PropDef }
	local rows = {}
	local indexes = {}
	local function merge(layer)
		for _, property in layer do
			local copy = table.clone(property)
			local existing = indexes[property.name]
			if existing then
				rows[existing] = copy
			else
				table.insert(rows, copy)
				indexes[property.name] = #rows
			end
		end
	end
	merge(INSTANCE_PROPS)
	merge(EngineClassSchemas.forClass(className))
	merge(SCHEMAS[className] or {})
	return rows
end

function EngineSchemas.insertable(): { string }
	local list = {}
	local seen = {}
	for _, section in INSERT_SECTIONS do
		for _, className in section.classes do
			if not seen[className] then
				seen[className] = true
				table.insert(list, className)
			end
		end
	end
	return list
end

function EngineSchemas.insertSections(): { InsertSection }
	return INSERT_SECTIONS
end

function EngineSchemas.has(className: string): boolean
	return SCHEMAS[className] ~= nil or EngineClassSchemas.has(className)
end

function EngineSchemas.baseClasses(): { string }
	local list = {}
	for name in SCHEMAS do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

function EngineSchemas.materials(): { string }
	return MATERIALS
end

return EngineSchemas
