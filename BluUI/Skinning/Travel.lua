local _, BUI = ...

local Skin = BUI.Skinning

local SKIN_ID = 'travel'
local ART_KEYS = { 'Border', 'BorderFrame', 'Background', 'BackgroundTile', 'NineSlice', 'Inset', 'PortraitContainer', 'TitleBg', 'Overlay' }
local WINDOW_NAMES = { 'TaxiFrame', 'FlightMapFrame' }
local FONT_DEPTH = 2

local skinnedWindows = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeArt, FadeKeys = context.Fade, context.FadeArt, context.FadeKeys
local Shell, Close, Title = context.Shell, context.Close, context.Title

local function SkinWindow(frame)
	if not frame or frame._buiTravel or frame:IsForbidden() then return end
	frame._buiTravel = true
	skinnedWindows[#skinnedWindows + 1] = frame
	FadeArt(frame)
	FadeKeys(frame, ART_KEYS)
	Fade(frame.portrait)
	Shell(frame)
	Close(frame.CloseButton)
	local borderFrame = frame.BorderFrame
	if borderFrame then
		FadeArt(borderFrame)
		FadeKeys(borderFrame, ART_KEYS)
		Close(borderFrame.CloseButton)
		Title(borderFrame.TitleText)
	end
	Skin.HideHelpButtons(frame)
	Skin.TipFaceTree(frame, FONT_DEPTH)
end

local function Apply()
	if not Enabled() then return end
	for index = 1, #WINDOW_NAMES do SkinWindow(_G[WINDOW_NAMES[index]]) end
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		for index = 1, #skinnedWindows do skinnedWindows[index]._buiTravel = nil end
		Apply()
	else
		context.Restore()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Flight Master',
	description = 'The taxi window at a flight master and the flight map.',
	icon = 'Interface/Icons/Ability_Mount_Gryphon_01',
})

BUI.Events:Register('ADDON_LOADED', 'Skin.Travel', Apply)
BUI.Events:Once('PLAYER_LOGIN', 'Skin.Travel', Apply)
BUI.Events:Register('TAXIMAP_OPENED', 'Skin.Travel', Apply)
