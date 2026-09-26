local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Widget = BUILib.Widget
local Layout = BUILib.Layout

local cachedTheme
local function GetTheme() if not cachedTheme then cachedTheme = BUILib.Theme end return cachedTheme end

local ipairs, select, unpack = ipairs, select, unpack
local math_abs = math.abs
local CreateFrame, GetCursorPosition, UIParent = CreateFrame, GetCursorPosition, UIParent

local Modals = BUILib.Modals

local SIZES = {
	width = 420,
	height = 180,
	buttonHeight = 28,
	buttonWidth = 100,
	buttonTextPadding = 14,
	buttonSpacing = 10,
	buttonBottomMargin = 20,
	titleFontSize = 18,
	messageFontSize = 14,
	buttonFontSize = 13,
	padding = 20,
	inputHeight = 28,
	inputWidth = 300,
}


local OFFSETS = {
	titleY = -25,
	messageY = 10,
	messageBelowTitle = -20,
	inputY = -10,
	labelGap = 6,
}

Modals.BTN_CONFIRM = {0.3, 1, 0.3, 1}
Modals.BTN_CANCEL = {1, 1, 1, 1}
Modals.BTN_NEUTRAL = {0.5, 0.5, 0.5, 1}
Modals.BTN_PRIMARY = {1, 1, 1, 1}
Modals.BTN_WARNING = {1, 0.6, 0.3, 1}

local OVERLAY_COLOR = {0, 0, 0, 0.7}

function Modals.BodyFont()
	local client = BUILib.GetActiveClient()
	return (client and client.bodyFont) or BUILib.Font
end

local defaultParent = nil

local function OnceGuard()
	local fired = false
	return function(callback, ...)
		if fired or not callback then return end
		fired = true
		callback(...)
	end
end

function Modals.CreateBase(width, height, bounded, parent)
	width = Widget.EvenSize(width or SIZES.width)
	height = Widget.EvenSize(height or SIZES.height)
	local theme = GetTheme()

	parent = parent or BUILib.GetActiveClient().popupParent or defaultParent
	local anchorParent = bounded and parent or UIParent

	local overlay = CreateFrame("Frame", nil, anchorParent, "BackdropTemplate")
	overlay.isBluUIWindow = true

	if bounded and parent then
		overlay:SetAllPoints(parent)
		overlay:SetFrameStrata(parent:GetFrameStrata())
		overlay:SetFrameLevel(parent:GetFrameLevel() + 100)
		overlay:EnableMouse(true)
	else
		overlay:SetAllPoints(UIParent)
		overlay:SetFrameStrata("FULLSCREEN_DIALOG")
		overlay:SetFrameLevel(100)
		overlay:EnableMouse(true)
	end

	overlay:SetBackdrop(Widget.BACKDROP_BORDERLESS)
	overlay:SetBackdropColor(unpack(OVERLAY_COLOR))
	overlay:EnableKeyboard(true)

	local dialog = Widget.New(overlay, "Frame", nil, {bg = theme.bg.panel, border = theme.border.dark, size = {width, height}}).frame
	dialog:SetPoint("CENTER")
	local client = BUILib.GetActiveClient()
	if client.modalColor then dialog:SetBackdropColor(unpack(client.modalColor)) end
	if client.modalBorderColor then dialog:SetBackdropBorderColor(unpack(client.modalBorderColor)) end
	dialog:SetFrameLevel(overlay:GetFrameLevel() + 10)
	dialog:EnableMouse(true)

	local closed = false
	local function Close()
		if closed then return end
		closed = true
		overlay:Hide()
	end

	overlay:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			Close()
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)

	local overlayAnim = overlay:CreateAnimationGroup()
	local fade = overlayAnim:CreateAnimation("Alpha")
	fade:SetFromAlpha(0)
	fade:SetToAlpha(1)
	fade:SetDuration(0.12)
	fade:SetSmoothing("OUT")
	overlayAnim:Play()

	overlay.dialog = dialog
	overlay.Close = Close

	return overlay, dialog, Close
end

