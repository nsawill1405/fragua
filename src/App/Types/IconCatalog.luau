-- Wide icon menu for custom instance types.
-- Uses Studio class sprite sheet where possible, plus emoji glyphs as fallbacks.

export type IconDef = {
	id: string,
	label: string,
	kind: "class" | "emoji" | "image",
	className: string?,
	emoji: string?,
	image: string?,
}

local CLASS_ICONS = {
	"Folder",
	"Part",
	"MeshPart",
	"Model",
	"Humanoid",
	"Script",
	"LocalScript",
	"ModuleScript",
	"RemoteEvent",
	"RemoteFunction",
	"BindableEvent",
	"BindableFunction",
	"Configuration",
	"StringValue",
	"IntValue",
	"BoolValue",
	"NumberValue",
	"ObjectValue",
	"BillboardGui",
	"SurfaceGui",
	"Frame",
	"TextLabel",
	"TextButton",
	"ImageLabel",
	"Sound",
	"Animation",
	"Attachment",
	"Beam",
	"ParticleEmitter",
	"PointLight",
	"SpotLight",
	"SpawnLocation",
	"Tool",
	"Seat",
	"VehicleSeat",
	"ProximityPrompt",
	"ClickDetector",
	"TouchTransmitter",
	"Camera",
	"Terrain",
	"Workspace",
	"Players",
	"Lighting",
	"ReplicatedStorage",
	"ServerStorage",
	"ServerScriptService",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"HttpService",
	"CollectionService",
	"Debris",
	"TweenService",
	"RunService",
	"UserInputService",
	"ContextActionService",
	"PathfindingModifier",
	"PathfindingLink",
	"Highlight",
	"UICorner",
	"UIListLayout",
	"UIGridLayout",
	"UIPadding",
	"UIStroke",
	"CanvasGroup",
	"ViewportFrame",
	"WorldModel",
	"Actor",
	"SpecialMesh",
	"Decal",
	"Texture",
	"Fire",
	"Smoke",
	"Sparkles",
	"Trail",
	"WeldConstraint",
	"Motor6D",
	"AlignPosition",
	"AlignOrientation",
	"LinearVelocity",
	"AngularVelocity",
	"VectorForce",
	"Attachment",
	"Bone",
	"Accessory",
	"Hat",
	"Shirt",
	"Pants",
	"ShirtGraphic",
	"BodyColors",
	"HumanoidDescription",
	"Animator",
	"AnimationController",
	"Chat",
	"Teams",
	"Team",
	"SoundGroup",
	"Sky",
	"Atmosphere",
	"BloomEffect",
	"BlurEffect",
	"ColorCorrectionEffect",
	"SunRaysEffect",
	"DepthOfFieldEffect",
}

local EMOJI_ICONS = {
	{ id = "emoji_skull", label = "Skull", emoji = "💀" },
	{ id = "emoji_zombie", label = "Zombie", emoji = "🧟" },
	{ id = "emoji_ghost", label = "Ghost", emoji = "👻" },
	{ id = "emoji_robot", label = "Robot", emoji = "🤖" },
	{ id = "emoji_alien", label = "Alien", emoji = "👽" },
	{ id = "emoji_dragon", label = "Dragon", emoji = "🐉" },
	{ id = "emoji_fire", label = "Fire", emoji = "🔥" },
	{ id = "emoji_ice", label = "Ice", emoji = "❄️" },
	{ id = "emoji_bolt", label = "Bolt", emoji = "⚡" },
	{ id = "emoji_heart", label = "Heart", emoji = "❤️" },
	{ id = "emoji_star", label = "Star", emoji = "⭐" },
	{ id = "emoji_sword", label = "Sword", emoji = "⚔️" },
	{ id = "emoji_shield", label = "Shield", emoji = "🛡️" },
	{ id = "emoji_key", label = "Key", emoji = "🔑" },
	{ id = "emoji_gem", label = "Gem", emoji = "💎" },
	{ id = "emoji_crown", label = "Crown", emoji = "👑" },
	{ id = "emoji_gear", label = "Gear", emoji = "⚙️" },
	{ id = "emoji_wrench", label = "Wrench", emoji = "🔧" },
	{ id = "emoji_hammer", label = "Hammer", emoji = "🔨" },
	{ id = "emoji_magnet", label = "Magnet", emoji = "🧲" },
	{ id = "emoji_bomb", label = "Bomb", emoji = "💣" },
	{ id = "emoji_target", label = "Target", emoji = "🎯" },
	{ id = "emoji_rocket", label = "Rocket", emoji = "🚀" },
	{ id = "emoji_car", label = "Car", emoji = "🚗" },
	{ id = "emoji_plane", label = "Plane", emoji = "✈️" },
	{ id = "emoji_tree", label = "Tree", emoji = "🌳" },
	{ id = "emoji_mountain", label = "Mountain", emoji = "⛰️" },
	{ id = "emoji_moon", label = "Moon", emoji = "🌙" },
	{ id = "emoji_sun", label = "Sun", emoji = "☀️" },
	{ id = "emoji_eye", label = "Eye", emoji = "👁️" },
	{ id = "emoji_brain", label = "Brain", emoji = "🧠" },
	{ id = "emoji_bug", label = "Bug", emoji = "🐛" },
	{ id = "emoji_fish", label = "Fish", emoji = "🐟" },
	{ id = "emoji_cat", label = "Cat", emoji = "🐱" },
	{ id = "emoji_dog", label = "Dog", emoji = "🐶" },
	{ id = "emoji_wolf", label = "Wolf", emoji = "🐺" },
	{ id = "emoji_fox", label = "Fox", emoji = "🦊" },
	{ id = "emoji_bear", label = "Bear", emoji = "🐻" },
	{ id = "emoji_bird", label = "Bird", emoji = "🐦" },
	{ id = "emoji_package", label = "Package", emoji = "📦" },
	{ id = "emoji_scroll", label = "Scroll", emoji = "📜" },
	{ id = "emoji_book", label = "Book", emoji = "📕" },
	{ id = "emoji_puzzle", label = "Puzzle", emoji = "🧩" },
	{ id = "emoji_dice", label = "Dice", emoji = "🎲" },
	{ id = "emoji_flag", label = "Flag", emoji = "🚩" },
	{ id = "emoji_link", label = "Link", emoji = "🔗" },
	{ id = "emoji_lock", label = "Lock", emoji = "🔒" },
	{ id = "emoji_unlock", label = "Unlock", emoji = "🔓" },
	{ id = "emoji_warning", label = "Warning", emoji = "⚠️" },
	{ id = "emoji_check", label = "Check", emoji = "✅" },
	{ id = "emoji_cross", label = "Cross", emoji = "❌" },
	{ id = "emoji_plus", label = "Plus", emoji = "➕" },
	{ id = "emoji_minus", label = "Minus", emoji = "➖" },
	{ id = "emoji_infinity", label = "Infinity", emoji = "♾️" },
	{ id = "emoji_sparkles", label = "Sparkles", emoji = "✨" },
	{ id = "emoji_crystal", label = "Crystal", emoji = "🔮" },
	{ id = "emoji_potion", label = "Potion", emoji = "🧪" },
	{ id = "emoji_mushroom", label = "Mushroom", emoji = "🍄" },
	{ id = "emoji_anchor", label = "Anchor", emoji = "⚓" },
	{ id = "emoji_compass", label = "Compass", emoji = "🧭" },
}

