local Theme = require(script.Parent.Parent.Shared.Theme)
local UiUtil = require(script.Parent.Parent.Shared.UiUtil)
local SettingsStore = require(script.Parent.Parent.Settings.Store)
local EngineSchemas = require(script.Parent.Parent.Types.EngineSchemas)
local IconCatalog = require(script.Parent.Parent.Types.IconCatalog)
local Registry = require(script.Parent.Parent.Types.Registry)
local TypeEditor = require(script.Parent.Parent.Types.TypeEditor)
local InsertFlow = require(script.Parent.InsertFlow)

local Workspace = game:GetService("Workspace")

local InsertPicker = {}

export type InsertChoice =
	{ kind: "engine", className: string }
	| { kind: "custom", typeId: string }
	| { kind: "create_type" }
	| { kind: "edit_type", typeId: string }

local creatableCache: { [string]: boolean } = {}
local function canCreateClass(className: string): boolean
	if creatableCache[className] ~= nil then
		return creatableCache[className]
	end
	local ok = pcall(function()
		local o = Instance.new(className)
		o:Destroy()
	end)
	creatableCache[className] = ok
	return ok
end

function InsertPicker.open(host: Instance, onChoose: (InsertChoice) -> ())
	local sectionCollapsed: { [string]: boolean } = {}

	local overlay = Instance.new("Frame")
	overlay.Name = "InsertPicker"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 40
	overlay.Parent = host

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(320, 440)
	panel.BackgroundColor3 = Theme.bg
	panel.BorderSizePixel = 0
	panel.ZIndex = 41
	panel.Parent = overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.borderLight
	stroke.Thickness = 1
	stroke.Parent = panel

	local titleBar = Instance.new("Frame")
	titleBar.BackgroundTransparency = 1
	titleBar.Size = UDim2.new(1, 0, 0, 34)
	titleBar.ZIndex = 42
	titleBar.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -48, 0, 20)
	title.Font = Theme.fontBold
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.textBright
	title.Text = "Insert Object"
	title.ZIndex = 43
	title.Parent = titleBar

	local close = UiUtil.makeCloseButton(titleBar, 22)
	close.Position = UDim2.new(1, -30, 0, 6)
	close.ZIndex = 43
	close.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	local search = Instance.new("TextBox")
	search.PlaceholderText = "Search..."
	search.ClearTextOnFocus = false
	search.Text = ""
	search.Font = Theme.font
	search.TextSize = 13
	search.TextColor3 = Theme.textBright
	search.PlaceholderColor3 = Theme.textMuted
	search.BackgroundColor3 = Theme.inputBg
	search.BorderSizePixel = 0
	search.Position = UDim2.fromOffset(14, 38)
	search.Size = UDim2.new(1, -28, 0, 26)
	search.ZIndex = 42
	search.Parent = panel

	local sc = Instance.new("UICorner")
	sc.CornerRadius = Theme.corner
	sc.Parent = search

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundColor3 = Theme.bgDeep
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(14, 72)
	scroll.Size = UDim2.new(1, -28, 1, -86)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.borderLight
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ZIndex = 42
	scroll.Parent = panel

	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = Theme.corner
	listCorner.Parent = scroll

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = scroll

	local function row(opts: {
		label: string,
		iconId: string?,
		order: number,
		onClick: () -> (),
		onEdit: (() -> ())?,
		onDelete: (() -> ())?,
	})
		local btn = Instance.new("TextButton")
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Theme.bgHover
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.Size = UDim2.new(1, -8, 0, 24)
		btn.Text = ""
		btn.LayoutOrder = opts.order
		btn.ZIndex = 43
		btn.Parent = scroll

		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 4)
		rc.Parent = btn

		local rightPad = 12
		if opts.onDelete then
			rightPad += 20
		end
		if opts.onEdit then
			rightPad += 28
		end

		if opts.iconId then
			local icon = IconCatalog.createIconWidget(btn, opts.iconId, 14)
			icon.Position = UDim2.fromOffset(8, 5)
			IconCatalog.setZIndex(icon, 45)
		end

		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromOffset(if opts.iconId then 28 else 10, 0)
		text.Size = UDim2.new(1, -rightPad - (if opts.iconId then 28 else 10), 1, 0)
		text.Font = Theme.font
		text.TextSize = 13
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextColor3 = Theme.textBright
		text.TextTruncate = Enum.TextTruncate.AtEnd
		text.Text = opts.label
		text.ZIndex = 44
		text.Active = false
		text.Parent = btn

		local xOffset = 6
		if opts.onDelete then
			local del = Instance.new("TextButton")
			del.AutoButtonColor = false
			del.BackgroundTransparency = 1
			del.AnchorPoint = Vector2.new(1, 0.5)
			del.Position = UDim2.new(1, -xOffset, 0.5, 0)
			del.Size = UDim2.fromOffset(18, 18)
			del.Font = Enum.Font.GothamBold
			del.TextSize = 14
			del.Text = "x"
			del.TextColor3 = Theme.textMuted
			del.ZIndex = 46
			del.Parent = btn
			del.MouseEnter:Connect(function()
				del.TextColor3 = Theme.danger
			end)
			del.MouseLeave:Connect(function()
				del.TextColor3 = Theme.textMuted
			end)
			del.MouseButton1Click:Connect(function()
				opts.onDelete()
			end)
			xOffset += 20
		end

		if opts.onEdit then
			local edit = Instance.new("TextButton")
			edit.AutoButtonColor = false
			edit.BackgroundTransparency = 1
			edit.AnchorPoint = Vector2.new(1, 0.5)
			edit.Position = UDim2.new(1, -xOffset, 0.5, 0)
			edit.Size = UDim2.fromOffset(28, 18)
			edit.Font = Theme.font
			edit.TextSize = 11
			edit.Text = "Edit"
			edit.TextColor3 = Theme.textMuted
			edit.ZIndex = 46
			edit.Parent = btn
			edit.MouseEnter:Connect(function()
				edit.TextColor3 = Theme.accent
			end)
			edit.MouseLeave:Connect(function()
				edit.TextColor3 = Theme.textMuted
			end)
			edit.MouseButton1Click:Connect(function()
				opts.onEdit()
			end)
		end

		btn.MouseEnter:Connect(function()
			btn.BackgroundTransparency = 0
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundTransparency = 1
		end)
		btn.MouseButton1Click:Connect(opts.onClick)
	end

	local function sectionHeader(text: string, order: number, collapsed: boolean, onToggle: () -> ())
		local color = UiUtil.sectionColor(text)
		local header = Instance.new("TextButton")
		header.AutoButtonColor = false
		header.BackgroundColor3 = Theme.section
		header.BorderSizePixel = 0
		header.Size = UDim2.new(1, -8, 0, 24)
		header.Text = ""
		header.LayoutOrder = order
		header.ZIndex = 43
		header.Parent = scroll

		local accent = Instance.new("Frame")
		accent.BackgroundColor3 = color
		accent.BorderSizePixel = 0
		accent.Size = UDim2.new(0, 3, 1, -4)
		accent.Position = UDim2.fromOffset(0, 2)
		accent.ZIndex = 44
		accent.Parent = header

		local twist = UiUtil.makeChevron(header, not collapsed, 14)
		twist.Position = UDim2.fromOffset(8, 5)
		twist.ZIndex = 44

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(26, 0)
		label.Size = UDim2.new(1, -30, 1, 0)
		label.Font = Theme.fontBold
		label.TextSize = 10
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = color
		label.Text = string.upper(text)
		label.ZIndex = 44
		label.Parent = header

		header.MouseButton1Click:Connect(function()
			local nextExpanded = collapsed -- currently collapsed, so expand
			UiUtil.setChevronExpanded(twist, nextExpanded, true)
			task.delay(0.05, onToggle)
		end)
	end

	local function rebuild(filter: string)
		for _, child in scroll:GetChildren() do
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local lower = string.lower(filter)
		local order = 1
		local filtering = lower ~= ""

		local function showSection(name: string): boolean
			if filtering then
				return true -- auto-expand while filtering
			end
			return not sectionCollapsed[name]
		end

		sectionHeader("Custom", order, sectionCollapsed.Custom == true and not filtering, function()
			sectionCollapsed.Custom = not sectionCollapsed.Custom
			rebuild(search.Text)
		end)
		order += 1

		if showSection("Custom") then
			row({
				label = "Create New Type...",
				iconId = "emoji_plus",
				order = order,
				onClick = function()
					overlay:Destroy()
					onChoose({ kind = "create_type" })
				end,
			})
			order += 1

			local customCount = 0
			for _, def in Registry.list() do
				if lower == "" or string.find(string.lower(def.name), lower, 1, true) then
					local typeId = def.id
					row({
						label = def.name,
						iconId = def.icon,
						order = order,
						onClick = function()
							overlay:Destroy()
							onChoose({ kind = "custom", typeId = typeId })
						end,
						onEdit = function()
							overlay:Destroy()
							onChoose({ kind = "edit_type", typeId = typeId })
						end,
						onDelete = function()
							local count = Registry.countInstances(typeId)
							local function doDelete()
								Registry.delete(typeId)
								rebuild(search.Text)
							end
							if count > 0 and SettingsStore.getConfirmOnDelete() then
								local confirm = Instance.new("Frame")
								confirm.Name = "DeleteConfirm"
								confirm.BackgroundColor3 = Color3.new(0, 0, 0)
								confirm.BackgroundTransparency = 0.45
								confirm.Size = UDim2.fromScale(1, 1)
								confirm.ZIndex = 80
								confirm.Parent = overlay

								local box = Instance.new("Frame")
								box.AnchorPoint = Vector2.new(0.5, 0.5)
								box.Position = UDim2.fromScale(0.5, 0.5)
								box.Size = UDim2.fromOffset(260, 120)
								box.BackgroundColor3 = Theme.bg
								box.BorderSizePixel = 0
								box.ZIndex = 81
								box.Parent = confirm
								local bc = Instance.new("UICorner")
								bc.CornerRadius = UDim.new(0, 8)
								bc.Parent = box

								local msg = Instance.new("TextLabel")
								msg.BackgroundTransparency = 1
								msg.Position = UDim2.fromOffset(12, 12)
								msg.Size = UDim2.new(1, -24, 0, 48)
								msg.Font = Theme.font
								msg.TextSize = 13
								msg.TextWrapped = true
								msg.TextColor3 = Theme.textBright
								msg.Text = `Delete type "{typeId}" and {count} placed instance(s)?`
								msg.ZIndex = 82
								msg.Parent = box

								local cancel = Theme.makeButton(box, "Cancel", { Size = UDim2.fromOffset(80, 28) })
								cancel.Position = UDim2.new(1, -180, 1, -40)
								cancel.ZIndex = 82
								cancel.MouseButton1Click:Connect(function()
									confirm:Destroy()
								end)

								local okBtn = Theme.makeButton(box, "Delete", { Size = UDim2.fromOffset(80, 28) })
								okBtn.Position = UDim2.new(1, -90, 1, -40)
								okBtn.BackgroundColor3 = Theme.danger
								okBtn.ZIndex = 82
								okBtn.MouseButton1Click:Connect(function()
									confirm:Destroy()
									doDelete()
								end)
							else
								doDelete()
							end
						end,
					})
					order += 1
					customCount += 1
				end
			end
			if customCount == 0 and lower == "" then
				local empty = Instance.new("TextLabel")
				empty.BackgroundTransparency = 1
				empty.Size = UDim2.new(1, -8, 0, 20)
				empty.Font = Theme.font
				empty.TextSize = 11
				empty.TextColor3 = Theme.textMuted
				empty.TextXAlignment = Enum.TextXAlignment.Left
				empty.Text = "  No custom types yet"
				empty.LayoutOrder = order
				empty.ZIndex = 43
				empty.Parent = scroll
				order += 1
			end
		end

		for _, section in EngineSchemas.insertSections() do
			local matched = {}
			for _, className in section.classes do
				if lower == "" or string.find(string.lower(className), lower, 1, true) then
					if canCreateClass(className) then
						table.insert(matched, className)
					end
				end
			end
			if #matched > 0 then
				local titleText = section.title
				sectionHeader(titleText, order, sectionCollapsed[titleText] == true and not filtering, function()
					sectionCollapsed[titleText] = not sectionCollapsed[titleText]
					rebuild(search.Text)
				end)
				order += 1

				if showSection(titleText) then
					for _, className in matched do
						local cn = className
						row({
							label = className,
							iconId = "class_" .. className,
							order = order,
							onClick = function()
								overlay:Destroy()
								onChoose({ kind = "engine", className = cn })
							end,
						})
						order += 1
					end
				end
			end
		end
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		rebuild(search.Text)
	end)
	rebuild("")
	search:CaptureFocus()
end

function InsertPicker.handleChoice(
	host: Instance,
	choice: InsertChoice,
	parent: Instance?,
	afterInsert: (Instance) -> (),
	refresh: () -> ()
)
	if choice.kind == "create_type" then
		TypeEditor.open(host, function(id)
			local resolvedParent = InsertFlow.resolveParent(parent, Workspace)
			local ok, result = pcall(function()
				return Registry.createInstance(id, resolvedParent)
			end)
			if not ok then
				return false, "Type saved, but insertion failed. Retry insert."
			end
			afterInsert(result)
			refresh()
			return true
		end)
		return
	end
	if choice.kind == "edit_type" then
		TypeEditor.open(host, function(_id)
			refresh()
		end, choice.typeId)
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
			warn("[Fragua] Could not create " .. choice.className)
		end
		return
	end
	if choice.kind == "custom" then
		local inst = Registry.createInstance(choice.typeId, parent)
		afterInsert(inst)
	end
end

return InsertPicker
