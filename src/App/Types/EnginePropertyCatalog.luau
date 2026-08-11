-- Canonical engine property metadata shared by type schemas and the Properties dock.

export type EngineProp = {
	name: string,
	category: string,
	valueType: string?, -- string | number | boolean | Color3 | Vector3 | enum
	default: any?,
	defaultKind: string?,
	readonly: boolean?,
	enumItems: { string }?,
	enumType: string?, -- Enum family name, e.g. "Material"
	minimum: number?,
	maximum: number?,
	step: number?,
	multiline: boolean?,
	referenceType: string?,
}

local EnginePropertyCatalog = {}

local MATERIALS = {
	"Plastic",
	"Wood",
	"Slate",
	"Concrete",
	"CorrodedMetal",
	"DiamondPlate",
	"Foil",
	"Grass",
	"Ice",
	"Marble",
	"Granite",
	"Brick",
	"Pebble",
	"Sand",
	"Fabric",
	"SmoothPlastic",
	"Metal",
	"WoodPlanks",
	"Glass",
	"ForceField",
	"Neon",
	"Cobblestone",
	"Asphalt",
	"Rock",
	"Glacier",
	"Snow",
	"Sandstone",
	"Mud",
	"Basalt",
	"Ground",
	"CrackedLava",
	"LeafyGrass",
	"Salt",
	"Limestone",
	"Pavement",
}

local BASE_PART_PROPS = {
	{ name = "Anchored", category = "Behavior", valueType = "boolean", default = false },
	{ name = "CanCollide", category = "Behavior", valueType = "boolean", default = true },
	{ name = "CanQuery", category = "Behavior", valueType = "boolean", default = true },
	{ name = "CanTouch", category = "Behavior", valueType = "boolean", default = true },
	{ name = "Massless", category = "Behavior", valueType = "boolean", default = false },
	{ name = "CastShadow", category = "Appearance", valueType = "boolean", default = true },
	{ name = "Transparency", category = "Appearance", valueType = "number", default = 0 },
	{ name = "Reflectance", category = "Appearance", valueType = "number", default = 0 },
	{ name = "Color", category = "Appearance", valueType = "Color3", defaultKind = "partColor" },
	{
		name = "Material",
		category = "Appearance",
		valueType = "enum",
		default = "Plastic",
		enumType = "Material",
		enumItems = MATERIALS,
	},
	{ name = "MaterialVariant", category = "Appearance", valueType = "string", default = "" },
	{ name = "Size", category = "Transform", valueType = "Vector3", defaultKind = "partSize" },
	{ name = "Position", category = "Transform", valueType = "Vector3", defaultKind = "vectorZero" },
	{ name = "Orientation", category = "Transform", valueType = "Vector3", defaultKind = "vectorZero" },
	{ name = "Rotation", category = "Transform", valueType = "Vector3", defaultKind = "vectorZero" },
	{
		name = "AssemblyAngularVelocity",
		category = "Physics",
		valueType = "Vector3",
		defaultKind = "vectorZero",
	},
	{
		name = "AssemblyLinearVelocity",
		category = "Physics",
		valueType = "Vector3",
		defaultKind = "vectorZero",
	},
	{ name = "CollisionGroup", category = "Physics", valueType = "string", default = "Default" },
	{ name = "EnableFluidForces", category = "Physics", valueType = "boolean", default = true },
	{ name = "Locked", category = "Behavior", valueType = "boolean", default = false },
	{ name = "RootPriority", category = "Physics", valueType = "number", default = 0 },
}

local GUI_OBJECT_PROPS = {
	{ name = "Visible", category = "Data", valueType = "boolean" },
	{ name = "Active", category = "Behavior", valueType = "boolean" },
	{ name = "Interactable", category = "Behavior", valueType = "boolean" },
	{ name = "BackgroundColor3", category = "Appearance", valueType = "Color3" },
	{ name = "BackgroundTransparency", category = "Appearance", valueType = "number" },
	{ name = "BorderColor3", category = "Appearance", valueType = "Color3" },
	{ name = "BorderSizePixel", category = "Appearance", valueType = "number" },
	{ name = "LayoutOrder", category = "Layout", valueType = "number" },
	{ name = "ZIndex", category = "Layout", valueType = "number" },
}

