local Theme = require(script.Parent.Parent.Shared.Theme)
local UiUtil = require(script.Parent.Parent.Shared.UiUtil)
local PointerController = require(script.Parent.Parent.Shared.PointerController)
local InteractionMath = require(script.Parent.Parent.Shared.InteractionMath)
local ColorText = require(script.Parent.Parent.Shared.ColorText)

local Controls = {}

function Controls.enumDropdown(
	parent: GuiObject,
	items: { string },
	current: string,
	onPick: (string) -> (),
	_enumType: string?
): TextButton
	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Theme.inputBg
	btn.BorderSizePixel = 0
	btn.Font = Theme.font
	btn.TextSize = 12
	btn.TextColor3 = Theme.textBright
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Text = "  " .. current .. "  v"
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = btn

	local open = false
	local menu: ScrollingFrame? = nil

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

		local host = UiUtil.dockHost(parent)
		local drop = Instance.new("ScrollingFrame")
		drop.Name = "EnumMenu"
		drop.BackgroundColor3 = Theme.bgRaised
		drop.BorderSizePixel = 0
		drop.ZIndex = 100
		drop.ScrollBarThickness = 4
		drop.AutomaticCanvasSize = Enum.AutomaticSize.Y
		drop.CanvasSize = UDim2.new()
		drop.Parent = host

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

		UiUtil.placeDropdown(host, btn, drop, math.max(160, btn.AbsoluteSize.X), math.min(220, 24 * #items + 12))

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
				btn.Text = "  " .. item .. "  v"
				close()
				onPick(item)
			end)
		end

		menu = drop
	end)

	btn.AncestryChanged:Connect(function(_, parentNow)
		if not parentNow then
			close()
		end
	end)

	return btn
end

function Controls.numberField(parent: GuiObject, value: number, onCommit: (number) -> (), range: { number }?): Frame
	local minV = if range then range[1] else nil
	local maxV = if range then range[2] else nil
	if minV == nil or maxV == nil then
		if value >= 0 and value <= 1 then
			minV, maxV = 0, 1
		else
			local span = math.max(math.abs(value) * 2, 10)
			minV, maxV = math.min(0, value - span * 0.25), math.max(value + span * 0.75, span)
		end
	end
	if maxV <= minV then
		maxV = minV + 1
	end

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = parent

	local box = Instance.new("TextBox")
	box.ClearTextOnFocus = false
	box.BackgroundColor3 = Theme.inputBg
	box.BorderSizePixel = 0
	box.Size = UDim2.new(0.34, -2, 1, 0)
	box.Position = UDim2.new(0.66, 2, 0, 0)
	box.Font = Theme.fontMono
	box.TextSize = 11
	box.TextColor3 = Theme.textBright
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Text = string.format(" %.3g", value)
	box.Parent = holder
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 4)
	bc.Parent = box

	local hit = Instance.new("TextButton")
	hit.Name = "SliderHit"
	hit.AutoButtonColor = false
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.BorderSizePixel = 0
	hit.Size = UDim2.new(0.66, -4, 1, 0)
	hit.Position = UDim2.fromOffset(0, 0)
	hit.ZIndex = 2
	hit.Parent = holder

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Theme.bgDeep
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.new(0, 0, 0.5, -3)
	track.Active = false
	track.ZIndex = 1
	track.Parent = hit
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(1, 0)
	tc.Parent = track

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Active = false
	fill.ZIndex = 1
	fill.Parent = track
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(12, 12)
	knob.Position = UDim2.fromScale(0, 0.5)
	knob.BackgroundColor3 = Theme.textBright
	knob.BorderSizePixel = 0
	knob.Active = false
	knob.ZIndex = 2
	knob.Parent = track
	local kc = Instance.new("UICorner")
	kc.CornerRadius = UDim.new(1, 0)
	kc.Parent = knob

	local working = value

	local function paint(n: number)
		working = math.clamp(n, minV :: number, maxV :: number)
		local span = (maxV :: number) - (minV :: number)
		local alpha = if span == 0 then 0 else math.clamp((working - (minV :: number)) / span, 0, 1)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		box.Text = string.format(" %.3g", working)
	end

	paint(value)

	local function commit(n: number)
		paint(n)
		onCommit(working)
	end

	hit.MouseButton1Down:Connect(function(rawX, rawY)
		local host = UiUtil.dockHost(holder)
		local scroll = holder:FindFirstAncestorWhichIsA("ScrollingFrame")
		local hostX, hostY = PointerController.toHostLocal(host, rawX, rawY)
		PointerController.capture(host, {
			initial = Vector2.new(hostX, hostY),
			scroll = scroll,
			onMove = function(x, y)
				local localX = PointerController.toControlLocal(host, hit, x, y)
				local nextValue =
					InteractionMath.valueFromLocal(localX, hit.AbsoluteSize.X, minV :: number, maxV :: number)
				if nextValue ~= working then
					commit(nextValue)
				end
			end,
		})
	end)

	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then
			commit(n)
		else
			paint(working)
		end
	end)

	return holder
