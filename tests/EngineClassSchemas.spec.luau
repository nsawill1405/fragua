local ok, Schemas = pcall(function()
	return require("../src/App/Types/EngineClassSchemas")
end)
local Catalog = require("../src/App/Types/EnginePropertyCatalog")

local function byName(rows)
	local result = {}
	for _, row in rows do
		result[row.name] = row
	end
	return result
end

return {
	["every curated service inherits Instance identity and archive rows"] = function()
		local services = {
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
		}
		for _, className in services do
			local rows = byName(Schemas.forClass(className))
			assert(rows.Name and rows.Name.readonly ~= true, `{className} should inherit writable Name`)
			assert(rows.ClassName and rows.ClassName.readonly == true, `{className} should inherit read-only ClassName`)
			assert(rows.Archivable and rows.Archivable.readonly ~= true, `{className} should inherit Archivable`)
		end

		for className, propertyName in
			{
				Workspace = "Gravity",
				Players = "RespawnTime",
				Lighting = "Ambient",
				StarterGui = "ScreenOrientation",
				SoundService = "AmbientReverb",
			}
		do
			assert(byName(Schemas.forClass(className))[propertyName], `{className} should retain {propertyName}`)
		end
	end,
	["StarterPlayer exposes current scriptable settings with enum families"] = function()
		local rows = byName(Schemas.forClass("StarterPlayer"))
		for _, name in
			{
				"CameraMaxZoomDistance",
				"CameraMinZoomDistance",
				"CharacterWalkSpeed",
				"CharacterJumpPower",
				"CharacterUseJumpPower",
				"EnableMouseLockOption",
				"HealthDisplayDistance",
				"NameDisplayDistance",
				"LoadCharacterAppearance",
			}
		do
			assert(rows[name], `StarterPlayer should expose {name}`)
		end
		assert(rows.CameraMode and rows.CameraMode.enumType == "CameraMode")
		assert(rows.DevComputerMovementMode and rows.DevComputerMovementMode.enumType == "DevComputerMovementMode")
		assert(rows.DevTouchMovementMode and rows.DevTouchMovementMode.enumType == "DevTouchMovementMode")
	end,
	["Teams and Team remain distinct while sharing Instance rows"] = function()
		local teams = byName(Schemas.forClass("Teams"))
		assert(teams.Name and teams.ClassName and teams.Archivable)
		assert(not teams.AutoAssignable and not teams.TeamColor)

		local team = byName(Schemas.forClass("Team"))
		assert(team.Name and team.ClassName and team.Archivable)
		assert(team.AutoAssignable and team.AutoAssignable.valueType == "boolean")
		assert(team.TeamColor and team.TeamColor.valueType == "BrickColor")
	end,
	["custom inheritance schemas consume the Properties dock catalog"] = function()
		for _, className in { "StarterPlayer", "Team" } do
			local catalogRows = byName(Catalog.forClass(className))
			local schemaRows = byName(Schemas.forClass(className))
			for name, catalogRow in catalogRows do
				local schemaRow = schemaRows[name]
				assert(schemaRow, `{className}.{name} should reach custom inheritance schemas`)
				assert(schemaRow.valueType == catalogRow.valueType)
				assert(schemaRow.enumType == catalogRow.enumType)
				assert(schemaRow.readonly == catalogRow.readonly)
			end
		end
	end,
	["VehicleSeat exposes vehicle and inherited BasePart properties"] = function()
		assert(ok and Schemas, "EngineClassSchemas should be available")
		local rows = byName(Schemas.forClass("VehicleSeat"))
		assert(rows.Anchored and rows.Transparency and rows.CollisionGroup)
		assert(rows.Disabled and rows.HeadsUpDisplay and rows.MaxSpeed)
		assert(rows.Torque and rows.TurnSpeed and rows.SteerFloat and rows.ThrottleFloat)
		assert(rows.Steer.readonly ~= true and rows.Throttle.readonly ~= true)
		assert(rows.AreHingesDetected.readonly == true)
		assert(rows.Occupant.readonly == true)
	end,
	["Seat and SpawnLocation retain inherited BasePart controls"] = function()
		assert(ok and Schemas, "EngineClassSchemas should be available")
		local seat = byName(Schemas.forClass("Seat"))
		local spawn = byName(Schemas.forClass("SpawnLocation"))
		assert(seat.Disabled and seat.Occupant and seat.Transparency)
		assert(seat.Shape and spawn.Shape)
		assert(spawn.Anchored and spawn.CanCollide and spawn.Transparency and spawn.Material)
		assert(spawn.AllowTeamChangeOnTouch and spawn.Duration and spawn.Enabled and spawn.Neutral and spawn.TeamColor)
	end,
	["mesh and solid-operation subclasses expose their own geometry controls"] = function()
		assert(ok and Schemas, "EngineClassSchemas should be available")
		local mesh = byName(Schemas.forClass("MeshPart"))
		assert(mesh.CollisionFidelity and mesh.FluidFidelity and mesh.MeshSize.readonly == true)
		assert(mesh.DoubleSided and mesh.MeshId and mesh.RenderFidelity and mesh.TextureID)
		for _, className in { "NegateOperation", "UnionOperation", "IntersectOperation" } do
			local operation = byName(Schemas.forClass(className))
			assert(operation.CollisionFidelity and operation.FluidFidelity)
			assert(operation.RenderFidelity and operation.SmoothingAngle and operation.UsePartColor)
			assert(operation.TriangleCount.readonly == true)
		end
	end,
	["part and truss subclasses retain their own shape controls"] = function()
		assert(ok and Schemas, "EngineClassSchemas should be available")
		local part = byName(Schemas.forClass("Part"))
		local truss = byName(Schemas.forClass("TrussPart"))
		assert(part.Anchored and part.Anchored.default == false)
		assert(part.Shape and part.Shape.enumType == "PartType" and part.Shape.default == "Block")
		assert(truss.Style and truss.Style.enumType == "Style")
		assert(table.find(truss.Style.enumItems, "BridgeStyleSupports"))
		assert(not table.find(truss.Style.enumItems, "BridgeStyle"))
		local mesh = byName(Schemas.forClass("MeshPart"))
		assert(not table.find(mesh.CollisionFidelity.enumItems, "Scalable"))
	end,
}
