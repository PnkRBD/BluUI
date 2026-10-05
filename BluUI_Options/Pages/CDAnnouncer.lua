local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Layout, Modals = BUILib.Layout, BUILib.Modals
local Section = Layout.TableSection
local CDAnnouncer = BUI.CDAnnouncer
local Pixel = BUI.Pixel
local TimeFormat = BUI.TimeFormat

local PAGE_WIDTH = 960
local PREVIEW_HEIGHT = 110
local MENU_WIDTH = 150
local INPUT_WIDTH = 260
local NAME_WIDTH = 300
local ICON_SIZE = 24
local GRABBER_SIZE = 12
local GRABBER_X = 18
local LIST_ICON_X = 42
local LIST_NAME_X = 78
local LIST_ROOM = 190
local ERASE_SIZE = BUILib.Layout.ERASE_SIZE
local ERASE_INSET = 18
local TOOL_GAP = 12
local DRAG_ALPHA = 0.35
local DEFAULT_ICON = 134400
local LOOP_SECONDS = 7
local SEG_CD, SEG_LOW = 0.55, 0.20
local LOW_COLOR = { r = 1, g = 0.2, b = 0.2, a = 1 }
local TEXT_GAP = 6
local STACK_GAP = 4
local POSITION_RANGE_X = 1500
local POSITION_RANGE_Y = 1000
local ICON_TIME_RANGE = 30
local PREVIEW_SECONDS = 8

local GROWTH = {
	{ value = 'center', text = 'Grow from the middle' },
	{ value = 'down', text = 'Grow down' },
	{ value = 'up', text = 'Grow up' },
}
local READY_MODES = {
	{ value = 'flash', text = 'Flash and hide' },
	{ value = 'persist', text = 'Stay shown' },
}
local FLASH_SCOPES = {
	{ value = 'both', text = 'Icon and text' },
	{ value = 'icon', text = 'Icon only' },
	{ value = 'text', text = 'Text only' },
}
local TEXT_SIDES = {
	{ value = 'right', text = 'Right of the icon' },
	{ value = 'top', text = 'Above the icon' },
	{ value = 'bottom', text = 'Below the icon' },
}

local selectedID
local liveID
local items = {}
local preview
local fonts, sounds

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function Config()
	return BUI.GetDB().cdAnnouncer
end

local function Selected()
	return selectedID and CDAnnouncer.FindEntry(selectedID)
end

local function RefreshPreview()
	if preview then preview:Update() end
end

local function Apply()
	CDAnnouncer.Refresh()
	RefreshPreview()
end

local function RebuildPage()
	BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
end

local function StopLive()
	if not liveID then return end
	liveID = nil
	CDAnnouncer.StopLivePreview()
end

local function Describe(entry)
	local icon, name
	if entry.kind == 'item' then icon, name = BUI.Lookup.GetItemInfo(entry.spellID) else icon, name = BUI.Lookup.GetSpellInfo(entry.spellID) end
	return icon or DEFAULT_ICON, name or ((entry.kind == 'item' and 'Item ' or 'Spell ') .. entry.spellID)
end

local function MaxCharges(entry)
	if entry.kind == 'item' then return nil end
	local info = C_Spell.GetSpellCharges(entry.spellID)
	local charges = info and BUI.Tools.SafeNum(info.maxCharges)
	return charges and charges > 1 and charges or nil
end

local function Subtitle(entry)
	local kind = entry.kind == 'item' and 'Item ' or 'Spell '
	local charges = MaxCharges(entry)
	local hasDuration = entry.duration and entry.duration > 0
	local timing
	if charges then
		timing = hasDuration and ('%d charges, %gs recharge'):format(charges, entry.duration) or ('%d charges'):format(charges)
	else
		timing = hasDuration and ('%gs cooldown'):format(entry.duration) or 'no cooldown duration yet'
	end
	local aliases = entry.aliases and #entry.aliases > 0 and (', %d extra trigger IDs'):format(#entry.aliases) or ''
	return kind .. entry.spellID .. ', ' .. timing .. aliases
