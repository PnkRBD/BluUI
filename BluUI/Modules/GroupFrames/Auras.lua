local _, BUI = ...

local GroupFrames = BUI.GroupFrames
local Util   = GroupFrames.Util
local Pixel  = BUI.Pixel
local AuraRules = BUI.AuraRules
local Engine = BUI.AuraEngine

local CreateFrame       = CreateFrame
local UnitIsVisible     = UnitIsVisible
local UnitIsConnected   = UnitIsConnected
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
	debuffs      = { "bossAura", "priorityDebuff" },
	bigDef       = { "bigDefensive", "externalDefensive" },
	crowdControl = { "crowdControl" },
}

local KIND_LIST = { "buffs", "debuffs", "bigDef", "crowdControl" }

local KIND_KEYS = {}
for kindIndex = 1, #KIND_LIST do KIND_KEYS[KIND_LIST[kindIndex]] = "BluAura_" .. KIND_LIST[kindIndex] end

local EXCLUDED_BY = {
	buffs   = "bigDef",
	debuffs = "crowdControl",
}

local EXCLUDE_SOURCES = {}
for _, source in pairs(EXCLUDED_BY) do EXCLUDE_SOURCES[source] = true end

function GroupFrames.ContainerRules(config, kind)
	local rules = AuraRules.EnsureRules(config, 'rules', KIND_POLARITY[kind], DEFAULT_RULES[kind])
	if EXCLUDE_SOURCES[kind] then AuraRules.DropSortRules(rules) end
	return rules
end

function GroupFrames.FeedsExclusions(kind)
	return EXCLUDE_SOURCES[kind] == true
end

local BLACK_COLOR = { 0, 0, 0, 1 }

local kindCandidates = {}

local function KindPins(kind)
	if kind ~= "buffs" then return nil, '' end
	local db = GroupFrames.GetDB()
	if next(db.buffPins) == nil then return nil, '' end
	return db.buffPins, (db.buffPinsOnly and 'only:' or 'pin:') .. Engine.SortedKeys(db.buffPins)
end

local function KindCandidates(kind, settings)
	local polarity = KIND_POLARITY[kind]
	local blacklist = BUI.AuraBlacklist.GroupSet(polarity)
	local pins, pinSig = KindPins(kind)
	local hots, hotSig
	if kind == "buffs" then hots, hotSig = GroupFrames.HotSlots.ExcludedSpells(settings) end
	local cacheKey = hotSig and (kind .. hotSig) or kind
	local cached = kindCandidates[cacheKey]
	if cached and cached.source == blacklist and cached.pinSig == pinSig then return cached.candidates, cached.fingerprint end

	cached = { source = blacklist, pinSig = pinSig, fingerprint = '' }
	kindCandidates[cacheKey] = cached
	if pins and GroupFrames.GetDB().buffPinsOnly then
		cached.candidates = { includeSpellIDs = pins }
		cached.fingerprint = pinSig
		return cached.candidates, cached.fingerprint
	end

	local exclude = {}
	for spellID in pairs(blacklist) do
		exclude[spellID] = true
	end
	if polarity == "HELPFUL" then
		for spellID in pairs(GroupFrames.AuraRegistry.flatRaidBuffs) do
			exclude[spellID] = true
		end
	end
	if pins then
		for spellID in pairs(pins) do exclude[spellID] = true end
	end

	if next(exclude) ~= nil or hots then
		cached.candidates = { pinSpellIDs = pins, excludeSpellIDs = next(exclude) and exclude or nil, ownExcludeSpellIDs = hots }
		cached.fingerprint = pinSig .. 'bl:' .. Engine.SortedKeys(exclude) .. (hots and ('own:' .. hotSig) or '')
	end
	return cached.candidates, cached.fingerprint
end

