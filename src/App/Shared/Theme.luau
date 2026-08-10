-- Studio-dark inspired tokens for Fragua dock UIs.
local Theme = {
	bg = Color3.fromRGB(46, 46, 46),
	bgDeep = Color3.fromRGB(37, 37, 37),
	bgRaised = Color3.fromRGB(53, 53, 53),
	bgHover = Color3.fromRGB(66, 66, 66),
	bgSelected = Color3.fromRGB(11, 90, 175),
	bgSelectedMuted = Color3.fromRGB(36, 70, 110),
	border = Color3.fromRGB(30, 30, 30),
	borderLight = Color3.fromRGB(70, 70, 70),
	text = Color3.fromRGB(204, 204, 204),
	textMuted = Color3.fromRGB(140, 140, 140),
	textBright = Color3.fromRGB(240, 240, 240),
	accent = Color3.fromRGB(0, 162, 255),
	danger = Color3.fromRGB(224, 79, 95),
	success = Color3.fromRGB(80, 180, 110),
	section = Color3.fromRGB(60, 60, 60),
	inputBg = Color3.fromRGB(30, 30, 30),
	font = Enum.Font.SourceSans,
	fontBold = Enum.Font.SourceSansBold,
	fontMono = Enum.Font.RobotoMono,
	rowHeight = 22,
	toolbarHeight = 28,
	headerHeight = 26,
	corner = UDim.new(0, 4),
}

function Theme.applyText(label: TextLabel | TextButton | TextBox, bright: boolean?)
	label.Font = Theme.font
	label.TextSize = 14
	label.TextColor3 = if bright then Theme.textBright else Theme.text
	label.BackgroundTransparency = 1
end

function Theme.makeButton(parent: Instance, text: string, props: { [string]: any }?): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = props and props.Name or "Button"
	btn.AutoButtonColor = false
	btn.Font = Theme.font
	btn.TextSize = 14
	btn.Text = text
	btn.TextColor3 = Theme.textBright
	btn.BackgroundColor3 = Theme.bgRaised
	btn.BorderSizePixel = 0
	btn.Size = props and props.Size or UDim2.new(0, 80, 0, 24)
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.corner
	corner.Parent = btn

	btn.MouseEnter:Connect(function()
		if btn.BackgroundColor3 ~= Theme.bgSelected then
			btn.BackgroundColor3 = Theme.bgHover
		end
	end)
	btn.MouseLeave:Connect(function()
		if btn.BackgroundColor3 ~= Theme.bgSelected then
			btn.BackgroundColor3 = Theme.bgRaised
		end
	end)

	return btn
end

return Theme
