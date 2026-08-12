local DefaultControlModel = if script
	then require(script.Parent.DefaultControlModel)
	else require("./DefaultControlModel")
local TypeValue = if script then require(script.Parent.TypeValue) else require("./TypeValue")

local DefaultEditor = {}

local luneAvailable, LuneRoblox = pcall(function()
	return require("@lune/roblox")
end)
local BrickColorConstructor = if luneAvailable then LuneRoblox.BrickColor else BrickColor

function DefaultEditor.colorValue(valueType: string, color: Color3)
	if valueType == "BrickColor" then
		local typed = BrickColorConstructor.new(color)
		return typed, typed.Color
	end
	return color, color
end

local function uiDependencies()
	assert(script, "DefaultEditor.mount is only available in Roblox Studio")
	return require(script.Parent.Parent.Properties.Controls), require(script.Parent.Parent.Shared.Theme)
end

local function cloneList(value: any): { string }
	if typeof(value) ~= "table" then
		return {}
	end
	local result = {}
	for _, item in value do
		if typeof(item) == "string" then
			table.insert(result, item)
		end
	end
	return result
end

local function safeList(callback: ((string?) -> { string })?, argument: string?): { string }
	if not callback then
		return {}
	end
	local ok, result = pcall(callback, argument)
	return if ok then cloneList(result) else {}
end

function DefaultEditor.valueError(value: any, prop: any, lookupType): string?
	local metadata = table.clone(prop)
	metadata.lookupType = lookupType
	local valid, message = TypeValue.validate(prop.valueType, value, metadata)
	return if valid then nil else message
end

function DefaultEditor.referenceError(value: any, prop: any, lookupType): string?
	return DefaultEditor.valueError(value, prop, lookupType)
end

local function fullName(value: Instance?): string
	if not value then
		return "None"
	end
	local ok, result = pcall(value.GetFullName, value)
	return if ok then result else value.Name
end

local function makeCorner(control: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = control
end

local function makeTextBox(parent: GuiObject, Theme, text: string): TextBox
	local box = Instance.new("TextBox")
	box.ClearTextOnFocus = false
	box.BackgroundColor3 = Theme.inputBg
	box.BorderSizePixel = 0
	box.Font = Theme.fontMono
	box.TextSize = 11
	box.TextColor3 = Theme.textBright
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Text = text
	box.Parent = parent
	makeCorner(box)
	return box
end

local function componentState(valueType: string, value: any): ({ number }?, ((any) -> any)?)
	if valueType == "Vector2" then
		return { value.X, value.Y }, function(parts)
			return Vector2.new(parts[1], parts[2])
		end
	elseif valueType == "Vector3" then
		return { value.X, value.Y, value.Z }, function(parts)
			return Vector3.new(parts[1], parts[2], parts[3])
		end
	elseif valueType == "UDim" then
		return { value.Scale, value.Offset }, function(parts)
			return UDim.new(parts[1], parts[2])
		end
	elseif valueType == "UDim2" then
		return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }, function(parts)
			return UDim2.new(parts[1], parts[2], parts[3], parts[4])
		end
	elseif valueType == "CFrame" then
		local rx, ry, rz = value:ToOrientation()
		return {
			value.Position.X,
			value.Position.Y,
			value.Position.Z,
			math.deg(rx),
			math.deg(ry),
			math.deg(rz),
		}, function(parts)
			return CFrame.new(parts[1], parts[2], parts[3])
				* CFrame.fromOrientation(math.rad(parts[4]), math.rad(parts[5]), math.rad(parts[6]))
		end
	end
	return nil
end

local COMPONENT_LABELS = {
	Vector2 = { "X", "Y" },
	Vector3 = { "X", "Y", "Z" },
	UDim = { "S", "O" },
	UDim2 = { "XS", "XO", "YS", "YO" },
	CFrame = { "X", "Y", "Z", "RX", "RY", "RZ" },
}

