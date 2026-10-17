local _, BUI = ...

BUI.CombatRes = {}
local CombatRes = BUI.CombatRes
local Pixel = BUI.Pixel
local Tools = BUI.Tools

local REBIRTH = 20484
local GLOW_KEY = "CombatRes"
local GLOW_SECONDS = 2
local TEXT_MARGIN = 2
local PREVIEW_CHARGES, PREVIEW_REMAINING, PREVIEW_DURATION = 1, 272, 600
local EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
    "ENCOUNTER_START", "ENCOUNTER_END", "SPELL_UPDATE_CHARGES",
}

local floor = math.floor

local frame, tile, icon, cooldown, timerText, chargesText
local enabled = false
local previewing = false
local charges, rechargeStart, rechargeDuration, readyAt
local shownCharges
local Update

local function GetDB() return BUI.GetDB().combatRes end

local function PoolActive()
    local _, instanceType = IsInInstance()
    if instanceType == "raid" then return true end
    return instanceType == "party" and C_ChallengeMode.IsChallengeModeActive()
end

local function ReadCharges()
    charges, rechargeStart, rechargeDuration, readyAt = nil, nil, nil, nil
    if not PoolActive() then return false end
    local info = C_Spell.GetSpellCharges(REBIRTH)
    if not info then return false end
    charges = Tools.SafeNum(info.currentCharges)
    if not charges then return false end
    local start, duration = Tools.SafeNum(info.cooldownStartTime), Tools.SafeNum(info.cooldownDuration)
    if info.isActive and start and duration and start > 0 and start + duration > GetTime() then
        rechargeStart, rechargeDuration, readyAt = start, duration, start + duration
    end
    return true
end

local function LoadPreview()
    charges = PREVIEW_CHARGES
    rechargeDuration = PREVIEW_DURATION
    rechargeStart = GetTime() - (PREVIEW_DURATION - PREVIEW_REMAINING)
    readyAt = rechargeStart + rechargeDuration
end

local function TimerText(remaining)
    local seconds = floor(remaining + 0.5)
    return ("%d:%02d"):format(floor(seconds / 60), seconds % 60)
end

local function Tick()
    local remaining = readyAt and readyAt - GetTime()
    if remaining and remaining <= 0 then
        timerText:Hide()
        Update()
        return
    end
    local show = remaining ~= nil and GetDB().showTimer
    timerText:SetShown(show)
    if show then timerText:SetText(TimerText(remaining)) end
end

local function Paint()
    local db = GetDB()
    local empty = charges == 0
    local color = empty and db.emptyColor or db.textColor
    icon:SetDesaturated(empty)
    chargesText:SetText(charges)
    chargesText:SetTextColor(color.r, color.g, color.b)
    if rechargeStart and db.showIcon and db.showSwipe then
        cooldown:SetCooldown(rechargeStart, rechargeDuration)
    else
        cooldown:Clear()
    end
end

local function PlaceText(fontString, placement, offsetX, offsetY)
    local point, relativePoint, x, y, justify = Tools.ResolvePlacement(placement, TEXT_MARGIN, TEXT_MARGIN)
    fontString:ClearAllPoints()
    fontString:SetPoint(point, tile, relativePoint, Pixel.Scale(x + offsetX), Pixel.Scale(y + offsetY))
    fontString:SetJustifyH(justify)
end

local function StopGlow()
    BUI.GlowManager.Stop(tile, "proc", GLOW_KEY)
end

local function FlashGlow()
    BUI.GlowManager.Start(tile, "proc", nil, 100, nil, nil, GLOW_KEY, nil, nil, true)
    BUI.Profiler.After("Auras.CombatRes glow", GLOW_SECONDS, StopGlow)
end

