local _, BUI = ...

local UnitFrames = BUI.UnitFrames
local Pixel = BUI.Pixel
local SetColorTex = BUI.Tools.SetColorTex
local TextSetting = UnitFrames.TextSetting

local function ApplyBarTexture(bar, texture)
	bar:SetStatusBarTexture(texture)
	bar:GetStatusBarTexture():SetTexCoord(0.01, 0.99, 0.01, 0.99)
end

function UnitFrames.ApplyBarTextures(frame, texture)
	ApplyBarTexture(frame.Health, texture)
	ApplyBarTexture(frame.Power, texture)
end

function UnitFrames.ApplyBackgroundColors(frame, bgColor, powerBgColor)
	local settings = UnitFrames.GetSettings()
	local background = frame.FrameBG
	SetColorTex(background, bgColor[1], bgColor[2], bgColor[3], settings.transparentHealth and 0 or bgColor[4])
	background:ClearAllPoints()
	local edge = Pixel.Scale(Pixel.ClampBorder(settings.borderSize))
	background:SetPoint('TOPLEFT', frame, 'TOPLEFT', edge, -edge)
	background:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -edge, edge)
	local color = powerBgColor or bgColor
	SetColorTex(frame.PowerBG, color[1], color[2], color[3], color[4])
end

local function ApplyAbsorbBar(frame, bar, direction, enabled)
	UnitFrames.AnchorAbsorb(bar, frame.Health, frame.Health:GetStatusBarTexture(), direction)
	bar:SetShown(enabled)
end

function UnitFrames.ApplyAbsorbStyles(frame, settings)
	local enabled = settings.shieldEnabled ~= false
	UnitFrames.ApplyAbsorbVisual(frame.Absorb, settings.shieldOverlay, settings.shieldColor)
	ApplyAbsorbBar(frame, frame.Absorb, settings.shieldDirection, enabled)
	UnitFrames.ApplyAbsorbVisual(frame.AbsorbBars.Overflow, settings.shieldOverlay, settings.shieldColor, 1)
	UnitFrames.SetAbsorbOverflow(frame, enabled and settings.shieldDirection == 'right')
end

function UnitFrames.ApplyHealAbsorbStyles(frame, settings)
	UnitFrames.ApplyAbsorbVisual(frame.HealAbsorb, settings.healAbsorbOverlay, settings.healAbsorbColor)
	ApplyAbsorbBar(frame, frame.HealAbsorb, settings.healAbsorbDirection, settings.healAbsorbEnabled ~= false)
end

function UnitFrames.ApplyHealthBarLayout(frame, height, showPower, powerHeight, borderSize)
	powerHeight = Pixel.Scale(powerHeight)
	local edge = Pixel.Scale(Pixel.ClampBorder(borderSize))
	local health = frame.Health

	health:ClearAllPoints()
	health:SetPoint('TOPLEFT', frame, 'TOPLEFT', edge, -edge)
	health:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -edge, -edge)

	if showPower then
		local healthHeight = height - (edge * 2) - powerHeight - edge
		health:SetHeight(healthHeight)

		local separatorY = -(edge + healthHeight)
		local separatorFrame = frame.PowerBorderFrame
		separatorFrame:SetHeight(edge)
		separatorFrame:ClearAllPoints()
		separatorFrame:SetPoint('TOPLEFT', frame, 'TOPLEFT', edge, separatorY)
		separatorFrame:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -edge, separatorY)
		separatorFrame:Show()
	else
		health:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -edge, edge)
	end

	local power = frame.Power
	power:ClearAllPoints()
	power:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', edge, edge)
	power:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -edge, edge)
	power:SetHeight(powerHeight)
end

local function ApplyTextPosition(textElement, parent, position, offsetX, offsetY)
	local point, relativePoint, marginX, marginY, justify = BUI.Tools.ResolvePlacement(position, 4, 1)

	textElement:ClearAllPoints()
	textElement:SetPoint(point, parent, relativePoint, Pixel.Scale(offsetX + marginX), Pixel.Scale(offsetY + marginY))
	textElement:SetJustifyH(justify)
end

function UnitFrames.FitNameWidth(frame)
	local parentWidth = frame.TextOverlay:GetWidth()
	if parentWidth > 0 then frame.Name:SetWidth(parentWidth - 8) end
end

