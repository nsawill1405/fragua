local AutocompleteModel = require(script.Parent.AutocompleteModel)
local AutocompleteProviderModel = require(script.Parent.AutocompleteProviderModel)
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

function AutocompleteProvider.start(getSurface)
	local ScriptEditorService = game:GetService("ScriptEditorService")
	local function buildAdditions(request)
		local modelRequest = AutocompleteProviderModel.prepareRequest(request)
		local surface = getSurface()
		local additions = AutocompleteModel.complete(modelRequest, surface, facadeFor(request))
		local editorItems = {}
		for _, item in additions do
			table.insert(editorItems, AutocompleteProviderModel.editorItem(item, request, completionKind))
		end
		return editorItems
	end

	ScriptEditorService:RegisterAutocompleteCallback(CALLBACK_NAME, CALLBACK_PRIORITY, function(request, response)
		return AutocompleteProviderModel.applyAdditions(response, buildAdditions, request)
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
