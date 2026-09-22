local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('CDM.Events')

local GetTime = GetTime
local wipe = wipe

local CDM = BUI.CDM

local NotifyIconListRefreshers = BUI.Dispatcher.New(function()
    if InCombatLockdown() then return end
    if not CDM._iconListRefreshers then return end
    if not (BUI.PageEngine.frame and BUI.PageEngine.frame:IsShown()) then return end
    for _, callback in pairs(CDM._iconListRefreshers) do
        callback()
    end
end, 'CDM.IconListRefresh')

local function OnTalentBurst()
    BUI.Tools.InvalidateOverrideCache()
    BUI.Tools.InvalidateSpellBookIconCache()
    BUI.Tools.InvalidateChargeSpellCache()
    CDM.InvalidateClassSpellCache()
    CDM.MarkAllDirty()
    NotifyIconListRefreshers()

    CDM.UpdateShowOnlyOnCDWatcher()
    CDM.UpdateHideWhenZeroWatcher()
end

local function OnCooldownViewerDataLoaded()
    CDM.InvalidateSkinCache()
    CDM.MarkAllDirty()
    NotifyIconListRefreshers()
end

local cdSnapshotTime = 0

local cdSnapshot = {}

local function GetCooldownCached(spellID)
    local now = GetTime()
    if now ~= cdSnapshotTime then
        cdSnapshotTime = now
        wipe(cdSnapshot)
    end
    local cached = cdSnapshot[spellID]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    local info = C_Spell.GetSpellCooldown(spellID)
    cdSnapshot[spellID] = info or false
    return info
end

local cdLayoutRegistered = false
local cdWatchedSpells = {}
local cdWatchedItems = {}
local cdWatchedViewers = {}
local cdAltToWatched = {}
local cdAltConfigID = nil
local cdDirtyViewers = {}

local cdExpectedEnd = {}
local itemExpectedEnd = {}

local cdEndTimers = {}
local cdEstimatedEnd = {}
local itemEndTimers = {}

local function CancelCDEndTimer(spellID)
    local timer = cdEndTimers[spellID]
    if timer then
        timer:Cancel()
        cdEndTimers[spellID] = nil
    end
end

local function ClearCDExpectation(spellID)
    cdExpectedEnd[spellID] = nil
    cdEstimatedEnd[spellID] = nil
    CancelCDEndTimer(spellID)
end

local function CancelAllCDEndTimers()
    for _, timer in pairs(cdEndTimers) do
        timer:Cancel()
    end
    wipe(cdEndTimers)
    for _, timer in pairs(itemEndTimers) do
        timer:Cancel()
    end
    wipe(itemEndTimers)
    wipe(itemExpectedEnd)
    wipe(cdEstimatedEnd)
end

local cdPollTicker
local CheckCDWatchList

local QueueCDCheck = BUI.Dispatcher.New(function() CheckCDWatchList() end, 'CDM.CDWatch')

local function UpdateCDPollTicker()
    local needed = false
    for spellID, active in pairs(cdWatchedSpells) do
        if active and not cdExpectedEnd[spellID] then needed = true; break end
    end
    if not needed then
        for itemID, active in pairs(cdWatchedItems) do
            if active and not itemExpectedEnd[itemID] then needed = true; break end
        end
    end
    if needed and not cdPollTicker then
        cdPollTicker = BUI.Prof.NewTicker('CDM.Events', 0.5, BUI.Prof.Wrap('tick#CDWatchPoll', function() CheckCDWatchList() end))
    elseif not needed and cdPollTicker then
        cdPollTicker:Cancel()
        cdPollTicker = nil
    end
end

local function MarkWatcherViewersDirty(id)
    local viewers = cdWatchedViewers[id]
    if not viewers then return end
    for viewerKey in pairs(viewers) do
        CDM.MarkLayoutDirty(viewerKey)
    end
end

local IsSpellEngagedRef

local function OnCDEndReached(spellID)
    cdEndTimers[spellID] = nil
    if not cdExpectedEnd[spellID] then return end
    cdExpectedEnd[spellID] = nil
    cdEstimatedEnd[spellID] = nil
    local wasActive = cdWatchedSpells[spellID]
    if wasActive == nil then return end
    local engaged = IsSpellEngagedRef and IsSpellEngagedRef(spellID) or false
    if engaged ~= wasActive then
        cdWatchedSpells[spellID] = engaged
        MarkWatcherViewersDirty(spellID)
    end
    UpdateCDPollTicker()
end