local function Refresh()
    if not enabled then return end
    local active = true
    if previewing then LoadPreview() else active = ReadCharges() end
    if not active then
        shownCharges = nil
        BUI.Scheduler.SetUpdateEnabled("CombatRes", false)
        frame:Hide()
        return
    end
    if not previewing and shownCharges and charges > shownCharges and GetDB().glowOnCharge then FlashGlow() end
    shownCharges = not previewing and charges or nil
    Paint()
    Tick()
    frame:Show()
    BUI.Scheduler.SetUpdateEnabled("CombatRes", readyAt ~= nil)
end

Update = BUI.Dispatcher.New(Refresh, "Auras.CombatRes")

local function Build()
    if frame then return end
    frame = CreateFrame("Frame", "BUI_CombatRes", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    tile = CreateFrame("Frame", nil, frame)
    tile:SetPoint("TOP")

    icon = tile:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(C_Spell.GetSpellTexture(REBIRTH))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    cooldown = CreateFrame("Cooldown", nil, tile, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetSwipeColor(0, 0, 0, 0.65)

    local overlay = CreateFrame("Frame", nil, tile)
    overlay:SetAllPoints(tile)
    overlay:SetFrameLevel(cooldown:GetFrameLevel() + 2)

    timerText = overlay:CreateFontString(nil, "OVERLAY")
    chargesText = overlay:CreateFontString(nil, "OVERLAY")

    BUI.Dragging.MakeAnchoredAlert(frame, {
        settings = GetDB,
        isLocked = function() return GetDB().locked end,
        onRightClick = function() CombatRes.SetLocked(true) end,
    })

    BUI.Scheduler.RegisterUpdate("CombatRes", Tick, 1, false)
end

function CombatRes.ApplySettings()
    if not frame then return end
    local db = GetDB()
    local font = BUI.GetModuleFont(db)
    local size = Pixel.Scale(db.size)
    local border = db.borderColor

    frame:SetSize(size, size)
    tile:SetSize(size, size)
    Pixel.ApplyBorder(tile, 1, border.r, border.g, border.b, db.showIcon and 1 or 0)
    local edge = Pixel.GetBorderSize(tile)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", tile, "TOPLEFT", edge, -edge)
    icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -edge, edge)
    icon:SetShown(db.showIcon)

    Pixel.ApplyFont(timerText, db.timerSize, font)
    Pixel.ApplyFont(chargesText, db.chargesSize, font)
    timerText:SetTextColor(db.textColor.r, db.textColor.g, db.textColor.b)
    PlaceText(timerText, db.timerPosition, db.timerOffsetX, db.timerOffsetY)
    PlaceText(chargesText, db.chargesPosition, db.chargesOffsetX, db.chargesOffsetY)
    chargesText:SetShown(db.showCharges)

    BUI.Anchor.ApplyPosition(frame, db)
    Refresh()
end

function CombatRes.SetLocked(locked)
    local db = GetDB()
    db.locked = locked
    BUI.NotifyModuleChange("combatRes")
    if db.enabled then CombatRes.Enable() end
end

function CombatRes.Enable()
    enabled = true
    Build()
    local db = GetDB()
    previewing = not db.locked
    BUI.Dragging.SetLocked(frame, db.locked)
    for eventIndex = 1, #EVENTS do
        BUI.Events:Register(EVENTS[eventIndex], "CombatRes", Update)
    end
    CombatRes.ApplySettings()
end

function CombatRes.Disable()
    enabled = false
    previewing = false
    shownCharges = nil
    BUI.Events:UnregisterAll("CombatRes")
    BUI.Scheduler.SetUpdateEnabled("CombatRes", false)
    if frame then
        StopGlow()
        frame:Hide()
    end
end

function CombatRes.Toggle(on)
    GetDB().enabled = on
    if on then CombatRes.Enable() else CombatRes.Disable() end
end

BUI.Anchor.Follow("CombatRes", function() return GetDB().enabled and frame end, GetDB)

BUI.Events:OnLogin("CombatRes", function()
    if GetDB().enabled then CombatRes.Enable() end
end, "auras")
