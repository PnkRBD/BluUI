local _, BUI = ...

local UnitFrames = BUI.UnitFrames
local Pixel = BUI.Pixel
local AuraBlacklist = BUI.AuraBlacklist
local Engine = BUI.AuraEngine

local pairs, ipairs = pairs, ipairs

local UnitExists = UnitExists

local DEBUFF_BASE_COLOR = { 0.8, 0, 0, 1 }
local BUFF_BASE_COLOR = { 0, 0, 0, 1 }

local filterCache
local debuffWhitelistActive, buffWhitelistActive = false, false
local candidateCache = {}

local function GetFilters()
	if not filterCache then
		local db = BUI.GetDB()
		filterCache = db and db.auraFilters or {}
		debuffWhitelistActive = (filterCache.debuffWhitelist and next(filterCache.debuffWhitelist)) ~= nil
		buffWhitelistActive   = (filterCache.buffWhitelist   and next(filterCache.buffWhitelist))   ~= nil
	end
	return filterCache
end

function UnitFrames.InvalidateFilterCache()
	filterCache = nil
	wipe(candidateCache)
end

local DEBUFF_FILTER = 'HARMFUL|INCLUDE_NAME_PLATE_ONLY'
local BUFF_FILTER = 'HELPFUL'

local SHOWMODE_TO_RULES = {
	debuff = {
		all            = { 'allHarmful' },
		mine           = { 'mineHarmful' },
		dispellable    = { 'dispellable' },
		allDispellable = { 'anyDispellable' },
		blizzardRaid   = { 'allHarmful' },
	},
	buff = {
		all     = { 'allHelpful' },
		mine    = { 'mineHelpful' },
		mineAll = { 'mineHelpful' },
		raid    = { 'raidRelevant' },
	},
}

local function UnitRules(unitSettings, isDebuff)
	local key = isDebuff and 'debuffRules' or 'buffRules'
	local rules = unitSettings[key]
	if type(rules) == 'table' then return rules end
	local map = isDebuff and SHOWMODE_TO_RULES.debuff or SHOWMODE_TO_RULES.buff
	local mode = isDebuff and (unitSettings.debuffShowMode or 'all') or (unitSettings.buffShowMode or 'all')
	local from = map[mode] or { isDebuff and 'allHarmful' or 'allHelpful' }
	rules = {}
	for ruleIndex = 1, #from do rules[ruleIndex] = from[ruleIndex] end
	unitSettings[key] = rules
	return rules
end
UnitFrames.GetAuraRules = UnitRules

local function MigrateDebuffSettings(settings, unitType)
	if unitType == 'player' and not settings.playerBuffRulesNarrowed then
		settings.playerBuffRulesNarrowed = true
		local buffRules = settings.buffRules
		if type(buffRules) == 'table' and #buffRules == 1 and buffRules[1] == 'mineHelpful' then
			buffRules[1] = 'mineRaidCombat'
		end
	end

	if not settings.debuffShowMode then
		local mode = settings.debuffFilter
		if mode then
			settings.debuffOnlyMine = (mode == 'mine' or mode == 'myimportant')
			settings.debuffImportant = (mode == 'important' or mode == 'myimportant')
			settings.debuffFilter = nil
		end
		if settings.onlyPlayerDebuffs then
			settings.debuffOnlyMine = true
			settings.onlyPlayerDebuffs = nil
		end

		if settings.debuffOnlyMine then
			settings.debuffShowMode = 'mine'
		elseif settings.onlyDispellableDebuffs then
			settings.debuffShowMode = 'dispellable'
		else
			settings.debuffShowMode = 'all'
		end
		settings.debuffImportant = nil
		settings.debuffOnlyMine  = nil
		settings.onlyDispellableDebuffs = nil
	end

	if not settings.buffShowMode then
		if settings.onlyPlayerBuffs then
			settings.buffShowMode = settings.buffImportant and 'mine' or 'mineAll'
		elseif settings.buffImportant then
			settings.buffShowMode = 'raid'
		else
			settings.buffShowMode = 'all'
		end
		settings.onlyPlayerBuffs = nil
		settings.buffImportant   = nil
	end
end

