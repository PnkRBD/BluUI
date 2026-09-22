local _, BUI = ...
local SetScript = BUI.Prof.Scripts('Util.Scale')
BUI.Scale = {}
local Scale = BUI.Scale
local Pixel = BUI.Pixel
local BUILib = BluUI.BUILibClient

local PRESETS = {
    { key = "1080p",  value = 0.711111,          label = "1080p Scale" },
    { key = "1440p",  value = 0.533333333333333, label = "1440p Scale" },
    { key = "4K",     value = 0.355556,          label = "4K Scale" },
    { key = "Custom",                             label = "Custom" },
}

local buttons = {}

local function GetSavedScale()
    local db = BUI.GetDB()
    return db and db.uiScale.scale
end

local function SaveScale(value)
    local db = BUI.GetDB()
    if not db then return end
    db.uiScale.scale = value
end

local function FindPresetKey(scale)
    if not scale then return nil end
    for presetIndex = 1, #PRESETS do
        local preset = PRESETS[presetIndex]
        if preset.value and BUI.ApproxEqual(scale, preset.value) then return preset.key end
    end
    return nil
end

local function RefreshButtons(scale)
    if not next(buttons) then return end
    local matched = FindPresetKey(scale)
    local isCustom = scale ~= nil and matched == nil
    for presetIndex = 1, #PRESETS do
        local preset = PRESETS[presetIndex]
        local button = buttons[preset.key]
        if button then
            local active = (preset.key == "Custom") and isCustom or (preset.key == matched)
            if button.SetActive then button:SetActive(active) end
            if button.SetFlashing then button:SetFlashing(scale == nil) end
        end
    end
end

local function Apply(newScale)
    SaveScale(newScale)
    if InCombatLockdown() then
        BUI.Print("Scale will apply after combat.")
    end
    BUI.ApplyScale()
    RefreshButtons(newScale)
end

local function ShowCustomDialog(parent)
    local Modals = BUILib.Modals
    local Controls = BUILib.Controls
    local current = GetSavedScale() or 0.5
    local chosen = current

    local overlay, dialog, close = Modals.CreateBase(340, 200, true, parent)
    Modals.CreateTitle(dialog, "Custom Scale")

    local hint = dialog:CreateFontString(nil, "OVERLAY")
    hint:SetFont(BUILib.Font, 11, "")
    hint:SetPoint("TOP", dialog, "TOP", 0, Pixel.Scale(-50))
    hint:SetTextColor(0.6, 0.6, 0.6)
    hint:SetText("Lower = smaller UI (for higher resolutions)")

    local slider = Controls.Slider(dialog, nil, 0.30, 0.90, current, function(value) chosen = value end, 0, false, nil, 0.01, 260)
    slider:SetPoint("CENTER", 0, Pixel.Scale(5))

    local confirmButton = Modals.CreateButton(dialog, "Set", Modals.BTN_CONFIRM, 100)
    confirmButton:SetPoint("BOTTOM", dialog, "BOTTOM", Pixel.Scale(-55), Pixel.Scale(20))
    SetScript(confirmButton, "OnClick", function() close(); Apply(chosen) end)
    local cancelButton = Modals.CreateButton(dialog, "Cancel", Modals.BTN_CANCEL, 100)
    cancelButton:SetPoint("BOTTOM", dialog, "BOTTOM", Pixel.Scale(55), Pixel.Scale(20))
    SetScript(cancelButton, "OnClick", close)

    overlay:Show()
end

function Scale.GetFooterButtons()
    local buttonDefinitions = {}
    for presetIndex = 1, #PRESETS do
        local preset = PRESETS[presetIndex]
        buttonDefinitions[#buttonDefinitions + 1] = {
            key = preset.key,
            text = preset.label,
            width = preset.key == "Custom" and 90 or 120,
            roundedIndicator = true,
        }
    end
    buttonDefinitions[#buttonDefinitions + 1] = {
        key = "finish",
        text = "Finish & Reload",
        width = 140,
        callback = ReloadUI,
    }
    return buttonDefinitions
end

function Scale.SetupButtons(window, parent)
    buttons = {}
    for presetIndex = 1, #PRESETS do
        local preset = PRESETS[presetIndex]
        local button = window.footerButtons[preset.key]
        if button then
            buttons[preset.key] = button
            if preset.key == "Custom" then
                SetScript(button, "OnClick", function() ShowCustomDialog(parent) end)
            else
                SetScript(button, "OnClick", function() Apply(preset.value) end)
            end
        end
    end
    RefreshButtons(GetSavedScale())
end

function Scale.SyncButtons()
    RefreshButtons(GetSavedScale())
end

local function ProtectScale()
    if BUI._applyingScale then return end
    if InCombatLockdown() then return end

    local target = BUI.AppliedUIScale()
    if not BUI.ApproxEqual(UIParent:GetScale(), target) then
        BUI.ApplyScale()
    end
end
BUI.Events:Register("UI_SCALE_CHANGED", "Scale.Protect", ProtectScale)
BUI.Events:Register("DISPLAY_SIZE_CHANGED", "Scale.Protect", ProtectScale)
BUI.Events:Register("PLAYER_REGEN_ENABLED", "Scale.Protect", ProtectScale)
