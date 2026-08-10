local Theme = require(script.Parent.Parent.Shared.Theme)
local IconCatalog = require(script.Parent.IconCatalog)

local IconPicker = {}

function IconPicker.open(parentGui: Instance, currentId: string?, onPick: (string) -> ())
	local overlay = Instance.new("Frame")
	overlay.Name = "IconPickerOverlay"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 50
	overlay.Parent = parentGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 360)
	panel.BackgroundColor3 = Theme.bg
	panel.BorderSizePixel = 0
	panel.ZIndex = 51
	panel.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -80, 0, 32)
	title.Position = UDim2.fromOffset(12, 4)
	title.Font = Theme.fontBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.textBright
	title.Text = "Choose Icon"
	title.ZIndex = 52
	title.Parent = panel

	local close = Theme.makeButton(panel, "Close", { Name = "Close", Size = UDim2.fromOffset(64, 24) })
	close.Position = UDim2.new(1, -76, 0, 8)
	close.ZIndex = 52
	close.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.PlaceholderText = "Filter icons…"
	search.ClearTextOnFocus = false
	search.Text = ""
	search.Font = Theme.font
	search.TextSize = 14
	search.TextColor3 = Theme.textBright
	search.PlaceholderColor3 = Theme.textMuted
	search.BackgroundColor3 = Theme.inputBg
	search.BorderSizePixel = 0
	search.Size = UDim2.new(1, -24, 0, 28)
	search.Position = UDim2.fromOffset(12, 40)
	search.ZIndex = 52
	search.Parent = panel

	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = Theme.corner
	searchCorner.Parent = search

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Grid"
	scroll.BackgroundColor3 = Theme.bgDeep
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(12, 76)
	scroll.Size = UDim2.new(1, -24, 1, -88)
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = 52
	scroll.Parent = panel

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(72, 64)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = scroll

	local function rebuild(filter: string)
		for _, child in scroll:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local lower = string.lower(filter)
		for i, def in IconCatalog.list() do
			if lower == "" or string.find(string.lower(def.label), lower, 1, true) or string.find(string.lower(def.id), lower, 1, true) then
				local btn = Instance.new("TextButton")
				btn.Name = def.id
				btn.Text = ""
				btn.AutoButtonColor = false
				btn.BackgroundColor3 = if def.id == currentId then Theme.bgSelectedMuted else Theme.bgRaised
				btn.BorderSizePixel = 0
				btn.LayoutOrder = i
				btn.ZIndex = 53
				btn.Parent = scroll

				local c = Instance.new("UICorner")
				c.CornerRadius = Theme.corner
				c.Parent = btn

				local icon = IconCatalog.createIconWidget(btn, def.id, 28)
				icon.AnchorPoint = Vector2.new(0.5, 0)
				icon.Position = UDim2.new(0.5, 0, 0, 8)
				icon.ZIndex = 54

				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.new(1, -4, 0, 16)
				label.Position = UDim2.new(0, 2, 1, -20)
				label.Font = Theme.font
				label.TextSize = 11
				label.TextColor3 = Theme.text
				label.TextTruncate = Enum.TextTruncate.AtEnd
				label.Text = def.label
				label.ZIndex = 54
				label.Parent = btn

				btn.MouseButton1Click:Connect(function()
					onPick(def.id)
					overlay:Destroy()
				end)
			end
		end
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		rebuild(search.Text)
	end)
	rebuild("")

	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- click outside panel closes
		end
	end)
end

return IconPicker
