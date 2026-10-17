local _, BUI = ...

local Hook = BUI.Profiler.Hooker('CDM.EditModeLock')

local CDM = BUI.CDM
local EditModeLock = {}
CDM.EditModeLock = EditModeLock

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local pairs, ipairs = pairs, ipairs

local CDM_SYSTEM_FRAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
}
local BAR_VIEWER = "BuffBarCooldownViewer"
local LOCK_TEXT_TIMEOUT = 2.5
local COOLDOWN_SYSTEM = Enum.EditModeSystem.CooldownViewer
local ICON_SETTINGS = {
    [Enum.EditModeCooldownViewerSetting.VisibleSetting] = Enum.CooldownViewerVisibleSetting.Always,
    [Enum.EditModeCooldownViewerSetting.ShowTimer] = 1,
}
local BUFF_SETTINGS = {
    [Enum.EditModeCooldownViewerSetting.VisibleSetting] = Enum.CooldownViewerVisibleSetting.Always,
    [Enum.EditModeCooldownViewerSetting.ShowTimer] = 1,
    [Enum.EditModeCooldownViewerSetting.HideWhenInactive] = 1,
}
local BUFF_SYSTEMS = {
    [Enum.EditModeCooldownViewerSystemIndices.BuffIcon] = true,
    [Enum.EditModeCooldownViewerSystemIndices.BuffBar] = true,
}

local Pixel = BUI.Pixel
local lockState = setmetatable({}, { __mode = "k" })
local isInEditMode = false

local function BarsLocked()
    return BUI.GetDB().cdm.buffBars.skinEnabled == true
end

local function IsLocked(frame)
    if frame.system ~= COOLDOWN_SYSTEM then return false end
    return frame ~= _G[BAR_VIEWER] or BarsLocked()
end

local function OverlayTarget(systemFrame)
    local viewerName = systemFrame:GetName()
    local db = BUI.GetDB()
    for key, name in pairs(CDM.VIEWERS) do
        if name == viewerName then
            if db.cdm[key].enabled then return CDM.Anchors[key] end
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

local function ShowLockText(systemFrame)
    if InCombatLockdown() then return end
    local state = EnsureOverlay(systemFrame)
    state.overlay:Show()
    state.notice:Show()
    state.token = state.token + 1
    local myToken = state.token
    BUI.Profiler.After("CDM.EditModeLock lock text", LOCK_TEXT_TIMEOUT, function()
        if state.token == myToken then state.notice:Hide() end
    end)
end

local function HideLockText(systemFrame)
    local state = lockState[systemFrame]
    if state then state.notice:Hide() end
end

local function HideOverlay(state)
    state.token = state.token + 1
    state.notice:Hide()
    state.overlay:Hide()
end

local function OnDialogAttach(dialog, systemFrame)
    if not IsLocked(systemFrame) then return end
    dialog:Hide()
    ShowLockText(systemFrame)
end

local function OnSelectSystem(systemFrame)
    if isInEditMode and IsLocked(systemFrame) then ShowLockText(systemFrame) end
end

local function HookSystemFrame(frame)
    Hook(frame, "SelectSystem", OnSelectSystem)
    Hook(frame, "HighlightSystem", OnSelectSystem)
    Hook(frame, "ClearHighlight", HideLockText)
end

local function SyncBarsLock()
    local viewer = _G[BAR_VIEWER]
    local locked = BarsLocked()
    viewer.isLocked = locked or nil
    if not isInEditMode then return end
    local state = EnsureOverlay(viewer)
    if locked then state.overlay:Show() else HideOverlay(state) end
end
EditModeLock.SyncBarsLock = SyncBarsLock

local function OnEditModeShow()
    isInEditMode = true
    for _, name in ipairs(CDM_SYSTEM_FRAMES) do
        EnsureOverlay(_G[name]).overlay:Show()
    end
    SyncBarsLock()
end

local function OnEditModeHide()
    isInEditMode = false
    for _, state in pairs(lockState) do HideOverlay(state) end
end

local function MarkDirtySoon()
    BUI.Profiler.After("CDM.EditModeLock edit mode dirty", 0, CDM.MarkAllDirty)
end

local function OnManagerShow()
    MarkDirtySoon()
    OnEditModeShow()
end

local function OnManagerHide()
    CDM.FlushPendingLayoutRefresh()
    MarkDirtySoon()
    OnEditModeHide()
end

local function DesiredSettings(systemIndex)
    return BUFF_SYSTEMS[systemIndex] and BUFF_SETTINGS or ICON_SETTINGS
end

local function FetchLayoutData()
    local layoutInfo = C_EditMode.GetLayouts()
    local layouts = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    local offset = #layouts
    for layoutIndex, layout in ipairs(layoutInfo.layouts) do
        layouts[offset + layoutIndex] = layout
    end
    layoutInfo.layouts = layouts
    return layoutInfo
end

local function GetActiveLayout(layoutInfo)
    local active = layoutInfo.layouts[layoutInfo.activeLayout]
    return active, active.layoutType == Enum.EditModeLayoutType.Preset
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

local function IsEditModeReady()
    return EditModeManagerFrame:HasAccountSettings()
end

function EditModeLock.GetCompliance()
    local result = { isCompliant = true, isReady = false, mismatches = {} }
    if not IsEditModeReady() then return result end
    local active, isPreset = GetActiveLayout(FetchLayoutData())
    result.isReady = true
    result.isPreset = isPreset

    local seen = 0
    for _, systemInfo in ipairs(active.systems) do
        if systemInfo.system == COOLDOWN_SYSTEM then
            seen = seen + 1
            for settingEnum, wantedValue in pairs(DesiredSettings(systemInfo.systemIndex)) do
                if FindSettingValue(systemInfo.settings, settingEnum) ~= wantedValue then
                    result.isCompliant = false
                    result.mismatches[#result.mismatches + 1] = { systemIndex = systemInfo.systemIndex, setting = settingEnum }
                end
            end
        end
    end

    if seen == 0 then result.isReady = false end
    return result
end

function EditModeLock.ApplyRecommendedSettings()
    if InCombatLockdown() then return "in_combat" end
    if not IsEditModeReady() then return "not_ready" end
    local info = FetchLayoutData()
    local active, isPreset = GetActiveLayout(info)
    if isPreset then return "preset" end

    local changed = false
    for _, systemInfo in ipairs(active.systems) do
        if systemInfo.system == COOLDOWN_SYSTEM then
            for settingEnum, wantedValue in pairs(DesiredSettings(systemInfo.systemIndex)) do
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
    Hook(EditModeSystemSettingsDialog, "AttachToSystemFrame", OnDialogAttach)
    for _, name in ipairs(CDM_SYSTEM_FRAMES) do
        local frame = _G[name]
        frame.isLocked = true
        HookSystemFrame(frame)
    end
    HookSystemFrame(_G[BAR_VIEWER])
    SyncBarsLock()

    EditModeManagerFrame:HookScript("OnShow", BUI.Profiler.Wrap("CDM.EditModeLock edit mode show", OnManagerShow))
    EditModeManagerFrame:HookScript("OnHide", BUI.Profiler.Wrap("CDM.EditModeLock edit mode hide", OnManagerHide))
    if EditModeManagerFrame:IsShown() then OnEditModeShow() end
end
