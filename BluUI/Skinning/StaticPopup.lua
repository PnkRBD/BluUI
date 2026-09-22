local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('StaticPopup')

local hooksecurefunc = BUI.Prof.MakeHooker('staticpopup')
local select = select

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SKIN_ID = 'staticpopup'
local SCALE_KEY = 'staticpopupScale'
local DIALOG_COUNT = 4
local GLOW_INSET = 2
local GLOW_THICKNESS = 2
local RESURRECT_DIALOGS = { RESURRECT = true, RESURRECT_NO_SICKNESS = true, RESURRECT_NO_TIMER = true }
local BUTTON_KEYS = { 'button1', 'button2', 'button3', 'button4', 'extraButton' }
local BUTTON_SUFFIXES = { 'Button1', 'Button2', 'Button3', 'Button4', 'ExtraButton' }

local installed = false
local fadedArt = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local function CurrentScale()
	return BUI.GetDB().skinning[SCALE_KEY]
end

local function FadeTextures(frame)
	if not frame or not frame.GetRegions then return end
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region and region.IsObjectType and region:IsObjectType('Texture') and not region.__buiSkin then
			fadedArt[region] = true
			region:SetAlpha(0)
		end
	end
end

local function Child(dialog, key, suffix)
	local name = dialog:GetName()
	return dialog[key] or (name and _G[name .. suffix])
end

local function DialogButtons(dialog)
	local buttons = {}
	for keyIndex = 1, #BUTTON_KEYS do
		local button = Child(dialog, BUTTON_KEYS[keyIndex], BUTTON_SUFFIXES[keyIndex])
		if button then buttons[#buttons + 1] = button end
	end
	return buttons
end

local function DialogText(dialog)
	return Child(dialog, 'text', 'Text')
end

local function EnsureAcceptGlow(button)
	local glow = button._buiAcceptGlow
	if glow then return glow end
	glow = CreateFrame('Frame', nil, button)
	glow:SetPoint('TOPLEFT', button, 'TOPLEFT', -GLOW_INSET, GLOW_INSET)
	glow:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', GLOW_INSET, -GLOW_INSET)
	glow:SetFrameLevel(button:GetFrameLevel() + 2)
	local edges = {}
	for edgeIndex = 1, 4 do
		edges[edgeIndex] = glow:CreateTexture(nil, 'OVERLAY')
		edges[edgeIndex].__buiSkin = true
	end
	edges[1]:SetPoint('TOPLEFT'); edges[1]:SetPoint('TOPRIGHT'); edges[1]:SetHeight(GLOW_THICKNESS)
	edges[2]:SetPoint('BOTTOMLEFT'); edges[2]:SetPoint('BOTTOMRIGHT'); edges[2]:SetHeight(GLOW_THICKNESS)
	edges[3]:SetPoint('TOPLEFT'); edges[3]:SetPoint('BOTTOMLEFT'); edges[3]:SetWidth(GLOW_THICKNESS)
	edges[4]:SetPoint('TOPRIGHT'); edges[4]:SetPoint('BOTTOMRIGHT'); edges[4]:SetWidth(GLOW_THICKNESS)
	glow.edges = edges
	local pulse = glow:CreateAnimationGroup()
	pulse:SetLooping('BOUNCE')
	local fade = pulse:CreateAnimation('Alpha')
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.15)
	fade:SetDuration(0.6)
	fade:SetSmoothing('IN_OUT')
	glow.pulse = pulse
	glow:Hide()
	button._buiAcceptGlow = glow
	return glow
end

local function StopAcceptGlow(dialog)
	local button = Child(dialog, 'button1', 'Button1')
	local glow = button and button._buiAcceptGlow
	if not glow then return end
	glow.pulse:Stop()
	glow:Hide()
end

local function UpdateAcceptGlow(dialog)
	if not Enabled() or not RESURRECT_DIALOGS[dialog.which] or not dialog:IsShown() then
		StopAcceptGlow(dialog)
		return
	end
	local button = Child(dialog, 'button1', 'Button1')
	if not button then return end
	local glow = EnsureAcceptGlow(button)
	local red, green, blue = BUILib.Theme.GetAccent()
	for edgeIndex = 1, 4 do glow.edges[edgeIndex]:SetColorTexture(red, green, blue, 1) end
	glow:Show()
	if not glow.pulse:IsPlaying() then glow.pulse:Play() end
end

local function Apply(dialog)
	if not Enabled() or not dialog or dialog:IsForbidden() then return end
	if not dialog._buiStaticPopup then
		dialog._buiStaticPopup = true
		FadeTextures(dialog)
		FadeTextures(dialog.Border)
		if dialog.BG then dialog.BG:SetAlpha(0) end
		if dialog.NineSlice then dialog.NineSlice:SetAlpha(0) end
	end
	local scale = CurrentScale()
	Skin.TipShell(dialog)
	Skin.TipFont(DialogText(dialog), 'body', scale)
	local buttons = DialogButtons(dialog)
	for buttonIndex = 1, #buttons do
		Skin.TipButton(buttons[buttonIndex], scale)
	end
	UpdateAcceptGlow(dialog)
end

local function ApplyShown()
	for dialogIndex = 1, DIALOG_COUNT do
		local dialog = _G['StaticPopup' .. dialogIndex]
		if dialog and dialog:IsShown() then Apply(dialog) end
	end
end

local function Install()
	if installed then return end
	installed = true
	for dialogIndex = 1, DIALOG_COUNT do
		local dialog = _G['StaticPopup' .. dialogIndex]
		if dialog then
			HookScript(dialog, 'OnShow', Apply)
			HookScript(dialog, 'OnHide', StopAcceptGlow)
		end
	end
	ApplyShown()
end

local function Deactivate()
	for region in pairs(fadedArt) do region:SetAlpha(1) end
	for dialogIndex = 1, DIALOG_COUNT do
		local dialog = _G['StaticPopup' .. dialogIndex]
		if dialog and dialog._buiStaticPopup then
			StopAcceptGlow(dialog)
			if dialog.BG then dialog.BG:SetAlpha(1) end
			if dialog.NineSlice then dialog.NineSlice:SetAlpha(1) end
			Skin.HideTipShell(dialog)
		end
	end
	BUI.Print('Popup skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		ApplyShown()
	else
		Deactivate()
	end
end)

StaticPopupDialogs['BUI_SKIN_TEST'] = {
	text = 'Skin preview. This is how Blizzard popups look with the BluUI skin on.',
	button1 = 'Looks Good',
	button2 = 'Close',
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

Skin.RegisterSkin(SKIN_ID, {
	name = 'Popups',
	description = 'Resurrect, release, confirm and other Blizzard popup dialogs drawn like the BluUI tooltip.',
	icon = 'Interface/Icons/INV_Misc_Note_02',
	settingsHeight = 240,
	test = function()
		return StaticPopup_Show('BUI_SKIN_TEST')
	end,
	stopTest = function()
		StaticPopup_Hide('BUI_SKIN_TEST')
	end,
	buildSettings = function(content)
		Skin.TipScaleCard(content, SCALE_KEY, ApplyShown)
	end,
})
