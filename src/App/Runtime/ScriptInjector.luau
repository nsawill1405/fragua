local ScriptEditorService = game:GetService("ScriptEditorService")

local ScriptHeader = require(script.Parent.ScriptHeader)

local ScriptInjector = {}

function ScriptInjector.start()
	local updating = setmetatable({}, { __mode = "k" })
	local watched = setmetatable({}, { __mode = "k" })
	local warned = setmetatable({}, { __mode = "k" })
	local connections: { RBXScriptConnection } = {}
	local stopped = false

	local process: (LuaSourceContainer) -> ()

	local function watch(container: LuaSourceContainer)
		if watched[container] then
			return
		end
		watched[container] = true
		table.insert(
			connections,
			container:GetPropertyChangedSignal("Source"):Connect(function()
				if not stopped and not updating[container] then
					task.defer(process, container)
				end
			end)
		)
	end

	process = function(container: LuaSourceContainer)
		if stopped or updating[container] or not container.Parent then
			return
		end
		watch(container)
		if ScriptHeader.shouldSkip(container:GetFullName()) then
			return
		end

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
	end

	table.insert(
		connections,
		game.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("LuaSourceContainer") then
				task.defer(process, descendant)
			end
		end)
	)

	for _, descendant in game:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			task.defer(process, descendant)
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
