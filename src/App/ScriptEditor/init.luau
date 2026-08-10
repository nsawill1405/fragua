local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Shared.Theme)
local Constants = require(script.Parent.Shared.Constants)
local Registry = require(script.Parent.Types.Registry)
local CodeCanvas = require(script.CodeCanvas)
local DocumentStore = require(script.DocumentStore)

local ScriptEditor = {}

local function isEditableScript(inst: Instance?): boolean
	return inst ~= nil and (inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript"))
end

local function resolveEditTarget(inst: Instance?): (LuaSourceContainer?, string?, string?)
	if not inst then
		return nil, nil, nil
	end
	if Registry.isFraguaInstance(inst) then
		local typeId = Registry.getTypeId(inst)
		if typeId then
			return Registry.ensureBehaviorTemplate(typeId), `{typeId}Behavior`, typeId
		end
	end
	if
		inst.Name == Constants.BEHAVIOR_NAME
		and inst:IsA("ModuleScript")
		and inst.Parent
		and Registry.isFraguaInstance(inst.Parent)
	then
		local typeId = Registry.getTypeId(inst.Parent)
		if typeId then
			return Registry.ensureBehaviorTemplate(typeId), `{typeId}Behavior`, typeId
		end
	end
	if inst:IsA("ModuleScript") and string.sub(inst.Name, -8) == "Behavior" then
		local typeId = string.sub(inst.Name, 1, #inst.Name - 8)
		if Registry.get(typeId) then
			return inst, inst.Name, typeId
		end
	end
	if isEditableScript(inst) then
		return inst :: LuaSourceContainer, inst.Name, nil
	end
	return nil, nil, nil
end

function ScriptEditor.mount(widget: DockWidgetPluginGui)
	local root = Instance.new("Frame")
	root.Name = "ScriptEditorRoot"
	root.BackgroundColor3 = Theme.bg
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = widget

	local top = Instance.new("Frame")
	top.Name = "Tabs"
	top.BackgroundColor3 = Theme.bgDeep
	top.BorderSizePixel = 0
	top.Size = UDim2.new(1, 0, 0, 38)
	top.Parent = root

	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(8, 6)
	tabs.Size = UDim2.new(1, -162, 0, 32)
	tabs.ClipsDescendants = true
	tabs.Parent = top
	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Padding = UDim.new(0, 4)
	tabList.Parent = tabs

	local findButton = Theme.makeButton(top, "Find", { Size = UDim2.fromOffset(54, 26) })
	findButton.Position = UDim2.new(1, -146, 0, 6)
	local saveButton = Theme.makeButton(top, "Save", { Size = UDim2.fromOffset(76, 26) })
	saveButton.Position = UDim2.new(1, -84, 0, 6)
	saveButton.BackgroundColor3 = Theme.accent

	local breadcrumb = Instance.new("TextLabel")
	breadcrumb.BackgroundColor3 = Theme.bgRaised
	breadcrumb.BorderSizePixel = 0
	breadcrumb.Position = UDim2.fromOffset(0, 38)
	breadcrumb.Size = UDim2.new(1, 0, 0, 28)
	breadcrumb.Font = Theme.font
	breadcrumb.TextSize = 11
	breadcrumb.TextColor3 = Theme.textMuted
	breadcrumb.TextXAlignment = Enum.TextXAlignment.Left
	breadcrumb.TextTruncate = Enum.TextTruncate.AtEnd
	breadcrumb.Text = "  Select a script or Fragua instance"
	breadcrumb.Parent = root

	local canvasHost = Instance.new("Frame")
	canvasHost.BackgroundTransparency = 1
	canvasHost.Position = UDim2.fromOffset(0, 66)
	canvasHost.Size = UDim2.new(1, 0, 1, -90)
	canvasHost.Parent = root

	local status = Instance.new("TextLabel")
	status.BackgroundColor3 = Theme.bgRaised
	status.BorderSizePixel = 0
	status.Position = UDim2.new(0, 0, 1, -24)
	status.Size = UDim2.new(1, 0, 0, 24)
	status.Font = Theme.font
	status.TextSize = 10
	status.TextColor3 = Theme.textMuted
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Text = "  Luau  /  No document"
	status.Parent = root

	local findBar = Instance.new("TextBox")
	findBar.Visible = false
	findBar.ClearTextOnFocus = false
	findBar.PlaceholderText = "Find in document"
	findBar.PlaceholderColor3 = Theme.textMuted
	findBar.BackgroundColor3 = Theme.inputBg
	findBar.BorderSizePixel = 0
	findBar.Position = UDim2.new(1, -230, 0, 70)
	findBar.Size = UDim2.fromOffset(220, 28)
	findBar.Font = Theme.font
	findBar.TextSize = 12
	findBar.TextColor3 = Theme.textBright
	findBar.ZIndex = 30
	findBar.Parent = root
	local findCorner = Instance.new("UICorner")
	findCorner.CornerRadius = Theme.radius.control
	findCorner.Parent = findBar

	local state = DocumentStore.new()
	local targets = {}
	local targetConnections = {}
	local savingDocuments = {}
	local currentDiagnostics = {}
	local loadingDocument = false
	local canvas

	local function allTypeIds()
		local ids = {}
		for _, definition in Registry.list() do
			table.insert(ids, definition.id)
		end
		table.sort(ids)
		return ids
	end

	local function schemaFor(typeId: string?)
		if not typeId then
			return {}
		end
		local definition = Registry.get(typeId)
		if not definition then
			return {}
		end
		local direct = {}
		for _, property in definition.properties do
			direct[property.name] = true
		end
		local schema = {}
		for _, property in Registry.resolvedSchema(definition) do
			local copy = table.clone(property)
			copy.inherited = not direct[property.name]
			table.insert(schema, copy)
		end
		return schema
	end

	local function activeDocument()
		return state.activeId and state.documents[state.activeId] or nil
	end

	local function cursorStatus(source: string, cursor: number): string
		local before = source:sub(1, math.max(cursor - 1, 0))
		local line = 1
		for _ in before:gmatch("\n") do
			line += 1
		end
		local column = #(before:match("([^\n]*)$") or "") + 1
		return `Ln {line}, Col {column}`
	end

	local function diagnosticsStatus(source: string, cursor: number, issues): string
		local base = `  Luau  /  {cursorStatus(source, cursor)}  /  {#issues} issue(s)`
		local first = issues[1]
		if not first then
			return base
		end
		return `{base}  /  {string.upper(first.severity or "issue")} {cursorStatus(source, first.startByte or 1)}: {first.message}`
	end

	local rebuildTabs: () -> ()
	local loadActive: () -> ()

	canvas = CodeCanvas.mount(canvasHost, {
		onChanged = function(source, cursor, selectionStart)
			if loadingDocument or not state.activeId then
				return
			end
			DocumentStore.edit(state, state.activeId, source, cursor, selectionStart)
			local document = activeDocument()
			if document then
				status.Text = `  Luau  /  {cursorStatus(source, cursor)}  /  {#currentDiagnostics} issue(s)`
			end
			rebuildTabs()
		end,
		onDiagnostics = function(issues)
			currentDiagnostics = issues
			local document = activeDocument()
			if document then
				status.Text = diagnosticsStatus(document.source, document.cursor, issues)
			end
		end,
	})

	rebuildTabs = function()
		for _, child in tabs:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for order, id in state.order do
			local document = state.documents[id]
			local tab = Instance.new("TextButton")
			tab.AutoButtonColor = false
			tab.BackgroundColor3 = if id == state.activeId then Theme.bgRaised else Theme.bgDeep
			tab.BorderSizePixel = 0
			tab.Size = UDim2.fromOffset(150, 32)
			tab.Font = Theme.font
			tab.TextSize = 11
			tab.TextColor3 = if id == state.activeId then Theme.textBright else Theme.textMuted
			tab.TextTruncate = Enum.TextTruncate.AtEnd
			tab.Text = `{if document.dirty then "* " else ""}{document.title}`
			tab.LayoutOrder = order
			tab.Parent = tabs
			local corner = Instance.new("UICorner")
			corner.CornerRadius = Theme.radius.control
			corner.Parent = tab
			tab.MouseButton1Click:Connect(function()
				DocumentStore.select(state, id)
				loadActive()
			end)
		end
	end

	loadActive = function()
		local document = activeDocument()
		loadingDocument = true
		canvas.setDocument(document)
		canvas.setContext({
			schema = schemaFor(document and document.typeId or nil),
			typeIds = allTypeIds(),
		})
		loadingDocument = false
		if document then
			local scope = if document.typeId then `Shared Behavior / {document.sharedCount} instance(s)` else "Script"
			breadcrumb.Text = `  {document.title}  /  {scope}`
			status.Text =
				`  Luau  /  {cursorStatus(document.source, document.cursor)}  /  {#currentDiagnostics} issue(s)`
		else
			breadcrumb.Text = "  Select a script or Fragua instance"
			status.Text = "  Luau  /  No document"
		end
		rebuildTabs()
	end

	local function openTarget(target: LuaSourceContainer, title: string, typeId: string?)
		local targetKey = tostring(target)
		local sharedCount = if typeId then Registry.countInstances(typeId) else 0
		local _, id = DocumentStore.open(state, {
			targetKey = targetKey,
			title = title,
			source = target.Source,
			typeId = typeId,
			sharedCount = sharedCount,
		})
		targets[id] = target
		if not targetConnections[id] then
			targetConnections[id] = target:GetPropertyChangedSignal("Source"):Connect(function()
				if savingDocuments[id] then
					return
				end
				local document = state.documents[id]
				if not document then
					return
				end
				DocumentStore.markExternalChange(state, id, target.Source)
				if state.activeId == id then
					if document.conflicted then
						status.Text = "  External change conflict  /  Local edits preserved"
					else
						loadActive()
					end
				end
			end)
		end
		widget.Enabled = true
		loadActive()
		canvas.focus()
	end

	local function openFromInstance(instance: Instance?)
		local target, title, typeId = resolveEditTarget(instance)
		if target and title then
			openTarget(target, title, typeId)
		end
	end

	local function save()
		local document = activeDocument()
		local id = state.activeId
		local target = id and targets[id] or nil
		if not document or not id or not target then
			return
		end
		ChangeHistoryService:SetWaypoint("Fragua Script Save")
		savingDocuments[id] = true
		local ok, err = pcall(function()
			if document.typeId then
				Registry.setSharedBehaviorSource(document.typeId, document.source)
			else
				ScriptEditorService:UpdateSourceAsync(target, function()
					return document.source
				end)
			end
		end)
		savingDocuments[id] = nil
		if ok then
			DocumentStore.markSaved(state, id)
			status.Text = "  Luau  /  Saved"
			rebuildTabs()
		else
			status.Text = `  Save failed  /  {tostring(err)}`
		end
	end

	saveButton.MouseButton1Click:Connect(save)
	findButton.MouseButton1Click:Connect(function()
		findBar.Visible = not findBar.Visible
		if findBar.Visible then
			findBar:CaptureFocus()
		end
	end)
	findBar.FocusLost:Connect(function(enterPressed)
		if enterPressed and findBar.Text ~= "" then
			local document = activeDocument()
			local found = document and document.source:find(findBar.Text, 1, true)
			status.Text = if found then `  Found at byte {found}` else "  No matches"
		end
	end)

	local connections = {}
	table.insert(
		connections,
		Selection.SelectionChanged:Connect(function()
			openFromInstance(Selection:Get()[1])
		end)
	)
	table.insert(
		connections,
		Registry.Changed:Connect(function()
			local document = activeDocument()
			if document then
				canvas.setContext({ schema = schemaFor(document.typeId), typeIds = allTypeIds() })
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input)
			if not widget.Enabled then
				return
			end
			local modifier = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
				or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)
			if modifier and input.KeyCode == Enum.KeyCode.S then
				save()
			elseif modifier and input.KeyCode == Enum.KeyCode.F then
				findBar.Visible = true
				findBar:CaptureFocus()
			end
		end)
	)

	return {
		root = root,
		openTarget = function(context)
			if typeof(context) == "Instance" then
				openFromInstance(context)
			elseif context and context.target then
				openTarget(context.target, context.title or context.target.Name, context.typeId)
			end
		end,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			for _, connection in targetConnections do
				connection:Disconnect()
			end
			canvas.destroy()
			root:Destroy()
		end,
	}
end

return ScriptEditor
