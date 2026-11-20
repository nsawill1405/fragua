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
	["double click opens script documents"] = function()
		local source = fs.readFile("src/App/Explorer/Tree.luau")
		assert(source:find("OpenScriptDocumentAsync", 1, true))
		assert(source:find("openIfScript", 1, true))
		assert(source:find("Open Script", 1, true))
	end,
	["double click is detected on press so the drag capture cannot swallow it"] = function()
		local source = fs.readFile("src/App/Explorer/Tree.luau")
		local press = assert(source:find("local function onPress", 1, true))
		local pressEnd = assert(source:find("label.InputBegan:Connect(onPress)", press, true))
		local body = source:sub(press, pressEnd)
		assert(body:find("registerPress(instance)", 1, true), "press must register for double click")
		assert(body:find("openIfScript(instance)", 1, true), "double press must open scripts")
		local doubled = assert(body:find("if doubled then", 1, true))
		local drag = assert(body:find("beginPressDrag(input)", 1, true))
		assert(doubled < drag, "double press must open before starting a drag capture")
		assert(source:find("row.InputBegan:Connect(onPress)", 1, true), "row clicks must also open scripts")
	end,
	["hides sticker internals so expand arrows dont flash on select"] = function()
		local source = fs.readFile("src/App/Explorer/Tree.luau")
		assert(source:find("_Sticker", 1, true))
		assert(source:find("twist.Visible = hasChildren", 1, true))
	end,
}
