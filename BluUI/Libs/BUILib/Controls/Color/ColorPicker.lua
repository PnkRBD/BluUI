local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget

local L = {
	WIDTH = 272,
	PAD = 14,
	RADIUS = 10,
	WHEEL = 200,
	WHEEL_INNER = 60,
	WHEEL_CROP = 28 / 256,
	WHEEL_OUTER = 97,
	READOUT_HEIGHT = 18,
	READOUT_GAP = 6,
	READOUT_BOX = 46,
	CENTER_DISC = 112,
	HEX_WIDTH = 120,
	HEX_SIZE = 18,
	VALUE_WIDTH = 60,
	VALUE_HEIGHT = 18,
	SWATCH_LABEL_SIZE = 18,
	KNOB_SIZE = 14,
	CROSS_SIZE = 14,
	CROSS_ARM = 2,
	TITLE_HEIGHT = 20,
	TITLE_SIZE = 13,
	PILL_WIDTH = 28,
	PILL_HEIGHT = 14,
	PILL_RADIUS = 4,
	SLIDER_HEIGHT = 32,
	SLIDER_GAP = 6,
	TRACK_HEIGHT = 8,
	TRACK_RADIUS = 4,
	ROW_HEIGHT = 28,
	DOT_SIZE = 14,
	DOT_GAP = 5,
	DOT_COUNT = 13,
	LABEL_HEIGHT = 14,
	GAP = 12,
	BUTTON_WIDTH = 80,
	BUTTON_RADIUS = 6,
	BUTTON_GAP = 8,
	ANCHOR_GAP = 8,
	SCREEN_MARGIN = 8,
	FADE_SECONDS = 0.12,
	REOPEN_GUARD = 0.5,
}
L.INNER = L.WIDTH - L.PAD * 2

local C = {
	SURFACE = { 0.055, 0.06, 0.068, 0.98 },
	EDGE = { 0.19, 0.2, 0.23, 1 },
	TRACK = { 0.14, 0.15, 0.175, 1 },
	TEXT = { 0.93, 0.94, 0.95, 1 },
	LABEL = { 0.5, 0.53, 0.58, 1 },
	HINT = { 0.36, 0.38, 0.42, 1 },
	CLEAR = { 0, 0, 0, 0 },
	WHITE = { 1, 1, 1, 1 },
	BLACK = { 0, 0, 0, 1 },
	DOT_EDGE = { 1, 1, 1, 0.12 },
	DOT_RING = { 1, 1, 1, 0.95 },
	SECONDARY = { 0.16, 0.17, 0.2, 1 },
	SECONDARY_TEXT = { 0.86, 0.88, 0.9, 1 },
	BUTTON_HOVER = { 1, 1, 1, 0.1 },
	KNOB_SHADOW = { 0, 0, 0, 0.5 },
}

local CLASS_ORDER = {
	'DEATHKNIGHT', 'DEMONHUNTER', 'DRUID', 'EVOKER', 'HUNTER',
	'MAGE', 'MONK', 'PALADIN', 'PRIEST', 'ROGUE',
	'SHAMAN', 'WARLOCK', 'WARRIOR',
}
local CLASS_LABEL = {
	DEATHKNIGHT = 'Death Knight', DEMONHUNTER = 'Demon Hunter', DRUID = 'Druid',
	EVOKER = 'Evoker', HUNTER = 'Hunter', MAGE = 'Mage', MONK = 'Monk',
	PALADIN = 'Paladin', PRIEST = 'Priest', ROGUE = 'Rogue', SHAMAN = 'Shaman',
	WARLOCK = 'Warlock', WARRIOR = 'Warrior',
}

local function HSVtoRGB(hue, saturation, value)
	if saturation == 0 then return value, value, value end
	hue = hue * 6
	local sector = math.floor(hue)
	local fraction = hue - sector
	local low = value * (1 - saturation)
	local falling = value * (1 - saturation * fraction)
	local rising = value * (1 - saturation * (1 - fraction))
	if sector == 0 then return value, rising, low
	elseif sector == 1 then return falling, value, low
	elseif sector == 2 then return low, value, rising
	elseif sector == 3 then return low, falling, value
	elseif sector == 4 then return rising, low, value
	else return value, low, falling end
end

local function RGBtoHSV(red, green, blue)
	local maxChannel, minChannel = math.max(red, green, blue), math.min(red, green, blue)
	local delta = maxChannel - minChannel
	local hue, saturation, value = 0, 0, maxChannel
	if maxChannel ~= 0 then
		saturation = delta / maxChannel
		if delta ~= 0 then
			if maxChannel == red then hue = ((green - blue) / delta) % 6
			elseif maxChannel == green then hue = (blue - red) / delta + 2
			else hue = (red - green) / delta + 4 end
			hue = hue / 6
			if hue < 0 then hue = hue + 1 end
		end
	end
	return hue, saturation, value