local function GetAuraSetting(settings, isDebuff, debuffKey, buffKey, globalKey, fallback)
	local specificKey = isDebuff and debuffKey or buffKey
	local value = settings[specificKey]
	if value ~= nil then return value end
	if globalKey then
		value = settings[globalKey]
		if value ~= nil then return value end
	end
	return fallback
end

local GrowthToAnchor = Engine.GrowthToAnchor

local function ResolveStyle(settings, isDebuff)
	local style = {}
	if isDebuff then
		style.size   = settings.debuffIconSize or settings.auraIconSize or 24
		style.gap    = settings.debuffSpacing or settings.auraSpacing or 2
		style.perRow = settings.debuffsPerRow or settings.maxDebuffs or 8
		style.max    = settings.maxDebuffs or 16
		style.growX  = settings.debuffGrowthX
		style.growY  = settings.debuffGrowthY
		style.anchorTo = settings.debuffAnchorPoint
		style.offsetX = settings.debuffOffsetX
		style.offsetY = settings.debuffOffsetY
		style.shown  = settings.showDebuffs
		style.baseColor = DEBUFF_BASE_COLOR
		style.showDispelType = settings.showDebuffType ~= false
	else
		style.size   = settings.buffIconSize or settings.auraIconSize or 20
		style.gap    = settings.buffSpacing or settings.auraSpacing or 2
		style.perRow = settings.buffsPerRow or settings.maxBuffs or 8
		style.max    = settings.maxBuffs or 8
		style.growX  = settings.buffGrowthX or 'RIGHT'
		style.growY  = settings.buffGrowthY or 'DOWN'
		style.anchorTo = settings.buffAnchorPoint or 'BOTTOMLEFT'
		style.offsetX = settings.buffOffsetX or 0
		style.offsetY = settings.buffOffsetY or 0
		style.shown  = settings.showBuffs
		style.baseColor = BUFF_BASE_COLOR
		style.showDispelType = false
	end
	style.sortMethod = Engine.ResolveSortMethod(GetAuraSetting(settings, isDebuff, 'debuffSortMethod', 'buffSortMethod', 'auraSortMethod', 'default'))
	style.showStack = GetAuraSetting(settings, isDebuff, 'debuffShowStack', 'buffShowStack', 'auraShowStack', true)
	style.stackSize = GetAuraSetting(settings, isDebuff, 'debuffStackSize', 'buffStackSize', 'auraStackSize', 10)
	style.stackPos  = GetAuraSetting(settings, isDebuff, 'debuffStackPos', 'buffStackPos', nil, 'BOTTOMRIGHT')
	style.showCd    = GetAuraSetting(settings, isDebuff, 'debuffShowCd', 'buffShowCd', 'auraShowCd', true)
	style.cdSize    = GetAuraSetting(settings, isDebuff, 'debuffCdSize', 'buffCdSize', 'auraCdSize', 10)
	style.reverseSwipe = settings.auraReverseSwipe
	style.padding = 0
	style.showTooltips = settings.showTooltips ~= false
	style.font = UnitFrames.GetFont()
	return style
end

UnitFrames.ResolveAuraStyle = ResolveStyle

local AURA_FLOWS = {
	debuffsOnBuffs    = { debuffsFollow = true, stacked = true },
	buffsOnDebuffs    = { debuffsFollow = false, stacked = true },
	debuffsAfterBuffs = { debuffsFollow = true },
	buffsAfterDebuffs = { debuffsFollow = false },
}

local function StackEdge(style)
	return (style.growY == 'UP' and 'TOP' or 'BOTTOM') .. (style.growX == 'RIGHT' and 'LEFT' or 'RIGHT')
end

function UnitFrames.ResolveAuraFlow(unitSettings, debuffStyle, buffStyle)
	local flow = AURA_FLOWS[unitSettings.auraFlow]
	if not flow then return end
	local follower, leader = buffStyle, debuffStyle
	if flow.debuffsFollow then follower, leader = debuffStyle, buffStyle end
	if not (follower.shown and leader.shown) then return end
	if flow.stacked then follower.growX, follower.growY = leader.growX, leader.growY end
	return follower, leader, flow.stacked
end

function UnitFrames.StackAuras(follower, leader, followerFrame, leaderFrame)
	local gap = leader.growY == 'UP' and leader.gap or -leader.gap
	followerFrame:ClearAllPoints()
	followerFrame:SetPoint(GrowthToAnchor(follower.growX, follower.growY), leaderFrame, StackEdge(leader), 0, Pixel.Scale(gap))
