local _, BUI = ...

local Events = BUI.Events
local Tools  = BUI.Tools
local Pixel  = BUI.Pixel
local RING_TEXTURE = BUI.C.CURSOR_RING_TEXTURE

local GCD_SPELL = 61304
local SLOT_NAMES = { 'inner', 'main', 'outer' }
local MIN_DIAMETER = 4

local CAST_START_EVENTS = { 'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_DELAYED', 'UNIT_SPELLCAST_CHANNEL_START', 'UNIT_SPELLCAST_CHANNEL_UPDATE' }
local CAST_STOP_EVENTS  = { 'UNIT_SPELLCAST_STOP', 'UNIT_SPELLCAST_INTERRUPTED', 'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_CHANNEL_STOP' }

local MouseCursor = {}
BUI.MouseCursor = MouseCursor

local cursorFrame
local slots = {}
local enabled, clicking = false, false
local screenScale = 1
local lastX, lastY

local function GetConfig()
    return BUI.GetDB().cursor
end

function MouseCursor.SlotDiameter(slotConfig)
    return Pixel.Scale(math.max(MIN_DIAMETER, GetConfig().size + slotConfig.offset))
end

local function CreateSlot(parent)
    local slot = { kind = 'none' }

    slot.holder = CreateFrame('Frame', nil, parent)
    slot.holder:SetAllPoints()

    slot.tex = slot.holder:CreateTexture(nil, 'OVERLAY')
    slot.tex:SetTexture(RING_TEXTURE)
    slot.tex:SetPoint('CENTER')
    slot.tex:Hide()

    slot.cd = CreateFrame('Cooldown', nil, slot.holder)
    slot.cd:SetPoint('CENTER')
    slot.cd:SetSwipeTexture(RING_TEXTURE)
    slot.cd:SetReverse(true)
    slot.cd:SetDrawSwipe(true)
    slot.cd:SetDrawEdge(false)
    slot.cd:SetDrawBling(false)
    slot.cd:SetHideCountdownNumbers(true)
    slot.cd:SetScript('OnCooldownDone', BUI.Profiler.Wrap('Cursor.Cursor cooldown done', function() slot.cd:Hide() end))
    slot.cd:Hide()

    return slot
end

local function StyleSlot(name)
    local slot = slots[name]
    local slotConfig = GetConfig().slots[name]
    slot.holder:SetFrameLevel(cursorFrame:GetFrameLevel() + slotConfig.zOrder)
    local diameter = MouseCursor.SlotDiameter(slotConfig)
    slot.tex:SetSize(diameter, diameter)
    slot.tex:SetVertexColor(slotConfig.colorR, slotConfig.colorG, slotConfig.colorB, slotConfig.alpha)
    slot.cd:SetSize(diameter, diameter)
    slot.cd:SetSwipeColor(slotConfig.colorR, slotConfig.colorG, slotConfig.colorB, slotConfig.alpha)
end

local function ApplySlot(name)
    StyleSlot(name)
    local slot = slots[name]
    local slotConfig = GetConfig().slots[name]
    slot.kind = (slotConfig.enabled and slotConfig.kind) or 'none'
    slot.tex:SetShown(slot.kind == 'static' or (slot.kind == 'click' and clicking))
    slot.cd:Hide()
end

local function HasSlotKind(kind)
    for _, name in ipairs(SLOT_NAMES) do
        if slots[name].kind == kind then return true end
    end
    return false
end

local function UpdateGCDSlots()
    local info = C_Spell.GetSpellCooldown(GCD_SPELL)
    if not info then return end
    local startTime, duration = Tools.SafeNum(info.startTime), Tools.SafeNum(info.duration)
    if not startTime or not duration or startTime <= 0 or duration <= 0 then return end

    for _, name in ipairs(SLOT_NAMES) do
        local slot = slots[name]
        if slot.kind == 'gcd' then
            slot.cd:SetCooldown(startTime, duration)
            slot.cd:Show()
        end
    end
end

local function HideCastOnSlots()
    for _, name in ipairs(SLOT_NAMES) do
        local slot = slots[name]
        if slot.kind == 'cast' then slot.cd:Hide() end
    end
end

local function ShowCastOnSlots()
    local _, _, _, startMilliseconds, endMilliseconds = UnitCastingInfo('player')
    local channeling = false
    if not startMilliseconds then
        _, _, _, startMilliseconds, endMilliseconds = UnitChannelInfo('player')
        channeling = startMilliseconds ~= nil
    end

    if not startMilliseconds or not endMilliseconds then
        HideCastOnSlots()
        return
    end

    local startTime = startMilliseconds / 1000
    local duration  = (endMilliseconds - startMilliseconds) / 1000
    if duration <= 0 then return end

    for _, name in ipairs(SLOT_NAMES) do
        local slot = slots[name]
        if slot.kind == 'cast' then
            slot.cd:SetCooldown(startTime, duration)
            slot.cd:SetReverse(not channeling)
            slot.cd:Show()
        end
    end
end

local FollowCursor = BUI.Profiler.Hot('Cursor.Cursor follow', function()
    local cursorX, cursorY = GetCursorPosition()
    if cursorX ~= lastX or cursorY ~= lastY then
        lastX, lastY = cursorX, cursorY
        cursorFrame:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', cursorX / screenScale, cursorY / screenScale)
    end
end)