local LIGHT_PROPS = {
	{ name = "Enabled", category = "Data", valueType = "boolean" },
	{ name = "Brightness", category = "Appearance", valueType = "number" },
	{ name = "Color", category = "Appearance", valueType = "Color3" },
	{ name = "Shadows", category = "Appearance", valueType = "boolean" },
}

local POST_EFFECT_PROPS = {
	{ name = "Enabled", category = "Data", valueType = "boolean" },
}

local BASE_SCRIPT_PROPS = {
	{ name = "Disabled", category = "Data", valueType = "boolean" },
}

local TRIANGLE_MESH_PROPS = {
	{
		name = "CollisionFidelity",
		category = "Geometry",
		valueType = "enum",
		default = "Default",
		enumType = "CollisionFidelity",
		enumItems = { "Default", "Hull", "Box", "PreciseConvexDecomposition" },
	},
	{
		name = "FluidFidelity",
		category = "Geometry",
		valueType = "enum",
		default = "Automatic",
		enumType = "FluidFidelity",
		enumItems = { "Automatic", "UseCollisionGeometry", "UsePreciseGeometry" },
	},
	{ name = "MeshSize", category = "Geometry", valueType = "Vector3", defaultKind = "vectorZero", readonly = true },
}

local PART_OPERATION_PROPS = {
	{
		name = "RenderFidelity",
		category = "Geometry",
		valueType = "enum",
		default = "Automatic",
		enumType = "RenderFidelity",
		enumItems = { "Automatic", "Precise", "Performance" },
	},
	{ name = "SmoothingAngle", category = "Geometry", valueType = "number", default = 30 },
	{ name = "TriangleCount", category = "Geometry", valueType = "number", default = 0, readonly = true },
	{ name = "UsePartColor", category = "Appearance", valueType = "boolean", default = false },
}

local PART_DERIVED_PROPS = {
	{
		name = "Shape",
		category = "Part",
		valueType = "enum",
		default = "Block",
		enumType = "PartType",
		enumItems = { "Ball", "Block", "Cylinder", "Wedge", "CornerWedge" },
	},
}

local INHERITED_FAMILIES = {
	{
		className = "BasePart",
		properties = BASE_PART_PROPS,
		classes = {
			Part = true,
			MeshPart = true,
			WedgePart = true,
			CornerWedgePart = true,
			TrussPart = true,
			SpawnLocation = true,
			Seat = true,
			VehicleSeat = true,
			NegateOperation = true,
			UnionOperation = true,
			IntersectOperation = true,
		},
	},
	{
		className = "GuiObject",
		properties = GUI_OBJECT_PROPS,
		classes = { Frame = true, TextLabel = true, TextButton = true },
	},
	{
		className = "Light",
		properties = LIGHT_PROPS,
		classes = { PointLight = true, SpotLight = true, SurfaceLight = true },
	},
	{
		className = "PostEffect",
		properties = POST_EFFECT_PROPS,
		classes = {
			BloomEffect = true,
			BlurEffect = true,
			ColorCorrectionEffect = true,
			DepthOfFieldEffect = true,
			SunRaysEffect = true,
		},
	},
	{
		className = "BaseScript",
		properties = BASE_SCRIPT_PROPS,
		classes = { Script = true, LocalScript = true },
	},
	{
		className = "TriangleMeshPart",
		properties = TRIANGLE_MESH_PROPS,
		classes = { MeshPart = true, NegateOperation = true, UnionOperation = true, IntersectOperation = true },
	},
	{
		className = "PartOperation",
		properties = PART_OPERATION_PROPS,
		classes = { NegateOperation = true, UnionOperation = true, IntersectOperation = true },
	},
	{
		className = "Part",
		properties = PART_DERIVED_PROPS,
		classes = { Part = true, Seat = true, SpawnLocation = true },
	},
}

