local _, BUI = ...

local Display = {}
BUI.BuffTracking.Display = Display

local Pixel = BUI.Pixel
local GetTime = GetTime
local pairs, ipairs = pairs, ipairs

local trackers = {}
local inCombat = false

local STACK_COLOR_KEYS = { "stack1Color", "stack2Color", "stack3Color" }
local SOUND_COOLDOWN_SECONDS = 2

local anchorCallbacks = {}

function Display.GetTrackers() return trackers end
function Display.GetTracker(settingsKey) return trackers[settingsKey] end
function Display.IsInCombat() return inCombat end
function Display.AlwaysActive() return true end

function Display.RefreshAll()
    for _, tracker in pairs(trackers) do
        tracker.Refresh()
    end
end

function Display.UpdateOpacity()
    local opacity = BUI.Visibility.GetContextualOpacity("BuffTracking") / 100
    for _, tracker in pairs(trackers) do
        if tracker.frame then
            tracker.frame:SetAlpha(opacity)
        end
    end
end

function Display.RegisterAnchorCallback(settingsKey, callback)
    anchorCallbacks[settingsKey] = callback
end

function Display.UnregisterAnchorCallback(settingsKey)
    anchorCallbacks[settingsKey] = nil
end

function Display.NotifyAnchorChanged(settingsKey, state)
    local callback = anchorCallbacks[settingsKey]
    if callback then callback(state) end
end

function Display.MakeAnchorOverlay(frame)
    frame.anchor = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.anchor:SetAllPoints()
    BUI.Tools.SetColorTex(frame.anchor, 0, 0, 0, 0.3)
    frame.anchor:Hide()

    frame.anchorText = frame:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(frame.anchorText, 10, BUI.GetGlobalFont(), "OUTLINE")
    frame.anchorText:SetPoint("BOTTOM", frame, "TOP", 0, Pixel.Scale(2))
    frame.anchorText:SetText("Drag to Reposition | Right-Click to Lock")
    frame.anchorText:Hide()
end

function Display.EnableDragging(tracker, GetConfig)
    local frame = tracker.frame
    if not frame then return end

    BUI.Dragging.EnableAnchorDrag(frame, {
        isCentered = function() return GetConfig().centerHorizontally and not frame._isAnchored end,
        onSave     = function() BUI.Anchor.SaveDrop(frame, GetConfig()) end,
        onRightClick = function()
            GetConfig().showAnchor = false
            tracker.DisableDragging()
            Display.NotifyAnchorChanged(tracker.settingsKey, false)
        end,
    })

    if frame.anchor     then frame.anchor:Show()     end
    if frame.anchorText then frame.anchorText:Show() end
end

function Display.DisableDragging(tracker)
    local frame = tracker.frame
    if not frame then return end

    BUI.Dragging.DisableAnchorDrag(frame)

    if frame.anchor     then frame.anchor:Hide()     end
    if frame.anchorText then frame.anchorText:Hide() end
end

