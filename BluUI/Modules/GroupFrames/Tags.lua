local _, BUI = ...

local GroupFrames   = BUI.GroupFrames
local oUF  = BUI.oUF
local Util = GroupFrames.Util
local Tools = BUI.Tools

local UnitHealth        = UnitHealth
local UnitHealthMax     = UnitHealthMax
local UnitPower         = UnitPower
local UnitPowerMax      = UnitPowerMax
local UnitName          = UnitName
local UnitIsConnected   = UnitIsConnected
local UnitIsDead        = UnitIsDead
local UnitIsGhost       = UnitIsGhost
local UnitIsAFK         = UnitIsAFK
local UnitIsDND         = UnitIsDND
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

local UnitHealthPercent   = UnitHealthPercent
local UnitPowerPercent    = UnitPowerPercent
local UnitHealthMissing   = UnitHealthMissing
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local CurveConstants      = CurveConstants
local C_StringUtil        = C_StringUtil
local AbbreviateNumbers   = AbbreviateNumbers

local IsSecret  = Util.IsSecret
local CanAccess = Util.CanAccess

local Methods = oUF.Tags.Methods
local Events  = oUF.Tags.Events

local HEALTH_EVENTS = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"
local STATUS_EVENTS = "UNIT_CONNECTION PLAYER_FLAGS_CHANGED UNIT_FLAGS"

local function SafeBoolean(value)
	if not CanAccess(value) then return nil end
	return value
end

local function HealthStatus(unit)
	if not unit then return nil end
	local connected = SafeBoolean(UnitIsConnected(unit)); if connected == false then return "Offline" end
	if SafeBoolean(UnitIsDead(unit))  then return "Dead"  end
	if SafeBoolean(UnitIsGhost(unit)) then return "Ghost" end
	if SafeBoolean(UnitIsAFK(unit))   then return "AFK"   end
	if SafeBoolean(UnitIsDND(unit))   then return "DND"   end
end

Methods["blu:status"] = function(unit)
	local status = HealthStatus(unit)
	if not status then return "" end
	return BUI.UnitFrames.StatusText(status)
end
Events["blu:status"] = STATUS_EVENTS

local SCALE_100 = CurveConstants.ScaleTo100

local function IsOffline(unit) return not unit or SafeBoolean(UnitIsConnected(unit)) == false end

Methods["blu:hp"] = function(unit)
	if IsOffline(unit) then return "" end
	return AbbreviateNumbers(UnitHealth(unit))
end
Events["blu:hp"] = HEALTH_EVENTS

Methods["blu:hpmax"] = function(unit)
	if IsOffline(unit) then return "" end
	return AbbreviateNumbers(UnitHealthMax(unit))
end
Events["blu:hpmax"] = "UNIT_MAXHEALTH UNIT_CONNECTION"

Methods["blu:hppct"] = function(unit)
	if IsOffline(unit) then return "" end
	local percent = UnitHealthPercent(unit, true, SCALE_100)
	if percent == nil then return "" end
	return ("%d%%"):format(percent)
end
Events["blu:hppct"] = HEALTH_EVENTS

Methods["blu:hpmissing"] = function(unit)
	if IsOffline(unit) then return "" end
	local missingHealth = UnitHealthMissing(unit)
	if IsSecret(missingHealth) then
		local text = C_StringUtil.TruncateWhenZero(missingHealth)
		if IsSecret(text) or text == "" then return text end
		return AbbreviateNumbers(missingHealth)
	end
	if missingHealth <= 0 then return "" end
	return AbbreviateNumbers(missingHealth)
end
Events["blu:hpmissing"] = HEALTH_EVENTS

Methods["blu:absorb"] = function(unit)
	if IsOffline(unit) then return "" end
	local absorb = UnitGetTotalAbsorbs(unit)
	if not IsSecret(absorb) and absorb <= 0 then return "" end
	return AbbreviateNumbers(absorb)
end
Events["blu:absorb"] = "UNIT_ABSORB_AMOUNT_CHANGED UNIT_CONNECTION"

Methods["blu:pwr"] = function(unit)
	if IsOffline(unit) then return "" end
	return AbbreviateNumbers(UnitPower(unit))
end
Events["blu:pwr"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_CONNECTION"

Methods["blu:pwrmax"] = function(unit)
	if IsOffline(unit) then return "" end
	return AbbreviateNumbers(UnitPowerMax(unit))
end
Events["blu:pwrmax"] = "UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_CONNECTION"

Methods["blu:pwrpct"] = function(unit)
	if IsOffline(unit) then return "" end
	local percent = UnitPowerPercent(unit, nil, true, SCALE_100)
	if percent == nil then return "" end
	return ("%d%%"):format(percent)
end
Events["blu:pwrpct"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_CONNECTION"

Methods["blu:name"] = function(unit)
	if not unit then return "" end
	local name = UnitName(unit)
	if not name or IsSecret(name) then return "" end
	local limit = GroupFrames.SettingsForFrame(_FRAME).nameMaxLength
	if limit > 0 then return Tools.TruncateName(name, limit) end
	return name
end
Events["blu:name"] = "UNIT_NAME_UPDATE"

local DIRECT_HP_FORMATS = { ["[blu:hppct]"] = true }

function GroupFrames.IsDirectHpFormat(format)
	return DIRECT_HP_FORMATS[format] == true
end

local function DirectHpUpdate(self, event, unit)
	if not unit or self.__unit ~= unit then return end
	local element = self.HpTextDirect
	if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
		element:SetText("")
		return
	end
	local percent = UnitHealthPercent(unit, true, SCALE_100)
	if percent == nil then
		element:SetText("")
		return
	end
	element:SetFormattedText("%.0f%%", percent)
end

local function DirectHpPath(self, ...)
	return (self.HpTextDirect.Override or DirectHpUpdate)(self, ...)
end

local function DirectHpForceUpdate(element)
	return DirectHpPath(element.__owner, "ForceUpdate", element.__owner.__unit)
end

local function DirectHpEnable(self)
	local element = self.HpTextDirect
	if not element then return end
	local settings = GroupFrames.SettingsForFrame(self)
	if not settings.showHpText or not GroupFrames.IsDirectHpFormat(settings.hpText.format) then return end
	element.__owner = self
	element.ForceUpdate = DirectHpForceUpdate
	self:RegisterEvent("UNIT_HEALTH", DirectHpPath)
	self:RegisterEvent("UNIT_MAXHEALTH", DirectHpPath)
	self:RegisterEvent("UNIT_CONNECTION", DirectHpPath)
	return true
end

local function DirectHpDisable(self)
	if not self.HpTextDirect then return end
	self:UnregisterEvent("UNIT_HEALTH", DirectHpPath)
	self:UnregisterEvent("UNIT_MAXHEALTH", DirectHpPath)
	self:UnregisterEvent("UNIT_CONNECTION", DirectHpPath)
end

oUF:AddElement("BluHpTextDirect", DirectHpPath, DirectHpEnable, DirectHpDisable)
