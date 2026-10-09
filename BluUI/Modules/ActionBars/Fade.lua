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

local function StopFader(fader)
	fader.playing = false
	fader.header:SetScript('OnUpdate', nil)
end

local function Fader(bar)
	local fader = bar.fader
	if fader then return fader end
	local header = bar.header
	fader = { header = header, from = 1, to = 1, start = 0, duration = 0, playing = false }
	fader.tick = BUI.Profiler.Script('ActionBars.Fade tween', function()
		local progress = (GetTime() - fader.start) / fader.duration
		if progress >= 1 then
			header:SetAlpha(fader.to)
			StopFader(fader)
			return
		end
		local eased = progress * progress * (3 - 2 * progress)
		header:SetAlpha(fader.from + (fader.to - fader.from) * eased)
	end)
	bar.fader = fader
	return fader
end

local function AtTarget(bar, target)
	if bar.fadeTarget ~= target then return false end
	local fader = bar.fader
	if fader and fader.playing and bar.header:IsShown() then return true end
	return math.abs(bar.header:GetAlpha() - target) < SETTLE
end

local function SetAlphaTarget(bar, target, seconds)
	if AtTarget(bar, target) then return end
	local header = bar.header
	local current = header:GetAlpha()
	bar.fadeTarget = target
	if bar.fader then StopFader(bar.fader) end
	if seconds <= 0 or math.abs(current - target) < SETTLE then
		header:SetAlpha(target)
		return
	end
	local fader = Fader(bar)
	fader.from, fader.to, fader.start, fader.duration, fader.playing = current, target, GetTime(), seconds, true
	header:SetScript('OnUpdate', fader.tick)
end

local function ApplyBar(bar)
	local barSettings = ActionBars.GetBarSettings(bar.key)
	if barSettings and barSettings.enabled then
		SetAlphaTarget(bar, TargetAlpha(bar, barSettings), barSettings.fadeDuration)
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
	if not bar.gapCheck then
		bar.gapCheck = BUI.Profiler.Wrap('ActionBars.Fade gap watch', function()
			if (bar.hoverCount or 0) > 0 then
				StopGapWatch(bar)
			elseif not CursorOverBar(bar) then
				StopGapWatch(bar)
				SetHovered(bar, false)
			end
		end)
	end
	bar.gapWatch = C_Timer.NewTicker(GAP_INTERVAL, bar.gapCheck)
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
	BUI.Profiler.After('ActionBars.Fade leave check', 0, function()
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
	frame:HookScript('OnEnter', BUI.Profiler.Wrap('ActionBars.Fade frame OnEnter', OnFrameEnter))
	frame:HookScript('OnLeave', BUI.Profiler.Wrap('ActionBars.Fade frame OnLeave', OnFrameLeave))
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
	button:HookScript('OnEnter', BUI.Profiler.Wrap('ActionBars.Fade button OnEnter', OnFlyoutButtonEnter))
	button:HookScript('OnLeave', BUI.Profiler.Wrap('ActionBars.Fade button OnLeave', OnFlyoutButtonLeave))
	local handler = LibActionButton.flyoutHandler
	if handler and not handler._buiFadeHooked then
		handler._buiFadeHooked = true
		handler:HookScript('OnHide', BUI.Profiler.Wrap('ActionBars.Fade flyout hide', OnFlyoutHidden))
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
		header:HookScript('OnShow', BUI.Profiler.Wrap('ActionBars.Fade header show', OnHeaderShown))
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

local function RefreshBarFade(bar)
	EnsureHooks(bar)
	local barSettings = ActionBars.GetBarSettings(bar.key)
	SyncHeaderMotion(bar, barSettings)
	if barSettings.enabled then
		if barSettings.fadeEnabled then
			bar.hovered = CursorOverBar(bar)
		else
			StopGapWatch(bar)
		end
		SetAlphaTarget(bar, TargetAlpha(bar, barSettings), barSettings.fadeDuration)
	end
end

function ActionBars.RefreshBarFade(key)
	local bar = ActionBars.bars[key]
	if bar then RefreshBarFade(bar) end
end

function ActionBars.RefreshFade()
	for _, bar in pairs(ActionBars.bars) do RefreshBarFade(bar) end
end

function ActionBars.SetBarContentHidden(bar, hidden)
	hidden = hidden and true or false
	if bar.contentHidden == hidden then return end
	bar.contentHidden = hidden
	ActionBars.ApplyBarMouse(bar)
	if bar.fader then StopFader(bar.fader) end
	bar.fadeTarget = nil
	local barSettings = ActionBars.GetBarSettings(bar.key)
	if barSettings and barSettings.enabled then
		SetAlphaTarget(bar, TargetAlpha(bar, barSettings), 0)
	end
	ActionBars.RefreshFade()
end

ActionBars.OnMoversChanged('fade', ActionBars.RefreshFade)
