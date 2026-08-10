local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local ScriptEditorService = game:GetService("ScriptEditorService")

local Explorer = require(script.App.Explorer)
local Properties = require(script.App.Properties)
local SettingsStore = require(script.App.Settings.Store)
local EnsurePlaceModules = require(script.App.Runtime.EnsurePlaceModules)
local ScriptInjector = require(script.App.Runtime.ScriptInjector)
local TypeCatalog = require(script.App.Runtime.TypeCatalog)
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

local explorerInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, false, 320, 480, 240, 200)
local propertiesInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, true, false, 320, 480, 240, 200)

local explorerWidget = plugin:CreateDockWidgetPluginGuiAsync("FraguaExplorer", explorerInfo)
explorerWidget.Title = "Fragua Explorer"
explorerWidget.Name = "FraguaExplorer"

local propertiesWidget = plugin:CreateDockWidgetPluginGuiAsync("FraguaProperties", propertiesInfo)
propertiesWidget.Title = "Fragua Properties"
propertiesWidget.Name = "FraguaProperties"

Registry.seedDefaults()
local behaviorSync = Registry.watchBehaviorTemplates()
TypeCatalog.sync(Registry)
local catalogConnection = Registry.Changed:Connect(function()
	TypeCatalog.sync(Registry)
end)
Host.start()

local explorerApi = Explorer.mount(explorerWidget)
local propertiesApi = Properties.mount(propertiesWidget, {
	onEditScript = function(context)
		task.spawn(function()
			local ok, opened, err =
				pcall(ScriptEditorService.OpenScriptDocumentAsync, ScriptEditorService, context.target)
			if not ok or not opened then
				warn(`[Fragua] Could not open {context.target:GetFullName()}: {tostring(if ok then err else opened)}`)
			end
		end)
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
	scriptInjector.destroy()
	behaviorSync.destroy()
	catalogConnection:Disconnect()
	if explorerApi and explorerApi.destroy then
		explorerApi.destroy()
	end
	if propertiesApi and propertiesApi.destroy then
		propertiesApi.destroy()
	end
end)

ChangeHistoryService:SetWaypoint("Fragua Ready")
