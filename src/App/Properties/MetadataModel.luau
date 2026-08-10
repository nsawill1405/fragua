local MetadataModel = {}

function MetadataModel.normalizeName(name: string): string
	return string.gsub(name, "^%s*(.-)%s*$", "%1")
end

function MetadataModel.validateAttributeName(
	name: string,
	existing: { [string]: boolean },
	previous: string?
): (boolean, string?)
	local normalized = MetadataModel.normalizeName(name)
	if normalized == "" then
		return false, "Attribute name is required."
	end
	if existing[normalized] and normalized ~= previous then
		return false, "An attribute with that name already exists."
	end
	return true, nil
end

function MetadataModel.defaultFor(valueType: string, constructors: any?): any
	local color3 = if constructors then constructors.Color3 else Color3
	local vector3 = if constructors then constructors.Vector3 else Vector3
	if valueType == "string" then
		return ""
	elseif valueType == "number" then
		return 0
	elseif valueType == "boolean" then
		return false
	elseif valueType == "Color3" then
		return color3.new(1, 1, 1)
	elseif valueType == "Vector3" then
		return vector3.zero
	end
	return nil
end

function MetadataModel.isProtectedAttribute(name: string): boolean
	return name == "_FraguaType"
end

function MetadataModel.isProtectedTag(name: string, isFragua: boolean): boolean
	return isFragua and name == "FraguaInstance"
end

return MetadataModel
