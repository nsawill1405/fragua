local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.Shared.Theme)
local Util = require(script.Parent.Parent.Shared.Util)
local Constants = require(script.Parent.Parent.Shared.Constants)
local IconCatalog = require(script.Parent.Parent.Types.IconCatalog)
local Registry = require(script.Parent.Parent.Types.Registry)
local ContextMenu = require(script.ContextMenu)

local Tree = {}

local ROOT_SERVICES = {
	"Workspace",
	"Players",
	"Lighting",
	"MaterialService",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"SoundService",
	"TextChatService",
}

local SERVICE_COLORS: { [string]: Color3 } = {
	Workspace = Color3.fromRGB(100, 180, 120),
	Players = Color3.fromRGB(100, 160, 220),
	Lighting = Color3.fromRGB(240, 200, 100),
	MaterialService = Color3.fromRGB(180, 140, 100),
	ReplicatedFirst = Color3.fromRGB(160, 120, 200),
	ReplicatedStorage = Color3.fromRGB(120, 160, 220),
	ServerScriptService = Color3.fromRGB(100, 200, 140),
	ServerStorage = Color3.fromRGB(200, 140, 100),
	StarterGui = Color3.fromRGB(100, 180, 210),
	StarterPack = Color3.fromRGB(180, 160, 100),
	StarterPlayer = Color3.fromRGB(140, 180, 200),
	Teams = Color3.fromRGB(220, 120, 120),
	SoundService = Color3.fromRGB(160, 120, 220),
	TextChatService = Color3.fromRGB(120, 200, 200),
}

local function iconFor(instance: Instance): string
	if Registry.isFraguaInstance(instance) then
		local typeId = Registry.getTypeId(instance)
		local def = typeId and Registry.get(typeId)
		if def then
			return def.icon
		end
		return "emoji_warning"
	end
	return "class_" .. instance.ClassName
end

local function isHidden(inst: Instance): boolean
	if inst.Name == "_FraguaNameplate" then
		return true
	end
	if inst.Name == Constants.ROOT_FOLDER and inst.Parent and inst.Parent.Name == "ServerStorage" then
		return true
	end
	if inst:FindFirstAncestor(Constants.ROOT_FOLDER) then
		local anc = inst:FindFirstAncestor(Constants.ROOT_FOLDER)
		if anc and anc.Parent and anc.Parent.Name == "ServerStorage" then
			return true
		end
	end
	-- Behavior template siblings like ZombieBehavior living under Types
	if string.sub(inst.Name, -8) == "Behavior" and inst:IsA("ModuleScript") then
		local parent = inst.Parent
		if parent and parent.Name == Constants.TYPES_FOLDER then
			return true
		end
	end
	return false
end

local function shouldTrackDescendant(inst: Instance): boolean
	if isHidden(inst) or inst:FindFirstAncestor("_FraguaNameplate") then
		return false
	end
	for _, serviceName in ROOT_SERVICES do
		local ok, service = pcall(function()
			return game:GetService(serviceName)
		end)
		if ok and service and (inst == service or inst:IsDescendantOf(service)) then
			return true
		end
	end
	return false
end

local function isServiceRoot(inst: Instance): boolean
	return inst.Parent == game and table.find(ROOT_SERVICES, inst.Name) ~= nil
end

