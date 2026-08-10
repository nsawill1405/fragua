local InsertFlow = require("../src/App/Explorer/InsertFlow")

local workspace = { kind = "workspace" }

return {
	["uses selected valid parent"] = function()
		local parent = { Parent = workspace }
		assert(InsertFlow.resolveParent(parent, workspace) == parent)
	end,
	["falls back to workspace for missing or destroyed parent"] = function()
		assert(InsertFlow.resolveParent(nil, workspace) == workspace)
		assert(InsertFlow.resolveParent({ Parent = nil }, workspace) == workspace)
	end,
	["accepts workspace itself as the target"] = function()
		assert(InsertFlow.resolveParent(workspace, workspace) == workspace)
	end,
}
