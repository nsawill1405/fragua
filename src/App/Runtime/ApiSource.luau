local WrapperPolicy = if script then require(script.Parent.WrapperPolicy) else require("./WrapperPolicy")

local ApiSource = {}

local function quote(value: string): string
	return string.format("%q", value)
end

local function sortedKeys(values): { string }
	local keys = {}
	for key in values do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function encodeSet(values): string
	local fields = {}
	for _, key in sortedKeys(values) do
		if values[key] then
			table.insert(fields, "[ " .. quote(key) .. " ] = true")
		end
	end
	return "{ " .. table.concat(fields, ", ") .. " }"
end

local function encodeKnownMethods(surface): string
	local entries = {}
	for _, typeEntry in surface.types or {} do
		local sides = {}
		for _, side in { "Server", "Client" } do
			local methods = if side == "Server" then typeEntry.serverMethods else typeEntry.clientMethods
			local names = {}
			for _, method in methods or {} do
				if typeof(method.name) == "string" then
					names[method.name] = true
				end
			end
			table.insert(sides, "[ " .. quote(side) .. " ] = " .. encodeSet(names))
		end
		table.insert(entries, "[ " .. quote(typeEntry.id) .. " ] = { " .. table.concat(sides, ", ") .. " }")
	end
	table.sort(entries)
	return "{ " .. table.concat(entries, ", ") .. " }"
end

local SOURCE = [=[
-- Fragua runtime API. Managed script headers select Core, Server, or Client.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RobloxInstance = Instance
local RobloxEnum = Enum
local RobloxType = type
local RobloxTypeof = typeof

local TAG = "FraguaInstance"
local TYPE_ATTR = "_FraguaType"
local CATALOG_NAME = "FraguaTypes"
local REFERENCE_PREFIX = "_FraguaRef_"

local CORE_MEMBERS = @@CORE_MEMBERS@@
local LIFECYCLE_MEMBERS = @@LIFECYCLE_MEMBERS@@
local WRAPPER_MEMBERS = @@WRAPPER_MEMBERS@@
local KNOWN_METHOD_SIDES = @@KNOWN_METHOD_SIDES@@

local wrappersBySide = {
	Core = setmetatable({}, { __mode = "kv" }),
	Server = setmetatable({}, { __mode = "kv" }),
	Client = setmetatable({}, { __mode = "kv" }),
}
local wrapperStates = setmetatable({}, { __mode = "k" })
local behaviorCache = {
	Server = {},
	Client = {},
}

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
		elseif RobloxTypeof(key) == "string" and findDefinition(key) then
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
	__metatable = "FraguaEnumType",
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
	__metatable = "FraguaEnum",
})

