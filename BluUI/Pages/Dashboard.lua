local _, BUI = ...
local Pixel = BUI.Pixel

local BUILib = BluUI.BUILibClient
local Controls = BUILib.Controls
local Modals = BUILib.Modals
local Widget = BUILib.Widget
local Theme = BUILib.Theme
local font

local SESSION_RESET_GAP = 120

local CARD_DEFINITIONS = {
    { id = "stat_ilvl",    label = "Item Level",      group = "tiles" },
    { id = "stat_mscore",  label = "M+ Score",        group = "tiles" },
    { id = "weeklyMplus",  label = "Weekly M+ Runs",  group = "tiles" },
    { id = "stat_session", label = "Session",         group = "tiles" },
    { id = "dungeons",     label = "Recent Dungeons",   group = "cards" },
    { id = "vault",        label = "Great Vault",       group = "cards" },
    { id = "raidprog",     label = "Raid Progress",     group = "cards" },
    { id = "crests",       label = "Crests",            group = "cards" },
    { id = "alts",         label = "Alt Overview",      group = "cards" },
}

local GetDashboardDB, IsCardVisible
local Session, ItemLevel, MythicPlusScore, Duration, TimeDelta, Score, KeyLevel
local SpecName, WeeklyResetSeconds
local OwnedKeystone, VaultBuckets, WeeklyMplusCount, MapTimeLimit, RunSeconds
local RaiderIORunSeconds, RaiderIORuns, BlizzardRuns, ResolveBlizzardUpgrades, KeyTierColor
local ClearRows, MakeCard, MakeCardHeader, MakeDungeonRow, MakeEmptyRow
local PlayCardSlideIn
local SeasonCurrencyList, VaultSlotLabel, RaidProgress, FormatAgo
local SnapshotCurrentChar, MakeVaultTypeRow, MakeRaidRow, MakeAltRow, MakeCrestRow

function GetDashboardDB()
    local db = BUI.GetDB()
    db.dashboard = db.dashboard or {}
    return db.dashboard
end

function IsCardVisible(cardID)
    local visibility = GetDashboardDB().cardVisibility
    if visibility and visibility[cardID] ~= nil then return visibility[cardID] end
    return true
end

local sessionStart

local function InitSession()
    local globalDB = BUI.db and BUI.db.global
    if not globalDB then return end
    globalDB.session = globalDB.session or {}
    local now = time()
    if not globalDB.session.start or (globalDB.session.lastSeen and (now - globalDB.session.lastSeen) > SESSION_RESET_GAP) then
        globalDB.session.start = now
    end
    sessionStart = globalDB.session.start
end

BUI.Events:Once("PLAYER_ENTERING_WORLD", "Dashboard.SessionInit", InitSession)

BUI.Events:Register("PLAYER_LOGOUT", "Dashboard.SessionSave", function()
    local globalDB = BUI.db and BUI.db.global
    if not globalDB then return end
    globalDB.session = globalDB.session or {}
    globalDB.session.lastSeen = time()
end)

function Session()
    if not sessionStart then return "0m" end
    local elapsed = time() - sessionStart
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    if hours > 0 then return ("%dh %02dm"):format(hours, minutes) end
    return ("%dm"):format(minutes)
end

function ItemLevel()
    local overall, equipped = GetAverageItemLevel()
    return ("%d / %d"):format(math.floor((equipped or 0) + 0.5), math.floor((overall or 0) + 0.5))
end

function MythicPlusScore()
    local score = C_ChallengeMode.GetOverallDungeonScore()
    if not score then return "0" end
    local roundedScore = math.floor(score)
    local color = C_ChallengeMode.GetDungeonScoreRarityColor(roundedScore)
    if color then
        return ("|cff%02x%02x%02x%d|r"):format(
            math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255), roundedScore)
    end
    return tostring(roundedScore)
end

function Duration(seconds)
    if not seconds or seconds <= 0 then return "" end
    return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

function TimeDelta(actualSeconds, limitSeconds)
    if not actualSeconds or actualSeconds <= 0 or not limitSeconds or limitSeconds <= 0 then return "" end
    local difference = math.floor(limitSeconds - actualSeconds + 0.5)
    local sign = difference >= 0 and "-" or "+"
    difference = math.abs(difference)
    return string.format("(%s%d:%02d)", sign, math.floor(difference / 60), difference % 60)
end

function Score(score)
    if not score or score <= 0 then return "" end
    return tostring(math.floor(score + 0.5))
end

function KeyLevel(level, upgrades)
    if not level or level <= 0 then return "" end
    local upgradeCount = math.max(0, upgrades or 0)
    if upgradeCount <= 0 then return tostring(level) end
    return string.rep("+", upgradeCount) .. tostring(level)
end

function SpecName()
    local specIndex = GetSpecialization()
    if not specIndex then return "" end
    local _, name = GetSpecializationInfo(specIndex)
    return name or ""
end

function WeeklyResetSeconds()
    return C_DateAndTime.GetSecondsUntilWeeklyReset()
end

function OwnedKeystone()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if not level or level == 0 or not mapID then return nil end
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    return level, name or ("map " .. mapID)
end

local function CountUnlocked(activities)
    local unlockedCount = 0
    for _, activity in ipairs(activities or {}) do
        if activity.progress and activity.threshold and activity.progress >= activity.threshold then unlockedCount = unlockedCount + 1 end
    end
    return unlockedCount
end

function VaultBuckets()
    local RewardThresholdType = Enum.WeeklyRewardChestThresholdType
    return
        { CountUnlocked(C_WeeklyRewards.GetActivities(RewardThresholdType.Raid)),       3 },
        { CountUnlocked(C_WeeklyRewards.GetActivities(RewardThresholdType.Activities)), 3 },
        { CountUnlocked(C_WeeklyRewards.GetActivities(RewardThresholdType.World)),      3 }
end

function WeeklyMplusCount()
    local RewardThresholdType = Enum.WeeklyRewardChestThresholdType
    local activities = C_WeeklyRewards.GetActivities(RewardThresholdType.Activities) or {}
    local count = 0
    for _, activity in ipairs(activities) do
        if activity.progress and activity.progress > count then count = activity.progress end
    end
    return count
end

local PVP_CURRENCY_IDS = {}
do
    local currencyConstants = Constants and Constants.CurrencyConsts
    if currencyConstants then
        for _, constantName in ipairs({ "CONQUEST_CURRENCY_ID", "HONOR_CURRENCY_ID", "CLASSIC_HONOR_CURRENCY_ID", "ACCOUNT_WIDE_HONOR_CURRENCY_ID" }) do
            local currencyID = currencyConstants[constantName]
            if type(currencyID) == "number" then PVP_CURRENCY_IDS[currencyID] = true end
        end
    end
    PVP_CURRENCY_IDS[1602] = true
    PVP_CURRENCY_IDS[1792] = true
end

local function IsPvPCurrencyHeader(headerName)
    if type(headerName) ~= "string" then return false end
    return headerName == PLAYER_V_PLAYER or headerName == PVP or headerName == PVP_LABEL_PVP
end

local function IsUpgradeCrestName(currencyName)
    return type(currencyName) == "string" and currencyName:lower():find("crest", 1, true) ~= nil
end

local CREST_TIER_ORDER = { "veteran", "champion", "hero", "myth" }
local function CrestTier(currencyName)
    local loweredName = type(currencyName) == "string" and currencyName:lower() or ""
    for tierIndex, tierName in ipairs(CREST_TIER_ORDER) do
        if loweredName:find(tierName, 1, true) then return tierIndex end
    end
    return #CREST_TIER_ORDER + 1
end

local CREST_ROW_PITCH   = 20
local CREST_ROW_LIMIT   = 12
local CREST_ROWS_HEIGHT = 168

local TRACKED_CURRENCY_PATTERNS = { "manaflux" }
local HIDDEN_CURRENCY_PATTERNS  = { "adventurer", "voidlight marl" }

local function MatchesCurrencyPattern(currencyName, namePatterns)
    if type(currencyName) ~= "string" then return false end
    local loweredName = currencyName:lower()
    for _, namePattern in ipairs(namePatterns) do
        if loweredName:find(namePattern, 1, true) then return true end
    end
    return false
end

local seasonCurrencyIDs
local lastCurrencyScan = 0

