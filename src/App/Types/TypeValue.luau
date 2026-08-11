local TypeValue = {}

local luneAvailable, LuneRoblox = pcall(function()
	return require("@lune/roblox")
end)
local constructors = if luneAvailable then LuneRoblox else nil
local Color3Constructor = if constructors then constructors.Color3 else Color3
local BrickColorConstructor = if constructors then constructors.BrickColor else BrickColor
local Vector2Constructor = if constructors then constructors.Vector2 else Vector2
local Vector3Constructor = if constructors then constructors.Vector3 else Vector3
local UDimConstructor = if constructors then constructors.UDim else UDim
local UDim2Constructor = if constructors then constructors.UDim2 else UDim2
local CFrameConstructor = if constructors then constructors.CFrame else CFrame

local DESCRIPTORS = {
	string = { default = "" },
	number = { default = 0 },
	integer = { default = 0 },
	boolean = { default = false },
	Color3 = { default = Color3Constructor.new(1, 1, 1) },
	BrickColor = { default = BrickColorConstructor.new("Medium stone grey") },
	Vector2 = { default = Vector2Constructor.zero },
	Vector3 = { default = Vector3Constructor.zero },
	UDim = { default = UDimConstructor.new() },
	UDim2 = { default = UDim2Constructor.new() },
	CFrame = { default = CFrameConstructor.identity },
	enum = { default = "" },
	Instance = { default = nil },
	FraguaInstance = { default = nil },
}

local SUPPORTED = {
	"string",
	"number",
	"integer",
	"boolean",
	"Color3",
	"BrickColor",
	"Vector2",
	"Vector3",
	"UDim",
	"UDim2",
	"CFrame",
	"enum",
	"Instance",
	"FraguaInstance",
}

local function validNumber(value: any, metadata: table?): (boolean, string?)
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return false, "Expected a finite number."
	end
	if metadata then
		if metadata.minimum ~= nil and value < metadata.minimum then
			return false, `Value must be at least {metadata.minimum}.`
		end
		if metadata.maximum ~= nil and value > metadata.maximum then
			return false, `Value must be at most {metadata.maximum}.`
		end
		if metadata.step ~= nil and metadata.step > 0 then
			local origin = metadata.minimum or 0
			local steps = (value - origin) / metadata.step
			if math.abs(steps - math.round(steps)) > 1e-9 then
				return false, `Value must use increments of {metadata.step}.`
			end
		end
	end
	return true
end

function TypeValue.supported(): { string }
	return table.clone(SUPPORTED)
end

function TypeValue.default(valueType: string, metadata: table?): any
	local descriptor = assert(DESCRIPTORS[valueType], `Unsupported value type: {valueType}`)
	if valueType == "enum" and metadata and metadata.enumItems then
		return metadata.enumItems[1] or ""
	end
	return descriptor.default
end

function TypeValue.validate(valueType: string, value: any, metadata: table?): (boolean, string?)
	if not DESCRIPTORS[valueType] then
		return false, `Unsupported value type: {valueType}`
	end
	if valueType == "number" then
		return validNumber(value, metadata)
	elseif valueType == "integer" then
		local valid, message = validNumber(value, metadata)
		if not valid then
			return false, message
		end
		if value % 1 ~= 0 then
			return false, "Expected an integer."
		end
		return true
	elseif valueType == "enum" then
		if typeof(value) ~= "string" then
			return false, "Expected an enum item name."
		end
		if metadata and metadata.enumItems and not table.find(metadata.enumItems, value) then
			return false, `"{value}" is not an available enum item.`
		end
		return true
	elseif valueType == "Instance" or valueType == "FraguaInstance" then
		if value == nil or typeof(value) == "Instance" then
			return true
		end
		return false, "Expected an Instance reference."
	end

	if typeof(value) ~= valueType then
		return false, `Expected a {valueType} value.`
	end
	return true
end

function TypeValue.serialize(value: any): any
	local valueType = typeof(value)
	if valueType == "Color3" then
		return { __typeof = "Color3", R = value.R, G = value.G, B = value.B }
	elseif valueType == "BrickColor" then
		return { __typeof = "BrickColor", Name = value.Name }
	elseif valueType == "Vector2" then
		return { __typeof = "Vector2", X = value.X, Y = value.Y }
	elseif valueType == "Vector3" then
		return { __typeof = "Vector3", X = value.X, Y = value.Y, Z = value.Z }
	elseif valueType == "UDim" then
		return { __typeof = "UDim", Scale = value.Scale, Offset = value.Offset }
	elseif valueType == "UDim2" then
		return {
			__typeof = "UDim2",
			XScale = value.X.Scale,
			XOffset = value.X.Offset,
			YScale = value.Y.Scale,
			YOffset = value.Y.Offset,
		}
	elseif valueType == "CFrame" then
		return { __typeof = "CFrame", components = { value:GetComponents() } }
	elseif valueType == "table" then
		local serialized = {}
		for key, item in value do
			serialized[key] = TypeValue.serialize(item)
		end
		return serialized
	end
	return value
end

function TypeValue.deserialize(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	if value.__typeof == "Color3" then
		return Color3Constructor.new(value.R, value.G, value.B)
	elseif value.__typeof == "BrickColor" then
		return BrickColorConstructor.new(value.Name)
	elseif value.__typeof == "Vector2" then
		return Vector2Constructor.new(value.X, value.Y)
	elseif value.__typeof == "Vector3" then
		return Vector3Constructor.new(value.X, value.Y, value.Z)
	elseif value.__typeof == "UDim" then
		return UDimConstructor.new(value.Scale, value.Offset)
	elseif value.__typeof == "UDim2" then
		return UDim2Constructor.new(value.XScale, value.XOffset, value.YScale, value.YOffset)
	elseif value.__typeof == "CFrame" then
		return CFrameConstructor.new(table.unpack(value.components))
	end

	local deserialized = {}
	for key, item in value do
		deserialized[key] = TypeValue.deserialize(item)
	end
	return deserialized
end

return TypeValue
