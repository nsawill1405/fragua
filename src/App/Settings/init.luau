local Theme = require(script.Parent.Shared.Theme)
local UiUtil = require(script.Parent.Shared.UiUtil)
local Store = require(script.Store)

local SettingsUI = {}

function SettingsUI.open(host: Instance)
	local existing = host:FindFirstChild("FraguaSettingsOverlay")
	if existing then
		existing:Destroy()
	end

	local overlay = Instance.new("Frame")
	overlay.Name = "FraguaSettingsOverlay"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 70
	overlay.Parent = host

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(340, 420)
	panel.BackgroundColor3 = Theme.bg
	panel.BorderSizePixel = 0
	panel.ZIndex = 71
	panel.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local titleBar = Instance.new("Frame")
	titleBar.BackgroundTransparency = 1
	titleBar.Size = UDim2.new(1, 0, 0, 32)
	titleBar.ZIndex = 72
	titleBar.Active = true
	titleBar.Parent = panel
	UiUtil.makeDraggable(titleBar, panel)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -40, 0, 20)
	title.Font = Theme.fontBold
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.textBright
	title.Text = "Fragua Settings"
	title.ZIndex = 73
	title.Parent = titleBar

	local close = UiUtil.makeCloseButton(titleBar, 20)
	close.Position = UDim2.new(1, -26, 0, 6)
	close.ZIndex = 73
	close.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundColor3 = Theme.bgDeep
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(12, 40)
	scroll.Size = UDim2.new(1, -24, 1, -52)
	scroll.ScrollBarThickness = 5
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ZIndex = 72
	scroll.Parent = panel

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll

	local function toggleRow(order: number, labelText: string, get: () -> boolean, set: (boolean) -> ())
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 28)
		row.LayoutOrder = order
		row.ZIndex = 73
		row.Parent = scroll

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -50, 1, 0)
		label.Font = Theme.font
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Theme.textBright
		label.Text = labelText
		label.ZIndex = 74
		label.Parent = row

		local btn = Instance.new("TextButton")
		btn.AutoButtonColor = false
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.fromScale(1, 0.5)
		btn.Size = UDim2.fromOffset(40, 20)
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.ZIndex = 74
		btn.Parent = row
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(1, 0)
		bc.Parent = btn

		local knob = Instance.new("Frame")
		knob.Size = UDim2.fromOffset(16, 16)
		knob.BorderSizePixel = 0
		knob.ZIndex = 75
		knob.Parent = btn
		local kc = Instance.new("UICorner")
		kc.CornerRadius = UDim.new(1, 0)
		kc.Parent = knob

		local function paint()
			local on = get()
			btn.BackgroundColor3 = if on then Theme.accent else Theme.inputBg
			knob.BackgroundColor3 = Theme.textBright
			knob.Position = if on then UDim2.new(1, -18, 0.5, -8) else UDim2.fromOffset(2, 2)
		end
		paint()
		btn.MouseButton1Click:Connect(function()
			set(not get())
			paint()
		end)
	end

	toggleRow(1, "Confirm before deleting types with instances", Store.getConfirmOnDelete, Store.setConfirmOnDelete)
	toggleRow(2, "Highlight search matches", Store.getMatchHighlight, Store.setMatchHighlight)
	toggleRow(3, "Animate interface transitions", Store.getAnimations, Store.setAnimations)

	local colorHeader = Instance.new("TextLabel")
	colorHeader.BackgroundTransparency = 1
	colorHeader.Size = UDim2.new(1, 0, 0, 22)
	colorHeader.Font = Theme.fontBold
	colorHeader.TextSize = 12
	colorHeader.TextXAlignment = Enum.TextXAlignment.Left
	colorHeader.TextColor3 = Theme.textMuted
	colorHeader.Text = "SECTION COLORS (click to cycle)"
	colorHeader.LayoutOrder = 4
	colorHeader.ZIndex = 73
	colorHeader.Parent = scroll

	local colorChoices = {
		Color3.fromRGB(90, 160, 220),
		Color3.fromRGB(120, 200, 140),
		Color3.fromRGB(220, 160, 90),
		Color3.fromRGB(180, 140, 220),
		Color3.fromRGB(230, 90, 90),
		Color3.fromRGB(100, 190, 200),
		Color3.fromRGB(220, 200, 100),
		Color3.fromRGB(80, 200, 170),
	}
	local colorSections = { "Custom", "Data", "Behavior", "Health", "Control", "Display" }
	for i, sectionName in colorSections do
		local row = Instance.new("TextButton")
		row.AutoButtonColor = false
		row.BackgroundColor3 = Theme.bgRaised
		row.BackgroundTransparency = 0.3
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 26)
		row.Text = ""
		row.LayoutOrder = 4 + i
		row.ZIndex = 73
		row.Parent = scroll
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 4)
		rc.Parent = row

		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.fromOffset(16, 16)
		swatch.Position = UDim2.fromOffset(8, 5)
		swatch.BorderSizePixel = 0
		swatch.BackgroundColor3 = UiUtil.sectionColor(sectionName)
		swatch.ZIndex = 74
		swatch.Parent = row
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(0, 3)
		sc.Parent = swatch

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(32, 0)
		label.Size = UDim2.new(1, -40, 1, 0)
		label.Font = Theme.font
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Theme.textBright
		label.Text = sectionName
		label.ZIndex = 74
		label.Parent = row

		row.MouseButton1Click:Connect(function()
			local current = swatch.BackgroundColor3
			local nextIdx = 1
			for idx, c in colorChoices do
				if
					math.abs(c.R - current.R) < 0.02
					and math.abs(c.G - current.G) < 0.02
					and math.abs(c.B - current.B) < 0.02
				then
					nextIdx = (idx % #colorChoices) + 1
					break
				end
			end
			local nextColor = colorChoices[nextIdx]
			Store.setSectionColor(sectionName, nextColor)
			swatch.BackgroundColor3 = nextColor
		end)
	end

	local svcHeader = Instance.new("TextLabel")
	svcHeader.BackgroundTransparency = 1
	svcHeader.Size = UDim2.new(1, 0, 0, 22)
	svcHeader.Font = Theme.fontBold
	svcHeader.TextSize = 12
	svcHeader.TextXAlignment = Enum.TextXAlignment.Left
	svcHeader.TextColor3 = Theme.textMuted
	svcHeader.Text = "VISIBLE SERVICES"
	svcHeader.LayoutOrder = 20
	svcHeader.ZIndex = 73
	svcHeader.Parent = scroll

	local visible = {}
	for _, name in Store.getVisibleServices() do
		visible[name] = true
	end

	for i, name in Store.defaultServices() do
		local row = Instance.new("TextButton")
		row.AutoButtonColor = false
		row.BackgroundColor3 = Theme.bgRaised
		row.BackgroundTransparency = 0.3
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 24)
		row.Text = ""
		row.LayoutOrder = 20 + i
		row.ZIndex = 73
		row.Parent = scroll
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 4)
		rc.Parent = row

		local check = Instance.new("TextLabel")
		check.BackgroundTransparency = 1
		check.Size = UDim2.fromOffset(20, 24)
		check.Font = Theme.fontBold
		check.TextSize = 14
		check.TextColor3 = Theme.accent
		check.Text = if visible[name] then "x" else ""
		check.ZIndex = 74
		check.Parent = row

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(24, 0)
		label.Size = UDim2.new(1, -28, 1, 0)
		label.Font = Theme.font
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Theme.textBright
		label.Text = name
		label.ZIndex = 74
		label.Parent = row

		row.MouseButton1Click:Connect(function()
			visible[name] = not visible[name]
			check.Text = if visible[name] then "x" else ""
			local listOut = {}
			for _, svc in Store.defaultServices() do
				if visible[svc] then
					table.insert(listOut, svc)
				end
			end
			Store.setVisibleServices(listOut)
		end)
	end

	return overlay
end

return SettingsUI
