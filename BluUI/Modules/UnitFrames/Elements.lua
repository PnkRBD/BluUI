local _, BUI = ...

local UnitFrames = BUI.UnitFrames
local Pixel = BUI.Pixel

local CreateFrame = CreateFrame

function UnitFrames.ApplyBarTextures(frame, texture)
	local tint = BUI.GetGradientTint()
	local red, green, blue, alpha = 1, 1, 1, 1
	if tint then red, green, blue, alpha = tint[1], tint[2], tint[3], tint[4] or 1 end

	for _, bar in ipairs({frame.Health, frame.Power}) do
		if bar then
			bar:SetStatusBarTexture(texture)
			local barTexture = bar:GetStatusBarTexture()
			if barTexture then
				barTexture:SetTexCoord(0.01, 0.99, 0.01, 0.99)
				if tint then barTexture:SetVertexColor(red, green, blue, alpha) end
			end
		end
	end
end

function UnitFrames.ApplyBackgroundColors(frame, bgColor, powerBgColor)
	if not bgColor or not bgColor[1] then return end
	local settings = UnitFrames.GetSettings()

	frame._transparentHealth = settings.transparentHealth
	if frame.FrameBG then
		local bgAlpha = frame._transparentHealth and 0 or (bgColor[4] or 1)
		BUI.Tools.SetColorTex(frame.FrameBG, bgColor[1], bgColor[2], bgColor[3], bgAlpha)
		frame.FrameBG:ClearAllPoints()
		local edge = Pixel.Scale(Pixel.ClampBorder(settings.borderSize))
		frame.FrameBG:SetPoint('TOPLEFT', frame, 'TOPLEFT', edge, -edge)
		frame.FrameBG:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -edge, edge)
	end
	if frame.PowerBG then
		local color = powerBgColor or bgColor
		BUI.Tools.SetColorTex(frame.PowerBG, color[1], color[2], color[3], color[4] or 1)
	end
end

local function ApplyAbsorbBar(frame, bar, healthKey, direction, enabled)
	if not frame.Health then return end
	UnitFrames.AnchorAbsorb(bar, frame.Health, frame.Health:GetStatusBarTexture(), direction)
	if enabled then
		frame.Health[healthKey] = bar
		bar:Show()
	else
		frame.Health[healthKey] = nil
		bar:Hide()
	end
end

function UnitFrames.ApplyAbsorbStyles(frame, settings)
	if not frame.Absorb then return end
	UnitFrames.ApplyAbsorbVisual(frame.Absorb, UnitFrames.BuildAbsorbCfg(settings))
	ApplyAbsorbBar(frame, frame.Absorb, 'DamageAbsorb', settings.shieldDirection, settings.shieldEnabled ~= false)
end

function UnitFrames.ApplyHealAbsorbStyles(frame, settings)
	if not frame.HealAbsorb then return end
	UnitFrames.ApplyHealAbsorbVisual(frame.HealAbsorb, UnitFrames.BuildHealAbsorbCfg(settings))
	ApplyAbsorbBar(frame, frame.HealAbsorb, 'HealAbsorb', settings.healAbsorbDirection, settings.healAbsorbEnabled ~= false)
end

function UnitFrames.ApplyHealthBarLayout(frame, height, showPower, powerHeight, borderSize)
	if not frame.Health then return end

	powerHeight = Pixel.Scale(powerHeight or 0)
	local edge = borderSize and Pixel.Scale(Pixel.ClampBorder(borderSize)) or Pixel.GetBorderSize(frame)

	frame.Health:ClearAllPoints()
	frame.Health:SetPoint('TOPLEFT', frame, 'TOPLEFT', edge, -edge)
	frame.Health:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -edge, -edge)

	if showPower then
		local healthHeight = height - (edge * 2) - powerHeight - edge
		frame.Health:SetHeight(healthHeight)

		if not frame.PowerBorderFrame and frame.Power then
			local separatorFrame = CreateFrame('Frame', nil, frame)
			separatorFrame:SetFrameLevel(frame.Power:GetFrameLevel() + 5)
			local separator = separatorFrame:CreateTexture(nil, 'OVERLAY', nil, 7)
			separator:SetAllPoints()
			local borderColor = frame._edgeRGBA or {0, 0, 0, 1}
			BUI.Tools.SetColorTex(separator, borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
			frame.PowerBorder = separator
			frame.PowerBorderFrame = separatorFrame
		end

		if frame.PowerBorderFrame then
			local separatorY = -(edge + (height - (edge * 2) - powerHeight - edge))
			frame.PowerBorderFrame:SetHeight(edge)
			frame.PowerBorderFrame:ClearAllPoints()
			frame.PowerBorderFrame:SetPoint('TOPLEFT', frame, 'TOPLEFT', edge, separatorY)
			frame.PowerBorderFrame:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -edge, separatorY)
			frame.PowerBorderFrame:Show()
			if frame.PowerBorder and frame._edgeRGBA then
				local borderColor = frame._edgeRGBA
				BUI.Tools.SetColorTex(frame.PowerBorder, borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
			end
		end
	else
		frame.Health:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -edge, edge)
	end

	if frame.Power then
		frame.Power:ClearAllPoints()
		frame.Power:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', edge, edge)
		frame.Power:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -edge, edge)
		frame.Power:SetHeight(powerHeight)
	end
