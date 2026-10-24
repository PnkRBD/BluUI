local _, BUI = ...

local ceil = math.ceil

local Skin = BUI.Skinning
local SELECTED_COLOR, MUTED_COLOR = Skin.SELECTED_COLOR, Skin.MUTED_COLOR

local ANCHOR_KEY = 'bonusroll'
local HOLD_SETTING = 'bonusrollHoldToRoll'
local HOLD_SECONDS = 3
local HOLD_LABEL = ('Hold the dice for %d seconds to roll'):format(HOLD_SECONDS)
local HOLD_TIP = HOLD_LABEL .. '. Let go to cancel.'
local HINTS = {
	idle = { text = 'HOLD TO ROLL', role = 'skinLabel' },
	holding = { text = 'KEEP HOLDING', role = 'skinTitle' },
	warn = { text = 'HOLD TO ROLL', role = 'danger' },
}
local HINT_SCALE = 0.8
local HINT_WARN_SECONDS = 0.8
local COUNT_SCALE = 1.5
local SWEEP_ALPHA = 0.3
local TIMER_INSET, TIMER_HEIGHT = 1, 3
local SPEC_EDGE = 1
local FRAME_ART = { 'Background', 'LootSpinnerBG', 'IconBorder', 'SpecRing' }

local context = Skin.Define('bonusroll', {
	name = 'Bonus Roll',
	description = 'The bonus roll prompt in the dark shell with a framed icon, a white timer and an optional hold-to-roll on the dice.',
	icon = 'Interface/Icons/INV_Misc_Coin_19',
	newLook = true,
	unlock = {
		tooltip = 'Unlock position. Drag the bonus roll window, then click again to lock.',
		get = function() return Skin.ToastAnchors.IsUnlocked(ANCHOR_KEY) end,
		set = function(value) Skin.ToastAnchors.SetUnlocked(ANCHOR_KEY, value) end,
	},
})
local Fade, FadeKeys, Shell, Title, Body = context.Fade, context.FadeKeys, context.Shell, context.Title, context.Body
local CropIcon = Skin.CropIcon

local rollButton, rollClick, specIcon, hint, sweep
local holding = false
local holdElapsed, holdSecond = 0, 0

local function HoldEnabled()
	return context.Enabled() and BUI.GetDB().skinning[HOLD_SETTING] ~= false
end

local function SetHint(state)
	local entry = HINTS[state]
	hint:SetShown(entry ~= nil)
	if not entry then return end
	hint:SetText(entry.text)
	BUI.Painter.Text(hint, entry.role)
end

local function RefreshHint()
	if not holding then SetHint(HoldEnabled() and 'idle') end
end

local function ResetHold()
	holding = false
	rollButton:SetScript('OnUpdate', nil)
	sweep:Clear()
	sweep:Hide()
end

local OnHoldUpdate = function(button, elapsed)
	holdElapsed = holdElapsed + elapsed
	local remaining = HOLD_SECONDS - holdElapsed
	if remaining <= 0 then
		ResetHold()
		SetHint()
		rollClick(button, 'LeftButton')
		return
	end
	local second = ceil(remaining)
	if second == holdSecond then return end
	holdSecond = second
	sweep.count:SetFormattedText('%d', second)
end

local function OnRollMouseDown(button, mouseButton)
	if mouseButton ~= 'LeftButton' or not button:IsEnabled() or not HoldEnabled() then return end
	holding, holdElapsed, holdSecond = true, 0, HOLD_SECONDS
	sweep.count:SetFormattedText('%d', HOLD_SECONDS)
	sweep:Show()
	sweep:SetCooldown(GetTime(), HOLD_SECONDS)
	SetHint('holding')
	button:SetScript('OnUpdate', OnHoldUpdate)
end

local function OnRollMouseUp()
	if not holding then return end
	ResetHold()
	SetHint('warn')
	C_Timer.After(HINT_WARN_SECONDS, RefreshHint)
end

local function OnRollHide()
	if holding then ResetHold() end
end

local OnRollClick = function(button, ...)
	if not HoldEnabled() then rollClick(button, ...) end
end

local function OnRollEnter()
	if not HoldEnabled() then return end
	GameTooltip:AddLine(HOLD_TIP, MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3])
	GameTooltip:Show()
end

