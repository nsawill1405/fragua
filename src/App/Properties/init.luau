local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Theme = require(script.Parent.Shared.Theme)
local Util = require(script.Parent.Shared.Util)
local UiUtil = require(script.Parent.Shared.UiUtil)
local IconCatalog = require(script.Parent.Types.IconCatalog)
local Registry = require(script.Parent.Types.Registry)
local EngineProps = require(script.EngineProps)
local Controls = require(script.Controls)

local Properties = {}

local CATEGORY_ORDER = {
	"Data",
	"Behavior",
	"Appearance",
	"Transform",
	"Part",
	"Health",
	"Control",
	"Display",
	"Text",
	"Audio",
	"Camera",
	"World",
	"Streaming",
	"Celestial",
	"Fog",
	"Attributes",
}

local function sortCategories(cats: { string }): { string }
	local rank: { [string]: number } = {}
	for i, name in CATEGORY_ORDER do
		rank[name] = i
	end
	table.sort(cats, function(a, b)
		local ra = rank[a] or 500
		local rb = rank[b] or 500
		if ra == rb then
			return a < b
		end
		return ra < rb
	end)
	return cats
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
	header.Size = UDim2.new(1, 0, 0, Theme.headerHeight)
	header.Parent = root

	local headerLine = Instance.new("Frame")
	headerLine.BackgroundColor3 = Theme.border
	headerLine.BorderSizePixel = 0
	headerLine.Position = UDim2.new(0, 0, 1, -1)
	headerLine.Size = UDim2.new(1, 0, 0, 1)
	headerLine.Parent = header

	local iconHolder = IconCatalog.createIconWidget(header, "class_Configuration", 16)
	iconHolder.Position = UDim2.fromOffset(10, 9)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(34, 0)
	title.Size = UDim2.new(1, -44, 1, 0)
	title.Font = Theme.fontBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.textBright
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Text = "No selection"
	title.Parent = header

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Props"
	scroll.BackgroundColor3 = Theme.bg
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, Theme.headerHeight)
	scroll.Size = UDim2.new(1, 0, 1, -Theme.headerHeight)
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Theme.borderLight
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local current: Instance? = nil
	local conns: { RBXScriptConnection } = {}
	local rebuilding = false
	local collapsedSections: { [string]: boolean } = {}

	local function clearConns()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
	end

	local function clearRows()
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") and not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end

	local function addSection(name: string, order: number, onToggle: () -> ())
		local color = UiUtil.sectionColor(name)
		local collapsed = collapsedSections[name] == true
		local section = Instance.new("TextButton")
		section.AutoButtonColor = false
		section.BackgroundColor3 = Theme.section
		section.BorderSizePixel = 0
		section.Size = UDim2.new(1, 0, 0, 22)
		section.Text = ""
		section.LayoutOrder = order
		section.Parent = scroll

		local accent = Instance.new("Frame")
		accent.BackgroundColor3 = color
		accent.BorderSizePixel = 0
		accent.Size = UDim2.new(0, 3, 1, -4)
		accent.Position = UDim2.fromOffset(0, 2)
		accent.Parent = section

		local twist = Instance.new("TextLabel")
		twist.BackgroundTransparency = 1
		twist.Position = UDim2.fromOffset(10, 0)
		twist.Size = UDim2.fromOffset(14, 22)
		twist.Font = Enum.Font.GothamBold
		twist.TextSize = 11
		twist.TextColor3 = Theme.textMuted
		twist.Text = if collapsed then ">" else "v"
		twist.Parent = section

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(26, 0)
		label.Size = UDim2.new(1, -30, 1, 0)
		label.Font = Theme.fontBold
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = color
		label.Text = string.upper(name)
		label.Parent = section

		section.MouseButton1Click:Connect(onToggle)
	end

	local function addRow(order: number, prop: {
		name: string,
		valueType: string,
		value: any,
		readonly: boolean?,
		enumItems: { string }?,
		onCommit: (any) -> (),
	})
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Theme.bg
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 26)
		row.LayoutOrder = order
		row.Parent = scroll

		local divider = Instance.new("Frame")
		divider.BackgroundColor3 = Theme.border
		divider.BackgroundTransparency = 0.55
		divider.BorderSizePixel = 0
		divider.Position = UDim2.new(0, 0, 1, -1)
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(10, 0)
		nameLabel.Size = UDim2.new(0.4, -10, 1, 0)
		nameLabel.Font = Theme.font
		nameLabel.TextSize = 12
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = Theme.text
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Text = prop.name
		nameLabel.Parent = row

		local valueParent = Instance.new("Frame")
		valueParent.BackgroundTransparency = 1
		valueParent.Position = UDim2.new(0.4, 0, 0.5, -10)
		valueParent.Size = UDim2.new(0.6, -10, 0, 20)
		valueParent.Parent = row

		local readonly = prop.readonly == true
		local valueType = prop.valueType
		local value = prop.value

		if valueType == "boolean" and not readonly then
			local toggle = Instance.new("TextButton")
			toggle.AutoButtonColor = false
			toggle.Size = UDim2.fromOffset(36, 18)
			toggle.Position = UDim2.fromOffset(0, 1)
			toggle.BackgroundColor3 = if value then Theme.accent else Theme.inputBg
			toggle.BorderSizePixel = 0
			toggle.Text = ""
			toggle.Parent = valueParent
			local tc = Instance.new("UICorner")
			tc.CornerRadius = UDim.new(1, 0)
			tc.Parent = toggle
			local knob = Instance.new("Frame")
			knob.Size = UDim2.fromOffset(14, 14)
			knob.Position = if value then UDim2.new(1, -16, 0.5, -7) else UDim2.fromOffset(2, 2)
			knob.BackgroundColor3 = Theme.textBright
			knob.BorderSizePixel = 0
			knob.Parent = toggle
			local kc = Instance.new("UICorner")
			kc.CornerRadius = UDim.new(1, 0)
			kc.Parent = knob
			toggle.MouseButton1Click:Connect(function()
				ChangeHistoryService:SetWaypoint("Fragua Property")
				prop.onCommit(not value)
			end)
			return
		end

		if (valueType == "enum" or prop.enumItems) and not readonly then
			local items = prop.enumItems or { tostring(value) }
			local currentName = if typeof(value) == "EnumItem" then value.Name else tostring(value)
			local drop = Controls.enumDropdown(valueParent, items, currentName, function(picked)
				ChangeHistoryService:SetWaypoint("Fragua Property")
				prop.onCommit(picked)
			end)
			drop.Size = UDim2.fromScale(1, 1)
			return
		end

		if valueType == "Color3" and typeof(value) == "Color3" and not readonly then
			local field = Controls.colorField(valueParent, value, function(c)
				ChangeHistoryService:SetWaypoint("Fragua Property")
				prop.onCommit(c)
			end)
			field.Size = UDim2.fromScale(1, 1)
			return
		end

		local box = Instance.new("TextBox")
		box.ClearTextOnFocus = false
		box.Size = UDim2.fromScale(1, 1)
		box.BackgroundColor3 = Theme.inputBg
		box.BorderSizePixel = 0
		box.Font = Theme.fontMono
		box.TextSize = 11
		box.TextColor3 = if readonly then Theme.textMuted else Theme.textBright
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.Text = " " .. Util.formatValue(value)
		box.TextEditable = not readonly
		box.Parent = valueParent
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 4)
		bc.Parent = box

		if not readonly then
			box.FocusLost:Connect(function()
				local text = string.gsub(box.Text, "^%s+", "")
				local ok, parsed = Util.parseValue(valueType, text)
				if ok then
					ChangeHistoryService:SetWaypoint("Fragua Property")
					prop.onCommit(parsed)
				else
					box.Text = " " .. Util.formatValue(value)
				end
			end)
		end
	end

	local function rebuild()
		if rebuilding then
			return
		end
		rebuilding = true
		local ok, err = pcall(function()
		clearConns()
		clearRows()
		local list = Selection:Get()
		current = list[1]
		if not current then
			title.Text = "No selection"
			iconHolder:SetAttribute("IconId", "class_Folder")
			return
		end

		local byCategory: { [string]: { any } } = {}
		local categories: { string } = {}

		local function push(cat: string, row: any)
			if not byCategory[cat] then
				byCategory[cat] = {}
				table.insert(categories, cat)
			end
			table.insert(byCategory[cat], row)
		end

		if Registry.isFraguaInstance(current) then
			local typeId = Registry.getTypeId(current)
			local def = typeId and Registry.get(typeId)
			local classLabel = if def then def.name else (typeId or "Unknown")
			title.Text = current.Name .. "  ·  " .. classLabel
			iconHolder:SetAttribute("IconId", if def then def.icon else "emoji_warning")

			push("Data", {
				name = "Name",
				valueType = "string",
				value = current.Name,
				onCommit = function(v)
					current.Name = tostring(v)
				end,
			})
			push("Data", {
				name = "Class",
				valueType = "string",
				value = classLabel,
				readonly = true,
				onCommit = function() end,
			})

			if def then
				for _, prop in Registry.resolvedSchema(def) do
					if prop.name ~= "Name" and prop.name ~= "Archivable" then
						local value = current:GetAttribute(prop.name)
						if value == nil then
							value = prop.default
						end
						local captured = prop.name
						push(prop.category or "Data", {
							name = prop.name,
							valueType = prop.valueType,
							value = value,
							readonly = prop.readonly == true,
							enumItems = prop.enumItems,
							onCommit = function(v)
								current:SetAttribute(captured, v)
							end,
						})
					end
				end
			end
		else
			title.Text = current.Name .. "  ·  " .. current.ClassName
			iconHolder:SetAttribute("IconId", "class_" .. current.ClassName)

			for _, prop in EngineProps.forInstance(current) do
				local ok, value = pcall(EngineProps.get, current, prop.name)
				if not ok then
					continue
				end
				local valueType = prop.valueType or Util.attributeTypeName(value)
				local enumItems = prop.enumItems
				local readonly = prop.readonly == true
				local displayValue = value

				if typeof(value) == "EnumItem" then
					valueType = "enum"
					displayValue = value.Name
					enumItems = EngineProps.resolveEnumItems(prop, value)
				elseif typeof(value) == "Instance" then
					valueType = "string"
					displayValue = value:GetFullName()
					readonly = true
				elseif valueType == "enum" then
					enumItems = EngineProps.resolveEnumItems(prop, value)
					if typeof(value) == "EnumItem" then
						displayValue = value.Name
					end
				elseif typeof(value) == "Color3" then
					valueType = "Color3"
				elseif typeof(value) == "Vector3" then
					valueType = "Vector3"
				elseif typeof(value) == "boolean" then
					valueType = "boolean"
				elseif typeof(value) == "number" then
					valueType = "number"
				end

				local capturedName = prop.name
				push(prop.category or "Data", {
					name = prop.name,
					valueType = valueType,
					value = displayValue,
					readonly = readonly,
					enumItems = enumItems,
					onCommit = function(v)
						EngineProps.set(current, capturedName, v)
					end,
				})
			end

			local attrs = current:GetAttributes()
			local attrNames = {}
			for name in attrs do
				if name ~= "_FraguaType" then
					table.insert(attrNames, name)
				end
			end
			table.sort(attrNames)
			for _, name in attrNames do
				local value = attrs[name]
				local captured = name
				push("Attributes", {
					name = name,
					valueType = Util.attributeTypeName(value),
					value = value,
					onCommit = function(v)
						current:SetAttribute(captured, v)
					end,
				})
			end
		end

		local order = 1
		for _, cat in sortCategories(categories) do
			local catName = cat
			addSection(catName, order, function()
				collapsedSections[catName] = not collapsedSections[catName]
				task.defer(rebuild)
			end)
			order += 1
			if not collapsedSections[catName] then
				for _, row in byCategory[catName] do
					addRow(order, row)
					order += 1
				end
			end
		end

		table.insert(
			conns,
			current.Changed:Connect(function()
				task.defer(rebuild)
			end)
		)
		table.insert(
			conns,
			current.AttributeChanged:Connect(function()
				task.defer(rebuild)
			end)
		)
		end)
		rebuilding = false
		if not ok then
			warn("[Fragua] Properties rebuild failed:", err)
		end
	end

	local lifetime: { RBXScriptConnection } = {}
	table.insert(lifetime, Selection.SelectionChanged:Connect(function()
		task.defer(rebuild)
	end))
	table.insert(lifetime, Registry.Changed:Connect(function()
		task.defer(rebuild)
	end))
	rebuild()

	return {
		root = root,
		rebuild = rebuild,
		destroy = function()
			clearConns()
			for _, c in lifetime do
				c:Disconnect()
			end
			table.clear(lifetime)
			root:Destroy()
		end,
	}
end

return Properties
