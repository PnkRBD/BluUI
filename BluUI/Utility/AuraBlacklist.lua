local _, BUI = ...

local AuraBlacklist = {}
BUI.AuraBlacklist = AuraBlacklist

local POL_KEY = { HARMFUL = 'debuff', HELPFUL = 'buff' }

local RECENT_CAP = 24

local curatedCache

function AuraBlacklist.Curated(polarity)
	if not curatedCache then
		local registry = BUI.GroupFrames.AuraRegistry
		local harmful = {}
		for _, set in ipairs({ registry.debuffBlacklist, registry.satedIDs, registry.deserterIDs, registry.skyridingIDs }) do
			for spellID in pairs(set) do harmful[spellID] = true end
		end
		curatedCache = { HARMFUL = harmful, HELPFUL = {} }
	end
	return curatedCache[polarity]
end

local function Overrides(polarity)
	return BUI.GetDB().groupFrames.blacklistOverrides[POL_KEY[polarity]]
end

local function UnitFilters()
	return BUI.GetDB().auraFilters
end

local function UnitOwn(polarity)
	local filters = UnitFilters()
	return polarity == 'HARMFUL' and filters.debuffBlacklist or filters.buffBlacklist
end

local function FrameOwn(polarity)
	return BUI.GetDB().buffFrames.blacklist[POL_KEY[polarity]]
end

local function OwnStore(scope, polarity)
	if scope == 'frames' then return FrameOwn(polarity) end
	return UnitOwn(polarity)
end

function AuraBlacklist.IsShared()
	return UnitFilters().shareBlacklists == true
end

local function EditsSharedStore(scope)
	if scope == 'frames' then return false end
	return scope == 'group' or AuraBlacklist.IsShared()
end

local setCache = {}

function AuraBlacklist.Invalidate()
	wipe(setCache)
end

function AuraBlacklist.GroupSet(polarity)
	local set = setCache[polarity]
	if not set then
		set = {}
		for spellID in pairs(AuraBlacklist.Curated(polarity)) do set[spellID] = true end
		for spellID, mode in pairs(Overrides(polarity)) do
			if mode == 'hide' then set[spellID] = true
			elseif mode == 'show' then set[spellID] = nil end
		end
		setCache[polarity] = set
	end
	return set
end

function AuraBlacklist.UnitSet(polarity)
	if AuraBlacklist.IsShared() then return AuraBlacklist.GroupSet(polarity) end
	return UnitOwn(polarity)
end

function AuraBlacklist.FrameSet(polarity)
	return FrameOwn(polarity)
end

function AuraBlacklist.Set(scope, polarity)
	if scope == 'group' then return AuraBlacklist.GroupSet(polarity) end
	if scope == 'frames' then return AuraBlacklist.FrameSet(polarity) end
	return AuraBlacklist.UnitSet(polarity)
end

function AuraBlacklist.HidesOnFriendly(spellID, polarity)
	return polarity == 'HELPFUL' or C_Secrets.GetSpellAuraSecrecy(spellID) == Enum.SecrecyLevel.NeverSecret
end

function AuraBlacklist.IsGroupBlacklisted(spellID, polarity)
	return AuraBlacklist.GroupSet(polarity)[spellID] == true
end

function AuraBlacklist.UserAdd(scope, polarity, spellID)
	if EditsSharedStore(scope) then
		local overrides = Overrides(polarity)
		if AuraBlacklist.Curated(polarity)[spellID] then overrides[spellID] = nil
		else overrides[spellID] = 'hide' end
	else
		OwnStore(scope, polarity)[spellID] = true
	end
	AuraBlacklist.Invalidate()
end

function AuraBlacklist.UserRemove(scope, polarity, spellID)
	if EditsSharedStore(scope) then
		Overrides(polarity)[spellID] = nil
	else
		OwnStore(scope, polarity)[spellID] = nil
	end
	AuraBlacklist.Invalidate()
end

function AuraBlacklist.SetBuiltInHidden(polarity, spellID, hidden)
	local overrides = Overrides(polarity)
	if hidden then
		overrides[spellID] = nil
	else
		overrides[spellID] = 'show'
	end
	AuraBlacklist.Invalidate()
end

