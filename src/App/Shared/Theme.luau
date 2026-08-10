-- Modern Studio-dark tokens for Fragua dock UIs.
local TweenService = game:GetService("TweenService")

local function fontOrFallback(name: string, fallback: Enum.Font): Enum.Font
	local ok, value = pcall(function()
		return (Enum.Font :: any)[name]
	end)
	return if ok and value then value else fallback
end

local Theme = {
	bg = Color3.fromRGB(36, 37, 41),
	bgDeep = Color3.fromRGB(24, 25, 28),
	bgRaised = Color3.fromRGB(46, 48, 54),
	bgHover = Color3.fromRGB(58, 61, 70),
	bgSelected = Color3.fromRGB(38, 110, 196),
	bgSelectedMuted = Color3.fromRGB(32, 72, 120),
	border = Color3.fromRGB(18, 19, 22),
	borderLight = Color3.fromRGB(72, 76, 86),
	text = Color3.fromRGB(210, 212, 218),
	textMuted = Color3.fromRGB(140, 144, 156),
	textBright = Color3.fromRGB(250, 251, 255),
	accent = Color3.fromRGB(64, 156, 255),
	accentSoft = Color3.fromRGB(40, 96, 150),
	danger = Color3.fromRGB(232, 96, 104),
	dangerHover = Color3.fromRGB(255, 128, 136),
	success = Color3.fromRGB(88, 196, 130),
	section = Color3.fromRGB(42, 44, 50),
	inputBg = Color3.fromRGB(22, 23, 27),
	matchTint = Color3.fromRGB(48, 78, 110),
	dropTint = Color3.fromRGB(56, 120, 180),
	syntaxKeyword = Color3.fromRGB(197, 134, 192),
	syntaxString = Color3.fromRGB(206, 145, 120),
	syntaxNumber = Color3.fromRGB(181, 206, 168),
	syntaxComment = Color3.fromRGB(106, 153, 85),
	syntaxType = Color3.fromRGB(78, 201, 176),
	syntaxProperty = Color3.fromRGB(156, 220, 254),
	syntaxGlobal = Color3.fromRGB(220, 220, 170),
	font = fontOrFallback("BuilderSans", Enum.Font.Gotham),
	fontBold = fontOrFallback("BuilderSansMedium", Enum.Font.GothamMedium),
	fontMono = Enum.Font.RobotoMono,
	spacing = { xs = 4, sm = 8, md = 12, lg = 16 },
	radius = { control = UDim.new(0, 6), card = UDim.new(0, 8), overlay = UDim.new(0, 10) },
	typeSize = { caption = 10, secondary = 11, control = 12, body = 13, title = 14 },
	rowHeight = 26,
	toolbarHeight = 34,
	headerHeight = 36,
	corner = UDim.new(0, 6),
	tweenFast = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	tweenMed = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	tweenSnap = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

local activeTweens: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any

function Theme.play(inst: Instance, key: string, props: { [string]: any }, info: TweenInfo?): Tween
	local byKey = activeTweens[inst]
	if not byKey then
		byKey = {}
		activeTweens[inst] = byKey
	end
	local previous = byKey[key]
	if previous then
		previous:Cancel()
	end
	local tweenInfo = info or Theme.tweenFast
	local ok, Store = pcall(function()
		return require(script.Parent.Parent.Settings.Store)
	end)
	if ok and Store and Store.getAnimations and not Store.getAnimations() then
		tweenInfo = TweenInfo.new(0)
	end
	local tween = TweenService:Create(inst, tweenInfo, props)
	byKey[key] = tween
	tween.Completed:Once(function()
		if activeTweens[inst] and activeTweens[inst][key] == tween then
			activeTweens[inst][key] = nil
		end
	end)
	tween:Play()
	return tween
end

function Theme.tween(inst: Instance, props: { [string]: any }, info: TweenInfo?): Tween
	return Theme.play(inst, "default", props, info)
end

function Theme.applyText(label: TextLabel | TextButton | TextBox, bright: boolean?)
	label.Font = Theme.font
	label.TextSize = 13
	label.TextColor3 = if bright then Theme.textBright else Theme.text
	label.BackgroundTransparency = 1
end

function Theme.makeButton(parent: Instance, text: string, props: { [string]: any }?): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = props and props.Name or "Button"
	btn.AutoButtonColor = false
	btn.Font = Theme.fontBold
	btn.TextSize = 13
	btn.Text = text
	btn.TextColor3 = Theme.textBright
	btn.BackgroundColor3 = Theme.bgRaised
	btn.BorderSizePixel = 0
	btn.Size = props and props.Size or UDim2.fromOffset(80, 28)
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.radius.control
	corner.Parent = btn

	local base = btn.BackgroundColor3
	btn.MouseEnter:Connect(function()
		Theme.play(btn, "hover", { BackgroundColor3 = Theme.bgHover })
	end)
	btn.MouseLeave:Connect(function()
		Theme.play(btn, "hover", { BackgroundColor3 = base })
	end)

	return btn
end

function Theme.iconButton(parent: Instance, text: string, size: number?): TextButton
	local px = size or 18
	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.Size = UDim2.fromOffset(px, px)
	btn.Font = Theme.fontBold
	btn.TextSize = math.floor(px * 0.75)
	btn.Text = text
	btn.TextColor3 = Theme.textMuted
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = btn

	btn.MouseEnter:Connect(function()
		btn.TextColor3 = Theme.textBright
		Theme.tween(btn, { BackgroundTransparency = 0.7, BackgroundColor3 = Theme.bgHover })
	end)
	btn.MouseLeave:Connect(function()
		btn.TextColor3 = Theme.textMuted
		Theme.tween(btn, { BackgroundTransparency = 1 })
	end)

	return btn
end

return Theme
