local _, BUI = ...

local wipe = wipe

local CreateFrame = CreateFrame

local CDM = BUI.CDM

local DirtyViewers = {}

local function FlushDirty(self)
    self:Hide()

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

local UpdateFrame = CreateFrame("Frame", "BUI_CDMDirtyFlush")
UpdateFrame:SetScript("OnUpdate", FlushDirty)
UpdateFrame:Hide()

function CDM.MarkDirty(key)
    DirtyViewers[key] = true
    CDM.InvalidateIconCache(key)
    if not CDM.state.settling then
        UpdateFrame:Show()
    elseif key == 'buffs' then
        CDM.MarkBuffCenterDirty()
    end
end

function CDM.MarkLayoutDirty(key)
    if key == 'buffs' then return CDM.MarkDirty(key) end
    DirtyViewers[key] = true
    if not CDM.state.settling then UpdateFrame:Show() end
end

function CDM.MarkAllDirty()
    for keyIndex = 1, CDM.VIEWER_KEYS_COUNT do
        DirtyViewers[CDM.VIEWER_KEYS[keyIndex]] = true
    end
    CDM.InvalidateIconCache()
    if not CDM.state.settling then
        UpdateFrame:Show()
    else
        CDM.MarkBuffCenterDirty()
    end
end

function CDM.ClearDirty()
    wipe(DirtyViewers)
    UpdateFrame:Hide()
end

function CDM.SetUpdatePending(pending)
    if pending then CDM.MarkAllDirty() else CDM.ClearDirty() end
end