function Modals.CreateButton(parent, text, textColor, width)
	width = width or SIZES.buttonWidth
	local theme = GetTheme()
	local normal, hover = theme.button.normal, theme.button.hover
	local button = Widget.New(parent, "Button", nil, {raw = true, size = {width, SIZES.buttonHeight}}).frame
	local client = BUILib.GetActiveClient()
	local fillColor = client.modalColor or normal
	local edgeColor = client.modalBorderColor or theme.border.default
	BUILib.Skin.Shell(button, { fill = fillColor, edge = edgeColor })

	button.text = button:CreateFontString(nil, "OVERLAY")
	button.text:SetFont(BUILib.Font, SIZES.buttonFontSize, "")
	button.text:SetShadowColor(0, 0, 0, 0)
	button.text:SetText(text or "OK")
	button.text:SetPoint("CENTER")
	button.text:SetTextColor(unpack(textColor or Modals.BTN_PRIMARY))

	button:SetScript("OnEnter", function(self)
		BUILib.Skin.SetShellFill(self, hover)
		local red, green, blue = theme.GetAccent()
		BUILib.Skin.SetShellEdges(self, { red, green, blue, 1 })
	end)
	button:SetScript("OnLeave", function(self)
		BUILib.Skin.SetShellFill(self, fillColor)
		BUILib.Skin.SetShellEdges(self, edgeColor)
	end)
	button:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 1, -1) end)
	button:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)

	return button
end

function Modals.CreateTitle(dialog, text, color)
	local theme = GetTheme()
	local title = dialog:CreateFontString(nil, "OVERLAY")
	title:SetFont(BUILib.Font, SIZES.titleFontSize, "")
	title:SetShadowColor(0, 0, 0, 0)
	title:SetPoint("TOP", 0, OFFSETS.titleY)
	title:SetText(text or "")
	title:SetTextColor(unpack(color or theme.text.primary))
	return title
end

function Modals.CreateMessage(dialog, text, justify, anchorTo, offsetY)
	local theme = GetTheme()
	local messageText = dialog:CreateFontString(nil, "OVERLAY")
	messageText:SetFont(Modals.BodyFont(), SIZES.messageFontSize, "")
	messageText:SetShadowColor(0, 0, 0, 0)

	if anchorTo then
		messageText:SetPoint("TOP", anchorTo, "BOTTOM", 0, offsetY or OFFSETS.messageBelowTitle)
	else
		messageText:SetPoint("CENTER", 0, OFFSETS.messageY)
	end

	messageText:SetWidth(dialog:GetWidth() - (SIZES.padding * 2))
	messageText:SetText(text or "")
	messageText:SetTextColor(unpack(theme.text.primary))
	messageText:SetJustifyH(justify or "CENTER")
	return messageText
end

function Modals.CreateInput(parent, defaultText, width, height)
	width = width or SIZES.inputWidth
	height = height or SIZES.inputHeight
	local theme = GetTheme()

	local input = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	input:SetSize(width, height)
	input:SetAutoFocus(true)
	input:SetFont(BUILib.Font, SIZES.messageFontSize, "")
	input:SetTextColor(unpack(theme.text.primary))
	input:SetTextInsets(8, 8, 0, 0)
	input:SetBackdrop(Widget.BACKDROP)
	input:SetBackdropColor(unpack(theme.bg.input))
	input:SetBackdropBorderColor(unpack(theme.border.input))
	input:SetText(defaultText or "")
	input:HighlightText()

	return input
end

