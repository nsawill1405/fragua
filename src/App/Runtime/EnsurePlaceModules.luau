local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local ApiSource = require(script.Parent.ApiSource)
local BootstrapSource = require(script.Parent.BootstrapSource)
local ClientBootstrapSource = require(script.Parent.ClientBootstrapSource)
local GuideSource = require(script.Parent.GuideSource)
local Constants = require(script.Parent.Parent.Shared.Constants)

local EnsurePlaceModules = {}

local function createManaged(parent: Instance, name: string, source: string, className: string)
	local inst = Instance.new(className)
	inst.Name = name;
	(inst :: any).Source = source
	inst:SetAttribute("_FraguaManaged", true)
	inst.Parent = parent
	return inst
end

local function ensureModule(parent: Instance, name: string, source: string, className: string)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		local marker = existing:GetAttribute("_FraguaManaged")
		if marker == true then
			if (existing :: any).Source == source then
				return existing
			end
			-- recreate so require caches pick up the new gateway shape
			existing:Destroy()
			return createManaged(parent, name, source, className)
		end
		return existing
	end
	if existing then
		existing:Destroy()
	end
	return createManaged(parent, name, source, className)
end

local function ensurePluginRoot(): Instance
	local root = ServerStorage:FindFirstChild(Constants.ROOT_FOLDER)
	if root then
		return root
	end
	root = Instance.new("Folder")
	root.Name = Constants.ROOT_FOLDER
	root.Parent = ServerStorage
	return root
end

function EnsurePlaceModules.sync(surface: any)
	local RunService = game:GetService("RunService")
	if RunService:IsRunning() and not RunService:IsEdit() then
		return
	end
	assert(surface ~= nil, "type surface required")
	ensureModule(ReplicatedStorage, "Fragua", ApiSource.build(surface or { types = {} }), "ModuleScript")
	ensureModule(ServerScriptService, "FraguaRuntime", BootstrapSource, "Script")
	local starterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	ensureModule(starterPlayerScripts, "FraguaClientRuntime", ClientBootstrapSource, "LocalScript")
	-- ai / mcp guide lives with type defs so studio mcp can script_read it
	ensureModule(ensurePluginRoot(), "README", GuideSource, "ModuleScript")
end

return EnsurePlaceModules
