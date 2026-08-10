local EditorLayout = {}

local function lineStats(source: string): (number, number, number)
	local lineCount = 1
	local longest = 0
	local current = 0
	for index = 1, #source do
		if source:sub(index, index) == "\n" then
			lineCount += 1
			longest = math.max(longest, current)
			current = 0
		else
			current += 1
		end
	end
	return lineCount, math.max(longest, current), current
end

function EditorLayout.measure(source: string, viewportWidth: number, viewportHeight: number, metrics)
	local lineCount, longest = lineStats(source)
	return {
		width = math.max(viewportWidth, metrics.gutterWidth + longest * metrics.charWidth + metrics.padX * 2),
		height = math.max(viewportHeight, lineCount * metrics.lineHeight + metrics.padY * 2),
	}
end

function EditorLayout.caretPoint(source: string, cursor: number, metrics)
	local before = source:sub(1, math.clamp(cursor - 1, 0, #source))
	local line = 0
	for _ in before:gmatch("\n") do
		line += 1
	end
	local column = #(before:match("([^\n]*)$") or "")
	return {
		x = metrics.gutterWidth + metrics.padX + column * metrics.charWidth,
		y = metrics.padY + (line + 1) * metrics.lineHeight,
	}
end

function EditorLayout.popupPoint(
	caret,
	canvasX: number,
	canvasY: number,
	viewportWidth: number,
	viewportHeight: number,
	popupWidth: number,
	popupHeight: number
)
	return {
		x = math.clamp(caret.x - canvasX, 4, math.max(4, viewportWidth - popupWidth)),
		y = math.clamp(caret.y - canvasY, 4, math.max(4, viewportHeight - popupHeight)),
	}
end

return EditorLayout
