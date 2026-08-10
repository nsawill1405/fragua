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
	["minimum dock keeps body and footer usable"] = function()
		assert(Layout.geometry, "geometry should be available")
		local geometry = Layout.geometry(220, 260)
		assert(geometry.body.height >= 1)
		assert(geometry.footer.height >= 44)
		assert(geometry.cancelWidth + geometry.buttonGap + geometry.saveWidth <= geometry.panel.width - 24)
	end,
	["short dock never produces a negative body"] = function()
		assert(Layout.geometry, "geometry should be available")
		local geometry = Layout.geometry(240, 200)
		assert(geometry.body.height >= 1)
		assert(geometry.footer.y + geometry.footer.height <= geometry.panel.height)
	end,
	["large dialog geometry remains capped"] = function()
		assert(Layout.geometry, "geometry should be available")
		local geometry = Layout.geometry(900, 800)
		assert(geometry.panel.width == 520 and geometry.panel.height == 620)
	end,
}
