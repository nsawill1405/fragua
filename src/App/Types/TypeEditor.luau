local Theme = require(script.Parent.Parent.Shared.Theme)
local Util = require(script.Parent.Parent.Shared.Util)
local EngineSchemas = require(script.Parent.EngineSchemas)
local IconCatalog = require(script.Parent.IconCatalog)
local IconPicker = require(script.Parent.IconPicker)
local Registry = require(script.Parent.Registry)

local TypeEditor = {}

local function makeField(parent: Instance, labelText: string, y: number): (TextLabel, TextBox)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, y)
	label.Size = UDim2.new(1, -24, 0, 18)
	label.Font = Theme.font
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.textMuted
	label.Text = labelText
	label.ZIndex = 62
	label.Parent = parent

	local box = Instance.new("TextBox")
	box.ClearTextOnFocus = false
	box.Font = Theme.font
	box.TextSize = 14
	box.TextColor3 = Theme.textBright
	box.BackgroundColor3 = Theme.inputBg
	box.BorderSizePixel = 0
	box.Position = UDim2.fromOffset(12, y + 18)
	box.Size = UDim2.new(1, -24, 0, 28)
	box.ZIndex = 62
	box.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.corner
	corner.Parent = box

	return label, box
end

function TypeEditor.open(host: Instance, onSaved: ((string) -> ())?)
	local overlay = Instance.new("Frame")
	overlay.Name = "TypeEditorOverlay"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 60
	overlay.Parent = host

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(440, 480)
	panel.BackgroundColor3 = Theme.bg
	panel.BorderSizePixel = 0
	panel.ZIndex = 61
	panel.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Font = Theme.fontBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.textBright
	title.Text = "Create New Type"
	title.ZIndex = 62
	title.Parent = panel

	local _, nameBox = makeField(panel, "Name", 44)
	nameBox.PlaceholderText = "Zombie"
	nameBox.Text = ""

	local _, extendsBox = makeField(panel, "Extends (engine class or Fragua type)", 100)
	extendsBox.Text = "Humanoid"
	extendsBox.PlaceholderText = "Humanoid"

	local _, descBox = makeField(panel, "Description", 156)
	descBox.Text = ""
	descBox.PlaceholderText = "Optional description"

	local iconLabel = Instance.new("TextLabel")
	iconLabel.BackgroundTransparency = 1
	iconLabel.Position = UDim2.fromOffset(12, 212)
	iconLabel.Size = UDim2.new(1, -24, 0, 18)
	iconLabel.Font = Theme.font
	iconLabel.TextSize = 13
	iconLabel.TextXAlignment = Enum.TextXAlignment.Left
	iconLabel.TextColor3 = Theme.textMuted
	iconLabel.Text = "Icon"
	iconLabel.ZIndex = 62
	iconLabel.Parent = panel

	local selectedIcon = "emoji_package"
	local iconBtn = Theme.makeButton(panel, "Pick Icon…", { Name = "PickIcon", Size = UDim2.fromOffset(120, 28) })
	iconBtn.Position = UDim2.fromOffset(12, 232)
	iconBtn.ZIndex = 62

	local iconPreview = IconCatalog.createIconWidget(panel, selectedIcon, 28)
	iconPreview.Position = UDim2.fromOffset(144, 232)
	iconPreview.ZIndex = 62

	iconBtn.MouseButton1Click:Connect(function()
		IconPicker.open(overlay, selectedIcon, function(id)
			selectedIcon = id
			iconPreview:SetAttribute("IconId", id)
		end)
	end)

	local _, propsBox = makeField(panel, "Extra properties (name:type:default:category per line)", 272)
	propsBox.Position = UDim2.fromOffset(12, 290)
	propsBox.Size = UDim2.new(1, -24, 0, 100)
	propsBox.Text = "IsHostile:boolean:true:AI\nDetectRange:number:40:AI"
	propsBox.TextYAlignment = Enum.TextYAlignment.Top
	propsBox.MultiLine = true
	propsBox.TextWrapped = true

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(12, 392)
	hint.Size = UDim2.new(1, -24, 0, 28)
	hint.Font = Theme.font
	hint.TextSize = 12
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Theme.textMuted
	hint.Text = "Types: string, number, boolean, Color3, Vector3. Inherited props from Extends are merged automatically."
	hint.ZIndex = 62
	hint.Parent = panel

	local cancel = Theme.makeButton(panel, "Cancel", { Size = UDim2.fromOffset(90, 28) })
	cancel.Position = UDim2.new(1, -204, 1, -40)
	cancel.ZIndex = 62
	cancel.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	local save = Theme.makeButton(panel, "Create", { Size = UDim2.fromOffset(90, 28) })
	save.Position = UDim2.new(1, -104, 1, -40)
	save.BackgroundColor3 = Theme.accent
	save.ZIndex = 62

	local errorLabel = Instance.new("TextLabel")
	errorLabel.BackgroundTransparency = 1
	errorLabel.Position = UDim2.fromOffset(12, 448)
	errorLabel.Size = UDim2.new(1, -220, 0, 20)
	errorLabel.Font = Theme.font
	errorLabel.TextSize = 12
	errorLabel.TextXAlignment = Enum.TextXAlignment.Left
	errorLabel.TextColor3 = Theme.danger
	errorLabel.Text = ""
	errorLabel.ZIndex = 62
	errorLabel.Parent = panel

	save.MouseButton1Click:Connect(function()
		local name = string.gsub(nameBox.Text, "^%s*(.-)%s*$", "%1")
		if name == "" or not string.match(name, "^[%a_][%w_]*$") then
			errorLabel.Text = "Name must be a valid identifier."
			return
		end
		if Registry.get(name) then
			errorLabel.Text = "A type with that name already exists."
			return
		end
		local extends = string.gsub(extendsBox.Text, "^%s*(.-)%s*$", "%1")
		if extends == "" then
			extends = "Configuration"
		end
		if not EngineSchemas.has(extends) and not Registry.get(extends) and not table.find(EngineSchemas.insertable(), extends) then
			-- allow unknown engine class names too
		end

		local properties = {}
		for line in string.gmatch(propsBox.Text, "[^\r\n]+") do
			local trimmed = string.gsub(line, "^%s*(.-)%s*$", "%1")
			if trimmed ~= "" then
				local pname, ptype, pdefault, pcat = string.match(trimmed, "^([^:]+):([^:]+):([^:]*):(.*)$")
				if not pname then
					pname, ptype, pdefault = string.match(trimmed, "^([^:]+):([^:]+):(.*)$")
					pcat = "Data"
				end
				if not pname then
					errorLabel.Text = `Bad property line: {trimmed}`
					return
				end
				pname = string.gsub(pname, "^%s*(.-)%s*$", "%1")
				ptype = string.gsub(ptype, "^%s*(.-)%s*$", "%1")
				local ok, value = Util.parseValue(ptype, pdefault or "")
				if not ok then
					errorLabel.Text = `Bad default for {pname}`
					return
				end
				table.insert(properties, {
					name = pname,
					valueType = ptype,
					default = value,
					category = if pcat and pcat ~= "" then pcat else "Data",
				})
			end
		end

		Registry.save({
			id = name,
			name = name,
			description = descBox.Text,
			extends = extends,
			icon = selectedIcon,
			properties = properties,
		})

		if onSaved then
			onSaved(name)
		end
		overlay:Destroy()
	end)
