local Layout = require("../src/App/Types/TypeEditorLayout")
local fs = require("@lune/fs")

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
	["property section decoration cannot increase its own layout height"] = function()
		assert(Layout.sectionGeometry, "sectionGeometry should be available")
		local geometry = Layout.sectionGeometry(84)
		assert(geometry.height == 92, `expected 92, got {geometry.height}`)
		assert(geometry.contentHeight == 92)
		assert(geometry.accentHeight == 86)
		local repeated = Layout.sectionGeometry(84)
		assert(repeated.height == geometry.height)
	end,
	["one taller default editor changes only its own row contribution"] = function()
		assert(Layout.measureRows, "measureRows should be available")
		local before = Layout.measureRows({ 22, 22, 22 }, 6)
		local after = Layout.measureRows({ 22, 96, 22 }, 6)
		assert(after - before == 74, `expected 74, got {after - before}`)
	end,
	["property rows reserve a stable header and optional validation line"] = function()
		assert(Layout.propertyRowHeight, "propertyRowHeight should be available")
		assert(Layout.propertyRowHeight(22, false) == 48)
		assert(Layout.propertyRowHeight(96, false) - Layout.propertyRowHeight(22, false) == 74)
		assert(Layout.propertyRowHeight(22, true) > Layout.propertyRowHeight(22, false))
	end,
	["typed controls replace only their row host"] = function()
		local source = fs.readFile("src/App/Types/TypeEditor.luau")
		assert(source:find("TypeValue.supported()", 1, true), "value types should come from TypeValue")
		assert(source:find("DefaultEditor.mount", 1, true), "rows should mount DefaultEditor")
		assert(source:find("oldEditor.destroy()", 1, true), "type changes should destroy only the old editor")
		assert(source:find("prop.controlError", 1, true), "uncommitted component/reference errors must block save")
		assert(not source:find("local defField", 1, true), "the unconditional text default must be removed")
	end,
	["footer controls stay outside the scrolling body"] = function()
		local source = fs.readFile("src/App/Types/TypeEditor.luau")
		assert(source:find("footerFrame.Parent = panel", 1, true))
		assert(not source:find("footerFrame.Parent = propsScroll", 1, true))
		assert(source:find("CanvasPosition", 1, true), "category rebuilds should preserve scroll position")
	end,
}
