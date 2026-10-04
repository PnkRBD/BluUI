local _, BUI = ...

local BUILib = BUI.BUILibClient
local Layout, Widget = BUILib.Layout, BUILib.Widget

local PAGE_WIDTH = 960
local LEFT_WIDTH = 580
local GAP = 12
local HEADER_HEIGHT = 50
local TABS_GAP = 14
local CARD_RADIUS = 8
local INSET_RADIUS = 6
local PAD = 16
local BOTTOM_PAD = 12
local TITLE_Y = 20
local ACCENT_WIDTH, ACCENT_HEIGHT = 3, 16
local TITLE_GAP = 10
local CONTENT_TOP = 40
local TABLE_TOP = 40
local TABLE_ROWS_TOP = 56
local STRIP_HEIGHT = 60
local STAT_ICON = 26
local STAT_TEXT_X = 56
local STAT_KICKER_Y = 12
local VALUE_GAP = 10
local DIVIDER_INSET = 14
local TILE_HEIGHT = 80
local TILE_GAP = 12
local COLUMN_LABEL_Y = 4
local COLUMNS_TOP = 48
local STATUS_MARK = 12
local MARK_GAP = 6
local CHECK_MARK = 12
local VAULT_SIDE = 170
local LINK_GAP = 8
local SIDE_TEXT_Y = 5
local LINK_INSET = 12
local LINK_HEIGHT = 20
local CHEVRON_SIZE = 10
local CHEVRON_INSET = 14
local BAR_HEIGHT = 8
local BAR_RADIUS = 4
local RAID_ROWS_TOP = 42
local RAID_ROW = 26
local RAID_LABEL = 70
local RAID_COUNT = 60
local KEY_ROW = 26
local KEY_ROWS = 8
local DUNGEON_ICON = 16
local ICON_GAP = 10
local CURRENCY_ROW = 28
local CURRENCY_ICON = 18
local CURRENCY_ROWS = 12
local GROUP_RULE = 9
local CHAR_ROW = 26
local CHAR_ROWS = 20
local CLASS_ICON = 16
local SESSION_TICK = 30
local SESSION_RESET_GAP = 120
local SNAPSHOT_DELAY = 2
local CURRENCY_RESCAN = 30
local KEYSTONE_ITEM = 180653
local WHITE = { 1, 1, 1, 1 }
local POINT_RIGHT = { 1, 0, 0, 0, 1, 1, 0, 1 }
local ICON_CROP = { 0.08, 0.92, 0.08, 0.92 }

local KEY_COLUMNS = { key = 0.47, time = 0.66, under = 0.82 }
local CHAR_COLUMNS = { ilvl = 0.25, score = 0.375, key = 0.505, vault = 0.685, seen = 0.84 }

local RAID_DIFFICULTIES = {
    { label = 'Normal', short = 'N', color = { 0.35, 0.85, 0.35 } },
    { label = 'Heroic', short = 'H', color = { 0.25, 0.6, 1 } },
    { label = 'Mythic', short = 'M', color = { 0.7, 0.4, 0.95 } },
}

local CARDS = {
    { id = 'stat_mscore', label = 'M+ score' },
    { id = 'stat_ilvl', label = 'Item level' },
    { id = 'weeklyMplus', label = 'Weekly M+' },
    { id = 'stat_session', label = 'Session' },
    { id = 'vault', label = 'Great Vault', separator = true },
    { id = 'raidprog', label = 'Raid progress' },
    { id = 'dungeons', label = 'Best keys' },
    { id = 'crests', label = 'Currencies' },
}

local VaultType = Enum.WeeklyRewardChestThresholdType
local RAID_DIFFICULTY_NAMES = { [17] = 'LFR', [14] = 'Normal', [15] = 'Heroic', [16] = 'Mythic' }

local sessionStart

local function DashboardDB()
    return BUI.GetDB().dashboard
end

local function CardShown(id)
    return DashboardDB().cardVisibility[id] ~= false
end

local function CharacterKey()
    return UnitName('player') .. '-' .. GetRealmName()
end

local function SessionText()
    local elapsed = time() - sessionStart
    local hours, minutes = math.floor(elapsed / 3600), math.floor(elapsed % 3600 / 60)
    if hours > 0 then return ('%dh %02dm'):format(hours, minutes) end
    return ('%dm'):format(minutes)
end