local function SetClicking(down)
    clicking = down
    for _, name in ipairs(SLOT_NAMES) do
        local slot = slots[name]
        if slot.kind == 'click' then slot.tex:SetShown(down) end
    end
end

local function OnMouseDown() SetClicking(true) end
local function OnMouseUp() SetClicking(false) end

local QueueGCDUpdate = BUI.Dispatcher.New(UpdateGCDSlots, 'Cursor.GCD')

local function ConfigureKindEvents()
    if enabled and HasSlotKind('gcd') then
        Events:Register('SPELL_UPDATE_COOLDOWN', 'Cursor:GCD', QueueGCDUpdate)
    else
        Events:Unregister('SPELL_UPDATE_COOLDOWN', 'Cursor:GCD')
    end

    local castEnabled = enabled and HasSlotKind('cast')
    for _, event in ipairs(CAST_START_EVENTS) do
        if castEnabled then Events:RegisterUnit(event, 'player', 'Cursor:Cast', ShowCastOnSlots)
        else Events:Unregister(event, 'Cursor:Cast') end
    end
    for _, event in ipairs(CAST_STOP_EVENTS) do
        if castEnabled then Events:RegisterUnit(event, 'player', 'Cursor:Cast', HideCastOnSlots)
        else Events:Unregister(event, 'Cursor:Cast') end
    end
end

local function WireCursor()
    enabled = true
    lastX, lastY = nil, nil
    cursorFrame:SetScript('OnUpdate', FollowCursor)
    for _, name in ipairs(SLOT_NAMES) do ApplySlot(name) end
    Events:Register('GLOBAL_MOUSE_DOWN', 'Cursor:Down', OnMouseDown)
    Events:Register('GLOBAL_MOUSE_UP',   'Cursor:Up',   OnMouseUp)
    ConfigureKindEvents()
    UpdateGCDSlots()
    ShowCastOnSlots()
end

local function UnwireCursor()
    enabled  = false
    clicking = false
    cursorFrame:SetScript('OnUpdate', nil)
    for _, name in ipairs(SLOT_NAMES) do
        local slot = slots[name]
        slot.tex:Hide(); slot.cd:Hide()
    end
    Events:Unregister('GLOBAL_MOUSE_DOWN', 'Cursor:Down')
    Events:Unregister('GLOBAL_MOUSE_UP',   'Cursor:Up')
    ConfigureKindEvents()
end

local function Build()
    if cursorFrame then return end

    cursorFrame = CreateFrame('Frame', nil, UIParent)
    cursorFrame:SetFrameStrata('HIGH')
    cursorFrame:SetFrameLevel(100)
    cursorFrame:SetSize(1, 1)
    cursorFrame:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', 0, 0)
    cursorFrame:Hide()

    for _, name in ipairs(SLOT_NAMES) do
        slots[name] = CreateSlot(cursorFrame)
    end

    cursorFrame:SetScript('OnShow', BUI.Profiler.Wrap('Cursor.Cursor wire', WireCursor))
    cursorFrame:SetScript('OnHide', BUI.Profiler.Wrap('Cursor.Cursor unwire', UnwireCursor))
end

local function ShowCursor()
    Build()
    if cursorFrame:IsShown() then WireCursor() else cursorFrame:Show() end
end

local function HideCursor()
    if not cursorFrame then return end
    if cursorFrame:IsShown() then cursorFrame:Hide() elseif enabled then UnwireCursor() end
end

local function ModuleEnabled()
    return BUI.IsModuleEnabled('cursor')
end

local driverActive = false

local function ApplyCombatDriver()
    local shouldDrive = (ModuleEnabled() and GetConfig().combatOnly) or false
    if shouldDrive == driverActive then return end
    driverActive = shouldDrive
    if shouldDrive then
        Build()
        RegisterStateDriver(cursorFrame, 'visibility', '[combat] show; hide')
    else
        UnregisterStateDriver(cursorFrame, 'visibility')
    end
end

local function ConfigureCombatDriver()
    if InCombatLockdown() then
        Events:AfterCombat(function()
            ApplyCombatDriver()
            MouseCursor.Refresh()
        end, 'Cursor:CombatDriver')
        return
    end
    ApplyCombatDriver()
end

function MouseCursor.Refresh()
    local config = GetConfig()
    if not ModuleEnabled() then
        ConfigureCombatDriver()
        HideCursor()
        return
    end

    Build()
    ConfigureCombatDriver()
    if config.combatOnly then
        if InCombatLockdown() then
            ShowCursor()
        elseif cursorFrame:IsShown() then
            WireCursor()
        end
    else
        ShowCursor()
    end
end

function MouseCursor.Apply()
    if not cursorFrame then return end
    for _, name in ipairs(SLOT_NAMES) do ApplySlot(name) end
    ConfigureKindEvents()
    if enabled then
        UpdateGCDSlots()
        ShowCastOnSlots()
    end
end

function MouseCursor.Restyle()
    if not cursorFrame then return end
    for _, name in ipairs(SLOT_NAMES) do StyleSlot(name) end
end

local function SyncScale()
    screenScale = UIParent:GetEffectiveScale()
    lastX, lastY = nil, nil
end
Pixel.OnScaleChange('Cursor', SyncScale)

function MouseCursor.Initialize()
    SyncScale()
    MouseCursor.Refresh()
end

Events:OnLogin('Cursor', MouseCursor.Initialize, 'cursor')
BUI.RegisterModuleControl('cursor', MouseCursor.Initialize)
