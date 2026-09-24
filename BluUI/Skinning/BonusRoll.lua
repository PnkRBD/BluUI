local _, BUI = ...


local Skin = BUI.Skinning
local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Layout = BUILib.Layout
local Theme = BUILib.Theme

local SKIN_ID = 'bonusroll'
local HOLD_SETTING = 'bonusrollHoldToRoll'
local HOLD_SECONDS = 3
local HINT_IDLE = 'HOLD TO ROLL'
local HINT_HOLDING = 'KEEP HOLDING'
local HINT_SCALE = 0.8
local HINT_IDLE_COLOR = { 0.55, 0.55, 0.6, 1 }
local HINT_WARN_COLOR = { 0.9, 0.35, 0.3, 1 }
local HINT_WARN_SECONDS = 0.8
local COUNT_SCALE = 1.5
local SWEEP_ALPHA = 0.55
local FRAME_ART = { 'Background', 'LootSpinnerBG', 'IconBorder' }

local skinned = false
local holdElapsed = 0
local originalRollClick

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local function HoldEnabled()
	return Enabled() and BUI.GetDB().skinning[HOLD_SETTING] ~= false
end

local context = Skin.NewContext(Enabled)
local Fade, FadeKeys, Shell, Body, Title = context.Fade, context.FadeKeys, context.Shell, context.Body, context.Title
local CropIcon = Skin.CropIcon

local function RollFrame(button)
	return button:GetParent():GetParent()
end

local function HoldHint(button)
	local hint = button._buiHoldHint
	if hint then return hint end
	hint = button:GetParent():CreateFontString(nil, 'OVERLAY')
	hint.__buiSkin = true
	Skin.TipFont(hint, 'label', HINT_SCALE)
	hint:SetPoint('TOP', button, 'BOTTOM', 0, -1)
	hint:SetText(HINT_IDLE)
	button._buiHoldHint = hint
	return hint
end

local function HoldSweep(button)
	local sweep = button._buiHoldSweep
	if sweep then return sweep end
	sweep = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
	sweep.__buiSkin = true
	sweep:SetAllPoints(button)
	sweep:SetFrameLevel(button:GetFrameLevel() + 2)
	sweep:SetDrawEdge(false)
	sweep:SetDrawBling(false)
	sweep:SetDrawSwipe(true)
	sweep:SetReverse(true)
	sweep:SetHideCountdownNumbers(true)
	sweep:EnableMouse(false)
	local red, green, blue = Theme.GetAccent()
	sweep:SetSwipeColor(red, green, blue, SWEEP_ALPHA)
	local count = sweep:CreateFontString(nil, 'OVERLAY')
	Skin.TipFont(count, 'title', COUNT_SCALE)
	count:SetPoint('CENTER')
	sweep.count = count
	sweep:Hide()
	button._buiHoldSweep = sweep
	return sweep
end

local function SetHint(button, state)
	local hint = HoldHint(button)
	if state == 'hidden' then
		hint:Hide()
		return
	end
	hint:Show()
	if state == 'holding' then
		local red, green, blue = Theme.GetAccent()
		hint:SetTextColor(red, green, blue, 1)
		hint:SetText(HINT_HOLDING)
	elseif state == 'warn' then
		hint:SetTextColor(HINT_WARN_COLOR[1], HINT_WARN_COLOR[2], HINT_WARN_COLOR[3], HINT_WARN_COLOR[4])
		hint:SetText(HINT_IDLE)
	else
		hint:SetTextColor(HINT_IDLE_COLOR[1], HINT_IDLE_COLOR[2], HINT_IDLE_COLOR[3], HINT_IDLE_COLOR[4])
		hint:SetText(HINT_IDLE)
	end
end

local function RefreshHint(button)
	if not button or button._buiHolding then return end
	SetHint(button, HoldEnabled() and 'idle' or 'hidden')
end

local function StopHold(button, completed)
	local wasHolding = button._buiHolding
	button._buiHolding = nil
	button:SetScript('OnUpdate', nil)
	holdElapsed = 0
	local sweep = button._buiHoldSweep
	if sweep then
		sweep:Clear()
		sweep:Hide()
	end
	if completed or not HoldEnabled() then
		SetHint(button, 'hidden')
	elseif wasHolding then
		SetHint(button, 'warn')
		C_Timer.After(HINT_WARN_SECONDS, function() RefreshHint(button) end)
	else
		SetHint(button, 'idle')
	end
end

local function CompleteRoll(button)
	AcceptSpellConfirmationPrompt(RollFrame(button).spellID)
	button:SetEnabled(false)
end

local function OnHoldUpdate(button, elapsed)
	holdElapsed = holdElapsed + elapsed
	local remaining = HOLD_SECONDS - holdElapsed
	local sweep = HoldSweep(button)
	sweep.count:SetText(tostring(math.max(1, math.ceil(remaining))))
	if remaining <= 0 then
		StopHold(button, true)
		CompleteRoll(button)
	end
end

