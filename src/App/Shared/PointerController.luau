local UserInputService = game:GetService("UserInputService")

local InteractionMath = require(script.Parent.InteractionMath)

local PointerController = {}

type CaptureOptions = {
	onMove: (number, number) -> (),
	onFinish: ((number, number, boolean) -> ())?,
	initial: Vector2?,
	scroll: ScrollingFrame?,
}

type PointerSession = {
	cancel: (PointerSession) -> (),
}

local activeByHost: { [GuiObject]: PointerSession } = setmetatable({}, { __mode = "k" }) :: any

function PointerController.toHostLocal(host: GuiObject, sampleX: number, sampleY: number): (number, number)
	local pluginGui = host:FindFirstAncestorWhichIsA("PluginGui")
	if pluginGui then
		local ok, relative = pcall(function()
			return pluginGui:GetRelativeMousePosition()
		end)
		if ok then
			return InteractionMath.toLocal(host.AbsolutePosition.X, host.AbsolutePosition.Y, relative.X, relative.Y)
		end
	end
	-- GuiButton events outside PluginGui use screen coordinates.
	return InteractionMath.toLocal(host.AbsolutePosition.X, host.AbsolutePosition.Y, sampleX, sampleY)
end

function PointerController.toControlLocal(
	host: GuiObject,
	control: GuiObject,
	hostX: number,
	hostY: number
): (number, number)
	local origin = control.AbsolutePosition - host.AbsolutePosition
	return InteractionMath.toLocal(origin.X, origin.Y, hostX, hostY)
end

function PointerController.capture(host: GuiObject, options: CaptureOptions): PointerSession
	local previous = activeByHost[host]
	if previous then
		previous:cancel()
	end

	local existing = host:FindFirstChild("_FraguaCapture")
	if existing then
		existing:Destroy()
	end

	local capture = Instance.new("TextButton")
	capture.Name = "_FraguaCapture"
	capture.AutoButtonColor = false
	capture.Text = ""
	capture.BackgroundTransparency = 1
	capture.BorderSizePixel = 0
	capture.Size = UDim2.fromScale(1, 1)
	capture.ZIndex = 10000
	capture.Active = true
	capture.Parent = host

	local scroll = options.scroll
	local previousScrolling = if scroll then scroll.ScrollingEnabled else nil
	if scroll then
		scroll.ScrollingEnabled = false
	end

	local finished = false
	local captureAlive = true
	local last = options.initial or Vector2.zero
	local connections: { RBXScriptConnection } = {}

	local session = {} :: PointerSession

	local function disconnectAll()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	local function finish(cancelled: boolean)
		if finished then
			return
		end
		finished = true
		disconnectAll()
		if scroll and scroll.Parent and previousScrolling ~= nil then
			scroll.ScrollingEnabled = previousScrolling
		end
		if captureAlive and capture.Parent then
			capture:Destroy()
		end
		if activeByHost[host] == session then
			activeByHost[host] = nil
		end
		if options.onFinish then
			options.onFinish(last.X, last.Y, cancelled)
		end
	end

	function session:cancel()
		finish(true)
	end

	activeByHost[host] = session

	local function sample(rawX: number, rawY: number)
		local x, y = PointerController.toHostLocal(host, rawX, rawY)
		last = Vector2.new(x, y)
		if not finished then
			options.onMove(x, y)
		end
	end

	if options.initial then
		options.onMove(options.initial.X, options.initial.Y)
	end

	table.insert(connections, capture.MouseMoved:Connect(sample))
	table.insert(
		connections,
		capture.MouseButton1Up:Connect(function(x, y)
			sample(x, y)
			finish(false)
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				finish(false)
			end
		end)
	)
	table.insert(
		connections,
		host.AncestryChanged:Connect(function(_, parent)
			if not parent then
				finish(true)
			end
		end)
	)
	table.insert(
		connections,
		capture.Destroying:Connect(function()
			if not finished then
				captureAlive = false
				finish(true)
			end
		end)
	)

	return session
end

function PointerController.cancel(host: GuiObject)
	local session = activeByHost[host]
	if session then
		session:cancel()
	end
end

return PointerController