local function readTypeId(backing): string?
	local ok, value = pcall(backing.GetAttribute, backing, TYPE_ATTR)
	if ok and RobloxTypeof(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function assertUsable(state)
	if state.destroyed then
		error(`[Fragua] attempted to use a destroyed {state.typeId} wrapper`, 3)
	end
end

local function unwrap(value)
	local state = wrapperStates[value]
	if state then
		assertUsable(state)
		return state.backing
	end
	return value
end

local function unwrapArguments(...)
	local arguments = table.pack(...)
	for index = 1, arguments.n do
		arguments[index] = unwrap(arguments[index])
	end
	return table.unpack(arguments, 1, arguments.n)
end

local function propertiesFolder(definition)
	local properties = definition and definition:FindFirstChild("Properties")
	if properties and properties:IsA("Folder") then
		return properties
	end
	return nil
end

local function propertyMetadata(definition, name: string)
	local properties = propertiesFolder(definition)
	local property = properties and properties:FindFirstChild(name)
	if property and property:IsA("Configuration") then
		return property
	end
	return nil
end

local function hasBackingMember(backing, name: string): boolean
	return pcall(function()
		local _ = backing[name]
	end)
end

local function isCustomProperty(definition, backing, name: string)
	local property = propertyMetadata(definition, name)
	if not property then
		return nil
	end
	if hasBackingMember(backing, name) then
		return nil
	end
	return property
end

local function isReferenceProperty(property): boolean
	local valueType = property:GetAttribute("ValueType")
	return valueType == "Instance" or valueType == "FraguaInstance" or property:GetAttribute("ReferenceType") ~= nil
end

local function ensureReference(backing, name: string)
	local childName = REFERENCE_PREFIX .. name
	local reference = backing:FindFirstChild(childName)
	if reference and reference:IsA("ObjectValue") then
		return reference
	end
	if reference then
		reference:Destroy()
	end
	reference = RobloxInstance.new("ObjectValue")
	reference.Name = childName
	reference:SetAttribute("_FraguaManaged", true)
	reference.Parent = backing
	return reference
end

local function declaredEnumName(property, value): string?
	local enumTypeName = property:GetAttribute("EnumType")
	if RobloxTypeof(enumTypeName) ~= "string" then
		return nil
	end
	local enumType = RobloxEnum[enumTypeName]
	if not enumType then
		return nil
	end
	local name
	if RobloxTypeof(value) == "EnumItem" then
		if value.EnumType ~= enumType then
			return nil
		end
		name = value.Name
	elseif RobloxTypeof(value) == "string" then
		name = value
	else
		return nil
	end
	local enumItems = property:FindFirstChild("EnumItems")
	if enumItems then
		for _, item in enumItems:GetChildren() do
			if item:IsA("StringValue") and item.Value == name then
				return name
			end
		end
		return nil
	end
	return if enumType[name] then name else nil
end

local wrap

local function readCustomProperty(state, property, name: string)
	local backing = state.backing
	if isReferenceProperty(property) then
		local reference = backing:FindFirstChild(REFERENCE_PREFIX .. name)
		local value = if reference and reference:IsA("ObjectValue") then reference.Value else nil
		return if value then wrap(value, state.side) else nil
	end
	local value = backing:GetAttribute(name)
	local enumTypeName = property:GetAttribute("EnumType")
	if RobloxTypeof(enumTypeName) == "string" and value ~= nil then
		local enumType = RobloxEnum[enumTypeName]
		return if enumType then enumType[value] else nil
	end
	return value
end

local function customIsA(backing, typeId: string): boolean
	local ownTypeId = readTypeId(backing)
	if ownTypeId == typeId then
		return true
	end
	local definition = ownTypeId and findDefinition(ownTypeId)
	local ancestors = definition and definition:FindFirstChild("FraguaAncestors")
	if ancestors then
		for _, ancestor in ancestors:GetChildren() do
			if ancestor:IsA("StringValue") and ancestor.Value == typeId then
				return true
			end
		end
	end
	return false
end

local function writeCustomProperty(state, property, name: string, value)
	if property:GetAttribute("Readonly") == true then
		error(`[Fragua] property "{name}" is read-only`, 3)
	end
	local backing = state.backing
	if isReferenceProperty(property) then
		local unwrapped = if value == nil then nil else unwrap(value)
		if unwrapped ~= nil and RobloxTypeof(unwrapped) ~= "Instance" then
			error(`[Fragua] property "{name}" expects an Instance or nil`, 3)
		end
		local referenceType = property:GetAttribute("ReferenceType")
		if unwrapped and RobloxTypeof(referenceType) == "string" and not customIsA(unwrapped, referenceType) then
			error(`[Fragua] property "{name}" expects a {referenceType} reference`, 3)
		end
		ensureReference(backing, name).Value = unwrapped
		return
	end
	local enumTypeName = property:GetAttribute("EnumType")
	if RobloxTypeof(enumTypeName) == "string" then
		local enumName = declaredEnumName(property, value)
		if not enumName then
			error(`[Fragua] property "{name}" expects an item from Enum.{enumTypeName}`, 3)
		end
		backing:SetAttribute(name, enumName)
		return
	end
	backing:SetAttribute(name, unwrap(value))
end

local function applyIdentity(backing, typeId: string)
	backing:SetAttribute(TYPE_ATTR, typeId)
	CollectionService:AddTag(backing, TAG)
end

local function eachCustomProperty(definition, backing, callback)
	local properties = propertiesFolder(definition)
	if not properties then
		return
	end
	for _, property in properties:GetChildren() do
		if property:IsA("Configuration") and isCustomProperty(definition, backing, property.Name) then
			callback(property, property.Name)
		end
	end
end

local function applyCustomDefaults(backing, definition)
	local defaults = definition:FindFirstChild("Defaults")
	if not defaults then
		return
	end
	eachCustomProperty(definition, backing, function(property, name)
		if isReferenceProperty(property) then
			local source = defaults:FindFirstChild(REFERENCE_PREFIX .. name)
			local value = if source and source:IsA("ObjectValue") then source.Value else nil
			ensureReference(backing, name).Value = value
		else
			local value = defaults:GetAttribute(name)
			if value ~= nil then
				backing:SetAttribute(name, value)
			end
		end
	end)
end

local function copyCustomValues(source, destination, definition)
	eachCustomProperty(definition, source, function(property, name)
		if isReferenceProperty(property) then
			local sourceReference = source:FindFirstChild(REFERENCE_PREFIX .. name)
			local value = if sourceReference and sourceReference:IsA("ObjectValue") then sourceReference.Value else nil
			ensureReference(destination, name).Value = value
		else
			local value = source:GetAttribute(name)
			destination:SetAttribute(name, value)
		end
	end)
end

local function findBehaviorTemplate(typeId: string, side: string)
	if side == "Server" then
		local root = ServerStorage:FindFirstChild("Fragua")
		local types = root and root:FindFirstChild("Types")
		local template = types and types:FindFirstChild(typeId .. "ServerBehavior")
		if template and template:IsA("ModuleScript") then
			return template
		end
	elseif side == "Client" then
		local definition = findDefinition(typeId)
		local template = definition and definition:FindFirstChild("ClientBehavior")
		if template and template:IsA("ModuleScript") then
			return template
		end
	end
	return nil
end

local function loadBehavior(typeId: string, side: string)
	if side == "Core" then
		return nil
	end
	local cached = behaviorCache[side][typeId]
	if cached ~= nil then
		return if cached == false then nil else cached
	end
	local template = findBehaviorTemplate(typeId, side)
	if not template then
		behaviorCache[side][typeId] = false
		return nil
	end
	local ok, behavior = pcall(require, template)
	if not ok then
		error(`[Fragua] could not load {side} behavior for {typeId}: {tostring(behavior)}`, 3)
	end
	if RobloxTypeof(behavior) ~= "table" then
		error(`[Fragua] {side} behavior for {typeId} must return a table`, 3)
	end
	behaviorCache[side][typeId] = behavior
	return behavior
end

local function wrongSideFor(typeId: string, side: string, name: string): string?
	local known = KNOWN_METHOD_SIDES[typeId]
	if not known then
		return nil
	end
	if side == "Core" then
		if known.Server[name] then
			return "Server"
		elseif known.Client[name] then
			return "Client"
		end
	elseif side == "Server" and known.Client[name] and not known.Server[name] then
		return "Client"
	elseif side == "Client" and known.Server[name] and not known.Client[name] then
		return "Server"
	end
	return nil
end

local function disconnectState(state)
	for _, connection in state.connections do
		connection:Disconnect()
	end
	table.clear(state.connections)
end

local function invalidateBacking(backing)
	for _, wrappers in wrappersBySide do
		local proxy = wrappers[backing]
		if proxy then
			local state = wrapperStates[proxy]
			if state and not state.destroyed then
				state.destroyed = true
				disconnectState(state)
			end
			wrappers[backing] = nil
		end
	end
end

local function cachedCoreMethod(state, name: string, create)
	local method = state.methods[name]
	if not method then
		method = create()
		state.methods[name] = method
	end
	return method
end

local function coreMember(state, key: string)
	if key == "Instance" then
		return true, state.backing
	elseif key == "TypeId" then
		return true, state.typeId
	elseif key == "Destroy" then
		return true, cachedCoreMethod(state, key, function()
			return function(_)
				assertUsable(state)
				local backing = state.backing
				invalidateBacking(backing)
				backing:Destroy()
			end
		end)
	elseif key == "Clone" then
		return true, cachedCoreMethod(state, key, function()
			return function(_)
				assertUsable(state)
				local clone = state.backing:Clone()
				if clone == nil then
					return nil
				end
				applyIdentity(clone, state.typeId)
				local definition = findDefinition(state.typeId)
				if definition then
					copyCustomValues(state.backing, clone, definition)
				end
				return wrap(clone, state.side)
			end
		end)
	elseif key == "IsA" then
		return true, cachedCoreMethod(state, key, function()
			return function(_, classOrType: string)
				assertUsable(state)
				if customIsA(state.backing, classOrType) then
					return true
				end
				return state.backing:IsA(classOrType)
			end
		end)
	end
	return false, nil
end

local WRAPPER_METATABLE = {}

WRAPPER_METATABLE.__index = function(proxy, key)
	local state = wrapperStates[proxy]
	if not state then
		error("[Fragua] invalid wrapper", 2)
	end
	if key == "TypeId" then
		return state.typeId
	end
	assertUsable(state)

	local handled, core = coreMember(state, key)
	if handled then
		return core
	end
	if LIFECYCLE_MEMBERS[key] then
		error(`[Fragua] lifecycle method "{key}" cannot be called through a wrapper`, 2)
	end

	local behavior = loadBehavior(state.typeId, state.side)
	local customMethod = behavior and behavior[key]
	if RobloxTypeof(customMethod) == "function" then
		if CORE_MEMBERS[key] or hasBackingMember(state.backing, key) then
			error(`[Fragua] custom method "{key}" conflicts with a reserved member`, 2)
		end
		local cached = state.methods[key]
		if not cached then
			cached = function(_, ...)
				assertUsable(state)
				return customMethod(state.backing, unwrapArguments(...))
			end
			state.methods[key] = cached
		end
		return cached
	end
	local wrongSide = wrongSideFor(state.typeId, state.side, key)
	if wrongSide then
		error(`[Fragua] method "{key}" is only available through the {wrongSide} facade`, 2)
	end

	local definition = findDefinition(state.typeId)
	local property = definition and isCustomProperty(definition, state.backing, key)
	if property then
		return readCustomProperty(state, property, key)
	end

	local ok, member = pcall(function()
		return state.backing[key]
	end)
	if not ok then
		error(member, 2)
	end
	if RobloxTypeof(member) == "function" then
		local cached = state.methods[key]
		if not cached then
			cached = function(_, ...)
				assertUsable(state)
				return member(state.backing, unwrapArguments(...))
			end
			state.methods[key] = cached
		end
		return cached
	end
	return member
end

WRAPPER_METATABLE.__newindex = function(proxy, key, value)
	local state = wrapperStates[proxy]
	if not state then
		error("[Fragua] invalid wrapper", 2)
	end
	assertUsable(state)
	if WRAPPER_MEMBERS[key] or LIFECYCLE_MEMBERS[key] then
		error(`[Fragua] member "{key}" is read-only`, 2)
	end
	local definition = findDefinition(state.typeId)
	local property = definition and isCustomProperty(definition, state.backing, key)
	if property then
		writeCustomProperty(state, property, key, value)
		return
	end
	state.backing[key] = unwrap(value)
end

WRAPPER_METATABLE.__tostring = function(proxy)
	local state = wrapperStates[proxy]
	if not state then
		return "FraguaInstance"
	end
	assertUsable(state)
	return tostring(state.backing)
end

WRAPPER_METATABLE.__metatable = "FraguaInstance"

wrap = function(backing, side: string)
	local typeId = readTypeId(backing)
	if not typeId then
		return backing
	end
	local wrappers = wrappersBySide[side]
	local existing = wrappers[backing]
	if existing then
		return existing
	end
	local state = {
		backing = backing,
		typeId = typeId,
		side = side,
		methods = {},
		connections = {},
		destroyed = false,
	}
	local proxy = setmetatable({}, WRAPPER_METATABLE)
	wrapperStates[proxy] = state
	wrappers[backing] = proxy
	return proxy
end

local function makeFacade(side: string)
	local Facade = {}
	local FraguaInstance = {}

	function FraguaInstance.new(classOrType, parent)
		local className
		local forceCustom = false
		if RobloxTypeof(classOrType) == "string" then
			className = classOrType
		elseif RobloxTypeof(classOrType) == "table" and getmetatable(classOrType) == CUSTOM_ITEM_METATABLE then
			className = classOrType.Name
			forceCustom = true
		else
			error("Instance.new expects a Roblox class name, Fragua type ID, or Enum.FraguaType item", 2)
		end

		if not forceCustom then
			local nativeOk, native = pcall(function()
				return RobloxInstance.new(className)
			end)
			if nativeOk then
				native.Parent = if parent == nil then nil else unwrap(parent)
				return native
			end
		end

		local definition = findDefinition(className)
		if not definition then
			error('Unable to create an Instance of type "' .. className .. '"', 2)
		end
		local backingClass = definition:GetAttribute("BackingClass")
		if RobloxTypeof(backingClass) ~= "string" or backingClass == "" then
			error(`[Fragua] type "{className}" has no backing class`, 2)
		end
		local backing = RobloxInstance.new(backingClass)
		backing.Name = definition:GetAttribute("DisplayName") or className
		applyIdentity(backing, className)
		applyCustomDefaults(backing, definition)
		backing.Parent = if parent == nil then nil else unwrap(parent)
		return wrap(backing, side)
	end

	function FraguaInstance.fromExisting(existing)
		local state = wrapperStates[existing]
		if state then
			assertUsable(state)
		end
		local backing = if state then state.backing else existing
		local typeId = readTypeId(backing)
		if not typeId then
			return RobloxInstance.fromExisting(backing)
		end
		local duplicate = RobloxInstance.fromExisting(backing)
		if duplicate == nil then
			return nil
		end
		applyIdentity(duplicate, typeId)
		local definition = findDefinition(typeId)
		if definition then
			copyCustomValues(backing, duplicate, definition)
		end
		return wrap(duplicate, side)
	end

	setmetatable(FraguaInstance, {
		__index = function(_, key)
			return RobloxInstance[key]
		end,
		__newindex = function()
			error("Instance is immutable", 2)
		end,
		__metatable = "FraguaInstanceFacade",
	})

	Facade.Instance = FraguaInstance
	Facade.Enum = FraguaEnum

	function Facade.type(value)
		if wrapperStates[value] then
			return "userdata"
		end
		return RobloxType(value)
	end

	function Facade.typeof(value)
		if wrapperStates[value] then
			return "Instance"
		end
		return RobloxTypeof(value)
	end

	function Facade.GetTypeId(value): string?
		local state = wrapperStates[value]
		if state then
			return state.typeId
		end
		if RobloxTypeof(value) ~= "Instance" then
			return nil
		end
		return readTypeId(value)
	end

	function Facade.IsA(value, classOrType: string): boolean
		local state = wrapperStates[value]
		if state then
			assertUsable(state)
			if customIsA(state.backing, classOrType) then
				return true
			end
			return state.backing:IsA(classOrType)
		end
		if RobloxTypeof(value) ~= "Instance" then
			return false
		end
		return customIsA(value, classOrType) or value:IsA(classOrType)
	end

	function Facade.Get(value)
		local state = wrapperStates[value]
		if state then
			assertUsable(state)
			return wrap(state.backing, side)
		end
		if RobloxTypeof(value) ~= "Instance" then
			error("Fragua.Get expects an Instance", 2)
		end
		return wrap(value, side)
	end

	function Facade.GetProperty(value, name: string)
		local wrapped = Facade.Get(value)
		if wrapperStates[wrapped] then
			return wrapped[name]
		end
		if name == "Name" then
			return wrapped.Name
		end
		return wrapped:GetAttribute(name)
	end

	function Facade.SetProperty(value, name: string, nextValue)
		local wrapped = Facade.Get(value)
		if wrapperStates[wrapped] then
			wrapped[name] = nextValue
		elseif name == "Name" then
			wrapped.Name = tostring(nextValue)
		else
			wrapped:SetAttribute(name, unwrap(nextValue))
		end
	end

	function Facade.GetInstances(typeId: string?)
		local result = {}
		for _, backing in CollectionService:GetTagged(TAG) do
			if typeId == nil or readTypeId(backing) == typeId then
				table.insert(result, wrap(backing, side))
			end
		end
		return result
	end

	return Facade
end

local Core = makeFacade("Core")
local Server = makeFacade("Server")
local Client = makeFacade("Client")

local Fragua = {
	Core = Core,
	Server = Server,
	Client = Client,
}

-- Compatibility aliases keep pre-facade managed headers runnable until upgraded.
Fragua.Instance = Core.Instance
Fragua.Enum = Core.Enum
Fragua.type = Core.type
Fragua.typeof = Core.typeof
Fragua.GetTypeId = Core.GetTypeId
Fragua.IsA = Core.IsA
Fragua.Get = Core.Get
Fragua.GetProperty = Core.GetProperty
Fragua.SetProperty = Core.SetProperty
Fragua.GetInstances = Core.GetInstances

return Fragua
]=]

function ApiSource.build(surface: any?): string
	local resolvedSurface = surface or { types = {} }
	local source = SOURCE:gsub("@@CORE_MEMBERS@@", encodeSet(WrapperPolicy.coreMembers))
	source = source:gsub("@@LIFECYCLE_MEMBERS@@", encodeSet(WrapperPolicy.lifecycleMembers))
	source = source:gsub("@@WRAPPER_MEMBERS@@", encodeSet(WrapperPolicy.wrapperMembers))
	source = source:gsub("@@KNOWN_METHOD_SIDES@@", encodeKnownMethods(resolvedSurface))
	return source
end

return ApiSource