local function OnRollMouseDown(button, mouseButton)
	if mouseButton ~= 'LeftButton' or not button:IsEnabled() or not HoldEnabled() then return end
	holdElapsed = 0
	button._buiHolding = true
	local sweep = HoldSweep(button)
	sweep.count:SetText(tostring(HOLD_SECONDS))
	sweep:Show()
	sweep:SetCooldown(GetTime(), HOLD_SECONDS)
	SetHint(button, 'holding')
	button:SetScript('OnUpdate', OnHoldUpdate)
end

local function OnRollMouseUp(button)
	if button._buiHolding then StopHold(button, false) end
end

local function OnRollHide(button)
	button._buiHolding = nil
	button:SetScript('OnUpdate', nil)
	holdElapsed = 0
	if button._buiHoldSweep then
		button._buiHoldSweep:Clear()
		button._buiHoldSweep:Hide()
	end
end

local function OnRollClick(button, mouseButton)
	if HoldEnabled() then return end
	if originalRollClick then originalRollClick(button, mouseButton) else CompleteRoll(button) end
end

local function OnRollEnter()
	if not HoldEnabled() then return end
	GameTooltip:AddLine(('Hold the dice for %d seconds to roll. Let go to cancel.'):format(HOLD_SECONDS), 0.55, 0.55, 0.6)
	GameTooltip:Show()
end

local function SkinTimer(timer)
	if not timer then return end
	timer:SetStatusBarTexture(BUI.GetGlobalTexture())
	local red, green, blue = Theme.GetAccent()
	timer:SetStatusBarColor(red, green, blue, 1)
	Shell(timer)
end

local function SkinRollButton(button)
	if not button then return end
	if button:GetScript('OnClick') ~= OnRollClick then
		originalRollClick = button:GetScript('OnClick')
		button:SetScript('OnClick', OnRollClick)
	end
	if button._buiRoll then return end
	button._buiRoll = true
	button:HookScript('OnMouseDown', OnRollMouseDown)
	button:HookScript('OnMouseUp', OnRollMouseUp)
	button:HookScript('OnEnter', OnRollEnter)
	button:HookScript('OnHide', OnRollHide)
	button:HookScript('OnShow', RefreshHint)
	RefreshHint(button)
end

local function Apply()
	local frame = _G.BonusRollFrame
	if not frame or not Enabled() or skinned then return end
	skinned = true
	FadeKeys(frame, FRAME_ART)
	if frame.BlackBackgroundHoist then Fade(frame.BlackBackgroundHoist.Background) end
	Shell(frame)
	local prompt = frame.PromptFrame
	if prompt then
		CropIcon(prompt.Icon)
		Skin.TipIconFrame(prompt, prompt.Icon)
		if prompt.InfoFrame then
			Title(prompt.InfoFrame.Label)
			Body(prompt.InfoFrame.Cost)
		end
		SkinTimer(prompt.Timer)
		SkinRollButton(prompt.RollButton)
	end
	if frame.CurrentCountFrame then Body(frame.CurrentCountFrame.Text) end
	if frame.RollingFrame then
		Title(frame.RollingFrame.Label)
		Title(frame.RollingFrame.LootSpinnerFinalText)
	end
end

local function Deactivate()
	context.Restore()
	skinned = false
	local frame = _G.BonusRollFrame
	local button = frame and frame.PromptFrame and frame.PromptFrame.RollButton
	if button and originalRollClick and button:GetScript('OnClick') == OnRollClick then button:SetScript('OnClick', originalRollClick) end
	if button then
		OnRollHide(button)
		if button._buiHoldHint then button._buiHoldHint:Hide() end
	end
end

local function AnchorHooks(reapply)
	if _G.UIParent_ManageFramePositions then hooksecurefunc('UIParent_ManageFramePositions', reapply) end
	local alertFrame = _G.AlertFrame
	if alertFrame and alertFrame.UpdateAnchors then hooksecurefunc(alertFrame, 'UpdateAnchors', reapply) end
end

Skin.ToastAnchors.Register({
	key = 'bonusroll',
	label = 'BONUS ROLL',
	point = 'CENTER',
	sample = 'bonus',
	followFrame = true,
	defaultY = 340,
	frame = function() return _G.BonusRollFrame end,
	hooks = AnchorHooks,
})

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then Apply() else Deactivate() end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Bonus Roll',
	description = 'The bonus roll prompt in the dark shell with an accent timer, and an optional hold-to-roll on the dice button.',
	icon = 'Interface/Icons/INV_Misc_Coin_19',
	buildSettings = function(content)
		local db = BUI.GetDB()
		local panel = Layout.SettingsCard(content, { title = 'Rolling' })
		Layout.Toggle(panel, ('Hold the dice for %d seconds to roll'):format(HOLD_SECONDS), db.skinning[HOLD_SETTING] ~= false, function(value)
			db.skinning[HOLD_SETTING] = value
			local frame = _G.BonusRollFrame
			RefreshHint(frame and frame.PromptFrame and frame.PromptFrame.RollButton)
		end)
	end,
	unlock = {
		tooltip = 'Unlock position. Drag the bonus roll window, then click again to lock.',
		get = function() return Skin.ToastAnchors.IsUnlocked('bonusroll') end,
		set = function(value) Skin.ToastAnchors.SetUnlocked('bonusroll', value) end,
	},
})

BUI.Events:Once('PLAYER_LOGIN', 'Skin.BonusRoll', Apply)
