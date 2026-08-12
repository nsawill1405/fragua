local WrapperPolicy = if script then require(script.Parent.WrapperPolicy) else require("./WrapperPolicy")
local EngineSchemas = if script
	then require(script.Parent.Parent.Types.EngineSchemas)
	else require("../Types/EngineSchemas")

local BehaviorSignatures = {}

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

local PORTABLE_TYPES = {
	any = true,
	boolean = true,
	buffer = true,
	["nil"] = true,
	number = true,
	string = true,
	thread = true,
	unknown = true,
	never = true,
	["true"] = true,
	["false"] = true,
	Axes = true,
	BrickColor = true,
	CFrame = true,
	Color3 = true,
	ColorSequence = true,
	ColorSequenceKeypoint = true,
	Content = true,
	DateTime = true,
	DockWidgetPluginGuiInfo = true,
	Enum = true,
	EnumItem = true,
	EnumType = true,
	Faces = true,
	FloatCurveKey = true,
	Font = true,
	FraguaTypeItem = true,
	Instance = true,
	NumberRange = true,
	NumberSequence = true,
	NumberSequenceKeypoint = true,
	OverlapParams = true,
	PathWaypoint = true,
	PhysicalProperties = true,
	Player = true,
	Random = true,
	Ray = true,
	RaycastParams = true,
	RaycastResult = true,
	RBXScriptConnection = true,
	RBXScriptSignal = true,
	Rect = true,
	Region3 = true,
	Region3int16 = true,
	RotationCurveKey = true,
	SharedTable = true,
	TweenInfo = true,
	UDim = true,
	UDim2 = true,
	Vector2 = true,
	Vector2int16 = true,
	Vector3 = true,
	Vector3int16 = true,
}
for _, className in EngineSchemas.classNames() do
	PORTABLE_TYPES[className] = true
end
for _, className in EngineSchemas.insertable() do
	PORTABLE_TYPES[className] = true
end

local function trim(value: string): string
	return value:match("^%s*(.-)%s*$") :: string
end

local function isIdentifier(value: string): boolean
	return value:match("^[%a_][%w_]*$") ~= nil and not LUAU_KEYWORDS[value]
end

local function isAllowedTypeCharacter(character: string): boolean
	return character:match("[%w%s_]") ~= nil or string.find(".?,:(){}[]<>|&-'\"\\", character, 1, true) ~= nil
end

