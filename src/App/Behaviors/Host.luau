local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ScriptEditorService = game:GetService("ScriptEditorService")
local Constants = require(script.Parent.Parent.Shared.Constants)
local Registry = require(script.Parent.Parent.Types.Registry)
local BehaviorModel = require(script.Parent.Parent.Types.BehaviorModel)
local ScriptHeader = require(script.Parent.Parent.Runtime.ScriptHeader)
local Util = require(script.Parent.Parent.Shared.Util)

local Host = {}

local loaded: { [Instance]: any } = {}
local loadedByType: { [string]: any } = {}
local connections: { [Instance]: { RBXScriptConnection } } = {}
local hostConnections: { RBXScriptConnection } = {}
local suspended = false
local started = false

local function editSessionActive(): boolean
	if not RunService:IsEdit() then
		return false
	end
	if typeof((RunService :: any).IsRunMode) == "function" and RunService:IsRunMode() then
		return false
	end
	return RunService.RunState == Enum.RunState.Stopped
end

local function unload(instance: Instance)
	local cons = connections[instance]
	if cons then
		for _, c in cons do
			c:Disconnect()
		end
		connections[instance] = nil
	end
	local behavior = loaded[instance]
	loaded[instance] = nil
	if behavior and typeof(behavior.onStop) == "function" then
		Util.safePcall(`{instance.Name}.onStop`, function()
			behavior.onStop(instance)
		end)
	end
end

local function freshRequire(target: any): any
	-- clone so edit-time requires dont sit on a stale modulescript cache
	if typeof(target) == "Instance" and target:IsA("ModuleScript") then
		local clone = target:Clone()
		-- keep it next to the original so script.Parent requires still work
		clone.Name = target.Name .. "_FraguaFresh"
		clone.Parent = target.Parent
		local ok, result = pcall(require, clone)
		clone:Destroy()
		if not ok then
			error(result)
		end
		return result
	end
	return require(target)
end

local function compileBehavior(typeId: string, source: string): any?
	source = ScriptHeader.strip(source)
	-- shadow require so StickerSurface etc pick up disk edits
	local wrapped = "local require = ...\n" .. source
	local chunk, err = loadstring(wrapped, typeId .. ".EditBehavior")
	if not chunk then
		warn(`[Fragua] Failed to compile behavior for {typeId}: {err}`)
		return nil
	end
	local ok, result = pcall(chunk, freshRequire)
	if not ok or typeof(result) ~= "table" then
		warn(`[Fragua] Failed to load behavior for {typeId}: {result}`)
		return nil
	end
	return result
end

local function loadBehavior(instance: Instance)
	if not editSessionActive() or suspended then
		return nil
	end
	if loaded[instance] then
		return loaded[instance]
	end
	local typeId = Registry.getTypeId(instance)
	if not typeId then
		return nil
	end
	if loadedByType[typeId] then
		loaded[instance] = loadedByType[typeId]
		return loadedByType[typeId]
	end
	local source = Registry.getBehaviorSource(typeId, "Edit")
	if not source then
		return nil
	end
	local result = compileBehavior(typeId, source)
	if not result then
		return nil
	end
	loadedByType[typeId] = result
	loaded[instance] = result
	return result
end

local function callHook(instance: Instance, hook: string, ...)
	if not editSessionActive() or suspended then
		return
	end
	local behavior = loadBehavior(instance)
	if behavior and typeof(behavior[hook]) == "function" then
		local args = table.pack(...)
		Util.safePcall(`{instance.Name}.{hook}`, function()
			behavior[hook](instance, table.unpack(args, 1, args.n))
		end)
	end
end

local function watch(instance: Instance)
	if not editSessionActive() or suspended or connections[instance] then
		return
	end
	local cons = {}
	table.insert(
		cons,
		instance.AncestryChanged:Connect(function()
			if not instance:IsDescendantOf(game) then
				unload(instance)
				return
			end
			callHook(instance, "onAncestryChanged")
		end)
	)
	table.insert(
		cons,
		instance.AttributeChanged:Connect(function(attr)
			if attr ~= Constants.TYPE_ATTR then
				callHook(instance, "onPropertyChanged", attr, instance:GetAttribute(attr))
			end
		end)
	)
	connections[instance] = cons
	callHook(instance, "onCreated")
end

local function matchingInstances(typeId: string?): { Instance }
	local result = {}
	local seen = {}
	for _, inst in CollectionService:GetTagged(Constants.TAG) do
		if typeId == nil or Registry.getTypeId(inst) == typeId then
			seen[inst] = true
			table.insert(result, inst)
		end
	end
	for inst in pairs(loaded) do
		if not seen[inst] and (typeId == nil or Registry.getTypeId(inst) == typeId) then
			seen[inst] = true
			table.insert(result, inst)
		end
	end
	for inst in pairs(connections) do
		if not seen[inst] and (typeId == nil or Registry.getTypeId(inst) == typeId) then
			seen[inst] = true
			table.insert(result, inst)
		end
	end
	return result
end

local function clearTypeCache(typeId: string?)
	if typeId then
		loadedByType[typeId] = nil
		return
	end
	table.clear(loadedByType)
