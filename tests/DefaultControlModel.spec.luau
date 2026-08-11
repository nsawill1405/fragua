local ok, Model = pcall(function()
	return require("../src/App/Types/DefaultControlModel")
end)
local TypeValue = require("../src/App/Types/TypeValue")

return {
	["describes the standard typed defaults"] = function()
		assert(ok and Model, "DefaultControlModel should be available")
		assert(Model.describe({ valueType = "boolean" }).kind == "toggle")
		assert(Model.describe({ valueType = "enum", enumItems = { "A", "B" } }).kind == "enum")
		assert(Model.describe({ valueType = "number", minimum = 0, maximum = 1 }).kind == "slider")
		assert(Model.describe({ valueType = "Vector3" }).components[3] == "Z")
		assert(Model.describe({ valueType = "FraguaInstance", referenceType = "Zombie" }).kind == "reference")
	end,
	["uses fixed heights for compact and composite defaults"] = function()
		assert(ok and Model, "DefaultControlModel should be available")
		assert(Model.describe({ valueType = "boolean" }).height == 22)
		assert(Model.describe({ valueType = "Vector2" }).height == 48)
		assert(Model.describe({ valueType = "UDim2" }).height == 72)
		assert(Model.describe({ valueType = "CFrame" }).height == 96)
	end,
	["only gives finite strictly increasing number bounds a slider"] = function()
		assert(ok and Model, "DefaultControlModel should be available")
		local unbounded = Model.describe({ valueType = "number", minimum = 0 })
		assert(unbounded.kind == "number")
		local infinite = Model.describe({ valueType = "number", minimum = 0, maximum = math.huge })
		assert(infinite.kind == "number")
	end,
	["descending bounds stay numeric and preserve validation semantics"] = function()
		assert(ok and Model, "DefaultControlModel should be available")
		local metadata = { valueType = "number", minimum = 10, maximum = -2 }
		assert(Model.describe(metadata).kind == "number")
		local valid = TypeValue.validate(metadata.valueType, 4, metadata)
		assert(not valid)
	end,
	["equal bounds stay numeric and accept only the declared value"] = function()
		assert(ok and Model, "DefaultControlModel should be available")
		local metadata = { valueType = "number", minimum = 5, maximum = 5 }
		assert(Model.describe(metadata).kind == "number")
		assert(TypeValue.validate(metadata.valueType, 5, metadata))
		assert(not TypeValue.validate(metadata.valueType, 5.5, metadata))
	end,
	["bounded integers stay numeric because fractional values are invalid"] = function()
		assert(ok and Model, "DefaultControlModel should be available")
		local metadata = { valueType = "integer", minimum = 0, maximum = 10 }
		assert(Model.describe(metadata).kind == "number")
		assert(not TypeValue.validate(metadata.valueType, 4.5, metadata))
	end,
	["positive finite steps stay numeric because continuous values are invalid"] = function()
		assert(ok and Model, "DefaultControlModel should be available")
		local metadata = { valueType = "number", minimum = 0, maximum = 10, step = 2 }
		assert(not TypeValue.validate(metadata.valueType, 1, metadata))
		assert(Model.describe(metadata).kind == "number")
	end,
	["unstepped bounded number sliders produce valid fractional values"] = function()
		assert(ok and Model, "DefaultControlModel should be available")
		local metadata = { valueType = "number", minimum = -2, maximum = 10 }
		local control = Model.describe(metadata)
		assert(control.kind == "slider")
		assert(control.options.minimum == -2 and control.options.maximum == 10)
		assert(TypeValue.validate(metadata.valueType, 4.5, metadata))
	end,
	["ignored numeric steps preserve continuous slider validation"] = function()
		assert(ok and Model, "DefaultControlModel should be available")
		for _, step in { 0, -2, math.huge, -math.huge, 0 / 0 } do
			local metadata = { valueType = "number", minimum = 0, maximum = 10, step = step }
			assert(TypeValue.validate(metadata.valueType, 1, metadata))
			assert(Model.describe(metadata).kind == "slider")
		end
	end,
	["falls back safely for absent or unsupported metadata"] = function()
		assert(ok and Model, "DefaultControlModel should be available")
		assert(Model.describe(nil).kind == "text")
		assert(Model.describe({}).kind == "text")
		assert(Model.describe({ valueType = "Unknown" }).kind == "text")
	end,
}
