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
		local editorSource = Header.HEADER .. "\n\nprint('editing')"
		local source = Gate.selectSource(true, editorSource, "print('stale Source property')")
		local changed = Gate.run(source, Header.apply, function()
			updateCount += 1
		end)
		assert(not changed)
		assert(updateCount == 0, `expected no source updates, got {updateCount}`)
	end,
	["missing imports invoke exactly one source update"] = function()
		assert(gateOk and Gate, "ScriptUpdateGate should be available")
		local updateCount = 0
		local source = Gate.selectSource(true, "print('editing')", Header.HEADER)
		local changed = Gate.run(source, Header.apply, function()
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