local BY_CLASS: { [string]: { EngineProp } } = {
	Instance = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "ClassName", category = "Data", valueType = "string", readonly = true },
		{ name = "Archivable", category = "Behavior", valueType = "boolean" },
	},
	Workspace = {
		{ name = "Gravity", category = "World", valueType = "number" },
		{ name = "FallenPartsDestroyHeight", category = "World", valueType = "number" },
		{ name = "AllowThirdPartySales", category = "Behavior", valueType = "boolean" },
		{ name = "StreamingEnabled", category = "Streaming", valueType = "boolean" },
	},
	Lighting = {
		{ name = "Ambient", category = "Appearance", valueType = "Color3" },
		{ name = "OutdoorAmbient", category = "Appearance", valueType = "Color3" },
		{ name = "ColorShift_Top", category = "Appearance", valueType = "Color3" },
		{ name = "ColorShift_Bottom", category = "Appearance", valueType = "Color3" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "ClockTime", category = "Celestial", valueType = "number" },
		{ name = "GeographicLatitude", category = "Celestial", valueType = "number" },
		{ name = "GlobalShadows", category = "Appearance", valueType = "boolean" },
		{ name = "FogColor", category = "Fog", valueType = "Color3" },
		{ name = "FogStart", category = "Fog", valueType = "number" },
		{ name = "FogEnd", category = "Fog", valueType = "number" },
	},
	Players = {
		{ name = "CharacterAutoLoads", category = "Behavior", valueType = "boolean" },
		{ name = "RespawnTime", category = "Behavior", valueType = "number" },
	},
	SoundService = {
		{ name = "AmbientReverb", category = "Audio", valueType = "enum", enumType = "ReverbType" },
		{ name = "DistanceFactor", category = "Audio", valueType = "number" },
		{ name = "DopplerScale", category = "Audio", valueType = "number" },
		{ name = "RolloffScale", category = "Audio", valueType = "number" },
	},
	StarterGui = {
		{ name = "ResetPlayerGuiOnSpawn", category = "Behavior", valueType = "boolean" },
		{ name = "ScreenOrientation", category = "Behavior", valueType = "enum", enumType = "ScreenOrientation" },
	},
	StarterPlayer = {
		{ name = "AutoJumpEnabled", category = "Mobile", valueType = "boolean" },
		{ name = "CameraMaxZoomDistance", category = "Camera", valueType = "number" },
		{ name = "CameraMinZoomDistance", category = "Camera", valueType = "number" },
		{ name = "CameraMode", category = "Camera", valueType = "enum", enumType = "CameraMode" },
		{ name = "CharacterBreakJointsOnDeath", category = "Character", valueType = "boolean" },
		{ name = "CharacterJumpHeight", category = "Character Jump Settings", valueType = "number" },
		{ name = "CharacterJumpPower", category = "Character Jump Settings", valueType = "number" },
		{ name = "CharacterMaxSlopeAngle", category = "Character", valueType = "number" },
		{ name = "CharacterUseJumpPower", category = "Character Jump Settings", valueType = "boolean" },
		{ name = "CharacterWalkSpeed", category = "Character", valueType = "number" },
		{ name = "ClassicDeath", category = "Character", valueType = "boolean" },
		{ name = "CreateDefaultPlayerModule", category = "Controls", valueType = "boolean" },
		{
			name = "DevCameraOcclusionMode",
			category = "Camera",
			valueType = "enum",
			enumType = "DevCameraOcclusionMode",
		},
		{
			name = "DevComputerCameraMovementMode",
			category = "Camera",
			valueType = "enum",
			enumType = "DevComputerCameraMovementMode",
		},
		{
			name = "DevComputerMovementMode",
			category = "Controls",
			valueType = "enum",
			enumType = "DevComputerMovementMode",
		},
		{
			name = "DevTouchCameraMovementMode",
			category = "Camera",
			valueType = "enum",
			enumType = "DevTouchCameraMovementMode",
		},
		{
			name = "DevTouchMovementMode",
			category = "Controls",
			valueType = "enum",
			enumType = "DevTouchMovementMode",
		},
		{
			name = "EnableDynamicHeads",
			category = "Character",
			valueType = "enum",
			enumType = "LoadDynamicHeads",
		},
		{ name = "EnableMouseLockOption", category = "Controls", valueType = "boolean" },
		{ name = "HealthDisplayDistance", category = "Data", valueType = "number" },
		{ name = "LoadCharacterAppearance", category = "Character", valueType = "boolean" },
		{
			name = "LoadCharacterLayeredClothing",
			category = "Character",
			valueType = "enum",
			enumType = "LoadCharacterLayeredClothing",
		},
		{
			name = "LuaCharacterController",
			category = "Controls",
			valueType = "enum",
			enumType = "CharacterControlMode",
		},
		{ name = "NameDisplayDistance", category = "Data", valueType = "number" },
		{ name = "UserEmotesEnabled", category = "Character", valueType = "boolean" },
		{ name = "AllowCustomAnimations", category = "Character", valueType = "boolean", readonly = true },
	},
	Team = {
		{ name = "AutoAssignable", category = "Data", valueType = "boolean", default = true },
		{ name = "TeamColor", category = "Data", valueType = "BrickColor", defaultKind = "teamColor" },
	},
	Part = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Anchored", category = "Behavior", valueType = "boolean" },
		{ name = "CanCollide", category = "Behavior", valueType = "boolean" },
		{ name = "CanQuery", category = "Behavior", valueType = "boolean" },
		{ name = "CanTouch", category = "Behavior", valueType = "boolean" },
		{ name = "CastShadow", category = "Appearance", valueType = "boolean" },
		{ name = "Transparency", category = "Appearance", valueType = "number" },
		{ name = "Reflectance", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{
			name = "Material",
			category = "Appearance",
			valueType = "enum",
			enumType = "Material",
			enumItems = MATERIALS,
		},
		{
			name = "Shape",
			category = "Part",
			valueType = "enum",
			enumType = "PartType",
			enumItems = {
				"Ball",
				"Block",
				"Cylinder",
				"Wedge",
				"CornerWedge",
			},
		},
		{ name = "Size", category = "Transform", valueType = "Vector3" },
		{ name = "Position", category = "Transform", valueType = "Vector3" },
		{ name = "Orientation", category = "Transform", valueType = "Vector3" },
	},
	MeshPart = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Anchored", category = "Behavior", valueType = "boolean" },
		{ name = "CanCollide", category = "Behavior", valueType = "boolean" },
		{ name = "Transparency", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{
			name = "Material",
			category = "Appearance",
			valueType = "enum",
			enumType = "Material",
			enumItems = MATERIALS,
		},
		{ name = "Size", category = "Transform", valueType = "Vector3" },
		{ name = "Position", category = "Transform", valueType = "Vector3" },
	},
	SpawnLocation = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Behavior", valueType = "boolean" },
		{ name = "Duration", category = "Behavior", valueType = "number" },
		{ name = "Neutral", category = "Behavior", valueType = "boolean" },
		{ name = "Anchored", category = "Behavior", valueType = "boolean" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{ name = "Size", category = "Transform", valueType = "Vector3" },
		{ name = "Position", category = "Transform", valueType = "Vector3" },
	},
	Model = {
		{ name = "Name", category = "Data", valueType = "string" },
	},
	Humanoid = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Health", category = "Health", valueType = "number" },
		{ name = "MaxHealth", category = "Health", valueType = "number" },
		{ name = "WalkSpeed", category = "Control", valueType = "number" },
		{ name = "JumpPower", category = "Control", valueType = "number" },
		{ name = "JumpHeight", category = "Control", valueType = "number" },
		{ name = "HipHeight", category = "Control", valueType = "number" },
		{ name = "AutoRotate", category = "Control", valueType = "boolean" },
		{ name = "DisplayName", category = "Display", valueType = "string" },
		{ name = "NameDisplayDistance", category = "Display", valueType = "number" },
		{ name = "HealthDisplayDistance", category = "Display", valueType = "number" },
	},
	Script = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Disabled", category = "Data", valueType = "boolean" },
		{
			name = "RunContext",
			category = "Data",
			valueType = "enum",
			enumType = "RunContext",
			enumItems = {
				"Legacy",
				"Server",
				"Client",
				"Plugin",
			},
		},
	},
	LocalScript = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Disabled", category = "Data", valueType = "boolean" },
	},
	ModuleScript = {
		{ name = "Name", category = "Data", valueType = "string" },
	},
	Folder = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Archivable", category = "Data", valueType = "boolean" },
	},
	Configuration = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Archivable", category = "Data", valueType = "boolean" },
	},
	Sound = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "SoundId", category = "Data", valueType = "string" },
		{ name = "Volume", category = "Audio", valueType = "number" },
		{ name = "PlaybackSpeed", category = "Audio", valueType = "number" },
		{ name = "Looped", category = "Audio", valueType = "boolean" },
		{ name = "Playing", category = "Audio", valueType = "boolean" },
	},
	PointLight = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{ name = "Range", category = "Appearance", valueType = "number" },
	},
	SpotLight = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{ name = "Range", category = "Appearance", valueType = "number" },
		{ name = "Angle", category = "Appearance", valueType = "number" },
	},
	Highlight = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "FillColor", category = "Appearance", valueType = "Color3" },
		{ name = "OutlineColor", category = "Appearance", valueType = "Color3" },
		{ name = "FillTransparency", category = "Appearance", valueType = "number" },
		{ name = "OutlineTransparency", category = "Appearance", valueType = "number" },
	},
	Frame = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Visible", category = "Data", valueType = "boolean" },
		{ name = "BackgroundColor3", category = "Appearance", valueType = "Color3" },
		{ name = "BackgroundTransparency", category = "Appearance", valueType = "number" },
		{ name = "BorderSizePixel", category = "Appearance", valueType = "number" },
	},
	TextLabel = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Text", category = "Text", valueType = "string" },
		{ name = "TextColor3", category = "Text", valueType = "Color3" },
		{ name = "TextSize", category = "Text", valueType = "number" },
		{ name = "BackgroundTransparency", category = "Appearance", valueType = "number" },
		{ name = "Visible", category = "Data", valueType = "boolean" },
	},
	TextButton = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Text", category = "Text", valueType = "string" },
		{ name = "TextColor3", category = "Text", valueType = "Color3" },
		{ name = "TextSize", category = "Text", valueType = "number" },
		{ name = "BackgroundColor3", category = "Appearance", valueType = "Color3" },
		{ name = "Visible", category = "Data", valueType = "boolean" },
	},
	ProximityPrompt = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "ActionText", category = "Data", valueType = "string" },
		{ name = "ObjectText", category = "Data", valueType = "string" },
		{ name = "HoldDuration", category = "Data", valueType = "number" },
		{ name = "MaxActivationDistance", category = "Data", valueType = "number" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
	},
	Camera = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "FieldOfView", category = "Camera", valueType = "number" },
		{ name = "CameraType", category = "Camera", valueType = "enum", enumType = "CameraType" },
	},
	BloomEffect = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Intensity", category = "Appearance", valueType = "number" },
		{ name = "Size", category = "Appearance", valueType = "number" },
		{ name = "Threshold", category = "Appearance", valueType = "number" },
	},
	BlurEffect = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Size", category = "Appearance", valueType = "number" },
	},
	ColorCorrectionEffect = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "Contrast", category = "Appearance", valueType = "number" },
		{ name = "Saturation", category = "Appearance", valueType = "number" },
		{ name = "TintColor", category = "Appearance", valueType = "Color3" },
	},
	DepthOfFieldEffect = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "FarIntensity", category = "Appearance", valueType = "number" },
		{ name = "FocusDistance", category = "Appearance", valueType = "number" },
		{ name = "InFocusRadius", category = "Appearance", valueType = "number" },
		{ name = "NearIntensity", category = "Appearance", valueType = "number" },
	},
	SunRaysEffect = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Intensity", category = "Appearance", valueType = "number" },
		{ name = "Spread", category = "Appearance", valueType = "number" },
	},
	Atmosphere = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Density", category = "Appearance", valueType = "number" },
		{ name = "Offset", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{ name = "Decay", category = "Appearance", valueType = "Color3" },
		{ name = "Glare", category = "Appearance", valueType = "number" },
		{ name = "Haze", category = "Appearance", valueType = "number" },
	},
	Sky = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "CelestialBodiesShown", category = "Appearance", valueType = "boolean" },
		{ name = "StarCount", category = "Appearance", valueType = "number" },
		{ name = "SkyboxBk", category = "Appearance", valueType = "string" },
		{ name = "SkyboxDn", category = "Appearance", valueType = "string" },
		{ name = "SkyboxFt", category = "Appearance", valueType = "string" },
		{ name = "SkyboxLf", category = "Appearance", valueType = "string" },
		{ name = "SkyboxRt", category = "Appearance", valueType = "string" },
		{ name = "SkyboxUp", category = "Appearance", valueType = "string" },
		{ name = "SunAngularSize", category = "Appearance", valueType = "number" },
		{ name = "MoonAngularSize", category = "Appearance", valueType = "number" },
	},
	ParticleEmitter = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Texture", category = "Appearance", valueType = "string" },
		{ name = "Rate", category = "Appearance", valueType = "number" },
		{ name = "Lifetime", category = "Appearance", valueType = "number" },
		{ name = "Drag", category = "Appearance", valueType = "number" },
		{ name = "LightEmission", category = "Appearance", valueType = "number" },
		{ name = "LightInfluence", category = "Appearance", valueType = "number" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "ZOffset", category = "Appearance", valueType = "number" },
	},
	Beam = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Texture", category = "Appearance", valueType = "string" },
		{ name = "Width0", category = "Appearance", valueType = "number" },
		{ name = "Width1", category = "Appearance", valueType = "number" },
		{ name = "LightEmission", category = "Appearance", valueType = "number" },
		{ name = "LightInfluence", category = "Appearance", valueType = "number" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "Segments", category = "Appearance", valueType = "number" },
		{ name = "TextureSpeed", category = "Appearance", valueType = "number" },
		{ name = "FaceCamera", category = "Appearance", valueType = "boolean" },
	},
	Fire = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Heat", category = "Appearance", valueType = "number" },
		{ name = "Size", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{ name = "SecondaryColor", category = "Appearance", valueType = "Color3" },
	},
	Smoke = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Opacity", category = "Appearance", valueType = "number" },
		{ name = "RiseVelocity", category = "Appearance", valueType = "number" },
		{ name = "Size", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
	},
	Trail = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Lifetime", category = "Appearance", valueType = "number" },
		{ name = "MinLength", category = "Appearance", valueType = "number" },
		{ name = "MaxLength", category = "Appearance", valueType = "number" },
		{ name = "WidthScale", category = "Appearance", valueType = "number" },
		{ name = "LightEmission", category = "Appearance", valueType = "number" },
		{ name = "LightInfluence", category = "Appearance", valueType = "number" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "FaceCamera", category = "Appearance", valueType = "boolean" },
	},
	Decal = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Texture", category = "Appearance", valueType = "string" },
		{ name = "Transparency", category = "Appearance", valueType = "number" },
		{ name = "Color3", category = "Appearance", valueType = "Color3" },
		{ name = "ZIndex", category = "Appearance", valueType = "number" },
	},
	Texture = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Texture", category = "Appearance", valueType = "string" },
		{ name = "Transparency", category = "Appearance", valueType = "number" },
		{ name = "Color3", category = "Appearance", valueType = "Color3" },
		{ name = "StudsPerTileU", category = "Appearance", valueType = "number" },
		{ name = "StudsPerTileV", category = "Appearance", valueType = "number" },
		{ name = "OffsetStudsU", category = "Appearance", valueType = "number" },
		{ name = "OffsetStudsV", category = "Appearance", valueType = "number" },
	},
}

