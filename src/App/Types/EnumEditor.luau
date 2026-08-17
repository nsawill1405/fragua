local Theme = require(script.Parent.Parent.Shared.Theme)
local UiUtil = require(script.Parent.Parent.Shared.UiUtil)
local TypeEditorLayout = require(script.Parent.TypeEditorLayout)
local EnumRegistry = require(script.Parent.EnumRegistry)

local EnumEditor = {}

local function robloxEnumNames(): { string }
	local names = {}
	local ok, enums = pcall(function()
		return Enum:GetEnums()
	end)
	if ok and enums then
		for _, enumType in enums do
			table.insert(names, enumType.Name)
		end
	end
	return names
end

function EnumEditor.open(host: Instance, onSaved: ((string) -> ())?, editId: string?)
	local editing = if editId then EnumRegistry.get(editId) else nil

	local overlay = Instance.new("Frame")
	overlay.Name = "EnumEditorOverlay"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 60
	overlay.Parent = host
	Theme.tween(overlay, { BackgroundTransparency = 0.35 }, Theme.tweenMed)

	local hostGui = host :: GuiObject
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(1, 1)
	panel.BackgroundColor3 = Theme.bg
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.ZIndex = 61
	panel.Parent = overlay

	local body: ScrollingFrame? = nil
	local footer: Frame? = nil
	local cancelButton: TextButton? = nil
	local saveButton: TextButton? = nil

	local function resizePanel()
		local geometry = TypeEditorLayout.geometry(hostGui.AbsoluteSize.X, hostGui.AbsoluteSize.Y)
		-- enum editor is shorter than the type editor
		local height = math.min(geometry.panel.height, 420)
		panel.Size = UDim2.fromOffset(math.min(geometry.panel.width, 420), height)
		if body then
			body.Position = UDim2.fromOffset(0, 112)
			body.Size = UDim2.new(1, 0, 1, -160)
		end
		if footer then
			footer.Position = UDim2.new(0, 0, 1, -48)
			footer.Size = UDim2.new(1, 0, 0, 48)
		end
		if cancelButton and saveButton then
			saveButton.Size = UDim2.fromOffset(geometry.saveWidth, 28)
			saveButton.Position = UDim2.new(1, -12, 1, -4)
			cancelButton.Size = UDim2.fromOffset(geometry.cancelWidth, 28)
			cancelButton.Position = UDim2.new(1, -12 - geometry.saveWidth - geometry.buttonGap, 1, -4)
		end
	end
	resizePanel()
	local resizeConnection = hostGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizePanel)
	overlay.Destroying:Once(function()
		resizeConnection:Disconnect()
	end)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.borderLight
	stroke.Parent = panel

	local titleBar = Instance.new("Frame")
	titleBar.BackgroundColor3 = Theme.bgDeep
	titleBar.BorderSizePixel = 0
	titleBar.Size = UDim2.new(1, 0, 0, 34)
	titleBar.ZIndex = 62
	titleBar.Active = true
	titleBar.Parent = panel
	local tbc = Instance.new("UICorner")
	tbc.CornerRadius = UDim.new(0, 10)
	tbc.Parent = titleBar
	UiUtil.makeDraggable(titleBar, panel)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 7)
	title.Size = UDim2.new(1, -40, 0, 20)
	title.Font = Theme.fontBold
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.textBright
	title.Text = if editing then "Edit Enum" else "New Enum"
	title.ZIndex = 63
	title.Parent = titleBar

	local close = UiUtil.makeCloseButton(titleBar, 20)
	close.Position = UDim2.new(1, -26, 0, 7)
	close.ZIndex = 63
	close.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(12, 42)
	nameLabel.Size = UDim2.new(1, -24, 0, 14)
	nameLabel.Font = Theme.font
	nameLabel.TextSize = 11
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Theme.textMuted
	nameLabel.Text = "Name"
	nameLabel.ZIndex = 62
	nameLabel.Parent = panel

	local nameBox = Instance.new("TextBox")
	nameBox.ClearTextOnFocus = false
	nameBox.PlaceholderText = "Mood"
	nameBox.PlaceholderColor3 = Theme.textMuted
	nameBox.Font = Theme.font
	nameBox.TextSize = 13
	nameBox.TextColor3 = Theme.textBright
	nameBox.BackgroundColor3 = Theme.inputBg
	nameBox.BorderSizePixel = 0
	nameBox.Position = UDim2.fromOffset(12, 58)
	nameBox.Size = UDim2.new(1, -24, 0, 28)
	nameBox.Text = if editing then editing.id else ""
	nameBox.ZIndex = 62
	nameBox.Parent = panel
	local nbc = Instance.new("UICorner")
	nbc.CornerRadius = Theme.corner
	nbc.Parent = nameBox
	if editing then
		nameBox.TextEditable = false
		nameBox.TextColor3 = Theme.textMuted
	end

	local itemsLabel = Instance.new("TextLabel")
	itemsLabel.BackgroundTransparency = 1
	itemsLabel.Position = UDim2.fromOffset(12, 94)
	itemsLabel.Size = UDim2.new(1, -24, 0, 14)
	itemsLabel.Font = Theme.font
	itemsLabel.TextSize = 11
	itemsLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemsLabel.TextColor3 = Theme.textMuted
	itemsLabel.Text = "Items"
	itemsLabel.ZIndex = 62
	itemsLabel.Parent = panel

	local propsScroll = Instance.new("ScrollingFrame")
	propsScroll.Name = "EnumEditorBody"
	propsScroll.BackgroundTransparency = 1
	propsScroll.BorderSizePixel = 0
	propsScroll.Position = UDim2.fromOffset(0, 112)
	propsScroll.Size = UDim2.new(1, 0, 1, -160)
	propsScroll.ScrollBarThickness = 4
	propsScroll.ScrollBarImageColor3 = Theme.borderLight
	propsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	propsScroll.CanvasSize = UDim2.new()
	propsScroll.ZIndex = 62
	propsScroll.Parent = panel
	body = propsScroll

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = propsScroll
	local listPad = Instance.new("UIPadding")
	listPad.PaddingLeft = UDim.new(0, 12)
	listPad.PaddingRight = UDim.new(0, 12)
	listPad.PaddingTop = UDim.new(0, 4)
	listPad.PaddingBottom = UDim.new(0, 8)
	listPad.Parent = propsScroll

	local itemBoxes: { TextBox } = {}

	local function addItemRow(value: string, layoutOrder: number)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 28)
		row.LayoutOrder = layoutOrder
		row.ZIndex = 62
		row.Parent = propsScroll

		local box = Instance.new("TextBox")
		box.ClearTextOnFocus = false
		box.PlaceholderText = "Item"
		box.PlaceholderColor3 = Theme.textMuted
		box.Font = Theme.font
		box.TextSize = 13
		box.TextColor3 = Theme.textBright
		box.BackgroundColor3 = Theme.inputBg
		box.BorderSizePixel = 0
		box.Size = UDim2.new(1, -28, 1, 0)
		box.Text = value
		box.ZIndex = 63
		box.Parent = row
		local bc = Instance.new("UICorner")
		bc.CornerRadius = Theme.corner
		bc.Parent = box
		table.insert(itemBoxes, box)

		local remove = Theme.iconButton(row, "x", 18)
		remove.AnchorPoint = Vector2.new(1, 0.5)
		remove.Position = UDim2.fromScale(1, 0.5)
		remove.ZIndex = 63
		remove.MouseButton1Click:Connect(function()
			local index = table.find(itemBoxes, box)
			if index then
				table.remove(itemBoxes, index)
			end
			row:Destroy()
		end)
	end

	local seedItems = if editing and #editing.items > 0 then editing.items else { "" }
	for index, item in seedItems do
		addItemRow(item, index)
	end

	local addItem = Theme.makeButton(propsScroll, "Add item", { Size = UDim2.new(1, 0, 0, 28) })
	addItem.LayoutOrder = 1000
	addItem.ZIndex = 62
	addItem.MouseButton1Click:Connect(function()
		addItemRow("", addItem.LayoutOrder - 1)
	end)

	local footerFrame = Instance.new("Frame")
	footerFrame.BackgroundColor3 = Theme.bgDeep
	footerFrame.BorderSizePixel = 0
	footerFrame.Position = UDim2.new(0, 0, 1, -48)
	footerFrame.Size = UDim2.new(1, 0, 0, 48)
	footerFrame.ZIndex = 62
	footerFrame.Parent = panel
	footer = footerFrame

	local errorLabel = Instance.new("TextLabel")
	errorLabel.BackgroundTransparency = 1
	errorLabel.Position = UDim2.fromOffset(12, 1)
	errorLabel.Size = UDim2.new(1, -24, 0, 14)
	errorLabel.Font = Theme.font
	errorLabel.TextSize = 11
	errorLabel.TextXAlignment = Enum.TextXAlignment.Left
	errorLabel.TextColor3 = Theme.danger
	errorLabel.Text = ""
	errorLabel.ZIndex = 62
	errorLabel.Parent = footerFrame

	local cancel = Theme.makeButton(footerFrame, "Cancel", { Size = UDim2.fromOffset(80, 28) })
	cancelButton = cancel
	cancel.AnchorPoint = Vector2.new(1, 1)
	cancel.ZIndex = 62
	cancel.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	local save = Theme.makeButton(
		footerFrame,
		if editing then "Save changes" else "Create",
		{ Size = UDim2.fromOffset(if editing then 108 else 80, 28) }
	)
	saveButton = save
	save.AnchorPoint = Vector2.new(1, 1)
	save.BackgroundColor3 = Theme.accent
	save.ZIndex = 62
	resizePanel()

	save.MouseButton1Click:Connect(function()
		local name = string.gsub(nameBox.Text, "^%s*(.-)%s*$", "%1")
		local items = {}
		for _, box in itemBoxes do
			if box.Parent then
				local item = string.gsub(box.Text, "^%s*(.-)%s*$", "%1")
				if item ~= "" then
					table.insert(items, item)
				end
			end
		end
		local def = {
			id = name,
			name = name,
			items = items,
		}
		local ok, message = EnumRegistry.validate(def, robloxEnumNames())
		if not ok then
			errorLabel.Text = message or "Invalid enum."
			return
		end
		if not editing and EnumRegistry.get(name) then
			errorLabel.Text = "That enum already exists."
			return
		end
		EnumRegistry.save(def)
		if onSaved then
			onSaved(name)
		end
		overlay:Destroy()
	end)
end

return EnumEditor
