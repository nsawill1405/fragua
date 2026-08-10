local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ApiSource = require(script.Parent.ApiSource)
local BootstrapSource = require(script.Parent.BootstrapSource)

local EnsurePlaceModules = {}

local function ensureModule(parent: Instance, name: string, source: string, className: string)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		-- Keep user edits if marker present and version matches; otherwise refresh API surface
		local marker = existing:GetAttribute("_FraguaManaged")
		if marker == true then
			(existing :: any).Source = source
		end
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name;
	(inst :: any).Source = source
	inst:SetAttribute("_FraguaManaged", true)
	inst.Parent = parent
	return inst
end

function EnsurePlaceModules.sync()
	ensureModule(ReplicatedStorage, "Fragua", ApiSource, "ModuleScript")
	ensureModule(ServerScriptService, "FraguaRuntime", BootstrapSource, "Script")
end

return EnsurePlaceModules
