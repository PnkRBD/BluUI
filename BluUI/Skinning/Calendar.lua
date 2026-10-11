local _, BUI = ...

local ipairs, pairs = ipairs, pairs

local Skin = BUI.Skinning

local DAY_COUNT = 42
local WEEKDAY_COUNT = 7
local EVENTS_PER_DAY = 4
local DAY_INSET = 2
local ART_INSET = DAY_INSET + 1
local DAY_WASH_ALPHA = 0.12
local EVENT_WASH_ALPHA = 0.1
local DIM_ALPHA = 0.6
local MONTH_SCALE = 1.3
local HEADER_MIDDLE = -23
local HEADER_GAP = 6
local TITLE_X = 14
local CLOSE_X = -6
local DIALOG_TITLE_X, DIALOG_TITLE_Y = 16, -10
local FRAME_INSETS = { bottom = -8 }
local DIALOGS = { 'CalendarViewHolidayFrame', 'CalendarViewRaidFrame', 'CalendarViewEventFrame', 'CalendarCreateEventFrame', 'CalendarMassInviteFrame', 'CalendarEventPickerFrame', 'CalendarTexturePickerFrame' }
local PANELS = { 'CalendarViewEventDescriptionContainer', 'CalendarViewEventInviteList', 'CalendarCreateEventDescriptionContainer', 'CalendarCreateEventInviteList' }
local INVITE_LISTS = { 'CalendarViewEventInviteList', 'CalendarCreateEventInviteList' }
local PICKERS = { 'CalendarEventPickerFrame', 'CalendarTexturePickerFrame' }
local SCROLLING_TEXTS = { 'CalendarViewHolidayFrame', 'CalendarViewRaidFrame', 'CalendarViewEventDescriptionContainer' }
local DIALOG_ART = { 'CalendarViewEventDivider', 'CalendarCreateEventDivider', 'CalendarCreateEventFrameButtonBackground', 'CalendarEventPickerFrameButtonBackground', 'CalendarTexturePickerFrameButtonBackground' }
local DIALOG_BUTTONS = {
	'CalendarViewEventAcceptButton', 'CalendarViewEventTentativeButton', 'CalendarViewEventDeclineButton', 'CalendarViewEventRemoveButton',
	'CalendarCreateEventCreateButton', 'CalendarCreateEventMassInviteButton', 'CalendarCreateEventInviteButton', 'CalendarCreateEventRaidInviteButton',
	'CalendarMassInviteAcceptButton', 'CalendarEventPickerCloseButton', 'CalendarTexturePickerAcceptButton', 'CalendarTexturePickerCancelButton',
}
local DIALOG_CLOSES = { 'CalendarViewEventCloseButton', 'CalendarViewHolidayCloseButton', 'CalendarViewRaidCloseButton', 'CalendarCreateEventCloseButton', 'CalendarMassInviteCloseButton' }
local EDIT_BOXES = { 'CalendarCreateEventTitleEdit', 'CalendarCreateEventInviteEdit', 'CalendarMassInviteMinLevelEdit', 'CalendarMassInviteMaxLevelEdit' }
local CHECKS = { 'CalendarCreateEventAutoApproveCheck', 'CalendarCreateEventLockEventCheck' }
local DROPDOWNS = {
	CalendarCreateEventFrame = { 'EventTypeDropdown', 'HourDropdown', 'MinuteDropdown', 'AMPMDropdown', 'DifficultyOptionDropdown', 'CommunityDropdown' },
	CalendarMassInviteFrame = { 'CommunityDropdown', 'RankDropdown' },
}
local DIALOG_TEXTS = {
	'CalendarViewEventCommunityName', 'CalendarViewEventTypeName', 'CalendarViewEventCreatorName', 'CalendarViewEventDateLabel', 'CalendarViewEventTimeLabel',
	'CalendarCreateEventCommunityName', 'CalendarCreateEventTextureName', 'CalendarCreateEventCreatorName', 'CalendarCreateEventDateLabel',
	'CalendarMassInviteLevelText', 'CalendarMassInviteRankText',
}
local ROW_SETUPS = { 'CalendarEventInviteList_InitButtonShared', 'CalendarEventPickerFrame_InitButton', 'CalendarTexturePicker_InitButton' }

local context = Skin.Define('calendar', {
	name = 'Calendar',
	description = 'The calendar: dark month grid with card days, house arrows and filter, and dark event dialogs.',
	icon = 'Interface/Icons/INV_Misc_Note_02',
	newLook = true,
})
local Hook = context.Hook
local Fade, FadeRegions = context.Fade, context.FadeRegions
local Shell, Button, Close, Card, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Card, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Face, Title, Body = context.ScrollBar, context.Face, context.Title, context.Body

local days = {}
local selectedButton, todayButton

local function Place(region, point, relativeTo, relativePoint, x, y)
	region:ClearAllPoints()
	region:SetPoint(point, relativeTo, relativePoint, x, y)
end

local function FitCell(region, button)
	region:ClearAllPoints()
	region:SetPoint('TOPLEFT', button, 'TOPLEFT', ART_INSET, -ART_INSET)
	region:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -ART_INSET, ART_INSET)
end

local function MarkDay(button, marked)
	if button then Skin.SetActiveEdge(button, marked) end
end

local function RefreshMarks()
	MarkDay(selectedButton, false)
	MarkDay(todayButton, false)
	selectedButton = _G.CalendarWeekdaySelectedTexture:IsShown() and _G.CalendarFrame.selectedDayButton
	todayButton = _G.CalendarTodayFrame:IsShown() and _G.CalendarTodayFrame:GetParent()
	MarkDay(selectedButton, true)
	MarkDay(todayButton, true)
end

