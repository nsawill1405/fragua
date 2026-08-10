local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")

local Theme = require(script.Parent.Parent.Shared.Theme)
local Util = require(script.Parent.Parent.Shared.Util)
local Controls = require(script.Parent.Controls)
local MetadataModel = require(script.Parent.MetadataModel)

local MetadataEditor = {}

local ATTRIBUTE_TYPES = { "string", "number", "boolean", "Color3", "Vector3" }

local function safeMutation(instance: Instance, label: string, mutate: () -> (), onError: ((string) -> ())?): boolean
	if not instance:IsDescendantOf(game) then
		local message = "The selected instance is no longer in the active DataModel."
		if onError then
			onError(message)
		else
			warn("[Fragua] " .. message)
		end
		return false
	end
	ChangeHistoryService:SetWaypoint(label)
	local ok, err = pcall(mutate)
	ChangeHistoryService:SetWaypoint(label .. " Done")
	if not ok then
		local message = tostring(err)
		if onError then
			onError(message)
		else
			warn(`[Fragua] {label}: {message}`)
		end
		return false
	end
	return true
end

local function closeOverlay(overlay: Instance)
	if overlay.Parent then
		overlay:Destroy()
	end
end

local function makeDialog(host: GuiObject, titleText: string, height: number)
	local layers = MetadataModel.modalLayers(150)
	local overlay = Instance.new("Frame")
	overlay.Name = "MetadataDialog"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = layers.overlay
	overlay.Parent = host

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(
		math.min(math.max(host.AbsoluteSize.X - 24, 1), 360),
		math.min(math.max(host.AbsoluteSize.Y - 16, 1), height)
	)
	panel.BackgroundColor3 = Theme.bg
	panel.BorderSizePixel = 0
	panel.ZIndex = layers.panel
	panel.Parent = overlay
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
	title.ZIndex = layers.panel + 1
	title.Parent = panel

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromOffset(0, 32)
	content.Size = UDim2.new(1, 0, 1, -80)
	content.ScrollBarThickness = 4
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.ZIndex = layers.panel + 1
	content.Parent = panel

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
	errorLabel.ZIndex = layers.panel + 1
	errorLabel.Parent = panel

	local cancel = Theme.makeButton(panel, "Cancel", { Size = UDim2.fromOffset(72, 28) })
	cancel.AnchorPoint = Vector2.new(1, 1)
	cancel.Position = UDim2.new(1, -92, 1, -12)
	cancel.ZIndex = layers.panel + 1
	cancel.MouseButton1Click:Connect(function()
		closeOverlay(overlay)
	end)

	local save = Theme.makeButton(panel, "Save", { Size = UDim2.fromOffset(72, 28) })
	save.AnchorPoint = Vector2.new(1, 1)
	save.Position = UDim2.new(1, -12, 1, -12)
	save.BackgroundColor3 = Theme.accent
	save.ZIndex = layers.panel + 1

	return overlay, panel, content, errorLabel, save, layers
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
	local overlay, _, content, errorLabel, save = makeDialog(host, "Add Tag", 150)
	makeLabel(content, "Tag name", 4)
	local nameBox = makeBox(content, 20, "", "Enemy")
	save.Text = "Add"
	save.MouseButton1Click:Connect(function()
		local name = MetadataModel.normalizeName(nameBox.Text)
		if name == "" then
			errorLabel.Text = "Tag name is required."
			return
		end
		local ok = safeMutation(instance, "Fragua Add Tag", function()
			CollectionService:AddTag(instance, name)
		end, function(mutationError)
			errorLabel.Text = mutationError
		end)
		if not ok then
			return
		end
		closeOverlay(overlay)
		requestRebuild()
	end)
	nameBox:CaptureFocus()
end

local function attributeType(value: any): string
	return typeof(value)
end

