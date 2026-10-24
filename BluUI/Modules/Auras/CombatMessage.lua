local _, BUI = ...

local Pixel = BUI.Pixel
BUI.CombatMessage = {}
local CombatMessage = BUI.CombatMessage

local FADE_OUT = 0.4

local messageFrame, messageText
local eventsWired = false
local flashToken = 0

local function GetDB() return BUI.GetDB().combatMessage end

local function Apply()
    local db = GetDB()
    BUI.Anchor.ApplyPosition(messageFrame, db)
    Pixel.ApplyFont(messageText, db.fontSize, BUI.GetModuleFont(db))
end

local function Build()
    if messageFrame then return end

    messageFrame = CreateFrame("Frame", "BUI_CombatMessage", UIParent)
    messageFrame:SnapSize(120, 30)
    messageFrame:SetFrameStrata("HIGH")
    messageFrame:Hide()

    messageText = messageFrame:CreateFontString(nil, "OVERLAY")
    messageText:SetPoint("CENTER")

    BUI.Dragging.MakeAnchoredAlert(messageFrame, {
        settings = GetDB,
        isLocked = function() return GetDB().locked end,
        onRightClick = function() CombatMessage.SetLocked(true) end,
    })
end

local function PaintForState(inCombat)
    local db = GetDB()
    local color = inCombat and db.enterColor or db.leaveColor
    messageText:SetText(inCombat and "+ Combat" or "- Combat")
    messageText:SetTextColor(color[1], color[2], color[3], color[4])
end

local function ShowPreview()
    UIFrameFadeRemoveFrame(messageFrame)
    PaintForState(true)
    messageFrame:SetAlpha(1)
    messageFrame:Show()
end

local function HideMessage()
    messageFrame:Hide()
end

local function Flash(inCombat)
    UIFrameFadeRemoveFrame(messageFrame)
    flashToken = flashToken + 1
    local token = flashToken

    PaintForState(inCombat)
    messageFrame:SetAlpha(1)
    messageFrame:Show()

    C_Timer.After(GetDB().fadeTime, function()
        if flashToken ~= token then return end
        UIFrameFade(messageFrame, { mode = "OUT", timeToFade = FADE_OUT, startAlpha = 1, endAlpha = 0, finishedFunc = HideMessage })
    end)
end

local function WireEvents()
    if eventsWired then return end
    eventsWired = true
    local function OnEvent(event) Flash(event == "PLAYER_REGEN_DISABLED") end
    BUI.Events:Register("PLAYER_REGEN_DISABLED", "CombatMessage", OnEvent)
    BUI.Events:Register("PLAYER_REGEN_ENABLED",  "CombatMessage", OnEvent)
end

function CombatMessage.Disable()
    BUI.Events:UnregisterAll("CombatMessage")
    eventsWired = false
    if messageFrame then messageFrame:Hide() end
end

function CombatMessage.Enable()
    Build()
    WireEvents()
    Apply()
    if not GetDB().locked then
        ShowPreview()
        BUI.Dragging.SetLocked(messageFrame, false)
    end
end

function CombatMessage.SetLocked(locked)
    local db = GetDB()
    db.locked = locked
    BUI.NotifyModuleChange('combatMessage')

    if not db.enabled then return end

    Build()
    Apply()
    BUI.Dragging.SetLocked(messageFrame, locked)

    if locked then
        messageFrame:Hide()
    else
        ShowPreview()
    end
end

function CombatMessage.Refresh()
    local db = GetDB()
    if not db.enabled then
        CombatMessage.Disable()
        return
    end

    Build()
    Apply()
    BUI.Dragging.SetLocked(messageFrame, db.locked)

    if messageFrame:IsShown() and not db.locked then
        ShowPreview()
    end
end

function CombatMessage.Initialize()
    if GetDB().enabled then CombatMessage.Enable() end
end

BUI.Events:OnLogin("CombatMessage", CombatMessage.Initialize, "auras")

BUI.Anchor.Follow("CombatMessage", function() return GetDB().enabled and messageFrame end, GetDB)
