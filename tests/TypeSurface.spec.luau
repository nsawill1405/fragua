local ok, TypeSurface = pcall(function()
	return require("../src/App/Runtime/TypeSurface")
end)

local function requireTypeSurface()
	assert(ok and TypeSurface, "TypeSurface should be available")
	return TypeSurface
end

local function fixture()
	local definitions = {
		{ id = "Zombie", name = "Zombie", extends = "Enemy" },
		{ id = "Enemy", name = "Enemy", extends = "Part" },
	}
	local schemas = {
		Enemy = {
			{ name = "Name", valueType = "string", origin = "Part", inherited = true },
			{ name = "Target", valueType = "Instance", origin = "Enemy" },
		},
		Zombie = {
			{ name = "Transparency", valueType = "number", origin = "Part", inherited = true },
			{ name = "Health", valueType = "integer", origin = "Enemy", inherited = true },
			{ name = "Mood", valueType = "enum", enumType = "HumanoidStateType", origin = "Zombie" },
			{ name = "Leader", valueType = "FraguaInstance", referenceType = "Enemy", origin = "Zombie" },
			{ name = "Health", valueType = "number", origin = "Zombie" },
		},
	}
	local behaviorSources = {
		["Zombie:Server"] = [[
function Behavior.Attack(instance: Instance, target: Instance, damage: number): boolean
	return true
end
]],
		["Zombie:Client"] = [[
function Behavior.PlayEffect(instance: Instance, color: Color3): ()
end
]],
	}
	return requireTypeSurface().build(definitions, function(definition)
		return schemas[definition.id]
	end, function(typeId)
		return if typeId == "Enemy" then "Part" else "Part"
	end, function(typeId, side)
		return behaviorSources[typeId .. ":" .. side]
	end)
end

return {
	["builds a deterministic resolved surface"] = function()
		local surface = fixture()
		assert(#surface.types == 2)
		assert(surface.types[1].id == "Enemy" and surface.types[2].id == "Zombie")
		local zombie = surface.types[2]
		assert(zombie.backingClass == "Part")
		assert(zombie.serverMethods[1].name == "Attack")
		assert(zombie.clientMethods[1].name == "PlayEffect")
		for index = 2, #zombie.properties do
			assert(zombie.properties[index - 1].name < zombie.properties[index].name)
		end
	end,
	["maps property types and keeps resolved property names unique"] = function()
		local zombie = fixture().types[2]
		local propertyByName = {}
		for _, property in zombie.properties do
			assert(propertyByName[property.name] == nil, `duplicate property {property.name}`)
			propertyByName[property.name] = property
		end
		assert(propertyByName.Health.typeName == "number")
		assert(propertyByName.Mood.typeName == "EnumItem")
		assert(propertyByName.Target == nil)
		assert(propertyByName.Leader.typeName == "Enemy")
		assert(propertyByName.Transparency.typeName == "number")
	end,
	["sorts side methods by name"] = function()
		local surface = requireTypeSurface().build({ { id = "Zombie" } }, function()
			return {}
		end, function()
			return "Part"
		end, function(_, side)
			if side == "Server" then
				return [[
function Behavior.Zap(instance: Instance): () end
function Behavior.Attack(instance: Instance): () end
]]
			end
			return nil
		end)
		assert(surface.types[1].serverMethods[1].name == "Attack")
		assert(surface.types[1].serverMethods[2].name == "Zap")
	end,
	["omits behavior methods that collide with backing members"] = function()
		local surface = requireTypeSurface().build({ { id = "Zombie" } }, function()
			return {}
		end, function()
			return "Part"
		end, function(_, side)
			if side == "Server" then
				return [[
function Behavior.ApplyImpulse(instance: Instance, force: Vector3): () end
function Behavior.Attack(instance: Instance): () end
]]
			end
			return nil
		end, function(_, memberName)
			return memberName == "ApplyImpulse"
		end)
		assert(#surface.types[1].serverMethods == 1)
		assert(surface.types[1].serverMethods[1].name == "Attack")
	end,
}
