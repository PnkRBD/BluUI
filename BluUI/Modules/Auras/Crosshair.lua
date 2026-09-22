local _, BUI = ...

local Pixel = BUI.Pixel
BUI.Crosshair = {}
local Crosshair = BUI.Crosshair

local MELEE_YARDS = 8
local RANGED_FALLBACK_YARDS = 40
local RANGED_CAP_YARDS = 60
local RANGE_TICK = 0.1

local crosshairFrame
local rangeTicker
local previewing = false
local RefreshRangeTicker

local function GetDB() return BUI.GetDB().crosshair end

Crosshair.MELEE_SPEC_IDS = {
    [250] = true, [251] = true, [252] = true,
    [577] = true, [581] = true,
    [103] = true, [104] = true,
    [255] = true,
    [268] = true, [269] = true,
    [66]  = true, [70]  = true,
    [259] = true, [260] = true, [261] = true,
    [263] = true,
    [71]  = true, [72]  = true, [73]  = true,
}

function Crosshair.IsMeleeSpec()
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    return specID ~= nil and Crosshair.MELEE_SPEC_IDS[specID] == true
end

local rangedLimit
local function RangedLimit()
    if rangedLimit then return rangedLimit end
    local rangeCheck = LibStub('LibRangeCheck-3.0')
    local best
    for range in rangeCheck:GetHarmCheckersNoItems() do
        if range <= RANGED_CAP_YARDS and (not best or range > best) then best = range end
    end
    rangedLimit = best or RANGED_FALLBACK_YARDS
    return rangedLimit
end

local function InvalidateRangedLimit() rangedLimit = nil end

function Crosshair.RangeLimit()
    if Crosshair.IsMeleeSpec() then return MELEE_YARDS, true end
    return RangedLimit(), false
end

function Crosshair.RangeLabel()
    local limit, melee = Crosshair.RangeLimit()
    if melee then return 'melee' end
    return ('%d yd'):format(limit)
end

local function IsTargetInRange()
    local minYards, maxYards = BUI.Range.SpellBracket("target")
    if minYards == nil then return nil end
    local limit = Crosshair.RangeLimit()
    if maxYards and maxYards <= limit then return true end
    if minYards >= limit then return false end
    return nil
end

local function PaintAll(red, green, blue, alpha)
    BUI.Tools.SetColorTex(crosshairFrame.left,  red, green, blue, alpha)
    BUI.Tools.SetColorTex(crosshairFrame.right, red, green, blue, alpha)
    BUI.Tools.SetColorTex(crosshairFrame.top,   red, green, blue, alpha)
    BUI.Tools.SetColorTex(crosshairFrame.bot,   red, green, blue, alpha)
    BUI.Tools.SetColorTex(crosshairFrame.leftBG,  0, 0, 0, alpha)
    BUI.Tools.SetColorTex(crosshairFrame.rightBG, 0, 0, 0, alpha)
    BUI.Tools.SetColorTex(crosshairFrame.topBG,   0, 0, 0, alpha)
    BUI.Tools.SetColorTex(crosshairFrame.botBG,   0, 0, 0, alpha)
end

local lastPaintState

local function UpdateColor()
    if not crosshairFrame:IsShown() then return end
    local db = GetDB()
    local alpha = db.alpha

    if db.rangeIndicator then
        if IsTargetInRange() == true then
            if lastPaintState == 'in' then return end
            lastPaintState = 'in'
            local color = db.inRangeColor
            PaintAll(color[1], color[2], color[3], alpha)
        else
            if lastPaintState == 'out' then return end
            lastPaintState = 'out'
            local color = db.outOfRangeColor
            PaintAll(color[1], color[2], color[3], alpha)
        end
    else
        lastPaintState = nil
        PaintAll(db.colorR, db.colorG, db.colorB, alpha)
    end
end

local function IsSpecAllowed()
    local db = GetDB()
    if not db.specs then return true end
    if not next(db.specs) then return false end
    local specIndex = GetSpecialization()
    if not specIndex then return true end
    return db.specs[GetSpecializationInfo(specIndex)] == true
end

local function UpdateVisibility()
    local db = GetDB()

    local show = db.enabled and IsSpecAllowed()
    if show and db.hideOutOfCombat and not InCombatLockdown() then show = false end
    if show and db.hideInTown and not IsInInstance() and IsResting() then show = false end
    if previewing then show = true end

    if show then
        crosshairFrame:Show()
        UpdateColor()
    else
        crosshairFrame:Hide()
    end
    RefreshRangeTicker()
end

local function PlaceSegment(segment, shadow, width, height, anchor, offsetX, offsetY)
    segment:SetSize(width, height)
    segment:ClearAllPoints()
    segment:SetPoint(anchor, crosshairFrame, "CENTER", offsetX or 0, offsetY or 0)
    segment:Show()

    local padding = Pixel.PixelSize(1)
    shadow:SetSize(width + padding * 2, height + padding * 2)
    shadow:ClearAllPoints()
    shadow:SetPoint("CENTER", segment, "CENTER")
    shadow:Show()
end

