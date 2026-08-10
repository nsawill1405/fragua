local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.Shared.Theme)
local CompletionEngine = require(script.Parent.CompletionEngine)
local Diagnostics = require(script.Parent.Diagnostics)
local EditorLayout = require(script.Parent.EditorLayout)
local SyntaxHighlighter = require(script.Parent.SyntaxHighlighter)

local CodeCanvas = {}

local function replaceRange(source: string, startByte: number, endByte: number, replacement: string): (string, number)
	local nextSource = source:sub(1, startByte - 1) .. replacement .. source:sub(endByte)
	return nextSource, startByte + #replacement
end

function CodeCanvas.mount(parent: GuiObject, options)
	local root = Instance.new("Frame")
	root.Name = "CodeCanvas"
	root.BackgroundColor3 = Theme.bgDeep
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ClipsDescendants = true
	root.Parent = parent

	local viewport = Instance.new("ScrollingFrame")
	viewport.Name = "Viewport"
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.CanvasSize = UDim2.new()
	viewport.ScrollBarThickness = 6
	viewport.ScrollBarImageColor3 = Theme.borderLight
	viewport.ScrollingDirection = Enum.ScrollingDirection.XY
	viewport.Parent = root

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = viewport

	local gutter = Instance.new("TextLabel")
	gutter.Name = "Gutter"
	gutter.BackgroundColor3 = Theme.bgDeep
	gutter.BorderSizePixel = 0
	gutter.Size = UDim2.new(0, 44, 1, 0)
	gutter.Font = Theme.fontMono
	gutter.TextSize = 12
	gutter.TextColor3 = Theme.textMuted
	gutter.TextXAlignment = Enum.TextXAlignment.Right
	gutter.TextYAlignment = Enum.TextYAlignment.Top
	gutter.Text = "1"
	gutter.Parent = content
	local gutterPadding = Instance.new("UIPadding")
	gutterPadding.PaddingTop = UDim.new(0, 10)
	gutterPadding.PaddingRight = UDim.new(0, 8)
	gutterPadding.Parent = gutter

	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = Theme.borderLight
	divider.BackgroundTransparency = 0.55
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromOffset(44, 0)
	divider.Size = UDim2.new(0, 1, 1, 0)
	divider.Parent = content

	local highlight = Instance.new("TextLabel")
	highlight.Name = "Highlight"
	highlight.BackgroundTransparency = 1
	highlight.BorderSizePixel = 0
	highlight.Position = UDim2.fromOffset(45, 0)
	highlight.Size = UDim2.new(1, -45, 1, 0)
	highlight.Font = Theme.fontMono
	highlight.TextSize = 13
	highlight.LineHeight = 1.35
	highlight.TextColor3 = Theme.textBright
	highlight.TextXAlignment = Enum.TextXAlignment.Left
	highlight.TextYAlignment = Enum.TextYAlignment.Top
	highlight.TextWrapped = false
	highlight.RichText = true
	highlight.Text = ""
	highlight.ZIndex = 1
	highlight.Parent = content
	local highlightPadding = Instance.new("UIPadding")
	highlightPadding.PaddingTop = UDim.new(0, 10)
	highlightPadding.PaddingBottom = UDim.new(0, 10)
	highlightPadding.PaddingLeft = UDim.new(0, 12)
	highlightPadding.PaddingRight = UDim.new(0, 12)
	highlightPadding.Parent = highlight

	local editor = Instance.new("TextBox")
	editor.Name = "Editor"
	editor.ClearTextOnFocus = false
	editor.MultiLine = true
	editor.TextWrapped = false
	editor.TextXAlignment = Enum.TextXAlignment.Left
	editor.TextYAlignment = Enum.TextYAlignment.Top
	editor.Font = Theme.fontMono
	editor.TextSize = 13
	editor.LineHeight = 1.35
	editor.TextColor3 = Theme.textBright
	editor.TextTransparency = 1
	editor.SelectionColor3 = Theme.bgSelected
	editor.BackgroundTransparency = 1
	editor.BorderSizePixel = 0
	editor.Position = UDim2.fromOffset(45, 0)
	editor.Size = UDim2.new(1, -45, 1, 0)
	editor.Text = ""
	editor.ZIndex = 2
	editor.Parent = content
	local editorPadding = Instance.new("UIPadding")
	editorPadding.PaddingTop = UDim.new(0, 10)
	editorPadding.PaddingBottom = UDim.new(0, 10)
	editorPadding.PaddingLeft = UDim.new(0, 12)
	editorPadding.PaddingRight = UDim.new(0, 12)
	editorPadding.Parent = editor

	local popup = Instance.new("Frame")
	popup.Name = "CompletionPopup"
	popup.Visible = false
	popup.BackgroundColor3 = Theme.bgRaised
	popup.BorderSizePixel = 0
	popup.Size = UDim2.fromOffset(280, 40)
	popup.ZIndex = 20
	popup.Parent = root
	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = Theme.radius.card
	popupCorner.Parent = popup
	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color = Theme.borderLight
	popupStroke.Parent = popup
	local popupList = Instance.new("UIListLayout")
	popupList.SortOrder = Enum.SortOrder.LayoutOrder
	popupList.Parent = popup

	local context = { schema = {}, typeIds = {} }
	local suggestions = {}
	local selectedIndex = 1
	local suppressChange = false
	local highlightGeneration = 0
	local metrics = {
		charWidth = 7.8,
		lineHeight = 18,
		gutterWidth = 44,
		padX = 12,
		padY = 10,
	}

	local function updateCanvas()
		local viewportSize = viewport.AbsoluteSize
		local size = EditorLayout.measure(editor.Text, viewportSize.X, viewportSize.Y, metrics)
		content.Size = UDim2.fromOffset(size.width, size.height)
		viewport.CanvasSize = UDim2.fromOffset(size.width, size.height)
		gutter.Size = UDim2.fromOffset(metrics.gutterWidth, size.height)
		divider.Size = UDim2.fromOffset(1, size.height)
		editor.Size = UDim2.fromOffset(math.max(1, size.width - 45), size.height)
		highlight.Size = editor.Size
	end

	local function fallbackRichText(source: string): string
		local safe = source:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
		return safe
	end

	local function scheduleHighlight()
		highlightGeneration += 1
		local generation = highlightGeneration
		task.defer(function()
			if generation ~= highlightGeneration or not root.Parent then
				return
			end
			local ok, richText = pcall(SyntaxHighlighter.render, editor.Text, context)
			highlight.Text = if ok then richText else fallbackRichText(editor.Text)
		end)
	end

	local function updateGutter()
		local lineCount = 1
		for _ in editor.Text:gmatch("\n") do
			lineCount += 1
		end
		local lines = table.create(lineCount)
		for line = 1, lineCount do
			lines[line] = tostring(line)
		end
		gutter.Text = table.concat(lines, "\n")
		updateCanvas()
	end

	local function clearPopupRows()
		for _, child in popup:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local acceptSelected: () -> ()

	local function renderPopup()
		clearPopupRows()
		if #suggestions == 0 or not editor:IsFocused() then
			popup.Visible = false
			return
		end
		selectedIndex = math.clamp(selectedIndex, 1, #suggestions)
		local visibleCount = math.min(#suggestions, 7)
		popup.Size = UDim2.fromOffset(math.min(300, math.max(200, root.AbsoluteSize.X - 16)), visibleCount * 34)
		local caret = EditorLayout.caretPoint(editor.Text, math.max(editor.CursorPosition, 1), metrics)
		local popupPoint = EditorLayout.popupPoint(
			caret,
			viewport.CanvasPosition.X,
			viewport.CanvasPosition.Y,
			viewport.AbsoluteSize.X,
			viewport.AbsoluteSize.Y,
			popup.Size.X.Offset,
			popup.Size.Y.Offset
		)
		popup.Position = UDim2.fromOffset(popupPoint.x, popupPoint.y)
		popup.Visible = true

		for index = 1, visibleCount do
			local item = suggestions[index]
			local row = Instance.new("TextButton")
			row.AutoButtonColor = false
			row.BackgroundColor3 = if index == selectedIndex then Theme.bgSelectedMuted else Theme.bgRaised
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, 0, 0, 34)
			row.Font = Theme.font
			row.TextSize = 12
			row.TextColor3 = Theme.textBright
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Text = `  {item.label}    {item.detail or ""}`
			row.TextTruncate = Enum.TextTruncate.AtEnd
			row.LayoutOrder = index
			row.ZIndex = 21
			row.Parent = popup
			row.MouseButton1Click:Connect(function()
				selectedIndex = index
				acceptSelected()
			end)
		end
	end

	local function refreshAssistance()
		if editor.CursorPosition <= 0 then
			popup.Visible = false
			return
		end
		suggestions = CompletionEngine.complete({
			source = editor.Text,
			cursor = editor.CursorPosition,
			schema = context.schema,
			typeIds = context.typeIds,
		})
		selectedIndex = 1
		renderPopup()
		if options.onDiagnostics then
			options.onDiagnostics(Diagnostics.analyze(editor.Text, context))
		end
	end

	acceptSelected = function()
		local item = suggestions[selectedIndex]
		if not item then
			return
		end
		local source, cursor = replaceRange(editor.Text, item.startByte, item.endByte, item.newText)
		suppressChange = true
		editor.Text = source
		editor.CursorPosition = cursor
		editor.SelectionStart = -1
		suppressChange = false
		popup.Visible = false
		if options.onChanged then
			options.onChanged(source, cursor, -1)
		end
	end

	editor:GetPropertyChangedSignal("Text"):Connect(function()
		updateGutter()
		scheduleHighlight()
		if not suppressChange and options.onChanged then
			options.onChanged(editor.Text, editor.CursorPosition, editor.SelectionStart)
		end
		task.defer(refreshAssistance)
	end)
	editor:GetPropertyChangedSignal("CursorPosition"):Connect(function()
		task.defer(refreshAssistance)
	end)
	editor.FocusLost:Connect(function()
		popup.Visible = false
	end)
	viewport:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if popup.Visible then
			renderPopup()
		end
	end)
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvas)

	local inputConnection = UserInputService.InputBegan:Connect(function(input)
		if not editor:IsFocused() then
			return
		end
		if popup.Visible then
			if input.KeyCode == Enum.KeyCode.Down then
				selectedIndex = math.min(selectedIndex + 1, math.min(#suggestions, 7))
				renderPopup()
			elseif input.KeyCode == Enum.KeyCode.Up then
				selectedIndex = math.max(selectedIndex - 1, 1)
				renderPopup()
			elseif input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.Return then
				acceptSelected()
			elseif input.KeyCode == Enum.KeyCode.Escape then
				popup.Visible = false
			end
		end
	end)

	return {
		root = root,
		setDocument = function(document)
			suppressChange = true
			editor.Text = document and document.source or ""
			editor.TextEditable = document ~= nil
			editor.CursorPosition = if document then math.clamp(document.cursor or 1, 1, #editor.Text + 1) else -1
			editor.SelectionStart = if document then document.selectionStart or -1 else -1
			suppressChange = false
			updateGutter()
			refreshAssistance()
		end,
		setContext = function(nextContext)
			context = nextContext or { schema = {}, typeIds = {} }
			scheduleHighlight()
			refreshAssistance()
		end,
		focus = function()
			editor:CaptureFocus()
		end,
		getText = function()
			return editor.Text
		end,
		destroy = function()
			inputConnection:Disconnect()
			root:Destroy()
		end,
	}
end

return CodeCanvas
