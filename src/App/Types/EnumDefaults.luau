local EnumDefaults = {}

local function ids(definitions)
	local result = {}
	for _, definition in definitions or {} do
		if typeof(definition.id) == "string" then
			table.insert(result, definition.id)
		end
	end
	table.sort(result)
	return result
end

function EnumDefaults.names(robloxNames, _definitions, customEnums)
	local result, seen = {}, {}
	for _, name in robloxNames or {} do
		if not seen[name] then
			seen[name] = true
			table.insert(result, name)
		end
	end
	if not seen.FraguaType then
		table.insert(result, "FraguaType")
		seen.FraguaType = true
	end
	for _, enum in customEnums or {} do
		if typeof(enum.id) == "string" and not seen[enum.id] then
			seen[enum.id] = true
			table.insert(result, enum.id)
		end
	end
	table.sort(result)
	return result
end

function EnumDefaults.items(enumTypeName, definitions, robloxItems, customEnums)
	if enumTypeName == "FraguaType" then
		return ids(definitions)
	end
	for _, enum in customEnums or {} do
		if enum.id == enumTypeName then
			local items = {}
			for _, item in enum.items or {} do
				table.insert(items, item)
			end
			return items
		end
	end
	return if robloxItems then robloxItems(enumTypeName) else {}
end

function EnumDefaults.facade(definitions, robloxEnum)
	local itemByName = {}
	local fraguaType = {}
	for _, name in ids(definitions) do
		itemByName[name] = setmetatable({}, { __index = { Name = name, Value = name, EnumType = "FraguaType" } })
	end
	setmetatable(fraguaType, { __index = itemByName })
	return setmetatable({ FraguaType = fraguaType }, { __index = robloxEnum })
end

function EnumDefaults.write(facade, enumTypeName, value, allowed)
	local enumType = facade[enumTypeName]
	if not enumType then
		return nil
	end
	local name = if typeof(value) == "string" then value else value and value.Name
	if typeof(name) ~= "string" or not enumType[name] then
		return nil
	end
	if allowed and not table.find(allowed, name) then
		return nil
	end
	return name
end

function EnumDefaults.read(facade, enumTypeName, stored)
	local enumType = facade[enumTypeName]
	return if enumType and typeof(stored) == "string" then enumType[stored] else nil
end

return EnumDefaults
