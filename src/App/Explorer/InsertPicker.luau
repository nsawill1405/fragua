local Theme = require(script.Parent.Parent.Shared.Theme)
local EngineSchemas = require(script.Parent.Parent.Types.EngineSchemas)
local IconCatalog = require(script.Parent.Parent.Types.IconCatalog)
local Registry = require(script.Parent.Parent.Types.Registry)
local TypeEditor = require(script.Parent.Parent.Types.TypeEditor)

local InsertPicker = {}

export type InsertChoice =
	{ kind: "engine", className: string }
	| { kind: "custom", typeId: string }
	| { kind: "create_type" }
	| { kind: "delete_type" }

function InsertPicker.open(host: Instance, onChoose: (InsertChoice) -> ())
	local overlay = Instance.new("Frame")
	overlay.Name = "InsertPicker"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 40
	overlay.Parent = host

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 420)
	panel.BackgroundColor3 = Theme.bg
	panel.BorderSizePixel = 0
	panel.ZIndex = 41
	panel.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 24)
	title.Font = Theme.fontBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.textBright
	title.Text = "Insert Object"
	title.ZIndex = 42
	title.Parent = panel

	local search = Instance.new("TextBox")
	search.PlaceholderText = "Search classes and custom types…"
	search.ClearTextOnFocus = false
	search.Text = ""
	search.Font = Theme.font
	search.TextSize = 14
	search.TextColor3 = Theme.textBright
	search.PlaceholderColor3 = Theme.textMuted
	search.BackgroundColor3 = Theme.inputBg
	search.BorderSizePixel = 0
	search.Position = UDim2.fromOffset(12, 40)
	search.Size = UDim2.new(1, -24, 0, 28)
	search.ZIndex = 42
	search.Parent = panel

	local sc = Instance.new("UICorner")
	sc.CornerRadius = Theme.corner
	sc.Parent = search

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundColor3 = Theme.bgDeep
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(12, 76)
	scroll.Size = UDim2.new(1, -24, 1, -88)
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ZIndex = 42
	scroll.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = scroll

	local function sectionHeader(text: string, order: number)
		local header = Instance.new("TextLabel")
		header.BackgroundColor3 = Theme.section
		header.BorderSizePixel = 0
		header.Size = UDim2.new(1, -8, 0, 22)
		header.Font = Theme.fontBold
		header.TextSize = 12
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextColor3 = Theme.textMuted
		header.Text = "  " .. text
		header.LayoutOrder = order
		header.ZIndex = 43
		header.Parent = scroll
	end

	local function row(label: string, iconId: string?, order: number, handler: () -> ())
		local btn = Instance.new("TextButton")
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Theme.bgRaised
		btn.BorderSizePixel = 0
		btn.Size = UDim2.new(1, -8, 0, 26)
		btn.Text = ""
		btn.LayoutOrder = order
		btn.ZIndex = 43
		btn.Parent = scroll

		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 3)
		rc.Parent = btn

		if iconId then
			local icon = IconCatalog.createIconWidget(btn, iconId, 16)
			icon.Position = UDim2.fromOffset(8, 5)
			icon.ZIndex = 44
		end

		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromOffset(if iconId then 30 else 10, 0)
		text.Size = UDim2.new(1, -36, 1, 0)
		text.Font = Theme.font
		text.TextSize = 14
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextColor3 = Theme.textBright
		text.Text = label
		text.ZIndex = 44
		text.Parent = btn

		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = Theme.bgHover
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Theme.bgRaised
		end)
		btn.MouseButton1Click:Connect(handler)
	end

	local function rebuild(filter: string)
		for _, child in scroll:GetChildren() do
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local lower = string.lower(filter)
		local order = 1

		sectionHeader("Custom", order)
		order += 1

		row("Create New Type…", "emoji_plus", order, function()
			overlay:Destroy()
			onChoose({ kind = "create_type" })
		end)
		order += 1

		row("Delete Type…", "emoji_cross", order, function()
			overlay:Destroy()
			onChoose({ kind = "delete_type" })
		end)
		order += 1

		for _, def in Registry.list() do
			if lower == "" or string.find(string.lower(def.name), lower, 1, true) then
				local typeId = def.id
				row(def.name .. "  (Fragua)", def.icon, order, function()
					overlay:Destroy()
					onChoose({ kind = "custom", typeId = typeId })
				end)
				order += 1
			end
		end

		sectionHeader("Engine", order)
		order += 1

		for _, className in EngineSchemas.insertable() do
			if lower == "" or string.find(string.lower(className), lower, 1, true) then
				local cn = className
				row(className, "class_" .. className, order, function()
					overlay:Destroy()
					onChoose({ kind = "engine", className = cn })
				end)
				order += 1
			end
		end
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		rebuild(search.Text)
	end)
	rebuild("")

	local close = Theme.makeButton(panel, "✕", { Size = UDim2.fromOffset(28, 24) })
	close.Position = UDim2.new(1, -40, 0, 8)
	close.ZIndex = 42
	close.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)
end

function InsertPicker.handleChoice(host: Instance, choice: InsertChoice, parent: Instance?, afterInsert: (Instance) -> (), refresh: () -> ())
	if choice.kind == "create_type" then
		TypeEditor.open(host, function(_id)
			refresh()
		end)
		return
	end
	if choice.kind == "delete_type" then
		TypeEditor.openDelete(host, refresh)
		return
	end
	if not parent then
		warn("[Fragua] Select a parent in Explorer before inserting.")
		return
	end
	if choice.kind == "engine" then
		local ok, inst = pcall(function()
			local obj = Instance.new(choice.className)
			obj.Parent = parent
			return obj
		end)
		if ok and inst then
			afterInsert(inst)
		else
			warn(`[Fragua] Could not create {choice.className}`)
		end
		return
	end
	if choice.kind == "custom" then
		local inst = Registry.createInstance(choice.typeId, parent)
		Registry.applyBehaviorTemplate(inst, choice.typeId)
		afterInsert(inst)
	end
end

return InsertPicker