local function GetStackColor(stacks, settings)
    if not settings.colorByStacks then
        local color = settings.filledColor
        return color.r, color.g, color.b, color.a
    end
    local color = settings[STACK_COLOR_KEYS[stacks] or STACK_COLOR_KEYS[#STACK_COLOR_KEYS]]
    return color.r, color.g, color.b, color.a
end

function Display.CreateTracker(config)
    local tracker = {
        settingsKey    = config.settingsKey,
        frameName      = config.frameName,
        getStacks      = config.getStacks,
        getColorStacks = config.getColorStacks,
        isActive       = config.isActive,
        maxStacks      = config.maxStacks,
        frame          = nil,
        bars           = {},
        textDisplay    = nil,
    }

    local function GetSettings() return BUI.GetDB()[tracker.settingsKey] end

    local lastSoundAt = 0

    local function PlaySound(settings)
        local now = GetTime()
        if now - lastSoundAt < SOUND_COOLDOWN_SECONDS then return end
        lastSoundAt = now
        BUI.PlaySoundByName(settings.sound)
    end

    local function BuildMainFrame()
        if tracker.frame then return end
        local frame = CreateFrame("Frame", tracker.frameName, UIParent)
        frame:SetFrameStrata("MEDIUM")
        frame:SetFrameLevel(10)
        frame:SetClampedToScreen(true)
        Display.MakeAnchorOverlay(frame)
        tracker.frame = frame
    end

    local function MakeBar()
        local bar = CreateFrame("Frame", nil, tracker.frame, "BackdropTemplate")
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints()
        bar.fill = bar:CreateTexture(nil, "ARTWORK")
        bar.fill:SetAllPoints()
        bar.fill:SetTexture(BUI.GetGlobalTexture())
        return bar
    end

    local function MakeTextDisplay()
        local frame = CreateFrame("Frame", nil, tracker.frame)
        frame.text = frame:CreateFontString(nil, "OVERLAY")
        frame.text:SetPoint("CENTER")
        return frame
    end

    local function StyleBar(bar, settings, barIndex)
        local barWidth = settings.barWidth
        local barHeight = settings.barHeight
        local borderThickness = settings.borderThickness

        bar:SnapSize(barWidth, barHeight)
        bar:ClearAllPoints()
        bar:SetPoint("LEFT", tracker.frame, "LEFT", Pixel.Scale((barIndex - 1) * (barWidth + settings.barSpacing)), 0)

        if borderThickness > 0 then
            local borderColor = settings.borderColor
            Pixel.ApplyBorder(bar, borderThickness, borderColor.r, borderColor.g, borderColor.b, borderColor.a)
            Pixel.ShowBorder(bar)
            local edge = Pixel.Scale(borderThickness)
            bar.bg:ClearAllPoints()
            bar.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", edge, -edge)
            bar.bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -edge, edge)
            bar.fill:ClearAllPoints()
            bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", edge, -edge)
            bar.fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -edge, edge)
        else
            Pixel.HideBorder(bar)
            bar.bg:ClearAllPoints()
            bar.bg:SetAllPoints()
            bar.fill:ClearAllPoints()
            bar.fill:SetAllPoints()
        end

        local emptyColor = settings.emptyColor
        BUI.Tools.SetColorTex(bar.bg, emptyColor.r, emptyColor.g, emptyColor.b, emptyColor.a)
    end

    local function UpdateBars(stacks, colorStacks, restyle)
        local settings = GetSettings()
        if restyle and tracker.textDisplay then tracker.textDisplay:Hide() end

        local red, green, blue, alpha = GetStackColor(colorStacks, settings)
        for barIndex = 1, tracker.maxStacks do
            local bar = tracker.bars[barIndex]
            local created = bar == nil
            if created then
                bar = MakeBar()
                tracker.bars[barIndex] = bar
            end
            if restyle or created then StyleBar(bar, settings, barIndex) end

            if barIndex <= stacks then
                bar.fill:SetVertexColor(red, green, blue, alpha)
                bar.fill:Show()
                bar.bg:Hide()
            else
                bar.bg:Show()
                bar.fill:Hide()
            end
            bar:Show()
        end

        if restyle then
            local barWidth = settings.barWidth
            tracker.frame:SnapSize(tracker.maxStacks * barWidth + (tracker.maxStacks - 1) * settings.barSpacing, settings.barHeight)
        end
    end

    local function StyleText(settings)
        local fontSize = settings.textSize
        Pixel.ApplyFont(tracker.textDisplay.text, fontSize, BUI.GetModuleFont(settings), BUI.GetFontOutline())
        tracker.textDisplay:SnapSize(fontSize * 2)
        tracker.textDisplay:ClearAllPoints()
        tracker.textDisplay:SetPoint("CENTER", tracker.frame, "CENTER")
        tracker.textDisplay:Show()
        tracker.frame:SnapSize(fontSize * 2)
    end

    local function UpdateText(stacks, colorStacks, restyle)
        local settings = GetSettings()
        if restyle then
            for barIndex = 1, #tracker.bars do tracker.bars[barIndex]:Hide() end
        end

        local created = tracker.textDisplay == nil
        if created then tracker.textDisplay = MakeTextDisplay() end
        if restyle or created then StyleText(settings) end

        local displayText
        if config.getCustomText then
            displayText = config.getCustomText(settings, stacks, colorStacks)
        end
        if displayText == nil or displayText == "" then
            displayText = settings.customText or stacks
        end
        tracker.textDisplay.text:SetText(displayText)

        local red, green, blue
        if settings.colorByStacks and colorStacks > 0 then
            red, green, blue = GetStackColor(colorStacks, settings)
        else
            local textColor = settings.textColor
            red, green, blue = textColor.r, textColor.g, textColor.b
        end
        tracker.textDisplay.text:SetTextColor(red, green, blue, 1)
    end

    local lastStacks = -1
    local lastColorStacks = -1
    local layoutDirty = true
    local auraLayoutDirty = true
    local showingAuraPath = false

    local auraDriver
    local auraTextSettings
    local auraStamp
    local auraLabelWidth, auraDigitWidth = 0, 0
    local auraLabelOffset = 0
    local auraShift
    local measureText

    local function StyleAuraText(text, button)
        local settings = auraTextSettings
        local textColor = settings.textColor
        Pixel.ApplyFont(text, settings.textSize, BUI.GetModuleFont(settings), BUI.GetFontOutline())
        if not config.stackDriver then
            text:SetText(settings.customText)
        end
        text:SetTextColor(textColor.r, textColor.g, textColor.b, 1)
        if config.stackDriver and button then
            local label = button._buiDriverLabel
            local wanted = settings.customText
            if wanted ~= "" then
                if not label then
                    label = button:CreateFontString(nil, 'OVERLAY')
                    button._buiDriverLabel = label
                end
                Pixel.ApplyFont(label, settings.textSize, BUI.GetModuleFont(settings), BUI.GetFontOutline())
                label:ClearAllPoints()
                label:SetPoint('RIGHT', button, 'CENTER', auraLabelOffset, 0)
                label:SetText(wanted)
                label:SetTextColor(textColor.r, textColor.g, textColor.b, 1)
                label:Show()
            elseif label then
                label:Hide()
            end
        end
    end

    local function AuraTextStamp(settings)
        local textColor = settings.textColor
        return table.concat({
            settings.customText,
            settings.textSize,
            BUI.GetModuleFont(settings),
            BUI.GetFontOutline(),
            ("%.2f:%.2f:%.2f"):format(textColor.r, textColor.g, textColor.b),
        }, "|")
    end

    local function MeasureLabel(settings)
        local label = settings.customText
        if label == "" then return 0, 0 end
        if not measureText then
            measureText = tracker.frame:CreateFontString(nil, "OVERLAY")
            measureText:Hide()
        end
        Pixel.ApplyFont(measureText, settings.textSize, BUI.GetModuleFont(settings), BUI.GetFontOutline())
        measureText:SetText(label)
        local labelWidth = measureText:GetStringWidth()
        measureText:SetText("8")
        local digitWidth = measureText:GetStringWidth()
        return labelWidth, digitWidth
    end

    local function RefreshAuraStyle()
        if not config.auraSpellSet then return end
        local settings = GetSettings()
        auraTextSettings = settings
        auraStamp = AuraTextStamp(settings)
        if config.stackDriver then
            auraLabelWidth, auraDigitWidth = MeasureLabel(settings)
        end
    end

    local function SyncAuraText(shouldSync)
        if not config.auraSpellSet then return false end
        local Engine = BUI.AuraEngine
        if not Engine.Available then return false end
        local syncDriver = config.stackDriver and Engine.SyncAuraStackDriver or Engine.SyncAuraTextDriver
        if not shouldSync then
            if auraDriver then syncDriver(auraDriver, false) end
            return false
        end
        if not auraDriver then auraDriver = Engine.NewAuraDriver(tracker.frame) end
        if not auraStamp then RefreshAuraStyle() end

        local sizePixels = auraTextSettings.textSize * 2
        local widthPixels = sizePixels
        local shift = 0
        if config.stackDriver then
            local gap = Pixel.Scale(5)
            auraLabelOffset = -(auraDigitWidth * 0.5 + gap)
            if auraLabelWidth > 0 then
                widthPixels = sizePixels + (auraLabelWidth + gap) * 2
                shift = (auraLabelWidth + gap) * 0.5
            end
        end
        syncDriver(auraDriver, true, config.auraSpellSet, auraStamp, widthPixels, sizePixels, StyleAuraText)
        local container = auraDriver.container
        if container and auraShift ~= shift then
            auraShift = shift
            container:ClearAllPoints()
            container:SetPoint("CENTER", tracker.frame, "CENTER", shift, 0)
        end
        return container ~= nil
    end

    local function HideAndReset()
        SyncAuraText(false)
        if tracker.frame then tracker.frame:Hide() end
        lastStacks = -1
    end

    function tracker.MarkDirty()
        layoutDirty = true
        auraLayoutDirty = true
    end

    function tracker.Update()
        if not tracker.frame then HideAndReset(); return end

        local settings = GetSettings()
        local forceShow = settings.showAnchor

        if not forceShow and not tracker.isActive() then
            HideAndReset(); return
        end
        if not settings.enabled and not forceShow then
            HideAndReset(); return
        end

        local stacks = tracker.getStacks()

        if not forceShow and SyncAuraText(true) then
            tracker.frame:Show()
            if not showingAuraPath or auraLayoutDirty then
                showingAuraPath = true
                auraLayoutDirty = false
                layoutDirty = true
                tracker.frame:SnapSize(settings.textSize * 2)
                if tracker.textDisplay then tracker.textDisplay:Hide() end
            end
            if stacks == 0 then
                lastStacks = -1
            else
                if lastStacks == -1 then PlaySound(settings) end
                lastStacks = stacks
            end
            return
        end
        if forceShow then SyncAuraText(false) end
        showingAuraPath = false

        if config.textOnly then
            if not forceShow and stacks == 0 then
                HideAndReset(); return
            end
        else
            if not forceShow and settings.showOnlyInCombat and not inCombat then
                HideAndReset(); return
            end
            if not forceShow and settings.hideWhenEmpty and stacks == 0 then
                HideAndReset(); return
            end
        end

        tracker.frame:Show()
        local colorStacks = stacks
        if tracker.getColorStacks then colorStacks = tracker.getColorStacks() end

        if stacks == lastStacks and colorStacks == lastColorStacks and not layoutDirty then
            return
        end

        if lastStacks == -1 and stacks > 0 then PlaySound(settings) end

        local restyle = layoutDirty
        lastStacks = stacks
        lastColorStacks = colorStacks
        layoutDirty = false

        if not config.textOnly and settings.displayMode == "BARS" then
            UpdateBars(stacks, colorStacks, restyle)
        else
            UpdateText(stacks, colorStacks, restyle)
        end
    end

    function tracker.ApplyPosition()
        if not tracker.frame then return end
        BUI.Anchor.ApplyPosition(tracker.frame, GetSettings())
    end

    function tracker.EnableDragging()  Display.EnableDragging(tracker, GetSettings) end
    function tracker.DisableDragging() Display.DisableDragging(tracker) end

    BUI.Anchor.Follow("BuffTracking." .. config.settingsKey, function()
        local settings = GetSettings()
        return (settings.enabled or settings.showAnchor) and tracker.frame
    end, GetSettings)

    function tracker.RecheckActive()
        BUI.Scheduler.SetUpdateEnabled(tracker.frameName, GetSettings().enabled and tracker.isActive())
        tracker.Update()
    end

    function tracker.Refresh()
        BuildMainFrame()
        tracker.ApplyPosition()
        RefreshAuraStyle()
        tracker.MarkDirty()

        if GetSettings().showAnchor then
            tracker.EnableDragging()
        else
            tracker.DisableDragging()
        end
        tracker.RecheckActive()
    end

    function tracker.Initialize()
        tracker.Refresh()
        BUI.Scheduler.RegisterUpdate(tracker.frameName, tracker.Update, config.updateInterval or 1, GetSettings().enabled and tracker.isActive())
    end

    trackers[config.settingsKey] = tracker
    return tracker
