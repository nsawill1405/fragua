--Services
local EngineSchemas = if script
	then require(script.Parent.Parent.Types.EngineSchemas)
	else require("../Types/EngineSchemas")

--Constants
local ClassOrder = {}

-- explorer sibling priority: scripts first, then full class catalogue order
local PRIORITY = {
	-- scripts / code
	"Script",
	"LocalScript",
	"ModuleScript",
	-- structure
	"Folder",
	"Model",
	"Configuration",
	"WorldModel",
	"Actor",
	"Camera",
	"Terrain",
	"TerrainRegion",
	-- values
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
	-- networking
	"RemoteEvent",
	"RemoteFunction",
	"BindableEvent",
	"BindableFunction",
	"UnreliableRemoteEvent",
	-- humanoid / avatar core
	"Humanoid",
	"HumanoidDescription",
	"Animator",
	"AnimationController",
	"BodyColors",
	-- parts / geometry
	"Part",
	"MeshPart",
	"WedgePart",
	"CornerWedgePart",
	"TrussPart",
	"SpawnLocation",
	"Seat",
	"VehicleSeat",
	"UnionOperation",
	"NegateOperation",
	"IntersectOperation",
	-- clothing under humanoid/parts
	"Shirt",
	"Pants",
	"ShirtGraphic",
	"Accessory",
	"Hat",
	"CharacterMesh",
	"ForceField",
	-- tools / prompts
	"Tool",
	"HopperBin",
	"ProximityPrompt",
	"ClickDetector",
	"DragDetector",
	-- animation assets
	"Animation",
	"KeyframeSequence",
	"Keyframe",
	"Pose",
	"NumberPose",
	-- sound
	"Sound",
	"SoundGroup",
	-- meshes / surface detail
	"SpecialMesh",
	"BlockMesh",
	"CylinderMesh",
	"FileMesh",
	"Decal",
	"Texture",
	"SurfaceAppearance",
	-- attachments / constraints / physics
	"Attachment",
	"Bone",
	"Motor6D",
	"Motor",
	"WeldConstraint",
	"Weld",
	"Snap",
	"ManualWeld",
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
	"PathfindingModifier",
	"PathfindingLink",
	-- lights / fx
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
	"BloomEffect",
	"BlurEffect",
	"ColorCorrectionEffect",
	"DepthOfFieldEffect",
	"SunRaysEffect",
	"Atmosphere",
	"Sky",
	"Clouds",
	-- ui
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
	-- services (rare as siblings, but keep stable)
	"Workspace",
	"Players",
	"Lighting",
	"MaterialService",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"SoundService",
	"TextChatService",
	"Team",
}

local rankByClass: { [string]: number } = {}
do
	local rank = 1
	for _, className in PRIORITY do
		if rankByClass[className] == nil then
			rankByClass[className] = rank
			rank += 1
		end
	end
	-- anything insertable but missing above still gets a stable mid-late rank
	for _, section in EngineSchemas.insertSections() do
		for _, className in section.classes do
			if rankByClass[className] == nil then
				rankByClass[className] = rank
				rank += 1
			end
		end
	end
end

local UNKNOWN_RANK = 100000

--Functions
function ClassOrder.rank(className: string): number
	return rankByClass[className] or UNKNOWN_RANK
end

function ClassOrder.compare(a: Instance, b: Instance): boolean
	local ra = ClassOrder.rank(a.ClassName)
	local rb = ClassOrder.rank(b.ClassName)
	if ra ~= rb then
		return ra < rb
	end
	if a.ClassName ~= b.ClassName then
		return a.ClassName < b.ClassName
	end
	return a.Name:lower() < b.Name:lower()
end

return ClassOrder
