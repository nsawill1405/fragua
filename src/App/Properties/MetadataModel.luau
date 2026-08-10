local MetadataModel = {}
local SUPPORTED_TYPES = {
	string = true,
	number = true,
	boolean = true,
	Color3 = true,
	Vector3 = true,
}

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

function MetadataModel.isSupportedType(valueType: string): boolean
	return SUPPORTED_TYPES[valueType] == true
end

function MetadataModel.modalLayers(overlay: number)
	return {
		overlay = overlay,
		panel = overlay + 1,
		menu = overlay + 10,
	}
end

function MetadataModel.dialogGeometry(hostWidth: number, hostHeight: number, desiredHeight: number, hasDelete: boolean)
	local panelWidth = math.min(math.max(hostWidth - 24, 1), 360)
	local panelHeight = math.min(math.max(hostHeight - 16, 1), desiredHeight)
	local padding = math.min(12, math.floor(panelWidth / 4))
	local gap = math.min(8, math.max(math.floor((panelWidth - padding * 2) / 20), 2))
	local innerWidth = math.max(panelWidth - padding * 2, 1)

	if hasDelete then
		local buttonWidth = math.max(math.floor((innerWidth - gap * 2) / 3), 1)
		return {
			panel = { width = panelWidth, height = panelHeight },
			deleteButton = { x = padding, width = buttonWidth },
			cancelButton = { x = padding + buttonWidth + gap, width = buttonWidth },
			saveButton = { x = padding + (buttonWidth + gap) * 2, width = buttonWidth },
		}
	end

	local buttonWidth = math.min(72, math.max(math.floor((innerWidth - gap) / 2), 1))
	local saveX = panelWidth - padding - buttonWidth
	return {
		panel = { width = panelWidth, height = panelHeight },
		deleteButton = nil,
		cancelButton = { x = saveX - gap - buttonWidth, width = buttonWidth },
		saveButton = { x = saveX, width = buttonWidth },
	}
end

function MetadataModel.isProtectedAttribute(name: string): boolean
	return name == "_FraguaType"
end

function MetadataModel.isProtectedTag(name: string, isFragua: boolean): boolean
	return isFragua and name == "FraguaInstance"
end

return MetadataModel