end

local UpdateAllTrackers = BUI.Dispatcher.New(function()
    for _, tracker in pairs(trackers) do
        tracker.Update()
    end
end, 'BuffTracking.Trackers')

local RecheckAllActive = BUI.Dispatcher.New(function()
    for _, tracker in pairs(trackers) do
        tracker.RecheckActive()
    end
end, 'BuffTracking.RecheckActive')

local function OnCombat(event)
    inCombat = (event == "PLAYER_REGEN_DISABLED")
    UpdateAllTrackers()
end

local function LabelWithCount(settings, stacks)
    local label = settings.customText
    if label ~= "" then return label .. " " .. stacks end
    return stacks
end

local function AlternateTextWhenNoTip(settings, _, colorStacks)
    if colorStacks == 2 then return settings.customTextAlt end
    return settings.customText
end

local HUNTER_TRACKERS = {
    { settingsKey = "hunterTip",          frameName = "BUI_BuffTrackingHunterTip",          stacks = "GetTipStacks",          isActive = "IsSurvivalHunter",     maxStacks = 3 },
    { settingsKey = "hunterPreciseShots", frameName = "BUI_BuffTrackingHunterPS",           stacks = "GetPreciseShotsStacks", isActive = "IsMarksmanshipHunter", maxStacks = 2, textOnly = true, auraSpellSet = "PreciseShotsSpellSet" },
    { settingsKey = "hunterLockAndLoad",  frameName = "BUI_BuffTrackingHunterLnL",          stacks = "GetLockAndLoadStacks",  isActive = "IsMarksmanshipHunter", maxStacks = 1, textOnly = true, auraSpellSet = "LockAndLoadSpellSet" },
    { settingsKey = "hunterBulletstorm",  frameName = "BUI_BuffTrackingHunterBS",           stacks = "GetBulletstormStacks",  isActive = "IsMarksmanshipHunter", maxStacks = 2, textOnly = true, customText = LabelWithCount },
    { settingsKey = "hunterKillCommand",  frameName = "BUI_BuffTrackingHunterKC",           stacks = "GetKillCommandStacks",  isActive = "IsBeastMasteryOrSurvival", maxStacks = 1, textOnly = true, auraSpellSet = "NaturesAllySpellSet" },
    { settingsKey = "hunterCobraFang",    frameName = "BUI_BuffTrackingHunterCF",           stacks = "GetCobraFangStacks",    isActive = "IsBeastMastery",       maxStacks = 4, textOnly = true, auraSpellSet = "CobraFangSpellSet", stackDriver = true, customText = LabelWithCount },
    { settingsKey = "hunterRaptorSwipe",  frameName = "BUI_BuffTrackingHunterRS",           stacks = "GetRaptorSwipeStacks",  isActive = "IsSurvivalHunter",     maxStacks = 1, textOnly = true, colorStacks = "GetRaptorSwipeColorStacks", customText = AlternateTextWhenNoTip },
    { settingsKey = "hunterRaptorPrompt", frameName = "BUI_BuffTrackingHunterRaptorPrompt", stacks = "GetRaptorPromptStacks", isActive = "IsSurvivalHunter",     maxStacks = 1, textOnly = true },
}

