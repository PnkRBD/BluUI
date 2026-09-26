local _, BUI = ...

BUI.Power.Primary = {}
local PrimaryPower = BUI.Power.Primary
local Pixel = BUI.Pixel
local ClassPowers = BUI.ClassPowers
local Shared = BUI.Power.Shared

local frame, text, barContainer, bar, barText, barTexture
local lowPowerCurve

local function GetDB() return BUI.Power.GetPrimaryDB() end
local function ShouldShow() local db = GetDB() return db.enabled and db.source ~= "none" and BUI.IsModuleEnabled("power") end

local function GetBaseBarColor(db)
    if db.classColorPower then
        local classColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
        if classColor then return classColor.r, classColor.g, classColor.b end
    end
    local powerType = BUI.ClassPowers.GetPrimaryPowerType()
    local key = BUI.Colors.PowerKey(powerType)
    if key then return BUI.Colors.Get(key) end
    return db.barColorR or 1, db.barColorG or 1, db.barColorB or 1
end

local function UpdateOpacity()
    if not frame then return end
    frame:SetAlpha(BUI.Visibility.GetContextualOpacity("PowerBar") / 100)
end

local function SetPowerValueText(fontString, db, isMana, currentPower)
    if isMana then
        local percent = UnitPowerPercent("player", Enum.PowerType.Mana, false, CurveConstants.ScaleTo100)
        fontString:SetFormattedText(db.hidePercentSign and "%.0f" or "%.0f%%", percent)
    else
        fontString:SetFormattedText("%d", currentPower)
    end
end

local function UpdateDisplay()
    if not frame then return end
    local db = GetDB()
    local powerType, isMana = ClassPowers.GetPrimaryPowerType()
    local resolvedPowerType = isMana and Enum.PowerType.Mana or powerType
    local currentPower = UnitPower("player", resolvedPowerType)
    local maxPower = UnitPowerMax("player", resolvedPowerType)

    if db.barMode then
        text:Hide()
        bar:SetMinMaxValues(0, maxPower)
        bar:SetValue(currentPower)

        if lowPowerCurve and barTexture then
            local color = UnitPowerPercent("player", resolvedPowerType, false, lowPowerCurve)
            if color and color.GetRGB then
                barTexture:SetVertexColor(color:GetRGB())
            else

                barTexture:SetVertexColor(GetBaseBarColor(db))
            end
        end

        if not db.barHideText then
            SetPowerValueText(barText, db, isMana, currentPower)
        end
        barText:SetShown(not db.barHideText)
        barContainer:Show()
        return
    end

    barContainer:Hide()
    barText:Hide()
    SetPowerValueText(text, db, isMana, currentPower)

    if lowPowerCurve then
        local color = UnitPowerPercent("player", resolvedPowerType, false, lowPowerCurve)
        if color and color.GetRGB then
            text:SetTextColor(color:GetRGB())
        else
            text:SetTextColor(db.textColorR, db.textColorG, db.textColorB)
        end
    else
        text:SetTextColor(db.textColorR, db.textColorG, db.textColorB)
    end
    text:Show()
end

local function Position()
    if not frame then return end
    local db = GetDB()

    BUI.Anchor.ApplyPosition(frame, BUI.Anchor.ModePos(db, not db.barMode))
end

