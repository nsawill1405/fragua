local SchemaResolver = require("../src/App/Types/SchemaResolver")

local definitions = {
	Base = {
		id = "Base",
		extends = "Configuration",
		properties = { { name = "Health", valueType = "number", default = 100, category = "Data" } },
	},
	Child = {
		id = "Child",
		extends = "Base",
		properties = {
			{ name = "Health", valueType = "number", default = 150, category = "Data" },
			{ name = "Speed", valueType = "number", default = 8, category = "Data" },
		},
	},
}

local function resolve(definition)
	return SchemaResolver.resolve(definition, function(id)
		return definitions[id]
	end, function()
		return {}
	end)
end

return {
	["child overrides replace inherited properties in place"] = function()
		local result = resolve(definitions.Child)
		assert(#result == 2)
		assert(result[1].name == "Health" and result[1].default == 150 and result[1].origin == "Child")
		assert(result[1].inherited == false)
		assert(result[2].name == "Speed")
	end,
	["three-level inheritance retains origin metadata"] = function()
		definitions.Grandchild = { id = "Grandchild", extends = "Child", properties = {} }
		local result = resolve(definitions.Grandchild)
		assert(result[1].origin == "Child" and result[1].inherited == true)
		assert(result[2].origin == "Child" and result[2].inherited == true)
	end,
	["active inheritance cycles return a structured error"] = function()
		definitions.A = { id = "A", extends = "B", properties = {} }
		definitions.B = { id = "B", extends = "A", properties = {} }
		local result, err = resolve(definitions.A)
		assert(#result == 0)
		assert(err.code == "inheritance-cycle")
	end,
}
