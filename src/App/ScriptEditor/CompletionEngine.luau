local CompletionEngine = {}

local KEYWORDS = {
	"and",
	"break",
	"continue",
	"do",
	"else",
	"elseif",
	"end",
	"false",
	"for",
	"function",
	"if",
	"in",
	"local",
	"nil",
	"not",
	"or",
	"repeat",
	"return",
	"then",
	"true",
	"until",
	"while",
}

local HOOKS = {
	{ label = "onCreated", newText = "onCreated(instance)\n\t$0\nend", detail = "Behavior hook / instance" },
	{ label = "onSelected", newText = "onSelected(instance)\n\t$0\nend", detail = "Behavior hook / instance" },
	{
		label = "onPropertyChanged",
		newText = "onPropertyChanged(instance, key, value)\n\t$0\nend",
		detail = "Behavior hook / instance, key, value",
	},
	{
		label = "onAncestryChanged",
		newText = "onAncestryChanged(instance)\n\t$0\nend",
		detail = "Behavior hook / instance",
	},
	{ label = "onStart", newText = "onStart(instance)\n\t$0\nend", detail = "Behavior hook / instance" },
	{ label = "onStop", newText = "onStop(instance)\n\t$0\nend", detail = "Behavior hook / instance" },
}

local COMMON_MEMBERS = {
	game = {
		{ label = "GetService", newText = 'GetService("$0")', detail = "Roblox DataModel method" },
	},
	workspace = {
		{ label = "FindFirstChild", newText = 'FindFirstChild("")', detail = "Instance method" },
		{ label = "WaitForChild", newText = 'WaitForChild("")', detail = "Instance method" },
		{ label = "GetChildren", newText = "GetChildren()", detail = "Instance method" },
		{ label = "GetDescendants", newText = "GetDescendants()", detail = "Instance method" },
	},
	instance = {
		{ label = "GetAttribute", newText = 'GetAttribute("")', detail = "Read an attribute" },
		{ label = "SetAttribute", newText = 'SetAttribute("", nil)', detail = "Write an attribute" },
		{ label = "FindFirstChild", newText = 'FindFirstChild("")', detail = "Instance method" },
		{ label = "WaitForChild", newText = 'WaitForChild("")', detail = "Instance method" },
		{ label = "IsA", newText = 'IsA("")', detail = "Instance type check" },
		{ label = "Clone", newText = "Clone()", detail = "Instance method" },
	},
	self = {
		{ label = "GetAttribute", newText = 'GetAttribute("")', detail = "Read an attribute" },
		{ label = "SetAttribute", newText = 'SetAttribute("", nil)', detail = "Write an attribute" },
	},
	Instance = {
		{ label = "new", newText = 'new("")', detail = "Create Roblox instance" },
	},
	math = {
		{ label = "clamp", newText = "clamp(value, min, max)", detail = "Math library" },
		{ label = "abs", newText = "abs(value)", detail = "Math library" },
		{ label = "floor", newText = "floor(value)", detail = "Math library" },
		{ label = "ceil", newText = "ceil(value)", detail = "Math library" },
		{ label = "max", newText = "max(a, b)", detail = "Math library" },
		{ label = "min", newText = "min(a, b)", detail = "Math library" },
	},
	string = {
		{ label = "format", newText = 'format("", value)', detail = "String library" },
		{ label = "find", newText = 'find(source, "")', detail = "String library" },
		{ label = "match", newText = 'match(source, "")', detail = "String library" },
		{ label = "gsub", newText = 'gsub(source, "", "")', detail = "String library" },
	},
	table = {
		{ label = "insert", newText = "insert(list, value)", detail = "Table library" },
		{ label = "remove", newText = "remove(list, index)", detail = "Table library" },
		{ label = "find", newText = "find(list, value)", detail = "Table library" },
		{ label = "sort", newText = "sort(list)", detail = "Table library" },
		{ label = "clone", newText = "clone(value)", detail = "Table library" },
	},
	task = {
		{ label = "wait", newText = "wait()", detail = "Task scheduler" },
		{ label = "spawn", newText = "spawn(function()\n\t\nend)", detail = "Task scheduler" },
		{ label = "defer", newText = "defer(function()\n\t\nend)", detail = "Task scheduler" },
		{ label = "delay", newText = "delay(seconds, function()\n\t\nend)", detail = "Task scheduler" },
	},
	Fragua = {
		{ label = "create", newText = 'create("")', detail = "Create custom type" },
	},
}

local GLOBALS = {
	"game",
	"workspace",
	"script",
	"plugin",
	"task",
	"math",
	"string",
	"table",
	"Instance",
	"Color3",
	"Vector3",
	"CFrame",
	"Enum",
	"Fragua",
}

