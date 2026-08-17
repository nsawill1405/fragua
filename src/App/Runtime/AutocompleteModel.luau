local AutocompleteModel = {}

local inferenceCache = {}
local inferenceCacheSize = 0

local function hash(value: string): string
	local result = 5381
	for index = 1, #value do
		result = (result * 33 + string.byte(value, index)) % 4294967296
	end
	return tostring(result)
end

local function revision(surface): string?
	if surface.revision ~= nil then
		return tostring(surface.revision)
	end
	if surface.catalogueRevision ~= nil then
		return tostring(surface.catalogueRevision)
	end
	return nil
end

local function sourceFrom(request): string
	if typeof(request.line) == "string" then
		return request.line
	end
	if typeof(request.text) == "string" then
		return request.text
	end
	if typeof(request.textDocument) == "table" and typeof(request.textDocument.text) == "string" then
		return request.textDocument.text
	end
	return ""
end

local function positionFrom(request, source: string): number
	if typeof(request.position) == "number" then
		return math.clamp(request.position, 0, #source)
	end
	if typeof(request.position) ~= "table" then
		return #source
	end

	local requestedLine = request.position.line
	local character = request.position.character or request.position.column or 0
	if typeof(requestedLine) ~= "number" or typeof(character) ~= "number" then
		return #source
	end
	local targetLine = math.max(1, requestedLine)
	local offset = 0
	for _ = 1, targetLine - 1 do
		local newline = source:find("\n", offset + 1, true)
		if not newline then
			return #source
		end
		offset = newline
	end
	return math.clamp(offset + character - 1, 0, #source)
end

local function extractContext(source: string, position: number): { string }
	local lines = {}
	local lineEnd = position
	for _ = 1, 201 do
		local newline = lineEnd
		while newline > 0 and string.byte(source, newline) ~= 10 do
			newline -= 1
		end
		table.insert(lines, 1, source:sub(newline + 1, lineEnd))
		if newline == 0 then
			break
		end
		lineEnd = newline - 1
	end
	return lines
end

local function typesById(surface)
	local result = {}
	for _, typeEntry in surface.types or {} do
		if typeof(typeEntry.id) == "string" and typeEntry.id ~= "" then
			result[typeEntry.id] = typeEntry
		end
	end
	return result
end

local function isFacade(value): boolean
	return value == "Server" or value == "Client" or value == "Core"
end

local function isFacadeRoot(value): boolean
	return value == "Fragua" or value == "FraguaGateway"
end

local function inferLocals(surface, lines)
	local surfaceRevision = revision(surface)
	local contextLines = {}
	for index = 1, #lines - 1 do
		table.insert(contextLines, lines[index])
	end
	local cacheKey = if surfaceRevision then surfaceRevision .. ":" .. hash(table.concat(contextLines, "\n")) else nil
	if cacheKey and inferenceCache[cacheKey] then
		return inferenceCache[cacheKey]
	end

	local knownTypes = typesById(surface)
	local locals = {}
	for _, line in contextLines do
		local name, facadeRoot, explicitFacade, typeId = line:match(
			"^%s*local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%.([%a_][%w_]*)%.Instance%.new%s*%(%s*[\"']([^\"']+)[\"']%s*%)"
		)
		if not (name and isFacadeRoot(facadeRoot) and isFacade(explicitFacade)) then
			name, typeId = line:match("^%s*local%s+([%a_][%w_]*)%s*=%s*Instance%.new%s*%(%s*[\"']([^\"']+)[\"']%s*%)")
			explicitFacade = nil
		end
		if not typeId then
			name, facadeRoot, explicitFacade, typeId = line:match(
				"^%s*local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%.([%a_][%w_]*)%.Instance%.new%s*%(%s*Enum%.FraguaType%.([%a_][%w_]*)%s*%)"
			)
			if not (name and isFacadeRoot(facadeRoot) and isFacade(explicitFacade)) then
				name, typeId = line:match(
					"^%s*local%s+([%a_][%w_]*)%s*=%s*Instance%.new%s*%(%s*Enum%.FraguaType%.([%a_][%w_]*)%s*%)"
				)
				explicitFacade = nil
			end
		end
		if name and knownTypes[typeId] then
			locals[name] = { typeId = typeId, facade = explicitFacade }
		else
			local assigned, getRoot, getFacade, sourceName = line:match(
				"^%s*local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%.([%a_][%w_]*)%.Get%s*%(%s*([%a_][%w_]*)%s*%)"
			)
			if not (assigned and isFacadeRoot(getRoot) and isFacade(getFacade)) then
				assigned, sourceName =
					line:match("^%s*local%s+([%a_][%w_]*)%s*=%s*Fragua%.Get%s*%(%s*([%a_][%w_]*)%s*%)")
				getFacade = nil
			end
			if assigned and locals[sourceName] then
				locals[assigned] = { typeId = locals[sourceName].typeId, facade = getFacade }
			else
				assigned, sourceName = line:match("^%s*local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%s*$")
				if assigned and locals[sourceName] then
					locals[assigned] = locals[sourceName]
				end
			end
		end
	end
	if inferenceCacheSize >= 64 then
		inferenceCache = {}
		inferenceCacheSize = 0
	end
	if cacheKey then
		inferenceCache[cacheKey] = locals
		inferenceCacheSize += 1
	end
	return locals
end

local function matches(label: string, partial: string): boolean
	return partial == "" or label:sub(1, #partial):lower() == partial:lower()
end

local function replacement(partial: string, position: number)
	if partial == "" then
		return nil
	end
	return {
		newText = "",
		replace = {
			start = position - #partial,
			["end"] = position,
		},
	}
end

local function typeItems(surface, partial: string, position: number)
	local items = {}
	for _, typeEntry in surface.types or {} do
		if typeof(typeEntry.id) == "string" and matches(typeEntry.id, partial) then
			local edit = replacement(partial, position)
			if edit then
				edit.newText = typeEntry.id
			end
			table.insert(items, {
				label = typeEntry.id,
				kind = "Class",
				detail = "Fragua type",
				documentation = typeEntry.name or typeEntry.id,
				textEdit = edit,
			})
		end
	end
	table.sort(items, function(a, b)
		return a.label < b.label
	end)
	return items
end

local function methodDetail(method): string
	local parameters = {}
	for _, parameter in method.parameters or {} do
		table.insert(parameters, (parameter.name or "value") .. ": " .. (parameter.typeName or "any"))
	end
	return string.format("(%s) -> %s", table.concat(parameters, ", "), method.returns or "any")
end

local function memberItems(typeEntry, facade: string, access: string, partial: string, position: number)
	local itemsByLabel = {}
	if access == "." then
		for _, property in typeEntry.properties or {} do
			if typeof(property.name) == "string" and matches(property.name, partial) then
				itemsByLabel[property.name] = {
					label = property.name,
					kind = "Property",
					detail = property.typeName or property.valueType or "any",
					documentation = if property.inherited then "Inherited Fragua property" else "Fragua property",
				}
			end
		end
	end
	local methods = if facade == "Server"
		then typeEntry.serverMethods
		elseif facade == "Client" then typeEntry.clientMethods
		else {}
	if access == ":" then
		for _, method in methods or {} do
			if typeof(method.name) == "string" and matches(method.name, partial) then
				itemsByLabel[method.name] = {
					label = method.name,
					kind = "Method",
					detail = methodDetail(method),
					documentation = "Fragua " .. facade .. " method",
				}
			end
		end
	end
	for _, name in { "Clone", "Destroy", "Instance", "IsA", "TypeId" } do
		local kind = if name == "Instance" or name == "TypeId" then "Property" else "Method"
		local expectedAccess = if kind == "Property" then "." else ":"
		if access == expectedAccess and matches(name, partial) and not itemsByLabel[name] then
			itemsByLabel[name] = {
				label = name,
				kind = kind,
				detail = "Fragua core member",
				documentation = "Fragua wrapper member",
			}
		end
	end
	local items = {}
	for _, item in itemsByLabel do
		local edit = replacement(partial, position)
		if edit then
			edit.newText = item.label
		end
		item.textEdit = edit
		table.insert(items, item)
	end
	table.sort(items, function(a, b)
		return a.label < b.label
	end)
	return items
end

function AutocompleteModel.complete(request, surface, facade)
	if typeof(request) ~= "table" or typeof(surface) ~= "table" then
		return {}
	end
	local source = sourceFrom(request)
	local position = positionFrom(request, source)
	local lines = extractContext(source, position)
	local currentLine = lines[#lines] or ""

	local partial = currentLine:match("Instance%.new%s*%(%s*[\"']([^\"']*)$")
	if partial then
		return typeItems(surface, partial, position)
	end
	partial = currentLine:match("Instance%.new%s*%(%s*Enum%.FraguaType%.([%w_]*)$")
	if partial then
		return typeItems(surface, partial, position)
	end
	local enumName, itemPartial = currentLine:match("Enum%.([%w_]+)%.([%w_]*)$")
	if enumName then
		if enumName == "FraguaType" then
			return typeItems(surface, itemPartial, position)
		end
		for _, enum in surface.enums or {} do
			if enum.id == enumName then
				local items = {}
				for _, item in enum.items or {} do
					if typeof(item) == "string" and matches(item, itemPartial) then
						local edit = replacement(itemPartial, position)
						if edit then
							edit.newText = item
						end
						table.insert(items, {
							label = item,
							kind = "Enum",
							detail = "Enum." .. enumName,
							documentation = "Fragua enum item",
							textEdit = edit,
						})
					end
				end
				table.sort(items, function(a, b)
					return a.label < b.label
				end)
				return items
			end
		end
	end

	local localName, access, memberPartial = currentLine:match("([%a_][%w_]*)%s*([%.:])%s*([%w_]*)$")
	if not localName then
		return {}
	end
	local localTypes = inferLocals(surface, lines)
	local binding = localTypes[localName]
	local typeEntry = binding and typesById(surface)[binding.typeId]
	if not typeEntry then
		return {}
	end
	return memberItems(typeEntry, binding.facade or facade or "Core", access, memberPartial, position)
end

function AutocompleteModel.extractContext(request): { string }
	local source = sourceFrom(request)
	return extractContext(source, positionFrom(request, source))
end

return AutocompleteModel