end

local function FormatAliases(list)
	if not list then return '' end
	return table.concat(list, ', ')
end

local function ParseAliases(text, selfID)
	local list = {}
	for part in text:gmatch('([^,%s]+)') do
		local id = tonumber(part)
		if id and id ~= selfID then list[#list + 1] = id end
	end
	return #list > 0 and list or nil
end

local function Fill(text, entry, value)
	local _, name = Describe(entry)
	text = text:gsub('%[spell%]', name):gsub('%[name%]', name)
	if value then text = text:gsub('%[time%]', value) end
	return text
end

local function Speak(entry, phrase, withTime)
	if not BUI.TTS.IsAvailable() then return end
	BUI.TTS.Speak(Fill(phrase, entry, withTime and tostring(math.max(1, math.floor(entry.lowThreshold))) or nil))
end

local function EntryFont(entry)
	if entry.font ~= BUI.C.GLOBAL_OPTION then return BUI.GetModuleFont({ font = entry.font }) end
	return BUI.GetModuleFont(Config())
end

local function Timeline(entry)
	local duration = entry.duration and entry.duration > 0 and entry.duration or 30
	local low = math.min(entry.lowThreshold, duration)
	local tail = entry.readyMode == 'persist' and 2 or math.max(0.5, entry.glowDuration)
	return duration, low, tail
end

local function PhaseAt(entry, position)
	local duration, low, tail = Timeline(entry)
	if position < SEG_CD then return 'cd', low + (duration - low) * (1 - position / SEG_CD) end
	if position < SEG_CD + SEG_LOW then return 'low', low * (1 - (position - SEG_CD) / SEG_LOW) end
	return 'ready', tail * ((position - SEG_CD - SEG_LOW) / (1 - SEG_CD - SEG_LOW))
end

local function PhaseShown(entry, phase)
	if phase == 'cd' then return entry.cdPhase end
	if phase == 'low' then return entry.lowPhase or entry.cdPhase end
	return entry.readyPhase
end

local function NextShown(entry, position)
	for _ = 1, 3 do
		local phase = PhaseAt(entry, position)
		if PhaseShown(entry, phase) then return position end
		if phase == 'cd' then position = SEG_CD elseif phase == 'low' then position = SEG_CD + SEG_LOW else position = 0 end
	end
	return position
end

local function Option(holder, label, key, extra)
	local option = { label = label, get = function() return holder[key] end, set = function(value) holder[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Toggle(holder, label, key)
	return { label = label, get = function() return holder[key] == true end, set = function(value) holder[key] = value end }
end

local function Color(holder, label, key, fallback)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = true,
		get = function()
			local color = holder[key] or fallback()
			return color.r, color.g, color.b, color.a or 1
		end,
		set = function(red, green, blue, alpha) holder[key] = { r = red, g = green, b = blue, a = alpha } end,
	}
end

local function Font(holder)
	return { entries = fonts, width = MENU_WIDTH, get = function() return holder.font end, set = function(value) holder.font = value end }
end

local function Sound(entry, key)
	return { entries = sounds, width = MENU_WIDTH, get = function() return entry[key] or 'None' end, set = function(value)
		entry[key] = value ~= 'None' and value or nil
		BUI.PlaySoundByName(value)
	end }
end

local function Phrase(entry, key, placeholder)
	return { icon = 'text', tooltip = 'Phrase', title = 'Phrase', options = {
		{ label = 'Phrase, [spell] and [time] fill in', kind = 'input', placeholder = placeholder, get = function() return entry[key] end, set = function(text) entry[key] = text ~= '' and text or placeholder end },
	} }
end

local function Test(entry, key, withTime)
	return { text = 'Test', onClick = function() Speak(entry, entry[key], withTime) end }
end

local function ConfirmDelete(entry)
	local _, name = Describe(entry)
	Modals.Confirm({
		parent = Window().frame,
		title = 'Stop announcing ' .. name,
		message = 'Remove "' .. name .. '" and its announcement settings?',
		confirmText = 'Remove', cancelText = 'Cancel',
		onConfirm = function()
			StopLive()
			CDAnnouncer.RemoveSpell(entry.spellID)
			selectedID = nil
			RebuildPage()
		end,
	})
end

local function PromptDuplicate(entry)
	local _, name = Describe(entry)
	Modals.Input({
		parent = Window().frame,
		title = 'Duplicate ' .. name,
		message = 'Which spell or item should announce with the same settings? Name, ID or link.',
		confirmText = 'Duplicate',
		onConfirm = function(text)
			local id, isItem = BUI.Lookup.ParseSpellOrItemInput(text)
			if not id or CDAnnouncer.FindEntry(id) then return end
			local newID = CDAnnouncer.DuplicateSpell(entry.spellID, id, isItem)
			if not newID then return end
			selectedID = newID
			RebuildPage()
		end,
	})
end

local function SpellBoard(ui, parent, width, entry)
	local id = entry.spellID
	local _, name = Describe(entry)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = name,
		description = Subtitle(entry) .. '. The preview above cycles through the countdown, the final seconds and the ready alert.',
		buttons = {
			{ text = 'Duplicate', icon = 'copy', onClick = function() PromptDuplicate(entry) end },
			{ text = 'Remove', style = 'danger', onClick = function() ConfirmDelete(entry) end },
		},
	})
	board:AddTools('Announce', 'Turn this announcement on, or run it on screen while you tune it', {
		{ icon = 'eye', tooltip = 'Run the preview on screen', get = function() return liveID == id end, set = function(value)
			StopLive()
			if value then liveID = id end
			Repaint()
		end },
		{ get = function() return entry.enabled ~= false end, set = function(value) CDAnnouncer.SetSpellEnabled(id, value) end },
	}, Apply)
	local cooldown = {
		{ label = 'Cooldown in seconds', kind = 'input', placeholder = 'Seconds', get = function() return entry.duration and tostring(entry.duration) or '' end, set = function(text)
			local seconds = tonumber(text)
			if seconds and seconds > 0 then entry.duration = seconds end
		end },
		{ label = 'Read it from the tooltip', text = 'Auto', onClick = function()
			local seconds = CDAnnouncer.ResolveCooldownSeconds(id, entry.kind)
			if not seconds then return end
			entry.duration = seconds
			Apply()
			Repaint()
		end },
	}
	if entry.kind ~= 'item' then
		cooldown[#cooldown + 1] = { label = 'Extra trigger IDs', kind = 'input', placeholder = 'Comma separated', get = function() return FormatAliases(entry.aliases) end, set = function(text) entry.aliases = ParseAliases(text, id) end }
	end
	board:AddTools('Countdown', 'Remaining time while it is on cooldown', {
		Color(entry, 'Countdown color', 'color', function() return Config().cdColor end),
		{ icon = 'text', tooltip = 'Text and icon', title = 'Countdown', options = {
			{ label = 'Text, [spell] and [time] fill in', kind = 'input', placeholder = '[spell] [time]', get = function() return entry.cdDisplayFormat end, set = function(text) entry.cdDisplayFormat = text ~= '' and text or '[spell] [time]' end },
			Toggle(entry, 'Show text', 'showText'),
			Toggle(entry, 'Show spell icon', 'showIcon'),
		} },
		{ tooltip = 'Duration and triggers', title = 'Cooldown', options = cooldown },
		Toggle(entry, nil, 'cdPhase'),
	}, Apply)
	board:AddTools('Countdown inside icon', 'Remaining seconds drawn on the spell icon', {
		{ icon = 'text', tooltip = 'Size and placement', title = 'Countdown inside icon', options = {
			{ label = 'Text size', min = 6, max = 40, step = 1, get = function() return entry.iconTimeSize or math.max(8, math.floor(entry.iconSize * 0.45)) end, set = function(value) entry.iconTimeSize = value end },
			Option(entry, 'Placement', 'iconTimeAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS_SHORT }),
		} },
		{ icon = 'location', tooltip = 'Nudge', title = 'Countdown inside icon', options = {
			Option(entry, 'Horizontal', 'iconTimeX', { min = -ICON_TIME_RANGE, max = ICON_TIME_RANGE, step = 1 }),
			Option(entry, 'Vertical', 'iconTimeY', { min = -ICON_TIME_RANGE, max = ICON_TIME_RANGE, step = 1 }),
		} },
		Toggle(entry, nil, 'timeInIcon'),
	}, Apply)
	board:AddTools('Final seconds', 'Recolor the countdown when it is almost ready', {
		Color(entry, 'Final seconds color', 'lowColor', function() return LOW_COLOR end),
		Sound(entry, 'soundLow'),
		{ tooltip = 'Threshold and flash', title = 'Final seconds', options = {
			Option(entry, 'Starts at seconds left', 'lowThreshold', { min = 1, max = 30, step = 1 }),
			Toggle(entry, 'Flash the text', 'flashLow'),
		} },
		Toggle(entry, nil, 'lowPhase'),
	}, Apply)
	board:AddTools('Speak the countdown', 'Read the final seconds aloud', {
		Phrase(entry, 'countdownText', '[spell] in [time]'),
		Test(entry, 'countdownText', true),
		Toggle(entry, nil, 'countdownLow'),
	}, Apply)
	board:AddTools('Ready', 'The moment it is back up', {
		Color(entry, 'Ready color', 'readyColor', function() return Config().readyColor end),
		{ entries = READY_MODES, width = MENU_WIDTH, get = function() return entry.readyMode end, set = function(value) entry.readyMode = value end },
		Sound(entry, 'soundReady'),
		{ icon = 'text', tooltip = 'Text', title = 'Ready', options = {
			{ label = 'Text, [spell] fills in', kind = 'input', placeholder = '[spell] Ready', get = function() return entry.readyDisplayFormat end, set = function(text) entry.readyDisplayFormat = text ~= '' and text or '[spell] Ready' end },
		} },
		{ tooltip = 'Flash', title = 'Ready', options = {
			Option(entry, 'Flash', 'flashScope', { entries = FLASH_SCOPES }),
			Option(entry, 'Flash for seconds', 'glowDuration', { min = 0.25, max = 5, step = 0.25 }),
		} },
		Toggle(entry, nil, 'readyPhase'),
	}, Apply)
	board:AddTools('Speak when ready', 'Say a phrase when it comes off cooldown', {
		Phrase(entry, 'ttsText', '[spell] ready'),
		Test(entry, 'ttsText', false),
		Toggle(entry, nil, 'tts'),
	}, Apply)
	board:AddTools('Text and icon', 'Font, sizes and where the text sits', {
		Font(entry),
		{ icon = 'text', tooltip = 'Size', title = 'Text', options = { Option(entry, 'Font size', 'fontSize', { min = 8, max = 48, step = 1 }) } },
		{ tooltip = 'Icon size and text side', title = 'Text and icon', options = {
			Option(entry, 'Icon size', 'iconSize', { min = 12, max = 64, step = 1 }),
			Option(entry, 'Text sits', 'textAnchor', { entries = TEXT_SIDES }),
		} },
	}, Apply)
	board:AddTools('Own position', 'Somewhere other than the shared anchor', {
		{ icon = 'location', tooltip = 'Anchor and offsets', title = 'Own position', options = {
			Option(entry, 'Anchor point', 'posAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
			Option(entry, 'Horizontal', 'posX', { min = -POSITION_RANGE_X, max = POSITION_RANGE_X, step = 1 }),
			Option(entry, 'Vertical', 'posY', { min = -POSITION_RANGE_Y, max = POSITION_RANGE_Y, step = 1 }),
		} },
		Toggle(entry, nil, 'useCustomPos'),
	}, Apply)
	return board
end

local function AnnouncerBoard(ui, parent, width)
	local cfg = Config()
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Announcer',
		description = 'Shared by every announced cooldown. Unlock the anchor with the eye in the header to drag it, right-click it to lock it again.',
	})
	board:AddSwitch('Hide unusable spells', function() return cfg.hideUnusable == true end, function(value)
		cfg.hideUnusable = value
		Apply()
	end, 'Skip cooldowns you cannot use right now')
	board:AddTools('Announcements', 'Default colors, font, stacking and the shared position', {
		Color(cfg, 'Countdown color', 'cdColor'),
		Color(cfg, 'Ready color', 'readyColor'),
		Font(cfg),
		{ entries = GROWTH, width = MENU_WIDTH, get = function() return cfg.growth or 'center' end, set = function(value) cfg.growth = value end },
		{ icon = 'location', tooltip = 'Position', title = 'Position', options = {
			Option(cfg, 'Horizontal', 'posX', { min = -POSITION_RANGE_X, max = POSITION_RANGE_X, step = 1 }),
			Option(cfg, 'Vertical', 'posY', { min = -POSITION_RANGE_Y, max = POSITION_RANGE_Y, step = 1 }),
			{ label = 'Center horizontally', get = function() return cfg.centerHorizontally == true end, set = function(value)
				cfg.centerHorizontally = value
				if value then cfg.posX = 0 end
			end },
		} },
	}, Apply)
	return board
end

local function CooldownsBoard(ui, parent, width, page)
	local entries = {}
	for position, entry in ipairs(CDAnnouncer.GetSpells()) do entries[position] = entry end
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Cooldowns',
		description = 'Announced in this order, top to bottom. Drag a row to reorder it, pick one from the rail to tune it. Type a name, paste an ID or a link, then press Enter.',
		columns = { { 'Spell or item', LIST_ICON_X } },
	})
	local function Add(id, isItem)
		if CDAnnouncer.FindEntry(id) or not CDAnnouncer.AddSpell(id, isItem) then return end
		selectedID = id
		RebuildPage()
	end
	local addRow = Section.AddRow(board, 'add a cooldown')
	ui.RowTitle(addRow, 'Add a cooldown', 'Name, ID or link', LIST_ICON_X, NAME_WIDTH)
	BUI.SpellSearch(ui, addRow, INPUT_WIDTH, { onPick = function(hit) Add(hit.id, hit.isItem) end }):SetPoint('RIGHT', -ui.ROW_INSET, 0)

	local rows = {}
	local function IndexOf(entry)
		for position, candidate in ipairs(entries) do
			if candidate == entry then return position end
		end
	end
	local function Move(entry, delta)
		local position = IndexOf(entry)
		local other = entries[position + delta]
		if not other then return end
		entries[position], entries[position + delta] = other, entry
		board:Move(rows[entry], delta)
		page:Resize()
	end
	local function RowUnder(cursorY)
		for _, entry in ipairs(entries) do
			local row = rows[entry]
			local top, bottom = row:GetTop(), row:GetBottom()
			if top and cursorY <= top and cursorY >= bottom then return entry end
		end
	end
	local dragging, grabOffset, ghost
	local function Ghost()
		if ghost then return ghost end
		ghost = CreateFrame('Frame', nil, board.panel)
		ghost:SetFrameLevel(board.panel:GetFrameLevel() + 10)
		ghost:SetWidth(board.panelWidth)
		ui.Fill(ghost, 'control'):SetAllPoints()
		local edge = ui.Fill(ghost, 'accent', 'ARTWORK', 1)
		edge:SetPoint('TOPLEFT')
		edge:SetPoint('BOTTOMLEFT')
		edge:SetWidth(2)
		ui.Glyph(ghost, 'grabber', GRABBER_SIZE, 'text'):SetPoint('LEFT', GRABBER_X, 0)
		ghost.icon = ghost:CreateTexture(nil, 'ARTWORK')
		ghost.icon:SetSize(ICON_SIZE, ICON_SIZE)
		ghost.icon:SetPoint('LEFT', LIST_ICON_X, 0)
		ghost.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ghost.label = ui.Text(ghost, '', 12, 'text')
		ghost.label:SetPoint('LEFT', LIST_NAME_X, 0)
		ghost:Hide()
		return ghost
	end
	local function Track()
		local _, cursorY = GetCursorPosition()
		cursorY = cursorY / board.frame:GetEffectiveScale()
		ghost:ClearAllPoints()
		ghost:SetPoint('TOPLEFT', board.panel, 'TOPLEFT', 0, -(board.panel:GetTop() - cursorY - grabOffset))
		local over = RowUnder(cursorY)
		if over and over ~= dragging then
			Move(dragging, IndexOf(over) > IndexOf(dragging) and 1 or -1)
		end
	end
	for _, entry in ipairs(entries) do
		local id = entry.spellID
		local iconTexture, name = Describe(entry)
		local row = Section.AddRow(board, name)
		rows[entry] = row
		ui.Glyph(row, 'grabber', GRABBER_SIZE, 'faint'):SetPoint('LEFT', GRABBER_X, 0)
		local icon = row:CreateTexture(nil, 'ARTWORK')
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		icon:SetPoint('LEFT', LIST_ICON_X, 0)
		icon:SetTexture(iconTexture)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ui.RowTitle(row, name, Subtitle(entry), LIST_NAME_X, board.panelWidth - LIST_NAME_X - LIST_ROOM)
		local x = ERASE_INSET
		local function Put(control)
			control:SetPoint('RIGHT', -x, 0)
			x = x + control:GetWidth() + TOOL_GAP
		end
		Put(ui.IconButton(row, 'erase', 'Stop announcing ' .. name, function() ConfirmDelete(entry) end, 'danger', ERASE_SIZE))
		Put(ui.Switch(row, function() return entry.enabled ~= false end, function(value)
			CDAnnouncer.SetSpellEnabled(id, value)
			RefreshPreview()
		end))
		Put(ui.IconButton(row, 'eye', 'Preview it on screen', function() CDAnnouncer.PreviewSpell(id, PREVIEW_SECONDS) end))
		Put(ui.IconButton(row, 'cog', 'Tune the announcement', function() page:Select('spell' .. id) end))
		row:EnableMouse(true)
		row:RegisterForDrag('LeftButton')
		row:SetScript('OnDragStart', function(self)
			local _, cursorY = GetCursorPosition()
			dragging = entry
			grabOffset = self:GetTop() - cursorY / board.frame:GetEffectiveScale()
			self:SetAlpha(DRAG_ALPHA)
			Ghost():SetHeight(self:GetHeight())
			ghost.icon:SetTexture(iconTexture)
			ghost.label:SetText(name)
			ghost:Show()
			Track()
			self:SetScript('OnUpdate', Track)
		end)
		row:SetScript('OnDragStop', function(self)
			self:SetScript('OnUpdate', nil)
			self:SetAlpha(1)
			ghost:Hide()
			dragging = nil
			local ids = {}
			for position, ordered in ipairs(entries) do ids[position] = ordered.spellID end
			CDAnnouncer.ReorderSpells(ids)
			RebuildPage()
		end)
	end
	if #entries == 0 then
		local empty = Section.AddRow(board, 'nothing announced yet')
		ui.RowTitle(empty, 'Nothing announced yet', 'Search above to add a spell or an item', LIST_ICON_X, NAME_WIDTH)
	end
	return board
