-- Source string for ReplicatedStorage.Fragua ModuleScript placed in the game.
return [=[
-- Fragua runtime API. Scripts receive Fragua, Instance, and Enum aliases automatically.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RobloxInstance = Instance
local RobloxEnum = Enum

local TAG = "FraguaInstance"
local TYPE_ATTR = "_FraguaType"
local CATALOG_NAME = "FraguaTypes"

local Fragua = {}

local function catalog()
	return ReplicatedStorage:FindFirstChild(CATALOG_NAME)
end

local function findDefinition(typeId: string)
	local root = catalog()
	local definition = root and root:FindFirstChild(typeId)
	if definition and definition:IsA("Configuration") then
		return definition
	end
	return nil
end

local CUSTOM_ITEM_METATABLE = {}
local customItems = {}

local function customItem(typeId: string)
	local existing = customItems[typeId]
	if existing then
		return existing
	end
	local item = {}
	setmetatable(item, {
		__index = function(_, key)
			if key == "Name" or key == "Value" then
				return typeId
			elseif key == "EnumType" then
				return "FraguaType"
			end
			return nil
		end,
		__newindex = function()
			error("Fragua enum items are immutable", 2)
		end,
		__tostring = function()
			return "Enum.FraguaType." .. typeId
		end,
		__metatable = CUSTOM_ITEM_METATABLE,
	})
	customItems[typeId] = item
	return item
end

local FraguaType = {}
setmetatable(FraguaType, {
	__index = function(_, key)
		if key == "Name" then
			return "FraguaType"
		elseif key == "GetEnumItems" then
			return function()
				local items = {}
				local root = catalog()
				if root then
					for _, definition in root:GetChildren() do
						if definition:IsA("Configuration") then
							table.insert(items, customItem(definition.Name))
						end
					end
				end
				table.sort(items, function(a, b)
					return a.Name < b.Name
				end)
				return items
			end
		elseif typeof(key) == "string" and findDefinition(key) then
			return customItem(key)
		end
		return nil
	end,
	__newindex = function()
		error("Fragua enum types are immutable", 2)
	end,
	__tostring = function()
		return "Enum.FraguaType"
	end,
})

local FraguaEnum = {}
setmetatable(FraguaEnum, {
	__index = function(_, key)
		if key == "FraguaType" then
			return FraguaType
		elseif key == "GetEnums" then
			return function()
				local enums = RobloxEnum:GetEnums()
				table.insert(enums, 1, FraguaType)
				return enums
			end
		end
		return RobloxEnum[key]
	end,
	__newindex = function()
		error("Enum is immutable", 2)
	end,
})

local FraguaInstance = {}

function FraguaInstance.new(classOrType, parent: Instance?): Instance
	local className
	if typeof(classOrType) == "string" then
		className = classOrType
	elseif typeof(classOrType) == "table" and getmetatable(classOrType) == CUSTOM_ITEM_METATABLE then
		className = classOrType.Name
	else
		error("Instance.new expects a Roblox class name, Fragua type ID, or Enum.FraguaType item", 2)
	end

	local nativeOk, native = pcall(function()
		return RobloxInstance.new(className)
	end)
	if nativeOk then
		native.Parent = parent
		return native
	end

	local definition = findDefinition(className)
	if not definition then
		error('Unable to create an Instance of type "' .. className .. '"', 2)
	end

	local instance = RobloxInstance.new("Configuration")
	instance.Name = definition:GetAttribute("DisplayName") or className
	instance:SetAttribute(TYPE_ATTR, className)
	CollectionService:AddTag(instance, TAG)

	local defaults = definition:FindFirstChild("Defaults")
	if defaults then
		for name, value in defaults:GetAttributes() do
			if name ~= "_FraguaManaged" then
				instance:SetAttribute(name, value)
			end
		end
	end

	local behaviorTemplate = definition:FindFirstChild("Behavior")
	if behaviorTemplate and behaviorTemplate:IsA("ModuleScript") then
		local behavior = behaviorTemplate:Clone()
		behavior.Name = "Behavior"
		behavior.Parent = instance
	end

	instance.Parent = parent
	return instance
end

Fragua.Instance = FraguaInstance
Fragua.Enum = FraguaEnum

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
	for _, instance in CollectionService:GetTagged(TAG) do
		if typeId == nil or Fragua.GetTypeId(instance) == typeId then
			table.insert(out, instance)
		end
	end
	return out
end

return Fragua
]=]
