local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local SCALE_KEY = 'staticpopupScale'
local DIALOG_COUNT = 4
local GLOW_LOW_ALPHA = 0.15
local GLOW_PULSE_SECONDS = 0.6
local RESURRECT_DIALOGS = { RESURRECT = true, RESURRECT_NO_SICKNESS = true, RESURRECT_NO_TIMER = true }
local BUTTON_KEYS = { 'Button1', 'Button2', 'Button3', 'Button4' }

local context = Skin.Define('staticpopup', {
	name = 'Popups',
	description = 'Resurrect, release, confirm and other Blizzard popup dialogs drawn like the BluUI tooltip.',
	icon = 'Interface/Icons/INV_Misc_Note_02',
})
local Fade, FadeRegions, Shell, Button = context.Fade, context.FadeRegions, context.Shell, context.Button

local function CurrentScale()
	return BUI.GetDB().skinning[SCALE_KEY]
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
	button:HookScript('OnLeave', KeepAcceptEdges)
	return pulse
end

local function StopAcceptGlow(dialog)
	local button = dialog.ButtonContainer.Button1
	local pulse = button._buiAcceptPulse
	if not pulse or not pulse:IsPlaying() then return end
	pulse:Stop()
	Skin.TipShellEdges(button, false)
end

local function UpdateAcceptGlow(dialog)
	if not RESURRECT_DIALOGS[dialog.which] then
		StopAcceptGlow(dialog)
		return
	end
	local button = dialog.ButtonContainer.Button1
	Skin.TipShellEdges(button, true)
	local pulse = EnsureAcceptPulse(button)
	if not pulse:IsPlaying() then pulse:Play() end
end

local function ScaledButton(button, scale)
	Button(button)
	Skin.TipButtonFonts(button, scale)
end

local function SkinDialog(dialog)
	FadeRegions(dialog)
	Fade(dialog.BG)
end

local function RefreshDialog(dialog)
	local scale = CurrentScale()
	Shell(dialog)
	Skin.TipFont(dialog.Text, 'body', scale)
	local container = dialog.ButtonContainer
	for _, key in ipairs(BUTTON_KEYS) do ScaledButton(container[key], scale) end
	ScaledButton(dialog.ExtraButton, scale)
	UpdateAcceptGlow(dialog)
end

local function ApplyShown()
	if not context.Enabled() then return end
	for dialogIndex = 1, DIALOG_COUNT do
		local dialog = _G['StaticPopup' .. dialogIndex]
		if dialog:IsShown() then RefreshDialog(dialog) end
	end
end

local function InstallDialog(dialog)
	dialog:HookScript('OnHide', StopAcceptGlow)
end

for dialogIndex = 1, DIALOG_COUNT do
	context.Window('StaticPopup' .. dialogIndex, { skin = SkinDialog, show = RefreshDialog, install = InstallDialog })
end

context.OnDisable(function()
	for dialogIndex = 1, DIALOG_COUNT do StopAcceptGlow(_G['StaticPopup' .. dialogIndex]) end
end)

context.info.settings = { Skin.ScaleOption(SCALE_KEY, ApplyShown) }
