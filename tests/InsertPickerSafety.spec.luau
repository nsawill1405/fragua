local fs = require("@lune/fs")

return {
	["custom insert path protects createInstance with pcall and warn"] = function()
		local source = fs.readFile("src/App/Explorer/InsertPicker.luau")
		local start = assert(source:find('if choice.kind == "custom" then', 1, true))
		local finish = assert(source:find("\nreturn InsertPicker", start, true))
		local body = source:sub(start, finish - 1)
		assert(body:find("pcall", 1, true), "custom insert must pcall Registry.createInstance")
		assert(body:find("Registry.createInstance", 1, true), "custom insert must still create via Registry")
		assert(body:find("warn(", 1, true), "custom insert must warn on failure")
		assert(body:find("afterInsert", 1, true), "custom insert must still call afterInsert on success")
	end,
}
