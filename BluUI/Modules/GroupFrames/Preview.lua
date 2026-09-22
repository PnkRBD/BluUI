local _, BUI = ...

local GroupFrames = BUI.GroupFrames

local UnregisterUnitWatch = UnregisterUnitWatch
local RegisterUnitWatch   = RegisterUnitWatch
local AbbreviateNumbers   = AbbreviateNumbers
local InCombatLockdown    = InCombatLockdown

local floor  = math.floor
local format = string.format

local PREVIEW_FRAMES_PER_HEADER = 5

local TANKS = {
	{ name = "Bolvar",   class = "DEATHKNIGHT", powerType = "RUNIC_POWER", maxPower = 100 },
	{ name = "Turalyon", class = "PALADIN",     powerType = "MANA",        maxPower = 520000 },
	{ name = "Broll",    class = "DRUID",       powerType = "RAGE",        maxPower = 100 },
	{ name = "Kayn",     class = "DEMONHUNTER", powerType = "FURY",        maxPower = 120 },
}

local HEALERS = {
	{ name = "Tyrande",   class = "PRIEST",  powerType = "MANA", maxPower = 540000 },
	{ name = "Malfurion", class = "DRUID",   powerType = "MANA", maxPower = 530000 },
	{ name = "Uther",     class = "PALADIN", powerType = "MANA", maxPower = 520000 },
	{ name = "Kalecgos",  class = "EVOKER",  powerType = "MANA", maxPower = 510000 },
}

local DAMAGERS = {
	{ name = "Valeera", class = "ROGUE",       powerType = "ENERGY", maxPower = 100 },
	{ name = "Jaina",   class = "MAGE",        powerType = "MANA",   maxPower = 500000 },
	{ name = "Rexxar",  class = "HUNTER",      powerType = "FOCUS",  maxPower = 100 },
	{ name = "Illidan", class = "DEMONHUNTER", powerType = "FURY",   maxPower = 120 },
	{ name = "Thrall",  class = "SHAMAN",      powerType = "MANA",   maxPower = 500000 },
	{ name = "Varian",  class = "WARRIOR",     powerType = "RAGE",   maxPower = 100 },
	{ name = "Chen",    class = "MONK",        powerType = "ENERGY", maxPower = 100 },
	{ name = "Khadgar", class = "MAGE",        powerType = "MANA",   maxPower = 500000 },
}

local SLOTS = {
	{ role = "TANK",    pool = TANKS,    poolShift = 0, health = 0.58, power = 0.52, absorb = 0.22, maxHealth = 12400000, leader = true },
	{ role = "HEALER",  pool = HEALERS,  poolShift = 0, health = 0.92, power = 0.61, absorb = 0,    maxHealth = 8800000 },
	{ role = "DAMAGER", pool = DAMAGERS, poolShift = 0, health = 1.00, power = 0.27, absorb = 0,    maxHealth = 9300000 },
	{ role = "DAMAGER", pool = DAMAGERS, poolShift = 3, health = 0.71, power = 0.86, absorb = 0.13, maxHealth = 9000000 },
	{ role = "DAMAGER", pool = DAMAGERS, poolShift = 5, health = 0.44, power = 0.59, absorb = 0,    maxHealth = 8600000 },
}

local OFF_GROUP_TANK_SLOT = { role = "DAMAGER", pool = DAMAGERS, poolShift = 7, health = 0.83, power = 0.44, absorb = 0, maxHealth = 9200000 }

local HEALTH_SHIFT = { 0, -0.12, 0.05, -0.21, 0.02, -0.06, 0.11, -0.16 }
local POWER_SHIFT  = { 0, 0.14, -0.09, 0.22, -0.18, 0.07, -0.24, 0.12 }

local decoyCache = {}

local function Clamp(value, low, high)
	if value < low then return low end
	if value > high then return high end
	return value
end