function DefaultEditor.mount(parent: GuiObject, prop: any, options: any)
	options = options or {}
	local Controls, Theme = uiDependencies()
	local descriptor = DefaultControlModel.describe(prop)
	local current = prop.defaultValue
	local root = Instance.new("Frame")
	root.Name = "DefaultEditor"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = parent

	local connections = {}
	local ownedOverlays = {}
	local updateControl = function(_nextValue) end
	local destroyed = false
	local previewing = false

	local function connect(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(connections, connection)
		return connection
	end

	local function reportError(message: string?)
		if options.onError then
			options.onError(message)
		end
	end

	local function changed(nextValue: any, metadata: any?)
		current = nextValue
		if options.onChanged then
			options.onChanged(nextValue, metadata)
		end
	end

	if descriptor.kind == "toggle" then
		local control, update = Controls.booleanToggle(root, current == true, changed)
		control.Position = UDim2.fromOffset(0, 2)
		updateControl = update
	elseif descriptor.kind == "enum" then
		local enumNames = safeList(options.getEnumNames, nil)
		local enumType = prop.enumType
		if not table.find(enumNames, enumType) then
			enumType = enumNames[1]
		end
		local typeButton
		local itemButton

		local function liveItems(name: string?): { string }
			local items = safeList(options.getEnumItems, name)
			if #items == 0 and name == prop.enumType then
				items = cloneList(prop.enumItems)
			end
			return items
		end

		local function mountItem(items: { string }, nextValue: string?)
			if itemButton then
				itemButton:Destroy()
			end
			local selected = if table.find(items, nextValue) then nextValue else items[1] or ""
			itemButton = Controls.enumDropdown(root, items, selected, function(item)
				changed(item, { enumType = enumType, enumItems = table.clone(items) })
			end, enumType, { host = options.host })
			itemButton.Position = UDim2.new(0.46, 2, 0, 0)
			itemButton.Size = UDim2.new(0.54, -2, 1, 0)
			if selected ~= current or enumType ~= prop.enumType then
				changed(selected, { enumType = enumType, enumItems = table.clone(items) })
			end
		end

		typeButton = Controls.enumDropdown(root, enumNames, enumType or "", function(name)
			enumType = name
			mountItem(liveItems(name), nil)
		end, nil, { host = options.host })
		typeButton.Size = UDim2.new(0.46, -2, 1, 0)
		mountItem(liveItems(enumType), current)
		updateControl = function(nextValue)
			current = nextValue
			if itemButton then
				itemButton.Text = "  " .. tostring(nextValue)
			end
		end
	elseif descriptor.kind == "slider" then
		local range = { descriptor.options.minimum, descriptor.options.maximum }
		local control, update = Controls.numberField(root, current, changed, range, options.onPreview)
		control.Size = UDim2.fromScale(1, 1)
		updateControl = update
	elseif descriptor.kind == "number" then
		local box = makeTextBox(root, Theme, " " .. tostring(current))
		box.Size = UDim2.fromScale(1, 1)
		connect(box.FocusLost, function()
			local nextValue = tonumber(box.Text)
			if nextValue then
				changed(nextValue)
			else
				box.Text = " " .. tostring(current)
			end
		end)
		updateControl = function(nextValue)
			current = nextValue
			if not box:IsFocused() then
				box.Text = " " .. tostring(nextValue)
			end
		end
	elseif descriptor.kind == "color" then
		local brickColor = prop.valueType == "BrickColor"
		local color = if brickColor then current.Color else current
		local function fromColor(nextColor)
			return DefaultEditor.colorValue(prop.valueType, nextColor)
		end
		local normalize
		if brickColor then
			normalize = function(nextColor)
				local _, display = DefaultEditor.colorValue(prop.valueType, nextColor)
				return display
			end
		end
		local control, update = Controls.colorField(root, color, function(nextColor)
			previewing = false
			local typed, display = fromColor(nextColor)
			update(display)
			changed(typed)
		end, function(nextColor)
			previewing = true
			local typed, display = fromColor(nextColor)
			update(display)
			if options.onPreview then
				options.onPreview(typed)
			end
		end, normalize)
		control.Size = UDim2.fromScale(1, 1)
		updateControl = function(nextValue)
			current = nextValue
			update(if brickColor then nextValue.Color else nextValue)
		end
		if options.host then
			connect(options.host.ChildAdded, function(child)
				if child.Name == "ColorPicker" then
					table.insert(ownedOverlays, child)
				end
			end)
		end
	elseif descriptor.kind == "components" then
		local labels = COMPONENT_LABELS[prop.valueType]
		local values, build = componentState(prop.valueType, current)
		assert(labels and values and build, `Unsupported component value: {prop.valueType}`)
		local boxes = {}
		local columns = if #labels <= 3 then #labels else 2
		local rowHeight = 22
		for index, labelText in labels do
			local column = (index - 1) % columns
			local rowIndex = math.floor((index - 1) / columns)
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Position = UDim2.new(column / columns, 2 * column, 0, rowIndex * (rowHeight + 4))
			holder.Size = UDim2.new(1 / columns, if column == columns - 1 then -2 * column else -2, 0, rowHeight)
			holder.Parent = root

			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromOffset(28, rowHeight)
			label.Font = Theme.font
			label.TextSize = 9
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = Theme.textMuted
			label.Text = labelText
			label.Parent = holder

			local box = makeTextBox(holder, Theme, " " .. string.format("%.6g", values[index]))
			box.Position = UDim2.fromOffset(28, 0)
			box.Size = UDim2.new(1, -28, 1, 0)
			boxes[index] = box
			connect(box.FocusLost, function()
				local parsed = {}
				for partIndex, partBox in boxes do
					parsed[partIndex] = tonumber(partBox.Text)
					if not parsed[partIndex] then
						partBox.TextColor3 = Theme.danger
						reportError(`{labels[partIndex]} must be a number.`)
						return
					end
					partBox.TextColor3 = Theme.textBright
				end
				values = parsed
				reportError(nil)
				changed(build(parsed))
			end)
		end
		updateControl = function(nextValue)
			current = nextValue
			local nextValues = componentState(prop.valueType, nextValue)
			if nextValues then
				values = nextValues
				for index, box in boxes do
					if not box:IsFocused() then
						box.Text = " " .. string.format("%.6g", values[index])
					end
				end
			end
		end
	elseif descriptor.kind == "reference" then
		local display = Theme.makeButton(root, fullName(current), { Size = UDim2.new(0.5, -2, 1, 0) })
		display.Font = Theme.font
		display.TextSize = 10
		display.TextTruncate = Enum.TextTruncate.AtEnd
		local useSelection = Theme.makeButton(root, "Use selection", { Size = UDim2.new(0.38, -2, 1, 0) })
		useSelection.Position = UDim2.new(0.5, 2, 0, 0)
		useSelection.TextSize = 10
		local clear = Theme.makeButton(root, "x", { Size = UDim2.new(0.12, -2, 1, 0) })
		clear.Position = UDim2.new(0.88, 2, 0, 0)
		clear.TextColor3 = Theme.textMuted

		connect(display.MouseButton1Click, function()
			if current and options.setSelection then
				options.setSelection({ current })
			end
		end)
		connect(useSelection.MouseButton1Click, function()
			local selection = if options.getSelection then options.getSelection() else {}
			if #selection ~= 1 then
				reportError("Select exactly one instance.")
				return
			end
			local candidate = selection[1]
			local metadata = nil
			local validationProp = prop
			if prop.valueType == "FraguaInstance" and not prop.referenceType then
				local selectedType = if options.getReferenceType
					then options.getReferenceType(candidate)
					else candidate:GetAttribute("_FraguaType")
				if typeof(selectedType) == "string" and selectedType ~= "" then
					metadata = { referenceType = selectedType }
					validationProp = table.clone(prop)
					validationProp.referenceType = selectedType
				end
			end
			local message = DefaultEditor.referenceError(candidate, validationProp, options.lookupType)
			if message then
				reportError(message)
				return
			end
			reportError(nil)
			display.Text = fullName(candidate)
			changed(candidate, metadata)
		end)
		connect(clear.MouseButton1Click, function()
			reportError(nil)
			display.Text = "None"
			changed(nil)
		end)
		updateControl = function(nextValue)
			current = nextValue
			display.Text = fullName(nextValue)
		end
	else
		local box = makeTextBox(root, Theme, tostring(current or ""))
		box.Size = UDim2.new(1, -38, 1, 0)
		box.MultiLine = prop.multiline == true
		local multiline = Theme.makeButton(root, "ML", { Size = UDim2.fromOffset(34, 22) })
		multiline.Position = UDim2.new(1, -34, 0, 0)
		multiline.TextSize = 9
		multiline.TextColor3 = if prop.multiline then Theme.accent else Theme.textMuted
		connect(box.FocusLost, function()
			changed(box.Text)
		end)
		connect(multiline.MouseButton1Click, function()
			local enabled = not box.MultiLine
			box.MultiLine = enabled
			multiline.TextColor3 = if enabled then Theme.accent else Theme.textMuted
			changed(current, { multiline = enabled })
		end)
		updateControl = function(nextValue)
			current = nextValue
			if not box:IsFocused() then
				box.Text = tostring(nextValue or "")
			end
		end
	end

	local baseZIndex = parent.ZIndex + 1
	root.ZIndex = baseZIndex
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = baseZIndex + 1
		end
	end

	return {
		update = function(nextValue)
			if not destroyed then
				updateControl(nextValue)
			end
		end,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			if previewing and options.onPreview then
				options.onPreview(current)
			end
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			for _, overlay in ownedOverlays do
				if overlay.Parent then
					overlay:Destroy()
				end
			end
			table.clear(ownedOverlays)
			root:Destroy()
		end,
	}
end

return DefaultEditor