local function openAttributeDialog(host: GuiObject, instance: Instance, previousName: string?, requestRebuild: () -> ())
	local previousValue = if previousName then instance:GetAttribute(previousName) else nil
	local originalType = if previousValue ~= nil then attributeType(previousValue) else nil
	local selectedType = originalType or "string"
	local startingValue = if previousValue ~= nil then previousValue else MetadataModel.defaultFor(selectedType)
	local overlay, panel, content, errorLabel, save, layers =
		makeDialog(host, if previousName then "Edit Attribute" else "Add Attribute", 260)

	makeLabel(content, "Name", 4)
	local nameBox = makeBox(content, 20, previousName or "", "Score")
	makeLabel(content, "Type", 54)
	local typeHost = Instance.new("Frame")
	typeHost.BackgroundTransparency = 1
	typeHost.Position = UDim2.fromOffset(12, 70)
	typeHost.Size = UDim2.new(1, -24, 0, 28)
	typeHost.ZIndex = layers.panel + 1
	typeHost.Parent = content

	makeLabel(content, "Value", 104)
	local valueBox = makeBox(content, 120, Util.formatValue(startingValue), "value")
	valueBox.TextEditable = MetadataModel.isSupportedType(selectedType)
	valueBox.TextColor3 = if valueBox.TextEditable then Theme.textBright else Theme.textMuted
	local typeChoices = table.clone(ATTRIBUTE_TYPES)
	if not MetadataModel.isSupportedType(selectedType) then
		table.insert(typeChoices, 1, selectedType)
	end
	local typeButton = Controls.enumDropdown(typeHost, typeChoices, selectedType, function(nextType)
		selectedType = nextType
		valueBox.TextEditable = MetadataModel.isSupportedType(nextType)
		valueBox.TextColor3 = if valueBox.TextEditable then Theme.textBright else Theme.textMuted
		if valueBox.TextEditable then
			valueBox.Text = Util.formatValue(MetadataModel.defaultFor(nextType))
		else
			valueBox.Text = Util.formatValue(previousValue)
		end
	end, nil, { host = overlay, zIndex = layers.menu })
	typeButton.Size = UDim2.fromScale(1, 1)
	typeButton.ZIndex = 153
	if previousName and not MetadataModel.isProtectedAttribute(previousName) then
		local deleteButton = Theme.makeButton(panel, "Delete", { Size = UDim2.fromOffset(72, 28) })
		deleteButton.AnchorPoint = Vector2.new(0, 1)
		deleteButton.Position = UDim2.new(0, 12, 1, -12)
		deleteButton.TextColor3 = Theme.danger
		deleteButton.ZIndex = 152
		deleteButton.MouseButton1Click:Connect(function()
			if
				safeMutation(instance, "Fragua Delete Attribute", function()
					instance:SetAttribute(previousName, nil)
				end, function(message)
					errorLabel.Text = message
				end)
			then
				closeOverlay(overlay)
				requestRebuild()
			end
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
		local parsed = true
		local nextValue = previousValue
		if MetadataModel.isSupportedType(selectedType) then
			parsed, nextValue = Util.parseValue(selectedType, valueBox.Text)
			if not parsed then
				errorLabel.Text = "Enter a valid " .. selectedType .. " value."
				return
			end
		elseif selectedType ~= originalType or previousValue == nil then
			errorLabel.Text = "Choose a supported type to replace this value."
			return
		end
		local changedShape = previousName ~= name or attributeType(previousValue) ~= selectedType
		local ok = safeMutation(instance, "Fragua Attribute", function()
			instance:SetAttribute(name, nextValue)
			if previousName and previousName ~= name then
				instance:SetAttribute(previousName, nil)
			end
		end, function(mutationError)
			errorLabel.Text = mutationError
		end)
		if not ok then
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
		local capturedTag = tag
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
				if
					safeMutation(instance, "Fragua Remove Tag", function()
						CollectionService:RemoveTag(instance, capturedTag)
					end, nil)
				then
					requestRebuild()
				end
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
		local supported = MetadataModel.isSupportedType(typeof(value))
		local capturedName = name
		push("Attributes", {
			name = name,
			valueType = Util.attributeTypeName(value),
			value = value,
			readonly = protected or not supported,
			onCommit = function(nextValue)
				safeMutation(instance, "Fragua Attribute", function()
					instance:SetAttribute(capturedName, nextValue)
				end, nil)
			end,
			onPreview = function(nextValue)
				if instance:IsDescendantOf(game) then
					local ok, err = pcall(instance.SetAttribute, instance, capturedName, nextValue)
					if not ok then
						warn(`[Fragua] Attribute preview: {tostring(err)}`)
					end
				end
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
