local _, BUI = ...

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

local CDM_FRAME_NAMES = { 'BuffBarCooldownViewer', 'BuffIconCooldownViewer', 'CDMGroups_Buffs' }

local function GetFrameCooldownID(frame)
    return frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID)
end

local framesByCooldownID = {}
local frameMapStale = true
local hookedViewers = {}
local scannerCount = 0

local function MarkFrameMapStale()
    frameMapStale = true
end

local function HookCDMViewers()
    for _, name in ipairs(CDM_FRAME_NAMES) do
        local viewer = _G[name]
        if viewer and not hookedViewers[viewer] then
            hookedViewers[viewer] = true
            if viewer.OnAcquireItemFrame then
                hooksecurefunc(viewer, 'OnAcquireItemFrame', MarkFrameMapStale)
            end
            if viewer.RefreshLayout then
                hooksecurefunc(viewer, 'RefreshLayout', MarkFrameMapStale)
            end
        end
    end
end

local function RegisterFrame(frame)
    local cooldownID = GetFrameCooldownID(frame)
    if cooldownID and not issecretvalue(cooldownID) then
        framesByCooldownID[cooldownID] = frame
    end
end

local function RebuildFrameMap()
    wipe(framesByCooldownID)
    for _, name in ipairs(CDM_FRAME_NAMES) do
        local viewer = _G[name]
        if viewer then
            local pool = viewer.itemFramePool
            if pool and pool.EnumerateActive then
                for itemFrame in pool:EnumerateActive() do
                    RegisterFrame(itemFrame)
                end
            elseif viewer.GetChildren then
                local children = { viewer:GetChildren() }
                for childIndex = 1, #children do
                    RegisterFrame(children[childIndex])
                end
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

BUI.Events:RegisterUnit('UNIT_AURA', 'player', 'BuffTrackingCDMScan', MarkFrameMapStale)

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
        if info.linkedSpellIDs then
            for _, linkedID in ipairs(info.linkedSpellIDs) do
                if trackedSpellIDs[linkedID] then return linkedID end
            end
        end
        return nil
    end

    local function TryCache(frame)
        local cooldownID = GetFrameCooldownID(frame)
        if not cooldownID or cooldownID <= 0 then return end
        local matched = MatchTrackedSpell(GetCooldownInfo(cooldownID))
        if matched then
            cache[matched] = { cdmFrame = frame, cooldownID = cooldownID }
        end
    end

    function scanner.Build()
        if BUI.Tools.ShouldAurasBeSecret() then
            pendingBuild = true
            return
        end
        pendingBuild = false
        cache = {}

        HookCDMViewers()
        RebuildFrameMap()
        for _, itemFrame in pairs(framesByCooldownID) do
            TryCache(itemFrame)
        end

        for categoryIndex = 1, #CDM_CATEGORIES do
            local cooldownIDs = GetCategorySet(CDM_CATEGORIES[categoryIndex], true)
            if cooldownIDs then
                for _, cooldownID in ipairs(cooldownIDs) do
                    local matched = MatchTrackedSpell(GetCooldownInfo(cooldownID))
                    if matched and not cache[matched] then
                        cache[matched] = { cdmFrame = nil, cooldownID = cooldownID }
                    end
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
            local currentCooldownID = GetFrameCooldownID(frame)
            if not issecretvalue(currentCooldownID) and currentCooldownID ~= data.cooldownID then
                frame = nil
                data.cdmFrame = nil
                MarkFrameMapStale()
            end
        end
        if not frame and data.cooldownID then
            frame = CDMFrameForCooldownID(data.cooldownID)
            data.cdmFrame = frame
        end
        if not frame then return false, nil end
        local auraInstanceID = frame.auraInstanceID
        if not auraInstanceID then return false, nil end
        if issecretvalue(auraInstanceID) then
            return true, auraInstanceID
        end
        if type(auraInstanceID) == 'number' and auraInstanceID > 0 then
            return true, auraInstanceID
        end
        return false, nil
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
    EventRegistry:RegisterCallback('CooldownViewerSettings.OnDataChanged', scanner.ScheduleRebuild, scanner)

    return scanner
end
