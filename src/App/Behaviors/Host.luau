local CollectionService = game:GetService("CollectionService")
local Constants = require(script.Parent.Parent.Shared.Constants)
local Registry = require(script.Parent.Parent.Types.Registry)
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
	if loaded[instance] then
		return loaded[instance]
	end
	local module = instance:FindFirstChild(Constants.BEHAVIOR_NAME)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok or typeof(result) ~= "table" then
		warn(`[Fragua] Failed to load behavior for {instance:GetFullName()}: {result}`)
		return nil
	end
	loaded[instance] = result
	return result
end

local function callHook(instance: Instance, hook: string, ...)
	local behavior = loadBehavior(instance)
	if behavior and typeof(behavior[hook]) == "function" then
		Util.safePcall(`{instance.Name}.{hook}`, function()
			behavior[hook](instance, ...)
		end)
	end
end

local function watch(instance: Instance)
	if connections[instance] then
		return
	end
	local cons = {}
	table.insert(cons, instance.AncestryChanged:Connect(function()
		if not instance:IsDescendantOf(game) then
			unload(instance)
			return
		end
		callHook(instance, "onAncestryChanged")
	end))
	table.insert(cons, instance.AttributeChanged:Connect(function(attr)
		if attr ~= Constants.TYPE_ATTR then
			callHook(instance, "onPropertyChanged", attr, instance:GetAttribute(attr))
		end
	end))
	connections[instance] = cons
	callHook(instance, "onCreated")
end

function Host.start()
	Registry.ensureRoot()

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
	for _, inst in instances do
		if Registry.isFraguaInstance(inst) then
			callHook(inst, "onSelected")
		end
	end
end

function Host.runCreated(instance: Instance)
	watch(instance)
	callHook(instance, "onCreated")
end

return Host
