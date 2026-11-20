local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Theme = require(script.Parent.Shared.Theme)
local Util = require(script.Parent.Shared.Util)
local Host = require(script.Parent.Behaviors.Host)
local SettingsUI = require(script.Parent.Settings)
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
	search.PlaceholderText = "Filter by name, class or type"
	search.ClearTextOnFocus = false
	search.Text = ""
	search.Font = Theme.font
	search.TextSize = 13
	search.TextColor3 = Theme.textBright
	search.PlaceholderColor3 = Theme.textMuted
	search.BackgroundColor3 = Theme.inputBg
	search.BorderSizePixel = 0
	search.Position = UDim2.fromOffset(8, 6)
	search.Size = UDim2.new(1, -44, 0, 24)
	search.Parent = toolbar

	local sc = Instance.new("UICorner")
	sc.CornerRadius = Theme.corner
	sc.Parent = search

	local searchPad = Instance.new("UIPadding")
	searchPad.PaddingLeft = UDim.new(0, 10)
	searchPad.Parent = search

	local gear = Instance.new("TextButton")
	gear.Name = "Settings"
	gear.AutoButtonColor = false
	gear.BackgroundColor3 = Theme.inputBg
	gear.BorderSizePixel = 0
	gear.AnchorPoint = Vector2.new(1, 0)
	gear.Position = UDim2.new(1, -8, 0, 6)
	gear.Size = UDim2.fromOffset(24, 24)
	gear.Font = Enum.Font.GothamBold
	gear.TextSize = 10
	gear.Text = "•••"
	gear.TextColor3 = Theme.textMuted
	gear.Parent = toolbar
	local gc = Instance.new("UICorner")
	gc.CornerRadius = Theme.corner
	gc.Parent = gear
	gear.MouseEnter:Connect(function()
		Theme.tween(gear, { BackgroundColor3 = Theme.bgHover, TextColor3 = Theme.textBright })
	end)
	gear.MouseLeave:Connect(function()
		Theme.tween(gear, { BackgroundColor3 = Theme.inputBg, TextColor3 = Theme.textMuted })
	end)
	gear.MouseButton1Click:Connect(function()
		SettingsUI.open(root)
	end)

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

	-- rebuilding per keystroke stalls typing in large places
	local rebuildForSearch = Util.debounce(0.12, treeApi.rebuild)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		if search.Text == "" then
			treeApi.rebuild()
		else
			rebuildForSearch()
		end
	end)

	return {
		root = root,
		rebuild = treeApi.rebuild,
		refreshForRunState = treeApi.refreshForRunState,
		destroy = treeApi.destroy,
	}
end

return Explorer
