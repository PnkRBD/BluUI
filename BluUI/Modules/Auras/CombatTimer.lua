local _, BUI = ...

BUI.CombatTimer = {}
local CombatTimer = BUI.CombatTimer
local Pixel = BUI.Pixel

local timerFrame, timerText
local startTime = 0
local enabled = false
local inCombat = false

local groupWatchActive = false

local floor = math.floor

local PLAIN_TEMPLATES = { minutes = "88:88", hours = "88:88:88" }
local MILLISECOND_TEMPLATES = { minutes = "88:88.8", hours = "88:88:88.8" }

local function GetDB() return BUI.GetDB().combatTimer end


local lastShownStep = -1
local currentLayoutKey

local function ShowMilliseconds() return GetDB().showMilliseconds == true end

local function TemplatesFor(showMilliseconds)
    return showMilliseconds and MILLISECOND_TEMPLATES or PLAIN_TEMPLATES
end

local function MeasureWidth(template)
    if not timerText or not timerText:GetFont() then return 0 end
    local previousText = timerText:GetText()
    timerText:SetText(template)
    local width = timerText:GetStringWidth()
    timerText:SetText(previousText or "")
    return width
end

local function ApplyLayout(showMilliseconds, useHours)
    if not timerFrame or not timerText then return end

    local layoutKey = (showMilliseconds and "milliseconds" or "plain") .. (useHours and "hours" or "minutes")
    if layoutKey == currentLayoutKey then return end

    local templates = TemplatesFor(showMilliseconds)
    local reservedWidth = MeasureWidth(templates.hours)
    local tierWidth = MeasureWidth(useHours and templates.hours or templates.minutes)

    timerText:ClearAllPoints()
    timerText:SetJustifyH("LEFT")
    timerText:SetPoint("LEFT", timerFrame, "CENTER", -(tierWidth / 2), 0)

    if reservedWidth > 0 and tierWidth > 0 then
        timerFrame:SnapSize(reservedWidth + 40, timerText:GetStringHeight() + 20)
        currentLayoutKey = layoutKey
    end
end

local function ShowIdleText()
    if not timerText or not timerText:GetFont() then return end
    local showMilliseconds = ShowMilliseconds()
    ApplyLayout(showMilliseconds, false)
    timerText:SetText(showMilliseconds and "00:00.0" or "00:00")
end

local function Tick()
    if not inCombat or not timerText or not timerText:GetFont() then return end

    local showMilliseconds = ShowMilliseconds()
    local elapsed = GetTime() - startTime
    if elapsed < 0 then elapsed = 0 end

    local step = showMilliseconds and floor(elapsed * 10) or floor(elapsed)
    if step == lastShownStep then return end
    lastShownStep = step

    local totalSeconds = floor(elapsed)
    local hours = floor(totalSeconds / 3600)
    local minutes = hours > 0 and floor((totalSeconds % 3600) / 60) or floor(totalSeconds / 60)
    local seconds = totalSeconds % 60

    ApplyLayout(showMilliseconds, hours > 0)

    if showMilliseconds then
        local tenths = floor(elapsed * 10) % 10
        if hours > 0 then
            timerText:SetFormattedText("%02d:%02d:%02d.%d", hours, minutes, seconds, tenths)
        else
            timerText:SetFormattedText("%02d:%02d.%d", minutes, seconds, tenths)
        end
    elseif hours > 0 then
        timerText:SetFormattedText("%02d:%02d:%02d", hours, minutes, seconds)
    else
        timerText:SetFormattedText("%02d:%02d", minutes, seconds)
    end
end

local function Build()
    if timerFrame then return end

    local db = GetDB()
    timerFrame = CreateFrame("Frame", "BUI_CombatTimer", UIParent)
    timerFrame:SnapSize(80, 40)
    timerFrame:SetPoint("CENTER", UIParent, "CENTER", db.posX, db.posY)
    timerFrame:SetFrameStrata("HIGH")
    timerFrame:Hide()

    timerText = timerFrame:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(timerText, db.fontSize, BUI.GetGlobalFont())

    timerFrame.TimerText = timerText

    ShowIdleText()

    BUI.Dragging.MakeDraggable(timerFrame, {
        showHint = true,
        showUnlockedBg = true,
        hintAnchor = "TOP",
        onPositionChanged = function(x, y)
            local currentDB = GetDB()
            local anchorX, anchorY = BUI.Anchor.SaveDragOffsets(timerFrame, currentDB)
            if anchorX then
                currentDB.anchorOffsetX = math.floor(anchorX)
                currentDB.anchorOffsetY = math.floor(anchorY)
                BUI.Anchor.ApplyPosition(timerFrame, currentDB)
                return
            end
            currentDB.posX = math.floor(x)
            currentDB.posY = math.floor(y)
        end,
        onRightClick = function() CombatTimer.SetLocked(true) end,
        usePointPosition = false,
    })

    BUI.Scheduler.RegisterUpdate("CombatTimer", Tick, 0.1, false)
end