local function DiscoverSeasonCurrencies()
    if GetTime() - lastCurrencyScan < 30 then return seasonCurrencyIDs end
    lastCurrencyScan = GetTime()
    local expanded = {}
    local expandIndex = 1
    while expandIndex <= C_CurrencyInfo.GetCurrencyListSize() do
        local listInfo = C_CurrencyInfo.GetCurrencyListInfo(expandIndex)
        if listInfo and listInfo.isHeader and not listInfo.isHeaderExpanded then
            C_CurrencyInfo.ExpandCurrencyList(expandIndex, true)
            expanded[listInfo.name or ""] = true
        end
        expandIndex = expandIndex + 1
    end

    local seasonCapped, extras, seen = {}, {}, {}
    local headerCount, inPvPCategory = 0, false
    for entryIndex = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local listInfo = C_CurrencyInfo.GetCurrencyListInfo(entryIndex)
        if listInfo then
            if listInfo.isHeader then
                headerCount = headerCount + 1
                inPvPCategory = IsPvPCurrencyHeader(listInfo.name)
            elseif not inPvPCategory then
                local link = C_CurrencyInfo.GetCurrencyListLink(entryIndex)
                local currencyID = link and tonumber(link:match("currency:(%d+)"))
                if currencyID and not seen[currencyID] and not PVP_CURRENCY_IDS[currencyID] then
                    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
                    if currencyInfo and not MatchesCurrencyPattern(currencyInfo.name, HIDDEN_CURRENCY_PATTERNS) then
                        local isSeasonCapped = currencyInfo.useTotalEarnedForMaxQty and (currencyInfo.maxQuantity or 0) > 0
                        if headerCount == 1 or MatchesCurrencyPattern(currencyInfo.name, TRACKED_CURRENCY_PATTERNS) then
                            seen[currencyID] = true
                            extras[#extras + 1] = currencyID
                        elseif isSeasonCapped then
                            seen[currencyID] = true
                            seasonCapped[#seasonCapped + 1] = {
                                id             = currencyID,
                                quality        = currencyInfo.quality or 0,
                                tier           = CrestTier(currencyInfo.name),
                                name           = currencyInfo.name or "",
                                isUpgradeCrest = IsUpgradeCrestName(currencyInfo.name),
                            }
                        end
                    end
                end
            end
        end
    end

    local crests = {}
    for _, candidate in ipairs(seasonCapped) do
        if candidate.isUpgradeCrest then crests[#crests + 1] = candidate end
    end
    if #crests == 0 then crests = seasonCapped end

    table.sort(crests, function(leftCrest, rightCrest)
        if leftCrest.tier ~= rightCrest.tier then return leftCrest.tier < rightCrest.tier end
        if leftCrest.quality ~= rightCrest.quality then return leftCrest.quality < rightCrest.quality end
        return leftCrest.name < rightCrest.name
    end)
    local currencyIDs = {}
    for _, crest in ipairs(crests) do currencyIDs[#currencyIDs + 1] = crest.id end
    for _, currencyID in ipairs(extras) do currencyIDs[#currencyIDs + 1] = currencyID end

    local collapseIndex = 1
    while collapseIndex <= C_CurrencyInfo.GetCurrencyListSize() do
        local listInfo = C_CurrencyInfo.GetCurrencyListInfo(collapseIndex)
        if listInfo and listInfo.isHeader and listInfo.isHeaderExpanded and expanded[listInfo.name or ""] then
            C_CurrencyInfo.ExpandCurrencyList(collapseIndex, false)
        end
        collapseIndex = collapseIndex + 1
    end

    if #currencyIDs > 0 then seasonCurrencyIDs = currencyIDs end
    return seasonCurrencyIDs
end

function SeasonCurrencyList()
    local currencyIDs = seasonCurrencyIDs or DiscoverSeasonCurrencies()
    if not currencyIDs then return nil end
    local currencies = {}
    for _, currencyID in ipairs(currencyIDs) do
        local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if currencyInfo and currencyInfo.name then
            currencies[#currencies + 1] = {
                name        = currencyInfo.name,
                icon        = currencyInfo.iconFileID,
                quantity    = currencyInfo.quantity or 0,
                totalEarned = currencyInfo.totalEarned or 0,
                max         = BUI.Currency.Cap(currencyID, currencyInfo),
                seasonCap   = currencyInfo.useTotalEarnedForMaxQty and (currencyInfo.maxQuantity or 0) > 0,
                quality     = currencyInfo.quality,
            }
        end
    end
    if #currencies == 0 then return nil end
    return currencies
end

local RAID_DIFFICULTY_SHORT = { [17] = "LFR", [14] = "Normal", [15] = "Heroic", [16] = "Mythic" }

function VaultSlotLabel(activity)
    local RewardThresholdType = Enum.WeeklyRewardChestThresholdType
    if activity.type == RewardThresholdType.Raid then
        local name = RAID_DIFFICULTY_SHORT[activity.level]
        if not name then name = GetDifficultyInfo(activity.level) end
        return name or ("D" .. tostring(activity.level))
    elseif activity.type == RewardThresholdType.Activities then
        return "+" .. activity.level
    end
    return "Tier " .. activity.level
end

local function VaultRewardItemLevel(activity)
    if not activity.id then return nil end
    local firstLink, secondLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(activity.id)
    local link = firstLink or secondLink
    if not link then return nil end
    local itemLevel = C_Item.GetDetailedItemLevelInfo(link)
    if itemLevel and itemLevel > 0 then return itemLevel end
    return nil
end

local function SortedVaultActivities(thresholdType)
    local activities = C_WeeklyRewards.GetActivities(thresholdType) or {}
    table.sort(activities, function(leftActivity, rightActivity) return (leftActivity.index or 0) < (rightActivity.index or 0) end)
    return activities
end

local function SameRaidName(firstName, secondName)
    if not firstName or not secondName then return false end
    firstName = firstName:lower():gsub("^the%s+", "")
    secondName = secondName:lower():gsub("^the%s+", "")
    return firstName == secondName or firstName:find(secondName, 1, true) ~= nil or secondName:find(firstName, 1, true) ~= nil
end

local ejBossCache = {}
local function EJBossNames(raidName, instanceMapIDs)
    local cacheKey = raidName or (instanceMapIDs and instanceMapIDs[1])
    if cacheKey == nil then return nil end
    if ejBossCache[cacheKey] then return ejBossCache[cacheKey] end
    pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
    local wantedMapIDs = {}
    for _, mapID in ipairs(instanceMapIDs or {}) do wantedMapIDs[mapID] = true end
    local ok, names = pcall(function()
        for tier = EJ_GetNumTiers(), 1, -1 do
            EJ_SelectTier(tier)
            local instanceIndex = 1
            while true do
                local journalInstanceID, instanceName, _, _, _, _, _, _, _, _, instanceMapID = EJ_GetInstanceByIndex(instanceIndex, true)
                if not journalInstanceID then break end
                if (instanceMapID and wantedMapIDs[instanceMapID]) or SameRaidName(instanceName, raidName) then
                    EJ_SelectInstance(journalInstanceID)
                    local bossNames, bossIndex = {}, 1
                    while true do
                        local bossName = EJ_GetEncounterInfoByIndex(bossIndex, journalInstanceID)
                        if not bossName then break end
                        bossNames[bossIndex] = bossName
                        bossIndex = bossIndex + 1
                    end
                    if #bossNames > 0 then return bossNames end
                end
                instanceIndex = instanceIndex + 1
            end
        end
    end)
    if ok and type(names) == "table" and #names > 0 then
        ejBossCache[cacheKey] = names
        return names
    end
    return nil
end

local function RaiderIORaidProgress()
    if type(RaiderIO) ~= "table" or type(RaiderIO.GetProfile) ~= "function" then return nil end
    local profile = RaiderIO.GetProfile("player")
    if type(profile) ~= "table" then profile = RaiderIO.GetProfile(UnitName("player"), GetRealmName()) end
    local raidProfile = type(profile) == "table" and profile.raidProfile
    if type(raidProfile) ~= "table" then return nil end
    local progressList = raidProfile.progress or raidProfile.sortedProgress or raidProfile.raidProgress
    if type(progressList) ~= "table" or #progressList == 0 then return nil end

    local raidsByName, orderedRaids = {}, {}
    for _, entry in ipairs(progressList) do
        local raid  = entry.raid or entry.currentRaid
        local raidName = (type(raid) == "table" and (raid.name or raid.shortName)) or entry.raidName
        local difficulty  = tonumber(entry.difficulty or entry.diff)
        local kills = entry.killsPerBoss or entry.kills
        if raidName and difficulty and difficulty >= 1 and difficulty <= 3 and type(kills) == "table" then
            local raidEntry = raidsByName[raidName]
            if not raidEntry then
                raidEntry = { name = raidName, bossCount = 0, diffs = {}, source = "rio" }
                raidsByName[raidName] = raidEntry
                orderedRaids[#orderedRaids + 1] = raidEntry
            end
            local bossCount = (type(raid) == "table" and raid.bossCount) or #kills
            if bossCount > raidEntry.bossCount then raidEntry.bossCount = bossCount end
            if not raidEntry.instanceMapIDs and type(raid) == "table" then
                raidEntry.instanceMapIDs = raid.instance_map_ids
                    or (raid.instance_map_id and { raid.instance_map_id })
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
    topRaid.bosses = EJBossNames(topRaid.name, topRaid.instanceMapIDs)
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
                raidEntry = { name = name, bossCount = 0, bosses = {}, diffs = {}, source = "lockout" }
                raidsByName[name] = raidEntry
                orderedRaids[#orderedRaids + 1] = raidEntry
            end
            if (encounterCount or 0) > raidEntry.bossCount then raidEntry.bossCount = encounterCount end
            local kills = {}
            for encounterIndex = 1, encounterCount or 0 do
                local bossName, _, isKilled = GetSavedInstanceEncounterInfo(instanceIndex, encounterIndex)
                kills[encounterIndex] = isKilled and 1 or 0
                if bossName and not raidEntry.bosses[encounterIndex] then raidEntry.bosses[encounterIndex] = bossName end
            end
            raidEntry.diffs[difficultyKey] = { killed = encounterProgress or 0, kills = kills }
        end
    end
    if #orderedRaids == 0 then return nil end
    table.sort(orderedRaids, function(leftRaid, rightRaid)
        local leftKills, rightKills = 0, 0
        for _, difficultyInfo in pairs(leftRaid.diffs) do leftKills = leftKills + difficultyInfo.killed end
        for _, difficultyInfo in pairs(rightRaid.diffs) do rightKills = rightKills + difficultyInfo.killed end
        return leftKills > rightKills
    end)
    return orderedRaids[1]
end

function RaidProgress()
    local raiderIOProgress = RaiderIORaidProgress()
    if not raiderIOProgress then return LockoutRaidProgress() end
    local lockoutProgress = LockoutRaidProgress()
    if not (lockoutProgress and SameRaidName(lockoutProgress.name, raiderIOProgress.name)) then return raiderIOProgress end

    if not raiderIOProgress.bosses and lockoutProgress.bosses and lockoutProgress.bosses[1] then
        raiderIOProgress.bosses = lockoutProgress.bosses
    end
    if lockoutProgress.bossCount > raiderIOProgress.bossCount then
        raiderIOProgress.bossCount = lockoutProgress.bossCount
    end

    local bossIndexByName = {}
    for bossIndex, bossName in ipairs(raiderIOProgress.bosses or {}) do bossIndexByName[bossName] = bossIndex end

    for difficultyKey, lockoutInfo in pairs(lockoutProgress.diffs) do
        local rioInfo = raiderIOProgress.diffs[difficultyKey]
        if not rioInfo then
            rioInfo = { killed = 0, kills = {} }
            raiderIOProgress.diffs[difficultyKey] = rioInfo
        end
        local mergedKills = {}
        for bossIndex = 1, raiderIOProgress.bossCount do mergedKills[bossIndex] = tonumber(rioInfo.kills[bossIndex]) or 0 end
        for lockoutIndex, lockoutKill in ipairs(lockoutInfo.kills) do
            if lockoutKill > 0 then
                local bossName = lockoutProgress.bosses[lockoutIndex]
                local mergedIndex = (bossName and bossIndexByName[bossName]) or lockoutIndex
                if (mergedKills[mergedIndex] or 0) < 1 then mergedKills[mergedIndex] = 1 end
            end
        end
        rioInfo.kills = mergedKills
        local killedCount = 0
        for bossIndex = 1, raiderIOProgress.bossCount do
            if mergedKills[bossIndex] > 0 then killedCount = killedCount + 1 end
        end
        rioInfo.killed = killedCount
    end
    return raiderIOProgress
end

function FormatAgo(seconds)
    seconds = math.max(0, seconds or 0)
    if seconds < 90 then return "now" end
    if seconds < 3600 then return ("%dm ago"):format(math.floor(seconds / 60)) end
    if seconds < 86400 then return ("%dh ago"):format(math.floor(seconds / 3600)) end
    return ("%dd ago"):format(math.floor(seconds / 86400))
end

local function AltCharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

function SnapshotCurrentChar()
    local globalDB = BUI.db and BUI.db.global
    if not globalDB then return end
    globalDB.altOverview = globalDB.altOverview or {}
    local _, equipped = GetAverageItemLevel()
    local keyLevel, keyMap = OwnedKeystone()
    local raidBucket, dungeonBucket, worldBucket = VaultBuckets()
    local _, classFile = UnitClass("player")
    globalDB.altOverview[AltCharKey()] = {
        name     = UnitName("player"),
        realm    = GetRealmName(),
        class    = classFile,
        ilvl     = math.floor((equipped or 0) + 0.5),
        score    = math.floor((C_ChallengeMode.GetOverallDungeonScore() or 0) + 0.5),
        keyLevel = keyLevel,
        keyMap   = keyMap,
        vault    = { raidBucket[1], dungeonBucket[1], worldBucket[1] },
        lastSeen = time(),
    }
end

BUI.Events:Register("PLAYER_LOGOUT", "Dashboard.AltSnapshot", SnapshotCurrentChar)

local function WeeklyResetTime()
    local secondsUntilReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
    if not secondsUntilReset then return nil end
    return math.floor((time() + secondsUntilReset) / 3600 + 0.5) * 3600
end

local function WeeklyMplusHistory()
    local globalDB = BUI.db and BUI.db.global
    if not globalDB then return nil end
    globalDB.weeklyMplusHistory = globalDB.weeklyMplusHistory or {}
    local charHistory = globalDB.weeklyMplusHistory[AltCharKey()]
    if not charHistory then
        charHistory = {}
        globalDB.weeklyMplusHistory[AltCharKey()] = charHistory
    end
    return charHistory
end

local function RecordWeeklyMplus(count)
    local resetTime = WeeklyResetTime()
    local charHistory = WeeklyMplusHistory()
    if not (resetTime and charHistory) then return end
    if count > (charHistory[resetTime] or -1) then charHistory[resetTime] = count end
    local resetTimes = {}
    for storedTime in pairs(charHistory) do resetTimes[#resetTimes + 1] = storedTime end
    if #resetTimes > 8 then
        table.sort(resetTimes, function(leftTime, rightTime) return leftTime > rightTime end)
        for index = 9, #resetTimes do charHistory[resetTimes[index]] = nil end
    end
end

local function WeeklyMplusHistoryEntries()
    local charHistory = WeeklyMplusHistory()
    if not charHistory then return {} end
    local resetTimes = {}
    for storedTime in pairs(charHistory) do resetTimes[#resetTimes + 1] = storedTime end
    table.sort(resetTimes, function(leftTime, rightTime) return leftTime > rightTime end)
    local currentReset = WeeklyResetTime()
    local entries = {}
    for index, resetTime in ipairs(resetTimes) do
        local label = (resetTime == currentReset) and "This week" or date("Week of %b %d", resetTime - 7 * 86400)
        entries[index] = { label = label, count = charHistory[resetTime] }
    end
    return entries
end

local mapTimeLimits = {}
function MapTimeLimit(mapID)
    if not mapID then return nil end
    if mapTimeLimits[mapID] then return mapTimeLimits[mapID] end
    local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
    mapTimeLimits[mapID] = timeLimit
    return timeLimit
end

function RunSeconds(run)
    return run.durationSec or (run.durationMS and run.durationMS / 1000) or 0
end

function ResolveBlizzardUpgrades(run)
    local upgrades = tonumber(run.keystoneUpgradeLevels)
            or tonumber(run.numKeystoneUpgrades)
            or tonumber(run.upgrades)
            or tonumber(run.chests)
    if upgrades then return upgrades end
    local duration = RunSeconds(run)
    local timeLimit = MapTimeLimit(run.mapChallengeModeID)
    if run.completed and timeLimit and duration > 0 and duration <= timeLimit then
        if duration <= timeLimit * 0.6 then return 3
        elseif duration <= timeLimit * 0.8 then return 2
        else return 1 end
    end
    return 0
end

function RaiderIORunSeconds(run)
    if type(run.clearTimeMS) == "number" and run.clearTimeMS > 0 then return run.clearTimeMS / 1000 end
    if type(run.durationSec) == "number" and run.durationSec > 0 then return run.durationSec end
    local fractionalTime = tonumber(run.fractionalTime)
    if fractionalTime and fractionalTime > 60 then return fractionalTime end
    return 0
end

local function GetRaiderIOProfile()
    if type(RaiderIO) ~= "table" or type(RaiderIO.GetProfile) ~= "function" then return nil end
    local profile = RaiderIO.GetProfile("player")
    if type(profile) ~= "table" then
        profile = RaiderIO.GetProfile(UnitName("player"), GetRealmName())
    end
    if type(profile) ~= "table" then return nil end
    return profile
end

function RaiderIORuns()
    local profile = GetRaiderIOProfile()
    if not profile then return nil end
    local keystoneProfile = profile.mythicKeystoneProfile or profile.keystoneProfile
    if type(keystoneProfile) ~= "table" then return nil end

    local function PickMapID(dungeon)
        if type(dungeon) ~= "table" then return nil end
        return dungeon.keystone_instance or dungeon.instance_map_id or dungeon.mapChallengeModeID or dungeon.challengeMapID
    end

    local runs = {}
    local sortedDungeons = keystoneProfile.sortedDungeons
    if type(sortedDungeons) == "table" and #sortedDungeons > 0 then
        for _, entry in ipairs(sortedDungeons) do
            local dungeon = entry.dungeon or entry
            runs[#runs + 1] = {
                mapName        = (dungeon and (dungeon.name or dungeon.shortNameLocale or dungeon.shortName)) or entry.name or "Unknown",
                mapID          = PickMapID(dungeon) or entry.mapChallengeModeID,
                level          = entry.level or entry.bestLevel or 0,
                upgrades       = entry.upgrades or entry.chests or 0,
                fractionalTime = entry.fractionalTime,
                clearTimeMS    = entry.clearTimeMS or entry.bestTimeMS or entry.durationMS,
                score          = entry.score,
            }
        end
    elseif type(keystoneProfile.dungeons) == "table" then
        for dungeonIndex, entry in ipairs(keystoneProfile.dungeons) do
            local mapName, dungeon
            if type(RaiderIO.GetDungeonByID) == "function" then
                dungeon = RaiderIO.GetDungeonByID(dungeonIndex)
                if dungeon then mapName = dungeon.name or dungeon.shortNameLocale or dungeon.shortName end
            end
            runs[#runs + 1] = {
                mapName        = mapName or ("Dungeon " .. dungeonIndex),
                mapID          = PickMapID(dungeon) or entry.mapChallengeModeID,
                level          = entry.level or 0,
                upgrades       = entry.chests or entry.upgrades or 0,
                fractionalTime = entry.fractionalTime,
                clearTimeMS    = entry.clearTimeMS or entry.bestTimeMS or entry.durationMS,
                score          = (keystoneProfile.dungeonScores and keystoneProfile.dungeonScores[dungeonIndex]) or entry.score,
            }
        end
    end

    if #runs == 0 then return nil end
    table.sort(runs, function(leftRun, rightRun)
        local leftScore, rightScore = leftRun.score or 0, rightRun.score or 0
        if leftScore ~= rightScore then return leftScore > rightScore end
        return (leftRun.level or 0) > (rightRun.level or 0)
    end)
    return runs, keystoneProfile
end

function BlizzardRuns()
    local rawRuns = C_MythicPlus.GetRunHistory(true, true) or {}
    table.sort(rawRuns, function(leftRun, rightRun) return (leftRun.startTime or 0) > (rightRun.startTime or 0) end)
    local runs = {}
    for _, run in ipairs(rawRuns) do
        runs[#runs + 1] = {
            mapName     = C_ChallengeMode.GetMapUIInfo(run.mapChallengeModeID) or "Unknown",
            mapID       = run.mapChallengeModeID,
            level       = run.level or 0,
            completed   = run.completed,
            upgrades    = ResolveBlizzardUpgrades(run),
            durationSec = RunSeconds(run),
            startTime   = run.startTime,
            score       = run.runScore or run.score,
        }
    end
    return runs
end

function KeyTierColor(level, score)
    if type(RaiderIO) == "table" and type(RaiderIO.GetScoreColor) == "function" and score and score > 0 then
        local red, green, blue = RaiderIO.GetScoreColor(score)
        if red and green and blue then return red, green, blue end
    end
    if level >= 14 then return 1.00, 0.45, 0.85 end
    if level >= 12 then return 1.00, 0.60, 0.20 end
    if level >= 10 then return 0.75, 0.50, 1.00 end
    if level >=  8 then return 0.40, 0.70, 1.00 end
    if level >=  5 then return 0.40, 0.95, 0.40 end
    return 0.65, 0.65, 0.70
end

function MakeCard(parent, collector)
    local card = CreateFrame("Frame", nil, parent)
    Widget.DrawCardShape(card, 8, Theme.bg.card, { 0.20, 0.22, 0.26, 0.50 }, "BACKGROUND", 0, 0)
    collector[#collector + 1] = card
    return card
end

function MakeCardHeader(card, title, accentRed, accentGreen, accentBlue)
    local accent = card:CreateTexture(nil, "OVERLAY")
    accent:SetTexture(Widget.WHITE); accent:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
    accent:SetSize(Pixel.Scale(2), Pixel.Scale(14)); accent:SetPoint("TOPLEFT", Pixel.Scale(14), Pixel.Scale(-14))

    Theme.RegisterAccentElement(accent, function(element, red, green, blue) element:SetVertexColor(red, green, blue, 1) end)
    local fontString = card:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(fontString, 13, font, "OUTLINE")
    fontString:SetPoint("LEFT", accent, "RIGHT", Pixel.Scale(8), 0)
    fontString:SetText(title)
    fontString:SetTextColor(1, 1, 1, 1)
    return fontString
end

local activeSlideIn

local function FinalizeSlideIn(state)
    state.ticker:SetScript("OnUpdate", nil)
    state.ticker:Hide()
    for cardIndex, card in ipairs(state.cards) do
        local snapshot = state.snapshots[cardIndex]
        card:ClearAllPoints()
        card:SetPoint(snapshot.p, snapshot.rel, snapshot.rp, snapshot.x, snapshot.y)
        card:SetAlpha(1)
    end
end

function PlayCardSlideIn(cards, parent)
    if not cards or #cards == 0 then return end

    if activeSlideIn then
        FinalizeSlideIn(activeSlideIn)
        activeSlideIn = nil
    end

    local STAGGER  = 0.045
    local DURATION = 0.38
    local OFFSET_Y = -18

    local visibleCards, snapshots = {}, {}
    for _, card in ipairs(cards) do
        if card:IsShown() then
            local point, relativeTo, relativePoint, x, y = card:GetPoint(1)
            if point then
                local index = #visibleCards + 1
                visibleCards[index]   = card
                snapshots[index] = { p = point, rel = relativeTo, rp = relativePoint, x = x or 0, y = y or 0 }
                card:ClearAllPoints()
                card:SetPoint(point, relativeTo, relativePoint, x or 0, (y or 0) + OFFSET_Y)
                card:SetAlpha(0)
            end
        end
    end
    if #visibleCards == 0 then return end

    local start  = GetTime()
    local floor  = math.floor
    parent._slideTicker = parent._slideTicker or CreateFrame("Frame", nil, parent)
    local ticker = parent._slideTicker
    ticker:Show()
    local state  = { ticker = ticker, cards = visibleCards, snapshots = snapshots }
    activeSlideIn = state

    ticker:SetScript("OnUpdate", function(self)
        local now = GetTime()
        local allDone = true
        for cardIndex, card in ipairs(visibleCards) do
            local snapshot = snapshots[cardIndex]
            local progress = (now - start - (cardIndex - 1) * STAGGER) / DURATION
            if progress < 0 then
                allDone = false
            elseif progress < 1 then
                allDone = false
                local eased = 1 - (1 - progress) ^ 3
                local offsetY = floor(snapshot.y + OFFSET_Y * (1 - eased) + 0.5)
                card:ClearAllPoints()
                card:SetPoint(snapshot.p, snapshot.rel, snapshot.rp, snapshot.x, offsetY)
                card:SetAlpha(eased)
            else
                card:ClearAllPoints()
                card:SetPoint(snapshot.p, snapshot.rel, snapshot.rp, snapshot.x, snapshot.y)
                card:SetAlpha(1)
            end
        end
        if allDone then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            if activeSlideIn == state then activeSlideIn = nil end
        end
    end)
end

function ClearRows(card)
    if card._rows then
        card._rowPool = card._rowPool or {}
        for _, row in ipairs(card._rows) do
            row:Hide()
            if row._rowKind then
                card._rowPool[row._rowKind] = card._rowPool[row._rowKind] or {}
                table.insert(card._rowPool[row._rowKind], row)
            else
                row:SetParent(nil)
            end
        end
    end
    card._rows = {}
end

local function AcquireRow(card, kind)
    local pool = card._rowPool and card._rowPool[kind]
    if pool and #pool > 0 then
        return table.remove(pool)
    end
end

function MakeEmptyRow(card, message)
    local empty = AcquireRow(card, "empty")
    if not empty then
        empty = CreateFrame("Frame", nil, card)
        empty._rowKind = "empty"
        empty._fs = empty:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(empty._fs, 11, font, "")
    end
    empty:SetHeight(Pixel.Scale(18))
    empty:ClearAllPoints()
    empty:SetPoint("TOPLEFT",  card, "TOPLEFT",  Pixel.Scale(14), Pixel.Scale(-42))
    empty:SetPoint("TOPRIGHT", card, "TOPRIGHT", Pixel.Scale(-14), Pixel.Scale(-42))
    local fontString = empty._fs
    fontString:ClearAllPoints(); fontString:SetPoint("LEFT", 0, 0)
    fontString:SetTextColor(0.5, 0.5, 0.55, 1); fontString:SetText(message)
    empty:Show()
    return empty
end

local TIME_WIDTH, SCORE_WIDTH, LEVEL_WIDTH, COLUMN_GAP = 92, 38, 44, 8

function MakeDungeonRow(card, rowIndex, yBase, width)
    local row = AcquireRow(card, "dungeon")
    if not row then
        row = CreateFrame("Frame", nil, card)
        row._rowKind = "dungeon"

        local timeFontString = row:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(timeFontString, 11, font, "")
        timeFontString:SetPoint("TOPRIGHT", 0, 0); timeFontString:SetPoint("BOTTOMRIGHT", 0, 0)
        timeFontString:SetWidth(Pixel.Scale(TIME_WIDTH)); timeFontString:SetJustifyH("RIGHT")

        local levelFontString = row:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(levelFontString, 11, font, "")
        levelFontString:SetPoint("TOPRIGHT", timeFontString, "TOPLEFT", Pixel.Scale(-COLUMN_GAP), 0)
        levelFontString:SetPoint("BOTTOMRIGHT", timeFontString, "BOTTOMLEFT", Pixel.Scale(-COLUMN_GAP), 0)
        levelFontString:SetWidth(Pixel.Scale(LEVEL_WIDTH)); levelFontString:SetJustifyH("RIGHT")

        local scoreFontString = row:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(scoreFontString, 11, font, "")
        scoreFontString:SetPoint("TOPRIGHT", levelFontString, "TOPLEFT", Pixel.Scale(-COLUMN_GAP), 0)
        scoreFontString:SetPoint("BOTTOMRIGHT", levelFontString, "BOTTOMLEFT", Pixel.Scale(-COLUMN_GAP), 0)
        scoreFontString:SetWidth(Pixel.Scale(SCORE_WIDTH)); scoreFontString:SetJustifyH("RIGHT")

        local leftFontString = row:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(leftFontString, 11, font, "")
        leftFontString:SetPoint("LEFT", 0, 0); leftFontString:SetPoint("RIGHT", scoreFontString, "LEFT", Pixel.Scale(-COLUMN_GAP), 0)
        leftFontString:SetJustifyH("LEFT"); leftFontString:SetWordWrap(false)

        row._time, row._lvl, row._score, row._left = timeFontString, levelFontString, scoreFontString, leftFontString
    end
    row:SetSize(Pixel.Scale(width - 32), Pixel.Scale(18))
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", Pixel.Scale(16), Pixel.Scale(-yBase - (rowIndex - 1) * 18))
    row:Show()
    return row
end

local VAULT_LABEL_WIDTH, VAULT_CHIP_GAP = 64, 8
local VAULT_CHIP_HEIGHT   = 44
local VAULT_ILVL_HEIGHT   = 18
local VAULT_SUB_HEIGHT    = 11
local VAULT_STACK_GAP     = 1
local VAULT_CHIP_PADDING  = math.floor((VAULT_CHIP_HEIGHT - VAULT_ILVL_HEIGHT - VAULT_STACK_GAP - VAULT_SUB_HEIGHT) / 2)

function MakeVaultTypeRow(card, rowIndex, label, activities, width, accentRed, accentGreen, accentBlue)
    local row = AcquireRow(card, "vaultslots")
    if not row then
        row = CreateFrame("Frame", nil, card)
        row._rowKind = "vaultslots"
        row._name = row:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(row._name, 11, font, "")
        row._name:SetPoint("LEFT", 0, 0)
        row._name:SetJustifyH("LEFT")
        row._chips = {}
    end
    local innerWidth = width - 28
    local chipWidth = math.floor((innerWidth - VAULT_LABEL_WIDTH - VAULT_CHIP_GAP * 2) / 3)
    row:SetHeight(Pixel.Scale(VAULT_CHIP_HEIGHT))
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT",  card, "TOPLEFT",  Pixel.Scale(14), Pixel.Scale(-38 - (rowIndex - 1) * 50))
    row:SetPoint("TOPRIGHT", card, "TOPRIGHT", Pixel.Scale(-14), Pixel.Scale(-38 - (rowIndex - 1) * 50))

    row._name:SetText(label)
    row._name:SetTextColor(0.85, 0.85, 0.88, 1)

    for slot = 1, 3 do
        local chip = row._chips[slot]
        if not chip then
            chip = CreateFrame("Frame", nil, row)
            Widget.DrawRoundedRect(chip, 5, { 0.05, 0.06, 0.08, 0.90 }, "BACKGROUND", 0, 0)
            chip._ilvl = chip:CreateFontString(nil, "OVERLAY")
            Pixel.ApplyFont(chip._ilvl, 16, font, "")
            chip._ilvl:SetHeight(Pixel.Scale(VAULT_ILVL_HEIGHT))
            chip._ilvl:SetJustifyV("MIDDLE")
            chip._ilvl:SetPoint("TOP", chip, "TOP", 0, Pixel.Scale(-VAULT_CHIP_PADDING))
            chip._sub = chip:CreateFontString(nil, "OVERLAY")
            Pixel.ApplyFont(chip._sub, 9, font, "")
            chip._sub:SetHeight(Pixel.Scale(VAULT_SUB_HEIGHT))
            chip._sub:SetJustifyV("MIDDLE")
            chip._sub:SetPoint("TOP", chip, "TOP", 0, Pixel.Scale(-VAULT_CHIP_PADDING - VAULT_ILVL_HEIGHT - VAULT_STACK_GAP))
            row._chips[slot] = chip
        end
        chip:SetSize(Pixel.Scale(chipWidth), Pixel.Scale(VAULT_CHIP_HEIGHT))
        chip:ClearAllPoints()
        chip:SetPoint("TOPRIGHT", row, "TOPRIGHT",
            -Pixel.Scale((3 - slot) * (chipWidth + VAULT_CHIP_GAP)), 0)

        local activity = activities[slot]
        if activity then
            local threshold = activity.threshold or 0
            local progress  = math.min(activity.progress or 0, threshold)
            local unlocked  = threshold > 0 and progress >= threshold
            if unlocked then
                local itemLevel = VaultRewardItemLevel(activity)
                chip._ilvl:SetText(itemLevel and tostring(itemLevel) or "...")
                chip._ilvl:SetTextColor(0.97, 0.97, 0.97, 1)
                chip._sub:SetText(("%s · %d/%d"):format(VaultSlotLabel(activity), progress, threshold))
                chip._sub:SetTextColor(accentRed, accentGreen, accentBlue, 1)
            else
                chip._ilvl:SetText("—")
                chip._ilvl:SetTextColor(0.45, 0.45, 0.5, 1)
                chip._sub:SetText(("%d/%d"):format(progress, threshold))
                chip._sub:SetTextColor(0.5, 0.5, 0.55, 1)
            end
            chip:Show()
        else
            chip:Hide()
        end
    end
    row:Show()
    return row
end

local RAID_DIFFICULTY_COLORS = {
    [1] = { 0.35, 0.85, 0.35 },
    [2] = { 0.25, 0.60, 1.00 },
    [3] = { 0.70, 0.40, 0.95 },
}
local RAID_COLUMN_WIDTH = 36

function MakeRaidRow(card, rowIndex, yBase)
    local row = AcquireRow(card, "raid")
    if not row then
        row = CreateFrame("Frame", nil, card)
        row._rowKind = "raid"
        row._cols = {}
        local previousColumn
        for difficultyIndex = 3, 1, -1 do
            local fontString = row:CreateFontString(nil, "OVERLAY")
            Pixel.ApplyFont(fontString, 10, font, "")
            fontString:SetWidth(Pixel.Scale(RAID_COLUMN_WIDTH))
            fontString:SetJustifyH("RIGHT")
            if previousColumn then fontString:SetPoint("RIGHT", previousColumn, "LEFT", 0, 0)
            else fontString:SetPoint("RIGHT", 0, 0) end
            row._cols[difficultyIndex] = fontString
            previousColumn = fontString
        end
        row._left = row:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(row._left, 11, font, "")
        row._left:SetPoint("LEFT", 0, 0)
        row._left:SetPoint("RIGHT", row._cols[1], "LEFT", Pixel.Scale(-8), 0)
        row._left:SetJustifyH("LEFT")
        row._left:SetWordWrap(false)
    end
    row:SetHeight(Pixel.Scale(17))
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT",  card, "TOPLEFT",  Pixel.Scale(14), Pixel.Scale(-yBase - (rowIndex - 1) * 18))
    row:SetPoint("TOPRIGHT", card, "TOPRIGHT", Pixel.Scale(-14), Pixel.Scale(-yBase - (rowIndex - 1) * 18))
    row:Show()
    return row
end

function MakeCrestRow(card, rowIndex, name, value, icon, qualityRed, qualityGreen, qualityBlue, rowPitch)
    local row = AcquireRow(card, "crest")
    if not row then
        row = CreateFrame("Frame", nil, card)
        row._rowKind = "crest"
        row._icon = row:CreateTexture(nil, "OVERLAY")
        row._icon:SetSize(Pixel.Scale(14), Pixel.Scale(14))
        row._icon:SetPoint("LEFT", 0, 0)
        row._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row._right = row:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(row._right, 11, font, "")
        row._right:SetPoint("RIGHT", 0, 0)
        row._left = row:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(row._left, 11, font, "")
        row._left:SetPoint("LEFT", Pixel.Scale(22), 0)
        row._left:SetJustifyH("LEFT")
        row._left:SetWordWrap(false)
    end
    local pitch = rowPitch or CREST_ROW_PITCH
    local rowTop = -34 - (rowIndex - 1) * pitch
    row:SetHeight(Pixel.Scale(math.min(18, pitch - 1)))
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT",  card, "TOPLEFT",  Pixel.Scale(14), Pixel.Scale(rowTop))
    row:SetPoint("TOPRIGHT", card, "TOPRIGHT", Pixel.Scale(-14), Pixel.Scale(rowTop))
    row._left:SetPoint("RIGHT", row._right, "LEFT", Pixel.Scale(-8), 0)

    if icon then row._icon:SetTexture(icon); row._icon:Show()
    else row._icon:Hide() end
    row._left:SetText(name)
    row._left:SetTextColor(qualityRed or 0.92, qualityGreen or 0.92, qualityBlue or 0.92, 1)
    row._right:SetText(value)
    row._right:SetTextColor(0.6, 0.6, 0.65, 1)
    row:Show()
    return row
end

local ALT_COLUMNS = {
    { key = "_seen",  w = 64,  x = 0   },
    { key = "_vault", w = 104, x = 68  },
    { key = "_key",   w = 170, x = 176 },
    { key = "_score", w = 56,  x = 350 },
    { key = "_ilvl",  w = 56,  x = 410 },
}

function MakeAltRow(card, rowIndex, yBase)
    local row = AcquireRow(card, "alt")
    if not row then
        row = CreateFrame("Frame", nil, card)
        row._rowKind = "alt"
        for _, column in ipairs(ALT_COLUMNS) do
            local fontString = row:CreateFontString(nil, "OVERLAY")
            Pixel.ApplyFont(fontString, 10, font, "")
            fontString:SetWidth(Pixel.Scale(column.w))
            fontString:SetJustifyH("RIGHT")
            fontString:SetPoint("RIGHT", -Pixel.Scale(column.x), 0)
            fontString:SetWordWrap(false)
            row[column.key] = fontString
        end
        row._name = row:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(row._name, 11, font, "")
        row._name:SetPoint("LEFT", 0, 0)
        row._name:SetPoint("RIGHT", row._ilvl, "LEFT", Pixel.Scale(-10), 0)
        row._name:SetJustifyH("LEFT")
        row._name:SetWordWrap(false)
    end
    row:SetHeight(Pixel.Scale(18))
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT",  card, "TOPLEFT",  Pixel.Scale(14), Pixel.Scale(-yBase - (rowIndex - 1) * 18))
    row:SetPoint("TOPRIGHT", card, "TOPRIGHT", Pixel.Scale(-14), Pixel.Scale(-yBase - (rowIndex - 1) * 18))
    row:Show()
    return row
end

local Layout = {
    PAD       = 16,
    TILE_W    = 192,
    TILE_H    = 70,
    TILE_GAP  = 12,
    TILES_TOP = -58,
    COL_H     = 206,
    WIDE_H    = 150,
}
Layout.DASH_W   = Layout.TILE_W * 4 + Layout.TILE_GAP * 3
Layout.COL_TOP  = Layout.TILES_TOP - Layout.TILE_H - 12
Layout.COL_W    = Layout.TILE_W * 2 + Layout.TILE_GAP
Layout.COL2_TOP = Layout.COL_TOP  - Layout.COL_H - 12
Layout.WIDE_TOP = Layout.COL2_TOP - Layout.COL_H - 12
Layout.DASH_H   = -Layout.WIDE_TOP + Layout.WIDE_H

local SLOTS = {
    { row = "mid",  x = 0,                              y = Layout.COL_TOP,  w = Layout.COL_W,  h = Layout.COL_H  },
    { row = "mid",  x = Layout.COL_W + Layout.TILE_GAP, y = Layout.COL_TOP,  w = Layout.COL_W,  h = Layout.COL_H  },
    { row = "mid2", x = 0,                              y = Layout.COL2_TOP, w = Layout.COL_W,  h = Layout.COL_H  },
    { row = "mid2", x = Layout.COL_W + Layout.TILE_GAP, y = Layout.COL2_TOP, w = Layout.COL_W,  h = Layout.COL_H  },
    { row = "wide", x = 0,                              y = Layout.WIDE_TOP, w = Layout.DASH_W, h = Layout.WIDE_H },
}

local DASHBOARD_MIN_WIDTH = 924
local DASHBOARD_MIN_HEIGHT = 600

local cardsByPage = setmetatable({}, { __mode = "k" })

local function BuildDashboard(canvas)
    font = BUILib.Font
    local accentRed, accentGreen, accentBlue = Theme.GetAccent()

    Theme.RegisterAccentElement(canvas, function(_, red, green, blue) accentRed, accentGreen, accentBlue = red, green, blue end)
    BUI.Tools.AddPageWatermark(canvas)

    local scroll = Controls.ScrollFrame(canvas)
    local scrollContainer = Widget.Unwrap(scroll)
    local scrollChild = scrollContainer.child
    local innerScrollFrame = scrollContainer.scrollFrame

    scrollChild:ClearAllPoints()
    scrollChild:SetPoint("TOPLEFT", innerScrollFrame, "TOPLEFT", 0, 0)
    local function SyncChildWidth()
        local width = innerScrollFrame:GetWidth()
        if width and width > 0 then scrollChild:SetWidth(width) end
    end
    SyncChildWidth()
    BUILib.Defer(SyncChildWidth)
    innerScrollFrame:HookScript("OnSizeChanged", SyncChildWidth)
    scrollContainer:SetChildHeight(Layout.DASH_H + Layout.PAD * 2)

    local dashboard = CreateFrame("Frame", nil, scrollChild)
    dashboard:SetSize(Pixel.Scale(Layout.DASH_W), Pixel.Scale(Layout.DASH_H))
    dashboard:SetPoint("TOP", scrollChild, "TOP", 0, Pixel.Scale(-Layout.PAD))

    local dashboardCards = {}
    cardsByPage[canvas] = dashboardCards

    local greeting = dashboard:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(greeting, 22, font, "")
    greeting:SetPoint("TOPLEFT", 0, 0)
    greeting:SetText("Welcome back, " .. UnitName("player"))
    greeting:SetTextColor(1, 1, 1, 1)

    local cogButton = Widget.Unwrap(Controls.Icon(dashboard, { size = 20 }))
    cogButton:SetPoint("LEFT", greeting, "RIGHT", Pixel.Scale(8), Pixel.Scale(-2))

    local className, classFile = UnitClass("player")
    local localizedClass = LOCALIZED_CLASS_NAMES_MALE[classFile] or className or ""
    local realmName = GetRealmName() or ""
    local zone = GetZoneText() or ""
    local subParts = {}
    if localizedClass ~= "" then subParts[#subParts + 1] = localizedClass end
    local spec = SpecName(); if spec ~= "" then subParts[#subParts + 1] = spec end
    subParts[#subParts + 1] = "iLvl " .. ItemLevel()
    if realmName ~= "" then subParts[#subParts + 1] = realmName end
    if zone ~= "" then subParts[#subParts + 1] = zone end
    local subtitle = dashboard:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(subtitle, 11, font, "")
    subtitle:SetPoint("TOPLEFT", greeting, "BOTTOMLEFT", 0, Pixel.Scale(-6))
    subtitle:SetText(table.concat(subParts, "   ·   "))
    subtitle:SetTextColor(0.55, 0.55, 0.6, 1)

    local refreshByCard, dirtyCards = {}, {}
    local function CardRefresher(card, refreshFunction)
        local function run()
            if card:IsVisible() then
                dirtyCards[card] = nil
                refreshFunction()
            else
                dirtyCards[card] = true
            end
        end
        refreshByCard[card] = run
        return run
    end

    local PlaceTopBand

    local function ApplyCardVisibility()
        for _, card in ipairs(dashboardCards) do
            if card._id and not IsCardVisible(card._id) then card:Hide() else card:Show() end
        end
        PlaceTopBand()
        for card in pairs(dirtyCards) do
            local run = refreshByCard[card]
            if run and card:IsVisible() then run() end
        end
    end

    local cardForSlot, slotForCard = {}, {}

    local function GetLayoutDB()
        local db = GetDashboardDB()
        db.layout = db.layout or {}
        return db.layout
    end

    local function MoveToSlot(card, slotIndex)
        local slot = SLOTS[slotIndex]
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", dashboard, "TOPLEFT", Pixel.Scale(slot.x), Pixel.Scale(slot.y))
    end

    local function SaveLayout()
        local db = GetLayoutDB()
        for card, slotIndex in pairs(slotForCard) do
            if card._id then db[card._id] = slotIndex end
        end
    end

    local function FindClosestSlot(card, fromSlot)
        local centerX = (card:GetLeft() or 0) + card:GetWidth() / 2 - (dashboard:GetLeft() or 0)
        local centerY = (card:GetTop()  or 0) - card:GetHeight() / 2 - (dashboard:GetTop() or 0)
        local row = SLOTS[fromSlot].row
        local bestSlot, bestDistance = fromSlot, math.huge
        for slotIndex, slot in ipairs(SLOTS) do
            if slot.row == row then
                local slotCenterX = slot.x + slot.w / 2
                local slotCenterY = slot.y - slot.h / 2
                local distance = (slotCenterX - centerX) * (slotCenterX - centerX) + (slotCenterY - centerY) * (slotCenterY - centerY)
                if distance < bestDistance then bestDistance, bestSlot = distance, slotIndex end
            end
        end
        return bestSlot
    end

    local function ClampDuringDrag(card)
        local dashLeft, dashRight   = dashboard:GetLeft(), dashboard:GetRight()
        local dashTop, dashBottom = dashboard:GetTop(),  dashboard:GetBottom()
        local cardLeft, cardRight  = card:GetLeft(),      card:GetRight()
        local cardTop, cardBottom  = card:GetTop(),       card:GetBottom()
        if not (dashLeft and dashRight and dashTop and dashBottom and cardLeft and cardRight and cardTop and cardBottom) then return end
        local shiftX, shiftY = 0, 0
        if cardLeft < dashLeft then shiftX = dashLeft - cardLeft elseif cardRight > dashRight then shiftX = dashRight - cardRight end
        if cardTop > dashTop then shiftY = dashTop - cardTop elseif cardBottom < dashBottom then shiftY = dashBottom - cardBottom end
        if shiftX ~= 0 or shiftY ~= 0 then
            local point, relativeTo, relativePoint, x, y = card:GetPoint(1)
            if point then card:ClearAllPoints(); card:SetPoint(point, relativeTo, relativePoint, x + shiftX, y + shiftY) end
        end
    end

    local function FindFreeSlotInRow(rowName)
        for slotIndex, slot in ipairs(SLOTS) do
            if slot.row == rowName and not cardForSlot[slotIndex] then return slotIndex end
        end
        return nil
    end

    local function MakeDraggable(card, cardID, defaultSlot)
        card._id = cardID

        if not IsCardVisible(cardID) then
            card:Hide()
            return
        end

        local defaultRow = SLOTS[defaultSlot].row
        local savedSlot  = GetLayoutDB()[cardID]
        local targetSlot = savedSlot
        if not targetSlot
           or not SLOTS[targetSlot]
           or SLOTS[targetSlot].row ~= defaultRow
           or cardForSlot[targetSlot] then
            targetSlot = (not cardForSlot[defaultSlot]) and defaultSlot or FindFreeSlotInRow(defaultRow)
        end
        if not targetSlot then card:Hide(); return end

        cardForSlot[targetSlot] = card
        slotForCard[card]   = targetSlot
        MoveToSlot(card, targetSlot)

        card:SetMovable(true)
        card:EnableMouse(true)
        card:RegisterForDrag("LeftButton")
        card:SetScript("OnDragStart", function(self)
            if activeSlideIn then FinalizeSlideIn(activeSlideIn); activeSlideIn = nil end
            self:SetAlpha(0.7)
            self:Raise()
            self:StartMoving()
            self:SetScript("OnUpdate", ClampDuringDrag)
        end)
        card:SetScript("OnDragStop", function(self)
            self:SetScript("OnUpdate", nil)
            self:StopMovingOrSizing()
            self:SetAlpha(1)
            local fromSlot = slotForCard[self]
            local toSlot   = FindClosestSlot(self, fromSlot)
            if toSlot ~= fromSlot then
                local occupant = cardForSlot[toSlot]
                cardForSlot[fromSlot] = occupant
                if occupant and occupant ~= self then
                    slotForCard[occupant] = fromSlot
                    MoveToSlot(occupant, fromSlot)
                end
                cardForSlot[toSlot] = self
                slotForCard[self]   = toSlot
            end
            MoveToSlot(self, slotForCard[self])
            SaveLayout()
        end)
    end

    local TOP_COLUMN_COUNT = 4
    local topEntries = {}
    local topEntryByCard = {}
    local entryAtColumn = {}

    local function GetTopColumns()
        local db = GetDashboardDB()
        db.topCols = db.topCols or {}
        return db.topCols
    end

    local function MoveToColumn(card, column)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", dashboard, "TOPLEFT", Pixel.Scale(column * (Layout.TILE_W + Layout.TILE_GAP)), Pixel.Scale(Layout.TILES_TOP))
    end

    function PlaceTopBand()
        local savedColumns = GetTopColumns()
        local visibleEntries = {}
        for _, entry in ipairs(topEntries) do
            if entry.card:IsShown() then visibleEntries[#visibleEntries + 1] = entry end
        end
        table.sort(visibleEntries, function(leftEntry, rightEntry) return leftEntry.defaultCol < rightEntry.defaultCol end)
        for column in pairs(entryAtColumn) do entryAtColumn[column] = nil end
        for _, entry in ipairs(visibleEntries) do
            local column = savedColumns[entry.id]
            if type(column) ~= "number" or column < 0 or column >= TOP_COLUMN_COUNT or entryAtColumn[column] then column = nil end
            if not column then
                for offset = 0, TOP_COLUMN_COUNT - 1 do
                    local candidateColumn = (entry.defaultCol + offset) % TOP_COLUMN_COUNT
                    if not entryAtColumn[candidateColumn] then column = candidateColumn; break end
                end
            end
            if column then
                entryAtColumn[column] = entry
                entry.col = column
                MoveToColumn(entry.card, column)
            end
        end
    end

    local function NearestColumn(card)
        local dashLeft = dashboard:GetLeft()
        local cardLeft = card:GetLeft()
        if not dashLeft or not cardLeft then return nil end
        local centerX = cardLeft + card:GetWidth() / 2 - dashLeft
        local stride = Pixel.Scale(Layout.TILE_W + Layout.TILE_GAP)
        if stride <= 0 then return nil end
        local column = math.floor((centerX - Pixel.Scale(Layout.TILE_W) / 2) / stride + 0.5)
        if column < 0 then column = 0 elseif column >= TOP_COLUMN_COUNT then column = TOP_COLUMN_COUNT - 1 end
        return column
    end

    local function MakeTopDraggable(card, cardID, defaultColumn)
        card._id = cardID
        if not IsCardVisible(cardID) then
            card:Hide()
            return
        end
        local entry = { card = card, id = cardID, defaultCol = defaultColumn }
        topEntries[#topEntries + 1] = entry
        topEntryByCard[card] = entry

        card:SetMovable(true)
        card:EnableMouse(true)
        card:RegisterForDrag("LeftButton")
        card:SetScript("OnDragStart", function(self)
            if activeSlideIn then FinalizeSlideIn(activeSlideIn); activeSlideIn = nil end
            self:SetAlpha(0.7)
            self:Raise()
            self:StartMoving()
            self:SetScript("OnUpdate", ClampDuringDrag)
        end)
        card:SetScript("OnDragStop", function(self)
            self:SetScript("OnUpdate", nil)
            self:StopMovingOrSizing()
            self:SetAlpha(1)
            local entry = topEntryByCard[self]
            local toColumn = NearestColumn(self)
            local fromColumn = entry.col
            if toColumn ~= nil and fromColumn ~= nil and toColumn ~= fromColumn then
                local savedColumns = GetTopColumns()
                local occupant = entryAtColumn[toColumn]
                savedColumns[entry.id] = toColumn
                if occupant and occupant ~= entry then savedColumns[occupant.id] = fromColumn end
            end
            PlaceTopBand()
        end)
    end

    local function BuildTile(cardID, defaultColumn, options)
        local tile = MakeCard(dashboard, dashboardCards)
        tile:SetSize(Pixel.Scale(Layout.TILE_W), Pixel.Scale(Layout.TILE_H))
        MakeTopDraggable(tile, cardID, defaultColumn)

        if options.header then
            MakeCardHeader(tile, options.header, accentRed, accentGreen, accentBlue)
        else
            local kickerFontString = tile:CreateFontString(nil, "OVERLAY")
            Pixel.ApplyFont(kickerFontString, 10, font, "")
            kickerFontString:SetPoint("TOPLEFT", Pixel.Scale(16), Pixel.Scale(-14))
            kickerFontString:SetText(options.kicker)
            kickerFontString:SetTextColor(accentRed * 0.85, accentGreen * 0.85, accentBlue * 0.85, 1)
        end

        local valueFontString = tile:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(valueFontString, 24, font, "")
        valueFontString:SetPoint("LEFT", Pixel.Scale(16), Pixel.Scale(-6))
        valueFontString:SetTextColor(0.95, 0.95, 0.95, 1)

        local subFontString = tile:CreateFontString(nil, "OVERLAY")
        Pixel.ApplyFont(subFontString, 10, font, "")
        subFontString:SetPoint("TOPLEFT", valueFontString, "BOTTOMLEFT", 0, Pixel.Scale(-2))
        subFontString:SetTextColor(0.45, 0.45, 0.5, 1)

        return tile, valueFontString, subFontString
    end

    local STATS = {
        { id = "stat_ilvl",    col = 0, kicker = "ITEM LEVEL", sub = "equipped / overall", valueFn = ItemLevel       },
        { id = "stat_mscore",  col = 1, kicker = "M+ SCORE",   sub = "this season",        valueFn = MythicPlusScore },
        { id = "stat_session", col = 3, kicker = "SESSION",    sub = "this run",           valueFn = Session         },
    }
    local tileRefreshers = {}
    for _, stat in ipairs(STATS) do
        local _, valueFontString, subFontString = BuildTile(stat.id, stat.col, { kicker = stat.kicker })
        valueFontString:SetText(stat.valueFn())
        subFontString:SetText(stat.sub)
        tileRefreshers[#tileRefreshers + 1] = { fs = valueFontString, fn = stat.valueFn }
    end

    local weeklyTile, weeklyCountFontString, weeklySubFontString = BuildTile("weeklyMplus", 2, { header = "WEEKLY M+" })
    weeklySubFontString:SetText("runs")

    local weeklyHover = weeklyTile:CreateTexture(nil, "HIGHLIGHT")
    weeklyHover:SetAllPoints()
    BUI.Tools.SetColorTex(weeklyHover, 1, 1, 1, 0.04)

    local RefreshWeeklyMplus = CardRefresher(weeklyTile, function()
        local runCount = WeeklyMplusCount()
        RecordWeeklyMplus(runCount)
        weeklyCountFontString:SetText(tostring(runCount))
    end)
    RefreshWeeklyMplus()

    weeklyTile:HookScript("OnEnter", function(self)
        local rows = {}
        for _, entry in ipairs(WeeklyMplusHistoryEntries()) do
            rows[#rows + 1] = { left = entry.label, right = tostring(entry.count) }
        end
        local seasonRuns = C_MythicPlus.GetRunHistory(true, false)
        if type(seasonRuns) == "table" then
            rows[#rows + 1] = { space = true }
            rows[#rows + 1] = { left = "This season", right = tostring(#seasonRuns), rightColor = { 1, 0.82, 0 } }
        end
        BUILib.Widget.ShowTipRows(self, "Weekly M+ Runs", rows, { anchor = "RIGHT" })
    end)
    weeklyTile:HookScript("OnLeave", function() BUILib.Widget.HideTip() end)

    local function RefreshTiles()
        for _, refresher in ipairs(tileRefreshers) do refresher.fs:SetText(refresher.fn()) end
    end

    local dungeons = MakeCard(dashboard, dashboardCards)
    dungeons:SetSize(Pixel.Scale(Layout.COL_W), Pixel.Scale(Layout.COL_H))
    MakeDraggable(dungeons, "dungeons", 1)
    local dungeonsHeader = MakeCardHeader(dungeons, "RECENT DUNGEONS", accentRed, accentGreen, accentBlue)

    local dungeonsSummary = dungeons:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(dungeonsSummary, 10, font, "")
    dungeonsSummary:SetPoint("TOPLEFT", Pixel.Scale(16), Pixel.Scale(-36))
    dungeonsSummary:SetPoint("TOPRIGHT", Pixel.Scale(-16), Pixel.Scale(-36))
    dungeonsSummary:SetJustifyH("LEFT")
    dungeonsSummary:SetTextColor(0.65, 0.65, 0.7, 1)
    dungeonsSummary:Hide()

    local dungeonsSignature
    local RefreshDungeons = CardRefresher(dungeons, function()
        local raiderIORuns, raiderIOKeystoneProfile = RaiderIORuns()
        local blizzardRuns = BlizzardRuns()
        local runs = raiderIORuns or blizzardRuns
        local usingRaiderIO  = raiderIORuns ~= nil

        local bestLevel, timedCount, totalRuns = 0, 0, #blizzardRuns
        if usingRaiderIO then
            local bestTimeByMapKey = {}
            for _, run in ipairs(blizzardRuns) do
                if run.mapID and run.completed and (run.durationSec or 0) > 0 then
                    local key = run.mapID .. ":" .. (run.level or 0)
                    if not bestTimeByMapKey[key] or run.durationSec < bestTimeByMapKey[key] then bestTimeByMapKey[key] = run.durationSec end
                end
                if run.completed and (run.upgrades or 0) > 0 then
                    timedCount = timedCount + 1
                    if (run.level or 0) > bestLevel then bestLevel = run.level end
                end
            end
            for _, run in ipairs(runs) do
                if not run.clearTimeMS and run.mapID and run.level then
                    local duration = bestTimeByMapKey[run.mapID .. ":" .. run.level]
                    if duration then run.durationSec = duration end
                end
            end
        end

        local currentScore  = (raiderIOKeystoneProfile and raiderIOKeystoneProfile.currentScore)  or 0
        local previousScore = (raiderIOKeystoneProfile and raiderIOKeystoneProfile.previousScore) or 0

        local signatureParts = { usingRaiderIO and 1 or 0, currentScore, previousScore, bestLevel, timedCount, totalRuns, #runs }
        for runIndex = 1, math.min(#runs, 8) do
            local run = runs[runIndex]
            signatureParts[#signatureParts + 1] = table.concat({
                run.mapName or "", run.level or 0, run.upgrades or 0,
                math.floor((usingRaiderIO and RaiderIORunSeconds(run) or run.durationSec) or 0),
                run.score or 0, run.completed and 1 or 0,
            }, ":")
        end
        local signature = table.concat(signatureParts, "|")
        if signature == dungeonsSignature then return end
        dungeonsSignature = signature

        ClearRows(dungeons)
        dungeonsHeader:SetText(usingRaiderIO and "BEST KEYS (RaiderIO)" or "RECENT DUNGEONS")

        if usingRaiderIO then
            local previousText = previousScore > 0 and ("  ·  Prev |cff888888" .. previousScore .. "|r") or ""
            dungeonsSummary:SetText(string.format(
                "Score |cffffffff%d|r%s  ·  Best |cffffffff+%d|r  ·  Timed |cffffffff%d/%d|r",
                currentScore, previousText, bestLevel, timedCount, totalRuns))
            dungeonsSummary:Show()
        else
            dungeonsSummary:Hide()
        end

        if #runs == 0 then
            dungeons._rows[#dungeons._rows + 1] = MakeEmptyRow(dungeons, "No recent dungeon runs.")
            return
        end

        local rowYBase = usingRaiderIO and 50 or 36
        for runIndex = 1, math.min(#runs, 8) do
            local run = runs[runIndex]
            local row = MakeDungeonRow(dungeons, runIndex, rowYBase, Layout.COL_W)

            local timed   = (run.upgrades or 0) > 0
            local untimed = (usingRaiderIO and (run.level or 0) <= 0) or (not usingRaiderIO and not run.completed)
            local levelRed, levelGreen, levelBlue
            if untimed then
                levelRed, levelGreen, levelBlue = (usingRaiderIO and 0.5 or 0.85), (usingRaiderIO and 0.5 or 0.5), (usingRaiderIO and 0.55 or 0.5)
            elseif timed then
                levelRed, levelGreen, levelBlue = KeyTierColor(run.level or 0, run.score)
            else
                levelRed, levelGreen, levelBlue = 0.95, 0.7, 0.4
            end

            local actualSeconds = usingRaiderIO and RaiderIORunSeconds(run) or run.durationSec
            local limitSeconds  = run.mapID and MapTimeLimit(run.mapID) or nil
            local deltaText  = (timed and not untimed) and TimeDelta(actualSeconds, limitSeconds) or ""
            local timeText   = Duration(actualSeconds)
            local levelText    = (usingRaiderIO and (run.level or 0) <= 0) and "no run" or KeyLevel(run.level, run.upgrades)
            if not usingRaiderIO and not run.completed then levelText = levelText .. "*" end
            local scoreText  = (not untimed) and Score(run.score) or ""

            if deltaText ~= "" then
                row._time:SetText(timeText .. " |cff5cd47b" .. deltaText .. "|r")
            else
                row._time:SetText(timeText)
            end
            row._time:SetTextColor(0.55, 0.55, 0.6, 1)

            row._lvl:SetText(levelText)
            if untimed then row._lvl:SetTextColor(0.6, 0.6, 0.65, 1)
            else row._lvl:SetTextColor(levelRed, levelGreen, levelBlue, 1) end

            row._score:SetText(scoreText)
            row._score:SetTextColor(0.55, 0.85, 0.55, 1)

            row._left:SetText(run.mapName or "")
            row._left:SetTextColor(0.95, 0.95, 0.97, 1)

            dungeons._rows[#dungeons._rows + 1] = row
        end
    end)

    C_MythicPlus.RequestMapInfo()
    RefreshDungeons()

    local vaultCard = MakeCard(dashboard, dashboardCards)
    vaultCard:SetSize(Pixel.Scale(Layout.COL_W), Pixel.Scale(Layout.COL_H))
    MakeDraggable(vaultCard, "vault", 2)
    MakeCardHeader(vaultCard, "GREAT VAULT", accentRed, accentGreen, accentBlue)

    local vaultHint = vaultCard:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(vaultHint, 10, font, "")
    vaultHint:SetPoint("BOTTOMLEFT", Pixel.Scale(14), Pixel.Scale(10))
    vaultHint:SetTextColor(0.5, 0.5, 0.55, 1)

    local RefreshVault
    local vaultItemWaiting = false
    local function QueueVaultItemLoad(link)
        if vaultItemWaiting then return end
        local ok, item = pcall(Item.CreateFromItemLink, Item, link)
        if ok and item and not item:IsItemEmpty() then
            vaultItemWaiting = true
            item:ContinueOnItemLoad(function()
                vaultItemWaiting = false
                if RefreshVault then RefreshVault() end
            end)
        end
    end

    RefreshVault = CardRefresher(vaultCard, function()
        ClearRows(vaultCard)
        local RewardThresholdType = Enum.WeeklyRewardChestThresholdType
        local sections = {
            { label = "Raids",    acts = SortedVaultActivities(RewardThresholdType.Raid)       },
            { label = "Dungeons", acts = SortedVaultActivities(RewardThresholdType.Activities) },
            { label = "World",    acts = SortedVaultActivities(RewardThresholdType.World)      },
        }
        local pendingLink
        for sectionIndex, section in ipairs(sections) do
            vaultCard._rows[#vaultCard._rows + 1] = MakeVaultTypeRow(vaultCard, sectionIndex, section.label, section.acts, Layout.COL_W, accentRed, accentGreen, accentBlue)
            if not pendingLink then
                for _, activity in ipairs(section.acts) do
                    if (activity.progress or 0) >= (activity.threshold or math.huge) and not VaultRewardItemLevel(activity) and activity.id then
                        pendingLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(activity.id)
                        if pendingLink then break end
                    end
                end
            end
        end

        local nextLocked
        for _, activity in ipairs(sections[2].acts) do
            if (activity.progress or 0) < (activity.threshold or 0) then nextLocked = activity break end
        end
        if nextLocked then
            local need = (nextLocked.threshold or 0) - (nextLocked.progress or 0)
            vaultHint:SetText(("%d more M+ %s the next slot"):format(need, need == 1 and "run unlocks" or "runs unlock"))
        elseif #sections[2].acts > 0 then
            vaultHint:SetText("All dungeon slots unlocked")
        else
            vaultHint:SetText("")
        end

        if pendingLink then QueueVaultItemLoad(pendingLink) end
    end)
    RefreshVault()

    local raidCard = MakeCard(dashboard, dashboardCards)
    raidCard:SetSize(Pixel.Scale(Layout.COL_W), Pixel.Scale(Layout.COL_H))
    MakeDraggable(raidCard, "raidprog", 3)
    local raidHeader = MakeCardHeader(raidCard, "RAID PROGRESS", accentRed, accentGreen, accentBlue)

    local raidSummary = raidCard:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(raidSummary, 10, font, "")
    raidSummary:SetPoint("TOPLEFT", Pixel.Scale(16), Pixel.Scale(-36))
    raidSummary:SetPoint("TOPRIGHT", Pixel.Scale(-16), Pixel.Scale(-36))
    raidSummary:SetJustifyH("LEFT")
    raidSummary:SetTextColor(0.65, 0.65, 0.7, 1)

    local RAID_DIFFICULTY_LABEL = { "N", "H", "M" }
    local RefreshRaidProgress = CardRefresher(raidCard, function()
        ClearRows(raidCard)
        local raid = RaidProgress()
        if not raid or raid.bossCount == 0 then
            raidHeader:SetText("RAID PROGRESS")
            raidSummary:SetText("")
            raidCard._rows[#raidCard._rows + 1] = MakeEmptyRow(raidCard, "No raid data yet.")
            return
        end
        raidHeader:SetText((raid.name or "RAID"):upper())

        local parts = {}
        for difficultyIndex = 1, 3 do
            local info = raid.diffs[difficultyIndex]
            local difficultyColor = RAID_DIFFICULTY_COLORS[difficultyIndex]
            parts[#parts + 1] = ("|cff%02x%02x%02x%s %d/%d|r"):format(
                math.floor(difficultyColor[1] * 255), math.floor(difficultyColor[2] * 255), math.floor(difficultyColor[3] * 255),
                RAID_DIFFICULTY_LABEL[difficultyIndex], (info and info.killed) or 0, raid.bossCount)
        end
        raidSummary:SetText(table.concat(parts, "    ")
            .. (raid.source == "lockout" and "    |cff888888this week|r" or ""))

        for bossIndex = 1, math.min(raid.bossCount, 8) do
            local row = MakeRaidRow(raidCard, bossIndex, 54)
            row._left:SetText((raid.bosses and raid.bosses[bossIndex]) or ("Boss " .. bossIndex))
            row._left:SetTextColor(0.92, 0.92, 0.94, 1)
            for difficultyIndex = 1, 3 do
                local info  = raid.diffs[difficultyIndex]
                local kills = info and info.kills and tonumber(info.kills[bossIndex]) or 0
                local difficultyColor  = RAID_DIFFICULTY_COLORS[difficultyIndex]
                local fontString = row._cols[difficultyIndex]
                if raid.source == "lockout" then
                    fontString:SetText(kills > 0 and "+" or "-")
                else
                    fontString:SetText(tostring(kills))
                end
                if kills > 0 then fontString:SetTextColor(difficultyColor[1], difficultyColor[2], difficultyColor[3], 1)
                else fontString:SetTextColor(0.4, 0.42, 0.46, 1) end
            end
            raidCard._rows[#raidCard._rows + 1] = row
        end
    end)
    RequestRaidInfo()
    RefreshRaidProgress()

    local crestCard = MakeCard(dashboard, dashboardCards)
    crestCard:SetSize(Pixel.Scale(Layout.COL_W), Pixel.Scale(Layout.COL_H))
    MakeDraggable(crestCard, "crests", 4)
    MakeCardHeader(crestCard, "CRESTS", accentRed, accentGreen, accentBlue)

    local RefreshCrests = CardRefresher(crestCard, function()
        ClearRows(crestCard)
        local currencies = SeasonCurrencyList()
        if not currencies then
            crestCard._rows[#crestCard._rows + 1] = MakeEmptyRow(crestCard, "No crests found yet.")
            return
        end
        local rowCount = math.min(#currencies, CREST_ROW_LIMIT)
        local rowPitch = math.min(CREST_ROW_PITCH, math.floor(CREST_ROWS_HEIGHT / math.max(rowCount, 1)))
        for currencyIndex = 1, rowCount do
            local currency = currencies[currencyIndex]
            local value
            if currency.max > 0 then
                value = ("%d/%d"):format(currency.quantity, currency.max)
            else
                value = tostring(currency.quantity)
            end
            local qualityColor = currency.quality and ITEM_QUALITY_COLORS[currency.quality]
            crestCard._rows[#crestCard._rows + 1] = MakeCrestRow(crestCard, currencyIndex, currency.name, value, currency.icon,
                qualityColor and qualityColor.r, qualityColor and qualityColor.g, qualityColor and qualityColor.b, rowPitch)
        end
    end)
    RefreshCrests()

    local altCard = MakeCard(dashboard, dashboardCards)
    altCard:SetSize(Pixel.Scale(Layout.DASH_W), Pixel.Scale(Layout.WIDE_H))
    MakeDraggable(altCard, "alts", 5)
    MakeCardHeader(altCard, "ALT OVERVIEW", accentRed, accentGreen, accentBlue)

    local RefreshAlts = CardRefresher(altCard, function()
        SnapshotCurrentChar()
        ClearRows(altCard)
        local globalDB = BUI.db and BUI.db.global
        local store = globalDB and globalDB.altOverview
        if not store or not next(store) then
            altCard._rows[#altCard._rows + 1] = MakeEmptyRow(altCard, "No characters recorded yet.")
            return
        end

        local characters = {}
        for _, character in pairs(store) do characters[#characters + 1] = character end
        table.sort(characters, function(leftCharacter, rightCharacter)
            if (leftCharacter.score or 0) ~= (rightCharacter.score or 0) then return (leftCharacter.score or 0) > (rightCharacter.score or 0) end
            return (leftCharacter.ilvl or 0) > (rightCharacter.ilvl or 0)
        end)

        local headerRow = MakeAltRow(altCard, 1, 34)
        headerRow._name:SetText("CHARACTER")
        headerRow._ilvl:SetText("ILVL")
        headerRow._score:SetText("SCORE")
        headerRow._key:SetText("KEYSTONE")
        headerRow._vault:SetText("VAULT R·D·W")
        headerRow._seen:SetText("SEEN")
        for _, fontString in ipairs({ headerRow._name, headerRow._ilvl, headerRow._score, headerRow._key, headerRow._vault, headerRow._seen }) do
            fontString:SetTextColor(0.5, 0.5, 0.55, 1)
        end
        altCard._rows[#altCard._rows + 1] = headerRow

        local now = time()
        local lastReset = now + WeeklyResetSeconds() - 7 * 86400
        local myName, myRealm = UnitName("player"), GetRealmName()
        for characterIndex = 1, math.min(#characters, 5) do
            local character = characters[characterIndex]
            local row = MakeAltRow(altCard, characterIndex + 1, 34)
            local isMe = (character.name == myName and character.realm == myRealm)

            local nameText = character.name or "?"
            if character.realm and character.realm ~= myRealm then nameText = nameText .. "-" .. character.realm end
            row._name:SetText(nameText)
            local classColor = character.class and RAID_CLASS_COLORS[character.class]
            if classColor then row._name:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
            else row._name:SetTextColor(0.92, 0.92, 0.92, 1) end

            row._ilvl:SetText(tostring(character.ilvl or 0))
            row._ilvl:SetTextColor(0.88, 0.88, 0.9, 1)

            local score = character.score or 0
            local scoreColor = C_ChallengeMode.GetDungeonScoreRarityColor(score)
            row._score:SetText(tostring(score))
            if scoreColor then row._score:SetTextColor(scoreColor.r, scoreColor.g, scoreColor.b, 1)
            else row._score:SetTextColor(0.7, 0.7, 0.75, 1) end

            local fresh = (character.lastSeen or 0) >= lastReset or isMe
            if fresh and character.keyLevel then
                row._key:SetText(("+%d %s"):format(character.keyLevel, character.keyMap or "?"))
                row._key:SetTextColor(0.85, 0.85, 0.9, 1)
            else
                row._key:SetText("-")
                row._key:SetTextColor(0.45, 0.45, 0.5, 1)
            end
            if fresh and character.vault then
                row._vault:SetText(("%d·%d·%d"):format(character.vault[1] or 0, character.vault[2] or 0, character.vault[3] or 0))
                row._vault:SetTextColor(0.75, 0.75, 0.8, 1)
            else
                row._vault:SetText("-")
                row._vault:SetTextColor(0.45, 0.45, 0.5, 1)
            end

            row._seen:SetText(isMe and "now" or FormatAgo(now - (character.lastSeen or now)))
            row._seen:SetTextColor(0.5, 0.5, 0.55, 1)
            altCard._rows[#altCard._rows + 1] = row
        end
    end)
    RefreshAlts()

    local slowTickCount = 0
    local refreshTicker
    local function StartRefreshTicker()
        if refreshTicker then return end
        refreshTicker = C_Timer.NewTicker(1, function()
            if not dashboard:IsVisible() then
                refreshTicker:Cancel()
                refreshTicker = nil
                return
            end
            RefreshTiles()
            slowTickCount = slowTickCount + 1
            if slowTickCount >= 30 then
                slowTickCount = 0
                RefreshDungeons(); RefreshVault(); RefreshWeeklyMplus()
                RefreshRaidProgress(); RefreshCrests(); RefreshAlts()
            end
        end)
    end
    StartRefreshTicker()

    canvas:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    canvas:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    canvas:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    canvas:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    canvas:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    canvas:RegisterEvent("UPDATE_INSTANCE_INFO")
    canvas:RegisterEvent("BOSS_KILL")
    canvas:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    canvas:SetScript("OnEvent", function(_, event)
        if not canvas:IsVisible() then return end
        if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then
            RefreshTiles()
        elseif event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_MAPS_UPDATE" then
            RefreshTiles(); RefreshDungeons(); RefreshWeeklyMplus()
        elseif event == "WEEKLY_REWARDS_UPDATE" then
            RefreshVault()
        elseif event == "UPDATE_INSTANCE_INFO" or event == "BOSS_KILL" then
            RefreshRaidProgress()
        elseif event == "CURRENCY_DISPLAY_UPDATE" then
            RefreshCrests()
        end
    end)

    canvas:HookScript("OnShow", function()
        RefreshTiles()
        RefreshDungeons(); RefreshVault(); RefreshWeeklyMplus()
        RequestRaidInfo()
        RefreshRaidProgress(); RefreshCrests(); RefreshAlts()
        slowTickCount = 0
        StartRefreshTicker()
    end)

    local LAYOUT_GROUPS = {
        { key = "tiles", title = "TOP TILES" },
        { key = "cards", title = "CARDS"    },
    }

    local function OpenLayoutSettings()
        local groups = { tiles = {}, cards = {} }
        for _, cardInfo in ipairs(CARD_DEFINITIONS) do
            local groupList = groups[cardInfo.group]
            groupList[#groupList + 1] = cardInfo
        end
        local maxRows = 0
        for _, groupList in pairs(groups) do
            if #groupList > maxRows then maxRows = #groupList end
        end

        local sidePadding    = 30
        local columnWidth       = 168
        local columnGap     = 16
        local columnHeaderHeight = 18
        local rowHeight       = 28
        local topPadding     = 92
        local bottomPadding     = 66
        local columnCount    = #LAYOUT_GROUPS
        local modalWidth     = sidePadding * 2 + columnWidth * columnCount + columnGap * (columnCount - 1)
        local modalHeight     = topPadding + columnHeaderHeight + maxRows * rowHeight + bottomPadding

        local overlay, CloseModal = Modals.Custom({
            title     = "Dashboard Layout",
            width     = modalWidth,
            height    = modalHeight,
            message   = "Pick which cards show. Drag them around to reorder within a row.",
            showClose = false,
        })
        local dialog = overlay.dialog or overlay

        if dialog.message then
            dialog.message:ClearAllPoints()
            dialog.message:SetPoint("TOP",   dialog, "TOP",   0, Pixel.Scale(-52))
            dialog.message:SetPoint("LEFT",  dialog, "LEFT",  Pixel.Scale(20), 0)
            dialog.message:SetPoint("RIGHT", dialog, "RIGHT", Pixel.Scale(-20), 0)
        end

        local divider = dialog:CreateTexture(nil, "OVERLAY")
        divider:SetTexture(Widget.WHITE); divider:SetVertexColor(1, 1, 1, 0.05)
        divider:SetHeight(Pixel.PixelSize(1))
        divider:SetPoint("TOPLEFT",  dialog, "TOPLEFT",  Pixel.Scale(sidePadding), Pixel.Scale(-(topPadding - 14)))
        divider:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", Pixel.Scale(-sidePadding), Pixel.Scale(-(topPadding - 14)))

        local db = GetDashboardDB()
        db.cardVisibility = db.cardVisibility or {}

        local appliers = {}

        for columnIndex, group in ipairs(LAYOUT_GROUPS) do
            local columnX = sidePadding + (columnIndex - 1) * (columnWidth + columnGap)

            local header = dialog:CreateFontString(nil, "OVERLAY")
            Pixel.ApplyFont(header, 10, font, "OUTLINE")
            header:SetPoint("TOPLEFT", dialog, "TOPLEFT", Pixel.Scale(columnX + 4), Pixel.Scale(-topPadding))
            header:SetText(group.title)
            header:SetTextColor(1, 1, 1, 1)

            local headerRule = dialog:CreateTexture(nil, "OVERLAY")
            headerRule:SetTexture(Widget.WHITE)
            headerRule:SetVertexColor(accentRed, accentGreen, accentBlue, 0.25)
            headerRule:SetHeight(Pixel.PixelSize(1))
            headerRule:SetWidth(Pixel.Scale(columnWidth - 12))
            headerRule:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, Pixel.Scale(-3))

            for rowIndex, cardInfo in ipairs(groups[group.key]) do
                local row = CreateFrame("Frame", nil, dialog)
                row:SetSize(Pixel.Scale(columnWidth), Pixel.Scale(rowHeight))
                row:SetPoint("TOPLEFT", dialog, "TOPLEFT", Pixel.Scale(columnX), Pixel.Scale(-topPadding - columnHeaderHeight - (rowIndex - 1) * rowHeight))

                local checked = IsCardVisible(cardInfo.id)

                local dot = row:CreateTexture(nil, "OVERLAY")
                dot:SetTexture(Widget.WHITE)
                dot:SetVertexColor(accentRed, accentGreen, accentBlue, checked and 1 or 0.22)
                dot:SetSize(Pixel.Scale(4), Pixel.Scale(4)); dot:SetPoint("LEFT", Pixel.Scale(4), 0)

                local label = row:CreateFontString(nil, "OVERLAY")
                Pixel.ApplyFont(label, 12, font, "")
                label:SetPoint("LEFT", Pixel.Scale(16), 0)
                label:SetText(cardInfo.label)
                local function PaintLabel(isOn)
                    local shade = isOn and 0.95 or 0.5
                    label:SetTextColor(shade, shade, isOn and 0.97 or 0.5, 1)
                end
                PaintLabel(checked)

                local toggle
                local function Apply(isVisible)
                    db.cardVisibility[cardInfo.id] = isVisible
                    dot:SetVertexColor(accentRed, accentGreen, accentBlue, isVisible and 1 or 0.22)
                    PaintLabel(isVisible)
                    if toggle then toggle:SetValue(isVisible) end
                end
                appliers[#appliers + 1] = Apply

                toggle = Controls.StampCheckbox(row, nil, checked, function(isVisible)
                    Apply(isVisible)
                    BUI.PageEngine.RefreshCurrentPage()
                end)
                local toggleFrame = toggle.frame or toggle
                toggleFrame:ClearAllPoints(); toggleFrame:SetParent(row); toggleFrame:SetPoint("RIGHT", Pixel.Scale(-8), 0)
            end
        end

        local function FlipAll(value)
            for _, apply in ipairs(appliers) do apply(value) end
            BUI.PageEngine.RefreshCurrentPage()
        end

        local gap = 10
        local buttons = {
            Controls.Button(dialog, "Select all",   110, function() FlipAll(true)  end, { radius = 6 }),
            Controls.Button(dialog, "Unselect all", 110, function() FlipAll(false) end, { radius = 6 }),
            Controls.Button(dialog, "Close",        110, function() CloseModal()   end, { radius = 6 }),
        }
        local totalWidth = -gap
        for _, button in ipairs(buttons) do totalWidth = totalWidth + (button.frame or button):GetWidth() + gap end
        local x = -totalWidth / 2
        for _, button in ipairs(buttons) do
            local buttonFrame = button.frame or button
            buttonFrame:ClearAllPoints()
            buttonFrame:SetPoint("BOTTOM", dialog, "BOTTOM", x + buttonFrame:GetWidth() / 2, Pixel.Scale(16))
            x = x + buttonFrame:GetWidth() + gap
        end
    end
    cogButton:SetScript("OnClick", OpenLayoutSettings)

    ApplyCardVisibility()
    return dashboard
end

BUI.PageEngine.RegisterPage("dashboard", {
    title = "Dashboard",
    buttonText = "Dashboard",
    minContentWidth  = DASHBOARD_MIN_WIDTH,
    minContentHeight = DASHBOARD_MIN_HEIGHT,
    OnBuild = function(pageFrame) BuildDashboard(pageFrame) end,
    OnShow  = function(pageFrame) PlayCardSlideIn(cardsByPage[pageFrame], pageFrame) end,
})