function Modals.LayoutButtons(dialog, buttons, closeFunc, bottomMargin)
	if not buttons or #buttons == 0 then return end
	bottomMargin = bottomMargin or SIZES.buttonBottomMargin

	local created, widths, totalWidth = {}, {}, 0
	for index, buttonOptions in ipairs(buttons) do
		local button = Modals.CreateButton(dialog, buttonOptions.text, buttonOptions.color, buttonOptions.width)
		local fitted = math.ceil(button.text:GetStringWidth() + SIZES.buttonTextPadding * 2)
		local buttonWidth = Widget.EvenSize(math.max(buttonOptions.width or SIZES.buttonWidth, fitted))
		button:SetWidth(buttonWidth)
		created[index], widths[index] = button, buttonWidth
		totalWidth = totalWidth + buttonWidth
	end
	totalWidth = totalWidth + (SIZES.buttonSpacing * (#buttons - 1))

	local minimumDialogWidth = totalWidth + SIZES.padding * 2
	if dialog:GetWidth() < minimumDialogWidth then dialog:SetWidth(minimumDialogWidth) end

	local xOffset = -totalWidth / 2
	for index, button in ipairs(created) do
		local buttonOptions, buttonWidth = buttons[index], widths[index]
		button:SetPoint("BOTTOM", dialog, "BOTTOM", xOffset + buttonWidth / 2, bottomMargin)
		xOffset = xOffset + buttonWidth + SIZES.buttonSpacing

		if buttonOptions.onClick then
			button:SetScript("OnClick", function() buttonOptions.onClick(closeFunc) end)
		else
			button:SetScript("OnClick", closeFunc)
		end
	end
end

function Modals.Confirm(options)
	options = options or {}
	local bounded = not options.fullscreen
	local overlay, dialog, Close = Modals.CreateBase(options.width, options.height, bounded, options.parent)

	Modals.CreateTitle(dialog, options.title)
	Modals.CreateMessage(dialog, options.message)

	local fireOnce = OnceGuard()

	overlay:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			Close(); fireOnce(options.onCancel)
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)

	local buttons = {
		{text = options.confirmText or "Confirm", color = Modals.BTN_CONFIRM, width = options.buttonWidth,
			onClick = function(close) close(); fireOnce(options.onConfirm) end},
	}
	if options.laterText then
		buttons[#buttons + 1] = {text = options.laterText, color = Modals.BTN_PRIMARY, width = options.buttonWidth,
			onClick = function(close) close(); fireOnce(options.onLater) end}
	end
	buttons[#buttons + 1] = {text = options.cancelText or "Cancel", color = Modals.BTN_CANCEL, width = options.buttonWidth,
		onClick = function(close) close(); fireOnce(options.onCancel) end}

	Modals.LayoutButtons(dialog, buttons, Close)

	overlay:Show()
	return overlay, Close
end

function Modals.Message(options)
	options = options or {}
	local bounded = not options.fullscreen
	local overlay, dialog, Close = Modals.CreateBase(options.width, options.height, bounded, options.parent)

	Modals.CreateTitle(dialog, options.title, options.titleColor)
	Modals.CreateMessage(dialog, options.message)

	Modals.LayoutButtons(dialog, {
		{text = options.buttonText or "OK", color = Modals.BTN_CONFIRM, width = options.buttonWidth},
	}, Close)

	overlay:Show()
	return overlay, Close
end

function Modals.Input(options)
	options = options or {}
	local bounded = not options.fullscreen
	local overlay, dialog, Close = Modals.CreateBase(options.width or SIZES.width, options.height or 200, bounded, options.parent)

	Modals.CreateTitle(dialog, options.title, options.titleColor)

	local messageText = Modals.CreateMessage(dialog, options.message)
	messageText:ClearAllPoints()
	messageText:SetPoint("CENTER", 0, 25)

	local inputWidth = dialog:GetWidth() - 60
	local input = Modals.CreateInput(dialog, options.defaultText, inputWidth)
	input:SetPoint("CENTER", 0, OFFSETS.inputY)

	local fireOnce = OnceGuard()

	overlay:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			Close(); fireOnce(options.onCancel)
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)

	input:SetScript("OnEnterPressed", function()
		local text = input:GetText()
		Close(); fireOnce(options.onConfirm, text)
	end)
	input:SetScript("OnEscapePressed", function()
		Close(); fireOnce(options.onCancel)
	end)

	Modals.LayoutButtons(dialog, {
		{text = options.confirmText or "OK", color = Modals.BTN_CONFIRM, width = options.buttonWidth,
			onClick = function(close)
				local text = input:GetText()
				close(); fireOnce(options.onConfirm, text)
			end},
		{text = options.cancelText or "Cancel", color = Modals.BTN_CANCEL, width = options.buttonWidth,
			onClick = function(close) close(); fireOnce(options.onCancel) end},
	}, Close)

	overlay:Show()
	return overlay, Close
end

function Modals.Custom(options)
	options = options or {}
	local bounded = not options.fullscreen
	local overlay, dialog, Close = Modals.CreateBase(options.width, options.height, bounded, options.parent)
	local theme = GetTheme()

	local titleText = Modals.CreateTitle(dialog, options.title, options.titleColor)

	if options.message then
		local messageText = dialog:CreateFontString(nil, "OVERLAY")
		messageText:SetFont(Modals.BodyFont(), SIZES.messageFontSize, "")
		messageText:SetShadowColor(0, 0, 0, 0)
		messageText:SetPoint("TOP", titleText, "BOTTOM", 0, OFFSETS.messageBelowTitle)
		messageText:SetPoint("LEFT", dialog, "LEFT", SIZES.padding, 0)
		messageText:SetPoint("RIGHT", dialog, "RIGHT", -SIZES.padding, 0)
		messageText:SetText(options.message)
		messageText:SetTextColor(unpack(options.messageColor or theme.text.primary))
		messageText:SetJustifyH(options.justify or "CENTER")
		messageText:SetSpacing(4)
		dialog.message = messageText
	end

	if options.buttons and #options.buttons > 0 then
		Modals.LayoutButtons(dialog, options.buttons, Close)
	elseif options.showClose ~= false then
		Modals.LayoutButtons(dialog, {
			{text = options.buttonText or "Close", color = options.buttonColor or Modals.BTN_NEUTRAL},
		}, Close)
	end

	overlay:Show()
	return overlay, Close
end

local CARD_SIZES = {
	width = 220, height = 150, gap = 16,
	iconSize = 32, badgeFontSize = 10,
	titleFontSize = 13, descFontSize = 10,
}