end

local function BuildPreview(band, kit)
	local stage = CreateFrame('Frame', nil, band)
	stage:SetPoint('CENTER')
	stage:SetSize(10, 10)
	local icon = stage:CreateTexture(nil, 'ARTWORK')
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local text = stage:CreateFontString(nil, 'OVERLAY')
	local iconTime = stage:CreateFontString(nil, 'OVERLAY')
	local note = kit.Text(band, '', 12, 'muted')
	note:SetPoint('CENTER')

	local function Pulse(region)
		local group = region:CreateAnimationGroup()
		group:SetLooping('REPEAT')
		local out = group:CreateAnimation('Alpha')
		out:SetFromAlpha(1)
		out:SetToAlpha(0.45)
		out:SetDuration(0.35)
		out:SetOrder(1)
		out:SetSmoothing('IN_OUT')
		local back = group:CreateAnimation('Alpha')
		back:SetFromAlpha(0.45)
		back:SetToAlpha(1)
		back:SetDuration(0.35)
		back:SetOrder(2)
		back:SetSmoothing('IN_OUT')
		return group
	end
	local textPulse, stagePulse = Pulse(text), Pulse(stage)
	local function Run(group, region, wanted)
		if wanted and not group:IsPlaying() then
			group:Play()
		elseif not wanted and group:IsPlaying() then
			group:Stop()
			region:SetAlpha(1)
		end
	end

	local function Arrange(entry, showIcon, showText)
		icon:SetShown(showIcon)
		text:SetShown(showText)
		local size = entry.iconSize
		icon:SetSize(size, size)
		local textWidth = showText and text:GetStringWidth() or 0
		local textHeight = showText and text:GetStringHeight() or 0
		icon:ClearAllPoints()
		text:ClearAllPoints()
		local width, height
		if not showIcon then
			text:SetPoint('CENTER')
			width, height = textWidth, textHeight
		elseif entry.textAnchor == 'top' then
			icon:SetPoint('BOTTOM')
			text:SetPoint('BOTTOM', icon, 'TOP', 0, STACK_GAP)
			width, height = math.max(textWidth, size), size + (showText and textHeight + STACK_GAP or 0)
		elseif entry.textAnchor == 'bottom' then
			icon:SetPoint('TOP')
			text:SetPoint('TOP', icon, 'BOTTOM', 0, -STACK_GAP)
			width, height = math.max(textWidth, size), size + (showText and textHeight + STACK_GAP or 0)
		else
			icon:SetPoint('LEFT')
			text:SetPoint('LEFT', icon, 'RIGHT', TEXT_GAP, 0)
			width, height = size + (showText and TEXT_GAP + textWidth or 0), math.max(size, textHeight)
		end
		stage:SetSize(math.max(width, 10), math.max(height, 10))
	end

	local position = 0
	local function Render(entry)
		local phase, value = PhaseAt(entry, position)
		local shown = PhaseShown(entry, phase)
		stage:SetShown(shown)
		note:SetShown(not shown)
		if not shown then
			note:SetText(phase == 'ready' and 'The ready alert is off, nothing shows when it comes back up' or 'The countdown is off, nothing shows while it is on cooldown')
			return
		end
		local onCooldown = phase ~= 'ready'
		local color, showIcon, showText, message
		if onCooldown then
			message = Fill(entry.cdDisplayFormat, entry, TimeFormat.Format(value, 10))
			local low = phase == 'low' and entry.lowPhase
			color = low and (entry.lowColor or LOW_COLOR) or (entry.color or Config().cdColor)
			showIcon, showText = entry.showIcon, entry.showText
		else
			message = Fill(entry.readyDisplayFormat, entry)
			color = entry.readyColor or Config().readyColor
			showIcon, showText = entry.showIconReady, entry.showTextReady
			if entry.readyMode ~= 'persist' then
				if entry.flashScope == 'icon' then showText = false elseif entry.flashScope == 'text' then showIcon = false end
			end
		end
		local font = EntryFont(entry)
		Pixel.ApplyFont(text, entry.fontSize, font, BUI.GetFontOutline())
		text:SetText(message)
		text:SetTextColor(color.r, color.g, color.b, color.a or 1)
		icon:SetTexture((Describe(entry)))
		if onCooldown and entry.timeInIcon and showIcon then
			Pixel.ApplyFont(iconTime, entry.iconTimeSize or math.max(8, math.floor(entry.iconSize * 0.45)), font, BUI.GetFontOutline())
			iconTime:ClearAllPoints()
			iconTime:SetPoint(entry.iconTimeAnchor, icon, entry.iconTimeAnchor, entry.iconTimeX, entry.iconTimeY)
			iconTime:SetText(TimeFormat.Format(value, 10))
			iconTime:SetTextColor(color.r, color.g, color.b, color.a or 1)
			iconTime:Show()
		else
			iconTime:Hide()
		end
		Arrange(entry, showIcon, showText)
		Run(textPulse, text, phase == 'low' and entry.flashLow and entry.lowPhase)
		Run(stagePulse, stage, phase == 'ready' and entry.readyMode ~= 'persist')
	end

	function band:Update()
		local entry = Selected()
		if entry then return Render(entry) end
		stage:Hide()
		note:Show()
		note:SetText(#CDAnnouncer.GetSpells() > 0 and 'Pick a cooldown from the rail to see it here' or 'Nothing here yet, add a cooldown below')
	end
	band:SetScript('OnUpdate', function(self, elapsed)
		local entry = Selected()
		if not entry then return end
		position = NextShown(entry, (position + elapsed / LOOP_SECONDS) % 1)
		Render(entry)
		if liveID then
			local phase, value = PhaseAt(entry, position)
			CDAnnouncer.DriveLivePreview(liveID, phase, value)
		end
	end)
	band:HookScript('OnShow', function(self) self:Update() end)
	return band
end

local function Panes(ui, _, parent, width, item, page)
	if item.spellID then
		local entry = CDAnnouncer.FindEntry(item.spellID)
		CDAnnouncer.ApplyEntryDefaults(entry)
		return { SpellBoard(ui, parent, width, entry) }
	end
	return { AnnouncerBoard(ui, parent, width), CooldownsBoard(ui, parent, width, page) }
end

local function RailGroups()
	items = {}
	local cooldowns = {}
	for _, entry in ipairs(CDAnnouncer.GetSpells()) do
		local _, name = Describe(entry)
		cooldowns[#cooldowns + 1] = { id = 'spell' .. entry.spellID, label = name, spellID = entry.spellID }
	end
	if #cooldowns == 0 then cooldowns[1] = { id = 'none', label = 'Nothing announced yet', disabled = true } end
	local groups = {
		{ title = 'Settings', items = { { id = 'announcer', label = 'Announcer', icon = 'cog' } } },
		{ title = 'Cooldowns', items = cooldowns },
	}
	for _, group in ipairs(groups) do
		for _, item in ipairs(group.items) do items[item.id] = item end
	end
	return groups
end

local function ActiveID()
	if Selected() then return 'spell' .. selectedID end
	return 'announcer'
end

BUI.PageEngine.RegisterPage('cdAnnouncer', {
	title = 'CD Announcer',
	buttonText = 'CD Announcer',
	icon = 'clock',
	hidden = true,
	navParent = 'auras',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		sounds = BUI.BuildSoundDropdownItems()
		local cfg = Config()
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local tab = page:GetTab(1)
		local rail
		rail = Layout.RailPage(tab, { window = Window() }, {
			icon = 'clock',
			title = 'CD Announcer',
			placeholder = 'Search announcer settings...',
			disabled = function() return cfg.enabled ~= true end,
			back = { label = 'alerts', onClick = function() BUI.PageEngine.NavigateToID('auras') end },
			tools = {
				{ icon = 'enable', tooltip = 'Turn the announcer on or off', get = function() return cfg.enabled == true end, set = function(value)
					cfg.enabled = value
					Apply()
				end },
				{ icon = 'eye', tooltip = 'Unlock the shared anchor to drag it, right-click it to lock', get = function() return cfg.showAnchor == true end, set = function(value)
					cfg.showAnchor = value
					Apply()
				end },
			},
			preview = { height = PREVIEW_HEIGHT, build = function(band, kit) preview = BuildPreview(band, kit) end },
			rail = { groups = RailGroups(), selected = ActiveID() },
			build = Panes,
		})
		local Select = rail.Select
		function rail:Select(id)
			StopLive()
			selectedID = items[id].spellID
			Select(self, id)
			Repaint()
			RefreshPreview()
		end
		pageFrame._page = { tabContents = { tab }, currentTab = 1, SetTab = function() rail:Select('announcer') end }
		RefreshPreview()
		CDAnnouncer.RegisterAnchorCallback(Repaint)
		page:AutoRefresh()
	end,
	OnHide = StopLive,
})
