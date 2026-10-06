local _, BUI = ...

local Menu = {}
BUI.MinimapMenu = Menu

local Pixel = BUI.Pixel
local Client = BUI.BUILibClient
local Controls = Client.Controls
local LibMedia = Client.GetLibMedia
local SetColorTex = BUI.Tools.SetColorTex
local Layout = Client.Layout
local Widget = Client.Widget

local PAD           = 14
local TITLE_H       = 52
local TITLE_SIZE    = 13
local SUBTITLE_SIZE = 12
local SUBTITLE_GAP  = 8
local TITLE_TEXT    = 'Tracking & Tools'
local LABEL_SIZE    = 11
local CONTROL_SIZE  = 11
local ROW_H         = 36
local DROPDOWN_W    = 200
local DROPDOWN_H    = 26
local DROPDOWN_TEXT_X = 10
local ARROW_SIZE    = 9
local LIST_MIN_W    = 220
local LIST_GAP      = 4
local MENU_W        = 370
local CONTENT_W     = MENU_W - PAD * 2
local TOOL_ROW_H    = 27
local TOOL_GAP      = 6
local FOOTER_GAP    = 12
local TOOL_ICON     = 15
local TOOL_ICON_GAP = 7
local DOT_SIZE      = 5
local DOT_INSET     = 5
local CARD_RADIUS   = 8
local ICON_MARKUP   = '|T%s:14:14:0:0|t  %s'

local SECTIONS = {
	{ key = 'tracking', label = 'Tracking' },
	{ key = 'world',    label = 'World & Townsfolk' },
}

local HUNTER_TRACKING_SUBTYPE = 1
local TOWNSFOLK_TRACKING_SUBTYPE = 2

local THEME = {}

function THEME:Color(role)
	return BUI.ThemeColor(role)
end

function THEME:FontPath(fontRole)
	return BUI.ThemeFontPath(fontRole)
end

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

local function PaintText(fontString, role, fontRole, size)
	Pixel.ApplyFont(fontString, size, BUI.ThemeFontPath(fontRole), '')
	fontString:SetTextColor(BUI.ThemeColor(role))
end

local function ShowHover(button) button.hover:Show() end
local function HideHover(button) button.hover:Hide() end

local function ControlButton()
	local button = CreateFrame('Button', nil, menu)
	button.fill = button:CreateTexture(nil, 'BACKGROUND', nil, 0)
	button.fill:SetAllPoints()
	local hoverColor = Layout.SOLID_HOVER
	button.hover = button:CreateTexture(nil, 'BACKGROUND', nil, 1)
	button.hover:SetAllPoints()
	button.hover:SetColorTexture(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4])
	button.hover:Hide()
	button:SetScript('OnEnter', ShowHover)
	button:SetScript('OnLeave', HideHover)
	return button
end

local function CalendarAtlas()
	return 'UI-HUD-Calendar-' .. tonumber(date('%d')) .. '-Up'
end

local function OpenCalendar()
	if InCombatLockdown() then BUI.Print('Calendar opens when combat ends.') end
	BUI.Events:AfterCombat(function() GameTimeFrame:Click() end, 'MinimapMenu.Calendar')
end

