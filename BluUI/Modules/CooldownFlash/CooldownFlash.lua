local _, BUI = ...

local CooldownFlash = {}
BUI.CooldownFlash = CooldownFlash

local Pixel = BUI.Pixel
local Tools = BUI.Tools
local LibCustomGlow = LibStub('LibCustomGlow-1.0')

local SETTINGS_KEY = 'cooldownFlash'
local FRAME_NAME = 'BUI_CooldownFlash'
local EVENT_KEY = 'CooldownFlash'
local GLOW_KEY = '_BUICooldownFlash'
local POLL_SECONDS = 0.1
local FADE_SECONDS = 0.4
local POP_SECONDS = 0.15
local POP_SCALE = 1.35
local ICON_CROP = 0.08

local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCharges = C_Spell.GetSpellCharges
local GetSpellTexture = C_Spell.GetSpellTexture
local GetSpellName = C_Spell.GetSpellName

local root
local pool, active, state = {}, {}, {}
local anchorCallback
local Release

local function GetConfig() return BUI.GetDB()[SETTINGS_KEY] end

local function ListKey()
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    if specID then return 'spec:' .. specID end
    local _, class = UnitClass('player')
    return 'class:' .. class
end

function CooldownFlash.GetSpells()
    local lists = GetConfig().specs
    local key = ListKey()
    lists[key] = lists[key] or {}
    return lists[key]
end

function CooldownFlash.ListLabel()
    local className = UnitClass('player')
    local specIndex = GetSpecialization()
    local _, specName = specIndex and GetSpecializationInfo(specIndex)
    return specName and (specName .. ' ' .. className) or className
end

function CooldownFlash.RegisterAnchorCallback(callback) anchorCallback = callback end

local function Known(value) return not Tools.IsSecretValue(value) end

local function ReadState(spellID)
    local charges = GetSpellCharges(spellID)
    if charges and Known(charges.currentCharges) and Known(charges.maxCharges) and charges.maxCharges > 1 then
        return charges.currentCharges < charges.maxCharges, charges.currentCharges
    end
    local info = GetSpellCooldown(spellID)
    if not info or not Known(info.isActive) or not Known(info.isOnGCD) then return nil end
    return info.isActive and not info.isOnGCD
end

local function AnyOnCooldown()
    for _, spellState in pairs(state) do
        if spellState.onCD then return true end
    end
    return false
end

