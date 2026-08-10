-- Curated readable/writable engine properties with categories + enum metadata.

export type EngineProp = {
	name: string,
	category: string,
	valueType: string?, -- string | number | boolean | Color3 | Vector3 | enum
	readonly: boolean?,
	enumItems: { string }?,
	enumType: string?, -- Enum family name, e.g. "Material"
}

local EngineProps = {}

local MATERIALS = require(script.Parent.Parent.Types.EngineSchemas).materials()

local BY_CLASS: { [string]: { EngineProp } } = {
	Instance = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "ClassName", category = "Data", valueType = "string", readonly = true },
		{ name = "Archivable", category = "Data", valueType = "boolean" },
	},
	Workspace = {
		{ name = "Name", category = "Data", valueType = "string", readonly = true },
		{ name = "ClassName", category = "Data", valueType = "string", readonly = true },
		{ name = "Gravity", category = "World", valueType = "number" },
		{ name = "FallenPartsDestroyHeight", category = "World", valueType = "number" },
		{ name = "AllowThirdPartySales", category = "Behavior", valueType = "boolean" },
		{ name = "StreamingEnabled", category = "Streaming", valueType = "boolean" },
	},
	Lighting = {
		{ name = "Name", category = "Data", valueType = "string", readonly = true },
		{ name = "ClassName", category = "Data", valueType = "string", readonly = true },
		{ name = "Ambient", category = "Appearance", valueType = "Color3" },
		{ name = "OutdoorAmbient", category = "Appearance", valueType = "Color3" },
		{ name = "ColorShift_Top", category = "Appearance", valueType = "Color3" },
		{ name = "ColorShift_Bottom", category = "Appearance", valueType = "Color3" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "ClockTime", category = "Celestial", valueType = "number" },
		{ name = "GeographicLatitude", category = "Celestial", valueType = "number" },
		{ name = "GlobalShadows", category = "Appearance", valueType = "boolean" },
		{ name = "FogColor", category = "Fog", valueType = "Color3" },
		{ name = "FogStart", category = "Fog", valueType = "number" },
		{ name = "FogEnd", category = "Fog", valueType = "number" },
	},
	Players = {
		{ name = "Name", category = "Data", valueType = "string", readonly = true },
		{ name = "ClassName", category = "Data", valueType = "string", readonly = true },
		{ name = "CharacterAutoLoads", category = "Behavior", valueType = "boolean" },
		{ name = "RespawnTime", category = "Behavior", valueType = "number" },
	},
	SoundService = {
		{ name = "Name", category = "Data", valueType = "string", readonly = true },
		{ name = "ClassName", category = "Data", valueType = "string", readonly = true },
		{ name = "AmbientReverb", category = "Audio", valueType = "enum", enumType = "ReverbType" },
		{ name = "DistanceFactor", category = "Audio", valueType = "number" },
		{ name = "DopplerScale", category = "Audio", valueType = "number" },
		{ name = "RolloffScale", category = "Audio", valueType = "number" },
	},
	StarterGui = {
		{ name = "Name", category = "Data", valueType = "string", readonly = true },
		{ name = "ClassName", category = "Data", valueType = "string", readonly = true },
		{ name = "ResetPlayerGuiOnSpawn", category = "Behavior", valueType = "boolean" },
		{ name = "ScreenOrientation", category = "Behavior", valueType = "enum", enumType = "ScreenOrientation" },
	},
	Part = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Anchored", category = "Behavior", valueType = "boolean" },
		{ name = "CanCollide", category = "Behavior", valueType = "boolean" },
		{ name = "CanQuery", category = "Behavior", valueType = "boolean" },
		{ name = "CanTouch", category = "Behavior", valueType = "boolean" },
		{ name = "CastShadow", category = "Appearance", valueType = "boolean" },
		{ name = "Transparency", category = "Appearance", valueType = "number" },
		{ name = "Reflectance", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{
			name = "Material",
			category = "Appearance",
			valueType = "enum",
			enumType = "Material",
			enumItems = MATERIALS,
		},
		{
			name = "Shape",
			category = "Part",
			valueType = "enum",
			enumType = "PartType",
			enumItems = {
				"Ball",
				"Block",
				"Cylinder",
				"Wedge",
				"CornerWedge",
			},
		},
		{ name = "Size", category = "Transform", valueType = "Vector3" },
		{ name = "Position", category = "Transform", valueType = "Vector3" },
		{ name = "Orientation", category = "Transform", valueType = "Vector3" },
	},
	MeshPart = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Anchored", category = "Behavior", valueType = "boolean" },
		{ name = "CanCollide", category = "Behavior", valueType = "boolean" },
		{ name = "Transparency", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{
			name = "Material",
			category = "Appearance",
			valueType = "enum",
			enumType = "Material",
			enumItems = MATERIALS,
		},
		{ name = "Size", category = "Transform", valueType = "Vector3" },
		{ name = "Position", category = "Transform", valueType = "Vector3" },
	},
	SpawnLocation = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Behavior", valueType = "boolean" },
		{ name = "Duration", category = "Behavior", valueType = "number" },
		{ name = "Neutral", category = "Behavior", valueType = "boolean" },
		{ name = "Anchored", category = "Behavior", valueType = "boolean" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{ name = "Size", category = "Transform", valueType = "Vector3" },
		{ name = "Position", category = "Transform", valueType = "Vector3" },
	},
	Model = {
		{ name = "Name", category = "Data", valueType = "string" },
	},
	Humanoid = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Health", category = "Health", valueType = "number" },
		{ name = "MaxHealth", category = "Health", valueType = "number" },
		{ name = "WalkSpeed", category = "Control", valueType = "number" },
		{ name = "JumpPower", category = "Control", valueType = "number" },
		{ name = "JumpHeight", category = "Control", valueType = "number" },
		{ name = "HipHeight", category = "Control", valueType = "number" },
		{ name = "AutoRotate", category = "Control", valueType = "boolean" },
		{ name = "DisplayName", category = "Display", valueType = "string" },
		{ name = "NameDisplayDistance", category = "Display", valueType = "number" },
		{ name = "HealthDisplayDistance", category = "Display", valueType = "number" },
	},
	Script = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Disabled", category = "Data", valueType = "boolean" },
		{
			name = "RunContext",
			category = "Data",
			valueType = "enum",
			enumType = "RunContext",
			enumItems = {
				"Legacy",
				"Server",
				"Client",
				"Plugin",
			},
		},
	},
	LocalScript = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Disabled", category = "Data", valueType = "boolean" },
	},
	ModuleScript = {
		{ name = "Name", category = "Data", valueType = "string" },
	},
	Folder = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Archivable", category = "Data", valueType = "boolean" },
	},
	Configuration = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Archivable", category = "Data", valueType = "boolean" },
	},
	Sound = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "SoundId", category = "Data", valueType = "string" },
		{ name = "Volume", category = "Audio", valueType = "number" },
		{ name = "PlaybackSpeed", category = "Audio", valueType = "number" },
		{ name = "Looped", category = "Audio", valueType = "boolean" },
		{ name = "Playing", category = "Audio", valueType = "boolean" },
	},
	PointLight = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{ name = "Range", category = "Appearance", valueType = "number" },
	},
	SpotLight = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{ name = "Range", category = "Appearance", valueType = "number" },
		{ name = "Angle", category = "Appearance", valueType = "number" },
	},
	Highlight = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "FillColor", category = "Appearance", valueType = "Color3" },
		{ name = "OutlineColor", category = "Appearance", valueType = "Color3" },
		{ name = "FillTransparency", category = "Appearance", valueType = "number" },
		{ name = "OutlineTransparency", category = "Appearance", valueType = "number" },
	},
	Frame = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Visible", category = "Data", valueType = "boolean" },
		{ name = "BackgroundColor3", category = "Appearance", valueType = "Color3" },
		{ name = "BackgroundTransparency", category = "Appearance", valueType = "number" },
		{ name = "BorderSizePixel", category = "Appearance", valueType = "number" },
	},
	TextLabel = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Text", category = "Text", valueType = "string" },
		{ name = "TextColor3", category = "Text", valueType = "Color3" },
		{ name = "TextSize", category = "Text", valueType = "number" },
		{ name = "BackgroundTransparency", category = "Appearance", valueType = "number" },
		{ name = "Visible", category = "Data", valueType = "boolean" },
	},
	TextButton = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Text", category = "Text", valueType = "string" },
		{ name = "TextColor3", category = "Text", valueType = "Color3" },
		{ name = "TextSize", category = "Text", valueType = "number" },
		{ name = "BackgroundColor3", category = "Appearance", valueType = "Color3" },
		{ name = "Visible", category = "Data", valueType = "boolean" },
	},
	ProximityPrompt = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "ActionText", category = "Data", valueType = "string" },
		{ name = "ObjectText", category = "Data", valueType = "string" },
		{ name = "HoldDuration", category = "Data", valueType = "number" },
		{ name = "MaxActivationDistance", category = "Data", valueType = "number" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
	},
	Camera = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "FieldOfView", category = "Camera", valueType = "number" },
		{ name = "CameraType", category = "Camera", valueType = "enum", enumType = "CameraType" },
	},
	BloomEffect = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Intensity", category = "Appearance", valueType = "number" },
		{ name = "Size", category = "Appearance", valueType = "number" },
		{ name = "Threshold", category = "Appearance", valueType = "number" },
	},
	BlurEffect = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Size", category = "Appearance", valueType = "number" },
	},
	ColorCorrectionEffect = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "Contrast", category = "Appearance", valueType = "number" },
		{ name = "Saturation", category = "Appearance", valueType = "number" },
		{ name = "TintColor", category = "Appearance", valueType = "Color3" },
	},
	DepthOfFieldEffect = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "FarIntensity", category = "Appearance", valueType = "number" },
		{ name = "FocusDistance", category = "Appearance", valueType = "number" },
		{ name = "InFocusRadius", category = "Appearance", valueType = "number" },
		{ name = "NearIntensity", category = "Appearance", valueType = "number" },
	},
	SunRaysEffect = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Intensity", category = "Appearance", valueType = "number" },
		{ name = "Spread", category = "Appearance", valueType = "number" },
	},
	Atmosphere = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Density", category = "Appearance", valueType = "number" },
		{ name = "Offset", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{ name = "Decay", category = "Appearance", valueType = "Color3" },
		{ name = "Glare", category = "Appearance", valueType = "number" },
		{ name = "Haze", category = "Appearance", valueType = "number" },
	},
	Sky = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "CelestialBodiesShown", category = "Appearance", valueType = "boolean" },
		{ name = "StarCount", category = "Appearance", valueType = "number" },
		{ name = "SkyboxBk", category = "Appearance", valueType = "string" },
		{ name = "SkyboxDn", category = "Appearance", valueType = "string" },
		{ name = "SkyboxFt", category = "Appearance", valueType = "string" },
		{ name = "SkyboxLf", category = "Appearance", valueType = "string" },
		{ name = "SkyboxRt", category = "Appearance", valueType = "string" },
		{ name = "SkyboxUp", category = "Appearance", valueType = "string" },
		{ name = "SunAngularSize", category = "Appearance", valueType = "number" },
		{ name = "MoonAngularSize", category = "Appearance", valueType = "number" },
	},
	ParticleEmitter = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Texture", category = "Appearance", valueType = "string" },
		{ name = "Rate", category = "Appearance", valueType = "number" },
		{ name = "Lifetime", category = "Appearance", valueType = "number" },
		{ name = "Drag", category = "Appearance", valueType = "number" },
		{ name = "LightEmission", category = "Appearance", valueType = "number" },
		{ name = "LightInfluence", category = "Appearance", valueType = "number" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "ZOffset", category = "Appearance", valueType = "number" },
	},
	Beam = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Texture", category = "Appearance", valueType = "string" },
		{ name = "Width0", category = "Appearance", valueType = "number" },
		{ name = "Width1", category = "Appearance", valueType = "number" },
		{ name = "LightEmission", category = "Appearance", valueType = "number" },
		{ name = "LightInfluence", category = "Appearance", valueType = "number" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "Segments", category = "Appearance", valueType = "number" },
		{ name = "TextureSpeed", category = "Appearance", valueType = "number" },
		{ name = "FaceCamera", category = "Appearance", valueType = "boolean" },
	},
	Fire = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Heat", category = "Appearance", valueType = "number" },
		{ name = "Size", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
		{ name = "SecondaryColor", category = "Appearance", valueType = "Color3" },
	},
	Smoke = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Opacity", category = "Appearance", valueType = "number" },
		{ name = "RiseVelocity", category = "Appearance", valueType = "number" },
		{ name = "Size", category = "Appearance", valueType = "number" },
		{ name = "Color", category = "Appearance", valueType = "Color3" },
	},
	Trail = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Enabled", category = "Data", valueType = "boolean" },
		{ name = "Lifetime", category = "Appearance", valueType = "number" },
		{ name = "MinLength", category = "Appearance", valueType = "number" },
		{ name = "MaxLength", category = "Appearance", valueType = "number" },
		{ name = "WidthScale", category = "Appearance", valueType = "number" },
		{ name = "LightEmission", category = "Appearance", valueType = "number" },
		{ name = "LightInfluence", category = "Appearance", valueType = "number" },
		{ name = "Brightness", category = "Appearance", valueType = "number" },
		{ name = "FaceCamera", category = "Appearance", valueType = "boolean" },
	},
	Decal = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Texture", category = "Appearance", valueType = "string" },
		{ name = "Transparency", category = "Appearance", valueType = "number" },
		{ name = "Color3", category = "Appearance", valueType = "Color3" },
		{ name = "ZIndex", category = "Appearance", valueType = "number" },
	},
	Texture = {
		{ name = "Name", category = "Data", valueType = "string" },
		{ name = "Texture", category = "Appearance", valueType = "string" },
		{ name = "Transparency", category = "Appearance", valueType = "number" },
		{ name = "Color3", category = "Appearance", valueType = "Color3" },
		{ name = "StudsPerTileU", category = "Appearance", valueType = "number" },
		{ name = "StudsPerTileV", category = "Appearance", valueType = "number" },
		{ name = "OffsetStudsU", category = "Appearance", valueType = "number" },
		{ name = "OffsetStudsV", category = "Appearance", valueType = "number" },
	},
}