local ITEM_CD_THRESHOLD = 1.5
local CD_END_GRACE = 0.1

local parseKindCache = {}
local parseNumCache = {}

local function ParseEntry(id)
    local cached = parseKindCache[id]
    if cached ~= nil then
        if cached == false then return nil, nil end
        return cached, parseNumCache[id]
    end

    if type(id) == 'number' then
        parseKindCache[id] = 'spell'
        parseNumCache[id] = id
        return 'spell', id
    end

    local idString = tostring(id)
    local trinketSlot = idString:match('^trinket:(%d)$')
    if trinketSlot then
        parseKindCache[id] = 'trinket-slot'
        parseNumCache[id] = tonumber(trinketSlot)
        return 'trinket-slot', parseNumCache[id]
    end
    local racialSlot = idString:match('^racial:(%d)$')
    if racialSlot then
        parseKindCache[id] = 'racial-slot'
        parseNumCache[id] = tonumber(racialSlot)
        return 'racial-slot', parseNumCache[id]
    end
    local numericID = tonumber(idString:match('(%d+)'))
    if not numericID then
        parseKindCache[id] = false
        return nil, nil
    end
    local kind = idString:find('^custom:') and 'custom' or 'spell'
    parseKindCache[id] = kind
    parseNumCache[id] = numericID
    return kind, numericID
end

local function ClassifyWatchEntry(id)
    local kind, numericID = ParseEntry(id)
    if not kind then return nil end

    if kind == 'spell' then return 'spell', numericID end
    if kind == 'trinket-slot' then
        local itemID = BUI.IconEngine.ResolveTrinketSlot(numericID)
        if itemID then return 'item', itemID end
        return nil
    end
    if kind == 'racial-slot' then
        local spellID = BUI.IconEngine.ResolveRacialSlot(numericID)
        if spellID then return 'spell', spellID end
        return nil
    end
    if kind == 'custom' then
        if IsPlayerSpell(numericID) or IsSpellKnown(numericID) then return 'spell', numericID end
        if C_Item.GetItemInfoInstant(numericID) then return 'item', numericID end
        return 'spell', numericID
    end
    return nil
end

local IsItemCDActive

local function IsSpellEngaged(spellID)
    if BUI.Tools.IsChargeSpell(spellID) then
        local chargeInfo = C_Spell.GetSpellCharges(spellID)
        local current = chargeInfo and BUI.Tools.SafeNum(chargeInfo.currentCharges)
        if current then return current == 0 end

        local icon = CDM.FindIconForSpell(spellID, true)
        if icon then
            local fromCharges = icon.wasSetFromCharges
            if fromCharges ~= nil and not issecretvalue(fromCharges) then
                if fromCharges then return false end
                local desaturated = icon.cooldownDesaturated
                if desaturated ~= nil and not issecretvalue(desaturated) then
                    return desaturated == true
                end
                local actual = icon.isOnActualCooldown
                if actual ~= nil and not issecretvalue(actual) then
                    return actual == true
                end
            end
        end

        return BUI.Tools.IsSpellOnCooldown(spellID) == true
    end
    if (BUI.Tools.GetAuraStacks('player', spellID) or 0) > 0 then return true end
    local cdInfo = GetCooldownCached(spellID)
    local rawActive = cdInfo and cdInfo.isActive
    local rawOnGCD = cdInfo and cdInfo.isOnGCD
    if not cdInfo or issecretvalue(rawActive) or issecretvalue(rawOnGCD) then
        local durationObject = C_Spell.GetSpellCooldownDuration(spellID)
        if durationObject and durationObject.EvaluateRemainingDuration then
            return (durationObject:EvaluateRemainingDuration(BUI.Tools.GCDFilterCurve, 0) or 0) > 0.5
        end
        return false
    end
    return rawActive and not rawOnGCD or false
end

IsSpellEngagedRef = IsSpellEngaged

local function RebuildCDWatchList()
    wipe(cdWatchedSpells)
    wipe(cdWatchedItems)
    wipe(cdWatchedViewers)
    wipe(cdAltToWatched)
    cdAltConfigID = nil
    wipe(cdExpectedEnd)
    CancelAllCDEndTimers()
    local db = BUI.GetDB()
    local any = false
    for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[viewerIndex]
        if key ~= 'buffs' then
            local config = db.cdm[key]
            if config then
                local showOnlyEntries = CDM.GetShowOnlyOnCD(config)
                for id in pairs(showOnlyEntries) do
                    local kind, numericID = ClassifyWatchEntry(id)
                    if numericID then
                        if kind == 'item' then
                            cdWatchedItems[numericID] = IsItemCDActive(numericID)
                        else
                            cdWatchedSpells[numericID] = IsSpellEngaged(numericID)
                        end
                        local viewers = cdWatchedViewers[numericID]
                        if not viewers then viewers = {}; cdWatchedViewers[numericID] = viewers end
                        viewers[key] = true
                        any = true
                    end
                end
            end
        end
    end
    UpdateCDPollTicker()
    return any