local SCHEMA_EXACT: { [string]: { EngineProp } } = {
	SpawnLocation = {
		{ name = "AllowTeamChangeOnTouch", category = "Spawn", valueType = "boolean", default = false },
		{ name = "Duration", category = "Spawn", valueType = "number", default = 10 },
		{ name = "Enabled", category = "Spawn", valueType = "boolean", default = true },
		{ name = "Neutral", category = "Spawn", valueType = "boolean", default = true },
		{ name = "TeamColor", category = "Spawn", valueType = "BrickColor", defaultKind = "teamColor" },
	},
	Seat = {
		{ name = "Disabled", category = "Behavior", valueType = "boolean", default = false },
		{ name = "Occupant", category = "Data", valueType = "string", default = "None", readonly = true },
	},
	VehicleSeat = {
		{ name = "AreHingesDetected", category = "Data", valueType = "number", default = 0, readonly = true },
		{ name = "Disabled", category = "Behavior", valueType = "boolean", default = false },
		{ name = "HeadsUpDisplay", category = "Behavior", valueType = "boolean", default = true },
		{ name = "MaxSpeed", category = "Control", valueType = "number", default = 25 },
		{ name = "Occupant", category = "Data", valueType = "string", default = "None", readonly = true },
		{ name = "Steer", category = "Control", valueType = "number", default = 0 },
		{ name = "SteerFloat", category = "Control", valueType = "number", default = 0 },
		{ name = "Throttle", category = "Control", valueType = "number", default = 0 },
		{ name = "ThrottleFloat", category = "Control", valueType = "number", default = 0 },
		{ name = "Torque", category = "Control", valueType = "number", default = 10 },
		{ name = "TurnSpeed", category = "Control", valueType = "number", default = 1 },
	},
	MeshPart = {
		{ name = "DoubleSided", category = "Geometry", valueType = "boolean", default = false },
		{ name = "MeshId", category = "Geometry", valueType = "string", default = "", readonly = true },
		{
			name = "RenderFidelity",
			category = "Geometry",
			valueType = "enum",
			default = "Automatic",
			enumType = "RenderFidelity",
			enumItems = { "Automatic", "Precise", "Performance" },
		},
		{ name = "TextureID", category = "Appearance", valueType = "string", default = "" },
	},
	TrussPart = {
		{
			name = "Style",
			category = "Part",
			valueType = "enum",
			default = "AlternatingSupports",
			enumType = "Style",
			enumItems = { "AlternatingSupports", "BridgeStyleSupports", "NoSupports" },
		},
	},
}

