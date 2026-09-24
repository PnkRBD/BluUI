local _, BUI = ...
local SetScript = BUI.Prof.Scripts('Minimap.Menu')

local Menu = {}
BUI.MinimapMenu = Menu

local Pixel = BUI.Pixel
local Client = BUI.BUILibClient
local LibMedia = Client.GetLibMedia
local SetColorTex = BUI.Tools.SetColorTex
local BUILib = LibStub('BUILib')

local PAD          = 14
local TITLE_H      = 52
local TITLE_SIZE   = 16
local SUBTITLE_SIZE = 10
local ROW_H        = 36
local DROPDOWN_W   = 200
local MENU_W       = 370
local CONTENT_W    = MENU_W - PAD * 2
local TOOL_ROW_H   = 27
local TOOL_GAP     = 6
local FOOTER_GAP   = 12
local VISIBLE_ROWS = 14
local TOOL_FILL    = { 0.02, 0.022, 0.026, 1 }

local SECTIONS = {
	{ key = 'tracking', label = 'Tracking' },
	{ key = 'world',    label = 'World & Townsfolk' },
}

local HUNTER_TRACKING_SUBTYPE = 1
local TOWNSFOLK_TRACKING_SUBTYPE = 2

local function SectionKey(info)
	if info.subType == TOWNSFOLK_TRACKING_SUBTYPE then return 'world' end
	if info.subType == HUNTER_TRACKING_SUBTYPE or info.spellID or info.type == 'spell' then return 'tracking' end
	return 'world'
end

local function DisplayName(name)
	return (name:gsub('^Track ', ''):gsub('^Find ', ''))
end

local menu
local sectionRows = {}
local PopulateTracking
local RefreshSubtitle

local function CalendarAtlas()
	return 'UI-HUD-Calendar-' .. tonumber(date('%d')) .. '-Up'
end

local pendingCombatAction
local queueRegistered = false

local function QueueForCombatEnd(callback)
	pendingCombatAction = callback
	if not queueRegistered then
		queueRegistered = true
		BUI.Events:Register('PLAYER_REGEN_ENABLED', 'MinimapMenuQueue', function()
			local queuedAction = pendingCombatAction
			pendingCombatAction = nil
			if queuedAction then queuedAction() end
		end)
	end
end

local function OpenCalendar()
	if InCombatLockdown() then
		BUI.Print('Calendar opens when combat ends.')
		QueueForCombatEnd(OpenCalendar)
		return
	end
	GameTimeFrame:Click()
end

local function PopupOpen()
	return (BUILib._popupCount or 0) > 0
end