end

IsItemCDActive = function(itemID)
    local start, duration = C_Container.GetItemCooldown(itemID)
    if not start or not duration or duration < ITEM_CD_THRESHOLD then return false end
    return (start + duration) > GetTime()
end

local function RefreshCDExpectation(spellID)
    if BUI.Tools.IsChargeSpell(spellID) then return end
    local cdInfo = GetCooldownCached(spellID)
    if not cdInfo or issecretvalue(cdInfo.startTime) or issecretvalue(cdInfo.duration) then return end
    local startTime, duration = cdInfo.startTime, cdInfo.duration
    if not startTime or not duration or duration <= 1.5 then return end
    local endTime = startTime + duration
    local now = GetTime()
    if endTime <= now or cdExpectedEnd[spellID] == endTime then return end
    cdExpectedEnd[spellID] = endTime
    cdEstimatedEnd[spellID] = nil
    CancelCDEndTimer(spellID)
    cdEndTimers[spellID] = BUI.Prof.NewTimer('CDM.Events', endTime - now + CD_END_GRACE, function() OnCDEndReached(spellID) end)
end

CheckCDWatchList = function()
    local now = GetTime()
    local anyDirty = false
    for spellID, wasActive in pairs(cdWatchedSpells) do
        local isActive
        local expectedEnd = cdExpectedEnd[spellID]
        if expectedEnd and now < expectedEnd and not cdEstimatedEnd[spellID] then
            isActive = true
            RefreshCDExpectation(spellID)
        else
            isActive = IsSpellEngaged(spellID)
            if expectedEnd and (not isActive or now >= expectedEnd) then
                ClearCDExpectation(spellID)
            end
            if isActive then RefreshCDExpectation(spellID) end
        end
        if isActive ~= wasActive then
            cdWatchedSpells[spellID] = isActive
            local viewers = cdWatchedViewers[spellID]
            if viewers then
                for viewerKey in pairs(viewers) do
                    cdDirtyViewers[viewerKey] = true
                    anyDirty = true
                end
            end
        end
    end
    for itemID, wasActive in pairs(cdWatchedItems) do
        local isActive = IsItemCDActive(itemID)
        if isActive then
            local start, duration = C_Container.GetItemCooldown(itemID)
            local endTime = start and duration and (start + duration)
            if endTime and endTime > now and itemExpectedEnd[itemID] ~= endTime then
                itemExpectedEnd[itemID] = endTime
                if itemEndTimers[itemID] then itemEndTimers[itemID]:Cancel() end
                itemEndTimers[itemID] = BUI.Prof.NewTimer('CDM.Events', endTime - now + 0.1, function()
                    itemEndTimers[itemID] = nil
                    itemExpectedEnd[itemID] = nil
                    QueueCDCheck()
                end)
            end
        elseif itemExpectedEnd[itemID] then
            itemExpectedEnd[itemID] = nil
            if itemEndTimers[itemID] then itemEndTimers[itemID]:Cancel(); itemEndTimers[itemID] = nil end
        end
        if isActive ~= wasActive then
            cdWatchedItems[itemID] = isActive
            local viewers = cdWatchedViewers[itemID]
            if viewers then
                for viewerKey in pairs(viewers) do
                    cdDirtyViewers[viewerKey] = true
                    anyDirty = true
                end
            end
        end
    end
    if anyDirty then
        for viewerKey in pairs(cdDirtyViewers) do
            CDM.MarkLayoutDirty(viewerKey)
            cdDirtyViewers[viewerKey] = nil
        end
    end
    UpdateCDPollTicker()
end