end

function UnitFrames.ApplyTextPosition(textElement, parent, position, offsetX, offsetY)
	if not textElement then return end

	local point, relativePoint, marginX, marginY, justify = BUI.Tools.ResolvePlacement(position, 4, 1)

	textElement:ClearAllPoints()
	textElement:SetPoint(point, parent, relativePoint,
		Pixel.Scale((offsetX or 0) + marginX), Pixel.Scale((offsetY or 0) + marginY))
	textElement:SetJustifyH(justify)
end

function UnitFrames.ApplyTextStyles(frame, width, settings, unitSettings, unit)
	local font = UnitFrames.GetFont()
	local function PositiveOr(value, fallback) return (type(value) == 'number' and value > 0) and value or fallback end
	local textSize = PositiveOr(unitSettings.textSize, 12)
	local nameTextSize = PositiveOr(unitSettings.nameTextSize, textSize)
	local healthTextSize = PositiveOr(unitSettings.healthTextSize, textSize)
	local powerTextSize = PositiveOr(unitSettings.powerTextSize, textSize - 2)

	if frame.Name then
		Pixel.ApplyFont(frame.Name, nameTextSize, font)

		local showName = unitSettings.showName
		if showName == nil then showName = settings.showName ~= false end
		frame.Name:SetShown(showName)

		UnitFrames.ApplyTextPosition(frame.Name, frame.TextOverlay or frame.Health,
			unitSettings.namePosition, unitSettings.nameOffsetX, unitSettings.nameOffsetY)

		local nameParent = frame.TextOverlay or frame.Health
		if nameParent then
			local parentWidth = nameParent:GetWidth()
			if parentWidth and parentWidth > 0 then
				frame.Name:SetWidth(parentWidth - 8)
			end
		end

		if unitSettings.classColorName and UnitExists(unit) then
			local red, green, blue = UnitFrames.GetNameColor(unit, unitSettings)
			frame.Name:SetTextColor(red, green, blue)
		else
			frame.Name:SetTextColor(1, 1, 1)
		end
	end

	if frame.HealthText then
		Pixel.ApplyFont(frame.HealthText, healthTextSize, font)
		UnitFrames.ApplyTextPosition(frame.HealthText, frame.TextOverlay or frame.Health,
			unitSettings.healthPosition, unitSettings.healthOffsetX, unitSettings.healthOffsetY)

		local showHealthText = unitSettings.showHealthText
		if showHealthText == nil then showHealthText = settings.showHealthText ~= false end
		frame.HealthText:SetShown(showHealthText)
	end

	if frame.StatusText then
		Pixel.ApplyFont(frame.StatusText, textSize + 2, font)
	end

	if frame.PowerText then
		Pixel.ApplyFont(frame.PowerText, powerTextSize, font)
		UnitFrames.ApplyTextPosition(frame.PowerText, frame.Power,
			unitSettings.powerPosition, unitSettings.powerOffsetX, unitSettings.powerOffsetY)
	end
end

function UnitFrames.ApplyRaidIconPosition(frame, settings, unitSettings)
	local raidIcon = frame.RaidTargetIndicator
	if not raidIcon then return end

	local show = settings.raidIconMode ~= 'off'
	if unitSettings and unitSettings.hideRaidIcon then show = false end

	raidIcon._buiHidden = not show
	raidIcon:SnapSize(settings.raidIconSize)
	raidIcon:ClearAllPoints()
	raidIcon:SetPoint('CENTER', frame, settings.raidIconPosition,
		Pixel.Scale(settings.raidIconOffsetX), Pixel.Scale(settings.raidIconOffsetY))

	if not show then raidIcon:Hide() end
