local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Explorer = require(script.App.Explorer)
local Properties = require(script.App.Properties)
local Host = require(script.App.Behaviors.Host)
local Registry = require(script.App.Types.Registry)
local Constants = require(script.App.Shared.Constants)

local toolbar = plugin:CreateToolbar(Constants.PLUGIN_NAME)

local explorerBtn = toolbar:CreateButton(
	"FraguaExplorer",
	"Open Fragua Explorer",
	"rbxasset://textures/StudioToolbox/Tabs/Inventory.png",
	"Explorer"
)
explorerBtn.ClickableWhenViewportHidden = true

local propertiesBtn = toolbar:CreateButton(
	"FraguaProperties",
	"Open Fragua Properties",
	"rbxasset://textures/StudioSharedUI/attributes_icon.png",
	"Properties"
)
propertiesBtn.ClickableWhenViewportHidden = true

local scriptBtn = toolbar:CreateButton(
	"FraguaScriptEditor",
	"Script Editor (deferred)",
	"rbxasset://textures/Debugger/Breakpoints/Breakpoint.png",
	"Script Editor"
)
scriptBtn.ClickableWhenViewportHidden = true
scriptBtn.Enabled = true

local explorerInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left,
	true,
	false,
	320,
	480,
	240,
	200
)
local propertiesInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	true,
	false,
	320,
	480,
	240,
	200
)

local explorerWidget = plugin:CreateDockWidgetPluginGui("FraguaExplorer", explorerInfo)
explorerWidget.Title = "Fragua Explorer"
explorerWidget.Name = "FraguaExplorer"

local propertiesWidget = plugin:CreateDockWidgetPluginGui("FraguaProperties", propertiesInfo)
propertiesWidget.Title = "Fragua Properties"
propertiesWidget.Name = "FraguaProperties"

Registry.seedDefaults()
Host.start()

local explorerApi = Explorer.mount(explorerWidget)
local propertiesApi = Properties.mount(propertiesWidget)

explorerBtn.Click:Connect(function()
	explorerWidget.Enabled = not explorerWidget.Enabled
	explorerBtn:SetActive(explorerWidget.Enabled)
end)

propertiesBtn.Click:Connect(function()
	propertiesWidget.Enabled = not propertiesWidget.Enabled
	propertiesBtn:SetActive(propertiesWidget.Enabled)
end)

scriptBtn.Click:Connect(function()
	warn("[Fragua] Script Editor is deferred for a later release. Use Studio's built-in editor for now.")
	scriptBtn:SetActive(false)
end)

explorerWidget:GetPropertyChangedSignal("Enabled"):Connect(function()
	explorerBtn:SetActive(explorerWidget.Enabled)
end)
propertiesWidget:GetPropertyChangedSignal("Enabled"):Connect(function()
	propertiesBtn:SetActive(propertiesWidget.Enabled)
end)

explorerBtn:SetActive(explorerWidget.Enabled)
propertiesBtn:SetActive(propertiesWidget.Enabled)

Selection.SelectionChanged:Connect(function()
	Host.onSelection(Selection:Get())
end)

plugin.Unloading:Connect(function()
	if explorerApi and explorerApi.destroy then
		explorerApi.destroy()
	end
	if propertiesApi and propertiesApi.destroy then
		propertiesApi.destroy()
	end
end)

-- Keep ChangeHistoryService referenced so waypoints from panels stay meaningful in undo stack.
ChangeHistoryService:SetWaypoint("Fragua Ready")
print("[Fragua] Plugin loaded — forge custom instance types in Explorer → Insert Object.")