end

function TypeEditor.openDelete(host: Instance, onDeleted: (() -> ())?)
	local types = Registry.list()
	local overlay = Instance.new("Frame")
	overlay.Name = "DeleteTypeOverlay"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 60
	overlay.Parent = host

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 320)
	panel.BackgroundColor3 = Theme.bg
	panel.BorderSizePixel = 0
	panel.ZIndex = 61
	panel.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Font = Theme.fontBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.textBright
	title.Text = "Delete Type"
	title.ZIndex = 62
	title.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(12, 40)
	hint.Size = UDim2.new(1, -24, 0, 36)
	hint.Font = Theme.font
	hint.TextSize = 12
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Theme.textMuted
	hint.Text = "Removes the type from the Insert list. Existing placed instances are left in the place (orphaned)."
	hint.ZIndex = 62
	hint.Parent = panel

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundColor3 = Theme.bgDeep
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(12, 84)
	scroll.Size = UDim2.new(1, -24, 1, -136)
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ZIndex = 62
	scroll.Parent = panel

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = scroll

	if #types == 0 then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.Font = Theme.font
		empty.TextSize = 14
		empty.TextColor3 = Theme.textMuted
		empty.Text = "No custom types to delete."
		empty.ZIndex = 63
		empty.Parent = scroll
	end

	for i, def in types do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Theme.bgRaised
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, -8, 0, 32)
		row.LayoutOrder = i
		row.ZIndex = 63
		row.Parent = scroll

		local rc = Instance.new("UICorner")
		rc.CornerRadius = Theme.corner
		rc.Parent = row

		local icon = IconCatalog.createIconWidget(row, def.icon, 18)
		icon.Position = UDim2.fromOffset(8, 7)
		icon.ZIndex = 64

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(34, 0)
		name.Size = UDim2.new(1, -110, 1, 0)
		name.Font = Theme.font
		name.TextSize = 14
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = Theme.textBright
		name.Text = def.name
		name.ZIndex = 64
		name.Parent = row

		local del = Theme.makeButton(row, "Delete", { Size = UDim2.fromOffset(64, 22) })
		del.Position = UDim2.new(1, -72, 0.5, -11)
		del.BackgroundColor3 = Theme.danger
		del.ZIndex = 64
		del.MouseButton1Click:Connect(function()
			Registry.delete(def.id)
			row:Destroy()
			if onDeleted then
				onDeleted()
			end
		end)
	end

	local close = Theme.makeButton(panel, "Close", { Size = UDim2.fromOffset(90, 28) })
	close.Position = UDim2.new(1, -102, 1, -40)
	close.ZIndex = 62
	close.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)
end

return TypeEditor
