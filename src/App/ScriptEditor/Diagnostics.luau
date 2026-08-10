local Diagnostics = {}

local HOOK_ARITY = {
	onCreated = 1,
	onSelected = 1,
	onPropertyChanged = 3,
	onAncestryChanged = 1,
	onStart = 1,
	onStop = 1,
}

local function maskStringsAndComments(source: string): (string, boolean)
	local out = table.create(#source)
	local quote = nil
	local escaped = false
	local comment = false
	for index = 1, #source do
		local char = source:sub(index, index)
		local nextChar = source:sub(index + 1, index + 1)
		if comment then
			out[index] = if char == "\n" then "\n" else " "
			if char == "\n" then
				comment = false
			end
		elseif quote then
			out[index] = if char == "\n" then "\n" else " "
			if escaped then
				escaped = false
			elseif char == "\\" then
				escaped = true
			elseif char == quote then
				quote = nil
			end
		elseif char == "-" and nextChar == "-" then
			comment = true
			out[index] = " "
		elseif char == '"' or char == "'" then
			quote = char
			out[index] = " "
		else
			out[index] = char
		end
	end
	return table.concat(out), quote ~= nil
end

local function parameterCount(parameters: string): number
	local trimmed = parameters:match("^%s*(.-)%s*$")
	if trimmed == "" then
		return 0
	end
	local count = 1
	for _ in trimmed:gmatch(",") do
		count += 1
	end
	return count
end

local function literalType(text: string): string?
	local trimmed = text:match("^%s*(.-)%s*$") or text
	if trimmed:match('^".*"$') or trimmed:match("^'.*'$") then
		return "string"
	elseif tonumber(trimmed) ~= nil then
		return "number"
	elseif trimmed == "true" or trimmed == "false" then
		return "boolean"
	elseif trimmed:match("^Color3%.[%w_]+%s*%(") or trimmed:match("^Color3%s*%(") then
		return "Color3"
	elseif trimmed:match("^Vector3%.[%w_]+%s*%(") or trimmed:match("^Vector3%s*%(") then
		return "Vector3"
	end
	return nil
end

function Diagnostics.analyze(source: string, context)
	local issues = {}
	local schemaNames = {}
	local schemaTypes = {}
	local searchFrom = 1
	for _, property in context.schema or {} do
		schemaNames[property.name] = true
		schemaTypes[property.name] = property.valueType
	end

	local knownTypes = {}
	for _, typeId in context.typeIds or {} do
		knownTypes[typeId] = true
	end
	while true do
		local startByte, endByte, typeId = source:find("Fragua%.create%s*%(%s*[%\"']([^%\"']+)[%\"']", searchFrom)
		if not startByte then
			break
		end
		if not knownTypes[typeId] then
			table.insert(issues, {
				severity = "error",
				code = "unknown-type",
				message = `Unknown Fragua type "{typeId}".`,
				startByte = startByte,
				endByte = endByte + 1,
			})
		end
		searchFrom = endByte + 1
	end

	searchFrom = 1
	while true do
		local startByte, endByte, propertyName, literal =
			source:find("SetAttribute%s*%(%s*[%\"']([^%\"']+)[%\"']%s*,%s*([^%)]+)%)", searchFrom)
		if not startByte then
			break
		end
		local actual = literalType(literal)
		local expected = schemaTypes[propertyName]
		if actual and expected and actual ~= expected then
			table.insert(issues, {
				severity = "error",
				code = "attribute-type-mismatch",
				message = `"{propertyName}" expects {expected}, got {actual}.`,
				startByte = startByte,
				endByte = endByte + 1,
			})
		end
		searchFrom = endByte + 1
	end

	local localDeclarations = {}
	searchFrom = 1
	while true do
		local startByte, endByte, localName = source:find("local%s+([%a_][%w_]*)", searchFrom)
		if not startByte then
			break
		end
		if localDeclarations[localName] then
			table.insert(issues, {
				severity = "warning",
				code = "duplicate-local",
				message = `Local "{localName}" is declared more than once.`,
				startByte = startByte,
				endByte = endByte + 1,
			})
		else
			localDeclarations[localName] = true
		end
		searchFrom = endByte + 1
	end

	if next(schemaNames) ~= nil then
		searchFrom = 1
		while true do
			local startByte, endByte, propertyName =
				source:find("[GS]etAttribute%s*%(%s*[%\"']([^%\"']+)[%\"']", searchFrom)
			if not startByte then
				break
			end
			if not schemaNames[propertyName] then
				table.insert(issues, {
					severity = "warning",
					code = "unknown-property",
					message = `"{propertyName}" is not a property of this Fragua type.`,
					startByte = startByte,
					endByte = endByte + 1,
				})
			end
			searchFrom = endByte + 1
		end
	end

	local seenHooks = {}
	searchFrom = 1
	while true do
		local startByte, endByte, hookName, parameters =
			source:find("function%s+Behavior%.([%a_][%w_]*)%s*%(([^)]*)%)", searchFrom)
		if not startByte then
			break
		end
		if seenHooks[hookName] then
			table.insert(issues, {
				severity = "error",
				code = "duplicate-hook",
				message = `Behavior.{hookName} is declared more than once.`,
				startByte = startByte,
				endByte = endByte + 1,
			})
		else
			seenHooks[hookName] = true
		end
		local expected = HOOK_ARITY[hookName]
		if expected and parameterCount(parameters) ~= expected then
			table.insert(issues, {
				severity = "error",
				code = "invalid-hook-arity",
				message = `Behavior.{hookName} expects {expected} parameter(s).`,
				startByte = startByte,
				endByte = endByte + 1,
			})
		end
		searchFrom = endByte + 1
	end

	local masked, unclosedString = maskStringsAndComments(source)
	if unclosedString then
		table.insert(issues, {
			severity = "error",
			code = "unclosed-string",
			message = "String is not closed.",
			startByte = #source,
			endByte = #source + 1,
		})
	end
	local stack = {}
	local matching = { [")"] = "(", ["]"] = "[", ["}"] = "{" }
	for index = 1, #masked do
		local char = masked:sub(index, index)
		if char == "(" or char == "[" or char == "{" then
			table.insert(stack, { char = char, index = index })
		elseif matching[char] then
			local top = stack[#stack]
			if not top or top.char ~= matching[char] then
				table.insert(issues, {
					severity = "error",
					code = "unmatched-bracket",
					message = `Bracket "{char}" has no matching opener.`,
					startByte = index,
					endByte = index + 1,
				})
				break
			end
			table.remove(stack)
		end
	end
	if #stack > 0 then
		local top = stack[#stack]
		table.insert(issues, {
			severity = "error",
			code = "unmatched-bracket",
			message = `Bracket "{top.char}" is not closed.`,
			startByte = top.index,
			endByte = top.index + 1,
		})
	end

	table.sort(issues, function(a, b)
		if a.startByte == b.startByte then
			return a.code < b.code
		end
		return a.startByte < b.startByte
	end)
	return issues
end

return Diagnostics
