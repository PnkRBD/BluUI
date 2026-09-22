local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('CDM.EditModeLock')

local hooksecurefunc = BUI.Prof.MakeHooker('editmodelock')
local CDM = BUI.CDM
local EditModeLock = {}
CDM.EditModeLock = EditModeLock

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local pairs, ipairs, type = pairs, ipairs, type

local CDM_SYSTEM_FRAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
}
local LOCK_TEXT_TIMEOUT = 2.5

local Pixel = BUI.Pixel
local lockState = setmetatable({}, { __mode = "k" })
local hookedSystemFrames = setmetatable({}, { __mode = "k" })
local dialogHooked = false
local isInEditMode = false
local lockNoticePrinted = false

local function IsCDMSystemFrame(frame)
    if not frame then return false end
    return frame.system == Enum.EditModeSystem.CooldownViewer
end

local function OverlayTarget(systemFrame)
    local viewerName = systemFrame:GetName()
    local db = BUI.GetDB()
    for key, name in pairs(CDM.VIEWERS) do
        if name == viewerName then
            local settings = db.cdm[key]
            local container = CDM.Anchors[key]
            if settings and settings.enabled and container then return container end
            return systemFrame
        end
    end
    return systemFrame
end

local function EnsureOverlay(systemFrame)
    local state = lockState[systemFrame]
    if state then
        local target = OverlayTarget(systemFrame)
        if state.target ~= target then
            state.target = target
            state.overlay:ClearAllPoints()
            state.overlay:SetAllPoints(target)
        end
        return state
    end
    local target = OverlayTarget(systemFrame)
    local overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetAllPoints(target)
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetFrameLevel(systemFrame:GetFrameLevel() + 10)
    local title = overlay:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(title, 18, BUI.C.FONT_PATH, "OUTLINE")
    title:SetPoint("CENTER")
    title:SetText("Move via |cffFD008B/bui|r > CDM")
    title:SetTextColor(1, 1, 1, 1)
    local notice = overlay:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(notice, 12, BUI.C.FONT_PATH, "OUTLINE")
    notice:SetPoint("TOP", title, "BOTTOM", 0, -Pixel.Scale(2))
    notice:SetText("Edit Mode controls disabled")
    notice:SetTextColor(1, 0.78, 0.18, 1)
    notice:Hide()
    overlay:Hide()
    state = { token = 0, overlay = overlay, notice = notice, target = target }
    lockState[systemFrame] = state
    return state
end

local function ShowOverlay(systemFrame)
    if not IsCDMSystemFrame(systemFrame) then return end
    EnsureOverlay(systemFrame).overlay:Show()
end

local function ShowLockText(systemFrame)
    if InCombatLockdown() or not IsCDMSystemFrame(systemFrame) then return end
    local state = EnsureOverlay(systemFrame)
    state.overlay:Show()
    state.notice:Show()
    state.token = state.token + 1
    local myToken = state.token
    BUI.Prof.After('CDM.EditModeLock', LOCK_TEXT_TIMEOUT, function()
        if state.token == myToken then state.notice:Hide() end
    end)
end

local function HideLockText(systemFrame)
    local state = systemFrame and lockState[systemFrame]
    if state then state.notice:Hide() end
end

local function HideOverlay(systemFrame)
    local state = systemFrame and lockState[systemFrame]
    if not state then return end
    state.token = state.token + 1
    state.notice:Hide()
    state.overlay:Hide()
end

local function PrintLockNoticeOnce()
    if lockNoticePrinted then return end
    lockNoticePrinted = true
    BUI.Print("CDM edit mode is locked. Use /bui > CDM.")
end

local function HookSettingsDialog()
    if dialogHooked then return end
    local dialog = _G.EditModeSystemSettingsDialog
    if not (dialog and dialog.AttachToSystemFrame) then return end
    dialogHooked = true

    hooksecurefunc(dialog, "AttachToSystemFrame", function(self, systemFrame)
        if not IsCDMSystemFrame(systemFrame) then return end
        self:Hide()
        ShowLockText(systemFrame)
        PrintLockNoticeOnce()
    end)
end

