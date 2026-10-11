local _, BUI = ...

local ipairs = ipairs
local ceil = math.ceil

local Skin = BUI.Skinning
local Pixel = BUI.Pixel
local Painter = BUI.Painter

local HOVER_ALPHA = 0.15
local PRESS_ALPHA = 0.25
local SELECTED_ALPHA = 0.2
local TIMER_Y = -12
local BLIZZARD_BAR_WIDTH = 337
local TIMER_LINE_INSET, TIMER_LINE_HEIGHT = 1, 3
local XP_EDGE = -1
local INSTRUCTION_SCALE = 4 / 3
local PET_CARD_INSET = { left = 13, right = 10, top = 152, bottom = 6 }
local BAR_FRAME_KEYS = { 'FlowFrame', 'Delimiter', 'MicroButtonFrame' }
local TIMER_ART = { 'TimerBG', 'ArtFrame', 'ArtFrame2' }
local PET_CARD_ART = { 'Framing', 'SelectedTexture', 'MouseoverHighlight' }
local FIXED_BUTTON_KEYS = { 'SwitchPetButton', 'CatchButton', 'ForfeitButton' }

local context = Skin.Define('petBattle', {
	name = 'Pet Battle',
	description = 'The pet battle bar with square buttons, a white turn timer, a flat XP bar and pet picker cards.',
	icon = 'Interface/Icons/INV_Pet_BattlePetTraining',
	newLook = true,
})
local Fade, FadeKeys, FadeRegions = context.Fade, context.FadeKeys, context.FadeRegions
local Shell, Title, Body = context.Shell, context.Title, context.Body

local timerBox

local function EvenWidth(frame)
	frame:SetWidth(ceil(frame:GetWidth() / 2) * 2)
end

local function Overlay(texture, button)
	texture:SetBlendMode('BLEND')
	texture:ClearAllPoints()
	texture:SetAllPoints(button)
	return texture
end

local function SkinActionButton(button)
	if not button._buiPetButton then
		button._buiPetButton = true
		Skin.CropIcon(button.Icon)
		Skin.FlatTexture(Overlay(button:GetHighlightTexture(), button), 1, 1, 1, HOVER_ALPHA)
		Skin.FlatTexture(Overlay(button:GetPushedTexture(), button), 1, 1, 1, PRESS_ALPHA)
		Skin.SelectedTexture(Overlay(button.SelectedHighlight, button), SELECTED_ALPHA)
	end
	Fade(button.NormalTexture)
	Fade(button.CooldownShadow)
	local settings = BUI.ActionBars.GetSettings()
	local color = settings.borderColor
	Pixel.ApplyBorder(button, settings.borderSize, color[1], color[2], color[3], color[4])
end

local function ForEachActionButton(bottom, callback)
	for _, button in ipairs(bottom.abilityButtons) do callback(button) end
	for _, key in ipairs(FIXED_BUTTON_KEYS) do callback(bottom[key]) end
end

local function SkinBar(bottom)
	local switch = bottom.SwitchPetButton
	FadeRegions(bottom)
	for _, key in ipairs(BAR_FRAME_KEYS) do FadeRegions(bottom[key]) end
	Skin.SelectedTexture(Overlay(switch:GetCheckedTexture(), switch), SELECTED_ALPHA)
	ForEachActionButton(bottom, SkinActionButton)
	Skin.TipFont(bottom.FlowFrame.SelectPetInstruction, 'title', INSTRUCTION_SCALE)
end

local function SkinTimer(timer)
	local bar, text = timer.Bar, timer.TimerText
	FadeKeys(timer, TIMER_ART)
	timer:SetPoint('CENTER', timer:GetParent(), 'TOP', 0, TIMER_Y)
	EvenWidth(timer)
	context.Button(timer.SkipButton)
	Shell(timerBox)
	bar:ClearAllPoints()
	bar:SetPoint('BOTTOMLEFT', timerBox, 'BOTTOMLEFT', TIMER_LINE_INSET, TIMER_LINE_INSET)
	bar:SetHeight(TIMER_LINE_HEIGHT)
	Painter.Fill(bar, 'skinTitle')
	text:ClearAllPoints()
	text:SetPoint('CENTER', timerBox)
	Body(text)
end

local function SkinXPBar(bar)
	bar:SetStatusBarTexture(BUI.GetGlobalTexture())
	bar:GetStatusBarTexture().__buiSkin = true
	FadeRegions(bar)
	Shell(bar, XP_EDGE)
	Skin.TipCount(bar.TextString)
end

local function SyncPetCard(unit)
	if unit._buiPetCard then Skin.SetActiveEdge(unit, unit.SelectedTexture:IsShown()) end
end

local function SkinPetCard(button)
	local dead = button.DeadOverlay
	button._buiPetCard = true
	FadeKeys(button, PET_CARD_ART)
	context.Card(button, PET_CARD_INSET)
	dead:ClearAllPoints()
	dead:SetPoint('TOPLEFT', PET_CARD_INSET.left, -PET_CARD_INSET.top)
	dead:SetPoint('BOTTOMRIGHT', -PET_CARD_INSET.right, PET_CARD_INSET.bottom)
	Title(button.Name)
	Skin.TipCount(button.Level)
	Skin.TipCount(button.HealthText)
	SyncPetCard(button)
end

local function SkinFrame(frame)
	local bottom = frame.BottomFrame
	SkinBar(bottom)
	SkinTimer(bottom.TurnTimer)
	SkinXPBar(bottom.xpBar)
	local selection = bottom.PetSelectionFrame
	for index = 1, NUM_BATTLE_PETS_IN_BATTLE do SkinPetCard(selection['Pet' .. index]) end
end

local function SyncTimer(frame)
	timerBox:SetShown(frame.BottomFrame.TurnTimer.TimerBG:IsShown())
end

local function OnActionBarLayout(frame)
	local bottom = frame.BottomFrame
	EvenWidth(bottom)
	ForEachActionButton(bottom, SkinActionButton)
end

local function BuildTimerBox(timer)
	local skip = timer.SkipButton
	local box = context.Own(CreateFrame('Frame', nil, timer:GetParent()))
	box:SetPoint('TOPLEFT', skip, 'TOPRIGHT', Skin.CONTROL_GAP, 0)
	box:SetPoint('BOTTOMLEFT', skip, 'BOTTOMRIGHT', Skin.CONTROL_GAP, 0)
	box:SetWidth(BLIZZARD_BAR_WIDTH + TIMER_LINE_INSET * 2)
	local track = box:CreateTexture(nil, 'ARTWORK')
	track:SetPoint('BOTTOMLEFT', TIMER_LINE_INSET, TIMER_LINE_INSET)
	track:SetPoint('BOTTOMRIGHT', -TIMER_LINE_INSET, TIMER_LINE_INSET)
	track:SetHeight(TIMER_LINE_HEIGHT)
	Painter.Fill(track, 'skinLine')
	return box
end

local function InstallFrame(frame)
	timerBox = BuildTimerBox(frame.BottomFrame.TurnTimer)
	context.Hook('PetBattleFrame_UpdateActionBarLayout', OnActionBarLayout)
	context.Hook('PetBattleFrame_UpdatePassButtonAndTimer', SyncTimer)
	context.Hook('PetBattleUnitFrame_UpdateDisplay', SyncPetCard)
end

context.Window('PetBattleFrame', { skin = SkinFrame, show = SyncTimer, install = InstallFrame })

context.OnDisable(function()
	if timerBox then ForEachActionButton(_G.PetBattleFrame.BottomFrame, Pixel.HideBorder) end
end)
