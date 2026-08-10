local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Theme = require(script.Parent.Shared.Theme)
local Host = require(script.Parent.Behaviors.Host)
local InsertPicker = require(script.InsertPicker)
local Tree = require(script.Tree)

local Explorer = {}

function Explorer.mount(widget: DockWidgetPluginGui)
	local root = Instance.new("Frame")
	root.Name = "ExplorerRoot"
	root.BackgroundColor3 = Theme.bg
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = widget

	local toolbar = Instance.new("Frame")
	toolbar.Name = "Toolbar"
	toolbar.BackgroundColor3 = Theme.bgDeep
	toolbar.BorderSizePixel = 0
	toolbar.Size = UDim2.new(1, 0, 0, Theme.toolbarHeight)
	toolbar.Parent = root

	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.PlaceholderText = "Filter workspace"
	search.ClearTextOnFocus = false
	search.Text = ""
	search.Font = Theme.font
	search.TextSize = 13
	search.TextColor3 = Theme.textBright
	search.PlaceholderColor3 = Theme.textMuted
	search.BackgroundColor3 = Theme.inputBg
	search.BorderSizePixel = 0
	search.Position = UDim2.fromOffset(6, 3)
	search.Size = UDim2.new(1, -120, 0, 22)
	search.Parent = toolbar

	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 3)
	sc.Parent = search

	local insertBtn = Theme.makeButton(toolbar, "+", { Name = "Insert", Size = UDim2.fromOffset(28, 22) })
	insertBtn.Position = UDim2.new(1, -84, 0, 3)
	insertBtn.TextSize = 18

	local deleteBtn = Theme.makeButton(toolbar, "Del", { Name = "Delete", Size = UDim2.fromOffset(34, 22) })
	deleteBtn.Position = UDim2.new(1, -52, 0, 3)
	deleteBtn.TextSize = 12

	local renameBtn = Theme.makeButton(toolbar, "Aa", { Name = "Rename", Size = UDim2.fromOffset(28, 22) })
	renameBtn.Position = UDim2.new(1, -114, 0, 3)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Tree"
	scroll.BackgroundColor3 = Theme.bg
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, Theme.toolbarHeight)
	scroll.Size = UDim2.new(1, 0, 1, -Theme.toolbarHeight)
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = root

	local function openInsert(parent: Instance?)
		InsertPicker.open(root, function(choice)
			InsertPicker.handleChoice(root, choice, parent or Selection:Get()[1], function(inst)
				ChangeHistoryService:SetWaypoint("Fragua Insert")
				Selection:Set({ inst })
				Host.runCreated(inst)
			end, function()
				-- type list refresh happens via Registry.Changed
			end)
		end)
	end

	local treeApi = Tree.mount(scroll, {
		onInsertRequest = function(parent)
			openInsert(parent)
		end,
		filterText = function()
			return search.Text
		end,
	})

	search:GetPropertyChangedSignal("Text"):Connect(function()
		treeApi.rebuild()
	end)

	insertBtn.MouseButton1Click:Connect(function()
		openInsert(Selection:Get()[1])
	end)

	deleteBtn.MouseButton1Click:Connect(function()
		local list = Selection:Get()
		if #list == 0 then
			return
		end
		ChangeHistoryService:SetWaypoint("Fragua Delete")
		for _, inst in list do
			if inst.Parent and not inst:IsA("DataModel") then
				pcall(function()
					inst:Destroy()
				end)
			end
		end
		Selection:Set({})
	end)

	renameBtn.MouseButton1Click:Connect(function()
		local inst = Selection:Get()[1]
		if not inst then
			return
		end
		local overlay = Instance.new("Frame")
		overlay.BackgroundColor3 = Color3.new(0, 0, 0)
		overlay.BackgroundTransparency = 0.4
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.ZIndex = 30
		overlay.Parent = root

		local box = Instance.new("TextBox")
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Position = UDim2.fromScale(0.5, 0.5)
		box.Size = UDim2.fromOffset(240, 32)
		box.Font = Theme.font
		box.TextSize = 16
		box.TextColor3 = Theme.textBright
		box.BackgroundColor3 = Theme.inputBg
		box.BorderSizePixel = 0
		box.Text = inst.Name
		box.ClearTextOnFocus = false
		box.ZIndex = 31
		box.Parent = overlay
		box:CaptureFocus()

		local function commit()
			local name = string.gsub(box.Text, "^%s*(.-)%s*$", "%1")
			if name ~= "" then
				ChangeHistoryService:SetWaypoint("Fragua Rename")
				inst.Name = name
			end
			overlay:Destroy()
			treeApi.rebuild()
		end

		box.FocusLost:Connect(function(enter)
			if enter then
				commit()
			else
				overlay:Destroy()
			end
		end)
	end)

	return {
		root = root,
		rebuild = treeApi.rebuild,
		destroy = treeApi.destroy,
	}
end

return Explorer
