local _, BUI = ...
local SetScript = BUI.Prof.Scripts('CDM.DirtyTracking')

local wipe = wipe

local CreateFrame = CreateFrame

local CDM = BUI.CDM
local UpdateFrame = nil

local DirtyViewers = {}

function CDM.MarkDirty(key)
    DirtyViewers[key] = true
    CDM.InvalidateIconCache(key)
    if key == 'buffs' then CDM.MarkBuffCenterDirty() end
    if UpdateFrame and not CDM.state.settling then UpdateFrame:Show() end
end

function CDM.MarkLayoutDirty(key)
    if key == 'buffs' then return CDM.MarkDirty(key) end
    DirtyViewers[key] = true
    if UpdateFrame and not CDM.state.settling then UpdateFrame:Show() end
end

function CDM.MarkAllDirty()
    for keyIndex = 1, CDM.VIEWER_KEYS_COUNT do
        DirtyViewers[CDM.VIEWER_KEYS[keyIndex]] = true
    end
    CDM.InvalidateIconCache()
    CDM.MarkBuffCenterDirty()
    if UpdateFrame and not CDM.state.settling then UpdateFrame:Show() end
end

function CDM.ClearDirty()
    wipe(DirtyViewers)
    if UpdateFrame then UpdateFrame:Hide() end
end

local function FlushDirty()
    UpdateFrame:Hide()

    if CDM.state.settling then return end

    local profiler = BUI.Prof
    local profiling = profiler.active

    local buffsDirty = DirtyViewers['buffs']
    local anyDirty = false
    for keyIndex = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[keyIndex]
        if DirtyViewers[key] then
            anyDirty = true
            DirtyViewers[key] = nil
            if profiling then
                local startTime = debugprofilestop()
                CDM.ApplyIconPositions(key)
                profiler.Add(CDM.ProfKey('layout', key), debugprofilestop() - startTime)
            else
                CDM.ApplyIconPositions(key)
            end
        end
    end
    if anyDirty then
        if profiling then
            local startTime = debugprofilestop()
            CDM.NotifyDependents()
            profiler.Add(CDM.ProfKey('notifyDependents'), debugprofilestop() - startTime)
        else
            CDM.NotifyDependents()
        end
        if not buffsDirty then CDM.CenterBuffsNow() end
    end
end

function CDM.CreateUpdateFrame()
    if UpdateFrame then return end
    UpdateFrame = CreateFrame("Frame", "BUI_CDMDirtyFlush")
    SetScript(UpdateFrame, "OnUpdate", FlushDirty)
    UpdateFrame:Hide()
end

function CDM.SetUpdatePending(pending)
    if pending then CDM.MarkAllDirty() else CDM.ClearDirty() end
end
