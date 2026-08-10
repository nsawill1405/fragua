local Theme = require(script.Parent.Parent.Shared.Theme)

local ContextMenu = {}

export type MenuItem = {
	label: string,
	danger: boolean?,
	disabled: boolean?,
	onClick: (() -> ())?,
	separator: boolean?,
}

export type OpenAt = {
	-- row/button that was right-clicked (same AbsolutePosition space as host)
	anchor: GuiObject,
	-- optional window-space click from InputObject.Position
	clickPos: Vector2?,
}

function ContextMenu.open(host: Instance, items: { MenuItem }, at: OpenAt)
	local existing = host:FindFirstChild("ContextMenuOverlay")
	if existing then
		existing:Destroy()
	end

	local hostGui = host :: GuiObject
	local hostAbs = hostGui.AbsolutePosition
	local anchorAbs = at.anchor.AbsolutePosition
	local anchorSize = at.anchor.AbsoluteSize

	-- Prefer click offset within the anchor; fall back to middle of the row.
	-- Using AbsolutePosition deltas keeps PluginGui coords consistent (unlike GetMouseLocation).
	local localPos: Vector2
	if at.clickPos then
		local offsetInAnchor = at.clickPos - anchorAbs
		-- If clickPos space mismatches AbsolutePosition, offset will be wild; fall back.
		if
			offsetInAnchor.X < -8
			or offsetInAnchor.Y < -8
			or offsetInAnchor.X > anchorSize.X + 8
			or offsetInAnchor.Y > anchorSize.Y + 8
		then
			localPos = (anchorAbs - hostAbs) + Vector2.new(6, anchorSize.Y * 0.5)
		else
			localPos = (anchorAbs - hostAbs) + offsetInAnchor
		end
	else
		localPos = (anchorAbs - hostAbs) + Vector2.new(6, anchorSize.Y * 0.5)
	end

	local overlay = Instance.new("Frame")
	overlay.Name = "ContextMenuOverlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 200
	overlay.Active = true
	overlay.Parent = host

	local dismiss = Instance.new("TextButton")
	dismiss.Name = "Dismiss"
	dismiss.AutoButtonColor = false
	dismiss.Text = ""
	dismiss.BackgroundTransparency = 1
	dismiss.BorderSizePixel = 0
	dismiss.Size = UDim2.fromScale(1, 1)
	dismiss.ZIndex = 200
	dismiss.Active = false
	dismiss.Parent = overlay

	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.BackgroundColor3 = Theme.bgRaised
	menu.BorderSizePixel = 0
	menu.AutomaticSize = Enum.AutomaticSize.Y
	menu.Size = UDim2.fromOffset(168, 0)
	menu.Position = UDim2.fromOffset(localPos.X + 2, localPos.Y + 2)
	menu.ZIndex = 201
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
	list.Padding = UDim.new(0, 0)
	list.Parent = menu

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.PaddingLeft = UDim.new(0, 3)
	pad.PaddingRight = UDim.new(0, 3)
	pad.Parent = menu

	local function close()
		if overlay.Parent then
			overlay:Destroy()
		end
	end

	dismiss.MouseButton1Click:Connect(close)
	dismiss.MouseButton2Click:Connect(close)

	task.delay(0.15, function()
		if dismiss.Parent then
			dismiss.Active = true
		end
	end)

	for i, item in items do
		if item.separator then
			local sep = Instance.new("Frame")
			sep.BackgroundColor3 = Theme.borderLight
			sep.BorderSizePixel = 0
			sep.Size = UDim2.new(1, 0, 0, 1)
			sep.LayoutOrder = i
			sep.ZIndex = 202
			sep.Parent = menu
			continue
		end

		local btn = Instance.new("TextButton")
		btn.AutoButtonColor = false
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.Size = UDim2.new(1, 0, 0, 22)
		btn.Font = Theme.font
		btn.TextSize = 12
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Text = "  " .. item.label
		btn.TextColor3 = if item.disabled then Theme.textMuted elseif item.danger then Theme.danger else Theme.textBright
		btn.LayoutOrder = i
		btn.ZIndex = 202
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

	task.defer(function()
		if not menu.Parent then
			return
		end
		local menuSize = menu.AbsoluteSize
		local hostSize = hostGui.AbsoluteSize
		local x = localPos.X + 2
		local y = localPos.Y + 2
		-- flip if overflowing
		if x + menuSize.X > hostSize.X - 4 then
			x = math.max(4, localPos.X - menuSize.X - 2)
		end
		if y + menuSize.Y > hostSize.Y - 4 then
			y = math.max(4, localPos.Y - menuSize.Y - 2)
		end
		menu.Position = UDim2.fromOffset(math.max(4, x), math.max(4, y))
	end)

	return overlay
end

return ContextMenu
