local _, BUI = ...

local Hook = BUI.Profiler.Hooker('BuffTracking.CDMScan')

local GetCooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo
local GetCategorySet  = C_CooldownViewer.GetCooldownViewerCategorySet
local issecretvalue = issecretvalue
local next, pairs, ipairs, wipe = next, pairs, ipairs, wipe

BUI.BuffTracking = {}

local CDM_CATEGORIES = {
    Enum.CooldownViewerCategory.Essential,
    Enum.CooldownViewerCategory.Utility,
    Enum.CooldownViewerCategory.TrackedBuff,
    Enum.CooldownViewerCategory.TrackedBar,
}

local CDM_FRAME_NAMES = { 'BuffBarCooldownViewer', 'BuffIconCooldownViewer' }

local framesByCooldownID = {}
local frameMapStale = true
local viewersHooked = false
local scannerCount = 0

local function MarkFrameMapStale()
    frameMapStale = true
end

local function HookCDMViewers()
    if viewersHooked then return end
    viewersHooked = true
    for _, name in ipairs(CDM_FRAME_NAMES) do
        local viewer = _G[name]
        Hook(viewer, 'RefreshLayout', MarkFrameMapStale)
        Hook(viewer, 'RefreshData', MarkFrameMapStale)
    end
end

local function RebuildFrameMap()
    wipe(framesByCooldownID)
    for _, name in ipairs(CDM_FRAME_NAMES) do
        for itemFrame in _G[name].itemFramePool:EnumerateActive() do
            local cooldownID = itemFrame.cooldownID
            if cooldownID and not issecretvalue(cooldownID) then
                framesByCooldownID[cooldownID] = itemFrame
            end
        end
    end
    frameMapStale = false
end

local function CDMFrameForCooldownID(targetID)
    HookCDMViewers()
    if frameMapStale then RebuildFrameMap() end
    return framesByCooldownID[targetID]
end

function BUI.BuffTracking.NewCDMScan(trackedSpellIDs, onRebuilt)
    local scanner = {}
    local cache = {}
    local pendingBuild = false

    local function MatchTrackedSpell(info)
        if not info then return nil end
        if info.spellID and trackedSpellIDs[info.spellID] then return info.spellID end
        if info.overrideSpellID and trackedSpellIDs[info.overrideSpellID] then
            return info.overrideSpellID
        end
        for _, linkedID in ipairs(info.linkedSpellIDs) do
            if trackedSpellIDs[linkedID] then return linkedID end
        end
        return nil
    end

    function scanner.Build()
        if BUI.Tools.ShouldAurasBeSecret() then
            pendingBuild = true
            return
        end
        pendingBuild = false
        wipe(cache)

        HookCDMViewers()
        RebuildFrameMap()
        for cooldownID, itemFrame in pairs(framesByCooldownID) do
            local matched = MatchTrackedSpell(GetCooldownInfo(cooldownID))
            if matched then
                cache[matched] = { cdmFrame = itemFrame, cooldownID = cooldownID }
            end
        end

        for categoryIndex = 1, #CDM_CATEGORIES do
            local cooldownIDs = GetCategorySet(CDM_CATEGORIES[categoryIndex], true)
            for _, cooldownID in ipairs(cooldownIDs) do
                local matched = MatchTrackedSpell(GetCooldownInfo(cooldownID))
                if matched and not cache[matched] then
                    cache[matched] = { cooldownID = cooldownID }
                end
            end
        end

        if onRebuilt then onRebuilt() end
    end

    scannerCount = scannerCount + 1
    local key = 'CDMScan' .. scannerCount
    scanner.ScheduleRebuild = BUI.Dispatcher.New(scanner.Build, key .. '.Build')

    function scanner.GetEntry(spellID) return cache[spellID] end

    function scanner.FrameHasAura(data)
        local frame = data.cdmFrame
        if frame then
            local currentCooldownID = frame.cooldownID
            if not issecretvalue(currentCooldownID) and currentCooldownID ~= data.cooldownID then
                frame = nil
                data.cdmFrame = nil
                MarkFrameMapStale()
            end
        end
        if not frame then
            frame = CDMFrameForCooldownID(data.cooldownID)
            data.cdmFrame = frame
            if not frame then return false end
        end
        local auraInstanceID = frame.auraInstanceID
        if not auraInstanceID then return false end
        return issecretvalue(auraInstanceID) or auraInstanceID > 0
    end

    BUI.Events:Register('COOLDOWN_VIEWER_DATA_LOADED', key, scanner.ScheduleRebuild)
    BUI.Events:Register('COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED', key, scanner.ScheduleRebuild)
    BUI.Events:Register('PLAYER_TALENT_UPDATE', key, scanner.ScheduleRebuild)
    BUI.Events:Register('TRAIT_CONFIG_UPDATED', key, scanner.ScheduleRebuild)
    BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', key, function(_, unit)
        if unit == 'player' then scanner.ScheduleRebuild() end
    end)
    BUI.Events:Register('PLAYER_REGEN_DISABLED', key, function()
        if not next(cache) then scanner.Build() end
    end)
    BUI.Events:Register('PLAYER_REGEN_ENABLED', key, function()
        if pendingBuild or not next(cache) then scanner.ScheduleRebuild() end
    end)
    EventRegistry:RegisterCallback('CooldownViewerSettings.OnDataChanged', BUI.Profiler.Timed('BuffTracking.CDMScan NewCDMScan callback CooldownViewerSettings.OnDataChanged', scanner.ScheduleRebuild), scanner)

    return scanner
end
