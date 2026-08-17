local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local ScriptEditorService = game:GetService("ScriptEditorService")
local RunService = game:GetService("RunService")

local Explorer = require(script.App.Explorer)
local Properties = require(script.App.Properties)
local SettingsStore = require(script.App.Settings.Store)
local EnsurePlaceModules = require(script.App.Runtime.EnsurePlaceModules)
local ScriptInjector = require(script.App.Runtime.ScriptInjector)
local TypeCatalog = require(script.App.Runtime.TypeCatalog)
local TypeSurface = require(script.App.Runtime.TypeSurface)
local AutocompleteProvider = require(script.App.Runtime.AutocompleteProvider)
local Host = require(script.App.Behaviors.Host)
local Registry = require(script.App.Types.Registry)
local EnumRegistry = require(script.App.Types.EnumRegistry)
local Constants = require(script.App.Shared.Constants)
local LifecycleGate = require(script.App.Shared.LifecycleGate)

SettingsStore.bind(plugin)

Registry.seedDefaults()
local behaviorSync = Registry.watchBehaviorTemplates()
local surfaceRevision = 0

local function buildSurface()
	surfaceRevision += 1
	local surface = TypeSurface.build(Registry.list(), function(definition)
		return Registry.resolvedSchema(definition)
	end, function(typeId)
		return Registry.getBackingClass(typeId)
	end, function(typeId, side)
		return Registry.getBehaviorSource(typeId, side)
	end, nil, EnumRegistry.list())
	surface.revision = surfaceRevision
	return surface
end

local currentSurface = buildSurface()
TypeCatalog.sync(Registry, currentSurface)
EnsurePlaceModules.sync(currentSurface)
local autocompleteProvider = AutocompleteProvider.start(function()
	return currentSurface
end)
local scriptInjector = ScriptInjector.start()
local catalogConnection = Registry.Changed:Connect(function()
	currentSurface = buildSurface()
	TypeCatalog.sync(Registry, currentSurface)
	EnsurePlaceModules.sync(currentSurface)
end)
local enumConnection = EnumRegistry.Changed:Connect(function()
	currentSurface = buildSurface()
	TypeCatalog.sync(Registry, currentSurface)
	EnsurePlaceModules.sync(currentSurface)
end)

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
local lifecycleGate = LifecycleGate.new()
local runStateConnection = RunService:GetPropertyChangedSignal("RunState"):Connect(function()
	local token = lifecycleGate:advance()
	explorerApi.refreshForRunState()
	propertiesApi.refreshForRunState()
	task.defer(function()
		if lifecycleGate:isCurrent(token) then
			explorerApi.rebuild()
			propertiesApi.rebuild()
		end
	end)
end)

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

local selectionConnection = Selection.SelectionChanged:Connect(function()
	local valid = {}
	for _, instance in Selection:Get() do
		if instance:IsDescendantOf(game) then
			table.insert(valid, instance)
		end
	end
	Host.onSelection(valid)
end)

plugin.Unloading:Connect(function()
	autocompleteProvider.destroy()
	scriptInjector.destroy()
	behaviorSync.destroy()
	catalogConnection:Disconnect()
	enumConnection:Disconnect()
	runStateConnection:Disconnect()
	selectionConnection:Disconnect()
	if explorerApi and explorerApi.destroy then
		explorerApi.destroy()
	end
	if propertiesApi and propertiesApi.destroy then
		propertiesApi.destroy()
	end
end)

ChangeHistoryService:SetWaypoint("Fragua Ready")