local function MakeCard(parent, offsetX, cardOptions, accentRed, accentGreen, accentBlue, Close)
	local theme = GetTheme()
	local cardWidth, cardHeight = CARD_SIZES.width, CARD_SIZES.height

	local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
	card:SetSize(cardWidth, cardHeight)
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", offsetX, 0)
	card:SetBackdrop(Widget.BACKDROP)
	card:SetBackdropColor(unpack(theme.bg.card))
	card:SetBackdropBorderColor(unpack(theme.border.default))

	if cardOptions.recommended then
		local badge = card:CreateFontString(nil, "OVERLAY")
		badge:SetFont(BUILib.Font, CARD_SIZES.badgeFontSize, "OUTLINE")
		badge:SetPoint("TOP", 0, -10)
		badge:SetText("RECOMMENDED")
		badge:SetTextColor(accentRed, accentGreen, accentBlue, 1)
	end

	if cardOptions.icon then
		local iconFrame = CreateFrame("Frame", nil, card, "BackdropTemplate")
		iconFrame:SetSize(CARD_SIZES.iconSize + 2, CARD_SIZES.iconSize + 2)
		iconFrame:SetPoint("TOP", 0, -28)
		iconFrame:SetBackdrop(Widget.BACKDROP)
		iconFrame:SetBackdropColor(0, 0, 0, 1)
		iconFrame:SetBackdropBorderColor(0, 0, 0, 1)
		local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
		iconTexture:SetSize(CARD_SIZES.iconSize, CARD_SIZES.iconSize)
		iconTexture:SetPoint("CENTER")
		iconTexture:SetTexture(cardOptions.icon)
		iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end

	local title = card:CreateFontString(nil, "OVERLAY")
	title:SetFont(BUILib.Font, CARD_SIZES.titleFontSize, "OUTLINE")
	title:SetPoint("TOP", 0, -68)
	title:SetText(cardOptions.title)
	title:SetTextColor(unpack(theme.text.primary))
	title:SetWidth(cardWidth - 20)
	title:SetJustifyH("CENTER")

	local description = card:CreateFontString(nil, "OVERLAY")
	description:SetFont(BUILib.Font, CARD_SIZES.descFontSize, "")
	description:SetPoint("TOP", title, "BOTTOM", 0, -6)
	description:SetWidth(cardWidth - 24)
	description:SetText(cardOptions.desc)
	description:SetTextColor(unpack(theme.text.secondary))
	description:SetJustifyH("CENTER")
	description:SetSpacing(2)

	card:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(accentRed, accentGreen, accentBlue, 1) end)
	card:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(theme.border.default)) end)
	card:SetScript("OnClick", function()
		Close()
		if cardOptions.onClick then cardOptions.onClick() end
	end)
end

function Modals.CardPicker(options)
	options = options or {}
	local cards = options.cards or {}
	local cardCount = #cards
	if cardCount == 0 then return end

	local theme = GetTheme()
	local cardWidth = CARD_SIZES.width
	local totalCardsWidth = cardCount * cardWidth + (cardCount - 1) * CARD_SIZES.gap
	local modalWidth = options.width or (totalCardsWidth + 60)
	local modalHeight = options.height or 340

	local overlay, dialog, Close = Modals.CreateBase(modalWidth, modalHeight, false, options.parent)

	if options.onHide then
		local fired = false
		overlay:HookScript("OnHide", function()
			if fired then return end
			fired = true
			options.onHide()
		end)
	end

	local accentRed, accentGreen, accentBlue = theme.GetAccent()
	local title = Modals.CreateTitle(dialog, options.title, options.titleColor or {accentRed, accentGreen, accentBlue, 1})
	local messageText = Modals.CreateMessage(dialog, options.message, "CENTER", title)

	local cardArea = CreateFrame("Frame", nil, dialog)
	cardArea:SetSize(totalCardsWidth, CARD_SIZES.height)
	cardArea:SetPoint("TOP", messageText, "BOTTOM", 0, -16)

	for cardIndex, cardOptions in ipairs(cards) do
		local offsetX = (cardIndex - 1) * (cardWidth + CARD_SIZES.gap)
		MakeCard(cardArea, offsetX, cardOptions, accentRed, accentGreen, accentBlue, Close)
	end

	if options.dismissText then
		local dismissButton = Modals.CreateButton(dialog, options.dismissText, Modals.BTN_WARNING, options.dismissWidth or 140)
		dismissButton:SetPoint("BOTTOM", dialog, "BOTTOM", 0, SIZES.buttonBottomMargin)
		dismissButton:SetScript("OnClick", function()
			Close()
			if options.onDismiss then options.onDismiss() end
		end)
	end

	overlay:Show()
	return overlay, Close
end

