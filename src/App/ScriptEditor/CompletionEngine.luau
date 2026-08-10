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
	{ label = "onCreated", newText = "onCreated(instance)\n\t\nend", detail = "Behavior hook / instance" },
	{ label = "onSelected", newText = "onSelected(instance)\n\t\nend", detail = "Behavior hook / instance" },
	{
		label = "onPropertyChanged",
		newText = "onPropertyChanged(instance, key, value)\n\t\nend",
		detail = "Behavior hook / instance, key, value",
	},
	{
		label = "onAncestryChanged",
		newText = "onAncestryChanged(instance)\n\t\nend",
		detail = "Behavior hook / instance",
	},
	{ label = "onStart", newText = "onStart(instance)\n\t\nend", detail = "Behavior hook / instance" },
	{ label = "onStop", newText = "onStop(instance)\n\t\nend", detail = "Behavior hook / instance" },
}

local function startsWith(value: string, prefix: string): boolean
	return value:lower():sub(1, #prefix) == prefix:lower()
end

local function makeItem(label: string, prefix: string, cursor: number, detail: string?, newText: string?)
	return {
		label = label,
		newText = newText or label,
		startByte = cursor - #prefix,
		endByte = cursor,
		detail = detail or "",
	}
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
	local prefix = attributePrefix or typePrefix or hookPrefix or before:match("([%a_][%w_]*)$") or ""
	local items = {}

	if attributePrefix ~= nil then
		for _, property in request.schema or {} do
			if startsWith(property.name, prefix) then
				local inherited = if property.inherited then " / inherited" else ""
				local detail = `{property.valueType or "value"} / {property.category or "Data"}{inherited}`
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
		for _, keyword in KEYWORDS do
			if startsWith(keyword, prefix) and not seen[keyword] then
				local item = makeItem(keyword, prefix, cursor, "Luau keyword")
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
