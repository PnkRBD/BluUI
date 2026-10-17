local _, BUI = ...

BUI.CombatRes = {}
local CombatRes = BUI.CombatRes
local Pixel = BUI.Pixel
local Tools = BUI.Tools

local REBIRTH = 20484
local ICON_GAP = 4
local PAD_X, PAD_Y = 10, 6
local PREVIEW_CHARGES, PREVIEW_REMAINING = 2, 272
local EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
    "ENCOUNTER_START", "ENCOUNTER_END", "SPELL_UPDATE_CHARGES",
}

local floor = math.floor

local frame, icon, text
local enabled = false
local previewing = false
local charges, readyAt

local function GetDB() return BUI.GetDB().combatRes end

local function PoolActive()
    local _, instanceType = IsInInstance()
    if instanceType == "raid" then return true end
    return instanceType == "party" and C_ChallengeMode.IsChallengeModeActive()
end

local function ReadCharges()
    charges, readyAt = nil, nil
    if not PoolActive() then return false end
    local info = C_Spell.GetSpellCharges(REBIRTH)
    if not info then return false end
    charges = Tools.SafeNum(info.currentCharges)
    if not charges then return false end
    local start, duration = Tools.SafeNum(info.cooldownStartTime), Tools.SafeNum(info.cooldownDuration)
    if info.isActive and start and duration and start > 0 then readyAt = start + duration end
    return true
end

local function TimerText(remaining)
    local seconds = floor(remaining + 0.5)
    return ("%d:%02d"):format(floor(seconds / 60), seconds % 60)
end

local function Paint(count, remaining)
    local db = GetDB()
    if remaining and db.showTimer ~= false then
        text:SetFormattedText("%d  %s", count, TimerText(remaining))
    else
        text:SetText(count)
    end
    local color = count == 0 and db.emptyColor or db.textColor
    text:SetTextColor(color.r, color.g, color.b)
    local width = text:GetStringWidth() + Pixel.Scale(PAD_X) * 2
    local height = text:GetStringHeight()
    if db.showIcon ~= false then
        local size = Pixel.Scale(db.fontSize + 6)
        width = width + size + Pixel.Scale(ICON_GAP)
        if size > height then height = size end
    end
    frame:SnapSize(width, height + Pixel.Scale(PAD_Y) * 2)
end

local function Tick()
    local remaining = readyAt and readyAt - GetTime()
    if remaining and remaining <= 0 then
        ReadCharges()
        remaining = readyAt and readyAt - GetTime()
        BUI.Scheduler.SetUpdateEnabled("CombatRes", readyAt ~= nil)
    end
    if not charges then
        frame:Hide()
        return
    end
    Paint(charges, remaining and remaining > 0 and remaining or nil)
end

local function Refresh()
    if not enabled then return end
    if previewing then
        BUI.Scheduler.SetUpdateEnabled("CombatRes", false)
        Paint(PREVIEW_CHARGES, PREVIEW_REMAINING)
        frame:Show()
        return
    end
    if not ReadCharges() then
        BUI.Scheduler.SetUpdateEnabled("CombatRes", false)
        frame:Hide()
        return
    end
    Tick()
    frame:Show()
    BUI.Scheduler.SetUpdateEnabled("CombatRes", readyAt ~= nil)
end

local Update = BUI.Dispatcher.New(Refresh, "Auras.CombatRes")

local function Build()
    if frame then return end
    frame = CreateFrame("Frame", "BUI_CombatRes", UIParent)
    frame:SnapSize(80, 40)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(C_Spell.GetSpellTexture(REBIRTH))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    text = frame:CreateFontString(nil, "OVERLAY")

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
    Pixel.ApplyFont(text, db.fontSize, BUI.GetModuleFont(db))
    local showIcon = db.showIcon ~= false
    local size = Pixel.Scale(db.fontSize + 6)
    icon:SetSize(size, size)
    icon:SetShown(showIcon)
    icon:ClearAllPoints()
    text:ClearAllPoints()
    if showIcon then
        icon:SetPoint("LEFT", frame, "LEFT", Pixel.Scale(PAD_X), 0)
        text:SetPoint("LEFT", icon, "RIGHT", Pixel.Scale(ICON_GAP), 0)
    else
        text:SetPoint("LEFT", frame, "LEFT", Pixel.Scale(PAD_X), 0)
    end
    BUI.Anchor.ApplyPosition(frame, db)
    Refresh()
end

function CombatRes.SetLocked(locked)
    local db = GetDB()
    db.locked = locked
    BUI.NotifyModuleChange("combatRes")
    if not frame then return end
    BUI.Dragging.SetLocked(frame, locked)
    if not enabled then return end
    previewing = not locked
    Refresh()
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
    BUI.Events:UnregisterAll("CombatRes")
    BUI.Scheduler.SetUpdateEnabled("CombatRes", false)
    if frame then frame:Hide() end
end

function CombatRes.Toggle(on)
    GetDB().enabled = on
    if on then CombatRes.Enable() else CombatRes.Disable() end
end

BUI.Anchor.Follow("CombatRes", function() return GetDB().enabled and frame end, GetDB)

BUI.Events:OnLogin("CombatRes", function()
    if GetDB().enabled then CombatRes.Enable() end
end, "auras")
