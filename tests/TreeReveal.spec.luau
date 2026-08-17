local fs = require("@lune/fs")

return {
	["studio selection expands ancestor rows in the explorer"] = function()
		local source = fs.readFile("src/App/Explorer/Tree.luau")
		assert(source:find("local function expandAncestors", 1, true))
		assert(source:find("local function revealStudioSelection", 1, true))
		assert(source:find("Selection.SelectionChanged:Connect(revealStudioSelection)", 1, true))
		assert(source:find("scrollToInstance", 1, true))
		assert(source:find("expanded[current] = true", 1, true))
	end,
}