local function HookSystemFrame(name)
    local frame = _G[name]
    if not IsCDMSystemFrame(frame) then return end
    if hookedSystemFrames[frame] then return end
    hookedSystemFrames[frame] = true

    frame:SetMovable(false)
    if frame.Selection then
        SetScript(frame.Selection, "OnDragStart", nil)
        SetScript(frame.Selection, "OnDragStop", nil)
    end

    if frame.SelectSystem then
        hooksecurefunc(frame, "SelectSystem", function(systemFrame)
            if not isInEditMode then return end
            systemFrame:SetMovable(false)
            local dialog = _G.EditModeSystemSettingsDialog
            if dialog and dialog.attachedToSystem == systemFrame then
                dialog:Hide()
            end
            ShowLockText(systemFrame)
            PrintLockNoticeOnce()
        end)
    end

    if frame.HighlightSystem then
        hooksecurefunc(frame, "HighlightSystem", function(systemFrame)
            if not isInEditMode then return end
            ShowLockText(systemFrame)
        end)
    end

    if frame.ClearHighlight then
        hooksecurefunc(frame, "ClearHighlight", function(systemFrame)
            HideLockText(systemFrame)
        end)
    end
end

local function HookAllSystemFrames()
    for _, name in ipairs(CDM_SYSTEM_FRAMES) do
        HookSystemFrame(name)
    end
end

local function OnEditModeShow()
    isInEditMode = true
    HookSettingsDialog()
    HookAllSystemFrames()
    for _, name in ipairs(CDM_SYSTEM_FRAMES) do
        ShowOverlay(_G[name])
    end
end

local function OnEditModeHide()
    isInEditMode = false
    for _, name in ipairs(CDM_SYSTEM_FRAMES) do
        HideOverlay(_G[name])
    end
end

local function BuildDesiredSettings(systemIndex)
    local desired = {
        [Enum.EditModeCooldownViewerSetting.VisibleSetting] = Enum.CooldownViewerVisibleSetting.Always,
        [Enum.EditModeCooldownViewerSetting.ShowTimer]      = 1,
    }
    if systemIndex == Enum.EditModeCooldownViewerSystemIndices.BuffIcon
        or (Enum.EditModeCooldownViewerSystemIndices.BuffBar and
            systemIndex == Enum.EditModeCooldownViewerSystemIndices.BuffBar) then
        desired[Enum.EditModeCooldownViewerSetting.HideWhenInactive] = 1
    end
    return desired
end

local function MergePresetLayouts(layoutInfo)
    if type(layoutInfo) ~= "table" then return layoutInfo end
    if type(layoutInfo.layouts) ~= "table" then return layoutInfo end
    if type(layoutInfo.activeLayout) ~= "number" then return layoutInfo end

    local manager = EditModePresetLayoutManager
    if not (manager and manager.GetCopyOfPresetLayouts) then return layoutInfo end

    local presets = manager:GetCopyOfPresetLayouts()
    if type(presets) ~= "table" then return layoutInfo end

    local custom = layoutInfo.layouts
    local offset = #presets
    for layoutIndex = 1, #custom do
        presets[offset + layoutIndex] = custom[layoutIndex]
    end
    layoutInfo.layouts = presets
    return layoutInfo
end

local function FetchLayoutData()
    return MergePresetLayouts(C_EditMode.GetLayouts())
end

local function GetManagerActiveLayout()
    local managerFrame = EditModeManagerFrame
    if not managerFrame then return nil end
    local active = managerFrame.GetActiveLayoutInfo and managerFrame:GetActiveLayoutInfo()
    if type(active) == "table" then return active end
    local info = managerFrame.layoutInfo
    if type(info) == "table" and type(info.layouts) == "table"
        and type(info.activeLayout) == "number" then
        active = info.layouts[info.activeLayout]
        if type(active) == "table" then return active end
    end
    return nil
end

