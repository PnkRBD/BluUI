local _, BUI = ...

local GroupFrames    = BUI.GroupFrames
local Util  = GroupFrames.Util
local Pixel = BUI.Pixel

local CreateFrame              = CreateFrame
local UnitIsConnected          = UnitIsConnected
local UnitIsUnit               = UnitIsUnit
local UnitInRange              = UnitInRange
local InCombatLockdown         = InCombatLockdown
local sharedMedia              = LibStub("LibSharedMedia-3.0")
local WHITE_TEXTURE            = "Interface\\Buttons\\WHITE8x8"
local IsSecret                 = Util.IsSecret

local FILL_TEXTURES = {
	Solid = "Interface\\AddOns\\BluUI\\Media\\Textures\\solid.tga",
}
local OVERLAY_TEXTURES = {
	Stripes = "Interface\\RaidFrame\\Shield-Overlay",
}

local NAME_TAG   = "[blu:name]"
local STATUS_TAG = "[blu:status]"

local function ResolveTexture(name)
	if not name or name == BUI.C.GLOBAL_OPTION then return BUI.GetGlobalTexture() end
	return sharedMedia:Fetch("statusbar", name) or WHITE_TEXTURE
end

local function ResolveFont(name)
	if not name or name == BUI.C.GLOBAL_OPTION then return BUI.GetGlobalFont() end
	return sharedMedia:Fetch("font", name) or STANDARD_TEXT_FONT
end

local function ResolveOutline(outline)
	return BUI.ApplySlug(outline)
end

local function ResolveBackgroundColor(settings, unit, frame)
	local background = settings.bgColor
	if settings.classColorBackground then
		local red, green, blue = Util.ClassColor(unit, frame)
		if red then return red, green, blue, background[4] end
	end
	return background[1], background[2], background[3], background[4]
end

local function PickHealthColor(settings, unit, frame)
	if settings.useClassColor then
		local classRed, classGreen, classBlue = Util.ClassColor(unit, frame)
		if classRed then return classRed, classGreen, classBlue end
	end
	local healthColor = settings.healthColor
	return healthColor[1], healthColor[2], healthColor[3]
end

local function HealthAlphaFor(settings)
	return settings.transparentHealth and (settings.healthOpacity / 100) or 1
end