-- probe these when class has no curated list
local REFLECT_PROPS: { EngineProp } = {
	{ name = "Name", category = "Data", valueType = "string" },
	{ name = "Enabled", category = "Data", valueType = "boolean" },
	{ name = "Visible", category = "Data", valueType = "boolean" },
	{ name = "Active", category = "Behavior", valueType = "boolean" },
	{ name = "Interactable", category = "Behavior", valueType = "boolean" },
	{ name = "Disabled", category = "Data", valueType = "boolean" },
	{ name = "Archivable", category = "Data", valueType = "boolean" },
	{ name = "Intensity", category = "Appearance", valueType = "number" },
	{ name = "Threshold", category = "Appearance", valueType = "number" },
	{ name = "Brightness", category = "Appearance", valueType = "number" },
	{ name = "Contrast", category = "Appearance", valueType = "number" },
	{ name = "Saturation", category = "Appearance", valueType = "number" },
	{ name = "TintColor", category = "Appearance", valueType = "Color3" },
	{ name = "Color", category = "Appearance", valueType = "Color3" },
	{ name = "Color3", category = "Appearance", valueType = "Color3" },
	{ name = "BackgroundColor3", category = "Appearance", valueType = "Color3" },
	{ name = "BackgroundTransparency", category = "Appearance", valueType = "number" },
	{ name = "BorderColor3", category = "Appearance", valueType = "Color3" },
	{ name = "BorderSizePixel", category = "Appearance", valueType = "number" },
	{ name = "Transparency", category = "Appearance", valueType = "number" },
	{ name = "Shadows", category = "Appearance", valueType = "boolean" },
	{ name = "Range", category = "Appearance", valueType = "number" },
	{ name = "Angle", category = "Appearance", valueType = "number" },
	{ name = "Spread", category = "Appearance", valueType = "number" },
	{ name = "Density", category = "Appearance", valueType = "number" },
	{ name = "Texture", category = "Appearance", valueType = "string" },
	{ name = "SoundId", category = "Audio", valueType = "string" },
	{ name = "Volume", category = "Audio", valueType = "number" },
	{ name = "LayoutOrder", category = "Layout", valueType = "number" },
	{ name = "ZIndex", category = "Layout", valueType = "number" },
}

