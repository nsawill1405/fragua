local ok, Policy = pcall(function()
	return require("../src/App/Types/BehaviorTemplatePolicy")
end)

return {
	["custom source wins over generated duplicate"] = function()
		assert(ok and Policy, "BehaviorTemplatePolicy should be available")
		local plan = Policy.plan({ "generated", "custom" }, "generated")
		assert(plan.keep == 2)
		assert(#plan.discard == 1 and plan.discard[1] == 1)
		assert(#plan.backup == 0)
	end,
	["distinct custom duplicates are preserved as backups"] = function()
		assert(ok and Policy, "BehaviorTemplatePolicy should be available")
		local plan = Policy.plan({ "custom one", "custom two" }, "generated")
		assert(plan.keep == 1)
		assert(#plan.backup == 1 and plan.backup[1] == 2)
		assert(#plan.discard == 0)
	end,
	["identical custom duplicates do not need backups"] = function()
		assert(ok and Policy, "BehaviorTemplatePolicy should be available")
		local plan = Policy.plan({ "custom", "custom" }, "generated")
		assert(plan.keep == 1)
		assert(#plan.discard == 1 and #plan.backup == 0)
	end,
}
