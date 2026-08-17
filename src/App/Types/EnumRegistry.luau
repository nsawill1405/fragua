local Constants = if script then require(script.Parent.Parent.Shared.Constants) else require("../Shared/Constants")

--Types
export type EnumDef = {
	id: string,
	name: string,
	items: { string },
}

--Constants
local EnumRegistry = {}

local IDENTIFIER = "^[%a_][%w_]*$"
local RESERVED = {
	FraguaType = true,
	GetEnums = true,
}

local changedBindable: BindableEvent? = nil
local okBindable, bindable = pcall(function()
	return Instance.new("BindableEvent")
end)
if okBindable and bindable then
	changedBindable = bindable
	EnumRegistry.Changed = bindable.Event
else
	local listeners: { () -> () } = {}
	EnumRegistry.Changed = {
		Connect = function(_self, fn: () -> ())
			table.insert(listeners, fn)
			return {
				Disconnect = function()
					local index = table.find(listeners, fn)
					if index then
						table.remove(listeners, index)
					end
				end,
			}
		end,
	}
	changedBindable = nil
	EnumRegistry._listeners = listeners
end

--Functions
local function fireChanged()
	if changedBindable then
		changedBindable:Fire()
		return
	end
	for _, listener in EnumRegistry._listeners or {} do
		listener()
	end
end

local function jsonString(value: string): string
	return '"' .. (value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")) .. '"'
end

function EnumRegistry.isReservedName(name: string, robloxNames: { string }?): boolean
	if RESERVED[name] then
		return true
	end
	if robloxNames and table.find(robloxNames, name) then
		return true
	end
	return false
end

function EnumRegistry.validate(def: EnumDef, reservedNames: { string }?): (boolean, string?)
	if typeof(def.id) ~= "string" or def.id:match(IDENTIFIER) == nil then
		return false, "Use a valid identifier name."
	end
	if EnumRegistry.isReservedName(def.id, reservedNames) then
		return false, `"{def.id}" collides with a reserved or Roblox enum name.`
	end
	if typeof(def.items) ~= "table" or #def.items == 0 then
		return false, "Add at least one enum item."
	end
	local seen = {}
	for _, item in def.items do
		if typeof(item) ~= "string" or item:match(IDENTIFIER) == nil then
			return false, `"{tostring(item)}" is not a valid enum item name.`
		end
		if seen[item] then
			return false, `Duplicate enum item "{item}".`
		end
		seen[item] = true
	end
	return true
end

function EnumRegistry.encode(def: EnumDef): string
	local items = {}
	for _, item in def.items do
		table.insert(items, jsonString(item))
	end
	return string.format(
		'{"id":%s,"name":%s,"items":[%s]}',
		jsonString(def.id),
		jsonString(def.name or def.id),
		table.concat(items, ",")
	)
end

function EnumRegistry.decode(raw: string): EnumDef?
	if typeof(raw) ~= "string" then
		return nil
	end
	local source = raw
	local startPos = string.find(source, "[[", 1, true)
	local endPos = startPos and string.find(source, "]]", startPos + 2, true)
	if startPos and endPos then
		source = string.sub(source, startPos + 2, endPos - 1)
	end
	local id = source:match('"id"%s*:%s*"([^"]*)"')
	if typeof(id) ~= "string" or id == "" then
		return nil
	end
	local name = source:match('"name"%s*:%s*"([^"]*)"') or id
	local itemsBlock = source:match('"items"%s*:%s*%[(.-)%]')
	local items = {}
	if itemsBlock then
		for item in itemsBlock:gmatch('"([^"]*)"') do
			table.insert(items, item)
		end
	end
	return {
		id = id,
		name = name,
		items = items,
	}
end

function EnumRegistry.moduleSource(def: EnumDef): string
	return `-- Fragua enum definition: {def.id}\nreturn [[\n{EnumRegistry.encode(def)}\n]]\n`
end

function EnumRegistry.typesUsing(definitions: { any }, enumId: string): { string }
	local using = {}
	for _, definition in definitions or {} do
		if typeof(definition.id) == "string" then
			for _, property in definition.properties or {} do
				if property.valueType == "enum" and property.enumType == enumId then
					table.insert(using, definition.id)
					break
				end
			end
		end
	end
	table.sort(using)
	return using
end

function EnumRegistry.ensureFolder(): Folder
	local ServerStorage = game:GetService("ServerStorage")
	local root = ServerStorage:FindFirstChild(Constants.ROOT_FOLDER)
	if not root then
		root = Instance.new("Folder")
		root.Name = Constants.ROOT_FOLDER
		root.Parent = ServerStorage
	end
	local enums = root:FindFirstChild(Constants.ENUMS_FOLDER)
	if not enums then
		enums = Instance.new("Folder")
		enums.Name = Constants.ENUMS_FOLDER
		enums.Parent = root
	end
	return enums :: Folder
end

local function decodeContainer(container: Instance): EnumDef?
	if container:IsA("ModuleScript") then
		return EnumRegistry.decode((container :: ModuleScript).Source)
	end
	if container:IsA("StringValue") then
		return EnumRegistry.decode((container :: StringValue).Value)
	end
	return nil
end

function EnumRegistry.list(): { EnumDef }
	local folder = EnumRegistry.ensureFolder()
	local enums: { EnumDef } = {}
	for _, child in folder:GetChildren() do
		local def = decodeContainer(child)
		if def and def.id == child.Name then
			table.insert(enums, def)
		end
	end
	table.sort(enums, function(a, b)
		return a.id < b.id
	end)
	return enums
end

function EnumRegistry.get(id: string): EnumDef?
	local folder = EnumRegistry.ensureFolder()
	local existing = folder:FindFirstChild(id)
	if not existing then
		return nil
	end
	local def = decodeContainer(existing)
	if def and def.id == id then
		return def
	end
	return nil
end

function EnumRegistry.save(def: EnumDef)
	local reserved: { string }? = nil
	pcall(function()
		local names = {}
		for _, enumType in Enum:GetEnums() do
			table.insert(names, enumType.Name)
		end
		reserved = names
	end)
	local ok, message = EnumRegistry.validate(def, reserved)
	assert(ok, message or "Invalid enum definition")
	local folder = EnumRegistry.ensureFolder()
	local source = EnumRegistry.moduleSource(def)
	local existing = folder:FindFirstChild(def.id)
	if existing and existing:IsA("ModuleScript") then
		existing.Source = source
	else
		if existing then
			existing:Destroy()
		end
		local module = Instance.new("ModuleScript")
		module.Name = def.id
		module.Source = source
		module.Parent = folder
	end
	fireChanged()
end

function EnumRegistry.delete(id: string, definitions: { any }?): (boolean, string?)
	local using = EnumRegistry.typesUsing(definitions or {}, id)
	if #using > 0 then
		return false, `Enum "{id}" is used by {table.concat(using, ", ")}.`
	end
	local folder = EnumRegistry.ensureFolder()
	local existing = folder:FindFirstChild(id)
	if not existing then
		return false, `Enum "{id}" was not found.`
	end
	existing:Destroy()
	fireChanged()
	return true
end

return EnumRegistry