function CombatTimer.ApplySettings()
    if not timerFrame or not timerText then return end

    local db = GetDB()
    local moduleFont = BUI.GetModuleFont(db)
    Pixel.ApplyFont(timerText, db.fontSize, moduleFont)
    timerText:SetTextColor(db.colorR, db.colorG, db.colorB)
    BUI.Anchor.ApplyPosition(timerFrame, db)

    local showMilliseconds = ShowMilliseconds()
    BUI.Scheduler.RegisterUpdate("CombatTimer", Tick, showMilliseconds and 0.05 or 0.1, inCombat)

    BUI.Prof.After('Auras.CombatTimer', 0, function()
        if not timerFrame or not timerText then return end
        currentLayoutKey = nil
        lastShownStep = -1
        if inCombat then Tick() else ShowIdleText() end
    end)
end

function CombatTimer.SetLocked(locked)
    local db = GetDB()
    db.locked = locked

    if CombatTimer._lockToggle then
        CombatTimer._lockToggle:SetValue(not locked)
    end

    if not timerFrame then return end

    BUI.Dragging.SetLocked(timerFrame, locked)

    if not enabled then return end

    if locked then
        if not inCombat then timerFrame:Hide() end
    else
        ShowIdleText()
        timerFrame:Show()
    end
end

local IsGroupInCombat = BUI.Tools.IsGroupInCombat

local StopWatchingGroup

local function FinalizeEndCombat()
    StopWatchingGroup()
    inCombat = false
    BUI.Scheduler.SetUpdateEnabled("CombatTimer", false)
    ShowIdleText()
    if timerFrame then
        if GetDB().locked then timerFrame:Hide() else timerFrame:Show() end
    end
end

local function OnGroupCombatSignal(event, unit)
    if InCombatLockdown() then
        StopWatchingGroup()
        return
    end

    if event == "UNIT_FLAGS" and unit then
        if unit ~= "player" and not unit:match("^party%d") and not unit:match("^raid%d+") then
            return
        end
    end
    if not IsGroupInCombat() then
        FinalizeEndCombat()
    end
end

local GROUP_WATCH_UNITS = (function()
    local units = { 'player' }
    for partyIndex = 1, 4 do units[#units + 1] = 'party' .. partyIndex end
    for raidIndex = 1, 40 do units[#units + 1] = 'raid' .. raidIndex end
    return units
end)()

local function StartWatchingGroup()
    if groupWatchActive then return end
    groupWatchActive = true
    BUI.Events:RegisterUnit("UNIT_FLAGS", GROUP_WATCH_UNITS, "CombatTimer.GroupWatch", OnGroupCombatSignal)
    BUI.Events:Register("PLAYER_DEAD",         "CombatTimer.GroupWatch", OnGroupCombatSignal)
    BUI.Events:Register("GROUP_ROSTER_UPDATE", "CombatTimer.GroupWatch", OnGroupCombatSignal)
    OnGroupCombatSignal()
end

StopWatchingGroup = function()
    if not groupWatchActive then return end
    groupWatchActive = false
    BUI.Events:Unregister("UNIT_FLAGS",          "CombatTimer.GroupWatch")
    BUI.Events:Unregister("PLAYER_DEAD",         "CombatTimer.GroupWatch")
    BUI.Events:Unregister("GROUP_ROSTER_UPDATE", "CombatTimer.GroupWatch")
end

function CombatTimer.StartCombat()
    if not enabled then return end
    Build()

    if not inCombat then
        startTime = GetTime()
        lastShownStep = -1
        ShowIdleText()
    end
    StopWatchingGroup()
    inCombat = true
    BUI.Scheduler.SetUpdateEnabled("CombatTimer", true)
    timerFrame:Show()
end

function CombatTimer.EndCombat()
    if IsInGroup() and IsGroupInCombat() then
        StartWatchingGroup()
        return
    end
    FinalizeEndCombat()
end

function CombatTimer.Clear()
    FinalizeEndCombat()
end

function CombatTimer.Enable()
    enabled = true
    Build()
    CombatTimer.ApplySettings()

    BUI.Dragging.SetLocked(timerFrame, GetDB().locked)
    BUI.Scheduler.SetUpdateEnabled("CombatTimer", inCombat)

    BUI.Events:Register("PLAYER_REGEN_DISABLED", "CombatTimer", function() CombatTimer.StartCombat() end)
    BUI.Events:Register("PLAYER_REGEN_ENABLED",  "CombatTimer", function() CombatTimer.EndCombat() end)
    BUI.Events:Register("ENCOUNTER_END",         "CombatTimer", function() CombatTimer.Clear() end)
    if GetDB().locked and not inCombat then
        timerFrame:Hide()
    else
        ShowIdleText()
        timerFrame:Show()
    end
end

function CombatTimer.Disable()
    enabled = false
    inCombat = false
    StopWatchingGroup()
    BUI.Events:Unregister("PLAYER_REGEN_DISABLED", "CombatTimer")
    BUI.Events:Unregister("PLAYER_REGEN_ENABLED",  "CombatTimer")
    BUI.Events:Unregister("ENCOUNTER_END",         "CombatTimer")
    BUI.Scheduler.SetUpdateEnabled("CombatTimer", false)
    if timerFrame then timerFrame:Hide() end
end

function CombatTimer.Toggle(enabledFlag)
    GetDB().enabled = enabledFlag
    if enabledFlag then CombatTimer.Enable() else CombatTimer.Disable() end
end

BUI.Events:OnLogin("CombatTimer", function()
    if GetDB().enabled then CombatTimer.Enable() end
end)
