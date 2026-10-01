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
local UnitPowerType = UnitPowerType

local HEALTH_VALUE_EVENTS = {
	UNIT_HEALTH = true,
	UNIT_MAXHEALTH = true,
	UNIT_HEAL_PREDICTION = true,
	UNIT_ABSORB_AMOUNT_CHANGED = true,
	UNIT_HEAL_ABSORB_AMOUNT_CHANGED = true,
	UNIT_MAX_HEALTH_MODIFIERS_CHANGED = true,
}

local POWER_VALUE_EVENTS = {
	UNIT_POWER_FREQUENT = true,
	UNIT_MAXPOWER = true,
}

local STATUS_NAMES = { offline = 'Offline', ghost = 'Ghost', dead = 'Dead' }

local function DeadBackgroundColor(frame)
	local state = frame._statusState
	if state ~= 'dead' and state ~= 'ghost' then return end
	local raidSettings = BUI.GroupFrames.GetDB().raid
	if raidSettings.deadBackground then return raidSettings.deadBackgroundColor end
end

local function HealthUpdateColor(self, event, unit)
	if HEALTH_VALUE_EVENTS[event] or not unit or self.unit ~= unit then return end
	local element = self.Health
	local deadColor = DeadBackgroundColor(self)
	if deadColor then
		element:SetStatusBarColor(deadColor[1], deadColor[2], deadColor[3], deadColor[4] or 1)
		return
	end
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

local function PowerUpdateColor(self, event, unit)
	if POWER_VALUE_EVENTS[event] or self.__unit ~= unit then return end
	local element = self.Power
	local settings = UnitFrames.GetSettings()
	if element.colorPower and not settings.useClassColorPowerBar then
		local powerColors = self.colors.power
		local powerType, powerToken, altRed = UnitPowerType(unit)
		local tokenColor = powerColors[powerToken]
		if tokenColor or not altRed then
			element:SetStatusBarColor((tokenColor or powerColors[powerType] or powerColors.MANA):GetRGB())
			return
		end
	end
	local unitSettings = UnitFrames.GetUnitSettings(self._unitType)
	element:SetStatusBarColor(UnitFrames.GetPowerColor(unit, settings, unitSettings))
end

local function UpdateNameColor(frame, event, unit)
	if frame._isPreview then return end
	unit = unit or frame.unit
	if not unit or not UnitExists(unit) then return end
	local unitSettings = UnitFrames.GetUnitSettings(frame._unitType)
	local red, green, blue = UnitFrames.GetNameColor(unit, unitSettings)
	frame.Name:SetTextColor(red, green, blue)
end

local function LifeState(unit)
	if not unit or not UnitExists(unit) then return end
	if not UnitIsConnected(unit) then return 'offline' end
	if UnitIsGhost(unit) then return 'ghost' end
	if UnitIsDead(unit) then return 'dead' end
end

local function PaintDeadBackground(frame)
	if frame._isPreview then return end
	local deadColor = DeadBackgroundColor(frame)
	if not deadColor and not frame._deadPainted then return end
	frame._deadPainted = deadColor ~= nil
	local settings = UnitFrames.GetSettings()
	local backgroundColor = deadColor or (frame._unitType == 'pet' and settings.petBgColor or settings.bgColor)
	local deficitColor = deadColor or settings.bgColor
	BUI.Tools.SetColorTex(frame.FrameBG, backgroundColor[1], backgroundColor[2], backgroundColor[3], settings.transparentHealth and 0 or (backgroundColor[4] or 1))
	BUI.Tools.SetColorTex(frame.Health.Deficit, deficitColor[1], deficitColor[2], deficitColor[3], deficitColor[4] or 1)
	HealthUpdateColor(frame, nil, frame.unit)
end

local function UpdateHealthTextShown(frame)
	if frame._statusState then
		frame.HealthText:Hide()
		return
	end
	local show = UnitFrames.GetUnitSettings(frame._unitType).showHealthText
	if show == nil then show = UnitFrames.GetSettings().showHealthText ~= false end
	frame.HealthText:SetShown(show)