local function startsWith(value: string, prefix: string): boolean
	return value:lower():sub(1, #prefix) == prefix:lower()
end

local function makeItem(label: string, prefix: string, cursor: number, detail: string?, newText: string?)
	local insertion = newText or label
	local marker = insertion:find("$0", 1, true)
	if marker then
		insertion = insertion:sub(1, marker - 1) .. insertion:sub(marker + 2)
	end
	local item = {
		label = label,
		newText = insertion,
		startByte = cursor - #prefix,
		endByte = cursor,
		detail = detail or "",
	}
	if marker then
		item.caretOffset = marker - 1 - #insertion
	end
	return item
end

local function sorted(items)
	table.sort(items, function(a, b)
		local aExact = a.label:lower() == a.prefixLower
		local bExact = b.label:lower() == b.prefixLower
		if aExact ~= bExact then
			return aExact
		end
		return a.label:lower() < b.label:lower()
	end)
	for _, item in items do
		item.prefixLower = nil
	end
	return items
end

function CompletionEngine.complete(request)
	local cursor = math.clamp(request.cursor or (#request.source + 1), 1, #request.source + 1)
	local before = request.source:sub(1, cursor - 1)
	local attributePrefix = before:match("[GS]etAttribute%s*%(%s*[%\"']([^%\"']*)$")
	local typePrefix = before:match("Fragua%.create%s*%(%s*[%\"']([^%\"']*)$")
	local hookPrefix = before:match("Behavior%.([%a_][%w_]*)$")
	local memberOwner, memberPrefix = before:match("([%a_][%w_]*)[:%.]([%a_][%w_]*)$")
	local prefix = attributePrefix or typePrefix or hookPrefix or memberPrefix or before:match("([%a_][%w_]*)$") or ""
	local items = {}
	if prefix == "" and attributePrefix == nil and typePrefix == nil then
		return items
	end

	if attributePrefix ~= nil then
		for _, property in request.schema or {} do
			if startsWith(property.name, prefix) then
				local inherited = if property.inherited then " / inherited" else ""
				local origin = if property.origin then ` / {property.origin}` else ""
				local detail = `{property.valueType or "value"} / {property.category or "Data"}{origin}{inherited}`
				local item = makeItem(property.name, prefix, cursor, detail)
				item.documentation = `Default: {tostring(property.default)}`
				item.prefixLower = prefix:lower()
				table.insert(items, item)
			end
		end
	elseif typePrefix ~= nil then
		for _, typeId in request.typeIds or {} do
			if startsWith(typeId, prefix) then
				local item = makeItem(typeId, prefix, cursor, "Fragua custom type")
				item.prefixLower = prefix:lower()
				table.insert(items, item)
			end
		end
	elseif hookPrefix ~= nil then
		for _, hook in HOOKS do
			if startsWith(hook.label, prefix) then
				local item = makeItem(hook.label, prefix, cursor, hook.detail, hook.newText)
				item.prefixLower = prefix:lower()
				table.insert(items, item)
			end
		end
	elseif memberOwner then
		for _, member in COMMON_MEMBERS[memberOwner] or {} do
			if startsWith(member.label, prefix) then
				local item = makeItem(member.label, prefix, cursor, member.detail, member.newText)
				item.prefixLower = prefix:lower()
				table.insert(items, item)
			end
		end
		if memberOwner == "instance" or memberOwner == "self" then
			for _, property in request.schema or {} do
				if startsWith(property.name, prefix) then
					local inherited = if property.inherited then " / inherited" else ""
					local origin = if property.origin then ` / {property.origin}` else ""
					local item = makeItem(
						property.name,
						prefix,
						cursor,
						`{property.valueType or "value"} / custom property{origin}{inherited}`,
						`GetAttribute("{property.name}")`
					)
					item.prefixLower = prefix:lower()
					table.insert(items, item)
				end
			end
		end
	else
		local seen = {}
		for localName in request.source:gmatch("local%s+([%a_][%w_]*)") do
			if startsWith(localName, prefix) and not seen[localName] then
				seen[localName] = true
				local item = makeItem(localName, prefix, cursor, "Local symbol")
				item.prefixLower = prefix:lower()
				table.insert(items, item)
			end
		end
		for parameters in before:gmatch("function%s+[%w_%.:]+%s*%(([^)]*)%)") do
			for parameter in parameters:gmatch("([%a_][%w_]*)") do
				if startsWith(parameter, prefix) and not seen[parameter] then
					seen[parameter] = true
					local item = makeItem(parameter, prefix, cursor, "Function parameter")
					item.prefixLower = prefix:lower()
					table.insert(items, item)
				end
			end
		end
		for _, keyword in KEYWORDS do
			if startsWith(keyword, prefix) and not seen[keyword] then
				local item = makeItem(keyword, prefix, cursor, "Luau keyword")
				item.prefixLower = prefix:lower()
				table.insert(items, item)
			end
		end
		for _, globalName in GLOBALS do
			if startsWith(globalName, prefix) and not seen[globalName] then
				seen[globalName] = true
				local item = makeItem(globalName, prefix, cursor, "Roblox global")
				item.prefixLower = prefix:lower()
				table.insert(items, item)
			end
		end
	end

	sorted(items)
	while #items > 50 do
		table.remove(items)
	end
	return items
end

return CompletionEngine