local function KindExcludes(settings, kind)
	local source = EXCLUDED_BY[kind]
	if source and settings[source].enabled then
		return GroupFrames.ContainerRules(settings[source], source)
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
		sortMethod     = Engine.ResolveSortMethod(config.sortMethod),
		baseColor      = BLACK_COLOR,
		showDispelType = KIND_POLARITY[kind] == "HARMFUL",
		showStack      = true,
		stackSize      = config.stackSize,
		stackPos       = "BOTTOMRIGHT",
		showCd         = true,
		cdSize         = 11,
		decimals       = config.showCooldownDecimals and config.cooldownDecimalThreshold or 0,
		reverseSwipe   = true,
		showTooltips   = settings.showAuraTooltips,
		font           = STANDARD_TEXT_FONT,
		fontFlags      = "OUTLINE",
	}
end

local function BindAllKinds(frame, unit)
	for _, key in pairs(KIND_KEYS) do
		local container = frame[key]
		if container then Engine.BindUnit(container, unit) end
	end
	Engine.BindUnit(frame[GroupFrames.DISPEL_HL_KEY], unit)
	GroupFrames.HotSlots.Bind(frame, unit)
end

local function ApplyKind(frame, settings, kind)
	local config = settings[kind]
	local key = KIND_KEYS[kind]
	local container = frame[key]

	if not config.enabled then
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

	local candidates, candidateFingerprint = KindCandidates(kind, settings)
	Engine.Configure(container, KindStyle(settings, kind), GroupFrames.ContainerRules(config, kind), BASE_FILTER[KIND_POLARITY[kind]], candidates, candidateFingerprint, KindExcludes(settings, kind))

	container:ClearAllPoints()
	container:SetPoint(config.anchorPoint, frame, config.relativePoint, Pixel.Scale(config.offsetX), Pixel.Scale(config.offsetY))
	container:Show()
	Engine.BindUnit(container, frame.unit)
end

function GroupFrames.SyncLifeState(frame, dead, offline)
	local ghost = false
	if dead and frame.unit then
		local isGhost = UnitIsGhost(frame.unit)
		ghost = CanAccess(isGhost) and isGhost and true or false
	end
	if frame._bluWasDead == dead and frame._bluWasOffline == offline and frame._bluWasGhost == ghost then return end
	frame._bluWasDead, frame._bluWasOffline, frame._bluWasGhost = dead, offline, ghost
	local status = frame.StatusText
	if status.UpdateTag then status:UpdateTag() end
end

local dirtyFrames = {}

local FlushDirtyFrames = BUI.Dispatcher.New(function()
	for frame in pairs(dirtyFrames) do
		dirtyFrames[frame] = nil
		local unit = frame.unit
		if unit then GroupFrames.SyncLifeState(frame, UnitIsDeadOrGhost(unit) and true or false, not UnitIsConnected(unit)) end
	end
end)

function GroupFrames.MarkAurasDirty(frame)
	dirtyFrames[frame] = true
	FlushDirtyFrames()
end

function GroupFrames.RewireAuraEvents(frame, unit)
	if not frame._bluAurasBuilt then return end
	BindAllKinds(frame, unit)
	GroupFrames.MarkAurasDirty(frame)
end

local function BuildAuraContainers(frame)
	local settings = GroupFrames.SettingsForFrame(frame)

	for kindIndex = 1, #KIND_LIST do
		ApplyKind(frame, settings, KIND_LIST[kindIndex])
	end
	GroupFrames.HotSlots.Apply(frame, settings)
	GroupFrames.ConfigureDispelHighlight(frame)

	frame._bluAurasBuilt = true
	frame._bluLastUnit = frame.unit or frame:GetAttribute("unit")

	BindAllKinds(frame, frame.unit)
	GroupFrames.MarkAurasDirty(frame)
end

local function RebindOnWorldEntry(child)
	GroupFrames.RewireAuraEvents(child, child.unit)
end

BUI.Events:Register("PLAYER_ENTERING_WORLD", "GroupFrames.AuraRebind", function()
	GroupFrames.EachChild(RebindOnWorldEntry)
end)

function GroupFrames.RefreshDispelBorder(frame)
	if frame._bluAurasBuilt then GroupFrames.ConfigureDispelHighlight(frame) end
end

local function IsReachable(unit)
	local connected, visible, assist = UnitIsConnected(unit), UnitIsVisible(unit), UnitCanAssist("player", unit)
	if not (CanAccess(connected) and CanAccess(visible) and CanAccess(assist)) then return false end
	return (connected and visible and assist) and true or false
