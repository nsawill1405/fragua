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
	["backup folder naming never replaces a colliding object"] = function()
		assert(ok and Policy, "BehaviorTemplatePolicy should be available")
		assert(Policy.backupFolderName, "backupFolderName should be available")
		assert(Policy.backupFolderName({ BehaviorBackups = "ModuleScript" }) == "BehaviorBackups_Fragua")
		assert(
			Policy.backupFolderName({ BehaviorBackups = "ModuleScript", BehaviorBackups_Fragua = "Folder" })
				== "BehaviorBackups_Fragua2"
		)
		assert(Policy.backupFolderName({ BehaviorBackups = "Folder" }) == "BehaviorBackups")
	end,
	["clean hierarchy uses the canonical backup folder name"] = function()
		assert(ok and Policy, "BehaviorTemplatePolicy should be available")
		assert(Policy.backupFolderName, "backupFolderName should be available")
		assert(Policy.backupFolderName({}) == "BehaviorBackups")
	end,
}
