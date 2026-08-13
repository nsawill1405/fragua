local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Constants = require(script.Parent.Parent.Shared.Constants)
local Registry = require(script.Parent.Parent.Types.Registry)
local ScriptHeader = require(script.Parent.Parent.Runtime.ScriptHeader)
local Util = require(script.Parent.Parent.Shared.Util)

local Host = {}

local loaded: { [Instance]: any } = {}
local connections: { [Instance]: { RBXScriptConnection } } = {}

local function unload(instance: Instance)
	local cons = connections[instance]
	if cons then
		for _, c in cons do
			c:Disconnect()
		end
		connections[instance] = nil
	end
	loaded[instance] = nil
end

local function loadBehavior(instance: Instance)
	if not RunService:IsEdit() then
		return nil
	end
	if loaded[instance] then
		return loaded[instance]
	end
	local typeId = Registry.getTypeId(instance)
	if not typeId then
		return nil
	end
	local source = Registry.getBehaviorSource(typeId, "Edit")
	if not source then
		return nil
	end
	-- edit host runs in the plugin; strip managed headers so Instance/Enum stay roblox natives
	source = ScriptHeader.strip(source)
	-- loadstring so shared Edit Behavior edits hot-reload in Studio (require caches).
	local chunk, err = loadstring(source, instance:GetFullName() .. ".EditBehavior")
	if not chunk then
		warn(`[Fragua] Failed to compile behavior for {instance:GetFullName()}: {err}`)
		return nil
	end
	local ok, result = pcall(chunk)
	if not ok or typeof(result) ~= "table" then
		warn(`[Fragua] Failed to load behavior for {instance:GetFullName()}: {result}`)
		return nil
	end
	loaded[instance] = result
	return result
end

local function callHook(instance: Instance, hook: string, ...)
	if not RunService:IsEdit() then
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
	if not RunService:IsEdit() or connections[instance] then
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

function Host.invalidateType(typeId: string)
	for inst in pairs(loaded) do
		if Registry.getTypeId(inst) == typeId then
			unload(inst)
		end
	end
	if RunService:IsEdit() then
		for _, inst in CollectionService:GetTagged(Constants.TAG) do
			if Registry.getTypeId(inst) == typeId then
				watch(inst)
			end
		end
	end
end

function Host.start()
	if not RunService:IsEdit() then
		return
	end
	Registry.ensureRoot()
	-- rewrite any server templates that still require Edit Behavior at play time
	for _, def in Registry.list() do
		Registry.ensureBehaviorTemplate(def.id, "Server")
		Registry.ensureBehaviorTemplate(def.id, "Edit")
	end

	for _, inst in CollectionService:GetTagged(Constants.TAG) do
		watch(inst)
	end

	CollectionService:GetInstanceAddedSignal(Constants.TAG):Connect(function(inst)
		watch(inst)
	end)
	CollectionService:GetInstanceRemovedSignal(Constants.TAG):Connect(function(inst)
		unload(inst)
	end)
end

function Host.onSelection(instances: { Instance })
	if not RunService:IsEdit() then
		return
	end
	for _, inst in instances do
		if Registry.isFraguaInstance(inst) then
			callHook(inst, "onSelected")
		end
	end
end

function Host.runCreated(instance: Instance)
	if not RunService:IsEdit() then
		return
	end
	-- watch already fires onCreated once; dont call the hook again
	watch(instance)
end

return Host
