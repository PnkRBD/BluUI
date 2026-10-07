local _, BUI = ...

local Wrap = BUI.Profiler.Wrap

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

local kindCandidates = {}

local function KindCandidates(kind)
	local polarity = KIND_POLARITY[kind]
	local blacklist = BUI.AuraBlacklist.GroupSet(polarity)
	local cached = kindCandidates[kind]
	if cached and cached.source == blacklist then return cached.candidates, cached.fingerprint end

	local exclude = {}
	for spellID in pairs(blacklist) do
		exclude[spellID] = true
	end
	if polarity == "HELPFUL" then
		for spellID in pairs(GroupFrames.AuraRegistry.flatRaidBuffs) do
			exclude[spellID] = true
		end
	end

	cached = { source = blacklist, fingerprint = '' }
	if next(exclude) ~= nil then
		cached.candidates = { excludeSpellIDs = exclude }
		cached.fingerprint = 'bl:' .. Engine.SortedKeys(exclude)
	end
	kindCandidates[kind] = cached
	return cached.candidates, cached.fingerprint
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
updateDriver:SetScript("OnUpdate", Wrap("GroupFrames.Auras flush", function(self)
	local startTime = debugprofilestop()
	for frame in pairs(dirtyFrames) do
		dirtyFrames[frame] = nil
		if frame.unit then GroupFrames.RefreshFrameAuras(frame) end
		if debugprofilestop() - startTime > AURA_FLUSH_BUDGET_MS then return end
	end
	if next(dirtyFrames) == nil then self:Hide() end
end))

function GroupFrames.MarkAurasDirty(frame)
	dirtyFrames[frame] = true
	updateDriver:Show()
end

function GroupFrames.SyncLifeState(frame, dead, offline)
	if frame._bluWasDead == dead and frame._bluWasOffline == offline then return end
	frame._bluWasDead, frame._bluWasOffline = dead, offline
end

function GroupFrames.RefreshFrameAuras(frame)
	local unit = frame.unit
	if not unit then return end
	GroupFrames.UpdateDispelBorder(frame, unit)
	GroupFrames.SyncLifeState(frame, UnitIsDeadOrGhost(unit) and true or false, not UnitIsConnected(unit))
end

local function ResetFrameAuras(frame, unit)
	if frame.DispelBadge then frame.DispelBadge:Hide() end
	frame._dispelColor = nil
	BindAllKinds(frame, unit)
end

local function RegisterAuraUnitEvents(watcher, unit)
	if unit then watcher:RegisterUnitEvent("UNIT_AURA", unit)
	else watcher:UnregisterEvent("UNIT_AURA") end
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

local function BuildAuraContainers(frame)
	local settings = GroupFrames.SettingsForFrame(frame)

	for kindIndex = 1, #KIND_LIST do
		ApplyKind(frame, settings, KIND_LIST[kindIndex])
	end
	if GroupFrames.DispelViaEngine then GroupFrames.ConfigureDispelHighlight(frame) end

	local watcher = frame._auraWatcher
	if not watcher then
		watcher = CreateFrame("Frame", nil, frame)
		frame._auraWatcher = watcher
		watcher:SetScript("OnEvent", Wrap("GroupFrames.Auras aura event", function(_, event, _, updateInfo)
			if event == "UNIT_AURA" then
				if AuraUpdateRelevant(frame, updateInfo) then GroupFrames.MarkAurasDirty(frame) end
				return
			end
			if event == "PLAYER_ENTERING_WORLD" then ResetFrameAuras(frame, frame.unit) end
			GroupFrames.MarkAurasDirty(frame)
		end))
		watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	end
	frame._bluLastUnit = frame.unit or frame:GetAttribute("unit")
	RegisterAuraUnitEvents(watcher, frame._bluLastUnit)

	BindAllKinds(frame, frame.unit)
	GroupFrames.MarkAurasDirty(frame)
end

function GroupFrames.RefreshDispelBorder(frame, settings)
	if GroupFrames.DispelViaEngine then
		if frame._auraWatcher then GroupFrames.ConfigureDispelHighlight(frame) end
		return
	end
	if frame.unit then GroupFrames.UpdateDispelBorder(frame, frame.unit) end
end

