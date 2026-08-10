local PropertyRefreshPolicy = {}

function PropertyRefreshPolicy.action(kind: string, name: string): string
	if kind == "attribute" and name == "_FraguaType" then
		return "rebuild"
	end
	return "update"
end

return PropertyRefreshPolicy
