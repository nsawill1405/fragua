local ScriptContext = {}

export type Facade = "Server" | "Client" | "Core"

local function isInService(fullName: string, serviceName: string): boolean
	return fullName == serviceName or fullName:sub(1, #serviceName + 1) == serviceName .. "."
end

function ScriptContext.select(className: string, fullName: string): Facade
	if className == "Script" then
		return "Server"
	end
	if className == "LocalScript" then
		return "Client"
	end
	if
		className == "ModuleScript"
		and (isInService(fullName, "ServerStorage") or isInService(fullName, "ServerScriptService"))
	then
		return "Server"
	end
	return "Core"
end

return ScriptContext
