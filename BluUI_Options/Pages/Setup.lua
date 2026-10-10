local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Layout = BUILib.Layout

local PAD = 24
local TILE_GAP = 16
local TILE_PAD = 20
local FOOTER_HEIGHT = 30
local FOOTER_GAP = 28
local STEP_HEIGHT = 580
local LINE_HEIGHT = 32
local SLIDER_WIDTH = 360
local SCALE_TILE_HEIGHT = 108
local SCALE_TILE_PAD = 18
local SCALE_COLUMNS = 3
local SCALE_SLIDER_WIDTH = 520
local SCALE_BOX_WIDTH = 160
local SCALE_READOUT = 44
local SCALE_CUSTOM_GAP = 20
local SCALE_APPLY_KEY = 'Setup.ScaleApply'
local HERO_WIDTH, HERO_HEIGHT = 180, 240
local WAVE_ANIMATION = 67
local WAVE_SECONDS = 2.4
local MOCK_WIDTH, MOCK_HEIGHT = 172, 80
local MOCK_TAB_HEIGHT = 22
local MOCK_ROWS = { 'Bluhu', 'Target' }
local SKIN_TILE_HEIGHT = 238
local SKIN_WELL_INSET = 12
local SKIN_PREVIEW_HEIGHT = 150
local SKIN_TEXT_GAP = 20
local SWATCH_WIDTH, SWATCH_HEIGHT = 96, 34
local STYLE_TILE_HEIGHT = 110
local BAND_HEIGHT = 124
local BAND_PAIR_WIDTH = 320
local BAND_FRAME_HEIGHT = 80
local BAND_GAP = 18
local THEME_ROW_HEIGHT = 48
local THEME_GAP = 16
local THEME_SLIDER_WIDTH = 300
local THEME_SWATCH_GAP = 8
local THEME_SWATCH_SPACING = 28
local STYLE_NOTES = {
	classglass = 'Class color, glass',
	classsolid = 'Class color, solid',
	darkglass = 'Black on white, glass',
	darksolid = 'Black on white, solid',
}
local BLU_PROFILE = 'Blu'
local PROFILE_COLUMNS = 3
local PROFILE_TILE_HEIGHT = 124
local PROFILE_AVATAR = 32
local SUMMARY_COLUMNS = 3
local BAR_ROW_HEIGHT = 72
local GAME_ICON_CROP = 0.08
local BAR_ROW_GAP = 10
local BAR_TEXT_X = 66
local BAR_STATE_RIGHT = 52
local BAR_STATE_WIDTH = 120
local BAR_ADDONS = { 'Bartender4', 'Dominos', 'Neuron', 'RazerNaga' }
local OTHER_UI = { 'ElvUI', 'EllesmereUI', 'Tukui', 'Baganator', 'Bagnon', 'AdiBags', 'ArkInventory', 'BetterBags' }
local SUITE_PREFIX = '^EllesmereUI'
local SKINS_OFF_BY_DEFAULT = { experiencebar = true }
local SUMMARY_CARD_HEIGHT = 148
local SUMMARY_AVATAR = 28
local SUMMARY_READOUT = 40
local CARD_RADIUS = 8
local FIRST_LETTER = '[%z\1-\127\194-\244][\128-\191]*'
local REFRESH_DELAY = 0.15
local STAGE_OPTIONS = { bare = true, absorbs = 'both' }
local BLIZZARD_BACKDROP = {
	bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
	edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
	tile = true, tileEdge = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local STEPS = {
	{ id = 'welcome', label = 'Welcome', sub = 'What this does' },
	{ id = 'profile', label = 'Profile', sub = 'Start from one' },
	{ id = 'scale', label = 'Scale', sub = 'Sharp on your monitor' },
	{ id = 'skins', label = 'Skins', sub = 'Blizzard windows, but dark' },
	{ id = 'theme', label = 'Theme', sub = 'Your bars, your colors' },
	{ id = 'bars', label = 'Action bars', sub = 'Ours or yours' },
	{ id = 'finish', label = 'Finish', sub = 'Check and reload' },
}

local done = {}
local skinSelection = {}
local barsChoice, barsVisited = 'ours', false
local NeedsBarsStep
local openingProfile, pendingProfile, pendingNew, lookSnapshot
local themeVisited, scaleVisited, finishing = false, false, false
local scaleChoice
local SCALE_SCREENS = {
	{ key = '1080', title = '1080p', height = 1080, note = '1920 x 1080' },
	{ key = '1440', title = '1440p', height = 1440, note = '2560 x 1440' },
	{ key = '4k', title = '4K', height = 2160, note = '3840 x 2160' },
}
local UNIT_LOOK_KEYS = { 'transparentHealth', 'healthBarAlpha', 'classColorHealth', 'classColorPower', 'bgColor', 'healthColor', 'shieldColor', 'healAbsorbColor' }
local GROUP_LOOK_KEYS = { 'transparentHealth', 'healthOpacity', 'useClassColor', 'healthColor', 'bgColor' }
local GROUP_LOOK_NESTED = { 'absorb', 'healAbsorb' }
local GROUP_UNITS = { 'party', 'raid' }

local function CopyValue(value)
	if type(value) == 'table' then return CopyTable(value) end
	return value
end

local function CaptureLook(profile)
	local look = { unitFrames = {}, groups = {}, scale = profile.uiScale and profile.uiScale.scale }
	for _, key in ipairs(UNIT_LOOK_KEYS) do look.unitFrames[key] = CopyValue(profile.unitFrames[key]) end
	for _, unit in ipairs(GROUP_UNITS) do
		local section, saved = profile.groupFrames[unit], {}
		for _, key in ipairs(GROUP_LOOK_KEYS) do saved[key] = CopyValue(section[key]) end
		for _, group in ipairs(GROUP_LOOK_NESTED) do saved[group] = CopyValue(section[group] and section[group].color) end
		look.groups[unit] = saved
	end
	return look
end

local function WriteLook(profile, look, withTheme, withScale)
	if withTheme then
		for _, key in ipairs(UNIT_LOOK_KEYS) do profile.unitFrames[key] = CopyValue(look.unitFrames[key]) end
		for _, unit in ipairs(GROUP_UNITS) do
			local section, saved = profile.groupFrames[unit], look.groups[unit]
			for _, key in ipairs(GROUP_LOOK_KEYS) do section[key] = CopyValue(saved[key]) end
			for _, group in ipairs(GROUP_LOOK_NESTED) do
				if section[group] then section[group].color = CopyValue(saved[group]) end
			end
		end
	end
	if withScale and look.scale ~= nil then profile.uiScale.scale = look.scale end
end

local function ProfileExists(name)
	for _, existing in pairs(BUI.GetAceDB():GetProfiles()) do
		if existing == name then return true end
	end
	return false
end

local function CommitProfile()
	local aceDB = BUI.GetAceDB()
	if not pendingProfile or pendingProfile == aceDB:GetCurrentProfile() then return end
	local edited = CaptureLook(BUI.GetDB())
	if lookSnapshot then WriteLook(BUI.GetDB(), lookSnapshot, true, true) end
	local existed = ProfileExists(pendingProfile)
	BUI._suppressProfileCallback = true
	aceDB:SetProfile(pendingProfile)
	if not existed then BUI.ExportImport.ApplyDefaultProfile(BUI.GetDB()) end
	BUI.MigrateProfile(BUI.GetDB())
	BUI._suppressProfileCallback = nil
	WriteLook(BUI.GetDB(), edited, themeVisited, scaleVisited)
end

local function KeptProfiles()
	local keep = { Default = true }
	keep[BUI.GetAceDB():GetCurrentProfile()] = true
	for _, profileName in pairs(BUI.db.sv.profileKeys or {}) do keep[profileName] = true end
	for _, character in pairs(BUI.db.sv.char or {}) do
		local store = type(character) == 'table' and character.specProfiles
		local map = type(store) == 'table' and store.map
		if type(map) == 'table' then
			for _, profileName in pairs(map) do keep[profileName] = true end
		end
	end
	return keep
end

local function CharacterNames()
	local names = {}
	for charKey in pairs(BUI.db.sv.profileKeys or {}) do
		local name = charKey:match('^(.-) %- ')
		if name then names[name] = true end
	end
	return names
end

local function RemoveLeftoverProfiles()
	local aceDB = BUI.GetAceDB()
	local keep, characters, removed = KeptProfiles(), CharacterNames(), {}
	for _, name in pairs(aceDB:GetProfiles()) do
		local base = name:match('^(.-) %d+$') or name
		if not keep[name] and (characters[base] or name == BLU_PROFILE) then
			aceDB:DeleteProfile(name, true)
			removed[#removed + 1] = name
		end
	end
	if #removed > 0 then
		table.sort(removed)
		BUI.Print('Setup removed profiles an unfinished setup left behind: ' .. table.concat(removed, ', ') .. '.')
	end
end

local function RestoreOpeningLook()
	if finishing or not lookSnapshot or pendingProfile == openingProfile then return end
	BUI.Events:AfterCombat(function()
		WriteLook(BUI.GetDB(), lookSnapshot, true, true)
		BUI.ApplyScale()
		BUI.Scale.SyncButtons()
		BUI.ExportImport.RefreshAllModules()
	end, 'Setup.RestoreOpeningLook')
end

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

local function Show(page, id)
	if id == 'finish' then page:Rebuild('finish') end
	page:Select(id)
end

local function Go(page, id)
	local index = Index(id)
	if index > 1 then done[STEPS[index - 1].id] = true end
	Show(page, id)
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

local function Footer(kit, frame, y, back, forward, above)
	frame:SetHeight(math.max(y + FOOTER_HEIGHT + PAD + 1, STEP_HEIGHT - (above or 0)))
	local anchor = kit.Button(frame, forward.text, 'primary', forward.onClick)
	anchor:SetPoint('BOTTOMRIGHT', 0, PAD + 1)
	if back then
		local button = kit.Button(frame, 'Back', 'secondary', back)
		button:SetPoint('RIGHT', anchor, 'LEFT', -10, 0)
	end
	local rule = kit.DottedRule(frame)
	rule:SetPoint('BOTTOMLEFT')
	rule:SetPoint('BOTTOMRIGHT')
	return frame
end

local function Choice(kit, parent, x, y, width, height, selected, onClick)
	return kit.ChoiceCard(parent, x, y, width, height, selected, onClick)
end

local function Welcome(kit, _, parent, width, _, page)
	local frame = Block(parent, width)
	local y = Heading(kit, frame, ('Hey %s.'):format(UnitName('player')),
		'A few quick picks and you are back in the game. Everything applies as you go and nothing is permanent, so change your mind later in settings.', width - HERO_WIDTH - PAD)
	local lines = { "Start from Blu's profile, one of yours, or your own", 'Pick a scale that is sharp on your screen', 'Decide if Blizzard windows get the dark look', 'Pick how your unit frames look', 'Choose who runs your action bars', 'Check the summary and reload' }
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
	return { Footer(kit, frame, math.max(y, PAD + HERO_HEIGHT) + 12, nil, { text = 'Start', onClick = function() Go(page, 'profile') end }) }
end

local function ApplyScale(value)
	BUI.GetDB().uiScale.scale = value
	BUI.ApplyScale()
	BUI.Scale.SyncButtons()
end

local function ExactScale(value)
	return ('%.16g'):format(value)
end

local function CurrentScale()
	local saved = BUI.GetDB().uiScale.scale
	if saved and BUI.ApproxEqual(saved, UIParent:GetScale()) then return saved end
	return UIParent:GetScale()
end

local function Scale(kit, shell, parent, width, _, page)
	scaleVisited = true
	local best = BUI.ClampedUIScale()
	local minimum, maximum = BUI.ScaleBounds()
	local screenWidth, screenHeight = GetPhysicalScreenSize()
	local current = CurrentScale()
	local choices = { { key = 'auto', title = 'Auto', note = 'Your screen', value = best, height = screenHeight } }
	for _, screen in ipairs(SCALE_SCREENS) do
		choices[#choices + 1] = { key = screen.key, title = screen.title, note = screen.note, value = 768 / screen.height, height = screen.height }
	end
	choices[#choices + 1] = { key = 'custom', title = 'Custom', note = 'Use the slider' }
	if not scaleChoice then
		scaleChoice = 'custom'
		for _, choice in ipairs(choices) do
			if choice.value and BUI.ApproxEqual(current, choice.value) then scaleChoice = choice.key break end
		end
	end
	local chosen
	for _, choice in ipairs(choices) do
		if choice.key == scaleChoice then chosen = choice end
	end

	local frame = Block(parent, width)
	local y = Heading(kit, frame, 'Interface scale', ('Pixel-perfect means one point of the UI lands on exactly one pixel of your screen, so every border is a crisp line. The scale for that is 768 divided by your screen height. Yours is %d pixels tall.'):format(screenHeight), width)

	local readout = kit.Text(frame, '', SCALE_READOUT, 'text', nil, 'title')
	readout:SetPoint('TOPLEFT', 0, -y)
	local status = kit.Text(frame, '', 12, 'muted')
	status:SetPoint('TOPLEFT', readout, 'BOTTOMLEFT', 0, -8)
	local function Paint(value)
		readout:SetText(ExactScale(value))
		if chosen.height then
			status:SetText(('768 / %d. Pixel-perfect on a screen %d pixels tall.'):format(chosen.height, chosen.height))
		elseif BUI.ApproxEqual(value, best) then
			status:SetText(('Pixel-perfect for your %d x %d screen.'):format(screenWidth, screenHeight))
		else
			status:SetText('Not pixel-perfect, so some lines may look soft.')
		end
	end
	Paint(chosen.value or current)
	y = y + SCALE_READOUT + 8 + 16 + PAD

	local function Refresh() BUI.Profiler.After('Setup scale refresh', 0.05, function() page:Rebuild('scale') end) end
	local tileWidth = math.floor((width - TILE_GAP * (SCALE_COLUMNS - 1)) / SCALE_COLUMNS)
	local textWidth = tileWidth - SCALE_TILE_PAD * 2
	for index, choice in ipairs(choices) do
		local column, row = (index - 1) % SCALE_COLUMNS, math.floor((index - 1) / SCALE_COLUMNS)
		local tile = Choice(kit, frame, column * (tileWidth + TILE_GAP), y + row * (SCALE_TILE_HEIGHT + TILE_GAP), tileWidth, SCALE_TILE_HEIGHT, choice.key == scaleChoice, function()
			scaleChoice = choice.key
			if choice.value then
				ApplyScale(choice.value)
				Refresh()
			else
				page:Rebuild('scale')
			end
		end)
		local title = kit.Text(tile, choice.title, 15, 'text', textWidth, 'title')
		title:SetWordWrap(false)
		title:SetPoint('TOPLEFT', SCALE_TILE_PAD, -SCALE_TILE_PAD)
		local note = kit.Text(tile, choice.note, 12, 'muted', textWidth)
		note:SetWordWrap(false)
		note:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -8)
		local value = choice.value or (choice.key == scaleChoice and current)
		local exact = kit.Text(tile, value and ExactScale(value) or 'Your own size', 12, 'muted', textWidth)
		exact:SetWordWrap(false)
		exact:SetPoint('BOTTOMLEFT', SCALE_TILE_PAD, SCALE_TILE_PAD)
	end
	local rows = math.ceil(#choices / SCALE_COLUMNS)
	y = y + rows * SCALE_TILE_HEIGHT + (rows - 1) * TILE_GAP

	if scaleChoice == 'custom' then
		y = y + SCALE_CUSTOM_GAP
		local pending
		BUI.Scheduler.RegisterUpdate(SCALE_APPLY_KEY, function()
			if IsMouseButtonDown('LeftButton') then return end
			BUI.Scheduler.SetUpdateEnabled(SCALE_APPLY_KEY, false)
			local value = pending
			pending = nil
			if not value then return end
			ApplyScale(value)
			Refresh()
		end, 0.1, false)
		local slider = kit.Slider(frame, SCALE_SLIDER_WIDTH, { min = minimum, max = maximum, step = 0.001, precise = true, boxWidth = SCALE_BOX_WIDTH, format = ExactScale, get = function() return CurrentScale() end, set = function(value)
			pending = value
			Paint(value)
			BUI.Scheduler.SetUpdateEnabled(SCALE_APPLY_KEY, true)
		end })
		slider:SetPoint('TOPLEFT', 0, -y)
		y = y + FOOTER_HEIGHT
	end
	y = y + FOOTER_GAP
	return { Footer(kit, frame, y, function() Back(page, 'profile') end, { text = 'Next', onClick = function() Go(page, 'skins') end }) }
end

local function SkinOrder()
	local registry, order = Skin().GetSkinRegistry()
	return registry, order
end

local function SeedSelection()
	wipe(skinSelection)
	local _, order = SkinOrder()
	for _, id in ipairs(order) do skinSelection[id] = not SKINS_OFF_BY_DEFAULT[id] end
end

local function SelectionCounts()
	local _, order = SkinOrder()
	local count, total = 0, 0
	for _, id in ipairs(order) do
		if not SKINS_OFF_BY_DEFAULT[id] then
			total = total + 1
			if skinSelection[id] then count = count + 1 end
		end
	end
	return count, total
end

local function ChooseAll(enabled)
	local _, order = SkinOrder()
	for _, id in ipairs(order) do skinSelection[id] = enabled and not SKINS_OFF_BY_DEFAULT[id] end
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
		if tab.Text then
			if tabIndex == 1 then tab.Text:SetTextColor(1, 1, 1, 1) else tab.Text:SetTextColor(0.6, 0.62, 0.66, 1) end
		end
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

local function ProfileUsers(name)
	local myKey = BUI.db.keys.char
	local count, mine = 0, false
	for charKey, value in pairs(BUI.db.sv.profileKeys or {}) do
		if value == name then
			count = count + 1
			if charKey == myKey then mine = true end
		end
	end
	if mine then return count == 1 and 'This character only' or ('This character and %d more'):format(count - 1) end
	if count == 0 then return 'Not used by any character yet' end
	return ('Used by %d character%s'):format(count, count == 1 and '' or 's')
end

local function Initials(name)
	local letters = {}
	for word in name:gmatch('%S+') do
		letters[#letters + 1] = (word:match(FIRST_LETTER) or ''):upper()
		if #letters == 2 then break end
	end
	return table.concat(letters)
end

local function FreshProfileName()
	local taken = {}
	for _, name in pairs(BUI.GetAceDB():GetProfiles()) do taken[name] = true end
	local base = UnitName('player')
	local name, suffix = base, 1
	while taken[name] do
		suffix = suffix + 1
		name = ('%s %d'):format(base, suffix)
	end
	return name
end

local function PickProfile(page, name, isNew)
	pendingProfile, pendingNew = name, isNew
	page:Rebuild('profile')
end

local function Profile(kit, _, parent, width, _, page)
	local frame = Block(parent, width)
	local y = Heading(kit, frame, 'Pick a profile', "A profile is one full set of BluUI settings. Start from Blu's, keep the one you're on, or make your own. The next steps change whichever one you pick.", width)
	local current = openingProfile
	local tiles = { { name = BLU_PROFILE, title = BLU_PROFILE, note = "Bluhu's profile, ready to play", logo = true } }
	if current ~= BLU_PROFILE then tiles[#tiles + 1] = { name = current, title = current, note = ProfileUsers(current) } end
	local fresh = pendingNew and pendingProfile or FreshProfileName()
	tiles[#tiles + 1] = { name = fresh, title = 'Make your own', note = ('A new profile called %s, starting from the defaults'):format(fresh), create = true }

	local tileWidth = math.floor((width - TILE_GAP * (PROFILE_COLUMNS - 1)) / PROFILE_COLUMNS)
	local textWidth = tileWidth - TILE_PAD * 2
	for index, tile in ipairs(tiles) do
		local column, row = (index - 1) % PROFILE_COLUMNS, math.floor((index - 1) / PROFILE_COLUMNS)
		local card = Choice(kit, frame, column * (tileWidth + TILE_GAP), y + row * (PROFILE_TILE_HEIGHT + TILE_GAP), tileWidth, PROFILE_TILE_HEIGHT,
			(tile.create and pendingNew) or (not tile.create and not pendingNew and tile.name == pendingProfile), function() PickProfile(page, tile.name, tile.create == true) end)
		local avatar
		if tile.logo then
			avatar = card:CreateTexture(nil, 'ARTWORK')
			avatar:SetTexture(BUI.C.ICON_PATH)
			avatar:SetSize(PROFILE_AVATAR, PROFILE_AVATAR)
		elseif tile.create then
			avatar = kit.IconAvatar(card, PROFILE_AVATAR, 'plus')
		else
			avatar = kit.Initials(card, PROFILE_AVATAR, Initials(tile.name))
		end
		avatar:SetPoint('TOPLEFT', TILE_PAD, -TILE_PAD)
		local title = kit.Text(card, tile.title, 13, 'text', textWidth)
		title:SetWordWrap(false)
		title:SetPoint('TOPLEFT', TILE_PAD, -(TILE_PAD + PROFILE_AVATAR + 14))
		local note = kit.Text(card, tile.note, 11, 'muted', textWidth)
		note:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -6)
	end
	local rows = math.ceil(#tiles / PROFILE_COLUMNS)
	y = y + rows * PROFILE_TILE_HEIGHT + (rows - 1) * TILE_GAP + FOOTER_GAP
	return { Footer(kit, frame, y, function() Back(page, 'welcome') end, { text = 'Next', onClick = function()
		if pendingProfile ~= BLU_PROFILE then return Go(page, 'scale') end
		done.profile = true
		Show(page, NeedsBarsStep() and 'bars' or 'finish')
	end }) }
end

local function Skins(kit, shell, parent, width, _, page)
	local window = shell.window
	local frame = Block(parent, width)
	local y = Heading(kit, frame, 'Skins', 'Give every Blizzard window the same dark look as BluUI. Nothing changes until you finish, and you can switch single windows on or off later in Settings.', width)
	local selectedCount, total = SelectionCounts()
	local tileWidth = math.floor((width - TILE_GAP) / 2)
	local textTop = SKIN_WELL_INSET + SKIN_PREVIEW_HEIGHT + SKIN_TEXT_GAP
	local function Tile(index, selected, mock, title, note, enabled)
		local tile = Choice(kit, frame, (index - 1) * (tileWidth + TILE_GAP), y, tileWidth, SKIN_TILE_HEIGHT, selected, function()
			ChooseAll(enabled)
			page:Rebuild('skins')
		end)
		local well = CreateFrame('Frame', nil, tile)
		well:SetPoint('TOPLEFT', SKIN_WELL_INSET, -SKIN_WELL_INSET)
		well:SetPoint('TOPRIGHT', -SKIN_WELL_INSET, -SKIN_WELL_INSET)
		well:SetHeight(SKIN_PREVIEW_HEIGHT)
		local wellFill, wellEdge = BUILib.Widget.DrawCardShape(well, CARD_RADIUS, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
		window:Paint(wellFill, 'page')
		window:Paint(wellEdge, 'cardEdge')
		mock(well):SetPoint('CENTER', well, 'CENTER', 0, MOCK_TAB_HEIGHT / 2)
		tile.ring:ClearAllPoints()
		tile.ring:SetPoint('TOPRIGHT', -TILE_PAD, -textTop)
		local textWidth = tileWidth - TILE_PAD * 3 - 16
		local heading = kit.Text(tile, title, 14, 'text', textWidth, 'title')
		heading:SetPoint('TOPLEFT', TILE_PAD, -textTop)
		local detail = kit.Text(tile, note, 12, 'muted', textWidth)
		detail:SetPoint('TOPLEFT', heading, 'BOTTOMLEFT', 0, -8)
	end
	Tile(1, selectedCount == total, function(holder) return SkinnedMock(kit, holder) end, 'Skin everything', ('All %d Blizzard windows get the dark look'):format(total), true)
	Tile(2, selectedCount == 0, BlizzardMock, "Keep Blizzard's look", 'Every window stays the way Blizzard made it', false)
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

local function Theme(kit, shell, parent, width, _, page)
	themeVisited = true
	local window = shell.window
	local module = UnitFrames()
	local frame = Block(parent, width)
	local y = Heading(kit, frame, 'Unit frames', 'Pick a look. The preview shows your real frames, and it changes as you click.', width)
	local applied = BUI.Installer.AppliedStyle()
	local tileWidth = math.floor((width - TILE_GAP * 3) / 4)
	for index, style in ipairs(BUI.Installer.FRAME_STYLES) do
		local tile = Choice(kit, frame, (index - 1) * (tileWidth + TILE_GAP), y, tileWidth, STYLE_TILE_HEIGHT, applied == style, function()
			BUI.Installer.ApplyFrameStyle(style)
			page:Rebuild('theme')
		end)
		StyleSwatch(kit, tile, style)
		kit.Text(tile, style.name, 13, 'text'):SetPoint('TOPLEFT', TILE_PAD, -(TILE_PAD + SWATCH_HEIGHT + 16))
		kit.Text(tile, STYLE_NOTES[style.key] or style.tip, 11, 'muted', tileWidth - TILE_PAD * 2):SetPoint('TOPLEFT', TILE_PAD, -(TILE_PAD + SWATCH_HEIGHT + 36))
	end
	y = y + STYLE_TILE_HEIGHT + THEME_GAP

	local band = kit.PreviewBand(frame, width, BAND_HEIGHT)
	band:SetPoint('TOPLEFT', 0, -y)
	local stage = CreateFrame('Frame', nil, band)
	stage:SetAllPoints()
	stage:SetClipsChildren(true)
	local captions = { kit.Text(stage, 'PLAYER', 9, 'faint'), kit.Text(stage, 'TARGET', 9, 'faint') }
	local notice = kit.Text(stage, 'Preview after combat', 12, 'muted')
	notice:SetPoint('CENTER')
	local captionY = -(BAND_HEIGHT / 2) + 12
	local function PaintStage()
		local combat = module.StageLocked()
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
	module.WatchStage(stage, PaintStage)
	y = y + BAND_HEIGHT + THEME_GAP

	local settings = BUI.GetDB().unitFrames
	local Apply = BUI.Dispatcher.NewDelayed(function()
		module.InvalidateSettingsCache()
		module:Refresh()
		BUI.Installer.SyncGroupFrames()
		PaintStage()
	end, REFRESH_DELAY, 'Setup theme refresh')

	local rows = {
		{ title = 'Match party and raid frames', note = 'Party and raid frames get the same look', build = function(row)
			return kit.Switch(row, BUI.Installer.MatchesGroupFrames, function(value)
				BUI.Installer.SetMatchGroupFrames(value)
				BUI.Installer.SyncGroupFrames()
			end)
		end },
		{ title = 'Health fill opacity', note = 'How see-through the health bar is', build = function(row)
			return kit.Slider(row, THEME_SLIDER_WIDTH, { min = 0, max = 100, step = 5,
				get = function() return settings.transparentHealth and math.floor(settings.healthBarAlpha * 100 + 0.5) or 100 end,
				set = function(value)
					settings.healthBarAlpha = value / 100
					settings.transparentHealth = value < 100
					Apply()
				end })
		end },
		{ title = 'Absorb colors', note = 'Shields and heal absorbs on the health bar', build = function(row)
			local holder = CreateFrame('Frame', nil, row)
			local right
			for _, spec in ipairs({ { 'Heal absorb', 'healAbsorbColor' }, { 'Damage absorb', 'shieldColor' } }) do
				local label = kit.Text(holder, spec[1], 12, 'muted')
				if right then label:SetPoint('RIGHT', right, 'LEFT', -THEME_SWATCH_SPACING, 0) else label:SetPoint('RIGHT') end
				local swatch = kit.ColorSwatch(holder, {
					opacity = true,
					tooltip = spec[1],
					get = function()
						local color = settings[spec[2]]
						return color[1], color[2], color[3], color[4] or 1
					end,
					set = function(red, green, blue, alpha) settings[spec[2]] = { red, green, blue, alpha } end,
				}, Apply)
				swatch:SetPoint('RIGHT', label, 'LEFT', -THEME_SWATCH_GAP, 0)
				right = swatch
			end
			holder:SetSize(THEME_SLIDER_WIDTH, THEME_ROW_HEIGHT)
			return holder
		end },
	}
	local card = CreateFrame('Frame', nil, frame)
	card:SetPoint('TOPLEFT', 0, -y)
	card:SetSize(width, #rows * THEME_ROW_HEIGHT)
	local fill, edge = BUILib.Widget.DrawCardShape(card, CARD_RADIUS, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
	window:Paint(fill, 'card')
	window:Paint(edge, 'cardEdge')
	for index, spec in ipairs(rows) do
		local row = CreateFrame('Frame', nil, card)
		row:SetPoint('TOPLEFT', 0, -(index - 1) * THEME_ROW_HEIGHT)
		row:SetSize(width, THEME_ROW_HEIGHT)
		kit.Text(row, spec.title, 13, 'text'):SetPoint('BOTTOMLEFT', row, 'LEFT', TILE_PAD, 2)
		kit.Text(row, spec.note, 11, 'muted'):SetPoint('TOPLEFT', row, 'LEFT', TILE_PAD, -4)
		spec.build(row):SetPoint('RIGHT', -TILE_PAD, 0)
		if index > 1 then
			local rule = kit.Fill(row, 'cardEdge', 'ARTWORK')
			rule:SetPoint('TOPLEFT', TILE_PAD, 0)
			rule:SetPoint('TOPRIGHT', -TILE_PAD, 0)
			rule:SetHeight(1)
		end
	end
	y = y + #rows * THEME_ROW_HEIGHT + FOOTER_GAP
	return { Footer(kit, frame, y, function() Back(page, 'skins') end, { text = 'Next', onClick = function() Go(page, 'bars') end }) }
end


local function ElvUIBarSettings()
	local engine = C_AddOns.IsAddOnLoaded('ElvUI') and ElvUI and ElvUI[1]
	local private = type(engine) == 'table' and engine.private
	local bars = type(private) == 'table' and private.actionbar
	return type(bars) == 'table' and bars or nil
end

local function IsInstalled(name)
	if C_AddOns.DoesAddOnExist then return C_AddOns.DoesAddOnExist(name) end
	return C_AddOns.GetAddOnInfo(name) ~= nil
end

local function IsOnHere(name)
	return C_AddOns.IsAddOnLoaded(name) or C_AddOns.GetAddOnEnableState(name, UnitName('player')) > 0
end

local function EnableWithDependencies(name, character, seen)
	seen = seen or {}
	if seen[name] then return end
	seen[name] = true
	for _, dependency in ipairs({ C_AddOns.GetAddOnDependencies(name) }) do
		if IsInstalled(dependency) then EnableWithDependencies(dependency, character, seen) end
	end
	C_AddOns.EnableAddOn(name, character)
end

local function RivalBars()
	local found = {}
	for _, name in ipairs(BAR_ADDONS) do
		if IsInstalled(name) then found[#found + 1] = { name = name, label = name, on = IsOnHere(name) } end
	end
	if IsInstalled('ElvUI') then
		local settings = ElvUIBarSettings()
		found[#found + 1] = { name = 'ElvUI', label = "ElvUI's action bars", suite = true, on = settings ~= nil and settings.enable ~= false }
	end
	for index = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(index)
		if name and name:match(SUITE_PREFIX) and name:lower():find('actionbar', 1, true) then
			found[#found + 1] = { name = name, label = "EllesmereUI's action bars", on = IsOnHere(name) }
		end
	end
	return found
end

local function OtherUI()
	local found, seen = {}, {}
	for _, rival in ipairs(RivalBars()) do seen[rival.name] = true end
	for _, name in ipairs(OTHER_UI) do
		if not seen[name] and IsInstalled(name) and IsOnHere(name) then
			found[#found + 1] = name
			seen[name] = true
		end
	end
	if not seen.EllesmereUI then
		for index = 1, C_AddOns.GetNumAddOns() do
			local name = C_AddOns.GetAddOnInfo(index)
			if name and name:match(SUITE_PREFIX) and not seen[name] and IsOnHere(name) then
				found[#found + 1] = 'EllesmereUI'
				break
			end
		end
	end
	return found
end

NeedsBarsStep = function()
	return #RivalBars() > 0 or #OtherUI() > 0
end

local function JoinNames(names)
	if #names == 0 then return nil end
	if #names == 1 then return names[1] end
	return table.concat(names, ', ', 1, #names - 1) .. ' and ' .. names[#names]
end

local function BarOptions()
	local rivals = RivalBars()
	local options = { { key = 'ours', title = "Use BluUI's bars", value = 'BluUI', note = 'BluUI runs your action bars', logo = true } }
	for _, rival in ipairs(rivals) do
		local owner = rival.suite and 'ElvUI' or rival.name:match(SUITE_PREFIX) and 'EllesmereUI' or rival.name
		options[#options + 1] = { key = rival.name, title = 'Use ' .. rival.label, value = owner, note = owner .. ' runs your action bars', rival = owner }
	end
	if #rivals == 0 then options[#options + 1] = { key = 'blizzard', title = "Keep Blizzard's bars", value = 'Blizzard', note = "Blizzard's own action bars" } end
	return options, rivals
end

local function Outcomes()
	local list = { { label = "BluUI's action bars", before = BUI.GetDB().modules.actionBars ~= false, after = barsChoice == 'ours' } }
	for _, rival in ipairs(RivalBars()) do
		list[#list + 1] = { label = rival.label, before = rival.on, after = rival.name == barsChoice }
	end
	for _, outcome in ipairs(list) do
		if outcome.after then
			outcome.state, outcome.role = outcome.before and 'Stays on' or 'Turns on', 'positive'
		else
			outcome.state, outcome.role = outcome.before and 'Turns off' or 'Stays off', outcome.before and 'danger' or 'muted'
		end
	end
	return list
end

local function ApplyBars()
	if not barsVisited then return end
	BUI.GetDB().modules.actionBars = barsChoice == 'ours'
	local character = UnitName('player')
	for _, rival in ipairs(RivalBars()) do
		local chosen = rival.name == barsChoice
		if rival.suite then
			local settings = ElvUIBarSettings()
			if chosen then
				if not settings then
					EnableWithDependencies(rival.name, character)
				elseif settings.enable == false then
					settings.enable = true
				end
			elseif settings and settings.enable ~= false then
				settings.enable = false
			end
		elseif chosen and not rival.on then
			EnableWithDependencies(rival.name, character)
		elseif not chosen and rival.on then
			C_AddOns.DisableAddOn(rival.name, character)
		end
	end
	if C_AddOns.SaveAddOns then C_AddOns.SaveAddOns() end
end

local function BarsSummary()
	if not barsVisited then
		return BUI.GetDB().modules.actionBars ~= false and 'BluUI' or 'Off', 'From the profile'
	end
	local value = 'BluUI'
	for _, option in ipairs((BarOptions())) do
		if option.key == barsChoice then value = option.value end
	end
	local changes = {}
	for index, outcome in ipairs(Outcomes()) do
		if index > 1 and outcome.before ~= outcome.after then
			changes[#changes + 1] = outcome.label .. (outcome.after and ' turns on' or ' turns off')
		end
	end
	return value, #changes > 0 and table.concat(changes, ', ') or 'No other bar addons change'
end

local function BarRowState(option, rivalsByName)
	local modules = BUI.GetDB().modules
	local before
	if option.key == 'ours' then
		before = modules.actionBars ~= false
	elseif option.key == 'blizzard' then
		before = modules.actionBars == false
	else
		local rival = rivalsByName[option.key]
		before = rival and rival.on or false
	end
	local after = option.key == barsChoice
	local state = after and (before and 'Stays on' or 'Turns on') or (before and 'Turns off' or 'Stays off')
	return state, after
end

local function AddonAvatar(parent, name)
	local texture = C_AddOns.GetAddOnMetadata(name, 'IconTexture')
	local atlas = C_AddOns.GetAddOnMetadata(name, 'IconAtlas')
	if not texture and not atlas then return nil end
	local icon = parent:CreateTexture(nil, 'ARTWORK')
	icon:SetSize(PROFILE_AVATAR, PROFILE_AVATAR)
	if atlas then
		icon:SetAtlas(atlas)
	else
		icon:SetTexture(texture)
		if texture:lower():find('^interface.icons.') then
			icon:SetTexCoord(GAME_ICON_CROP, 1 - GAME_ICON_CROP, GAME_ICON_CROP, 1 - GAME_ICON_CROP)
			icon:SetMask(BUILib.GetLibMedia('circle_mask'))
		end
	end
	return icon
end

local function BarRowNote(option, rivalsByName)
	if option.key == 'ours' then return 'Built into BluUI' end
	if option.key == 'blizzard' then return "The game's own action bars" end
	local rival = rivalsByName[option.key]
	if rival and rival.on then return 'Installed and on right now' end
	return 'Installed, switched off on this character'
end

local function Bars(kit, _, parent, width, _, page)
	barsVisited = true
	local options, rivals = BarOptions()
	local rivalsByName = {}
	for _, rival in ipairs(rivals) do rivalsByName[rival.name] = rival end
	local picked = false
	for _, option in ipairs(options) do
		if option.key == barsChoice then picked = true end
	end
	if not picked then barsChoice = 'ours' end
	local frame = Block(parent, width)
	local intro = "Pick who runs your action bars. BluUI's bars, or the game's own."
	if #rivals > 0 then
		intro = "Our action bars don't get along with other bar addons. Pick the one you want and we'll switch the rest off."
	end
	local y = Heading(kit, frame, 'Action bars', intro, width)
	local nameWidth = width - BAR_TEXT_X - BAR_STATE_RIGHT - BAR_STATE_WIDTH - TILE_PAD
	for _, option in ipairs(options) do
		local selected = option.key == barsChoice
		local row = Choice(kit, frame, 0, y, width, BAR_ROW_HEIGHT, selected, function()
			barsChoice = option.key
			page:Rebuild('bars')
		end)
		local avatar
		if option.logo then
			avatar = row:CreateTexture(nil, 'ARTWORK')
			avatar:SetTexture(BUI.C.ICON_PATH)
			avatar:SetSize(PROFILE_AVATAR, PROFILE_AVATAR)
		elseif option.rival then
			avatar = AddonAvatar(row, option.key) or kit.Initials(row, PROFILE_AVATAR, Initials(option.rival))
		else
			avatar = kit.IconAvatar(row, PROFILE_AVATAR, 'order')
		end
		avatar:SetPoint('LEFT', TILE_PAD, 0)
		row.ring:ClearAllPoints()
		row.ring:SetPoint('RIGHT', -TILE_PAD, 0)
		local title = kit.Text(row, option.key == 'ours' and "BluUI's action bars" or option.key == 'blizzard' and "Blizzard's action bars" or option.title:gsub('^Use ', ''), 14, 'text', nameWidth, 'title')
		title:SetWordWrap(false)
		title:SetPoint('BOTTOMLEFT', row, 'LEFT', BAR_TEXT_X, 2)
		local note = kit.Text(row, BarRowNote(option, rivalsByName), 11, 'muted', nameWidth)
		note:SetWordWrap(false)
		note:SetPoint('TOPLEFT', row, 'LEFT', BAR_TEXT_X, -4)
		local state, on = BarRowState(option, rivalsByName)
		local stateText = kit.Text(row, state, 13, on and 'text' or 'muted', BAR_STATE_WIDTH, 'title')
		stateText:SetJustifyH('RIGHT')
		stateText:SetPoint('RIGHT', -BAR_STATE_RIGHT, 0)
		y = y + BAR_ROW_HEIGHT + BAR_ROW_GAP
	end
	y = y - BAR_ROW_GAP + FOOTER_GAP
	return { Footer(kit, frame, y, function() Back(page, pendingProfile == BLU_PROFILE and 'profile' or 'theme') end, { text = 'Next', onClick = function() Go(page, 'finish') end }) }
end

local function SummaryCard(kit, window, frame, x, y, width, spec)
	local card = CreateFrame('Button', nil, frame)
	card:SetPoint('TOPLEFT', x, -y)
	card:SetSize(width, SUMMARY_CARD_HEIGHT)
	local fill, edge = BUILib.Widget.DrawCardShape(card, CARD_RADIUS, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
	window:Paint(fill, 'card')
	window:Paint(edge, 'cardEdge')
	local avatar = kit.IconAvatar(card, SUMMARY_AVATAR, spec.icon)
	avatar:SetPoint('TOPLEFT', TILE_PAD, -TILE_PAD)
	kit.Text(card, spec.label, 12, 'muted'):SetPoint('LEFT', avatar, 'RIGHT', 10, 0)
	local change = kit.Text(card, 'Change', 11, 'faint')
	change:SetPoint('RIGHT', card, 'TOPRIGHT', -TILE_PAD, -(TILE_PAD + SUMMARY_AVATAR / 2))
	local textWidth = width - TILE_PAD * 2
	local value = kit.Text(card, spec.value, SUMMARY_READOUT, 'text', textWidth)
	value:SetWordWrap(false)
	value:SetPoint('TOPLEFT', TILE_PAD, -(TILE_PAD + SUMMARY_AVATAR + 14))
	local status = kit.Text(card, spec.status, 11, 'muted', textWidth)
	status:SetWordWrap(false)
	status:SetPoint('TOPLEFT', value, 'BOTTOMLEFT', 0, -6)
	card:SetScript('OnEnter', function()
		window:Paint(edge, 'faint')
		window:Paint(change, 'text')
	end)
	card:SetScript('OnLeave', function()
		window:Paint(edge, 'cardEdge')
		window:Paint(change, 'faint')
	end)
	card:SetScript('OnClick', spec.onClick)
	return card
end

local function Finish(kit, shell, parent, width, _, page)
	local frame = Block(parent, width)
	local y = Heading(kit, frame, "You're all set", 'Here is what you picked. Click a card to change it, or finish to reload and keep it.', width)
	local selectedCount, total = SelectionCounts()
	local style = BUI.Installer.AppliedStyle()
	local scale = UIParent:GetScale()
	local perfect = BUI.ApproxEqual(scale, BUI.ClampedUIScale())
	local screenWidth, screenHeight = GetPhysicalScreenSize()
	local profileName = pendingProfile
	local profileStatus = ProfileUsers(profileName)
	if pendingNew then
		profileStatus = 'A new profile, made when you finish'
	elseif not ProfileExists(profileName) then
		profileStatus = "Bluhu's profile, added when you finish"
	end
	local skinsValue, skinsStatus
	if selectedCount == total then
		skinsValue, skinsStatus = 'All', ('Every one of the %d Blizzard windows gets the dark look'):format(total)
	elseif selectedCount == 0 then
		skinsValue, skinsStatus = 'Off', "Blizzard windows keep Blizzard's look"
	else
		skinsValue, skinsStatus = ('%d of %d'):format(selectedCount, total), 'Blizzard windows get the dark look'
	end
	local barsValue, barsStatus = BarsSummary()
	local cards = {
		{ step = 'profile', icon = 'profile', label = 'Profile', value = profileName, status = profileStatus },
		{ step = 'scale', icon = 'resize', label = 'Scale', value = ('%.4f'):format(scale),
			status = (perfect and 'Pixel-perfect for %d x %d' or 'Off the pixel grid for %d x %d'):format(screenWidth, screenHeight) },
		{ step = 'skins', icon = 'eye', label = 'Skins', value = skinsValue, status = skinsStatus },
		{ step = 'theme', icon = 'layout', label = 'Unit frames', value = style and style.name or 'Unchanged',
			status = style and (BUI.Installer.MatchesGroupFrames() and 'Party and raid frames match' or 'Party and raid frames keep their own look') or 'Pick a look on the Theme step' },
		{ step = 'bars', icon = 'order', label = 'Action bars', value = barsValue, status = barsStatus },
	}
	local cardWidth = math.floor((width - TILE_GAP * (SUMMARY_COLUMNS - 1)) / SUMMARY_COLUMNS)
	for index, spec in ipairs(cards) do
		local column, row = (index - 1) % SUMMARY_COLUMNS, math.floor((index - 1) / SUMMARY_COLUMNS)
		spec.onClick = function() Back(page, spec.step) end
		SummaryCard(kit, shell.window, frame, column * (cardWidth + TILE_GAP), y + row * (SUMMARY_CARD_HEIGHT + TILE_GAP), cardWidth, spec)
	end
	local rows = math.ceil(#cards / SUMMARY_COLUMNS)
	y = y + rows * SUMMARY_CARD_HEIGHT + (rows - 1) * TILE_GAP + FOOTER_GAP
	frame:SetScript('OnShow', function() BUI.Confetti.Burst(shell.window.frame) end)
	return { Footer(kit, frame, y, function() Back(page, (profileName ~= BLU_PROFILE or NeedsBarsStep()) and 'bars' or 'profile') end, { text = 'Finish and reload', onClick = function()
		BUI.Events:AfterCombat(function()
			finishing = true
			CommitProfile()
			Skin().WriteSkinsEnabled(skinSelection)
			ApplyBars()
			BUI.Print('Setup complete. Open settings anytime with |cff' .. BUI.C.COLOR_PINK .. '/bui|r.')
			ReloadUI()
		end, 'Setup.Finish')
	end }) }
end

local BUILDERS = { welcome = Welcome, profile = Profile, scale = Scale, skins = Skins, theme = Theme, bars = Bars, finish = Finish }

BUI.OptionsWindow.New('setup', {
	title = 'Setup BluUI',
	brand = false,
	modal = true,
	icon = 'check',
	globalName = 'BluUISetupFrame',
	onOpen = function(shell)
		RemoveLeftoverProfiles()
		SeedSelection()
		barsChoice, barsVisited = 'ours', false
		scaleChoice = nil
		openingProfile = BUI.GetAceDB():GetCurrentProfile()
		pendingProfile, pendingNew = openingProfile, false
		themeVisited, scaleVisited, finishing = false, false, false
		lookSnapshot = CaptureLook(BUI.GetDB())
		wipe(done)
		shell:RebuildPage('setup')
	end,
	onClosed = function()
		RestoreOpeningLook()
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
