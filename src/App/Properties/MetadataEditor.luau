local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")

local Theme = require(script.Parent.Parent.Shared.Theme)
local Util = require(script.Parent.Parent.Shared.Util)
local Controls = require(script.Parent.Controls)
local MetadataModel = require(script.Parent.MetadataModel)

local MetadataEditor = {}

local ATTRIBUTE_TYPES = { "string", "number", "boolean", "Color3", "Vector3" }

local function closeOverlay(overlay: Instance)
	if overlay.Parent then
		overlay:Destroy()
	end
end

local function makeDialog(host: GuiObject, titleText: string, height: number)
	local overlay = Instance.new("Frame")
	overlay.Name = "MetadataDialog"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 150
	overlay.Parent = host

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -24, 0, height)
	panel.BackgroundColor3 = Theme.bg
	panel.BorderSizePixel = 0
	panel.ZIndex = 151
	panel.Parent = overlay
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(360, height)
	sizeConstraint.MinSize = Vector2.new(180, height)
	sizeConstraint.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.corner
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.borderLight
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 20)
	title.Font = Theme.fontBold
	title.TextSize = 13
	title.TextColor3 = Theme.textBright
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = titleText
	title.ZIndex = 152
	title.Parent = panel

	local errorLabel = Instance.new("TextLabel")
	errorLabel.BackgroundTransparency = 1
	errorLabel.Position = UDim2.new(0, 12, 1, -66)
	errorLabel.Size = UDim2.new(1, -24, 0, 18)
	errorLabel.Font = Theme.font
	errorLabel.TextSize = 11
	errorLabel.TextColor3 = Theme.danger
	errorLabel.TextXAlignment = Enum.TextXAlignment.Left
	errorLabel.TextTruncate = Enum.TextTruncate.AtEnd
	errorLabel.Text = ""
	errorLabel.ZIndex = 152
	errorLabel.Parent = panel

	local cancel = Theme.makeButton(panel, "Cancel", { Size = UDim2.fromOffset(72, 28) })
	cancel.AnchorPoint = Vector2.new(1, 1)
	cancel.Position = UDim2.new(1, -92, 1, -12)
	cancel.ZIndex = 152
	cancel.MouseButton1Click:Connect(function()
		closeOverlay(overlay)
	end)

	local save = Theme.makeButton(panel, "Save", { Size = UDim2.fromOffset(72, 28) })
	save.AnchorPoint = Vector2.new(1, 1)
	save.Position = UDim2.new(1, -12, 1, -12)
	save.BackgroundColor3 = Theme.accent
	save.ZIndex = 152

	return overlay, panel, errorLabel, save
end

local function makeLabel(panel: GuiObject, text: string, y: number)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, y)
	label.Size = UDim2.new(1, -24, 0, 14)
	label.Font = Theme.font
	label.TextSize = 11
	label.TextColor3 = Theme.textMuted
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.ZIndex = 152
	label.Parent = panel
end

local function makeBox(panel: GuiObject, y: number, text: string, placeholder: string): TextBox
	local box = Instance.new("TextBox")
	box.ClearTextOnFocus = false
	box.BackgroundColor3 = Theme.inputBg
	box.BorderSizePixel = 0
	box.Position = UDim2.fromOffset(12, y)
	box.Size = UDim2.new(1, -24, 0, 28)
	box.Font = Theme.font
	box.TextSize = 12
	box.TextColor3 = Theme.textBright
	box.PlaceholderColor3 = Theme.textMuted
	box.PlaceholderText = placeholder
	box.Text = text
	box.ZIndex = 152
	box.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.corner
	corner.Parent = box
	return box
end

local function openTagDialog(host: GuiObject, instance: Instance, requestRebuild: () -> ())
	local overlay, panel, errorLabel, save = makeDialog(host, "Add Tag", 150)
	makeLabel(panel, "Tag name", 36)
	local nameBox = makeBox(panel, 52, "", "Enemy")
	save.Text = "Add"
	save.MouseButton1Click:Connect(function()
		local name = MetadataModel.normalizeName(nameBox.Text)
		if name == "" then
			errorLabel.Text = "Tag name is required."
			return
		end
		local ok, err = pcall(function()
			ChangeHistoryService:SetWaypoint("Fragua Add Tag")
			CollectionService:AddTag(instance, name)
			ChangeHistoryService:SetWaypoint("Fragua Add Tag Done")
		end)
		if not ok then
			errorLabel.Text = tostring(err)
			return
		end
		closeOverlay(overlay)
		requestRebuild()
	end)
	nameBox:CaptureFocus()
end

local function attributeType(value: any): string
	local valueType = typeof(value)
	if table.find(ATTRIBUTE_TYPES, valueType) then
		return valueType
	end
	return "string"
end

