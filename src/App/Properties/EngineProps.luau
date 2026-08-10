-- Curated readable/writable engine properties for the Properties panel.

local EngineProps = {}

local BY_CLASS: { [string]: { string } } = {
	Instance = { "Name", "Archivable", "ClassName" },
	Folder = { "Name", "Archivable" },
	Configuration = { "Name", "Archivable" },
	Part = {
		"Name",
		"Anchored",
		"CanCollide",
		"CanQuery",
		"CanTouch",
		"CastShadow",
		"Transparency",
		"Reflectance",
		"Color",
		"Size",
		"Position",
		"Orientation",
		"Material",
		"Shape",
		"BrickColor",
	},
	MeshPart = {
		"Name",
		"Anchored",
		"CanCollide",
		"Transparency",
		"Color",
		"Size",
		"Position",
		"Orientation",
		"Material",
	},
	Model = { "Name", "PrimaryPart" },
	Humanoid = {
		"Name",
		"Health",
		"MaxHealth",
		"WalkSpeed",
		"JumpPower",
		"JumpHeight",
		"HipHeight",
		"AutoRotate",
		"DisplayName",
		"NameDisplayDistance",
		"HealthDisplayDistance",
	},
	Script = { "Name", "Disabled", "RunContext" },
	LocalScript = { "Name", "Disabled" },
	ModuleScript = { "Name" },
	BillboardGui = { "Name", "Enabled", "AlwaysOnTop", "Size", "StudsOffset", "MaxDistance" },
	StringValue = { "Name", "Value" },
	BoolValue = { "Name", "Value" },
	NumberValue = { "Name", "Value" },
	IntValue = { "Name", "Value" },
	ObjectValue = { "Name", "Value" },
	RemoteEvent = { "Name" },
	RemoteFunction = { "Name" },
	Highlight = { "Name", "Enabled", "FillColor", "OutlineColor", "FillTransparency", "OutlineTransparency" },
	ProximityPrompt = { "Name", "ActionText", "ObjectText", "HoldDuration", "MaxActivationDistance", "Enabled" },
	Sound = { "Name", "SoundId", "Volume", "PlaybackSpeed", "Looped", "Playing" },
	PointLight = { "Name", "Enabled", "Brightness", "Color", "Range" },
	SpotLight = { "Name", "Enabled", "Brightness", "Color", "Range", "Angle" },
	Decal = { "Name", "Texture", "Transparency", "Color3" },
	Texture = { "Name", "Texture", "Transparency", "Color3", "StudsPerTileU", "StudsPerTileV" },
	Frame = { "Name", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "Visible", "Size", "Position" },
	TextLabel = {
		"Name",
		"Text",
		"TextColor3",
		"TextSize",
		"Font",
		"BackgroundTransparency",
		"Visible",
		"Size",
		"Position",
	},
	TextButton = {
		"Name",
		"Text",
		"TextColor3",
		"TextSize",
		"Font",
		"BackgroundColor3",
		"Visible",
		"Size",
		"Position",
	},
	Camera = { "Name", "FieldOfView", "CameraType", "HeadLocked" },
	SpawnLocation = { "Name", "Enabled", "Duration", "Neutral", "TeamColor", "Anchored", "Size", "Position", "Color" },
	Tool = { "Name", "ToolTip", "CanBeDropped", "RequiresHandle", "Enabled" },
}

local READONLY = {
	ClassName = true,
	Position = true,
	Orientation = true,
}

function EngineProps.forInstance(instance: Instance): { { name: string, readonly: boolean } }
	local names = BY_CLASS[instance.ClassName] or BY_CLASS.Instance
	local list = {}
	for _, name in names do
		local ok = pcall(function()
			local _ = (instance :: any)[name]
		end)
		if ok then
			table.insert(list, {
				name = name,
				readonly = READONLY[name] == true or name == "ClassName",
			})
		end
	end
	return list
end

function EngineProps.get(instance: Instance, name: string): any
	return (instance :: any)[name]
end

function EngineProps.set(instance: Instance, name: string, value: any): boolean
	if READONLY[name] then
		return false
	end
	local ok = pcall(function()
		(instance :: any)[name] = value
	end)
	return ok
end

return EngineProps
