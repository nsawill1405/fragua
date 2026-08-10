local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Theme = require(script.Parent.Shared.Theme)
local Util = require(script.Parent.Shared.Util)
local IconCatalog = require(script.Parent.Types.IconCatalog)
local Registry = require(script.Parent.Types.Registry)
local EngineProps = require(script.EngineProps)

local Properties = {}

local function valueTypeOf(value: any): string
	return Util.attributeTypeName(value)
end

function Properties.mount(widget: DockWidgetPluginGui)
	local root = Instance.new("Frame")
	root.Name = "PropertiesRoot"
	root.BackgroundColor3 = Theme.bg
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = widget

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = Theme.bgDeep
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, Theme.headerHeight + 8)
	header.Parent = root

	local iconHolder = IconCatalog.createIconWidget(header, "class_Configuration", 18)
	iconHolder.Position = UDim2.fromOffset(8, 8)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(34, 0)
	title.Size = UDim2.new(1, -40, 1, 0)
	title.Font = Theme.fontBold
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.textBright
	title.Text = "No selection"
	title.Parent = header

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Props"
	scroll.BackgroundColor3 = Theme.bg
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, Theme.headerHeight + 8)
	scroll.Size = UDim2.new(1, 0, 1, -(Theme.headerHeight + 8))
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local current: Instance? = nil
	local conns: { RBXScriptConnection } = {}

	local function clearConns()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
	end

	local function clearRows()
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	local function addSection(name: string, order: number)
		local section = Instance.new("TextLabel")
		section.BackgroundColor3 = Theme.section
		section.BorderSizePixel = 0
		section.Size = UDim2.new(1, 0, 0, 22)
		section.Font = Theme.fontBold
		section.TextSize = 12
		section.TextXAlignment = Enum.TextXAlignment.Left
		section.TextColor3 = Theme.textMuted
		section.Text = "  " .. name
		section.LayoutOrder = order
		section.Parent = scroll
	end

	local function addRow(order: number, propName: string, displayValue: string, valueType: string, readonly: boolean, onCommit: (any) -> ())
		local row = Instance.new("Frame")
		row.BackgroundColor3 = if order % 2 == 0 then Theme.bg else Theme.bgDeep
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, Theme.rowHeight + 2)
		row.LayoutOrder = order
		row.Parent = scroll

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(8, 0)
		nameLabel.Size = UDim2.new(0.42, -8, 1, 0)
		nameLabel.Font = Theme.font
		nameLabel.TextSize = 13
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = Theme.text
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Text = propName
		nameLabel.Parent = row

		if valueType == "boolean" and not readonly then
			local toggle = Instance.new("TextButton")
			toggle.AutoButtonColor = false
			toggle.Size = UDim2.new(0.58, -12, 0, 20)
			toggle.Position = UDim2.new(0.42, 0, 0.5, -10)
			toggle.BackgroundColor3 = Theme.inputBg
			toggle.BorderSizePixel = 0
			toggle.Font = Theme.font
			toggle.TextSize = 13
			toggle.TextColor3 = Theme.textBright
			toggle.Text = displayValue
			toggle.Parent = row
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 3)
			c.Parent = toggle
			toggle.MouseButton1Click:Connect(function()
				local newVal = not (string.lower(toggle.Text) == "true")
				ChangeHistoryService:SetWaypoint("Fragua Property")
				onCommit(newVal)
				toggle.Text = if newVal then "true" else "false"
			end)
			return
		end

		local box = Instance.new("TextBox")
		box.ClearTextOnFocus = false
		box.Size = UDim2.new(0.58, -12, 0, 20)
		box.Position = UDim2.new(0.42, 0, 0.5, -10)
		box.BackgroundColor3 = Theme.inputBg
		box.BorderSizePixel = 0
		box.Font = Theme.fontMono
		box.TextSize = 12
		box.TextColor3 = if readonly then Theme.textMuted else Theme.textBright
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.Text = displayValue
		box.TextEditable = not readonly
		box.Parent = row

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 3)
		c.Parent = box

		if not readonly then
			box.FocusLost:Connect(function(enter)
				if not enter and box.Text == displayValue then
					return
				end
				local ok, parsed = Util.parseValue(valueType, box.Text)
				if ok then
					ChangeHistoryService:SetWaypoint("Fragua Property")
					onCommit(parsed)
				else
					box.Text = displayValue
				end
			end)
		end
	end

	local function rebuild()
		clearConns()
		clearRows()
		local list = Selection:Get()
		current = list[1]
		if not current then
			title.Text = "No selection"
			iconHolder:SetAttribute("IconId", "class_Folder")
			return
		end

		if Registry.isFraguaInstance(current) then
			local typeId = Registry.getTypeId(current)
			local def = typeId and Registry.get(typeId)
			local classLabel = if def then def.name else (typeId or "Unknown")
			title.Text = `{current.Name}  ({classLabel})`
			iconHolder:SetAttribute("IconId", if def then def.icon else "emoji_warning")

			local schema = if def then Registry.resolvedSchema(def) else {}
			local byCategory: { [string]: { any } } = {}
			local categories: { string } = {}

			table.insert(categories, "Data")
			byCategory.Data = {
				{ name = "Name", valueType = "string", value = current.Name, readonly = false, isName = true },
				{ name = "Class", valueType = "string", value = classLabel, readonly = true },
				{ name = "TypeId", valueType = "string", value = typeId or "", readonly = true },
			}

			for _, prop in schema do
				if prop.name == "Name" or prop.name == "Archivable" then
					continue
				end
				local cat = prop.category or "Data"
				if not byCategory[cat] then
					byCategory[cat] = {}
					table.insert(categories, cat)
				end
				local value = current:GetAttribute(prop.name)
				if value == nil then
					value = prop.default
				end
				table.insert(byCategory[cat], {
					name = prop.name,
					valueType = prop.valueType,
					value = value,
					readonly = prop.readonly == true,
				})
			end

			local order = 1
			for _, cat in categories do
				addSection(cat, order)
				order += 1
				for _, prop in byCategory[cat] do
					local captured = prop
					addRow(order, captured.name, Util.formatValue(captured.value), captured.valueType, captured.readonly, function(newValue)
						if captured.isName then
							current.Name = tostring(newValue)
						else
							current:SetAttribute(captured.name, newValue)
						end
					end)
					order += 1
				end
			end

			table.insert(conns, current.Changed:Connect(function()
				task.defer(rebuild)
			end))
			table.insert(conns, current.AttributeChanged:Connect(function()
				task.defer(rebuild)
			end))
			return
		end

		title.Text = `{current.Name}  ({current.ClassName})`
		iconHolder:SetAttribute("IconId", "class_" .. current.ClassName)

		addSection("Data", 1)
		local order = 2
		for _, prop in EngineProps.forInstance(current) do
			local ok, value = pcall(EngineProps.get, current, prop.name)
			if ok then
				local capturedName = prop.name
				local readonly = prop.readonly
				local vt = valueTypeOf(value)
				if typeof(value) == "EnumItem" then
					vt = "string"
					value = value.Name
					readonly = true
				elseif typeof(value) == "Instance" then
					vt = "string"
					value = value:GetFullName()
					readonly = true
				end
				addRow(order, capturedName, Util.formatValue(value), vt, readonly, function(newValue)
					EngineProps.set(current, capturedName, newValue)
				end)
				order += 1
			end
		end

		-- Attributes section
		local attrs = current:GetAttributes()
		local attrNames = {}
		for name in attrs do
			table.insert(attrNames, name)
		end
		table.sort(attrNames)
		if #attrNames > 0 then
			addSection("Attributes", order)
			order += 1
			for _, name in attrNames do
				local value = attrs[name]
				local captured = name
				addRow(order, name, Util.formatValue(value), valueTypeOf(value), false, function(newValue)
					current:SetAttribute(captured, newValue)
				end)
				order += 1
			end
		end

		table.insert(conns, current.Changed:Connect(function()
			task.defer(rebuild)
		end))
		table.insert(conns, current.AttributeChanged:Connect(function()
			task.defer(rebuild)
		end))
	end

	Selection.SelectionChanged:Connect(rebuild)
	Registry.Changed:Connect(function()
		task.defer(rebuild)
	end)
	rebuild()

	return {
		root = root,
		rebuild = rebuild,
	}
end

return Properties
