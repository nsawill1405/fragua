local ok, LifecycleGate = pcall(function()
	return require("../src/App/Shared/LifecycleGate")
end)

return {
	["transition invalidates work scheduled by the previous generation"] = function()
		assert(ok and LifecycleGate, "LifecycleGate should be available")
		local gate = LifecycleGate.new()
		local stale = gate:advance()
		local current = gate:advance()
		assert(not gate:isCurrent(stale))
		assert(gate:isCurrent(current))
	end,
	["the initial generation can schedule one current refresh"] = function()
		assert(ok and LifecycleGate, "LifecycleGate should be available")
		local gate = LifecycleGate.new()
		assert(gate:isCurrent(0))
	end,
}
