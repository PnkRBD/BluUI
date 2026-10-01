local _, BUI = ...

local select = select

local Skin = BUI.Skinning

local SKIN_ID = 'staticpopup'
local SCALE_KEY = 'staticpopupScale'
local DIALOG_COUNT = 4
local GLOW_LOW_ALPHA = 0.15
local GLOW_PULSE_SECONDS = 0.6
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

local function KeepAcceptEdges(button)
	if button._buiAcceptPulse:IsPlaying() then Skin.TipShellEdges(button, true) end
end

local function EnsureAcceptPulse(button)
	local pulse = button._buiAcceptPulse
	if pulse then return pulse end
	pulse = button:CreateAnimationGroup()
	pulse:SetLooping('BOUNCE')
	local edges = button._buiShell.edges
	for edgeIndex = 1, 4 do
		local fade = pulse:CreateAnimation('Alpha')
		fade:SetTarget(edges[edgeIndex])
		fade:SetFromAlpha(1)
		fade:SetToAlpha(GLOW_LOW_ALPHA)
		fade:SetDuration(GLOW_PULSE_SECONDS)
		fade:SetSmoothing('IN_OUT')
	end
	button._buiAcceptPulse = pulse
	button:HookScript('OnLeave', BUI.Profiler.Wrap('Skin.StaticPopup button OnLeave', KeepAcceptEdges))
	return pulse
end

local function StopAcceptGlow(dialog)
	local button = Child(dialog, 'button1', 'Button1')
	local pulse = button and button._buiAcceptPulse
	if not pulse or not pulse:IsPlaying() then return end
	pulse:Stop()
	Skin.TipShellEdges(button, false)
end

local function UpdateAcceptGlow(dialog)
	if not Enabled() or not RESURRECT_DIALOGS[dialog.which] or not dialog:IsShown() then
		StopAcceptGlow(dialog)
		return
	end
	local button = Child(dialog, 'button1', 'Button1')
	if not button then return end
	Skin.TipShellEdges(button, true)
	local pulse = EnsureAcceptPulse(button)
	if not pulse:IsPlaying() then pulse:Play() end
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
	local onShow = BUI.Profiler.Wrap('Skin.StaticPopup popup reskin', Apply)
	local onHide = BUI.Profiler.Wrap('Skin.StaticPopup glow stop', StopAcceptGlow)
	for dialogIndex = 1, DIALOG_COUNT do
		local dialog = _G['StaticPopup' .. dialogIndex]
		if dialog then
			dialog:HookScript('OnShow', onShow)
			dialog:HookScript('OnHide', onHide)
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
	buildSettings = function(content)
		Skin.TipScaleCard(content, SCALE_KEY, ApplyShown)
	end,
})
