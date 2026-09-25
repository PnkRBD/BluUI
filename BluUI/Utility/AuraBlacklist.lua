local _, BUI = ...

local AuraBlacklist = {}
BUI.AuraBlacklist = AuraBlacklist

local POL_KEY = { HARMFUL = 'debuff', HELPFUL = 'buff' }

local RECENT_CAP = 24

local EMPTY = {}

local curatedCache

function AuraBlacklist.Curated(polarity)
	if not curatedCache then
		local registry = BUI.GroupFrames and BUI.GroupFrames.AuraRegistry
		if not registry then return EMPTY end
		local harmful = {}
		for _, set in ipairs({ registry.debuffBlacklist, registry.satedIDs, registry.deserterIDs, registry.skyridingIDs }) do
			for spellID in pairs(set) do harmful[spellID] = true end
		end
		curatedCache = { HARMFUL = harmful, HELPFUL = {} }
	end
	return curatedCache[polarity]
end

local function Overrides(polarity)
	local profile = BUI.GetDB()
	local db = profile and profile.groupFrames
	return db and db.blacklistOverrides and db.blacklistOverrides[POL_KEY[polarity]]
end

local function UnitFilters()
	local profile = BUI.GetDB()
	return profile and profile.auraFilters
end

local function UnitOwn(polarity)
	local filters = UnitFilters()
	if not filters then return nil end
	return polarity == 'HARMFUL' and filters.debuffBlacklist or filters.buffBlacklist
end

function AuraBlacklist.IsShared()
	local filters = UnitFilters()
	return (filters and filters.shareBlacklists) == true
end

local function EditsSharedStore(scope)
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
		local overrides = Overrides(polarity)
		if overrides then
			for spellID, mode in pairs(overrides) do
				if mode == 'hide' then set[spellID] = true
				elseif mode == 'show' then set[spellID] = nil end
			end
		end
		setCache[polarity] = set
	end
	return set
end

function AuraBlacklist.UnitSet(polarity)
	if AuraBlacklist.IsShared() then return AuraBlacklist.GroupSet(polarity) end
	return UnitOwn(polarity) or EMPTY
end

function AuraBlacklist.HidesOnFriendly(spellID, polarity)
	return polarity == 'HELPFUL' or C_Secrets.GetSpellAuraSecrecy(spellID) == Enum.SecrecyLevel.NeverSecret
end

function AuraBlacklist.IsGroupBlacklisted(spellID, polarity)
	return AuraBlacklist.GroupSet(polarity)[spellID] == true
end

function AuraBlacklist.IsUnitBlacklisted(spellID, isHarmful)
	return AuraBlacklist.UnitSet(isHarmful and 'HARMFUL' or 'HELPFUL')[spellID] == true
end

function AuraBlacklist.UserAdd(scope, polarity, spellID)
	if EditsSharedStore(scope) then
		local overrides = Overrides(polarity)
		if not overrides then return end
		if AuraBlacklist.Curated(polarity)[spellID] then overrides[spellID] = nil
		else overrides[spellID] = 'hide' end
	else
		local own = UnitOwn(polarity)
		if own then own[spellID] = true end
	end
	AuraBlacklist.Invalidate()
end

function AuraBlacklist.UserRemove(scope, polarity, spellID)
	if EditsSharedStore(scope) then
		local overrides = Overrides(polarity)
		if overrides then overrides[spellID] = nil end
	else
		local own = UnitOwn(polarity)
		if own then own[spellID] = nil end
	end
	AuraBlacklist.Invalidate()
end

function AuraBlacklist.SetBuiltInHidden(polarity, spellID, hidden)
	local overrides = Overrides(polarity)
	if not overrides then return end
	if hidden then
		overrides[spellID] = nil
	else
		overrides[spellID] = 'show'
	end
	AuraBlacklist.Invalidate()
end

function AuraBlacklist.SetShared(on)
	local filters = UnitFilters()
	if not filters then return end
	on = on and true or false
	if filters.shareBlacklists == on then return end
	filters.shareBlacklists = on
	if on then
		for polarity in pairs(POL_KEY) do
			local own = UnitOwn(polarity)
			if own then
				for spellID, active in pairs(own) do
					if active then AuraBlacklist.UserAdd('group', polarity, spellID) end
				end
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
		local overrides = Overrides(polarity)
		if overrides then
			for spellID, mode in pairs(overrides) do
				if mode == 'hide' and not curated[spellID] then entries[#entries + 1] = spellID end
			end
		end
	else
		local own = UnitOwn(polarity)
		if own then
			for spellID, active in pairs(own) do
				if active then entries[#entries + 1] = spellID end
			end
		end
	end
	return entries
end

function AuraBlacklist.BuiltInEntries(polarity)
	local entries = {}
	local overrides = Overrides(polarity)
	for spellID in pairs(AuraBlacklist.Curated(polarity)) do
		entries[#entries + 1] = { id = spellID, hidden = not (overrides and overrides[spellID] == 'show') }
	end
	return entries
end

local function RecentStore(polarity)
	local profile = BUI.GetDB()
	local recent = profile and profile.recentAuras
	return recent and recent[POL_KEY[polarity]]
end

function AuraBlacklist.RecordAura(spellID, polarity)
	if type(spellID) ~= 'number' then return end
	local list = RecentStore(polarity)
	if not list or list[1] == spellID then return end
	for listIndex = #list, 1, -1 do
		if list[listIndex] == spellID then table.remove(list, listIndex) end
	end
	table.insert(list, 1, spellID)
	for listIndex = #list, RECENT_CAP + 1, -1 do list[listIndex] = nil end
end

function AuraBlacklist.RecentEntries(scope, polarity)
	local list = RecentStore(polarity) or EMPTY
	local set = scope == 'group' and AuraBlacklist.GroupSet(polarity) or AuraBlacklist.UnitSet(polarity)
	local entries = {}
	for listIndex = 1, #list do
		local spellID = list[listIndex]
		if not set[spellID] then entries[#entries + 1] = spellID end
	end
	return entries
end

function AuraBlacklist.RefreshConsumers(scope)
	AuraBlacklist.Invalidate()
	local shared = AuraBlacklist.IsShared()
	local groupFrames = BUI.GroupFrames
	if (scope ~= 'unit' or shared) and groupFrames and groupFrames.IsActive and groupFrames.IsActive() then
		groupFrames.Refresh()
	end
	local unitFrames = BUI.UnitFrames
	if (scope ~= 'group' or shared) and unitFrames and BUI.IsModuleEnabled('unitFrames') then
		if unitFrames.InvalidateFilterCache then unitFrames.InvalidateFilterCache() end
		if unitFrames.Refresh then unitFrames:Refresh() end
	end
end
