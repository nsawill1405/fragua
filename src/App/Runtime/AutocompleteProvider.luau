local AutocompleteModel = require(script.Parent.AutocompleteModel)
local ScriptContext = require(script.Parent.ScriptContext)

local AutocompleteProvider = {}

local CALLBACK_NAME = "FraguaAutocompleteV1"
local CALLBACK_PRIORITY = 100

local function requestScript(request)
	local textDocument = request.textDocument
	if typeof(textDocument) ~= "table" then
		return nil
	end
	if typeof(textDocument.script) == "Instance" then
		return textDocument.script
	end
	if textDocument.document then
		return textDocument.document:GetScript()
	end
	return nil
end

local function facadeFor(request)
	local scriptInstance = requestScript(request)
	if typeof(scriptInstance) ~= "Instance" then
		return "Core"
	end
	return ScriptContext.select(scriptInstance.ClassName, scriptInstance:GetFullName())
end

local function completionKind(kind)
	return Enum.CompletionItemKind[kind] or Enum.CompletionItemKind.Text
end

local function editorItem(item, request)
	local result = {
		label = item.label,
		kind = completionKind(item.kind),
		detail = item.detail,
		documentation = {
			value = item.documentation,
			kind = "markdown",
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

function AutocompleteProvider.start(getSurface)
	local ScriptEditorService = game:GetService("ScriptEditorService")
	local function buildAdditions(request)
		local modelRequest = table.clone(request)
		local document = request.textDocument and request.textDocument.document
		if document then
			modelRequest.text = document:GetText()
		elseif request.textDocument and typeof(request.textDocument.script) == "Instance" then
			modelRequest.text = ScriptEditorService:GetEditorSource(request.textDocument.script)
		end
		local surface = getSurface()
		local additions = AutocompleteModel.complete(modelRequest, surface, facadeFor(request))
		local editorItems = {}
		for _, item in additions do
			table.insert(editorItems, editorItem(item, request))
		end
		return editorItems
	end

	ScriptEditorService:RegisterAutocompleteCallback(CALLBACK_NAME, CALLBACK_PRIORITY, function(request, response)
		local ok, additions = pcall(buildAdditions, request)
		if ok then
			response.items = response.items or {}
			for _, item in additions do
				table.insert(response.items, item)
			end
		end
		return response
	end)

	return {
		destroy = function()
			pcall(function()
				ScriptEditorService:DeregisterAutocompleteCallback(CALLBACK_NAME)
			end)
		end,
	}
end

return AutocompleteProvider