end

function UnitFrames.ApplyLeaderIconPosition(frame, settings)
	local size    = settings.leaderIconSize
	local anchor  = settings.leaderIconPosition
	local offsetX = Pixel.Scale(settings.leaderIconOffsetX)
	local offsetY = Pixel.Scale(settings.leaderIconOffsetY)
	local hidden  = settings.leaderIconEnabled == false

	for _, element in ipairs({ frame.LeaderIndicator, frame.AssistantIndicator }) do
		if element then
			element:SetSize(Pixel.Scale(size), Pixel.Scale(size))
			element:ClearAllPoints()
			element:SetPoint(anchor, frame, anchor, offsetX, offsetY)
			element._buiHidden = hidden
			if hidden then
				element:Hide()
			elseif element.ForceUpdate then
				element:ForceUpdate()
			end
		end
	end
end

function UnitFrames.ApplyLevelTextStyles(frame, settings, unitSettings)
	if not frame or not frame.LevelText then return end

	local showLevel = settings.showLevel
	if unitSettings and unitSettings.hideLevel then showLevel = false end

	local font = UnitFrames.GetFont()
	local position = settings.levelPosition

	Pixel.ApplyFont(frame.LevelText, settings.levelTextSize, font)
	frame.LevelText:ClearAllPoints()

	local justify = 'CENTER'
	if position:find('LEFT') then justify = 'LEFT'
	elseif position:find('RIGHT') then justify = 'RIGHT' end
	frame.LevelText:SetJustifyH(justify)

	frame.LevelText:SetPoint(position, frame, position, Pixel.Scale(settings.levelOffsetX), Pixel.Scale(settings.levelOffsetY))
	frame.LevelText:SetShown(showLevel and true or false)
end

function UnitFrames.UpdateLevelTextVisibility(frame, unitType)
	if not frame or not frame.LevelText then return end
	local settings = UnitFrames.GetSettings()
	local unitSettings = UnitFrames.GetUnitSettings(unitType)
	local show = settings.showLevel and not (unitSettings and unitSettings.hideLevel)
	frame.LevelText:SetShown(show and true or false)
end

local targetBorderFrames = {}
local targetBorderEventsRegistered = false

local function UpdateTargetBorder(frame)
	local selection = frame.TargetBorder
	if not selection then return end
	local unit = frame.unit
	local unitSettings = UnitFrames.GetUnitSettings(frame._unitType)
	local config = unitSettings and unitSettings.targetBorder
	if not unit or frame._isPreview or not config or config.enabled == false or not UnitIsUnit('target', unit) then
		selection:Hide()
		return
	end
	local color = config.color
	Pixel.SetBorderColor(selection, color[1], color[2], color[3], color[4] or 1)
	selection:Show()
end

function UnitFrames.RefreshTargetBorders()
	for frame in pairs(targetBorderFrames) do UpdateTargetBorder(frame) end
end

local function RegisterTargetBorderEvents()
	if targetBorderEventsRegistered then return end
	targetBorderEventsRegistered = true
	for _, event in ipairs({ 'PLAYER_TARGET_CHANGED', 'INSTANCE_ENCOUNTER_ENGAGE_UNIT', 'UNIT_TARGETABLE_CHANGED', 'PLAYER_ENTERING_WORLD' }) do
		BUI.Events:Register(event, 'UF.TargetBorder.' .. event, UnitFrames.RefreshTargetBorders)
	end
end

function UnitFrames.ApplyTargetBorder(frame, unitSettings)
	local config = unitSettings and unitSettings.targetBorder
	if not config then
		if frame.TargetBorder then frame.TargetBorder:Hide() end
		return
	end
	local selection = frame.TargetBorder
	if not selection then
		selection = CreateFrame('Frame', nil, frame)
		selection:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
		selection:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', 0, 0)
		selection:Hide()
		frame.TargetBorder = selection
		targetBorderFrames[frame] = true
		RegisterTargetBorderEvents()
	end
	selection:SetFrameLevel(frame:GetFrameLevel() + 20)
	local color = config.color
	Pixel.SetTemplate(selection, 0, 0, 0, 0, color[1], color[2], color[3], color[4] or 1, config.thickness)
	UpdateTargetBorder(frame)
end

