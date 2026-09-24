local _, BUI = ...

local oUF = BUI.oUF
local UnitFrames = BUI.UnitFrames
local Pixel = BUI.Pixel

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitIsConnected = UnitIsConnected
local UnitIsDead = UnitIsDead
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost

local function HealthUpdateColor(self, event, unit)
	if not unit or self.unit ~= unit then return end
	local element = self.Health
	local settings = UnitFrames.GetSettings()

	local red, green, blue
	if unit ~= 'player' and not UnitIsConnected(unit) then
		local disconnectedColor = self.colors.disconnected
		if disconnectedColor then red, green, blue = disconnectedColor:GetRGB() end

	else
		red, green, blue = UnitFrames.GetHealthColor(unit, settings)
	end

	if not red then red, green, blue = 1, 1, 1 end

	if settings.transparentHealth then
		local alpha = settings.healthBarAlpha
		element:SetStatusBarColor(red, green, blue, alpha)
	else
		element:SetStatusBarColor(red, green, blue, 1)
	end
end

local function PowerPostUpdateColor(element, unit, color)
	local frame = element:GetParent()
	local settings = UnitFrames.GetSettings()
	if color and not settings.useClassColorPowerBar then return end
	local unitSettings = UnitFrames.GetUnitSettings(frame._unitType)
	local red, green, blue, alpha = UnitFrames.GetPowerColor(unit, settings, unitSettings)
	element:SetStatusBarColor(red, green, blue, alpha)
end

local function UpdateNameColor(frame, event, unit)
	if frame._isPreview then return end
	unit = unit or frame.unit
	if not unit or not UnitExists(unit) then return end
	local unitSettings = UnitFrames.GetUnitSettings(frame._unitType)
	local red, green, blue = UnitFrames.GetNameColor(unit, unitSettings)
	frame.Name:SetTextColor(red, green, blue)
end

local function UpdateStatusText(self, unit)
	if not self.StatusText then return end
	local state
	if not unit or not UnitExists(unit) then
		state = nil
	elseif not UnitIsConnected(unit) then
		state = 'offline'
	elseif UnitIsGhost(unit) then
		state = 'ghost'
	elseif UnitIsDead(unit) then
		state = 'dead'
	end
	if state == self._statusState then return end
	self._statusState = state
	if state == 'offline' then
		self.StatusText:SetText('OFFLINE')
		self.StatusText:SetTextColor(1, 1, 1)
		self.StatusText:Show()
	elseif state == 'ghost' then
		self.StatusText:SetText('GHOST')
		self.StatusText:SetTextColor(1, 1, 1)
		self.StatusText:Show()
	elseif state == 'dead' then
		self.StatusText:SetText('DEAD')
		self.StatusText:SetTextColor(0.8, 0.2, 0.2)
		self.StatusText:Show()
	else
		self.StatusText:Hide()
	end
end

local function HealthPostUpdate(element, unit)
	if UnitIsDeadOrGhost(unit) then
		element:SetMinMaxValues(0, 1)
		element:SetValue(0)
	elseif unit == 'player' and not UnitIsConnected(unit) then
		element:SetValue(element.cur or 0, element.smoothing)
	end
	local frame = element.__owner
	UpdateStatusText(frame, unit)
	if frame.HealthText then
		if frame.StatusText and frame.StatusText:IsShown() then
			frame.HealthText:Hide()
		else
			local settings = UnitFrames.GetSettings()
			local unitSettings = UnitFrames.GetUnitSettings(frame._unitType)
			local show = unitSettings and unitSettings.showHealthText
			if show == nil then show = settings.showHealthText ~= false end
			frame.HealthText:SetShown(show)
		end
	end
end

local function FramePostUpdate(self)
	local unit = self.unit
	if not unit or not UnitExists(unit) then return end
	UpdateNameColor(self, nil, unit)
	UnitFrames.UpdateLevelTextVisibility(self, self._unitType)
	UpdateStatusText(self, unit)
end

local function SetupTooltip(frame)
	frame:HookScript('OnEnter', function(self)
		if not self.unit or GetMouseFoci()[1] ~= self then return end
		local settings = UnitFrames.GetSettings()
		if settings and settings.showTooltips ~= false then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetUnit(self.unit)
		end
	end)
	frame:HookScript('OnLeave', function()
		GameTooltip:Hide()
	end)
end

