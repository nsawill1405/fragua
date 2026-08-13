-- Canonical engine schemas + insertable class categories.

export type PropDef = {
	name: string,
	valueType: string,
	default: any,
	category: string,
	readonly: boolean?,
	enumItems: { string }?,
	enumType: string?,
}

local EngineClassSchemas = if script then require(script.Parent.EngineClassSchemas) else require("./EngineClassSchemas")

local MATERIALS = EngineClassSchemas.materials()

local BASE_CLASSES = {
	"Configuration",
	"Folder",
	"Humanoid",
	"Instance",
	"LocalScript",
	"ModuleScript",
	"Part",
	"Script",
}

export type InsertSection = {
	title: string,
	classes: { string },
}

-- insert picker + explorer ranks: scripts first, then the rest of the catalogue
local INSERT_SECTIONS: { InsertSection } = {
	{
		title = "Scripts",
		classes = {
			"Script",
			"LocalScript",
			"ModuleScript",
		},
	},
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
		title = "Gameplay",
		classes = {
			"Humanoid",
			"HumanoidDescription",
			"BodyColors",
			"Shirt",
			"Pants",
			"ShirtGraphic",
			"Accessory",
			"Hat",
			"ForceField",
			"Tool",
			"ProximityPrompt",
			"ClickDetector",
			"DragDetector",
			"Sound",
			"SoundGroup",
			"Attachment",
			"Bone",
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
}

local EngineSchemas = {}

function EngineSchemas.get(className: string): { PropDef }
	return EngineClassSchemas.forClass(className)
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
	return EngineClassSchemas.has(className)
end

function EngineSchemas.classNames(): { string }
	local known = {}
	for _, className in EngineClassSchemas.classNames() do
		known[className] = true
	end
	for _, className in BASE_CLASSES do
		known[className] = true
	end
	for _, section in INSERT_SECTIONS do
		for _, className in section.classes do
			known[className] = true
		end
	end
	local names = {}
	for className in known do
		table.insert(names, className)
	end
	table.sort(names)
	return names
end

function EngineSchemas.baseClasses(): { string }
	return table.clone(BASE_CLASSES)
end

function EngineSchemas.materials(): { string }
	return MATERIALS
end

return EngineSchemas
