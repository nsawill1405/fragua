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
	local point = EditorLayout.cursorPoint(source, cursor, metrics)
	return {
		x = point.x,
		y = point.y + metrics.lineHeight,
	}
end

function EditorLayout.cursorPoint(source: string, cursor: number, metrics)
	local before = source:sub(1, math.clamp(cursor - 1, 0, #source))
	local line = 0
	for _ in before:gmatch("\n") do
		line += 1
	end
	local column = #(before:match("([^\n]*)$") or "")
	return {
		x = metrics.gutterWidth + metrics.padX + column * metrics.charWidth,
		y = metrics.padY + line * metrics.lineHeight,
	}
end

function EditorLayout.selectionRects(source: string, cursor: number, selectionStart: number, metrics)
	if cursor <= 0 or selectionStart <= 0 or cursor == selectionStart then
		return {}
	end
	local first = math.clamp(math.min(cursor, selectionStart) - 1, 0, #source)
	local last = math.clamp(math.max(cursor, selectionStart) - 1, 0, #source)
	local rects = {}
	local lineStart = 0
	local lineIndex = 0

	while lineStart <= #source do
		local newline = source:find("\n", lineStart + 1, true)
		local lineEnd = if newline then newline - 1 else #source
		local selectedStart = math.max(first, lineStart)
		local selectedEnd = math.min(last, lineEnd)
		if selectedEnd > selectedStart then
			table.insert(rects, {
				x = metrics.gutterWidth + metrics.padX + (selectedStart - lineStart) * metrics.charWidth,
				y = metrics.padY + lineIndex * metrics.lineHeight,
				width = (selectedEnd - selectedStart) * metrics.charWidth,
				height = metrics.lineHeight,
			})
		end
		if not newline then
			break
		end
		lineStart = newline
		lineIndex += 1
	end
	return rects
end

function EditorLayout.scrollToPoint(
	point,
	canvasX: number,
	canvasY: number,
	viewportWidth: number,
	viewportHeight: number,
	lineHeight: number
)
	local x = canvasX
	local y = canvasY
	if point.x < canvasX then
		x = point.x
	elseif point.x > canvasX + viewportWidth - 12 then
		x = point.x - viewportWidth + 12
	end
	if point.y < canvasY then
		y = point.y
	elseif point.y + lineHeight > canvasY + viewportHeight then
		y = point.y + lineHeight - viewportHeight
	end
	return { x = math.max(0, x), y = math.max(0, y) }
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
