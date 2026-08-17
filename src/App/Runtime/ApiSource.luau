local WrapperPolicy = if script then require(script.Parent.WrapperPolicy) else require("./WrapperPolicy")
local BehaviorSignatures = if script then require(script.Parent.BehaviorSignatures) else require("./BehaviorSignatures")

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

local LUAU_KEYWORDS = {
	["and"] = true,
	["break"] = true,
	["continue"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["export"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["type"] = true,
	["until"] = true,
	["while"] = true,
}

local function isIdentifier(value): boolean
	return typeof(value) == "string" and value:match("^[%a_][%w_]*$") ~= nil and not LUAU_KEYWORDS[value]
end

local function hexBytes(value: string): string
	local bytes = {}
	for index = 1, #value do
		table.insert(bytes, string.format("%02X", string.byte(value, index)))
	end
	return table.concat(bytes)
end

local function sortedTypeEntries(surface)
	local entriesById = {}
	for _, entry in surface.types or {} do
		if typeof(entry.id) == "string" and entry.id ~= "" then
			entriesById[entry.id] = entry
		end
	end
	local entries = {}
	for _, entry in entriesById do
		table.insert(entries, entry)
	end
	table.sort(entries, function(a, b)
		return a.id < b.id
	end)
	return entries
end

local function aliasNames(entries)
	local names = {}
	local used = {}
	for _, entry in entries do
		if isIdentifier(entry.id) then
			names[entry.id] = entry.id
			used[entry.id] = true
		end
	end
	for _, entry in entries do
		if not names[entry.id] then
			local candidate = "_FraguaType_" .. hexBytes(entry.id)
			while used[candidate] do
				candidate ..= "_"
			end
			names[entry.id] = candidate
			used[candidate] = true
		end
	end
	return names
end

local function safeBackingClass(value): string
	return if isIdentifier(value) then value else "Instance"
end

local function safeTypeName(value): string?
	if typeof(value) == "string" and BehaviorSignatures.isSafeType(value) then
		return value
	end
	return nil
end

local function memberName(value): string?
	if typeof(value) ~= "string" or value == "" then
		return nil
	end
	if isIdentifier(value) then
		return value
	end
	return "[" .. quote(value) .. "]"
end

local function propertyType(property, side: string, names): string
	local referenceType = property.referenceType
	local isReference = property.valueType == "Instance"
		or property.valueType == "FraguaInstance"
		or referenceType ~= nil
	if
		typeof(referenceType) == "string"
		and names[referenceType]
		and (property.valueType == "FraguaInstance" or property.typeName == referenceType)
	then
		return names[referenceType] .. side .. "?"
	end
	local typeName = safeTypeName(property.typeName) or "any"
	return if isReference then typeName .. "?" else typeName
end

local function validMethod(method): boolean
	if
		not isIdentifier(method.name)
		or WrapperPolicy.isReserved(method.name, {})
		or not safeTypeName(method.returns)
	then
		return false
	end
	for index, parameter in method.parameters or {} do
		if
			(not isIdentifier(parameter.name) and parameter.name ~= "...")
			or not safeTypeName(parameter.typeName)
			or (parameter.name == "..." and index ~= #(method.parameters or {}))
		then
			return false
		end
	end
	return true
end

local function methodField(method, alias: string): string?
	if not validMethod(method) then
		return nil
	end
	local parameters = { "self: " .. alias }
	for _, parameter in method.parameters or {} do
		if parameter.name == "..." then
			table.insert(parameters, "..." .. parameter.typeName)
		else
			table.insert(parameters, parameter.name .. ": " .. parameter.typeName)
		end
	end
	return string.format("\t%s: (%s) -> %s,", method.name, table.concat(parameters, ", "), method.returns)
end

local function methodsForSide(entry, side: string)
	if side == "Server" then
		return entry.serverMethods or {}
	elseif side == "Client" then
		return entry.clientMethods or {}
	end
	return {}
end

local function aliasSource(entry, side: string, names): string
	local alias = names[entry.id] .. side
	local methodNames = { Clone = true, TypeId = true }
	local methods = {}
	for _, method in methodsForSide(entry, side) do
		local field = methodField(method, alias)
		if field then
			methodNames[method.name] = true
			table.insert(methods, { name = method.name, field = field })
		end
	end
	table.sort(methods, function(a, b)
		return a.name < b.name
	end)

	local propertiesByName = {}
	for _, property in entry.properties or {} do
		local fieldName = memberName(property.name)
		if fieldName and not methodNames[property.name] then
			propertiesByName[property.name] = string.format("\t%s: %s,", fieldName, propertyType(property, side, names))
		end
	end
	local propertyNames = sortedKeys(propertiesByName)
	local lines = {
		string.format("export type %s = %s & {", alias, safeBackingClass(entry.backingClass)),
		string.format("\tTypeId: %s,", quote(entry.id)),
	}
	for _, name in propertyNames do
		table.insert(lines, propertiesByName[name])
	end
	table.insert(lines, string.format("\tClone: (self: %s) -> %s?,", alias, alias))
	for _, method in methods do
		table.insert(lines, method.field)
	end
	table.insert(lines, "}")
	return table.concat(lines, "\n")
end

local function sideAliases(entry, names): string
	local base = names[entry.id]
	return table.concat({ base .. "Server", base .. "Client", base .. "Core" }, " | ")
end

local function enumField(typeId: string): string
	local name = memberName(typeId)
	return string.format("\t%s: FraguaTypeItem<%s>,", name, quote(typeId))
end

local function facadeTypes(side: string, entries, names): string
	local lines = {
		string.format("type %sNew = typeof(RobloxInstance.new)", side),
	}
	for _, entry in entries do
		local alias = names[entry.id] .. side
		table.insert(lines, string.format("\t& ((className: %s, parent: Instance?) -> %s)", quote(entry.id), alias))
		table.insert(
			lines,
			string.format("\t& ((className: FraguaTypeItem<%s>, parent: Instance?) -> %s)", quote(entry.id), alias)
		)
	end
	if #entries == 0 then
		table.insert(lines, string.format("type %sFromExisting = typeof(RobloxInstance.fromExisting)", side))
		table.insert(lines, string.format("type %sGet = <T>(value: T & Instance) -> T", side))
	else
		for index, entry in entries do
			local targetAlias = names[entry.id] .. side
			local prefix = if index == 1 then string.format("type %sFromExisting = ", side) else "\t& "
			table.insert(
				lines,
				string.format("%s((existing: %s) -> %s?)", prefix, sideAliases(entry, names), targetAlias)
			)
		end
		table.insert(lines, "\t& typeof(RobloxInstance.fromExisting)")
		for index, entry in entries do
			local targetAlias = names[entry.id] .. side
			local prefix = if index == 1 then string.format("type %sGet = ", side) else "\t& "
			table.insert(lines, string.format("%s((value: %s) -> %s)", prefix, sideAliases(entry, names), targetAlias))
		end
		table.insert(lines, "\t& (<T>(value: T & Instance) -> T)")
	end
	table.insert(lines, string.format("type %sInstance = typeof(RobloxInstance) & {", side))
	table.insert(lines, string.format("\tnew: %sNew,", side))
	table.insert(lines, string.format("\tfromExisting: %sFromExisting,", side))
	table.insert(lines, "}")
	table.insert(lines, string.format("type %sFacade = {", side))
	table.insert(lines, string.format("\tInstance: %sInstance,", side))
	table.insert(lines, "\tEnum: FraguaEnum,")
	table.insert(lines, string.format("\tGet: %sGet,", side))
	table.insert(lines, "}")
	return table.concat(lines, "\n")
end

local function encodeTypeSurface(surface): string
	local entries = sortedTypeEntries(surface)
	local names = aliasNames(entries)
	local enums = {}
	for _, enum in surface.enums or {} do
		if typeof(enum.id) == "string" and isIdentifier(enum.id) then
			table.insert(enums, enum)
		end
	end
	table.sort(enums, function(a, b)
		return a.id < b.id
	end)
	local sections = {
		"export type FraguaTypeItem<Name> = {",
		"\tName: Name,",
		"\tValue: Name,",
		'\tEnumType: "FraguaType",',
		"}",
		"export type FraguaEnumItem<EnumName, ItemName> = {",
		"\tName: ItemName,",
		"\tValue: ItemName,",
		"\tEnumType: EnumName,",
		"}",
	}
	for _, entry in entries do
		for _, side in { "Server", "Client", "Core" } do
			table.insert(sections, aliasSource(entry, side, names))
		end
	end
	local enumLines = {
		"type FraguaTypeEnum = {",
		'\tName: "FraguaType",',
		"\tGetEnumItems: (self: FraguaTypeEnum) -> { FraguaTypeItem<string> },",
	}
	for _, entry in entries do
		table.insert(enumLines, enumField(entry.id))
	end
	table.insert(enumLines, "}")
	local enumFields = { "FraguaType: FraguaTypeEnum" }
	for _, enum in enums do
		local enumTypeName = enum.id .. "Enum"
		table.insert(enumLines, "")
		table.insert(enumLines, string.format("type %s = {", enumTypeName))
		table.insert(enumLines, string.format("\tName: %s,", quote(enum.id)))
		table.insert(
			enumLines,
			string.format("\tGetEnumItems: (self: %s) -> { FraguaEnumItem<%s, string> },", enumTypeName, quote(enum.id))
		)
		for _, item in enum.items or {} do
			local field = memberName(item)
			if field then
				table.insert(
					enumLines,
					string.format("\t%s: FraguaEnumItem<%s, %s>,", field, quote(enum.id), quote(item))
				)
			end
		end
		table.insert(enumLines, "}")
		table.insert(enumFields, string.format("%s: %s", enum.id, enumTypeName))
	end
	table.insert(enumLines, "type FraguaEnum = typeof(RobloxEnum) & { " .. table.concat(enumFields, ", ") .. " }")
	table.insert(sections, table.concat(enumLines, "\n"))
	for _, side in { "Server", "Client", "Core" } do
		table.insert(sections, facadeTypes(side, entries, names))
	end
	return table.concat(sections, "\n\n")
end

local SOURCE = [=[
-- Fragua runtime API. Managed; plugin overwrites this Source. Do not edit.
-- Script headers select Core, Server, or Client from this module.
-- AI / MCP guide: read ServerStorage.Fragua.README (require it for the same text).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RobloxInstance = Instance
local RobloxEnum = Enum
local RobloxType = type
local RobloxTypeof = typeof

@@TYPE_SURFACE@@

local TAG = "FraguaInstance"
local TYPE_ATTR = "_FraguaType"
local CATALOG_NAME = "FraguaTypes"
local ENUMS_CATALOG_NAME = "FraguaEnums"
local REFERENCE_PREFIX = "_FraguaRef_"
local NATIVE_CLASSES_NAME = "_FraguaNativeClasses"
local REFRESH_BINDABLE = "RefreshEditBehaviors"

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

local function enumCatalog()
	return ReplicatedStorage:FindFirstChild(ENUMS_CATALOG_NAME)
end

local function findDefinition(typeId: string)
	local root = catalog()
	local definition = root and root:FindFirstChild(typeId)
	if definition and definition:IsA("Configuration") then
		return definition
	end
	return nil
end

local function isKnownNativeClass(className: string): boolean
	local root = catalog()
	local nativeClasses = root and root:FindFirstChild(NATIVE_CLASSES_NAME)
	if nativeClasses then
		for _, entry in nativeClasses:GetChildren() do
			if entry:IsA("StringValue") and entry.Value == className then
				return true
			end
		end
	end
	return false
end

local CUSTOM_ITEM_METATABLE = {}
local customItems = {}
local customEnumItems = {}
local customEnumTypes = {}

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

local function enumItemNames(enumName: string): { string }
	local names = {}
	local root = enumCatalog()
	local entry = root and root:FindFirstChild(enumName)
	local folder = entry and entry:FindFirstChild("EnumItems")
	if folder then
		local children = folder:GetChildren()
		table.sort(children, function(a, b)
			return a.Name < b.Name
		end)
		for _, child in children do
			if child:IsA("StringValue") and child.Value ~= "" then
				table.insert(names, child.Value)
			end
		end
	end
	return names
end

local function customEnumItem(enumName: string, itemName: string)
	local key = enumName .. "." .. itemName
	local existing = customEnumItems[key]
	if existing then
		return existing
	end
	local item = {}
	setmetatable(item, {
		__index = function(_, field)
			if field == "Name" or field == "Value" then
				return itemName
			elseif field == "EnumType" then
				return enumName
			end
			return nil
		end,
		__newindex = function()
			error("Fragua enum items are immutable", 2)
		end,
		__tostring = function()
			return "Enum." .. enumName .. "." .. itemName
		end,
		__metatable = CUSTOM_ITEM_METATABLE,
	})
	customEnumItems[key] = item
	return item
end

local function customEnumType(enumName: string)
	local existing = customEnumTypes[enumName]
	if existing then
		return existing
	end
	local facade = {}
	setmetatable(facade, {
		__index = function(_, key)
			if key == "Name" then
				return enumName
			elseif key == "GetEnumItems" then
				return function()
					local items = {}
					for _, name in enumItemNames(enumName) do
						table.insert(items, customEnumItem(enumName, name))
					end
					return items
				end
			elseif RobloxTypeof(key) == "string" then
				for _, name in enumItemNames(enumName) do
					if name == key then
						return customEnumItem(enumName, name)
					end
				end
			end
			return nil
		end,
		__newindex = function()
			error("Fragua enum types are immutable", 2)
		end,
		__tostring = function()
			return "Enum." .. enumName
		end,
		__metatable = "FraguaEnumType",
	})
	customEnumTypes[enumName] = facade
	return facade
end

local function findCustomEnum(enumName: string)
	local root = enumCatalog()
	local entry = root and root:FindFirstChild(enumName)
	if entry and entry:IsA("Configuration") then
		return customEnumType(enumName)
	end
	return nil
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
				local root = enumCatalog()
				if root then
					for _, child in root:GetChildren() do
						if child:IsA("Configuration") then
							local robloxOk, robloxEnum = pcall(function()
								return RobloxEnum[child.Name]
							end)
							if not robloxOk or robloxEnum == nil then
								table.insert(enums, customEnumType(child.Name))
							end
						end
					end
				end
				return enums
			end
		end
		local robloxOk, robloxEnum = pcall(function()
			return RobloxEnum[key]
		end)
		if robloxOk and robloxEnum ~= nil then
			return robloxEnum
		end
		local custom = RobloxTypeof(key) == "string" and findCustomEnum(key)
		if custom then
			return custom
		end
		return nil
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
	local enumType = FraguaEnum[enumTypeName]
	if not enumType then
		return nil
	end
	local name
	if RobloxTypeof(value) == "EnumItem" then
		if value.EnumType ~= enumType then
			return nil
		end
		name = value.Name
	elseif RobloxTypeof(value) == "table" and value.EnumType == enumTypeName then
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
		local enumType = FraguaEnum[enumTypeName]
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

local function copyCustomValues(source, destination, definition, preserveDestinationReferences: boolean)
	eachCustomProperty(definition, source, function(property, name)
		if isReferenceProperty(property) then
			local referenceName = REFERENCE_PREFIX .. name
			local destinationReference = destination:FindFirstChild(referenceName)
			if not (preserveDestinationReferences and destinationReference and destinationReference:IsA("ObjectValue")) then
				local sourceReference = source:FindFirstChild(referenceName)
				local value = if sourceReference and sourceReference:IsA("ObjectValue")
					then sourceReference.Value
					else nil
				ensureReference(destination, name).Value = value
			end
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
					copyCustomValues(state.backing, clone, definition, true)
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
			local nativeOk, nativeProblem = pcall(function()
				return RobloxInstance.new(className)
			end)
			if nativeOk then
				nativeProblem.Parent = if parent == nil then nil else unwrap(parent)
				return nativeProblem
			end
			if isKnownNativeClass(className) then
				error(nativeProblem, 2)
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
			copyCustomValues(backing, duplicate, definition, false)
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

	function Facade.RefreshEditBehaviors(typeId: string?)
		local ServerStorage = game:GetService("ServerStorage")
		local root = ServerStorage:FindFirstChild("Fragua")
		local bindable = root and root:FindFirstChild(REFRESH_BINDABLE)
		if not bindable or not bindable:IsA("BindableFunction") then
			warn("[Fragua] RefreshEditBehaviors is only available while the plugin is loaded in edit mode")
			return
		end
		bindable:Invoke(typeId)
	end

	return Facade
end

local CoreRuntime = makeFacade("Core")
local ServerRuntime = makeFacade("Server")
local ClientRuntime = makeFacade("Client")
local Core = CoreRuntime :: typeof(CoreRuntime) & CoreFacade
local Server = ServerRuntime :: typeof(ServerRuntime) & ServerFacade
local Client = ClientRuntime :: typeof(ClientRuntime) & ClientFacade

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
Fragua.RefreshEditBehaviors = Core.RefreshEditBehaviors

return Fragua
]=]

function ApiSource.build(surface: any?): string
	local resolvedSurface = surface or { types = {} }
	local source = SOURCE:gsub("@@TYPE_SURFACE@@", function()
		return encodeTypeSurface(resolvedSurface)
	end)
	source = source:gsub("@@CORE_MEMBERS@@", function()
		return encodeSet(WrapperPolicy.coreMembers)
	end)
	source = source:gsub("@@LIFECYCLE_MEMBERS@@", function()
		return encodeSet(WrapperPolicy.lifecycleMembers)
	end)
	source = source:gsub("@@WRAPPER_MEMBERS@@", function()
		return encodeSet(WrapperPolicy.wrapperMembers)
	end)
	source = source:gsub("@@KNOWN_METHOD_SIDES@@", function()
		return encodeKnownMethods(resolvedSurface)
	end)
	return source
end

return ApiSource