local function openAttributeDialog(host: GuiObject, instance: Instance, previousName: string?, requestRebuild: () -> ())
	local previousValue = if previousName then instance:GetAttribute(previousName) else nil
	local selectedType = if previousValue ~= nil then attributeType(previousValue) else "string"
	local startingValue = if previousValue ~= nil then previousValue else MetadataModel.defaultFor(selectedType)
	local overlay, panel, errorLabel, save =
		makeDialog(host, if previousName then "Edit Attribute" else "Add Attribute", 260)

	makeLabel(panel, "Name", 36)
	local nameBox = makeBox(panel, 52, previousName or "", "Score")
	makeLabel(panel, "Type", 86)
	local typeHost = Instance.new("Frame")
	typeHost.BackgroundTransparency = 1
	typeHost.Position = UDim2.fromOffset(12, 102)
	typeHost.Size = UDim2.new(1, -24, 0, 28)
	typeHost.ZIndex = 152
	typeHost.Parent = panel

	makeLabel(panel, "Value", 136)
	local valueBox = makeBox(panel, 152, Util.formatValue(startingValue), "value")
	local typeButton = Controls.enumDropdown(typeHost, ATTRIBUTE_TYPES, selectedType, function(nextType)
		selectedType = nextType
		valueBox.Text = Util.formatValue(MetadataModel.defaultFor(nextType))
	end)
	typeButton.Size = UDim2.fromScale(1, 1)
	typeButton.ZIndex = 153
	if previousName and not MetadataModel.isProtectedAttribute(previousName) then
		local deleteButton = Theme.makeButton(panel, "Delete", { Size = UDim2.fromOffset(72, 28) })
		deleteButton.AnchorPoint = Vector2.new(0, 1)
		deleteButton.Position = UDim2.new(0, 12, 1, -12)
		deleteButton.TextColor3 = Theme.danger
		deleteButton.ZIndex = 152
		deleteButton.MouseButton1Click:Connect(function()
			ChangeHistoryService:SetWaypoint("Fragua Delete Attribute")
			instance:SetAttribute(previousName, nil)
			ChangeHistoryService:SetWaypoint("Fragua Delete Attribute Done")
			closeOverlay(overlay)
			requestRebuild()
		end)
	end

	save.MouseButton1Click:Connect(function()
		local existing = {}
		for name in instance:GetAttributes() do
			existing[name] = true
		end
		local name = MetadataModel.normalizeName(nameBox.Text)
		local valid, message = MetadataModel.validateAttributeName(name, existing, previousName)
		if not valid then
			errorLabel.Text = message or "Invalid attribute name."
			return
		end
		if MetadataModel.isProtectedAttribute(previousName or name) then
			errorLabel.Text = "Fragua identity metadata is protected."
			return
		end
		local parsed, nextValue = Util.parseValue(selectedType, valueBox.Text)
		if not parsed then
			errorLabel.Text = "Enter a valid " .. selectedType .. " value."
			return
		end
		local changedShape = previousName ~= name or attributeType(previousValue) ~= selectedType
		local ok, err = pcall(function()
			ChangeHistoryService:SetWaypoint("Fragua Attribute")
			instance:SetAttribute(name, nextValue)
			if previousName and previousName ~= name then
				instance:SetAttribute(previousName, nil)
			end
			ChangeHistoryService:SetWaypoint("Fragua Attribute Done")
		end)
		if not ok then
			errorLabel.Text = tostring(err)
			return
		end
		closeOverlay(overlay)
		if changedShape or not previousName then
			requestRebuild()
		end
	end)
end

function MetadataEditor.appendRows(context)
	local instance: Instance = context.instance
	local push = context.push
	local requestRebuild = context.requestRebuild
	local schemaNames = context.schemaNames or {}
	local isFragua = context.isFragua == true
	local host: GuiObject = context.host

	push("Tags", {
		name = "Add tag",
		valueType = "action",
		value = "+ Add",
		onCommit = function()
			openTagDialog(host, instance, requestRebuild)
		end,
	})
	local tags = CollectionService:GetTags(instance)
	table.sort(tags)
	for _, tag in tags do
		local protected = MetadataModel.isProtectedTag(tag, isFragua)
		push("Tags", {
			name = tag,
			valueType = if protected then "string" else "action",
			value = if protected then "Protected" else "Remove",
			readonly = protected,
			onCommit = function()
				if protected then
					return
				end
				ChangeHistoryService:SetWaypoint("Fragua Remove Tag")
				CollectionService:RemoveTag(instance, tag)
				ChangeHistoryService:SetWaypoint("Fragua Remove Tag Done")
				requestRebuild()
			end,
		})
	end

	push("Attributes", {
		name = "Add attribute",
		valueType = "action",
		value = "+ Add",
		onCommit = function()
			openAttributeDialog(host, instance, nil, requestRebuild)
		end,
	})

	local attributes = instance:GetAttributes()
	local names = {}
	for name in attributes do
		if not schemaNames[name] then
			table.insert(names, name)
		end
	end
	table.sort(names)
	for _, name in names do
		local value = attributes[name]
		local protected = MetadataModel.isProtectedAttribute(name)
		local capturedName = name
		push("Attributes", {
			name = name,
			valueType = Util.attributeTypeName(value),
			value = value,
			readonly = protected,
			onCommit = function(nextValue)
				instance:SetAttribute(capturedName, nextValue)
			end,
			onPreview = function(nextValue)
				instance:SetAttribute(capturedName, nextValue)
			end,
			changeKind = "attribute",
		})
		push("Attributes", {
			name = name .. " options",
			valueType = if protected then "string" else "action",
			value = if protected then "Protected" else "Edit / delete",
			readonly = protected,
			onCommit = function()
				if not protected then
					openAttributeDialog(host, instance, capturedName, requestRebuild)
				end
			end,
		})
	end
end

return MetadataEditor