local function IsReachable(unit)
	local connected, visible, assist = UnitIsConnected(unit), UnitIsVisible(unit), UnitCanAssist("player", unit)
	if not (CanAccess(connected) and CanAccess(visible) and CanAccess(assist)) then return false end
	return (connected and visible and assist) and true or false
end

local function ReparseShown(frame)
	for kindIndex = 1, #KIND_LIST do
		local container = frame[KIND_KEYS[KIND_LIST[kindIndex]]]
		if container and container:IsShown() then container:UpdateAllAuras() end
	end
	local highlight = frame[GroupFrames.DISPEL_HL_KEY]
	if highlight and highlight:IsShown() then highlight:UpdateAllAuras() end
end

local function reflowAuraVisibility(frame)
	local unit = frame.unit
	if not unit then return end
	local isVisible = IsReachable(unit)
	local wasHidden = frame._bluAurasVisible == false
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
	if isVisible and wasHidden then ReparseShown(frame) end
end
GroupFrames.ReflowAuraVisibility = reflowAuraVisibility

local REACHABILITY_EVENTS = {}
for _, event in ipairs({ "UNIT_CONNECTION", "UNIT_PHASE", "UNIT_FACTION", "UNIT_IN_RANGE_UPDATE", "UNIT_DISTANCE_CHECK_UPDATE" }) do
	if C_EventUtils.IsEventValid(event) then REACHABILITY_EVENTS[#REACHABILITY_EVENTS + 1] = event end
end

local ReflowOnEvent = Wrap("GroupFrames.Auras reachability event", reflowAuraVisibility)
local ReflowOnShow  = Wrap("GroupFrames.Auras show reflow", reflowAuraVisibility)

local function AttachReachabilityHooks(frame)
	for eventIndex = 1, #REACHABILITY_EVENTS do
		frame:RegisterEvent(REACHABILITY_EVENTS[eventIndex], ReflowOnEvent)
	end
	frame:HookScript("OnShow", ReflowOnShow)
	frame._bluAurasVisible = nil
	reflowAuraVisibility(frame)
end

local REACHABILITY_SWEEP_SECONDS = 1
local reachabilityTicker

local function SweepIfVisible(child)
	if child:IsVisible() then reflowAuraVisibility(child) end
end

local SweepReachability = Wrap("GroupFrames.Auras reachability sweep", function()
	GroupFrames.EachChild(SweepIfVisible)
end)

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

local function FinishChildAuraSetup(child)
	if child._auraWatcher or not child:GetAttribute("unit") then return end
	BuildAuraContainers(child)
	AttachReachabilityHooks(child)
end

local pendingSetup = {}
local SETUP_BUDGET_MS = 4

local setupDriver = CreateFrame("Frame")
setupDriver:Hide()
setupDriver:SetScript("OnUpdate", Wrap("GroupFrames.Auras staggered setup", function(self)
	if not GroupFrames.CanBuildChildren() then
		self:Hide()
		return
	end
	local startTime = debugprofilestop()
	for child in pairs(pendingSetup) do
		pendingSetup[child] = nil
		FinishChildAuraSetup(child)
		if debugprofilestop() - startTime > SETUP_BUDGET_MS then return end
	end
	self:Hide()
end))

function GroupFrames.QueueChildAuraSetup(child)
	if child._auraWatcher or not child:GetAttribute("unit") then return end
	pendingSetup[child] = true
	setupDriver:Show()
end

function GroupFrames.RebindAuraUnit(frame, unit)
	local watcher = frame._auraWatcher
	if not watcher then
		GroupFrames.QueueChildAuraSetup(frame)
		return
	end
	if unit == frame._bluLastUnit then return end
	frame._bluLastUnit = unit
	ResetFrameAuras(frame, unit)
	RegisterAuraUnitEvents(watcher, unit)
	GroupFrames.MarkAurasDirty(frame)
end

local function FinishPendingChildren()
	GroupFrames.EachChild(function(child)
		GroupFrames.QueueChildAuraSetup(child)
		if child.unit then GroupFrames.MarkAurasDirty(child) end
	end)
end

BUI.Tools.OnAuraQueriesUnblocked(FinishPendingChildren, 'Group frame auras')
BUI.Events:Register("PLAYER_REGEN_ENABLED", "GroupFrames.FinishChildren", function()
	BUI.Events:AfterCombatSettled(FinishPendingChildren, "GroupFrames.FinishChildren")
end)