local function MarkWatchedSpellActive(targetID, castSpellID)
    if not targetID or cdWatchedSpells[targetID] == nil then return end
    local now = GetTime()
    if BUI.Tools.IsChargeSpell(castSpellID or targetID) then
        CheckCDWatchList()
        local chargeInfo = C_Spell.GetSpellCharges(castSpellID or targetID)
        local start = chargeInfo and BUI.Tools.SafeNum(chargeInfo.cooldownStartTime)
        local duration = chargeInfo and BUI.Tools.SafeNum(chargeInfo.cooldownDuration)
        if start and duration and duration > 0 and (start + duration) > now then
            cdExpectedEnd[targetID] = start + duration
            cdEstimatedEnd[targetID] = nil
            CancelCDEndTimer(targetID)
            cdEndTimers[targetID] = BUI.Prof.NewTimer('CDM.Events', start + duration - now + CD_END_GRACE, function() OnCDEndReached(targetID) end)
        end
        return
    end
    local endTime, estimated

    local cdInfo = C_Spell.GetSpellCooldown(castSpellID or targetID)
    if cdInfo and not issecretvalue(cdInfo.startTime) and not issecretvalue(cdInfo.duration)
       and cdInfo.startTime and cdInfo.duration and cdInfo.duration > 1.5 then
        endTime = cdInfo.startTime + cdInfo.duration
    else
        local baseCDMs = GetSpellBaseCooldown(castSpellID or targetID)
        if baseCDMs and baseCDMs > 1500 then endTime = now + (baseCDMs / 1000); estimated = true end
    end
    if endTime and endTime > now then
        cdExpectedEnd[targetID] = endTime
        cdEstimatedEnd[targetID] = estimated
        CancelCDEndTimer(targetID)
        cdEndTimers[targetID] = BUI.Prof.NewTimer('CDM.Events', endTime - now + CD_END_GRACE, function() OnCDEndReached(targetID) end)
    end
    if cdWatchedSpells[targetID] == true then return end
    cdWatchedSpells[targetID] = true
    MarkWatcherViewersDirty(targetID)
    UpdateCDPollTicker()
end

local function ActiveTalentConfigID()
    return C_ClassTalents.GetActiveConfigID()
end

local function BuildCDAltIndex()
    wipe(cdAltToWatched)
    cdAltConfigID = nil
    local GetChoiceAlternatives = BUI.Tools.GetChoiceAlternatives
    local configID = ActiveTalentConfigID()
    if not configID then return end
    for watchedID in pairs(cdWatchedSpells) do
        local alternatives = GetChoiceAlternatives(watchedID)
        if alternatives then
            for _, alternative in ipairs(alternatives) do
                local altID = alternative.spellID
                if altID then cdAltToWatched[altID] = watchedID end
            end
        end
    end
    cdAltConfigID = configID
end

local function OnPlayerCastSucceeded(_, unit, _, spellID)
    if unit ~= "player" or not spellID then return end
    if cdWatchedSpells[spellID] ~= nil then
        MarkWatchedSpellActive(spellID, spellID)
        return
    end
    local configID = ActiveTalentConfigID()
    if configID and cdAltConfigID ~= configID then BuildCDAltIndex() end
    local watchedID = cdAltToWatched[spellID]
    if watchedID then MarkWatchedSpellActive(watchedID, spellID) end
end

function CDM.UpdateShowOnlyOnCDWatcher()
    local needed = RebuildCDWatchList()
    if needed and not cdLayoutRegistered then
        cdLayoutRegistered = true
        BUI.Events:Register("SPELL_UPDATE_COOLDOWN", "CDM.ShowOnlyOnCD", QueueCDCheck)
        BUI.Events:Register("SPELL_UPDATE_CHARGES", "CDM.ShowOnlyOnCDCharges", QueueCDCheck)
        BUI.Events:Register("BAG_UPDATE_COOLDOWN", "CDM.ShowOnlyOnCDBag", QueueCDCheck)
        BUI.Events:RegisterUnit("UNIT_SPELLCAST_SUCCEEDED", "player", "CDM.ShowOnlyOnCDCast", OnPlayerCastSucceeded)
    elseif not needed and cdLayoutRegistered then
        cdLayoutRegistered = false
        BUI.Events:Unregister("SPELL_UPDATE_COOLDOWN", "CDM.ShowOnlyOnCD")
        BUI.Events:Unregister("SPELL_UPDATE_CHARGES", "CDM.ShowOnlyOnCDCharges")
        BUI.Events:Unregister("BAG_UPDATE_COOLDOWN", "CDM.ShowOnlyOnCDBag")
        BUI.Events:Unregister("UNIT_SPELLCAST_SUCCEEDED", "CDM.ShowOnlyOnCDCast")
    end
    if needed then BuildCDAltIndex() end
end

function CDM.IsShowOnlyOnCDActive(id)
    return cdWatchedSpells[id] or cdWatchedItems[id] or false
end

