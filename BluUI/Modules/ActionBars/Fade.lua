local _, BUI = ...

local ActionBars = BUI.ActionBars
local LibActionButton = LibStub('LibActionButton-1.0-BluUI')

local GAP_INTERVAL = 0.1
local SETTLE = 0.01

local function TargetAlpha(bar, barSettings)
	if ActionBars.BarUnlocked(bar.key) or ActionBars.KeybindModeActive() then return 1 end
	if bar.contentHidden then return 0 end
	local alpha = barSettings.alpha / 100
	if barSettings.fadeEnabled and not bar.hovered then
		alpha = alpha * barSettings.fadeAlpha / 100
	end
	return alpha
end

local function FadeSeconds(barSettings)
	if not barSettings.fadeAnimated then return 0 end
	return barSettings.fadeDuration
end

local function Fader(bar)
	local fader = bar.fader
	if fader then return fader end
	local group = bar.header:CreateAnimationGroup()
	group:SetToFinalAlpha(true)
	local alpha = group:CreateAnimation('Alpha')
	alpha:SetSmoothing('IN_OUT')
	fader = { group = group, alpha = alpha, from = 1, to = 1 }
	bar.fader = fader
	return fader
end

local function VisibleAlpha(bar)
	local fader = bar.fader
	if fader and fader.group:IsPlaying() then
		return fader.from + (fader.to - fader.from) * fader.alpha:GetSmoothProgress()
	end
	return bar.header:GetAlpha()
end

local function AtTarget(bar, target)
	if bar.fadeTarget ~= target then return false end
	local fader = bar.fader
	if fader and fader.group:IsPlaying() and bar.header:IsShown() then return true end
	return math.abs(bar.header:GetAlpha() - target) < SETTLE
end

local function SetAlphaTarget(bar, target, seconds)
	if AtTarget(bar, target) then return end
	local current = VisibleAlpha(bar)
	bar.fadeTarget = target
	if bar.fader then bar.fader.group:Stop() end
	local header = bar.header
	if seconds <= 0 or math.abs(current - target) < SETTLE then
		header:SetAlpha(target)
		return
	end
	header:SetAlpha(current)
	local fader = Fader(bar)
	fader.from, fader.to = current, target
	fader.alpha:SetFromAlpha(current)
	fader.alpha:SetToAlpha(target)
	fader.alpha:SetDuration(seconds)
	fader.group:Play()
end

local function ApplyBar(bar)
	local barSettings = ActionBars.GetBarSettings(bar.key)
	if barSettings and barSettings.enabled then
		SetAlphaTarget(bar, TargetAlpha(bar, barSettings), FadeSeconds(barSettings))
	end
end

local function FlyoutOwner()
	local handler = LibActionButton.flyoutHandler
	if handler and handler:IsShown() then return handler:GetParent(), handler end
	if SpellFlyout and SpellFlyout:IsShown() then return SpellFlyout:GetParent(), SpellFlyout end
	return nil
end

local function FlyoutBar()
	local owner, flyout = FlyoutOwner()
	local bar = owner and owner._buiFadeBar
	return bar, flyout
end

local function CursorOverBar(bar)
	if bar.header:IsMouseOver() then return true end
	local flyoutBar, flyout = FlyoutBar()
	return flyoutBar == bar and flyout:IsMouseOver()
end

local function SetHovered(bar, hovered)
	if bar.hovered == hovered then return end
	bar.hovered = hovered
	ApplyBar(bar)
end

local function StopGapWatch(bar)
	if bar.gapWatch then
		bar.gapWatch:Cancel()
		bar.gapWatch = nil
	end
end

local function StartGapWatch(bar)
	if bar.gapWatch then return end
	bar.gapWatch = C_Timer.NewTicker(GAP_INTERVAL, function()
		if (bar.hoverCount or 0) > 0 then
			StopGapWatch(bar)
		elseif not CursorOverBar(bar) then
			StopGapWatch(bar)
			SetHovered(bar, false)
		end
	end)
end

local function Enter(bar)
	if not bar then return end
	bar.hoverCount = (bar.hoverCount or 0) + 1
	StopGapWatch(bar)
	SetHovered(bar, true)
end

