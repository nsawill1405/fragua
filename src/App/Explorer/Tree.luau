local Selection = game:GetService("Selection")
local Theme = require(script.Parent.Parent.Shared.Theme)
local Util = require(script.Parent.Parent.Shared.Util)
local IconCatalog = require(script.Parent.Parent.Types.IconCatalog)
local Registry = require(script.Parent.Parent.Types.Registry)

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

local function displayName(instance: Instance): string
	if Registry.isFraguaInstance(instance) then
		local typeId = Registry.getTypeId(instance)
		local def = typeId and Registry.get(typeId)
		if def then
			return `{instance.Name}  [{def.name}]`
		end
		return `{instance.Name}  [Unknown Type]`
	end
	return instance.Name
end

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

function Tree.mount(scroll: ScrollingFrame, opts: {
	onInsertRequest: (parent: Instance) -> (),
	filterText: () -> string,
})
	local expanded: { [Instance]: boolean } = {}
	local rowsFolder = Instance.new("Folder")
	rowsFolder.Name = "Rows"
	rowsFolder.Parent = scroll

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 0)
	layout.Parent = scroll

	local selected: { [Instance]: boolean } = {}
	local orderCounter = 0

	local function isSelected(inst: Instance): boolean
		return selected[inst] == true
	end

	local function syncSelectionFromStudio()
		table.clear(selected)
		for _, inst in Selection:Get() do
			selected[inst] = true
		end
	end

	local function setStudioSelection(inst: Instance?, additive: boolean?)
		if not inst then
			Selection:Set({})
			return
		end
		if additive then
			local list = Selection:Get()
			local found = table.find(list, inst)
			if found then
				table.remove(list, found)
			else
				table.insert(list, inst)
			end
			Selection:Set(list)
		else
			Selection:Set({ inst })
		end
	end

	local rebuild: () -> ()

	local function makeRow(instance: Instance, depth: number, hasChildren: boolean)
		orderCounter += 1
		local row = Instance.new("TextButton")
		row.Name = "Row_" .. instance.Name
		row.AutoButtonColor = false
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, Theme.rowHeight)
		row.BackgroundColor3 = if isSelected(instance) then Theme.bgSelected else Theme.bg
		row.Text = ""
		row.LayoutOrder = orderCounter
		row.Parent = scroll

		local padLeft = 6 + depth * 14

		local twist = Instance.new("TextButton")
		twist.AutoButtonColor = false
		twist.BackgroundTransparency = 1
		twist.Position = UDim2.fromOffset(padLeft, 0)
		twist.Size = UDim2.fromOffset(14, Theme.rowHeight)
		twist.Font = Theme.font
		twist.TextSize = 12
		twist.TextColor3 = Theme.textMuted
		twist.Text = if hasChildren then (if expanded[instance] then "▼" else "▶") else ""
		twist.Parent = row

		if hasChildren then
			twist.MouseButton1Click:Connect(function()
				expanded[instance] = not expanded[instance]
				rebuild()
			end)
		end

		local icon = IconCatalog.createIconWidget(row, iconFor(instance), 14)
		icon.Position = UDim2.fromOffset(padLeft + 16, 4)

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(padLeft + 34, 0)
		label.Size = UDim2.new(1, -(padLeft + 40), 1, 0)
		label.Font = Theme.font
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Theme.textBright
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = displayName(instance)
		label.Parent = row

		row.MouseEnter:Connect(function()
			if not isSelected(instance) then
				row.BackgroundColor3 = Theme.bgHover
			end
		end)
		row.MouseLeave:Connect(function()
			row.BackgroundColor3 = if isSelected(instance) then Theme.bgSelected else Theme.bg
		end)

		row.MouseButton1Click:Connect(function()
			setStudioSelection(instance, false)
		end)

		row.MouseButton2Click:Connect(function()
			setStudioSelection(instance, false)
			opts.onInsertRequest(instance)
		end)
	end

	local function matchesFilter(instance: Instance, filter: string): boolean
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
		if not matchesFilter(instance, filter) and depth > 0 then
			return
		end
		local children = instance:GetChildren()
		table.sort(children, function(a, b)
			return a.Name:lower() < b.Name:lower()
		end)
		local visibleChildren = {}
		for _, child in children do
			if matchesFilter(child, filter) then
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
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		orderCounter = 0
		syncSelectionFromStudio()
		local filter = opts.filterText()
		for _, serviceName in ROOT_SERVICES do
			local ok, service = pcall(function()
				return game:GetService(serviceName)
			end)
			if ok and service then
				if expanded[service] == nil then
					expanded[service] = serviceName == "Workspace" or serviceName == "ServerStorage"
				end
				walk(service, 0, filter)
			end
		end
	end

	local scheduleRebuild = Util.debounce(0.08, rebuild)

	local conns: { RBXScriptConnection } = {}
	table.insert(conns, Selection.SelectionChanged:Connect(function()
		rebuild()
	end))
	table.insert(conns, game.DescendantAdded:Connect(function()
		scheduleRebuild()
	end))
	table.insert(conns, game.DescendantRemoving:Connect(function()
		scheduleRebuild()
	end))
	table.insert(conns, Registry.Changed:Connect(function()
		rebuild()
	end))

	rebuild()

	return {
		rebuild = rebuild,
		getSelection = function(): Instance?
			local list = Selection:Get()
			return list[1]
		end,
		destroy = function()
			for _, c in conns do
				c:Disconnect()
			end
			rowsFolder:Destroy()
		end,
	}
end

return Tree
