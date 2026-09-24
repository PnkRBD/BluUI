local _, BUI = ...

local max, min = math.max, math.min
local GetCursorPosition = GetCursorPosition

local Pixel = BUI.Pixel
local Skin = BUI.Skinning
local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Widget = BUILib.Widget
local Controls = BUILib.Controls
local Colors = BUILib.Colors
local FONT = BUILib.Font or STANDARD_TEXT_FONT
local BACKDROP = Widget.BACKDROP

local SetColorTex = BUI.Tools.SetColorTex

function Skin.SmallButton(parent, width, height, label)
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(Pixel.Scale(width), Pixel.Scale(height))
	Skin.ApplyBackdrop(button, Colors.bg.light, Colors.border.default)

	local text = button:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(text, 11, FONT, '')
	text:SetPoint('CENTER')
	text:SetText(label)
	text:SetTextColor(0.9, 0.9, 0.9, 1)

	button:HookScript('OnEnter', function(self) self:SetBackdropBorderColor(Colors.GetAccent()) end)
	button:HookScript('OnLeave', function(self) self:SetBackdropBorderColor(unpack(Colors.border.default)) end)
	return button
end

local THUMB_IDLE  = { 0.35, 0.35, 0.35, 0.8 }
local THUMB_HOVER = { 0.5,  0.5,  0.5,  0.9 }
local TRACK_BG    = { 0.08, 0.08, 0.08, 0.5 }