end

local auraFrames = {}

local function BuildCandidates(isDebuff)
	local cached = candidateCache[isDebuff]
	if cached then return cached.candidates, cached.fingerprint end

	local filters = GetFilters()
	local candidates, fingerprint

	local blacklist = AuraBlacklist.UnitSet(isDebuff and 'HARMFUL' or 'HELPFUL')
	local whitelist, whitelistActive, whitelistOnly
	if isDebuff then
		whitelist, whitelistActive = filters.debuffWhitelist, debuffWhitelistActive
		whitelistOnly = filters.debuffWhitelistOnly
	else
		whitelist, whitelistActive = filters.buffWhitelist, buffWhitelistActive
		whitelistOnly = filters.buffWhitelistOnly
	end

	if whitelistActive and whitelistOnly then
		candidates = { includeSpellIDs = whitelist }
		fingerprint = 'wl:' .. Engine.SortedKeys(whitelist)
	else
		local exclude
		if whitelistActive then
			exclude = {}
			for spellID in pairs(whitelist) do exclude[spellID] = true end
			fingerprint = 'pin:' .. Engine.SortedKeys(whitelist)
		end
		if next(blacklist) then
			exclude = exclude or {}
			for spellID in pairs(blacklist) do exclude[spellID] = true end
			local blacklistFingerprint = 'bl:' .. Engine.SortedKeys(blacklist)
			fingerprint = fingerprint and (fingerprint .. '+' .. blacklistFingerprint) or blacklistFingerprint
		end
		if exclude then
			candidates = { pinSpellIDs = whitelistActive and whitelist or nil, excludeSpellIDs = exclude }
		end
	end

	candidateCache[isDebuff] = { candidates = candidates, fingerprint = fingerprint or '' }
	return candidates, fingerprint or ''
end

local UNIT_CONTAINER_KEYS = { 'DebuffContainer', 'BuffContainer', '_dispelFrameHL' }

local function BindUnit(frame, rebind)
	local unit = frame.unit
	if not unit then return end
	for _, key in ipairs(UNIT_CONTAINER_KEYS) do
		local container = frame[key]
		if container and (container._buiUnit or container:IsShown()) then
			if rebind then
				Engine.RebindUnit(container, unit)
			else
				Engine.BindUnit(container, unit)
			end
		end
	end
end

local EnsureEventlessTicker
local targetTargetFrames = {}

