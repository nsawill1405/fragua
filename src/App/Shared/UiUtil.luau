local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)

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
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = math.floor(px * 0.7)
	btn.Text = "✕"
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

function UiUtil.makeDraggable(handle: GuiObject, target: GuiObject)
	local dragging = false
	local dragStart: Vector2? = nil
	local startPos: UDim2? = nil

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPos = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	local moveConn = UserInputService.InputChanged:Connect(function(input)
		if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if not dragStart or not startPos then
			return
		end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
		target.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end)

	target.Destroying:Connect(function()
		moveConn:Disconnect()
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
	if palette[name] then
		return palette[name]
	end
	-- stable hash color
	local h = 0
	for i = 1, #name do
		h = (h * 31 + string.byte(name, i)) % 360
	end
	return Color3.fromHSV(h / 360, 0.45, 0.85)
end

return UiUtil