local function Style()
    if not frame then return end
    local db = GetDB()
    frame:SetFrameStrata(db.barMode and 'LOW' or (db.frameStrata or 'MEDIUM'))
    if frame.textOverlay then frame.textOverlay:SetFrameStrata(db.textStrata or 'MEDIUM') end
    local font = BUI.GetPowerFont()
    local texture = BUI.GetGlobalTexture()

    Pixel.ApplyFont(text, db.textSize, font)
    text:SetTextColor(db.textColorR, db.textColorG, db.textColorB)
    text:ClearAllPoints()
    text:SetPoint("CENTER")

    if not db.barMode then
        if db.lowPowerEnabled then lowPowerCurve = Shared.BuildLowPowerCurve(lowPowerCurve, db, db.textColorR, db.textColorG, db.textColorB) else lowPowerCurve = nil end
        local padding = (Shared.IsAnchoredFor(db, true) or BUI.Power.Container.HasMember('primary')) and 0 or 20
        frame:SetSize(Pixel.Scale(120 + padding), Pixel.Scale(50 + padding))
        return
    end

    local borderSize = Pixel.ClampBorder(db.borderSize or 1)
    local borderColor = db.borderColor or { 0, 0, 0, 1 }
    local edge = Pixel.Scale(borderSize)

    local anchorWidth = BUI.Anchor.GetAnchorWidth(frame, db)
    local scaledBarWidth = anchorWidth or Pixel.Scale(db.barWidth)
    local scaledBarHeight = Pixel.Scale(db.barHeight)

    barContainer:SetSize(scaledBarWidth, scaledBarHeight)
    Pixel.SetTemplate(barContainer,
        db.barBgColorR, db.barBgColorG, db.barBgColorB, db.barBgColorA or 1,
        borderColor[1], borderColor[2], borderColor[3], borderColor[4], borderSize)

    Shared.ApplyStackFlush(barContainer, bar, db.stackFlushEdge, edge,
        db.barBgColorR, db.barBgColorG, db.barBgColorB, db.barBgColorA or 1)
    bar:SetStatusBarTexture(texture)

    local red, green, blue = GetBaseBarColor(db)
    bar:SetStatusBarColor(red, green, blue)

    if bar._predict then
        bar._predict:SetStatusBarTexture(texture)
        bar._predict:SetStatusBarColor(
            db.predictionColorR or 1,
            db.predictionColorG or 1,
            db.predictionColorB or 1,
            db.predictionColorA or 0.35
        )
    end

    if db.lowPowerEnabled then lowPowerCurve = Shared.BuildLowPowerCurve(lowPowerCurve, db, red, green, blue) else lowPowerCurve = nil end

    barTexture = bar:GetStatusBarTexture()

    Pixel.ApplyFont(barText, db.barTextSize, font)
    barText:SetTextColor(db.barTextColorR, db.barTextColorG, db.barTextColorB)
    barText:ClearAllPoints()
    local textOffsetX = db.barTextOffsetX or 0
    local textOffsetY = db.barTextOffsetY or 0
    if db.barTextAbove then
        barText:SetPoint("BOTTOM", barContainer, "TOP", Pixel.Scale(textOffsetX), Pixel.Scale(2 + textOffsetY))
    else
        barText:SetPoint("CENTER", barContainer, "CENTER", Pixel.Scale(textOffsetX), Pixel.Scale(textOffsetY))
    end

    Shared.StyleTicks(bar, db, scaledBarWidth, scaledBarHeight, edge)

    frame:SetSize(scaledBarWidth, scaledBarHeight)
    local grabMargin = BUI.ResolveAnchorFrame(db.anchorFrame) and 0 or Pixel.Scale(10)
    frame:SetHitRectInsets(-grabMargin, -grabMargin, -grabMargin, -grabMargin)
    if frame.dragLocked and frame.RefreshDragState then frame:RefreshDragState() end
end

local function Build()
    if frame then return end

    frame = CreateFrame("Frame", "BUI_PowerBar", UIParent)
    frame:SetSize(Pixel.Scale(120), Pixel.Scale(50))
    frame:SetFrameStrata("MEDIUM")
    frame:Hide()
    frame:EnableMouse(true)
    local function NotifyAnchorChange()
        if not BUI.Power.Stack.IsEnabled() then
            BUI.Anchor.OnAnchorSizeChanged()
        end
    end
    frame:HookScript("OnShow", NotifyAnchorChange)
    frame:HookScript("OnHide", NotifyAnchorChange)

    text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER")
    Pixel.ApplyFont(text, 26, BUI.GetPowerFont())

    barContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    barContainer:SetPoint("CENTER")
    barContainer:Hide()
    frame.barContainer = barContainer

    bar = CreateFrame("StatusBar", nil, barContainer)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    bar._predict = BUI.PowerPrediction.Attach(bar, {
        enabled = function() return GetDB().showPrediction ~= false end,
        powerType = function() return (ClassPowers.GetPrimaryPowerType()) end,
    })

    local textOverlay = CreateFrame("Frame", nil, barContainer)
    textOverlay:SetAllPoints(barContainer)
    textOverlay:SetFrameLevel(barContainer:GetFrameLevel() + 150)
    frame.textOverlay = textOverlay
    barText = textOverlay:CreateFontString(nil, "OVERLAY")
    barText:SetPoint("CENTER")
    Pixel.ApplyFont(barText, 14, BUI.GetPowerFont())

    BUI.Dragging.MakeDraggable(frame, {
        showHint = true,
        showUnlockedBg = true,
        hintAnchor = "TOP",
        isLocked = function() return GetDB().locked end,
        onPositionChanged = function(x, y)
            local db = GetDB()
            local pos = BUI.Anchor.ModePos(db, not db.barMode)
            if pos.centerHorizontally then
                local _, centerY = BUI.Dragging.GetCenterOffset(frame)
                x, y = 0, centerY
            end
            pos.posX, pos.posY = x, y
            Position()
        end,
        onRightClick = function() PrimaryPower.SetLocked(true) end,
        usePointPosition = true,
    })
