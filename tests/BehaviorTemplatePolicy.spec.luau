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
	["legacy source backup naming never overwrites an existing backup"] = function()
		assert(ok and Policy, "BehaviorTemplatePolicy should be available")
		assert(Policy.backupName, "backupName should be available")
		assert(Policy.backupName({}, "Zombie") == "ZombieBehaviorBackup1")
		assert(
			Policy.backupName({ ZombieBehaviorBackup1 = true, ZombieBehaviorBackup2 = true }, "Zombie")
				== "ZombieBehaviorBackup3"
		)
	end,
	["legacy winner replaces every pre-existing sided collision"] = function()
		assert(ok and Policy, "BehaviorTemplatePolicy should be available")
		assert(Policy.legacyMigrationPlan, "legacyMigrationPlan should be available")
		local plan = Policy.legacyMigrationPlan(
			"legacy winner",
			{ Edit = "existing edit", Server = "existing server", Client = "existing client" },
			"server forwarder",
			"client skeleton"
		)
		assert(plan.sources.Edit == "legacy winner")
		assert(plan.sources.Server == "server forwarder")
		assert(plan.sources.Client == "client skeleton")
		assert(#plan.backup == 3)
		assert(plan.backup[1] == "Edit")
		assert(plan.backup[2] == "Server")
		assert(plan.backup[3] == "Client")
		assert(#plan.discard == 0)
	end,
}
