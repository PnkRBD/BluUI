local _, BUI = ...

local max, min = math.max, math.min
local GetCursorPosition = GetCursorPosition

local Pixel = BUI.Pixel
local Skin = BUI.Skinning
local Wrap = BUI.Profiler.Wrap
local BUILib = BluUI.BUILibClient
local Controls = BUILib.Controls
local FONT = BUILib.Font

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
Skin.PaintBackdrop = PaintBackdrop

local function HoverBorder(frame)
	frame:SetBackdropBorderColor(unpack(Skin.HoverColor()))
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
	button.label = text

	button:HookScript('OnEnter', Wrap('Skin.Widgets button OnEnter', HoverBorder))
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
	local contentHeight = Pixel.PixelSize(1)
	child:SetHeight(contentHeight)
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

	local function MaxScroll()
		return max(0, contentHeight - scroll:GetHeight())
	end

	local function ApplyScrollPct(percent)
		scroll:SetVerticalScroll(math.floor(percent * MaxScroll() + 0.5))
	end

	local function UpdateRange()
		local maxScroll = MaxScroll()
		if maxScroll <= 0 then
			thumb:Hide()
			track:Hide()
			scroll:SetPoint('BOTTOMRIGHT', Pixel.Scale(-padding), Pixel.Scale(padding))
		else
			track:Show()
			thumb:Show()
			scroll:SetPoint('BOTTOMRIGHT', Pixel.Scale(-padding - SCROLL_TRACK_SPACE), Pixel.Scale(padding))
			local height = scroll:GetHeight()
			thumb:SetHeight(max(20, track:GetHeight() * (height / (height + maxScroll))))
		end
	end

	hooksecurefunc(child, 'SetHeight', Wrap('Skin.Widgets content height', function(_, height)
		contentHeight = height
		UpdateRange()
	end))

	local DragUpdate = Wrap('Skin.Widgets scroll drag', function() ApplyScrollPct(CursorToScrollPct()) end)
	thumb:EnableMouse(true)
	thumb:RegisterForDrag('LeftButton')
	thumb:SetScript('OnDragStart', BUI.Profiler.Script('Skin.Widgets thumb OnDragStart', function(self) self:SetScript('OnUpdate', DragUpdate) end))
	thumb:SetScript('OnDragStop', BUI.Profiler.Script('Skin.Widgets thumb OnDragStop', function(self) self:SetScript('OnUpdate', nil) end))
	thumb:SetScript('OnEnter', BUI.Profiler.Script('Skin.Widgets thumb OnEnter', function() SetColorTex(thumbTex, unpack(THUMB_HOVER)) end))
	thumb:SetScript('OnLeave', BUI.Profiler.Script('Skin.Widgets thumb OnLeave', function() SetColorTex(thumbTex, unpack(THUMB_IDLE)) end))
	track:EnableMouse(true)
	track:SetScript('OnMouseDown', BUI.Profiler.Script('Skin.Widgets track OnMouseDown', function(_, button)
		if button == 'LeftButton' then ApplyScrollPct(CursorToScrollPct()) end
	end))

	scroll:EnableMouseWheel(true)
	scroll:SetScript('OnMouseWheel', BUI.Profiler.Script('Skin.Widgets scroll OnMouseWheel', function(self, delta)
		self:SetVerticalScroll(min(MaxScroll(), max(0, self:GetVerticalScroll() - delta * rowHeight * 2)))
	end))

	scroll:SetScript('OnSizeChanged', Wrap('Skin.Widgets scroll resize', function(_, width)
		if width > 0 then child:SetWidth(width) end
		UpdateRange()
	end))

	scroll:SetScript('OnVerticalScroll', Wrap('Skin.Widgets scroll thumb', function(_, offset)
		local maxScroll = MaxScroll()
		if maxScroll <= 0 then return end
		thumb:ClearAllPoints()
		thumb:SetPoint('TOP', track, 'TOP', 0, -(offset / maxScroll) * (track:GetHeight() - thumb:GetHeight()))
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
	local function showHover() HoverBorder(container) end
	local function showIdle() RestBorder(container) end

	container:SetScript('OnEnter', BUI.Profiler.Script('Skin.Widgets container OnEnter', showHover))
	container:SetScript('OnLeave', BUI.Profiler.Script('Skin.Widgets container OnLeave', function() if not editBox:HasFocus() then showIdle() end end))
	editBox:SetScript('OnEditFocusGained', BUI.Profiler.Script('Skin.Widgets editBox OnEditFocusGained', showHover))
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

local KIT_WINDOW = { font = FONT }

function KIT_WINDOW:Paint(region, role)
	if type(role) == 'function' then return Painter.Custom(region, role) end
	if region.SetTextColor then return Painter.Text(region, role) end
	return Painter.Tint(region, role)
end
KIT_WINDOW.Bind = KIT_WINDOW.Paint

function KIT_WINDOW:Fill(parent, role, layer, subLayer)
	local texture = parent:CreateTexture(nil, layer or 'BACKGROUND', nil, subLayer or 0)
	texture:SetTexture(BUILib.Widget.WHITE)
	return Painter.Tint(texture, role)
end

function KIT_WINDOW:SetFontRole(region, fontRole)
	local _, size, flags = region:GetFont()
	region:SetFont(BUI.ThemeFontPath(fontRole), size, flags)
	return region
end

local Kit = BUILib.Layout.TableKit(KIT_WINDOW)
Skin.Kit = Kit

local SWITCH_ROW_H, SWITCH_TEXT_GAP, SWITCH_TEXT_SIZE = 30, 8, 12

function Skin.Switch(parent, label, get, set, width)
	local cell = CreateFrame('Button', nil, parent)
	cell:SetSize(width, SWITCH_ROW_H)
	local switch = Kit.Switch(cell, get, set)
	switch:SetPoint('LEFT')
	switch.toggle:EnableMouse(false)
	local text = cell:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(text, SWITCH_TEXT_SIZE, FONT, '')
	text:SetPoint('LEFT', switch, 'RIGHT', SWITCH_TEXT_GAP, 0)
	text:SetText(label)
	Painter.Text(text, 'skinText')
	cell:SetScript('OnClick', BUI.Profiler.Script('Skin.Widgets switch OnClick', function() switch.toggle:Click() end))
	cell.Refresh = switch.Refresh
	return cell
end

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
	Skin.PaintPanelBackdrop(row.iconBorder)

	row.icon = row.iconBorder:CreateTexture(nil, 'ARTWORK')
	row.icon:SetSize(Pixel.Scale(iconSize), Pixel.Scale(iconSize))
	row.icon:SetPoint('CENTER')
	Skin.CropIcon(row.icon)

	row.nameText = row:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(row.nameText, 12, FONT, '')
	row.nameText:SetPoint('LEFT', row.iconBorder, 'RIGHT', Pixel.Scale(8), Pixel.Scale(6))
	row.nameText:SetJustifyH('LEFT')
	row.nameText:SetWordWrap(false)

	row.priceText = row:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(row.priceText, 10, FONT, '')
	row.priceText:SetPoint('LEFT', row.iconBorder, 'RIGHT', Pixel.Scale(8), Pixel.Scale(-8))
	Painter.Text(row.priceText, 'skinLabel')

	row:SetScript('OnEnter', BUI.Profiler.Script('Skin.Widgets row OnEnter', HoverBorder))
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
	dropdown:SetScript('OnEnter', BUI.Profiler.Script('Skin.Widgets dropdown OnEnter', HoverBorder))
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

local Motion = BUILib.Motion
local SLIDE = { easing = Motion.Ease.outCubic }
local SLIDE_TIME, DROP_TIME = 0.16, 0.24
local GRIP_SIZE, GRIP_X, ITEM_TEXT_GAP = 14, 8, 8

local function OrderIndex(order, key)
	for index, each in ipairs(order) do
		if each == key then return index end
	end
end

local function OrderCursor(list)
	local _, cursorY = GetCursorPosition()
	return cursorY / list:GetEffectiveScale() - list:GetTop()
end

local function PlaceOrder(list, duration, skip)
	for index, key in ipairs(list.order) do
		local item = list.items[key]
		if item ~= skip then Motion.To(item, 'y', -(index - 1) * list.step, duration, SLIDE) end
	end
end

local TrackOrder = Wrap('Skin.Widgets order drag', function(item)
	local list = item.list
	local count = #list.order
	local y = min(0, max(-(count - 1) * list.step, OrderCursor(list) - list.grab))
	Motion.To(item, 'y', y, 0)
	local target = min(count, max(1, math.floor(-y / list.step + 0.5) + 1))
	local index = OrderIndex(list.order, item.key)
	if target == index then return end
	table.remove(list.order, index)
	table.insert(list.order, target, item.key)
	PlaceOrder(list, SLIDE_TIME, item)
	list.onChange(list.order)
end)

local function StartOrderDrag(item)
	local list = item.list
	local _, _, _, _, offsetY = item:GetPoint(1)
	list.dragging = item
	list.grab = OrderCursor(list) - offsetY
	item:SetFrameLevel(list:GetFrameLevel() + 3)
	HoverBorder(item)
	item:SetScript('OnUpdate', TrackOrder)
end

local function StopOrderDrag(item)
	local list = item.list
	item:SetScript('OnUpdate', nil)
	list.dragging = nil
	item:SetFrameLevel(list:GetFrameLevel() + 1)
	if not item:IsMouseOver() then RestBorder(item) end
	Motion.To(item, 'y', -(OrderIndex(list.order, item.key) - 1) * list.step, DROP_TIME, SLIDE)
end

local function OrderLeave(item)
	if item.list.dragging ~= item then RestBorder(item) end
end

local function SetListOrder(list, order)
	if list.dragging then return end
	list.order = order
	PlaceOrder(list, 0)
end

function Skin.CreateOrderList(parent, spec)
	local list = CreateFrame('Frame', nil, parent)
	local width, height, gap = Pixel.Scale(spec.width), Pixel.Scale(spec.rowHeight), Pixel.Scale(spec.gap)
	list.step = height + gap
	list:SetSize(width, #spec.items * list.step - gap)
	list.order, list.onChange, list.items = spec.order, spec.onChange, {}
	for _, entry in ipairs(spec.items) do
		local item = CreateFrame('Button', nil, list)
		item:SetSize(width, height)
		item:SetPoint('TOPLEFT', list, 'TOPLEFT', 0, 0)
		item:SetFrameLevel(list:GetFrameLevel() + 1)
		PaintBackdrop(item, PALETTE.card)
		item.key, item.list = entry.key, list

		local grip = item:CreateTexture(nil, 'OVERLAY')
		BUILib.Widget.SetGlyph(grip, BUILib.GetLibMedia('grabber'))
		grip:SetSize(Pixel.Scale(GRIP_SIZE), Pixel.Scale(GRIP_SIZE))
		grip:SetPoint('LEFT', Pixel.Scale(GRIP_X), 0)
		Painter.Tint(grip, 'skinLabel')

		local text = item:CreateFontString(nil, 'OVERLAY')
		Pixel.ApplyFont(text, 11, FONT, '')
		text:SetPoint('LEFT', grip, 'RIGHT', Pixel.Scale(ITEM_TEXT_GAP), 0)
		text:SetPoint('RIGHT', Pixel.Scale(-ITEM_TEXT_GAP), 0)
		text:SetJustifyH('LEFT')
		text:SetWordWrap(false)
		text:SetText(entry.label)
		Painter.Text(text, 'skinText')

		item:RegisterForDrag('LeftButton')
		item:SetScript('OnDragStart', BUI.Profiler.Script('Skin.Widgets order OnDragStart', StartOrderDrag))
		item:SetScript('OnDragStop', BUI.Profiler.Script('Skin.Widgets order OnDragStop', StopOrderDrag))
		item:SetScript('OnEnter', BUI.Profiler.Script('Skin.Widgets order OnEnter', HoverBorder))
		item:SetScript('OnLeave', BUI.Profiler.Script('Skin.Widgets order OnLeave', OrderLeave))
		list.items[entry.key] = item
	end
	list.SetOrder = SetListOrder
	PlaceOrder(list, 0)
	return list
end

local function SetHeaderTitle(header, title)
	header.text:SetText(title:upper())
end

function Skin.CreateListHeader(parent, height)
	local header = CreateFrame('Frame', nil, parent)
	header:SetHeight(Pixel.Scale(height or 22))

	local text = header:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(text, 10, FONT, '')
	text:SetPoint('LEFT')
	Painter.Text(text, 'skinLabel')
	header.text = text
	header.SetTitle = SetHeaderTitle

	local line = header:CreateTexture(nil, 'BACKGROUND')
	line:SetHeight(Pixel.PixelSize(1))
	line:SetPoint('LEFT', text, 'RIGHT', Pixel.Scale(8), 0)
	line:SetPoint('RIGHT')
	Painter.Fill(line, 'skinBorder')
	return header
end
