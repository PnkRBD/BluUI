local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout
local Widget = BUILib.Widget

local REPORT_HEIGHT = 300
local BOX_PAD = 12
local SCROLL_STEP = 40
local HEAVIEST = 4

local COMMANDS = {
	{ label = 'Open or close the settings', keys = { '/bui' } },
	{ label = 'Recenter the window', keys = { '/bui', 'center' } },
	{ label = 'Run the setup wizard', keys = { '/bui', 'install' } },
	{ label = 'Keybind mode for action bars', keys = { '/bui', 'keybind' } },
	{ label = 'Unit frame test mode', keys = { '/buitest' } },
	{ label = 'Reload the interface', keys = { '/rl' } },
}

local STEPS = {
	{ label = 'Generate the report', sub = 'It gathers your character, client and addon details' },
	{ label = 'Copy it', sub = 'Click into the box, then Ctrl+A and Ctrl+C' },
	{ label = 'Paste it with the bug', sub = 'What happened, what you expected, and the report' },
}

local function Window()
	return BUI.PageEngine.window
end

local function Megabytes(kilobytes)
	return ('%.0f MB'):format(kilobytes / 1024)
end

local function GatherDiagnostics()
	local db = BUI.GetDB()
	local lines = {}
	local function AddLine(line) lines[#lines + 1] = line end

	AddLine('== BluUI ==')
	AddLine('Version: ' .. BUI.Version)

	local _, class = UnitClass('player')
	local specIndex = GetSpecialization()
	local specName = specIndex and select(2, GetSpecializationInfo(specIndex)) or 'none'
	AddLine('')
	AddLine('== Character ==')
	AddLine('Name: ' .. UnitName('player') .. ' - ' .. GetRealmName())
	AddLine('Class: ' .. class)
	AddLine('Spec: ' .. specName)
	AddLine('Level: ' .. UnitLevel('player'))

	local clientVersion, build, _, tocVersion = GetBuildInfo()
	AddLine('')
	AddLine('== Client ==')
	AddLine('Version: ' .. clientVersion .. ' (build ' .. build .. ')')
	AddLine('TOC: ' .. tocVersion)
	AddLine('Locale: ' .. GetLocale())
	local screenWidth, screenHeight = GetPhysicalScreenSize()
	AddLine('Screen: ' .. screenWidth .. 'x' .. screenHeight)
	AddLine('UI Scale: ' .. format('%.4f', UIParent:GetEffectiveScale()))

	AddLine('')
	AddLine('== Settings ==')
	AddLine('Font: ' .. tostring(db.general.font))
	AddLine('Texture: ' .. tostring(db.general.texture))
	AddLine('Class Color Theme: ' .. tostring(db.general.useClassColorTheme))
	local themeColor = db.general.themeColor
	AddLine('Theme Color: ' .. format('%.2f, %.2f, %.2f', themeColor[1], themeColor[2], themeColor[3]))
	AddLine('')
	AddLine('== Modules ==')
	for moduleKey, moduleEnabled in pairs(db.modules) do
		AddLine('  ' .. moduleKey .. ': ' .. tostring(moduleEnabled))
	end

	AddLine('')
	AddLine('== Addons (' .. C_AddOns.GetNumAddOns() .. ') ==')
	for addonIndex = 1, C_AddOns.GetNumAddOns() do
		local addonName = C_AddOns.GetAddOnInfo(addonIndex)
		if C_AddOns.IsAddOnLoaded(addonIndex) then
			local addonVersion = C_AddOns.GetAddOnMetadata(addonName, 'Version') or ''
			AddLine(addonVersion ~= '' and ('  ' .. addonName .. ' v' .. addonVersion) or ('  ' .. addonName))
		end
	end

	return table.concat(lines, '\n')
end

local function LoadedAddons()
	local count = 0
	for index = 1, C_AddOns.GetNumAddOns() do
		if C_AddOns.IsAddOnLoaded(index) then count = count + 1 end
	end
	return count
end

local function HeaviestAddons()
	UpdateAddOnMemoryUsage()
	local list, total = {}, 0
	for index = 1, C_AddOns.GetNumAddOns() do
		if C_AddOns.IsAddOnLoaded(index) then
			local memory = GetAddOnMemoryUsage(index)
			total = total + memory
			list[#list + 1] = { name = (C_AddOns.GetAddOnInfo(index)), memory = memory }
		end
	end
	table.sort(list, function(first, second) return first.memory > second.memory end)
	local rows = {}
	for index = 1, math.min(HEAVIEST, #list) do
		local entry = list[index]
		rows[index] = { name = entry.name, value = Megabytes(entry.memory), fraction = total > 0 and entry.memory / total or 0 }
	end
	return rows, total
end

local function ReportCard(ui, cards, window, parent, x, y, width)
	local card = cards.Card(parent, x, y, width, REPORT_HEIGHT)
	cards.Title(card, 'Diagnostics report')
	cards.Description(card, 'Character, client, settings and addon details. Paste it with a bug report.', cards.PAD, 38, width - cards.PAD * 2 - 160)

	local box = CreateFrame('Frame', nil, card)
	box:SetPoint('TOPLEFT', cards.PAD, -72)
	box:SetPoint('BOTTOMRIGHT', -cards.PAD, cards.PAD)
	for _, piece in ipairs(Widget.DrawRoundedRect(box, 6, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)) do window:Paint(piece, 'input') end
	local scroll = CreateFrame('ScrollFrame', nil, box)
	scroll:SetPoint('TOPLEFT', BOX_PAD, -BOX_PAD)
	scroll:SetPoint('BOTTOMRIGHT', -BOX_PAD, BOX_PAD)
	local edit = CreateFrame('EditBox', nil, scroll)
	edit:SetWidth(width - cards.PAD * 2 - BOX_PAD * 2)
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

	local hint = cards.Description(box, 'Nothing generated yet. Generate builds the report and selects it for Ctrl+C.', BOX_PAD, BOX_PAD, width - cards.PAD * 2 - BOX_PAD * 2)
	local generate = ui.Button(card, 'Generate', 'primary', function()
		edit:SetText(GatherDiagnostics())
		hint:Hide()
		scroll:SetVerticalScroll(0)
		edit:SetFocus()
		edit:HighlightText()
	end, 'report2')
	generate:SetPoint('TOPRIGHT', -cards.PAD, -(cards.PAD - 6))
	return card
end

local function Sections(ui, _, parent, width)
	local window = Window()
	local cards = Layout.CardKit(window)
	local host = CreateFrame('Frame', nil, parent)
	host:SetSize(width, 1)

	local className = UnitClass('player')
	local specIndex = GetSpecialization()
	local specName = specIndex and select(2, GetSpecializationInfo(specIndex)) or 'No spec'
	local clientVersion, build = GetBuildInfo()
	local heaviest, total = HeaviestAddons()

	local height = cards.Grid(host, width, {
		{
			{ span = 'third', build = function(frame, x, y, span)
				return cards.Profile(frame, x, y, span, { unit = 'player', name = UnitName('player'), sub = 'Level ' .. UnitLevel('player') .. ' ' .. className, tags = { specName, GetRealmName() } })
			end },
			{ span = 'twoThirds', build = function(frame, x, y, span)
				return cards.Strip(frame, x, y, span, {
					cells = { { sub = 'BluUI version', accent = true }, { sub = 'Client build' }, { sub = 'Addons loaded' }, { sub = 'BluUI memory' } },
					values = { BUI.Version, clientVersion .. ' (' .. build .. ')', tostring(LoadedAddons()), Megabytes(GetAddOnMemoryUsage('BluUI')) },
				})
			end },
		},
		{
			{ span = 'full', build = function(frame, x, y, span) return ReportCard(ui, cards, window, frame, x, y, span) end },
		},
		{
			{ span = 'third', build = function(frame, x, y, span)
				return cards.Steps(frame, x, y, span, { title = 'Report a bug', steps = STEPS, states = { 'current', 'todo', 'todo' } })
			end },
			{ span = 'third', build = function(frame, x, y, span)
				return cards.Keycaps(frame, x, y, span, { title = 'Slash commands', rows = COMMANDS })
			end },
			{ span = 'third', build = function(frame, x, y, span)
				return cards.Breakdown(frame, x, y, span, { title = 'Heaviest addons', rows = HEAVIEST, list = heaviest, total = Megabytes(total) .. ' in use' })
			end },
		},
		{
			{ span = 'third', build = function(frame, x, y, span)
				return cards.Clock(frame, x, y, span, { caption = 'Latency', icon = 'reload', every = 5, read = function()
					local _, _, home, world = GetNetStats()
					return home .. ' ms', 'World ' .. world .. ' ms, ' .. math.floor(GetFramerate() + 0.5) .. ' fps'
				end })
			end },
			{ span = 'third', build = function(frame, x, y, span)
				return cards.Action(frame, x, y, span, { icon = 'reload', title = 'Reload the interface', description = 'Applies everything that waits for a reload, and clears a stuck frame.', onClick = ReloadUI })
			end },
			{ span = 'third', build = function(frame, x, y, span)
				return cards.Callout(frame, x, y, span, { title = 'Tip', body = 'Most changes apply as you make them. Modules that wait for a reload say so in their status.' })
			end },
		},
	})
	host:SetHeight(height)
	return { host }
end

BUI.HelpPage = { Sections = Sections }
