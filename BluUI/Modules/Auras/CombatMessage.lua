local _, BUI = ...

local Pixel = BUI.Pixel
BUI.CombatMessage = {}
local CombatMessage = BUI.CombatMessage

local messageFrame, messageText
local eventsWired = false

local function GetDB() return BUI.GetDB().combatMessage end


local function Apply()
    if not messageFrame or not messageText then return end
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

    Apply()

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

local function ShowPreview(inCombat)
    if not messageText then return end
    PaintForState(inCombat)
    messageFrame:SetAlpha(1)
    messageFrame:Show()
end

local function Flash(inCombat)
    local db = GetDB()
    if not db.enabled or not messageFrame then return end

    UIFrameFadeRemoveFrame(messageFrame)

    local token = (messageFrame._flashToken or 0) + 1
    messageFrame._flashToken = token

    PaintForState(inCombat)
    messageFrame:SetAlpha(1)
    messageFrame:Show()

    C_Timer.After(db.fadeTime, function()
        if not messageFrame or messageFrame._flashToken ~= token then return end
        UIFrameFadeOut(messageFrame, 0.4, 1, 0)
        C_Timer.After(0.5, function()
            if messageFrame and messageFrame._flashToken == token then
                messageFrame:Hide()
            end
        end)
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
        ShowPreview(true)
        BUI.Dragging.SetLocked(messageFrame, false)
    end
end

function CombatMessage.SetLocked(locked)
    local db = GetDB()
    db.locked = locked

    if CombatMessage._lockToggle and CombatMessage._lockToggle.SetValue then
        CombatMessage._lockToggle:SetValue(not locked)
    end

    if not db.enabled then return end

    Build()
    Apply()
    BUI.Dragging.SetLocked(messageFrame, locked)

    if locked then
        messageFrame:Hide()
    else
        ShowPreview(true)
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
        ShowPreview(true)
    end
end

function CombatMessage.Initialize()
    if GetDB().enabled then CombatMessage.Enable() end
end

BUI.Events:OnLogin("CombatMessage", CombatMessage.Initialize, "auras")

BUI.Anchor.Follow("CombatMessage", function() return GetDB().enabled and messageFrame end, GetDB)
