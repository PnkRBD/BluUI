local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget

local floor, min, max, abs, format = math.floor, math.min, math.max, math.abs, string.format

local WIDTH = 256
local PAD = 12
local INNER = WIDTH - PAD * 2
local FIELD_HEIGHT = 150
local BAR_HEIGHT = 10
local KNOB_SIZE = 14
local ROW_HEIGHT = 28
local ALPHA_WIDTH = 58
local INPUT_GAP = 8
local SWATCH_SIZE = 15
local SWATCH_GAP = 3
local SWATCH_COUNT = 13
local LABEL_HEIGHT = 14
local GAP = 12
local BUTTON_WIDTH = 80
local ANCHOR_GAP = 8
local SCREEN_MARGIN = 8
local CHECKER = 5
local FADE_SECONDS = 0.12
local REOPEN_GUARD = 0.5

local SURFACE = { 0.055, 0.06, 0.068, 0.98 }
local EDGE = { 0.19, 0.2, 0.23, 1 }
local RULE = { 1, 1, 1, 0.07 }
local LABEL = { 0.5, 0.53, 0.58, 1 }
local HINT = { 0.36, 0.38, 0.42, 1 }
local SWATCH_EDGE = { 1, 1, 1, 0.08 }
local SWATCH_RING = { 1, 1, 1, 0.95 }
local SWATCH_RING_INNER = { 0, 0, 0, 0.6 }
local SECONDARY = { 0.16, 0.17, 0.2, 1 }
local SECONDARY_TEXT = { 0.86, 0.88, 0.9, 1 }
local BUTTON_HOVER = { 1, 1, 1, 0.1 }
local CHECKER_LIGHT, CHECKER_DARK = 0.32, 0.18
local HUE_STOPS = { { 1, 0, 0 }, { 1, 1, 0 }, { 0, 1, 0 }, { 0, 1, 1 }, { 0, 0, 1 }, { 1, 0, 1 }, { 1, 0, 0 } }
local OUTLINE_SIDES = {
	{ 'TOPLEFT', 'TOPRIGHT', 'SetHeight' },
	{ 'BOTTOMLEFT', 'BOTTOMRIGHT', 'SetHeight' },
	{ 'TOPLEFT', 'BOTTOMLEFT', 'SetWidth' },
	{ 'TOPRIGHT', 'BOTTOMRIGHT', 'SetWidth' },
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
	local sector = floor(hue)
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
	local maxChannel, minChannel = max(red, green, blue), min(red, green, blue)
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
	return format('%02X%02X%02X', floor(red * 255 + 0.5), floor(green * 255 + 0.5), floor(blue * 255 + 0.5))
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
	return abs(color[1] - red) < 0.01 and abs(color[2] - green) < 0.01 and abs(color[3] - blue) < 0.01
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
	recent[SWATCH_COUNT + 1] = nil
end

local function Solid(parent, layer, subLevel)
	local texture = parent:CreateTexture(nil, layer, nil, subLevel or 0)
	texture:SetTexture(Widget.WHITE)
	return texture
end

local function Disc(parent, size, subLevel)
	local disc = parent:CreateTexture(nil, 'OVERLAY', nil, subLevel)
	disc:SetTexture(BUILib.GetLibMedia('smoothdisc'))
	disc:SetSize(size, size)
	disc:SetPoint('CENTER')
	return disc
end

local function Outline(frame, color)
	local edges = {}
	for index, side in ipairs(OUTLINE_SIDES) do
		local edge = Solid(frame, 'OVERLAY', 6)
		edge:SetVertexColor(color[1], color[2], color[3], color[4])
		edge:SetPoint(side[1])
		edge:SetPoint(side[2])
		edge[side[3]](edge, 1)
		edges[index] = edge
	end
	return edges
end

local function Checker(parent, width, height)
	for row = 0, math.ceil(height / CHECKER) - 1 do
		for column = 0, math.ceil(width / CHECKER) - 1 do
			local cell = Solid(parent, 'BACKGROUND')
			local shade = (row + column) % 2 == 0 and CHECKER_LIGHT or CHECKER_DARK
			cell:SetVertexColor(shade, shade, shade, 1)
			cell:SetPoint('TOPLEFT', column * CHECKER, -row * CHECKER)
			cell:SetSize(min(CHECKER, width - column * CHECKER), min(CHECKER, height - row * CHECKER))
		end
	end
end

local function Knob(parent)
	local knob = CreateFrame('Frame', nil, parent)
	knob:SetSize(KNOB_SIZE, KNOB_SIZE)
	knob:SetFrameLevel(parent:GetFrameLevel() + 5)
	Disc(knob, KNOB_SIZE + 2, 0):SetVertexColor(0, 0, 0, 0.5)
	Disc(knob, KNOB_SIZE, 1):SetVertexColor(1, 1, 1, 1)
	knob.fill = Disc(knob, KNOB_SIZE - 4, 2)
	return knob
end

local function Label(parent, text, color)
	local label = parent:CreateFontString(nil, 'OVERLAY')
	label:SetFont(BUILib.Font, 10, '')
	label:SetTextColor(color[1], color[2], color[3], color[4])
	label:SetText(text)
	return label
end

local function Input(parent, width, letters)
	local box = CreateFrame('EditBox', nil, parent, 'BackdropTemplate')
	box:SetSize(width, ROW_HEIGHT)
	box:SetBackdrop(Widget.BACKDROP)
	box:SetBackdropColor(unpack(Theme.bg.input))
	box:SetBackdropBorderColor(unpack(Theme.border.input))
	box:SetAutoFocus(false)
	box:SetMaxLetters(letters)
	box:SetFont(BUILib.Font, 12, '')
	box:SetTextColor(1, 1, 1, 1)
	box:SetTextInsets(10, 10, 0, 0)
	box:SetScript('OnEditFocusGained', function(self)
		self:SetBackdropBorderColor(Theme.GetAccent())
		self:HighlightText()
	end)
	box:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
	return box
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

local function CursorFraction(region)
	local scale = region:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	local x = (cursorX / scale - region:GetLeft()) / region:GetWidth()
	local y = (cursorY / scale - region:GetBottom()) / region:GetHeight()
	return max(0, min(1, x)), max(0, min(1, y))
end

local function Swatch(parent)
	local swatch = CreateFrame('Button', nil, parent)
	swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
	swatch:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	local fill = Solid(swatch, 'ARTWORK')
	fill:SetAllPoints()
	Outline(swatch, SWATCH_EDGE)
	local ring = CreateFrame('Frame', nil, swatch)
	ring:SetAllPoints()
	Outline(ring, SWATCH_RING)
	local innerRing = CreateFrame('Frame', nil, ring)
	innerRing:SetPoint('TOPLEFT', 1, -1)
	innerRing:SetPoint('BOTTOMRIGHT', -1, 1)
	Outline(innerRing, SWATCH_RING_INNER)
	ring:Hide()
	function swatch:SetColor(color)
		self.color = color
		if color then fill:SetVertexColor(color[1], color[2], color[3], 1) end
	end
	function swatch:SetActive(active)
		self.active = active
		ring:SetShown(active)
	end
	swatch:SetScript('OnEnter', function(self)
		ring:Show()
		if self.tooltip then Widget.ShowTip(self, self.tooltip) end
	end)
	swatch:SetScript('OnLeave', function(self)
		ring:SetShown(self.active)
		Widget.HideTip()
	end)
	return swatch
end

local function FlatButton(parent, text, onClick)
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(BUTTON_WIDTH, ROW_HEIGHT)
	button.fill = Solid(button, 'BACKGROUND')
	button.fill:SetAllPoints()
	local hover = Solid(button, 'BACKGROUND', 1)
	hover:SetAllPoints()
	hover:SetVertexColor(BUTTON_HOVER[1], BUTTON_HOVER[2], BUTTON_HOVER[3], BUTTON_HOVER[4])
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

local picker
local lastClosedAnchor, lastClosedTime

local function BuildPicker()
	local frame = CreateFrame('Frame', 'BUILibColorPicker', UIParent)
	frame.isBluUIWindow = true
	frame:SetWidth(WIDTH)
	frame:EnableMouse(true)
	frame:Hide()
	local surface = Solid(frame, 'BACKGROUND')
	surface:SetAllPoints()
	surface:SetVertexColor(SURFACE[1], SURFACE[2], SURFACE[3], SURFACE[4])
	Outline(frame, EDGE)

	local field = CreateFrame('Frame', nil, frame)
	field:SetSize(INNER, FIELD_HEIGHT)
	local hueFill = Solid(field, 'ARTWORK', 0)
	hueFill:SetAllPoints()
	local whiteFade = Solid(field, 'ARTWORK', 1)
	whiteFade:SetAllPoints()
	whiteFade:SetGradient('HORIZONTAL', CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 0))
	local blackFade = Solid(field, 'ARTWORK', 2)
	blackFade:SetAllPoints()
	blackFade:SetGradient('VERTICAL', CreateColor(0, 0, 0, 1), CreateColor(0, 0, 0, 0))
	Outline(field, EDGE)
	local fieldKnob = Knob(field)

	local hueBar = CreateFrame('Frame', nil, frame)
	hueBar:SetSize(INNER, BAR_HEIGHT)
	local segmentWidth = INNER / 6
	for index = 1, 6 do
		local segment = Solid(hueBar, 'ARTWORK')
		segment:SetPoint('TOPLEFT', (index - 1) * segmentWidth, 0)
		segment:SetSize(segmentWidth + 1, BAR_HEIGHT)
		local from, to = HUE_STOPS[index], HUE_STOPS[index + 1]
		segment:SetGradient('HORIZONTAL', CreateColor(from[1], from[2], from[3], 1), CreateColor(to[1], to[2], to[3], 1))
	end
	Outline(hueBar, EDGE)
	local hueKnob = Knob(hueBar)

	local alphaBar = CreateFrame('Frame', nil, frame)
	alphaBar:SetSize(INNER, BAR_HEIGHT)
	Checker(alphaBar, INNER, BAR_HEIGHT)
	local alphaFill = Solid(alphaBar, 'ARTWORK')
	alphaFill:SetAllPoints()
	Outline(alphaBar, EDGE)
	local alphaKnob = Knob(alphaBar)
	local fadeStart, fadeEnd = CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1)

	local row = CreateFrame('Frame', nil, frame)
	row:SetSize(INNER, ROW_HEIGHT)
	local compare = CreateFrame('Frame', nil, row)
	compare:SetSize(ROW_HEIGHT, ROW_HEIGHT)
	compare:SetPoint('LEFT')
	Checker(compare, ROW_HEIGHT, ROW_HEIGHT)
	local before = Solid(compare, 'ARTWORK')
	before:SetPoint('TOPLEFT')
	before:SetPoint('BOTTOMLEFT')
	before:SetWidth(ROW_HEIGHT / 2)
	local after = Solid(compare, 'ARTWORK')
	after:SetPoint('TOPRIGHT')
	after:SetPoint('BOTTOMRIGHT')
	after:SetWidth(ROW_HEIGHT / 2)
	Outline(compare, EDGE)
	local revert = CreateFrame('Button', nil, compare)
	revert:SetPoint('TOPLEFT')
	revert:SetPoint('BOTTOMLEFT')
	revert:SetWidth(ROW_HEIGHT / 2)
	Widget.Tooltip(revert, 'Back to the colour you started with')

	local hexBox = Input(row, INNER - ROW_HEIGHT - INPUT_GAP, 7)
	hexBox:SetPoint('LEFT', compare, 'RIGHT', INPUT_GAP, 0)
	local alphaBox = Input(row, ALPHA_WIDTH, 3)
	alphaBox:SetPoint('RIGHT')
	alphaBox:SetTextInsets(10, 22, 0, 0)
	local percentSign = Label(alphaBox, '%', LABEL)
	percentSign:SetPoint('RIGHT', -10, 0)

	local rule = Solid(frame, 'ARTWORK')
	rule:SetVertexColor(RULE[1], RULE[2], RULE[3], RULE[4])
	rule:SetSize(INNER, 1)

	local sections = {}
	local function Section(title)
		local swatches = {}
		for index = 1, SWATCH_COUNT do swatches[index] = Swatch(frame) end
		local section = { label = Label(frame, title, LABEL), swatches = swatches }
		sections[#sections + 1] = section
		return section
	end
	local classes = Section('Class colours')
	for index, token in ipairs(CLASS_ORDER) do
		local red, green, blue = ClassColor(token)
		classes.swatches[index]:SetColor({ red, green, blue, 1 })
		classes.swatches[index].tooltip = CLASS_LABEL[token]
	end
	local saved = Section('Saved')
	local recent = Section('Recent')
	local savedHint = Label(frame, 'Nothing saved yet', HINT)
	local recentHint = Label(frame, 'Colours you pick show up here', HINT)

	local saveLink = CreateFrame('Button', nil, frame)
	local saveText = Label(saveLink, 'Save this colour', LABEL)
	saveText:SetPoint('RIGHT')
	saveLink:SetSize(math.ceil(saveText:GetStringWidth()), LABEL_HEIGHT)
	local function PaintLink()
		if saveLink:IsMouseOver() then saveText:SetTextColor(1, 1, 1, 1) else saveText:SetTextColor(Theme.GetAccent()) end
	end
	PaintLink()
	saveLink:SetScript('OnEnter', PaintLink)
	saveLink:SetScript('OnLeave', PaintLink)
	Theme.RegisterAccentElement(saveText, PaintLink)

	frame.h, frame.s, frame.v, frame.a = 0, 1, 1, 1
	frame.hasOpacity = true

	local function Render(notify)
		local red, green, blue = HSVtoRGB(frame.h, frame.s, frame.v)
		local hueRed, hueGreen, hueBlue = HSVtoRGB(frame.h, 1, 1)
		hueFill:SetVertexColor(hueRed, hueGreen, hueBlue, 1)
		fieldKnob:ClearAllPoints()
		fieldKnob:SetPoint('CENTER', field, 'BOTTOMLEFT', frame.s * INNER, frame.v * FIELD_HEIGHT)
		fieldKnob.fill:SetVertexColor(red, green, blue, 1)
		hueKnob:ClearAllPoints()
		hueKnob:SetPoint('CENTER', hueBar, 'LEFT', frame.h * INNER, 0)
		hueKnob.fill:SetVertexColor(hueRed, hueGreen, hueBlue, 1)
		fadeStart:SetRGBA(red, green, blue, 0)
		fadeEnd:SetRGBA(red, green, blue, 1)
		alphaFill:SetGradient('HORIZONTAL', fadeStart, fadeEnd)
		alphaKnob:ClearAllPoints()
		alphaKnob:SetPoint('CENTER', alphaBar, 'LEFT', frame.a * INNER, 0)
		alphaKnob.fill:SetVertexColor(red, green, blue, 1)
		local original = frame.original
		before:SetVertexColor(original[1], original[2], original[3], original[4])
		after:SetVertexColor(red, green, blue, frame.a)
		if not hexBox:HasFocus() then hexBox:SetText('#' .. RGBtoHex(red, green, blue)) end
		if not alphaBox:HasFocus() then alphaBox:SetText(tostring(floor(frame.a * 100 + 0.5))) end
		for _, section in ipairs(sections) do
			for _, swatch in ipairs(section.swatches) do
				swatch:SetActive(swatch.color ~= nil and Same(swatch.color, red, green, blue))
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

	Draggable(field, function()
		frame.s, frame.v = CursorFraction(field)
		Render(true)
	end)
	Draggable(hueBar, function()
		frame.h = min(0.999, (CursorFraction(hueBar)))
		Render(true)
	end)
	Draggable(alphaBar, function()
		frame.a = (CursorFraction(alphaBar))
		Render(true)
	end)

	revert:SetScript('OnClick', function() SetColor(unpack(frame.original)) end)

	hexBox:SetScript('OnEnterPressed', function(self)
		local red, green, blue = HexToRGB(self:GetText())
		self:ClearFocus()
		if red then SetColor(red, green, blue, frame.a) end
	end)
	alphaBox:SetScript('OnEnterPressed', function(self)
		local percent = tonumber(self:GetText())
		self:ClearFocus()
		if percent then
			frame.a = max(0, min(100, percent)) / 100
			Render(true)
		end
	end)
	for _, box in ipairs({ hexBox, alphaBox }) do
		box:SetScript('OnEditFocusLost', function(self)
			self:SetBackdropBorderColor(unpack(Theme.border.input))
			Render()
		end)
	end

	local function RefreshSaved()
		local favorites = Favorites()
		for index, swatch in ipairs(saved.swatches) do
			swatch:SetColor(favorites[index])
			swatch:SetShown(favorites[index] ~= nil)
		end
		savedHint:SetShown(#favorites == 0)
		saveLink:SetShown(#favorites < SWATCH_COUNT)
	end

	local function RefreshRecent()
		local colors = Recent()
		for index, swatch in ipairs(recent.swatches) do
			swatch:SetColor(colors[index])
			swatch:SetShown(colors[index] ~= nil)
		end
		recentHint:SetShown(#colors == 0)
	end

	for _, swatch in ipairs(classes.swatches) do
		swatch:SetScript('OnClick', function(self) SetColor(unpack(self.color)) end)
	end
	for index, swatch in ipairs(saved.swatches) do
		swatch.tooltip = 'Right-click to remove'
		swatch:SetScript('OnClick', function(self, button)
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
	for _, swatch in ipairs(recent.swatches) do
		swatch:SetScript('OnClick', function(self) SetColor(unpack(self.color)) end)
	end
	saveLink:SetScript('OnClick', function()
		local favorites = Favorites()
		local red, green, blue = HSVtoRGB(frame.h, frame.s, frame.v)
		favorites[#favorites + 1] = { red, green, blue, frame.a }
		RefreshSaved()
		Render()
	end)

	local function Finish()
		local red, green, blue = HSVtoRGB(frame.h, frame.s, frame.v)
		AddRecent(red, green, blue, frame.a)
		frame.confirmed = true
		if frame.callback then frame.callback(red, green, blue, frame.a, false, 'commit') end
		frame:Hide()
	end
	frame.Finish = Finish

	local cancel = FlatButton(frame, 'Cancel', function() frame:Hide() end)
	cancel.fill:SetVertexColor(SECONDARY[1], SECONDARY[2], SECONDARY[3], SECONDARY[4])
	cancel.label:SetTextColor(SECONDARY_TEXT[1], SECONDARY_TEXT[2], SECONDARY_TEXT[3], SECONDARY_TEXT[4])
	local done = FlatButton(frame, 'Done', Finish)
	local function PaintDone(_, red, green, blue)
		done.fill:SetVertexColor(red, green, blue, 1)
		done.label:SetTextColor(Theme.ReadableOn(red, green, blue))
	end
	PaintDone(nil, Theme.GetAccent())
	Theme.RegisterAccentElement(done, PaintDone)
	done:SetPoint('BOTTOMRIGHT', -PAD, PAD)
	cancel:SetPoint('RIGHT', done, 'LEFT', -INPUT_GAP, 0)

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

	local function Place(top, region)
		region:ClearAllPoints()
		region:SetPoint('TOPLEFT', PAD, -top)
	end

	function frame.Layout()
		local y = PAD
		Place(y, field)
		y = y + FIELD_HEIGHT + GAP
		Place(y, hueBar)
		y = y + BAR_HEIGHT + GAP
		alphaBar:SetShown(frame.hasOpacity)
		alphaBox:SetShown(frame.hasOpacity)
		if frame.hasOpacity then
			Place(y, alphaBar)
			y = y + BAR_HEIGHT + GAP
		end
		hexBox:SetWidth(frame.hasOpacity and (INNER - ROW_HEIGHT - ALPHA_WIDTH - INPUT_GAP * 2) or (INNER - ROW_HEIGHT - INPUT_GAP))
		Place(y + 2, row)
		y = y + 2 + ROW_HEIGHT + GAP
		Place(y, rule)
		y = y + 1 + GAP
		for _, section in ipairs(sections) do
			Place(y, section.label)
			if section == saved then
				saveLink:ClearAllPoints()
				saveLink:SetPoint('TOPRIGHT', frame, 'TOPLEFT', PAD + INNER, -y)
			end
			y = y + LABEL_HEIGHT + 4
			for index, swatch in ipairs(section.swatches) do
				swatch:ClearAllPoints()
				swatch:SetPoint('TOPLEFT', PAD + (index - 1) * (SWATCH_SIZE + SWATCH_GAP), -y)
			end
			local hint = section == saved and savedHint or section == recent and recentHint
			if hint then
				hint:ClearAllPoints()
				hint:SetPoint('LEFT', frame, 'TOPLEFT', PAD, -(y + SWATCH_SIZE / 2))
			end
			y = y + SWATCH_SIZE + GAP
		end
		frame:SetHeight(y + 2 + ROW_HEIGHT + PAD)
		RefreshSaved()
		RefreshRecent()
	end

	function frame.Position(anchor)
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
		if left + width > screenWidth - SCREEN_MARGIN then left = anchor:GetRight() - width end
		local top = anchor:GetBottom() - ANCHOR_GAP
		if top - height < SCREEN_MARGIN then top = anchor:GetTop() + ANCHOR_GAP + height end
		left = max(SCREEN_MARGIN, min(left, screenWidth - width - SCREEN_MARGIN))
		top = max(height + SCREEN_MARGIN, min(top, screenHeight - SCREEN_MARGIN))
		frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', left, top)
	end

	local fade = frame:CreateAnimationGroup()
	local fadeIn = fade:CreateAnimation('Alpha')
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(FADE_SECONDS)
	fadeIn:SetSmoothing('OUT')
	frame.fade = fade

	table.insert(UISpecialFrames, 'BUILibColorPicker')
	return frame
end

function Controls.OpenColorPicker(opts)
	opts = opts or {}
	if opts.anchorTo and opts.anchorTo == lastClosedAnchor and GetTime() - lastClosedTime < REOPEN_GUARD then
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
	picker.Position(opts.anchorTo)
	picker:Show()
	picker:Raise()
	picker.fade:Play()
end
