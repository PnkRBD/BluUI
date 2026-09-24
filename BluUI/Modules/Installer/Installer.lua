local _, BUI = ...
local BUILib = LibStub('BUILib')
local Widget = BUILib.Widget
local Theme = BUILib.Theme
local Controls = BUILib.Controls
local Animation = BUI.Animation
local sharedMedia = LibStub('LibSharedMedia-3.0')

local Installer = {}
BUI.Installer = Installer

local DIALOG_WIDTH, DIALOG_HEIGHT = 520, 600
local OVERLAY_DIM = { 0, 0, 0, 0.75 }
local TEXT_BODY = { 0.87, 0.87, 0.9, 1 }
local TEXT_BRIGHT = { 0.95, 0.95, 0.97, 1 }
local TEXT_LABEL = { 0.55, 0.55, 0.6, 1 }
local BUTTON_HEIGHT = 26
local BUTTON_PADDING = 18
local NEXT_MIN_WIDTH = 96
local WELCOME_BUTTON_WIDTH = 180
local CHOICE_REST_FILL = { 0.03, 0.03, 0.036, 0.97 }
local CHOICE_HOVER_FILL = { 0.06, 0.062, 0.07, 0.97 }
local CHOICE_SELECTED_FILL = { 0.075, 0.078, 0.088, 0.97 }
local HEADLINE_SIZE = 32

local wizard
local STEPS
local skinSelection

local function Skin() return BUI.Skinning end
local function PanelFill() return BUI.Skinning.PANEL_FILL end
local function PanelEdge() return BUI.Skinning.PANEL_EDGE end
local function Accent() return Theme.GetAccent() end

local function PlayerClassColor()
	local _, class = UnitClass('player')
	local classColor = class and RAID_CLASS_COLORS[class]
	if classColor then return classColor.r, classColor.g, classColor.b end
	return 0.8, 0.8, 0.8
end

local function AccentHex()
	local red, green, blue = Accent()
	return ('%02x%02x%02x'):format(math.floor(red * 255 + 0.5), math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5))
end

local function RefreshAddonAccent()
	BUI.BUILibClient.Colors.RefreshAccent()
end

local function SetColor(fontString, color)
	fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function MakeText(parent, size, text, color)
	local fontString = parent:CreateFontString(nil, 'OVERLAY')
	fontString:SetFont(BUILib.Font, size, '')
	fontString:SetShadowColor(0, 0, 0, 0)
	fontString:SetShadowOffset(0, 0)
	fontString:SetText(text or '')
	SetColor(fontString, color or TEXT_BODY)
	return fontString
end

local function MakeButton(parent, text, width, onClick)
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(width, BUTTON_HEIGHT)
	Skin().TipButton(button)
	button:SetText(text)
	button:SetScript('OnClick', onClick)
	return button
end

local function FitButton(button, minWidth)
	local text = button:GetFontString()
	local width = text and (text:GetStringWidth() + 2 * BUTTON_PADDING) or 0
	button:SetWidth(math.ceil(math.max(minWidth, width) / 2) * 2)
end

local function MakeStepButton(parent, text, width, onClick)
	local button = MakeButton(parent, text, width, onClick)
	button:HookScript('OnEnter', function(self) BUILib.Skin.SetShellFill(self, CHOICE_HOVER_FILL) end)
	button:HookScript('OnLeave', function(self) BUILib.Skin.SetShellFill(self, PanelFill()) end)
	return button
end

local function PaintChoice(frame, selected, hovered)
	local red, green, blue = Accent()
	if selected then
		BUILib.Skin.SetShellFill(frame, CHOICE_SELECTED_FILL)
		BUILib.Skin.SetShellEdges(frame, { red, green, blue, 1 })
	else
		BUILib.Skin.SetShellFill(frame, hovered and CHOICE_HOVER_FILL or CHOICE_REST_FILL)
		BUILib.Skin.SetShellEdges(frame, hovered and { red, green, blue, 1 } or PanelEdge())
	end
end

local function MakeChoice(parent, width, height, onClick)
	local choice = CreateFrame('Button', nil, parent)
	choice:SetSize(width, height)
	Skin().TipShell(choice)
	choice.selected = false
	function choice:Paint(hovered)
		PaintChoice(self, self.selected, hovered)
		if self.text then
			if self.selected then
				local red, green, blue = Accent()
				self.text:SetTextColor(red, green, blue, 1)
			else
				SetColor(self.text, hovered and TEXT_BRIGHT or TEXT_BODY)
			end
		end
	end
	choice:SetScript('OnEnter', function(self) self:Paint(true) end)
	choice:SetScript('OnLeave', function(self) self:Paint(false) end)
	choice:SetScript('OnClick', onClick)
	return choice
end

