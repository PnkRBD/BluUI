local _, BUI = ...

local _G = _G

local CDM = BUI.CDM
local Pixel = BUI.Pixel
function CDM.Initialize()
    if CDM.state.initialized then return end
    CDM.state.initialized = true
    CDM.state.settling = true

    CDM.InvalidateSkinCache()

    local db = BUI.GetDB()
    for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
        CDM.CreateAnchor(CDM.VIEWER_KEYS[viewerIndex])
    end

    CDM.RegisterEvents()

    for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[viewerIndex]
        local viewer = _G[CDM.VIEWERS[key]]
        if db.cdm[key].enabled then
            CDM.HookViewer(viewer, key)
            CDM.SaveToEditModeLayout(key)
        else
            CDM.RestoreViewer(viewer, key)
        end
    end

    CDM.LayoutAllViewers()
    CDM.state.initComplete = true
    CDM.ClearDirty()
    CDM.Custom.Refresh()
    CDM.NotifyDependents()
    CDM.UpdateShowOnlyOnCDWatcher()
    CDM.UpdateHideWhenZeroWatcher()
    CDM.NotifyAnchoredFrames()
    C_Timer.After(0, function()
        CDM.state.settling = nil
        CDM.MarkAllDirty()
    end)

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
            if db.cdm[key].anchorFrame ~= "" then
                CDM.ApplyAnchorPosition(key)
                if key == "buffs" then
                    CDM.CenterBuffsNow(true)
                end
            end
        end
    end)

    Pixel.OnScaleChange("CDM", function()
        CDM.InvalidateSkinCache()
        CDM.MarkAllDirty()
        for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
            CDM.Keybinds.StyleViewer(CDM.VIEWER_KEYS[viewerIndex])
        end
    end)

    CDM.Detached.UpdateModifierWatcher()
    CDM.SetupBlizzardOverlay()

    BUI.Visibility.Register("CDM", CDM.UpdateOpacity)
end