end

local function rewatch(typeId: string?)
	for _, inst in matchingInstances(typeId) do
		unload(inst)
	end
	clearTypeCache(typeId)
	if editSessionActive() and not suspended then
		for _, inst in CollectionService:GetTagged(Constants.TAG) do
			if typeId == nil or Registry.getTypeId(inst) == typeId then
				watch(inst)
			end
		end
		Host.onSelection(Selection:Get())
	end
end

local function applyOpenEditSource(typeId: string)
	local template = Registry.ensureBehaviorTemplate(typeId, "Edit")
	local ok, editorSource = pcall(function()
		return ScriptEditorService:GetEditorSource(template)
	end)
	if ok and typeof(editorSource) == "string" and editorSource ~= template.Source then
		template.Source = ScriptHeader.strip(editorSource)
	end
end

function Host.editSessionActive(): boolean
	return editSessionActive()
end

function Host.invalidateType(typeId: string)
	rewatch(typeId)
end

function Host.refreshType(typeId: string)
	applyOpenEditSource(typeId)
	rewatch(typeId)
	Registry.notifyChanged()
end

function Host.refreshAll()
	for _, def in Registry.list() do
		applyOpenEditSource(def.id)
	end
	rewatch(nil)
	Registry.notifyChanged()
end

function Host.suspend()
	if suspended then
		return
	end
	suspended = true
	for _, inst in matchingInstances(nil) do
		unload(inst)
	end
	clearTypeCache(nil)
end

function Host.resume()
	if not suspended and editSessionActive() then
		return
	end
	suspended = false
	if editSessionActive() then
		Host.refreshAll()
	end
end

local function ensureRefreshBindable()
	local root = Registry.ensureRoot()
	local existing = root:FindFirstChild(Constants.REFRESH_BINDABLE)
	if existing and not existing:IsA("BindableFunction") then
		existing:Destroy()
		existing = nil
	end
	local bindable = (existing or Instance.new("BindableFunction")) :: BindableFunction
	bindable.Name = Constants.REFRESH_BINDABLE
	bindable:SetAttribute("_FraguaManaged", true)
	bindable.OnInvoke = function(typeId)
		if typeof(typeId) == "string" and typeId ~= "" then
			Host.refreshType(typeId)
		else
			Host.refreshAll()
		end
	end
	bindable.Parent = root
end

local function editorTypeId(container: Instance): string?
	if not container:IsA("ModuleScript") then
		return nil
	end
	local typeIds = {}
	for _, def in Registry.list() do
		table.insert(typeIds, def.id)
	end
	local typeId, side = BehaviorModel.templateIdentity(container.Name, typeIds, false)
	if side == "Edit" then
		return typeId
	end
	return nil
end

local function hookEditorDocuments()
	local refreshForType = Util.debounce(0.4, function(typeId: string)
		if editSessionActive() and not suspended then
			Host.refreshType(typeId)
		end
	end)

	table.insert(
		hostConnections,
		ScriptEditorService.TextDocumentDidChange:Connect(function(document)
			local ok, container = pcall(document.GetScript, document)
			if not ok or not container then
				return
			end
			local typeId = editorTypeId(container)
			if typeId then
				refreshForType(typeId)
			end
		end)
	)
end

local function hookRunState()
	table.insert(
		hostConnections,
		RunService:GetPropertyChangedSignal("RunState"):Connect(function()
			if editSessionActive() then
				Host.resume()
			else
				Host.suspend()
			end
		end)
	)
end

function Host.start()
	if started then
		return
	end
	started = true
	if not RunService:IsEdit() then
		return
	end
	Registry.ensureRoot()
	ensureRefreshBindable()
	-- rewrite any server templates that still require Edit Behavior at play time
	for _, def in Registry.list() do
		Registry.ensureBehaviorTemplate(def.id, "Server")
		Registry.ensureBehaviorTemplate(def.id, "Edit")
	end

	hookEditorDocuments()
	hookRunState()

	table.insert(
		hostConnections,
		CollectionService:GetInstanceAddedSignal(Constants.TAG):Connect(function(inst)
			watch(inst)
		end)
	)
	table.insert(
		hostConnections,
		CollectionService:GetInstanceRemovedSignal(Constants.TAG):Connect(function(inst)
			unload(inst)
		end)
	)

	if not editSessionActive() then
		suspended = true
		return
	end

	for _, inst in CollectionService:GetTagged(Constants.TAG) do
		watch(inst)
	end
end

function Host.stop()
	for _, connection in hostConnections do
		connection:Disconnect()
	end
	table.clear(hostConnections)
	for inst in connections do
		unload(inst)
	end
	for inst in loaded do
		unload(inst)
	end
	clearTypeCache(nil)
	started = false
end

function Host.onSelection(instances: { Instance })
	if not editSessionActive() or suspended then
		return
	end
	for _, inst in instances do
		if Registry.isFraguaInstance(inst) then
			callHook(inst, "onSelected")
		end
	end
end

function Host.runCreated(instance: Instance)
	if not editSessionActive() or suspended then
		return
	end
	-- watch already fires onCreated once; dont call the hook again
	watch(instance)
end

return Host
