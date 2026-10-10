local _, BUI = ...

local max, min = math.max, math.min
local GetCursorPosition = GetCursorPosition

local Pixel = BUI.Pixel
local Skin = BUI.Skinning
local Wrap = BUI.Profiler.Wrap
local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Controls = BUILib.Controls
local Colors = BUILib.Colors
local FONT = BUILib.Font or STANDARD_TEXT_FONT

local SetColorTex = BUI.Tools.SetColorTex
local Painter = BUI.Painter
local PALETTE = Skin.PALETTE
local TITLE_SCALE = 14 / 12

local WINDOW_TITLE_HEIGHT = 36
local WINDOW_INSET = 12
local WINDOW_LEVEL = 100
local SLIDE_LEVEL = 50
local LIST_INSET, LIST_BOTTOM = 8, 12

local function PaintBackdrop(frame, fill)
	Painter.Custom(frame, function(target) Skin.ApplyBackdrop(target, fill, PALETTE.edge) end)
end

local function AccentBorder(frame)
	frame:SetBackdropBorderColor(Colors.GetAccent())
end

local function RestBorder(frame)
	frame:SetBackdropBorderColor(unpack(PALETTE.edge))
end

function Skin.SmallButton(parent, width, height, label)
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(Pixel.Scale(width), Pixel.Scale(height))
	PaintBackdrop(button, PALETTE.panel)

	local text = button:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(text, 11, FONT, '')
	text:SetPoint('CENTER')
	text:SetText(label)
	Painter.Text(text, 'skinText')

	button:HookScript('OnEnter', Wrap('Skin.Widgets button OnEnter', AccentBorder))
	button:HookScript('OnLeave', Wrap('Skin.Widgets button OnLeave', RestBorder))
	return button
end

local THUMB_IDLE  = { 0.35, 0.35, 0.35, 0.8 }
local THUMB_HOVER = { 0.5,  0.5,  0.5,  0.9 }
local TRACK_BG    = { 0.08, 0.08, 0.08, 0.5 }
local SCROLL_TRACK_SPACE = 20

