local Theme = require(script.Parent.Parent.Shared.Theme)
local UiUtil = require(script.Parent.Parent.Shared.UiUtil)
local IconCatalog = require(script.Parent.IconCatalog)

local IconPicker = {}

function IconPicker.open(parentGui: Instance, currentId: string?, onPick: (string) -> ())
	local overlay = Instance.new("Frame")
	overlay.Name = "IconPickerOverlay"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 200
	overlay.Parent = parentGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(280, 300)
	panel.BackgroundColor3 = Theme.bg
	panel.BorderSizePixel = 0
	panel.ZIndex = 201
	panel.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.borderLight
	stroke.Parent = panel

	local titleBar = Instance.new("Frame")
	titleBar.BackgroundTransparency = 1
	titleBar.Size = UDim2.new(1, 0, 0, 32)
	titleBar.ZIndex = 202
	titleBar.Active = true
	titleBar.Parent = panel
	UiUtil.makeDraggable(titleBar, panel)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -40, 1, 0)
	title.Position = UDim2.fromOffset(12, 0)
	title.Font = Theme.fontBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.textBright
	title.Text = "Choose Icon"
	title.ZIndex = 203
	title.Parent = titleBar

	local close = UiUtil.makeCloseButton(titleBar, 20)
	close.Position = UDim2.new(1, -26, 0, 6)
	close.ZIndex = 203
	close.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	local search = Instance.new("TextBox")
	search.PlaceholderText = "Filter..."
	search.ClearTextOnFocus = false
	search.Text = ""
	search.Font = Theme.font
	search.TextSize = 12
	search.TextColor3 = Theme.textBright
	search.PlaceholderColor3 = Theme.textMuted
	search.BackgroundColor3 = Theme.inputBg
	search.BorderSizePixel = 0
	search.Size = UDim2.new(1, -20, 0, 24)
	search.Position = UDim2.fromOffset(10, 34)
	search.ZIndex = 202
	search.Parent = panel

	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = Theme.corner
	searchCorner.Parent = search

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundColor3 = Theme.bgDeep
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(10, 64)
	scroll.Size = UDim2.new(1, -20, 1, -74)
	scroll.ScrollBarThickness = 5
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = 202
	scroll.Parent = panel

	local sc = Instance.new("UICorner")
	sc.CornerRadius = Theme.corner
	sc.Parent = scroll

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(56, 52)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = scroll

	local function rebuild(filter: string)
		for _, child in scroll:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local lower = string.lower(filter)
		for i, def in IconCatalog.list() do
			if
				lower == ""
				or string.find(string.lower(def.label), lower, 1, true)
				or string.find(string.lower(def.id), lower, 1, true)
				or string.find(string.lower(def.category or ""), lower, 1, true)
			then
				local btn = Instance.new("TextButton")
				btn.Name = def.id
				btn.Text = ""
				btn.AutoButtonColor = false
				btn.BackgroundColor3 = if def.id == currentId then Theme.bgSelectedMuted else Theme.bgRaised
				btn.BorderSizePixel = 0
				btn.LayoutOrder = i
				btn.ZIndex = 203
				btn.Parent = scroll

				local c = Instance.new("UICorner")
				c.CornerRadius = Theme.corner
				c.Parent = btn

				local icon = IconCatalog.createIconWidget(btn, def.id, 22)
				icon.AnchorPoint = Vector2.new(0.5, 0)
				icon.Position = UDim2.new(0.5, 0, 0, 4)
				IconCatalog.setZIndex(icon, 204)

				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.new(1, -2, 0, 14)
				label.Position = UDim2.new(0, 1, 1, -16)
				label.Font = Theme.font
				label.TextSize = 9
				label.TextColor3 = Theme.text
				label.TextTruncate = Enum.TextTruncate.AtEnd
				label.Text = def.label
				label.ZIndex = 204
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
	UiUtil.raiseZ(overlay, 200)
end

return IconPicker
