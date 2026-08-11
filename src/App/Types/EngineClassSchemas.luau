local EngineClassSchemas = {}

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

local BASE_PART_CLASSES = {
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
}

local BASE_PART = {
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
		enumItems = MATERIALS,
		enumType = "Material",
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

local TRIANGLE_MESH = {
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

local PART_OPERATION = {
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

local TRIANGLE_MESH_CLASSES = {
	MeshPart = true,
	NegateOperation = true,
	UnionOperation = true,
	IntersectOperation = true,
}

local PART_OPERATION_CLASSES = {
	NegateOperation = true,
	UnionOperation = true,
	IntersectOperation = true,
}

local PART_DERIVED_CLASSES = {
	Part = true,
	Seat = true,
	SpawnLocation = true,
}

local PART_DERIVED = {
	{
		name = "Shape",
		category = "Part",
		valueType = "enum",
		default = "Block",
		enumType = "PartType",
		enumItems = { "Ball", "Block", "Cylinder", "Wedge", "CornerWedge" },
	},
}

local EXACT = {
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

function EngineClassSchemas.forClass(className: string)
	local rows = {}
	local function copyProperty(property)
		local copy = table.clone(property)
		if property.defaultKind == "partColor" and Color3 then
			copy.default = Color3.fromRGB(163, 162, 165)
		elseif property.defaultKind == "partSize" and Vector3 then
			copy.default = Vector3.new(4, 1, 2)
		elseif property.defaultKind == "vectorZero" and Vector3 then
			copy.default = Vector3.zero
		elseif property.defaultKind == "teamColor" and BrickColor then
			copy.default = BrickColor.new("Medium stone grey")
		end
		copy.defaultKind = nil
		return copy
	end
	if BASE_PART_CLASSES[className] then
		for _, property in BASE_PART do
			table.insert(rows, copyProperty(property))
		end
	end
	if PART_DERIVED_CLASSES[className] then
		for _, property in PART_DERIVED do
			table.insert(rows, copyProperty(property))
		end
	end
	if TRIANGLE_MESH_CLASSES[className] then
		for _, property in TRIANGLE_MESH do
			table.insert(rows, copyProperty(property))
		end
	end
	if PART_OPERATION_CLASSES[className] then
		for _, property in PART_OPERATION do
			table.insert(rows, copyProperty(property))
		end
	end
	for _, property in EXACT[className] or {} do
		table.insert(rows, copyProperty(property))
	end
	return rows
end

function EngineClassSchemas.has(className: string): boolean
	return BASE_PART_CLASSES[className] == true or EXACT[className] ~= nil
end

function EngineClassSchemas.materials(): { string }
	return MATERIALS
end

return EngineClassSchemas