end

local function RGBtoHex(red, green, blue)
	return ('%02X%02X%02X'):format(math.floor(red * 255 + 0.5), math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5))
end

local function HexToRGB(text)
	local hex = text:match('^%s*#?(%x%x%x%x%x%x)%s*$')
	if not hex then return nil end
	return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function ClassColor(class)
	local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if classColor then return classColor.r, classColor.g, classColor.b end
	return 1, 1, 1
end

local function Same(color, red, green, blue)
	return math.abs(color[1] - red) < 0.01 and math.abs(color[2] - green) < 0.01 and math.abs(color[3] - blue) < 0.01
end

function Controls.SetColorPickerDB(getter) Controls.__pickerDBGetter = getter end

local function Favorites()
	local client = BUILib.GetActiveClient()
	local dbGetter = client.getDB or Controls.__pickerDBGetter
	local db = dbGetter and dbGetter()
	if not db or not db.general then return {} end
	local stored = db.general.colorPickerFavorites or {}
	local keys, list = {}, {}
	for key in pairs(stored) do
		if type(key) == 'number' then keys[#keys + 1] = key end
	end
	table.sort(keys)
	for _, key in ipairs(keys) do list[#list + 1] = stored[key] end
	db.general.colorPickerFavorites = list
	return list
end

local function Recent()
	local client = BUILib.GetActiveClient()
	client.__colorPickerRecent = client.__colorPickerRecent or {}
	return client.__colorPickerRecent
end

function Controls.ColorPickerSwatches()
	return Favorites(), Recent()
end

local function AddRecent(red, green, blue, alpha)
	local recent = Recent()
	for index = #recent, 1, -1 do
		if Same(recent[index], red, green, blue) then table.remove(recent, index) end
	end
	table.insert(recent, 1, { red, green, blue, alpha })
	recent[L.DOT_COUNT + 1] = nil
end

local function Solid(parent, layer, subLevel)
	local texture = parent:CreateTexture(nil, layer, nil, subLevel or 0)
	texture:SetTexture(Widget.WHITE)
	return texture
end

local function Disc(parent, size, layer, subLevel)
	local disc = parent:CreateTexture(nil, layer or 'OVERLAY', nil, subLevel or 0)
	disc:SetTexture(BUILib.GetLibMedia('smoothdisc'))
	disc:SetSize(size, size)
	disc:SetPoint('CENTER')
	return disc
end

local function Square(parent, size, layer, subLevel)
	local square = Solid(parent, layer, subLevel)
	square:SetSize(size, size)
	square:SetPoint('CENTER')
	return square
end

local function Checker(parent, layer, subLevel)
	local texture = parent:CreateTexture(nil, layer or 'BACKGROUND', nil, subLevel or 0)
	texture:SetTexture(BUILib.GetLibMedia('checker'), 'REPEAT', 'REPEAT', 'NEAREST')
	texture:SetHorizTile(true)
	texture:SetVertTile(true)
	return texture
end

local function Knob(parent)
	local knob = CreateFrame('Frame', nil, parent)
	knob:SetSize(L.KNOB_SIZE, L.KNOB_SIZE)
	knob:SetFrameLevel(parent:GetFrameLevel() + 5)
	Disc(knob, L.KNOB_SIZE + 2, 'OVERLAY', 0):SetVertexColor(unpack(C.KNOB_SHADOW))
	Disc(knob, L.KNOB_SIZE, 'OVERLAY', 1):SetVertexColor(1, 1, 1, 1)
	knob.fill = Disc(knob, L.KNOB_SIZE - 4, 'OVERLAY', 2)
	return knob
end

local function Cross(parent)
	local cross = CreateFrame('Frame', nil, parent)
	cross:SetSize(L.CROSS_SIZE, L.CROSS_SIZE)
	cross:SetFrameLevel(parent:GetFrameLevel() + 5)
	for _, arm in ipairs({ { L.CROSS_SIZE + 2, L.CROSS_ARM + 2 }, { L.CROSS_ARM + 2, L.CROSS_SIZE + 2 } }) do
		local shadow = Solid(cross, 'OVERLAY', 0)
		shadow:SetSize(arm[1], arm[2])
		shadow:SetPoint('CENTER')
		shadow:SetVertexColor(unpack(C.KNOB_SHADOW))
	end
	for _, arm in ipairs({ { L.CROSS_SIZE, L.CROSS_ARM }, { L.CROSS_ARM, L.CROSS_SIZE } }) do
		local bar = Solid(cross, 'OVERLAY', 1)
		bar:SetSize(arm[1], arm[2])
		bar:SetPoint('CENTER')
	end
	return cross
end

local function Label(parent, text, color, size)
	local label = parent:CreateFontString(nil, 'OVERLAY')
	label:SetFont(BUILib.Font, size or 10, '')
	label:SetTextColor(color[1], color[2], color[3], color[4])
	label:SetText(text)
	return label
end

local function Caption(parent, text)
	return Label(parent, text:upper(), C.LABEL)
end

local function DottedRule(parent)
	local rule = parent:CreateTexture(nil, 'ARTWORK')
	rule:SetTexture(BUILib.GetLibMedia('dots'), 'REPEAT', 'REPEAT', 'NEAREST')
	rule:SetHorizTile(true)
	rule:SetSize(L.INNER, 1)
	rule:SetVertexColor(unpack(C.EDGE))
	return rule
end

local function Link(parent, text, onClick, plain)
	local link = CreateFrame('Button', nil, parent)
	local label = Label(link, text, C.LABEL)
	label:SetPoint('RIGHT')
	link:SetSize(math.ceil(label:GetStringWidth()), L.LABEL_HEIGHT)
	link.label = label
	local function Paint()
		local hovered = link:IsMouseOver()
		if plain then
			if hovered then label:SetTextColor(Theme.GetAccent()) else label:SetTextColor(unpack(C.TEXT)) end
		elseif link.active or hovered then
			label:SetTextColor(1, 1, 1, 1)
		else
			label:SetTextColor(Theme.GetAccent())
		end
	end
	link.Paint = Paint
	Paint()
	link:SetScript('OnEnter', Paint)
	link:SetScript('OnLeave', Paint)
	link:SetScript('OnClick', function() onClick() end)
	Theme.RegisterAccentElement(label, Paint)
	return link
end

local function Draggable(region, onMove)
	region:EnableMouse(true)
	region:SetScript('OnMouseDown', function(self)
		onMove()
		self:SetScript('OnUpdate', function(dragged)
			if IsMouseButtonDown('LeftButton') then onMove() else dragged:SetScript('OnUpdate', nil) end
		end)
	end)
end

local function CursorOffset(region)
	local scale = region:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	local centerX, centerY = region:GetCenter()
	return cursorX / scale - centerX, cursorY / scale - centerY
end

local function CursorFraction(region)
	local scale = region:GetEffectiveScale()
	local cursorX = GetCursorPosition()
	return math.max(0, math.min(1, (cursorX / scale - region:GetLeft()) / region:GetWidth()))
end

local function Dot(parent)
	local dot = CreateFrame('Button', nil, parent)
	dot:SetSize(L.DOT_SIZE, L.DOT_SIZE)
	dot:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	local ring = Square(dot, L.DOT_SIZE, 'ARTWORK', 0)
	ring:SetVertexColor(unpack(C.DOT_RING))
	ring:Hide()
	local edge = Square(dot, L.DOT_SIZE - 2, 'ARTWORK', 1)
	edge:SetVertexColor(unpack(C.DOT_EDGE))
	local fill = Square(dot, L.DOT_SIZE - 4, 'ARTWORK', 2)
	function dot:SetColor(color)
		self.color = color
		if color then fill:SetVertexColor(color[1], color[2], color[3], 1) end
	end
	function dot:SetActive(active)
		self.active = active
		ring:SetShown(active)
	end
	dot:SetScript('OnEnter', function(self)
		ring:Show()
		if self.tooltip then Widget.ShowTip(self, self.tooltip) end
	end)
	dot:SetScript('OnLeave', function(self)
		ring:SetShown(self.active)
		Widget.HideTip()
	end)
	return dot
end

local function Pill(parent)
	local pill = CreateFrame('Button', nil, parent)
	pill:SetSize(L.PILL_WIDTH, L.PILL_HEIGHT)
	pill.fill = Widget.DrawCardShape(pill, L.PILL_RADIUS, C.WHITE, C.DOT_EDGE, 'ARTWORK', 0, 0)
	return pill
end

local function Button(parent, text, onClick)
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(L.BUTTON_WIDTH, L.ROW_HEIGHT)
	button.fill = Widget.DrawCardShape(button, L.BUTTON_RADIUS, C.SECONDARY, C.CLEAR, 'BACKGROUND', 0, 0)
	local hover = Widget.DrawCardShape(button, L.BUTTON_RADIUS, C.BUTTON_HOVER, C.CLEAR, 'BACKGROUND', 2, 0)
	hover:Hide()
	button.label = button:CreateFontString(nil, 'OVERLAY')
	button.label:SetFont(BUILib.Font, 12, '')
	button.label:SetPoint('CENTER')
	button.label:SetText(text)
	button:SetScript('OnEnter', function() hover:Show() end)
	button:SetScript('OnLeave', function() hover:Hide() end)
	button:SetScript('OnClick', function() onClick() end)
	return button
end

local function ValueBox(parent, width, justify, tooltip)
	local box = CreateFrame('EditBox', nil, parent)
	box:SetSize(width, L.VALUE_HEIGHT)
	box:SetHitRectInsets(-8, -4, -4, -2)
	box:SetAutoFocus(false)
	box:SetFont(BUILib.Font, 12, '')
	box:SetJustifyH(justify)
	box:SetTextColor(unpack(C.TEXT))
	box.underline = Solid(box, 'ARTWORK')
	box.underline:SetPoint('BOTTOMLEFT')
	box.underline:SetPoint('BOTTOMRIGHT')
	box.underline:SetHeight(1)
	box.underline:Hide()
	Widget.Tooltip(box, tooltip)
	box:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
	box:SetScript('OnEditFocusGained', function(self)
		self.underline:SetVertexColor(Theme.GetAccent())
		self.underline:Show()
		self:HighlightText()
	end)
	return box
end

local function Slider(parent, spec)
	local row = CreateFrame('Frame', nil, parent)
	row:SetSize(L.INNER, L.SLIDER_HEIGHT)
	row.spec = spec
	row.label = Label(row, spec.label, C.TEXT, 11)
	row.label:SetPoint('TOPLEFT')
	row.value = ValueBox(row, L.VALUE_WIDTH, 'RIGHT', 'Click to type a value')
	row.value:SetPoint('TOPRIGHT', 0, 2)
	local track = CreateFrame('Frame', nil, row)
	track:SetSize(L.INNER, L.TRACK_HEIGHT)
	track:SetPoint('BOTTOMLEFT')
	if spec.alpha then
		local checker = Checker(track)
		checker:SetPoint('TOPLEFT', L.TRACK_RADIUS, 0)
		checker:SetPoint('BOTTOMRIGHT', -L.TRACK_RADIUS, 0)
	end
	row.pieces = Widget.DrawRoundedRect(track, L.TRACK_RADIUS, C.TRACK, 'ARTWORK', 0, 0)
	row.track = track
	row.knob = Knob(track)
	return row
end

local function BuildHexBox(center)
	local hexBox = CreateFrame('EditBox', nil, center)
	hexBox:SetSize(L.HEX_WIDTH, 24)
	hexBox:SetPoint('CENTER', 0, -8)
	hexBox:SetAutoFocus(false)
	hexBox:SetMaxLetters(7)
	hexBox:SetFont(BUILib.Font, L.HEX_SIZE, '')
	hexBox:SetJustifyH('CENTER')
	hexBox:SetTextColor(unpack(C.TEXT))
	local underline = Solid(hexBox, 'ARTWORK')
	underline:SetPoint('BOTTOMLEFT', 10, 0)
	underline:SetPoint('BOTTOMRIGHT', -10, 0)
	underline:SetHeight(1)
	underline:Hide()
	hexBox.underline = underline
	hexBox:SetScript('OnEditFocusGained', function(self)
		underline:SetVertexColor(Theme.GetAccent())
		underline:Show()
		self:HighlightText()
	end)
	hexBox:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
	return hexBox
end

local function Position(frame, anchor)
	frame:ClearAllPoints()
	local parentScale = UIParent:GetEffectiveScale()
	local host = anchor or BUILib.GetPopupParent()
	local scale = host and host:GetEffectiveScale() or parentScale
	frame:SetScale(scale / parentScale)
	if not anchor then
		frame:SetPoint('CENTER', host or UIParent, 'CENTER')
		return
	end
	local screenWidth = UIParent:GetWidth() * parentScale / scale
	local screenHeight = UIParent:GetHeight() * parentScale / scale
	local width, height = frame:GetWidth(), frame:GetHeight()
	local left = anchor:GetLeft()
	if left + width > screenWidth - L.SCREEN_MARGIN then left = anchor:GetRight() - width end
	local top = anchor:GetBottom() - L.ANCHOR_GAP
	if top - height < L.SCREEN_MARGIN then top = anchor:GetTop() + L.ANCHOR_GAP + height end
	left = math.max(L.SCREEN_MARGIN, math.min(left, screenWidth - width - L.SCREEN_MARGIN))
	top = math.max(height + L.SCREEN_MARGIN, math.min(top, screenHeight - L.SCREEN_MARGIN))
	frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', math.floor(left + 0.5), math.floor(top + 0.5))
end

local picker
local lastClosedAnchor, lastClosedTime

local function BuildPicker()
	local frame = CreateFrame('Frame', 'BUILibColorPicker', UIParent)
	frame.isBluUIWindow = true
	frame:SetWidth(L.WIDTH)
	frame:EnableMouse(true)
	frame:Hide()
	Widget.DrawCardShape(frame, L.RADIUS, C.SURFACE, C.EDGE, 'BACKGROUND', 0, 0)

	local title = Label(frame, 'Color', C.TEXT, L.TITLE_SIZE)
	local after = Pill(frame)
	local before = Pill(frame)
	Widget.Tooltip(before, 'Back to the color you started with')

	local wheel = CreateFrame('Frame', nil, frame)
	wheel:SetSize(L.WHEEL, L.WHEEL)
	local ring = wheel:CreateTexture(nil, 'ARTWORK')
	ring:SetTexture(BUILib.GetLibMedia('wheel'))
	ring:SetAllPoints()
	ring:SetTexCoord(L.WHEEL_CROP, 1 - L.WHEEL_CROP, L.WHEEL_CROP, 1 - L.WHEEL_CROP)
	local wheelKnob = Cross(wheel)

	local center = CreateFrame('Frame', nil, wheel)
	center:SetSize(L.CENTER_DISC, L.CENTER_DISC)
	center:SetPoint('CENTER')
	center:EnableMouse(true)
	local swatchLabel = Label(center, 'COLOR', C.LABEL, L.SWATCH_LABEL_SIZE)
	swatchLabel:SetPoint('CENTER', 0, 16)
	local hexBox = BuildHexBox(center)
	local copy = CreateFrame('Button', nil, center)
	local copyLabel = Label(copy, 'Copy', C.TEXT)
	copyLabel:SetPoint('CENTER')
	copy:SetSize(math.ceil(copyLabel:GetStringWidth()), L.LABEL_HEIGHT)
	copy:SetPoint('CENTER', 0, -26)
	copy:SetScript('OnClick', function() hexBox:SetFocus() end)
	Widget.Tooltip(copy, 'Selects the hex so Ctrl+C copies it')

	frame.h, frame.s, frame.v, frame.a = 0, 1, 1, 1
	frame.hasOpacity = true

	local function Current()
		return HSVtoRGB(frame.h, frame.s, frame.v)
	end

	local function SetChannel(channel, fraction)
		local rgb = { Current() }
		rgb[channel] = fraction
		local hue, saturation, value = RGBtoHSV(rgb[1], rgb[2], rgb[3])
		frame.h = saturation > 0 and hue or frame.h
		frame.s, frame.v = saturation, value
	end

	local function Percent(fraction) return math.floor(fraction * 100 + 0.5) .. '%' end
	local function Byte(fraction) return tostring(math.floor(fraction * 255 + 0.5)) end
	local function FromPercent(text) local number = tonumber(text:match('%d+%.?%d*')) return number and number / 100 end
	local function FromByte(text) local number = tonumber(text:match('%d+')) return number and number / 255 end

	local specs = {
		{ label = 'Brightness', get = function() return frame.v end, set = function(x) frame.v = x end, text = Percent, parse = FromPercent,
			ends = function() return C.BLACK, { HSVtoRGB(frame.h, frame.s, 1) } end },
		{ label = 'Opacity', alpha = true, get = function() return frame.a end, set = function(x) frame.a = x end, text = Percent, parse = FromPercent,
			ends = function() local red, green, blue = Current() return { red, green, blue, 0 }, { red, green, blue, 1 } end },
	}
	local sliders = {}
	for index, spec in ipairs(specs) do sliders[index] = Slider(frame, spec) end

	local function Degrees(fraction) return math.floor(fraction * 360 + 0.5) .. '°' end
	local function FromDegrees(text) local number = tonumber(text:match('%d+%.?%d*')) return number and (number / 360) % 1 end
	local readouts = CreateFrame('Frame', nil, frame)
	readouts:SetSize(L.INNER, L.READOUT_HEIGHT * 2 + L.READOUT_GAP)
	local readoutSpecs = {
		{ label = 'H', tooltip = 'Hue, the angle around the ring. Click to type a value in degrees.', get = function() return frame.h end, set = function(x) frame.h = x end, text = Degrees, parse = FromDegrees },
		{ label = 'S', tooltip = 'Saturation, how far the color sits from white. Click to type a percentage.', get = function() return frame.s end, set = function(x) frame.s = x end, text = Percent, parse = FromPercent },
		{ label = 'V', tooltip = 'Value, how bright the color is. Click to type a percentage.', get = function() return frame.v end, set = function(x) frame.v = x end, text = Percent, parse = FromPercent },
	}
	for channel, entry in ipairs({ { 'R', 'Red' }, { 'G', 'Green' }, { 'B', 'Blue' } }) do
		readoutSpecs[#readoutSpecs + 1] = { label = entry[1], tooltip = entry[2] .. ', 0 to 255. Click to type a value.', get = function() return (select(channel, Current())) end, set = function(x) SetChannel(channel, x) end, text = Byte, parse = FromByte }
	end
	local column = L.INNER / 3
	for index, spec in ipairs(readoutSpecs) do
		local label = Label(readouts, spec.label, C.LABEL, 11)
		local groupWidth = label:GetStringWidth() + 6 + L.READOUT_BOX
		local slot, row = (index - 1) % 3, math.floor((index - 1) / 3)
		label:SetPoint('TOPLEFT', math.floor((slot + 0.5) * column - groupWidth / 2), -(row * (L.READOUT_HEIGHT + L.READOUT_GAP) + 2))
		spec.box = ValueBox(readouts, L.READOUT_BOX, 'CENTER', spec.tooltip)
		spec.box:SetPoint('LEFT', label, 'RIGHT', 6, 0)
		spec.box:SetHitRectInsets(-(label:GetStringWidth() + 10), -4, -4, -2)
	end

	local adjustCaption = Caption(frame, 'Adjust')

	local rule = DottedRule(frame)

	local sections = {}
	local function Section(caption, count)
		local dots = {}
		for index = 1, count do dots[index] = Dot(frame) end
		local section = { label = Caption(frame, caption), dots = dots }
		sections[#sections + 1] = section
		return section
	end
	local saved = Section('Saved', L.DOT_COUNT)
	local recent = Section('Recent', L.DOT_COUNT)
	local classes = Section('Class colors', L.DOT_COUNT)
	for index, token in ipairs(CLASS_ORDER) do
		local red, green, blue = ClassColor(token)
		classes.dots[index]:SetColor({ red, green, blue, 1 })
		classes.dots[index].tooltip = CLASS_LABEL[token]
	end
	saved.hint = Label(frame, 'Nothing saved yet', C.HINT)
	recent.hint = Label(frame, 'Colors you pick show up here', C.HINT)

	local function Render(notify)
		local red, green, blue = Current()
		local angle = frame.h * 2 * math.pi
		local radius = L.WHEEL_INNER + frame.s * (L.WHEEL_OUTER - L.WHEEL_INNER)
		wheelKnob:ClearAllPoints()
		wheelKnob:SetPoint('CENTER', wheel, 'CENTER', math.cos(angle) * radius, math.sin(angle) * radius)
		for _, spec in ipairs(readoutSpecs) do
			if not spec.box:HasFocus() then spec.box:SetText(spec.text(spec.get())) end
		end
		for _, slider in ipairs(sliders) do
			if slider:IsShown() then
				local spec = slider.spec
				local fraction = spec.get()
				local low, high = spec.ends()
				Widget.PaintGradientRect(slider.track, slider.pieces, 'HORIZONTAL', low, high)
				slider.knob:ClearAllPoints()
				slider.knob:SetPoint('CENTER', slider.track, 'LEFT', fraction * L.INNER, 0)
				slider.knob.fill:SetVertexColor(red, green, blue, spec.alpha and frame.a or 1)
				if not slider.value:HasFocus() then slider.value:SetText(spec.text(fraction)) end
			end
		end
		local original = frame.original
		before.fill:SetVertexColor(original[1], original[2], original[3], original[4])
		after.fill:SetVertexColor(red, green, blue, frame.a)
		swatchLabel:SetTextColor(red, green, blue, 1)
		if not hexBox:HasFocus() then hexBox:SetText('#' .. RGBtoHex(red, green, blue)) end
		for _, section in ipairs(sections) do
			for _, dot in ipairs(section.dots) do
				dot:SetActive(dot.color ~= nil and Same(dot.color, red, green, blue))
			end
		end
		if notify and frame.callback then frame.callback(red, green, blue, frame.a, false, 'preview') end
	end
	frame.Render = Render

	local function SetColor(red, green, blue, alpha)
		local hue, saturation, value = RGBtoHSV(red, green, blue)
		frame.h = saturation > 0 and hue or frame.h
		frame.s, frame.v = saturation, value
		frame.a = frame.hasOpacity and (alpha or 1) or 1
		Render(true)
	end

	Draggable(wheel, function()
		local dx, dy = CursorOffset(wheel)
		frame.h = (math.atan2(dy, dx) / (2 * math.pi)) % 1
		frame.s = math.max(0, math.min(1, (math.sqrt(dx * dx + dy * dy) - L.WHEEL_INNER) / (L.WHEEL_OUTER - L.WHEEL_INNER)))
		Render(true)
	end)
	local function Typed(box, spec)
		box:SetScript('OnEnterPressed', function(self)
			local fraction = spec.parse(self:GetText())
			self:ClearFocus()
			if fraction then
				spec.set(math.max(0, math.min(1, fraction)))
				Render(true)
			end
		end)
		box:SetScript('OnEditFocusLost', function(self)
			self.underline:Hide()
			Render()
		end)
	end
	for _, slider in ipairs(sliders) do
		Draggable(slider.track, function()
			slider.spec.set(CursorFraction(slider.track))
			Render(true)
		end)
		Typed(slider.value, slider.spec)
	end
	for _, spec in ipairs(readoutSpecs) do Typed(spec.box, spec) end

	before:SetScript('OnClick', function() SetColor(unpack(frame.original)) end)

	hexBox:SetScript('OnEnterPressed', function(self)
		local red, green, blue = HexToRGB(self:GetText())
		self:ClearFocus()
		if red then SetColor(red, green, blue, frame.a) end
	end)
	hexBox:SetScript('OnEditFocusLost', function(self)
		self.underline:Hide()
		Render()
	end)

	local function RefreshSaved()
		local favorites = Favorites()
		for index, dot in ipairs(saved.dots) do
			dot:SetColor(favorites[index])
			dot:SetShown(favorites[index] ~= nil)
		end
		saved.hint:SetShown(#favorites == 0)
		saved.link:SetShown(#favorites < L.DOT_COUNT)
	end

	local function RefreshRecent()
		local colors = Recent()
		for index, dot in ipairs(recent.dots) do
			dot:SetColor(colors[index])
			dot:SetShown(colors[index] ~= nil)
		end
		recent.hint:SetShown(#colors == 0)
		recent.link:SetShown(#colors > 0)
	end

	saved.link = Link(frame, 'Save this color', function()
		local favorites = Favorites()
		local red, green, blue = Current()
		favorites[#favorites + 1] = { red, green, blue, frame.a }
		RefreshSaved()
		Render()
	end, true)
	recent.link = Link(frame, 'Clear', function()
		wipe(Recent())
		RefreshRecent()
		Render()
	end, true)

	for _, dot in ipairs(classes.dots) do
		dot:SetScript('OnClick', function(self) SetColor(self.color[1], self.color[2], self.color[3], frame.a) end)
	end
	for index, dot in ipairs(saved.dots) do
		dot.tooltip = 'Right-click to remove'
		dot:SetScript('OnClick', function(self, button)
			if button == 'RightButton' then
				table.remove(Favorites(), index)
				Widget.HideTip()
				RefreshSaved()
				Render()
			else
				SetColor(unpack(self.color))
			end
		end)
	end
	for _, dot in ipairs(recent.dots) do
		dot:SetScript('OnClick', function(self) SetColor(unpack(self.color)) end)
	end

	local function Finish()
		local red, green, blue = Current()
		AddRecent(red, green, blue, frame.a)
		frame.confirmed = true
		if frame.callback then frame.callback(red, green, blue, frame.a, false, 'commit') end
		frame:Hide()
	end
	frame.Finish = Finish

	local cancel = Button(frame, 'Cancel', function() frame:Hide() end)
	cancel.label:SetTextColor(unpack(C.SECONDARY_TEXT))
	local done = Button(frame, 'Done', Finish)
	local function PaintDone(_, red, green, blue)
		done.fill:SetVertexColor(red, green, blue, 1)
		done.label:SetTextColor(Theme.ReadableOn(red, green, blue))
	end
	PaintDone(nil, Theme.GetAccent())
	Theme.RegisterAccentElement(done, PaintDone)
	done:SetPoint('BOTTOMRIGHT', -L.PAD, L.PAD)
	cancel:SetPoint('RIGHT', done, 'LEFT', -L.BUTTON_GAP, 0)

	local watcher = CreateFrame('Frame', nil, frame)
	watcher:SetScript('OnUpdate', function()
		local down = IsMouseButtonDown('LeftButton') or IsMouseButtonDown('RightButton')
		if down and not frame.wasDown and not frame:IsMouseOver() then
			if frame.anchor and frame.anchor:IsMouseOver() then
				lastClosedAnchor, lastClosedTime = frame.anchor, GetTime()
			end
			Finish()
		end
		frame.wasDown = down
	end)

	frame:SetScript('OnHide', function()
		if not frame.confirmed and frame.cancel then frame.cancel() end
		frame.confirmed, frame.cancel, frame.callback, frame.anchor = nil, nil, nil, nil
	end)

	local function Place(top, region, x)
		region:ClearAllPoints()
		region:SetPoint('TOPLEFT', x or L.PAD, -top)
	end

	local function PlaceRight(top, region)
		region:ClearAllPoints()
		region:SetPoint('TOPRIGHT', frame, 'TOPLEFT', L.PAD + L.INNER, -top)
	end

	function frame.Layout()
		local y = L.PAD
		Place(y + 3, title)
		PlaceRight(y + 3, after)
		before:ClearAllPoints()
		before:SetPoint('RIGHT', after, 'LEFT', -4, 0)
		y = y + L.TITLE_HEIGHT + L.GAP
		Place(y, wheel, L.PAD + math.floor((L.INNER - L.WHEEL) / 2))
		y = y + L.WHEEL + 6
		Place(y, readouts)
		y = y + readouts:GetHeight() + L.GAP
		Place(y, adjustCaption)
		y = y + L.LABEL_HEIGHT + 6
		for _, slider in ipairs(sliders) do
			local spec = slider.spec
			local shown = not spec.alpha or frame.hasOpacity
			slider:SetShown(shown)
			if shown then
				Place(y, slider)
				y = y + L.SLIDER_HEIGHT + L.SLIDER_GAP
			end
		end
		y = y + L.GAP - L.SLIDER_GAP
		Place(y, rule)
		y = y + 1 + L.GAP
		for _, section in ipairs(sections) do
			Place(y, section.label)
			if section.link then PlaceRight(y, section.link) end
			y = y + L.LABEL_HEIGHT + 4
			for index, dot in ipairs(section.dots) do
				dot:ClearAllPoints()
				dot:SetPoint('TOPLEFT', L.PAD + (index - 1) * (L.DOT_SIZE + L.DOT_GAP), -y)
			end
			if section.hint then
				section.hint:ClearAllPoints()
				section.hint:SetPoint('LEFT', frame, 'TOPLEFT', L.PAD, -(y + L.DOT_SIZE / 2))
			end
			y = y + L.DOT_SIZE + L.GAP
		end
		frame:SetHeight(y + 2 + L.ROW_HEIGHT + L.PAD)
		RefreshSaved()
		RefreshRecent()
	end

	local fade = frame:CreateAnimationGroup()
	local fadeIn = fade:CreateAnimation('Alpha')
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(L.FADE_SECONDS)
	fadeIn:SetSmoothing('OUT')
	frame.fade = fade

	table.insert(UISpecialFrames, 'BUILibColorPicker')
	return frame
end

function Controls.OpenColorPicker(opts)
	opts = opts or {}
	if opts.anchorTo and opts.anchorTo == lastClosedAnchor and GetTime() - lastClosedTime < L.REOPEN_GUARD then
		lastClosedAnchor = nil
		return
	end
	if not picker then picker = BuildPicker() end
	if picker:IsShown() then picker.Finish() end

	picker.hasOpacity = opts.hasOpacity ~= false
	local red, green, blue = opts.r or 1, opts.g or 1, opts.b or 1
	local alpha = picker.hasOpacity and (opts.a or 1) or 1
	picker.original = { red, green, blue, alpha }
	picker.h, picker.s, picker.v = RGBtoHSV(red, green, blue)
	picker.a = alpha
	picker.callback = opts.callback
	picker.cancel = opts.callback and function() opts.callback(red, green, blue, alpha, true, 'cancel') end
	picker.anchor = opts.anchorTo
	picker.wasDown = IsMouseButtonDown('LeftButton') or IsMouseButtonDown('RightButton')

	picker.Layout()
	picker.Render()
	picker:SetFrameStrata(BUILib.GetPopupStrata())
	picker:SetFrameLevel(BUILib.GetPopupLevel())
	Position(picker, opts.anchorTo)
	picker:Show()
	picker:Raise()
	picker.fade:Play()
end
