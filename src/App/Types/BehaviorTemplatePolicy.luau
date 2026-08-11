local BehaviorTemplatePolicy = {}

function BehaviorTemplatePolicy.plan(sources: { string }, generatedSource: string)
	local keep = 1
	for index, source in sources do
		if source ~= generatedSource then
			keep = index
			break
		end
	end

	local discard = {}
	local backup = {}
	local keepSource = sources[keep]
	for index, source in sources do
		if index ~= keep then
			if source == keepSource or source == generatedSource then
				table.insert(discard, index)
			else
				table.insert(backup, index)
			end
		end
	end

	return {
		keep = keep,
		discard = discard,
		backup = backup,
	}
end

function BehaviorTemplatePolicy.backupFolderName(existing: { [string]: string }): string
	if existing.BehaviorBackups == nil or existing.BehaviorBackups == "Folder" then
		return "BehaviorBackups"
	end
	local base = "BehaviorBackups_Fragua"
	local candidate = base
	local suffix = 1
	while existing[candidate] do
		suffix += 1
		candidate = base .. tostring(suffix)
	end
	return candidate
end

function BehaviorTemplatePolicy.backupName(existing: { [string]: any }, typeId: string): string
	local base = typeId .. "BehaviorBackup"
	local suffix = 1
	local candidate = base .. tostring(suffix)
	while existing[candidate] do
		suffix += 1
		candidate = base .. tostring(suffix)
	end
	return candidate
end

function BehaviorTemplatePolicy.legacyMigrationPlan(
	legacySource: string,
	existingSources: { [string]: string },
	serverSource: string,
	clientSource: string
)
	local sources = {
		Edit = legacySource,
		Server = serverSource,
		Client = clientSource,
	}
	local backup = {}
	local discard = {}
	for _, side in { "Edit", "Server", "Client" } do
		local existing = existingSources[side]
		if existing ~= nil then
			if existing == sources[side] then
				table.insert(discard, side)
			else
				table.insert(backup, side)
			end
		end
	end
	return {
		sources = sources,
		backup = backup,
		discard = discard,
	}
end

return BehaviorTemplatePolicy
