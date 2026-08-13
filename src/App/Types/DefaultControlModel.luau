local DefaultControlModel = {}

local COMPOSITE_COMPONENTS = {
	Vector2 = { "X", "Y" },
	Vector3 = { "X", "Y", "Z" },
	UDim = { "Scale", "Offset" },
	UDim2 = { "X Scale", "X Offset", "Y Scale", "Y Offset" },
	CFrame = { "X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22" },
}

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function descriptor(kind: string, height: number, options: { [string]: any }?)
	local result = { kind = kind, height = height }
	if options then
		result.options = options
	end
	return result
end

function DefaultControlModel.describe(prop: any)
	if typeof(prop) ~= "table" then
		return descriptor("text", 22)
	end

	local valueType = prop.valueType
	if typeof(valueType) ~= "string" then
		return descriptor("text", 22)
	end

	if valueType == "boolean" then
		return descriptor("toggle", 22)
	elseif valueType == "enum" then
		local items = if typeof(prop.enumItems) == "table" then table.clone(prop.enumItems) else {}
		return descriptor("enum", 22, { items = items })
	elseif valueType == "number" then
		local hasPositiveFiniteStep = isFiniteNumber(prop.step) and prop.step > 0
		if
			isFiniteNumber(prop.minimum)
			and isFiniteNumber(prop.maximum)
			and prop.minimum < prop.maximum
			and not hasPositiveFiniteStep
		then
			return descriptor("slider", 22, { minimum = prop.minimum, maximum = prop.maximum })
		end
		return descriptor("number", 22)
	elseif valueType == "integer" then
		return descriptor("number", 22)
	elseif valueType == "Color3" or valueType == "BrickColor" then
		return descriptor("color", 22)
	elseif valueType == "Instance" or valueType == "FraguaInstance" then
		local options = {}
		if typeof(prop.referenceType) == "string" then
			options.referenceType = prop.referenceType
		end
		return descriptor("reference", 22, options)
	end

	local components = COMPOSITE_COMPONENTS[valueType]
	if components then
		local height = if valueType == "UDim2" then 72 elseif valueType == "CFrame" then 96 else 48
		local result = descriptor("components", height)
		result.components = table.clone(components)
		return result
	end

	return descriptor("text", 22)
end

return DefaultControlModel