function UnitFrames.ApplyTextStyles(frame, settings, unitSettings, unit)
	local font = UnitFrames.GetFont()
	local overlay = frame.TextOverlay

	local name = frame.Name
	Pixel.ApplyFont(name, TextSetting(unitSettings, 'nameTextSize'), font)
	name:SetShown(unitSettings.showName)
	ApplyTextPosition(name, overlay, TextSetting(unitSettings, 'namePosition'), TextSetting(unitSettings, 'nameOffsetX'), TextSetting(unitSettings, 'nameOffsetY'))
	UnitFrames.FitNameWidth(frame)
	if unitSettings.classColorName and UnitExists(unit) then
		name:SetTextColor(UnitFrames.GetNameColor(unit, unitSettings))
	else
		local color = settings.nameColor
		name:SetTextColor(color[1], color[2], color[3])
	end

	local healthText = frame.HealthText
	Pixel.ApplyFont(healthText, TextSetting(unitSettings, 'healthTextSize'), font)
	local healthTextColor = settings.healthTextColor
	healthText:SetTextColor(healthTextColor[1], healthTextColor[2], healthTextColor[3])
	ApplyTextPosition(healthText, overlay, TextSetting(unitSettings, 'healthPosition'), TextSetting(unitSettings, 'healthOffsetX'), TextSetting(unitSettings, 'healthOffsetY'))
	healthText:SetShown(unitSettings.showHealthText)

	Pixel.ApplyFont(frame.StatusText, TextSetting(unitSettings, 'statusTextSize'), font)
	ApplyTextPosition(frame.StatusText, overlay, TextSetting(unitSettings, 'statusPosition'), TextSetting(unitSettings, 'statusOffsetX'), TextSetting(unitSettings, 'statusOffsetY'))
	UnitFrames.RefreshStatusText(frame)

	local powerText = frame.PowerText
	Pixel.ApplyFont(powerText, TextSetting(unitSettings, 'powerTextSize'), font)
	local powerTextColor = settings.powerTextColor
	powerText:SetTextColor(powerTextColor[1], powerTextColor[2], powerTextColor[3])
	ApplyTextPosition(powerText, frame.Power, TextSetting(unitSettings, 'powerPosition'), TextSetting(unitSettings, 'powerOffsetX'), TextSetting(unitSettings, 'powerOffsetY'))
end

function UnitFrames.ApplyRaidIconPosition(frame, settings, unitSettings)
	local raidIcon = frame.RaidTargetIndicator
	local show = settings.raidIconMode ~= 'off' and not unitSettings.hideRaidIcon

	raidIcon._buiHidden = not show
	raidIcon:SnapSize(settings.raidIconSize)
	raidIcon:ClearAllPoints()
	raidIcon:SetPoint('CENTER', frame, settings.raidIconPosition,
		Pixel.Scale(settings.raidIconOffsetX), Pixel.Scale(settings.raidIconOffsetY))

	if not show then raidIcon:Hide() end
end

local function PlaceGroupIcon(frame, element, settings, hidden)
	local size = Pixel.Scale(settings.leaderIconSize)
	local anchor = settings.leaderIconPosition
	element:SetSize(size, size)
	element:ClearAllPoints()
	element:SetPoint(anchor, frame, anchor, Pixel.Scale(settings.leaderIconOffsetX), Pixel.Scale(settings.leaderIconOffsetY))
	element._buiHidden = hidden
	if hidden then
		element:Hide()
	else
		element:ForceUpdate()
	end
end

function UnitFrames.ApplyLeaderIconPosition(frame, settings)
	local hidden = settings.leaderIconEnabled == false
	PlaceGroupIcon(frame, frame.LeaderIndicator, settings, hidden)
	PlaceGroupIcon(frame, frame.AssistantIndicator, settings, hidden)
end

function UnitFrames.ApplyLevelTextStyles(frame, settings, unitSettings)
	local levelText = frame.LevelText
	local position = settings.levelPosition

	Pixel.ApplyFont(levelText, settings.levelTextSize, UnitFrames.GetFont())
	levelText:ClearAllPoints()

	local justify = 'CENTER'
	if position:find('LEFT') then justify = 'LEFT'
	elseif position:find('RIGHT') then justify = 'RIGHT' end
	levelText:SetJustifyH(justify)

	levelText:SetPoint(position, frame, position, Pixel.Scale(settings.levelOffsetX), Pixel.Scale(settings.levelOffsetY))
	levelText:SetShown(settings.showLevel and not unitSettings.hideLevel)
end

function UnitFrames.UpdateLevelTextVisibility(frame, unitType)
	frame.LevelText:SetShown(UnitFrames.GetSettings().showLevel and not UnitFrames.GetUnitSettings(unitType).hideLevel)
end
