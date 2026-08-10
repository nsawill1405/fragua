local ScriptEditorService = game:GetService("ScriptEditorService")

local ScriptHeader = require(script.Parent.ScriptHeader)
local ScriptUpdateGate = require(script.Parent.ScriptUpdateGate)

local ScriptInjector = {}

function ScriptInjector.start()
	local updating = setmetatable({}, { __mode = "k" })
	local watched = setmetatable({}, { __mode = "k" })
	local warned = setmetatable({}, { __mode = "k" })
	local scheduled = setmetatable({}, { __mode = "k" })
	local connections: { RBXScriptConnection } = {}
	local stopped = false

	local process: (LuaSourceContainer) -> ()
	local schedule: (LuaSourceContainer) -> ()

	local function watch(container: LuaSourceContainer)
		if watched[container] then
			return
		end
		watched[container] = true
		table.insert(
			connections,
			container:GetPropertyChangedSignal("Source"):Connect(function()
				if not stopped and not updating[container] then
					schedule(container)
				end
			end)
		)
	end

	schedule = function(container: LuaSourceContainer)
		if stopped or scheduled[container] then
			return
		end
		scheduled[container] = true
		task.defer(function()
			scheduled[container] = nil
			process(container)
		end)
	end

	process = function(container: LuaSourceContainer)
		if stopped or updating[container] or not container.Parent then
			return
		end
		watch(container)
		if ScriptHeader.shouldSkip(container:GetFullName()) then
			return
		end

		local editorReadOk, editorSource = pcall(ScriptEditorService.GetEditorSource, ScriptEditorService, container)
		local currentSource = ScriptUpdateGate.selectSource(editorReadOk, editorSource, container.Source)
		ScriptUpdateGate.run(currentSource, ScriptHeader.apply, function()
			updating[container] = true
			local ok, err = pcall(function()
				ScriptEditorService:UpdateSourceAsync(container, function(oldSource)
					local nextSource = ScriptHeader.apply(oldSource)
					return nextSource
				end)
			end)
			updating[container] = nil
			if ok then
				warned[container] = nil
			else
				local message = tostring(err)
				if warned[container] ~= message then
					warned[container] = message
					warn(`[Fragua] Could not add imports to {container:GetFullName()}: {message}`)
				end
			end
		end)
	end

	table.insert(
		connections,
		game.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("LuaSourceContainer") then
				schedule(descendant)
			end
		end)
	)
	table.insert(
		connections,
		ScriptEditorService.TextDocumentDidChange:Connect(function(document)
			local ok, container = pcall(document.GetScript, document)
			if ok and container and container:IsA("LuaSourceContainer") then
				schedule(container)
			end
		end)
	)

	for _, descendant in game:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			schedule(descendant)
		end
	end

	return {
		destroy = function()
			stopped = true
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
		end,
	}
end

return ScriptInjector
