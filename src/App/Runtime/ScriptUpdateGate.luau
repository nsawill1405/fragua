local ScriptUpdateGate = {}

function ScriptUpdateGate.selectSource(editorReadOk: boolean, editorSource: any, storedSource: string): string
	if editorReadOk and type(editorSource) == "string" then
		return editorSource
	end
	return storedSource
end

function ScriptUpdateGate.run(source: string, apply: (string) -> (string, boolean), update: () -> ()): boolean
	local _, changed = apply(source)
	if not changed then
		return false
	end
	update()
	return true
end

return ScriptUpdateGate
