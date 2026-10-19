local _, BUI = ...

local BUILib = BluUI.BUILibClient
local FONT = BUILib.Font
local Motion = BUILib.Motion
local Skin = BUI.Skinning
local Painter = BUI.Painter
local Pixel = BUI.Pixel
local Script = BUI.Profiler.Script
local Wrap = BUI.Profiler.Wrap
local PALETTE = Skin.PALETTE

local BUTTON_H = 24
local FRAME = {
	width = 960, height = 624, slotX = 16, slotY = -116, edge = 12, footerY = 12, scrollPad = 8,
	sideW = 240, toolbarY = 12,
}
FRAME.listBottom = FRAME.footerY + BUTTON_H + 8
FRAME.listTop = FRAME.toolbarY + BUTTON_H + 2
local STRIP = { top = 44, header = 18, tileH = 46, tileGap = 6, perRow = 8, tileIcon = 30, tileInset = 7, tileTextGap = 6, divider = 10 }
local SIDE = { pad = 12, header = 18, section = 16, ratingW = 70, toggleH = 24, playstyleH = 26, toggleGap = 4, serversH = 28 }
local BAR = { gap = 6, sortW = 130, searchW = 72, refreshGlyph = 14, editW = 70, blizzardW = 150, startW = 120, searchBoxGap = 12, autoComplete = 'DIALOG',
	hint = 'Search +10, 10-15 or a dungeon', completeGap = 2, searchGlyph = 13, searchInset = 10, clearSize = 10, caretH = 14, blink = 0.5,
}
local ROW = { pad = 4, inset = 6, columnGap = 8, signUp = 64, cancel = 56, statusGap = 6, slot = 18, slotGap = 2, role = 24, roleIcon = 18, roleGap = 4, coverLevel = 10, coverSize = 14 }
local LEVEL = { catcher = 20, popover = 40 }
local POP = {
	pad = 12, gap = 4, header = 18, headerMid = 6, linkGap = 10, section = 8, checkRow = 24, checkSize = 14, checkIcon = 18,
	textGap = 8, tick = 2, dungeonW = 210, dungeonGap = 12, serversW = 290, serversListH = 240, serverRow = 24, eye = 16,
	flagW = 52, flagH = 22, languageGap = 12, ratingDigits = 4, columnsW = 240, columnRow = 28, columnGap = 4,
}
local ALPHA = { dimmed = 0.45, emptyRole = 0.3, tileOff = 0.45, lit = 0.08, plate = 0.8 }
local FILTER = {
	search = Enum.LFGListFilter.Recommended,
	preferred = Enum.LFGListFilter.PvE,
	season = bit.bor(Enum.LFGListFilter.CurrentSeason, Enum.LFGListFilter.PvE),
	other = bit.bor(Enum.LFGListFilter.CurrentExpansion, Enum.LFGListFilter.NotCurrentSeason, Enum.LFGListFilter.PvE),
}
local SLIDE_TIME = 0.16
local SLIDE = { easing = Motion.Ease.outCubic }
local LAYOUTS = {
	regular = { height = 44, icon = 32, nameY = 7, subY = -8, scoreY = 7, bestY = -8 },
	compact = { height = 32, icon = 24, nameY = 6, subY = -6, scoreY = 6, bestY = -6 },
}
local COLUMNS = {
	{ key = 'dungeon', label = 'Dungeon picture', width = 34 },
	{ key = 'title', label = 'Group title' },
	{ key = 'group', label = 'Group members', width = 98 },
	{ key = 'leader', label = 'Leader score', width = 44 },
	{ key = 'action', label = 'Sign up button', width = 104 },
}
local MENU_W = 230
local MAX_APPLICATIONS = 5
local DUNGEON_CATEGORY = 2
local FALLBACK_ICON = 'Interface/Icons/INV_Relics_Hourglass'
local CENSORED_TITLE = 'Title hidden'
local ALL, ANY = 'All', 'Any'
local ROLES = { 'TANK', 'HEALER', 'DAMAGER' }
local SLOT_ROLES = { 'TANK', 'HEALER', 'DAMAGER', 'DAMAGER', 'DAMAGER' }
local SLOT_RANK = { 1, 1, 1, 2, 3 }
local ROLE_ATLAS = { TANK = 'groupfinder-icon-role-micro-tank', HEALER = 'groupfinder-icon-role-micro-heal', DAMAGER = 'groupfinder-icon-role-micro-dps' }
local ROLE_NAMES = { TANK = 'Tank', HEALER = 'Healer', DAMAGER = 'Damage' }
local REQUIRE = {
	{ key = 'needsTank', label = LFG_LIST_NEEDS_TANK, role = 'TANK' },
	{ key = 'needsHealer', label = LFG_LIST_NEEDS_HEALER, role = 'HEALER' },
	{ key = 'needsDamage', label = LFG_LIST_NEEDS_DAMAGE, role = 'DAMAGER' },
	{ key = 'needsMyClass', label = LFG_LIST_CLASS_AVAILABLE:format(UnitClass('player')) },
	{ key = 'hasTank', label = LFG_LIST_HAS_TANK },
	{ key = 'hasHealer', label = LFG_LIST_HAS_HEALER },
	{ key = 'hasLust', label = 'Has lust', own = true },
}
local Comp = {
	lust = { 'SHAMAN', 'MAGE', 'HUNTER', 'EVOKER' },
	choices = { { key = 'any', label = 'Any' }, { key = 'physical', label = 'Physical' }, { key = 'magic', label = 'Caster' } },
	labels = { physical = 'Physical', magic = 'Caster', mixed = 'Mixed' },
	damage = {
		[71] = 'physical', [72] = 'physical', [103] = 'physical', [253] = 'physical', [254] = 'physical',
		[255] = 'physical', [260] = 'physical', [261] = 'physical', [269] = 'physical',
		[62] = 'magic', [63] = 'magic', [64] = 'magic', [70] = 'magic', [102] = 'magic', [251] = 'magic',
		[252] = 'magic', [258] = 'magic', [259] = 'magic', [262] = 'magic', [263] = 'magic', [265] = 'magic',
		[266] = 'magic', [267] = 'magic', [577] = 'magic', [1467] = 'magic', [1473] = 'magic', [1480] = 'magic',
	},
}
local DIFFICULTIES = {
	{ key = 'difficultyNormal', label = PLAYER_DIFFICULTY1 },
	{ key = 'difficultyHeroic', label = PLAYER_DIFFICULTY2 },
	{ key = 'difficultyMythic', label = PLAYER_DIFFICULTY6 },
	{ key = 'difficultyMythicPlus', label = PLAYER_DIFFICULTY_MYTHIC_PLUS },
}
local PLAYSTYLES = {}
for value = 1, 4 do PLAYSTYLES[value] = { key = 'generalPlaystyle' .. value, label = _G['GROUP_FINDER_GENERAL_PLAYSTYLE' .. value] } end
local REGIONS = {
	{ key = 'us', label = 'US', tip = 'Every other server in the Americas.' },
	{ key = 'oceanic', label = 'Oceanic', realms = { "Aman'Thul", 'Barthilas', 'Caelestrasz', "Dath'Remar", 'Dreadmaul', 'Frostmourne', 'Gundrak', "Jubei'Thos", "Khaz'goroth", 'Nagrand', 'Saurfang', 'Thaurissan' } },
	{ key = 'latam', label = 'Latin America', realms = { 'Drakkari', "Quel'Thalas", 'Ragnaros' } },
	{ key = 'brazil', label = 'Brazil', realms = { 'Azralon', 'Gallywix', 'Goldrinn', 'Nemesis', 'Tol Barad' } },
	byRealm = {},
	split = GetCurrentRegion() == 1,
}
for _, region in ipairs(REGIONS) do
	for _, realm in ipairs(region.realms or {}) do REGIONS.byRealm[(realm:lower():gsub('[%s%p]', ''))] = region.key end
	region.tip = region.tip or table.concat(region.realms, ', ')
end
local SORT_ITEMS = {
	{ label = 'Leader score', sort = 'score' },
	{ label = 'Newest', sort = 'newest' },
	{ label = 'Leader best run', sort = 'best' },
	{ label = 'Open slots', sort = 'slots' },
}
local LIVE_EVENTS = {
	'LFG_LIST_SEARCH_RESULTS_RECEIVED', 'LFG_LIST_SEARCH_RESULT_UPDATED', 'LFG_LIST_SEARCH_FAILED',
	'LFG_LIST_APPLICATION_STATUS_UPDATED', 'GROUP_ROSTER_UPDATE', 'PLAYER_SPECIALIZATION_CHANGED',
	'LFG_LIST_ACTIVE_ENTRY_UPDATE',
}
local STATUS_TEXT = {
	applied = 'Applied', invited = 'Invited', declined = 'Declined', declined_full = 'Group full',
	declined_delisted = 'Delisted', timedout = 'Expired', cancelled = 'Cancelled', failed = 'Failed',
	invitedeclined = 'Declined invite', inviteaccepted = 'Joined',
}
local STATUS_DONE = {
	declined = true, declined_full = true, declined_delisted = true, timedout = true,
	cancelled = true, failed = true, invitedeclined = true, inviteaccepted = true,
}

local context = Skin.Define('premadegroups', {
	name = 'Premade Groups',
	description = 'Replaces Premade Groups with a Mythic+ list: filters, leader scores and one-click sign up with your saved roles.',
	icon = 'Interface/LFGFrame/UI-LFG-PORTRAIT',
	newLook = true,
	optIn = true,
})

local finder
local entries, rows, activities, rank, searchRealms = {}, {}, {}, {}, {}
local entryByID, dirtyIDs, rowByID, seen = {}, {}, {}, {}
local panels, searchedWith = {}, { dungeons = {} }
local inSearch, notInSearch = {}, {}
local rowsCompact, dungeonGroups, columnWidths
local advanced, pickedDungeons
local dungeonsCleared = false
local openPanel, searchBorrow
local resortPending = true
local searching, searchFailed, searched = false, false, false
local skipTakeover = false
local RefreshContent
local Panel, Strip = {}, {}

local function Settings() return BUI.GetDB().premadeGroups end

local function Realms() return BUI.db.global.premadeRealms end

local function LeaderRealm(info)
	local leader = info.leaderName
	if not leader then return nil end
	return leader:match('%-(.+)$') or GetNormalizedRealmName()
end

local function LeaderScore(info)
	return info.leaderOverallDungeonScore or 0
end

local function ToggleInSet(set, key)
	set[key] = not set[key] or nil
end

local function CountKeys(set)
	local count = 0
	for _ in pairs(set) do count = count + 1 end
	return count
end

local function Text(parent, size, role, justify)
	local text = parent:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(text, size, FONT, '')
	text:SetJustifyH(justify or 'LEFT')
	text:SetWordWrap(false)
	Painter.Text(text, role)
	return text
end

local function Rule(parent)
	local line = parent:CreateTexture(nil, 'ARTWORK')
	Painter.Fill(line, 'skinBorder')
	return line
end

local function SavedRoles()
	local char = BUI.db.char
	if not char.premadeRoles then char.premadeRoles = {} end
	return char.premadeRoles
end

local function AvailableRoles()
	local tank, healer, damage = C_LFGList.GetAvailableRoles()
	return { TANK = tank, HEALER = healer, DAMAGER = damage }
end

local function SpecRole()
	local spec = C_SpecializationInfo.GetSpecialization()
	return spec and GetSpecializationRole(spec)
end

local function ChosenRoles(available)
	local saved, chosen, any = SavedRoles(), {}, false
	for _, role in ipairs(ROLES) do
		chosen[role] = (saved[role] and available[role]) and true or false
		any = any or chosen[role]
	end
	if not any then
		local role = SpecRole()
		if role and available[role] then chosen[role] = true end
	end
	return chosen
end

local function ToggleRole(role)
	local saved, chosen = SavedRoles(), ChosenRoles(AvailableRoles())
	for _, each in ipairs(ROLES) do saved[each] = chosen[each] end
	saved[role] = not saved[role]
	resortPending = true
	RefreshContent()
end

local function DungeonArt(info)
	local name, texture, _, background = BUI.Tools.ChallengeMapForActivity(info.fullName)
	if name then return name, texture, background end
	local journalID = (info.mapID or 0) > 0 and C_EncounterJournal.GetInstanceForGameMap(info.mapID)
	if not journalID then return info.fullName, FALLBACK_ICON end
	local journalName, _, _, _, loreImage, buttonImage = EJ_GetInstanceInfo(journalID)
	return journalName, buttonImage or FALLBACK_ICON, loreImage
end

local function DifficultyKey(info)
	if info.isMythicPlusActivity then return 'difficultyMythicPlus' end
	if info.isMythicActivity then return 'difficultyMythic' end
	if info.isHeroicActivity then return 'difficultyHeroic' end
	if info.isNormalActivity then return 'difficultyNormal' end
