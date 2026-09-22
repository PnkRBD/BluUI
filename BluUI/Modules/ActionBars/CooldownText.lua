local _, BUI = ...

local ActionBars = BUI.ActionBars
local Pixel = BUI.Pixel

local function BarSettingsFor(button)
	return ActionBars.GetBarSettings(button._buiBar) or ActionBars.GetBarSettings(1)
end

local function CountdownRegion(cooldown)
	local region = cooldown._buiCountdown
	if region then return region end
	for index = 1, select('#', cooldown:GetRegions()) do
		local candidate = select(index, cooldown:GetRegions())
		if candidate:GetObjectType() == 'FontString' then
			cooldown._buiCountdown = candidate
			return candidate
		end
	end
	return nil
end

function ActionBars.StyleCooldownText(button)
	local cooldown = button.cooldown
	if not cooldown then return end
	local barSettings = BarSettingsFor(button)
	cooldown:SetHideCountdownNumbers(not barSettings.showCooldownText)
	local region = CountdownRegion(cooldown)
	if not region then return end
	local settings = ActionBars.GetSettings()
	Pixel.ApplyFont(region, barSettings.cooldownFontSize, BUI.GetAddonFont(), 'OUTLINE')
	local color = settings.cooldownColor
	region:SetTextColor(color[1], color[2], color[3], color[4])
	local threshold = settings.cooldownThreshold
	if threshold > 0 or cooldown._buiFormatter then
		cooldown._buiFormatter = threshold > 0 or nil
		cooldown:SetCountdownFormatter(BUI.TimeFormat.GetFormatter(0, threshold, settings.cooldownThresholdColor))
	end
	local anchor = settings.cooldownAnchor
	region:ClearAllPoints()
	region:SetPoint(anchor, button, anchor, settings.cooldownOffsetX, settings.cooldownOffsetY)
	region:SetJustifyH(ActionBars.JustifyForAnchor(anchor))
	region:SetDrawLayer('OVERLAY', 7)
end

function ActionBars.RefreshCooldownText()
	ActionBars.ForEachButton(ActionBars.StyleCooldownText)
end