function Skin.CreateScrollArea(parent, rowHeight, padding)
	rowHeight = rowHeight or 40
	padding = padding or 8

	local scroll = CreateFrame('ScrollFrame', nil, parent)
	scroll:SetPoint('TOPLEFT', Pixel.Scale(padding), Pixel.Scale(-padding))
	scroll:SetPoint('BOTTOMRIGHT', Pixel.Scale(-padding - 8), Pixel.Scale(padding))

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
		scroll:SetVerticalScroll(percent * maxScroll)
	end

	thumb:EnableMouse(true)
	thumb:RegisterForDrag('LeftButton')
	thumb:SetScript('OnDragStart', function(self) self.dragging = true end)
	thumb:SetScript('OnDragStop', function(self) self.dragging = false end)
	thumb:SetScript('OnUpdate', function(self)
		if self.dragging then ApplyScrollPct(CursorToScrollPct()) end
	end)
	thumb:SetScript('OnEnter', function() SetColorTex(thumbTex, unpack(THUMB_HOVER)) end)
	thumb:SetScript('OnLeave', function() SetColorTex(thumbTex, unpack(THUMB_IDLE)) end)
	track:EnableMouse(true)
	track:SetScript('OnMouseDown', function(_, button)
		if button == 'LeftButton' then ApplyScrollPct(CursorToScrollPct()) end
	end)

	scroll:EnableMouseWheel(true)
	scroll:SetScript('OnMouseWheel', function(self, delta)
		local currentScroll = self:GetVerticalScroll()
		local maxScroll = max(0, child:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(min(maxScroll, max(0, currentScroll - delta * rowHeight * 2)))
	end)

	scroll:SetScript('OnSizeChanged', function(_, width)
		if width and width > 0 then child:SetWidth(width) end
	end)

	scroll:SetScript('OnScrollRangeChanged', function(self, _, yMax)
		yMax = yMax or 0
		if yMax <= 0 then
			thumb:Hide()
			track:Hide()
			scroll:SetPoint('BOTTOMRIGHT', Pixel.Scale(-padding), Pixel.Scale(padding))
		else
			track:Show()
			thumb:Show()
			scroll:SetPoint('BOTTOMRIGHT', Pixel.Scale(-padding - 8), Pixel.Scale(padding))
			thumb:SetHeight(max(20, track:GetHeight() * (self:GetHeight() / (self:GetHeight() + yMax))))
		end
	end)

	scroll:SetScript('OnVerticalScroll', function(self, offset)
		local yMax = max(0, child:GetHeight() - self:GetHeight())
		if yMax <= 0 then return end
		thumb:ClearAllPoints()
		thumb:SetPoint('TOP', track, 'TOP', 0, -(offset / yMax) * (track:GetHeight() - thumb:GetHeight()))
	end)

	return scroll, child
end

function Skin.CreateSearchBox(parent, width, callback)
	local container = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	container:SetSize(Pixel.Scale(width), Pixel.Scale(24))
	container:SetBackdrop(BACKDROP)
	container:SetBackdropColor(unpack(Colors.bg.input or Colors.bg.medium))
	local idleBorder = Colors.border.input or Colors.border.default
	container:SetBackdropBorderColor(unpack(idleBorder))

	local hint = container:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(hint, 11, FONT, '')
	hint:SetPoint('LEFT', Pixel.Scale(8), 0)
	hint:SetText('Search...')
	hint:SetTextColor(0.35, 0.35, 0.35, 1)

	local editBox = CreateFrame('EditBox', nil, container)
	editBox:SetAllPoints()
	editBox:SetTextInsets(8, 8, 0, 0)
	Pixel.ApplyFont(editBox, 11, FONT, '')
	editBox:SetTextColor(0.9, 0.9, 0.9, 1)
	editBox:SetAutoFocus(false)
	editBox:SetScript('OnTextChanged', function(self, userInput)
		if not userInput then return end
		local text = self:GetText():lower()
		hint:SetShown(text == '')
		callback(text)
	end)
	editBox:SetScript('OnEscapePressed', function(self) self:SetText(''); self:ClearFocus() end)
	local function showAccent() container:SetBackdropBorderColor(Colors.GetAccent()) end
	local function showIdle() container:SetBackdropBorderColor(unpack(idleBorder)) end

	container:SetScript('OnEnter', showAccent)
	container:SetScript('OnLeave', function() if not editBox:HasFocus() then showIdle() end end)
	editBox:SetScript('OnEditFocusGained', showAccent)
	editBox:SetScript('OnEditFocusLost', showIdle)

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
	Pixel.ApplyFont(frame.titleText, 14, FONT, 'OUTLINE')
	frame.titleText:SetPoint('LEFT', Pixel.Scale(14), 0)
	frame.titleText:SetTextColor(1, 1, 1, 1)
	frame.titleText:SetText(title)

	local closeButton = Controls.Icon(frame, { preset = 'close', size = 20, onClick = onClose })
	closeButton:SetPoint('RIGHT', bar, 'RIGHT', Pixel.Scale(-8), 0)
	closeButton:SetFrameLevel(frame:GetFrameLevel() + 10)
	bar.closeBtn = closeButton

	return bar
end

function Skin.CreateListRow(parent, height, iconSize)
	height = height or 40
	iconSize = iconSize or 32

	local row = CreateFrame('Button', nil, parent, 'BackdropTemplate')
	row:SetHeight(Pixel.Scale(height))
	row:SetBackdrop(BACKDROP)
	row:SetBackdropColor(unpack(Colors.bg.medium))
	row:SetBackdropBorderColor(unpack(Colors.border.dark))
	row:EnableMouse(true)

	row.iconBorder = CreateFrame('Frame', nil, row, 'BackdropTemplate')
	row.iconBorder:SetSize(Pixel.Scale(iconSize + 2), Pixel.Scale(iconSize + 2))
	row.iconBorder:SetPoint('LEFT', Pixel.Scale(4), 0)
	row.iconBorder:SetBackdrop(BACKDROP)
	row.iconBorder:SetBackdropColor(0, 0, 0, 1)
	row.iconBorder:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)

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
	row.priceText:SetTextColor(0.65, 0.65, 0.65, 1)

	row:SetScript('OnEnter', function(self) self:SetBackdropBorderColor(Colors.GetAccent()) end)
	row:SetScript('OnLeave', function(self)
		self:SetBackdropBorderColor(unpack(Colors.border.dark))
		GameTooltip:Hide()
	end)

	return row
