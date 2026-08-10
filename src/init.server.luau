local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Explorer = require(script.App.Explorer)
local Properties = require(script.App.Properties)
local ScriptEditor = require(script.App.ScriptEditor)
local SettingsStore = require(script.App.Settings.Store)
local EnsurePlaceModules = require(script.App.Runtime.EnsurePlaceModules)
local ScriptInjector = require(script.App.Runtime.ScriptInjector)
local Host = require(script.App.Behaviors.Host)
local Registry = require(script.App.Types.Registry)
local Constants = require(script.App.Shared.Constants)

SettingsStore.bind(plugin)
EnsurePlaceModules.sync()
local scriptInjector = ScriptInjector.start()

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
	"rbxasset://textures/StudioToolbox/Tabs/Inventory.png",
	"Properties"
)
propertiesBtn.ClickableWhenViewportHidden = true

local scriptBtn = toolbar:CreateButton(
	"FraguaScriptEditor",
	"Open Fragua Script Editor",
	"rbxasset://textures/StudioToolbox/Tabs/Inventory.png",
	"Script Editor"
)
scriptBtn.ClickableWhenViewportHidden = true
scriptBtn.Enabled = true

local explorerInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, false, 320, 480, 240, 200)
local propertiesInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, true, false, 320, 480, 240, 200)
local scriptInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 520, 420, 320, 240)

local explorerWidget = plugin:CreateDockWidgetPluginGuiAsync("FraguaExplorer", explorerInfo)
explorerWidget.Title = "Fragua Explorer"
explorerWidget.Name = "FraguaExplorer"

local propertiesWidget = plugin:CreateDockWidgetPluginGuiAsync("FraguaProperties", propertiesInfo)
propertiesWidget.Title = "Fragua Properties"
propertiesWidget.Name = "FraguaProperties"

local scriptWidget = plugin:CreateDockWidgetPluginGuiAsync("FraguaScriptEditor", scriptInfo)
scriptWidget.Title = "Fragua Script"
scriptWidget.Name = "FraguaScriptEditor"

Registry.seedDefaults()
Host.start()

local explorerApi = Explorer.mount(explorerWidget)
local scriptApi = ScriptEditor.mount(scriptWidget)
local propertiesApi = Properties.mount(propertiesWidget, {
	onEditScript = function(context)
		scriptApi.openTarget(context)
	end,
})

explorerBtn.Click:Connect(function()
	explorerWidget.Enabled = not explorerWidget.Enabled
	explorerBtn:SetActive(explorerWidget.Enabled)
end)

propertiesBtn.Click:Connect(function()
	propertiesWidget.Enabled = not propertiesWidget.Enabled
	propertiesBtn:SetActive(propertiesWidget.Enabled)
end)

scriptBtn.Click:Connect(function()
	scriptWidget.Enabled = not scriptWidget.Enabled
	scriptBtn:SetActive(scriptWidget.Enabled)
end)

explorerWidget:GetPropertyChangedSignal("Enabled"):Connect(function()
	explorerBtn:SetActive(explorerWidget.Enabled)
end)
propertiesWidget:GetPropertyChangedSignal("Enabled"):Connect(function()
	propertiesBtn:SetActive(propertiesWidget.Enabled)
end)
scriptWidget:GetPropertyChangedSignal("Enabled"):Connect(function()
	scriptBtn:SetActive(scriptWidget.Enabled)
end)

explorerBtn:SetActive(explorerWidget.Enabled)
propertiesBtn:SetActive(propertiesWidget.Enabled)
scriptBtn:SetActive(scriptWidget.Enabled)

Selection.SelectionChanged:Connect(function()
	Host.onSelection(Selection:Get())
end)

plugin.Unloading:Connect(function()
	scriptInjector.destroy()
	if explorerApi and explorerApi.destroy then
		explorerApi.destroy()
	end
	if propertiesApi and propertiesApi.destroy then
		propertiesApi.destroy()
	end
	if scriptApi and scriptApi.destroy then
		scriptApi.destroy()
	end
end)

ChangeHistoryService:SetWaypoint("Fragua Ready")
print("[Fragua] Plugin loaded - forge custom instance types in Explorer > Insert Object.")
