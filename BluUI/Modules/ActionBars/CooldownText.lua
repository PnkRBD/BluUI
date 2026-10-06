local _, BUI = ...

local ActionBars = BUI.ActionBars
local Pixel = BUI.Pixel

local function BarSettingsFor(button)
	return ActionBars.GetBarSettings(button._buiBar) or ActionBars.GetBarSettings(1)
end

function ActionBars.StyleCooldownText(button, cooldown)
	local barSettings = BarSettingsFor(button)
	cooldown:SetHideCountdownNumbers(not barSettings.showCooldownText)
	local region = BUI.Tools.CooldownFontString(cooldown)
	if not region then return end
	local fontReset = Pixel.ApplyFont(region, barSettings.cooldownFontSize, BUI.GetAddonFont(), 'OUTLINE')
	if cooldown._buiTextStyled and not fontReset then return end
	cooldown._buiTextStyled = true
	local settings = ActionBars.GetSettings()
	local color = settings.cooldownColor
	region:SetTextColor(color[1], color[2], color[3], color[4])
	local threshold = settings.cooldownThreshold
	local decimalThreshold = settings.showCooldownDecimals and settings.cooldownDecimalThreshold or 0
	cooldown:SetCountdownMillisecondsThreshold(decimalThreshold)
	local wantFormatter = threshold > 0 or decimalThreshold > 0
	if wantFormatter or cooldown._buiFormatter then
		cooldown._buiFormatter = wantFormatter or nil
		cooldown:SetCountdownFormatter(BUI.TimeFormat.GetFormatter(decimalThreshold, threshold, settings.cooldownThresholdColor))
	end
	local anchor = settings.cooldownAnchor
	region:ClearAllPoints()
	region:SetPoint(anchor, button, anchor, settings.cooldownOffsetX, settings.cooldownOffsetY)
	region:SetJustifyH(ActionBars.JustifyForAnchor(anchor))
	region:SetDrawLayer('OVERLAY', 7)
end

local function RefreshButtonCooldownText(button)
	local cooldown = button.cooldown
	if not cooldown then return end
	cooldown._buiTextStyled = nil
	cooldown._buiSwipeApplied = nil
	ActionBars.StyleCooldownText(button, cooldown)
end

function ActionBars.RefreshCooldownText()
	ActionBars.ForEachButton(RefreshButtonCooldownText)
end

function ActionBars.RefreshBarCooldownText(key)
	local bar = ActionBars.bars[key]
	if not bar then return end
	for _, button in ipairs(bar.buttons) do RefreshButtonCooldownText(button) end
end