function AuraBlacklist.SetShared(on)
	local filters = UnitFilters()
	on = on and true or false
	if filters.shareBlacklists == on then return end
	filters.shareBlacklists = on
	if on then
		for polarity in pairs(POL_KEY) do
			for spellID, active in pairs(UnitOwn(polarity)) do
				if active then AuraBlacklist.UserAdd('group', polarity, spellID) end
			end
		end
	end
	AuraBlacklist.Invalidate()
end

function AuraBlacklist.ShowsBuiltIns(scope, polarity)
	return EditsSharedStore(scope) and next(AuraBlacklist.Curated(polarity)) ~= nil
end

function AuraBlacklist.UserEntries(scope, polarity)
	local entries = {}
	if EditsSharedStore(scope) then
		local curated = AuraBlacklist.Curated(polarity)
		for spellID, mode in pairs(Overrides(polarity)) do
			if mode == 'hide' and not curated[spellID] then entries[#entries + 1] = spellID end
		end
	else
		for spellID, active in pairs(OwnStore(scope, polarity)) do
			if active then entries[#entries + 1] = spellID end
		end
	end
	return entries
end

function AuraBlacklist.BuiltInEntries(polarity)
	local entries = {}
	local overrides = Overrides(polarity)
	for spellID in pairs(AuraBlacklist.Curated(polarity)) do
		entries[#entries + 1] = { id = spellID, hidden = overrides[spellID] ~= 'show' }
	end
	return entries
end

local function RecentStore(polarity)
	return BUI.GetDB().recentAuras[POL_KEY[polarity]]
end

local UNIT_SCAN = { 'player', 'pet', 'target', 'targettarget', 'focus', 'boss1', 'boss2', 'boss3', 'boss4', 'boss5' }
local FRAME_SCAN = { 'player' }

local function ScanUnits(scope)
	if scope == 'frames' then return FRAME_SCAN end
	if scope ~= 'group' then return UNIT_SCAN end
	local units = { 'player' }
	local prefix, count = 'party', GetNumSubgroupMembers()
	if IsInRaid() then prefix, count = 'raid', GetNumGroupMembers() end
	for memberIndex = 1, count do units[#units + 1] = prefix .. memberIndex end
	return units
end

local function RecordAura(list, spellID)
	for listIndex = #list, 1, -1 do
		if list[listIndex] == spellID then table.remove(list, listIndex) end
	end
	table.insert(list, 1, spellID)
end

function AuraBlacklist.RecordUnitAuras(scope, polarity)
	if BUI.Tools.ShouldAurasBeSecret() or BUI.Tools.AuraQueriesBlocked() then return end
	local list = RecentStore(polarity)
	local filter = polarity == 'HARMFUL' and 'HARMFUL|INCLUDE_NAME_PLATE_ONLY' or 'HELPFUL'
	local seen, found = {}, {}
	for _, unit in ipairs(ScanUnits(scope)) do
		local auras = UnitExists(unit) and C_UnitAuras.GetUnitAuras(unit, filter, 40, 0, 0)
		if auras then
			for auraIndex = 1, #auras do
				local spellID = auras[auraIndex].spellId
				if canaccessvalue(spellID) and type(spellID) == 'number' and not seen[spellID] then
					seen[spellID] = true
					found[#found + 1] = spellID
				end
			end
		end
	end
	for foundIndex = #found, 1, -1 do RecordAura(list, found[foundIndex]) end
	for listIndex = #list, RECENT_CAP + 1, -1 do list[listIndex] = nil end
end

function AuraBlacklist.RecentEntries(scope, polarity)
	local list = RecentStore(polarity)
	local set = AuraBlacklist.Set(scope, polarity)
	local entries = {}
	for listIndex = 1, #list do
		local spellID = list[listIndex]
		if not set[spellID] then entries[#entries + 1] = spellID end
	end
	return entries
end

function AuraBlacklist.RefreshConsumers(scope)
	AuraBlacklist.Invalidate()
	if scope ~= 'frames' then
		local shared = AuraBlacklist.IsShared()
		if (scope ~= 'unit' or shared) and BUI.GroupFrames.IsActive() then
			BUI.GroupFrames.Refresh()
		end
		if (scope ~= 'group' or shared) and BUI.IsModuleEnabled('unitFrames') then
			BUI.UnitFrames.InvalidateFilterCache()
			BUI.UnitFrames:Refresh()
		end
	end
	if scope == 'frames' then BUI.BuffFrames.Refresh() end
end
