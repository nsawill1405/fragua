-- Source string for ReplicatedStorage.Fragua ModuleScript placed in the game.
-- use [=[ ]=] so nested ]] in comments dont close the string early
return [=[
-- Fragua runtime API: require(game:GetService("ReplicatedStorage").Fragua)
local CollectionService = game:GetService("CollectionService")

local TAG = "FraguaInstance"
local TYPE_ATTR = "_FraguaType"

local Fragua = {}

function Fragua.GetTypeId(instance: Instance): string?
	local attr = instance:GetAttribute(TYPE_ATTR)
	if typeof(attr) == "string" and attr ~= "" then
		return attr
	end
	return nil
end

function Fragua.IsA(instance: Instance, typeId: string): boolean
	return Fragua.GetTypeId(instance) == typeId
end

function Fragua.GetProperty(instance: Instance, name: string): any
	if name == "Name" then
		return instance.Name
	end
	return instance:GetAttribute(name)
end

function Fragua.SetProperty(instance: Instance, name: string, value: any)
	if name == "Name" then
		instance.Name = tostring(value)
		return
	end
	instance:SetAttribute(name, value)
end

function Fragua.Get(instance: Instance)
	local proxy = {}
	setmetatable(proxy, {
		__index = function(_, key)
			if key == "Instance" then
				return instance
			elseif key == "TypeId" then
				return Fragua.GetTypeId(instance)
			end
			return Fragua.GetProperty(instance, key)
		end,
		__newindex = function(_, key, value)
			Fragua.SetProperty(instance, key, value)
		end,
	})
	return proxy
end

function Fragua.GetInstances(typeId: string?): { Instance }
	local out = {}
	for _, inst in CollectionService:GetTagged(TAG) do
		if typeId == nil or Fragua.GetTypeId(inst) == typeId then
			table.insert(out, inst)
		end
	end
	return out
end

return Fragua
]=]