local NUMBER = {
	width = 520,
	padding = 24,
	titleSize = 16,
	messageSize = 12,
	readoutSize = 32,
	hintSize = 11,
	trackHeight = 4,
	trackHit = 22,
	knobSize = 14,
	fieldWidth = 200,
	fieldHeight = 30,
	chipGap = 8,
	sectionGap = 22,
	buttonArea = 68,
}

local function TrimNumber(text)
	local whole, fraction = text:match('^(%-?%d+)%.(%d+)$')
	if not fraction then return text end
	fraction = fraction:gsub('0+$', '')
	if #fraction < 2 then fraction = fraction .. string.rep('0', 2 - #fraction) end
	return whole .. '.' .. fraction
end

function Modals.Number(options)
	options = options or {}
	local theme = GetTheme()
	local minimum, maximum = options.min or 0, options.max or 1
	local decimals = options.decimals or 2
	local wheelStep = options.wheelStep or (maximum - minimum) / 200
	local padding = NUMBER.padding
	local bounded = not options.fullscreen
	local overlay, dialog, Close = Modals.CreateBase(options.width or NUMBER.width, 400, bounded, options.parent)
	local innerWidth = dialog:GetWidth() - padding * 2
	local accentRed, accentGreen, accentBlue = theme.GetAccent()
	local fireOnce = OnceGuard()
	local value

	local function Clamp(number)
		if number < minimum then return minimum end
		if number > maximum then return maximum end
		return number
	end

	local function Format(number)
		return TrimNumber(('%.' .. decimals .. 'f'):format(number))
	end

	local function Cancel()
		Close()
		fireOnce(options.onCancel)
	end

	local function Confirm()
		Close()
		fireOnce(options.onConfirm, value)
	end

	overlay:SetScript('OnKeyDown', function(self, key)
		if key == 'ESCAPE' then
			self:SetPropagateKeyboardInput(false)
			Cancel()
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)

	local title = dialog:CreateFontString(nil, 'OVERLAY')
	title:SetFont(BUILib.Font, NUMBER.titleSize, '')
	title:SetShadowColor(0, 0, 0, 0)
	title:SetPoint('TOPLEFT', padding, -padding)
	title:SetText(options.title or '')
	title:SetTextColor(unpack(theme.text.primary))
	local y = padding + math.ceil(title:GetStringHeight())

	if options.message then
		local message = dialog:CreateFontString(nil, 'OVERLAY')
		message:SetFont(Modals.BodyFont(), NUMBER.messageSize, '')
		message:SetShadowColor(0, 0, 0, 0)
		message:SetPoint('TOPLEFT', padding, -(y + 6))
		message:SetWidth(innerWidth - 40)
		message:SetJustifyH('LEFT')
		message:SetSpacing(3)
		message:SetText(options.message)
		message:SetTextColor(unpack(theme.text.muted))
		y = y + 6 + math.ceil(message:GetStringHeight())
	end

	local closeButton = Widget.Unwrap(BUILib.Controls.Icon(dialog, { preset = 'close', size = 28, onClick = Cancel }))
	closeButton:SetPoint('TOPRIGHT', -10, -10)

	y = y + 18
	local divider = dialog:CreateTexture(nil, 'ARTWORK')
	divider:SetTexture(Widget.WHITE)
	divider:SetPoint('TOPLEFT', padding, -y)
	divider:SetPoint('TOPRIGHT', -padding, -y)
	divider:SetHeight(1)
	divider:SetVertexColor(accentRed, accentGreen, accentBlue, 0.25)

	y = y + NUMBER.sectionGap
	local readout = dialog:CreateFontString(nil, 'OVERLAY')
	readout:SetFont(BUILib.Font, NUMBER.readoutSize, '')
	readout:SetShadowColor(0, 0, 0, 0)
	readout:SetPoint('TOP', 0, -y)
	readout:SetTextColor(accentRed, accentGreen, accentBlue, 1)
	y = y + NUMBER.readoutSize + 6
	local hint = dialog:CreateFontString(nil, 'OVERLAY')
	hint:SetFont(Modals.BodyFont(), NUMBER.hintSize, '')
	hint:SetShadowColor(0, 0, 0, 0)
	hint:SetPoint('TOP', 0, -y)
	hint:SetTextColor(unpack(theme.text.muted))
	y = y + NUMBER.hintSize + NUMBER.sectionGap

	local track = CreateFrame('Button', nil, dialog)
	track:SetPoint('TOPLEFT', padding, -y)
	track:SetSize(innerWidth, NUMBER.trackHit)
	track:EnableMouseWheel(true)
	local rail = track:CreateTexture(nil, 'ARTWORK')
	rail:SetTexture(Widget.WHITE)
	rail:SetVertexColor(unpack(theme.control.track))
	rail:SetPoint('LEFT')
	rail:SetPoint('RIGHT')
	rail:SetHeight(NUMBER.trackHeight)
	local fill = track:CreateTexture(nil, 'ARTWORK', nil, 1)
	fill:SetTexture(Widget.WHITE)
	fill:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
	fill:SetPoint('LEFT')
	fill:SetHeight(NUMBER.trackHeight)
	local knob = track:CreateTexture(nil, 'OVERLAY')
	knob:SetTexture(BUILib.GetLibMedia('smoothdisc'))
	knob:SetSize(NUMBER.knobSize, NUMBER.knobSize)
	knob:SetVertexColor(unpack(theme.text.primary))
	y = y + NUMBER.trackHit + 4
	local lowLabel = dialog:CreateFontString(nil, 'OVERLAY')
	lowLabel:SetFont(Modals.BodyFont(), 10, '')
	lowLabel:SetShadowColor(0, 0, 0, 0)
	lowLabel:SetPoint('TOPLEFT', padding, -y)
	lowLabel:SetText(Format(minimum))
	lowLabel:SetTextColor(unpack(theme.text.muted))
	local highLabel = dialog:CreateFontString(nil, 'OVERLAY')
	highLabel:SetFont(Modals.BodyFont(), 10, '')
	highLabel:SetShadowColor(0, 0, 0, 0)
	highLabel:SetPoint('TOPRIGHT', -padding, -y)
	highLabel:SetText(Format(maximum))
	highLabel:SetTextColor(unpack(theme.text.muted))
	y = y + 12 + NUMBER.sectionGap

	local fieldLabel = dialog:CreateFontString(nil, 'OVERLAY')
	fieldLabel:SetFont(Modals.BodyFont(), NUMBER.messageSize, '')
	fieldLabel:SetShadowColor(0, 0, 0, 0)
	fieldLabel:SetPoint('TOPLEFT', padding, -(y + 8))
	fieldLabel:SetText(options.fieldLabel or 'Exact value')
	fieldLabel:SetTextColor(unpack(theme.text.primary))
	local field = CreateFrame('EditBox', nil, dialog)
	field:SetSize(NUMBER.fieldWidth, NUMBER.fieldHeight)
	field:SetPoint('TOPRIGHT', -padding, -y)
	field:SetAutoFocus(false)
	field:SetFont(BUILib.Font, 13, '')
	field:SetTextColor(unpack(theme.text.primary))
	field:SetTextInsets(10, 10, 0, 0)
	field:SetJustifyH('RIGHT')
	BUILib.Skin.Shell(field, { fill = theme.bg.input, edge = theme.border.input })
	y = y + NUMBER.fieldHeight

	local fieldFocused = false
	local function PaintField(invalid)
		local edge = theme.border.input
		if invalid then
			edge = Modals.BTN_WARNING
		elseif fieldFocused then
			edge = { accentRed, accentGreen, accentBlue, 1 }
		end
		BUILib.Skin.SetShellEdges(field, edge)
	end

	local function Set(newValue, source)
		value = Clamp(newValue)
		local fraction = maximum > minimum and (value - minimum) / (maximum - minimum) or 0
		readout:SetText(Format(value))
		hint:SetText(options.hint and options.hint(value, Format) or '')
		fill:SetWidth(math.max(1, fraction * innerWidth))
		knob:ClearAllPoints()
		knob:SetPoint('CENTER', track, 'LEFT', fraction * innerWidth, 0)
		if source ~= 'field' then field:SetText(Format(value)) end
		PaintField(false)
	end

	local function ValueAtCursor()
		local cursorX = GetCursorPosition() / track:GetEffectiveScale()
		local fraction = (cursorX - track:GetLeft()) / track:GetWidth()
		if fraction < 0 then fraction = 0 elseif fraction > 1 then fraction = 1 end
		return minimum + fraction * (maximum - minimum)
	end

	track:SetScript('OnMouseDown', function(self)
		Set(ValueAtCursor())
		field:ClearFocus()
		self:SetScript('OnUpdate', function(frame)
			if IsMouseButtonDown('LeftButton') then
				Set(ValueAtCursor())
			else
				frame:SetScript('OnUpdate', nil)
			end
		end)
	end)
	track:SetScript('OnMouseWheel', function(_, delta) Set(value + delta * wheelStep) end)

	field:SetScript('OnTextChanged', function(self, userInput)
		if not userInput then return end
		local parsed = tonumber(self:GetText())
		if parsed and parsed >= minimum and parsed <= maximum then
			Set(parsed, 'field')
		else
			PaintField(true)
		end
	end)
	field:SetScript('OnEditFocusGained', function(self)
		fieldFocused = true
		PaintField(false)
		self:HighlightText()
	end)
	field:SetScript('OnEditFocusLost', function(self)
		fieldFocused = false
		self:SetText(Format(value))
		PaintField(false)
	end)
	field:SetScript('OnEnterPressed', Confirm)
	field:SetScript('OnEscapePressed', Cancel)

	if options.presets and #options.presets > 0 then
		y = y + NUMBER.sectionGap
		local caption = dialog:CreateFontString(nil, 'OVERLAY')
		caption:SetFont(Modals.BodyFont(), 9, '')
		caption:SetShadowColor(0, 0, 0, 0)
		caption:SetPoint('TOPLEFT', padding, -y)
		caption:SetText((options.presetLabel or 'Quick picks'):upper())
		caption:SetTextColor(unpack(theme.text.muted))
		y = y + 18
		local x = padding
		for _, preset in ipairs(options.presets) do
			local chip = Modals.CreateButton(dialog, preset.label, Modals.BTN_PRIMARY, 60)
			chip:SetWidth(Widget.EvenSize(chip.text:GetStringWidth() + SIZES.buttonTextPadding * 2))
			chip:SetPoint('TOPLEFT', x, -y)
			chip:SetScript('OnClick', function()
				Set(preset.value)
				field:ClearFocus()
			end)
			x = x + chip:GetWidth() + NUMBER.chipGap
		end
		y = y + SIZES.buttonHeight
	end

	dialog:SetHeight(Widget.EvenSize(y + NUMBER.buttonArea))
	Modals.LayoutButtons(dialog, {
		{ text = options.confirmText or 'Apply', color = Modals.BTN_CONFIRM, width = options.buttonWidth, onClick = Confirm },
		{ text = options.cancelText or 'Cancel', color = Modals.BTN_CANCEL, width = options.buttonWidth, onClick = Cancel },
	}, Cancel)

	Set(options.value or minimum)
	overlay:Show()
	return overlay, Close
