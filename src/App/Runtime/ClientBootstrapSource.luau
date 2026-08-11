-- Source string for StarterPlayer.StarterPlayerScripts.FraguaClientRuntime
return [=[
-- Fragua client play-mode behavior host
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TAG = "FraguaInstance"
local TYPE_ATTR = "_FraguaType"
local SIDE = "Client"
local TEMPLATE_NAME = "ClientBehavior"
local CATALOG_NAME = "FraguaTypes"

local started: { [Instance]: { typeId: string, behavior: any? } } = {}

local function warnFailure(instance: Instance, typeId: string, phase: string, problem: any)
	warn(
		`[FraguaRuntime] {SIDE} {phase} failed for type "{typeId}" at {instance:GetFullName()}: {tostring(problem)}`
	)
end

local function findTemplate(typeId: string): ModuleScript?
	local catalog = ReplicatedStorage:FindFirstChild(CATALOG_NAME)
	local definition = catalog and catalog:FindFirstChild(typeId)
	local template = definition and definition:FindFirstChild(TEMPLATE_NAME)
	if template and template:IsA("ModuleScript") then
		return template
	end
	return nil
end

local function start(instance: Instance)
	if started[instance] ~= nil then
		return
	end
	local typeId = instance:GetAttribute(TYPE_ATTR)
	if typeof(typeId) ~= "string" or typeId == "" then
		return
	end

	local state = { typeId = typeId, behavior = nil }
	started[instance] = state
	task.spawn(function()
		local phase = "load"
		local ok, problem = pcall(function()
			local template = findTemplate(typeId)
			assert(template, `missing {TEMPLATE_NAME}`)
			local behavior = require(template)
			assert(typeof(behavior) == "table", "behavior module must return a table")
			if started[instance] ~= state then
				return
			end
			state.behavior = behavior
			if typeof(behavior.onStart) == "function" then
				phase = "onStart"
				behavior.onStart(instance)
			end
		end)
		if not ok then
			warnFailure(instance, typeId, phase, problem)
		end
	end)
end

local function stop(instance: Instance)
	local state = started[instance]
	if not state then
		return
	end
	started[instance] = nil
	local behavior = state.behavior
	if behavior and typeof(behavior.onStop) == "function" then
		local ok, problem = pcall(behavior.onStop, instance)
		if not ok then
			warnFailure(instance, state.typeId, "onStop", problem)
		end
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(start)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(stop)

for _, instance in CollectionService:GetTagged(TAG) do
	start(instance)
end
]=]