local function SyncSpecEdges()
	Skin.SetIconEdgeThickness(specIcon, specIcon:IsShown() and SPEC_EDGE or 0)
end

local function BuildHold(button)
	hint = button:GetParent():CreateFontString(nil, 'OVERLAY')
	Skin.TipFont(hint, 'label', HINT_SCALE)
	hint:SetPoint('TOP', button, 'BOTTOM', 0, -1)
	sweep = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
	sweep:SetDrawEdge(false)
	sweep:SetDrawBling(false)
	sweep:SetDrawSwipe(true)
	sweep:SetReverse(true)
	sweep:SetHideCountdownNumbers(true)
	sweep:SetSwipeColor(SELECTED_COLOR[1], SELECTED_COLOR[2], SELECTED_COLOR[3], SWEEP_ALPHA)
	sweep.count = sweep:CreateFontString(nil, 'OVERLAY')
	Skin.TipFont(sweep.count, 'title', COUNT_SCALE)
	sweep.count:SetPoint('CENTER')
end

local function SkinTimer(frame, timer)
	timer:ClearAllPoints()
	timer:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', TIMER_INSET, TIMER_INSET)
	timer:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -TIMER_INSET, TIMER_INSET)
	timer:SetHeight(TIMER_HEIGHT)
	timer:SetStatusBarTexture(BUI.GetGlobalTexture())
	timer:SetStatusBarColor(SELECTED_COLOR[1], SELECTED_COLOR[2], SELECTED_COLOR[3], 1)
end

local function SkinFrame(frame)
	local prompt, rolling = frame.PromptFrame, frame.RollingFrame
	FadeKeys(frame, FRAME_ART)
	Fade(frame.BlackBackgroundHoist.Background)
	Shell(frame)
	Skin.TipIconFrame(prompt, prompt.Icon)
	Skin.SquareIcon(frame, specIcon)
	SyncSpecEdges()
	Title(prompt.InfoFrame.Label)
	Body(prompt.InfoFrame.Cost)
	Skin.TipFont(frame.CurrentCountFrame.Text, 'label')
	Title(rolling.Label)
	Title(rolling.LootSpinnerFinalText)
	SkinTimer(frame, prompt.Timer)
end

local function RaiseTimer(frame)
	frame.PromptFrame.Timer:SetFrameLevel(frame:GetFrameLevel() + 1)
end

local function InstallFrame(frame)
	local prompt = frame.PromptFrame
	rollButton, specIcon = prompt.RollButton, frame.SpecIcon
	rollClick = rollButton:GetScript('OnClick')
	BuildHold(rollButton)
	rollButton:HookScript('OnMouseDown', OnRollMouseDown)
	rollButton:HookScript('OnMouseUp', OnRollMouseUp)
	rollButton:HookScript('OnEnter', OnRollEnter)
	rollButton:HookScript('OnShow', RefreshHint)
	rollButton:HookScript('OnHide', OnRollHide)
	context.Hook(prompt.Icon, 'SetTexture', CropIcon)
	context.Hook(specIcon, 'Show', SyncSpecEdges)
	context.Hook(specIcon, 'Hide', SyncSpecEdges)
end

local function EnableFrame()
	rollButton:SetScript('OnClick', OnRollClick)
	RefreshHint()
end

context.Window('BonusRollFrame', { skin = SkinFrame, show = RaiseTimer, install = InstallFrame, enable = EnableFrame })

context.OnDisable(function()
	if not rollButton then return end
	rollButton:SetScript('OnClick', rollClick)
	ResetHold()
	SetHint()
	Skin.SetIconEdgeThickness(specIcon, 0)
end)

Skin.ToastAnchors.Register({
	key = ANCHOR_KEY,
	label = 'BONUS ROLL',
	point = 'CENTER',
	sample = 'bonus',
	followFrame = true,
	defaultY = 340,
	frame = function() return _G.BonusRollFrame end,
	hooks = function(reapply) hooksecurefunc(BottomManagedFrameContainer, 'Layout', reapply) end,
})

context.info.settings = {
	{
		label = HOLD_LABEL,
		get = function() return BUI.GetDB().skinning[HOLD_SETTING] ~= false end,
		set = function(value)
			BUI.GetDB().skinning[HOLD_SETTING] = value
			if hint then RefreshHint() end
		end,
	},
}