end

local function Activity(activityID)
	local cached = activities[activityID]
	if cached ~= nil then return cached end
	local info = C_LFGList.GetActivityInfoTable(activityID)
	cached = false
	if info and info.categoryID == DUNGEON_CATEGORY then
		local name, texture, background = DungeonArt(info)
		cached = {
			name = name, label = info.isMythicPlusActivity and name or info.fullName, fullName = info.fullName,
			texture = texture, background = background,
			groupID = info.groupFinderActivityGroupID, difficulty = DifficultyKey(info),
		}
	end
	activities[activityID] = cached
	return cached
end

local function GroupList(filters)
	local list = {}
	for _, groupID in ipairs(C_LFGList.GetAvailableActivityGroups(DUNGEON_CATEGORY, filters)) do
		local name = C_LFGList.GetActivityGroupInfo(groupID)
		local activityID = C_LFGList.GetAvailableActivities(DUNGEON_CATEGORY, groupID, Enum.LFGListFilter.PvE)[1]
		local activity = activityID and Activity(activityID)
		if name then list[#list + 1] = { groupID = groupID, label = name, texture = activity and activity.texture or FALLBACK_ICON } end
	end
	table.sort(list, function(left, right) return left.label < right.label end)
	return list
end

local function DungeonGroups()
	if not dungeonGroups then dungeonGroups = { GroupList(FILTER.season), GroupList(FILTER.other) } end
	return dungeonGroups
end

local function DungeonTotal()
	local groups = DungeonGroups()
	return #groups[1] + #groups[2]
end

local function CheckedDungeons()
	if next(pickedDungeons) then return CountKeys(pickedDungeons) end
	return dungeonsCleared and 0 or DungeonTotal()
end

local function NormaliseChoices(choices)
	for _, choice in ipairs(choices) do
		if advanced[choice.key] then return end
	end
	for _, choice in ipairs(choices) do advanced[choice.key] = true end
end

local function Snapshot()
	for key, value in pairs(advanced) do
		if key ~= 'activities' then searchedWith[key] = value end
	end
	wipe(searchedWith.dungeons)
	for groupID in pairs(pickedDungeons) do searchedWith.dungeons[groupID] = true end
end

local function LoadAdvanced()
	advanced = C_LFGList.GetAdvancedFilter()
	NormaliseChoices(DIFFICULTIES)
	NormaliseChoices(PLAYSTYLES)
	pickedDungeons = {}
	for _, groupID in ipairs(advanced.activities) do pickedDungeons[groupID] = true end
	dungeonsCleared = false
	Snapshot()
end

local function SaveFilter()
	local list = {}
	for groupID in pairs(pickedDungeons) do list[#list + 1] = groupID end
	advanced.activities = list
	C_LFGList.SaveAdvancedFilter(advanced)
end

local function AddedChoice(items)
	for _, item in ipairs(items) do
		if advanced[item.key] and not searchedWith[item.key] then return true end
	end
	return false
end

local function Loosened()
	for _, item in ipairs(REQUIRE) do
		if searchedWith[item.key] and not advanced[item.key] then return true end
	end
	if AddedChoice(DIFFICULTIES) or AddedChoice(PLAYSTYLES) then return true end
	if advanced.minimumRating < searchedWith.minimumRating then return true end
	local before = searchedWith.dungeons
	if not next(before) then return false end
	if not next(pickedDungeons) then return true end
	for groupID in pairs(pickedDungeons) do
		if not before[groupID] then return true end
	end
	return false
end

local function CountOn(items)
	local count = 0
	for _, item in ipairs(items) do
		if advanced[item.key] then count = count + 1 end
	end
	return count
end

local function OpenSlotFor(counts, chosen)
	for _, role in ipairs(ROLES) do
		if chosen[role] and counts[role .. '_REMAINING'] > 0 then return true end
	end
	return false
end

local function MembersByRole(entry)
	if entry.byRole then return entry.byRole end
	local byRole = { TANK = {}, HEALER = {}, DAMAGER = {} }
	for memberIndex = 1, entry.info.numMembers do
		local player = C_LFGList.GetSearchResultPlayerInfo(entry.id, memberIndex)
		local list = player and byRole[player.assignedRole]
		if list then list[#list + 1] = player end
	end
	entry.byRole = byRole
	return byRole
end

local function SlotMember(byRole, slotIndex)
	return byRole[SLOT_ROLES[slotIndex]][SLOT_RANK[slotIndex]]
end

function Comp.SpecDamage(player)
	local specName = player.specName
	if not specName or (issecretvalue and issecretvalue(specName)) then return nil end
	local ids = Comp.specIDs
	if not ids then
		ids = {}
		for classID = 1, GetNumClasses() do
			local _, classFile = GetClassInfo(classID)
			if classFile then
				for index = 1, GetNumSpecializationsForClassID(classID) do
					local specID, name = GetSpecializationInfoForClassID(classID, index)
					if name then ids[classFile .. name] = specID end
				end
			end
		end
		Comp.specIDs = ids
	end
	return Comp.damage[ids[player.classFilename .. specName]]
end

function Comp.Of(entry)
	if entry.comp == nil then
		local comp = false
		for _, player in ipairs(MembersByRole(entry).DAMAGER) do
			local damage = Comp.SpecDamage(player) or 'mixed'
			if not comp then
				comp = damage
			elseif comp ~= damage then
				comp = 'mixed'
			end
		end
		entry.comp = comp
	end
	return entry.comp or nil
end

function Comp.HasLust(counts)
	for _, classFile in ipairs(Comp.lust) do
		if counts[classFile] > 0 then return true end
	end
	return false
end

local function Passes(entry, classFile)
	if entry.isApplication then return true end
	local info, counts, activity = entry.info, entry.counts, entry.activity
	if info.isDelisted then return false end
	if entry.realm and Realms().hidden[entry.realm] then return false end
	if entry.region and Realms().hiddenRegions[entry.region] then return false end
	if advanced.needsTank and counts.TANK > 0 then return false end
	if advanced.needsHealer and counts.HEALER > 0 then return false end
	if advanced.needsDamage and counts.DAMAGER >= 3 then return false end
	if advanced.needsMyClass and counts[classFile] > 0 then return false end
	if advanced.hasTank and counts.TANK == 0 then return false end
	if advanced.hasHealer and counts.HEALER == 0 then return false end
	if LeaderScore(info) < advanced.minimumRating then return false end
	if next(pickedDungeons) and not pickedDungeons[activity.groupID] then return false end
	if activity.difficulty and not advanced[activity.difficulty] then return false end
	local playstyle = PLAYSTYLES[info.generalPlaystyle]
	if playstyle and not advanced[playstyle.key] then return false end
	local settings = Settings()
	if settings.hasLust and not Comp.HasLust(counts) then return false end
	if settings.comp ~= 'any' then
		local comp = Comp.Of(entry)
		if comp and comp ~= settings.comp then return false end
	end
	return true
end

local function CanCancel(entry)
	return entry.appStatus == 'applied' and entry.pendingStatus ~= 'applied'
end

local function EntryState(entry, chosen)
	if entry.isApplication then
		local status = entry.pendingStatus == 'applied' and 'applied' or entry.appStatus
		return STATUS_TEXT[status], STATUS_DONE[entry.appStatus] == true
	end
	local counts = entry.counts
	if entry.info.isDelisted then return 'Delisted', true end
	if counts.TANK_REMAINING + counts.HEALER_REMAINING + counts.DAMAGER_REMAINING == 0 then return 'Group full', true end
	if not OpenSlotFor(counts, chosen) then return 'No slot for you', true end
	if entry.stale then return 'No longer matches', true end
	return nil, false
end

local function LeaderBest(entry)
	local best = entry.info.leaderDungeonScoreInfo[1]
	return best and best.bestRunLevel or 0
end

local SORT_KEYS = {
	score = function(entry) return LeaderScore(entry.info) end,
	newest = function(entry) return -entry.info.age end,
	best = LeaderBest,
	slots = function(entry) return entry.counts.TANK_REMAINING + entry.counts.HEALER_REMAINING + entry.counts.DAMAGER_REMAINING end,
}
local sortKey = SORT_KEYS.score

local function SortEntries(left, right)
	if left.isApplication ~= right.isApplication then return left.isApplication end
	local leftValue, rightValue = sortKey(left), sortKey(right)
	if leftValue ~= rightValue then return leftValue > rightValue end
	if left.info.age ~= right.info.age then return left.info.age < right.info.age end
	return left.id < right.id
end

local function SortByRank(left, right)
	local leftRank, rightRank = rank[left.id] or math.huge, rank[right.id] or math.huge
	if leftRank ~= rightRank then return leftRank < rightRank end
	return SortEntries(left, right)
end

local function ReadEntry(resultID)
	local entry = entryByID[resultID]
	if entry == false then return nil end
	if entry and not entry.dirty then return entry end
	if not C_LFGList.HasSearchResultInfo(resultID) then return entry end
	local info = C_LFGList.GetSearchResultInfo(resultID)
	local activity = Activity(info.activityIDs[1])
	if not activity then
		entryByID[resultID] = false
		return nil
	end
	entry = entry or { id = resultID }
	local _, appStatus, pendingStatus = C_LFGList.GetApplicationInfo(resultID)
	entry.info, entry.activity, entry.realm = info, activity, LeaderRealm(info)
	entry.counts = C_LFGList.GetSearchResultMemberCounts(resultID)
	entry.appStatus, entry.pendingStatus = appStatus, pendingStatus
	entry.isApplication = appStatus ~= 'none' or pendingStatus ~= nil
	entry.region = REGIONS.split and entry.realm and (REGIONS.byRealm[(entry.realm:lower():gsub('[%s%p]', ''))] or 'us') or nil
	entry.byRole, entry.comp, entry.dirty = nil, nil, false
	entryByID[resultID] = entry
	return entry
end

local function JudgeEntry(entry, chosen, classFile)
	entry.stale = not Passes(entry, classFile)
	entry.stateText, entry.dimmed = EntryState(entry, chosen)
end

local function CollectEntries(chosen, resort)
	wipe(entries)
	wipe(searchRealms)
	wipe(seen)
	wipe(dirtyIDs)
	local _, classFile = UnitClass('player')
	local function Consider(resultID)
		if seen[resultID] then return end
		seen[resultID] = true
		local entry = ReadEntry(resultID)
		if not entry then return end
		if entry.realm then searchRealms[entry.realm] = (searchRealms[entry.realm] or 0) + 1 end
		JudgeEntry(entry, chosen, classFile)
		if not entry.stale or (not resort and rank[resultID]) then entries[#entries + 1] = entry end
	end
	for _, resultID in ipairs(C_LFGList.GetApplications()) do Consider(resultID) end
	local _, results = C_LFGList.GetSearchResults()
	for _, resultID in ipairs(results) do Consider(resultID) end
	sortKey = SORT_KEYS[Settings().sort]
	if resort then
		table.sort(entries, SortEntries)
		wipe(rank)
		for index, entry in ipairs(entries) do rank[entry.id] = index end
	else
		table.sort(entries, SortByRank)
	end
end

local function SignUpBlocker(chosen)
	local queueMessage = LFGListUtil_GetActiveQueueMessage(true)
	if queueMessage then return queueMessage end
	if not LFGListUtil_IsAppEmpowered() then return LFG_LIST_APP_UNEMPOWERED end
	if IsInGroup(LE_PARTY_CATEGORY_HOME) and C_LFGList.IsCurrentlyApplying() then return LFG_LIST_APP_CURRENTLY_APPLYING end
	local _, active = C_LFGList.GetNumApplications()
	if active >= MAX_APPLICATIONS then return LFG_LIST_HIT_MAX_APPLICATIONS:format(MAX_APPLICATIONS) end
	if not (chosen.TANK or chosen.HEALER or chosen.DAMAGER) then return LFG_LIST_MUST_CHOOSE_SPEC end
end

local function Search()
	Snapshot()
	searching, searchFailed = true, false
	C_LFGList.Search(DUNGEON_CATEGORY, FILTER.search, FILTER.preferred, C_LFGList.GetLanguageSearchFilter(), nil, advanced)
	RefreshContent()
end

local function Age(seconds)
	if seconds < 3600 then return ('%dm'):format(math.floor(seconds / 60)) end
	return ('%dh'):format(math.floor(seconds / 3600))
end

local function RealmText(realm)
	if not Realms().flagged[realm] then return realm end
	return '|cff' .. BUI.Hex(BUI.ThemeColor('danger')) .. realm .. '|r'
end

local function Subtitle(entry, settings)
	local info = entry.info
	local text = entry.activity.label
	if settings.showServer and entry.realm then text = text .. '  ·  ' .. RealmText(entry.realm) end
	local playstyle = settings.showPlaystyle and PLAYSTYLES[info.generalPlaystyle]
	if playstyle then text = text .. '  ·  ' .. playstyle.label end
	if settings.showAge then text = text .. '  ·  ' .. Age(info.age) end
	if info.requiredItemLevel > 0 then text = text .. ('  ·  %d+ ilvl'):format(info.requiredItemLevel) end
	if (info.requiredDungeonScore or 0) > 0 then text = text .. ('  ·  %d+ score'):format(info.requiredDungeonScore) end
	local comp = settings.showComp and Comp.Of(entry)
	if comp then text = text .. '  ·  ' .. Comp.labels[comp] end
	return text
end

local function CreateSlot(parent, role)
	local slot = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	slot:SetSize(Pixel.Scale(ROW.slot), Pixel.Scale(ROW.slot))
	Skin.PaintPanelBackdrop(slot)
	slot.fill = slot:CreateTexture(nil, 'ARTWORK')
	slot.fill:SetSize(Pixel.Scale(ROW.slot - 2), Pixel.Scale(ROW.slot - 2))
	slot.fill:SetPoint('CENTER')
	slot.role = slot:CreateTexture(nil, 'OVERLAY')
	slot.role:SetAllPoints(slot.fill)
	slot.role:SetAtlas(ROLE_ATLAS[role])
	return slot
end

local function PaintSlot(slot, classFile)
	local color = RAID_CLASS_COLORS[classFile]
	slot.fill:SetShown(color ~= nil)
	if color then slot.fill:SetColorTexture(color.r, color.g, color.b, 1) end
	slot.role:SetAlpha(color and 1 or ALPHA.emptyRole)
end

local function PaintLeader(row, info, settings)
	local score = LeaderScore(info)
	row.scoreText:SetText(score > 0 and C_ChallengeMode.GetDungeonScoreRarityColor(score):WrapTextInColorCode(score) or '')
	local best = info.leaderDungeonScoreInfo[1]
	if settings.showBest and best and best.bestRunLevel > 0 then
		row.bestText:SetText(('+%d'):format(best.bestRunLevel))
		Painter.Text(row.bestText, best.finishedSuccess and 'skinText' or 'skinLabel')
	else
		row.bestText:SetText('')
	end
end

local function ShowRowTooltip(row)
	local entry = row.entry
	if not entry then return end
	GameTooltip:SetOwner(row, 'ANCHOR_RIGHT')
	LFGListUtil_SetSearchEntryTooltip(GameTooltip, entry.id)
	if entry.realm then
		local labelR, labelG, labelB = Painter.Color('skinLabel')
		local valueR, valueG, valueB = Painter.Color('skinTitle')
		if Realms().flagged[entry.realm] then valueR, valueG, valueB = BUI.ThemeColor('danger') end
		GameTooltip:AddLine(' ')
		GameTooltip:AddDoubleLine('Server', entry.realm, labelR, labelG, labelB, valueR, valueG, valueB)
		GameTooltip:AddLine('Right-click to hide or flag this server', labelR, labelG, labelB)
	end
	GameTooltip:Show()
end

local function ToggleHidden(realm)
	ToggleInSet(Realms().hidden, realm)
	resortPending = true
	RefreshContent()
	Panel.Notify()
end

local function ToggleFlagged(realm)
	ToggleInSet(Realms().flagged, realm)
	RefreshContent()
	Panel.Notify()
end

local function RealmMenu(realm)
	local realms = Realms()
	Skin.ContextMenu({
		{ title = realm },
		{ text = 'Hide groups from this server', checked = realms.hidden[realm] == true, callback = function() ToggleHidden(realm) end },
		{ text = 'Flag this server', checked = realms.flagged[realm] == true, callback = function() ToggleFlagged(realm) end },
	}, { atCursor = true, width = MENU_W })
end

local function ShowActionTooltip(button)
	if not button.blocker then return end
	local dangerR, dangerG, dangerB = BUI.ThemeColor('danger')
	GameTooltip:SetOwner(button, 'ANCHOR_TOP')
	GameTooltip:SetText(button.blocker, dangerR, dangerG, dangerB, 1, true)
	GameTooltip:Show()
end

local function OnAction(button)
	local entry = button.entry
	if button.mode == 'cancel' then
		C_LFGList.CancelApplication(entry.id)
	elseif not button.blocker then
		local chosen = ChosenRoles(AvailableRoles())
		C_LFGList.ApplyToGroup(entry.id, chosen.TANK, chosen.HEALER, chosen.DAMAGER)
	end
end

local function RowLayout()
	return Settings().compact and LAYOUTS.compact or LAYOUTS.regular
end

local function PlaceColumn(row, column, side, offset, duration)
	if column.side == side then
		Motion.To(column, 'x', offset, duration, SLIDE)
		return
	end
	column.side = side
	column:ClearAllPoints()
	column:SetPoint(side, row, side, offset, 0)
end

local function PlaceColumns(row, duration)
	local order = Settings().columns
	local columns = row.columns
	local inset, gap = Pixel.Scale(ROW.inset), Pixel.Scale(ROW.columnGap)
	local titleIndex = 1
	for index, key in ipairs(order) do
		if key == 'title' then titleIndex = index end
	end
	local left = inset
	for index = 1, titleIndex - 1 do
		local key = order[index]
		PlaceColumn(row, columns[key], 'LEFT', left, duration)
		left = left + columnWidths[key] + gap
	end
	local right = inset
	for index = #order, titleIndex + 1, -1 do
		local key = order[index]
		PlaceColumn(row, columns[key], 'RIGHT', -right, duration)
		right = right + columnWidths[key] + gap
	end
	local title, before, after = columns.title, columns[order[titleIndex - 1]], columns[order[titleIndex + 1]]
	title:ClearAllPoints()
	if before then
		title:SetPoint('LEFT', before, 'RIGHT', gap, 0)
	else
		title:SetPoint('LEFT', row, 'LEFT', inset, 0)
	end
	if after then
		title:SetPoint('RIGHT', after, 'LEFT', -gap, 0)
	else
		title:SetPoint('RIGHT', row, 'RIGHT', -inset, 0)
	end
end

local function OnColumnsMoved()
	for _, row in ipairs(rows) do PlaceColumns(row, row:IsShown() and SLIDE_TIME or 0) end
end

local function RowEnter(row)
	Pixel.SetBorderColor(row, unpack(Skin.HoverColor()))
	ShowRowTooltip(row)
end

local function RowLeave(row)
	Pixel.SetBorderColor(row, unpack(PALETTE.edge))
	GameTooltip:Hide()
end

local function OnRowClick(row)
	local entry = row.entry
	if entry and entry.realm then RealmMenu(entry.realm) end
end

local function Column(row, key, height)
	local column = CreateFrame('Frame', nil, row)
	column:SetSize(columnWidths[key] or 1, height)
	row.columns[key] = column
	return column
end

local function CreateRow(parent, layout)
	local height = Pixel.Scale(layout.height)
	local row = CreateFrame('Button', nil, parent, 'BackdropTemplate')
	row:SetHeight(height)
	row:SetPoint('TOPLEFT')
	row:SetPoint('RIGHT')
	Skin.PaintBackdrop(row, PALETTE.card)
	row.columns = {}

	local dungeon = Column(row, 'dungeon', height)
	row.icon = dungeon:CreateTexture(nil, 'ARTWORK')
	row.icon:SetSize(Pixel.Scale(layout.icon), Pixel.Scale(layout.icon))
	row.icon:SetPoint('CENTER')
	Skin.SquareIcon(dungeon, row.icon, 1)

	local title = Column(row, 'title', height)
	row.nameText = Text(title, 12, 'skinText')
	row.nameText:SetPoint('LEFT', 0, Pixel.Scale(layout.nameY))
	row.nameText:SetPoint('RIGHT', 0, Pixel.Scale(layout.nameY))
	row.subText = Text(title, 10, 'skinLabel')
	row.subText:SetPoint('LEFT', 0, Pixel.Scale(layout.subY))
	row.subText:SetPoint('RIGHT', 0, Pixel.Scale(layout.subY))

	local group = Column(row, 'group', height)
	row.slots = {}
	for slotIndex, role in ipairs(SLOT_ROLES) do
		local slot = CreateSlot(group, role)
		slot:SetPoint('LEFT', Pixel.Scale((slotIndex - 1) * (ROW.slot + ROW.slotGap)), 0)
		row.slots[slotIndex] = slot
	end

	local leader = Column(row, 'leader', height)
	row.scoreText = Text(leader, 12, 'skinTitle', 'RIGHT')
	row.scoreText:SetPoint('RIGHT', 0, Pixel.Scale(layout.scoreY))
	row.bestText = Text(leader, 10, 'skinText', 'RIGHT')
	row.bestText:SetPoint('RIGHT', 0, Pixel.Scale(layout.bestY))

	local action = Column(row, 'action', height)
	row.action = Skin.SmallButton(action, ROW.signUp, BUTTON_H, 'Sign up')
	row.action:SetPoint('RIGHT')
	row.action:SetScript('OnClick', Script('Skin.PremadeGroups action OnClick', OnAction))
	row.action:HookScript('OnEnter', Wrap('Skin.PremadeGroups action OnEnter', ShowActionTooltip))
	row.action:HookScript('OnLeave', Wrap('Skin.PremadeGroups action OnLeave', GameTooltip_Hide))
	row.statusText = Text(action, 11, 'skinTitle', 'RIGHT')

	row.cover = Strip.Cover(row)

	row:RegisterForClicks('RightButtonUp')
	row:SetScript('OnClick', Script('Skin.PremadeGroups row OnClick', OnRowClick))
	row:SetScript('OnEnter', Script('Skin.PremadeGroups row OnEnter', RowEnter))
	row:SetScript('OnLeave', Script('Skin.PremadeGroups row OnLeave', RowLeave))
	PlaceColumns(row, 0)
	return row
end

local function FillAction(row, entry, blocker)
	local action, status = row.action, row.statusText
	local cancel = entry.isApplication and CanCancel(entry)
	local apply = not entry.isApplication and not entry.stateText
	action.entry = entry
	action.mode = cancel and 'cancel' or 'apply'
	action.blocker = apply and blocker or nil
	action.label:SetText(cancel and 'Cancel' or 'Sign up')
	action:SetWidth(Pixel.Scale(cancel and ROW.cancel or ROW.signUp))
	action:SetAlpha(action.blocker and ALPHA.dimmed or 1)
	action:SetShown(cancel or apply)
	status:SetText(not entry.dimmed and entry.stateText or '')
	status:ClearAllPoints()
	if action:IsShown() then
		status:SetPoint('RIGHT', action, 'LEFT', Pixel.Scale(-ROW.statusGap), 0)
	else
		status:SetPoint('RIGHT')
	end
end

local function FillRow(row, entry, blocker, settings)
	local info = entry.info
	row.entry = entry
	row.icon:SetTexture(entry.activity.texture)
	row.nameText:SetText(info.censored and CENSORED_TITLE or info.name)
	row.subText:SetText(Subtitle(entry, settings))
	local byRole = MembersByRole(entry)
	for slotIndex, slot in ipairs(row.slots) do
		local player = SlotMember(byRole, slotIndex)
		PaintSlot(slot, player and player.classFilename)
	end
	PaintLeader(row, info, settings)
	FillAction(row, entry, blocker)
	row.cover:SetShown(entry.dimmed)
	row.cover.label:SetText(entry.dimmed and (entry.stateText or ''):upper() or '')
	for _, column in pairs(row.columns) do column:SetAlpha(entry.dimmed and ALPHA.dimmed or 1) end
end

local function DropRowsForLayout(settings)
	if rowsCompact == settings.compact then return end
	for _, row in ipairs(rows) do
		row.entry = nil
		row:Hide()
	end
	wipe(rows)
	rowsCompact = settings.compact
end

local function PopulateRows(parent, blocker, settings)
	DropRowsForLayout(settings)
	local layout = RowLayout()
	local step = layout.height + ROW.pad
	local scroll = finder.scroll
	local maxScroll = math.max(0, Pixel.Scale(#entries * step) - scroll:GetHeight())
	if scroll:GetVerticalScroll() > maxScroll then scroll:SetVerticalScroll(maxScroll) end
	local first = math.floor(scroll:GetVerticalScroll() / Pixel.Scale(step)) + 1
	local count = math.ceil((FRAME.height - finder.bodyTop - FRAME.listTop - FRAME.listBottom) / step) + 1
	finder.firstRow, finder.rowBlocker = first, blocker
	wipe(rowByID)
	for slot = 1, count do
		local index = first + slot - 1
		local entry, row = entries[index], rows[slot]
		if entry then
			if not row then
				row = CreateRow(parent, layout)
				rows[slot] = row
			end
			row:SetPoint('TOPLEFT', 0, -Pixel.Scale((index - 1) * step))
			rowByID[entry.id] = row
			FillRow(row, entry, blocker, settings)
			row:Show()
		elseif row then
			row.entry = nil
			row:Hide()
		end
	end
	parent:SetHeight(math.max(1, Pixel.Scale(#entries * step)))
end

local function OnListScroll()
	local step = Pixel.Scale(RowLayout().height + ROW.pad)
	if math.floor(finder.scroll:GetVerticalScroll() / step) + 1 == finder.firstRow then return end
	PopulateRows(finder.child, finder.rowBlocker, Settings())
end

local function RoleEnter(button)
	GameTooltip:SetOwner(button, 'ANCHOR_TOP')
	GameTooltip:SetText('Sign up as ' .. ROLE_NAMES[button.role])
	GameTooltip:Show()
end

local function RoleClick(button)
	ToggleRole(button.role)
end

local function RoleButton(parent, role)
	local button = CreateFrame('Button', nil, parent, 'BackdropTemplate')
	button:SetSize(Pixel.Scale(ROW.role), Pixel.Scale(ROW.role))
	Skin.PaintPanelBackdrop(button)
	button.icon = button:CreateTexture(nil, 'ARTWORK')
	button.icon:SetSize(Pixel.Scale(ROW.roleIcon), Pixel.Scale(ROW.roleIcon))
	button.icon:SetPoint('CENTER')
	button.icon:SetAtlas(ROLE_ATLAS[role])
	button.role = role
	button:SetScript('OnClick', Script('Skin.PremadeGroups role OnClick', RoleClick))
	button:SetScript('OnEnter', Script('Skin.PremadeGroups role OnEnter', RoleEnter))
	button:SetScript('OnLeave', Script('Skin.PremadeGroups role OnLeave', GameTooltip_Hide))
	return button
end

local function PaintRoles(available, chosen)
	for _, button in ipairs(finder.roleButtons) do
		local role = button.role
		local usable = available[role] == true
		button:SetEnabled(usable)
		button:SetAlpha(usable and 1 or ALPHA.dimmed)
		button.icon:SetDesaturated(not chosen[role])
		button.icon:SetAlpha(chosen[role] and 1 or ALPHA.dimmed)
	end
end

local function EmptyMessage()
	if searching then return 'Searching...' end
	if searchFailed then return LFG_LIST_SEARCH_FAILED end
	if not searched then return 'Press Search to look for groups.' end
	return 'No groups match your filters.'
end

RefreshContent = function()
	if not finder or not finder:IsShown() or not finder.main:IsShown() then return end
	local settings = Settings()
	local available = AvailableRoles()
	local chosen = ChosenRoles(available)
	PaintRoles(available, chosen)
	CollectEntries(chosen, resortPending)
	resortPending = false
	Strip.Paint(available)
	PopulateRows(finder.child, SignUpBlocker(chosen), settings)
	Strip.PaintStart()
	local _, active = C_LFGList.GetNumApplications()
	finder.countText:SetText(#entries == 1 and '1 group' or (#entries .. ' groups'))
	finder.appText:SetText(('Applications %d/%d'):format(active, MAX_APPLICATIONS))
	finder.emptyText:SetShown(#entries == 0)
	finder.emptyText:SetText(EmptyMessage())
	if openPanel then openPanel:Refresh() end
end

local QueueRefresh = BUI.Dispatcher.New(function() RefreshContent() end, 'Skin.PremadeGroups refresh')

local function UpdateDirty()
	if not finder:IsShown() then return end
	local settings = Settings()
	local chosen = ChosenRoles(AvailableRoles())
	local blocker = SignUpBlocker(chosen)
	local _, classFile = UnitClass('player')
	for resultID in pairs(dirtyIDs) do
		local row = rowByID[resultID]
		local entry = row and ReadEntry(resultID)
		if entry then
			JudgeEntry(entry, chosen, classFile)
			FillRow(row, entry, blocker, settings)
		end
	end
	wipe(dirtyIDs)
end

local QueueDirty = BUI.Dispatcher.New(UpdateDirty, 'Skin.PremadeGroups result update')

local function OnLiveEvent(event, resultID)
	local entry = resultID and entryByID[resultID]
	if event == 'LFG_LIST_SEARCH_RESULT_UPDATED' then
		if not entry then return end
		entry.dirty = true
		dirtyIDs[resultID] = true
		QueueDirty()
		return
	end
	if event == 'LFG_LIST_SEARCH_RESULTS_RECEIVED' then
		searching, searched, resortPending = false, true, true
		wipe(entryByID)
	elseif event == 'LFG_LIST_SEARCH_FAILED' then
		searching, searchFailed = false, true
	elseif event == 'LFG_LIST_APPLICATION_STATUS_UPDATED' and entry then
		entry.dirty = true
	end
	QueueRefresh()
end

local function ApplyFilters()
	resortPending = true
	RefreshContent()
	finder.scroll:SetVerticalScroll(0)
end

local function FilterChanged()
	SaveFilter()
	if Loosened() then
		Search()
		finder.scroll:SetVerticalScroll(0)
		return
	end
	ApplyFilters()
end

local function ServersSummary()
	local realms = Realms()
	local parts = {}
	if REGIONS.split and next(realms.hiddenRegions) then
		local shown = {}
		for _, region in ipairs(REGIONS) do
			if not realms.hiddenRegions[region.key] then shown[#shown + 1] = region.label end
		end
		parts[1] = table.concat(shown, ', ') .. ' only'
	end
	local hidden, flagged = CountKeys(realms.hidden), CountKeys(realms.flagged)
	if hidden > 0 then parts[#parts + 1] = hidden .. ' hidden' end
	if flagged > 0 then parts[#parts + 1] = flagged .. ' flagged' end
	return #parts > 0 and table.concat(parts, ' · ') or 'All shown'
end

function Panel.LinkEnter(link)
	link.text:SetTextColor(unpack(Skin.HoverColor()))
end

function Panel.LinkLeave(link)
	Painter.Text(link.text, 'skinLabel')
end

function Panel.LinkButton(parent, label, onClick)
	local link = CreateFrame('Button', nil, parent)
	link.text = Text(link, 10, 'skinLabel', 'RIGHT')
	link.text:SetPoint('RIGHT')
	link.text:SetText(label)
	link:SetSize(link.text:GetUnboundedStringWidth(), Pixel.Scale(POP.header))
	link:SetScript('OnClick', Script('Skin.PremadeGroups link OnClick', onClick))
	link:SetScript('OnEnter', Script('Skin.PremadeGroups link OnEnter', Panel.LinkEnter))
	link:SetScript('OnLeave', Script('Skin.PremadeGroups link OnLeave', Panel.LinkLeave))
	return link
end

function Panel.Header(parent, text, x, y)
	local label = Text(parent, 10, 'skinLabel')
	label:SetPoint('LEFT', parent, 'TOPLEFT', Pixel.Scale(x), Pixel.Scale(-(y + POP.headerMid)))
	label:SetText(text:upper())
	return label
end

function Panel.CheckEnter(check)
	Pixel.SetBorderColor(check.box, unpack(Skin.HoverColor()))
end

function Panel.CheckLeave(check)
	Pixel.SetBorderColor(check.box, unpack(PALETTE.edge))
end

function Panel.CheckRow(parent, width, onClick, icon)
	local check = CreateFrame('Button', nil, parent)
	check:SetSize(Pixel.Scale(width), Pixel.Scale(POP.checkRow))
	check.box = CreateFrame('Frame', nil, check, 'BackdropTemplate')
	check.box:SetSize(Pixel.Scale(POP.checkSize), Pixel.Scale(POP.checkSize))
	check.box:SetPoint('LEFT')
	Skin.PaintBackdrop(check.box, PALETTE.card)
	check.tick = check.box:CreateTexture(nil, 'OVERLAY')
	BUILib.Widget.SetGlyph(check.tick, BUILib.GetLibMedia('check'))
	check.tick:SetPoint('TOPLEFT', Pixel.Scale(POP.tick), Pixel.Scale(-POP.tick))
	check.tick:SetPoint('BOTTOMRIGHT', Pixel.Scale(-POP.tick), Pixel.Scale(POP.tick))
	Painter.Tint(check.tick, 'skinTitle')
	local anchor = check.box
	if icon then
		check.icon = check:CreateTexture(nil, 'ARTWORK')
		check.icon:SetSize(Pixel.Scale(POP.checkIcon), Pixel.Scale(POP.checkIcon))
		check.icon:SetPoint('LEFT', check.box, 'RIGHT', Pixel.Scale(POP.textGap), 0)
		check.icon:SetTexture(icon)
		Skin.SquareIcon(check, check.icon, 1)
		anchor = check.icon
	end
	check.text = Text(check, 11, 'skinText')
	check.text:SetPoint('LEFT', anchor, 'RIGHT', Pixel.Scale(POP.textGap), 0)
	check.text:SetPoint('RIGHT')
	check:SetScript('OnClick', Script('Skin.PremadeGroups check OnClick', onClick))
	check:SetScript('OnEnter', Script('Skin.PremadeGroups check OnEnter', Panel.CheckEnter))
	check:SetScript('OnLeave', Script('Skin.PremadeGroups check OnLeave', Panel.CheckLeave))
	return check
end

function Panel.SetChecked(check, checked)
	check.tick:SetShown(checked)
	Painter.Text(check.text, checked and 'skinTitle' or 'skinText')
end

function Panel.RequireOn(item)
	if item.own then return Settings()[item.key] == true end
	return advanced[item.key] == true
end

function Panel.RequireSummary()
	local names = {}
	for _, item in ipairs(REQUIRE) do
		if Panel.RequireOn(item) then names[#names + 1] = item.label end
	end
	if #names == 0 then return ANY end
	if #names == 1 then return names[1] end
	return ('%d selected'):format(#names)
end

function Panel.ToggleRequire(check)
	local item = check.item
	if item.own then
		local settings = Settings()
		settings[item.key] = not settings[item.key]
		ApplyFilters()
		return
	end
	advanced[item.key] = not advanced[item.key]
	FilterChanged()
end

function Panel.CompOn(button)
	return Settings().comp == button.item.key
end

function Panel.ToggleComp(button)
	Settings().comp = button.item.key
	ApplyFilters()
end

function Panel.ToggleChoice(control)
	local key = control.item.key
	if advanced[key] and CountOn(control.items) == 1 then return end
	advanced[key] = not advanced[key]
	FilterChanged()
end

function Panel.DungeonChecked(groupID)
	return pickedDungeons[groupID] == true or (not dungeonsCleared and next(pickedDungeons) == nil)
end

function Panel.ToggleDungeon(control)
	if next(pickedDungeons) == nil and not dungeonsCleared then
		for _, list in ipairs(DungeonGroups()) do
			for _, group in ipairs(list) do pickedDungeons[group.groupID] = true end
		end
	end
	ToggleInSet(pickedDungeons, control.groupID)
	dungeonsCleared = next(pickedDungeons) == nil
	FilterChanged()
end

function Panel.ResetDungeons(cleared)
	wipe(pickedDungeons)
	dungeonsCleared = cleared
	FilterChanged()
end

function Panel.AllDungeons()
	Panel.ResetDungeons(false)
end

function Panel.NoDungeons()
	Panel.ResetDungeons(true)
end

function Panel.ChecksFor(parent, items, width, x, y, onClick)
	local checks = {}
	for index, item in ipairs(items) do
		local check = Panel.CheckRow(parent, width, onClick, item.texture)
		check.item, check.items, check.groupID = item, items, item.groupID
		check.text:SetText(item.label)
		check:SetPoint('TOPLEFT', Pixel.Scale(x), Pixel.Scale(-(y + (index - 1) * POP.checkRow)))
		checks[index] = check
	end
	return checks, y + #items * POP.checkRow
end

function Panel.PaintRequire(checks, available)
	for _, check in ipairs(checks) do
		local role = check.item.role
		local usable = not role or available[role] == true
		check:SetEnabled(usable)
		check:SetAlpha(usable and 1 or ALPHA.dimmed)
		Panel.SetChecked(check, Panel.RequireOn(check.item))
	end
end

function Panel.PaintDungeons(checks)
	for _, check in ipairs(checks) do Panel.SetChecked(check, Panel.DungeonChecked(check.groupID)) end
end

function Panel.FilterOn(button)
	return advanced[button.item.key] == true
end

function Panel.RegionOn(button)
	return not Realms().hiddenRegions[button.item.key]
end

function Panel.ToggleRegion(control)
	local hidden, key = Realms().hiddenRegions, control.item.key
	if not hidden[key] then
		local shown = 0
		for _, region in ipairs(REGIONS) do
			if not hidden[region.key] then shown = shown + 1 end
		end
		if shown == 1 then return end
	end
	ToggleInSet(hidden, key)
	resortPending = true
	RefreshContent()
	Panel.Notify()
end

function Panel.ToggleTip(button)
	local item = button.item
	GameTooltip:SetOwner(button, 'ANCHOR_RIGHT')
	GameTooltip:SetText(item.label .. ' servers')
	GameTooltip:AddLine(item.tip, Painter.Color('skinLabel'))
	GameTooltip:Show()
end

function Panel.PaintToggle(button)
	local on = button.isOn(button)
	button.lit:SetShown(on)
	local edge = button:IsMouseOver() and Skin.HoverColor() or PALETTE.edge
	Pixel.SetBorderColor(button, edge[1], edge[2], edge[3], edge[4])
	Painter.Text(button.label, on and 'skinTitle' or 'skinLabel')
end

function Panel.Toggle(parent, width, height, item, items, isOn, onClick)
	local button = Skin.SmallButton(parent, width, height, item.label)
	button.item, button.items, button.isOn = item, items, isOn
	button.lit = button:CreateTexture(nil, 'BACKGROUND', nil, 1)
	button.lit:SetPoint('TOPLEFT', Pixel.PixelSize(1), -Pixel.PixelSize(1))
	button.lit:SetPoint('BOTTOMRIGHT', -Pixel.PixelSize(1), Pixel.PixelSize(1))
	Skin.SelectedTexture(button.lit, ALPHA.lit)
	button:SetScript('OnClick', Script('Skin.PremadeGroups toggle OnClick', onClick))
	button:HookScript('OnEnter', Wrap('Skin.PremadeGroups toggle OnEnter', Panel.PaintToggle))
	button:HookScript('OnLeave', Wrap('Skin.PremadeGroups toggle OnLeave', Panel.PaintToggle))
	if item.tip then
		button:HookScript('OnEnter', Wrap('Skin.PremadeGroups toggle tip', Panel.ToggleTip))
		button:HookScript('OnLeave', Wrap('Skin.PremadeGroups toggle tip hide', GameTooltip_Hide))
	end
	return button
end

function Panel.MinimumRating()
	return advanced.minimumRating
end

function Panel.RatingTyped(rating)
	advanced.minimumRating = rating
	SaveFilter()
	ApplyFilters()
end

function Panel.RatingEntered()
	if Loosened() then Search() end
end

function Panel.NumberTyped(box, userInput)
	if userInput then box.onChange(tonumber(box:GetText()) or 0) end
end

function Panel.NumberEntered(box)
	box:ClearFocus()
	if box.onEnter then box.onEnter() end
end

function Panel.NumberBox(parent, width, getValue, onChange, onEnter)
	local box = CreateFrame('EditBox', nil, parent, 'BackdropTemplate')
	box:SetSize(Pixel.Scale(width), Pixel.Scale(BUTTON_H))
	Skin.PaintBackdrop(box, PALETTE.card)
	Pixel.ApplyFont(box, 12, FONT, '')
	Painter.Text(box, 'skinTitle')
	box:SetJustifyH('CENTER')
	box:SetNumeric(true)
	box:SetMaxLetters(POP.ratingDigits)
	box:SetAutoFocus(false)
	box.getValue, box.onChange, box.onEnter = getValue, onChange, onEnter
	box:SetScript('OnTextChanged', Script('Skin.PremadeGroups number OnTextChanged', Panel.NumberTyped))
	box:SetScript('OnEnterPressed', Script('Skin.PremadeGroups number OnEnterPressed', Panel.NumberEntered))
	box:SetScript('OnEscapePressed', Script('Skin.PremadeGroups number OnEscapePressed', box.ClearFocus))
	box:SetScript('OnEditFocusGained', Script('Skin.PremadeGroups number OnEditFocusGained', Panel.NumberFocused))
	box:SetScript('OnEditFocusLost', Script('Skin.PremadeGroups number OnEditFocusLost', Panel.PaintNumber))
	box.hint = Text(box, 11, 'skinLabel', 'CENTER')
	box.hint:SetPoint('CENTER')
	box.hint:SetText(ANY)
	return box
end

function Panel.NumberFocused(box)
	box.hint:Hide()
end

function Panel.PaintNumber(box)
	if box:HasFocus() then return end
	local value = box.getValue()
	box:SetText(value > 0 and tostring(value) or '')
	box.hint:SetShown(value == 0)
end

function Panel.HideServer(button)
	ToggleHidden(button.realm)
end

function Panel.FlagServer(button)
	ToggleFlagged(button.realm)
end

function Panel.ServerRow(holder)
	local row = CreateFrame('Frame', nil, holder.list)
	row:SetHeight(Pixel.Scale(POP.serverRow))
	row.flag = Skin.SmallButton(row, POP.flagW, POP.flagH, 'Flag')
	row.flag:SetPoint('RIGHT', Pixel.Scale(-2), 0)
	row.flag:SetScript('OnClick', Script('Skin.PremadeGroups server flag OnClick', Panel.FlagServer))
	row.eye = CreateFrame('Button', nil, row)
	row.eye:SetSize(Pixel.Scale(POP.eye), Pixel.Scale(POP.eye))
	row.eye:SetPoint('RIGHT', row.flag, 'LEFT', Pixel.Scale(-POP.textGap), 0)
	row.eye:SetScript('OnClick', Script('Skin.PremadeGroups server eye OnClick', Panel.HideServer))
	row.eye.icon = row.eye:CreateTexture(nil, 'ARTWORK')
	row.eye.icon:SetAllPoints()
	row.count = Text(row, 10, 'skinLabel', 'RIGHT')
	row.count:SetPoint('RIGHT', row.eye, 'LEFT', Pixel.Scale(-POP.textGap), 0)
	row.name = Text(row, 11, 'skinText')
	row.name:SetPoint('LEFT', Pixel.Scale(4), 0)
	row.name:SetPoint('RIGHT', row.count, 'LEFT', Pixel.Scale(-POP.textGap), 0)
	return row
end

function Panel.FillServerRow(holder, index, realm, count)
	local row = holder.rows[index] or Panel.ServerRow(holder)
	holder.rows[index] = row
	row:SetPoint('TOPLEFT', 0, -Pixel.Scale(holder.rowTop + (index - 1) * POP.serverRow))
	row:SetPoint('RIGHT')
	local realms = Realms()
	local hidden = realms.hidden[realm] == true
	row.eye.realm, row.flag.realm = realm, realm
	row.name:SetText(RealmText(realm))
	Painter.Text(row.name, hidden and 'skinLabel' or 'skinText')
	local noun = count == 1 and holder.noun or holder.noun .. 's'
	row.count:SetText(count and (count .. ' ' .. noun) or holder.absent)
	BUILib.Widget.SetGlyph(row.eye.icon, BUILib.GetLibMedia(hidden and 'hide' or 'eye'))
	Painter.Tint(row.eye.icon, hidden and 'skinLabel' or 'skinText')
	row.flag.label:SetText(realms.flagged[realm] and 'Unflag' or 'Flag')
	row:Show()
end

function Panel.MatchesQuery(query, realm)
	return not query or query == '' or realm:lower():find(query, 1, true) ~= nil
end

function Panel.FillServers(holder)
	wipe(inSearch)
	wipe(notInSearch)
	local counts = holder.counts
	for realm in pairs(counts) do
		if Panel.MatchesQuery(holder.query, realm) then inSearch[#inSearch + 1] = realm end
	end
	for realm in pairs(Realms().hidden) do
		if not counts[realm] and Panel.MatchesQuery(holder.query, realm) then notInSearch[#notInSearch + 1] = realm end
	end
	table.sort(inSearch)
	table.sort(notInSearch)
	for index, realm in ipairs(inSearch) do Panel.FillServerRow(holder, index, realm, counts[realm]) end
	for index, realm in ipairs(notInSearch) do Panel.FillServerRow(holder, #inSearch + index, realm, nil) end
	local shown = #inSearch + #notInSearch
	for index = shown + 1, #holder.rows do holder.rows[index]:Hide() end
	holder.emptyText:SetShown(shown == 0)
	holder.emptyText:SetText(next(counts) and 'No servers match.' or holder.empty)
	return shown
end

function Panel.ToggleLanguage(check)
	local enabled = C_LFGList.GetLanguageSearchFilter()
	enabled[check.language] = not enabled[check.language]
	C_LFGList.SaveLanguageSearchFilter(enabled)
	Search()
end

function Panel.Languages(holder, parent, width)
	local defaults = C_LFGList.GetDefaultLanguageSearchFilter()
	local available = C_LFGList.GetAvailableLanguageSearchFilter()
	local changeable = false
	for _, language in ipairs(available) do changeable = changeable or not defaults[language] end
	if not changeable then return end
	holder.languageHeader = Text(parent, 10, 'skinLabel')
	holder.languageHeader:SetText(LANGUAGES_LABEL:upper())
	holder.languages = {}
	holder.languageWidth = (width - POP.languageGap) / 2
	for index, language in ipairs(available) do
		local check = Panel.CheckRow(parent, holder.languageWidth, Panel.ToggleLanguage)
		check.language, check.locked = language, defaults[language] == true
		check.text:SetText(_G['LFG_LIST_LANGUAGE_' .. language:upper()])
		check:SetEnabled(not check.locked)
		holder.languages[index] = check
	end
end

function Panel.PlaceLanguages(holder, parent, x, y)
	if not holder.languages then return y end
	holder.languageHeader:SetPoint('LEFT', parent, 'TOPLEFT', Pixel.Scale(x), Pixel.Scale(-(y + POP.headerMid)))
	y = y + POP.header
	for index, check in ipairs(holder.languages) do
		local column, line = (index - 1) % 2, math.floor((index - 1) / 2)
		check:SetPoint('TOPLEFT', Pixel.Scale(x + column * (holder.languageWidth + POP.languageGap)), Pixel.Scale(-(y + line * POP.checkRow)))
	end
	return y + math.ceil(#holder.languages / 2) * POP.checkRow
end

function Panel.PaintLanguages(holder)
	if not holder.languages then return end
	local enabled = C_LFGList.GetLanguageSearchFilter()
	for _, check in ipairs(holder.languages) do
		Panel.SetChecked(check, check.locked or enabled[check.language] == true)
		check:SetAlpha(check.locked and ALPHA.dimmed or 1)
	end
end

function Panel.Popover(kind, width, point, relativePoint, offsetX, offsetY)
	local pop = CreateFrame('Frame', nil, finder, 'BackdropTemplate')
	pop:SetWidth(Pixel.Scale(width))
	pop:SetFrameLevel(finder:GetFrameLevel() + LEVEL.popover)
	Skin.PaintBackdrop(pop, PALETTE.panel)
	pop:EnableMouse(true)
	pop:Hide()
	pop.point, pop.relativePoint, pop.offsetX, pop.offsetY = point, relativePoint, offsetX, offsetY
	panels[kind] = pop
	return pop
end

function Panel.RefreshOther(pop)
	Panel.PaintDungeons(pop.checks)
end

function Panel.BuildOther()
	local others = DungeonGroups()[2]
	local width = POP.pad * 2 + POP.dungeonW * 2 + POP.dungeonGap
	local pop = Panel.Popover('other', width, 'TOPRIGHT', 'BOTTOMRIGHT', 0, -POP.gap)
	Panel.Header(pop, 'Other dungeons', POP.pad, POP.pad)
	local y = POP.pad + POP.header
	pop.checks = {}
	for index, group in ipairs(others) do
		local check = Panel.CheckRow(pop, POP.dungeonW, Panel.ToggleDungeon, group.texture)
		check.groupID = group.groupID
		check.text:SetText(group.label)
		local column, line = (index - 1) % 2, math.floor((index - 1) / 2)
		check:SetPoint('TOPLEFT', Pixel.Scale(POP.pad + column * (POP.dungeonW + POP.dungeonGap)), Pixel.Scale(-(y + line * POP.checkRow)))
		pop.checks[index] = check
	end
	pop:SetHeight(Pixel.Scale(y + math.ceil(#others / 2) * POP.checkRow + POP.pad))
	pop.Refresh = Panel.RefreshOther
	return pop
end

Panel.SERVER_LISTS = {
	servers = {
		counts = searchRealms, noun = 'group', absent = 'Not in search', empty = 'Search to see servers.',
		header = 'Servers in this search', languages = true,
	},
}

function Panel.Notify()
	if Panel.onRealmsChanged then Panel.onRealmsChanged() end
end

function Panel.RefreshServersPopover(pop)
	local shown = Panel.FillServers(pop)
	pop.list:SetHeight(math.max(1, Pixel.Scale(shown * POP.serverRow)))
	Panel.PaintLanguages(pop)
end

function Panel.BuildServers(kind)
	local list = Panel.SERVER_LISTS[kind]
	local pop = Panel.Popover(kind, POP.serversW, 'BOTTOMLEFT', 'BOTTOMRIGHT', POP.gap, 0)
	pop.counts, pop.noun, pop.absent, pop.empty = list.counts, list.noun, list.absent, list.empty
	local inner = POP.serversW - POP.pad * 2
	pop.search = Skin.CreateSearchBox(pop, inner, function(text)
		pop.query = text
		Panel.RefreshServersPopover(pop)
	end)
	pop.search:SetPoint('TOPLEFT', Pixel.Scale(POP.pad), Pixel.Scale(-POP.pad))
	local y = POP.pad + BUTTON_H + POP.section
	Panel.Header(pop, list.header, POP.pad, y)
	y = y + POP.header
	local area = CreateFrame('Frame', nil, pop)
	area:SetPoint('TOPLEFT', Pixel.Scale(POP.pad), Pixel.Scale(-y))
	area:SetSize(Pixel.Scale(inner), Pixel.Scale(POP.serversListH))
	pop.scroll, pop.list = Skin.CreateScrollArea(area, POP.serverRow, 0)
	pop.emptyText = Skin.CreateEmptyText(pop, area)
	pop.rows, pop.rowTop = {}, 0
	y = y + POP.serversListH + POP.section
	if list.languages then
		Panel.Languages(pop, pop, inner)
		y = Panel.PlaceLanguages(pop, pop, POP.pad, y)
	end
	pop:SetHeight(Pixel.Scale(y + POP.pad))
	pop.Refresh = Panel.RefreshServersPopover
	return pop
end

function Panel.RefreshColumns(pop)
	pop.list:SetOrder(Settings().columns)
end

function Panel.ResetColumns()
	local columns = Settings().columns
	for index, column in ipairs(COLUMNS) do columns[index] = column.key end
	panels.columns.list:SetOrder(columns)
	OnColumnsMoved()
end

function Panel.BuildColumns()
	local pop = Panel.Popover('columns', POP.columnsW, 'TOPLEFT', 'BOTTOMLEFT', 0, -POP.gap)
	Panel.Header(pop, 'Row layout', POP.pad, POP.pad)
	local reset = Panel.LinkButton(pop, RESET, Panel.ResetColumns)
	reset:SetPoint('RIGHT', pop, 'TOPRIGHT', Pixel.Scale(-POP.pad), Pixel.Scale(-(POP.pad + POP.headerMid)))
	local hint = Text(pop, 10, 'skinLabel')
	hint:SetPoint('TOPLEFT', Pixel.Scale(POP.pad), Pixel.Scale(-(POP.pad + POP.header)))
	hint:SetText('Drag to change the order across each row')
	local top = POP.pad + POP.header * 2
	pop.list = Skin.CreateOrderList(pop, {
		items = COLUMNS, order = Settings().columns, width = POP.columnsW - POP.pad * 2,
		rowHeight = POP.columnRow, gap = POP.columnGap, onChange = OnColumnsMoved,
	})
	pop.list:SetPoint('TOPLEFT', Pixel.Scale(POP.pad), Pixel.Scale(-top))
	pop:SetHeight(Pixel.Scale(top + POP.pad) + pop.list:GetHeight())
	pop.Refresh = Panel.RefreshColumns
	return pop
end

function Panel.RefreshRequire(pop)
	Panel.PaintRequire(pop.checks, AvailableRoles())
end

function Panel.BuildRequire()
	local width = FRAME.sideW - SIDE.pad * 2
	local pop = Panel.Popover('require', width, 'TOPLEFT', 'BOTTOMLEFT', 0, -POP.gap)
	pop.checks = Panel.ChecksFor(pop, REQUIRE, width - POP.pad * 2, POP.pad, POP.pad, Panel.ToggleRequire)
	pop:SetHeight(Pixel.Scale(POP.pad * 2 + #REQUIRE * POP.checkRow))
	pop.Refresh = Panel.RefreshRequire
	return pop
end

Panel.BUILDERS = { other = Panel.BuildOther, servers = Panel.BuildServers, columns = Panel.BuildColumns, require = Panel.BuildRequire }

local function HidePanel()
	if not openPanel then return end
	openPanel:Hide()
	openPanel = nil
	finder.catcher:Hide()
end

function Panel.OpenPanel(anchor)
	HidePanel()
	local pop = panels[anchor.kind] or Panel.BUILDERS[anchor.kind](anchor.kind)
	pop:ClearAllPoints()
	pop:SetPoint(pop.point, anchor, pop.relativePoint, Pixel.Scale(pop.offsetX), Pixel.Scale(pop.offsetY))
	pop:Refresh()
	pop:Show()
	openPanel = pop
	finder.catcher:Show()
end

function Strip.DungeonOn(tile)
	return Panel.DungeonChecked(tile.groupID)
end

function Strip.PaintTile(tile)
	local on = tile.isOn(tile)
	tile.icon:SetDesaturated(not on)
	tile.icon:SetAlpha(on and 1 or ALPHA.tileOff)
	Painter.Text(tile.text, on and 'skinTitle' or 'skinLabel')
	local edge = PALETTE.edge
	if on then
		edge = Skin.SELECTED_COLOR
	elseif tile:IsMouseOver() then
		edge = Skin.HoverColor()
	end
	Pixel.SetBorderColor(tile, edge[1], edge[2], edge[3], edge[4])
end

function Strip.Tile(parent, group, width, isOn, onClick)
	local tile = CreateFrame('Button', nil, parent, 'BackdropTemplate')
	tile:SetSize(Pixel.Scale(width), Pixel.Scale(STRIP.tileH))
	Skin.PaintBackdrop(tile, PALETTE.card)
	tile.groupID, tile.isOn = group.groupID, isOn
	tile.icon = tile:CreateTexture(nil, 'ARTWORK')
	tile.icon:SetSize(Pixel.Scale(STRIP.tileIcon), Pixel.Scale(STRIP.tileIcon))
	tile.icon:SetPoint('LEFT', Pixel.Scale(STRIP.tileInset), 0)
	tile.icon:SetTexture(group.texture)
	Skin.SquareIcon(tile, tile.icon, 1)
	tile.text = Text(tile, 10, 'skinTitle')
	tile.text:SetPoint('LEFT', tile.icon, 'RIGHT', Pixel.Scale(STRIP.tileTextGap), 0)
	tile.text:SetPoint('RIGHT', Pixel.Scale(-STRIP.tileTextGap), 0)
	tile.text:SetWordWrap(true)
	tile.text:SetMaxLines(2)
	tile.text:SetText(group.label)
	tile.label = group.label
	tile:SetScript('OnClick', Script('Skin.PremadeGroups tile OnClick', onClick))
	tile:SetScript('OnEnter', Script('Skin.PremadeGroups tile OnEnter', Strip.TileEnter))
	tile:SetScript('OnLeave', Script('Skin.PremadeGroups tile OnLeave', Strip.TileLeave))
	return tile
end

function Strip.TileEnter(tile)
	Strip.PaintTile(tile)
	GameTooltip:SetOwner(tile, 'ANCHOR_BOTTOM')
	GameTooltip:SetText(tile.label)
	GameTooltip:Show()
end

function Strip.TileLeave(tile)
	Strip.PaintTile(tile)
	GameTooltip:Hide()
end

function Strip.Links(view, y)
	local others = DungeonGroups()[2]
	local right = Pixel.Scale(-FRAME.edge)
	local function Place(link)
		link:SetPoint('RIGHT', view, 'TOPRIGHT', right, Pixel.Scale(-(y + POP.headerMid)))
		right = right - link:GetWidth() - Pixel.Scale(POP.linkGap)
	end
	if #others > 0 then
		local other = Panel.LinkButton(view, ('+%d other dungeons'):format(#others), Panel.OpenPanel)
		other.kind = 'other'
		Place(other)
	end
	Place(Panel.LinkButton(view, NONE, Panel.NoDungeons))
	Place(Panel.LinkButton(view, ALL, Panel.AllDungeons))
end

function Strip.Tiles(view, y)
	local season = DungeonGroups()[1]
	local width = (FRAME.width - FRAME.edge * 2 - STRIP.tileGap * (STRIP.perRow - 1)) / STRIP.perRow
	view.tiles = {}
	for index, group in ipairs(season) do
		local tile = Strip.Tile(view, group, width, Strip.DungeonOn, Panel.ToggleDungeon)
		local column, line = (index - 1) % STRIP.perRow, math.floor((index - 1) / STRIP.perRow)
		tile:SetPoint('TOPLEFT', Pixel.Scale(FRAME.edge + column * (width + STRIP.tileGap)), Pixel.Scale(-(y + line * (STRIP.tileH + STRIP.tileGap))))
		view.tiles[index] = tile
	end
	local lines = math.max(1, math.ceil(#season / STRIP.perRow))
	return y + lines * STRIP.tileH + (lines - 1) * STRIP.tileGap
end

function Strip.DropdownButton(parent, width, kind)
	local button = Skin.SmallButton(parent, width, BUTTON_H, '')
	button.label:ClearAllPoints()
	button.label:SetPoint('LEFT', Pixel.Scale(SIDE.pad), 0)
	button.label:SetPoint('RIGHT', Pixel.Scale(-SIDE.pad * 2), 0)
	button.label:SetJustifyH('LEFT')
	button.label:SetWordWrap(false)
	Skin.TipArrow(button)
	button.kind = kind
	button:SetScript('OnClick', Script('Skin.PremadeGroups dropdown OnClick', Panel.OpenPanel))
	return button
end

function Strip.PlaceToggles(view, pool, items, perRow, height, y, isOn, onClick)
	local width = FRAME.sideW - SIDE.pad * 2
	local buttonW = (width - SIDE.toggleGap * (perRow - 1)) / perRow
	for index, item in ipairs(items) do
		local column, line = (index - 1) % perRow, math.floor((index - 1) / perRow)
		local button = pool[index]
		if not button then
			button = Panel.Toggle(view, buttonW, height, item, items, isOn, onClick)
			pool[index] = button
		end
		button.item, button.items = item, items
		button.label:SetText(item.label)
		button:SetSize(Pixel.Scale(buttonW), Pixel.Scale(height))
		button:ClearAllPoints()
		button:SetPoint('TOPLEFT', Pixel.Scale(SIDE.pad + column * (buttonW + SIDE.toggleGap)), Pixel.Scale(-(y + line * (height + SIDE.toggleGap))))
		button:Show()
	end
	for index = #items + 1, #pool do pool[index]:Hide() end
	local lines = math.ceil(#items / perRow)
	return y + lines * height + math.max(0, lines - 1) * SIDE.toggleGap
end

function Strip.ToggleGrid(view, items, perRow, height, y, isOn, onClick)
	local pool = {}
	y = Strip.PlaceToggles(view, pool, items, perRow, height, y, isOn, onClick)
	for _, button in ipairs(pool) do view.toggles[#view.toggles + 1] = button end
	return y
end

function Strip.Sidebar(view, top)
	local width = FRAME.sideW - SIDE.pad * 2
	local y = top + SIDE.pad
	Panel.Header(view, LFG_LIST_REQUIRE, SIDE.pad, y)
	view.requireButton = Strip.DropdownButton(view, width, 'require')
	view.requireButton:SetPoint('TOPLEFT', Pixel.Scale(SIDE.pad), Pixel.Scale(-(y + SIDE.header)))
	y = y + SIDE.header + BUTTON_H + SIDE.section
	Panel.Header(view, 'Comp', SIDE.pad, y)
	view.toggles = {}
	y = Strip.ToggleGrid(view, Comp.choices, #Comp.choices, SIDE.toggleH, y + SIDE.header, Panel.CompOn, Panel.ToggleComp) + SIDE.section
	Panel.Header(view, 'Min rating', SIDE.pad, y + BUTTON_H / 2 - POP.headerMid)
	view.ratingBox = Panel.NumberBox(view, SIDE.ratingW, Panel.MinimumRating, Panel.RatingTyped, Panel.RatingEntered)
	view.ratingBox:SetPoint('TOPRIGHT', view, 'TOPLEFT', Pixel.Scale(FRAME.sideW - SIDE.pad), Pixel.Scale(-y))
	y = y + BUTTON_H + SIDE.section
	Panel.Header(view, LFG_LIST_DIFFICULTY, SIDE.pad, y)
	y = Strip.ToggleGrid(view, DIFFICULTIES, #DIFFICULTIES, SIDE.toggleH, y + SIDE.header, Panel.FilterOn, Panel.ToggleChoice) + SIDE.section
	Panel.Header(view, GROUP_FINDER_FILTER_PLAYSTYLE, SIDE.pad, y)
	y = Strip.ToggleGrid(view, PLAYSTYLES, 2, SIDE.playstyleH, y + SIDE.header, Panel.FilterOn, Panel.ToggleChoice) + SIDE.section
	if REGIONS.split then
		Panel.Header(view, 'Region', SIDE.pad, y)
		Strip.ToggleGrid(view, REGIONS, 2, SIDE.toggleH, y + SIDE.header, Panel.RegionOn, Panel.ToggleRegion)
	end

	view.servers = Strip.ServersButton(view, 'servers')
	view.servers:SetPoint('BOTTOMLEFT', Pixel.Scale(SIDE.pad), Pixel.Scale(SIDE.pad))
end

function Strip.ServersButton(view, kind)
	local servers = Skin.SmallButton(view, FRAME.sideW - SIDE.pad * 2, SIDE.serversH, 'Servers')
	servers.label:ClearAllPoints()
	servers.label:SetPoint('LEFT', Pixel.Scale(SIDE.pad), 0)
	servers.kind = kind
	servers:SetScript('OnClick', Script('Skin.PremadeGroups servers OnClick', Panel.OpenPanel))
	servers.value = Text(servers, 11, 'skinLabel', 'RIGHT')
	servers.value:SetPoint('RIGHT', Pixel.Scale(-SIDE.pad), 0)
	return servers
end

function Strip.Paint(available)
	local view = finder.stripView
	view.count:SetText(('DUNGEONS · %d OF %d'):format(CheckedDungeons(), DungeonTotal()))
	for _, tile in ipairs(view.tiles) do Strip.PaintTile(tile) end
	view.requireButton.label:SetText(Panel.RequireSummary())
	for _, button in ipairs(view.toggles) do Panel.PaintToggle(button) end
	Panel.PaintNumber(view.ratingBox)
	view.servers.value:SetText(ServersSummary())
end

function Strip.Build(frame)
	local view = CreateFrame('Frame', nil, frame)
	view:SetAllPoints()
	frame.stripView = view
	local y = STRIP.top
	view.count = Panel.Header(view, '', FRAME.edge, y)
	Strip.Links(view, y)
	y = Strip.Tiles(view, y + STRIP.header) + STRIP.divider
	local divider = Rule(view)
	divider:SetHeight(Pixel.PixelSize(1))
	divider:SetPoint('TOPLEFT', Pixel.Scale(1), Pixel.Scale(-y))
	divider:SetPoint('TOPRIGHT', Pixel.Scale(-1), Pixel.Scale(-y))
	view.bodyTop = y + 1
	Strip.Sidebar(view, view.bodyTop)
	return view
end

local function SortLabel(sort)
	for _, item in ipairs(SORT_ITEMS) do
		if item.sort == sort then return item.label end
	end
end

local function OnSort(item)
	Settings().sort = item.sort
	ApplyFilters()
end

local function SearchBox()
	return LFGListFrame.SearchPanel.SearchBox
end

local function MirrorSearchText()
	if not searchBorrow then return end
	local box = SearchBox()
	local text = box:GetText()
	local focused = box:HasFocus()
	local known = not (issecretvalue and issecretvalue(text))
	local empty = known and text == ''
	finder.searchText:SetText(text)
	finder.searchHint:SetShown(empty and not focused)
	finder.searchClear:SetShown(not empty)
	local edge = focused and Skin.SELECTED_COLOR or PALETTE.edge
	Pixel.SetBorderColor(finder.searchSlot, edge[1], edge[2], edge[3], edge[4])
	Strip.PlaceCaret(finder.searchCaret, box, focused)
end

local function FocusSearchBox()
	SearchBox():SetFocus()
end

local function ClearSearchBox()
	SearchBox().clearButton:Click()
end

local function BorrowSearchBox()
	local autoComplete = LFGListFrame.SearchPanel.AutoCompleteFrame
	searchBorrow = { strata = autoComplete:GetFrameStrata() }
	for index = 1, autoComplete:GetNumPoints() do searchBorrow[index] = { autoComplete:GetPoint(index) } end
	autoComplete:ClearAllPoints()
	autoComplete:SetPoint('TOPLEFT', finder.searchSlot, 'BOTTOMLEFT', 0, -Pixel.Scale(BAR.completeGap))
	autoComplete:SetPoint('TOPRIGHT', finder.searchSlot, 'BOTTOMRIGHT', 0, -Pixel.Scale(BAR.completeGap))
	autoComplete:SetIgnoreParentAlpha(true)
	autoComplete:SetFrameStrata(BAR.autoComplete)
	MirrorSearchText()
end

local function ReturnSearchBox()
	if not searchBorrow then return end
	local box, autoComplete = SearchBox(), LFGListFrame.SearchPanel.AutoCompleteFrame
	local saved = searchBorrow
	searchBorrow = nil
	if box:HasFocus() then box:ClearFocus() end
	autoComplete:ClearAllPoints()
	for _, point in ipairs(saved) do autoComplete:SetPoint(unpack(point)) end
	autoComplete:SetIgnoreParentAlpha(false)
	autoComplete:SetFrameStrata(saved.strata)
end

local function ApplyLook()
	if not finder then return end
	Pixel.SetScale(finder, Settings().scale)
	RefreshContent()
end

local function OnBlizzardSearch()
	if not finder or not finder:IsShown() then return end
	Snapshot()
	searching, searchFailed = true, false
	QueueRefresh()
end

function Strip.GlyphEnter(button)
	button.glyph:SetVertexColor(unpack(Skin.HoverColor()))
	GameTooltip:SetOwner(button, 'ANCHOR_TOP')
	GameTooltip:SetText(button.tip)
	GameTooltip:Show()
end

function Strip.GlyphLeave(button)
	Painter.Tint(button.glyph, 'skinTitle')
	GameTooltip:Hide()
end

function Strip.GlyphButton(parent, glyph, tip, onClick)
	local button = Skin.SmallButton(parent, BUTTON_H, BUTTON_H, '')
	button.tip = tip
	button:SetScript('OnClick', Script('Skin.PremadeGroups glyph OnClick', onClick))
	button:HookScript('OnEnter', Wrap('Skin.PremadeGroups glyph OnEnter', Strip.GlyphEnter))
	button:HookScript('OnLeave', Wrap('Skin.PremadeGroups glyph OnLeave', Strip.GlyphLeave))
	button.glyph = button:CreateTexture(nil, 'ARTWORK')
	button.glyph:SetSize(Pixel.Scale(BAR.refreshGlyph), Pixel.Scale(BAR.refreshGlyph))
	button.glyph:SetPoint('CENTER')
	BUILib.Widget.SetGlyph(button.glyph, BUILib.GetLibMedia(glyph))
	Painter.Tint(button.glyph, 'skinTitle')
	return button
end

function Strip.Caret(parent, text, size)
	local caret = parent:CreateTexture(nil, 'OVERLAY')
	caret:SetSize(Pixel.Scale(1), Pixel.Scale(BAR.caretH))
	Painter.Fill(caret, 'skinTitle')
	caret.text = text
	caret.measure = parent:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(caret.measure, size, FONT, '')
	caret.measure:Hide()
	caret.blink = caret:CreateAnimationGroup()
	caret.blink:SetLooping('REPEAT')
	for order, alpha in ipairs({ 0, 1 }) do
		local step = caret.blink:CreateAnimation('Alpha')
		step:SetFromAlpha(1 - alpha)
		step:SetToAlpha(alpha)
		step:SetDuration(0.01)
		step:SetStartDelay(BAR.blink)
		step:SetOrder(order)
	end
	caret:Hide()
	return caret
end

function Strip.PlaceCaret(caret, box, focused)
	local text = box:GetText()
	local plain = not (issecretvalue and issecretvalue(text)) and text or nil
	caret.blink:Stop()
	caret:SetShown(focused and plain ~= nil)
	if not caret:IsShown() then return end
	caret.measure:SetText(plain:sub(1, box:GetCursorPosition()))
	local offset = math.min(caret.measure:GetUnboundedStringWidth(), caret.text:GetWidth())
	caret:ClearAllPoints()
	caret:SetPoint('LEFT', caret.text, 'LEFT', offset, 0)
	caret.blink:Play()
end

function Strip.Cover(parent)
	local cover = CreateFrame('Frame', nil, parent)
	cover:SetPoint('TOPLEFT', Pixel.PixelSize(1), -Pixel.PixelSize(1))
	cover:SetPoint('BOTTOMRIGHT', -Pixel.PixelSize(1), Pixel.PixelSize(1))
	cover:SetFrameLevel(parent:GetFrameLevel() + ROW.coverLevel)
	local plate = cover:CreateTexture(nil, 'BACKGROUND')
	plate:SetAllPoints()
	Painter.Fill(plate, 'skinBackground')
	plate:SetAlpha(ALPHA.plate)
	cover.label = Text(cover, ROW.coverSize, 'skinTitle', 'CENTER')
	cover.label:SetPoint('CENTER')
	cover:Hide()
	return cover
end

function Strip.Hold()
	finder.releasing = false
	finder:Show()
	Skin.SuppressBlizzardFrame(PVEFrame)
	Skin.BorrowCloseButton(PVEFrame.CloseButton, finder.titleBar.closeBtn.frame)
end

function Strip.FinishRelease()
	if not finder.releasing then return end
	finder.releasing = false
	HidePanel()
	finder:Hide()
	Skin.ReturnCloseButton(PVEFrame.CloseButton)
	Skin.RestoreBlizzardFrame(PVEFrame)
end

Strip.QueueRelease = BUI.Dispatcher.New(Strip.FinishRelease, 'Skin.PremadeGroups release')

function Strip.Release(now)
	finder.releasing = true
	if now then
		Strip.FinishRelease()
	else
		Strip.QueueRelease()
	end
end

function Strip.ShowSearch(shown)
	for _, page in pairs(finder.pages) do page:Hide() end
	finder.stripView:SetShown(shown)
	finder.main:SetShown(shown)
	finder.sideRule:SetShown(shown)
end

function Strip.PaintStart()
	local button = finder.startButton
	local listed = C_LFGList.HasActiveEntryInfo()
	button.blocker = not listed and not LFGListUtil_IsAppEmpowered() and LFG_LIST_NOT_LEADER or nil
	button.label:SetText(listed and 'View applicants' or 'Start a group')
	button:SetAlpha(button.blocker and ALPHA.dimmed or 1)
end

function Strip.StartGroup(button)
	if button.blocker then return end
	if C_LFGList.HasActiveEntryInfo() then
		LFGListFrame_SetActivePanel(LFGListFrame, LFGListFrame.ApplicationViewer)
	else
		LFGListSearchPanel_CreateGroupInstead(LFGListFrame.SearchPanel)
	end
end

local function ShowBlizzard()
	skipTakeover = true
	ReturnSearchBox()
	BUI.Events:UnregisterAll('Skinning.PremadeGroups')
	Strip.Release(true)
end

local function CloseFinder()
	if not Skin.CloseBorrowed(PVEFrame.CloseButton) then HideUIPanel(PVEFrame) end
end

local function SearchFieldEnter(slot)
	Pixel.SetBorderColor(slot, unpack(Skin.HoverColor()))
end

local function SearchGoEnter(button)
	button.lit:Show()
	Painter.Text(button.label, 'skinTitle')
end

local function SearchGoLeave(button)
	button.lit:Hide()
	Painter.Text(button.label, 'skinText')
end

local function BuildSearchField(frame, parent, left, right)
	local pixel = Pixel.PixelSize(1)
	local slot = CreateFrame('Button', nil, parent, 'BackdropTemplate')
	slot:SetHeight(Pixel.Scale(BUTTON_H))
	slot:SetPoint('LEFT', left, 'RIGHT', Pixel.Scale(BAR.searchBoxGap), 0)
	slot:SetPoint('RIGHT', right, 'LEFT', Pixel.Scale(-BAR.gap), 0)
	Skin.PaintBackdrop(slot, PALETTE.card)
	slot:SetScript('OnClick', Script('Skin.PremadeGroups search field OnClick', FocusSearchBox))
	slot:SetScript('OnEnter', Script('Skin.PremadeGroups search field OnEnter', SearchFieldEnter))
	slot:SetScript('OnLeave', Script('Skin.PremadeGroups search field OnLeave', MirrorSearchText))
	frame.searchSlot = slot

	local go = CreateFrame('Button', nil, slot)
	go:SetPoint('TOPRIGHT', -pixel, -pixel)
	go:SetPoint('BOTTOMRIGHT', -pixel, pixel)
	go:SetWidth(Pixel.Scale(BAR.searchW))
	go.lit = go:CreateTexture(nil, 'BACKGROUND')
	go.lit:SetAllPoints()
	Skin.SelectedTexture(go.lit, ALPHA.lit)
	go.lit:Hide()
	local divider = Rule(go)
	divider:SetWidth(pixel)
	divider:SetPoint('TOPLEFT')
	divider:SetPoint('BOTTOMLEFT')
	go.label = Text(go, 11, 'skinText', 'CENTER')
	go.label:SetPoint('CENTER')
	go.label:SetText(SEARCH)
	go:SetScript('OnClick', Script('Skin.PremadeGroups search go OnClick', Search))
	go:SetScript('OnEnter', Script('Skin.PremadeGroups search go OnEnter', SearchGoEnter))
	go:SetScript('OnLeave', Script('Skin.PremadeGroups search go OnLeave', SearchGoLeave))

	local glyph = slot:CreateTexture(nil, 'ARTWORK')
	glyph:SetAtlas('common-search-magnifyingglass')
	glyph:SetSize(Pixel.Scale(BAR.searchGlyph), Pixel.Scale(BAR.searchGlyph))
	glyph:SetPoint('LEFT', Pixel.Scale(BAR.searchInset), 0)
	Painter.Tint(glyph, 'skinLabel')

	local clear = CreateFrame('Button', nil, slot)
	clear:SetSize(Pixel.Scale(BAR.clearSize), Pixel.Scale(BAR.clearSize))
	clear:SetPoint('RIGHT', go, 'LEFT', Pixel.Scale(-BAR.searchInset), 0)
	clear.glyph = clear:CreateTexture(nil, 'ARTWORK')
	clear.glyph:SetAllPoints()
	BUILib.Widget.SetGlyph(clear.glyph, BUILib.GetLibMedia('x'))
	Painter.Tint(clear.glyph, 'skinLabel')
	clear:SetScript('OnClick', Script('Skin.PremadeGroups search clear OnClick', ClearSearchBox))
	clear:Hide()
	frame.searchClear = clear

	frame.searchText = Text(slot, 12, 'skinTitle')
	frame.searchText:SetPoint('LEFT', glyph, 'RIGHT', Pixel.Scale(BAR.searchInset), 0)
	frame.searchText:SetPoint('RIGHT', clear, 'LEFT', Pixel.Scale(-BAR.searchInset), 0)
	frame.searchHint = Text(slot, 11, 'skinLabel')
	frame.searchHint:SetPoint('LEFT', glyph, 'RIGHT', Pixel.Scale(BAR.searchInset), 0)
	frame.searchHint:SetPoint('RIGHT', clear, 'LEFT', Pixel.Scale(-BAR.searchInset), 0)
	frame.searchHint:SetText(BAR.hint)
	frame.searchCaret = Strip.Caret(slot, frame.searchText, 12)
end

local function BuildToolbar(main)
	local sortDropdown = Skin.CreateDropdown(main, SORT_ITEMS, OnSort, BAR.sortW)
	sortDropdown:SetPoint('TOPLEFT', Pixel.Scale(FRAME.edge), Pixel.Scale(-FRAME.toolbarY))
	sortDropdown.label:SetText(SortLabel(Settings().sort))
	finder.editButton = Skin.SmallButton(main, BAR.editW, BUTTON_H, 'Edit row')
	finder.editButton:SetPoint('LEFT', sortDropdown, 'RIGHT', Pixel.Scale(BAR.gap), 0)
	finder.editButton.kind = 'columns'
	finder.editButton:SetScript('OnClick', Script('Skin.PremadeGroups edit OnClick', Panel.OpenPanel))

	finder.roleButtons = {}
	local previous
	for index = #ROLES, 1, -1 do
		local button = RoleButton(main, ROLES[index])
		if previous then
			button:SetPoint('RIGHT', previous, 'LEFT', Pixel.Scale(-ROW.roleGap), 0)
		else
			button:SetPoint('TOPRIGHT', Pixel.Scale(-FRAME.edge), Pixel.Scale(-FRAME.toolbarY))
		end
		finder.roleButtons[index] = button
		previous = button
	end
	local roleLabel = Text(main, 11, 'skinLabel', 'RIGHT')
	roleLabel:SetPoint('RIGHT', previous, 'LEFT', Pixel.Scale(-BAR.gap), 0)
	roleLabel:SetText('Sign up as')
	local searchButton = Strip.GlyphButton(main, 'reload', 'Search again', Search)
	searchButton:SetPoint('RIGHT', roleLabel, 'LEFT', Pixel.Scale(-BAR.searchBoxGap), 0)
	BuildSearchField(finder, main, finder.editButton, searchButton)
end

local function BuildMain(frame)
	local main = CreateFrame('Frame', nil, frame)
	main:SetPoint('BOTTOMRIGHT')
	frame.main = main
	BuildToolbar(main)

	frame.listArea = CreateFrame('Frame', nil, main)
	frame.listArea:SetPoint('TOPLEFT', Pixel.Scale(FRAME.edge - FRAME.scrollPad), Pixel.Scale(-FRAME.listTop))
	frame.listArea:SetPoint('BOTTOMRIGHT', Pixel.Scale(FRAME.scrollPad - FRAME.edge), Pixel.Scale(FRAME.listBottom))
	frame.scroll, frame.child = Skin.CreateScrollArea(frame.listArea, LAYOUTS.regular.height, FRAME.scrollPad)
	frame.scroll:HookScript('OnVerticalScroll', Wrap('Skin.PremadeGroups list scroll', OnListScroll))
	frame.emptyText = Skin.CreateEmptyText(main, frame.listArea)

	frame.appText = Text(main, 11, 'skinLabel')
	frame.appText:SetPoint('LEFT', main, 'BOTTOMLEFT', Pixel.Scale(FRAME.edge), Pixel.Scale(FRAME.footerY + BUTTON_H / 2))
	local blizzardButton = Skin.SmallButton(main, BAR.blizzardW, BUTTON_H, 'Blizzard group finder')
	blizzardButton:SetPoint('BOTTOMRIGHT', Pixel.Scale(-FRAME.edge), Pixel.Scale(FRAME.footerY))
	blizzardButton:SetScript('OnClick', Script('Skin.PremadeGroups blizzard OnClick', ShowBlizzard))
	frame.startButton = Skin.SmallButton(main, BAR.startW, BUTTON_H, '')
	frame.startButton:SetPoint('RIGHT', blizzardButton, 'LEFT', Pixel.Scale(-BAR.gap), 0)
	frame.startButton:SetScript('OnClick', Script('Skin.PremadeGroups start OnClick', Strip.StartGroup))
	frame.startButton:HookScript('OnEnter', Wrap('Skin.PremadeGroups start OnEnter', ShowActionTooltip))
	frame.startButton:HookScript('OnLeave', Wrap('Skin.PremadeGroups start OnLeave', GameTooltip_Hide))

	frame.sideRule = Rule(frame)
	frame.sideRule:SetWidth(Pixel.PixelSize(1))
	frame.sideRule:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', Pixel.Scale(FRAME.sideW), Pixel.Scale(1))
end

local function BuildFrame()
	if finder then return end
	local frame = Skin.CreatePanelWindow('Premade Groups', CloseFinder)
	frame:SetSize(Pixel.Scale(FRAME.width), Pixel.Scale(FRAME.height))
	frame:SetFrameStrata('HIGH')
	finder = frame
	frame.pages = {}
	Skin.MakeDraggable(frame, 'premadeGroups', 'TOPLEFT', Pixel.Scale(FRAME.slotX), Pixel.Scale(FRAME.slotY))
	columnWidths = {}
	for _, column in ipairs(COLUMNS) do columnWidths[column.key] = column.width and Pixel.Scale(column.width) end

	frame.countText = Text(frame.titleBar, 11, 'skinLabel', 'RIGHT')
	frame.countText:SetPoint('RIGHT', frame.titleBar.closeBtn.frame, 'LEFT', Pixel.Scale(-12), 0)

	BuildMain(frame)
	frame.bodyTop = Strip.Build(frame).bodyTop
	frame.main:SetPoint('TOPLEFT', Pixel.Scale(FRAME.sideW), Pixel.Scale(-frame.bodyTop))
	frame.sideRule:SetPoint('TOPLEFT', Pixel.Scale(FRAME.sideW), Pixel.Scale(-frame.bodyTop))

	frame.catcher = CreateFrame('Button', nil, frame)
	frame.catcher:SetAllPoints(UIParent)
	frame.catcher:SetFrameLevel(frame:GetFrameLevel() + LEVEL.catcher)
	frame.catcher:RegisterForClicks('AnyDown')
	frame.catcher:SetScript('OnClick', Script('Skin.PremadeGroups catcher OnClick', HidePanel))
	frame.catcher:Hide()
end

local function Open()
	BuildFrame()
	LoadAdvanced()
	Strip.ShowSearch(true)
	Pixel.SetScale(finder, Settings().scale)
	Strip.Hold()
	BorrowSearchBox()
	for _, event in ipairs(LIVE_EVENTS) do BUI.Events:Register(event, 'Skinning.PremadeGroups', OnLiveEvent) end
	for _, row in ipairs(rows) do PlaceColumns(row, 0) end
	resortPending = true
	RefreshContent()
end

local function CloseWindow(now)
	BUI.Events:UnregisterAll('Skinning.PremadeGroups')
	ReturnSearchBox()
	if not finder then return end
	HidePanel()
	Strip.Release(now)
end

local function OnSearchShown(panel)
	if skipTakeover or panel.categoryID ~= DUNGEON_CATEGORY then return end
	searching = panel.searching == true
	searchFailed = false
	searched = not searching
	Open()
end

local function OnSearchHidden()
	skipTakeover = false
	CloseWindow()
end

context.Window('LFGListFrame', {
	install = function(frame)
		local panel = frame.SearchPanel
		panel:HookScript('OnShow', Wrap('Skin.PremadeGroups search shown', context.Guard(OnSearchShown)))
		panel:HookScript('OnHide', Wrap('Skin.PremadeGroups search hidden', context.Guard(OnSearchHidden)))
		hooksecurefunc('LFGListSearchPanel_DoSearch', Wrap('Skin.PremadeGroups blizzard search', context.Guard(OnBlizzardSearch)))
		local box = panel.SearchBox
		box:HookScript('OnTextChanged', Wrap('Skin.PremadeGroups search text', MirrorSearchText))
		box:HookScript('OnEditFocusGained', Wrap('Skin.PremadeGroups search focus', MirrorSearchText))
		box:HookScript('OnEditFocusLost', Wrap('Skin.PremadeGroups search blur', MirrorSearchText))
		box:HookScript('OnCursorChanged', Wrap('Skin.PremadeGroups search cursor', MirrorSearchText))
	end,
})

context.OnDisable(function()
	skipTakeover = false
	if finder and finder:IsShown() then CloseWindow(true) end
end)

local function LookOption(label, key, extra)
	local option = {
		label = label,
		get = function() return Settings()[key] end,
		set = function(value)
			Settings()[key] = value
			ApplyLook()
		end,
	}
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

context.info.settings = {
	LookOption('Scale', 'scale', { min = 0.8, max = 1.4, step = 0.05 }),
	LookOption('Compact rows', 'compact'),
	LookOption('Show server', 'showServer', { separator = true }),
	LookOption('Show playstyle', 'showPlaystyle'),
	LookOption('Show listing age', 'showAge'),
	LookOption('Show leader best run', 'showBest'),
	LookOption('Show group comp', 'showComp'),
}

BUI.Premade = {
	context = context, Settings = Settings, Text = Text, Rule = Rule, Panel = Panel, Strip = Strip, Comp = Comp,
	CreateSlot = CreateSlot, PaintSlot = PaintSlot, DungeonArt = DungeonArt, HidePanel = HidePanel,
	Frame = function()
		BuildFrame()
		return finder
	end,
	BUTTON_H = BUTTON_H, FRAME = FRAME, STRIP = STRIP, SIDE = SIDE, BAR = BAR, ROW = ROW, POP = POP, ALPHA = ALPHA,
	ROLES = ROLES, ROLE_ATLAS = ROLE_ATLAS, ROLE_NAMES = ROLE_NAMES, SLOT_ROLES = SLOT_ROLES, SLOT_RANK = SLOT_RANK,
	PLAYSTYLES = PLAYSTYLES, DUNGEON_CATEGORY = DUNGEON_CATEGORY, FALLBACK_ICON = FALLBACK_ICON,
	CENSORED_TITLE = CENSORED_TITLE, MENU_W = MENU_W, ALL = ALL, ANY = ANY, BlockerTip = ShowActionTooltip,
	REGIONS = REGIONS, Realms = Realms, RealmText = RealmText, ServersSummary = ServersSummary,
	ToggleHidden = ToggleHidden, ToggleFlagged = ToggleFlagged,
}
