local EnginePropertyCatalog = if script
	then require(script.Parent.EnginePropertyCatalog)
	else require("./EnginePropertyCatalog")

local EngineClassSchemas = {}

local function materializeDefault(property)
	local copy = table.clone(property)
	if property.defaultKind == "partColor" and Color3 then
		copy.default = Color3.fromRGB(163, 162, 165)
	elseif property.defaultKind == "partSize" and Vector3 then
		copy.default = Vector3.new(4, 1, 2)
	elseif property.defaultKind == "vectorZero" and Vector3 then
		copy.default = Vector3.zero
	elseif property.defaultKind == "teamColor" and BrickColor then
		copy.default = BrickColor.new("Medium stone grey")
	end
	copy.defaultKind = nil
	return copy
end

function EngineClassSchemas.forClass(className: string)
	local rows = {}
	for _, property in EnginePropertyCatalog.forClass(className) do
		table.insert(rows, materializeDefault(property))
	end
	return rows
end

function EngineClassSchemas.has(className: string): boolean
	return EnginePropertyCatalog.has(className)
end

function EngineClassSchemas.classNames(): { string }
	return EnginePropertyCatalog.classNames()
end

function EngineClassSchemas.materials(): { string }
	return EnginePropertyCatalog.materials()
end

return EngineClassSchemas
