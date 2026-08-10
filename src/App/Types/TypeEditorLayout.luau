local TypeEditorLayout = {}

function TypeEditorLayout.panelSize(hostWidth: number, hostHeight: number)
	return {
		width = math.min(math.max(hostWidth - 16, 1), 520),
		height = math.min(math.max(hostHeight - 16, 1), 620),
	}
end

function TypeEditorLayout.geometry(hostWidth: number, hostHeight: number)
	local panel = TypeEditorLayout.panelSize(hostWidth, hostHeight)
	local titleHeight = math.min(34, math.max(panel.height - 2, 1))
	local footerHeight = math.min(48, math.max(panel.height - titleHeight - 1, 1))
	local footerY = math.max(titleHeight + 1, panel.height - footerHeight)
	local bodyHeight = math.max(1, footerY - titleHeight)
	local available = math.max(panel.width - 24, 1)
	local buttonGap = math.min(8, math.max(available - 2, 0))
	local cancelWidth = math.min(80, math.max(1, math.floor((available - buttonGap) * 0.34)))
	local saveWidth = math.max(1, available - buttonGap - cancelWidth)

	return {
		panel = { x = 0, y = 0, width = panel.width, height = panel.height },
		body = { x = 0, y = titleHeight, width = panel.width, height = bodyHeight },
		footer = { x = 0, y = footerY, width = panel.width, height = footerHeight },
		cancelWidth = cancelWidth,
		saveWidth = saveWidth,
		buttonGap = buttonGap,
	}
end

function TypeEditorLayout.sectionGeometry(editableContentHeight: number)
	local height = math.max(40, editableContentHeight + 8)
	return {
		height = height,
		contentHeight = height,
		accentHeight = math.max(18, height - 6),
	}
end

return TypeEditorLayout