-- probe these when class has no curated list
local REFLECT_PROPS: { EngineProp } = {
	{ name = "Name", category = "Data", valueType = "string" },
	{ name = "Enabled", category = "Data", valueType = "boolean" },
	{ name = "Visible", category = "Data", valueType = "boolean" },
	{ name = "Archivable", category = "Data", valueType = "boolean" },
	{ name = "Intensity", category = "Appearance", valueType = "number" },
	{ name = "Size", category = "Appearance", valueType = "number" },
	{ name = "Threshold", category = "Appearance", valueType = "number" },
	{ name = "Brightness", category = "Appearance", valueType = "number" },
	{ name = "Contrast", category = "Appearance", valueType = "number" },
	{ name = "Saturation", category = "Appearance", valueType = "number" },
	{ name = "TintColor", category = "Appearance", valueType = "Color3" },
	{ name = "Color", category = "Appearance", valueType = "Color3" },
	{ name = "Color3", category = "Appearance", valueType = "Color3" },
	{ name = "Transparency", category = "Appearance", valueType = "number" },
	{ name = "Range", category = "Appearance", valueType = "number" },
	{ name = "Angle", category = "Appearance", valueType = "number" },
	{ name = "Spread", category = "Appearance", valueType = "number" },
	{ name = "Density", category = "Appearance", valueType = "number" },
	{ name = "Texture", category = "Appearance", valueType = "string" },
	{ name = "SoundId", category = "Audio", valueType = "string" },
	{ name = "Volume", category = "Audio", valueType = "number" },
	{ name = "Position", category = "Transform", valueType = "Vector3" },
	{ name = "Orientation", category = "Transform", valueType = "Vector3" },
}

