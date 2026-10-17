local _, BUI = ...

local oUF = BUI.oUF
local UnitFrames = BUI.UnitFrames
local Pixel = BUI.Pixel

local InCombatLockdown = InCombatLockdown
local UnitHasVehiclePlayerFrameUI = UnitHasVehiclePlayerFrameUI

local function ShowPower(unitType, unitSettings)
	if UnitFrames.GetUnitConfig(unitType).showPowerDefault == false then
		return unitSettings.showPower == true
	end
	return unitSettings.showPower ~= false
end

local function ApplySettings(frame, unitType, index)
	if not frame then return end

	local unitConfig = UnitFrames.GetUnitConfig(unitType)
	local settings = UnitFrames.GetSettings()
	local unitSettings = UnitFrames.GetUnitSettings(unitType)
	local texture = UnitFrames.GetTexture()

	local anchorHeight = BUI.Anchor.GetAnchorHeight(unitSettings)
	local scaledHeight = anchorHeight or Pixel.Scale(unitSettings.height)
	local borderSize = settings.borderSize

	frame:SetSize(Pixel.Scale(unitSettings.width), scaledHeight)
	if not frame._stage then UnitFrames.ApplyPosition(frame, unitType, index) end

	local showPower = ShowPower(unitType, unitSettings)

	local borderColor
	if unitConfig.hasCombatBorder and unitSettings.combatBorder and InCombatLockdown() then
		borderColor = unitSettings.combatBorderColor
	else
		borderColor = (unitType == 'pet') and settings.petBorderColor or settings.borderColor
	end
	Pixel.ApplyBorder(frame, borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4])

	UnitFrames.ApplyHealthBarLayout(frame, scaledHeight, showPower, unitSettings.powerHeight, borderSize)
	UnitFrames.ApplyBarTextures(frame, texture)

	local power = frame.Power
	if showPower then
		if not frame:IsElementEnabled('Power') then
			frame:EnableElement('Power')
			power:ForceUpdate()
		end
	elseif frame:IsElementEnabled('Power') then
		frame:DisableElement('Power')
	end
	power:SetShown(showPower)
	frame.PowerBG:SetShown(showPower)
	frame.PowerBorderFrame:SetShown(showPower)

	local opacity = BUI.Visibility.GetContextualOpacity('UnitFrames') / 100
	frame._ufOpacity = opacity
	frame:SetAlpha(opacity)

	local isPet = unitType == 'pet'
	UnitFrames.ApplyBackgroundColors(frame, isPet and settings.petBgColor or settings.bgColor, isPet and settings.petPowerBgColor or settings.powerBgColor)
	UnitFrames.ApplyAbsorbStyles(frame, settings)
	UnitFrames.ApplyHealAbsorbStyles(frame, settings)

	UnitFrames.ApplyTextStyles(frame, settings, unitSettings, index and (unitType .. index) or unitType)
	UnitFrames.ApplyRaidIconPosition(frame, settings, unitSettings)
	UnitFrames.ApplyLeaderIconPosition(frame, settings)
	UnitFrames.ApplyLevelTextStyles(frame, settings, unitSettings)

	frame.PowerText:SetShown(showPower and unitSettings.showPowerText)
	BUI.Tools.SetColorTex(frame.PowerBorder, borderColor[1], borderColor[2], borderColor[3], borderColor[4])

	local smoothing = UnitFrames.GetBarSmoothing()
	frame.Health.smoothing = smoothing
	power.smoothing = smoothing
	power.colorPower = settings.classColorPower

	local deficit = frame.Health.Deficit
	deficit:SetShown(settings.transparentHealth)
	if settings.transparentHealth then
		local deficitColor = settings.bgColor
		BUI.Tools.SetColorTex(deficit, deficitColor[1], deficitColor[2], deficitColor[3], deficitColor[4])
	end

	local predict = power._predict
	if predict then
		local predictionColor = unitSettings.powerPredictionColor
		BUI.PowerPrediction.Restyle(predict, texture, predictionColor[1], predictionColor[2], predictionColor[3], predictionColor[4])
	end

	if unitType == 'boss' then
		if frame.Castbar then BUI.CastBar.ApplyBossCastbar(frame, index) end
		if not frame._stage then UnitFrames.ApplyBossOutlines(frame) end
	elseif frame.Castbar then
		BUI.CastBar.ApplyCastbar(frame, unitType)
	end

	if not frame._isPreview then
		UnitFrames.TagFontStrings(frame)

		if unitConfig.hasAuras then
			UnitFrames.RefreshAuraLayout(frame, unitType)
		end

		frame:UpdateAllElements('SettingsRefresh')
	end
end

UnitFrames.ApplySettings = ApplySettings

local VEHICLE_TOGGLE_UNITS = {'player', 'pet'}

local function ApplyVehicleToggle()
	if InCombatLockdown() then
		BUI.Events:AfterCombat(ApplyVehicleToggle, 'UF.VehicleToggle')
		return
	end
	local swap = UnitHasVehiclePlayerFrameUI('player') and true or false
	for _, unitType in ipairs(VEHICLE_TOGGLE_UNITS) do
		local frame = UnitFrames[unitType]
		if frame then
			if frame:GetAttribute('toggleForVehicle') ~= swap then
				frame:SetAttribute('toggleForVehicle', swap)
			end
			frame:SetAttribute('unit', frame:GetAttribute('unit'))
		end
	end
end

local QueueVehicleToggle = BUI.Dispatcher.New(ApplyVehicleToggle, 'UF.VehicleToggle')

