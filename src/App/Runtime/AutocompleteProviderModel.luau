local AutocompleteModel = if script then require(script.Parent.AutocompleteModel) else require("./AutocompleteModel")

local AutocompleteProviderModel = {}

local MAX_PRECEDING_LINES = 200

function AutocompleteProviderModel.prepareRequest(request)
	local modelRequest = table.clone(request)
	local position = request.position
	local document = request.textDocument and request.textDocument.document
	if
		document
		and typeof(position) == "table"
		and typeof(position.line) == "number"
		and typeof(position.character) == "number"
	then
		local startLine = math.max(1, position.line - MAX_PRECEDING_LINES)
		modelRequest.line = nil
		modelRequest.text = document:GetText(startLine, 1, position.line, position.character)
		modelRequest.position = {
			line = position.line - startLine + 1,
			character = position.character,
		}
		return modelRequest
	end

	local lines = AutocompleteModel.extractContext(request)
	modelRequest.line = table.concat(lines, "\n")
	modelRequest.text = nil
	modelRequest.textDocument = nil
	modelRequest.position = #modelRequest.line
	return modelRequest
end

function AutocompleteProviderModel.editorItem(item, request, completionKind)
	local result = {
		label = item.label,
		kind = completionKind(item.kind),
		detail = item.detail,
		documentation = {
			value = item.documentation,
		},
	}
	if item.textEdit then
		local start = item.textEdit.replace.start
		local finish = item.textEdit.replace["end"]
		local replace = item.textEdit.replace
		if typeof(request.position) == "table" and typeof(request.position.character) == "number" then
			local partialLength = finish - start
			replace = {
				start = {
					line = request.position.line,
					character = request.position.character - partialLength,
				},
				["end"] = {
					line = request.position.line,
					character = request.position.character,
				},
			}
		end
		result.textEdit = {
			newText = item.textEdit.newText,
			replace = replace,
		}
	end
	return result
end

local function itemKey(item): string
	return tostring(item.label) .. "\0" .. tostring(item.kind)
end

function AutocompleteProviderModel.appendUnique(response, additions)
	response.items = response.items or {}
	local existing = {}
	for _, item in response.items do
		existing[itemKey(item)] = true
	end
	for _, item in additions do
		local key = itemKey(item)
		if not existing[key] then
			existing[key] = true
			table.insert(response.items, item)
		end
	end
	return response
end

function AutocompleteProviderModel.applyAdditions(response, buildAdditions, request)
	pcall(function()
		AutocompleteProviderModel.appendUnique(response, buildAdditions(request))
	end)
	return response
end

return AutocompleteProviderModel
