local _, BUI = ...

BUI.Power.Primary = {}
local PrimaryPower = BUI.Power.Primary
local Pixel = BUI.Pixel
local ClassPowers = BUI.ClassPowers
local Shared = BUI.Power.Shared
local SafeNum = BUI.Tools.SafeNum

local frame, text, barContainer, bar, barText, barTexture, textOverlay
local lowPowerCurve
local livePowerType, livePower, liveMax

local function GetDB() return BUI.Power.GetPrimaryDB() end
local function ShouldShow() local db = GetDB() return db.enabled and db.source ~= "none" and BUI.IsModuleEnabled("power") end

local function GetBaseBarColor(db)
    if db.classColorPower then
        local classColor = RAID_CLASS_COLORS[ClassPowers.GetPlayerClass()]
        return classColor.r, classColor.g, classColor.b
    end
    local key = BUI.Colors.PowerKey((ClassPowers.GetPrimaryPowerType()))
    if key then return BUI.Colors.Get(key) end
    return db.barColorR, db.barColorG, db.barColorB
end

local function UpdateOpacity()
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
    local db = GetDB()
    local powerType, isMana = ClassPowers.GetPrimaryPowerType()
    local currentPower = UnitPower("player", powerType)
    local maxPower = UnitPowerMax("player", powerType)
    livePowerType = powerType

    if db.barMode then
        text:Hide()
        bar:SetMinMaxValues(0, maxPower)
        bar:SetValue(currentPower)

        if lowPowerCurve then
            barTexture:SetVertexColor(UnitPowerPercent("player", powerType, false, lowPowerCurve):GetRGB())
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
        text:SetTextColor(UnitPowerPercent("player", powerType, false, lowPowerCurve):GetRGB())
    end
    text:Show()
end

local function OnLivePower(_, _, powerToken)
    if powerToken ~= ClassPowers.PowerToken(livePowerType) then return end
    local current, max = SafeNum(UnitPower("player", livePowerType)), SafeNum(UnitPowerMax("player", livePowerType))
    if current and max and current == livePower and max == liveMax then return end
    livePower, liveMax = current, max
    UpdateDisplay()
end

local function Position()
    local db = GetDB()
    BUI.Anchor.ApplyPosition(frame, BUI.Anchor.ModePos(db, not db.barMode))
end

local styledPowerType, styledAnchorWidth

local function Style()
    local db = GetDB()
    livePower = nil
    styledPowerType = ClassPowers.GetPrimaryPowerType()
    styledAnchorWidth = BUI.Anchor.GetAnchorWidth(frame, db)
    frame:SetFrameStrata(db.barMode and 'LOW' or db.frameStrata)
    textOverlay:SetFrameStrata(db.textStrata)
    local font = BUI.GetPowerFont()
    local texture = BUI.GetGlobalTexture()

    Pixel.ApplyFont(text, db.textSize, font)
    text:SetTextColor(db.textColorR, db.textColorG, db.textColorB)

    if not db.barMode then
        if db.lowPowerEnabled then lowPowerCurve = Shared.BuildLowPowerCurve(lowPowerCurve, db, db.textColorR, db.textColorG, db.textColorB) else lowPowerCurve = nil end
        local padding = (Shared.IsAnchoredFor(db, true) or BUI.Power.Container.HasMember('primary')) and 0 or 20
        frame:SetSize(Pixel.Scale(120 + padding), Pixel.Scale(50 + padding))
        return
    end

    local borderSize = Pixel.ClampBorder(db.borderSize)
    local borderColor = db.borderColor
    local edge = Pixel.Scale(borderSize)

    local scaledBarWidth = styledAnchorWidth or Pixel.Scale(db.barWidth)
    local scaledBarHeight = Pixel.Scale(db.barHeight)

    barContainer:SetSize(scaledBarWidth, scaledBarHeight)
    Pixel.SetTemplate(barContainer,
        db.barBgColorR, db.barBgColorG, db.barBgColorB, db.barBgColorA,
        borderColor[1], borderColor[2], borderColor[3], borderColor[4], borderSize)

    Shared.InsetBar(barContainer, bar, edge)
    bar:SetStatusBarTexture(texture)

    local red, green, blue = GetBaseBarColor(db)
    bar:SetStatusBarColor(red, green, blue)

    BUI.PowerPrediction.Restyle(bar._predict, texture, db.predictionColorR, db.predictionColorG, db.predictionColorB, db.predictionColorA)

    if db.lowPowerEnabled then lowPowerCurve = Shared.BuildLowPowerCurve(lowPowerCurve, db, red, green, blue) else lowPowerCurve = nil end

    barTexture = bar:GetStatusBarTexture()

    Pixel.ApplyFont(barText, db.barTextSize, font)
    barText:SetTextColor(db.barTextColorR, db.barTextColorG, db.barTextColorB)
    barText:ClearAllPoints()
    if db.barTextAbove then
        barText:SetPoint("BOTTOM", barContainer, "TOP", Pixel.Scale(db.barTextOffsetX), Pixel.Scale(2 + db.barTextOffsetY))
    else
        barText:SetPoint("CENTER", barContainer, "CENTER", Pixel.Scale(db.barTextOffsetX), Pixel.Scale(db.barTextOffsetY))
    end

    Shared.StyleTicks(bar, db, scaledBarWidth, scaledBarHeight, edge)

    frame:SetSize(scaledBarWidth, scaledBarHeight)
    local grabMargin = Shared.IsAnchoredFor(db) and 0 or Pixel.Scale(10)
    frame:SetHitRectInsets(-grabMargin, -grabMargin, -grabMargin, -grabMargin)
    if frame.dragLocked then frame:RefreshDragState() end