local function ApplyFrameColors(frame, settings, unit)
	if frame.Health then frame.Health._inOffline = nil end
	local red, green, blue, alpha = ResolveBackgroundColor(settings, unit, frame)
	if settings.transparentHealth then alpha = 0 end
	local borderColor = settings.borderColor
	Pixel.SetBackgroundColor(frame, red, green, blue, alpha)
	Pixel.SetBorderColor(frame, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
end
GroupFrames.ApplyFrameColors = ApplyFrameColors

local function BuildBackdrop(frame, unit)
	local settings = GroupFrames.SettingsForFrame(frame)
	local red, green, blue, alpha = ResolveBackgroundColor(settings, unit, frame)
	if settings.transparentHealth then alpha = 0 end
	local borderColor = settings.borderColor
	Pixel.SetTemplate(frame, red, green, blue, alpha, borderColor[1], borderColor[2], borderColor[3], borderColor[4], 1)
end

local function BuildHealth(frame, unit)
	local settings  = GroupFrames.SettingsForFrame(frame)
	local texture = ResolveTexture(settings.statusbarTexture)

	local edge = Pixel.Scale(Pixel.ClampBorder(1))
	local healthBar = CreateFrame("StatusBar", nil, frame)
	healthBar:SetStatusBarTexture(texture)
	healthBar:SetPoint("TOPLEFT", edge, -edge)
	healthBar:SetPoint("TOPRIGHT", -edge, -edge)
	local healthTexture = healthBar:GetStatusBarTexture()
	if healthTexture then healthTexture:SetTexCoord(0.01, 0.99, 0.01, 0.99) end

	healthBar.bg = healthBar:CreateTexture(nil, "BACKGROUND")
	healthBar.bg:SetAllPoints()
	healthBar.bg:SetTexture(texture)
	healthBar.bg.multiplier = 0.25

	healthBar.smoothing = BUI.GetDB().general.smoothBars and Enum.StatusBarInterpolation.ExponentialEaseOut or nil

	local deficit = healthBar:CreateTexture(nil, "ARTWORK", nil, -1)
	deficit:SetTexture(texture)
	if healthTexture then
		deficit:SetPoint("TOPLEFT", healthTexture, "TOPRIGHT")
		deficit:SetPoint("BOTTOMLEFT", healthTexture, "BOTTOMRIGHT")
	end
	deficit:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT")
	deficit:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT")
	deficit:Hide()
	healthBar.Deficit = deficit

	healthBar.PostUpdateColor = function(self, updatedUnit)
		local owner = self.__owner
		local isPreview = owner and owner._preview
		local offline = (not isPreview and updatedUnit and not UnitIsConnected(updatedUnit)) and true or false
		local dead = (not isPreview and updatedUnit and not offline and UnitIsDeadOrGhost(updatedUnit)) and true or false
		local class = Util.FrameClass(owner, updatedUnit)
		local dispel = owner and owner._dispelColor
		local hasDispel = (dispel and dispel.r ~= nil and dispel.g ~= nil and dispel.b ~= nil) and true or false
		local dispelRed = hasDispel and dispel.r or false
		local dispelGreen = hasDispel and dispel.g or false
		local dispelBlue = hasDispel and dispel.b or false
		local hasSecretValue = hasDispel and (IsSecret(dispelRed) or IsSecret(dispelGreen) or IsSecret(dispelBlue)) or false

		if not hasSecretValue then
			if self._inOffline == offline and self._inDead == dead and self._inClass == class
				and self._inDR == dispelRed and self._inDG == dispelGreen and self._inDB == dispelBlue then
				return
			end
			self._inOffline, self._inDead, self._inClass = offline, dead, class
			self._inDR, self._inDG, self._inDB = dispelRed, dispelGreen, dispelBlue
		else
			self._inOffline = nil
		end

		local ownerSettings = GroupFrames.SettingsForFrame(owner)
		local deadColor = (dead and ownerSettings.deadBackground) and ownerSettings.deadBackgroundColor or false
		local tintBar = (hasDispel and ownerSettings.dispelBorder and ownerSettings.dispelBorder.tintBar) and true or false
		local transparent = ownerSettings.transparentHealth and true or false
		local alpha = HealthAlphaFor(ownerSettings)

		local backgroundRed, backgroundGreen, backgroundBlue
		if offline then backgroundRed, backgroundGreen, backgroundBlue = 0.5, 0.5, 0.5
		else backgroundRed, backgroundGreen, backgroundBlue = PickHealthColor(ownerSettings, updatedUnit, owner) end

		local red, green, blue = backgroundRed, backgroundGreen, backgroundBlue
		if tintBar and not offline then red, green, blue = dispelRed, dispelGreen, dispelBlue end
		if deadColor then red, green, blue = deadColor[1], deadColor[2], deadColor[3] end

		if offline then self:SetValue(0) end
		self:SetStatusBarColor(red, green, blue, deadColor and (deadColor[4] or 1) or alpha)

		local backgroundAlpha = transparent and 0 or 1
		if deadColor then
			self.bg:SetVertexColor(deadColor[1], deadColor[2], deadColor[3], transparent and 0 or (deadColor[4] or 1))
		else
			self.bg:SetVertexColor(backgroundRed * self.bg.multiplier, backgroundGreen * self.bg.multiplier, backgroundBlue * self.bg.multiplier, backgroundAlpha)
		end

		local barTexture = self:GetStatusBarTexture()
		if barTexture then barTexture:SetDesaturated(offline) end
		if self.Deficit then
			self.Deficit:SetShown(transparent)
			local deficitColor = deadColor or ownerSettings.bgColor
			self.Deficit:SetVertexColor(deficitColor[1], deficitColor[2], deficitColor[3], deficitColor[4] or 1)
		end
		GroupFrames.ReflowAuraVisibility(owner)
	end

	healthBar.PostUpdate = function(self, updatedUnit)
		local owner = self.__owner
		local class = Util.FrameClass(owner, updatedUnit)
		if owner._txtClass == class then return end
		owner._txtClass = class
		GroupFrames.ApplyTextColors(owner, GroupFrames.SettingsForFrame(owner))
	end

	frame.Health = healthBar
end

local function AnchorAbsorb(absorb, health, direction)
	absorb:ClearAllPoints()
	local healthTexture = health:GetStatusBarTexture()
	if direction == "left" then
		absorb:SetReverseFill(true)
		absorb:SetPoint("TOPRIGHT", healthTexture, "TOPRIGHT")
		absorb:SetPoint("BOTTOMRIGHT", healthTexture, "BOTTOMRIGHT")
	elseif direction == "edge" then
		absorb:SetReverseFill(true)
		absorb:SetPoint("TOPRIGHT", health, "TOPRIGHT", 0, 0)
		absorb:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
	else
		absorb:SetReverseFill(false)
		absorb:SetPoint("LEFT", healthTexture, "RIGHT")
		absorb:SetPoint("TOP", health, "TOP")
		absorb:SetPoint("BOTTOM", health, "BOTTOM")
	end
end
GroupFrames.AnchorAbsorb = AnchorAbsorb

local function ApplyAbsorbStyle(bar, config)
	local textureKey = config.texture
	local color   = config.color

	bar:SetStatusBarTexture(FILL_TEXTURES[textureKey] or WHITE_TEXTURE)
	bar:SetStatusBarColor(color[1], color[2], color[3], color[4])
	local baseTexture = bar:GetStatusBarTexture()
	if baseTexture and baseTexture.SetBlendMode then baseTexture:SetBlendMode("BLEND") end

	if bar._absBg then bar._absBg:Hide() end

	local overlayTexturePath = OVERLAY_TEXTURES[textureKey]
	if overlayTexturePath then
		local overlay = bar._absOverlay
		if not overlay then overlay = bar:CreateTexture(nil, "OVERLAY"); bar._absOverlay = overlay end
		overlay:SetTexture(overlayTexturePath, "REPEAT", "REPEAT")
		overlay:SetHorizTile(true); overlay:SetVertTile(true)
		overlay:SetBlendMode("BLEND")
		overlay:SetVertexColor(1, 1, 1)
		overlay:SetAlpha(1)
		overlay:ClearAllPoints()
		overlay:SetAllPoints(baseTexture)
		overlay:Show()
	elseif bar._absOverlay then
		bar._absOverlay:Hide()
	end
end

GroupFrames.ApplyAbsorbVisual = ApplyAbsorbStyle

local function BuildAbsorb(frame, unit)
	local settings = GroupFrames.SettingsForFrame(frame)
	local absorbSettings = settings.absorb
	if not absorbSettings.enabled then return end

	local clip = CreateFrame("Frame", nil, frame.Health)
	clip:SetAllPoints(frame.Health)
	clip:SetClipsChildren(true)
	clip:SetFrameLevel(frame.Health:GetFrameLevel() + 1)

	local absorb = CreateFrame("StatusBar", nil, clip)
	absorb:SetFrameLevel(clip:GetFrameLevel() + 1)
	GroupFrames.ApplyAbsorbVisual(absorb, absorbSettings)
	AnchorAbsorb(absorb, frame.Health, absorbSettings.direction)

	frame.Health.DamageAbsorb = absorb
	frame.Health.damageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode and Enum.UnitDamageAbsorbClampMode.MaximumHealth
	frame.Absorb = absorb

	local healAbsorb = CreateFrame("StatusBar", nil, clip)
	healAbsorb:SetFrameLevel(clip:GetFrameLevel() + 1)
	GroupFrames.ApplyAbsorbVisual(healAbsorb, settings.healAbsorb)
	AnchorAbsorb(healAbsorb, frame.Health, settings.healAbsorb.direction)

	frame.Health.healAbsorbClampMode = Enum.UnitHealAbsorbClampMode and Enum.UnitHealAbsorbClampMode.MaximumHealth
	frame.HealAbsorb = healAbsorb
	if settings.healAbsorb.enabled ~= false then
		frame.Health.HealAbsorb = healAbsorb
	else
		healAbsorb:Hide()
	end
end

function GroupFrames.ApplyAbsorbToChild(child, settings)
	if not child.Absorb then return end
	local absorbSettings = settings.absorb
	GroupFrames.ApplyAbsorbVisual(child.Absorb, absorbSettings)
	AnchorAbsorb(child.Absorb, child.Health, absorbSettings.direction)
	child.Absorb:SetShown(absorbSettings.enabled)
	if child.HealAbsorb then
		GroupFrames.ApplyAbsorbVisual(child.HealAbsorb, settings.healAbsorb)
		AnchorAbsorb(child.HealAbsorb, child.Health, settings.healAbsorb.direction)
		if settings.healAbsorb.enabled ~= false then
			child.Health.HealAbsorb = child.HealAbsorb
		else
			child.Health.HealAbsorb = nil
			child.HealAbsorb:Hide()
		end
	end
end

local function PowerRoleAllowed(healerOnly, frame)
	if not healerOnly or not frame.unit then return true end
	return Util.FrameRole(frame) == "HEALER"
end

local function BuildPower(frame, unit)
	local settings  = GroupFrames.SettingsForFrame(frame)
	local texture = ResolveTexture(settings.statusbarTexture)

	local powerBar = CreateFrame("StatusBar", nil, frame)
	powerBar:SetStatusBarTexture(texture)
	local powerTexture = powerBar:GetStatusBarTexture()
	if powerTexture then powerTexture:SetTexCoord(0.01, 0.99, 0.01, 0.99) end

	powerBar.bg = powerBar:CreateTexture(nil, "BACKGROUND")
	powerBar.bg:SetAllPoints()
	powerBar.bg:SetTexture(texture)
	powerBar.bg.multiplier = 0.25

	powerBar.colorPower = true
	powerBar.smoothing = BUI.GetDB().general.smoothBars and Enum.StatusBarInterpolation.ExponentialEaseOut or nil

	frame.Power = powerBar
end

local function ApplyText(fontString, parent, textSettings, fontFile)
	fontString:SetFont(fontFile, textSettings.size, ResolveOutline(textSettings.outline))
	fontString:SetShadowColor(0, 0, 0, 0)
	fontString:SetShadowOffset(0, 0)
	fontString:SetJustifyH(Util.JustifyFor(textSettings.anchor))
	fontString:SetWordWrap(false)
	fontString:ClearAllPoints()
	fontString:SetPoint(textSettings.anchor, parent, textSettings.anchor, Pixel.Scale(textSettings.offsetX), Pixel.Scale(textSettings.offsetY))
end

GroupFrames.ApplyTextSettings = ApplyText
GroupFrames.ResolveFont = ResolveFont

local function ReTag(frame, fontString, tag)
	if not fontString then return end
	frame:Untag(fontString)
	if frame._preview then return end
	frame:Tag(fontString, tag)
end

local function ApplyTextColor(fontString, useClass, customColor, unit, frame)
	if useClass then
		local red, green, blue = Util.ClassColor(unit, frame)
		if red then
			fontString:SetTextColor(red, green, blue, 1)
			return
		end
	end
	fontString:SetTextColor(customColor[1], customColor[2], customColor[3], customColor[4] or 1)
end

function GroupFrames.ApplyTextColors(child, settings)
	ApplyTextColor(child.NameText,  settings.classColorNames,    settings.name.color,    child.unit, child)
	ApplyTextColor(child.HpText,    settings.hpText.classColor,  settings.hpText.color,  child.unit, child)
	ApplyTextColor(child.PowerText, settings.pwrText.classColor, settings.pwrText.color, child.unit, child)
end

local function InjectAbsorbColor(tagFormat, color)
	if not tagFormat or not tagFormat:find("blu:absorb", 1, true) then return tagFormat end
	local absorbColor = color or { 0.5, 0.5, 1, 1 }
	local hex = ("%02x%02x%02x%02x"):format((absorbColor[4] or 1) * 255, absorbColor[1] * 255, absorbColor[2] * 255, absorbColor[3] * 255)
	return (tagFormat:gsub("%[blu:absorb%]", "|c" .. hex .. "[blu:absorb]|r"))
end
GroupFrames.InjectAbsorbColor = InjectAbsorbColor

function GroupFrames.ReTagHp(child, settings)
	local hpText = child.HpText
	if not hpText then return end
	local format = settings.hpText.format
	if GroupFrames.IsDirectHpFormat(format) then
		child:Untag(hpText)
		if child._preview then return end
		if not child:IsElementEnabled("BluHpTextDirect") then
			child:EnableElement("BluHpTextDirect")
		end
		if child.__unit and hpText.ForceUpdate then hpText:ForceUpdate() else hpText:SetText("") end
		return
	end
	if child:IsElementEnabled("BluHpTextDirect") then
		child:DisableElement("BluHpTextDirect")
	end
	ReTag(child, hpText, InjectAbsorbColor(format, settings.absorbColor))
end

function GroupFrames.ApplyTextToChild(child, settings)
	local fontFile = ResolveFont(settings.font)

	if child.NameText then
		ApplyText(child.NameText, child.Health, settings.name, fontFile)
		ReTag(child, child.NameText, NAME_TAG)
		child.NameText:SetShown(settings.showName)
	end
	if child.HpText then
		ApplyText(child.HpText, child.Health, settings.hpText, fontFile)
		GroupFrames.ReTagHp(child, settings)
		child.HpText:SetShown(settings.showHpText)
	end
	if child.StatusText then
		ApplyText(child.StatusText, child.Health, settings.statusText, fontFile)
		ReTag(child, child.StatusText, STATUS_TAG)
		child.StatusText:SetShown(settings.showStatusText)
	end
	if child.PowerText then
		ApplyText(child.PowerText, child, settings.pwrText, fontFile)
		ReTag(child, child.PowerText, settings.pwrText.format)
		child.PowerText:SetShown(settings.showPwrText and PowerRoleAllowed(settings.healerOnlyPower, child))
	end

	GroupFrames.ApplyTextColors(child, settings)
	child:UpdateTags()
end

local function BuildText(frame, unit)
	local settings = GroupFrames.SettingsForFrame(frame)
	local fontFile = ResolveFont(settings.font)

	local textLayer = CreateFrame("Frame", nil, frame.Health)
	textLayer:SetAllPoints()
	textLayer:SetFrameLevel(frame.Health:GetFrameLevel() + 5)

	local name = textLayer:CreateFontString(nil, "OVERLAY")
	ApplyText(name, frame.Health, settings.name, fontFile)
	frame.NameText = name
	frame:Tag(name, NAME_TAG)

	local hpText = textLayer:CreateFontString(nil, "OVERLAY")
	ApplyText(hpText, frame.Health, settings.hpText, fontFile)
	frame.HpText = hpText
	frame.HpTextDirect = hpText
	if not GroupFrames.IsDirectHpFormat(settings.hpText.format) then
		frame:Tag(hpText, InjectAbsorbColor(settings.hpText.format, settings.absorbColor))
	end

	local statusText = textLayer:CreateFontString(nil, "OVERLAY")
	ApplyText(statusText, frame.Health, settings.statusText, fontFile)
	frame.StatusText = statusText
	frame:Tag(statusText, STATUS_TAG)

	local pwrText = textLayer:CreateFontString(nil, "OVERLAY")
	ApplyText(pwrText, frame, settings.pwrText, fontFile)
	frame.PowerText = pwrText
	frame:Tag(pwrText, settings.pwrText.format)

	GroupFrames.ApplyTextColors(frame, settings)

	frame:RegisterEvent("UNIT_NAME_UPDATE", function()
		GroupFrames.ApplyTextColors(frame, GroupFrames.SettingsForFrame(frame))
	end)
end

function GroupFrames.ApplyGeometry(frame, settings)
	local width, height = Pixel.Scale(settings.width), Pixel.Scale(settings.height)
	local currentWidth, currentHeight = frame:GetSize()
	if math.abs((currentWidth or 0) - width) > 0.1 or math.abs((currentHeight or 0) - height) > 0.1 then
		if not InCombatLockdown() then
			frame:SetSize(width, height)
		end
	end

	local healthBar = frame.Health
	if not healthBar then return end

	local edge = Pixel.Scale(Pixel.ClampBorder(1))
	local hasPower = frame.Power and settings.showPower ~= false and settings.powerHeight > 0
		and PowerRoleAllowed(settings.healerOnlyPower, frame)

	if hasPower then
		local powerHeight = Pixel.Scale(settings.powerHeight)
		healthBar:ClearAllPoints()
		healthBar:SetPoint("TOPLEFT", edge, -edge)
		healthBar:SetPoint("TOPRIGHT", -edge, -edge)
		healthBar:SetPoint("BOTTOM", frame, "BOTTOM", 0, powerHeight + edge)

		frame.Power:ClearAllPoints()
		frame.Power:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", 0, 0)
		frame.Power:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
		frame.Power:SetHeight(powerHeight)
		if not frame._preview and not frame:IsElementEnabled("Power") then
			frame:EnableElement("Power", frame:GetAttribute("oUF-guessUnit"))
			if frame.unit then frame.Power:ForceUpdate() end
		end
		frame.Power:Show()
	else
		healthBar:ClearAllPoints()
		healthBar:SetPoint("TOPLEFT", edge, -edge)
		healthBar:SetPoint("BOTTOMRIGHT", -edge, edge)
		if frame.Power then
			if frame:IsElementEnabled("Power") then
				frame:DisableElement("Power")
			end
			frame.Power:Hide()
		end
	end

	if frame.PowerText then
		frame.PowerText:SetShown(settings.showPwrText and PowerRoleAllowed(settings.healerOnlyPower, frame))
	end
	if frame.NameText then frame.NameText:SetShown(settings.showName)  end
	if frame.HpText   then frame.HpText:SetShown(settings.showHpText) end
end

function GroupFrames.ApplyBarTextures(child, settings)
	local texture = ResolveTexture(settings.statusbarTexture)
	if child.Health then
		child.Health:SetStatusBarTexture(texture)
		if child.Health.bg      then child.Health.bg:SetTexture(texture)      end
		if child.Health.Deficit then child.Health.Deficit:SetTexture(texture) end
	end
	if child.Power then
		child.Power:SetStatusBarTexture(texture)
		if child.Power.bg then child.Power.bg:SetTexture(texture) end
	end
end

local EvaluateColorValueFromBoolean = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean

local function RangeOverride(self)
	local unit = self.unit
	if not unit then return end
	local element = self.Range

	if UnitIsUnit(unit, "player") then
		self:SetAlpha(element.insideAlpha)
		return
	end
	if not UnitIsConnected(unit) then
		self:SetAlpha(element.fadeOffline and element.outsideAlpha or element.insideAlpha)
		return
	end
	if not element.rangeFade then
		self:SetAlpha(element.insideAlpha)
		return
	end

	local inRange = UnitInRange(unit)
	if not IsSecret(inRange) then
		self:SetAlpha(inRange and element.insideAlpha or element.outsideAlpha)
	elseif EvaluateColorValueFromBoolean then
		self:SetAlpha(EvaluateColorValueFromBoolean(inRange, element.insideAlpha, element.outsideAlpha))
	else
		self:SetAlphaFromBoolean(inRange, element.insideAlpha, element.outsideAlpha)
	end
end

local function BuildRangeFade(frame, unit)
	if unit == "player" then return end
	local rangeSettings = GroupFrames.GetDB().range
	frame.Range = {
		insideAlpha  = rangeSettings.insideAlpha,
		outsideAlpha = rangeSettings.outsideAlpha,
		rangeFade    = rangeSettings.enabled,
		fadeOffline  = rangeSettings.fadeOffline,
		Override     = RangeOverride,
	}
	frame:RegisterEvent("UNIT_PHASE", RangeOverride)
	frame:RegisterEvent("UNIT_FLAGS", RangeOverride)
end

function GroupFrames.RefreshRange()
	local rangeSettings = GroupFrames.GetDB().range
	local function ApplyToChild(child)
		local range = child.Range
		if not range then return end
		range.insideAlpha  = rangeSettings.insideAlpha
		range.outsideAlpha = rangeSettings.outsideAlpha
		range.rangeFade    = rangeSettings.enabled
		range.fadeOffline  = rangeSettings.fadeOffline
		child:UpdateAllElements("BluRangeRefresh")
	end
	GroupFrames.EachChild(ApplyToChild)
end

local CLICK_MODES = {
	down = { "AnyDown" },
	up   = { "AnyUp" },
	both = { "AnyDown", "AnyUp" },
}

local function SetClicks(frame, mode)
	if frame._bluClicksMode == mode then return end
	frame:RegisterForClicks(unpack(CLICK_MODES[mode]))
	frame._bluClicksMode = mode
end

function GroupFrames.RefreshClickMode()
	GroupFrames.AfterCombat(function()
		local mode = GroupFrames.GetDB().clickMode
		GroupFrames.EachChild(function(child) SetClicks(child, mode) end)
	end, "GF.ClickMode")
end

local function ApplySecureClicks(frame)
	if InCombatLockdown() then GroupFrames.AfterCombat(function() ApplySecureClicks(frame) end, "GF.SecureClicks:" .. tostring(frame)); return end
	if frame:GetFrameStrata() ~= "LOW" then frame:SetFrameStrata("LOW") end
	SetClicks(frame, GroupFrames.GetDB().clickMode)
end

local function HookTooltip(frame)
	frame:HookScript("OnEnter", function(self)
		local settings = GroupFrames.SettingsForFrame(self)
		if not settings.showUnitTooltips or not self.unit or not UnitExists(self.unit) then return end
		if GetMouseFoci()[1] ~= self then return end
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetUnit(self.unit)
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function GroupFrameStyle(frame, unit)
	C_Timer.After(0, function() ApplySecureClicks(frame) end)
	frame:HookScript("OnShow", function(self)
		if self._bluClicksMode == GroupFrames.GetDB().clickMode and self:GetFrameStrata() == "LOW" then return end
		C_Timer.After(0, function() ApplySecureClicks(self) end)
	end)

	HookTooltip(frame)

	BuildBackdrop(frame, unit)
	BuildHealth(frame, unit)
	BuildPower(frame, unit)
	BuildText(frame, unit)
	BuildAbsorb(frame, unit)
	GroupFrames.BuildIndicators(frame, unit)
	GroupFrames.BuildSelection(frame, unit)
	BuildRangeFade(frame, unit)
	GroupFrames.BuildKeystone(frame, unit)

	GroupFrames.ApplyGeometry(frame, GroupFrames.SettingsForFrame(frame))
	if frame:GetAttribute("unit") then
		GroupFrames.BuildAuraContainers(frame, unit)
		GroupFrames.AttachReachabilityHooks(frame)
	else
		frame:HookScript("OnAttributeChanged", function(self, name, value)
			if name ~= "unit" or not value or self._auraWatcher then return end
			C_Timer.After(0, function() GroupFrames.FinishChildAuraSetup(self) end)
		end)
	end
end

GroupFrames.Style = GroupFrameStyle
