local Theme = require(script.Parent.Parent.Shared.Theme)
local UiUtil = require(script.Parent.Parent.Shared.UiUtil)
local Util = require(script.Parent.Parent.Shared.Util)
local EngineSchemas = require(script.Parent.EngineSchemas)
local IconCatalog = require(script.Parent.IconCatalog)
local IconPicker = require(script.Parent.IconPicker)
local Registry = require(script.Parent.Registry)
local TypeDraft = require(script.Parent.TypeDraft)
local TypeEditorLayout = require(script.Parent.TypeEditorLayout)

local TypeEditor = {}

local NONE_LABEL = "None"
local VALUE_TYPES = { "string", "number", "boolean", "Color3", "Vector3" }

type PropDraft = {
	name: string,
	valueType: string,
	defaultText: string,
	category: string,
}

local function extendsChoices(excludeId: string?): { string }
	local items = { NONE_LABEL }
	local seen = { [NONE_LABEL] = true, [""] = true }
	for _, def in Registry.list() do
		if def.id ~= excludeId and not seen[def.id] then
			seen[def.id] = true
			table.insert(items, def.id)
		end
	end
	for _, className in EngineSchemas.insertable() do
		if not seen[className] then
			seen[className] = true
			table.insert(items, className)
		end
	end
	for _, className in EngineSchemas.baseClasses() do
		if not seen[className] then
			seen[className] = true
			table.insert(items, className)
		end
	end
	return items
end

local function iconForExtends(item: string): string
	if item == NONE_LABEL then
		return "emoji_cross"
	end
	local custom = Registry.get(item)
	if custom then
		return custom.icon
	end
	return "class_" .. item
end

local function displayExtends(value: string): string
	if value == "" or value == "Configuration" then
		return NONE_LABEL
	end
	return value
end

local function storeExtends(display: string): string
	if display == NONE_LABEL or display == "" then
		return "Configuration"
	end
	return display
end

local function defaultTextFor(value: any, valueType: string): string
	if valueType == "boolean" then
		return if value then "true" else "false"
	elseif typeof(value) == "Color3" then
		return string.format(
			"%d,%d,%d",
			math.floor(value.R * 255 + 0.5),
			math.floor(value.G * 255 + 0.5),
			math.floor(value.B * 255 + 0.5)
		)
	elseif typeof(value) == "Vector3" then
		return string.format("%.2f,%.2f,%.2f", value.X, value.Y, value.Z)
	elseif value == nil then
		if valueType == "number" then
			return "0"
		elseif valueType == "boolean" then
			return "false"
		elseif valueType == "Color3" then
			return "255,255,255"
		elseif valueType == "Vector3" then
			return "0,0,0"
		end
		return ""
	end
	return tostring(value)
end

