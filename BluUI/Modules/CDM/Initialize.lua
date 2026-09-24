local _, BUI = ...

local _G = _G

local CDM = BUI.CDM
local Pixel = BUI.Pixel
function CDM.Initialize()
    if CDM.state.initialized then return end
    CDM.state.initialized = true
    CDM.state.settling = true

    CDM.MigrateGlowType()
    CDM.InvalidateSkinCache()

    local db = BUI.GetDB()
    local function StripAutoSlots(list)
        if type(list) ~= "table" then return end
        for slotIndex = #list, 1, -1 do
            local entry = list[slotIndex]
            if type(entry) == "string" and (entry:match("^trinket:%d$") or entry:match("^racial:%d$")) then
                table.remove(list, slotIndex)
            end
        end
    end
    StripAutoSlots(db.cdm.essential.customSpells)
    StripAutoSlots(db.cdm.utility.customSpells)

    for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[viewerIndex]
        CDM.CreateAnchor(key)
        CDM.ApplyAnchorPosition(key)
    end

    CDM.RegisterEvents()
    CDM.CreateUpdateFrame()

    local initialHookDone = {}
    local retryFrame

    local function FinishInit()
        CDM.LayoutAllViewers()
        CDM.state.initComplete = true
        CDM.ClearDirty()
        CDM.Custom.Refresh()
        CDM.NotifyDependents()
        CDM.UpdateShowOnlyOnCDWatcher()
        CDM.UpdateHideWhenZeroWatcher()
        CDM.NotifyUnitFrames()
        C_Timer.After(0, function()
            CDM.state.settling = nil
            CDM.MarkAllDirty()
        end)
    end

    local function TryHookAll()
        local allEnabledHooked = true
        local db = BUI.GetDB()

        for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
            local key = CDM.VIEWER_KEYS[viewerIndex]
            local name = CDM.VIEWERS[key]
            local viewer = _G[name]

            local settings = db.cdm[key]
            local isEnabled = settings and settings.enabled

            if viewer then
                if isEnabled then
                    if not initialHookDone[key] then
                        initialHookDone[key] = true
                        CDM.HookViewer(viewer, key)
                        CDM.ApplyAnchorPosition(key)
                        CDM.SaveToEditModeLayout(key)
                        CDM.ApplyIconPositions(key)
                        BUI.Anchor.OnAnchorSizeChanged()
                    end
                else
                    CDM.RestoreViewer(viewer, key)
                end
            else
                if isEnabled then allEnabledHooked = false end
            end
        end

        if allEnabledHooked and retryFrame then
            retryFrame:UnregisterAllEvents()
            retryFrame:SetScript("OnEvent", nil)
            retryFrame = nil
        end

        return allEnabledHooked
    end

    if TryHookAll() then
        FinishInit()
    else
        retryFrame = CreateFrame("Frame")
        retryFrame:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")
        retryFrame:SetScript("OnEvent", function(self, event)
            if TryHookAll() then FinishInit() end
        end)
    end

    if EditModeManagerFrame then
        local function MarkDirtySoon()
            C_Timer.After(0, CDM.MarkAllDirty)
        end
        EditModeManagerFrame:HookScript("OnShow", MarkDirtySoon)
        EditModeManagerFrame:HookScript("OnHide", MarkDirtySoon)
    end

    CDM.SetupGlowHooks()
    CDM.RefreshProcMsgWatcher()
    CDM.InitAssistHighlight()
    CDM.PressHighlight.Initialize()
    CDM.SetupBuffCentering()
    CDM.InitBuffBarSkin()
    CDM.EditModeLock.Initialize()

    BUI.Anchor.RegisterCallback("CDM_viewer_reanchor", function()
        local db = BUI.GetDB()
        for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
            local key = CDM.VIEWER_KEYS[viewerIndex]
            local settings = db.cdm[key]
            if settings and settings.anchorFrame and settings.anchorFrame ~= "" then
                CDM.ApplyAnchorPosition(key)
                if key == "buffs" then
                    CDM.CenterBuffsNow(true)
                end
            end
        end
    end)

    Pixel.OnScaleChange("CDM", function()
        CDM.InvalidateSkinCache()
        CDM.UpdateAllPixelValues()
        CDM.MarkAllDirty()
        for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
            CDM.Keybinds.StyleViewer(CDM.VIEWER_KEYS[viewerIndex])
        end
    end)

    CDM.Detached.UpdateModifierWatcher()
    CDM.SetupBlizzardOverlay()

    BUI.Visibility.Register("CDM", function(instant)
        CDM.UpdateOpacity(instant)
    end)
end