local function CreateHunterTracker(Hunter, definition)
    local readStacks = Hunter[definition.stacks]
    return Display.CreateTracker({
        settingsKey    = definition.settingsKey,
        frameName      = definition.frameName,
        auraSpellSet   = definition.auraSpellSet and Hunter[definition.auraSpellSet],
        stackDriver    = definition.stackDriver,
        getStacks      = function() Hunter.Update() return readStacks() end,
        getColorStacks = definition.colorStacks and Hunter[definition.colorStacks],
        getCustomText  = definition.customText,
        isActive       = Hunter[definition.isActive],
        maxStacks      = definition.maxStacks,
        textOnly       = definition.textOnly,
    })
end

local function CreateModuleTracker(module)
    local tracker = module.Create()
    if tracker then tracker.Initialize() end
end

BUI.Events:OnLogin("BuffTrackingDisplay", function()
    local Hunter = BUI.BuffTracking.Hunter
    if Hunter.PlayerIsHunter then
        for _, definition in ipairs(HUNTER_TRACKERS) do
            CreateHunterTracker(Hunter, definition).Initialize()
        end
        CreateModuleTracker(BUI.BuffTracking.PackLeader)
    end
    CreateModuleTracker(BUI.BuffTracking.PetAlert)
    CreateModuleTracker(BUI.BuffTracking.SmartMisdirect)
    RecheckAllActive()
end)

BUI.Events:Register("PLAYER_REGEN_DISABLED", "BuffTrackingDisplay", OnCombat)
BUI.Events:Register("PLAYER_REGEN_ENABLED",  "BuffTrackingDisplay", OnCombat)
BUI.Events:RegisterUnit("UNIT_AURA", "player", "BuffTrackingAura", UpdateAllTrackers)
BUI.Events:RegisterUnit("UNIT_SPELLCAST_SUCCEEDED", "player", "BuffTrackingCast", UpdateAllTrackers)
BUI.Events:Register("SPELL_UPDATE_CHARGES", "BuffTrackingCharges", UpdateAllTrackers)
BUI.Events:Register("PLAYER_SPECIALIZATION_CHANGED", "BuffTrackingDisplay", RecheckAllActive)
BUI.Visibility.Register("BuffTracking", Display.UpdateOpacity, true)
