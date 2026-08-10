local Layout = require("../src/App/Types/TypeEditorLayout")

return {
	["dialog never exceeds a small dock"] = function()
		local size = Layout.panelSize(220, 260)
		assert(size.width == 204 and size.height == 244, `{size.width}x{size.height}`)
	end,
	["dialog caps itself in a large dock"] = function()
		local size = Layout.panelSize(900, 800)
		assert(size.width == 520 and size.height == 620, `{size.width}x{size.height}`)
	end,
}
