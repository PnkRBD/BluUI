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

local ABSORB_OVERFLOW_W = 6

local HEALTH_VALUE_EVENTS = {
	UNIT_HEALTH = true,
	UNIT_MAXHEALTH = true,
}

local POWER_VALUE_EVENTS = {
	UNIT_POWER_FREQUENT = true,
	UNIT_MAXPOWER = true,
}

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
		element:SetStatusBarColor(deadColor[1], deadColor[2], deadColor[3], deadColor[4])
		return
	end
	local settings = UnitFrames.GetSettings()

	local red, green, blue
	if unit ~= 'player' and not UnitIsConnected(unit) then
		red, green, blue = self.colors.disconnected:GetRGB()
	else
		red, green, blue = UnitFrames.GetHealthColor(unit, settings)
	end

	element:SetStatusBarColor(red, green, blue, settings.transparentHealth and settings.healthBarAlpha or 1)
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
	BUI.Tools.SetColorTex(frame.FrameBG, backgroundColor[1], backgroundColor[2], backgroundColor[3], settings.transparentHealth and 0 or backgroundColor[4])
	BUI.Tools.SetColorTex(frame.Health.Deficit, deficitColor[1], deficitColor[2], deficitColor[3], deficitColor[4])
	HealthUpdateColor(frame, nil, frame.unit)
end

local function UpdateHealthTextShown(frame)
	if frame._statusState then
		frame.HealthText:Hide()
		return
	end
	frame.HealthText:SetShown(UnitFrames.GetUnitSettings(frame._unitType).showHealthText)
end

local function ApplyStatusText(frame)
	frame.StatusText:SetShown(UnitFrames.GetUnitSettings(frame._unitType).showStatusText ~= false)
end

local function ApplyLifeVisuals(frame)
	ApplyStatusText(frame)
	UpdateHealthTextShown(frame)
	PaintDeadBackground(frame)
end

function UnitFrames.RefreshStatusText(frame)
	ApplyStatusText(frame)
	if frame.StatusText.UpdateTag then frame.StatusText:UpdateTag() end
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
	self.Name:SetTextColor(UnitFrames.GetNameColor(unit, UnitFrames.GetUnitSettings(self._unitType)))
	UnitFrames.UpdateLevelTextVisibility(self, self._unitType)
	UnitFrames.FollowDebuffHighlightUnit(self)
	if not UpdateLifeState(self, unit) then ApplyLifeVisuals(self) end
	if self.TargetOutline then UnitFrames.UpdateBossTarget(self) end
end

function UnitFrames.RefreshLifeVisuals()
	for _, frame in ipairs(oUF.objects) do
		if frame.style == 'BluUI' and not frame._isPreview then ApplyLifeVisuals(frame) end
	end
end

local function TooltipAnchor()
	if UnitFrames.GetSettings().showTooltips ~= false then return UIParent end
end

local BossEnter = function(self)
	self._hovered = true
	UnitFrames.UpdateBossMouseover(self)
end

local BossLeave = function(self)
	self._hovered = false
	UnitFrames.UpdateBossMouseover(self)
end

local function HideWhenMuted(element)
	if element._buiHidden then element:Hide() end
end

local function LeaderOverride(frame)
	local indicator = frame.LeaderIndicator
	if indicator._buiHidden or not BUI.Tools.UnitLeadsGroup(frame.unit) then
		indicator:Hide()
	else
		indicator:SetAtlas('UI-HUD-UnitFrame-Player-Group-LeaderIcon')
		indicator:Show()
	end
end

local function AssistantOverride(frame)
	local indicator = frame.AssistantIndicator
	if indicator._buiHidden or not BUI.Tools.UnitAssistsGroup(frame.unit) then
		indicator:Hide()
	else
		indicator:SetAtlas('UI-HUD-UnitFrame-Party-PortraitOn-Icon-Assist')
		indicator:Show()
	end
end