local function Style(self, unit)
	local unitType = unit:gsub('%d+$', '')
	self._unitType = unitType

	local settings = UnitFrames.GetSettings()
	local unitSettings = UnitFrames.GetUnitSettings(unitType)
	local config = UnitFrames.GetUnitConfig(unitType)
	if not config then return end

	local texture = UnitFrames.GetTexture()
	local font = UnitFrames.GetFont()
	local isPet = (unitType == 'pet')

	local width = Pixel.Scale(unitSettings.width)
	local height = Pixel.Scale(unitSettings.height)

	self:SetSize(width, height)
	self:SetFrameStrata('LOW')
	self:RegisterForClicks('AnyUp')
	if settings.clickToTarget ~= false then
		self:SetAttribute('*type1*', 'target')
	end

	local bgColor = isPet and settings.petBgColor or settings.bgColor
	local healthColor = isPet and settings.petHealthColor or settings.healthColor
	local powerColor = unitSettings.powerColor or settings.powerColor
	local borderColor = isPet and settings.petBorderColor or settings.borderColor
	local borderSize = Pixel.ClampBorder(settings.borderSize)
	local edge = Pixel.Scale(borderSize)
	local powerHeight = Pixel.Scale(unitSettings.powerHeight)
	local showPower = config.showPower

	local healthHeight = showPower and (height - edge * 2 - powerHeight - edge) or (height - edge * 2)

	local background = self:CreateTexture(nil, 'BACKGROUND', nil, -8)
	background:SetPoint('TOPLEFT', self, 'TOPLEFT', edge, -edge)
	background:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -edge, edge)
	BUI.Tools.SetColorTex(background, bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
	self.FrameBG = background

	Pixel.ApplyBorder(self, borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)

	local health = CreateFrame('StatusBar', nil, self)
	health:SetStatusBarTexture(texture)
	local healthTexture = health:GetStatusBarTexture()
	if healthTexture then healthTexture:SetTexCoord(0.01, 0.99, 0.01, 0.99) end
	health:SetPoint('TOPLEFT', self, 'TOPLEFT', edge, -edge)
	health:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -edge, -edge)
	health:SetHeight(healthHeight)
	local initAlpha = settings.transparentHealth and settings.healthBarAlpha or 1
	health:SetStatusBarColor(healthColor[1], healthColor[2], healthColor[3], initAlpha)
	health.smoothing = BUI.GetDB().general.smoothBars and Enum.StatusBarInterpolation.ExponentialEaseOut or nil
	health.UpdateColor = HealthUpdateColor
	health.PostUpdate = HealthPostUpdate
	self.Health = health

	local deficit = self:CreateTexture(nil, 'ARTWORK', nil, -1)
	if healthTexture then
		deficit:SetPoint('TOPLEFT', healthTexture, 'TOPRIGHT')
		deficit:SetPoint('BOTTOMLEFT', healthTexture, 'BOTTOMRIGHT')
	end
	deficit:SetPoint('RIGHT', health, 'RIGHT')
	local deficitColor = settings.bgColor
	BUI.Tools.SetColorTex(deficit, deficitColor[1], deficitColor[2], deficitColor[3], deficitColor[4] or 1)
	deficit:SetShown(settings.transparentHealth)
	health.Deficit = deficit

	local absorbClip = CreateFrame('Frame', nil, health)
	absorbClip:SetAllPoints(health)
	absorbClip:SetClipsChildren(true)
	absorbClip:SetFrameLevel(health:GetFrameLevel() + 1)

	local absorb = CreateFrame('StatusBar', nil, absorbClip)
	absorb:SetFrameLevel(absorbClip:GetFrameLevel() + 1)
	UnitFrames.ApplyAbsorbVisual(absorb, UnitFrames.BuildAbsorbCfg(settings))
	UnitFrames.AnchorAbsorb(absorb, health, healthTexture, settings.shieldDirection)
	self.Absorb = absorb
	health.damageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode and Enum.UnitDamageAbsorbClampMode.MaximumHealth
	if settings.shieldEnabled ~= false then
		health.DamageAbsorb = absorb
	else
		absorb:Hide()
	end

	local healAbsorb = CreateFrame('StatusBar', nil, absorbClip)
	healAbsorb:SetFrameLevel(absorbClip:GetFrameLevel() + 1)
	UnitFrames.ApplyHealAbsorbVisual(healAbsorb, UnitFrames.BuildHealAbsorbCfg(settings))
	UnitFrames.AnchorAbsorb(healAbsorb, health, healthTexture, settings.healAbsorbDirection)
	self.HealAbsorb = healAbsorb
	health.healAbsorbClampMode = Enum.UnitHealAbsorbClampMode and Enum.UnitHealAbsorbClampMode.MaximumHealth
	if settings.healAbsorbEnabled ~= false then
		health.HealAbsorb = healAbsorb
	else
		healAbsorb:Hide()
	end

	local power = CreateFrame('StatusBar', nil, self)
	power:SetStatusBarTexture(texture)
	local powerTexture = power:GetStatusBarTexture()
	if powerTexture then powerTexture:SetTexCoord(0.01, 0.99, 0.01, 0.99) end
	power:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', edge, edge)
	power:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -edge, edge)
	power:SetHeight(powerHeight)
	local powerRed, powerGreen, powerBlue, powerAlpha = powerColor[1], powerColor[2], powerColor[3], powerColor[4] or 1
	if (settings.classColorPower or settings.useClassColorPowerBar) and unitType then
		local powerType, powerToken = UnitPowerType(unitType)
		local powerTypeColor = PowerBarColor[powerToken or powerType]
		if powerTypeColor then powerRed, powerGreen, powerBlue = powerTypeColor.r, powerTypeColor.g, powerTypeColor.b end
	end
	power:SetStatusBarColor(powerRed, powerGreen, powerBlue, powerAlpha)
	power:SetShown(showPower)
	power.frequentUpdates = true
	power.colorPower = settings.classColorPower
	power.smoothing = BUI.GetDB().general.smoothBars and Enum.StatusBarInterpolation.ExponentialEaseOut or nil
	power.PostUpdateColor = PowerPostUpdateColor
	self.Power = power

	local powerBG = self:CreateTexture(nil, 'BACKGROUND', nil, -7)
	powerBG:SetAllPoints(power)
	BUI.Tools.SetColorTex(powerBG, bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
	powerBG:SetShown(showPower)
	self.PowerBG = powerBG

	if unitType == 'player' then
		local predictionBar = BUI.PowerPrediction.Attach(power, {
			texture = texture,
			enabled = function()
				return UnitFrames.GetUnitSettings('player').powerPrediction == true
			end,
		})
		local predictionColor = settings.powerPredictionColor or { 1, 1, 1, 0.35 }
		predictionBar:SetStatusBarColor(predictionColor[1] or 1, predictionColor[2] or 1, predictionColor[3] or 1, predictionColor[4] or 0.35)
		power._predict = predictionBar
	end

	local separatorFrame = CreateFrame('Frame', nil, self)
	separatorFrame:SetFrameLevel(power:GetFrameLevel() + 5)
	separatorFrame:SetPoint('TOPLEFT', self, 'TOPLEFT', edge, -(edge + healthHeight))
	separatorFrame:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -edge, -(edge + healthHeight))
	separatorFrame:SetHeight(edge)
	separatorFrame:SetShown(showPower)
	local separator = separatorFrame:CreateTexture(nil, 'OVERLAY', nil, 7)
	separator:SetAllPoints()
	BUI.Tools.SetColorTex(separator, borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
	self.PowerBorder = separator
	self.PowerBorderFrame = separatorFrame

	local overlay = CreateFrame('Frame', nil, self)
	overlay:SetAllPoints(self)
	overlay:SetFrameLevel(self:GetFrameLevel() + 20)
	overlay:EnableMouse(false)
	self.TextOverlay = overlay

	local function PositiveOr(value, fallback) return (type(value) == 'number' and value > 0) and value or fallback end
	local textSize = PositiveOr(unitSettings.textSize, 12)
	local nameTextSize = PositiveOr(unitSettings.nameTextSize, textSize)
	local healthTextSize = PositiveOr(unitSettings.healthTextSize, textSize)
	local powerTextSize = PositiveOr(unitSettings.powerTextSize, textSize - 2)

	local name = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(name, nameTextSize, font)
	name:SetPoint('LEFT', health, 'LEFT', Pixel.Scale(4), 0)
	name:SetJustifyH('LEFT')
	name:SetWordWrap(false)
	name:SetNonSpaceWrap(false)
	self.Name = name

	local healthText = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(healthText, healthTextSize, font)
	healthText:SetPoint('RIGHT', health, 'RIGHT', Pixel.Scale(-4), 0)
	self.HealthText = healthText

	local statusText = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(statusText, textSize + 2, font)
	statusText:SetPoint('CENTER', health, 'CENTER', 0, 0)
	statusText:Hide()
	self.StatusText = statusText

	local powerText = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(powerText, powerTextSize, font)
	powerText:SetPoint('RIGHT', power, 'RIGHT', Pixel.Scale(-4), 0)
	powerText:Hide()
	self.PowerText = powerText

	local raidIconFrame = CreateFrame('Frame', nil, self)
	raidIconFrame:SetAllPoints(self)
	raidIconFrame:SetFrameLevel(self:GetFrameLevel() + 50)
	raidIconFrame:EnableMouse(false)

	local raidIcon = raidIconFrame:CreateTexture(nil, 'OVERLAY', nil, 7)
	raidIcon:SetSize(Pixel.Scale(16), Pixel.Scale(16))
	raidIcon:SetPoint('CENTER', self, 'TOP', 0, 0)
	raidIcon:SetTexture(BUI.C.RAID_ICON_TEXTURE)
	raidIcon:Hide()

	raidIcon.PostUpdate = function(element) if element._buiHidden then element:Hide() end end
	self.RaidTargetIndicator = raidIcon

	local leaderSize = settings.leaderIconSize
	local leaderAnchor = settings.leaderIconPosition
	local leaderOffsetX = settings.leaderIconOffsetX
	local leaderOffsetY = settings.leaderIconOffsetY
	local leaderEnabled = settings.leaderIconEnabled ~= false

	local leaderTexture = raidIconFrame:CreateTexture(nil, 'OVERLAY', nil, 7)
	leaderTexture:SetSize(Pixel.Scale(leaderSize), Pixel.Scale(leaderSize))
	leaderTexture:SetPoint(leaderAnchor, self, leaderAnchor, Pixel.Scale(leaderOffsetX), Pixel.Scale(leaderOffsetY))
	leaderTexture:Hide()
	leaderTexture.Override = function(frame)
		local indicator = frame.LeaderIndicator
		if indicator._buiHidden or not frame.unit or not UnitInParty(frame.unit) or not UnitIsGroupLeader(frame.unit) then
			indicator:Hide()
		else
			indicator:SetAtlas('UI-HUD-UnitFrame-Player-Group-LeaderIcon', true)
			indicator:Show()
		end
	end
	leaderTexture._buiHidden = not leaderEnabled
	self.LeaderIndicator = leaderTexture

	local assistantTexture = raidIconFrame:CreateTexture(nil, 'OVERLAY', nil, 7)
	assistantTexture:SetSize(Pixel.Scale(leaderSize), Pixel.Scale(leaderSize))
	assistantTexture:SetPoint(leaderAnchor, self, leaderAnchor, Pixel.Scale(leaderOffsetX), Pixel.Scale(leaderOffsetY))
	assistantTexture:Hide()
	assistantTexture.Override = function(frame)
		local indicator = frame.AssistantIndicator
		if indicator._buiHidden or not frame.unit or not UnitInParty(frame.unit) or not UnitIsGroupAssistant(frame.unit) or UnitIsGroupLeader(frame.unit) then
			indicator:Hide()
		else
			indicator:SetAtlas('UI-HUD-UnitFrame-Party-PortraitOn-Icon-Assist', true)
			indicator:Show()
		end
	end
	assistantTexture._buiHidden = not leaderEnabled
	self.AssistantIndicator = assistantTexture

	local levelText = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(levelText, 10, font)
	levelText:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', Pixel.Scale(2), Pixel.Scale(2))
	levelText:Hide()
	self.LevelText = levelText

	UnitFrames.TagFontStrings(self)

	if unitType == 'player' or unitType == 'target' or unitType == 'focus' or unitType == 'boss' or unitType == 'targettarget' then
		UnitFrames.CreateAuraElements(self, unitType)
		UnitFrames.ApplyAuraPositions(self, unitType)
	end

	if unitType == 'boss' then
		BUI.CastBar.CreateBossCastbar(self)
	end

	if unitType == 'player' or unitType == 'target' or unitType == 'focus' then
		BUI.CastBar.CreateCastbar(self, unitType)
	end

	self.PostUpdate = FramePostUpdate
	self:RegisterEvent('UNIT_FLAGS', function(unitFrame)
		if unitFrame.Health and unitFrame.Health.ForceUpdate then unitFrame.Health:ForceUpdate() else UpdateStatusText(unitFrame, unitFrame.unit) end
	end)
	if unitType == 'player' then
		self:RegisterEvent('PLAYER_ALIVE',   function(unitFrame) UpdateStatusText(unitFrame, unitFrame.unit) end, true)
		self:RegisterEvent('PLAYER_UNGHOST', function(unitFrame) UpdateStatusText(unitFrame, unitFrame.unit) end, true)
		self:RegisterEvent('PLAYER_DEAD',    function(unitFrame) UpdateStatusText(unitFrame, unitFrame.unit) end, true)
	end

	SetupTooltip(self)

	local savedPosition = unitSettings.position
	self:ClearAllPoints()
	self:SetPoint(
		savedPosition.point,
		UIParent,
		savedPosition.relPoint,
		Pixel.Scale(savedPosition.x),
		Pixel.Scale(savedPosition.y)
	)
end

oUF:RegisterStyle('BluUI', Style)
oUF:SetActiveStyle('BluUI')
