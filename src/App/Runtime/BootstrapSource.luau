-- Source string for ServerScriptService.FraguaRuntime
-- use [=[ ]=] so nested ]] in comments dont close the string early
return [=[
-- Fragua play-mode behavior bootstrap (onStart / onStop)
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local TAG = "FraguaInstance"
local TYPE_ATTR = "_FraguaType"
local BEHAVIOR_NAME = "Behavior"

local started: { [Instance]: any } = {}

local function syncFromShared(instance: Instance)
	local typeId = instance:GetAttribute(TYPE_ATTR)
	if typeof(typeId) ~= "string" then
		return
	end
	local root = ServerStorage:FindFirstChild("Fragua")
	local types = root and root:FindFirstChild("Types")
	local shared = types and types:FindFirstChild(typeId .. "Behavior")
	local behavior = instance:FindFirstChild(BEHAVIOR_NAME)
	if shared and shared:IsA("ModuleScript") and behavior and behavior:IsA("ModuleScript") then
		behavior.Source = shared.Source
	end
end

local function loadBehavior(instance: Instance)
	syncFromShared(instance)
	local module = instance:FindFirstChild(BEHAVIOR_NAME)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and typeof(result) == "table" then
		return result
	end
	warn("[FraguaRuntime] Failed to require Behavior for", instance:GetFullName(), result)
	return nil
end

local function start(instance: Instance)
	if started[instance] then
		return
	end
	local behavior = loadBehavior(instance)
	if not behavior then
		return
	end
	started[instance] = behavior
	if typeof(behavior.onStart) == "function" then
		task.spawn(behavior.onStart, instance)
	end
end

local function stop(instance: Instance)
	local behavior = started[instance]
	if not behavior then
		return
	end
	if typeof(behavior.onStop) == "function" then
		pcall(behavior.onStop, instance)
	end
	started[instance] = nil
end

for _, inst in CollectionService:GetTagged(TAG) do
	start(inst)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(start)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(stop)

game:BindToClose(function()
	for inst in pairs(started) do
		stop(inst)
	end
end)
]=]
