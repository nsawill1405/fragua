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

	local line = Instance.new("Frame")
	line.BackgroundColor3 = Theme.border
	line.BorderSizePixel = 0
	line.Position = UDim2.new(0, 0, 1, -1)
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Parent = toolbar

	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.PlaceholderText = "Filter workspace"
	search.ClearTextOnFocus = false
	search.Text = ""
	search.Font = Theme.font
	search.TextSize = 12
	search.TextColor3 = Theme.textBright
	search.PlaceholderColor3 = Theme.textMuted
	search.BackgroundColor3 = Theme.inputBg
	search.BorderSizePixel = 0
	search.Position = UDim2.fromOffset(8, 5)
	search.Size = UDim2.new(1, -16, 0, 22)
	search.Parent = toolbar

	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 5)
	sc.Parent = search

	local searchPad = Instance.new("UIPadding")
	searchPad.PaddingLeft = UDim.new(0, 8)
	searchPad.Parent = search

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Tree"
	scroll.BackgroundColor3 = Theme.bg
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, Theme.toolbarHeight)
	scroll.Size = UDim2.new(1, 0, 1, -Theme.toolbarHeight)
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Theme.borderLight
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = root

	local treeApi
	local function openInsert(parent: Instance?)
		InsertPicker.open(root, function(choice)
			InsertPicker.handleChoice(root, choice, parent or Selection:Get()[1], function(inst)
				ChangeHistoryService:SetWaypoint("Fragua Insert")
				Selection:Set({ inst })
				Host.runCreated(inst)
				if treeApi then
					treeApi.reveal(inst)
				end
			end, function() end)
		end)
	end

	treeApi = Tree.mount(scroll, {
		host = root,
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

	return {
		root = root,
		rebuild = treeApi.rebuild,
		destroy = treeApi.destroy,
	}
end

return Explorer
