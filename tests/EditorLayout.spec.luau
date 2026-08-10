local EditorLayout = require("../src/App/ScriptEditor/EditorLayout")

local metrics = {
	charWidth = 8,
	lineHeight = 18,
	gutterWidth = 44,
	padX = 12,
	padY = 10,
}

return {
	["long documents grow vertically beyond the viewport"] = function()
		local size = EditorLayout.measure("a\nb\nc\nd", 200, 40, metrics)
		assert(size.height == 92, `expected 92, got {size.height}`)
	end,
	["long lines grow horizontally beyond the viewport"] = function()
		local size = EditorLayout.measure(string.rep("x", 40), 180, 100, metrics)
		assert(size.width == 388, `expected 388, got {size.width}`)
	end,
	["popup position subtracts canvas scroll and clamps to viewport"] = function()
		local point = EditorLayout.popupPoint({ x = 300, y = 220 }, 160, 120, 240, 140, 100, 60)
		assert(point.x == 140 and point.y == 80, `{point.x},{point.y}`)
	end,
	["cursor point sits on the active text line"] = function()
		assert(EditorLayout.cursorPoint, "cursorPoint should be available")
		local point = EditorLayout.cursorPoint("one\ntw", 7, metrics)
		assert(point.x == 72 and point.y == 28, `{point.x},{point.y}`)
	end,
	["selection rectangles span each selected line"] = function()
		assert(EditorLayout.selectionRects, "selectionRects should be available")
		local rects = EditorLayout.selectionRects("abcd\nefgh", 3, 9, metrics)
		assert(#rects == 2, `expected 2 rectangles, got {#rects}`)
		assert(rects[1].x == 72 and rects[1].width == 16, `{rects[1].x},{rects[1].width}`)
		assert(rects[2].x == 56 and rects[2].width == 24, `{rects[2].x},{rects[2].width}`)
	end,
	["scroll target keeps the caret inside the visible editor area"] = function()
		assert(EditorLayout.scrollToPoint, "scrollToPoint should be available")
		local point = EditorLayout.scrollToPoint({ x = 300, y = 220 }, 0, 0, 200, 100, 18)
		assert(point.x == 112 and point.y == 138, `{point.x},{point.y}`)
		local stable = EditorLayout.scrollToPoint({ x = 80, y = 40 }, 20, 10, 200, 100, 18)
		assert(stable.x == 20 and stable.y == 10, `{stable.x},{stable.y}`)
	end,
}
