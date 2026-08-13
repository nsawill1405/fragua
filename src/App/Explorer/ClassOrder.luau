--Services
local EngineSchemas = if script
	then require(script.Parent.Parent.Types.EngineSchemas)
	else require("../Types/EngineSchemas")

--Constants
local ClassOrder = {}

-- explorer sibling priority: characters read humanoid → parts → clothing → rest
local PRIORITY = {
	"Humanoid",
	"HumanoidDescription",
	"Animator",
	"AnimationController",
	"BodyColors",
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
	"Shirt",
	"Pants",
	"ShirtGraphic",
	"Accessory",
	"Hat",
	"ForceField",
	"Tool",
	"Script",
	"LocalScript",
	"ModuleScript",
	"Folder",
	"Model",
	"Configuration",
	"Sound",
	"Attachment",
	"Bone",
	"Motor6D",
	"WeldConstraint",
	"Weld",
	"SpecialMesh",
	"BlockMesh",
	"CylinderMesh",
	"FileMesh",
	"Decal",
	"Texture",
	"BillboardGui",
	"SurfaceGui",
	"ProximityPrompt",
	"ClickDetector",
	"Highlight",
}

local rankByClass: { [string]: number } = {}
do
	local rank = 1
	for _, className in PRIORITY do
		rankByClass[className] = rank
		rank += 1
	end
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
