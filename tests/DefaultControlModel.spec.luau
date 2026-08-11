local ok, Model = pcall(function()
	return require("../src/App/Types/DefaultControlModel")
end)

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
	["only gives finite bounded numbers a slider with ordered bounds"] = function()
		assert(ok and Model, "DefaultControlModel should be available")
		local unbounded = Model.describe({ valueType = "number", minimum = 0 })
		assert(unbounded.kind == "number")
		local infinite = Model.describe({ valueType = "number", minimum = 0, maximum = math.huge })
		assert(infinite.kind == "number")
		local bounded = Model.describe({ valueType = "number", minimum = 10, maximum = -2 })
		assert(bounded.kind == "slider")
		assert(bounded.options.minimum == -2 and bounded.options.maximum == 10)
	end,
	["falls back safely for absent or unsupported metadata"] = function()
		assert(ok and Model, "DefaultControlModel should be available")
		assert(Model.describe(nil).kind == "text")
		assert(Model.describe({}).kind == "text")
		assert(Model.describe({ valueType = "Unknown" }).kind == "text")
	end,
}