local MODEL_WIDTH, MODEL_HEIGHT = 200, 290
local WAVE_ANIMATION = 67
local WAVE_SECONDS = 2.4
local HERO_RULE_WIDTH = 220
local COLUMN_WIDTH = 228
local NUMBER_WORDS = { 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight' }
local ROW_HEIGHT, ROW_GAP = 40, 8
local COMPACT_ROW_HEIGHT, COMPACT_ROW_GAP = 28, 6
local COMPACT_ROW_COUNT = 5

local function WelcomeSteps()
	local steps = {}
	for _, step in ipairs(STEPS) do
		if step.summary then steps[#steps + 1] = step end
	end
	return steps
end

local function MakeGradientRule(parent, width)
	local left = parent:CreateTexture(nil, 'ARTWORK')
	local right = parent:CreateTexture(nil, 'ARTWORK')
	left:SetSize(width / 2, 1)
	right:SetSize(width / 2, 1)
	left:SetTexture(Widget.WHITE)
	right:SetTexture(Widget.WHITE)
	right:SetPoint('LEFT', left, 'RIGHT')
	local function Paint()
		local red, green, blue = Accent()
		left:SetGradient('HORIZONTAL', CreateColor(red, green, blue, 0), CreateColor(red, green, blue, 1))
		right:SetGradient('HORIZONTAL', CreateColor(red, green, blue, 1), CreateColor(red, green, blue, 0))
	end
	return left, Paint
end

local function MakeHero(parent)
	local host = CreateFrame('Frame', nil, parent)
	host:SetSize(MODEL_WIDTH, MODEL_HEIGHT)
	local model = CreateFrame('PlayerModel', nil, host)
	model:SetAllPoints(host)
	function host:Pose()
		model:SetUnit('player')
		model:SetFacing(0.35)
		model:SetAnimation(WAVE_ANIMATION)
		C_Timer.After(WAVE_SECONDS, function()
			if host:IsVisible() then model:SetAnimation(0) end
		end)
	end
	return host
end

local function BuildWelcome(frame)
	local headline = MakeText(frame, HEADLINE_SIZE, '', TEXT_BRIGHT)
	headline:SetPoint('TOP', 0, -6)
	local rule, paintRule = MakeGradientRule(frame, HERO_RULE_WIDTH)
	rule:SetPoint('TOPRIGHT', headline, 'BOTTOM', 0, -10)

	local hero = MakeHero(frame)
	hero:SetPoint('TOPLEFT', 0, -66)

	local column = CreateFrame('Frame', nil, frame)
	column:SetPoint('TOPLEFT', 220, -80)
	column:SetPoint('BOTTOMRIGHT', 0, 0)

	local greeting = MakeText(column, 20, ('Hey %s.'):format(UnitName('player')), TEXT_BRIGHT)
	greeting:SetPoint('TOPLEFT', 0, 0)
	local classLine = MakeText(column, 12, ('Level %d %s'):format(UnitLevel('player'), UnitClass('player')), TEXT_BODY)
	classLine:SetPoint('TOPLEFT', greeting, 'BOTTOMLEFT', 0, -4)
	local classRed, classGreen, classBlue = PlayerClassColor()
	classLine:SetTextColor(classRed, classGreen, classBlue, 1)

	local steps = WelcomeSteps()
	local countWord = NUMBER_WORDS[#steps]
	local intro = MakeText(column, 11, ('%s quick picks and you\'re back in the game. Nothing here is permanent, so change your mind later with /bui.'):format(countWord), TEXT_LABEL)
	intro:SetPoint('TOPLEFT', classLine, 'BOTTOMLEFT', 0, -12)
	intro:SetWidth(COLUMN_WIDTH)
	intro:SetJustifyH('LEFT')
	intro:SetSpacing(3)

	local compact = #steps >= COMPACT_ROW_COUNT
	local rowHeight = compact and COMPACT_ROW_HEIGHT or ROW_HEIGHT
	local rowGap = compact and COMPACT_ROW_GAP or ROW_GAP
	local previousRow
	for rowIndex, step in ipairs(steps) do
		local row = CreateFrame('Frame', nil, column)
		row:SetSize(COLUMN_WIDTH, rowHeight)
		if previousRow then
			row:SetPoint('TOPLEFT', previousRow, 'BOTTOMLEFT', 0, -rowGap)
		else
			row:SetPoint('TOPLEFT', intro, 'BOTTOMLEFT', 0, -18)
		end
		Skin().TipShell(row)
		local number = MakeText(row, compact and 12 or 16, tostring(rowIndex), TEXT_LABEL)
		number:SetPoint('LEFT', 12, 0)
		local name = MakeText(row, 12, step.title, TEXT_BRIGHT)
		if compact then
			name:SetPoint('LEFT', 36, 0)
		else
			name:SetPoint('TOPLEFT', 36, -7)
			local detail = MakeText(row, 10, step.summary, TEXT_LABEL)
			detail:SetPoint('TOPLEFT', 36, -22)
		end
		frame.accentables[#frame.accentables + 1] = function()
			local red, green, blue = Accent()
			number:SetTextColor(red, green, blue, 1)
		end
		previousRow = row
	end

	local footer = MakeText(frame, 11, 'A minute, tops.', TEXT_LABEL)
	footer:SetPoint('BOTTOM', 0, 0)

	frame.accentables[#frame.accentables + 1] = function()
		headline:SetFormattedText('Welcome to |cff%sBluUI|r', AccentHex())
		paintRule()
	end
	frame.OnShow = function() hero:Pose() end
end

local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.35, 1.15, 0.001
local SCALE_SLIDER_WIDTH = 360
local OPTION_WIDTH, OPTION_HEIGHT, OPTION_GAP = 360, 40, 8
local SCALE_APPLY_KEY = 'Installer.ScaleApply'

local function MakeOptionRow(parent, width, height, title, detail, valueText, onClick)
	local row = MakeChoice(parent, width, height, onClick)
	row.text = MakeText(row, 12, title, TEXT_BODY)
	row.text:SetPoint('TOPLEFT', 14, -7)
	local detailText = MakeText(row, 10, detail, TEXT_LABEL)
	detailText:SetPoint('TOPLEFT', 14, -22)
	local value = MakeText(row, 12, valueText, TEXT_LABEL)
	value:SetPoint('RIGHT', -14, 0)
	row:Paint()
	return row
end

local function BuildScale(frame)
	local title = MakeText(frame, 18, 'Interface scale', TEXT_BRIGHT)
	title:SetPoint('TOP', 0, -4)
	local subtitle = MakeText(frame, 11, 'A pixel-perfect scale keeps every line sharp instead of smeared across half a pixel.', TEXT_LABEL)
	subtitle:SetPoint('TOP', title, 'BOTTOM', 0, -6)

	local readout = MakeText(frame, 56, '', TEXT_BRIGHT)
	readout:SetPoint('TOP', subtitle, 'BOTTOM', 0, -18)
	local status = MakeText(frame, 11, '', TEXT_LABEL)
	status:SetPoint('TOP', readout, 'BOTTOM', 0, -4)

	local best = BUI.ClampedUIScale()
	local screenWidth, screenHeight = GetPhysicalScreenSize()
	local rows = {}
	local slider

	local function Refresh()
		local current = UIParent:GetScale()
		readout:SetText(('%.3f'):format(current))
		if BUI.ApproxEqual(current, best) then
			local red, green, blue = Accent()
			readout:SetTextColor(red, green, blue, 1)
			status:SetTextColor(red, green, blue, 1)
			status:SetFormattedText('Pixel-perfect for %d × %d', screenWidth, screenHeight)
		else
			SetColor(readout, TEXT_BRIGHT)
			SetColor(status, TEXT_LABEL)
			status:SetFormattedText('Off the pixel grid for %d × %d', screenWidth, screenHeight)
		end
		local matched = false
		for _, row in ipairs(rows) do
			local isMatch = BUI.ApproxEqual(current, row.scaleValue)
			row.selected = isMatch and not matched
			if isMatch then matched = true end
			row:Paint(row:IsMouseOver())
		end
		slider.frame:SetValue(current)
	end

	local function SetScale(value)
		if value < SCALE_MIN then value = SCALE_MIN elseif value > SCALE_MAX then value = SCALE_MAX end
		BUI.GetDB().uiScale.scale = value
		BUI.ApplyScale()
		C_Timer.After(0.05, Refresh)
	end

	local pendingScale
	BUI.Scheduler.RegisterUpdate(SCALE_APPLY_KEY, function()
		if IsMouseButtonDown('LeftButton') then return end
		BUI.Scheduler.SetUpdateEnabled(SCALE_APPLY_KEY, false)
		local value = pendingScale
		pendingScale = nil
		if value then SetScale(value) end
	end, 0.1, false)

	slider = Controls.CompactSlider(frame, nil, SCALE_MIN, SCALE_MAX, best, function(value)
		pendingScale = value
		readout:SetText(('%.3f'):format(value))
		BUI.Scheduler.SetUpdateEnabled(SCALE_APPLY_KEY, true)
	end, SCALE_STEP, SCALE_SLIDER_WIDTH, false, 'Drag for a custom scale. It applies when you let go.')
	slider.frame:SetPoint('TOP', status, 'BOTTOM', 0, -20)

	local presetsLabel = MakeText(frame, 12, 'Presets', TEXT_BODY)
	presetsLabel:SetPoint('TOP', slider.frame, 'BOTTOM', 0, -22)

	local PRESETS = {
		{ title = 'Auto', detail = 'Pixel-perfect for this screen', value = best },
		{ title = '1440p', detail = 'Pixel-perfect on a 1440p display', value = 768 / 1440 },
		{ title = '4K', detail = 'Pixel-perfect on a 4K display', value = 768 / 2160 },
	}
	local previousRow
	for _, preset in ipairs(PRESETS) do
		local row = MakeOptionRow(frame, OPTION_WIDTH, OPTION_HEIGHT, preset.title, preset.detail, ('%.3f'):format(preset.value), function() SetScale(preset.value) end)
		row.scaleValue = preset.value
		if previousRow then
			row:SetPoint('TOP', previousRow, 'BOTTOM', 0, -OPTION_GAP)
		else
			row:SetPoint('TOP', presetsLabel, 'BOTTOM', 0, -10)
		end
		rows[#rows + 1] = row
		previousRow = row
	end

	local note = MakeText(frame, 11, 'Mid-fight? This waits until you drop out of combat.', TEXT_LABEL)
	note:SetPoint('BOTTOM', 0, 0)

	frame.OnShow = Refresh
	frame.accentables[#frame.accentables + 1] = Refresh
end

local MOCK_WIDTH, MOCK_HEIGHT = 172, 80
local MOCK_TAB_HEIGHT = 22
local BLIZZARD_MOCK_BACKDROP = {
	bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
	edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
	tile = true, tileEdge = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local MOCK_ROWS = { 'Bluhu', 'Target' }

local function MakeMockRows(mock, makeRow)
	for rowIndex, rowText in ipairs(MOCK_ROWS) do
		local row = CreateFrame('Frame', nil, mock)
		row:SetPoint('TOPLEFT', 8, -34 - (rowIndex - 1) * 18)
		row:SetPoint('TOPRIGHT', -8, -34 - (rowIndex - 1) * 18)
		row:SetHeight(16)
		makeRow(row, rowText, rowIndex)
	end
end

local function MakeSkinnedMock(parent)
	local mock = CreateFrame('Frame', nil, parent)
	mock:SetSize(MOCK_WIDTH, MOCK_HEIGHT)
	Skin().TipShell(mock)
	local title = MakeText(mock, 12, 'Contacts', TEXT_BRIGHT)
	title:SetPoint('TOPLEFT', 10, -9)
	local line = mock:CreateTexture(nil, 'BORDER')
	line:SetPoint('TOPLEFT', 8, -27)
	line:SetPoint('TOPRIGHT', -8, -27)
	line:SetHeight(1)
	line:SetColorTexture(1, 1, 1, 0.1)
	MakeMockRows(mock, function(row, rowText, rowIndex)
		if rowIndex == 1 then
			local highlight = row:CreateTexture(nil, 'BACKGROUND')
			highlight:SetAllPoints(row)
			Skin().AccentTexture(highlight, 0.22)
		end
		local name = MakeText(row, 11, rowText, rowIndex == 1 and TEXT_BRIGHT or TEXT_BODY)
		name:SetPoint('LEFT', 4, 0)
		local status = MakeText(row, 11, rowIndex == 1 and 'Online' or 'Away', TEXT_LABEL)
		status:SetPoint('RIGHT', -4, 0)
	end)
	local tabs = {}
	for tabIndex, tabText in ipairs({ 'Friends', 'Who' }) do
		local tab = CreateFrame('Button', nil, mock)
		tab:SetHeight(MOCK_TAB_HEIGHT)
		Skin().TipTab(tab, true)
		tab:SetText(tabText)
		tab.Text = tab:GetFontString()
		tab:EnableMouse(false)
		Skin().TipTabSelected(tab, tabIndex == 1)
		tabs[tabIndex] = tab
	end
	BUILib.Skin.LayoutTabStrip(mock, tabs)
	return mock
end

local function MakeBlizzardMock(parent)
	local mock = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	mock:SetSize(MOCK_WIDTH, MOCK_HEIGHT)
	mock:SetBackdrop(BLIZZARD_MOCK_BACKDROP)
	local title = mock:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	title:SetPoint('TOPLEFT', 10, -9)
	title:SetText('Contacts')
	MakeMockRows(mock, function(row, rowText, rowIndex)
		local name = row:CreateFontString(nil, 'OVERLAY', rowIndex == 1 and 'GameFontHighlightSmall' or 'GameFontNormalSmall')
		name:SetPoint('LEFT', 4, 0)
		name:SetText(rowText)
		local status = row:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
		status:SetPoint('RIGHT', -4, 0)
		status:SetText(rowIndex == 1 and 'Online' or 'Away')
	end)
	return mock
end

local CHOICE_WIDTH, CHOICE_HEIGHT, CHOICE_GAP = 204, 160, 16
local PICKER_WIDTH, PREVIEW_BUTTON_WIDTH = 240, 168
local PREVIEW_SKINS = { 'friends', 'groupfinder', 'collections' }
local PICKER_COLUMNS, PICKER_ROW_HEIGHT, PICKER_PADDING = 2, 20, 8
local PICKER_CHECK_SIZE, PICKER_CHECK_INSET = 14, 3
local PICKER_ROW_HOVER_ALPHA = 0.05

local function SkinIDs()
	local registry, order = Skin().GetSkinRegistry()
	return registry, order
end

local function SeedSelection()
	skinSelection = {}
	local _, order = SkinIDs()
	for _, id in ipairs(order) do skinSelection[id] = Skin().IsSkinEnabled(id) end
end

local function SelectionCounts()
	local _, order = SkinIDs()
	local selectedCount = 0
	for _, id in ipairs(order) do
		if skinSelection[id] then selectedCount = selectedCount + 1 end
	end
	return selectedCount, #order
end

local function LoadedSkinCount()
	local _, order = SkinIDs()
	local count = 0
	for _, id in ipairs(order) do
		if Skin().IsSkinEnabled(id) then count = count + 1 end
	end
	return count
end

local function MakePickerRow(list, id, name, width, onToggle)
	local row = CreateFrame('Button', nil, list)
	row:SetSize(width, PICKER_ROW_HEIGHT)
	local hover = row:CreateTexture(nil, 'BACKGROUND')
	hover:SetAllPoints(row)
	hover:SetColorTexture(1, 1, 1, PICKER_ROW_HOVER_ALPHA)
	hover:Hide()
	local box = CreateFrame('Frame', nil, row)
	box:SetSize(PICKER_CHECK_SIZE, PICKER_CHECK_SIZE)
	box:SetPoint('LEFT', 6, 0)
	Skin().TipShell(box)
	local mark = box:CreateTexture(nil, 'OVERLAY')
	mark:SetTexture(BUILib.GetLibMedia('check'))
	mark:SetPoint('TOPLEFT', PICKER_CHECK_INSET, -PICKER_CHECK_INSET)
	mark:SetPoint('BOTTOMRIGHT', -PICKER_CHECK_INSET, PICKER_CHECK_INSET)
	local label = MakeText(row, 11, name, TEXT_BODY)
	label:SetPoint('LEFT', box, 'RIGHT', 8, 0)
	row:SetScript('OnEnter', function() hover:Show() end)
	row:SetScript('OnLeave', function() hover:Hide() end)
	row:SetScript('OnClick', function()
		skinSelection[id] = not skinSelection[id]
		onToggle()
	end)
	function row:Paint()
		local selected = skinSelection[id] == true
		mark:SetShown(selected)
		if selected then
			local red, green, blue = Accent()
			mark:SetVertexColor(red, green, blue, 1)
			BUILib.Skin.SetShellEdges(box, { red, green, blue, 1 })
		else
			BUILib.Skin.SetShellEdges(box, PanelEdge())
		end
		SetColor(label, selected and TEXT_BRIGHT or TEXT_BODY)
	end
	return row
end

local function MakePicker(frame, onToggle)
	local picker = MakeButton(frame, '', PICKER_WIDTH, nil)
	local arrow = picker:CreateTexture(nil, 'OVERLAY')
	arrow:SetTexture(BUILib.GetLibMedia('dropdown'))
	arrow:SetSize(11, 11)
	arrow:SetPoint('RIGHT', -8, 0)
	arrow:SetVertexColor(TEXT_LABEL[1], TEXT_LABEL[2], TEXT_LABEL[3], 1)
	local text = MakeText(picker, 12, '', TEXT_BODY)
	text:SetPoint('LEFT', 10, 0)
	text:SetPoint('RIGHT', arrow, 'LEFT', -6, 0)
	text:SetJustifyH('LEFT')

	local list = CreateFrame('Frame', nil, frame)
	list:SetFrameLevel(frame:GetFrameLevel() + 30)
	list:EnableMouse(true)
	list:SetPoint('TOPLEFT', picker, 'BOTTOMLEFT', 0, -4)
	Skin().TipShell(list)
	list:Hide()
	local registry, order = SkinIDs()
	local listWidth = CHOICE_WIDTH * 2 + CHOICE_GAP
	local columnWidth = (listWidth - 2 * PICKER_PADDING) / PICKER_COLUMNS
	local rowCount = math.ceil(#order / PICKER_COLUMNS)
	list:SetSize(listWidth, rowCount * PICKER_ROW_HEIGHT + 2 * PICKER_PADDING)
	local rows = {}
	for index, id in ipairs(order) do
		local row = MakePickerRow(list, id, registry[id].name, columnWidth, onToggle)
		local column = (index - 1) % PICKER_COLUMNS
		local rowIndex = math.floor((index - 1) / PICKER_COLUMNS)
		row:SetPoint('TOPLEFT', list, 'TOPLEFT', PICKER_PADDING + column * columnWidth, -(PICKER_PADDING + rowIndex * PICKER_ROW_HEIGHT))
		rows[#rows + 1] = row
	end

	picker:SetScript('OnClick', function() list:SetShown(not list:IsShown()) end)
	function picker:Paint()
		local selectedCount, total = SelectionCounts()
		if selectedCount == total then
			text:SetFormattedText('All %d skins', total)
		elseif selectedCount == 0 then
			text:SetText('No skins')
		else
			text:SetFormattedText('%d of %d skins', selectedCount, total)
		end
		for _, row in ipairs(rows) do row:Paint() end
	end
	function picker:CloseList() list:Hide() end
	return picker
end

local function BuildSkins(frame)
	local title = MakeText(frame, 18, 'Would you like our skins turned on?', TEXT_BRIGHT)
	title:SetPoint('TOP', 0, -4)
	local subtitle = MakeText(frame, 11, 'One dark look across every Blizzard window, matching the rest of BluUI.', TEXT_LABEL)
	subtitle:SetPoint('TOP', title, 'BOTTOM', 0, -6)
	subtitle:SetWidth(420)
	subtitle:SetJustifyH('CENTER')
	subtitle:SetSpacing(3)

	local host = CreateFrame('Frame', nil, frame)
	host:SetSize(CHOICE_WIDTH * 2 + CHOICE_GAP, CHOICE_HEIGHT)
	host:SetPoint('TOP', subtitle, 'BOTTOM', 0, -22)

	local yes, no, picker, showButton, hint

	local function Paint()
		local selectedCount, total = SelectionCounts()
		yes.selected = selectedCount == total
		no.selected = selectedCount == 0
		yes:Paint(yes:IsMouseOver())
		no:Paint(no:IsMouseOver())
		picker:Paint()
		local loadedCount = LoadedSkinCount()
		showButton:SetEnabled(loadedCount > 0)
		if loadedCount == 0 then
			hint:SetText('Nothing is skinned yet, so there is nothing to show. Your picks land when setup finishes and the UI reloads.')
		else
			hint:SetText('Your picks land when setup finishes and the UI reloads.')
		end
	end

	local function ChooseAll(enabled)
		local _, order = SkinIDs()
		for _, id in ipairs(order) do skinSelection[id] = enabled end
		Paint()
	end

	yes = MakeChoice(host, CHOICE_WIDTH, CHOICE_HEIGHT, function() ChooseAll(true) end)
	yes:SetPoint('LEFT')
	local skinnedMock = MakeSkinnedMock(yes)
	skinnedMock:SetPoint('TOP', 0, -14)
	yes.text = MakeText(yes, 12, 'Yes, skin it all')
	yes.text:SetPoint('BOTTOM', 0, 14)

	no = MakeChoice(host, CHOICE_WIDTH, CHOICE_HEIGHT, function() ChooseAll(false) end)
	no:SetPoint('RIGHT')
	local blizzardMock = MakeBlizzardMock(no)
	blizzardMock:SetPoint('TOP', 0, -14)
	no.text = MakeText(no, 12, 'No, keep Blizzard\'s look')
	no.text:SetPoint('BOTTOM', 0, 14)

	picker = MakePicker(frame, Paint)
	picker:SetPoint('TOPLEFT', host, 'BOTTOMLEFT', 0, -18)
	Widget.Tooltip(picker, 'Pick exactly which windows get the BluUI look.')

	showButton = MakeButton(frame, 'Preview', PREVIEW_BUTTON_WIDTH, function()
		if not wizard then return end
		wizard:Suspend()
		if not Skin().Test(function() if wizard then wizard:Resume() end end, PREVIEW_SKINS) then
			wizard:Resume()
		end
	end)
	showButton:SetPoint('TOPRIGHT', host, 'BOTTOMRIGHT', 0, -18)
	Widget.Tooltip(showButton, 'Opens three skinned windows side by side. Escape brings you back here.')

	hint = MakeText(frame, 11, '', TEXT_LABEL)
	hint:SetPoint('BOTTOM', 0, 2)
	hint:SetWidth(430)
	hint:SetJustifyH('CENTER')
	hint:SetSpacing(3)

	frame.ClosePopups = function() picker:CloseList() end
	frame.OnShow = function()
		picker:CloseList()
		Paint()
	end
	frame.accentables[#frame.accentables + 1] = Paint
end

local GLASS_UF = {
	transparentHealth = true, healthBarAlpha = 0.35,
	classColorHealth = true, classColorPower = true,
	bgColor = { 0.05, 0.05, 0.06, 0.55 },
}
local SOLID_UF = {
	transparentHealth = false, healthBarAlpha = 1,
	classColorHealth = true, classColorPower = true,
	bgColor = { 0.1, 0.1, 0.1, 0.8 },
}
local DARK_GLASS_UF = {
	transparentHealth = true, healthBarAlpha = 0.5,
	classColorHealth = false, classColorPower = false,
	healthColor = { 0.30, 0.31, 0.36, 1 },
	bgColor = { 0.03, 0.03, 0.04, 0.6 },
}
local DARK_SOLID_UF = {
	transparentHealth = false, healthBarAlpha = 1,
	classColorHealth = false, classColorPower = false,
	healthColor = { 0.18, 0.19, 0.23, 1 },
	bgColor = { 0.05, 0.05, 0.06, 0.9 },
}

local FRAME_STYLES = {
	{ key = 'classglass', name = 'Class Glass', dark = false, glass = true, uf = GLASS_UF, tip = 'Class-colored glass bars' },
	{ key = 'classsolid', name = 'Class Solid', dark = false, glass = false, uf = SOLID_UF, tip = 'Class-colored solid bars' },
	{ key = 'darkglass', name = 'Dark Glass', dark = true, glass = true, uf = DARK_GLASS_UF, tip = 'Slate glass bars, no class coloring' },
	{ key = 'darksolid', name = 'Dark Solid', dark = true, glass = false, uf = DARK_SOLID_UF, tip = 'Slate solid bars, no class coloring' },
}

local ACCENTS = {
	{ name = 'Class', class = true },
	{ name = 'Purple', color = { 0.427, 0.000, 0.992 } },
	{ name = 'Pink', color = { 0.831, 0.000, 0.373 } },
	{ name = 'Blue', color = { 0.200, 0.550, 1.000 } },
	{ name = 'Teal', color = { 0.000, 0.800, 0.700 } },
	{ name = 'Gold', color = { 1.000, 0.720, 0.200 } },
	{ name = 'Slate', color = { 0.40, 0.42, 0.48 } },
	{ name = 'White', color = { 0.95, 0.95, 0.97 } },
}

local function ApplyFrameStyle(style)
	local unitFrameSettings = BUI.GetDB().unitFrames
	for key, value in pairs(style.uf) do
		if type(value) == 'table' then
			unitFrameSettings[key] = { value[1], value[2], value[3], value[4] }
		else
			unitFrameSettings[key] = value
		end
	end
	BUI.db.global.installerFrameStyle = style.key
	BUI.ExportImport.RefreshAllModules()
end

local function ApplyAccentChoice(accent)
	local general = BUI.GetDB().general
	if accent.class then
		general.useClassColorTheme = true
	else
		general.useClassColorTheme = false
		general.themeColor = { accent.color[1], accent.color[2], accent.color[3], 1 }
	end
end

local TEXTURE_PICKER_WIDTH, TEXTURE_LIST_WIDTH = 200, 424
local TEXTURE_COLUMNS, TEXTURE_VISIBLE_ROWS, TEXTURE_ROW_HEIGHT = 2, 11, 20
local TEXTURE_SCROLL_ROWS = 3
local TEXTURE_SWATCH_WIDTH, TEXTURE_SWATCH_HEIGHT = 56, 10

local function TexturePath(name)
	return sharedMedia:Fetch('statusbar', name, true) or Widget.WHITE
end

local function PaintSwatch(swatch, name)
	swatch:SetTexture(TexturePath(name))
	local red, green, blue = Accent()
	swatch:SetVertexColor(red, green, blue, 1)
end

local function MakeTextureRow(list, width, onSelect)
	local row = CreateFrame('Button', nil, list)
	row:SetSize(width, TEXTURE_ROW_HEIGHT)
	local hover = row:CreateTexture(nil, 'BACKGROUND')
	hover:SetAllPoints(row)
	hover:SetColorTexture(1, 1, 1, PICKER_ROW_HOVER_ALPHA)
	hover:Hide()
	local swatch = row:CreateTexture(nil, 'ARTWORK')
	swatch:SetSize(TEXTURE_SWATCH_WIDTH, TEXTURE_SWATCH_HEIGHT)
	swatch:SetPoint('LEFT', 6, 0)
	local label = MakeText(row, 11, '', TEXT_BODY)
	label:SetPoint('LEFT', swatch, 'RIGHT', 8, 0)
	label:SetPoint('RIGHT', -6, 0)
	label:SetJustifyH('LEFT')
	label:SetWordWrap(false)
	row:SetScript('OnEnter', function() hover:Show() end)
	row:SetScript('OnLeave', function() hover:Hide() end)
	row:SetScript('OnClick', function(self) if self.value then onSelect(self.value) end end)
	function row:Bind(item, selected)
		self.value = item and item.value
		self:SetShown(item ~= nil)
		if not item then return end
		PaintSwatch(swatch, item.value)
		label:SetText(item.text)
		if selected then
			local red, green, blue = Accent()
			label:SetTextColor(red, green, blue, 1)
		else
			SetColor(label, TEXT_BODY)
		end
	end
	return row
end

local function MakeTexturePicker(frame, getValue, onSelect)
	local picker = MakeButton(frame, '', TEXTURE_PICKER_WIDTH, nil)
	local arrow = picker:CreateTexture(nil, 'OVERLAY')
	arrow:SetTexture(BUILib.GetLibMedia('dropdown'))
	arrow:SetSize(11, 11)
	arrow:SetPoint('RIGHT', -8, 0)
	arrow:SetVertexColor(TEXT_LABEL[1], TEXT_LABEL[2], TEXT_LABEL[3], 1)
	local swatch = picker:CreateTexture(nil, 'ARTWORK')
	swatch:SetSize(TEXTURE_SWATCH_WIDTH, TEXTURE_SWATCH_HEIGHT)
	swatch:SetPoint('LEFT', 10, 0)
	local text = MakeText(picker, 12, '', TEXT_BODY)
	text:SetPoint('LEFT', swatch, 'RIGHT', 8, 0)
	text:SetPoint('RIGHT', arrow, 'LEFT', -6, 0)
	text:SetJustifyH('LEFT')
	text:SetWordWrap(false)

	local list = CreateFrame('Frame', nil, frame)
	list:SetFrameLevel(frame:GetFrameLevel() + 30)
	list:EnableMouse(true)
	list:EnableMouseWheel(true)
	list:SetPoint('TOPLEFT', picker, 'BOTTOMLEFT', 0, -4)
	Skin().TipShell(list)
	list:Hide()
	local columnWidth = (TEXTURE_LIST_WIDTH - 2 * PICKER_PADDING) / TEXTURE_COLUMNS
	list:SetSize(TEXTURE_LIST_WIDTH, TEXTURE_VISIBLE_ROWS * TEXTURE_ROW_HEIGHT + 2 * PICKER_PADDING)
	local items, offset, rows = {}, 0, {}
	local function Select(value)
		list:Hide()
		onSelect(value)
	end
	for index = 1, TEXTURE_COLUMNS * TEXTURE_VISIBLE_ROWS do
		local row = MakeTextureRow(list, columnWidth, Select)
		local column = (index - 1) % TEXTURE_COLUMNS
		local rowIndex = math.floor((index - 1) / TEXTURE_COLUMNS)
		row:SetPoint('TOPLEFT', list, 'TOPLEFT', PICKER_PADDING + column * columnWidth, -(PICKER_PADDING + rowIndex * TEXTURE_ROW_HEIGHT))
		rows[index] = row
	end
	local function MaxOffset()
		local totalRows = math.ceil(#items / TEXTURE_COLUMNS)
		return math.max(0, totalRows - TEXTURE_VISIBLE_ROWS) * TEXTURE_COLUMNS
	end
	local function BindRows()
		local current = getValue()
		for index, row in ipairs(rows) do
			local item = items[offset + index]
			row:Bind(item, item ~= nil and item.value == current)
		end
	end
	list:SetScript('OnMouseWheel', function(_, delta)
		offset = math.max(0, math.min(MaxOffset(), offset - delta * TEXTURE_COLUMNS * TEXTURE_SCROLL_ROWS))
		BindRows()
	end)
	picker:SetScript('OnClick', function()
		if list:IsShown() then
			list:Hide()
			return
		end
		items = BUI.BuildTextureDropdownItems()
		local current = getValue()
		offset = 0
		for index, item in ipairs(items) do
			if item.value == current then
				offset = math.min(MaxOffset(), math.floor((index - 1) / TEXTURE_COLUMNS) * TEXTURE_COLUMNS)
				break
			end
		end
		BindRows()
		list:Show()
	end)
	function picker:Paint()
		local current = getValue()
		PaintSwatch(swatch, current)
		text:SetText(current)
		if list:IsShown() then BindRows() end
	end
	function picker:CloseList() list:Hide() end
	return picker
end

local function BuildTheme(frame)
	local title = MakeText(frame, 18, 'Theme', TEXT_BRIGHT)
	title:SetPoint('TOP', 0, -4)
	local subtitle = MakeText(frame, 11, 'Applies live. Hover a style to try it on.', TEXT_LABEL)
	subtitle:SetPoint('TOP', title, 'BOTTOM', 0, -6)

	local function RefreshUnitFrames()
		BUI.UnitFrames.InvalidateSettingsCache()
		BUI.UnitFrames:Refresh()
	end

	local function CurrentUnitFrames()
		return BUI.GetDB().unitFrames
	end

	local unitFramesLabel = MakeText(frame, 12, 'Unit frames', TEXT_BODY)
	unitFramesLabel:SetPoint('TOP', subtitle, 'BOTTOM', 0, -18)

	local TILE_WIDTH, TILE_HEIGHT, TILE_GAP_X = 96, 44, 14
	local tiles = {}

	local function StyleColor(style)
		if style.dark then return 0.30, 0.31, 0.36 end
		return PlayerClassColor()
	end

	local function PaintStyles()
		local applied = BUI.db.global.installerFrameStyle
		local accentRed, accentGreen, accentBlue = Accent()
		for _, tile in ipairs(tiles) do
			local red, green, blue = StyleColor(tile.style)
			BUILib.Skin.SetShellFill(tile, { red, green, blue, tile.style.glass and 0.45 or 1 })
			if applied == tile.style.key then
				BUILib.Skin.SetShellEdges(tile, { accentRed, accentGreen, accentBlue, 1 })
				tile.label:SetTextColor(accentRed, accentGreen, accentBlue, 1)
			else
				BUILib.Skin.SetShellEdges(tile, PanelEdge())
				SetColor(tile.label, TEXT_LABEL)
			end
		end
	end

	local tileHost = CreateFrame('Frame', nil, frame)
	tileHost:SetSize(#FRAME_STYLES * TILE_WIDTH + (#FRAME_STYLES - 1) * TILE_GAP_X, TILE_HEIGHT)
	tileHost:SetPoint('TOP', unitFramesLabel, 'BOTTOM', 0, -10)

	for styleIndex, style in ipairs(FRAME_STYLES) do
		local tile = CreateFrame('Button', nil, tileHost)
		tile:SetSize(TILE_WIDTH, TILE_HEIGHT)
		tile:SetPoint('LEFT', (styleIndex - 1) * (TILE_WIDTH + TILE_GAP_X), 0)
		Skin().TipShell(tile)
		tile.style = style
		tile.label = MakeText(tileHost, 11, style.name, TEXT_LABEL)
		tile.label:SetPoint('TOP', tile, 'BOTTOM', 0, -6)
		Widget.Tooltip(tile, style.tip)
		tiles[#tiles + 1] = tile
	end

	local PREVIEW_WIDTH, PREVIEW_HEIGHT = 190, 40
	local previewHost = CreateFrame('Frame', nil, frame)
	previewHost:SetSize(PREVIEW_WIDTH * 2 + 16, PREVIEW_HEIGHT)
	previewHost:SetPoint('TOP', tileHost, 'BOTTOM', 0, -32)

	local function BarTexture()
		local name = BUI.GetDB().general.texture
		local path = sharedMedia:Fetch('statusbar', name, true)
		return path or Widget.WHITE
	end

	local function MakePreviewFrame(nameText, fillPercent, offsetX)
		local previewFrame = CreateFrame('Frame', nil, previewHost)
		previewFrame:SetSize(PREVIEW_WIDTH, PREVIEW_HEIGHT)
		previewFrame:SetPoint('TOPLEFT', offsetX, 0)
		Skin().TipShell(previewFrame)
		BUILib.Skin.SetShellEdges(previewFrame, { 0, 0, 0, 1 })

		local fill = previewFrame:CreateTexture(nil, 'ARTWORK')
		fill:SetPoint('TOPLEFT', 1, -1)
		fill:SetPoint('BOTTOMLEFT', 1, 6)
		fill:SetWidth((PREVIEW_WIDTH - 2) * fillPercent)

		local power = previewFrame:CreateTexture(nil, 'ARTWORK')
		power:SetPoint('BOTTOMLEFT', 1, 1)
		power:SetPoint('BOTTOMRIGHT', -1, 1)
		power:SetHeight(4)

		local name = MakeText(previewFrame, 10, nameText, TEXT_BRIGHT)
		name:SetPoint('LEFT', 6, 3)
		local percentText = MakeText(previewFrame, 10, math.floor(fillPercent * 100) .. '%', TEXT_BRIGHT)
		percentText:SetPoint('RIGHT', -6, 3)

		return { frame = previewFrame, fill = fill, power = power }
	end

	local playerPreview = MakePreviewFrame(UnitName('player'), 0.72, 0)
	local targetPreview = MakePreviewFrame('Target', 0.43, PREVIEW_WIDTH + 16)

	local TARGET_SAMPLE = { 0.78, 0.61, 0.43 }
	local function StylePreview(unitFrameSettings)
		local _, class = UnitClass('player')
		local classColor = class and RAID_CLASS_COLORS[class]
		local playerColor = (unitFrameSettings.classColorHealth and classColor) and { classColor.r, classColor.g, classColor.b } or unitFrameSettings.healthColor or { 0.2, 0.8, 0.2 }
		local targetColor = unitFrameSettings.classColorHealth and TARGET_SAMPLE or unitFrameSettings.healthColor or { 0.2, 0.8, 0.2 }
		local fillAlpha = unitFrameSettings.transparentHealth and unitFrameSettings.healthBarAlpha or 1
		local texture = BarTexture()

		for previewIndex, preview in ipairs({ playerPreview, targetPreview }) do
			local color = previewIndex == 1 and playerColor or targetColor
			BUILib.Skin.SetShellFill(preview.frame, unitFrameSettings.bgColor)
			preview.fill:SetTexture(texture)
			preview.fill:SetVertexColor(color[1], color[2], color[3], fillAlpha)
			preview.power:SetTexture(texture)
			if unitFrameSettings.classColorPower and classColor then
				preview.power:SetVertexColor(classColor.r, classColor.g, classColor.b, 1)
			else
				preview.power:SetVertexColor(0.35, 0.36, 0.42, 1)
			end
		end
	end

	local controls = CreateFrame('Frame', nil, frame)
	controls:SetSize(448, 46)
	controls:SetPoint('TOP', previewHost, 'BOTTOM', 0, -22)

	local textureLabel = MakeText(controls, 12, 'Bar texture', TEXT_BODY)
	textureLabel:SetPoint('TOPLEFT', 0, 0)
	local texturePicker
	texturePicker = MakeTexturePicker(frame, function() return BUI.GetDB().general.texture end, function(value)
		BUI.GetDB().general.texture = value
		BUI.ExportImport.RefreshAllModules()
		StylePreview(CurrentUnitFrames())
		texturePicker:Paint()
	end)
	texturePicker:SetPoint('TOPLEFT', textureLabel, 'BOTTOMLEFT', 0, -6)
	Widget.Tooltip(texturePicker, 'The statusbar texture every bar uses.')

	local transparencyLabel = MakeText(controls, 12, 'Transparency', TEXT_BODY)
	transparencyLabel:SetPoint('TOPLEFT', 248, 0)
	local healthSlider = Controls.CompactSlider(frame, nil, 0, 100, 100,
		function(value)
			local unitFrameSettings = CurrentUnitFrames()
			unitFrameSettings.healthBarAlpha = value / 100
			unitFrameSettings.transparentHealth = value < 100
			RefreshUnitFrames()
			StylePreview(unitFrameSettings)
		end, 5, 200, false, 'How see-through the health fill is. 100 = solid.')
	healthSlider.frame:SetPoint('TOPLEFT', transparencyLabel, 'BOTTOMLEFT', 0, -6)

	local function SyncSliders()
		local unitFrameSettings = CurrentUnitFrames()
		local health = unitFrameSettings.transparentHealth and math.floor(unitFrameSettings.healthBarAlpha * 100 + 0.5) or 100
		healthSlider.frame:SetValue(health)
	end

	for _, tile in ipairs(tiles) do
		tile:HookScript('OnEnter', function(self) StylePreview(self.style.uf) end)
		tile:HookScript('OnLeave', function() StylePreview(CurrentUnitFrames()) end)
		tile:SetScript('OnClick', function(self)
			ApplyFrameStyle(self.style)
			PaintStyles()
			SyncSliders()
			StylePreview(CurrentUnitFrames())
		end)
	end

	local accentLabel = MakeText(frame, 12, 'Accent', TEXT_BODY)
	accentLabel:SetPoint('TOP', controls, 'BOTTOM', 0, -18)

	local SWATCH_SIZE, SWATCH_GAP = 32, 10
	local swatches = {}

	local function AccentColorOf(accent)
		if accent.class then return PlayerClassColor() end
		return accent.color[1], accent.color[2], accent.color[3]
	end

	local function PaintAccents()
		local general = BUI.GetDB().general
		for _, swatch in ipairs(swatches) do
			local red, green, blue = AccentColorOf(swatch.accent)
			local selected
			if swatch.accent.class then
				selected = general.useClassColorTheme == true
			else
				local themeColor = not general.useClassColorTheme and general.themeColor
				selected = themeColor and BUI.ApproxEqual(themeColor[1], red) and BUI.ApproxEqual(themeColor[2], green) and BUI.ApproxEqual(themeColor[3], blue)
			end
			BUILib.Skin.SetShellFill(swatch, { red, green, blue, 1 })
			BUILib.Skin.SetShellEdges(swatch, selected and TEXT_BRIGHT or { 0, 0, 0, 1 })
			swatch.mark:SetShown(selected)
		end
	end

	local swatchHost = CreateFrame('Frame', nil, frame)
	swatchHost:SetSize(#ACCENTS * SWATCH_SIZE + (#ACCENTS - 1) * SWATCH_GAP, SWATCH_SIZE)
	swatchHost:SetPoint('TOP', accentLabel, 'BOTTOM', 0, -10)

	for accentIndex, accent in ipairs(ACCENTS) do
		local swatch = CreateFrame('Button', nil, swatchHost)
		swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
		swatch:SetPoint('LEFT', (accentIndex - 1) * (SWATCH_SIZE + SWATCH_GAP), 0)
		Skin().TipShell(swatch)
		swatch.accent = accent
		swatch.mark = swatch:CreateTexture(nil, 'ARTWORK')
		swatch.mark:SetSize(14, 14)
		swatch.mark:SetPoint('CENTER')
		swatch.mark:SetTexture(BUILib.GetLibMedia('check'))
		swatch.mark:SetVertexColor(0, 0, 0, 0.85)
		Widget.Tooltip(swatch, accent.class and 'Your class color, always' or accent.name)
		swatch:SetScript('OnClick', function(self)
			ApplyAccentChoice(self.accent)
			RefreshAddonAccent()
			if wizard then wizard:ApplyAccent() end
			PaintAccents()
		end)
		swatches[#swatches + 1] = swatch
	end

	local hint = MakeText(frame, 11, 'The full color picker lives in /bui > Colors.', TEXT_LABEL)
	hint:SetPoint('TOP', swatchHost, 'BOTTOM', 0, -14)

	frame.ClosePopups = function() texturePicker:CloseList() end
	frame.OnShow = function()
		texturePicker:CloseList()
		texturePicker:Paint()
		PaintStyles()
		PaintAccents()
		StylePreview(CurrentUnitFrames())
		BUILib.Defer(SyncSliders)
	end
	frame.accentables[#frame.accentables + 1] = function()
		texturePicker:Paint()
		PaintStyles()
		PaintAccents()
	end
end

local function BuildDone(frame)
	local badge = CreateFrame('Frame', nil, frame)
	badge:SetSize(76, 76)
	badge:SetPoint('CENTER', 0, 84)
	Skin().TipShell(badge)
	local check = badge:CreateTexture(nil, 'ARTWORK')
	check:SetSize(40, 40)
	check:SetPoint('CENTER')
	check:SetTexture(BUILib.GetLibMedia('check'))
	frame.accentables[#frame.accentables + 1] = function()
		local red, green, blue = Accent()
		BUILib.Skin.SetShellEdges(badge, { red, green, blue, 1 })
		check:SetVertexColor(red, green, blue, 1)
	end

	local heading = MakeText(frame, 24, 'You\'re all set', TEXT_BRIGHT)
	heading:SetPoint('TOP', badge, 'BOTTOM', 0, -22)

	local body = MakeText(frame, 12, 'Finish reloads your UI so everything you picked takes hold.', TEXT_BODY)
	body:SetPoint('TOP', heading, 'BOTTOM', 0, -10)

	local settingsHint = MakeText(frame, 11, 'Everything else lives in /bui, or the minimap button.', TEXT_LABEL)
	settingsHint:SetPoint('TOP', body, 'BOTTOM', 0, -8)
end

STEPS = {
	{ build = BuildWelcome, title = 'Welcome', nextText = 'Get Started' },
	{ build = BuildScale, title = 'Scale', summary = 'Get it sharp on your monitor', nextText = 'Continue' },
	{ build = BuildSkins, title = 'Skins', summary = 'Blizzard windows, but dark', nextText = 'Continue' },
	{ build = BuildTheme, title = 'Theme', summary = 'Your bars, your colors', nextText = 'Continue' },
	{ build = BuildDone, title = 'Done', nextText = 'Finish and reload' },
}

local DOT_SIZE, DOT_CURRENT_WIDTH, DOT_GAP = 6, 18, 6

local function BuildDots(card, count)
	local host = CreateFrame('Frame', nil, card)
	host:SetSize((count - 1) * (DOT_SIZE + DOT_GAP) + DOT_CURRENT_WIDTH, DOT_SIZE)
	host:SetPoint('BOTTOM', 0, 26)
	local dots = {}
	for dotIndex = 1, count do
		local dot = host:CreateTexture(nil, 'ARTWORK')
		dot:SetHeight(DOT_SIZE)
		dots[dotIndex] = dot
	end
	function host:Paint(current)
		local red, green, blue = Accent()
		local edge = PanelEdge()
		local cursor = 0
		for dotIndex, dot in ipairs(dots) do
			local width = dotIndex == current and DOT_CURRENT_WIDTH or DOT_SIZE
			dot:ClearAllPoints()
			dot:SetPoint('LEFT', self, 'LEFT', cursor, 0)
			dot:SetWidth(width)
			if dotIndex == current then
				dot:SetColorTexture(red, green, blue, 1)
			elseif dotIndex < current then
				dot:SetColorTexture(TEXT_LABEL[1], TEXT_LABEL[2], TEXT_LABEL[3], 1)
			else
				dot:SetColorTexture(edge[1], edge[2], edge[3], 1)
			end
			cursor = cursor + width + DOT_GAP
		end
	end
	return host
end

local function BuildWizard(onClosed)
	local wizardInstance = { step = 1 }

	local overlay = CreateFrame('Frame', nil, UIParent)
	overlay:SetAllPoints(UIParent)
	overlay:SetFrameStrata('FULLSCREEN_DIALOG')
	overlay:SetFrameLevel(100)
	overlay:EnableMouse(true)
	overlay:EnableKeyboard(true)
	local dim = overlay:CreateTexture(nil, 'BACKGROUND')
	dim:SetAllPoints(overlay)
	dim:SetColorTexture(OVERLAY_DIM[1], OVERLAY_DIM[2], OVERLAY_DIM[3], OVERLAY_DIM[4])
	wizardInstance.overlay = overlay

	local card = CreateFrame('Frame', nil, overlay)
	card:SetSize(DIALOG_WIDTH, DIALOG_HEIGHT)
	card:EnableMouse(true)
	Skin().TipShell(card)
	wizardInstance.card = card

	local function FitCard()
		local screenWidth, screenHeight = GetPhysicalScreenSize()
		card:SetScale(BUI.DeviceScale() / UIParent:GetScale())
		card:ClearAllPoints()
		card:SetPoint('TOPLEFT', overlay, 'TOPLEFT', math.floor((screenWidth - DIALOG_WIDTH) / 2), -math.floor((screenHeight - DIALOG_HEIGHT) / 2))
	end
	wizardInstance.FitCard = FitCard
	FitCard()

	local stepTitle = MakeText(card, 11, '', TEXT_BODY)
	stepTitle:SetPoint('TOPLEFT', 18, -16)
	local exitButton = CreateFrame('Button', nil, card)
	exitButton:SetSize(22, 22)
	exitButton:SetPoint('TOPRIGHT', -12, -10)
	Skin().TipClose(exitButton)
	exitButton:SetScript('OnClick', function() wizardInstance:Exit() end)
	Widget.Tooltip(exitButton, 'Exit setup')
	local headerLine = card:CreateTexture(nil, 'BORDER')
	headerLine:SetPoint('TOPLEFT', 1, -42)
	headerLine:SetPoint('TOPRIGHT', -1, -42)
	headerLine:SetHeight(1)
	local edge = PanelEdge()
	headerLine:SetColorTexture(edge[1], edge[2], edge[3], edge[4])

	local function Close()
		if wizardInstance.closed then return end
		wizardInstance.closed = true
		overlay:Hide()
	end
	wizardInstance.Close = Close

	overlay:SetScript('OnKeyDown', function(self, key)
		if key == 'ESCAPE' then
			self:SetPropagateKeyboardInput(false)
			Close()
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)

	wizardInstance.frames = {}
	for stepIndex, step in ipairs(STEPS) do
		local stepFrame = CreateFrame('Frame', nil, card)
		stepFrame:SetPoint('TOPLEFT', 36, -64)
		stepFrame:SetPoint('BOTTOMRIGHT', -36, 72)
		stepFrame.accentables = {}
		step.build(stepFrame)
		stepFrame:Hide()
		wizardInstance.frames[stepIndex] = stepFrame
	end

	local function ClosePopups()
		for _, stepFrame in ipairs(wizardInstance.frames) do
			if stepFrame.ClosePopups then stepFrame.ClosePopups() end
		end
	end
	overlay:SetScript('OnMouseDown', ClosePopups)
	card:SetScript('OnMouseDown', ClosePopups)

	local nextButton = MakeStepButton(card, 'Get Started', NEXT_MIN_WIDTH, function() wizardInstance:Next() end)
	nextButton:SetPoint('BOTTOMRIGHT', -20, 16)
	wizardInstance.nextBtn = nextButton

	local dots = BuildDots(card, #STEPS)
	wizardInstance.dots = dots

	local backButton = MakeButton(card, 'Back', 80, function() wizardInstance:Prev() end)
	backButton:SetPoint('BOTTOMLEFT', 20, 16)
	wizardInstance.backBtn = backButton

	function wizardInstance:ApplyAccent()
		self.dots:Paint(self.step)
		local frame = self.frames[self.step]
		if frame then
			for _, applyAccent in ipairs(frame.accentables) do applyAccent() end
		end
	end

	function wizardInstance:ShowStep(index, instant)
		local old = self.frames[self.step]
		self.step = index
		local new = self.frames[index]

		stepTitle:SetText(STEPS[index].title)
		self.backBtn:SetShown(index > 1 and index < #STEPS)
		self.nextBtn:SetText(STEPS[index].nextText)
		local welcome = index == 1
		self.dots:SetShown(not welcome)
		self.nextBtn:ClearAllPoints()
		if welcome then
			self.nextBtn:SetPoint('BOTTOM', 0, 16)
			FitButton(self.nextBtn, WELCOME_BUTTON_WIDTH)
		else
			self.nextBtn:SetPoint('BOTTOMRIGHT', -20, 16)
			FitButton(self.nextBtn, NEXT_MIN_WIDTH)
		end

		local function Reveal()
			new:SetAlpha(0)
			new:Show()
			if new.OnShow then new.OnShow() end
			self:ApplyAccent()
			Animation.To(new, 'alpha', 1, instant and 0 or 0.18)
		end

		if old and old ~= new and old:IsShown() then
			Animation.To(old, 'alpha', 0, instant and 0 or 0.1, { onComplete = function(hiddenFrame) hiddenFrame:Hide(); Reveal() end })
		else
			Reveal()
		end
	end

	function wizardInstance:Next()
		if self.step >= #STEPS then self:Finish() return end
		self:ShowStep(self.step + 1)
	end

	function wizardInstance:Prev()
		if self.step <= 1 then return end
		self:ShowStep(self.step - 1)
	end

	function wizardInstance:Suspend()
		self.suspended = true
		overlay:Hide()
	end

	function wizardInstance:Resume()
		if self.closed or not self.suspended then return end
		self.suspended = false
		overlay:Show()
		self:ApplyAccent()
	end

	function wizardInstance:Finish()
		self.Close()
		Skin().WriteSkinsEnabled(skinSelection)
		BUI.Print('Setup complete. Open settings anytime with |cff' .. BUI.C.COLOR_PINK .. '/bui|r.')
		BUI.Reload()
	end

	function wizardInstance:Exit()
		self.Close()
		BUI.Print('Setup closed. Run it anytime with |cff' .. BUI.C.COLOR_PINK .. '/bui install|r.')
	end

	overlay:HookScript('OnHide', function()
		if wizardInstance.suspended then return end
		wizard = nil
		if onClosed then onClosed() end
	end)

	return wizardInstance
end

BUI.Pixel.OnScaleChange('Installer', function()
	if wizard then wizard.FitCard() end
end)

function Installer.Open(onClosed)
	if wizard then return end
	SeedSelection()
	wizard = BuildWizard(onClosed)
	wizard:ShowStep(1, true)
	wizard.overlay:SetAlpha(0)
	wizard.overlay:Show()
	Animation.To(wizard.overlay, 'alpha', 1, 0.2)
end
