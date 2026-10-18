local _, BUI = ...

local Pixel = BUI.Pixel

local DurabilityWarning = {}
BUI.Auras.DurabilityWarning = DurabilityWarning

local EVENT_KEY = 'DurabilityWarning'

local frame, text
local eventsLive = false
local previewing = false

local function GetDB() return BUI.GetDB().durabilityWarning end

local function Build()
    if frame then return end

    frame = CreateFrame('Frame', 'BUI_DurabilityWarning', UIParent)
    frame:SnapSize(200, 40)
    frame:SetFrameStrata('HIGH')
    frame:Hide()

    text = frame:CreateFontString(nil, 'OVERLAY')
    text:SetPoint('CENTER')

    BUI.Dragging.MakeAnchoredAlert(frame, {
        settings = GetDB,
        isLocked = function() return GetDB().locked end,
        onRightClick = function() DurabilityWarning.SetLocked(true) end,
    })
end

local function Update()
    local db = GetDB()
    local percent = BUI.Tools.LowestDurability()
    if not db.enabled or (db.locked and not previewing and percent > db.threshold) then
        frame:Hide()
        return
    end
    text:SetText(db.showPercent and ('%s %d%%'):format(db.text, percent) or db.text)
    frame:SnapSize(text:GetStringWidth() + 40, text:GetStringHeight() + 20)
    frame:Show()
end

local UpdateSoon = BUI.Dispatcher.New(Update, 'Auras.DurabilityWarning')

local function Apply()
    local db = GetDB()
    BUI.Anchor.ApplyPosition(frame, db)
    Pixel.ApplyFont(text, db.fontSize, BUI.GetModuleFont(db))
    local color = db.textColor
    text:SetTextColor(color.r, color.g, color.b, color.a)
    BUI.Dragging.SetLocked(frame, db.locked)
end

function DurabilityWarning.Refresh()
    if not GetDB().enabled then
        BUI.Events:UnregisterAll(EVENT_KEY)
        eventsLive = false
        if frame then frame:Hide() end
        return
    end

    Build()
    Apply()
    if not eventsLive then
        eventsLive = true
        BUI.Events:Register('UPDATE_INVENTORY_DURABILITY', EVENT_KEY, UpdateSoon)
        BUI.Events:Register('PLAYER_EQUIPMENT_CHANGED', EVENT_KEY, UpdateSoon)
    end
    Update()
end

function DurabilityWarning.SetPreview(on)
    previewing = on
    if frame then Update() end
end

function DurabilityWarning.SetLocked(locked)
    GetDB().locked = locked
    BUI.NotifyModuleChange('durabilityWarning')
    DurabilityWarning.Refresh()
end

BUI.Events:OnLogin(EVENT_KEY, DurabilityWarning.Refresh, 'auras')

BUI.Anchor.Follow(EVENT_KEY, function() return GetDB().enabled and frame end, GetDB)