local function hasBalancedTypeDelimiters(annotation: string): boolean
	local expected = {}
	local quote = nil
	local escaped = false
	local pairsByOpen = { ["("] = ")", ["{"] = "}", ["["] = "]", ["<"] = ">" }
	for index = 1, #annotation do
		local character = annotation:sub(index, index)
		if quote then
			if escaped then
				escaped = false
			elseif character == "\\" then
				escaped = true
			elseif character == quote then
				quote = nil
			end
		elseif character == '"' or character == "'" then
			quote = character
		elseif pairsByOpen[character] then
			table.insert(expected, pairsByOpen[character])
		elseif character == ")" or character == "}" or character == "]" or character == ">" then
			if character == ">" and annotation:sub(index - 1, index - 1) == "-" then
				continue
			end
			if expected[#expected] ~= character then
				return false
			end
			table.remove(expected)
		end
	end
	return quote == nil and #expected == 0
end

local function hasAdjacentWords(annotation: string): boolean
	local previousWasWord = false
	local whitespaceAfterWord = false
	local quote = nil
	local escaped = false
	for index = 1, #annotation do
		local character = annotation:sub(index, index)
		if quote then
			previousWasWord = false
			whitespaceAfterWord = false
			if escaped then
				escaped = false
			elseif character == "\\" then
				escaped = true
			elseif character == quote then
				quote = nil
			end
		elseif character == '"' or character == "'" then
			quote = character
			previousWasWord = false
			whitespaceAfterWord = false
		elseif character:match("[%w_]") then
			if whitespaceAfterWord then
				return true
			end
			previousWasWord = true
		elseif character:match("%s") then
			whitespaceAfterWord = previousWasWord
		else
			previousWasWord = false
			whitespaceAfterWord = false
		end
	end
	return false
end

local function usesOnlyPortableTypes(annotation: string): boolean
	local quote = nil
	local escaped = false
	local index = 1
	while index <= #annotation do
		local character = annotation:sub(index, index)
		if quote then
			if escaped then
				escaped = false
			elseif character == "\\" then
				escaped = true
			elseif character == quote then
				quote = nil
			end
			index += 1
		elseif character == '"' or character == "'" then
			quote = character
			index += 1
		elseif character:match("[%a_]") then
			local endAt = index + 1
			while endAt <= #annotation and annotation:sub(endAt, endAt):match("[%w_]") do
				endAt += 1
			end
			local name = annotation:sub(index, endAt - 1)
			local before = annotation:sub(1, index - 1):match("(%S)%s*$")
			local after = annotation:sub(endAt):match("^%s*(.)")
			local isLabel = after == ":" and (before == "{" or before == "(" or before == ",")
			local isEnumMember = before == "." and annotation:sub(1, index - 1):match("Enum%s*%.%s*$") ~= nil
			if not PORTABLE_TYPES[name] and not isLabel and not isEnumMember then
				return false
			end
			if after == "." and name ~= "Enum" then
				return false
			end
			index = endAt
		else
			index += 1
		end
	end
	return quote == nil
end

local function isSafeType(annotation: string): boolean
	if annotation == "" or #annotation > 512 then
		return false
	end
	if annotation:find("--", 1, true) or annotation:find("//", 1, true) or annotation:find("/*", 1, true) then
		return false
	end
	local normalized = trim(annotation)
	if
		normalized:match("^[|&>,:)]")
		or normalized:match("[|&<,:%.%+%*/%-]$")
		or normalized:sub(-2) == "->"
		or hasAdjacentWords(normalized)
		or not usesOnlyPortableTypes(normalized)
	then
		return false
	end
	for index = 1, #annotation do
		if not isAllowedTypeCharacter(annotation:sub(index, index)) then
			return false
		end
	end
	local roundDepth = 0
	local braceDepth = 0
	local bracketDepth = 0
	local quote = nil
	local escaped = false
	for index = 1, #normalized do
		local character = normalized:sub(index, index)
		if quote then
			if escaped then
				escaped = false
			elseif character == "\\" then
				escaped = true
			elseif character == quote then
				quote = nil
			end
		elseif character == '"' or character == "'" then
			quote = character
		elseif character == "(" then
			roundDepth += 1
		elseif character == ")" then
			roundDepth -= 1
		elseif character == "{" then
			braceDepth += 1
		elseif character == "}" then
			braceDepth -= 1
		elseif character == "[" then
			bracketDepth += 1
		elseif character == "]" then
			bracketDepth -= 1
		elseif character == ":" and roundDepth == 0 and braceDepth == 0 and bracketDepth == 0 then
			return false
		elseif character == "-" and normalized:sub(index + 1, index + 1) ~= ">" then
			return false
		end
	end
	return hasBalancedTypeDelimiters(annotation)
end

local function scanTopLevel(value: string, delimiter: string): { string }
	local parts = {}
	local startAt = 1
	local roundDepth = 0
	local braceDepth = 0
	local bracketDepth = 0
	local angleDepth = 0
	local quote = nil
	local escaped = false
	for index = 1, #value do
		local character = value:sub(index, index)
		if quote then
			if escaped then
				escaped = false
			elseif character == "\\" then
				escaped = true
			elseif character == quote then
				quote = nil
			end
		elseif character == '"' or character == "'" then
			quote = character
		elseif character == "(" then
			roundDepth += 1
		elseif character == ")" then
			roundDepth -= 1
		elseif character == "{" then
			braceDepth += 1
		elseif character == "}" then
			braceDepth -= 1
		elseif character == "[" then
			bracketDepth += 1
		elseif character == "]" then
			bracketDepth -= 1
		elseif character == "<" then
			angleDepth += 1
		elseif character == ">" and value:sub(index - 1, index - 1) ~= "-" and angleDepth > 0 then
			angleDepth -= 1
		elseif
			character == delimiter
			and roundDepth == 0
			and braceDepth == 0
			and bracketDepth == 0
			and angleDepth == 0
		then
			table.insert(parts, value:sub(startAt, index - 1))
			startAt = index + 1
		end
	end
	table.insert(parts, value:sub(startAt))
	return parts
end

local function splitParameter(parameter: string): (string?, string?)
	local pieces = scanTopLevel(parameter, ":")
	if #pieces ~= 2 then
		return nil, nil
	end
	local name = trim(pieces[1])
	local typeName = trim(pieces[2])
	if (name ~= "..." and not isIdentifier(name)) or not isSafeType(typeName) then
		return nil, nil
	end
	return name, typeName
end

local function closingParenthesis(line: string, openAt: number): number?
	local depth = 0
	local quote = nil
	local escaped = false
	for index = openAt, #line do
		local character = line:sub(index, index)
		if quote then
			if escaped then
				escaped = false
			elseif character == "\\" then
				escaped = true
			elseif character == quote then
				quote = nil
			end
		elseif character == '"' or character == "'" then
			quote = character
		elseif character == "(" then
			depth += 1
		elseif character == ")" then
			depth -= 1
			if depth == 0 then
				return index
			end
		end
	end
	return nil
end

local function parseLine(line: string)
	local name, openAt = line:match("^%s*function%s+Behavior%.([%a_][%w_]*)%s*()%(")
	if not name or not openAt or not isIdentifier(name) or WrapperPolicy.isReserved(name, {}) then
		return nil
	end
	local closeAt = closingParenthesis(line, openAt)
	if not closeAt then
		return nil
	end
	local tail = trim(line:sub(closeAt + 1))
	local returnType = tail:match("^:%s*(.-)%s+end%s*$") or tail:match("^:%s*(.-)%s*$")
	returnType = if returnType then trim(returnType) else nil
	if not returnType or not isSafeType(returnType) then
		return nil
	end

	local rawParameters = scanTopLevel(line:sub(openAt + 1, closeAt - 1), ",")
	local parsedParameters = {}
	for _, rawParameter in rawParameters do
		if trim(rawParameter) == "" then
			continue
		end
		local parameterName, parameterType = splitParameter(rawParameter)
		if not parameterName or not parameterType then
			return nil
		end
		table.insert(parsedParameters, { name = parameterName, typeName = parameterType })
	end
	if #parsedParameters == 0 or parsedParameters[1].typeName ~= "Instance" or parsedParameters[1].name == "..." then
		return nil
	end
	table.remove(parsedParameters, 1)
	return {
		name = name,
		parameters = parsedParameters,
		returns = returnType,
	}
end

function BehaviorSignatures.parse(source: string)
	local methods = {}
	for line in (source .. "\n"):gmatch("(.-)\r?\n") do
		local method = parseLine(line)
		if method then
			table.insert(methods, method)
		end
	end
	return methods
end

BehaviorSignatures.isSafeType = isSafeType
BehaviorSignatures.isIdentifier = isIdentifier

return BehaviorSignatures