end

function Modals.SetParent(parent)
	defaultParent = parent
end

function Modals.Settings(options)
	options = options or {}
	local theme = GetTheme()
	local modalWidth = options.width or 500
	local modalHeight = options.height or 450
	local bounded = not options.fullscreen
	local contentPadding = options.padding or 16
	local titleHeight = 40
	local buttonAreaHeight = options.buttons and 56 or 0

	local overlay, dialog, Close = Modals.CreateBase(modalWidth, modalHeight, bounded, options.parent)

	local fireOnce = OnceGuard()

	overlay:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			Close(); fireOnce(options.onClose)
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)

	local accentRed, accentGreen, accentBlue = theme.GetAccent()

	if not options.noTitle then
		local titleFontString = dialog:CreateFontString(nil, "OVERLAY")
		titleFontString:SetFont(BUILib.Font, SIZES.titleFontSize, "OUTLINE")
		titleFontString:SetPoint("TOPLEFT", contentPadding, -12)
		titleFontString:SetText(options.title or "Settings")
		titleFontString:SetTextColor(accentRed, accentGreen, accentBlue, 1)

		if options.message then
			local subtitleFontString = dialog:CreateFontString(nil, "OVERLAY")
			subtitleFontString:SetFont(BUILib.Font, 11, "")
			subtitleFontString:SetPoint("TOPLEFT", titleFontString, "BOTTOMLEFT", 0, -4)
			subtitleFontString:SetPoint("RIGHT", dialog, "RIGHT", -40, 0)
			subtitleFontString:SetText(options.message)
			subtitleFontString:SetTextColor(unpack(theme.text.muted))
			subtitleFontString:SetJustifyH("LEFT")
			titleHeight = titleHeight + 18
		end
	end

	local closeButton = BUILib.Controls.Icon(dialog, { preset = "close", size = 28, onClick = function()
		Close(); fireOnce(options.onClose)
	end })
	local closeButtonFrame = closeButton.frame or closeButton
	closeButtonFrame:SetPoint("TOPRIGHT", -8, -8)

	local divider = dialog:CreateTexture(nil, "ARTWORK")
	divider:SetPoint("TOPLEFT", 1, -titleHeight)
	divider:SetPoint("TOPRIGHT", -1, -titleHeight)
	divider:SetHeight(1)
	divider:SetTexture(Widget.WHITE)
	divider:SetVertexColor(accentRed, accentGreen, accentBlue, 0.25)
	if options.noTitle then divider:Hide() end

	local scrollArea = CreateFrame("Frame", nil, dialog)
	scrollArea:SetPoint("TOPLEFT", 0, -titleHeight - 1)
	scrollArea:SetPoint("BOTTOMRIGHT", 0, buttonAreaHeight)

	local scrollFrame = CreateFrame("ScrollFrame", nil, scrollArea)
	scrollFrame:SetPoint("TOPLEFT", 4, -8)
	scrollFrame:SetPoint("BOTTOMRIGHT", -14, 4)

	local contentWidth = modalWidth - contentPadding * 2 - 18
	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetWidth(modalWidth - 24)
	scrollChild:SetHeight(100)
	scrollFrame:SetScrollChild(scrollChild)

	local track = CreateFrame("Frame", nil, scrollArea, "BackdropTemplate")
	track:SetPoint("TOPRIGHT", -4, -4)
	track:SetPoint("BOTTOMRIGHT", -4, 4)
	track:SetWidth(8)
	track:SetBackdrop(Widget.BACKDROP_BORDERLESS)
	track:SetBackdropColor(unpack(theme.scrollbar.track))
	track:Hide()

	local thumb = Widget.New(track, "Frame", nil, {bg = theme.scrollbar.thumb, border = theme.scrollbar.border, size = {8, 40}}).frame
	thumb:SetPoint("TOP", track, "TOP", 0, 0)
	thumb:EnableMouse(true)
	thumb:Hide()
	thumb:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(theme.scrollbar.thumbHover)) end)
	thumb:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(theme.scrollbar.thumb)) end)

	local scrollLogic = Widget.ScrollLogic(scrollFrame, scrollChild, track, thumb, {draggable = true})

	local contentWrapper = CreateFrame("Frame", nil, scrollChild)
	contentWrapper:SetPoint("TOPLEFT", contentPadding, 0)
	contentWrapper:SetWidth(contentWidth)
	contentWrapper:SetHeight(100)

	local topAnchor = CreateFrame("Frame", nil, contentWrapper)
	topAnchor:SetPoint("TOPLEFT", 0, 0)
	topAnchor:SetPoint("TOPRIGHT", 0, 0)
	topAnchor:SetHeight(1)

	local content = {
		frame = scrollArea,
		child = contentWrapper,
		scroll = scrollFrame,
		scrollChild = scrollChild,
		y = 0,
		width = contentWidth,
		contentWidth = contentWidth,
	}

	function content:GetContentHeight()

		local childTop = self.child:GetTop()
		if childTop then
			local lowest = 0
			local childCount = self.child:GetNumChildren()
			for childIndex = 1, childCount do
				local childFrame = select(childIndex, self.child:GetChildren())
				if childFrame and childFrame:IsShown() and childFrame.GetBottom and (childFrame:GetHeight() or 0) > 0 then
					local childBottom = childFrame:GetBottom()
					if childBottom then
						local distance = childTop - childBottom
						if distance > lowest then lowest = distance end
					end
				end
			end
			if lowest > 0 then return lowest end
		end
		local fallbackHeight = math_abs(self.y)
		if fallbackHeight < 20 then fallbackHeight = 40 end
		return fallbackHeight
	end

	function content:Refresh()
		local contentHeight = self:GetContentHeight() + contentPadding
		self.child:SetHeight(contentHeight)
		self.scrollChild:SetHeight(contentHeight)
		scrollLogic.UpdateThumb()
	end

	Layout.ApplyContentMixin(content)
	content.lastControl = topAnchor

	content.Close = Close
	content.overlay = overlay
	content.dialog = dialog

	if options.buttons and #options.buttons > 0 then
		local buttonDivider = dialog:CreateTexture(nil, "ARTWORK")
		buttonDivider:SetPoint("BOTTOMLEFT", 1, buttonAreaHeight)
		buttonDivider:SetPoint("BOTTOMRIGHT", -1, buttonAreaHeight)
		buttonDivider:SetHeight(1)
		buttonDivider:SetTexture(Widget.WHITE)
		buttonDivider:SetVertexColor(0.12, 0.12, 0.12, 1)
		if options.noTitle then buttonDivider:Hide() end

		local centeredMargin = (buttonAreaHeight - SIZES.buttonHeight) / 2
		Modals.LayoutButtons(dialog, options.buttons, function()
			Close(); fireOnce(options.onClose)
		end, centeredMargin)
	end

	overlay:Show()

	local activeClient = BUILib.GetActiveClient()
	local prevPopupStrata, prevPopupLevel, prevPopupParent = activeClient.popupStrata, activeClient.popupLevel, activeClient.popupParent
	BUILib.SetPopupParent(dialog)
	overlay:HookScript("OnHide", function()
		activeClient.popupStrata, activeClient.popupLevel, activeClient.popupParent = prevPopupStrata, prevPopupLevel, prevPopupParent
	end)

	BUILib.Defer(function()
		if content.Refresh then content:Refresh() end
	end)

	return content, Close
end