local function HideAllSegments()
    crosshairFrame.left:Hide();    crosshairFrame.leftBG:Hide()
    crosshairFrame.right:Hide();   crosshairFrame.rightBG:Hide()
    crosshairFrame.top:Hide();     crosshairFrame.topBG:Hide()
    crosshairFrame.bot:Hide();     crosshairFrame.botBG:Hide()
end

local function ApplyStyle()
    local db = GetDB()

    local size      = Pixel.Scale(db.size)
    local thickness = Pixel.Scale(db.thickness)
    local gap       = Pixel.Scale(db.gap)

    crosshairFrame:SetSize(size * 2, size * 2)
    crosshairFrame:ClearAllPoints()
    crosshairFrame:SetPoint("CENTER", UIParent, "CENTER", Pixel.Scale(db.offsetX), Pixel.Scale(db.offsetY))

    HideAllSegments()

    if db.style == "dot" then
        PlaceSegment(crosshairFrame.left, crosshairFrame.leftBG, thickness * 2, thickness * 2, "CENTER")
    elseif gap > 0 then
        local segmentLength = Pixel.Snap((size * 2 - gap) / 2)
        local halfGap = Pixel.PixelSize(gap / 2)
        PlaceSegment(crosshairFrame.left,  crosshairFrame.leftBG,  segmentLength, thickness, "RIGHT",  -halfGap, 0)
        PlaceSegment(crosshairFrame.right, crosshairFrame.rightBG, segmentLength, thickness, "LEFT",    halfGap, 0)
        PlaceSegment(crosshairFrame.top,   crosshairFrame.topBG,   thickness, segmentLength, "BOTTOM",  0,  halfGap)
        PlaceSegment(crosshairFrame.bot,   crosshairFrame.botBG,   thickness, segmentLength, "TOP",     0, -halfGap)
    else
        PlaceSegment(crosshairFrame.left, crosshairFrame.leftBG, size * 2, thickness, "CENTER")
        PlaceSegment(crosshairFrame.top,  crosshairFrame.topBG,  thickness, size * 2, "CENTER")
    end
end

local function Build()
    if crosshairFrame then return end

    crosshairFrame = CreateFrame("Frame", "BUI_Crosshair", UIParent)
    crosshairFrame:SetFrameStrata("BACKGROUND")
    crosshairFrame:SetFrameLevel(1)

    crosshairFrame.leftBG  = crosshairFrame:CreateTexture(nil, "BACKGROUND")
    crosshairFrame.rightBG = crosshairFrame:CreateTexture(nil, "BACKGROUND")
    crosshairFrame.topBG   = crosshairFrame:CreateTexture(nil, "BACKGROUND")
    crosshairFrame.botBG   = crosshairFrame:CreateTexture(nil, "BACKGROUND")

    crosshairFrame.left  = crosshairFrame:CreateTexture(nil, "ARTWORK")
    crosshairFrame.right = crosshairFrame:CreateTexture(nil, "ARTWORK")
    crosshairFrame.top   = crosshairFrame:CreateTexture(nil, "ARTWORK")
    crosshairFrame.bot   = crosshairFrame:CreateTexture(nil, "ARTWORK")

    BUI.Events:Register("PLAYER_REGEN_ENABLED",          "Crosshair", UpdateVisibility)
    BUI.Events:Register("PLAYER_REGEN_DISABLED",         "Crosshair", UpdateVisibility)
    BUI.Events:Register("PLAYER_UPDATE_RESTING",         "Crosshair", UpdateVisibility)
    BUI.Events:Register("ZONE_CHANGED_NEW_AREA",         "Crosshair", UpdateVisibility)
    BUI.Events:Register("PLAYER_SPECIALIZATION_CHANGED", "Crosshair", function()
        InvalidateRangedLimit()
        UpdateVisibility()
    end)
    BUI.Events:Register("SPELLS_CHANGED", "Crosshair", InvalidateRangedLimit)
    local rangeCheck = LibStub('LibRangeCheck-3.0')
    rangeCheck.RegisterCallback(Crosshair, rangeCheck.CHECKERS_CHANGED, InvalidateRangedLimit)
    BUI.Events:Register("PLAYER_TARGET_CHANGED",         "Crosshair", function()
        UpdateColor()
        RefreshRangeTicker()
    end)
end

local function StopRangeTicker()
    if rangeTicker then
        rangeTicker:Cancel()
        rangeTicker = nil
    end
end

local function StartRangeTicker()
    if not rangeTicker then
        rangeTicker = BUI.Prof.NewTicker('Auras.Crosshair', RANGE_TICK, BUI.Prof.Wrap('tick#CrosshairRange', UpdateColor))
    end
end

RefreshRangeTicker = function()
    local db = GetDB()
    if (db.enabled or previewing) and db.rangeIndicator
        and crosshairFrame and crosshairFrame:IsShown() and UnitExists("target") then
        StartRangeTicker()
    else
        StopRangeTicker()
    end
end

function Crosshair.Refresh()
    Build()
    ApplyStyle()
    lastPaintState = nil
    UpdateVisibility()
end

function Crosshair.SetPreview(show)
    previewing = show and true or false
    Crosshair.Refresh()
end

function Crosshair.IsPreviewing() return previewing end

BUI.Events:OnLogin("Crosshair", Crosshair.Refresh)
Pixel.OnScaleChange("Crosshair", Crosshair.Refresh)
