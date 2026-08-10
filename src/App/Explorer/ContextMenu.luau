local Theme = require(script.Parent.Parent.Shared.Theme)

local ContextMenu = {}

export type MenuItem = {
	label: string,
	danger: boolean?,
	disabled: boolean?,
	onClick: (() -> ())?,
	separator: boolean?,
}

function ContextMenu.open(host: Instance, screenPos: Vector2, items: { MenuItem })
	local existing = host:FindFirstChild("ContextMenuOverlay")
	if existing then
		existing:Destroy()
	end

	local overlay = Instance.new("Frame")
	overlay.Name = "ContextMenuOverlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 90
	overlay.Parent = host

	local hostGui = host :: GuiObject
	local localPos = screenPos - hostGui.AbsolutePosition

	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.BackgroundColor3 = Theme.bgRaised
	menu.BorderSizePixel = 0
	menu.AutomaticSize = Enum.AutomaticSize.Y
	menu.Size = UDim2.fromOffset(180, 0)
	menu.Position = UDim2.fromOffset(localPos.X, localPos.Y)
	menu.ZIndex = 91
	menu.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = menu

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.borderLight
	stroke.Thickness = 1
	stroke.Parent = menu

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 1)
	list.Parent = menu

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = menu

	local function close()
		overlay:Destroy()
	end

	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			task.defer(close)
		end
	end)

	for i, item in items do
		if item.separator then
			local sep = Instance.new("Frame")
			sep.BackgroundColor3 = Theme.borderLight
			sep.BorderSizePixel = 0
			sep.Size = UDim2.new(1, 0, 0, 1)
			sep.LayoutOrder = i
			sep.ZIndex = 92
			sep.Parent = menu
			continue
		end

		local btn = Instance.new("TextButton")
		btn.AutoButtonColor = false
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.Size = UDim2.new(1, 0, 0, 26)
		btn.Font = Theme.font
		btn.TextSize = 13
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Text = "  " .. item.label
		btn.TextColor3 = if item.disabled then Theme.textMuted elseif item.danger then Theme.danger else Theme.textBright
		btn.LayoutOrder = i
		btn.ZIndex = 92
		btn.Active = not item.disabled
		btn.Parent = menu

		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 4)
		bc.Parent = btn

		if not item.disabled then
			btn.MouseEnter:Connect(function()
				btn.BackgroundTransparency = 0
				btn.BackgroundColor3 = if item.danger then Color3.fromRGB(80, 40, 44) else Theme.bgHover
			end)
			btn.MouseLeave:Connect(function()
				btn.BackgroundTransparency = 1
			end)
			btn.MouseButton1Click:Connect(function()
				close()
				if item.onClick then
					item.onClick()
				end
			end)
		end
	end

	-- Keep on-screen
	task.defer(function()
		if not menu.Parent then
			return
		end
		local maxX = hostGui.AbsoluteSize.X - menu.AbsoluteSize.X - 4
		local maxY = hostGui.AbsoluteSize.Y - menu.AbsoluteSize.Y - 4
		menu.Position = UDim2.fromOffset(
			math.clamp(menu.Position.X.Offset, 4, math.max(4, maxX)),
			math.clamp(menu.Position.Y.Offset, 4, math.max(4, maxY))
		)
	end)

	return overlay
end

return ContextMenu
