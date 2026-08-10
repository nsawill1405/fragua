-- Wide icon menu for custom instance types.
-- Uses StudioService class icons where possible, plus emoji glyphs.

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
	"TextBox",
	"ImageLabel",
	"ImageButton",
	"ScrollingFrame",
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
	"Camera",
	"Workspace",
	"Players",
	"Lighting",
	"MaterialService",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerStorage",
	"ServerScriptService",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"SoundService",
	"TextChatService",
	"Highlight",
	"UICorner",
	"UIListLayout",
	"UIPadding",
	"UIStroke",
	"Decal",
	"Texture",
	"Fire",
	"Smoke",
	"Sparkles",
	"Trail",
	"WeldConstraint",
	"Motor6D",
}

local EMOJI_ICONS = {
	{ id = "emoji_skull", label = "Skull", emoji = "💀" },
	{ id = "emoji_zombie", label = "Zombie", emoji = "🧟" },
	{ id = "emoji_ghost", label = "Ghost", emoji = "👻" },
	{ id = "emoji_robot", label = "Robot", emoji = "🤖" },
	{ id = "emoji_alien", label = "Alien", emoji = "👽" },
	{ id = "emoji_dragon", label = "Dragon", emoji = "🐉" },
	{ id = "emoji_fire", label = "Fire", emoji = "🔥" },
	{ id = "emoji_ice", label = "Ice", emoji = "❄" },
	{ id = "emoji_bolt", label = "Bolt", emoji = "⚡" },
	{ id = "emoji_heart", label = "Heart", emoji = "❤" },
	{ id = "emoji_star", label = "Star", emoji = "⭐" },
	{ id = "emoji_sword", label = "Sword", emoji = "⚔" },
	{ id = "emoji_shield", label = "Shield", emoji = "🛡" },
	{ id = "emoji_key", label = "Key", emoji = "🔑" },
	{ id = "emoji_gem", label = "Gem", emoji = "💎" },
	{ id = "emoji_crown", label = "Crown", emoji = "👑" },
	{ id = "emoji_gear", label = "Gear", emoji = "⚙" },
	{ id = "emoji_package", label = "Package", emoji = "📦" },
	{ id = "emoji_scroll", label = "Scroll", emoji = "📜" },
	{ id = "emoji_book", label = "Book", emoji = "📕" },
	{ id = "emoji_warning", label = "Warning", emoji = "⚠" },
	{ id = "emoji_check", label = "Check", emoji = "✓" },
	{ id = "emoji_cross", label = "Cross", emoji = "✕" },
	{ id = "emoji_plus", label = "Plus", emoji = "+" },
	{ id = "emoji_sparkles", label = "Sparkles", emoji = "✨" },
	{ id = "emoji_target", label = "Target", emoji = "◎" },
	{ id = "emoji_rocket", label = "Rocket", emoji = "🚀" },
	{ id = "emoji_bug", label = "Bug", emoji = "🐛" },
	{ id = "emoji_eye", label = "Eye", emoji = "👁" },
	{ id = "emoji_lock", label = "Lock", emoji = "🔒" },
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
		emoji = "◆",
	}
end

local function applyClassIcon(image: ImageLabel, className: string): boolean
	local ok, info = pcall(function()
		return game:GetService("StudioService"):GetClassIcon(className)
	end)
	if ok and typeof(info) == "table" and info.Image then
		image.Image = info.Image
		image.ImageRectOffset = info.ImageRectOffset or Vector2.zero
		image.ImageRectSize = info.ImageRectSize or Vector2.zero
		image.ImageTransparency = 0
		return true
	end
	return false
end

function IconCatalog.applyTo(gui: ImageLabel | TextLabel, iconId: string?)
	local def = IconCatalog.get(iconId)
	if gui:IsA("ImageLabel") then
		if def.kind == "class" and def.className and applyClassIcon(gui, def.className) then
			return
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
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromOffset(sizePx, sizePx)
	holder.Active = false
	holder.Parent = parent

	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Size = UDim2.fromScale(1, 1)
	image.ScaleType = Enum.ScaleType.Fit
	image.Active = false
	image.Parent = holder

	local emoji = Instance.new("TextLabel")
	emoji.Name = "Emoji"
	emoji.BackgroundTransparency = 1
	emoji.BorderSizePixel = 0
	emoji.Size = UDim2.fromScale(1, 1)
	emoji.Font = Enum.Font.GothamBold
	emoji.TextSize = math.max(10, sizePx - 1)
	emoji.TextColor3 = Color3.fromRGB(230, 230, 230)
	emoji.Text = ""
	emoji.Visible = false
	emoji.Active = false
	emoji.Parent = holder

	local function paint(id: string?)
		local def = IconCatalog.get(id)
		if def.kind == "emoji" then
			image.Visible = false
			emoji.Visible = true
			emoji.Text = def.emoji or "◆"
		elseif def.kind == "class" and def.className and applyClassIcon(image, def.className) then
			emoji.Visible = false
			image.Visible = true
		elseif def.kind == "image" and def.image then
			emoji.Visible = false
			image.Visible = true
			image.Image = def.image
			image.ImageRectOffset = Vector2.zero
			image.ImageRectSize = Vector2.zero
			image.ImageTransparency = 0
		else
			image.Visible = false
			emoji.Visible = true
			emoji.Text = if def.className then string.upper(string.sub(def.className, 1, 1)) else "◆"
		end
	end

	paint(iconId)
	holder:SetAttribute("IconId", iconId or "")
	holder:GetAttributeChangedSignal("IconId"):Connect(function()
		paint(holder:GetAttribute("IconId") :: string?)
	end)

	return holder
end

function IconCatalog.setZIndex(holder: Frame, z: number)
	holder.ZIndex = z
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child.ZIndex = z
		end
	end
end

return IconCatalog
