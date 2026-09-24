local _, BUI = ...

local GroupFrames = BUI.GroupFrames
local Util   = GroupFrames.Util
local Pixel  = BUI.Pixel
local AuraRules = BUI.AuraRules
local Engine = BUI.AuraEngine

local CreateFrame       = CreateFrame
local UnitIsVisible     = UnitIsVisible
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCanAssist     = UnitCanAssist
local CanAccess         = Util.CanAccess

local BASE_FILTER = {
	HELPFUL = "HELPFUL",
	HARMFUL = "HARMFUL|INCLUDE_NAME_PLATE_ONLY",
}

local KIND_POLARITY = {
	buffs        = "HELPFUL",
	debuffs      = "HARMFUL",
	bigDef       = "HELPFUL",
	crowdControl = "HARMFUL",
}

local DEFAULT_RULES = {
	buffs        = { "raidRelevant" },
	debuffs      = { "bossAura" },
	bigDef       = { "bigDefensive", "externalDefensive" },
	crowdControl = { "crowdControl" },
}

local KIND_LIST = { "buffs", "debuffs", "bigDef", "crowdControl" }

local KIND_KEYS = {}
for kindIndex = 1, #KIND_LIST do KIND_KEYS[KIND_LIST[kindIndex]] = "BluAura_" .. KIND_LIST[kindIndex] end

function GroupFrames.ContainerRules(config, kind)
	return AuraRules.EnsureRules(config, KIND_POLARITY[kind], DEFAULT_RULES[kind])
end

local function isBlacklistedDebuff(spellID)
	if not spellID or not CanAccess(spellID) then return false end
	return BUI.AuraBlacklist.IsGroupBlacklisted(spellID, "HARMFUL")
end
GroupFrames.IsBlacklistedDebuff = isBlacklistedDebuff

function GroupFrames.BuildDispelCurve(zeroColor)
	return Engine.BuildDispelCurve(zeroColor)
end

local BLACK_COLOR = { 0, 0, 0, 1 }

local function KindCandidates(kind)
	local polarity = KIND_POLARITY[kind]
	local exclude = {}

	for spellID in pairs(BUI.AuraBlacklist.GroupSet(polarity)) do
		exclude[spellID] = true
	end
	if polarity == "HELPFUL" then
		for spellID in pairs(GroupFrames.AuraRegistry.flatRaidBuffs) do
			exclude[spellID] = true
		end
	end

	if next(exclude) == nil then return nil, '' end
	return { excludeSpellIDs = exclude }, 'bl:' .. Engine.SortedKeys(exclude)
end

local function KindSuffix(settings, kind)
	if kind == "buffs" and settings.bigDef.enabled then
		return AuraRules.ExcludeSuffix(GroupFrames.ContainerRules(settings.bigDef, "bigDef"))
	end
	if kind == "debuffs" and settings.crowdControl.enabled then
		return AuraRules.ExcludeSuffix(GroupFrames.ContainerRules(settings.crowdControl, "crowdControl"))
	end
end

local function KindStyle(settings, kind)
	local config = settings[kind]
	local growX, growY = Util.ResolveGrowth(config.anchorPoint, config.growDirection)
	return {
		size    = config.size,
		gap     = config.spacing,
		rowGap  = config.rowSpacing,
		perRow  = math.max(1, config.perRow),
		max     = config.max,
		growX   = growX,
		growY   = growY,
		sortMethod     = Engine.ResolveSortMethod(config.sortMethod or 'default'),
		baseColor      = BLACK_COLOR,
		showDispelType = KIND_POLARITY[kind] == "HARMFUL",
		showStack      = true,
		stackSize      = config.stackSize,
		stackPos       = "BOTTOMRIGHT",
		showCd         = true,
		cdSize         = 11,
		reverseSwipe   = true,
		showTooltips   = settings.showAuraTooltips and true or false,
		font           = STANDARD_TEXT_FONT,
		fontFlags      = "OUTLINE",
	}
end

local function BindAllKinds(frame, unit)
	for _, key in pairs(KIND_KEYS) do
		local container = frame[key]
		if container then Engine.BindUnit(container, unit) end
	end
	local highlight = frame[GroupFrames.DISPEL_HL_KEY]
	if highlight then Engine.BindUnit(highlight, unit) end
end

local function ApplyKind(frame, settings, kind)
	local config = settings[kind]
	local key = KIND_KEYS[kind]
	local container = frame[key]

	if not config.enabled or not Engine.Available then
		if container then
			container:Hide()
			Engine.BindUnit(container, nil)
		end
		return
	end

	if not container then
		container = Engine.NewContainer(frame, KIND_POLARITY[kind] == "HARMFUL", GroupFrames.Layers.auras)
		container._buiScope = "group"
		frame[key] = container
	end

	local candidates, candidateFingerprint = KindCandidates(kind)
	Engine.Configure(container, KindStyle(settings, kind), GroupFrames.ContainerRules(config, kind), BASE_FILTER[KIND_POLARITY[kind]], candidates, candidateFingerprint, KindSuffix(settings, kind))

	container:ClearAllPoints()
	container:SetPoint(config.anchorPoint, frame, config.relativePoint, Pixel.Scale(config.offsetX), Pixel.Scale(config.offsetY))
	container:Show()
	Engine.BindUnit(container, frame.unit)
