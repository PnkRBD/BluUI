local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('Calendar')

local hooksecurefunc = BUI.Prof.MakeHooker('calendar')
local ipairs = ipairs

local Skin = BUI.Skinning

local SKIN_ID = 'calendar'
local FRAME_ART_NAMES = {
	'TopLeftTexture', 'TopMiddleTexture', 'TopRightTexture', 'LeftTopTexture', 'LeftMiddleTexture', 'LeftBottomTexture',
	'RightTopTexture', 'RightMiddleTexture', 'RightBottomTexture', 'BottomLeftTexture', 'BottomMiddleTexture', 'BottomRightTexture',
}
local WEEKDAY_COUNT = 7
local DAY_BUTTON_COUNT = 42
local DAY_INSET = 1
local DAY_HOVER_ALPHA = 0.15
local MONTH_SCALE = 1.3
local EVENT_FRAME_NAMES = { 'CalendarViewEventFrame', 'CalendarViewHolidayFrame', 'CalendarViewRaidFrame', 'CalendarCreateEventFrame' }
local EVENT_BUTTON_NAMES = {
	'CalendarViewEventAcceptButton', 'CalendarViewEventTentativeButton', 'CalendarViewEventDeclineButton', 'CalendarViewEventRemoveButton',
	'CalendarCreateEventCreateButton', 'CalendarCreateEventMassInviteButton', 'CalendarCreateEventInviteButton', 'CalendarCreateEventRaidInviteButton',
}
local EVENT_CLOSE_NAMES = { 'CalendarViewEventCloseButton', 'CalendarViewHolidayCloseButton', 'CalendarViewRaidCloseButton', 'CalendarCreateEventCloseButton' }
local EVENT_TITLE_NAMES = { 'CalendarViewEventTitle' }
local EVENT_BODY_NAMES = {
	'CalendarViewEventCommunityName', 'CalendarViewEventTypeName', 'CalendarViewEventCreatorName', 'CalendarViewEventDateLabel', 'CalendarViewEventTimeLabel',
	'CalendarCreateEventCommunityName', 'CalendarCreateEventTextureName', 'CalendarCreateEventCreatorName', 'CalendarCreateEventDateLabel',
}
local BACKDROP_FRAME_NAMES = { 'CalendarViewEventDescriptionContainer', 'CalendarViewEventInviteList', 'CalendarCreateEventDescriptionContainer', 'CalendarCreateEventInviteList' }

local installed = false
local skinned = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions = context.Fade, context.FadeRegions
local Shell, Button, Close, Dropdown, ScrollBar, Body, Title = context.Shell, context.Button, context.Close, context.Dropdown, context.ScrollBar, context.Body, context.Title
local AccentTexture = Skin.AccentTexture

local function SkinDayButton(dayIndex)
	local button = _G['CalendarDayButton' .. dayIndex]
	if not button then return end
	local name = button:GetName()
	Fade(button:GetNormalTexture())
	local highlight = button:GetHighlightTexture()
	if highlight then
		highlight:SetBlendMode('BLEND')
		AccentTexture(highlight, DAY_HOVER_ALPHA)
	end
	Shell(button, DAY_INSET)
	Fade(_G[name .. 'DateFrameBackground'])
	Skin.TipFace(_G[name .. 'DateFrameDate'], 'body')
end

local function OnDayEventButton(button)
	if not Enabled() or not button then return end
	local name = button:GetName()
	Skin.TipFace(name and _G[name .. 'Text1'], 'body')
	Skin.TipFace(name and _G[name .. 'Text2'], 'body')
end

local function SkinBackdropFrame(frame)
	if not frame then return end
	FadeRegions(frame)
	Fade(frame.NineSlice)
	Shell(frame)
	ScrollBar(frame.ScrollBar)
end

local function SkinEventFrame(frame)
	if not frame then return end
	Skin.FadeTree(frame.Border)
	Shell(frame)
	if frame.Header then
		FadeRegions(frame.Header)
		Title(frame.Header.Text)
	end
end

local function SkinEventFrames()
	for _, name in ipairs(EVENT_FRAME_NAMES) do SkinEventFrame(_G[name]) end
	for _, name in ipairs(EVENT_BUTTON_NAMES) do Button(_G[name]) end
	for _, name in ipairs(EVENT_CLOSE_NAMES) do Close(_G[name]) end
	for _, name in ipairs(EVENT_TITLE_NAMES) do Title(_G[name]) end
	for _, name in ipairs(EVENT_BODY_NAMES) do Body(_G[name]) end
	for _, name in ipairs(BACKDROP_FRAME_NAMES) do SkinBackdropFrame(_G[name]) end
end

local function SkinMainFrame(frame)
	for _, key in ipairs(FRAME_ART_NAMES) do Fade(_G['CalendarFrame' .. key]) end
	Shell(frame)
	for weekday = 1, WEEKDAY_COUNT do
		Fade(_G['CalendarWeekday' .. weekday .. 'Background'])
		Skin.TipFont(_G['CalendarWeekday' .. weekday .. 'Name'], 'label')
	end
	Fade(_G.CalendarMonthBackground)
	Fade(_G.CalendarYearBackground)
	Skin.TipFont(_G.CalendarMonthName, 'title', MONTH_SCALE)
	Skin.TipFont(_G.CalendarYearName, 'label')
	Skin.TipPageButton(_G.CalendarPrevMonthButton, 'previous')
	Skin.TipPageButton(_G.CalendarNextMonthButton, 'next')
	Dropdown(frame.FilterButton)
	Close(_G.CalendarCloseButton)
	for dayIndex = 1, DAY_BUTTON_COUNT do SkinDayButton(dayIndex) end
	SkinEventFrames()
end

local function Apply()
	local frame = _G.CalendarFrame
	if not frame or frame:IsForbidden() or not Enabled() or skinned then return end
	skinned = true
	SkinMainFrame(frame)
end

local function Install()
	if installed then return end
	local frame = _G.CalendarFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	if _G.CalendarDayEventButton_OnLoad then hooksecurefunc('CalendarDayEventButton_OnLoad', OnDayEventButton) end
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Calendar') end
end

local function Deactivate()
	context.Restore()
	skinned = false
	BUI.Print('Calendar skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.Calendar', TryInstall)
		elseif _G.CalendarFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Calendar',
	description = 'The calendar: dark month grid with accent day highlights, house arrows and filter, and dark event dialogs.',
	icon = 'Interface/Icons/INV_Misc_Note_02',
})
