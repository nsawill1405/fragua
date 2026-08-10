local PropertyRefreshPolicy = {}

function PropertyRefreshPolicy.action(kind: string, name: string, previousType: string?, nextType: string?): string
	if kind == "attribute" and name == "_FraguaType" then
		return "rebuild"
	end
	if kind == "attribute" and previousType and nextType and previousType ~= nextType then
		return "rebuild"
	end
	return "update"
end

return PropertyRefreshPolicy