-- Generic service fallback (read-only identity)
local SERVICE_FALLBACK: { EngineProp } = {
	{ name = "Name", category = "Data", valueType = "string", readonly = true },
	{ name = "ClassName", category = "Data", valueType = "string", readonly = true },
}

local SERVICE_NAMES = {
	Workspace = true,
	Players = true,
	Lighting = true,
	MaterialService = true,
	ReplicatedFirst = true,
	ReplicatedStorage = true,
	ServerScriptService = true,
	ServerStorage = true,
	StarterGui = true,
	StarterPack = true,
	StarterPlayer = true,
	Teams = true,
	SoundService = true,
	TextChatService = true,
}

function EngineProps.forInstance(instance: Instance): { EngineProp }
	local list = BY_CLASS[instance.ClassName]
	if not list then
		if SERVICE_NAMES[instance.ClassName] or instance.Parent == game then
			list = SERVICE_FALLBACK
		else
			-- reflect common props so classes like Bloom aren't empty
			list = REFLECT_PROPS
		end
	end

	local out = {}
	local seen: { [string]: boolean } = {}
	for _, prop in list do
		local ok = pcall(function()
			local _ = (instance :: any)[prop.name]
		end)
		if ok and not seen[prop.name] then
			seen[prop.name] = true
			table.insert(out, prop)
		end
	end
	-- always ensure Name shows
	if not seen.Name then
		table.insert(out, 1, { name = "Name", category = "Data", valueType = "string" })
	end
	return out
end

function EngineProps.get(instance: Instance, name: string): any
	return (instance :: any)[name]
end

function EngineProps.set(instance: Instance, name: string, value: any): boolean
	local ok = pcall(function()
		local current = (instance :: any)[name]
		if typeof(current) == "EnumItem" and typeof(value) == "string" then
			local enumType = current.EnumType
			local item = (enumType :: any)[value]
			if item then
				(instance :: any)[name] = item
				return
			end
		end
		(instance :: any)[name] = value
	end)
	return ok
end

function EngineProps.resolveEnumItems(prop: EngineProp, currentValue: any): { string }?
	if prop.enumItems then
		return prop.enumItems
	end
	if typeof(currentValue) == "EnumItem" then
		local items = {}
		for _, item in currentValue.EnumType:GetEnumItems() do
			table.insert(items, item.Name)
		end
		table.sort(items)
		return items
	end
	if prop.enumType then
		local ok, enumType = pcall(function()
			return (Enum :: any)[prop.enumType]
		end)
		if ok and enumType then
			local items = {}
			for _, item in enumType:GetEnumItems() do
				table.insert(items, item.Name)
			end
			table.sort(items)
			return items
		end
	end
	return nil
end

return EngineProps