local function CreateAuraElements(frame, unitType)
	frame.DebuffContainer = Engine.NewContainer(frame, true)
	frame.BuffContainer = Engine.NewContainer(frame, false)
	frame.DebuffContainer._buiScope = 'unit'
	frame.BuffContainer._buiScope = 'unit'
	auraFrames[#auraFrames + 1] = { frame = frame, unitType = unitType }
	if unitType == 'targettarget' then targetTargetFrames[frame] = true end
end

local TargetTargetShown = BUI.Profiler.Wrap('UnitFrames.Auras targettarget show', function(shownFrame)
	BindUnit(shownFrame, true)
	EnsureEventlessTicker()
end)

BUI.oUF:RegisterInitCallback(function(frame)
	if targetTargetFrames[frame] then frame:HookScript('OnShow', TargetTargetShown) end
end)

local NO_RULES = {}

local function AuraSet(unitSettings, style, isDebuff)
	local candidates, candidatesFingerprint = BuildCandidates(isDebuff)
	return { style, UnitRules(unitSettings, isDebuff), isDebuff and DEBUFF_FILTER or BUFF_FILTER, candidates, candidatesFingerprint }
end

local function ApplyContainer(container, unitSettings, style)
	container:SetShown(style.shown)
	Engine.ConfigureSets(container, { AuraSet(unitSettings, style, container._buiIsDebuff) })
end

local function PlaceContainer(frame, container, style)
	container:ClearAllPoints()
	container:SetPoint(GrowthToAnchor(style.growX, style.growY), frame, style.anchorTo, Pixel.Scale(style.offsetX), Pixel.Scale(style.offsetY))
end

local function ApplyAuraPositions(frame, unitType)
	local unitSettings = UnitFrames.GetUnitSettings(unitType)
	MigrateDebuffSettings(unitSettings, unitType)

	local debuffs, buffs = frame.DebuffContainer, frame.BuffContainer
	local debuffStyle = ResolveStyle(unitSettings, true)
	local buffStyle = ResolveStyle(unitSettings, false)
	local follower, leader, stacked = UnitFrames.ResolveAuraFlow(unitSettings, debuffStyle, buffStyle)
	debuffs._buiOnHatch, buffs._buiOnHatch = nil, nil
	if follower and not stacked then
		local leaderIsDebuff = leader == debuffStyle
		local host = leaderIsDebuff and debuffs or buffs
		local idle = leaderIsDebuff and buffs or debuffs
		host:Show()
		Engine.ConfigureSets(host, { AuraSet(unitSettings, leader, leaderIsDebuff), AuraSet(unitSettings, follower, not leaderIsDebuff) })
		idle:Hide()
		Engine.Configure(idle, follower, NO_RULES, idle._buiIsDebuff and DEBUFF_FILTER or BUFF_FILTER)
		PlaceContainer(frame, host, leader)
	else
		ApplyContainer(debuffs, unitSettings, debuffStyle)
		ApplyContainer(buffs, unitSettings, buffStyle)
		PlaceContainer(frame, debuffs, debuffStyle)
		PlaceContainer(frame, buffs, buffStyle)
		if follower then
			local followerContainer = follower == debuffStyle and debuffs or buffs
			local leaderContainer = followerContainer == debuffs and buffs or debuffs
			local function Stack()
				if next(followerContainer._buiGroups) then UnitFrames.StackAuras(follower, leader, followerContainer, leaderContainer) end
			end
			followerContainer._buiOnHatch = Stack
			Stack()
		end
	end

	BindUnit(frame)
end

local function RefreshAuraLayout(frame, unitType)
	if not frame then return end
	ApplyAuraPositions(frame, unitType)
end

local function PokeFrames(matchTypes, rebind)
	for _, entry in ipairs(auraFrames) do
		local frame = entry.frame
		if matchTypes[entry.unitType] and frame:IsEnabled() and frame.unit and UnitExists(frame.unit) then
			BindUnit(frame, rebind)
		end
	end
end

local eventlessTicker
local PollEventlessUnits = BUI.Profiler.Wrap('UnitFrames.Auras eventless poll', function()
	local active = false
	for _, entry in ipairs(auraFrames) do
		if entry.unitType == 'targettarget' and entry.frame:IsVisible() then
			active = true
			BindUnit(entry.frame)
		end
	end
	if not active and eventlessTicker then
		eventlessTicker:Cancel()
		eventlessTicker = nil
	end
end)
function EnsureEventlessTicker()
	if eventlessTicker then return end
	for _, entry in ipairs(auraFrames) do
		if entry.unitType == 'targettarget' and entry.frame:IsVisible() then
			eventlessTicker = C_Timer.NewTicker(0.5, PollEventlessUnits)
			return
		end
	end
end

BUI.Events:Register('PLAYER_TARGET_CHANGED', 'UFAuras.Target', function()
	PokeFrames({ target = true, targettarget = true }, true)
	EnsureEventlessTicker()
end)
BUI.Events:Register('PLAYER_FOCUS_CHANGED', 'UFAuras.Focus', function()
	PokeFrames({ focus = true }, true)
end)
BUI.Events:RegisterUnit('UNIT_TARGET', 'target', 'UFAuras.TargetOfTarget', function()
	PokeFrames({ targettarget = true }, true)
end)
BUI.Events:RegisterUnit('UNIT_FACTION', { 'target', 'focus' }, 'UFAuras.Reaction', function()
	PokeFrames({ target = true, focus = true })
end)
BUI.Events:Register('INSTANCE_ENCOUNTER_ENGAGE_UNIT', 'UFAuras.Boss', function()
	PokeFrames({ boss = true }, true)
end)
BUI.Events:RegisterUnit('UNIT_PET', 'player', 'UFAuras.Pet', function()
	PokeFrames({ pet = true }, true)
end)

UnitFrames.CreateAuraElements = CreateAuraElements
UnitFrames.RefreshAuraLayout = RefreshAuraLayout
