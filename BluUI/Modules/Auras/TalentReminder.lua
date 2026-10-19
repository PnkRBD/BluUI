local _, BUI = ...

local Pixel = BUI.Pixel

local TalentReminder = {}
BUI.Auras.TalentReminder = TalentReminder

local EVENT_KEY = 'TalentReminder'
local FADE_OUT = 0.4
local HEADLINE = 'Check Talents'
local BUILD_FORMAT = HEADLINE .. ' (%s - %s)'

local frame, text
local showToken = 0

local function GetDB() return BUI.GetDB().talentReminder end

local function Build()
    if frame then return end

    frame = CreateFrame('Frame', 'BUI_TalentReminder', UIParent)
    frame:SnapSize(300, 40)
    frame:SetFrameStrata('HIGH')
    frame:Hide()

    text = frame:CreateFontString(nil, 'OVERLAY')
    text:SetPoint('CENTER')

    BUI.Dragging.MakeAnchoredAlert(frame, {
        settings = GetDB,
        isLocked = function() return GetDB().locked end,
        onRightClick = function() TalentReminder.SetLocked(true) end,
    })
end

local function Message()
    local specIndex = C_SpecializationInfo.GetSpecialization()
    if not specIndex then return HEADLINE end
    local specID, specName = C_SpecializationInfo.GetSpecializationInfo(specIndex)
    if not specID then return HEADLINE end
    return BUILD_FORMAT:format(specName, BUI.Tools.ActiveLoadoutName(specID))
end

local function Fit()
    frame:SnapSize(text:GetStringWidth() + 40, text:GetStringHeight() + 20)
end

local function Paint()
    text:SetText(Message())
    Fit()
    UIFrameFadeRemoveFrame(frame)
    frame:SetAlpha(1)
    frame:Show()
end

local function HideReminder()
    frame:Hide()
end

local function AllowedHere(db)
    local _, instanceType = IsInInstance()
    if instanceType == 'raid' then return db.inRaids end
    if instanceType == 'party' then return db.inDungeons end
    return db.elsewhere
end

local function Remind()
    if not GetDB().locked or not AllowedHere(GetDB()) then return end
    Paint()
    showToken = showToken + 1
    local token = showToken
    BUI.Profiler.After('Auras.TalentReminder fade out', GetDB().duration, function()
        if showToken ~= token or not GetDB().locked then return end
        UIFrameFade(frame, { mode = 'OUT', timeToFade = FADE_OUT, startAlpha = 1, endAlpha = 0, finishedFunc = HideReminder })
    end)
end

local function OnEnteringWorld(_, isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi or not IsInInstance() then return end
    Remind()
end

local function WireEvents(db)
    BUI.Events:UnregisterAll(EVENT_KEY)
    if db.onReadyCheck then BUI.Events:Register('READY_CHECK', EVENT_KEY, Remind) end
    if db.onCountdown then BUI.Events:Register('START_PLAYER_COUNTDOWN', EVENT_KEY, Remind) end
    if db.onInstance then BUI.Events:Register('PLAYER_ENTERING_WORLD', EVENT_KEY, OnEnteringWorld) end
end

local function Apply()
    local db = GetDB()
    BUI.Anchor.ApplyPosition(frame, db)
    Pixel.ApplyFont(text, db.fontSize, BUI.GetModuleFont(db))
    local color = db.textColor
    text:SetTextColor(color.r, color.g, color.b, color.a)
    BUI.Dragging.SetLocked(frame, db.locked)
end

function TalentReminder.Refresh()
    local db = GetDB()
    if not db.enabled then
        BUI.Events:UnregisterAll(EVENT_KEY)
        if frame then frame:Hide() end
        return
    end

    Build()
    Apply()
    WireEvents(db)
    if not db.locked then
        showToken = showToken + 1
        Paint()
    elseif frame:IsShown() then
        Fit()
    end
end

function TalentReminder.SetLocked(locked)
    GetDB().locked = locked
    BUI.NotifyModuleChange('talentReminder')
    if locked and frame then frame:Hide() end
    TalentReminder.Refresh()
end

BUI.Events:OnLogin(EVENT_KEY, TalentReminder.Refresh, 'auras')

BUI.Anchor.Follow(EVENT_KEY, function() return GetDB().enabled and frame end, GetDB)