local function Leave(bar)
	if not bar then return end
	bar.hoverCount = math.max(0, (bar.hoverCount or 0) - 1)
	if bar.hoverCount > 0 or bar.leavePending then return end
	bar.leavePending = true
	C_Timer.After(0, function()
		bar.leavePending = nil
		if bar.hoverCount > 0 then return end
		if CursorOverBar(bar) then
			StartGapWatch(bar)
		else
			SetHovered(bar, false)
		end
	end)
end

local function OnFrameEnter(frame) Enter(frame._buiFadeBar) end
local function OnFrameLeave(frame) Leave(frame._buiFadeBar) end
local function OnFlyoutButtonEnter() Enter((FlyoutBar())) end
local function OnFlyoutButtonLeave() Leave((FlyoutBar())) end

local function OnFlyoutHidden(flyout)
	local owner = flyout:GetParent()
	local bar = owner and owner._buiFadeBar
	if bar and bar.hovered and (bar.hoverCount or 0) == 0 and not bar.header:IsMouseOver() then
		SetHovered(bar, false)
	end
end

local function HookHoverFrame(frame, bar)
	frame._buiFadeBar = bar
	if frame._buiFadeHooked then return end
	frame._buiFadeHooked = true
	frame:HookScript('OnEnter', OnFrameEnter)
	frame:HookScript('OnLeave', OnFrameLeave)
end

function ActionBars.HookFadeFrames(bar, frames)
	if not bar then return end
	for _, frame in ipairs(frames) do
		HookHoverFrame(frame, bar)
	end
end

local function HookFlyoutButton(button)
	if button._buiFadeHooked then return end
	button._buiFadeHooked = true
	button:HookScript('OnEnter', OnFlyoutButtonEnter)
	button:HookScript('OnLeave', OnFlyoutButtonLeave)
	local handler = LibActionButton.flyoutHandler
	if handler and not handler._buiFadeHooked then
		handler._buiFadeHooked = true
		handler:HookScript('OnHide', OnFlyoutHidden)
	end
end

local flyoutOwner = {}
LibActionButton.RegisterCallback(flyoutOwner, 'OnFlyoutButtonCreated', function(_, button) HookFlyoutButton(button) end)

local function OnHeaderShown(header)
	local bar = header._buiFadeBar
	if bar then ApplyBar(bar) end
end

local function EnsureHooks(bar)
	local header = bar.header
	if not header._buiFadeHooked then
		header:HookScript('OnShow', OnHeaderShown)
	end
	HookHoverFrame(header, bar)
	for _, button in ipairs(bar.buttons) do HookHoverFrame(button, bar) end
	for _, button in ipairs(LibActionButton.FlyoutButtons) do HookFlyoutButton(button) end
end

local motionRefreshQueued = false
local function SyncHeaderMotion(bar, barSettings)
	local header = bar.header
	local wanted = (barSettings.enabled and barSettings.fadeEnabled) and true or false
	if bar.headerMotion == wanted then return end
	if InCombatLockdown() and header:IsProtected() then
		if not motionRefreshQueued then
			motionRefreshQueued = true
			BUI.Events:AfterCombat(function()
				motionRefreshQueued = false
				ActionBars.RefreshFade()
			end, 'ActionBars.FadeMotion')
		end
		return
	end
	bar.headerMotion = wanted
	header:SetMouseMotionEnabled(wanted)
end

function ActionBars.RefreshFade()
	for _, bar in pairs(ActionBars.bars) do
		EnsureHooks(bar)
		local barSettings = ActionBars.GetBarSettings(bar.key)
		SyncHeaderMotion(bar, barSettings)
		if barSettings.enabled then
			if barSettings.fadeEnabled then
				bar.hovered = CursorOverBar(bar)
			else
				StopGapWatch(bar)
			end
			SetAlphaTarget(bar, TargetAlpha(bar, barSettings), FadeSeconds(barSettings))
		end
	end
end

function ActionBars.SetBarContentHidden(bar, hidden)
	hidden = hidden and true or false
	if bar.contentHidden == hidden then return end
	bar.contentHidden = hidden
	ActionBars.ApplyBarMouse(bar)
	if bar.fader then bar.fader.group:Stop() end
	bar.fadeTarget = nil
	local barSettings = ActionBars.GetBarSettings(bar.key)
	if barSettings and barSettings.enabled then
		SetAlphaTarget(bar, TargetAlpha(bar, barSettings), 0)
	end
	ActionBars.RefreshFade()
end

ActionBars.OnMoversChanged('fade', ActionBars.RefreshFade)
