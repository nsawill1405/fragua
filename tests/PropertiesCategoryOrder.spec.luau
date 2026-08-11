local ok, CategoryOrder = pcall(function()
	return require("../src/App/Properties/CategoryOrder")
end)

return {
	["direct custom sections stay above inherited engine sections"] = function()
		assert(ok and CategoryOrder, "CategoryOrder should be available")
		local ordered = CategoryOrder.sort(
			{ "Appearance", "Combat", "Data", "Tags", "AI", "Attributes", "Behavior" },
			{ "AI", "Combat" }
		)
		local expected = { "Data", "AI", "Combat", "Behavior", "Appearance", "Tags", "Attributes" }
		assert(#ordered == #expected)
		for index, name in expected do
			assert(ordered[index] == name, `expected {name} at {index}, got {ordered[index]}`)
		end
	end,
	["custom section creation order is preserved"] = function()
		assert(ok and CategoryOrder, "CategoryOrder should be available")
		local ordered = CategoryOrder.sort({ "Second", "First", "Data" }, { "First", "Second" })
		assert(ordered[1] == "Data" and ordered[2] == "First" and ordered[3] == "Second")
	end,
	["any number of direct sections remain ahead of engine sections"] = function()
		assert(ok and CategoryOrder, "CategoryOrder should be available")
		local categories = { "Data", "Behavior" }
		local direct = {}
		for index = 1, 120 do
			local name = `Custom{index}`
			table.insert(categories, name)
			table.insert(direct, name)
		end
		local ordered = CategoryOrder.sort(categories, direct)
		assert(ordered[1] == "Data")
		assert(ordered[121] == "Custom120")
		assert(ordered[122] == "Behavior")
	end,
}
