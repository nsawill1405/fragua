local Theme = require(script.Parent.Theme)
local PointerController = require(script.Parent.PointerController)

local UiUtil = {}

function UiUtil.raiseZ(root: GuiObject, base: number)
	root.ZIndex = base
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = base + 1
		end
	end
end

function UiUtil.makeCloseButton(parent: Instance, size: number?): TextButton
	local px = size or 22
	local btn = Instance.new("TextButton")
	btn.Name = "Close"
	btn.AutoButtonColor = false
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.Size = UDim2.fromOffset(px, px)
	btn.Font = Theme.fontBold
	btn.TextSize = math.floor(px * 0.72)
	btn.Text = "x"
	btn.TextColor3 = Theme.textMuted
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = btn

	btn.MouseEnter:Connect(function()
		btn.BackgroundTransparency = 0
		btn.BackgroundColor3 = Theme.danger
		btn.TextColor3 = Theme.textBright
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundTransparency = 1
		btn.TextColor3 = Theme.textMuted
	end)

	return btn
end

function UiUtil.makeChevron(parent: Instance, expanded: boolean, size: number?): Frame
	local px = size or 14
	local twist = Instance.new("Frame")
	twist.Name = "Chevron"
	twist.BackgroundTransparency = 1
	twist.Size = UDim2.fromOffset(px, px)
	twist.Rotation = if expanded then 90 else 0
	twist.Parent = parent

	for direction in { -1, 1 } do
		local line = Instance.new("Frame")
		line.Name = "Line"
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = Theme.textMuted
		line.BorderSizePixel = 0
		line.Position = UDim2.fromScale(0.5, if direction == -1 then 0.37 else 0.63)
		line.Size = UDim2.fromOffset(math.max(5, px - 8), 1)
		-- A collapsed chevron points right; rotating the container 90 degrees opens it downward.
		line.Rotation = -45 * direction
		line.Parent = twist
	end
	return twist
end

function UiUtil.setChevronExpanded(twist: GuiObject, expanded: boolean, animate: boolean?)
	local rot = if expanded then 90 else 0
	if animate == false then
		twist.Rotation = rot
	else
		Theme.tween(twist, { Rotation = rot }, Theme.tweenFast)
	end
end

function UiUtil.makeFocusStroke(control: GuiObject): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "FocusStroke"
	stroke.Color = Theme.accent
	stroke.Thickness = 1
	stroke.Transparency = 1
	stroke.Parent = control
	if control:IsA("TextBox") then
		control.Focused:Connect(function()
			Theme.play(stroke, "focus", { Transparency = 0 })
		end)
		control.FocusLost:Connect(function()
			Theme.play(stroke, "focus", { Transparency = 1 })
		end)
	end
	return stroke
end

function UiUtil.makeCard(parent: Instance): Frame
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.bgRaised
	card.BorderSizePixel = 0
	card.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.radius.card
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.borderLight
	stroke.Transparency = 0.45
	stroke.Parent = card
	return card
end

-- PluginGui-safe pointer capture. MouseMoved x/y are local to `host`.
-- Prefer this over UIS MouseMovement / IsMouseButtonPressed (both flaky in docks).
function UiUtil.capturePointer(
	host: GuiObject,
	onMove: (x: number, y: number) -> (),
	onUp: (x: number, y: number) -> (),
	initialX: number?,
	initialY: number?
): TextButton
	PointerController.capture(host, {
		initial = if initialX ~= nil and initialY ~= nil then Vector2.new(initialX, initialY) else nil,
		onMove = onMove,
		onFinish = function(x, y)
			onUp(x, y)
		end,
	})
	return host:FindFirstChild("_FraguaCapture") :: TextButton
end

-- convert host-local point to a descendant's local space (same AbsolutePosition basis)
function UiUtil.hostToLocal(host: GuiObject, gui: GuiObject, hostX: number, hostY: number): Vector2
	local x, y = PointerController.toControlLocal(host, gui, hostX, hostY)
	return Vector2.new(x, y)
end

-- best host for pointer capture / dropdown parenting inside dock widgets
function UiUtil.dockHost(from: Instance): GuiObject
	local named = from:FindFirstAncestor("PropertiesRoot")
		or from:FindFirstAncestor("ExplorerRoot")
		or from:FindFirstAncestorWhichIsA("PluginGui")
		or from:FindFirstAncestorOfClass("Frame")
		or from
	return named :: GuiObject
end

