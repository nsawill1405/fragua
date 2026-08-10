local TypeEditorLayout = {}

function TypeEditorLayout.panelSize(hostWidth: number, hostHeight: number)
	return {
		width = math.min(math.max(hostWidth - 16, 1), 520),
		height = math.min(math.max(hostHeight - 16, 1), 620),
	}
end

return TypeEditorLayout
