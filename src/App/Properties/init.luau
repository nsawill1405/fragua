local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")

local Theme = require(script.Parent.Shared.Theme)
local Util = require(script.Parent.Shared.Util)
local UiUtil = require(script.Parent.Shared.UiUtil)
local IconCatalog = require(script.Parent.Types.IconCatalog)
local Registry = require(script.Parent.Types.Registry)
local EngineProps = require(script.EngineProps)
local Controls = require(script.Controls)
local MetadataEditor = require(script.MetadataEditor)
local PropertyRefreshPolicy = require(script.PropertyRefreshPolicy)

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
	"Tags",
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

function Properties.mount(widget: DockWidgetPluginGui, opts: { onEditScript: ((any) -> ())? }?)
	opts = opts or {}
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
	local propertyUpdaters: { [string]: (any) -> () } = {}
	local attributeUpdaters: { [string]: (any) -> () } = {}
	local attributeValueTypes: { [string]: string } = {}
	local previewingProperties: { [string]: boolean } = {}
	local previewingAttributes: { [string]: boolean } = {}

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

	local function closeMetadataDialogs()
		for _, child in root:GetChildren() do
			if child.Name == "MetadataDialog" then
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
		section.Size = UDim2.new(1, 0, 0, 24)
		section.Text = ""
		section.LayoutOrder = order
		section.Parent = scroll

		local accent = Instance.new("Frame")
		accent.BackgroundColor3 = color
		accent.BorderSizePixel = 0
		accent.Size = UDim2.new(0, 3, 1, -4)
		accent.Position = UDim2.fromOffset(0, 2)
		accent.Parent = section

		local twist = UiUtil.makeChevron(section, not collapsed, 14)
		twist.Position = UDim2.fromOffset(8, 5)

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

		section.MouseButton1Click:Connect(function()
			UiUtil.setChevronExpanded(twist, collapsed, true)
			task.delay(0.05, onToggle)
		end)
	end

	local NUMBER_RANGES: { [string]: { number } } = {
		Transparency = { 0, 1 },
		BackgroundTransparency = { 0, 1 },
		TextTransparency = { 0, 1 },
		Reflectance = { 0, 1 },
		FillTransparency = { 0, 1 },
		OutlineTransparency = { 0, 1 },
		Volume = { 0, 1 },
		PlaybackSpeed = { 0, 4 },
		Brightness = { 0, 10 },
		ClockTime = { 0, 24 },
		GeographicLatitude = { -90, 90 },
		FogStart = { 0, 10000 },
		FogEnd = { 0, 100000 },
		Gravity = { 0, 500 },
		WalkSpeed = { 0, 100 },
		JumpPower = { 0, 200 },
		JumpHeight = { 0, 50 },
		HipHeight = { 0, 20 },
		Health = { 0, 500 },
		MaxHealth = { 0, 500 },
		Range = { 0, 120 },
		Angle = { 0, 180 },
		FieldOfView = { 1, 120 },
		TextSize = { 1, 100 },
		BorderSizePixel = { 0, 20 },
		ZIndex = { 0, 100 },
		Intensity = { 0, 10 },
		Contrast = { -1, 1 },
		Saturation = { -1, 1 },
		Density = { 0, 1 },
		Spread = { 0, 1 },
		Threshold = { 0, 10 },
		Size = { 0, 50 },
	}

	local function addRow(
		order: number,
		prop: {
			name: string,
			valueType: string,
			value: any,
			readonly: boolean?,
			enumItems: { string }?,
			enumType: string?,
			onCommit: (any) -> (),
			onPreview: ((any) -> ())?,
			changeKind: string?,
		}
	)
		local function registerUpdater(update: (any) -> ())
			if prop.changeKind == "property" then
				propertyUpdaters[prop.name] = update
			elseif prop.changeKind == "attribute" then
				attributeUpdaters[prop.name] = update
				attributeValueTypes[prop.name] = typeof(prop.value)
			end
		end

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

		if valueType == "action" and not readonly then
			local action = Theme.makeButton(valueParent, tostring(value), { Size = UDim2.fromScale(1, 1) })
			action.MouseButton1Click:Connect(function()
				prop.onCommit(true)
			end)
			return
		end

		if valueType == "boolean" and not readonly then
			local displayValue = value == true
			local animationToken = 0
			local toggle = Instance.new("TextButton")
			toggle.AutoButtonColor = false
			toggle.Size = UDim2.fromOffset(36, 18)
			toggle.Position = UDim2.fromOffset(0, 1)
			toggle.BackgroundColor3 = if displayValue then Theme.accent else Theme.inputBg
			toggle.BorderSizePixel = 0
			toggle.Text = ""
			toggle.Parent = valueParent
			local tc = Instance.new("UICorner")
			tc.CornerRadius = UDim.new(1, 0)
			tc.Parent = toggle
			local knob = Instance.new("Frame")
			knob.Size = UDim2.fromOffset(14, 14)
			knob.Position = if displayValue then UDim2.new(1, -16, 0.5, -7) else UDim2.fromOffset(2, 2)
			knob.BackgroundColor3 = Theme.textBright
			knob.BorderSizePixel = 0
			knob.Parent = toggle
			local kc = Instance.new("UICorner")
			kc.CornerRadius = UDim.new(1, 0)
			kc.Parent = knob
			toggle.MouseButton1Click:Connect(function()
				displayValue = not displayValue
				animationToken += 1
				local token = animationToken
				local trackTween = Theme.play(toggle, "boolean-track", {
					BackgroundColor3 = if displayValue then Theme.accent else Theme.inputBg,
				})
				Theme.play(knob, "boolean-knob", {
					Position = if displayValue then UDim2.new(1, -16, 0.5, -7) else UDim2.fromOffset(2, 2),
				})
				trackTween.Completed:Once(function()
					if token ~= animationToken or not toggle.Parent then
						return
					end
					ChangeHistoryService:SetWaypoint("Fragua Property")
					prop.onCommit(displayValue)
				end)
			end)
			registerUpdater(function(nextValue)
				displayValue = nextValue == true
				toggle.BackgroundColor3 = if displayValue then Theme.accent else Theme.inputBg
				knob.Position = if displayValue then UDim2.new(1, -16, 0.5, -7) else UDim2.fromOffset(2, 2)
			end)
			return
		end

		if (valueType == "enum" or prop.enumItems) and not readonly then
			local items = prop.enumItems or { tostring(value) }
			local currentName = if typeof(value) == "EnumItem" then value.Name else tostring(value)
			local enumType = prop.enumType
			if not enumType and typeof(value) == "EnumItem" then
				enumType = value.EnumType.Name
			end
			local drop = Controls.enumDropdown(valueParent, items, currentName, function(picked)
				ChangeHistoryService:SetWaypoint("Fragua Property")
				prop.onCommit(picked)
			end, enumType)
			drop.Size = UDim2.fromScale(1, 1)
			registerUpdater(function(nextValue)
				local name = if typeof(nextValue) == "EnumItem" then nextValue.Name else tostring(nextValue)
				drop.Text = "  " .. name
			end)
			return
		end

		if valueType == "Color3" and typeof(value) == "Color3" and not readonly then
			local field, update = Controls.colorField(valueParent, value, function(c)
				ChangeHistoryService:SetWaypoint("Fragua Property")
				prop.onCommit(c)
			end, prop.onPreview)
			field.Size = UDim2.fromScale(1, 1)
			registerUpdater(update)
			return
		end

		if valueType == "number" and typeof(value) == "number" and not readonly then
			local field, update = Controls.numberField(valueParent, value, function(n)
				ChangeHistoryService:SetWaypoint("Fragua Property")
				prop.onCommit(n)
			end, NUMBER_RANGES[prop.name], prop.onPreview)
			field.Size = UDim2.fromScale(1, 1)
			registerUpdater(update)
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
		registerUpdater(function(nextValue)
			if not box:IsFocused() then
				box.Text = " " .. Util.formatValue(nextValue)
			end
		end)
	end

	local function rebuild()
		if rebuilding then
			return
		end
		rebuilding = true
		local ok, err = pcall(function()
			clearConns()
			clearRows()
			table.clear(propertyUpdaters)
			table.clear(attributeUpdaters)
			table.clear(attributeValueTypes)
			local list = Selection:Get()
			current = list[1]
			if current and not current:IsDescendantOf(game) then
				current = nil
			end
			if not current then
				title.Text = "No selection"
				iconHolder:SetAttribute("IconId", "class_Folder")
				return
			end

			local byCategory: { [string]: { any } } = {}
			local categories: { string } = {}
			local schemaNames: { [string]: boolean } = {}
			local isFragua = Registry.isFraguaInstance(current)

			local function push(cat: string, row: any)
				if not byCategory[cat] then
					byCategory[cat] = {}
					table.insert(categories, cat)
				end
				table.insert(byCategory[cat], row)
			end

			if isFragua then
				local typeId = Registry.getTypeId(current)
				local def = typeId and Registry.get(typeId)
				local classLabel = if def then def.name else (typeId or "Unknown")
				title.Text = current.Name .. "  /  " .. classLabel
				iconHolder:SetAttribute("IconId", if def then def.icon else "emoji_warning")

				push("Data", {
					name = "Name",
					valueType = "string",
					value = current.Name,
					onCommit = function(v)
						current.Name = tostring(v)
					end,
					changeKind = "property",
				})
				local typeIds = {}
				for _, d in Registry.list() do
					table.insert(typeIds, d.id)
				end
				table.sort(typeIds)
				push("Data", {
					name = "Type",
					valueType = "enum",
					value = typeId or classLabel,
					enumItems = typeIds,
					onCommit = function(v)
						if typeof(v) == "string" and v ~= "" then
							Registry.applyType(current, v)
						end
					end,
				})

				if def then
					for _, prop in Registry.resolvedSchema(def) do
						if prop.name ~= "Name" and prop.name ~= "Archivable" then
							schemaNames[prop.name] = true
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
								onPreview = function(v)
									previewingAttributes[captured] = true
									current:SetAttribute(captured, v)
									previewingAttributes[captured] = nil
								end,
								changeKind = "attribute",
							})
						end
					end
				end

				if typeId then
					local behavior = Registry.ensureBehaviorTemplate(typeId)
					local hooks = {}
					for hookName in behavior.Source:gmatch("function%s+Behavior%.([%a_][%w_]*)") do
						table.insert(hooks, hookName)
					end
					table.sort(hooks)
					push("Behavior", {
						name = "Shared behavior",
						valueType = "string",
						value = behavior.Name,
						readonly = true,
						onCommit = function() end,
					})
					push("Behavior", {
						name = "Used by",
						valueType = "string",
						value = `{Registry.countInstances(typeId)} instance(s)`,
						readonly = true,
						onCommit = function() end,
					})
					push("Behavior", {
						name = "Hooks",
						valueType = "string",
						value = if #hooks > 0 then table.concat(hooks, ", ") else "No hooks yet",
						readonly = true,
						onCommit = function() end,
					})
					push("Behavior", {
						name = "Code",
						valueType = "action",
						value = "Edit behavior",
						onCommit = function()
							if opts.onEditScript then
								opts.onEditScript({
									target = behavior,
									title = behavior.Name,
									typeId = typeId,
									sharedCount = Registry.countInstances(typeId),
								})
							end
						end,
					})
				end
			else
				title.Text = current.Name .. "  /  " .. current.ClassName
				iconHolder:SetAttribute("IconId", "class_" .. current.ClassName)

				for _, prop in EngineProps.forInstance(current) do
					local gotValue, value = pcall(EngineProps.get, current, prop.name)
					if not gotValue then
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
					local enumType = prop.enumType
					if not enumType and typeof(value) == "EnumItem" then
						enumType = value.EnumType.Name
					end
					push(prop.category or "Data", {
						name = prop.name,
						valueType = valueType,
						value = if valueType == "enum" and typeof(value) == "EnumItem" then value else displayValue,
						readonly = readonly,
						enumItems = enumItems,
						enumType = enumType,
						onCommit = function(v)
							EngineProps.set(current, capturedName, v)
						end,
						onPreview = function(v)
							previewingProperties[capturedName] = true
							EngineProps.set(current, capturedName, v)
							previewingProperties[capturedName] = nil
						end,
						changeKind = "property",
					})
				end
			end

			MetadataEditor.appendRows({
				instance = current,
				host = root,
				push = push,
				schemaNames = schemaNames,
				isFragua = Registry.getTypeId(current) ~= nil,
				requestRebuild = function()
					task.defer(rebuild)
				end,
			})

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

			local selected = current
			local function updateTitle()
				if Registry.isFraguaInstance(selected) then
					local typeId = Registry.getTypeId(selected)
					local def = typeId and Registry.get(typeId)
					title.Text = selected.Name .. "  /  " .. (if def then def.name else (typeId or "Unknown"))
				else
					title.Text = selected.Name .. "  /  " .. selected.ClassName
				end
			end
			table.insert(
				conns,
				selected.Changed:Connect(function(propertyName)
					if current ~= selected or PropertyRefreshPolicy.action("property", propertyName) ~= "update" then
						return
					end
					if previewingProperties[propertyName] then
						return
					end
					local update = propertyUpdaters[propertyName]
					if update then
						local gotValue, nextValue = pcall(EngineProps.get, selected, propertyName)
						if gotValue then
							update(nextValue)
						end
					end
					if propertyName == "Name" then
						updateTitle()
					end
				end)
			)
			local watchedTags = {}
			local function watchTag(tag: string)
				if watchedTags[tag] then
					return
				end
				watchedTags[tag] = true
				local function changed(instance: Instance)
					if instance == selected and current == selected then
						task.defer(rebuild)
					end
				end
				table.insert(conns, CollectionService:GetInstanceAddedSignal(tag):Connect(changed))
				table.insert(conns, CollectionService:GetInstanceRemovedSignal(tag):Connect(changed))
			end
			for _, tag in CollectionService:GetAllTags() do
				watchTag(tag)
			end
			table.insert(conns, CollectionService.TagAdded:Connect(watchTag))
			table.insert(
				conns,
				CollectionService.TagRemoved:Connect(function()
					if current == selected then
						task.defer(rebuild)
					end
				end)
			)
			table.insert(
				conns,
				selected.AttributeChanged:Connect(function(attributeName)
					if current ~= selected then
						return
					end
					local nextValue = selected:GetAttribute(attributeName)
					if
						PropertyRefreshPolicy.action(
							"attribute",
							attributeName,
							attributeValueTypes[attributeName],
							typeof(nextValue)
						) == "rebuild"
					then
						task.defer(rebuild)
						return
					end
					if previewingAttributes[attributeName] then
						return
					end
					local update = attributeUpdaters[attributeName]
					if update and nextValue ~= nil then
						update(nextValue)
					else
						task.defer(rebuild)
					end
				end)
			)
		end)
		rebuilding = false
		if not ok then
			warn("[Fragua] Properties rebuild failed:", err)
		end
	end

	local lifetime: { RBXScriptConnection } = {}
	table.insert(
		lifetime,
		Selection.SelectionChanged:Connect(function()
			closeMetadataDialogs()
			task.defer(rebuild)
		end)
	)
	table.insert(
		lifetime,
		Registry.Changed:Connect(function()
			task.defer(rebuild)
		end)
	)
	rebuild()

	return {
		root = root,
		rebuild = rebuild,
		refreshForRunState = function()
			closeMetadataDialogs()
			clearConns()
			if current and not current:IsDescendantOf(game) then
				current = nil
			end
		end,
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
