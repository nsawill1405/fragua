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

return BehaviorTemplatePolicy
