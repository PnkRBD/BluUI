local _, BUI = ...
local SetScript = BUI.Prof.Scripts('Cursor.Cursor')

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
local hideOverMenus, hiddenOverMenu = false, false

local function GetConfig()
    return BUI.GetDB().cursor
end

local function SafeNumber(value)
    return Tools.SafeNum(value) or 0
end

local function SlotDiameter(slotConfig)
    local config = GetConfig()
    return math.max(MIN_DIAMETER, config.size + slotConfig.offset)
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
    SetScript(slot.cd, 'OnCooldownDone', function() slot.cd:Hide() end)
    slot.cd:Hide()

    return slot
end

local function ApplySlot(name)
    local slot = slots[name]
    local slotConfig = GetConfig().slots[name]

    slot.holder:SetFrameLevel(cursorFrame:GetFrameLevel() + slotConfig.zOrder)

    local diameter = Pixel.Scale(SlotDiameter(slotConfig))
    slot.tex:SetSize(diameter, diameter)
    slot.tex:SetVertexColor(slotConfig.colorR, slotConfig.colorG, slotConfig.colorB, slotConfig.alpha)
    slot.cd:SetSize(diameter, diameter)
    slot.cd:SetSwipeColor(slotConfig.colorR, slotConfig.colorG, slotConfig.colorB, slotConfig.alpha)

    slot.tex:Hide()
    slot.cd:Hide()

    slot.kind = (slotConfig.enabled and slotConfig.kind) or 'none'

    if slot.kind == 'static' then
        slot.tex:Show()
    elseif slot.kind == 'click' and clicking then
        slot.tex:Show()
    end
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
    local startTime, duration = SafeNumber(info.startTime), SafeNumber(info.duration)
    if startTime <= 0 or duration <= 0 then return end

    for _, name in ipairs(SLOT_NAMES) do
        local slot = slots[name]
        if slot.kind == 'gcd' then
            slot.cd:SetCooldown(startTime, duration)
            slot.cd:Show()
        end
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
        for _, name in ipairs(SLOT_NAMES) do
            local slot = slots[name]
            if slot.kind == 'cast' then slot.cd:Hide() end
        end
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

local function HideCastOnSlots()
    for _, name in ipairs(SLOT_NAMES) do
        local slot = slots[name]
        if slot.kind == 'cast' then slot.cd:Hide() end
    end
end

local function OverOwnWindow()
    local focus = GetMouseFoci()[1]
    while focus and focus ~= UIParent and focus ~= WorldFrame do
        if focus.IsForbidden and focus:IsForbidden() then return false end
        if focus.isBluUIWindow then return true end
        focus = focus:GetParent()
    end
    return false
end

local MENU_CHECK_INTERVAL = 0.1
local menuCheckElapsed = 0

local function FollowCursor(_, elapsed)
    local cursorX, cursorY = GetCursorPosition()
    if cursorX ~= lastX or cursorY ~= lastY then
        lastX, lastY = cursorX, cursorY
        cursorFrame:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', cursorX / screenScale, cursorY / screenScale)
    end
    if hideOverMenus then
        menuCheckElapsed = menuCheckElapsed + elapsed
        if menuCheckElapsed < MENU_CHECK_INTERVAL then return end
        menuCheckElapsed = 0
        local overMenu = OverOwnWindow()
        if overMenu ~= hiddenOverMenu then
            hiddenOverMenu = overMenu
            cursorFrame:SetAlpha(overMenu and 0 or 1)
        end
    end
end

local function SyncMenuHiding()
    hideOverMenus = GetConfig().hideOverMenus and true or false
    if not hideOverMenus and hiddenOverMenu then
        hiddenOverMenu = false
        cursorFrame:SetAlpha(1)
    end
end

local function OnMouseDown()
    if not enabled then return end
    clicking = true
    for _, name in ipairs(SLOT_NAMES) do
        local slot = slots[name]
        if slot.kind == 'click' then slot.tex:Show() end
    end
end

local function OnMouseUp()
    if not enabled then return end
    clicking = false
    for _, name in ipairs(SLOT_NAMES) do
        local slot = slots[name]
        if slot.kind == 'click' then slot.tex:Hide() end
    end
end

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
    SyncMenuHiding()
    lastX, lastY = nil, nil
    SetScript(cursorFrame, 'OnUpdate', FollowCursor)
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
    SetScript(cursorFrame, 'OnUpdate', nil)
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

    SetScript(cursorFrame, 'OnShow', WireCursor)
    SetScript(cursorFrame, 'OnHide', UnwireCursor)
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
    SyncMenuHiding()
    ConfigureKindEvents()
    if enabled then
        UpdateGCDSlots()
        ShowCastOnSlots()
    end
end

function MouseCursor.Initialize()
    local function SyncScale()
        screenScale = UIParent:GetEffectiveScale()
        lastX, lastY = nil, nil
    end
    SyncScale()
    BUI.Pixel.OnScaleChange('Cursor', SyncScale)
    Events:Register('UI_SCALE_CHANGED',     'Cursor:Scale', SyncScale)
    Events:Register('DISPLAY_SIZE_CHANGED', 'Cursor:Scale', SyncScale)
    MouseCursor.Refresh()
end

Events:OnLogin('Cursor', MouseCursor.Initialize)

BUI.RegisterModuleControl('cursor', function(enabled)
    if enabled then
        MouseCursor.Initialize()
    else
        MouseCursor.Refresh()
    end
end)
