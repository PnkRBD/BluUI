local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout
local Widget = BUILib.Widget
local Modals = BUILib.Modals

local RAIL_WIDTH = 240
local RAIL_GAP = 40
local CARD_HEIGHT = 320
local BODY_Y = 42
local BOX_Y = 92
local BOX_PAD = 12
local SCROLL_STEP = 40
local ISSUES_URL = 'https://github.com/PnkRBD/BluUI/issues'

local STEPS = {
	{ id = 'generate', label = 'Generate the report', sub = 'One click gathers the details' },
	{ id = 'copy', label = 'Copy it', sub = 'Ctrl+C, it is already selected' },
	{ id = 'send', label = 'Send it', sub = 'Paste it with what happened' },
}

local function Window()
	return BUI.PageEngine.window
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

local function Sections(ui, _, parent, width)
	local window = Window()
	local cards = Layout.CardKit(window)
	local pad = cards.PAD
	local host = CreateFrame('Frame', nil, parent)
	host:SetSize(width, 1)

	local contentX = RAIL_WIDTH + RAIL_GAP
	local contentWidth = width - contentX
	local card = cards.Card(host, contentX, 0, contentWidth, CARD_HEIGHT)
	local done, report = {}, ''
	local panes = {}
	local rail

	local function Show(id)
		for paneID, pane in pairs(panes) do pane:SetShown(paneID == id) end
		rail:Select(id)
	end

	local function Pane(id, title, description)
		local pane = CreateFrame('Frame', nil, card)
		pane:SetAllPoints()
		pane:Hide()
		cards.Title(pane, title)
		cards.Description(pane, description, pad, BODY_Y, contentWidth - pad * 2)
		panes[id] = pane
		return pane
	end

	local generate = Pane('generate', 'Generate the report', 'One click gathers your character, client, settings and addon list. Nothing leaves your computer until you paste it.')
	local generateButton = ui.Button(generate, 'Generate report', 'primary', function()
		report = GatherDiagnostics()
		done.generate = true
		Show('copy')
	end, 'report2')
	generateButton:SetPoint('BOTTOMLEFT', pad, pad)

	local copy = Pane('copy', 'Copy it', 'The report is selected. Press Ctrl+C, then carry on.')
	local box = CreateFrame('Frame', nil, copy)
	box:SetPoint('TOPLEFT', pad, -BOX_Y)
	box:SetPoint('BOTTOMRIGHT', -pad, pad + 30 + 14)
	for _, piece in ipairs(Widget.DrawRoundedRect(box, 6, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)) do window:Paint(piece, 'input') end
	local scroll = CreateFrame('ScrollFrame', nil, box)
	scroll:SetPoint('TOPLEFT', BOX_PAD, -BOX_PAD)
	scroll:SetPoint('BOTTOMRIGHT', -BOX_PAD, BOX_PAD)
	local edit = CreateFrame('EditBox', nil, scroll)
	edit:SetWidth(contentWidth - pad * 2 - BOX_PAD * 2)
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
	copy:SetScript('OnShow', function()
		edit:SetText(report)
		scroll:SetVerticalScroll(0)
		edit:SetFocus()
		edit:HighlightText()
	end)
	local copied = ui.Button(copy, 'I copied it', 'primary', function()
		done.copy = true
		Show('send')
	end, 'check')
	copied:SetPoint('BOTTOMRIGHT', -pad, pad)
	local back = ui.Button(copy, 'Back', 'secondary', function() Show('generate') end)
	back:SetPoint('BOTTOMLEFT', pad, pad)

	local send = Pane('send', 'Send it', 'Paste the report with what happened and what you expected. Anywhere you reach us works, and the issues page keeps everything in one place.')
	local link = ui.Button(send, 'Copy the issues link', 'secondary', function()
		Modals.Copy({ title = 'Issues page', message = 'The link is selected. Press Ctrl+C to copy it.', text = ISSUES_URL })
	end, 'copy')
	link:SetPoint('BOTTOMLEFT', pad, pad)
	local again = ui.Button(send, 'Start over', 'secondary', function()
		done, report = {}, ''
		Show('generate')
	end, 'reset')
	again:SetPoint('BOTTOMRIGHT', -pad, pad)
	send:SetScript('OnShow', function()
		done.send = true
		rail:Refresh()
	end)

	rail = Layout.Rail(window, host, RAIL_WIDTH, {
		style = 'steps',
		groups = { { items = STEPS } },
		isDone = function(item) return done[item.id] == true end,
		onSelect = function(item) Show(item.id) end,
	})
	rail.frame:SetPoint('TOPLEFT', 0, -pad)
	Show('generate')

	host:SetHeight(math.max(rail.height + pad, CARD_HEIGHT))
	return { host }
end

BUI.HelpPage = { Sections = Sections }