local function CollectSections()
	local buckets = {}
	for _, section in ipairs(SECTIONS) do
		buckets[section.key] = { items = {}, indexes = {} }
	end

	local seen = {}
	for trackingIndex = 1, C_Minimap.GetNumTrackingTypes() do
		local info = C_Minimap.GetTrackingInfo(trackingIndex)
		if info and info.name and not seen[info.name] then
			seen[info.name] = true
			local bucket = buckets[SectionKey(info)]
			bucket.items[#bucket.items + 1] = { value = trackingIndex, text = DisplayName(info.name), icon = info.texture }
			bucket.indexes[#bucket.indexes + 1] = trackingIndex
		end
	end

	if #buckets.tracking.items == 0 then
		buckets.tracking, buckets.world = buckets.world, buckets.tracking
	end
	return buckets
end

local function Summary(row)
	local count, first = 0, nil
	for _, trackingIndex in ipairs(row.indexes) do
		local info = C_Minimap.GetTrackingInfo(trackingIndex)
		if info and info.active then
			count = count + 1
			first = first or DisplayName(info.name)
		end
	end
	if count == 0 then return NONE end
	if count == 1 then return first end
	return format('%d selected', count)
end

local function OpenList(row, anchor)
	local items = {}
	for _, entry in ipairs(row.items) do
		local info = C_Minimap.GetTrackingInfo(entry.value)
		items[#items + 1] = {
			text = entry.icon and ICON_MARKUP:format(entry.icon, entry.text) or entry.text,
			checked = info and info.active or false,
			callback = function(item)
				item.checked = not item.checked
				C_Minimap.SetTracking(entry.value, item.checked)
				return true
			end,
		}
	end
	Controls.ContextMenu(items, { anchor = anchor, width = math.max(Pixel.Scale(DROPDOWN_W), LIST_MIN_W), offsetY = -LIST_GAP, window = THEME })
end

local function CreateDropdown(row)
	local button = ControlButton()
	button:SetSize(Pixel.Scale(DROPDOWN_W), Pixel.Scale(DROPDOWN_H))
	button.label = button:CreateFontString(nil, 'OVERLAY')
	button.label:SetPoint('LEFT', Pixel.Scale(DROPDOWN_TEXT_X), 0)
	button.label:SetPoint('RIGHT', -Pixel.Scale(DROPDOWN_TEXT_X + ARROW_SIZE + 6), 0)
	button.label:SetJustifyH('LEFT')
	button.label:SetWordWrap(false)
	button.arrow = button:CreateTexture(nil, 'OVERLAY')
	button.arrow:SetTexture(LibMedia('dropdown'))
	button.arrow:SetSize(Pixel.Scale(ARROW_SIZE), Pixel.Scale(ARROW_SIZE))
	button.arrow:SetPoint('RIGHT', -Pixel.Scale(DROPDOWN_TEXT_X), 0)
	button:SetScript('OnClick', BUI.Profiler.Script('Minimap.Menu dropdown OnClick', function(self) OpenList(row, self) end))
	return button
end

local function PaintDropdown(button)
	button.fill:SetColorTexture(BUI.ThemeColor('control'))
	PaintText(button.label, 'controlText', 'control', CONTROL_SIZE)
	button.arrow:SetVertexColor(BUI.ThemeColor('controlText'))
end

local function BuildSectionRow(section)
	local row = { items = {}, indexes = {}, text = section.label }
	row.label = menu:CreateFontString(nil, 'OVERLAY')
	row.label:SetJustifyH('LEFT')
	row.dropdown = CreateDropdown(row)
	sectionRows[section.key] = row
	return row
end

local function RefreshSubtitle()
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

	menu.subtitle:SetText(table.concat(parts, ' · '))
end

local function RefreshSelection()
	for _, row in pairs(sectionRows) do
		if row.dropdown:IsShown() then row.dropdown.label:SetText(Summary(row)) end
	end
	RefreshSubtitle()
end

local toolActions = {
	{ label = 'Settings',  texture = BUI.C.ICON_PATH,    onClick = function() BUI.PageEngine.Toggle() end },
	{ label = 'Calendar',  dynamic = true,               onClick = OpenCalendar },
	{ label = 'Reload',    texture = LibMedia('reload'), tint = true, onClick = ReloadUI },
}

local function CreateToolRow(action)
	local button = ControlButton()
	button:SetHeight(Pixel.Scale(TOOL_ROW_H))
	button.action = action
	button.label = button:CreateFontString(nil, 'OVERLAY')
	button.label:SetPoint('CENTER', Pixel.Scale(TOOL_ICON + TOOL_ICON_GAP) / 2, 0)
	button.icon = button:CreateTexture(nil, 'ARTWORK')
	button.icon:SetSize(Pixel.Scale(TOOL_ICON), Pixel.Scale(TOOL_ICON))
	button.icon:SetPoint('RIGHT', button.label, 'LEFT', -Pixel.Scale(TOOL_ICON_GAP), 0)
	if action.dynamic then
		button.icon:SetAtlas(CalendarAtlas())
	else
		button.icon:SetTexture(action.texture)
	end
	button.dot = button:CreateTexture(nil, 'OVERLAY')
	button.dot:SetSize(Pixel.Scale(DOT_SIZE), Pixel.Scale(DOT_SIZE))
	button.dot:SetPoint('TOPRIGHT', -Pixel.Scale(DOT_INSET), -Pixel.Scale(DOT_INSET))
	button.dot:Hide()
	button:SetScript('OnClick', BUI.Profiler.Script('Minimap.Menu tool OnClick', function(self)
		menu:Hide()
		self.action.onClick()
	end))
	return button
end

local function BuildToolPane()
	menu._toolRows = {}
	for actionIndex = 1, #toolActions do
		local row = CreateToolRow(toolActions[actionIndex])
		menu._toolRows[actionIndex] = row
		if toolActions[actionIndex].dynamic then menu.calendarRow = row end
	end
end

local function Repaint()
	menu.fill:SetVertexColor(BUI.ThemeColor('page'))
	menu.edge:SetVertexColor(BUI.ThemeColor('edge'))

	PaintText(menu.title, 'text', 'title', TITLE_SIZE)
	PaintText(menu.subtitle, 'muted', 'body', SUBTITLE_SIZE)
	menu.title:SetText(TITLE_TEXT)

	for _, row in pairs(sectionRows) do
		PaintText(row.label, 'text', 'title', LABEL_SIZE)
		row.label:SetText(row.text)
		PaintDropdown(row.dropdown)
	end

	for _, row in ipairs(menu._toolRows) do
		row.fill:SetColorTexture(BUI.ThemeColor('secondary'))
		PaintText(row.label, 'secondaryText', 'control', CONTROL_SIZE)
		row.label:SetText(row.action.label)
		if row.action.tint then
			row.icon:SetVertexColor(BUI.ThemeColor('secondaryText'))
		end
	end
end

local function BuildMenu()
	if menu then return menu end

	menu = CreateFrame('Frame', 'BUI_MinimapMenu', UIParent)
	menu.fill, menu.edge = Widget.DrawCardShape(menu, CARD_RADIUS, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
	menu:SetSize(Pixel.Scale(MENU_W), Pixel.Scale(200))
	menu:SetFrameStrata('DIALOG')
	menu:SetFrameLevel(100)
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	menu:Hide()
	table.insert(UISpecialFrames, 'BUI_MinimapMenu')

	local function MouseInside()
		return menu:IsMouseOver() or Controls.ContextMenuIsMouseOver()
	end

	local pressedOutside = false
	local function OnGlobalMouse(event)
		if event == 'GLOBAL_MOUSE_DOWN' then
			pressedOutside = not MouseInside()
		elseif event == 'GLOBAL_MOUSE_UP' and pressedOutside and not MouseInside() then
			menu:Hide()
		end
	end
	menu:SetScript('OnShow', BUI.Profiler.Wrap('Minimap.Menu menu shown', function()
		pressedOutside = false
		BUI.Events:Register('GLOBAL_MOUSE_DOWN', 'Minimap.Menu', OnGlobalMouse)
		BUI.Events:Register('GLOBAL_MOUSE_UP',   'Minimap.Menu', OnGlobalMouse)
		BUI.Events:Register('MINIMAP_UPDATE_TRACKING', 'Minimap.Menu', function()
			if menu:IsShown() then RefreshSelection() end
		end)
	end))
	menu:SetScript('OnHide', BUI.Profiler.Wrap('Minimap.Menu menu hidden', function()
		BUI.Events:UnregisterAll('Minimap.Menu')
	end))

	menu.title = menu:CreateFontString(nil, 'OVERLAY')
	menu.title:SetPoint('TOPLEFT', Pixel.Scale(PAD), Pixel.Scale(-PAD))
	menu.title:SetJustifyH('LEFT')

	menu.subtitle = menu:CreateFontString(nil, 'OVERLAY')
	menu.subtitle:SetPoint('TOPLEFT', menu.title, 'BOTTOMLEFT', 0, -Pixel.Scale(SUBTITLE_GAP))
	menu.subtitle:SetJustifyH('LEFT')

	for _, section in ipairs(SECTIONS) do BuildSectionRow(section) end

	BuildToolPane()
	return menu
end

local function PopulateTracking()
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
			row.items, row.indexes = bucket.items, bucket.indexes
			row.label:ClearAllPoints()
			row.label:SetPoint('LEFT', menu, 'TOPLEFT', Pixel.Scale(PAD), Pixel.Scale(-centerY))
			row.dropdown:ClearAllPoints()
			row.dropdown:SetPoint('RIGHT', menu, 'TOPRIGHT', Pixel.Scale(-PAD), Pixel.Scale(-centerY))
			row.dropdown.label:SetText(Summary(row))
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
	Repaint()
	RefreshSubtitle()
	menu.calendarRow.icon:SetAtlas(CalendarAtlas())
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
	minimap:SetScript('OnMouseUp', BUI.Profiler.Script('Minimap.Menu minimap OnMouseUp', function(self, button, ...)
		if button == 'RightButton' then
			Menu.Show()
		elseif button == 'MiddleButton' then
			OpenCalendar()
		elseif originalOnMouseUp then
			originalOnMouseUp(self, button, ...)
		end
	end))
end