end

function Skin.GetPooledRow(pool, factory, parent, index)
	if not pool[index] then pool[index] = factory(parent) end
	return pool[index]
end

function Skin.CreateDropdown(parent, items, onSelect, width)
	width = width or 148

	local dropdown = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	dropdown:SetSize(Pixel.Scale(width), Pixel.Scale(24))
	dropdown:SetBackdrop(BACKDROP)
	dropdown:SetBackdropColor(unpack(Colors.bg.input or Colors.bg.medium))
	local idleBorder = Colors.border.input or Colors.border.default
	dropdown:SetBackdropBorderColor(unpack(idleBorder))

	local label = dropdown:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(label, 11, FONT, '')
	label:SetPoint('LEFT', Pixel.Scale(8), 0)
	label:SetPoint('RIGHT', Pixel.Scale(-16), 0)
	label:SetJustifyH('LEFT')
	label:SetTextColor(0.85, 0.85, 0.85, 1)
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
	menu:SetBackdrop(BACKDROP)
	menu:SetBackdropColor(0.04, 0.045, 0.05, 0.98)
	menu:SetBackdropBorderColor(unpack(Colors.border.default))
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
		text:SetTextColor(0.8, 0.8, 0.8, 1)

		local highlight = row:CreateTexture(nil, 'HIGHLIGHT')
		highlight:SetAllPoints()
		SetColorTex(highlight, 1, 1, 1, 0.06)

		row:SetScript('OnClick', function()
			label:SetText(item.label)
			menu:Hide()
			SetArrowOpen(false)
			onSelect(item)
		end)
	end
	menu:SetHeight(Pixel.Scale(#items * rowHeight + 4))

	dropdown:EnableMouse(true)
	dropdown:SetScript('OnMouseDown', function()
		if menu:IsShown() then
			menu:Hide()
			SetArrowOpen(false)
		else
			menu:Show()
			SetArrowOpen(true)
		end
	end)
	dropdown:SetScript('OnEnter', function(self) self:SetBackdropBorderColor(Colors.GetAccent()) end)
	dropdown:SetScript('OnLeave', function(self)
		if not menu:IsShown() then self:SetBackdropBorderColor(unpack(idleBorder)) end
	end)

	local grace = 0
	menu:SetScript('OnShow', function(menuFrame)
		grace = 0
		menuFrame:SetScript('OnUpdate', function(updatingMenu, elapsed)
			if dropdown:IsMouseOver() or updatingMenu:IsMouseOver() then
				grace = 0
			else
				grace = grace + elapsed
				if grace > 0.3 then
					updatingMenu:Hide()
					SetArrowOpen(false)
					dropdown:SetBackdropBorderColor(unpack(idleBorder))
				end
			end
		end)
	end)
	menu:SetScript('OnHide', function(menuFrame) menuFrame:SetScript('OnUpdate', nil) end)
	return dropdown
end

function Skin.CreateListHeader(parent, height)
	local header = CreateFrame('Frame', nil, parent)
	header:SetHeight(Pixel.Scale(height or 22))

	local text = header:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(text, 11, BUILib.Font or STANDARD_TEXT_FONT, 'OUTLINE')
	text:SetPoint('LEFT', Pixel.Scale(4), 0)
	text:SetTextColor(0.55, 0.55, 0.55)
	header.text = text

	local line = header:CreateTexture(nil, 'BACKGROUND')
	line:SetHeight(Pixel.PixelSize(1))
	line:SetPoint('LEFT', text, 'RIGHT', Pixel.Scale(6), 0)
	line:SetPoint('RIGHT', header, 'RIGHT', Pixel.Scale(-2), 0)
	line:SetColorTexture(0.22, 0.22, 0.22, 0.6)
	return header
end
