local ok, Schemas = pcall(function()
	return require("../src/App/Types/EngineClassSchemas")
end)

local function byName(rows)
	local result = {}
	for _, row in rows do
		result[row.name] = row
	end
	return result
end

return {
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
		assert(part.Shape and part.Shape.enumType == "PartType")
		assert(truss.Style and truss.Style.enumType == "Style")
		assert(table.find(truss.Style.enumItems, "BridgeStyleSupports"))
		assert(not table.find(truss.Style.enumItems, "BridgeStyle"))
		local mesh = byName(Schemas.forClass("MeshPart"))
		assert(not table.find(mesh.CollisionFidelity.enumItems, "Scalable"))
	end,
}