local function Clock(seconds)
    seconds = math.floor(seconds + 0.5)
    return ('%d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

local function ColorOf(color)
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

local function SpecLine()
    local className = UnitClass('player')
    local specIndex = GetSpecialization()
    local specName = specIndex and select(2, GetSpecializationInfo(specIndex))
    return (specName and (specName .. ' ' .. className) or className) .. '  ·  ' .. GetRealmName()
end

local function OwnedKeystone()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if not level or level == 0 or not mapID then return end
    return level, (C_ChallengeMode.GetMapUIInfo(mapID))
end

local function VaultActivities(thresholdType)
    local activities = C_WeeklyRewards.GetActivities(thresholdType)
    table.sort(activities, function(left, right) return left.index < right.index end)
    return activities
end

local function Unlocked(activity)
    return activity.progress >= activity.threshold
end

local function UnlockedCount(activities)
    local count = 0
    for _, activity in ipairs(activities) do
        if Unlocked(activity) then count = count + 1 end
    end
    return count
end

local function RewardLink(activity)
    return (C_WeeklyRewards.GetExampleRewardItemHyperlinks(activity.id))
end

local function RewardItemLevel(activity)
    local link = RewardLink(activity)
    return link and C_Item.GetDetailedItemLevelInfo(link)
end

local function VaultSlotLabel(activity)
    if activity.type == VaultType.Raid then return RAID_DIFFICULTY_NAMES[activity.level] or GetDifficultyInfo(activity.level) end
    if activity.type == VaultType.Activities then return '+' .. activity.level end
    return 'Tier ' .. activity.level
end

local function WeeklyMplusCount()
    local count = 0
    for _, activity in ipairs(C_WeeklyRewards.GetActivities(VaultType.Activities)) do
        count = math.max(count, activity.progress)
    end
    return count
end

local PVP_CURRENCY_IDS = { [1602] = true, [1792] = true }
if Constants.CurrencyConsts then
    for _, constantName in ipairs({ 'CONQUEST_CURRENCY_ID', 'HONOR_CURRENCY_ID', 'CLASSIC_HONOR_CURRENCY_ID', 'ACCOUNT_WIDE_HONOR_CURRENCY_ID' }) do
        local currencyID = Constants.CurrencyConsts[constantName]
        if currencyID then PVP_CURRENCY_IDS[currencyID] = true end
    end
end

local CREST_TIER_ORDER = { 'veteran', 'champion', 'hero', 'myth' }
local TRACKED_CURRENCY_PATTERNS = { 'manaflux' }
local HIDDEN_CURRENCY_PATTERNS = { 'adventurer', 'voidlight marl' }

local function IsPvPHeader(name)
    return name == PLAYER_V_PLAYER or name == PVP or name == PVP_LABEL_PVP
end

local function CrestTier(name)
    local lowered = name:lower()
    for tier, tierName in ipairs(CREST_TIER_ORDER) do
        if lowered:find(tierName, 1, true) then return tier end
    end
    return #CREST_TIER_ORDER + 1
end

local function MatchesAny(name, patterns)
    local lowered = name:lower()
    for _, pattern in ipairs(patterns) do
        if lowered:find(pattern, 1, true) then return true end
    end
    return false
end

local seasonCurrencies
local lastCurrencyScan = 0

local function DiscoverSeasonCurrencies()
    if GetTime() - lastCurrencyScan < CURRENCY_RESCAN then return end
    lastCurrencyScan = GetTime()
    local expanded = {}
    local index = 1
    while index <= C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(index)
        if info.isHeader and not info.isHeaderExpanded then
            C_CurrencyInfo.ExpandCurrencyList(index, true)
            expanded[info.name] = true
        end
        index = index + 1
    end

    local capped, extras, seen = {}, {}, {}
    local headerCount, inPvP = 0, false
    for entry = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local listInfo = C_CurrencyInfo.GetCurrencyListInfo(entry)
        if listInfo.isHeader then
            headerCount = headerCount + 1
            inPvP = IsPvPHeader(listInfo.name)
        elseif not inPvP then
            local link = C_CurrencyInfo.GetCurrencyListLink(entry)
            local currencyID = link and tonumber(link:match('currency:(%d+)'))
            if currencyID and not seen[currencyID] and not PVP_CURRENCY_IDS[currencyID] then
                local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
                if info and not MatchesAny(info.name, HIDDEN_CURRENCY_PATTERNS) then
                    if headerCount == 1 or MatchesAny(info.name, TRACKED_CURRENCY_PATTERNS) then
                        seen[currencyID] = true
                        extras[#extras + 1] = currencyID
                    elseif info.useTotalEarnedForMaxQty and info.maxQuantity > 0 then
                        seen[currencyID] = true
                        capped[#capped + 1] = { id = currencyID, quality = info.quality, tier = CrestTier(info.name), name = info.name, crest = info.name:lower():find('crest', 1, true) ~= nil }
                    end
                end
            end
        end
    end

    local crests = {}
    for _, candidate in ipairs(capped) do
        if candidate.crest then crests[#crests + 1] = candidate end
    end
    if #crests == 0 then crests = capped end
    table.sort(crests, function(left, right)
        if left.tier ~= right.tier then return left.tier < right.tier end
        if left.quality ~= right.quality then return left.quality < right.quality end
        return left.name < right.name
    end)

    index = 1
    while index <= C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(index)
        if info.isHeader and info.isHeaderExpanded and expanded[info.name] then C_CurrencyInfo.ExpandCurrencyList(index, false) end
        index = index + 1
    end

    if #crests + #extras == 0 then return end
    local crestIDs = {}
    for _, crest in ipairs(crests) do crestIDs[#crestIDs + 1] = crest.id end
    seasonCurrencies = { crests = crestIDs, extras = extras }
end

local function CurrencyRows(ids, rows, crest)
    for _, currencyID in ipairs(ids) do
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info then
            rows[#rows + 1] = { name = info.name, icon = info.iconFileID, quantity = info.quantity, max = BUI.Currency.Cap(currencyID, info), crest = crest }
        end
    end
end

local function SeasonCurrencies()
    if not seasonCurrencies then DiscoverSeasonCurrencies() end
    if not seasonCurrencies then return {} end
    local rows = {}
    CurrencyRows(seasonCurrencies.crests, rows, true)
    CurrencyRows(seasonCurrencies.extras, rows, false)
    return rows
end

local function SameRaidName(firstName, secondName)
    if not firstName or not secondName then return false end
    firstName = firstName:lower():gsub('^the%s+', '')
    secondName = secondName:lower():gsub('^the%s+', '')
    return firstName == secondName or firstName:find(secondName, 1, true) ~= nil or secondName:find(firstName, 1, true) ~= nil
end

local bossNameCache = {}
local function EncounterBossNames(raidName, instanceMapIDs)
    local cacheKey = raidName or (instanceMapIDs and instanceMapIDs[1])
    if cacheKey == nil then return nil end
    if bossNameCache[cacheKey] then return bossNameCache[cacheKey] end
    C_AddOns.LoadAddOn('Blizzard_EncounterJournal')
    local wanted = {}
    for _, mapID in ipairs(instanceMapIDs or {}) do wanted[mapID] = true end
    for tier = EJ_GetNumTiers(), 1, -1 do
        EJ_SelectTier(tier)
        local instanceIndex = 1
        while true do
            local journalID, instanceName, _, _, _, _, _, _, _, _, instanceMapID = EJ_GetInstanceByIndex(instanceIndex, true)
            if not journalID then break end
            if (instanceMapID and wanted[instanceMapID]) or SameRaidName(instanceName, raidName) then
                EJ_SelectInstance(journalID)
                local names, bossIndex = {}, 1
                while true do
                    local bossName = EJ_GetEncounterInfoByIndex(bossIndex, journalID)
                    if not bossName then break end
                    names[bossIndex] = bossName
                    bossIndex = bossIndex + 1
                end
                if #names > 0 then
                    bossNameCache[cacheKey] = names
                    return names
                end
            end
            instanceIndex = instanceIndex + 1
        end
    end
end

local function RaiderIORaidProgress()
    if type(RaiderIO) ~= 'table' or type(RaiderIO.GetProfile) ~= 'function' then return nil end
    local profile = RaiderIO.GetProfile('player')
    if type(profile) ~= 'table' then profile = RaiderIO.GetProfile(UnitName('player'), GetRealmName()) end
    local raidProfile = type(profile) == 'table' and profile.raidProfile
    if type(raidProfile) ~= 'table' then return nil end
    local progressList = raidProfile.progress or raidProfile.sortedProgress or raidProfile.raidProgress
    if type(progressList) ~= 'table' or #progressList == 0 then return nil end

    local raidsByName, orderedRaids = {}, {}
    for _, entry in ipairs(progressList) do
        local raid = entry.raid or entry.currentRaid
        local raidName = (type(raid) == 'table' and (raid.name or raid.shortName)) or entry.raidName
        local difficulty = tonumber(entry.difficulty or entry.diff)
        local kills = entry.killsPerBoss or entry.kills
        if raidName and difficulty and difficulty >= 1 and difficulty <= 3 and type(kills) == 'table' then
            local raidEntry = raidsByName[raidName]
            if not raidEntry then
                raidEntry = { name = raidName, bossCount = 0, diffs = {}, source = 'rio' }
                raidsByName[raidName] = raidEntry
                orderedRaids[#orderedRaids + 1] = raidEntry
            end
            local bossCount = (type(raid) == 'table' and raid.bossCount) or #kills
            if bossCount > raidEntry.bossCount then raidEntry.bossCount = bossCount end
            if not raidEntry.instanceMapIDs and type(raid) == 'table' then
                raidEntry.instanceMapIDs = raid.instance_map_ids or (raid.instance_map_id and { raid.instance_map_id })
            end
            local killed = 0
            for _, killCount in ipairs(kills) do
                if (tonumber(killCount) or 0) > 0 then killed = killed + 1 end
            end
            raidEntry.diffs[difficulty] = { killed = killed, kills = kills }
        end
    end
    if #orderedRaids == 0 then return nil end
    local topRaid = orderedRaids[1]
    topRaid.bosses = EncounterBossNames(topRaid.name, topRaid.instanceMapIDs)
    return topRaid
end

local LOCKOUT_DIFFICULTY_KEY = { [14] = 1, [15] = 2, [16] = 3 }

local function LockoutRaidProgress()
    local raidsByName, orderedRaids = {}, {}
    for instanceIndex = 1, GetNumSavedInstances() do
        local name, _, _, difficultyID, locked, extended, _, isRaid, _, _, encounterCount, encounterProgress = GetSavedInstanceInfo(instanceIndex)
        local difficultyKey = LOCKOUT_DIFFICULTY_KEY[difficultyID]
        if isRaid and (locked or extended) and difficultyKey then
            local raidEntry = raidsByName[name]
            if not raidEntry then
                raidEntry = { name = name, bossCount = 0, bosses = {}, diffs = {}, source = 'lockout' }
                raidsByName[name] = raidEntry
                orderedRaids[#orderedRaids + 1] = raidEntry
            end
            if encounterCount > raidEntry.bossCount then raidEntry.bossCount = encounterCount end
            local kills = {}
            for encounterIndex = 1, encounterCount do
                local bossName, _, isKilled = GetSavedInstanceEncounterInfo(instanceIndex, encounterIndex)
                kills[encounterIndex] = isKilled and 1 or 0
                if bossName and not raidEntry.bosses[encounterIndex] then raidEntry.bosses[encounterIndex] = bossName end
            end
            raidEntry.diffs[difficultyKey] = { killed = encounterProgress, kills = kills }
        end
    end
    if #orderedRaids == 0 then return nil end
    table.sort(orderedRaids, function(left, right)
        local leftKills, rightKills = 0, 0
        for _, info in pairs(left.diffs) do leftKills = leftKills + info.killed end
        for _, info in pairs(right.diffs) do rightKills = rightKills + info.killed end
        return leftKills > rightKills
    end)
    return orderedRaids[1]
end

local function RaidProgress()
    local rio = RaiderIORaidProgress()
    local lockout = LockoutRaidProgress()
    if not rio then return lockout end
    if not (lockout and SameRaidName(lockout.name, rio.name)) then return rio end

    if not rio.bosses and lockout.bosses[1] then rio.bosses = lockout.bosses end
    if lockout.bossCount > rio.bossCount then rio.bossCount = lockout.bossCount end

    local bossIndexByName = {}
    for bossIndex, bossName in ipairs(rio.bosses or {}) do bossIndexByName[bossName] = bossIndex end

    for difficultyKey, lockoutInfo in pairs(lockout.diffs) do
        local rioInfo = rio.diffs[difficultyKey]
        if not rioInfo then
            rioInfo = { killed = 0, kills = {} }
            rio.diffs[difficultyKey] = rioInfo
        end
        local merged = {}
        for bossIndex = 1, rio.bossCount do merged[bossIndex] = tonumber(rioInfo.kills[bossIndex]) or 0 end
        for lockoutIndex, kill in ipairs(lockoutInfo.kills) do
            if kill > 0 then
                local bossName = lockout.bosses[lockoutIndex]
                local mergedIndex = (bossName and bossIndexByName[bossName]) or lockoutIndex
                if (merged[mergedIndex] or 0) < 1 then merged[mergedIndex] = 1 end
            end
        end
        rioInfo.kills = merged
        local killed = 0
        for bossIndex = 1, rio.bossCount do
            if merged[bossIndex] > 0 then killed = killed + 1 end
        end
        rioInfo.killed = killed
    end
    return rio
end

local function FormatAgo(seconds)
    seconds = math.max(0, seconds)
    if seconds < 90 then return 'Now' end
    if seconds < 3600 then return ('%dm ago'):format(math.floor(seconds / 60)) end
    if seconds < 86400 then return ('%dh ago'):format(math.floor(seconds / 3600)) end
    return ('%dd ago'):format(math.floor(seconds / 86400))
end

local function SnapshotCurrentChar()
    local store = BUI.db.global.altOverview
    local key = CharacterKey()
    local previous = store[key]
    local _, equipped = GetAverageItemLevel()
    local itemLevel = math.floor(equipped + 0.5)
    if itemLevel == 0 and previous then itemLevel = previous.ilvl end
    local keyLevel, keyMap = OwnedKeystone()
    local _, classFile = UnitClass('player')
    store[key] = {
        name = UnitName('player'),
        realm = GetRealmName(),
        class = classFile,
        ilvl = itemLevel,
        score = math.floor(C_ChallengeMode.GetOverallDungeonScore() + 0.5),
        keyLevel = keyLevel,
        keyMap = keyMap,
        vault = { UnlockedCount(VaultActivities(VaultType.Raid)), UnlockedCount(VaultActivities(VaultType.Activities)), UnlockedCount(VaultActivities(VaultType.World)) },
        lastSeen = time(),
    }
end

local QueueSnapshot = BUI.Dispatcher.NewDelayed(SnapshotCurrentChar, SNAPSHOT_DELAY, 'Dashboard.Snapshot')
for _, event in ipairs({ 'PLAYER_AVG_ITEM_LEVEL_UPDATE', 'WEEKLY_REWARDS_UPDATE', 'CHALLENGE_MODE_COMPLETED', 'CHALLENGE_MODE_MAPS_UPDATE' }) do
    BUI.Events:Register(event, 'Dashboard.Snapshot', QueueSnapshot)
end

BUI.Events:Once('PLAYER_ENTERING_WORLD', 'Dashboard.SessionInit', function()
    local session = BUI.db.global.session
    local now = time()
    if not session.start or (session.lastSeen and now - session.lastSeen > SESSION_RESET_GAP) then session.start = now end
    sessionStart = session.start
    C_MythicPlus.RequestMapInfo()
    QueueSnapshot()
end)

BUI.Events:Register('PLAYER_LOGOUT', 'Dashboard.Logout', function()
    local now = time()
    BUI.db.global.session.lastSeen = now
    local entry = BUI.db.global.altOverview[CharacterKey()]
    if entry then entry.lastSeen = now end
end)

local function WeeklyResetTime()
    return math.floor((time() + C_DateAndTime.GetSecondsUntilWeeklyReset()) / 3600 + 0.5) * 3600
end

local function WeeklyHistory()
    local store = BUI.db.global.weeklyMplusHistory
    local key = CharacterKey()
    store[key] = store[key] or {}
    return store[key]
end

local function RecordWeeklyMplus(count)
    local resetTime = WeeklyResetTime()
    local history = WeeklyHistory()
    if count > (history[resetTime] or -1) then history[resetTime] = count end
    local resetTimes = {}
    for storedTime in pairs(history) do resetTimes[#resetTimes + 1] = storedTime end
    if #resetTimes > 8 then
        table.sort(resetTimes, function(left, right) return left > right end)
        for index = 9, #resetTimes do history[resetTimes[index]] = nil end
    end
end

local function WeeklyHistoryRows()
    local history = WeeklyHistory()
    local resetTimes = {}
    for storedTime in pairs(history) do resetTimes[#resetTimes + 1] = storedTime end
    table.sort(resetTimes, function(left, right) return left > right end)
    local currentReset = WeeklyResetTime()
    local rows = {}
    for index, resetTime in ipairs(resetTimes) do
        rows[index] = { left = resetTime == currentReset and 'This week' or date('Week of %b %d', resetTime - 7 * 86400), right = tostring(history[resetTime]) }
    end
    return rows
end

local function SeasonBestRuns()
    local runs = {}
    for _, mapID in ipairs(C_ChallengeMode.GetMapTable()) do
        local intime, overtime = C_MythicPlus.GetSeasonBestForMap(mapID)
        local best = intime
        if overtime and (not best or overtime.dungeonScore > best.dungeonScore) then best = overtime end
        if best then
            local name, _, timeLimit, icon = C_ChallengeMode.GetMapUIInfo(mapID)
            runs[#runs + 1] = { name = name, icon = icon, level = best.level, duration = best.durationSec, limit = timeLimit, score = best.dungeonScore }
        end
    end
    table.sort(runs, function(left, right)
        if left.level ~= right.level then return left.level > right.level end
        return left.score > right.score
    end)
    return runs
end

local function SeasonSummary()
    local best, timed, total = 0, 0, 0
    for _, run in ipairs(C_MythicPlus.GetRunHistory(true, true, true)) do
        total = total + 1
        if run.completed and run.durationSec <= (select(3, C_ChallengeMode.GetMapUIInfo(run.mapChallengeModeID))) then
            timed = timed + 1
            best = math.max(best, run.level)
        end
    end
    return best, timed, total
end

local activeSlideIn

local function FinishSlideIn(state)
    state.ticker:SetScript('OnUpdate', nil)
    for index, card in ipairs(state.cards) do
        local anchor = state.anchors[index]
        card:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
        card:SetAlpha(1)
    end
end

local function SlideIn(cards, ticker)
    if activeSlideIn then FinishSlideIn(activeSlideIn) end
    local STAGGER, DURATION, OFFSET = 0.045, 0.38, -18
    local shown, anchors = {}, {}
    for _, card in ipairs(cards) do
        if card:IsShown() then
            local point, relative, relativePoint, x, y = card:GetPoint(1)
            shown[#shown + 1] = card
            anchors[#anchors + 1] = { point, relative, relativePoint, x, y }
            card:SetPoint(point, relative, relativePoint, x, y + OFFSET)
            card:SetAlpha(0)
        end
    end
    if #shown == 0 then return end
    local start = GetTime()
    local state = { ticker = ticker, cards = shown, anchors = anchors }
    activeSlideIn = state
    ticker:SetScript('OnUpdate', BUI.Profiler.Hot('Pages.Dashboard card slide', function(self)
        local now, done = GetTime(), true
        for index, card in ipairs(shown) do
            local anchor = anchors[index]
            local progress = (now - start - (index - 1) * STAGGER) / DURATION
            if progress < 1 then
                done = false
                local eased = progress <= 0 and 0 or 1 - (1 - progress) ^ 3
                card:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], math.floor(anchor[5] + OFFSET * (1 - eased) + 0.5))
                card:SetAlpha(eased)
            end
        end
        if done then
            FinishSlideIn(state)
            if activeSlideIn == state then activeSlideIn = nil end
        end
    end))
end

local window, kit, block

local function Tint(region, red, green, blue)
    window:Paint(region, function(target) target:SetTextColor(red, green, blue) end)
end

local function Card(title)
    local card = CreateFrame('Frame', nil, block)
    local fill, edge = Widget.DrawCardShape(card, CARD_RADIUS, WHITE, WHITE, 'BACKGROUND', 0, 0)
    window:Paint(fill, 'card')
    window:Paint(edge, 'cardEdge')
    if title then
        local bar = kit.Fill(card, 'accent', 'ARTWORK')
        bar:SetSize(ACCENT_WIDTH, ACCENT_HEIGHT)
        bar:SetPoint('TOPLEFT', PAD, -TITLE_Y + ACCENT_HEIGHT / 2)
        card.title = kit.Text(card, title, 14, 'text')
        card.title:SetPoint('LEFT', bar, 'RIGHT', TITLE_GAP, 0)
    end
    return card
end

local function Inset(parent, frameType)
    local frame = CreateFrame(frameType or 'Frame', nil, parent)
    window:Paint(Widget.DrawOutline(frame, INSET_RADIUS, WHITE, 'BACKGROUND', 1), 'cardEdge')
    return frame
end

local function Chevron(parent)
    local glyph = kit.Glyph(parent, 'dropdown', CHEVRON_SIZE, 'muted')
    glyph:SetTexCoord(unpack(POINT_RIGHT))
    return glyph
end

local function Empty(card, text)
    local label = kit.Text(card, text, 12, 'muted')
    label:SetPoint('TOPLEFT', PAD, -CONTENT_TOP)
    label:Hide()
    return label
end

local function Rule(parent)
    local rule = kit.Fill(parent, 'cardEdge', 'ARTWORK')
    rule:SetHeight(1)
    return rule
end

local function Tip(owner, title, rows)
    Widget.ShowTipRows(owner, title, rows, { anchor = 'RIGHT' })
end

local function Dash(region)
    region:SetText('—')
    window:Paint(region, 'faint')
end

local function Place(region, y)
    region:ClearAllPoints()
    region:SetPoint('TOPLEFT', PAD, -y)
    region:SetPoint('TOPRIGHT', -PAD, -y)
end

local function Hover(button, chevron, tip)
    button:SetScript('OnEnter', function(self)
        window:Paint(chevron, 'text')
        Tip(self, tip())
    end)
    button:SetScript('OnLeave', function()
        window:Paint(chevron, 'muted')
        Widget.HideTip()
    end)
end

local function SideRow(parent, label, tip)
    local row = Inset(parent, 'Button')
    local title = kit.Text(row, label, 12, 'text')
    title:SetPoint('TOPLEFT', LINK_INSET, -SIDE_TEXT_Y)
    row.value = kit.Text(row, '', 11, 'muted')
    row.value:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -2)
    local chevron = Chevron(row)
    chevron:SetPoint('RIGHT', -CHEVRON_INSET, 0)
    Hover(row, chevron, tip)
    return row
end

local function HeaderLink(card, label, tip)
    local link = CreateFrame('Button', nil, card)
    link:SetHeight(LINK_HEIGHT)
    link:SetPoint('RIGHT', card, 'TOPRIGHT', -PAD, -TITLE_Y)
    local chevron = Chevron(link)
    chevron:SetPoint('RIGHT')
    local text = kit.Text(link, label, 12, 'muted')
    text:SetPoint('RIGHT', chevron, 'LEFT', -LINK_GAP, 0)
    window:Bind(link, function() link:SetWidth(math.ceil(text:GetStringWidth()) + LINK_GAP + CHEVRON_SIZE) end)
    Hover(link, chevron, tip)
    return link
end

local function TableHead(card, columns)
    local heads = {}
    for _, column in ipairs(columns) do
        heads[#heads + 1] = { label = kit.Text(card, column[1], 11, 'faint'), x = column[2] }
    end
    return heads
end

local function PlaceHead(heads, width)
    local inner = width - PAD * 2
    for _, head in ipairs(heads) do
        head.label:ClearAllPoints()
        head.label:SetPoint('TOPLEFT', PAD + inner * head.x, -TABLE_TOP)
    end
end

local function BuildHeader(onCards)
    local greeting = kit.Text(block, 'Welcome back, ' .. UnitName('player'), 22, 'text')
    greeting:SetPoint('TOPLEFT')
    local specLine = kit.Text(block, '', 13, 'muted')
    specLine:SetPoint('TOPLEFT', greeting, 'BOTTOMLEFT', 0, -2)
    local options = {}
    for _, entry in ipairs(CARDS) do
        options[#options + 1] = {
            label = entry.label, separator = entry.separator,
            get = function() return CardShown(entry.id) end,
            set = function(value) DashboardDB().cardVisibility[entry.id] = value end,
        }
    end
    kit.Tool(block, { icon = 'cog', tooltip = 'Choose cards', title = 'Cards', options = options }, onCards):SetPoint('TOPRIGHT', 0, -4)
    return { Refresh = function() specLine:SetText(SpecLine()) end }
end

local function BuildStats()
    local strip = Card()
    strip.cells = {}
    local function Stat(id, kicker)
        local cell = CreateFrame('Frame', nil, strip)
        cell.id = id
        cell.icon = cell:CreateTexture(nil, 'ARTWORK')
        cell.icon:SetSize(STAT_ICON, STAT_ICON)
        cell.icon:SetPoint('LEFT', PAD, 0)
        cell.kicker = kit.Text(cell, kicker, 10, 'muted')
        cell.kicker:SetPoint('TOPLEFT', STAT_TEXT_X, -STAT_KICKER_Y)
        cell.value = kit.Text(cell, '', 26, 'text')
        cell.value:SetPoint('TOPLEFT', cell.kicker, 'BOTTOMLEFT', 0, -4)
        cell.sub = kit.Text(cell, '', 12, 'muted')
        cell.sub:SetPoint('BOTTOMLEFT', cell.value, 'BOTTOMRIGHT', VALUE_GAP, 3)
        cell.divider = kit.Fill(cell, 'cardEdge', 'ARTWORK')
        cell.divider:SetPoint('TOPLEFT', 0, -DIVIDER_INSET)
        cell.divider:SetPoint('BOTTOMLEFT', 0, DIVIDER_INSET)
        cell.divider:SetWidth(1)
        strip.cells[#strip.cells + 1] = cell
        return cell
    end

    local score = Stat('stat_mscore', 'M+ SCORE')
    score.icon:SetTexture(C_Item.GetItemIconByID(KEYSTONE_ITEM))
    score.icon:SetTexCoord(unpack(ICON_CROP))
    score.sub:SetText('This season')
    local level = Stat('stat_ilvl', 'ITEM LEVEL')
    level.icon:SetTexCoord(unpack(ICON_CROP))
    level.icon:SetDesaturated(true)
    local weekly = Stat('weeklyMplus', 'WEEKLY M+')
    weekly.icon:SetTexture(BUILib.GetLibMedia('reload'))
    window:Paint(weekly.icon, 'muted')
    weekly.sub:SetText('Runs completed')
    weekly:EnableMouse(true)
    weekly:SetScript('OnEnter', function(self)
        local rows = WeeklyHistoryRows()
        rows[#rows + 1] = { space = true }
        rows[#rows + 1] = { left = 'This season', right = tostring(#C_MythicPlus.GetRunHistory(true, false, true)) }
        Tip(self, 'Weekly M+ runs', rows)
    end)
    weekly:SetScript('OnLeave', Widget.HideTip)
    local session = Stat('stat_session', 'SESSION')
    session.icon:SetTexture(BUILib.GetLibMedia('clock'))
    window:Paint(session.icon, 'muted')

    function strip.RefreshSession()
        session.value:SetText(SessionText())
    end

    function strip.Refresh()
        local rating = math.floor(C_ChallengeMode.GetOverallDungeonScore())
        local red, green, blue = ColorOf(C_ChallengeMode.GetDungeonScoreRarityColor(rating))
        score.value:SetText(rating)
        Tint(score.value, red, green, blue)
        Tint(score.kicker, red, green, blue)
        local overall, equipped = GetAverageItemLevel()
        level.value:SetText(math.floor(equipped + 0.5))
        level.sub:SetText(math.floor(overall + 0.5) .. ' overall')
        level.icon:SetTexture(GetInventoryItemTexture('player', INVSLOT_HEAD))
        local runs = WeeklyMplusCount()
        RecordWeeklyMplus(runs)
        weekly.value:SetText(runs)
        strip.RefreshSession()
    end

    function strip:Layout(width, shown)
        local cellWidth = width / #shown
        for index, cell in ipairs(shown) do
            cell:ClearAllPoints()
            cell:SetPoint('TOPLEFT', (index - 1) * cellWidth, 0)
            cell:SetSize(cellWidth, STRIP_HEIGHT)
            cell.divider:SetShown(index > 1)
        end
    end
    return strip
end

local function SlotRows(thresholdType, noun)
    local rows = {}
    for _, activity in ipairs(VaultActivities(thresholdType)) do
        local open = Unlocked(activity)
        local itemLevel = open and RewardItemLevel(activity)
        rows[#rows + 1] = {
            left = ('%d %s'):format(activity.threshold, noun),
            right = open and ((VaultSlotLabel(activity) or '') .. (itemLevel and ('  ' .. itemLevel) or '')) or ('%d / %d'):format(activity.progress, activity.threshold),
        }
    end
    return rows
end

local function SlotSummary(row, thresholdType, noun)
    local activities = VaultActivities(thresholdType)
    local last = activities[#activities]
    row.value:SetText(last and ('%d / %d %s'):format(math.min(last.progress, last.threshold), last.threshold, noun) or '')
end

local function BuildVault()
    local vault = Card('Great Vault')
    vault.id = 'vault'
    kit.Text(vault, 'ITEM LEVEL', 10, 'faint'):SetPoint('TOPLEFT', vault.title, 'BOTTOMLEFT', 0, -3)
    local status = kit.Text(vault, '', 12, 'muted')
    status:SetPoint('RIGHT', vault, 'TOPRIGHT', -PAD, -TITLE_Y)
    local statusMark = kit.Glyph(vault, 'check', STATUS_MARK, 'positive')
    statusMark:SetPoint('RIGHT', status, 'LEFT', -MARK_GAP, 0)

    local columns = {}
    for slot = 1, 3 do
        local column = CreateFrame('Frame', nil, vault)
        column.label = kit.Text(column, '', 12, 'muted')
        column.label:SetPoint('TOP', 0, -COLUMN_LABEL_Y)
        column.value = kit.Text(column, '', 28, 'text')
        column.value:SetPoint('TOP', column.label, 'BOTTOM', 0, -2)
        column.progress = kit.Text(column, '', 12, 'muted')
        column.mark = kit.Glyph(column, 'check', CHECK_MARK, 'accent')
        column.mark:SetPoint('RIGHT', column.progress, 'LEFT', -MARK_GAP, 0)
        if slot > 1 then
            local divider = kit.Fill(column, 'cardEdge', 'ARTWORK')
            divider:SetPoint('TOPLEFT', 0, -DIVIDER_INSET)
            divider:SetPoint('BOTTOMLEFT', 0, DIVIDER_INSET)
            divider:SetWidth(1)
        end
        columns[slot] = column
    end
    local raids = SideRow(vault, 'Raids', function() return 'Raid slots', SlotRows(VaultType.Raid, 'bosses') end)
    local world = SideRow(vault, 'World', function() return 'World slots', SlotRows(VaultType.World, 'activities') end)

    local waiting = false
    local function WaitForItem(link)
        if waiting then return end
        local item = Item:CreateFromItemLink(link)
        if item:IsItemEmpty() then return end
        waiting = true
        item:ContinueOnItemLoad(function()
            waiting = false
            vault.Refresh()
        end)
    end

    function vault.Refresh()
        local dungeons = VaultActivities(VaultType.Activities)
        local need
        for slot, column in ipairs(columns) do
            local activity = dungeons[slot]
            column:SetShown(activity ~= nil)
            if activity then
                local open = Unlocked(activity)
                column.label:SetText(activity.threshold == 1 and '1 run' or (activity.threshold .. ' runs'))
                column.progress:SetText(('%d / %d'):format(math.min(activity.progress, activity.threshold), activity.threshold))
                column.progress:SetPoint('TOP', column.value, 'BOTTOM', open and (CHECK_MARK + MARK_GAP) / 2 or 0, -4)
                column.mark:SetShown(open)
                if open then
                    local itemLevel = RewardItemLevel(activity)
                    column.value:SetText(itemLevel or '...')
                    window:Paint(column.value, 'text')
                    if not itemLevel then
                        local link = RewardLink(activity)
                        if link then WaitForItem(link) end
                    end
                else
                    need = need or (activity.threshold - activity.progress)
                    Dash(column.value)
                end
            end
        end
        statusMark:SetShown(#dungeons > 0 and not need)
        if need then
            status:SetText(need == 1 and '1 more run' or (need .. ' more runs'))
        else
            status:SetText(#dungeons > 0 and 'All unlocked' or '')
        end
        SlotSummary(raids, VaultType.Raid, 'bosses')
        SlotSummary(world, VaultType.World, 'activities')
    end

    function vault:Layout(width)
        local columnWidth = (width - PAD * 2 - VAULT_SIDE - TILE_GAP) / 3
        for slot, column in ipairs(columns) do
            column:ClearAllPoints()
            column:SetPoint('TOPLEFT', PAD + (slot - 1) * columnWidth, -COLUMNS_TOP)
            column:SetSize(columnWidth, TILE_HEIGHT)
        end
        local rowHeight = (TILE_HEIGHT - LINK_GAP) / 2
        for index, row in ipairs({ raids, world }) do
            row:ClearAllPoints()
            row:SetPoint('TOPLEFT', width - PAD - VAULT_SIDE, -(COLUMNS_TOP + (index - 1) * (rowHeight + LINK_GAP)))
            row:SetSize(VAULT_SIDE, rowHeight)
        end
        return COLUMNS_TOP + TILE_HEIGHT + BOTTOM_PAD
    end
    return vault
end

local function BossRows(raid)
    local rows = {}
    for bossIndex = 1, raid.bossCount do
        local marks = {}
        for key, difficulty in ipairs(RAID_DIFFICULTIES) do
            local info = raid.diffs[key]
            local killed = info and (tonumber(info.kills[bossIndex]) or 0) > 0
            local red, green, blue = unpack(difficulty.color)
            marks[#marks + 1] = killed and ('|cff%02x%02x%02x%s|r'):format(math.floor(red * 255), math.floor(green * 255), math.floor(blue * 255), difficulty.short) or ('|cff555a62%s|r'):format(difficulty.short)
        end
        rows[#rows + 1] = { left = (raid.bosses and raid.bosses[bossIndex]) or ('Boss ' .. bossIndex), right = table.concat(marks, ' ') }
    end
    return rows
end

local function BuildRaid()
    local raid = Card('Raid progress')
    raid.id = 'raidprog'
    local current
    local bosses = HeaderLink(raid, 'Bosses', function() return current.name, BossRows(current) end)
    local name = kit.Text(raid, '', 12, 'muted')
    name:SetPoint('LEFT', raid.title, 'RIGHT', TITLE_GAP, 0)
    name:SetPoint('RIGHT', bosses, 'LEFT', -TITLE_GAP, 0)
    name:SetWordWrap(false)
    local empty = Empty(raid, 'No raid data yet.')
    local bars = {}
    for index, difficulty in ipairs(RAID_DIFFICULTIES) do
        local row = CreateFrame('Frame', nil, raid)
        row:SetHeight(RAID_ROW)
        kit.Text(row, difficulty.label, 12, 'text'):SetPoint('LEFT')
        row.track = CreateFrame('Frame', nil, row)
        row.track:SetHeight(BAR_HEIGHT)
        row.track:SetPoint('LEFT', RAID_LABEL, 0)
        row.track:SetPoint('RIGHT', -RAID_COUNT, 0)
        local trackFill, trackEdge = Widget.DrawCardShape(row.track, BAR_RADIUS, WHITE, WHITE, 'ARTWORK', 0, 0)
        window:Paint(trackFill, 'control')
        window:Paint(trackEdge, 'control')
        row.fill = CreateFrame('Frame', nil, row.track)
        row.fill:SetPoint('TOPLEFT')
        row.fill:SetPoint('BOTTOMLEFT')
        local barFill, barEdge = Widget.DrawCardShape(row.fill, BAR_RADIUS, WHITE, WHITE, 'ARTWORK', 2, 0)
        local red, green, blue = unpack(difficulty.color)
        barFill:SetVertexColor(red, green, blue, 1)
        barEdge:SetVertexColor(red, green, blue, 1)
        row.count = kit.Text(row, '', 12, 'muted')
        row.count:SetPoint('RIGHT')
        row.fraction = 0
        bars[index] = row
    end

    function raid.Refresh()
        current = RaidProgress()
        local hasRaid = current ~= nil and current.bossCount > 0
        empty:SetShown(not hasRaid)
        name:SetShown(hasRaid)
        bosses:SetShown(hasRaid)
        for key, row in ipairs(bars) do
            row:SetShown(hasRaid)
            if hasRaid then
                local info = current.diffs[key]
                local killed = info and info.killed or 0
                row.count:SetText(('%d / %d'):format(killed, current.bossCount))
                row.fraction = killed / current.bossCount
                if killed > 0 then Tint(row.count, unpack(RAID_DIFFICULTIES[key].color)) else window:Paint(row.count, 'muted') end
            end
        end
        if hasRaid then name:SetText(current.name .. (current.source == 'lockout' and '  ·  this week' or '')) end
    end

    function raid:Layout(width)
        local trackWidth = width - PAD * 2 - RAID_LABEL - RAID_COUNT
        local y = RAID_ROWS_TOP
        for _, row in ipairs(bars) do
            Place(row, y)
            row.fill:SetWidth(math.max(BAR_HEIGHT, trackWidth * row.fraction))
            row.fill:SetShown(row.fraction > 0)
            y = y + RAID_ROW
        end
        return y + BOTTOM_PAD
    end
    return raid
end

local function BuildKeys()
    local keys = Card('Best keys')
    keys.id = 'dungeons'
    kit.Text(keys, 'This season', 12, 'muted'):SetPoint('LEFT', keys.title, 'RIGHT', TITLE_GAP + 4, 0)
    local summary = kit.Text(keys, '', 12, 'muted')
    summary:SetPoint('RIGHT', keys, 'TOPRIGHT', -PAD, -TITLE_Y)
    local empty = Empty(keys, 'No timed keys this season yet.')
    local heads = TableHead(keys, { { 'Dungeon', 0 }, { 'Key', KEY_COLUMNS.key }, { 'Time', KEY_COLUMNS.time }, { 'Under time', KEY_COLUMNS.under } })
    local rows = {}
    for index = 1, KEY_ROWS do
        local row = CreateFrame('Frame', nil, keys)
        row:SetHeight(KEY_ROW)
        row.rule = Rule(row)
        row.rule:SetPoint('TOPLEFT')
        row.rule:SetPoint('TOPRIGHT')
        row.rule:SetShown(index > 1)
        row.icon = row:CreateTexture(nil, 'ARTWORK')
        row.icon:SetSize(DUNGEON_ICON, DUNGEON_ICON)
        row.icon:SetPoint('LEFT')
        row.icon:SetTexCoord(unpack(ICON_CROP))
        row.name = kit.Text(row, '', 12, 'text')
        row.name:SetPoint('LEFT', DUNGEON_ICON + ICON_GAP, 0)
        row.name:SetWordWrap(false)
        row.key = kit.Text(row, '', 12, 'text')
        row.time = kit.Text(row, '', 12, 'text')
        row.under = kit.Text(row, '', 12, 'text')
        rows[index] = row
    end

    function keys.Refresh()
        local runs = SeasonBestRuns()
        empty:SetShown(#runs == 0)
        for _, head in ipairs(heads) do head.label:SetShown(#runs > 0) end
        for index, row in ipairs(rows) do
            local run = runs[index]
            row:SetShown(run ~= nil)
            if run then
                row.icon:SetTexture(run.icon)
                row.name:SetText(run.name)
                row.key:SetText('+' .. run.level)
                Tint(row.key, ColorOf(C_ChallengeMode.GetKeystoneLevelRarityColor(run.level)))
                row.time:SetText(Clock(run.duration))
                local spare = run.limit - run.duration
                row.under:SetText(spare >= 0 and Clock(spare) or ('+' .. Clock(-spare)))
                if spare >= 0 then Tint(row.under, 0.36, 0.83, 0.48) else window:Paint(row.under, 'danger') end
            end
        end
        local best, timed, total = SeasonSummary()
        summary:SetText(total > 0 and ('Best +%d  ·  Timed %d/%d'):format(best, timed, total) or '')
    end

    function keys:Layout(width)
        local inner = width - PAD * 2
        PlaceHead(heads, width)
        local y = TABLE_ROWS_TOP
        for _, row in ipairs(rows) do
            Place(row, y)
            row.name:SetWidth(inner * KEY_COLUMNS.key - DUNGEON_ICON - ICON_GAP * 2)
            row.key:SetPoint('LEFT', inner * KEY_COLUMNS.key, 0)
            row.time:SetPoint('LEFT', inner * KEY_COLUMNS.time, 0)
            row.under:SetPoint('LEFT', inner * KEY_COLUMNS.under, 0)
            y = y + KEY_ROW
        end
        return y + BOTTOM_PAD
    end
    return keys
end

local function BuildCurrencies()
    local currencies = Card('Currencies')
    currencies.id = 'crests'
    local empty = Empty(currencies, 'No season currencies found yet.')
    local rule = Rule(currencies)
    local rows = {}
    for index = 1, CURRENCY_ROWS do
        local row = CreateFrame('Frame', nil, currencies)
        row:SetHeight(CURRENCY_ROW)
        row.icon = row:CreateTexture(nil, 'ARTWORK')
        row.icon:SetSize(CURRENCY_ICON, CURRENCY_ICON)
        row.icon:SetPoint('LEFT')
        row.icon:SetTexCoord(unpack(ICON_CROP))
        row.value = kit.Text(row, '', 12, 'text')
        row.value:SetPoint('RIGHT')
        row.name = kit.Text(row, '', 12, 'text')
        row.name:SetPoint('LEFT', CURRENCY_ICON + ICON_GAP, 0)
        row.name:SetPoint('RIGHT', row.value, 'LEFT', -ICON_GAP, 0)
        row.name:SetWordWrap(false)
        rows[index] = row
    end
    local data = {}

    function currencies.Refresh()
        data = SeasonCurrencies()
        empty:SetShown(#data == 0)
        for index, row in ipairs(rows) do
            local currency = data[index]
            row:SetShown(currency ~= nil)
            if currency then
                row.icon:SetTexture(currency.icon)
                row.name:SetText(currency.name)
                row.value:SetText(currency.max > 0 and ('%d / %d'):format(currency.quantity, currency.max) or currency.quantity)
            end
        end
    end

    function currencies:Layout()
        local y = TABLE_TOP - 4
        local previousCrest = false
        rule:Hide()
        for index = 1, math.min(#data, CURRENCY_ROWS) do
            local currency = data[index]
            if previousCrest and not currency.crest then
                Place(rule, y + GROUP_RULE / 2)
                rule:Show()
                y = y + GROUP_RULE
            end
            previousCrest = currency.crest
            Place(rows[index], y)
            y = y + CURRENCY_ROW
        end
        return y + BOTTOM_PAD
    end
    return currencies
end

local function SortedCharacters(me)
    local list = {}
    for key, character in pairs(BUI.db.global.altOverview) do list[#list + 1] = { key = key, data = character } end
    table.sort(list, function(left, right)
        if (left.key == me) ~= (right.key == me) then return left.key == me end
        return left.data.lastSeen > right.data.lastSeen
    end)
    return list
end

local function FillCharacterRow(row, character, isMe, now, lastReset)
    row.highlight:SetShown(isMe)
    row.icon:SetAtlas('classicon-' .. character.class:lower())
    row.name:SetText(character.realm ~= GetRealmName() and (character.name .. '-' .. character.realm) or character.name)
    Tint(row.name, ColorOf(RAID_CLASS_COLORS[character.class]))
    if character.ilvl > 0 then
        row.ilvl:SetText(character.ilvl)
        window:Paint(row.ilvl, 'text')
    else
        Dash(row.ilvl)
    end
    row.score:SetText(character.score)
    Tint(row.score, ColorOf(C_ChallengeMode.GetDungeonScoreRarityColor(character.score)))
    local fresh = isMe or character.lastSeen >= lastReset
    if fresh and character.keyLevel then
        row.key:SetText(('+%d %s'):format(character.keyLevel, character.keyMap))
        window:Paint(row.key, 'text')
    else
        Dash(row.key)
    end
    if fresh then
        row.vault:SetText(('%d / %d / %d'):format(character.vault[1], character.vault[2], character.vault[3]))
        window:Paint(row.vault, 'text')
    else
        Dash(row.vault)
    end
    row.seen:SetText(isMe and 'Now' or FormatAgo(now - character.lastSeen))
    window:Paint(row.seen, 'muted')
end

local function BuildCharacters()
    local characters = Card('Characters')
    local count = kit.Text(characters, '', 12, 'muted')
    count:SetPoint('LEFT', characters.title, 'RIGHT', TITLE_GAP + 4, 0)
    local heads = TableHead(characters, {
        { 'Character', 0 }, { 'Item level', CHAR_COLUMNS.ilvl }, { 'M+ score', CHAR_COLUMNS.score },
        { 'Keystone', CHAR_COLUMNS.key }, { 'Vault', CHAR_COLUMNS.vault }, { 'Last seen', CHAR_COLUMNS.seen },
    })
    local rows = {}
    for index = 1, CHAR_ROWS do
        local row = CreateFrame('Frame', nil, characters)
        row:SetHeight(CHAR_ROW)
        row.highlight = kit.Fill(row, 'hover', 'BACKGROUND')
        row.highlight:SetAllPoints()
        row.icon = row:CreateTexture(nil, 'ARTWORK')
        row.icon:SetSize(CLASS_ICON, CLASS_ICON)
        row.icon:SetPoint('LEFT', 4, 0)
        row.name = kit.Text(row, '', 12, 'text')
        row.name:SetPoint('LEFT', CLASS_ICON + ICON_GAP + 4, 0)
        row.name:SetWordWrap(false)
        for field in pairs(CHAR_COLUMNS) do
            row[field] = kit.Text(row, '', 12, 'text')
            row[field]:SetWordWrap(false)
        end
        rows[index] = row
    end
    local total = 0

    function characters.Refresh()
        SnapshotCurrentChar()
        local me = CharacterKey()
        local list = SortedCharacters(me)
        total = #list
        count:SetText(total == 1 and '1 character' or (total .. ' characters'))
        local now = time()
        local lastReset = now + C_DateAndTime.GetSecondsUntilWeeklyReset() - 7 * 86400
        for index, row in ipairs(rows) do
            local entry = list[index]
            row:SetShown(entry ~= nil)
            if entry then FillCharacterRow(row, entry.data, entry.key == me, now, lastReset) end
        end
    end

    function characters:Layout(width)
        local inner = width - PAD * 2
        PlaceHead(heads, width)
        local y = TABLE_ROWS_TOP
        for index = 1, math.min(total, CHAR_ROWS) do
            local row = rows[index]
            Place(row, y)
            row.name:SetWidth(inner * CHAR_COLUMNS.ilvl - CLASS_ICON - ICON_GAP * 2)
            for field, fraction in pairs(CHAR_COLUMNS) do row[field]:SetPoint('LEFT', inner * fraction, 0) end
            y = y + CHAR_ROW
        end
        return y + BOTTOM_PAD
    end
    return characters
end

local function BuildDashboard(pageFrame)
    window = BUI.PageEngine.window
    kit = Layout.TableKit(window)
    local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
    local tab = page:GetTab(1)
    block = CreateFrame('Frame', nil, tab.child)
    block:SetWidth(PAGE_WIDTH)

    local Relayout
    local header = BuildHeader(function() Relayout() end)
    local strip = BuildStats()
    local vault, raid, keys, currencies, characters = BuildVault(), BuildRaid(), BuildKeys(), BuildCurrencies(), BuildCharacters()
    local cards = { strip, vault, raid, keys, currencies, characters }
    local panes = {
        { cards = { strip, vault, raid, keys, currencies }, strip = true, rows = { { vault, raid }, { keys, currencies } } },
        { cards = { characters }, rows = { { characters } } },
    }
    local selected = 1
    local slideTicker = CreateFrame('Frame', nil, block)

    local function PlaceStrip(y)
        local shown = {}
        for _, cell in ipairs(strip.cells) do
            cell:SetShown(CardShown(cell.id))
            if cell:IsShown() then shown[#shown + 1] = cell end
        end
        strip:SetShown(#shown > 0)
        if #shown == 0 then return y end
        strip:ClearAllPoints()
        strip:SetPoint('TOPLEFT', 0, -y)
        strip:SetSize(PAGE_WIDTH, STRIP_HEIGHT)
        strip:Layout(PAGE_WIDTH, shown)
        return y + STRIP_HEIGHT + GAP
    end

    local function PlaceRows(rows, y)
        for _, row in ipairs(rows) do
            local shown = {}
            for _, card in ipairs(row) do
                card:SetShown(not card.id or CardShown(card.id))
                if card:IsShown() then shown[#shown + 1] = card end
            end
            if #shown > 0 then
                local widths = #shown == 2 and { LEFT_WIDTH, PAGE_WIDTH - LEFT_WIDTH - GAP } or { PAGE_WIDTH }
                local height = 0
                for index, card in ipairs(shown) do height = math.max(height, card:Layout(widths[index])) end
                local x = 0
                for index, card in ipairs(shown) do
                    card:ClearAllPoints()
                    card:SetPoint('TOPLEFT', x, -y)
                    card:SetSize(widths[index], height)
                    x = x + widths[index] + GAP
                end
                y = y + height + GAP
            end
        end
        return y
    end

    SnapshotCurrentChar()
    local characterCount = 0
    for _ in pairs(BUI.db.global.altOverview) do characterCount = characterCount + 1 end
    local contentTop = kit.Tabs(block, HEADER_HEIGHT, { 'Overview', 'Characters (' .. characterCount .. ')' }, function(index)
        selected = index
        Relayout()
        SlideIn(panes[index].cards, slideTicker)
    end) + TABS_GAP

    Relayout = function()
        for _, card in ipairs(cards) do card:Hide() end
        local pane = panes[selected]
        local y = contentTop
        if pane.strip then y = PlaceStrip(y) end
        y = PlaceRows(pane.rows, y)
        block:SetHeight(y)
        block.layoutHeight = y
        BUILib.Defer(function() tab:Refresh() end)
    end

    local function Both(first, second) return function() first() second() end end
    local handlers = {
        PLAYER_EQUIPMENT_CHANGED = strip.Refresh,
        PLAYER_AVG_ITEM_LEVEL_UPDATE = strip.Refresh,
        PLAYER_SPECIALIZATION_CHANGED = header.Refresh,
        CHALLENGE_MODE_COMPLETED = Both(strip.Refresh, keys.Refresh),
        CHALLENGE_MODE_MAPS_UPDATE = Both(strip.Refresh, keys.Refresh),
        WEEKLY_REWARDS_UPDATE = Both(strip.Refresh, vault.Refresh),
        UPDATE_INSTANCE_INFO = raid.Refresh,
        BOSS_KILL = raid.Refresh,
        CURRENCY_DISPLAY_UPDATE = currencies.Refresh,
    }
    for event in pairs(handlers) do block:RegisterEvent(event) end
    block:SetScript('OnEvent', BUI.Profiler.Wrap('Pages.Dashboard event', function(self, event)
        if not self:IsVisible() then return end
        handlers[event]()
        Relayout()
    end))

    local sessionTicker
    block:SetScript('OnShow', function()
        C_MythicPlus.RequestMapInfo()
        RequestRaidInfo()
        header.Refresh()
        for _, card in ipairs(cards) do card.Refresh() end
        Relayout()
        sessionTicker = sessionTicker or C_Timer.NewTicker(SESSION_TICK, strip.RefreshSession)
        SlideIn(panes[selected].cards, slideTicker)
    end)
    block:SetScript('OnHide', function()
        if sessionTicker then
            sessionTicker:Cancel()
            sessionTicker = nil
        end
    end)

    Relayout()
    Layout.Add(tab, block, -Layout.DEFAULT_PADDING)
    page:AutoRefresh()
end

BUI.PageEngine.RegisterPage('dashboard', {
    title = 'Dashboard',
    buttonText = 'Dashboard',
    icon = 'dashboard',
    OnBuild = BuildDashboard,
})
