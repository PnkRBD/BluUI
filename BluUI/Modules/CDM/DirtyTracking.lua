local _, BUI = ...

local wipe = wipe

local CreateFrame = CreateFrame

local CDM = BUI.CDM
local UpdateFrame = nil

local DirtyViewers = {}

function CDM.MarkDirty(key)
    DirtyViewers[key] = true
    CDM.InvalidateIconCache(key)
    if UpdateFrame and not CDM.state.settling then
        UpdateFrame:Show()
    elseif key == 'buffs' then
        CDM.MarkBuffCenterDirty()
    end
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
    if UpdateFrame and not CDM.state.settling then
        UpdateFrame:Show()
    else
        CDM.MarkBuffCenterDirty()
    end
end

function CDM.ClearDirty()
    wipe(DirtyViewers)
    if UpdateFrame then UpdateFrame:Hide() end
end

local function FlushDirty()
    UpdateFrame:Hide()

    if CDM.state.settling then return end

    local anyDirty = false
    for keyIndex = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[keyIndex]
        if DirtyViewers[key] then
            anyDirty = true
            DirtyViewers[key] = nil
            if not CDM.ApplyIconPositions(key) and key == 'buffs' then
                CDM.MarkBuffCenterDirty()
            end
        end
    end
    if anyDirty then
        CDM.NotifyDependents()
    end
end

function CDM.CreateUpdateFrame()
    if UpdateFrame then return end
    UpdateFrame = CreateFrame("Frame", "BUI_CDMDirtyFlush")
    UpdateFrame:SetScript("OnUpdate", BUI.Profiler.Wrap("CDM.DirtyTracking flush", FlushDirty))
    UpdateFrame:Hide()
end

function CDM.SetUpdatePending(pending)
    if pending then CDM.MarkAllDirty() else CDM.ClearDirty() end
end
