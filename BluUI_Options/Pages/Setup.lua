local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Layout = BUILib.Layout

local PAD = 24
local TILE_GAP = 16
local TILE_PAD = 20
local FOOTER_HEIGHT = 30
local FOOTER_GAP = 28
local LINE_HEIGHT = 32
local READOUT_SIZE = 48
local SLIDER_WIDTH = 360
local SCALE_TILE_HEIGHT = 84
local SCALE_APPLY_KEY = 'Setup.ScaleApply'
local HERO_WIDTH, HERO_HEIGHT = 180, 240
local WAVE_ANIMATION = 67
local WAVE_SECONDS = 2.4
local MOCK_WIDTH, MOCK_HEIGHT = 172, 80
local MOCK_TAB_HEIGHT = 22
local MOCK_ROWS = { 'Bluhu', 'Target' }
local SKIN_TILE_HEIGHT = 176
local SWATCH_WIDTH, SWATCH_HEIGHT = 96, 34
local STYLE_TILE_HEIGHT = 128
local BAND_HEIGHT = 150
local BAND_PAIR_WIDTH = 320
local BAND_FRAME_HEIGHT = 80
local BAND_GAP = 18
local ABSORB_X = 408
local ABSORB_GAP = 150
local ABSORB_SWATCH_Y = 6
local REFRESH_DELAY = 0.15
local STAGE_OPTIONS = { bare = true, absorbs = 'both' }
local BLIZZARD_BACKDROP = {
	bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
	edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
	tile = true, tileEdge = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local EDGES = {
	{ 'TOPLEFT', 'TOPRIGHT', 'SetHeight' },
	{ 'BOTTOMLEFT', 'BOTTOMRIGHT', 'SetHeight' },
	{ 'TOPLEFT', 'BOTTOMLEFT', 'SetWidth' },
	{ 'TOPRIGHT', 'BOTTOMRIGHT', 'SetWidth' },
}
local STEPS = {
	{ id = 'welcome', label = 'Welcome', sub = 'What this does' },
	{ id = 'scale', label = 'Scale', sub = 'Sharp on your monitor' },
	{ id = 'skins', label = 'Skins', sub = 'Blizzard windows, but dark' },
	{ id = 'theme', label = 'Theme', sub = 'Your bars, your colors' },
	{ id = 'finish', label = 'Finish', sub = 'Check and reload' },
}
local SCALE_PRESETS = {
	{ title = 'Auto', detail = 'Pixel-perfect for this screen' },
	{ title = '1440p', detail = 'Pixel-perfect on a 1440p display', value = 768 / 1440 },
	{ title = '4K', detail = 'Pixel-perfect on a 4K display', value = 768 / 2160 },
}

local done = {}
local skinSelection = {}

local function Skin()
	return BUI.Skinning
end

local function UnitFrames()
	return BUI.UnitFrames
end

local function Index(id)
	for index, step in ipairs(STEPS) do
		if step.id == id then return index end
	end
end

local function Go(page, id)
	local index = Index(id)
	if index > 1 then done[STEPS[index - 1].id] = true end
	page:Select(id)
end

local function Back(page, id)
	page:Select(id)
end

local function Block(parent, width)
	local frame = CreateFrame('Frame', nil, parent)
	frame:SetWidth(width)
	return frame
end

local function Heading(kit, frame, title, text, width)
	local titleText = kit.Text(frame, title, 13, 'text')
	titleText:SetPoint('TOPLEFT', 0, -(PAD + 2))
	local body = kit.Text(frame, text, 12, 'muted', math.min(width, 520))
	body:SetSpacing(4)
	body:SetPoint('TOPLEFT', titleText, 'BOTTOMLEFT', 0, -8)
	return PAD + 2 + kit.Height(titleText) + 8 + kit.Height(body) + PAD
end

local function Footer(kit, frame, y, back, forward)
	local anchor = kit.Button(frame, forward.text, 'primary', forward.onClick)
	anchor:SetPoint('TOPRIGHT', 0, -y)
	if back then
		local button = kit.Button(frame, 'Back', 'secondary', back)
		button:SetPoint('RIGHT', anchor, 'LEFT', -10, 0)
	end
	local rule = kit.DottedRule(frame)
	rule:SetPoint('BOTTOMLEFT')
	rule:SetPoint('BOTTOMRIGHT')
	frame:SetHeight(y + FOOTER_HEIGHT + PAD + 1)
	return frame
end

local function Choice(kit, parent, x, y, width, height, selected, onClick)
	local tile = CreateFrame('Button', nil, parent)
	tile:SetPoint('TOPLEFT', x, -y)
	tile:SetSize(width, height)
	kit.Fill(tile, 'panel'):SetAllPoints()
	for _, side in ipairs(EDGES) do
		local edge = kit.Fill(tile, selected and 'accent' or 'rule', 'BACKGROUND', 2)
		edge:SetPoint(side[1])
		edge:SetPoint(side[2])
		edge[side[3]](edge, selected and 2 or 1)
	end
	kit.Hover(tile)
	tile:SetScript('OnClick', onClick)
	local ring = kit.Disc(tile, 16, selected and 'accent' or 'faint')
	ring:SetPoint('TOPRIGHT', -14, -14)
	if selected then
		kit.Glyph(tile, 'check', 9, 'onAccent', 'OVERLAY'):SetPoint('CENTER', ring)
	else
		kit.Disc(tile, 13, 'panel', 'ARTWORK', 1):SetPoint('CENTER', ring)
	end
	return tile
end

local function Welcome(kit, _, parent, width, _, page)
	local frame = Block(parent, width)
	local y = Heading(kit, frame, ('Hey %s.'):format(UnitName('player')),
		'Four quick picks and you are back in the game. Everything applies as you go and nothing is permanent, so change your mind later in settings.', width - HERO_WIDTH - PAD)
	local lines = { 'Pick a scale that is sharp on your screen', 'Decide if Blizzard windows get the dark look', 'Pick how your unit frames look', 'Check the summary and reload' }
	for index, line in ipairs(lines) do
		local disc = kit.Disc(frame, 20, 'secondary')
		disc:SetPoint('TOPLEFT', 0, -y)
		kit.Text(frame, tostring(index), 10, 'secondaryText'):SetPoint('CENTER', disc)
		kit.Text(frame, line, 12, 'text'):SetPoint('LEFT', disc, 'RIGHT', 12, 0)
		y = y + LINE_HEIGHT
	end
	local hero = CreateFrame('PlayerModel', nil, frame)
	hero:SetSize(HERO_WIDTH, HERO_HEIGHT)
	hero:SetPoint('TOPRIGHT', 0, -PAD)
	hero:SetUnit('player')
	hero:SetFacing(0.35)
	hero:SetAnimation(WAVE_ANIMATION)
	BUI.Profiler.After('Setup hero wave', WAVE_SECONDS, function()
		if hero:IsVisible() then hero:SetAnimation(0) end
	end)
	return { Footer(kit, frame, math.max(y, PAD + HERO_HEIGHT) + 12, nil, { text = 'Start', onClick = function() Go(page, 'scale') end }) }
end

local function ApplyScale(value)
	BUI.GetDB().uiScale.scale = value
	BUI.ApplyScale()
	BUI.Scale.SyncButtons()
end

local function Scale(kit, shell, parent, width, _, page)
	local frame = Block(parent, width)
	local y = Heading(kit, frame, 'Interface scale', 'A pixel-perfect scale keeps every line sharp instead of smeared across half a pixel. Drag for a custom value, it applies when you let go.', width)
	local window = shell.window
	local best = BUI.ClampedUIScale()
	local minimum, maximum = BUI.ScaleBounds()
	local screenWidth, screenHeight = GetPhysicalScreenSize()

	local readout = kit.Text(frame, '', READOUT_SIZE, 'text')
	readout:SetPoint('TOPLEFT', 0, -y)
	local status = kit.Text(frame, '', 11, 'muted')
	status:SetPoint('TOPLEFT', readout, 'BOTTOMLEFT', 0, -6)
	local function Paint(value)
		local perfect = BUI.ApproxEqual(value, best)
		readout:SetText(('%.3f'):format(value))
		window:Paint(readout, perfect and 'accent' or 'text')
		window:Paint(status, perfect and 'accent' or 'muted')
		status:SetFormattedText(perfect and 'Pixel-perfect for %d x %d' or 'Off the pixel grid for %d x %d', screenWidth, screenHeight)
	end
	Paint(UIParent:GetScale())
	y = y + READOUT_SIZE + 6 + 14 + PAD

	local pending
	BUI.Scheduler.RegisterUpdate(SCALE_APPLY_KEY, function()
		if IsMouseButtonDown('LeftButton') then return end
		BUI.Scheduler.SetUpdateEnabled(SCALE_APPLY_KEY, false)
		local value = pending
		pending = nil
		if not value then return end
		ApplyScale(value)
		BUI.Profiler.After('Setup scale refresh', 0.05, function() page:Rebuild('scale') end)
	end, 0.1, false)
	local slider = kit.Slider(frame, SLIDER_WIDTH, { min = minimum, max = maximum, step = 0.001, get = function() return UIParent:GetScale() end, set = function(value)
		pending = value
		Paint(value)
		BUI.Scheduler.SetUpdateEnabled(SCALE_APPLY_KEY, true)
	end })
	slider:SetPoint('TOPLEFT', 0, -y)
	y = y + FOOTER_HEIGHT + PAD

	local current = UIParent:GetScale()
	local tileWidth = math.floor((width - TILE_GAP * 2) / 3)
	for index, preset in ipairs(SCALE_PRESETS) do
		local value = preset.value or best
		local tile = Choice(kit, frame, (index - 1) * (tileWidth + TILE_GAP), y, tileWidth, SCALE_TILE_HEIGHT, BUI.ApproxEqual(current, value), function()
			ApplyScale(value)
			BUI.Profiler.After('Setup scale refresh', 0.05, function() page:Rebuild('scale') end)
		end)
		kit.Text(tile, preset.title, 13, 'text'):SetPoint('TOPLEFT', TILE_PAD, -18)
		kit.Text(tile, preset.detail, 11, 'muted'):SetPoint('TOPLEFT', TILE_PAD, -38)
		kit.Text(tile, ('%.3f'):format(value), 11, 'faint'):SetPoint('TOPLEFT', TILE_PAD, -56)
	end
	y = y + SCALE_TILE_HEIGHT + FOOTER_GAP
	return { Footer(kit, frame, y, function() Back(page, 'welcome') end, { text = 'Next', onClick = function() Go(page, 'skins') end }) }
end

local function SkinOrder()
	local registry, order = Skin().GetSkinRegistry()
	return registry, order
end

local function SeedSelection()
	wipe(skinSelection)
	local _, order = SkinOrder()
	for _, id in ipairs(order) do skinSelection[id] = Skin().IsSkinEnabled(id) end
end

local function SelectionCounts()
	local _, order = SkinOrder()
	local count = 0
	for _, id in ipairs(order) do
		if skinSelection[id] then count = count + 1 end
	end
	return count, #order
end

local function ChooseAll(enabled)
	local _, order = SkinOrder()
	for _, id in ipairs(order) do skinSelection[id] = enabled end
end

local function MockRows(mock, makeRow)
	for rowIndex, rowText in ipairs(MOCK_ROWS) do
		local row = CreateFrame('Frame', nil, mock)
		row:SetPoint('TOPLEFT', 8, -34 - (rowIndex - 1) * 18)
		row:SetPoint('TOPRIGHT', -8, -34 - (rowIndex - 1) * 18)
		row:SetHeight(16)
		makeRow(row, rowText, rowIndex)
	end
end

local function SkinnedMock(kit, parent)
	local mock = CreateFrame('Frame', nil, parent)
	mock:SetSize(MOCK_WIDTH, MOCK_HEIGHT)
	Skin().TipShell(mock)
	kit.Text(mock, 'Contacts', 12, 'text'):SetPoint('TOPLEFT', 10, -9)
	local line = mock:CreateTexture(nil, 'BORDER')
	line:SetPoint('TOPLEFT', 8, -27)
	line:SetPoint('TOPRIGHT', -8, -27)
	line:SetHeight(1)
	line:SetColorTexture(1, 1, 1, 0.1)
	MockRows(mock, function(row, rowText, rowIndex)
		if rowIndex == 1 then
			local highlight = row:CreateTexture(nil, 'BACKGROUND')
			highlight:SetAllPoints(row)
			Skin().AccentTexture(highlight, 0.22)
		end
		kit.Text(row, rowText, 11, rowIndex == 1 and 'text' or 'muted'):SetPoint('LEFT', 4, 0)
		kit.Text(row, rowIndex == 1 and 'Online' or 'Away', 11, 'faint'):SetPoint('RIGHT', -4, 0)
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

local function BlizzardMock(parent)
	local mock = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	mock:SetSize(MOCK_WIDTH, MOCK_HEIGHT)
	mock:SetBackdrop(BLIZZARD_BACKDROP)
	local title = mock:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	title:SetPoint('TOPLEFT', 10, -9)
	title:SetText('Contacts')
	MockRows(mock, function(row, rowText, rowIndex)
		local name = row:CreateFontString(nil, 'OVERLAY', rowIndex == 1 and 'GameFontHighlightSmall' or 'GameFontNormalSmall')
		name:SetPoint('LEFT', 4, 0)
		name:SetText(rowText)
		local status = row:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
		status:SetPoint('RIGHT', -4, 0)
		status:SetText(rowIndex == 1 and 'Online' or 'Away')
	end)
	return mock
end

local function Skins(kit, _, parent, width, _, page)
	local frame = Block(parent, width)
	local y = Heading(kit, frame, 'Would you like our skins turned on?', 'One dark look across every Blizzard window, matching the rest of BluUI. Your picks land when setup finishes and the UI reloads, and single windows can be switched later under Skins in settings.', width)
	local selectedCount, total = SelectionCounts()
	local tileWidth = math.floor((width - TILE_GAP) / 2)
	local function Tile(index, selected, mock, title, note, enabled)
		local tile = Choice(kit, frame, (index - 1) * (tileWidth + TILE_GAP), y, tileWidth, SKIN_TILE_HEIGHT, selected, function()
			ChooseAll(enabled)
			page:Rebuild('skins')
		end)
		mock(tile):SetPoint('TOP', 0, -TILE_PAD)
		kit.Text(tile, title, 13, 'text'):SetPoint('TOPLEFT', TILE_PAD, -(TILE_PAD + MOCK_HEIGHT + 16))
		kit.Text(tile, note, 11, 'muted'):SetPoint('TOPLEFT', TILE_PAD, -(TILE_PAD + MOCK_HEIGHT + 36))
	end
	Tile(1, selectedCount == total, function(tile) return SkinnedMock(kit, tile) end, 'Yes, skin it all', ('All %d windows get the BluUI look'):format(total), true)
	Tile(2, selectedCount == 0, BlizzardMock, 'No, keep Blizzard\'s look', 'Every window stays as Blizzard made it', false)
	y = y + SKIN_TILE_HEIGHT + FOOTER_GAP
	return { Footer(kit, frame, y, function() Back(page, 'scale') end, { text = 'Next', onClick = function() Go(page, 'theme') end }) }
end

local function StyleSwatch(kit, tile, style)
	local swatch = CreateFrame('Frame', nil, tile)
	swatch:SetSize(SWATCH_WIDTH, SWATCH_HEIGHT)
	swatch:SetPoint('TOPLEFT', TILE_PAD, -TILE_PAD)
	kit.Box(swatch, 'input', 'rule')
	local red, green, blue
	if style.dark then
		red, green, blue = 0, 0, 0
	else
		red, green, blue = BUI.Tools.GetUnitClassColor('player')
	end
	local fill = swatch:CreateTexture(nil, 'ARTWORK')
	fill:SetTexture(BUILib.Widget.WHITE)
	fill:SetPoint('TOPLEFT', 1, -1)
	fill:SetPoint('BOTTOMLEFT', 1, 1)
	fill:SetWidth((SWATCH_WIDTH - 2) * 0.72)
	fill:SetVertexColor(red, green, blue, style.glass and 0.45 or 1)
	local background = style.uf.bgColor
	local rest = swatch:CreateTexture(nil, 'ARTWORK')
	rest:SetTexture(BUILib.Widget.WHITE)
	rest:SetPoint('TOPLEFT', fill, 'TOPRIGHT')
	rest:SetPoint('BOTTOMRIGHT', -1, 1)
	rest:SetVertexColor(background[1], background[2], background[3], background[4])
end

local function Theme(kit, _, parent, width, _, page)
	local module = UnitFrames()
	local frame = Block(parent, width)
	local y = Heading(kit, frame, 'Unit frames', 'Pick a look. It applies live and the frames below are the real thing, so judge it on those.', width)
	local match = kit.Switch(frame, BUI.Installer.MatchesGroupFrames, function(value)
		BUI.Installer.SetMatchGroupFrames(value)
		BUI.Installer.SyncGroupFrames()
	end)
	match:SetPoint('TOPRIGHT', 0, -PAD)
	kit.Text(frame, 'Match party and raid frames', 12, 'text'):SetPoint('RIGHT', match, 'LEFT', -10, 0)
	local applied = BUI.Installer.AppliedStyle()
	local tileWidth = math.floor((width - TILE_GAP * 3) / 4)
	for index, style in ipairs(BUI.Installer.FRAME_STYLES) do
		local tile = Choice(kit, frame, (index - 1) * (tileWidth + TILE_GAP), y, tileWidth, STYLE_TILE_HEIGHT, applied == style, function()
			BUI.Installer.ApplyFrameStyle(style)
			page:Rebuild('theme')
		end)
		StyleSwatch(kit, tile, style)
		kit.Text(tile, style.name, 13, 'text'):SetPoint('TOPLEFT', TILE_PAD, -(TILE_PAD + SWATCH_HEIGHT + 16))
		kit.Text(tile, style.tip, 11, 'muted', tileWidth - TILE_PAD * 2):SetPoint('TOPLEFT', TILE_PAD, -(TILE_PAD + SWATCH_HEIGHT + 36))
	end
	y = y + STYLE_TILE_HEIGHT + PAD

	local band = kit.PreviewBand(frame, width, BAND_HEIGHT)
	band:SetPoint('TOPLEFT', 0, -y)
	local stage = CreateFrame('Frame', nil, band)
	stage:SetAllPoints()
	stage:SetClipsChildren(true)
	local captions = { kit.Text(stage, 'PLAYER', 9, 'faint'), kit.Text(stage, 'TARGET', 9, 'faint') }
	local notice = kit.Text(stage, 'Preview after combat', 12, 'muted')
	notice:SetPoint('CENTER')
	local captionY = -(BAND_HEIGHT / 2) + 16
	local function PaintStage()
		local combat = InCombatLockdown()
		notice:SetShown(combat)
		for _, caption in ipairs(captions) do caption:Hide() end
		if combat then return end
		module.ClearStage(stage)
		local playerX, targetX = module.StagePair(stage, kit, BAND_PAIR_WIDTH, BAND_FRAME_HEIGHT, BAND_GAP, STAGE_OPTIONS)
		if not playerX then return end
		for index, x in ipairs({ playerX, targetX }) do
			captions[index]:ClearAllPoints()
			captions[index]:SetPoint('CENTER', stage, 'CENTER', x, captionY)
			captions[index]:Show()
		end
	end
	PaintStage()
	y = y + BAND_HEIGHT + PAD

	local settings = BUI.GetDB().unitFrames
	local Apply = BUI.Dispatcher.NewDelayed(function()
		module.InvalidateSettingsCache()
		module:Refresh()
		BUI.Installer.SyncGroupFrames()
		PaintStage()
	end, REFRESH_DELAY, 'Setup theme refresh')
	kit.Text(frame, 'Health fill opacity', 12, 'text'):SetPoint('TOPLEFT', 0, -y)
	local slider = kit.Slider(frame, SLIDER_WIDTH, { min = 0, max = 100, step = 5,
		get = function() return settings.transparentHealth and math.floor(settings.healthBarAlpha * 100 + 0.5) or 100 end,
		set = function(value)
			settings.healthBarAlpha = value / 100
			settings.transparentHealth = value < 100
			Apply()
		end })
	slider:SetPoint('TOPLEFT', 0, -(y + 22))
	kit.Text(frame, 'Absorb colors', 12, 'text'):SetPoint('TOPLEFT', ABSORB_X, -y)
	local function AbsorbSwatch(x, label, key)
		local swatch = kit.ColorSwatch(frame, {
			opacity = true,
			tooltip = label,
			get = function()
				local color = settings[key]
				return color[1], color[2], color[3], color[4] or 1
			end,
			set = function(red, green, blue, alpha) settings[key] = { red, green, blue, alpha } end,
		}, Apply)
		swatch:SetPoint('TOPLEFT', x, -(y + 22 + ABSORB_SWATCH_Y))
		kit.Text(frame, label, 12, 'muted'):SetPoint('LEFT', swatch, 'RIGHT', 8, 0)
	end
	AbsorbSwatch(ABSORB_X, 'Damage absorb', 'shieldColor')
	AbsorbSwatch(ABSORB_X + ABSORB_GAP, 'Heal absorb', 'healAbsorbColor')
	y = y + 22 + FOOTER_HEIGHT + FOOTER_GAP
	return { Footer(kit, frame, y, function() Back(page, 'skins') end, { text = 'Next', onClick = function() Go(page, 'finish') end }) }
end

local function Finish(kit, _, parent, width, _, page)
	local selectedCount, total = SelectionCounts()
	local style = BUI.Installer.AppliedStyle()
	local summary = kit.Section(parent, width, {
		stacked = true,
		title = 'Summary',
		description = 'What you picked. Go back to change anything, or finish to reload and keep it.',
		columns = { { 'Setting', kit.NAME_X }, { 'Value', math.floor(width * 0.5) } },
	})
	local scale = UIParent:GetScale()
	local rows = {
		{ 'Scale', ('%.3f%s'):format(scale, BUI.ApproxEqual(scale, BUI.ClampedUIScale()) and ', pixel-perfect' or ''), 'resize' },
		{ 'Skins', selectedCount == total and ('All %d windows'):format(total) or selectedCount == 0 and 'None' or ('%d of %d windows'):format(selectedCount, total), 'eye' },
		{ 'Unit frames', style and (style.name .. (BUI.Installer.MatchesGroupFrames() and ', also party and raid' or '')) or 'Unchanged', 'profile' },
	}
	for _, entry in ipairs(rows) do
		local row = summary:AddRow(entry[1] .. ' ' .. entry[2])
		kit.IconAvatar(row, 28, entry[3]):SetPoint('LEFT', kit.AVATAR_X, 0)
		kit.RowTitle(row, entry[1], nil, kit.NAME_X)
		kit.Cell(row, entry[2], math.floor(width * 0.5))
	end
	local frame = Block(parent, width)
	return { summary, Footer(kit, frame, PAD, function() Back(page, 'theme') end, { text = 'Finish and reload', onClick = function()
		Skin().WriteSkinsEnabled(skinSelection)
		BUI.Print('Setup complete. Open settings anytime with |cff' .. BUI.C.COLOR_PINK .. '/bui|r.')
		ReloadUI()
	end }) }
end

local BUILDERS = { welcome = Welcome, scale = Scale, skins = Skins, theme = Theme, finish = Finish }

BUI.OptionsWindow.New('setup', {
	title = 'Setup BluUI',
	brand = false,
	icon = 'check',
	globalName = 'BluUISetupFrame',
	onOpen = function(shell)
		SeedSelection()
		wipe(done)
		shell:RebuildPage('setup')
	end,
	onClosed = function()
		BUI.Print('Setup closed. Run it anytime with |cff' .. BUI.C.COLOR_PINK .. '/bui install|r.')
	end,
	build = function(tab, shell)
		Layout.RailPage(tab, shell, {
			icon = 'check',
			title = 'Setup BluUI',
			rail = { style = 'steps', groups = { { items = STEPS } }, isDone = function(step) return done[step.id] end },
			build = function(kit, pageShell, parent, width, item, railPage)
				return BUILDERS[item.id](kit, pageShell, parent, width, item, railPage)
			end,
		})
	end,
})