function Tree.mount(scroll: ScrollingFrame, opts: {
	host: Instance,
	onInsertRequest: (parent: Instance) -> (),
	filterText: () -> string,
})
	local expanded: { [Instance]: boolean } = {}
	local sectionOpen: { [string]: boolean } = {}
	local rowByInstance: { [Instance]: Frame } = {}
	local plusByInstance: { [Instance]: TextButton } = {}
	local selected: { [Instance]: boolean } = {}
	local hoveredInstance: Instance? = nil
	local hoverGen = 0
	local orderCounter = 0
	local renameToken = 0

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local function syncSelectionFromStudio()
		table.clear(selected)
		for _, inst in Selection:Get() do
			selected[inst] = true
		end
	end

	local function paintRow(instance: Instance)
		local row = rowByInstance[instance]
		if not row then
			return
		end
		if selected[instance] then
			row.BackgroundColor3 = Theme.bgSelected
		elseif hoveredInstance == instance then
			row.BackgroundColor3 = Theme.bgHover
		else
			row.BackgroundColor3 = Theme.bg
		end
	end

	local function refreshPlusVisibility()
		for inst, plus in plusByInstance do
			plus.Visible = hoveredInstance == inst
		end
		for inst in rowByInstance do
			paintRow(inst)
		end
	end

	local function setHovered(instance: Instance?)
		hoveredInstance = instance
		refreshPlusVisibility()
	end

	local function paintSelection()
		syncSelectionFromStudio()
		for inst in rowByInstance do
			paintRow(inst)
		end
	end

	local function setStudioSelection(inst: Instance?)
		if not inst then
			Selection:Set({})
		else
			Selection:Set({ inst })
		end
		paintSelection()
	end

	local rebuild: () -> ()

	local function beginRename(instance: Instance, label: TextButton, cluster: Frame)
		if isServiceRoot(instance) then
			return
		end
		label.Visible = false
		local cancelled = false
		local box = Instance.new("TextBox")
		box.Name = "RenameBox"
		box.ClearTextOnFocus = false
		box.BackgroundColor3 = Theme.inputBg
		box.BorderSizePixel = 0
		box.Font = Theme.font
		box.TextSize = 13
		box.TextColor3 = Theme.textBright
		box.Text = instance.Name
		box.Size = UDim2.fromOffset(math.max(80, label.AbsoluteSize.X + 24), Theme.rowHeight - 4)
		box.LayoutOrder = 1
		box.Parent = cluster
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 3)
		c.Parent = box
		box:CaptureFocus()
		box.SelectionStart = 1
		box.CursorPosition = #instance.Name + 1

		local function finish(commit: boolean)
			if box.Parent == nil then
				return
			end
			if commit and not cancelled then
				local name = string.gsub(box.Text, "^%s*(.-)%s*$", "%1")
				if name ~= "" and name ~= instance.Name then
					ChangeHistoryService:SetWaypoint("Fragua Rename")
					instance.Name = name
				end
			end
			box:Destroy()
			label.Visible = true
			label.Text = instance.Name
		end

		box.FocusLost:Connect(function()
			finish(true)
		end)
		UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Escape and box.Parent then
				cancelled = true
				finish(false)
			end
		end)
	end

	local function duplicateInstance(instance: Instance)
		if isServiceRoot(instance) then
			return
		end
		local clone = instance:Clone()
		clone.Parent = instance.Parent
		clone.Name = instance.Name
		ChangeHistoryService:SetWaypoint("Fragua Duplicate")
		setStudioSelection(clone)
		rebuild()
	end

	local function deleteInstance(instance: Instance)
		if isServiceRoot(instance) then
			return
		end
		local parent = instance.Parent
		ChangeHistoryService:SetWaypoint("Fragua Delete")
		instance:Destroy()
		if parent and parent ~= game then
			setStudioSelection(parent)
		else
			Selection:Set({})
		end
		rebuild()
	end

	local function openContext(instance: Instance, screenPos: Vector2)
		setStudioSelection(instance)
		local hasChildren = false
		for _, child in instance:GetChildren() do
			if not isHidden(child) then
				hasChildren = true
				break
			end
		end
		ContextMenu.open(opts.host, screenPos, {
			{
				label = "Insert Object…",
				onClick = function()
					opts.onInsertRequest(instance)
				end,
			},
			{
				label = "Rename",
				disabled = isServiceRoot(instance),
				onClick = function()
					local row = rowByInstance[instance]
					if not row then
						return
					end
					local cluster = row:FindFirstChild("Cluster")
					local label = cluster and cluster:FindFirstChild("Label")
					if cluster and label and label:IsA("TextButton") then
						beginRename(instance, label, cluster :: Frame)
					end
				end,
			},
			{
				label = "Duplicate",
				disabled = isServiceRoot(instance),
				onClick = function()
					duplicateInstance(instance)
				end,
			},
			{ separator = true, label = "" },
			{
				label = if expanded[instance] then "Collapse" else "Expand",
				disabled = not hasChildren,
				onClick = function()
					expanded[instance] = not expanded[instance]
					rebuild()
				end,
			},
			{
				label = "Copy Path",
				onClick = function()
					pcall(function()
						-- plugin clipboard if available
						local pluginHost = opts.host:FindFirstAncestorWhichIsA("PluginGui")
						if pluginHost then
							-- best-effort: print path
						end
					end)
					print("[Fragua] Path:", instance:GetFullName())
				end,
			},
			{ separator = true, label = "" },
			{
				label = "Delete",
				danger = true,
				disabled = isServiceRoot(instance),
				onClick = function()
					deleteInstance(instance)
				end,
			},
		})
	end

	local function makeRow(instance: Instance, depth: number, hasChildren: boolean)
		orderCounter += 1
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, Theme.rowHeight)
		row.BackgroundColor3 = Theme.bg
		row.LayoutOrder = orderCounter
		row.Active = true
		row.Parent = scroll
		rowByInstance[instance] = row

		local padLeft = 4 + depth * 14
		local accentColor = SERVICE_COLORS[instance.Name]

		if depth == 0 and accentColor then
			local accent = Instance.new("Frame")
			accent.BackgroundColor3 = accentColor
			accent.BorderSizePixel = 0
			accent.Size = UDim2.new(0, 3, 1, -4)
			accent.Position = UDim2.fromOffset(0, 2)
			accent.Parent = row
		end

		local twist = Instance.new("TextButton")
		twist.Name = "Twist"
		twist.AutoButtonColor = false
		twist.BackgroundTransparency = 1
		twist.BorderSizePixel = 0
		twist.Position = UDim2.fromOffset(padLeft, 0)
		twist.Size = UDim2.fromOffset(16, Theme.rowHeight)
		twist.Font = Enum.Font.GothamBold
		twist.TextSize = 11
		twist.TextColor3 = Theme.textMuted
		twist.Text = if hasChildren then (if expanded[instance] then "v" else ">") else ""
		twist.Parent = row
		if hasChildren then
			twist.MouseButton1Click:Connect(function()
				expanded[instance] = not expanded[instance]
				rebuild()
			end)
		else
			twist.Active = false
		end

		local icon = IconCatalog.createIconWidget(row, iconFor(instance), 14)
		icon.Position = UDim2.fromOffset(padLeft + 18, 5)

		local cluster = Instance.new("Frame")
		cluster.Name = "Cluster"
		cluster.BackgroundTransparency = 1
		cluster.Position = UDim2.fromOffset(padLeft + 36, 0)
		cluster.Size = UDim2.new(1, -(padLeft + 40), 1, 0)
		cluster.Active = false
		cluster.Parent = row

		local clusterLayout = Instance.new("UIListLayout")
		clusterLayout.FillDirection = Enum.FillDirection.Horizontal
		clusterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		clusterLayout.SortOrder = Enum.SortOrder.LayoutOrder
		clusterLayout.Padding = UDim.new(0, 4)
		clusterLayout.Parent = cluster

		local label = Instance.new("TextButton")
		label.Name = "Label"
		label.AutoButtonColor = false
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, Theme.rowHeight)
		label.Font = Theme.font
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Theme.textBright
		label.Text = instance.Name
		label.LayoutOrder = 1
		label.Parent = cluster

		local plus = Instance.new("TextButton")
		plus.Name = "Plus"
		plus.AutoButtonColor = false
		plus.BackgroundTransparency = 1
		plus.BorderSizePixel = 0
		plus.Size = UDim2.fromOffset(16, 16)
		plus.Font = Enum.Font.GothamBold
		plus.TextSize = 14
		plus.Text = "+"
		plus.TextColor3 = Theme.accent
		plus.Visible = false
		plus.LayoutOrder = 2
		plus.Parent = cluster
		plusByInstance[instance] = plus
		plus.MouseButton1Click:Connect(function()
			setStudioSelection(instance)
			opts.onInsertRequest(instance)
		end)

		if Registry.isFraguaInstance(instance) then
			local typeId = Registry.getTypeId(instance)
			local def = typeId and Registry.get(typeId)
			local badge = Instance.new("TextLabel")
			badge.BackgroundTransparency = 1
			badge.AutomaticSize = Enum.AutomaticSize.X
			badge.Size = UDim2.fromOffset(0, Theme.rowHeight)
			badge.Font = Theme.font
			badge.TextSize = 11
			badge.TextColor3 = Theme.textMuted
			badge.Text = def and ("· " .. def.name) or "· ?"
			badge.Active = false
			badge.LayoutOrder = 3
			badge.Parent = cluster
		end

		local myGen = 0
		row.MouseEnter:Connect(function()
			hoverGen += 1
			myGen = hoverGen
			setHovered(instance)
		end)
		row.MouseLeave:Connect(function()
			local leaveGen = hoverGen
			task.delay(0.05, function()
				if hoverGen ~= leaveGen then
					return
				end
				-- only clear if still the hovered instance and mouse left
				if hoveredInstance == instance then
					local mouse = UserInputService:GetMouseLocation()
					local pos = row.AbsolutePosition
					local size = row.AbsoluteSize
					local over = mouse.X >= pos.X
						and mouse.X <= pos.X + size.X
						and mouse.Y >= pos.Y
						and mouse.Y <= pos.Y + size.Y
					if not over then
						setHovered(nil)
					end
				end
			end)
		end)

		-- Studio-like rename: click name while already selected, hold hover 0.5s
		label.MouseButton1Click:Connect(function()
			local already = selected[instance] == true
			setStudioSelection(instance)
			if not already or isServiceRoot(instance) then
				return
			end
			renameToken += 1
			local token = renameToken
			task.delay(0.5, function()
				if token ~= renameToken then
					return
				end
				if hoveredInstance == instance and selected[instance] then
					beginRename(instance, label, cluster)
				end
			end)
		end)

		row.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				setStudioSelection(instance)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				local pos = UserInputService:GetMouseLocation()
				openContext(instance, pos)
			end
		end)

		paintRow(instance)
	end

	local function matchesFilter(instance: Instance, filter: string): boolean
		if isHidden(instance) then
			return false
		end
		if filter == "" then
			return true
		end
		local lower = string.lower(filter)
		if string.find(string.lower(instance.Name), lower, 1, true) then
			return true
		end
		if string.find(string.lower(instance.ClassName), lower, 1, true) then
			return true
		end
		local typeId = Registry.getTypeId(instance)
		if typeId and string.find(string.lower(typeId), lower, 1, true) then
			return true
		end
		for _, child in instance:GetChildren() do
			if matchesFilter(child, filter) then
				return true
			end
		end
		return false
	end

	local function walk(instance: Instance, depth: number, filter: string)
		if isHidden(instance) then
			return
		end
		if not matchesFilter(instance, filter) and depth > 0 then
			return
		end
		local children = instance:GetChildren()
		table.sort(children, function(a, b)
			return a.Name:lower() < b.Name:lower()
		end)
		local visibleChildren = {}
		for _, child in children do
			if not isHidden(child) and matchesFilter(child, filter) then
				table.insert(visibleChildren, child)
			end
		end
		makeRow(instance, depth, #visibleChildren > 0)
		if expanded[instance] or (filter ~= "" and #visibleChildren > 0) then
			if filter ~= "" then
				expanded[instance] = true
			end
			for _, child in visibleChildren do
				walk(child, depth + 1, filter)
			end
		end
	end

	rebuild = function()
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") and (child.Name == "Row" or child.Name == "Section") then
				child:Destroy()
			end
		end
		table.clear(rowByInstance)
		table.clear(plusByInstance)
		hoveredInstance = nil
		orderCounter = 0
		syncSelectionFromStudio()
		local filter = opts.filterText()
		for _, serviceName in ROOT_SERVICES do
			local ok, service = pcall(function()
				return game:GetService(serviceName)
			end)
			if ok and service then
				if sectionOpen[serviceName] == nil then
					sectionOpen[serviceName] = serviceName == "Workspace" or serviceName == "ServerStorage"
				end
				if expanded[service] == nil then
					expanded[service] = sectionOpen[serviceName]
				end
				-- Collapsible colored service segment header is the service row itself
				if filter == "" or matchesFilter(service, filter) then
					walk(service, 0, filter)
				end
			end
		end
	end

	local scheduleRebuild = Util.debounce(0.1, rebuild)

	local conns: { RBXScriptConnection } = {}
	table.insert(conns, Selection.SelectionChanged:Connect(paintSelection))
	table.insert(
		conns,
		game.DescendantAdded:Connect(function(inst)
			if shouldTrackDescendant(inst) then
				scheduleRebuild()
			end
		end)
	)
	table.insert(
		conns,
		game.DescendantRemoving:Connect(function(inst)
			if shouldTrackDescendant(inst) then
				scheduleRebuild()
			end
		end)
	)
	table.insert(conns, Registry.Changed:Connect(rebuild))

	-- Global mouse move: ensure only one hover
	table.insert(
		conns,
		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local mouse = UserInputService:GetMouseLocation()
			local found: Instance? = nil
			for inst, row in rowByInstance do
				local pos = row.AbsolutePosition
				local size = row.AbsoluteSize
				if mouse.X >= pos.X and mouse.X <= pos.X + size.X and mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y then
					found = inst
					break
				end
			end
			if found ~= hoveredInstance then
				setHovered(found)
			end
		end)
	)

	rebuild()

	return {
		rebuild = rebuild,
		reveal = function(inst: Instance)
			local current: Instance? = inst.Parent
			while current and current ~= game do
				expanded[current] = true
				current = current.Parent
			end
			rebuild()
		end,
		getSelection = function(): Instance?
			return Selection:Get()[1]
		end,
		destroy = function()
			for _, c in conns do
				c:Disconnect()
			end
		end,
	}
end

return Tree