end

function Controls.colorField(parent: GuiObject, value: Color3, onCommit: (Color3) -> ()): Frame
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
	hex.Text = " " .. ColorText.format(value.R, value.G, value.B)
	hex.Parent = holder

	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 4)
	hc.Parent = hex

	local function openPicker()
		local host = UiUtil.dockHost(parent)
		local original = swatch.BackgroundColor3
		local committed = original

		local overlay = Instance.new("Frame")
		overlay.Name = "ColorPicker"
		overlay.BackgroundColor3 = Color3.new(0, 0, 0)
		overlay.BackgroundTransparency = 1
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.ZIndex = 120
		overlay.Parent = host
		Theme.tween(overlay, { BackgroundTransparency = 0.4 }, Theme.tweenMed)

		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.48)
		panel.Size = UDim2.fromOffset(268, 292)
		panel.BackgroundColor3 = Theme.bg
		panel.BackgroundTransparency = 0.15
		panel.BorderSizePixel = 0
		panel.ZIndex = 121
		panel.Parent = overlay
		Theme.tween(panel, { BackgroundTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, Theme.tweenMed)

		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0, 10)
		pc.Parent = panel
		local pstroke = Instance.new("UIStroke")
		pstroke.Color = Theme.borderLight
		pstroke.Thickness = 1
		pstroke.Parent = panel

		local titleBar = Instance.new("Frame")
		titleBar.BackgroundColor3 = Theme.bgDeep
		titleBar.BorderSizePixel = 0
		titleBar.Size = UDim2.new(1, 0, 0, 32)
		titleBar.ZIndex = 122
		titleBar.Active = true
		titleBar.Parent = panel
		local tbc = Instance.new("UICorner")
		tbc.CornerRadius = UDim.new(0, 10)
		tbc.Parent = titleBar
		local titleCover = Instance.new("Frame")
		titleCover.BackgroundColor3 = Theme.bgDeep
		titleCover.BorderSizePixel = 0
		titleCover.Position = UDim2.new(0, 0, 1, -10)
		titleCover.Size = UDim2.new(1, 0, 0, 10)
		titleCover.ZIndex = 122
		titleCover.Parent = titleBar
		UiUtil.makeDraggable(titleBar, panel)

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(12, 6)
		title.Size = UDim2.new(1, -48, 0, 20)
		title.Font = Theme.fontBold
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Theme.textBright
		title.Text = "Color"
		title.ZIndex = 123
		title.Parent = titleBar

		local closeX = UiUtil.makeCloseButton(titleBar, 20)
		closeX.Position = UDim2.new(1, -26, 0, 6)
		closeX.ZIndex = 123

		local h, s, v = original:ToHSV()
		local working = original

		local preview = Instance.new("Frame")
		preview.Position = UDim2.fromOffset(12, 42)
		preview.Size = UDim2.new(1, -24, 0, 28)
		preview.BackgroundColor3 = working
		preview.BorderSizePixel = 0
		preview.ZIndex = 122
		preview.Parent = panel
		local prc = Instance.new("UICorner")
		prc.CornerRadius = UDim.new(0, 6)
		prc.Parent = preview

		local sv = Instance.new("Frame")
		sv.Position = UDim2.fromOffset(12, 80)
		sv.Size = UDim2.fromOffset(188, 148)
		sv.BorderSizePixel = 0
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		sv.ClipsDescendants = true
		sv.ZIndex = 122
		sv.Parent = panel
		local svc = Instance.new("UICorner")
		svc.CornerRadius = UDim.new(0, 8)
		svc.Parent = sv

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
		cursor.Size = UDim2.fromOffset(14, 14)
		cursor.BackgroundColor3 = Color3.new(1, 1, 1)
		cursor.BackgroundTransparency = 0.85
		cursor.Active = false
		cursor.ZIndex = 126
		cursor.Parent = sv
		local ring = Instance.new("UIStroke")
		ring.Color = Color3.new(1, 1, 1)
		ring.Thickness = 2
		ring.Parent = cursor
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(1, 0)
		cc.Parent = cursor
		cursor.Position = UDim2.fromScale(s, 1 - v)

		local svHit = Instance.new("TextButton")
		svHit.AutoButtonColor = false
		svHit.Text = ""
		svHit.BackgroundTransparency = 1
		svHit.BorderSizePixel = 0
		svHit.Size = UDim2.fromScale(1, 1)
		svHit.ZIndex = 127
		svHit.Parent = sv

		local hueBar = Instance.new("Frame")
		hueBar.Position = UDim2.fromOffset(210, 80)
		hueBar.Size = UDim2.fromOffset(46, 148)
		hueBar.BorderSizePixel = 0
		hueBar.BackgroundColor3 = Color3.new(1, 1, 1)
		hueBar.ClipsDescendants = true
		hueBar.ZIndex = 122
		hueBar.Parent = panel
		local hbc = Instance.new("UICorner")
		hbc.CornerRadius = UDim.new(0, 8)
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

		local hueKnob = Instance.new("Frame")
		hueKnob.AnchorPoint = Vector2.new(0.5, 0.5)
		hueKnob.Size = UDim2.new(1, -4, 0, 4)
		hueKnob.Position = UDim2.fromScale(0.5, h)
		hueKnob.BackgroundColor3 = Theme.textBright
		hueKnob.BorderSizePixel = 0
		hueKnob.Active = false
		hueKnob.ZIndex = 124
		hueKnob.Parent = hueBar
		local hkc = Instance.new("UICorner")
		hkc.CornerRadius = UDim.new(1, 0)
		hkc.Parent = hueKnob

		local hueHit = Instance.new("TextButton")
		hueHit.AutoButtonColor = false
		hueHit.Text = ""
		hueHit.BackgroundTransparency = 1
		hueHit.BorderSizePixel = 0
		hueHit.Size = UDim2.fromScale(1, 1)
		hueHit.ZIndex = 127
		hueHit.Parent = hueBar

		local function paintField(c: Color3)
			swatch.BackgroundColor3 = c
			hex.Text = " " .. ColorText.format(c.R, c.G, c.B)
		end

		local function refresh(live: boolean?)
			working = Color3.fromHSV(h, s, v)
			preview.BackgroundColor3 = working
			sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			cursor.Position = UDim2.fromScale(s, 1 - v)
			hueKnob.Position = UDim2.fromScale(0.5, h)
			paintField(working)
			if live ~= false then
				committed = working
				onCommit(working)
			end
		end

		-- Pick using overlay-local coordinates (AbsolutePosition deltas are PluginGui-safe).
		local function pickSVAtHost(hostX: number, hostY: number)
			local localPos = UiUtil.hostToLocal(overlay, sv, hostX, hostY)
			local w = math.max(sv.AbsoluteSize.X, sv.Size.X.Offset, 1)
			local hh = math.max(sv.AbsoluteSize.Y, sv.Size.Y.Offset, 1)
			s = math.clamp(localPos.X / w, 0, 1)
			v = 1 - math.clamp(localPos.Y / hh, 0, 1)
			refresh(true)
		end

		local function pickHueAtHost(hostX: number, hostY: number)
			local localPos = UiUtil.hostToLocal(overlay, hueBar, hostX, hostY)
			local hh = math.max(hueBar.AbsoluteSize.Y, hueBar.Size.Y.Offset, 1)
			h = math.clamp(localPos.Y / hh, 0, 1)
			refresh(true)
		end

		local function beginChannel(kind: string, rawX: number, rawY: number)
			local hostX, hostY = PointerController.toHostLocal(overlay, rawX, rawY)
			local function sample(x: number, y: number)
				if kind == "sv" then
					pickSVAtHost(x, y)
				else
					pickHueAtHost(x, y)
				end
			end
			PointerController.capture(overlay, {
				initial = Vector2.new(hostX, hostY),
				onMove = sample,
			})
		end

		svHit.MouseButton1Down:Connect(function(x, y)
			beginChannel("sv", x, y)
		end)
		hueHit.MouseButton1Down:Connect(function(x, y)
			beginChannel("hue", x, y)
		end)

		local function cleanup()
			local cap = overlay:FindFirstChild("_FraguaCapture")
			if cap then
				cap:Destroy()
			end
			overlay:Destroy()
		end

		local function revertAndClose()
			paintField(original)
			onCommit(original)
			cleanup()
		end

		closeX.MouseButton1Click:Connect(revertAndClose)

		local cancel = Theme.makeButton(panel, "Cancel", { Size = UDim2.fromOffset(84, 28) })
		cancel.Position = UDim2.new(1, -184, 1, -40)
		cancel.ZIndex = 122
		cancel.MouseButton1Click:Connect(revertAndClose)

		local okBtn = Theme.makeButton(panel, "Done", { Size = UDim2.fromOffset(84, 28) })
		okBtn.Position = UDim2.new(1, -90, 1, -40)
		okBtn.BackgroundColor3 = Theme.accent
		okBtn.ZIndex = 122
		okBtn.MouseButton1Click:Connect(function()
			onCommit(committed)
			cleanup()
		end)

		refresh(false)
	end

	swatch.MouseButton1Click:Connect(openPicker)

	hex.FocusLost:Connect(function()
		local r, g, b = ColorText.parse(hex.Text)
		if r then
			local c = Color3.new(r, g :: number, b :: number)
			swatch.BackgroundColor3 = c
			hex.Text = " " .. ColorText.format(c.R, c.G, c.B)
			onCommit(c)
		else
			hex.Text = " "
				.. ColorText.format(swatch.BackgroundColor3.R, swatch.BackgroundColor3.G, swatch.BackgroundColor3.B)
		end
	end)

	return holder
end

return Controls