local function RefreshPlayerFrame()
	local frame = UnitFrames.player
	if frame and frame:IsVisible() then
		frame:UpdateAllElements('LifeStateChanged')
	end
end

local CORE_UNITS = {'player', 'target', 'targettarget', 'focus', 'pet'}
local FRAME_NAMES = {
	player = 'BUI_PlayerFrame',
	target = 'BUI_TargetFrame',
	targettarget = 'BUI_TargetTargetFrame',
	focus = 'BUI_FocusFrame',
	pet = 'BUI_PetFrame',
}

function UnitFrames:Initialize()
	if not UnitFrames.GetSettings().enabled then return end

	oUF:Factory(function()
		oUF:SetActiveStyle('BluUI')

		for _, unitType in ipairs(CORE_UNITS) do
			if not self[unitType] then
				self[unitType] = oUF:Spawn(unitType, FRAME_NAMES[unitType])
			end
		end

		if UnitFrames.GetUnitSettings('boss').enabled ~= false then
			for bossIndex = 1, 5 do
				if not self['boss' .. bossIndex] then
					self['boss' .. bossIndex] = oUF:Spawn('boss' .. bossIndex, 'BUI_BossFrame' .. bossIndex)
				end
			end
		end

		ApplyVehicleToggle()
		BUI.Events:Register('PLAYER_MOUNT_DISPLAY_CHANGED', 'UF.Vehicle', QueueVehicleToggle)
		BUI.Events:Register('PLAYER_ENTERING_WORLD', 'UF.Vehicle', QueueVehicleToggle)
		BUI.Events:RegisterUnit('UNIT_ENTERED_VEHICLE', 'player', 'UF.Vehicle', QueueVehicleToggle)
		BUI.Events:RegisterUnit('UNIT_EXITED_VEHICLE', 'player', 'UF.Vehicle', QueueVehicleToggle)

		BUI.Events:Register('PLAYER_ALIVE', 'UF.LifeState', RefreshPlayerFrame)
		BUI.Events:Register('PLAYER_UNGHOST', 'UF.LifeState', RefreshPlayerFrame)
		BUI.Events:Register('PLAYER_DEAD', 'UF.LifeState', RefreshPlayerFrame)

		self:Refresh()
	end)

	Pixel.OnScaleChange('UnitFrames', function() UnitFrames:Refresh() end)
end

local function RefreshFrame(frame, unitType)
	if not frame then return end

	if InCombatLockdown() then
		BUI.Events:AfterCombat(function() RefreshFrame(frame, unitType) end, 'UF.RefreshFrame:' .. unitType)
		return
	end

	if UnitFrames.GetUnitSettings(unitType).enabled ~= false then
		ApplySettings(frame, unitType)
		if not frame._isPreview and not frame:IsEnabled() then frame:Enable() end
	elseif not frame._isPreview then
		frame:Disable()
	end
end

function UnitFrames:Refresh()
	UnitFrames.InvalidateSettingsCache()
	UnitFrames.RefreshAbbreviationSetting()

	for _, unitType in ipairs(CORE_UNITS) do
		RefreshFrame(self[unitType], unitType)
	end
	UnitFrames.UpdateDebuffHighlight(self.player)

	local bossEnabled = UnitFrames.GetUnitSettings('boss').enabled ~= false
	for bossIndex = 1, 5 do
		local key = 'boss' .. bossIndex
		local bossFrame = self[key]
		if bossEnabled then
			BUI.Events:AfterCombat(function()
				local frame = self[key]
				if not frame then
					oUF:SetActiveStyle('BluUI')
					frame = oUF:Spawn(key, 'BUI_BossFrame' .. bossIndex)
					self[key] = frame
				end
				ApplySettings(frame, 'boss', bossIndex)
				if not frame._isPreview and not frame:IsEnabled() then frame:Enable() end
			end, 'UF.ApplyBoss:' .. bossIndex)
		elseif bossFrame and not bossFrame._isPreview then
			BUI.Events:AfterCombat(function() bossFrame:Disable() end, 'UF.DisableBoss:' .. bossIndex)
		end
	end
end

local ANCHORABLE_UNITS = {'player', 'target', 'focus', 'pet', 'targettarget'}

local function ApplyAnchoredHeight(frame, unitType, unitSettings)
	local scaledHeight = BUI.Anchor.GetAnchorHeight(unitSettings) or Pixel.Scale(unitSettings.height)
	frame:SetSize(Pixel.Scale(unitSettings.width), scaledHeight)
	UnitFrames.ApplyPosition(frame, unitType)
	UnitFrames.ApplyHealthBarLayout(frame, scaledHeight, ShowPower(unitType, unitSettings), unitSettings.powerHeight, UnitFrames.GetSettings().borderSize)
	UnitFrames.FitNameWidth(frame)
	if frame.Castbar then BUI.CastBar.RepositionCastbar(frame, unitType) end
end

function UnitFrames.RefreshAnchoredFrames()
	if InCombatLockdown() then return end

	for _, unitType in ipairs(ANCHORABLE_UNITS) do
		local unitFrame = UnitFrames[unitType]
		if unitFrame then
			local unitSettings = UnitFrames.GetUnitSettings(unitType)
			if unitSettings.anchorFrame ~= '' and UnitFrames.AnchorGeometryChanged(unitFrame, BUI.ResolveAnchorFrame(unitSettings.anchorFrame), BUI.Anchor.GetAnchorHeight(unitSettings)) then
				if unitSettings.matchAnchorHeight then
					ApplyAnchoredHeight(unitFrame, unitType, unitSettings)
				else
					UnitFrames.ApplyPosition(unitFrame, unitType)
				end
			end
		end
	end
end