function Skin.CreateScrollArea(parent, rowHeight, padding)
	rowHeight = rowHeight or 40
	padding = padding or 8

	local scroll = CreateFrame('ScrollFrame', nil, parent)
	scroll:SetPoint('TOPLEFT', Pixel.Scale(padding), Pixel.Scale(-padding))
	scroll:SetPoint('BOTTOMRIGHT', Pixel.Scale(-padding - SCROLL_TRACK_SPACE), Pixel.Scale(padding))

	local child = CreateFrame('Frame', nil, scroll)
	child:SetHeight(Pixel.PixelSize(1))
	scroll:SetScrollChild(child)

	local track = CreateFrame('Frame', nil, parent)
	track:SetWidth(Pixel.Scale(6))
	track:SetPoint('TOPRIGHT', Pixel.Scale(-2), Pixel.Scale(-padding))
	track:SetPoint('BOTTOMRIGHT', Pixel.Scale(-2), Pixel.Scale(padding))
	local trackBg = track:CreateTexture(nil, 'BACKGROUND')
	trackBg:SetAllPoints()
	SetColorTex(trackBg, unpack(TRACK_BG))

	local thumb = CreateFrame('Frame', nil, track)
	thumb:SetWidth(Pixel.Scale(6))
	thumb:SetHeight(Pixel.Scale(40))
	thumb:SetPoint('TOP')
	local thumbTex = thumb:CreateTexture(nil, 'OVERLAY')
	thumbTex:SetAllPoints()
	SetColorTex(thumbTex, unpack(THUMB_IDLE))

	local function CursorToScrollPct()
		local trackHeight = track:GetHeight()
		local thumbHeight = thumb:GetHeight()
		local usable = trackHeight - thumbHeight
		if usable <= 0 then return 0 end
		local scale = track:GetEffectiveScale()
		local _, cursorY = GetCursorPosition()
		local relativeY = cursorY - track:GetBottom() * scale - (thumbHeight * scale / 2)
		local percent = 1 - (relativeY / (usable * scale))
		return min(1, max(0, percent))
	end

	local function ApplyScrollPct(percent)
		local maxScroll = max(0, child:GetHeight() - scroll:GetHeight())
		scroll:SetVerticalScroll(math.floor(percent * maxScroll + 0.5))
	end

	thumb:EnableMouse(true)
	thumb:RegisterForDrag('LeftButton')
	thumb:SetScript('OnDragStart', BUI.Profiler.Script('Skin.Widgets thumb OnDragStart', function(self) self.dragging = true end))
	thumb:SetScript('OnDragStop', BUI.Profiler.Script('Skin.Widgets thumb OnDragStop', function(self) self.dragging = false end))
	thumb:SetScript('OnUpdate', Wrap('Skin.Widgets scroll drag', function(self)
		if self.dragging then ApplyScrollPct(CursorToScrollPct()) end
	end))
	thumb:SetScript('OnEnter', BUI.Profiler.Script('Skin.Widgets thumb OnEnter', function() SetColorTex(thumbTex, unpack(THUMB_HOVER)) end))
	thumb:SetScript('OnLeave', BUI.Profiler.Script('Skin.Widgets thumb OnLeave', function() SetColorTex(thumbTex, unpack(THUMB_IDLE)) end))
	track:EnableMouse(true)
	track:SetScript('OnMouseDown', BUI.Profiler.Script('Skin.Widgets track OnMouseDown', function(_, button)
		if button == 'LeftButton' then ApplyScrollPct(CursorToScrollPct()) end
	end))

	scroll:EnableMouseWheel(true)
	scroll:SetScript('OnMouseWheel', BUI.Profiler.Script('Skin.Widgets scroll OnMouseWheel', function(self, delta)
		local currentScroll = self:GetVerticalScroll()
		local maxScroll = max(0, child:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(min(maxScroll, max(0, currentScroll - delta * rowHeight * 2)))
	end))

	scroll:SetScript('OnSizeChanged', Wrap('Skin.Widgets scroll resize', function(_, width)
		if width and width > 0 then child:SetWidth(width) end
	end))

	scroll:SetScript('OnScrollRangeChanged', Wrap('Skin.Widgets scroll range', function(self, _, yMax)
		yMax = yMax or 0
		if yMax <= 0 then
			thumb:Hide()
			track:Hide()
			scroll:SetPoint('BOTTOMRIGHT', Pixel.Scale(-padding), Pixel.Scale(padding))
		else
			track:Show()
			thumb:Show()
			scroll:SetPoint('BOTTOMRIGHT', Pixel.Scale(-padding - SCROLL_TRACK_SPACE), Pixel.Scale(padding))
			thumb:SetHeight(max(20, track:GetHeight() * (self:GetHeight() / (self:GetHeight() + yMax))))
		end
	end))

	scroll:SetScript('OnVerticalScroll', Wrap('Skin.Widgets scroll thumb', function(self, offset)
		local yMax = max(0, child:GetHeight() - self:GetHeight())
		if yMax <= 0 then return end
		thumb:ClearAllPoints()
		thumb:SetPoint('TOP', track, 'TOP', 0, -(offset / yMax) * (track:GetHeight() - thumb:GetHeight()))
	end))

	return scroll, child
end

function Skin.CreateSearchBox(parent, width, callback)
	local container = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	container:SetSize(Pixel.Scale(width), Pixel.Scale(24))
	PaintBackdrop(container, PALETTE.panel)

	local hint = container:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(hint, 11, FONT, '')
	hint:SetPoint('LEFT', Pixel.Scale(8), 0)
	hint:SetText('Search...')
	Painter.Text(hint, 'skinLabel')

	local editBox = CreateFrame('EditBox', nil, container)
	editBox:SetAllPoints()
	editBox:SetTextInsets(8, 8, 0, 0)
	Pixel.ApplyFont(editBox, 11, FONT, '')
	Painter.Text(editBox, 'skinText')
	editBox:SetAutoFocus(false)
	editBox:SetScript('OnTextChanged', BUI.Profiler.Script('Skin.Widgets editBox OnTextChanged', function(self, userInput)
		if not userInput then return end
		local text = self:GetText():lower()
		hint:SetShown(text == '')
		callback(text)
	end))
	editBox:SetScript('OnEscapePressed', BUI.Profiler.Script('Skin.Widgets editBox OnEscapePressed', function(self)
		self:SetText('')
		self:ClearFocus()
		hint:Show()
		callback('')
	end))
	editBox:SetScript('OnEnterPressed', BUI.Profiler.Script('Skin.Widgets editBox OnEnterPressed', editBox.ClearFocus))
	local function showAccent() AccentBorder(container) end
	local function showIdle() RestBorder(container) end

	container:SetScript('OnEnter', BUI.Profiler.Script('Skin.Widgets container OnEnter', showAccent))
	container:SetScript('OnLeave', BUI.Profiler.Script('Skin.Widgets container OnLeave', function() if not editBox:HasFocus() then showIdle() end end))
	editBox:SetScript('OnEditFocusGained', BUI.Profiler.Script('Skin.Widgets editBox OnEditFocusGained', showAccent))
	editBox:SetScript('OnEditFocusLost', BUI.Profiler.Script('Skin.Widgets editBox OnEditFocusLost', showIdle))

	container.editBox = editBox
	container.hint = hint
	return container
end

function Skin.CreateTitleBar(frame, title, height, onClose)
	height = height or 36
	local bar = CreateFrame('Frame', nil, frame)
	bar:SetPoint('TOPLEFT', Pixel.Scale(1), Pixel.Scale(-1))
	bar:SetPoint('TOPRIGHT', Pixel.Scale(-1), Pixel.Scale(-1))
	bar:SetHeight(Pixel.Scale(height))

	frame.titleText = bar:CreateFontString(nil, 'OVERLAY')
	Skin.TipFont(frame.titleText, 'title', TITLE_SCALE)
	frame.titleText:SetPoint('LEFT', Pixel.Scale(12), 0)
	frame.titleText:SetText(title)

	local closeButton = Controls.Icon(frame, { preset = 'close', size = 20, onClick = onClose })
	closeButton:SetPoint('RIGHT', bar, 'RIGHT', Pixel.Scale(-8), 0)
	closeButton:SetFrameLevel(frame:GetFrameLevel() + 10)
	bar.closeBtn = closeButton

	return bar
end

local MENU_THEME = {}

function MENU_THEME:Color(role)
	return BUI.ThemeColor(role)
end

function MENU_THEME:FontPath(fontRole)
	return BUI.ThemeFontPath(fontRole)
end

Skin.MENU_THEME = MENU_THEME

function Skin.ContextMenu(items, options)
	options.window = MENU_THEME
	options.surface = options.surface or 'skinBackground'
	Controls.ContextMenu(items, options)
end

local function NewWindow(title, onClose, level)
	local frame = CreateFrame('Frame', nil, UIParent, 'BackdropTemplate')
	PaintBackdrop(frame, PALETTE.panel)
	frame:SetFrameLevel(level)
	frame:Hide()
	frame.titleBar = Skin.CreateTitleBar(frame, title, WINDOW_TITLE_HEIGHT, onClose)
	return frame
end

function Skin.CreatePanelWindow(title, onClose)
	return NewWindow(title, onClose, SLIDE_LEVEL)
end

function Skin.CreateListArea(frame, top, rowHeight, bottom)
	local area = CreateFrame('Frame', nil, frame)
	area:SetPoint('TOPLEFT', Pixel.Scale(LIST_INSET), Pixel.Scale(-top))
	area:SetPoint('BOTTOMRIGHT', Pixel.Scale(-LIST_INSET), Pixel.Scale(bottom or LIST_BOTTOM))
	local scroll, child = Skin.CreateScrollArea(area, rowHeight, 4)
	return area, scroll, child
end

function Skin.CreateEmptyText(parent, area)
	local label = parent:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(label, 11, FONT, '')
	label:SetPoint('CENTER', area)
	Painter.Text(label, 'skinLabel')
	label:Hide()
	return label
end

function Skin.CreateWindow(spec)
	local frame = NewWindow(spec.title or '', spec.onClose, WINDOW_LEVEL)
	frame:SetSize(Pixel.Scale(spec.width), Pixel.Scale(spec.height))
	Skin.MakeDraggable(frame, spec.dbKey, 'CENTER', spec.x or 0, spec.y or 0, spec.follow)
	frame:SetFrameStrata('DIALOG')
	frame:SetFrameLevel(WINDOW_LEVEL)
	local content = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
	PaintBackdrop(content, PALETTE.panel)
	content:SetPoint('BOTTOMRIGHT', Pixel.Scale(-WINDOW_INSET), Pixel.Scale(spec.contentBottom))
	frame.content = content
	function frame:SetContentTop(top)
		content:SetPoint('TOPLEFT', Pixel.Scale(WINDOW_INSET), Pixel.Scale(-top))
	end
	frame:SetContentTop(spec.contentTop)
	return frame
end

function Skin.CreateListRow(parent, height, iconSize)
	height = height or 40
	iconSize = iconSize or 32

	local row = CreateFrame('Button', nil, parent, 'BackdropTemplate')
	row:SetHeight(Pixel.Scale(height))
	PaintBackdrop(row, PALETTE.card)
	row:EnableMouse(true)

	row.iconBorder = CreateFrame('Frame', nil, row, 'BackdropTemplate')
	row.iconBorder:SetSize(Pixel.Scale(iconSize + 2), Pixel.Scale(iconSize + 2))
	row.iconBorder:SetPoint('LEFT', Pixel.Scale(4), 0)
	Pixel.SetTemplate(row.iconBorder, 0, 0, 0, 1, 0.15, 0.15, 0.15, 1, 1)

	row.icon = row.iconBorder:CreateTexture(nil, 'ARTWORK')
	row.icon:SetSize(Pixel.Scale(iconSize), Pixel.Scale(iconSize))
	row.icon:SetPoint('CENTER')
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.nameText = row:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(row.nameText, 12, FONT, '')
	row.nameText:SetPoint('LEFT', row.iconBorder, 'RIGHT', Pixel.Scale(8), Pixel.Scale(6))
	row.nameText:SetJustifyH('LEFT')
	row.nameText:SetWordWrap(false)

	row.priceText = row:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(row.priceText, 10, FONT, '')
	row.priceText:SetPoint('LEFT', row.iconBorder, 'RIGHT', Pixel.Scale(8), Pixel.Scale(-8))
	Painter.Text(row.priceText, 'skinLabel')

	row:SetScript('OnEnter', BUI.Profiler.Script('Skin.Widgets row OnEnter', AccentBorder))
	row:SetScript('OnLeave', BUI.Profiler.Script('Skin.Widgets row OnLeave', function(self)
		RestBorder(self)
		GameTooltip:Hide()
	end))

	return row
end

function Skin.CreateDropdown(parent, items, onSelect, width)
	width = width or 148

	local dropdown = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	dropdown:SetSize(Pixel.Scale(width), Pixel.Scale(24))
	PaintBackdrop(dropdown, PALETTE.panel)

	local label = dropdown:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(label, 11, FONT, '')
	label:SetPoint('LEFT', Pixel.Scale(8), 0)
	label:SetPoint('RIGHT', Pixel.Scale(-16), 0)
	label:SetJustifyH('LEFT')
	Painter.Text(label, 'skinText')
	label:SetText(items[1] and items[1].label or '')
	dropdown.label = label

	local arrow = Skin.TipArrow(dropdown)
	local function SetArrowOpen(isOpen)
		arrow:SetRotation(isOpen and math.pi or 0)
	end
	SetArrowOpen(false)

	local menu = CreateFrame('Frame', nil, dropdown, 'BackdropTemplate')
	menu:SetFrameStrata('FULLSCREEN_DIALOG')
	menu:SetPoint('TOPLEFT', dropdown, 'BOTTOMLEFT', 0, Pixel.Scale(-2))
	menu:SetWidth(Pixel.Scale(width))
	PaintBackdrop(menu, PALETTE.panel)
	menu:Hide()

	local rowHeight = 22
	for itemIndex, item in ipairs(items) do
		local row = CreateFrame('Button', nil, menu)
		row:SetHeight(Pixel.Scale(rowHeight))
		row:SetPoint('TOPLEFT', Pixel.Scale(2), Pixel.Scale(-(itemIndex - 1) * rowHeight - 2))
		row:SetPoint('RIGHT', menu, 'RIGHT', Pixel.Scale(-2), 0)

		local text = row:CreateFontString(nil, 'OVERLAY')
		Pixel.ApplyFont(text, 11, FONT, '')
		text:SetPoint('LEFT', Pixel.Scale(8), 0)
		text:SetJustifyH('LEFT')
		text:SetText(item.label)
		Painter.Text(text, 'skinText')

		local highlight = row:CreateTexture(nil, 'HIGHLIGHT')
		highlight:SetAllPoints()
		SetColorTex(highlight, 1, 1, 1, 0.06)

		row:SetScript('OnClick', BUI.Profiler.Script('Skin.Widgets row OnClick', function()
			label:SetText(item.label)
			menu:Hide()
			SetArrowOpen(false)
			onSelect(item)
		end))
	end
	menu:SetHeight(Pixel.Scale(#items * rowHeight + 4))

	dropdown:EnableMouse(true)
	dropdown:SetScript('OnMouseDown', BUI.Profiler.Script('Skin.Widgets dropdown OnMouseDown', function()
		if menu:IsShown() then
			menu:Hide()
			SetArrowOpen(false)
		else
			menu:Show()
			SetArrowOpen(true)
		end
	end))
	dropdown:SetScript('OnEnter', BUI.Profiler.Script('Skin.Widgets dropdown OnEnter', AccentBorder))
	dropdown:SetScript('OnLeave', BUI.Profiler.Script('Skin.Widgets dropdown OnLeave', function(self)
		if not menu:IsShown() then RestBorder(self) end
	end))

	local grace = 0
	local autoClose = Wrap('Skin.Widgets menu autoclose', function(updatingMenu, elapsed)
		if dropdown:IsMouseOver() or updatingMenu:IsMouseOver() then
			grace = 0
		else
			grace = grace + elapsed
			if grace > 0.3 then
				updatingMenu:Hide()
				SetArrowOpen(false)
				RestBorder(dropdown)
			end
		end
	end)
	menu:SetScript('OnShow', Wrap('Skin.Widgets menu open', function(menuFrame)
		grace = 0
		menuFrame:SetScript('OnUpdate', autoClose)
	end))
	menu:SetScript('OnHide', BUI.Profiler.Script('Skin.Widgets menu OnHide', function(menuFrame) menuFrame:SetScript('OnUpdate', nil) end))
	return dropdown
end

function Skin.CreateListHeader(parent, height)
	local header = CreateFrame('Frame', nil, parent)
	header:SetHeight(Pixel.Scale(height or 22))

	local text = header:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(text, 11, BUILib.Font or STANDARD_TEXT_FONT, 'OUTLINE')
	text:SetPoint('LEFT', Pixel.Scale(4), 0)
	Painter.Text(text, 'skinLabel')
	header.text = text

	local line = header:CreateTexture(nil, 'BACKGROUND')
	line:SetHeight(Pixel.PixelSize(1))
	line:SetPoint('LEFT', text, 'RIGHT', Pixel.Scale(6), 0)
	line:SetPoint('RIGHT', header, 'RIGHT', Pixel.Scale(-2), 0)
	Painter.Fill(line, 'skinBorder')
	return header
end