local SERVICE_NAMES = {
	Workspace = true,
	Players = true,
	Lighting = true,
	MaterialService = true,
	ReplicatedFirst = true,
	ReplicatedStorage = true,
	ServerScriptService = true,
	ServerStorage = true,
	StarterGui = true,
	StarterPack = true,
	StarterPlayer = true,
	Teams = true,
	SoundService = true,
	TextChatService = true,
}

function EnginePropertyCatalog.resolve(className: string, isA, baseline: { EngineProp }?): { EngineProp }
	local rows = {}
	local indexes = {}

	local function merge(layer)
		for _, property in layer or {} do
			local index = indexes[property.name]
			if index then
				local merged = table.clone(rows[index])
				for key, value in property do
					merged[key] = value
				end
				rows[index] = merged
			else
				table.insert(rows, table.clone(property))
				indexes[property.name] = #rows
			end
		end
	end

	merge(baseline)
	merge(BY_CLASS.Instance)
	for _, family in INHERITED_FAMILIES do
		local inherited = if isA then isA(family.className) else family.classes[className] == true
		if inherited then
			merge(family.properties)
		end
	end
	if className ~= "Instance" then
		merge(BY_CLASS[className])
	end
	merge(SCHEMA_EXACT[className])
	return rows
end

function EnginePropertyCatalog.forClass(className: string): { EngineProp }
	return EnginePropertyCatalog.resolve(className, nil, nil)
end

function EnginePropertyCatalog.has(className: string): boolean
	if className == "Instance" or SERVICE_NAMES[className] or BY_CLASS[className] or SCHEMA_EXACT[className] then
		return true
	end
	for _, family in INHERITED_FAMILIES do
		if family.classes[className] then
			return true
		end
	end
	return false
end

function EnginePropertyCatalog.serviceNames(): { string }
	local names = {}
	for className in SERVICE_NAMES do
		table.insert(names, className)
	end
	table.sort(names)
	return names
end

function EnginePropertyCatalog.probeProperties(): { EngineProp }
	return REFLECT_PROPS
end

function EnginePropertyCatalog.materials(): { string }
	return MATERIALS
end

return EnginePropertyCatalog