local function DecoyFor(slotIndex, headerIndex)
	local cacheKey = slotIndex * 1000 + headerIndex
	local decoy = decoyCache[cacheKey]
	if decoy then return decoy end

	local slot = SLOTS[slotIndex]
	if slot.role == "TANK" and headerIndex > 1 then slot = OFF_GROUP_TANK_SLOT end
	local member = slot.pool[((slot.poolShift + headerIndex - 1) % #slot.pool) + 1]
	local shiftIndex = ((headerIndex - 1) % #HEALTH_SHIFT) + 1

	decoy = {
		name      = member.name,
		class     = member.class,
		role      = slot.role,
		powerType = member.powerType,
		maxPower  = member.maxPower,
		maxHealth = slot.maxHealth,
		leader    = slot.leader,
		health    = Clamp(slot.health + HEALTH_SHIFT[shiftIndex], 0.12, 1),
		power     = Clamp(slot.power + POWER_SHIFT[shiftIndex], 0.08, 1),
		absorb    = slot.absorb,
	}
	decoyCache[cacheKey] = decoy
	return decoy
end

local function HealthValue(decoy) return floor(decoy.health * decoy.maxHealth) end
local function PowerValue(decoy)  return floor(decoy.power  * decoy.maxPower)  end
local function AbsorbValue(decoy) return floor(decoy.absorb * decoy.maxHealth) end

local PREVIEW_TAGS = {
	["blu:name"]   = function(decoy) return decoy.name end,
	["blu:status"] = function() return "" end,
	["blu:hp"]     = function(decoy) return AbbreviateNumbers(HealthValue(decoy)) end,
	["blu:hpmax"]  = function(decoy) return AbbreviateNumbers(decoy.maxHealth) end,
	["blu:hppct"]  = function(decoy) return format("%d%%", decoy.health * 100 + 0.5) end,
	["blu:pwr"]    = function(decoy) return AbbreviateNumbers(PowerValue(decoy)) end,
	["blu:pwrmax"] = function(decoy) return AbbreviateNumbers(decoy.maxPower) end,
	["blu:pwrpct"] = function(decoy) return format("%d%%", decoy.power * 100 + 0.5) end,
	["blu:hpmissing"] = function(decoy)
		local missing = decoy.maxHealth - HealthValue(decoy)
		if missing <= 0 then return "" end
		return AbbreviateNumbers(missing)
	end,
	["blu:absorb"] = function(decoy)
		local absorb = AbsorbValue(decoy)
		if absorb <= 0 then return "" end
		return AbbreviateNumbers(absorb)
	end,
}

local function PreviewText(formatString, decoy)
	if not formatString or formatString == "" then return "" end
	return (formatString:gsub("%[([^%]]+)%]", function(tagName)
		local handler = PREVIEW_TAGS[tagName]
		if not handler then return "[" .. tagName .. "]" end
		return handler(decoy)
	end))
end

local LIVE_ELEMENTS = { "Health", "Power", "BluHpTextDirect" }

local function DisableLiveElements(child)
	for elementIndex = 1, #LIVE_ELEMENTS do
		local elementName = LIVE_ELEMENTS[elementIndex]
		if child:IsElementEnabled(elementName) then child:DisableElement(elementName) end
	end
end

local function PaintText(child, decoy, settings)
	local nameText = child.NameText
	if nameText then
		child:Untag(nameText)
		nameText:SetText(decoy.name)
	end

	local hpText = child.HpText
	if hpText then
		child:Untag(hpText)
		hpText:SetText(PreviewText(GroupFrames.InjectAbsorbColor(settings.hpText.format, settings.absorbColor), decoy))
	end

	local statusText = child.StatusText
	if statusText then
		child:Untag(statusText)
		statusText:SetText("")
	end

	local powerText = child.PowerText
	if powerText then
		child:Untag(powerText)
		powerText:SetText(PreviewText(settings.pwrText.format, decoy))
	end
end

local function PaintBars(child, decoy, settings)
	local health = child.Health
	if health then
		health:SetMinMaxValues(0, 1)
		health:SetValue(decoy.health)
		health:Show()
		health._inOffline = nil
		if health.PostUpdateColor then health.PostUpdateColor(health, child.unit) end
	end

	local absorb = child.Absorb
	if absorb then
		absorb:SetMinMaxValues(0, 1)
		absorb:SetValue(decoy.absorb)
		absorb:SetShown(settings.absorb.enabled and decoy.absorb > 0)
	end
	if child.HealAbsorb then child.HealAbsorb:Hide() end

	local power = child.Power
	if power then
		power:SetMinMaxValues(0, 1)
		power:SetValue(decoy.power)
		local color = BUI.oUF.colors.power[decoy.powerType]
		if color and color.GetRGB then
			local red, green, blue = color:GetRGB()
			power:SetStatusBarColor(red, green, blue)
			if power.bg then
				power.bg:SetVertexColor(red * power.bg.multiplier, green * power.bg.multiplier, blue * power.bg.multiplier)
			end
		end
	end
end

function GroupFrames.RepaintPreviewChild(child)
	local decoy = child._previewDecoy
	if not child._preview or not decoy then return end
	local settings = GroupFrames.SettingsForFrame(child)
	DisableLiveElements(child)
	PaintText(child, decoy, settings)
	PaintBars(child, decoy, settings)
end

local active = { party = false, raid = false }

local function ForceChild(child, slotIndex, headerIndex)
	local decoy = DecoyFor(slotIndex, headerIndex)
	child._previewRole  = decoy.role
	child._previewClass = decoy.class
	child._previewDecoy = decoy

	DisableLiveElements(child)

	local entering = not child._preview
	if entering then
		child._preview = true
		UnregisterUnitWatch(child)
		child:EnableMouse(false)
		if not child:GetAttribute("unit") then
			child._previewSavedUnit = child.unit
			child._previewSavedRawUnit = child.__unit
			child.unit = "player"
			child.__unit = "player"
			child._previewInjectedUnit = true
		end
		child:Show()
	end

	local settings = GroupFrames.SettingsForFrame(child)
	GroupFrames.ApplyGeometry(child, settings)
	GroupFrames.ApplyFrameColors(child, settings, child.unit)
	GroupFrames.ApplyTextColors(child, settings)
	child:UpdateAllElements("BluPreview")

	if entering then
		GroupFrames.RewireAuraEvents(child, child.unit)
		GroupFrames.ApplyPrivateAuras(child)
	end

	GroupFrames.RepaintPreviewChild(child)
end

local function UnforceChild(child)
	child._previewRole  = nil
	child._previewClass = nil
	child._previewDecoy = nil
	child._txtClass     = nil
	if not child._preview then return end
	child._preview = nil
	child:EnableMouse(true)
	if child._previewInjectedUnit then
		child._previewInjectedUnit = nil
		local attributeUnit = child:GetAttribute("unit")
		child.unit = attributeUnit or child._previewSavedUnit
		child.__unit = attributeUnit or child._previewSavedRawUnit
		child._previewSavedUnit = nil
		child._previewSavedRawUnit = nil
	end
	RegisterUnitWatch(child)
	GroupFrames.RewireAuraEvents(child, child.unit)

	if not child:IsElementEnabled("Health") then
		child:EnableElement("Health", child:GetAttribute("oUF-guessUnit"))
	end

	local settings = GroupFrames.SettingsForFrame(child)
	GroupFrames.ApplyGeometry(child, settings)
	GroupFrames.ApplyFrameColors(child, settings, child.unit)
	GroupFrames.ApplyAbsorbToChild(child, settings)
	GroupFrames.ApplyTextToChild(child, settings)

	GroupFrames.ApplyPrivateAuras(child)
	if child.unit then child:UpdateAllElements("BluPreview") end
end

local function CountActiveChildren(header)
	local activeCount = 0
	GroupFrames.ForEachHeaderChild(header, function(child)
		if child:GetAttribute("unit") then activeCount = activeCount + 1 end
	end)
	return activeCount
end

local function SetHeaderForced(header, forced, headerIndex)
	if forced then
		header:SetAttribute("startingIndex", CountActiveChildren(header) - (PREVIEW_FRAMES_PER_HEADER - 1))
		local slot = 0
		GroupFrames.ForEachHeaderChild(header, function(child)
			slot = slot + 1
			if slot <= PREVIEW_FRAMES_PER_HEADER then
				ForceChild(child, slot, headerIndex)
			else
				UnforceChild(child)
			end
		end)
	else
		GroupFrames.ForEachHeaderChild(header, UnforceChild)
		header:SetAttribute("startingIndex", 1)
	end
end

function GroupFrames.SyncPreviewChildren()
	if not active.party and not active.raid then return end
	if InCombatLockdown() then
		GroupFrames.AfterCombat(GroupFrames.SyncPreviewChildren, "GF.SyncPreview")
		return
	end
	if active.party and GroupFrames.headers.party then
		SetHeaderForced(GroupFrames.headers.party, true, 1)
	end
	if active.raid then
		local headers = GroupFrames.PreviewRaidHeaders() or GroupFrames.headers.raid
		if headers then
			for groupIndex = 1, #headers do SetHeaderForced(headers[groupIndex], true, groupIndex) end
		end
	end
end

local function ApplyPartyPreview(enabled)
	local header = GroupFrames.headers.party
	if not header or active.party == enabled then return end
	active.party = enabled
	if enabled then
		GroupFrames.ApplyPartyVisibility()
		SetHeaderForced(header, true, 1)
		GroupFrames.ReapplyIndicatorPreviews()
		GroupFrames.ReapplyAuraPreviews()
	else
		SetHeaderForced(header, false, 1)
		GroupFrames.ApplyPartyVisibility()
	end
end

local function ApplyRaidPreview(enabled)
	if active.raid == enabled then return end
	if enabled then
		local headers = GroupFrames.PreviewRaidHeaders() or GroupFrames.headers.raid
		if not headers then return end
		active.raid = true
		GroupFrames.ApplyRaidVisibility()
		for groupIndex = 1, #headers do SetHeaderForced(headers[groupIndex], true, groupIndex) end
		GroupFrames.ReapplyIndicatorPreviews()
		GroupFrames.ReapplyAuraPreviews()
	else
		local headers = GroupFrames.AllRaidHeaders()
		active.raid = false
		for groupIndex = 1, #headers do SetHeaderForced(headers[groupIndex], false, groupIndex) end
		GroupFrames.ApplyRaidVisibility()
	end
end

function GroupFrames.SetPartyPreview(enabled)
	GroupFrames.AfterCombat(function() ApplyPartyPreview(enabled) end, "GF.PartyPreview")
end

function GroupFrames.SetRaidPreview(enabled)
	GroupFrames.AfterCombat(function() ApplyRaidPreview(enabled) end, "GF.RaidPreview")
end

function GroupFrames.IsPartyPreviewShown() return active.party end
function GroupFrames.IsRaidPreviewShown()  return active.raid  end

function GroupFrames.TogglePartyPreview() GroupFrames.SetPartyPreview(not active.party) end
function GroupFrames.ToggleRaidPreview()  GroupFrames.SetRaidPreview(not active.raid)   end