function TypeEditor.open(host: Instance, onSaved: ((string) -> (boolean?, string?))?, editId: string?)
	local editing = editId and Registry.get(editId) or nil

	local overlay = Instance.new("Frame")
	overlay.Name = "TypeEditorOverlay"
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

	local function resizePanel()
		local size = TypeEditorLayout.panelSize(hostGui.AbsoluteSize.X, hostGui.AbsoluteSize.Y)
		panel.Size = UDim2.fromOffset(size.width, size.height)
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
	title.Text = if editing then "Edit Type" else "New Type"
	title.ZIndex = 63
	title.Parent = titleBar

	local close = UiUtil.makeCloseButton(titleBar, 20)
	close.Position = UDim2.new(1, -26, 0, 7)
	close.ZIndex = 63
	close.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	-- top fields
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(12, 42)
	nameLabel.Size = UDim2.fromOffset(80, 14)
	nameLabel.Font = Theme.font
	nameLabel.TextSize = 11
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Theme.textMuted
	nameLabel.Text = "Name"
	nameLabel.ZIndex = 62
	nameLabel.Parent = panel

	local nameBox = Instance.new("TextBox")
	nameBox.ClearTextOnFocus = false
	nameBox.PlaceholderText = "Zombie"
	nameBox.PlaceholderColor3 = Theme.textMuted
	nameBox.Font = Theme.font
	nameBox.TextSize = 13
	nameBox.TextColor3 = Theme.textBright
	nameBox.BackgroundColor3 = Theme.inputBg
	nameBox.BorderSizePixel = 0
	nameBox.Position = UDim2.fromOffset(12, 58)
	nameBox.Size = UDim2.new(0.5, -18, 0, 28)
	nameBox.Text = ""
	nameBox.ZIndex = 62
	nameBox.Parent = panel
	local nbc = Instance.new("UICorner")
	nbc.CornerRadius = Theme.corner
	nbc.Parent = nameBox

	local extendsLabel = Instance.new("TextLabel")
	extendsLabel.BackgroundTransparency = 1
	extendsLabel.Position = UDim2.new(0.5, 6, 0, 42)
	extendsLabel.Size = UDim2.new(0.5, -18, 0, 14)
	extendsLabel.Font = Theme.font
	extendsLabel.TextSize = 11
	extendsLabel.TextXAlignment = Enum.TextXAlignment.Left
	extendsLabel.TextColor3 = Theme.textMuted
	extendsLabel.Text = "Extends"
	extendsLabel.ZIndex = 62
	extendsLabel.Parent = panel

	local selectedExtends = NONE_LABEL
	local rebuildProps: (() -> ())? = nil
	local extendsBtn = Instance.new("TextButton")
	extendsBtn.AutoButtonColor = false
	extendsBtn.BackgroundColor3 = Theme.inputBg
	extendsBtn.BorderSizePixel = 0
	extendsBtn.Position = UDim2.new(0.5, 6, 0, 58)
	extendsBtn.Size = UDim2.new(0.5, -18, 0, 28)
	extendsBtn.Text = ""
	extendsBtn.ZIndex = 62
	extendsBtn.Parent = panel
	local ebc = Instance.new("UICorner")
	ebc.CornerRadius = Theme.corner
	ebc.Parent = extendsBtn

	local extendsIcon = IconCatalog.createIconWidget(extendsBtn, iconForExtends(NONE_LABEL), 16)
	extendsIcon.Position = UDim2.fromOffset(8, 6)
	IconCatalog.setZIndex(extendsIcon, 63)

	local extendsText = Instance.new("TextLabel")
	extendsText.BackgroundTransparency = 1
	extendsText.Position = UDim2.fromOffset(30, 0)
	extendsText.Size = UDim2.new(1, -42, 1, 0)
	extendsText.Font = Theme.font
	extendsText.TextSize = 13
	extendsText.TextXAlignment = Enum.TextXAlignment.Left
	extendsText.TextColor3 = Theme.textBright
	extendsText.Text = NONE_LABEL .. "  v"
	extendsText.ZIndex = 63
	extendsText.Parent = extendsBtn

	local function setExtendsDisplay(item: string)
		selectedExtends = item
		extendsText.Text = item .. "  v"
		extendsIcon:SetAttribute("IconId", iconForExtends(item))
		if rebuildProps then
			rebuildProps()
		end
	end

	local dropOpen = false
	local dropFrame: ScrollingFrame? = nil
	local function closeDrop()
		dropOpen = false
		if dropFrame then
			dropFrame:Destroy()
			dropFrame = nil
		end
	end

	extendsBtn.MouseButton1Click:Connect(function()
		if dropOpen then
			closeDrop()
			return
		end
		dropOpen = true
		local drop = Instance.new("ScrollingFrame")
		drop.Name = "ExtendsMenu"
		drop.BackgroundColor3 = Theme.bgRaised
		drop.BorderSizePixel = 0
		drop.ScrollBarThickness = 4
		drop.AutomaticCanvasSize = Enum.AutomaticSize.Y
		drop.CanvasSize = UDim2.new()
		drop.ZIndex = 90
		drop.Parent = panel
		local dc = Instance.new("UICorner")
		dc.CornerRadius = Theme.corner
		dc.Parent = drop
		local ds = Instance.new("UIStroke")
		ds.Color = Theme.borderLight
		ds.Parent = drop
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = drop
		UiUtil.placeDropdown(panel, extendsBtn, drop, math.max(180, extendsBtn.AbsoluteSize.X), 220)
		dropFrame = drop

		local filter = Instance.new("TextBox")
		filter.ClearTextOnFocus = false
		filter.PlaceholderText = "Filter..."
		filter.PlaceholderColor3 = Theme.textMuted
		filter.BackgroundColor3 = Theme.inputBg
		filter.BorderSizePixel = 0
		filter.Size = UDim2.new(1, -8, 0, 26)
		filter.Font = Theme.font
		filter.TextSize = 12
		filter.TextColor3 = Theme.textBright
		filter.Text = ""
		filter.LayoutOrder = 0
		filter.ZIndex = 91
		filter.Parent = drop
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0, 4)
		fc.Parent = filter

		local choices = extendsChoices(if editing then editing.id else nil)
		local rows: { TextButton } = {}

		local function rebuildRows(query: string)
			for _, r in rows do
				r:Destroy()
			end
			table.clear(rows)
			local q = string.lower(query)
			local order = 1
			for _, item in choices do
				if q == "" or string.find(string.lower(item), q, 1, true) then
					local row = Instance.new("TextButton")
					row.AutoButtonColor = false
					row.BackgroundTransparency = 1
					row.BorderSizePixel = 0
					row.Size = UDim2.new(1, -4, 0, 26)
					row.Text = ""
					row.LayoutOrder = order
					row.ZIndex = 91
					row.Parent = drop

					local icon = IconCatalog.createIconWidget(row, iconForExtends(item), 14)
					icon.Position = UDim2.fromOffset(6, 6)
					IconCatalog.setZIndex(icon, 92)

					local label = Instance.new("TextLabel")
					label.BackgroundTransparency = 1
					label.Position = UDim2.fromOffset(26, 0)
					label.Size = UDim2.new(1, -30, 1, 0)
					label.Font = Theme.font
					label.TextSize = 12
					label.TextXAlignment = Enum.TextXAlignment.Left
					label.TextColor3 = Theme.textBright
					label.Text = item
					label.ZIndex = 92
					label.Parent = row

					row.MouseEnter:Connect(function()
						row.BackgroundTransparency = 0
						row.BackgroundColor3 = Theme.bgHover
					end)
					row.MouseLeave:Connect(function()
						row.BackgroundTransparency = 1
					end)
					row.MouseButton1Click:Connect(function()
						setExtendsDisplay(item)
						closeDrop()
					end)
					table.insert(rows, row)
					order += 1
				end
			end
		end

		filter:GetPropertyChangedSignal("Text"):Connect(function()
			rebuildRows(filter.Text)
		end)
		rebuildRows("")
		filter:CaptureFocus()
	end)

	-- icon row
	local iconLabel = Instance.new("TextLabel")
	iconLabel.BackgroundTransparency = 1
	iconLabel.Position = UDim2.fromOffset(12, 94)
	iconLabel.Size = UDim2.fromOffset(40, 14)
	iconLabel.Font = Theme.font
	iconLabel.TextSize = 11
	iconLabel.TextXAlignment = Enum.TextXAlignment.Left
	iconLabel.TextColor3 = Theme.textMuted
	iconLabel.Text = "Icon"
	iconLabel.ZIndex = 62
	iconLabel.Parent = panel

	local selectedIcon = "emoji_package"
	local iconPreview = IconCatalog.createIconWidget(panel, selectedIcon, 22)
	iconPreview.Position = UDim2.fromOffset(12, 112)
	IconCatalog.setZIndex(iconPreview, 62)

	local iconBtn = Theme.makeButton(panel, "Choose...", { Size = UDim2.fromOffset(84, 26) })
	iconBtn.Position = UDim2.fromOffset(42, 110)
	iconBtn.ZIndex = 62
	iconBtn.MouseButton1Click:Connect(function()
		closeDrop()
		IconPicker.open(host, selectedIcon, function(id)
			selectedIcon = id
			iconPreview:SetAttribute("IconId", id)
		end)
	end)

	-- properties manager
	local propsHeader = Instance.new("TextLabel")
	propsHeader.BackgroundTransparency = 1
	propsHeader.Position = UDim2.fromOffset(12, 146)
	propsHeader.Size = UDim2.new(1, -24, 0, 16)
	propsHeader.Font = Theme.fontBold
	propsHeader.TextSize = 12
	propsHeader.TextXAlignment = Enum.TextXAlignment.Left
	propsHeader.TextColor3 = Theme.textMuted
	propsHeader.Text = "PROPERTIES & SEGMENTS"
	propsHeader.ZIndex = 62
	propsHeader.Parent = panel

	local propsScroll = Instance.new("ScrollingFrame")
	propsScroll.BackgroundColor3 = Theme.bgDeep
	propsScroll.BorderSizePixel = 0
	propsScroll.Position = UDim2.fromOffset(12, 166)
	-- leave room for +segment / error / cancel / save at bottom
	propsScroll.Size = UDim2.new(1, -24, 1, -214)
	propsScroll.ScrollBarThickness = 5
	propsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	propsScroll.CanvasSize = UDim2.new()
	propsScroll.ZIndex = 62
	propsScroll.Parent = panel
	local psc = Instance.new("UICorner")
	psc.CornerRadius = Theme.corner
	psc.Parent = propsScroll
	local propsList = Instance.new("UIListLayout")
	propsList.Padding = UDim.new(0, 6)
	propsList.SortOrder = Enum.SortOrder.LayoutOrder
	propsList.Parent = propsScroll
	local propsPad = Instance.new("UIPadding")
	propsPad.PaddingTop = UDim.new(0, 8)
	propsPad.PaddingBottom = UDim.new(0, 8)
	propsPad.PaddingLeft = UDim.new(0, 8)
	propsPad.PaddingRight = UDim.new(0, 8)
	propsPad.Parent = propsScroll

	-- drafts: ordered categories + props
	local categoryOrder: { string } = { "Data" }
	local propsByCat: { [string]: { PropDraft } } = { Data = {} }

	local function ensureCategory(name: string)
		if not propsByCat[name] then
			propsByCat[name] = {}
			table.insert(categoryOrder, name)
		end
	end

	if editing then
		for _, prop in editing.properties do
			local cat = prop.category or "Data"
			ensureCategory(cat)
			table.insert(propsByCat[cat], {
				name = prop.name,
				valueType = prop.valueType or "string",
				defaultText = defaultTextFor(prop.default, prop.valueType or "string"),
				category = cat,
			})
		end
		if #editing.properties == 0 then
			ensureCategory("Data")
		end
	else
		propsByCat.Data = {
			{ name = "IsHostile", valueType = "boolean", defaultText = "true", category = "Data" },
			{ name = "DetectRange", valueType = "number", defaultText = "40", category = "Data" },
		}
	end

	rebuildProps = function()
		for _, child in propsScroll:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local order = 1
		for _, catName in categoryOrder do
			local props = propsByCat[catName]
			if not props then
				continue
			end

			local section = Instance.new("Frame")
			section.BackgroundColor3 = Theme.bgRaised
			section.BackgroundTransparency = 0.35
			section.BorderSizePixel = 0
			section.Size = UDim2.new(1, 0, 0, 40)
			section.AutomaticSize = Enum.AutomaticSize.None
			section.ClipsDescendants = true
			section.LayoutOrder = order
			section.ZIndex = 63
			section.Parent = propsScroll
			local sc = Instance.new("UICorner")
			sc.CornerRadius = UDim.new(0, 6)
			sc.Parent = section
			local accent = Instance.new("Frame")
			accent.BackgroundColor3 = UiUtil.sectionColor(catName)
			accent.BorderSizePixel = 0
			accent.Size = UDim2.fromOffset(3, 34)
			accent.Position = UDim2.fromOffset(0, 3)
			accent.ZIndex = 64
			accent.Parent = section

			local sectionList = Instance.new("UIListLayout")
			sectionList.Padding = UDim.new(0, 4)
			sectionList.SortOrder = Enum.SortOrder.LayoutOrder
			sectionList.Parent = section
			local sectionPad = Instance.new("UIPadding")
			sectionPad.PaddingTop = UDim.new(0, 4)
			sectionPad.PaddingBottom = UDim.new(0, 4)
			sectionPad.PaddingLeft = UDim.new(0, 10)
			sectionPad.PaddingRight = UDim.new(0, 6)
			sectionPad.Parent = section

			local function resizeSection()
				local height = math.max(40, sectionList.AbsoluteContentSize.Y + 8)
				section.Size = UDim2.new(1, 0, 0, height)
				accent.Size = UDim2.fromOffset(3, math.max(18, height - 6))
			end
			sectionList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeSection)
			task.defer(resizeSection)

			local header = Instance.new("Frame")
			header.BackgroundTransparency = 1
			header.Size = UDim2.new(1, 0, 0, 24)
			header.LayoutOrder = 0
			header.ZIndex = 64
			header.Parent = section

			local catBox = Instance.new("TextBox")
			catBox.ClearTextOnFocus = false
			catBox.BackgroundColor3 = Theme.inputBg
			catBox.BorderSizePixel = 0
			catBox.Size = UDim2.new(1, -56, 0, 22)
			catBox.Font = Theme.fontBold
			catBox.TextSize = 12
			catBox.TextColor3 = Theme.textBright
			catBox.Text = catName
			catBox.ZIndex = 65
			catBox.Parent = header
			local cbc = Instance.new("UICorner")
			cbc.CornerRadius = UDim.new(0, 4)
			cbc.Parent = catBox

			local capturedCat = catName
			catBox.FocusLost:Connect(function()
				local newName = string.gsub(catBox.Text, "^%s*(.-)%s*$", "%1")
				if newName == "" or newName == capturedCat then
					catBox.Text = capturedCat
					return
				end
				if propsByCat[newName] and newName ~= capturedCat then
					catBox.Text = capturedCat
					return
				end
				propsByCat[newName] = propsByCat[capturedCat]
				propsByCat[capturedCat] = nil
				for i, n in categoryOrder do
					if n == capturedCat then
						categoryOrder[i] = newName
						break
					end
				end
				for _, p in propsByCat[newName] do
					p.category = newName
				end
				rebuildProps()
			end)

			local addProp = Instance.new("TextButton")
			addProp.AutoButtonColor = false
			addProp.BackgroundTransparency = 1
			addProp.AnchorPoint = Vector2.new(1, 0)
			addProp.Position = UDim2.new(1, -22, 0, 0)
			addProp.Size = UDim2.fromOffset(20, 22)
			addProp.Font = Enum.Font.SourceSansBold
			addProp.TextSize = 16
			addProp.Text = "+"
			addProp.TextColor3 = Theme.accent
			addProp.ZIndex = 65
			addProp.Parent = header
			addProp.MouseButton1Click:Connect(function()
				table.insert(propsByCat[capturedCat], {
					name = "NewProp",
					valueType = "string",
					defaultText = "",
					category = capturedCat,
				})
				rebuildProps()
			end)

			local delCat = Instance.new("TextButton")
			delCat.AutoButtonColor = false
			delCat.BackgroundTransparency = 1
			delCat.AnchorPoint = Vector2.new(1, 0)
			delCat.Position = UDim2.fromScale(1, 0)
			delCat.Size = UDim2.fromOffset(20, 22)
			delCat.Font = Enum.Font.SourceSansBold
			delCat.TextSize = 16
			delCat.Text = "x"
			delCat.TextColor3 = Theme.textMuted
			delCat.ZIndex = 65
			delCat.Parent = header
			delCat.MouseButton1Click:Connect(function()
				if #categoryOrder <= 1 then
					propsByCat[capturedCat] = {}
				else
					propsByCat[capturedCat] = nil
					local idx = table.find(categoryOrder, capturedCat)
					if idx then
						table.remove(categoryOrder, idx)
					end
				end
				rebuildProps()
			end)

			for pi, prop in props do
				local row = Instance.new("Frame")
				row.BackgroundTransparency = 1
				row.Size = UDim2.new(1, 0, 0, 24)
				row.LayoutOrder = pi
				row.ZIndex = 64
				row.Parent = section

				local nameField = Instance.new("TextBox")
				nameField.ClearTextOnFocus = false
				nameField.BackgroundColor3 = Theme.inputBg
				nameField.BorderSizePixel = 0
				nameField.Size = UDim2.new(0.34, -4, 0, 22)
				nameField.Font = Theme.font
				nameField.TextSize = 12
				nameField.TextColor3 = Theme.textBright
				nameField.Text = prop.name
				nameField.ZIndex = 65
				nameField.Parent = row
				local nfc = Instance.new("UICorner")
				nfc.CornerRadius = UDim.new(0, 4)
				nfc.Parent = nameField
				nameField.FocusLost:Connect(function()
					prop.name = string.gsub(nameField.Text, "^%s*(.-)%s*$", "%1")
					nameField.Text = prop.name
				end)

				local defField: TextBox
				local typeBtn = Instance.new("TextButton")
				typeBtn.AutoButtonColor = false
				typeBtn.BackgroundColor3 = Theme.inputBg
				typeBtn.BorderSizePixel = 0
				typeBtn.Position = UDim2.new(0.34, 2, 0, 0)
				typeBtn.Size = UDim2.new(0.22, -4, 0, 22)
				typeBtn.Font = Theme.font
				typeBtn.TextSize = 11
				typeBtn.TextColor3 = Theme.accent
				typeBtn.Text = prop.valueType .. " v"
				typeBtn.ZIndex = 65
				typeBtn.Parent = row
				local tfc = Instance.new("UICorner")
				tfc.CornerRadius = UDim.new(0, 4)
				tfc.Parent = typeBtn
				typeBtn.MouseButton1Click:Connect(function()
					local existing = panel:FindFirstChild("ValueTypeMenu")
					if existing then
						existing:Destroy()
						return
					end
					local drop = Instance.new("ScrollingFrame")
					drop.Name = "ValueTypeMenu"
					drop.BackgroundColor3 = Theme.bgRaised
					drop.BorderSizePixel = 0
					drop.ZIndex = 95
					drop.ScrollBarThickness = 4
					drop.AutomaticCanvasSize = Enum.AutomaticSize.Y
					drop.CanvasSize = UDim2.new()
					drop.Parent = panel
					local dc = Instance.new("UICorner")
					dc.CornerRadius = UDim.new(0, 6)
					dc.Parent = drop
					local ds = Instance.new("UIStroke")
					ds.Color = Theme.borderLight
					ds.Parent = drop
					local list = Instance.new("UIListLayout")
					list.SortOrder = Enum.SortOrder.LayoutOrder
					list.Parent = drop
					local pad = Instance.new("UIPadding")
					pad.PaddingTop = UDim.new(0, 4)
					pad.PaddingBottom = UDim.new(0, 4)
					pad.PaddingLeft = UDim.new(0, 4)
					pad.PaddingRight = UDim.new(0, 4)
					pad.Parent = drop
					UiUtil.placeDropdown(panel, typeBtn, drop, math.max(110, typeBtn.AbsoluteSize.X), 140)
					for i, vt in VALUE_TYPES do
						local opt = Instance.new("TextButton")
						opt.AutoButtonColor = false
						opt.BackgroundTransparency = if vt == prop.valueType then 0.3 else 1
						opt.BackgroundColor3 = if vt == prop.valueType then Theme.accentSoft else Theme.bgDeep
						opt.BorderSizePixel = 0
						opt.Size = UDim2.new(1, 0, 0, 22)
						opt.Font = Theme.font
						opt.TextSize = 12
						opt.TextColor3 = Theme.textBright
						opt.TextXAlignment = Enum.TextXAlignment.Left
						opt.Text = "  " .. vt
						opt.LayoutOrder = i
						opt.ZIndex = 96
						opt.Parent = drop
						opt.MouseButton1Click:Connect(function()
							prop.valueType = vt
							typeBtn.Text = vt .. " v"
							prop.defaultText = defaultTextFor(nil, vt)
							defField.Text = prop.defaultText
							drop:Destroy()
						end)
					end
				end)

				defField = Instance.new("TextBox")
				defField.ClearTextOnFocus = false
				defField.BackgroundColor3 = Theme.inputBg
				defField.BorderSizePixel = 0
				defField.Position = UDim2.new(0.56, 2, 0, 0)
				defField.Size = UDim2.new(0.36, -24, 0, 22)
				defField.Font = Theme.fontMono
				defField.TextSize = 11
				defField.TextColor3 = Theme.textBright
				defField.Text = prop.defaultText
				defField.PlaceholderText = "default"
				defField.PlaceholderColor3 = Theme.textMuted
				defField.ZIndex = 65
				defField.Parent = row
				local dfc = Instance.new("UICorner")
				dfc.CornerRadius = UDim.new(0, 4)
				dfc.Parent = defField
				defField.FocusLost:Connect(function()
					prop.defaultText = defField.Text
				end)

				local del = Instance.new("TextButton")
				del.AutoButtonColor = false
				del.BackgroundTransparency = 1
				del.AnchorPoint = Vector2.new(1, 0)
				del.Position = UDim2.fromScale(1, 0)
				del.Size = UDim2.fromOffset(20, 24)
				del.Font = Enum.Font.SourceSansBold
				del.TextSize = 14
				del.Text = "x"
				del.TextColor3 = Theme.textMuted
				del.ZIndex = 65
				del.Parent = row
				del.MouseButton1Click:Connect(function()
					local currentList = propsByCat[capturedCat]
					local propIndex = currentList and table.find(currentList, prop)
					if currentList and propIndex then
						table.remove(currentList, propIndex)
					end
					rebuildProps()
				end)
				del.MouseEnter:Connect(function()
					del.TextColor3 = Theme.danger
				end)
				del.MouseLeave:Connect(function()
					del.TextColor3 = Theme.textMuted
				end)
			end

			order += 1
		end

		local directProperties = {}
		for _, catName in categoryOrder do
			for _, property in propsByCat[catName] or {} do
				table.insert(directProperties, {
					name = property.name,
					valueType = property.valueType,
					default = property.defaultText,
					category = catName,
				})
			end
		end
		local draftDefinition = {
			id = if editing then editing.id else "__FraguaDraft",
			name = if editing then editing.name else "Draft",
			description = "",
			extends = storeExtends(selectedExtends),
			icon = selectedIcon,
			properties = directProperties,
		}
		local inheritedByOrigin = {}
		local inheritedOrder = {}
		for _, property in Registry.resolvedSchema(draftDefinition) do
			if property.inherited then
				local origin = property.origin or draftDefinition.extends
				if not inheritedByOrigin[origin] then
					inheritedByOrigin[origin] = {}
					table.insert(inheritedOrder, origin)
				end
				table.insert(inheritedByOrigin[origin], property)
			end
		end

		for _, origin in inheritedOrder do
			local inherited = inheritedByOrigin[origin]
			local section = Instance.new("Frame")
			section.BackgroundColor3 = Theme.bgRaised
			section.BackgroundTransparency = 0.65
			section.BorderSizePixel = 0
			section.Size = UDim2.new(1, 0, 0, 38 + #inherited * 26)
			section.LayoutOrder = order
			section.ZIndex = 63
			section.Parent = propsScroll
			local inheritedCorner = Instance.new("UICorner")
			inheritedCorner.CornerRadius = Theme.radius.control
			inheritedCorner.Parent = section
			local list = Instance.new("UIListLayout")
			list.Padding = UDim.new(0, 2)
			list.SortOrder = Enum.SortOrder.LayoutOrder
			list.Parent = section
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, 6)
			padding.PaddingBottom = UDim.new(0, 6)
			padding.PaddingLeft = UDim.new(0, 10)
			padding.PaddingRight = UDim.new(0, 8)
			padding.Parent = section

			local header = Instance.new("TextLabel")
			header.BackgroundTransparency = 1
			header.Size = UDim2.new(1, 0, 0, 22)
			header.Font = Theme.fontBold
			header.TextSize = 11
			header.TextXAlignment = Enum.TextXAlignment.Left
			header.TextColor3 = Theme.textMuted
			header.Text = `INHERITED FROM {string.upper(origin)}`
			header.LayoutOrder = 0
			header.ZIndex = 64
			header.Parent = section

			for index, property in inherited do
				local row = Instance.new("Frame")
				row.BackgroundColor3 = Theme.bgDeep
				row.BackgroundTransparency = 0.45
				row.BorderSizePixel = 0
				row.Size = UDim2.new(1, 0, 0, 24)
				row.LayoutOrder = index
				row.ZIndex = 64
				row.Parent = section
				local rowCorner = Instance.new("UICorner")
				rowCorner.CornerRadius = UDim.new(0, 4)
				rowCorner.Parent = row

				local name = Instance.new("TextLabel")
				name.BackgroundTransparency = 1
				name.Position = UDim2.fromOffset(8, 0)
				name.Size = UDim2.new(0.46, -8, 1, 0)
				name.Font = Theme.font
				name.TextSize = 11
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.TextColor3 = Theme.text
				name.Text = property.name
				name.ZIndex = 65
				name.Parent = row

				local meta = Instance.new("TextLabel")
				meta.BackgroundTransparency = 1
				meta.Position = UDim2.fromScale(0.46, 0)
				meta.Size = UDim2.new(0.54, -8, 1, 0)
				meta.Font = Theme.fontMono
				meta.TextSize = 10
				meta.TextXAlignment = Enum.TextXAlignment.Right
				meta.TextColor3 = Theme.textMuted
				meta.TextTruncate = Enum.TextTruncate.AtEnd
				meta.Text = `{property.valueType or "value"}  {defaultTextFor(property.default, property.valueType)}`
				meta.ZIndex = 65
				meta.Parent = row
			end

			local function resizeInherited()
				section.Size = UDim2.new(1, 0, 0, math.max(38, list.AbsoluteContentSize.Y + 12))
			end
			list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeInherited)
			task.defer(resizeInherited)
			order += 1
		end
	end

	rebuildProps()

	local addSectionBtn = Theme.makeButton(panel, "+ Segment", { Size = UDim2.fromOffset(96, 26) })
	addSectionBtn.Position = UDim2.fromOffset(12, 1)
	addSectionBtn.AnchorPoint = Vector2.new(0, 1)
	addSectionBtn.Position = UDim2.new(0, 12, 1, -48)
	addSectionBtn.ZIndex = 62
	addSectionBtn.MouseButton1Click:Connect(function()
		local base = "Custom"
		local name = base
		local n = 1
		while propsByCat[name] do
			n += 1
			name = base .. tostring(n)
		end
		ensureCategory(name)
		rebuildProps()
	end)

	local errorLabel = Instance.new("TextLabel")
	errorLabel.BackgroundTransparency = 1
	errorLabel.Position = UDim2.new(0, 120, 1, -72)
	errorLabel.Size = UDim2.new(1, -132, 0, 18)
	errorLabel.Font = Theme.font
	errorLabel.TextSize = 11
	errorLabel.TextXAlignment = Enum.TextXAlignment.Left
	errorLabel.TextColor3 = Theme.danger
	errorLabel.Text = ""
	errorLabel.ZIndex = 62
	errorLabel.Parent = panel

	local cancel = Theme.makeButton(panel, "Cancel", { Size = UDim2.fromOffset(80, 28) })
	cancel.AnchorPoint = Vector2.new(1, 1)
	cancel.Position = UDim2.new(1, -100, 1, -14)
	cancel.ZIndex = 62
	cancel.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	local save = Theme.makeButton(
		panel,
		if editing then "Save changes" else "Create & insert",
		{ Size = UDim2.fromOffset(if editing then 108 else 116, 28) }
	)
	save.AnchorPoint = Vector2.new(1, 1)
	save.Position = UDim2.new(1, -12, 1, -14)
	save.BackgroundColor3 = Theme.accent
	save.ZIndex = 62

	if editing then
		nameBox.Text = editing.id
		nameBox.TextEditable = false
		nameBox.TextColor3 = Theme.textMuted
		setExtendsDisplay(displayExtends(editing.extends))
		selectedIcon = editing.icon
		iconPreview:SetAttribute("IconId", selectedIcon)
	end

	save.MouseButton1Click:Connect(function()
		local name = string.gsub(nameBox.Text, "^%s*(.-)%s*$", "%1")
		if name == "" or not string.match(name, "^[%a_][%w_]*$") then
			errorLabel.Text = "Use a valid identifier name."
			return
		end
		if not editing and Registry.get(name) then
			errorLabel.Text = "That type already exists."
			return
		end

		local validationDraft = TypeDraft.new(name, storeExtends(selectedExtends))
		for _, catName in categoryOrder do
			local categoryId = TypeDraft.addCategory(validationDraft, catName)
			for _, prop in propsByCat[catName] or {} do
				TypeDraft.addProperty(
					validationDraft,
					categoryId,
					string.gsub(prop.name, "^%s*(.-)%s*$", "%1"),
					prop.valueType,
					prop.defaultText or ""
				)
			end
		end
		local validationErrors = TypeDraft.validate(validationDraft, Registry.get)
		if #validationErrors > 0 then
			errorLabel.Text = validationErrors[1].message
			return
		end

		local properties = {}
		for _, catName in categoryOrder do
			local list = propsByCat[catName]
			if list then
				for _, prop in list do
					local pname = string.gsub(prop.name, "^%s*(.-)%s*$", "%1")
					if pname == "" then
						continue
					end
					if not string.match(pname, "^[%a_][%w_]*$") then
						errorLabel.Text = "Bad property name: " .. pname
						return
					end
					local ok, value = Util.parseValue(prop.valueType, prop.defaultText or "")
					if not ok then
						errorLabel.Text = "Bad default for " .. pname
						return
					end
					table.insert(properties, {
						name = pname,
						valueType = prop.valueType,
						default = value,
						category = catName,
					})
				end
			end
		end

		local previous = editing
		local def = {
			id = name,
			name = name,
			description = if editing then editing.description else "",
			extends = storeExtends(selectedExtends),
			icon = selectedIcon,
			properties = properties,
		}
		Registry.save(def)
		if previous then
			Registry.migrateInstances(name, previous, def)
		end
		if onSaved then
			local accepted, message = onSaved(name)
			if accepted == false then
				errorLabel.Text = message or "Type saved, but the next action failed."
				return
			end
		end
		overlay:Destroy()
	end)
end

function TypeEditor.openDelete(_host: Instance, onDeleted: (() -> ())?)
	local types = Registry.list()
	if #types == 0 then
		return
	end
	Registry.delete(types[1].id)
	if onDeleted then
		onDeleted()
	end
end

return TypeEditor
