local headerOk, Header = pcall(function()
	return require("../src/App/Runtime/ScriptHeader")
end)
local gateOk, Gate = pcall(function()
	return require("../src/App/Runtime/ScriptUpdateGate")
end)

return {
	["current imports do not invoke a source update"] = function()
		assert(headerOk and Header, "ScriptHeader should be available")
		assert(gateOk and Gate, "ScriptUpdateGate should be available")
		local updateCount = 0
		local applyClient = function(source)
			return Header.apply(source, "Client")
		end
		local editorSource = Header.apply("print('editing')", "Client")
		local source = Gate.selectSource(true, editorSource, "print('stale Source property')")
		local changed = Gate.run(source, applyClient, function()
			updateCount += 1
		end)
		assert(not changed)
		assert(updateCount == 0, `expected no source updates, got {updateCount}`)
	end,
	["missing imports invoke exactly one source update"] = function()
		assert(headerOk and Header, "ScriptHeader should be available")
		assert(gateOk and Gate, "ScriptUpdateGate should be available")
		local updateCount = 0
		local applyServer = function(source)
			return Header.apply(source, "Server")
		end
		local source = Gate.selectSource(true, "print('editing')", Header.apply("print('stored')", "Server"))
		local changed = Gate.run(source, applyServer, function()
			updateCount += 1
		end)
		assert(changed)
		assert(updateCount == 1, `expected one source update, got {updateCount}`)
	end,
	["failed editor read falls back to the stored source"] = function()
		assert(gateOk and Gate, "ScriptUpdateGate should be available")
		local source = Gate.selectSource(false, nil, "print('stored')")
		assert(source == "print('stored')")
	end,
}