local function Style(self, unit)
	local unitType = unit:gsub('%d+$', '')
	self._unitType = unitType

	local settings = UnitFrames.GetSettings()
	local unitSettings = UnitFrames.GetUnitSettings(unitType)
	local config = UnitFrames.GetUnitConfig(unitType)

	local texture = UnitFrames.GetTexture()
	local font = UnitFrames.GetFont()
	local isPet = (unitType == 'pet')

	local width = Pixel.Scale(unitSettings.width)
	local height = Pixel.Scale(unitSettings.height)

	self:SetSize(width, height)
	self:SetFrameStrata('LOW')
	self:RegisterForClicks('AnyUp')
	self:SetAttribute('*type1', settings.clickToTarget ~= false and 'target' or nil)

	local bgColor = isPet and settings.petBgColor or settings.bgColor
	local healthColor = isPet and settings.petHealthColor or settings.healthColor
	local powerColor = settings.powerColor
	local borderColor = isPet and settings.petBorderColor or settings.borderColor
	local borderSize = Pixel.ClampBorder(settings.borderSize)
	local edge = Pixel.Scale(borderSize)
	local powerHeight = Pixel.Scale(unitSettings.powerHeight)
	local showPower = config.showPower

	local healthHeight = showPower and (height - edge * 2 - powerHeight - edge) or (height - edge * 2)

	local background = self:CreateTexture(nil, 'BACKGROUND', nil, -8)
	background:SetPoint('TOPLEFT', self, 'TOPLEFT', edge, -edge)
	background:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -edge, edge)
	BUI.Tools.SetColorTex(background, bgColor[1], bgColor[2], bgColor[3], bgColor[4])
	self.FrameBG = background

	Pixel.ApplyBorder(self, borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4])

	local smoothing = UnitFrames.GetBarSmoothing()

	local health = CreateFrame('StatusBar', nil, self)
	health:SetStatusBarTexture(texture)
	local healthTexture = health:GetStatusBarTexture()
	healthTexture:SetTexCoord(0.01, 0.99, 0.01, 0.99)
	health:SetPoint('TOPLEFT', self, 'TOPLEFT', edge, -edge)
	health:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -edge, -edge)
	health:SetHeight(healthHeight)
	local initAlpha = settings.transparentHealth and settings.healthBarAlpha or 1
	health:SetStatusBarColor(healthColor[1], healthColor[2], healthColor[3], initAlpha)
	health.smoothing = smoothing
	health.UpdateColor = HealthUpdateColor
	health.PostUpdate = HealthPostUpdate
	self.Health = health

	local deficit = self:CreateTexture(nil, 'ARTWORK', nil, -1)
	deficit:SetPoint('TOPLEFT', healthTexture, 'TOPRIGHT')
	deficit:SetPoint('BOTTOMLEFT', healthTexture, 'BOTTOMRIGHT')
	deficit:SetPoint('RIGHT', health, 'RIGHT')
	local deficitColor = settings.bgColor
	BUI.Tools.SetColorTex(deficit, deficitColor[1], deficitColor[2], deficitColor[3], deficitColor[4])
	deficit:SetShown(settings.transparentHealth)
	health.Deficit = deficit

	local absorbClip = CreateFrame('Frame', nil, health)
	absorbClip:SetAllPoints(health)
	absorbClip:SetClipsChildren(true)
	absorbClip:SetFrameLevel(health:GetFrameLevel() + 1)

	local absorb = CreateFrame('StatusBar', nil, absorbClip)
	absorb:SetFrameLevel(absorbClip:GetFrameLevel() + 1)
	UnitFrames.AddAbsorbExcess(absorb)
	self.Absorb = absorb

	local healAbsorb = CreateFrame('StatusBar', nil, absorbClip)
	healAbsorb:SetFrameLevel(absorbClip:GetFrameLevel() + 2)
	self.HealAbsorb = healAbsorb

	local overflow = CreateFrame('StatusBar', nil, absorbClip)
	overflow:SetFrameLevel(absorbClip:GetFrameLevel() + 1)
	overflow:SetPoint('TOPRIGHT')
	overflow:SetPoint('BOTTOMRIGHT')
	overflow:SetWidth(Pixel.Scale(ABSORB_OVERFLOW_W))
	overflow:SetMinMaxValues(0, 1)
	overflow:SetValue(1)
	overflow:SetAlpha(0)
	self.AbsorbBars = { Damage = absorb, Heal = healAbsorb, Overflow = overflow }

	local power = CreateFrame('StatusBar', nil, self)
	power:SetStatusBarTexture(texture)
	power:GetStatusBarTexture():SetTexCoord(0.01, 0.99, 0.01, 0.99)
	power:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', edge, edge)
	power:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -edge, edge)
	power:SetHeight(powerHeight)
	local powerRed, powerGreen, powerBlue, powerAlpha = powerColor[1], powerColor[2], powerColor[3], powerColor[4]
	if settings.classColorPower or settings.useClassColorPowerBar then
		local powerType, powerToken = UnitPowerType(unitType)
		local powerTypeColor = PowerBarColor[powerToken or powerType]
		if powerTypeColor then powerRed, powerGreen, powerBlue = powerTypeColor.r, powerTypeColor.g, powerTypeColor.b end
	end
	power:SetStatusBarColor(powerRed, powerGreen, powerBlue, powerAlpha)
	power:SetShown(showPower)
	power.frequentUpdates = true
	power.colorPower = settings.classColorPower
	power.smoothing = smoothing
	power.UpdateColor = PowerUpdateColor
	self.Power = power

	local powerBG = self:CreateTexture(nil, 'BACKGROUND', nil, -7)
	powerBG:SetAllPoints(power)
	BUI.Tools.SetColorTex(powerBG, bgColor[1], bgColor[2], bgColor[3], bgColor[4])
	powerBG:SetShown(showPower)
	self.PowerBG = powerBG

	if unitType == 'player' then
		local predictionBar = BUI.PowerPrediction.Attach(power, {
			enabled = function()
				return UnitFrames.GetUnitSettings('player').powerPrediction == true
			end,
		})
		local predictionColor = unitSettings.powerPredictionColor
		BUI.PowerPrediction.Restyle(predictionBar, texture, predictionColor[1], predictionColor[2], predictionColor[3], predictionColor[4])
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
	BUI.Tools.SetColorTex(separator, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	self.PowerBorder = separator
	self.PowerBorderFrame = separatorFrame

	local overlay = CreateFrame('Frame', nil, self)
	overlay:SetAllPoints(self)
	overlay:SetFrameLevel(self:GetFrameLevel() + 20)
	overlay:EnableMouse(false)
	self.TextOverlay = overlay

	local nameTextSize = UnitFrames.TextSetting(unitSettings, 'nameTextSize')
	local healthTextSize = UnitFrames.TextSetting(unitSettings, 'healthTextSize')
	local powerTextSize = UnitFrames.TextSetting(unitSettings, 'powerTextSize')

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
	Pixel.ApplyFont(statusText, UnitFrames.TextSetting(unitSettings, 'statusTextSize'), font)
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

	raidIcon.PostUpdate = HideWhenMuted
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
	leaderTexture.Override = LeaderOverride
	leaderTexture._buiHidden = not leaderEnabled
	self.LeaderIndicator = leaderTexture

	local assistantTexture = raidIconFrame:CreateTexture(nil, 'OVERLAY', nil, 7)
	assistantTexture:SetSize(Pixel.Scale(leaderSize), Pixel.Scale(leaderSize))
	assistantTexture:SetPoint(leaderAnchor, self, leaderAnchor, Pixel.Scale(leaderOffsetX), Pixel.Scale(leaderOffsetY))
	assistantTexture:Hide()
	assistantTexture.Override = AssistantOverride
	assistantTexture._buiHidden = not leaderEnabled
	self.AssistantIndicator = assistantTexture

	local levelText = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(levelText, 10, font)
	levelText:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', Pixel.Scale(2), Pixel.Scale(2))
	levelText:Hide()
	self.LevelText = levelText

	if config.hasAuras then
		UnitFrames.CreateAuraElements(self, unitType)
	end

	if unitType == 'boss' and not self._stage then
		BUI.CastBar.CreateBossCastbar(self)
		self:HookScript('OnEnter', BossEnter)
		self:HookScript('OnLeave', BossLeave)
	end

	if (unitType == 'player' or unitType == 'target' or unitType == 'focus') and not self._stage then
		BUI.CastBar.CreateCastbar(self, unitType)
	end

	self.PostUpdate = FramePostUpdate
	self:RegisterEvent('UNIT_FLAGS', OnUnitFlags)
	self:RegisterEvent('UNIT_CONNECTION', OnUnitFlags)
	self:RegisterEvent('UNIT_FACTION', HealthUpdateColor)
	self:RegisterEvent('UNIT_FACTION', PowerUpdateColor)

	BUI.Tools.HookUnitTooltip(self, TooltipAnchor)

	local savedPosition = unitSettings.position
	self:ClearAllPoints()
	self:SetPoint(
		savedPosition.point,
		UIParent,
		savedPosition.relPoint,
		Pixel.Scale(savedPosition.x),
		Pixel.Scale(savedPosition.y)
	)
	if InCombatLockdown() then UnitFrames.ApplySettings(self, unitType, tonumber(unit:match('%d+$'))) end
end

local function StageStyle(self, unit)
	self._stage = true
	Style(self, unit)
end

oUF:RegisterStyle('BluUI', Style)
oUF:RegisterStyle('BluUIStage', StageStyle)
oUF:SetActiveStyle('BluUI')
