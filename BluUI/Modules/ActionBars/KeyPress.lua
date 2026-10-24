local _, BUI = ...

local ActionBars = BUI.ActionBars

local pairs = pairs

local TAP_SECONDS = 0.12

local running = false
local held = {}

local function Release(button)
	held[button] = nil
	if button:GetButtonState() == 'PUSHED' then button:SetButtonState('NORMAL') end
end

local function Tap(button)
	button:SetButtonState('PUSHED')
	BUI.Tools.ReplaceTimer(button, '_buiTapTimer', TAP_SECONDS, Release, button)
end

local OnPostClick = function(button, _, down)
	if not running then return end
	if down then
		held[button] = true
		if button:GetButtonState() == 'NORMAL' then button:SetButtonState('PUSHED') end
	elseif held[button] then
		Release(button)
	elseif not button:IsMouseOver() then
		Tap(button)
	end
end

function ActionBars.TrackKeyPresses(button)
	button:HookScript('PostClick', OnPostClick)
end

function ActionBars.RefreshKeyPress()
	running = BUI.IsModuleEnabled('actionBars') and ActionBars.GetSettings().showKeyPresses == true
	if running then return end
	for button in pairs(held) do Release(button) end
end