end

local eventsStarted, opacityStarted = false, false
local loginSettleArmed = false

local function OnStyleEvent(event)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        ClassPowers.UpdateSpecID()
    end
    if event == "PLAYER_ENTERING_WORLD" and not loginSettleArmed then
        loginSettleArmed = true
        BUI.Events:RegisterUnit("UNIT_AURA", "player", "PowerLoginSettle", function()
            loginSettleArmed = false
            BUI.Events:Unregister("UNIT_AURA", "PowerLoginSettle")
            OnStyleEvent("AURA_SETTLE")
        end)
    end
    Style()
    UpdateDisplay()
    if frame then
        if not ShouldShow() or ClassPowers.IsPrimaryHiddenForForm() then frame:Hide() else frame:Show() end
    end
end

local function StartEvents()
    if eventsStarted then return end
    eventsStarted = true
    BUI.Events:RegisterUnit("UNIT_MAXPOWER", "player", "Power", function() Style() UpdateDisplay() end)
    BUI.Events:RegisterUnit("UNIT_DISPLAYPOWER", "player", "Power", function() OnStyleEvent("UNIT_DISPLAYPOWER") end)
    BUI.Events:RegisterUnit("UNIT_POWER_FREQUENT", "player", "PowerLive", UpdateDisplay)
    BUI.Events:Register("PLAYER_ENTERING_WORLD", "Power", OnStyleEvent)
    BUI.Events:Register("PLAYER_SPECIALIZATION_CHANGED", "Power", OnStyleEvent)
    BUI.Events:Register("UPDATE_SHAPESHIFT_FORM", "Power", OnStyleEvent)
    BUI.Events:Register("UPDATE_SHAPESHIFT_FORMS", "Power", OnStyleEvent)
end

local function StopEvents()
    if not eventsStarted then return end
    BUI.Events:UnregisterAll("Power")
    BUI.Events:UnregisterAll("PowerLive")
    BUI.Events:UnregisterAll("PowerLoginSettle")
    loginSettleArmed = false
    eventsStarted = false
end

local function StartOpacityEvents()
    if opacityStarted then return end
    opacityStarted = true
    BUI.Visibility.Register("PowerBar", UpdateOpacity, true)
end

local function StopOpacityEvents()
    if not opacityStarted then return end
    BUI.Visibility.Unregister("PowerBar")
    opacityStarted = false
end

local function Shutdown()
    StopEvents()
    StopOpacityEvents()
    if frame then frame:Hide() end
end

local function Activate()
    Build()
    StartEvents()
    StartOpacityEvents()
    Position()
    Style()
    UpdateDisplay()
    UpdateOpacity()
    BUI.Dragging.SetLocked(frame, GetDB().locked)
    if ClassPowers.IsPrimaryHiddenForForm() then frame:Hide() else frame:Show() end
end

local function OnAnchorSizeChanged()
    if Shared.ShouldReanchor(frame, GetDB()) then
        Position()
        Style()
    end
end

function PrimaryPower.Initialize()
    Build()
    BUI.Anchor.RegisterCallback("PowerBar", OnAnchorSizeChanged)
    if ShouldShow() then Activate() end
    Pixel.OnScaleChange("PowerBar", function()
        if frame and GetDB().enabled then
            Position()
            Style()
        end
    end)
end

function PrimaryPower.Toggle(on)
    GetDB().enabled = on
    if ShouldShow() then Activate() else Shutdown() end
end

function PrimaryPower.Apply()
    if not ShouldShow() then Shutdown() return end
    Activate()
end

function PrimaryPower.SetLocked(locked)
    if not frame then return end
    local db = GetDB()
    db.locked = locked
    BUI.Dragging.SetLocked(frame, locked)
    if PrimaryPower._lockToggle and PrimaryPower._lockToggle.SetValue then
        PrimaryPower._lockToggle:SetValue(not locked)
    end
end

BUI.Events:OnLogin("PowerBar", function()
    PrimaryPower.Initialize()
    Shared.DeferRefresh(function() return frame end, GetDB, function() Position() Style() end)
end, "power")
