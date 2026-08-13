local ok, ProviderModel = pcall(function()
	return require("../src/App/Runtime/AutocompleteProviderModel")
end)

return {
	["reads only the current line and 200 predecessors from ScriptDocument"] = function()
		assert(ok and ProviderModel, "AutocompleteProviderModel should be available")
		local received = nil
		local document = {
			GetText = function(_, ...)
				received = { ... }
				return 'local zombie = Instance.new("Zombie")\nzombie:Att'
			end,
		}
		local request = {
			position = { line = 1001, character = 11 },
			textDocument = { document = document },
		}
		local prepared = ProviderModel.prepareRequest(request)
		assert(received[1] == 801 and received[2] == 1)
		assert(received[3] == 1001 and received[4] == 11)
		assert(prepared.position.line == 201 and prepared.position.character == 11)
	end,
	["resolves documented script-only requests to a bounded open document range"] = function()
		assert(ok and ProviderModel, "AutocompleteProviderModel should be available")
		local scriptInstance = {}
		local received = nil
		local document = {
			GetText = function(_, ...)
				received = { ... }
				return 'local zombie = Instance.new("Zombie")\nzombie:'
			end,
		}
		local request = {
			position = { line = 451, character = 8 },
			textDocument = { script = scriptInstance },
		}
		local prepared = ProviderModel.prepareRequest(request, function(scriptToResolve)
			assert(scriptToResolve == scriptInstance)
			return document
		end)
		assert(received[1] == 251 and received[2] == 1)
		assert(received[3] == 451 and received[4] == 8)
		assert(prepared.position.line == 201 and prepared.position.character == 8)
	end,
	["contains script document lookup failures and preserves native results"] = function()
		assert(ok and ProviderModel, "AutocompleteProviderModel should be available")
		local attempted = false
		local native = { label = "Wait", kind = "Method" }
		local response = { items = { native } }
		local request = {
			position = { line = 4, character = 8 },
			textDocument = { script = {} },
		}
		ProviderModel.applyAdditions(response, function(callbackRequest)
			ProviderModel.prepareRequest(callbackRequest, function()
				attempted = true
				error("document lookup failed")
			end)
			return {}
		end, request)
		assert(attempted)
		assert(#response.items == 1 and response.items[1] == native)
	end,
	["deduplicates additions without changing native item order"] = function()
		assert(ok and ProviderModel, "AutocompleteProviderModel should be available")
		local first = { label = "Health", kind = "Property" }
		local second = { label = "Wait", kind = "Method" }
		local response = { items = { first, second } }
		ProviderModel.appendUnique(response, {
			{ label = "Health", kind = "Property" },
			{ label = "Health", kind = "Method" },
			{ label = "Attack", kind = "Method" },
		})
		assert(#response.items == 4)
		assert(response.items[1] == first and response.items[2] == second)
		assert(response.items[3].label == "Health" and response.items[3].kind == "Method")
		assert(response.items[4].label == "Attack")
	end,
	["emits the documented completion documentation shape"] = function()
		assert(ok and ProviderModel, "AutocompleteProviderModel should be available")
		local item = ProviderModel.editorItem({
			label = "Health",
			kind = "Property",
			detail = "number",
			documentation = "Fragua property",
		}, {}, function(kind)
			return kind
		end)
		assert(item.documentation.value == "Fragua property")
		assert(item.documentation.kind == nil)
	end,
	["leaves the native response usable when custom completion fails"] = function()
		assert(ok and ProviderModel, "AutocompleteProviderModel should be available")
		local native = { label = "Wait", kind = "Method" }
		local response = { items = { native } }
		local returned = ProviderModel.applyAdditions(response, function()
			error("custom failure")
		end)
		assert(returned == response)
		assert(#response.items == 1 and response.items[1] == native)
	end,
}