local function GetActiveLayout(layoutInfo)
    if type(layoutInfo) ~= "table" or type(layoutInfo.layouts) ~= "table" then return nil end
    local layouts = layoutInfo.layouts

    local managerActive = GetManagerActiveLayout()
    if type(managerActive) == "table" then
        local isPreset = managerActive.layoutType == Enum.EditModeLayoutType.Preset
        local nameMatch, nameMatchIndex
        for layoutIndex = 1, #layouts do
            local layout = layouts[layoutIndex]
            if type(layout) == "table" and type(layout.systems) == "table"
                and layout.layoutName == managerActive.layoutName then
                if layout.layoutType == managerActive.layoutType then
                    return layout, layoutIndex, isPreset
                end
                if not nameMatch and (isPreset or layout.layoutType ~= Enum.EditModeLayoutType.Preset) then
                    nameMatch, nameMatchIndex = layout, layoutIndex
                end
            end
        end
        if nameMatch then return nameMatch, nameMatchIndex, isPreset end
        return nil, nil, isPreset
    end

    local layoutIndex = layoutInfo.activeLayout
    if type(layoutIndex) ~= "number" then return nil end
    local active = layouts[layoutIndex]
    if type(active) ~= "table" or type(active.systems) ~= "table" then return nil end
    local isPreset = active.layoutType == Enum.EditModeLayoutType.Preset
    return active, layoutIndex, isPreset
end

local function FindSettingValue(settings, settingEnum)
    for settingIndex = 1, #settings do
        local info = settings[settingIndex]
        if info.setting == settingEnum then return info.value end
    end
end

local function WriteSetting(settings, settingEnum, desired)
    for settingIndex = 1, #settings do
        local info = settings[settingIndex]
        if info.setting == settingEnum then
            if info.value == desired then return false end
            info.value = desired
            return true
        end
    end
    settings[#settings + 1] = { setting = settingEnum, value = desired }
    return true
end

local function EnsureEditModeLoaded()
    if EditModePresetLayoutManager then return end
    C_AddOns.LoadAddOn("Blizzard_EditMode")
end

local function IsEditModeReady()
    return EditModeManagerFrame and EditModeManagerFrame.accountSettings ~= nil
end

function EditModeLock.GetCompliance()
    local result = { isCompliant = true, isReady = false, mismatches = {} }

    EnsureEditModeLoaded()
    if not IsEditModeReady() then return result end
    local active, activeIndex, isPreset = GetActiveLayout(FetchLayoutData())
    if not active then
        if isPreset then
            result.isReady = true
            result.isPreset = true
        end
        return result
    end

    result.isReady = true
    result.activeLayout = activeIndex
    result.isPreset = isPreset

    local cdSystem = Enum.EditModeSystem.CooldownViewer
    local seen = 0
    for _, systemInfo in ipairs(active.systems) do
        if systemInfo.system == cdSystem and type(systemInfo.settings) == "table" then
            seen = seen + 1
            local desired = BuildDesiredSettings(systemInfo.systemIndex)
            for settingEnum, wantedValue in pairs(desired) do
                local currentValue = FindSettingValue(systemInfo.settings, settingEnum)
                if currentValue ~= wantedValue then
                    result.isCompliant = false
                    result.mismatches[#result.mismatches + 1] = {
                        systemIndex = systemInfo.systemIndex,
                        setting = settingEnum,
                        current = currentValue,
                        desired = wantedValue,
                    }
                end
            end
        end
    end

    if seen == 0 then result.isReady = false end
    return result
end

function EditModeLock.ApplyRecommendedSettings()
    if InCombatLockdown() then return "in_combat" end

    EnsureEditModeLoaded()
    if not IsEditModeReady() then return "not_ready" end
    local info = FetchLayoutData()
    local active, _, isPreset = GetActiveLayout(info)
    if isPreset then return "preset" end
    if not active then return "not_ready" end

    local changed = false
    local cdSystem = Enum.EditModeSystem.CooldownViewer
    for _, systemInfo in ipairs(active.systems) do
        if systemInfo.system == cdSystem and type(systemInfo.settings) == "table" then
            local desired = BuildDesiredSettings(systemInfo.systemIndex)
            for settingEnum, wantedValue in pairs(desired) do
                if WriteSetting(systemInfo.settings, settingEnum, wantedValue) then
                    changed = true
                end
            end
        end
    end

    if not changed then return "noop" end

    C_EditMode.SaveLayouts(info)
    return "applied"
end

function EditModeLock.Initialize()
    if not EditModeManagerFrame then return end

    HookSettingsDialog()
    HookAllSystemFrames()

    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", function()
        HookSettingsDialog()
        HookAllSystemFrames()
    end)

    HookScript(EditModeManagerFrame, "OnShow", OnEditModeShow)
    HookScript(EditModeManagerFrame, "OnHide", OnEditModeHide)
    if EditModeManagerFrame:IsShown() then OnEditModeShow() end
end
