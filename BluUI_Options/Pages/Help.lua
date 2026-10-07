local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout
local Widget = BUILib.Widget
local Modals = BUILib.Modals

local CARD_MIN_HEIGHT = 420
local PAGE_OVERHEAD = 130
local BODY_Y = 42
local BOX_Y = 92
local BOX_PAD = 12
local SCROLL_STEP = 40
local ISSUES_URL = 'https://github.com/PnkRBD/BluUI/issues'

local function Window()
	return BUI.PageEngine.window
end

local function Megabytes(kilobytes)
	return ('%.1f MB'):format(kilobytes / 1024)
end

local function CVar(name)
	return tostring(GetCVar(name))
end

local function Elapsed(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ('%dh %02dm'):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

local function GatherDiagnostics()
	local db = BUI.GetDB()
	local theme = db.windowTheme
	local lines = {}
	local function Add(line) lines[#lines + 1] = line end
	local function Section(title)
		if #lines > 0 then Add('') end
		Add('== ' .. title .. ' ==')
	end
	local function Row(label, value) Add(label .. ': ' .. tostring(value)) end

	Section('BluUI')
	Row('Version', BUI.Version)
	Row('Profile', BUI.GetAceDB():GetCurrentProfile())
	Row('Theme', theme.name or 'Custom')
	local fonts = theme.fonts or {}
	Row('Window font', fonts.base or 'Default')
	for _, tier in ipairs({ 'title', 'body', 'hint', 'control' }) do
		if fonts[tier] then Row('Font for ' .. tier, fonts[tier]) end
	end
	local overrides = 0
	for _ in pairs(theme.dark or {}) do overrides = overrides + 1 end
	Row('Color overrides', overrides)
	Row('Saved themes', #BUI.db.global.savedThemes)

	Section('Character')
	Row('Name', UnitName('player') .. ' - ' .. GetRealmName())
	local className, classFile = UnitClass('player')
	Row('Class', className .. ' (' .. classFile .. ')')
	local specIndex = GetSpecialization()
	Row('Spec', specIndex and select(2, GetSpecializationInfo(specIndex)) or 'none')
	Row('Race', (UnitRace('player')))
	Row('Faction', (UnitFactionGroup('player')))
	Row('Level', UnitLevel('player'))
	local overall, equipped = GetAverageItemLevel()
	Row('Item level', ('%.1f equipped, %.1f overall'):format(equipped, overall))
	local money = GetMoney()
	Row('Gold', ('%s gold %d silver'):format(BreakUpLargeNumbers(math.floor(money / 10000)), math.floor(money / 100) % 100))
	Row('Group', IsInRaid() and ('Raid of ' .. GetNumGroupMembers()) or (IsInGroup() and ('Party of ' .. GetNumGroupMembers()) or 'Solo'))
	local subZone = GetSubZoneText()
	Row('Zone', GetZoneText() .. (subZone ~= '' and (' / ' .. subZone) or ''))
	local instanceName, instanceType, _, difficultyName = GetInstanceInfo()
	Row('Instance', instanceType == 'none' and 'None' or (instanceName .. ' (' .. (difficultyName ~= '' and difficultyName or instanceType) .. ')'))
	Row('Mythic+ rating', C_ChallengeMode.GetOverallDungeonScore() or 0)
	Row('Session', Elapsed(GetSessionTime()))

	Section('Client')
	local clientVersion, build, buildDate, tocVersion = GetBuildInfo()
	Row('Version', clientVersion .. ' (build ' .. build .. ', ' .. buildDate .. ')')
	Row('TOC', tocVersion)
	Row('Locale', GetLocale())
	Row('Region', GetCurrentRegionName())
	Row('Frame rate', ('%d fps'):format(GetFramerate()))
	local bandwidthIn, bandwidthOut, home, world = GetNetStats()
	Row('Latency', ('%d ms home, %d ms world'):format(home, world))
	Row('Bandwidth', ('%.1f KB/s in, %.1f KB/s out'):format(bandwidthIn, bandwidthOut))

	Section('Display')
	local screenWidth, screenHeight = GetPhysicalScreenSize()
	Row('Monitor', ('%d x %d'):format(screenWidth, screenHeight))
	Row('Logical size', ('%d x %d'):format(GetScreenWidth(), GetScreenHeight()))
	Row('Resolution', CVar('gxWindowedResolution') .. ' windowed, ' .. CVar('gxFullscreenResolution') .. ' fullscreen')
	Row('Window mode', 'gxWindow ' .. CVar('gxWindow') .. ', gxMaximize ' .. CVar('gxMaximize'))
	Row('Monitor index', CVar('gxMonitor'))
	Row('Render scale', CVar('renderScale'))
	Row('Graphics quality', CVar('graphicsQuality'))
	Row('VSync', CVar('vsync'))
	Row('FPS cap', CVar('maxFPS') .. ' foreground, ' .. CVar('maxFPSBk') .. ' background')
	Row('UI scale', CVar('uiScale') .. ' (useUiScale ' .. CVar('useUiScale') .. ')')
	Row('UIParent scale', ('%.4f effective'):format(UIParent:GetEffectiveScale()))
	Row('Pixel perfect scale', ('%.4f'):format(768 / screenHeight))
	local frame = BUI.PageEngine.window.frame
	Row('BluUI window', ('%d x %d at %.4f effective'):format(frame:GetWidth(), frame:GetHeight(), frame:GetEffectiveScale()))

	Section('Memory')
	UpdateAddOnMemoryUsage()
	Row('Lua heap', Megabytes(collectgarbage('count')))
	Row('BluUI', Megabytes(GetAddOnMemoryUsage('BluUI')))
	Row('BluUI_Options', Megabytes(GetAddOnMemoryUsage('BluUI_Options')))
	local heaviest, total = {}, 0
	for index = 1, C_AddOns.GetNumAddOns() do
		if C_AddOns.IsAddOnLoaded(index) then
			local memory = GetAddOnMemoryUsage(index)
			total = total + memory
			heaviest[#heaviest + 1] = { name = (C_AddOns.GetAddOnInfo(index)), memory = memory }
		end
	end
	table.sort(heaviest, function(first, second) return first.memory > second.memory end)
	Row('All addons', Megabytes(total))
	Add('Heaviest:')
	for index = 1, math.min(10, #heaviest) do
		Add(('  %-30s %s'):format(heaviest[index].name, Megabytes(heaviest[index].memory)))
	end

	Section('Settings')
	Row('Global font', db.general.font)
	Row('Slug outline', db.general.fontSlug)
	Row('Texture', db.general.texture)
	Row('Class color theme', db.general.useClassColorTheme)
	local themeColor = db.general.themeColor
	Row('Theme color', ('%.2f, %.2f, %.2f'):format(themeColor[1], themeColor[2], themeColor[3]))
	Row('Smooth bars', db.general.smoothBars)

	Section('Modules')
	local keys = {}
	for key in pairs(db.modules) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do Add(('  %-16s %s'):format(key, db.modules[key] and 'on' or 'off')) end

	Section('Frame positions')
	for _, line in ipairs(BUI.MoveFrames.Report()) do Add(line) end

	Section('Addons')
	local loaded, waiting = {}, 0
	for index = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(index)
		if C_AddOns.IsAddOnLoaded(index) then
			local version = C_AddOns.GetAddOnMetadata(name, 'Version') or ''
			loaded[#loaded + 1] = version ~= '' and (name .. ' v' .. version) or name
		elseif C_AddOns.GetAddOnEnableState(index, UnitName('player')) > 0 then
			waiting = waiting + 1
		end
	end
	table.sort(loaded, function(first, second) return first:lower() < second:lower() end)
	Row('Loaded', #loaded .. ' of ' .. C_AddOns.GetNumAddOns() .. (waiting > 0 and (', ' .. waiting .. ' enabled but not loaded') or ''))
	for _, entry in ipairs(loaded) do Add('  ' .. entry) end

	return table.concat(lines, '\n')
end

local function Sections(ui, _, parent, width)
	local window = Window()
	local cards = Layout.CardKit(window)
	local pad = cards.PAD
	local cardHeight = math.max(CARD_MIN_HEIGHT, window.content:GetHeight() - PAGE_OVERHEAD)
	local host = CreateFrame('Frame', nil, parent)
	host:SetSize(width, cardHeight)

	local card = cards.Card(host, 0, 0, width, cardHeight)
	cards.Title(card, 'Report')
	cards.Description(card, 'Gathers your character, client, settings, addon list and frame positions. Nothing leaves your computer until you paste it with what happened.', pad, BODY_Y, width - pad * 2)

	local box = CreateFrame('Frame', nil, card)
	box:SetPoint('TOPLEFT', pad, -BOX_Y)
	box:SetPoint('BOTTOMRIGHT', -pad, pad + 30 + 14)
	for _, piece in ipairs(Widget.DrawRoundedRect(box, 6, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)) do window:Paint(piece, 'input') end
	local scroll = CreateFrame('ScrollFrame', nil, box)
	scroll:SetPoint('TOPLEFT', BOX_PAD, -BOX_PAD)
	scroll:SetPoint('BOTTOMRIGHT', -BOX_PAD, BOX_PAD)
	local edit = CreateFrame('EditBox', nil, scroll)
	edit:SetWidth(width - pad * 2 - BOX_PAD * 2)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(0)
	edit:SetFont(window.font, 11, '')
	window:Paint(edit, 'text')
	window:SetFontRole(edit, 'control')
	scroll:SetScrollChild(edit)
	scroll:EnableMouseWheel(true)
	scroll:SetScript('OnMouseWheel', function(self, delta)
		local range = math.max(0, edit:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * SCROLL_STEP)))
	end)
	edit:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
	box:EnableMouse(true)
	box:SetScript('OnMouseDown', function() edit:SetFocus() end)
	box:Hide()

	local generate = ui.Button(card, 'Generate report', 'primary', function()
		edit:SetText(GatherDiagnostics())
		box:Show()
		scroll:SetVerticalScroll(0)
		edit:SetFocus()
		edit:HighlightText()
	end, 'copy')
	generate:SetPoint('BOTTOMLEFT', pad, pad)

	local link = ui.Button(card, 'Copy the issues link', 'secondary', function()
		Modals.Copy({ title = 'Issues page', message = 'The link is selected. Press Ctrl+C to copy it.', text = ISSUES_URL })
	end, 'copy')
	link:SetPoint('BOTTOMRIGHT', -pad, pad)

	return { host }
end

BUI.HelpPage = { Sections = Sections }
