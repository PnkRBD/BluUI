local _, BUI = ...

local Skin = BUI.Skinning

local FONT_DEPTH = 2

local context = Skin.Define('travel', {
	name = 'Flight Master',
	description = 'The taxi window at a flight master and the flight map.',
	icon = 'Interface/Icons/Ability_Mount_Gryphon_01',
})
local Fade, FadeArt = context.Fade, context.FadeArt
local Shell, Close = context.Shell, context.Close

local function SkinTaxi(frame)
	Skin.TipFaceTree(frame, FONT_DEPTH)
	context.Chrome(frame)
end

local function SkinFlightMap(frame)
	Skin.TipFaceTree(frame, FONT_DEPTH)
	Shell(frame)
	local border = frame.BorderFrame
	FadeArt(border)
	Fade(border.PortraitContainer.portrait)
	Skin.LeftTitle(border)
	Close(border.CloseButton)
end

context.Window('TaxiFrame', { skin = SkinTaxi })
context.Window('FlightMapFrame', { skin = SkinFlightMap })