end

local function Build()
    if frame then return end

    frame = CreateFrame("Frame", "BUI_PowerBar", UIParent)
    frame:SetSize(Pixel.Scale(120), Pixel.Scale(50))
    frame:SetFrameStrata("MEDIUM")
    frame:Hide()
    frame:EnableMouse(true)
    local NotifyAnchorChange = BUI.Profiler.Wrap("Power.Power anchor notify", function()
        BUI.Anchor.OnAnchorSizeChanged()
    end)
    frame:HookScript("OnShow", NotifyAnchorChange)
    frame:HookScript("OnHide", NotifyAnchorChange)

    text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER")

    barContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    barContainer:SetPoint("CENTER")
    barContainer:Hide()

    bar = CreateFrame("StatusBar", nil, barContainer)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    bar._predict = BUI.PowerPrediction.Attach(bar, {
        active = false,
        enabled = function() return GetDB().showPrediction end,
        powerType = function() return (ClassPowers.GetPrimaryPowerType()) end,
    })

    textOverlay = CreateFrame("Frame", nil, barContainer)
    textOverlay:SetAllPoints(barContainer)
    textOverlay:SetFrameLevel(barContainer:GetFrameLevel() + 150)
    barText = textOverlay:CreateFontString(nil, "OVERLAY")
    barText:SetPoint("CENTER")

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
local styledFormID
local RESTYLE_ONLY_ON_TYPE_CHANGE = { UNIT_DISPLAYPOWER = true, UPDATE_SHAPESHIFT_FORM = true, UPDATE_SHAPESHIFT_FORMS = true }

local function OnStyleEvent(event)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and BUI.Power.GetScope() == 'spec' then return end
    local formID = GetShapeshiftFormID()
    if event == "UPDATE_SHAPESHIFT_FORM" and formID == styledFormID then return end
    styledFormID = formID
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
    if not RESTYLE_ONLY_ON_TYPE_CHANGE[event] or ClassPowers.GetPrimaryPowerType() ~= styledPowerType then Style() end
    UpdateDisplay()
    frame:SetShown(ShouldShow() and not ClassPowers.IsPrimaryHiddenForForm())
end

local function StartEvents()
    if eventsStarted then return end
    eventsStarted = true
    BUI.Events:RegisterUnit("UNIT_MAXPOWER", "player", "Power", UpdateDisplay)
    BUI.Events:RegisterUnit("UNIT_DISPLAYPOWER", "player", "Power", function() OnStyleEvent("UNIT_DISPLAYPOWER") end)
    BUI.Events:RegisterUnit("UNIT_POWER_FREQUENT", "player", "PowerLive", OnLivePower)
    BUI.Events:Register("PLAYER_ENTERING_WORLD", "Power", OnStyleEvent)
    BUI.Events:RegisterUnit("PLAYER_SPECIALIZATION_CHANGED", "player", "Power", OnStyleEvent)
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
    if frame then
        frame:Hide()
        BUI.PowerPrediction.SetActive(bar._predict, false)
    end
end

local function Activate()
    Build()
    StartEvents()
    StartOpacityEvents()
    styledFormID = GetShapeshiftFormID()
    Position()
    Style()
    UpdateDisplay()
    UpdateOpacity()
    local db = GetDB()
    BUI.PowerPrediction.SetActive(bar._predict, db.barMode and db.showPrediction)
    BUI.Dragging.SetLocked(frame, db.locked)
    frame:SetShown(not ClassPowers.IsPrimaryHiddenForForm())
end

local function OnAnchorSizeChanged()
    local db = GetDB()
    if not Shared.ShouldReanchor(frame, db) then return end
    Position()
    if BUI.Anchor.GetAnchorWidth(frame, db) ~= styledAnchorWidth then Style() end
end

function PrimaryPower.Initialize()
    Build()
    BUI.Anchor.RegisterCallback("PowerBar", OnAnchorSizeChanged)
    if ShouldShow() then Activate() end
    Pixel.OnScaleChange("PowerBar", function()
        if GetDB().enabled then
            Position()
            Style()
        end
    end)
end

function PrimaryPower.Apply()
    if not ShouldShow() then Shutdown() return end
    Activate()
end

function PrimaryPower.Toggle(on)
    GetDB().enabled = on
    PrimaryPower.Apply()
end

function PrimaryPower.SetLocked(locked)
    if not frame then return end
    local db = GetDB()
    db.locked = locked
    BUI.Dragging.SetLocked(frame, locked)
    BUI.NotifyModuleChange('powerBar')
end

BUI.Events:OnLogin("PowerBar", function()
    PrimaryPower.Initialize()
    Shared.DeferRefresh(function() return frame end, GetDB, function() Position() Style() end)
end, "power")
