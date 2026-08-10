-- Modern Studio-dark tokens for Fragua dock UIs.
local Theme = {
	bg = Color3.fromRGB(40, 40, 42),
	bgDeep = Color3.fromRGB(30, 30, 32),
	bgRaised = Color3.fromRGB(48, 48, 52),
	bgHover = Color3.fromRGB(56, 56, 62),
	bgSelected = Color3.fromRGB(0, 112, 198),
	bgSelectedMuted = Color3.fromRGB(28, 78, 128),
	border = Color3.fromRGB(22, 22, 24),
	borderLight = Color3.fromRGB(68, 68, 74),
	text = Color3.fromRGB(214, 214, 218),
	textMuted = Color3.fromRGB(148, 148, 156),
	textBright = Color3.fromRGB(248, 248, 250),
	accent = Color3.fromRGB(47, 156, 255),
	accentSoft = Color3.fromRGB(36, 90, 140),
	danger = Color3.fromRGB(232, 88, 96),
	dangerHover = Color3.fromRGB(255, 120, 128),
	success = Color3.fromRGB(80, 180, 110),
	section = Color3.fromRGB(48, 48, 52),
	inputBg = Color3.fromRGB(26, 26, 28),
	font = Enum.Font.Gotham,
	fontBold = Enum.Font.GothamMedium,
	fontMono = Enum.Font.RobotoMono,
	rowHeight = 24,
	toolbarHeight = 32,
	headerHeight = 34,
	corner = UDim.new(0, 5),
}

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
	btn.Size = props and props.Size or UDim2.new(0, 80, 0, 26)
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.corner
	corner.Parent = btn

	local base = btn.BackgroundColor3
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = Theme.bgHover
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = base
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
		btn.BackgroundTransparency = 0.75
		btn.BackgroundColor3 = Theme.bgHover
	end)
	btn.MouseLeave:Connect(function()
		btn.TextColor3 = Theme.textMuted
		btn.BackgroundTransparency = 1
	end)

	return btn
end

return Theme
