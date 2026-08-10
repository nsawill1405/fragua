local SyntaxHighlighter = {}

local COLORS = {
	keyword = "#C586C0",
	string = "#CE9178",
	number = "#B5CEA8",
	comment = "#6A9955",
	type = "#4EC9B0",
	property = "#9CDCFE",
	global = "#DCDCAA",
}

local KEYWORDS = {
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

local GLOBALS = {
	game = true,
	workspace = true,
	script = true,
	plugin = true,
	task = true,
	math = true,
	string = true,
	table = true,
	Instance = true,
	Color3 = true,
	Vector3 = true,
	CFrame = true,
	Enum = true,
	Fragua = true,
}

local function escape(text: string): string
	local escaped = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
	return escaped
end

local function colored(text: string, kind: string?): string
	local safe = escape(text)
	if not kind then
		return safe
	end
	return `<font color="{COLORS[kind]}">{safe}</font>`
end

function SyntaxHighlighter.render(source: string, context): string
	local types = {}
	for _, typeId in context.typeIds or {} do
		types[typeId] = true
	end
	local properties = {}
	for _, property in context.schema or {} do
		properties[property.name] = true
	end

	local output = {}
	local index = 1
	while index <= #source do
		local char = source:sub(index, index)
		local nextChar = source:sub(index + 1, index + 1)
		if char == "-" and nextChar == "-" then
			local finish = source:find("\n", index, true) or (#source + 1)
			table.insert(output, colored(source:sub(index, finish - 1), "comment"))
			index = finish
		elseif char == '"' or char == "'" then
			local quote = char
			local finish = index + 1
			local escaped = false
			while finish <= #source do
				local current = source:sub(finish, finish)
				if escaped then
					escaped = false
				elseif current == "\\" then
					escaped = true
				elseif current == quote then
					finish += 1
					break
				end
				finish += 1
			end
			local token = source:sub(index, finish - 1)
			local value = token:sub(2, if token:sub(-1) == quote then -2 else -1)
			local kind = if types[value] then "type" elseif properties[value] then "property" else "string"
			table.insert(output, colored(token, kind))
			index = finish
		elseif char:match("%d") then
			local finish = index + 1
			while finish <= #source and source:sub(finish, finish):match("[%w%.]") do
				finish += 1
			end
			table.insert(output, colored(source:sub(index, finish - 1), "number"))
			index = finish
		elseif char:match("[%a_]") then
			local finish = index + 1
			while finish <= #source and source:sub(finish, finish):match("[%w_]") do
				finish += 1
			end
			local token = source:sub(index, finish - 1)
			local kind = if KEYWORDS[token] then "keyword" elseif GLOBALS[token] then "global" else nil
			table.insert(output, colored(token, kind))
			index = finish
		else
			table.insert(output, escape(char))
			index += 1
		end
	end
	return table.concat(output)
end

return SyntaxHighlighter