local function CollectSections()
	local buckets = {}
	for _, section in ipairs(SECTIONS) do
		buckets[section.key] = { items = {}, selected = {}, indexes = {} }
	end

	local seen = {}
	for trackingIndex = 1, C_Minimap.GetNumTrackingTypes() do
		local info = C_Minimap.GetTrackingInfo(trackingIndex)
		if info and info.name and not seen[info.name] then
			seen[info.name] = true
			local bucket = buckets[SectionKey(info)] or buckets.tracking
			bucket.items[#bucket.items + 1] = { value = trackingIndex, text = DisplayName(info.name), icon = info.texture }
			bucket.indexes[#bucket.indexes + 1] = trackingIndex
			if info.active then bucket.selected[trackingIndex] = true end
		end
	end

	if #buckets.tracking.items == 0 then
		buckets.tracking, buckets.world = buckets.world, buckets.tracking
	end
	return buckets
end

local function ApplySelection(row, selection)
	for _, trackingIndex in ipairs(row.indexes) do
		local info = C_Minimap.GetTrackingInfo(trackingIndex)
		if info then
			local wanted = selection[trackingIndex] and true or false
			if (info.active and true or false) ~= wanted then
				C_Minimap.SetTracking(trackingIndex, wanted)
			end
		end
	end
end

local function BuildSectionRow(section)
	local row = { indexes = {} }

	row.label = menu:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(row.label, 11, BUI.GetGlobalFont())
	row.label:SetJustifyH('LEFT')
	row.label:SetTextColor(0.85, 0.85, 0.88)
	row.label:SetText(section.label)

	row.dropdown = Client.Controls.MultiDropdown(menu, nil, {}, {}, function(selection)
		ApplySelection(row, selection)
	end, nil, DROPDOWN_W, VISIBLE_ROWS)

	sectionRows[section.key] = row
	return row
end

local function RefreshSelection()
	local buckets = CollectSections()
	for _, section in ipairs(SECTIONS) do
		local row = sectionRows[section.key]
		local bucket = buckets[section.key]
		if #bucket.items > 0 then row.dropdown:SetValue(bucket.selected) end
	end
	RefreshSubtitle()
end

local function CloseDropdowns()
	for _, row in pairs(sectionRows) do
		if row.dropdown.CloseMenu then row.dropdown:CloseMenu() end
	end
end

local toolActions = {
	{ label = 'Settings',  texture = BUI.C.ICON_PATH,    onClick = function() BUI.PageEngine.Toggle() end },
	{ label = 'Calendar',  dynamic = true,               onClick = OpenCalendar },
	{ label = 'Reload',    texture = LibMedia('reload'), onClick = BUI.Reload },
}

local function CreateToolRow(action)
	local row = Client.Controls.ToolButton(menu, {
		label        = action.label,
		atlas        = action.dynamic and CalendarAtlas() or nil,
		texture      = (not action.dynamic) and action.texture or nil,
		fill         = TOOL_FILL,
		height       = Pixel.Scale(TOOL_ROW_H),
		iconSize     = Pixel.Scale(15),
		iconGap      = Pixel.Scale(7),
		labelOffsetX = Pixel.Scale(11),
		dotSize      = Pixel.Scale(5),
		dotInset     = Pixel.Scale(5),
		setScript    = SetScript,
		onClick      = function() menu:Hide(); action.onClick() end,
	})
	Pixel.ApplyFont(row.label, 11, BUI.GetGlobalFont())
	return row
end

local function BuildToolPane()
	menu._toolRows = {}
	for actionIndex = 1, #toolActions do
		local row = CreateToolRow(toolActions[actionIndex])
		menu._toolRows[actionIndex] = row
		if toolActions[actionIndex].dynamic then menu.calendarRow = row end
	end
end

local function RefreshAccent()
	local red, green, blue = BUI.GetAccentColor()
	menu.title:SetText(format('Tracking |cff%s&|r Tools', BUI.Hex(red, green, blue)))
end

RefreshSubtitle = function()
	local parts = {}
	local zone = GetZoneText()
	local subZone = GetSubZoneText()
	if zone and zone ~= '' then parts[#parts + 1] = zone end
	if subZone and subZone ~= '' and subZone ~= zone then parts[#parts + 1] = subZone end

	local activeCount = 0
	for trackingIndex = 1, C_Minimap.GetNumTrackingTypes() do
		local info = C_Minimap.GetTrackingInfo(trackingIndex)
		if info and info.active then activeCount = activeCount + 1 end
	end
	parts[#parts + 1] = format('%d tracking active', activeCount)

	menu.subtitle:SetText(table.concat(parts, '   ·   '))
end

local function BuildMenu()
	if menu then return menu end

	menu = CreateFrame('Frame', 'BUI_MinimapMenu', UIParent, 'BackdropTemplate')
	menu.isBluUIWindow = true
	menu:SetSize(Pixel.Scale(MENU_W), Pixel.Scale(200))
	menu:SetFrameStrata('DIALOG')
	menu:SetFrameLevel(100)
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	Pixel.SetTemplate(menu, unpack(BUI.C.PANEL_BACKDROP))
	menu:Hide()
	table.insert(UISpecialFrames, 'BUI_MinimapMenu')

	local pressedOutside = false
	local function OnGlobalMouse(event)
		if event == 'GLOBAL_MOUSE_DOWN' then
			pressedOutside = not menu:IsMouseOver() and not PopupOpen()
		elseif event == 'GLOBAL_MOUSE_UP' and pressedOutside and not menu:IsMouseOver() then
			menu:Hide()
		end
	end
	SetScript(menu, 'OnShow', function()
		pressedOutside = false
		BUI.Events:Register('GLOBAL_MOUSE_DOWN', 'Minimap.Menu', OnGlobalMouse)
		BUI.Events:Register('GLOBAL_MOUSE_UP',   'Minimap.Menu', OnGlobalMouse)
		BUI.Events:Register('MINIMAP_UPDATE_TRACKING', 'Minimap.Menu', function()
			if menu:IsShown() then RefreshSelection() end
		end)
	end)
	SetScript(menu, 'OnHide', function()
		BUI.Events:UnregisterAll('Minimap.Menu')
		CloseDropdowns()
	end)

	menu.title = menu:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(menu.title, TITLE_SIZE, BUI.GetGlobalFont(), '')
	menu.title:SetPoint('TOPLEFT', Pixel.Scale(PAD), Pixel.Scale(-PAD))
	menu.title:SetJustifyH('LEFT')
	menu.title:SetTextColor(1, 1, 1)

	menu.subtitle = menu:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(menu.subtitle, SUBTITLE_SIZE, BUI.GetGlobalFont(), '')
	menu.subtitle:SetPoint('TOPLEFT', menu.title, 'BOTTOMLEFT', 0, Pixel.Scale(-6))
	menu.subtitle:SetJustifyH('LEFT')
	menu.subtitle:SetTextColor(0.55, 0.55, 0.6)

	for _, section in ipairs(SECTIONS) do BuildSectionRow(section) end

	BuildToolPane()
	RefreshAccent()
	return menu
end

PopulateTracking = function()
	local buckets = CollectSections()
	local visibleRows = 0

	for _, section in ipairs(SECTIONS) do
		local row = sectionRows[section.key]
		local bucket = buckets[section.key]
		if #bucket.items == 0 then
			row.label:Hide()
			row.dropdown:Hide()
		else
			visibleRows = visibleRows + 1
			local centerY = TITLE_H + 10 + (visibleRows - 1) * ROW_H + ROW_H / 2
			row.indexes = bucket.indexes
			row.label:ClearAllPoints()
			row.label:SetPoint('LEFT', menu, 'TOPLEFT', Pixel.Scale(PAD), Pixel.Scale(-centerY))
			row.dropdown:ClearAllPoints()
			row.dropdown:SetPoint('RIGHT', menu, 'TOPRIGHT', Pixel.Scale(-PAD), Pixel.Scale(-centerY))
			row.dropdown:SetItems(bucket.items, bucket.selected)
			row.label:Show()
			row.dropdown:Show()
		end
	end

	local toolsY = TITLE_H + 10 + visibleRows * ROW_H + FOOTER_GAP
	local toolCount = #menu._toolRows
	local toolSpan = CONTENT_W + TOOL_GAP
	for toolIndex = 1, toolCount do
		local row = menu._toolRows[toolIndex]
		local left = PAD + math.floor((toolIndex - 1) * toolSpan / toolCount)
		local right = PAD + math.floor(toolIndex * toolSpan / toolCount) - TOOL_GAP
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', menu, 'TOPLEFT', Pixel.Scale(left), Pixel.Scale(-toolsY))
		row:SetPoint('TOPRIGHT', menu, 'TOPLEFT', Pixel.Scale(right), Pixel.Scale(-toolsY))
	end

	menu:SetHeight(Pixel.Scale(toolsY + TOOL_ROW_H + PAD))
end

function Menu.Show()
	BUI.Datatext.HideSocial()
	BuildMenu()
	RefreshAccent()
	RefreshSubtitle()
	menu.calendarRow:SetIconAtlas(CalendarAtlas())
	local pending = C_Calendar.GetNumPendingInvites()
	if pending > 0 then
		local red, green, blue = BUI.GetAccentColor()
		SetColorTex(menu.calendarRow.dot, red, green, blue, 1)
		menu.calendarRow.dot:Show()
	else
		menu.calendarRow.dot:Hide()
	end
	PopulateTracking()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	menu:ClearAllPoints()
	menu:SetPoint('TOPRIGHT', UIParent, 'BOTTOMLEFT', x / scale, y / scale)
	menu:Show()
end

local hooked = false

function Menu.Setup()
	if hooked then return end
	hooked = true
	BuildMenu()
	local minimap = _G.Minimap
	local originalOnMouseUp = minimap:GetScript('OnMouseUp')
	SetScript(minimap, 'OnMouseUp', function(self, button, ...)
		if button == 'RightButton' then
			Menu.Show()
		elseif button == 'MiddleButton' then
			OpenCalendar()
		elseif originalOnMouseUp then
			originalOnMouseUp(self, button, ...)
		end
	end)
end
