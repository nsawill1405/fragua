local Theme = require(script.Parent.Parent.Shared.Theme)
local UiUtil = require(script.Parent.Parent.Shared.UiUtil)

local Controls = {}

function Controls.enumDropdown(
	parent: GuiObject,
	items: { string },
	current: string,
	onPick: (string) -> ()
): TextButton
	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Theme.inputBg
	btn.BorderSizePixel = 0
	btn.Font = Theme.font
	btn.TextSize = 12
	btn.TextColor3 = Theme.textBright
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Text = "  " .. current .. "  ▾"
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = btn

	local open = false
	local menu: Frame? = nil

	local function close()
		open = false
		if menu then
			menu:Destroy()
			menu = nil
		end
	end

	btn.MouseButton1Click:Connect(function()
		if open then
			close()
			return
		end
		open = true

		local host = parent:FindFirstAncestorWhichIsA("PluginGui") or parent:FindFirstAncestorOfClass("Frame") or parent
		local drop = Instance.new("ScrollingFrame")
		drop.Name = "EnumMenu"
		drop.BackgroundColor3 = Theme.bgRaised
		drop.BorderSizePixel = 0
		drop.ZIndex = 100
		drop.ScrollBarThickness = 4
		drop.AutomaticCanvasSize = Enum.AutomaticSize.Y
		drop.CanvasSize = UDim2.new()
		drop.Parent = host

		local abs = btn.AbsolutePosition
		local rootAbs = (host :: GuiObject).AbsolutePosition
		drop.Position = UDim2.fromOffset(abs.X - rootAbs.X, abs.Y - rootAbs.Y + btn.AbsoluteSize.Y + 2)
		drop.Size = UDim2.fromOffset(math.max(140, btn.AbsoluteSize.X), math.min(180, 24 * #items + 8))

		local dc = Instance.new("UICorner")
		dc.CornerRadius = UDim.new(0, 6)
		dc.Parent = drop

		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.borderLight
		stroke.Thickness = 1
		stroke.Parent = drop

		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 1)
		list.Parent = drop

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.PaddingLeft = UDim.new(0, 4)
		pad.PaddingRight = UDim.new(0, 4)
		pad.Parent = drop

		for i, item in items do
			local opt = Instance.new("TextButton")
			opt.AutoButtonColor = false
			opt.BackgroundColor3 = if item == current then Theme.accentSoft else Theme.bgDeep
			opt.BackgroundTransparency = if item == current then 0.3 else 1
			opt.BorderSizePixel = 0
			opt.Size = UDim2.new(1, 0, 0, 22)
			opt.Font = Theme.font
			opt.TextSize = 12
			opt.TextColor3 = Theme.textBright
			opt.TextXAlignment = Enum.TextXAlignment.Left
			opt.Text = "  " .. item
			opt.LayoutOrder = i
			opt.ZIndex = 101
			opt.Parent = drop

			local oc = Instance.new("UICorner")
			oc.CornerRadius = UDim.new(0, 3)
			oc.Parent = opt

			opt.MouseEnter:Connect(function()
				opt.BackgroundTransparency = 0
				opt.BackgroundColor3 = Theme.bgHover
			end)
			opt.MouseLeave:Connect(function()
				opt.BackgroundColor3 = if item == current then Theme.accentSoft else Theme.bgDeep
				opt.BackgroundTransparency = if item == current then 0.3 else 1
			end)
			opt.MouseButton1Click:Connect(function()
				btn.Text = "  " .. item .. "  ▾"
				close()
				onPick(item)
			end)
		end

		menu = drop :: any
	end)

	btn.AncestryChanged:Connect(function(_, parentNow)
		if not parentNow then
			close()
		end
	end)

	return btn
end

function Controls.colorField(
	parent: GuiObject,
	value: Color3,
	onCommit: (Color3) -> ()
): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Parent = parent

	local swatch = Instance.new("TextButton")
	swatch.AutoButtonColor = false
	swatch.Size = UDim2.fromOffset(20, 20)
	swatch.Position = UDim2.fromOffset(0, 0)
	swatch.BackgroundColor3 = value
	swatch.BorderSizePixel = 0
	swatch.Text = ""
	swatch.Parent = holder

	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 4)
	sc.Parent = swatch

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.borderLight
	stroke.Thickness = 1
	stroke.Parent = swatch

	local hex = Instance.new("TextBox")
	hex.ClearTextOnFocus = false
	hex.BackgroundColor3 = Theme.inputBg
	hex.BorderSizePixel = 0
	hex.Position = UDim2.fromOffset(26, 0)
	hex.Size = UDim2.new(1, -26, 0, 20)
	hex.Font = Theme.fontMono
	hex.TextSize = 11
	hex.TextColor3 = Theme.textBright
	hex.TextXAlignment = Enum.TextXAlignment.Left
	hex.Text = string.format(
		" %d, %d, %d",
		math.floor(value.R * 255 + 0.5),
		math.floor(value.G * 255 + 0.5),
		math.floor(value.B * 255 + 0.5)
	)
	hex.Parent = holder

	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 4)
	hc.Parent = hex

	local function openPicker()
		local host = parent:FindFirstAncestorWhichIsA("PluginGui") or parent:FindFirstAncestorOfClass("Frame") or parent
		local overlay = Instance.new("Frame")
		overlay.Name = "ColorPicker"
		overlay.BackgroundColor3 = Color3.new(0, 0, 0)
		overlay.BackgroundTransparency = 0.45
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.ZIndex = 120
		overlay.Parent = host

		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(260, 280)
		panel.BackgroundColor3 = Theme.bg
		panel.BorderSizePixel = 0
		panel.ZIndex = 121
		panel.Parent = overlay

		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0, 8)
		pc.Parent = panel

		local titleBar = Instance.new("Frame")
		titleBar.BackgroundTransparency = 1
		titleBar.Size = UDim2.new(1, 0, 0, 30)
		titleBar.ZIndex = 122
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
		title.Text = "Color"
		title.ZIndex = 123
		title.Parent = titleBar

		local closeX = UiUtil.makeCloseButton(titleBar, 20)
		closeX.Position = UDim2.new(1, -26, 0, 5)
		closeX.ZIndex = 123

		local h, s, v = value:ToHSV()
		local working = value

		local preview = Instance.new("Frame")
		preview.Position = UDim2.fromOffset(12, 36)
		preview.Size = UDim2.new(1, -24, 0, 28)
		preview.BackgroundColor3 = working
		preview.BorderSizePixel = 0
		preview.ZIndex = 122
		preview.Parent = panel
		local prc = Instance.new("UICorner")
		prc.CornerRadius = UDim.new(0, 6)
		prc.Parent = preview

		-- SV square
		local sv = Instance.new("ImageButton")
		sv.AutoButtonColor = false
		sv.Position = UDim2.fromOffset(12, 76)
		sv.Size = UDim2.fromOffset(180, 140)
		sv.BorderSizePixel = 0
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		sv.Image = ""
		sv.ZIndex = 122
		sv.Parent = panel
		local svc = Instance.new("UICorner")
		svc.CornerRadius = UDim.new(0, 6)
		svc.Parent = sv

		-- Gradient approximation using UIGradient white->transparent and black
		local white = Instance.new("Frame")
		white.Size = UDim2.fromScale(1, 1)
		white.BackgroundColor3 = Color3.new(1, 1, 1)
		white.BorderSizePixel = 0
		white.Active = false
		white.ZIndex = 123
		white.Parent = sv
		local wg = Instance.new("UIGradient")
		wg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		wg.Parent = white

		local black = Instance.new("Frame")
		black.Size = UDim2.fromScale(1, 1)
		black.BackgroundColor3 = Color3.new(0, 0, 0)
		black.BorderSizePixel = 0
		black.Active = false
		black.ZIndex = 124
		black.Parent = sv
		local bg = Instance.new("UIGradient")
		bg.Rotation = 90
		bg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
		bg.Parent = black

		local cursor = Instance.new("Frame")
		cursor.AnchorPoint = Vector2.new(0.5, 0.5)
		cursor.Size = UDim2.fromOffset(10, 10)
		cursor.BackgroundTransparency = 1
		cursor.Active = false
		cursor.ZIndex = 125
		cursor.Parent = sv
		local ring = Instance.new("UIStroke")
		ring.Color = Color3.new(1, 1, 1)
		ring.Thickness = 2
		ring.Parent = cursor
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(1, 0)
		cc.Parent = cursor
		cursor.Position = UDim2.fromScale(s, 1 - v)

		-- Hue bar
		local hueBar = Instance.new("ImageButton")
		hueBar.AutoButtonColor = false
		hueBar.Position = UDim2.fromOffset(204, 76)
		hueBar.Size = UDim2.fromOffset(44, 140)
		hueBar.BorderSizePixel = 0
		hueBar.BackgroundColor3 = Color3.new(1, 1, 1)
		hueBar.ZIndex = 122
		hueBar.Parent = panel
		local hbc = Instance.new("UICorner")
		hbc.CornerRadius = UDim.new(0, 6)
		hbc.Parent = hueBar
		local hg = Instance.new("UIGradient")
		hg.Rotation = 90
		hg.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
			ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
			ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
			ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
		})
		hg.Parent = hueBar

		local function refresh()
			working = Color3.fromHSV(h, s, v)
			preview.BackgroundColor3 = working
			sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			cursor.Position = UDim2.fromScale(s, 1 - v)
			swatch.BackgroundColor3 = working
			hex.Text = string.format(
				" %d, %d, %d",
				math.floor(working.R * 255 + 0.5),
				math.floor(working.G * 255 + 0.5),
				math.floor(working.B * 255 + 0.5)
			)
		end

		local function pickSV(inputPos: Vector3)
			local rel = Vector2.new(inputPos.X, inputPos.Y) - sv.AbsolutePosition
			s = math.clamp(rel.X / sv.AbsoluteSize.X, 0, 1)
			v = 1 - math.clamp(rel.Y / sv.AbsoluteSize.Y, 0, 1)
			refresh()
		end

		local function pickHue(inputPos: Vector3)
			local rel = inputPos.Y - hueBar.AbsolutePosition.Y
			h = math.clamp(rel / hueBar.AbsoluteSize.Y, 0, 1)
			refresh()
		end

		sv.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				pickSV(input.Position)
			end
		end)
		sv.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement and input.UserInputState == Enum.UserInputState.Change then
				-- drag handled below
			end
		end)

		local UserInputService = game:GetService("UserInputService")
		local draggingSV = false
		local draggingHue = false
		sv.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingSV = true
				pickSV(input.Position)
			end
		end)
		hueBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingHue = true
				pickHue(input.Position)
			end
		end)
		local moveConn = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				if draggingSV then
					pickSV(input.Position)
				elseif draggingHue then
					pickHue(input.Position)
				end
			end
		end)
		local endConn = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingSV = false
				draggingHue = false
			end
		end)

		local function cleanup()
			moveConn:Disconnect()
			endConn:Disconnect()
			overlay:Destroy()
		end

		closeX.MouseButton1Click:Connect(cleanup)

		local cancel = Theme.makeButton(panel, "Cancel", { Size = UDim2.fromOffset(80, 28) })
		cancel.Position = UDim2.new(1, -180, 1, -40)
		cancel.ZIndex = 122
		cancel.MouseButton1Click:Connect(cleanup)

		local okBtn = Theme.makeButton(panel, "OK", { Size = UDim2.fromOffset(80, 28) })
		okBtn.Position = UDim2.new(1, -90, 1, -40)
		okBtn.BackgroundColor3 = Theme.accent
		okBtn.ZIndex = 122
		okBtn.MouseButton1Click:Connect(function()
			onCommit(working)
			cleanup()
		end)
	end

	swatch.MouseButton1Click:Connect(openPicker)

	hex.FocusLost:Connect(function()
		local r, g, b = string.match(hex.Text, "(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
		if r then
			local c = Color3.fromRGB(tonumber(r) :: number, tonumber(g) :: number, tonumber(b) :: number)
			swatch.BackgroundColor3 = c
			onCommit(c)
		end
	end)

	return holder
end

return Controls