function CDM.OnIconCooldownDone(icon)
    if not cdLayoutRegistered or not icon then return end
    local frameData = CDM.FrameData[icon]
    local id = CDM.GetStableSpellID(icon)
    if id == nil and frameData then id = frameData.knownBaseID or frameData.knownOverrideID end
    local watched = id
    if watched ~= nil and cdWatchedSpells[watched] == nil then watched = cdAltToWatched[watched] end
    if id == nil then
        for _, timer in pairs(cdEndTimers) do timer:Cancel() end
        wipe(cdEndTimers)
        wipe(cdExpectedEnd)
        wipe(cdEstimatedEnd)
    elseif watched ~= nil and cdWatchedSpells[watched] ~= nil then
        ClearCDExpectation(watched)
    end
    QueueCDCheck()
end

function CDM.OnCooldownWidgetDone(cooldown)
    local icon = cooldown and cooldown:GetParent()
    if icon then CDM.OnIconCooldownDone(icon) end
end

local function ForEachHideWhenZeroViewer(callback)
    local db = BUI.GetDB()
    local any = false
    for key in pairs(CDM.VIEWERS) do
        if key ~= 'buffs' then
            local config = db.cdm[key]
            local hideWhenZeroEntries = config and CDM.GetHideWhenZero(config)
            if hideWhenZeroEntries and next(hideWhenZeroEntries) then
                any = true
                if callback then callback(key) end
            end
        end
    end
    return any
end

local function OnHideWhenZeroEvent()
    ForEachHideWhenZeroViewer(function(key) CDM.MarkLayoutDirty(key) end)
end

local hideWhenZeroRegistered = false
function CDM.UpdateHideWhenZeroWatcher()
    local needed = ForEachHideWhenZeroViewer(nil)
    if needed and not hideWhenZeroRegistered then
        hideWhenZeroRegistered = true
        BUI.Events:Register("SPELL_UPDATE_CHARGES", "CDM.HideWhenZero", OnHideWhenZeroEvent)
        BUI.Events:Register("BAG_UPDATE_DELAYED", "CDM.HideWhenZeroBag", OnHideWhenZeroEvent)
    elseif not needed and hideWhenZeroRegistered then
        hideWhenZeroRegistered = false
        BUI.Events:Unregister("SPELL_UPDATE_CHARGES", "CDM.HideWhenZero")
        BUI.Events:Unregister("BAG_UPDATE_DELAYED", "CDM.HideWhenZeroBag")
    end
end

local layoutRefreshing = false
local layoutRefreshPending = false
local layoutHooksDone = false
local RequestLayoutRefresh

local function DoLayoutRefresh()
    layoutRefreshing = true
    CDM.RefreshAll(true)
    BUI.Prof.After('CDM.Events', 0.2, function()
        layoutRefreshing = false
        if layoutRefreshPending then
            layoutRefreshPending = false
            RequestLayoutRefresh()
        end
    end)
end

local lastActiveLayout

RequestLayoutRefresh = function(force)
    if layoutRefreshing then layoutRefreshPending = true; return end
    if InCombatLockdown() then layoutRefreshPending = true; return end
    local managerFrame = _G.EditModeManagerFrame
    if managerFrame and managerFrame:IsShown() then layoutRefreshPending = true; return end
    if not force then
        local layouts = C_EditMode.GetLayouts()
        local active = layouts and layouts.activeLayout
        if active ~= nil then
            if active == lastActiveLayout then return end
            lastActiveLayout = active
        end
    end
    layoutRefreshPending = false
    BUI.Prof.After('CDM.Events', 0, DoLayoutRefresh)
end

local function FlushPendingLayoutRefresh()
    if layoutRefreshPending then
        layoutRefreshPending = false
        RequestLayoutRefresh(true)
    end
end

function CDM.RegisterEvents()
    BUI.Events:OnTalentBurst("CDM", OnTalentBurst)
    BUI.Events:Register("COOLDOWN_VIEWER_DATA_LOADED", "CDM", OnCooldownViewerDataLoaded)
    BUI.Events:Register("EDIT_MODE_LAYOUTS_UPDATED", "CDM.Layout", function() RequestLayoutRefresh() end)
    BUI.Events:Register("PLAYER_REGEN_ENABLED", "CDM.LayoutPending", function() BUI.Events:AfterCombatSettled(FlushPendingLayoutRefresh, "CDM.LayoutPending") end)
    if not layoutHooksDone and _G.EditModeManagerFrame then
        layoutHooksDone = true
        HookScript(_G.EditModeManagerFrame, "OnHide", FlushPendingLayoutRefresh)
    end
end
