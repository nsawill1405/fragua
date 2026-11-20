local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local ScriptEditorService = game:GetService("ScriptEditorService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.Shared.Theme)
local UiUtil = require(script.Parent.Parent.Shared.UiUtil)
local Util = require(script.Parent.Parent.Shared.Util)
local PointerController = require(script.Parent.Parent.Shared.PointerController)
local InteractionMath = require(script.Parent.Parent.Shared.InteractionMath)
local Constants = require(script.Parent.Parent.Shared.Constants)
local SettingsStore = require(script.Parent.Parent.Settings.Store)
local IconCatalog = require(script.Parent.Parent.Types.IconCatalog)
local Registry = require(script.Parent.Parent.Types.Registry)
local ClassOrder = require(script.Parent.ClassOrder)
local ContextMenu = require(script.Parent.ContextMenu)
local SelectionModel = require(script.Parent.SelectionModel)

local Tree = {}

local function openScriptDocument(scriptInst: LuaSourceContainer)
	task.spawn(function()
		local ok, opened, err = pcall(ScriptEditorService.OpenScriptDocumentAsync, ScriptEditorService, scriptInst)
		if not ok or not opened then
			warn(`[Fragua] Could not open {scriptInst:GetFullName()}: {tostring(if ok then err else opened)}`)
		end
	end)
end

local function openBehaviorScript(typeId: string, side: string)
	local behavior = Registry.ensureBehaviorTemplate(typeId, side)
	Selection:Set({ behavior })
	openScriptDocument(behavior)
end

local DEFAULT_SERVICE_COLORS: { [string]: Color3 } = {
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

local function modDown(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)
end

local function shiftDown(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

local function inputHasModifier(input: InputObject?, modifier: Enum.ModifierKey): boolean
	if not input then
		return false
	end
	local ok, down = pcall(function()
		return input:IsModifierKeyDown(modifier)
	end)
	return ok and down == true
end

local function iconFor(instance: Instance, isFragua: boolean, def: any): string
	if isFragua then
		return if def then def.icon else "emoji_warning"
	end
	return "class_" .. instance.ClassName
end

local function isHidden(inst: Instance): boolean
	if inst.Name == "_FraguaNameplate" then
		return true
	end
	-- sticker internals. they only exist after select and were flashing a chevron
	if string.sub(inst.Name, 1, 8) == "_Sticker" then
		return true
	end
	if string.sub(inst.Name, 1, 10) == "_FraguaRef" then
		return true
	end
	-- hide managed place modules (api / runtime)
	if inst:GetAttribute("_FraguaManaged") == true then
		return true
	end
	if (inst.Name == "Fragua" or inst.Name == "FraguaRuntime") and inst:IsA("LuaSourceContainer") then
		local parent = inst.Parent
		if parent and (parent.Name == "ReplicatedStorage" or parent.Name == "ServerScriptService") then
			return true
		end
	end
	-- hide ServerStorage.Fragua internals (type defs + shared behavior templates)
	if inst.Name == Constants.ROOT_FOLDER and inst.Parent and inst.Parent.Name == "ServerStorage" then
		return true
	end
	local anc = inst:FindFirstAncestor(Constants.ROOT_FOLDER)
	if anc and anc.Parent and anc.Parent.Name == "ServerStorage" then
		return true
	end
	-- hide per-instance Behavior copies (shared template is the source of truth)
	if inst:IsA("ModuleScript") then
		local parent = inst.Parent
		local name = inst.Name
		if parent and Registry.isFraguaInstance(parent) then
			if name == Constants.BEHAVIOR_NAME or string.sub(name, -8) == "Behavior" then
				return true
			end
		end
		if inst:GetAttribute("_FraguaBehaviorSide") == "Edit" then
			return true
		end
	end
	if inst:GetAttribute("_FraguaInstanceBehavior") == true then
		return true
	end
	if string.sub(inst.Name, -8) == "Behavior" and inst:IsA("ModuleScript") then
		local parent = inst.Parent
		if parent and parent.Name == Constants.TYPES_FOLDER then
			return true
		end
		if parent and parent.Name == Constants.ENUMS_FOLDER then
			return true
		end
	end
	return false
end

local function rootServices(): { string }
	return SettingsStore.getVisibleServices()
end

local function topLevelAncestor(inst: Instance): Instance?
	local current = inst
	while current.Parent and current.Parent ~= game do
		current = current.Parent
	end
	return if current.Parent == game then current else nil
end

local function shouldTrackDescendant(inst: Instance, visibleServices: { [string]: boolean }): boolean
	local service = topLevelAncestor(inst)
	if not service or not visibleServices[service.Name] then
		return false
	end
	return not isHidden(inst) and inst:FindFirstAncestor("_FraguaNameplate") == nil
end

local function isServiceRoot(inst: Instance): boolean
	return inst.Parent == game and table.find(SettingsStore.defaultServices(), inst.Name) ~= nil
end

local function canReparent(inst: Instance, newParent: Instance): boolean
	if isServiceRoot(inst) then
		return false
	end
	if inst == newParent then
		return false
	end
	if newParent:IsDescendantOf(inst) then
		return false
	end
	if isHidden(newParent) then
		return false
	end
	return true
end

function Tree.mount(
	scroll: ScrollingFrame,
	opts: {
		host: Instance,
		onInsertRequest: (parent: Instance) -> (),
		filterText: () -> string,
	}
)
	local expanded: { [Instance]: boolean } = {}
	local sectionOpen: { [string]: boolean } = {}
	local rowByInstance: { [Instance]: Frame } = {}
	local instanceByRow: { [Frame]: Instance } = {}
	local plusByInstance: { [Instance]: TextButton } = {}
	local selected: { [Instance]: boolean } = {}
	local visibleOrder: { Instance } = {}
	local hoveredInstance: Instance? = nil
	local orderCounter = 0
	local renameToken = 0
	local selectionAnchor: Instance? = nil
	local shiftHeld = false
	local modHeld = false
	local lastSelectAt = 0
	local lastSelectInst: Instance? = nil
	local lastClickAt = 0
	local lastClickInst: Instance? = nil
	local dropTarget: Instance? = nil
	local dragging = false
	local dragPressed = false
	local dragSource: Instance? = nil
	local dragGhost: TextLabel? = nil
	local cancelDragSession: (() -> ())? = nil
	local matchFlash: { [Instance]: number } = {}
	local clipboard: { Instance } = {}
	local clipboardIsCut = false
	local DRAG_THRESHOLD = 8

	local pluginGui = opts.host:FindFirstAncestorWhichIsA("PluginGui")

	local function isAlive(inst: Instance?): boolean
		return inst ~= nil and inst.Parent ~= nil
	end

	local function clearDragGhost()
		if dragGhost then
			dragGhost:Destroy()
			dragGhost = nil
		end
	end

	local function updateDragGhost()
		if not dragGhost then
			local ghost = Instance.new("TextLabel")
			ghost.Name = "DragGhost"
			ghost.BackgroundColor3 = Theme.bgSelected
			ghost.BackgroundTransparency = 0.25
			ghost.BorderSizePixel = 0
			ghost.Font = Theme.font
			ghost.TextSize = 12
			ghost.TextColor3 = Theme.textBright
			ghost.TextXAlignment = Enum.TextXAlignment.Left
			ghost.TextTruncate = Enum.TextTruncate.AtEnd
			ghost.Size = UDim2.fromOffset(160, 22)
			ghost.ZIndex = 200
			ghost.Active = false
			ghost.Parent = opts.host
			local gc = Instance.new("UICorner")
			gc.CornerRadius = UDim.new(0, 4)
			gc.Parent = ghost
			dragGhost = ghost
		end
		local name = if dragSource then dragSource.Name else "..."
		local count = #Selection:Get()
		dragGhost.Text = "  " .. (if count > 1 then `{count} items` else name)
	end

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local emptyState = Instance.new("TextLabel")
	emptyState.Name = "EmptyState"
	emptyState.BackgroundTransparency = 1
	emptyState.Size = UDim2.new(1, 0, 0, 48)
	emptyState.Font = Theme.font
	emptyState.TextSize = Theme.typeSize.control
	emptyState.TextColor3 = Theme.textMuted
	emptyState.TextWrapped = true
	emptyState.LayoutOrder = 2 ^ 30
	emptyState.Visible = false
	emptyState.Parent = scroll

	local function syncSelectionFromStudio()
		table.clear(selected)
		local list = Selection:Get()
		for _, inst in list do
			selected[inst] = true
		end
		if selectionAnchor and not selected[selectionAnchor] then
			selectionAnchor = list[#list] or list[1]
		elseif not selectionAnchor and #list > 0 then
			selectionAnchor = list[#list]
		end
	end

	local lastFilter, lastFilterLower = "", ""
	local function isDirectMatch(instance: Instance, filter: string): boolean
		if filter == "" then
			return false
		end
		if filter ~= lastFilter then
			lastFilter, lastFilterLower = filter, string.lower(filter)
		end
		local lower = lastFilterLower
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
		return false
	end

	local function paintRow(instance: Instance)
		local row = rowByInstance[instance]
		if not row or row.Parent == nil then
			return
		end
		if not isAlive(instance) then
			return
		end
		local plus = plusByInstance[instance]
		if plus then
			plus.Visible = hoveredInstance == instance or selected[instance] == true
		end
		local target: Color3
		if dropTarget == instance and dragging then
			target = Theme.dropTint
		elseif selected[instance] then
			target = Theme.bgSelected
		elseif matchFlash[instance] and SettingsStore.getMatchHighlight() then
			target = Theme.matchTint
		elseif hoveredInstance == instance then
			target = Theme.bgHover
		else
			target = Theme.bg
		end
		if row.BackgroundColor3 ~= target then
			Theme.tween(row, { BackgroundColor3 = target })
		end
	end

	local function setHovered(instance: Instance?)
		if instance and not isAlive(instance) then
			instance = nil
		end
		local previous = hoveredInstance
		if previous == instance then
			return
		end
		hoveredInstance = instance
		if previous then
			paintRow(previous)
		end
		if instance then
			paintRow(instance)
		end
	end

	local rebuild: () -> ()

	local function paintSelection()
		syncSelectionFromStudio()
		-- drop dead selection anchors so undo/redo doesnt keep stale refs
		if selectionAnchor and not isAlive(selectionAnchor) then
			selectionAnchor = nil
		end
		for inst in rowByInstance do
			paintRow(inst)
		end
	end

	local function expandAncestors(inst: Instance): boolean
		local changed = false
		local current: Instance? = inst.Parent
		while current and current ~= game do
			if not expanded[current] then
				expanded[current] = true
				changed = true
			end
			if current.Parent == game then
				sectionOpen[current.Name] = true
			end
			current = current.Parent
		end
		return changed
	end

	local function scrollToInstance(inst: Instance)
		task.defer(function()
			local row = rowByInstance[inst]
			if not row or row.Parent == nil then
				return
			end
			local viewH = scroll.AbsoluteWindowSize.Y
			if viewH <= 0 then
				return
			end
			local relY = row.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
			local top = scroll.CanvasPosition.Y
			local bottom = top + viewH
			local rowBottom = relY + row.AbsoluteSize.Y
			if relY < top or rowBottom > bottom then
				scroll.CanvasPosition = Vector2.new(0, math.max(0, relY - viewH * 0.28))
			end
		end)
	end

	local function revealStudioSelection()
		local list = Selection:Get()
		local opened = false
		for _, inst in list do
			if isAlive(inst) and expandAncestors(inst) then
				opened = true
			end
		end
		if opened then
			rebuild()
		else
			paintSelection()
		end
		local first = list[1]
		if first then
			scrollToInstance(first)
		end
	end

	local function setStudioSelectionList(list: { Instance })
		Selection:Set(list)
		paintSelection()
	end

	local function setStudioSelection(inst: Instance?)
		if not inst then
			Selection:Set({})
		else
			Selection:Set({ inst })
			selectionAnchor = inst
		end
		paintSelection()
	end

	local function modifierState(input: InputObject?): (boolean, boolean)
		local shift = shiftHeld or shiftDown() or inputHasModifier(input, Enum.ModifierKey.Shift)
		local mod = modHeld or modDown() or inputHasModifier(input, Enum.ModifierKey.Ctrl)
		if not mod then
			mod = inputHasModifier(input, Enum.ModifierKey.Meta)
		end
		return shift, mod
	end

	local function openIfScript(instance: Instance): boolean
		if instance:IsA("LuaSourceContainer") then
			openScriptDocument(instance)
			return true
		end
		return false
	end

	local function selectWithModifiers(instance: Instance, input: InputObject?)
		local now = os.clock()
		if lastSelectInst == instance and (now - lastSelectAt) < 0.08 then
			return
		end
		lastSelectAt = now
		lastSelectInst = instance

		local shift, mod = modifierState(input)
		local current = Selection:Get()
		local list, nextAnchor = SelectionModel.apply(visibleOrder, current, selectionAnchor, instance, shift, mod)
		selectionAnchor = nextAnchor
		setStudioSelectionList(list)
	end

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

		local escapeConn = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Escape and box.Parent then
				cancelled = true
				finish(false)
			end
		end)
		box.Destroying:Once(function()
			escapeConn:Disconnect()
		end)
		box.FocusLost:Connect(function()
			finish(true)
		end)
	end

	local function renameSelected()
		local inst = Selection:Get()[1]
		if not inst or isServiceRoot(inst) then
			return
		end
		local row = rowByInstance[inst]
		if not row then
			return
		end
		local cluster = row:FindFirstChild("Cluster")
		local label = cluster and cluster:FindFirstChild("Label")
		if cluster and label and label:IsA("TextButton") then
			beginRename(inst, label, cluster :: Frame)
		end
	end

	local function duplicateSelected()
		local clones = {}
		ChangeHistoryService:SetWaypoint("Fragua Duplicate")
		for _, instance in Selection:Get() do
			if not isServiceRoot(instance) and instance.Parent then
				local clone = instance:Clone()
				clone.Parent = instance.Parent
				clone.Name = instance.Name
				table.insert(clones, clone)
			end
		end
		if #clones > 0 then
			setStudioSelectionList(clones)
			rebuild()
		end
	end

	local function deleteSelected()
		local targets = {}
		for _, instance in Selection:Get() do
			if not isServiceRoot(instance) then
				table.insert(targets, instance)
			end
		end
		if #targets == 0 then
			return
		end
		ChangeHistoryService:SetWaypoint("Fragua Delete")
		local parentHint = targets[1].Parent
		for _, instance in targets do
			instance:Destroy()
		end
		if parentHint and parentHint.Parent ~= nil and parentHint ~= game then
			setStudioSelection(parentHint)
		else
			Selection:Set({})
		end
		rebuild()
	end

	local function setDropTarget(inst: Instance?)
		if inst and not isAlive(inst) then
			inst = nil
		end
		local prev = dropTarget
		dropTarget = inst
		if prev and isAlive(prev) then
			paintRow(prev)
		end
		if dropTarget then
			paintRow(dropTarget)
		end
	end

	-- abort press/drag without reparenting
	local function abortDrag()
		if cancelDragSession then
			cancelDragSession()
			return
		end
		dragging = false
		dragPressed = false
		dragSource = nil
		clearDragGhost()
		setDropTarget(nil)
	end

	local function finishDrag()
		local source = dragSource
		local target = dropTarget
		dragging = false
		dragPressed = false
		dragSource = nil
		clearDragGhost()
		setDropTarget(nil)
		if not source or not isAlive(source) or not target or not isAlive(target) or target == source then
			return
		end
		local sources = {}
		local sel = Selection:Get()
		local sourceSelected = false
		for _, inst in sel do
			if not isAlive(inst) then
				continue
			end
			if inst == source then
				sourceSelected = true
			end
			if not isServiceRoot(inst) and inst ~= target and not target:IsDescendantOf(inst) then
				table.insert(sources, inst)
			end
		end
		if not sourceSelected then
			sources = { source }
		end
		local moved = false
		ChangeHistoryService:SetWaypoint("Fragua Reparent")
		for _, inst in sources do
			if canReparent(inst, target) and inst.Parent ~= target then
				local ok = pcall(function()
					inst.Parent = target
				end)
				if ok then
					moved = true
				end
			end
		end
		if moved then
			expanded[target] = true
			rebuild()
		end
	end

	local function copySelected(cut: boolean)
		table.clear(clipboard)
		clipboardIsCut = cut
		for _, inst in Selection:Get() do
			if not isServiceRoot(inst) then
				table.insert(clipboard, inst)
			end
		end
	end

	local function pasteInto(parent: Instance)
		if #clipboard == 0 or isHidden(parent) then
			return
		end
		ChangeHistoryService:SetWaypoint(if clipboardIsCut then "Fragua Cut" else "Fragua Paste")
		local created = {}
		if clipboardIsCut then
			for _, inst in clipboard do
				if inst.Parent and canReparent(inst, parent) then
					inst.Parent = parent
					table.insert(created, inst)
				end
			end
			table.clear(clipboard)
			clipboardIsCut = false
		else
			for _, inst in clipboard do
				if inst.Parent then
					local clone = inst:Clone()
					clone.Parent = parent
					table.insert(created, clone)
				end
			end
		end
		if #created > 0 then
			setStudioSelectionList(created)
			expanded[parent] = true
			rebuild()
		end
	end

	local function selectChildren(instance: Instance)
		local kids = {}
		for _, child in instance:GetChildren() do
			if not isHidden(child) then
				table.insert(kids, child)
			end
		end
		if #kids > 0 then
			setStudioSelectionList(kids)
		end
	end

	local function groupAsModel()
		local sel = Selection:Get()
		if #sel == 0 then
			return
		end
		local parent = sel[1].Parent
		if not parent then
			return
		end
		ChangeHistoryService:SetWaypoint("Fragua Group")
		local model = Instance.new("Model")
		model.Name = "Model"
		model.Parent = parent
		for _, inst in sel do
			if not isServiceRoot(inst) then
				inst.Parent = model
			end
		end
		setStudioSelection(model)
		rebuild()
	end

	local function openContext(instance: Instance, anchor: GuiObject, clickPos: Vector2?)
		if not selected[instance] then
			setStudioSelection(instance)
		end
		local hasChildren = false
		for _, child in instance:GetChildren() do
			if not isHidden(child) then
				hasChildren = true
				break
			end
		end
		local multi = #Selection:Get() > 1
		local locked = isServiceRoot(instance)
		local items: { ContextMenu.MenuItem } = {
			{
				label = "Cut",
				disabled = locked,
				onClick = function()
					copySelected(true)
				end,
			},
			{
				label = "Copy",
				disabled = locked,
				onClick = function()
					copySelected(false)
				end,
			},
			{
				label = "Paste Into",
				disabled = #clipboard == 0,
				onClick = function()
					pasteInto(instance)
				end,
			},
			{
				label = "Duplicate",
				disabled = locked,
				onClick = function()
					duplicateSelected()
				end,
			},
			{ separator = true, label = "" },
			{
				label = "Rename",
				disabled = multi or locked,
				onClick = function()
					renameSelected()
				end,
			},
			{
				label = "Open Script",
				disabled = not instance:IsA("LuaSourceContainer"),
				onClick = function()
					openIfScript(instance)
				end,
			},
			{
				label = "Insert Object...",
				onClick = function()
					opts.onInsertRequest(instance)
				end,
			},
			{
				label = "Group as Model",
				disabled = locked,
				onClick = function()
					groupAsModel()
				end,
			},
			{
				label = "Ungroup",
				disabled = not instance:IsA("Model") or locked,
				onClick = function()
					ChangeHistoryService:SetWaypoint("Fragua Ungroup")
					local parent = instance.Parent
					local kids = instance:GetChildren()
					for _, child in kids do
						child.Parent = parent
					end
					instance:Destroy()
					if #kids > 0 then
						setStudioSelectionList(kids)
					end
					rebuild()
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
				label = "Select Children",
				disabled = not hasChildren,
				onClick = function()
					selectChildren(instance)
				end,
			},
			{ separator = true, label = "" },
			{
				label = "Delete",
				danger = true,
				disabled = locked,
				onClick = function()
					deleteSelected()
				end,
			},
		}
		local typeId = Registry.isFraguaInstance(instance) and Registry.getTypeId(instance)
		if typeId then
			local behaviorItems: { ContextMenu.MenuItem } = { { separator = true, label = "" } }
			for _, side in { "Edit", "Server", "Client" } do
				table.insert(behaviorItems, {
					label = `Open {side} Behavior`,
					onClick = function()
						openBehaviorScript(typeId, side)
					end,
				})
			end
			-- insert before the final separator so Delete stays last
			local at = #items - 1
			for _, item in behaviorItems do
				table.insert(items, at, item)
				at += 1
			end
		end
		ContextMenu.open(opts.host, items, {
			anchor = anchor,
			clickPos = clickPos,
		})
	end

	local function makeRow(instance: Instance, depth: number, hasChildren: boolean, filter: string)
		orderCounter += 1
		table.insert(visibleOrder, instance)

		local row = Instance.new("Frame")
		row.Name = "Row"
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, Theme.rowHeight)
		row.BackgroundColor3 = Theme.bg
		row.LayoutOrder = orderCounter
		row.Active = true
		rowByInstance[instance] = row
		instanceByRow[row] = instance

		local padLeft = 4 + depth * 14
		local accentColor =
			SettingsStore.colorForSection(instance.Name, DEFAULT_SERVICE_COLORS[instance.Name] or Theme.accent)

		if depth == 0 and DEFAULT_SERVICE_COLORS[instance.Name] then
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
		twist.Position = UDim2.fromOffset(padLeft - 1, 0)
		twist.Size = UDim2.fromOffset(18, Theme.rowHeight)
		twist.Text = ""
		twist.Visible = hasChildren
		twist.Parent = row
		if hasChildren then
			local chevron = UiUtil.makeChevron(twist, expanded[instance] == true, 12)
			chevron.AnchorPoint = Vector2.new(0.5, 0.5)
			chevron.Position = UDim2.fromScale(0.5, 0.5)
			local function tintChevron(color: Color3)
				for _, line in chevron:GetChildren() do
					if line:IsA("Frame") then
						line.BackgroundColor3 = color
					end
				end
			end
			twist.MouseButton1Click:Connect(function()
				expanded[instance] = not expanded[instance]
				rebuild()
			end)
			twist.MouseEnter:Connect(function()
				tintChevron(Theme.accent)
			end)
			twist.MouseLeave:Connect(function()
				tintChevron(Theme.textMuted)
			end)
		else
			twist.Active = false
		end

		local isFragua = Registry.isFraguaInstance(instance)
		local typeId = isFragua and Registry.getTypeId(instance)
		local def = typeId and Registry.get(typeId)
		local icon = IconCatalog.createIconWidget(row, iconFor(instance, isFragua, def), 14)
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
		local directMatch = isDirectMatch(instance, filter) and SettingsStore.getMatchHighlight()
		label.TextColor3 = if directMatch then Theme.accent else Theme.textBright
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

		if isFragua then
			local badge = Instance.new("TextLabel")
			badge.BackgroundTransparency = 1
			badge.AutomaticSize = Enum.AutomaticSize.X
			badge.Size = UDim2.fromOffset(0, Theme.rowHeight)
			badge.Font = Theme.font
			badge.TextSize = 11
			badge.TextColor3 = Theme.textMuted
			badge.Text = if def then def.name else "missing type"
			badge.Active = false
			badge.LayoutOrder = 3
			badge.Parent = cluster
		end

		row.MouseEnter:Connect(function()
			if dragging then
				if instance ~= dragSource then
					setDropTarget(instance)
				end
			else
				setHovered(instance)
			end
		end)
		row.MouseLeave:Connect(function()
			if not dragging and hoveredInstance == instance then
				setHovered(nil)
			end
		end)

		local function beginPressDrag(input: InputObject)
			if isServiceRoot(instance) then
				return
			end
			if dragPressed and dragSource == instance and cancelDragSession then
				return
			end
			if cancelDragSession then
				cancelDragSession()
			end
			local source = instance
			local sessionDragging = false
			local hostGui = opts.host :: GuiObject
			local ended = false
			dragPressed = true
			dragSource = source
			renameToken += 1
			local originX, originY = PointerController.toHostLocal(hostGui, input.Position.X, input.Position.Y)
			local lastX, lastY = originX, originY

			local function hitAt(hostX: number, hostY: number): Instance?
				local hostAbs = hostGui.AbsolutePosition
				for inst, r in rowByInstance do
					if not isAlive(inst) or r.Parent == nil then
						continue
					end
					local rel = r.AbsolutePosition - hostAbs
					local size = r.AbsoluteSize
					if hostX >= rel.X and hostX <= rel.X + size.X and hostY >= rel.Y and hostY <= rel.Y + size.Y then
						return inst
					end
				end
				return nil
			end

			local function finishPress(cancelled: boolean)
				if ended then
					return
				end
				ended = true
				cancelDragSession = nil
				local wasDragging = sessionDragging
				sessionDragging = false
				if wasDragging and not cancelled then
					local under = hitAt(lastX, lastY)
					if under and under ~= source then
						setDropTarget(under)
					end
					finishDrag()
				else
					dragging = false
					dragPressed = false
					dragSource = nil
					clearDragGhost()
					setDropTarget(nil)
				end
			end

			local session = PointerController.capture(hostGui, {
				initial = Vector2.new(originX, originY),
				scroll = scroll,
				onMove = function(x, y)
					if ended or not isAlive(source) then
						return
					end
					lastX, lastY = x, y
					if
						not sessionDragging
						and InteractionMath.crossedThreshold(originX, originY, x, y, DRAG_THRESHOLD)
					then
						sessionDragging = true
						dragging = true
						setHovered(nil)
						if not selected[source] then
							setStudioSelection(source)
						end
					end
					if sessionDragging then
						if not dragGhost then
							updateDragGhost()
						end
						if dragGhost then
							dragGhost.Position = UDim2.fromOffset(x + 12, y + 8)
						end
						local under = hitAt(x, y)
						setDropTarget(if under ~= source then under else nil)
					end
				end,
				onFinish = function(_, _, cancelled)
					finishPress(cancelled)
				end,
			})
			cancelDragSession = function()
				session:cancel()
			end
		end

		label.MouseButton1Click:Connect(function()
			if dragging then
				return
			end
			local now = os.clock()
			local doubled = lastClickInst == instance and (now - lastClickAt) < 0.35
			lastClickAt = now
			lastClickInst = instance
			if doubled then
				renameToken += 1
				if openIfScript(instance) then
					return
				end
				return
			end
			local shift, mod = modifierState()
			-- click is rename only. selection already happened on inputbegan
			if selected[instance] ~= true or isServiceRoot(instance) or mod or shift then
				return
			end
			renameToken += 1
			local token = renameToken
			task.delay(0.5, function()
				if token ~= renameToken or dragging then
					return
				end
				if hoveredInstance == instance and selected[instance] and isAlive(instance) then
					beginRename(instance, label, cluster)
				end
			end)
		end)

		-- label steals clicks from the row. select once from the input object
		label.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				selectWithModifiers(instance, input)
				beginPressDrag(input)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				openContext(instance, row, Vector2.new(input.Position.X, input.Position.Y))
			end
		end)

		row.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				selectWithModifiers(instance, input)
				beginPressDrag(input)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				openContext(instance, row, Vector2.new(input.Position.X, input.Position.Y))
			end
		end)

		if directMatch then
			matchFlash[instance] = os.clock()
		end

		row.Parent = scroll
		paintRow(instance)
	end

	-- per-rebuild memo; walk() asks about every subtree repeatedly while filtering
	local matchCache: { [Instance]: boolean } = {}
	local function matchesFilter(instance: Instance, filter: string): boolean
		local cached = matchCache[instance]
		if cached ~= nil then
			return cached
		end
		local result = false
		if isHidden(instance) then
			result = false
		elseif filter == "" or isDirectMatch(instance, filter) then
			result = true
		else
			for _, child in instance:GetChildren() do
				if matchesFilter(child, filter) then
					result = true
					break
				end
			end
		end
		matchCache[instance] = result
		return result
	end

	local function walk(instance: Instance, depth: number, filter: string)
		if isHidden(instance) then
			return
		end
		if not matchesFilter(instance, filter) and depth > 0 then
			return
		end
		local children = instance:GetChildren()
		table.sort(children, ClassOrder.compare)
		local visibleChildren = {}
		for _, child in children do
			if not isHidden(child) and matchesFilter(child, filter) then
				table.insert(visibleChildren, child)
			end
		end
		makeRow(instance, depth, #visibleChildren > 0, filter)
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
		-- dont tear down mid-drag; finish/abort first so ghost/state dont go stale
		if dragging or dragPressed then
			abortDrag()
		end
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") and (child.Name == "Row" or child.Name == "Section") then
				child:Destroy()
			end
		end
		table.clear(rowByInstance)
		table.clear(instanceByRow)
		table.clear(plusByInstance)
		table.clear(visibleOrder)
		table.clear(matchFlash)
		table.clear(matchCache)
		-- prune dead expand keys (delete/undo leaves Instance refs with Parent=nil)
		for inst in pairs(expanded) do
			if not isAlive(inst) then
				expanded[inst] = nil
			end
		end
		if selectionAnchor and not isAlive(selectionAnchor) then
			selectionAnchor = nil
		end
		hoveredInstance = nil
		dropTarget = nil
		orderCounter = 0
		syncSelectionFromStudio()
		local filter = opts.filterText()
		for _, serviceName in rootServices() do
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
				if filter == "" or matchesFilter(service, filter) then
					walk(service, 0, filter)
				end
			end
		end
		emptyState.Text = if filter ~= "" then `No matches for "{filter}"` else "Nothing to show"
		emptyState.Visible = #visibleOrder == 0
	end

	local scheduleRebuild = Util.debounce(0.08, rebuild)

	local visibleServiceSet: { [string]: boolean } = {}
	local function refreshVisibleServices()
		table.clear(visibleServiceSet)
		for _, name in rootServices() do
			visibleServiceSet[name] = true
		end
	end
	refreshVisibleServices()

	-- Without a filter, only changes under a shown row can alter the tree; skip the rest (e.g. play-mode churn).
	local function affectsTree(inst: Instance): boolean
		if opts.filterText() ~= "" then
			return shouldTrackDescendant(inst, visibleServiceSet)
		end
		local parent = inst.Parent
		return parent ~= nil and rowByInstance[parent] ~= nil and not isHidden(inst)
	end

	local conns: { RBXScriptConnection } = {}
	table.insert(conns, Selection.SelectionChanged:Connect(revealStudioSelection))
	table.insert(
		conns,
		game.DescendantAdded:Connect(function(inst)
			if affectsTree(inst) then
				scheduleRebuild()
			end
		end)
	)
	table.insert(
		conns,
		game.DescendantRemoving:Connect(function(inst)
			-- Parent may already be clearing; also catch rows we currently show
			if rowByInstance[inst] or affectsTree(inst) then
				if hoveredInstance == inst then
					hoveredInstance = nil
				end
				if selectionAnchor == inst then
					selectionAnchor = nil
				end
				if dragSource == inst then
					abortDrag()
				end
				scheduleRebuild()
			end
		end)
	)
	-- undo/redo often restores via ancestry moves that DescendantAdded alone can miss timing-wise
	pcall(function()
		table.insert(
			conns,
			ChangeHistoryService.OnUndo:Connect(function()
				task.defer(scheduleRebuild)
			end)
		)
		table.insert(
			conns,
			ChangeHistoryService.OnRedo:Connect(function()
				task.defer(scheduleRebuild)
			end)
		)
	end)
	table.insert(
		conns,
		Registry.Changed:Connect(function()
			scheduleRebuild()
		end)
	)
	table.insert(
		conns,
		SettingsStore.Changed:Connect(function(key)
			if key == "visibleServices" or key == "matchHighlight" or key == "sectionColors" then
				if key == "visibleServices" then
					refreshVisibleServices()
				end
				scheduleRebuild()
			end
		end)
	)

	-- clear hover when pointer leaves; do NOT abort drag here (MouseLeave is flaky with children)
	table.insert(
		conns,
		scroll.MouseLeave:Connect(function()
			if not dragging and not dragPressed then
				setHovered(nil)
			end
		end)
	)
	table.insert(
		conns,
		opts.host.MouseLeave:Connect(function()
			if not dragging and not dragPressed then
				setHovered(nil)
			end
		end)
	)

	table.insert(
		conns,
		UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
				shiftHeld = true
			elseif
				input.KeyCode == Enum.KeyCode.LeftControl
				or input.KeyCode == Enum.KeyCode.RightControl
				or input.KeyCode == Enum.KeyCode.LeftMeta
				or input.KeyCode == Enum.KeyCode.RightMeta
			then
				modHeld = true
			end
		end)
	)
	table.insert(
		conns,
		UserInputService.InputEnded:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
				shiftHeld = false
			elseif
				input.KeyCode == Enum.KeyCode.LeftControl
				or input.KeyCode == Enum.KeyCode.RightControl
				or input.KeyCode == Enum.KeyCode.LeftMeta
				or input.KeyCode == Enum.KeyCode.RightMeta
			then
				modHeld = false
			end
		end)
	)

	table.insert(
		conns,
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if pluginGui and not pluginGui.Enabled then
				return
			end
			if UserInputService:GetFocusedTextBox() then
				return
			end
			-- Prefer shortcuts when explorer has focus / mouse over it
			local mouse = UserInputService:GetMouseLocation()
			local hostPos = opts.host.AbsolutePosition
			local hostSize = opts.host.AbsoluteSize
			local overExplorer = mouse.X >= hostPos.X
				and mouse.X <= hostPos.X + hostSize.X
				and mouse.Y >= hostPos.Y
				and mouse.Y <= hostPos.Y + hostSize.Y
			if not overExplorer and not (pluginGui and pluginGui:IsA("DockWidgetPluginGui")) then
				return
			end
			-- Allow when dock enabled even if mouse elsewhere (Studio plugins often work this way when dock focused)
			if not overExplorer and pluginGui then
				-- only handle if something is selected in our tree
				local hasVisible = false
				for inst in pairs(selected) do
					if rowByInstance[inst] then
						hasVisible = true
						break
					end
				end
				if not hasVisible then
					return
				end
			end

			if input.KeyCode == Enum.KeyCode.F2 then
				renameSelected()
			elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
				local inst = Selection:Get()[1]
				if inst then
					openIfScript(inst)
				end
			elseif
				input.KeyCode == Enum.KeyCode.Delete
				or input.KeyCode == Enum.KeyCode.Backspace
				-- shift+d delete (mac-friendly; delete/backspace still work)
				or (input.KeyCode == Enum.KeyCode.D and shiftDown() and not modDown())
			then
				deleteSelected()
			elseif input.KeyCode == Enum.KeyCode.D and modDown() then
				duplicateSelected()
			elseif input.KeyCode == Enum.KeyCode.A and modDown() then
				setStudioSelectionList(table.clone(visibleOrder))
			elseif input.KeyCode == Enum.KeyCode.X and modDown() then
				copySelected(true)
			elseif input.KeyCode == Enum.KeyCode.C and modDown() then
				copySelected(false)
			elseif input.KeyCode == Enum.KeyCode.V and modDown() then
				local parent = Selection:Get()[1]
				if parent then
					pasteInto(parent)
				end
			end
		end)
	)

	rebuild()

	return {
		rebuild = rebuild,
		refreshForRunState = function()
			if dragging or dragPressed then
				abortDrag()
			end
			hoveredInstance = nil
			dropTarget = nil
			selectionAnchor = nil
		end,
		reveal = function(inst: Instance)
			expandAncestors(inst)
			rebuild()
			scrollToInstance(inst)
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