-- place a dropdown under (or above) an anchor so it stays inside host bounds
function UiUtil.placeDropdown(host: GuiObject, anchor: GuiObject, drop: GuiObject, width: number?, maxHeight: number?)
	local w = width or math.max(140, anchor.AbsoluteSize.X)
	local maxH = maxHeight or 200
	local hostAbs = host.AbsolutePosition
	local hostSize = host.AbsoluteSize
	local anchorAbs = anchor.AbsolutePosition
	local anchorSize = anchor.AbsoluteSize

	local localX = anchorAbs.X - hostAbs.X
	local belowY = anchorAbs.Y - hostAbs.Y + anchorSize.Y + 2
	local aboveY = anchorAbs.Y - hostAbs.Y - 2

	-- clamp x
	if localX + w > hostSize.X - 4 then
		localX = math.max(4, hostSize.X - w - 4)
	end
	if localX < 4 then
		localX = 4
	end

	local spaceBelow = hostSize.Y - belowY - 4
	local spaceAbove = aboveY - 4
	local openUp = spaceBelow < math.min(maxH, 120) and spaceAbove > spaceBelow
	local height = math.min(maxH, math.max(80, if openUp then spaceAbove else spaceBelow))

	drop.Size = UDim2.fromOffset(w, height)
	if openUp then
		drop.Position = UDim2.fromOffset(localX, math.max(4, aboveY - height))
	else
		drop.Position = UDim2.fromOffset(localX, belowY)
	end
end

function UiUtil.makeDraggable(handle: GuiObject, target: GuiObject)
	handle.Active = true
	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		-- The target's parent is the overlay coordinate space. PluginGui is a
		-- LayerCollector, not a GuiObject, so it cannot host pointer capture.
		local host = target.Parent
		if not host or not host:IsA("GuiObject") then
			return
		end
		local startPos = target.Position
		local raw = input.Position
		local originX, originY = PointerController.toHostLocal(host :: GuiObject, raw.X, raw.Y)
		PointerController.capture(host :: GuiObject, {
			initial = Vector2.new(originX, originY),
			onMove = function(x, y)
				local delta = Vector2.new(x - originX, y - originY)
				target.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end,
		})
	end)
end

function UiUtil.sectionColor(name: string): Color3
	local palette = {
		Data = Color3.fromRGB(90, 160, 220),
		Behavior = Color3.fromRGB(120, 200, 140),
		Appearance = Color3.fromRGB(220, 160, 90),
		Transform = Color3.fromRGB(180, 140, 220),
		Part = Color3.fromRGB(200, 120, 120),
		Health = Color3.fromRGB(230, 90, 90),
		Control = Color3.fromRGB(100, 190, 200),
		Display = Color3.fromRGB(220, 200, 100),
		Text = Color3.fromRGB(160, 180, 220),
		Audio = Color3.fromRGB(160, 120, 220),
		Camera = Color3.fromRGB(100, 160, 180),
		World = Color3.fromRGB(120, 180, 120),
		Streaming = Color3.fromRGB(100, 140, 200),
		Celestial = Color3.fromRGB(240, 200, 120),
		Fog = Color3.fromRGB(150, 160, 180),
		Attributes = Color3.fromRGB(180, 180, 120),
		Structure = Color3.fromRGB(120, 170, 210),
		Parts = Color3.fromRGB(210, 140, 100),
		Scripts = Color3.fromRGB(100, 200, 140),
		Values = Color3.fromRGB(200, 180, 100),
		Networking = Color3.fromRGB(140, 120, 220),
		UI = Color3.fromRGB(100, 180, 220),
		["Effects & Lights"] = Color3.fromRGB(230, 150, 80),
		Gameplay = Color3.fromRGB(220, 100, 120),
		Custom = Color3.fromRGB(80, 200, 170),
		Constraints = Color3.fromRGB(160, 140, 200),
		Animation = Color3.fromRGB(200, 120, 180),
		Physics = Color3.fromRGB(140, 200, 160),
	}
	local fallback: Color3
	if palette[name] then
		fallback = palette[name]
	else
		local h = 0
		for i = 1, #name do
			h = (h * 31 + string.byte(name, i)) % 360
		end
		fallback = Color3.fromHSV(h / 360, 0.45, 0.85)
	end
	local ok, Store = pcall(function()
		return require(script.Parent.Parent.Settings.Store)
	end)
	if ok and Store and Store.colorForSection then
		return Store.colorForSection(name, fallback)
	end
	return fallback
end

return UiUtil
