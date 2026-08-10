local SchemaMigration = require("../src/App/Types/SchemaMigration")

local function prop(name, valueType, default)
	return { name = name, valueType = valueType, default = default }
end

return {
	["plans added and removed properties deterministically"] = function()
		local plan = SchemaMigration.plan(
			{ properties = { prop("Old", "string", "") } },
			{ properties = { prop("Health", "number", 100) } }
		)
		assert(plan.add[1].name == "Health")
		assert(plan.remove[1] == "Old")
	end,
	["retains values for one same-type rename"] = function()
		local plan = SchemaMigration.plan(
			{ properties = { prop("Range", "number", 20) } },
			{ properties = { prop("DetectRange", "number", 40) } }
		)
		assert(plan.rename[1].from == "Range")
		assert(plan.rename[1].to == "DetectRange")
		assert(#plan.add == 0 and #plan.remove == 0)
	end,
	["warns when a property changes type"] = function()
		local plan = SchemaMigration.plan(
			{ properties = { prop("Health", "number", 100) } },
			{ properties = { prop("Health", "string", "100") } }
		)
		assert(plan.warnings[1].code == "property-type-change")
	end,
}