end

local dirtyFrames = {}
local AURA_FLUSH_BUDGET_MS = 2
local debugprofilestop = debugprofilestop

local updateDriver = CreateFrame("Frame", "BUI_GroupAuraFlush")
updateDriver:Hide()
updateDriver:SetScript("OnUpdate", function(self)
	local startTime = debugprofilestop()
	for frame in pairs(dirtyFrames) do
		dirtyFrames[frame] = nil
		if frame.unit then GroupFrames.RefreshFrameAuras(frame) end
		if debugprofilestop() - startTime > AURA_FLUSH_BUDGET_MS then return end
	end
	if next(dirtyFrames) == nil then self:Hide() end
end)

function GroupFrames.MarkAurasDirty(frame)
	dirtyFrames[frame] = true
	updateDriver:Show()
end

function GroupFrames.RefreshFrameAuras(frame)
	local unit = frame.unit
	if not unit then return end
	GroupFrames.UpdateDispelBorder(frame, unit)

	local dead = UnitIsDeadOrGhost(unit) and true or false
	if frame._bluWasDead ~= dead then
		frame._bluWasDead = dead
		GroupFrames.NudgePrivateAuras(frame)
	end
end

local function ResetFrameAuras(frame, unit)
	if frame.DispelBadge then frame.DispelBadge:Hide() end
	frame._dispelColor = nil
	BindAllKinds(frame, unit)
end

local UNIT_AURA_EVENTS = { "UNIT_AURA", "UNIT_FLAGS", "UNIT_PHASE", "UNIT_CONNECTION" }

local function RegisterAuraUnitEvents(watcher, unit)
	for eventIndex = 1, #UNIT_AURA_EVENTS do
		if unit then watcher:RegisterUnitEvent(UNIT_AURA_EVENTS[eventIndex], unit)
		else      watcher:UnregisterEvent(UNIT_AURA_EVENTS[eventIndex]) end
	end
end

function GroupFrames.RewireAuraEvents(frame, unit)
	if not frame._auraWatcher then return end
	RegisterAuraUnitEvents(frame._auraWatcher, unit)
	BindAllKinds(frame, unit)
	GroupFrames.MarkAurasDirty(frame)
end

local function ListHasEntries(list)
	if not CanAccess(list) then return true end
	if list == nil then return false end
	local first = list[1]
	if not CanAccess(first) then return true end
	return first ~= nil
end

local function RecordAddedAuras(info)
	if not info then return end
	local added = info.addedAuras
	if not CanAccess(added) or not added then return end
	for auraIndex = 1, #added do
		local aura = added[auraIndex]
		if CanAccess(aura) and aura then
			local spellID, helpful = aura.spellId, aura.isHelpful
			if CanAccess(spellID) and CanAccess(helpful) and type(spellID) == "number" then
				BUI.AuraBlacklist.RecordAura(spellID, helpful and "HELPFUL" or "HARMFUL")
			end
		end
	end
end

local function AuraUpdateRelevant(frame, info)
	local unit = frame.unit
	if not unit then return false end
	if (UnitIsDeadOrGhost(unit) and true or false) ~= (frame._bluWasDead or false) then return true end
	if not info then return true end
	local isFullUpdate = info.isFullUpdate
	if not CanAccess(isFullUpdate) or isFullUpdate then return true end
	if not GroupFrames.DispelViaEngine and ListHasEntries(info.addedAuras) then return true end
	return not GroupFrames.DispelViaEngine and frame._dispelColor ~= nil
end

local warnedNoEngine = false