local IconCatalog = {}

local cache: { IconDef }? = nil
local byId: { [string]: IconDef } = {}

function IconCatalog.list(): { IconDef }
	if cache then
		return cache
	end

	local icons: { IconDef } = {}
	for _, className in CLASS_ICONS do
		local def: IconDef = {
			id = "class_" .. className,
			label = className,
			kind = "class",
			className = className,
		}
		table.insert(icons, def)
		byId[def.id] = def
	end
	for _, emojiDef in EMOJI_ICONS do
		local def: IconDef = {
			id = emojiDef.id,
			label = emojiDef.label,
			kind = "emoji",
			emoji = emojiDef.emoji,
		}
		table.insert(icons, def)
		byId[def.id] = def
	end

	cache = icons
	return icons
end

function IconCatalog.get(id: string?): IconDef
	IconCatalog.list()
	if id and byId[id] then
		return byId[id]
	end
	return byId["class_Configuration"] or {
		id = "fallback",
		label = "Custom",
		kind = "emoji",
		emoji = "📦",
	}
end

function IconCatalog.applyTo(gui: ImageLabel | TextLabel, iconId: string?)
	local def = IconCatalog.get(iconId)
	if gui:IsA("ImageLabel") then
		if def.kind == "class" and def.className then
			local ok, info = pcall(function()
				return game:GetService("StudioService"):GetClassIcon(def.className)
			end)
			if ok and info then
				gui.Image = info.Image
				gui.ImageRectOffset = info.ImageRectOffset
				gui.ImageRectSize = info.ImageRectSize
				gui.ImageTransparency = 0
				return
			end
		elseif def.kind == "image" and def.image then
			gui.Image = def.image
			gui.ImageRectOffset = Vector2.zero
			gui.ImageRectSize = Vector2.zero
			gui.ImageTransparency = 0
			return
		end
		gui.Image = ""
		gui.ImageTransparency = 1
	elseif gui:IsA("TextLabel") then
		if def.kind == "emoji" and def.emoji then
			gui.Text = def.emoji
		elseif def.kind == "class" and def.className then
			gui.Text = string.sub(def.className, 1, 1)
		else
			gui.Text = "◆"
		end
	end
end

function IconCatalog.createIconWidget(parent: Instance, iconId: string?, size: number?): Frame
	local sizePx = size or 16
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(sizePx, sizePx)
	holder.Parent = parent

	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = holder

	local emoji = Instance.new("TextLabel")
	emoji.Name = "Emoji"
	emoji.BackgroundTransparency = 1
	emoji.Size = UDim2.fromScale(1, 1)
	emoji.Font = Enum.Font.SourceSans
	emoji.TextSize = sizePx - 2
	emoji.Text = ""
	emoji.Visible = false
	emoji.Parent = holder

	local function paint(id: string?)
		local def = IconCatalog.get(id)
		if def.kind == "emoji" then
			image.Visible = false
			emoji.Visible = true
			emoji.Text = def.emoji or "◆"
		else
			emoji.Visible = false
			image.Visible = true
			IconCatalog.applyTo(image, id)
			if image.Image == "" then
				image.Visible = false
				emoji.Visible = true
				emoji.Text = if def.className then string.sub(def.className, 1, 1) else "◆"
			end
		end
	end

	paint(iconId)
	holder:SetAttribute("IconId", iconId or "")
	holder:GetAttributeChangedSignal("IconId"):Connect(function()
		paint(holder:GetAttribute("IconId") :: string?)
	end)

	return holder
end

return IconCatalog