end

local function reflowAuraVisibility(frame)
	local unit = frame.unit
	if not unit then return end
	local isVisible = IsReachable(unit)
	if frame._bluAurasVisible == isVisible then return end
	frame._bluAurasVisible = isVisible
	local settings = GroupFrames.SettingsForFrame(frame)
	for kindIndex = 1, #KIND_LIST do
		local kind = KIND_LIST[kindIndex]
		local container = frame[KIND_KEYS[kind]]
		if container then container:SetShown(isVisible and settings[kind].enabled) end
	end
	GroupFrames.HotSlots.SetVisible(frame, isVisible)
	local highlight = frame[GroupFrames.DISPEL_HL_KEY]
	if highlight and not frame._dispelPreview then
		highlight:SetShown(isVisible and GroupFrames.DispelHighlightWanted(settings))
	end
end
GroupFrames.ReflowAuraVisibility = reflowAuraVisibility

local REACHABILITY_EVENTS = { "UNIT_CONNECTION", "UNIT_PHASE", "UNIT_FACTION", "UNIT_IN_RANGE_UPDATE", "UNIT_DISTANCE_CHECK_UPDATE" }

local reflowAuraVisibility  = reflowAuraVisibility

local function AttachReachabilityHooks(frame)
	for eventIndex = 1, #REACHABILITY_EVENTS do
		frame:RegisterEvent(REACHABILITY_EVENTS[eventIndex], reflowAuraVisibility)
	end
	frame:HookScript("OnShow", reflowAuraVisibility)
	frame._bluAurasVisible = nil
	reflowAuraVisibility(frame)
end

local REACHABILITY_SWEEP_SECONDS = 1
local reachabilityTicker

local function SweepIfVisible(child)
	if child:IsVisible() then reflowAuraVisibility(child) end
end

local SweepReachability = function()
	GroupFrames.EachChild(SweepIfVisible)
end

function GroupFrames.SyncReachabilitySweep()
	local wanted = GroupFrames.IsActive() and GroupFrames.GetDB().enabled and IsInGroup()
	if wanted and not reachabilityTicker then
		reachabilityTicker = C_Timer.NewTicker(REACHABILITY_SWEEP_SECONDS, SweepReachability)
	elseif not wanted and reachabilityTicker then
		reachabilityTicker:Cancel()
		reachabilityTicker = nil
	end
end

BUI.Events:Register("GROUP_ROSTER_UPDATE", "GroupFrames.ReachabilitySweep", GroupFrames.SyncReachabilitySweep)
BUI.Events:Register("PLAYER_ENTERING_WORLD", "GroupFrames.ReachabilitySweep", GroupFrames.SyncReachabilitySweep)

local function ApplyAurasToChild(child)
	if not child._bluAurasBuilt then return end
	local settings = GroupFrames.SettingsForFrame(child)
	for kindIndex = 1, #KIND_LIST do
		ApplyKind(child, settings, KIND_LIST[kindIndex])
	end
	GroupFrames.HotSlots.Apply(child, settings)
	GroupFrames.ConfigureDispelHighlight(child)

	child._bluAurasVisible = nil
	reflowAuraVisibility(child)
end

function GroupFrames.RefreshAuras(section)
	if section ~= "raid"  then GroupFrames.EachPartyChild(ApplyAurasToChild) end
	if section ~= "party" then GroupFrames.EachRaidChild(ApplyAurasToChild) end
end

function GroupFrames.FinishChildAuraSetup(child)
	if child._bluAurasBuilt or not child:GetAttribute("unit") or not GroupFrames.CanBuildChildren() then return end
	BuildAuraContainers(child)
	AttachReachabilityHooks(child)
end

function GroupFrames.RebindAuraUnit(frame, unit)
	if not frame._bluAurasBuilt then
		GroupFrames.FinishChildAuraSetup(frame)
		return
	end
	if unit == frame._bluLastUnit then return end
	frame._bluLastUnit = unit
	BindAllKinds(frame, unit)
	GroupFrames.MarkAurasDirty(frame)
end