function GroupFrames.BuildAuraContainers(frame, unit)
	local settings = GroupFrames.SettingsForFrame(frame)

	if not Engine.Available and not warnedNoEngine then
		warnedNoEngine = true
		GroupFrames.Print("Aura displays need the AuraContainer API (12.x) and are disabled on this client.")
	end

	for kindIndex = 1, #KIND_LIST do
		ApplyKind(frame, settings, KIND_LIST[kindIndex])
	end
	if GroupFrames.DispelViaEngine then GroupFrames.ConfigureDispelHighlight(frame) end
	frame.dispelBorderEnabled = settings.dispelBorder.enabled

	local watcher = frame._auraWatcher
	if not watcher then
		watcher = CreateFrame("Frame", nil, frame)
		frame._auraWatcher = watcher
		watcher:SetScript("OnEvent", function(_, event, _, updateInfo)
			if event == "UNIT_AURA" then
				RecordAddedAuras(updateInfo)
				if AuraUpdateRelevant(frame, updateInfo) then GroupFrames.MarkAurasDirty(frame) end
				return
			end
			if event == "PLAYER_ENTERING_WORLD" then ResetFrameAuras(frame, frame.unit) end
			GroupFrames.MarkAurasDirty(frame)
		end)
		watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	end
	frame._bluLastUnit = frame.unit or frame:GetAttribute("unit")
	RegisterAuraUnitEvents(watcher, frame._bluLastUnit)

	if not frame._bluUnitHookInstalled then
		frame._bluUnitHookInstalled = true
		frame:HookScript("OnAttributeChanged", function(self, name, value)
			if name == "unit" and value ~= self._bluLastUnit then
				self._bluLastUnit = value
				ResetFrameAuras(self, value)
				RegisterAuraUnitEvents(self._auraWatcher, value)
				GroupFrames.MarkAurasDirty(self)
			end
		end)
	end

	BindAllKinds(frame, frame.unit)
	GroupFrames.MarkAurasDirty(frame)
end

function GroupFrames.RefreshDispelBorder(frame, settings)
	frame.dispelBorderEnabled = settings.dispelBorder.enabled
	if GroupFrames.DispelViaEngine then
		if frame._auraWatcher then GroupFrames.ConfigureDispelHighlight(frame) end
		return
	end
	if frame.unit then GroupFrames.UpdateDispelBorder(frame, frame.unit) end
end

local function reflowAuraVisibility(frame)
	local unit = frame.unit
	if not unit then return end
	local isVisible = (UnitIsVisible(unit) and UnitCanAssist("player", unit)) and true or false
	if frame._bluAurasVisible == isVisible then return end
	frame._bluAurasVisible = isVisible
	local settings = GroupFrames.SettingsForFrame(frame)
	for kindIndex = 1, #KIND_LIST do
		local kind = KIND_LIST[kindIndex]
		local container = frame[KIND_KEYS[kind]]
		if container then container:SetShown(isVisible and settings[kind].enabled and true or false) end
	end
	local highlight = frame[GroupFrames.DISPEL_HL_KEY]
	if highlight and not frame._dispelPreview then
		highlight:SetShown(isVisible and GroupFrames.DispelHighlightWanted(settings) and true or false)
	end
end
GroupFrames.ReflowAuraVisibility = reflowAuraVisibility

local REACHABILITY_EVENTS = {
	"UNIT_CONNECTION", "UNIT_PHASE", "UNIT_FACTION", "UNIT_IN_RANGE_UPDATE", "UNIT_DISTANCE_CHECK_UPDATE",
}

function GroupFrames.AttachReachabilityHooks(frame)
	local sink = CreateFrame("Frame", nil, frame)
	sink:SetScript("OnEvent", function(_, _, eventUnit)
		if eventUnit ~= frame.unit then return end
		reflowAuraVisibility(frame)
		if not frame._bluAurasVisible then return end
		for kindIndex = 1, #KIND_LIST do
			local container = frame[KIND_KEYS[KIND_LIST[kindIndex]]]
			if container and container:IsShown() and container.UpdateAllAuras then container:UpdateAllAuras() end
		end
	end)
	for _, event in ipairs(REACHABILITY_EVENTS) do
		if C_EventUtils.IsEventValid(event) then sink:RegisterEvent(event) end
	end
	frame:HookScript("OnShow", reflowAuraVisibility)
end

local function ApplyAurasToChild(child)
	if not child._auraWatcher then return end
	local settings = GroupFrames.SettingsForFrame(child)
	for kindIndex = 1, #KIND_LIST do
		ApplyKind(child, settings, KIND_LIST[kindIndex])
	end
	GroupFrames.RefreshDispelBorder(child, settings)

	child._bluAurasVisible = nil
	reflowAuraVisibility(child)
end

function GroupFrames.RefreshAuras(section)
	if section ~= "raid"  then GroupFrames.EachPartyChild(ApplyAurasToChild) end
	if section ~= "party" then GroupFrames.EachRaidChild(ApplyAurasToChild) end
end

function GroupFrames.FinishChildAuraSetup(child)
	if child._auraWatcher or not child:GetAttribute("unit") or not GroupFrames.CanBuildChildren() then return end
	GroupFrames.BuildAuraContainers(child, child.unit)
	GroupFrames.AttachReachabilityHooks(child)
end

local function FinishPendingChildren()
	GroupFrames.EachChild(function(child)
		GroupFrames.FinishChildAuraSetup(child)
		if child.unit then GroupFrames.MarkAurasDirty(child) end
	end)
end

BUI.Tools.OnAuraQueriesUnblocked(FinishPendingChildren)
BUI.Events:Register("PLAYER_REGEN_ENABLED", "GroupFrames.FinishChildren", function()
	BUI.Events:AfterCombatSettled(FinishPendingChildren, "GroupFrames.FinishChildren")
end)