local function SkinRow(button)
	if button._buiCalendarRow then return end
	button._buiCalendarRow = true
	Skin.RowHighlight(button)
	Skin.TipFaceTree(button, 1)
end

local function SkinEventButton(button)
	local name = button:GetName()
	Face(_G[name .. 'Text1'])
	Face(_G[name .. 'Text2'])
	Skin.RowHighlight(button, EVENT_WASH_ALPHA)
	Skin.SelectedTexture(button.black, EVENT_WASH_ALPHA)
end

local function SkinDay(button)
	local name = button:GetName()
	Fade(button:GetNormalTexture())
	Fade(_G[name .. 'DarkFrameTop'])
	Fade(_G[name .. 'DarkFrameBottom'])
	Card(button, DAY_INSET)
end

local function SkinDialog(dialog)
	FadeRegions(dialog.Border)
	FadeRegions(dialog.Header)
	Shell(dialog)
	Title(dialog.Header.Text)
	Place(dialog.Header.Text, 'TOPLEFT', dialog, 'TOPLEFT', DIALOG_TITLE_X, DIALOG_TITLE_Y)
end

local function SkinPanel(panel)
	Fade(panel.NineSlice)
	Shell(panel)
	ScrollBar(panel.ScrollBar)
end

local function SkinDialogs()
	for _, name in ipairs(DIALOGS) do SkinDialog(_G[name]) end
	for _, name in ipairs(PANELS) do SkinPanel(_G[name]) end
	for _, name in ipairs(PICKERS) do ScrollBar(_G[name].ScrollBar) end
	for _, name in ipairs(DIALOG_ART) do Fade(_G[name]) end
	for _, name in ipairs(DIALOG_BUTTONS) do Button(_G[name]) end
	for _, name in ipairs(DIALOG_CLOSES) do Close(_G[name]) end
	for _, name in ipairs(EDIT_BOXES) do EditBox(_G[name]) end
	for _, name in ipairs(CHECKS) do CheckBox(_G[name]) end
	for _, name in ipairs(DIALOG_TEXTS) do Face(_G[name]) end
	for _, name in ipairs(SCROLLING_TEXTS) do Face(_G[name].ScrollingFont:GetFontString()) end
	for name, keys in pairs(DROPDOWNS) do
		for _, key in ipairs(keys) do Dropdown(_G[name][key]) end
	end
	for _, name in ipairs(INVITE_LISTS) do
		for _, sortButton in pairs(_G[name].sortButtons) do Skin.TipButtonFonts(sortButton) end
	end
	Title(_G.CalendarViewEventTitle)
end

local function SkinFrame(frame)
	FadeRegions(frame)
	Fade(_G.CalendarLastDayDarkTexture)
	Fade(_G.CalendarTodayFrame)
	Shell(frame, FRAME_INSETS)
	Skin.TipFont(_G.CalendarMonthName, 'title', MONTH_SCALE)
	Skin.TipFont(_G.CalendarYearName, 'label')
	for weekday = 1, WEEKDAY_COUNT do Skin.TipFont(_G['CalendarWeekday' .. weekday .. 'Name'], 'label') end
	Close(_G.CalendarCloseButton)
	context.TextDropdown(frame.FilterButton, true)
	Skin.TipStepper(_G.CalendarPrevMonthButton, 'previous')
	Skin.TipStepper(_G.CalendarNextMonthButton, 'next')
	for _, button in ipairs(days) do SkinDay(button) end
	SkinDialogs()
	RefreshMarks()
end

local function PlaceHeader(frame)
	local month, close, filter = _G.CalendarMonthName, _G.CalendarCloseButton, frame.FilterButton
	Place(month, 'LEFT', frame, 'TOPLEFT', TITLE_X, HEADER_MIDDLE)
	Place(_G.CalendarYearName, 'BOTTOMLEFT', month, 'BOTTOMRIGHT', HEADER_GAP, 0)
	Place(close, 'RIGHT', frame, 'TOPRIGHT', CLOSE_X, HEADER_MIDDLE)
	Place(filter, 'RIGHT', close, 'LEFT', -HEADER_GAP, 0)
	Place(_G.CalendarNextMonthButton, 'RIGHT', filter, 'LEFT', -HEADER_GAP, 0)
	Place(_G.CalendarPrevMonthButton, 'RIGHT', _G.CalendarNextMonthButton, 'LEFT', 0, 0)
end

local function BuildDay(button)
	local name = button:GetName()
	local dim = context.Own(_G[name .. 'DarkFrame']:CreateTexture(nil, 'OVERLAY'))
	BUI.Painter.Fill(dim, 'skinBackground')
	dim:SetAlpha(DIM_ALPHA)
	FitCell(dim, button)
	FitCell(button:GetHighlightTexture(), button)
	FitCell(_G[name .. 'EventTexture'], button)
	FitCell(_G[name .. 'OverlayFrame'], button)
	_G[name .. 'EventBackgroundTexture']:SetWidth(button:GetWidth() - ART_INSET * 2)
	Skin.RowHighlight(button, DAY_WASH_ALPHA)
	Body(_G[name .. 'DateFrameDate'])
	Skin.TipPageButton(_G[name .. 'MoreEventsButton'], 'down')
	for index = 1, EVENTS_PER_DAY do SkinEventButton(_G[name .. 'EventButton' .. index]) end
end

local function InstallFrame(frame)
	PlaceHeader(frame)
	for index = 1, DAY_COUNT do
		days[index] = _G['CalendarDayButton' .. index]
		BuildDay(days[index])
	end
	Hook('CalendarFrame_Update', RefreshMarks)
	Hook('CalendarDayButton_Click', RefreshMarks)
	for _, name in ipairs(ROW_SETUPS) do Hook(name, SkinRow) end
end

context.Window('CalendarFrame', { skin = SkinFrame, install = InstallFrame })