local function Layout()
    local settings = GetConfig()
    local size, gap = Pixel.Scale(settings.iconSize), Pixel.Scale(settings.spacing)
    local shown = {}
    for _, spellID in ipairs(CooldownFlash.GetSpells()) do
        local slot = active[spellID]
        if slot then shown[#shown + 1] = slot end
    end
    local count = #shown
    root:SetSize(math.max(size, count * size + math.max(0, count - 1) * gap), size)
    for index, slot in ipairs(shown) do
        slot:SetSize(size, size)
        slot:ClearAllPoints()
        slot:SetPoint('LEFT', root, 'LEFT', (index - 1) * (size + gap), 0)
    end
    root:SetShown(count > 0 or settings.showAnchor)
end

local function StopGlow(slot)
    LibCustomGlow.ProcGlow_Stop(slot, GLOW_KEY)
    LibCustomGlow.PixelGlow_Stop(slot, GLOW_KEY)
end

local function StartGlow(slot, style)
    if style == 'proc' then
        LibCustomGlow.ProcGlow_Start(slot, { key = GLOW_KEY, startAnim = true })
    elseif style == 'pixel' then
        LibCustomGlow.PixelGlow_Start(slot, nil, 8, 0.25, nil, 2, 0, 0, true, GLOW_KEY)
    end
end

local function NewSlot()
    local slot = CreateFrame('Frame', nil, root)
    slot.icon = slot:CreateTexture(nil, 'ARTWORK')
    slot.icon:SetAllPoints()
    slot.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    Pixel.ApplyBorder(slot, 1, 0, 0, 0, 1)

    local fade = slot:CreateAnimationGroup()
    local hold = fade:CreateAnimation('Alpha')
    hold:SetOrder(1)
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    local out = fade:CreateAnimation('Alpha')
    out:SetOrder(2)
    out:SetFromAlpha(1)
    out:SetToAlpha(0)
    out:SetDuration(FADE_SECONDS)
    out:SetSmoothing('IN')
    fade:SetScript('OnFinished', function() Release(slot) end)
    slot.fade, slot.hold = fade, hold

    local pop = slot:CreateAnimationGroup()
    local scale = pop:CreateAnimation('Scale')
    scale:SetScaleFrom(POP_SCALE, POP_SCALE)
    scale:SetScaleTo(1, 1)
    scale:SetDuration(POP_SECONDS)
    scale:SetSmoothing('OUT')
    slot.pop = pop
    return slot
end

Release = function(slot)
    StopGlow(slot)
    slot.fade:Stop()
    slot:Hide()
    active[slot.spellID] = nil
    slot.spellID = nil
    pool[#pool + 1] = slot
    Layout()
end

local function ReleaseAll()
    for _, slot in pairs(active) do Release(slot) end
end

local function Show(spellID, seconds)
    local slot = active[spellID] or table.remove(pool) or NewSlot()
    active[spellID] = slot
    slot.spellID = spellID
    slot.icon:SetTexture(GetSpellTexture(spellID))
    slot.fade:Stop()
    slot:SetAlpha(1)
    slot:Show()
    Layout()
    StopGlow(slot)
    StartGlow(slot, GetConfig().glow)
    if seconds then
        slot.pop:Stop()
        slot.pop:Play()
        slot.hold:SetDuration(seconds)
        slot.fade:Play()
    end
end

local function Flash(spellID)
    local settings = GetConfig()
    Show(spellID, settings.holdSeconds)
    BUI.PlaySoundByName(settings.sound)
end

function CooldownFlash.FlashNow(spellID)
    if not root then return end
    Flash(spellID)
end

local function Evaluate(spellID, mayFlash)
    local onCD, charges = ReadState(spellID)
    if onCD == nil then return end
    local spellState = state[spellID]
    if not spellState then
        state[spellID] = { onCD = onCD, charges = charges }
        return
    end
    local ready = (charges and spellState.charges and charges > spellState.charges)
        or (not charges and spellState.onCD and not onCD)
    spellState.onCD, spellState.charges = onCD, charges
    if ready and mayFlash then Flash(spellID) end
end

local function Scan(mayFlash)
    for _, spellID in ipairs(CooldownFlash.GetSpells()) do Evaluate(spellID, mayFlash) end
    BUI.Scheduler.SetUpdateEnabled(EVENT_KEY, AnyOnCooldown())
end

local function OnCooldowns() Scan(true) end

local function Restart()
    wipe(state)
    ReleaseAll()
    Scan(false)
end

local watching = false

local function SyncEvents(wanted)
    if wanted == watching then return end
    watching = wanted
    if wanted then
        BUI.Events:Register('SPELL_UPDATE_COOLDOWN', EVENT_KEY, OnCooldowns)
        BUI.Events:Register('SPELL_UPDATE_CHARGES', EVENT_KEY, OnCooldowns)
        BUI.Events:Register('PLAYER_ENTERING_WORLD', EVENT_KEY, Restart)
        Restart()
    else
        BUI.Events:Unregister('SPELL_UPDATE_COOLDOWN', EVENT_KEY)
        BUI.Events:Unregister('SPELL_UPDATE_CHARGES', EVENT_KEY)
        BUI.Events:Unregister('PLAYER_ENTERING_WORLD', EVENT_KEY)
        wipe(state)
        ReleaseAll()
        BUI.Scheduler.SetUpdateEnabled(EVENT_KEY, false)
    end
end

local function BuildRoot()
    if root then return end
    root = CreateFrame('Frame', FRAME_NAME, UIParent)
    root:SetFrameStrata('HIGH')
    root:SetSize(1, 1)
    root:Hide()
    BUI.Dragging.MakeAnchoredAlert(root, {
        settings = GetConfig,
        isLocked = function() return not GetConfig().showAnchor end,
        onRightClick = function()
            GetConfig().showAnchor = false
            CooldownFlash.Refresh()
            if anchorCallback then anchorCallback() end
        end,
    })
end

function CooldownFlash.Refresh()
    local settings = GetConfig()
    BuildRoot()
    BUI.Anchor.ApplyPosition(root, settings)
    BUI.Dragging.SetLocked(root, not settings.showAnchor)
    SyncEvents(settings.enabled)
    if settings.showAnchor then
        for _, spellID in ipairs(CooldownFlash.GetSpells()) do Show(spellID) end
    else
        for spellID, slot in pairs(active) do
            if not slot.fade:IsPlaying() then Release(slot) end
        end
    end
    Layout()
end

function CooldownFlash.AddSpell(spellID)
    if not GetSpellName(spellID) then return false end
    local spells = CooldownFlash.GetSpells()
    for _, known in ipairs(spells) do
        if known == spellID then return false end
    end
    spells[#spells + 1] = spellID
    CooldownFlash.Refresh()
    return true
end

function CooldownFlash.RemoveSpell(spellID)
    local spells = CooldownFlash.GetSpells()
    for index = #spells, 1, -1 do
        if spells[index] == spellID then table.remove(spells, index) end
    end
    state[spellID] = nil
    local slot = active[spellID]
    if slot then Release(slot) end
    CooldownFlash.Refresh()
end

function CooldownFlash.ReorderSpells(ordered)
    local spells = CooldownFlash.GetSpells()
    wipe(spells)
    for index, spellID in ipairs(ordered) do spells[index] = spellID end
    Layout()
end

local function OnSpecChanged(_, unit)
    if unit ~= 'player' then return end
    CooldownFlash.Refresh()
    if watching then Restart() end
end

local function Initialize()
    BUI.Scheduler.RegisterUpdate(EVENT_KEY, OnCooldowns, POLL_SECONDS, false)
    BUI.Events:RegisterUnit('PLAYER_SPECIALIZATION_CHANGED', 'player', EVENT_KEY, OnSpecChanged)
    CooldownFlash.Refresh()
end

BUI.Events:OnLogin(EVENT_KEY, Initialize)

BUI.Anchor.Follow(EVENT_KEY, function()
    return GetConfig().enabled and root
end, GetConfig)
