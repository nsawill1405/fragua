local InsertFlow = {}

function InsertFlow.resolveParent(candidate, workspace)
	if candidate == workspace then
		return workspace
	end
	if candidate and candidate.Parent ~= nil then
		return candidate
	end
	return workspace
end

return InsertFlow
