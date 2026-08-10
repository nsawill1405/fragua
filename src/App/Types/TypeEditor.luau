local Theme = require(script.Parent.Parent.Shared.Theme)
local UiUtil = require(script.Parent.Parent.Shared.UiUtil)
local Util = require(script.Parent.Parent.Shared.Util)
local IconCatalog = require(script.Parent.IconCatalog)
local IconPicker = require(script.Parent.IconPicker)
local Registry = require(script.Parent.Registry)

local TypeEditor = {}

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
	panel.Size = UDim2.fromOffset(300, 340)
	panel.BackgroundColor3 = Theme.bg
	panel.BorderSizePixel = 0
	panel.ZIndex = 61
	panel.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.borderLight
	stroke.Parent = panel

	local titleBar = Instance.new("Frame")
	titleBar.BackgroundTransparency = 1
	titleBar.Size = UDim2.new(1, 0, 0, 30)
	titleBar.ZIndex = 62
	titleBar.Active = true
	titleBar.Parent = panel
	UiUtil.makeDraggable(titleBar, panel)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -40, 0, 20)
	title.Font = Theme.fontBold
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.textBright
	title.Text = "New Type"
	title.ZIndex = 63
	title.Parent = titleBar

	local close = UiUtil.makeCloseButton(titleBar, 20)
	close.Position = UDim2.new(1, -26, 0, 5)
	close.ZIndex = 63
	close.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	local function field(labelText: string, y: number, placeholder: string): TextBox
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(12, y)
		label.Size = UDim2.new(1, -24, 0, 14)
		label.Font = Theme.font
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Theme.textMuted
		label.Text = labelText
		label.ZIndex = 62
		label.Parent = panel

		local box = Instance.new("TextBox")
		box.ClearTextOnFocus = false
		box.PlaceholderText = placeholder
		box.PlaceholderColor3 = Theme.textMuted
		box.Font = Theme.font
		box.TextSize = 13
		box.TextColor3 = Theme.textBright
		box.BackgroundColor3 = Theme.inputBg
		box.BorderSizePixel = 0
		box.Position = UDim2.fromOffset(12, y + 16)
		box.Size = UDim2.new(1, -24, 0, 26)
		box.Text = ""
		box.ZIndex = 62
		box.Parent = panel
		local c = Instance.new("UICorner")
		c.CornerRadius = Theme.corner
		c.Parent = box
		return box
	end

	local nameBox = field("Name", 36, "Zombie")
	local extendsBox = field("Extends", 86, "Humanoid")
	extendsBox.Text = "Humanoid"

	local iconLabel = Instance.new("TextLabel")
	iconLabel.BackgroundTransparency = 1
	iconLabel.Position = UDim2.fromOffset(12, 136)
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
	iconPreview.Position = UDim2.fromOffset(12, 154)
	IconCatalog.setZIndex(iconPreview, 62)

	local iconBtn = Theme.makeButton(panel, "Choose…", { Size = UDim2.fromOffset(84, 24) })
	iconBtn.Position = UDim2.fromOffset(42, 153)
	iconBtn.ZIndex = 62
	iconBtn.MouseButton1Click:Connect(function()
		-- Parent to host (explorer root), not nested overlay, with high z-index
		IconPicker.open(host, selectedIcon, function(id)
			selectedIcon = id
			iconPreview:SetAttribute("IconId", id)
		end)
	end)

	local propsBox = field("Properties (name:type:default)", 188, "")
	propsBox.Position = UDim2.fromOffset(12, 204)
	propsBox.Size = UDim2.new(1, -24, 0, 72)
	propsBox.Text = "IsHostile:boolean:true\nDetectRange:number:40"
	propsBox.TextYAlignment = Enum.TextYAlignment.Top
	propsBox.MultiLine = true
	propsBox.TextWrapped = true

	local errorLabel = Instance.new("TextLabel")
	errorLabel.BackgroundTransparency = 1
	errorLabel.Position = UDim2.fromOffset(12, 280)
	errorLabel.Size = UDim2.new(1, -24, 0, 16)
	errorLabel.Font = Theme.font
	errorLabel.TextSize = 11
	errorLabel.TextXAlignment = Enum.TextXAlignment.Left
	errorLabel.TextColor3 = Theme.danger
	errorLabel.Text = ""
	errorLabel.ZIndex = 62
	errorLabel.Parent = panel

	local cancel = Theme.makeButton(panel, "Cancel", { Size = UDim2.fromOffset(72, 26) })
	cancel.Position = UDim2.new(1, -160, 1, -36)
	cancel.ZIndex = 62
	cancel.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	local save = Theme.makeButton(panel, "Create", { Size = UDim2.fromOffset(72, 26) })
	save.Position = UDim2.new(1, -80, 1, -36)
	save.BackgroundColor3 = Theme.accent
	save.ZIndex = 62

	save.MouseButton1Click:Connect(function()
		local name = string.gsub(nameBox.Text, "^%s*(.-)%s*$", "%1")
		if name == "" or not string.match(name, "^[%a_][%w_]*$") then
			errorLabel.Text = "Use a valid identifier name."
			return
		end
		if Registry.get(name) then
			errorLabel.Text = "That type already exists."
			return
		end
		local extends = string.gsub(extendsBox.Text, "^%s*(.-)%s*$", "%1")
		if extends == "" then
			extends = "Configuration"
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
					errorLabel.Text = "Bad line: " .. trimmed
					return
				end
				pname = string.gsub(pname, "^%s*(.-)%s*$", "%1")
				ptype = string.gsub(ptype, "^%s*(.-)%s*$", "%1")
				local ok, value = Util.parseValue(ptype, pdefault or "")
				if not ok then
					errorLabel.Text = "Bad default for " .. pname
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
			description = "",
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