end

local function ApplyStatusText(frame)
	local status = STATUS_NAMES[frame._statusState]
	if not status then
		frame.StatusText:Hide()
		return
	end
	local color = BUI.GroupFrames.GetDB().raid.statusText.colors[status]
	frame.StatusText:SetText(status:upper())
	frame.StatusText:SetTextColor(color[1], color[2], color[3])
	frame.StatusText:Show()
end

local function ApplyLifeVisuals(frame)
	ApplyStatusText(frame)
	UpdateHealthTextShown(frame)
	PaintDeadBackground(frame)
end

local function UpdateLifeState(self, unit)
	local state = LifeState(unit)
	if state == self._statusState then return false end
	self._statusState = state
	ApplyLifeVisuals(self)
	return true
end

local function HealthPostUpdate(element, unit)
	local deadOrGhost = UnitIsDeadOrGhost(unit)
	if deadOrGhost then
		element:SetMinMaxValues(0, 1)
		element:SetValue(0)
	elseif unit == 'player' and not UnitIsConnected(unit) then
		element:SetValue(element.cur or 0, element.smoothing)
	end
	local frame = element.__owner
	if deadOrGhost or frame._statusState then UpdateLifeState(frame, unit) end
end

local function OnUnitFlags(self, event)
	if UpdateLifeState(self, self.unit) then
		self.Health:ForceUpdate()
	else
		HealthUpdateColor(self, event, self.unit)
	end
end

local function FramePostUpdate(self)
	local unit = self.unit
	if not unit or not UnitExists(unit) then return end
	UpdateNameColor(self, nil, unit)
	UnitFrames.UpdateLevelTextVisibility(self, self._unitType)
	UnitFrames.FollowDebuffHighlightUnit(self)
	if not UpdateLifeState(self, unit) then ApplyLifeVisuals(self) end
end

function UnitFrames.RefreshLifeVisuals()
	for _, frame in ipairs(oUF.objects) do
		if frame.style == 'BluUI' and not frame._isPreview then ApplyLifeVisuals(frame) end
	end
end

local function SetupTooltip(frame)
	frame:HookScript('OnEnter', BUI.Profiler.Wrap('UnitFrames.Layout frame OnEnter', function(self)
		if not self.unit or GetMouseFoci()[1] ~= self then return end
		local settings = UnitFrames.GetSettings()
		if settings and settings.showTooltips ~= false then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetUnit(self.unit)
		end
	end))
	frame:HookScript('OnLeave', BUI.Profiler.Wrap('UnitFrames.Layout frame OnLeave', function()
		GameTooltip:Hide()
	end))
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
	self.Absorb = absorb

	local healAbsorb = CreateFrame('StatusBar', nil, absorbClip)
	healAbsorb:SetFrameLevel(absorbClip:GetFrameLevel() + 1)
	self.HealAbsorb = healAbsorb
	self.AbsorbBars = { Damage = absorb, Heal = healAbsorb }

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
	power.UpdateColor = PowerUpdateColor
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

	if unitType == 'player' or unitType == 'target' or unitType == 'focus' or unitType == 'boss' or unitType == 'targettarget' then
		UnitFrames.CreateAuraElements(self, unitType)
	end

	if unitType == 'boss' then
		BUI.CastBar.CreateBossCastbar(self)
	end

	if unitType == 'player' or unitType == 'target' or unitType == 'focus' then
		BUI.CastBar.CreateCastbar(self, unitType)
	end

	self.PostUpdate = FramePostUpdate
	self:RegisterEvent('UNIT_FLAGS', OnUnitFlags)
	self:RegisterEvent('UNIT_CONNECTION', OnUnitFlags)
	self:RegisterEvent('UNIT_FACTION', HealthUpdateColor)
	self:RegisterEvent('UNIT_FACTION', PowerUpdateColor)

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
