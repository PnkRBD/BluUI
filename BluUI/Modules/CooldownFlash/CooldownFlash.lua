local _, BUI = ...

local CooldownFlash = {}
BUI.CooldownFlash = CooldownFlash

local Pixel = BUI.Pixel
local Tools = BUI.Tools

local SETTINGS_KEY = 'cooldownFlash'
local FRAME_NAME = 'BUI_CooldownFlash'
local EVENT_KEY = 'CooldownFlash'
local POLL_SECONDS = 0.1
local FADE_SECONDS = 0.4
local POP_SECONDS = 0.15
local POP_SCALE = 1.35
local ICON_CROP = 0.08
local SWEEP_SECONDS = 0.5
local SWEEP_PAUSE = 1.2
local SWEEP_WIDTH = 0.45
local SWEEP_ALPHA = 0.8
local GLOW_RINGS = { 0.7, 0.4, 0.18 }
local GLOW_RING_PIXELS = 2
local GLOW_PULSE_SECONDS = 0.6
local GLOW_PULSE_LOW = 0.35
local TEXT_GAP = 4
local SPACING = 6
local ANCHOR_SIZE = 48

local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCharges = C_Spell.GetSpellCharges
local GetSpellTexture = C_Spell.GetSpellTexture
local GetSpellName = C_Spell.GetSpellName

local root
local pool, active, state = {}, {}, {}
local tracked, scan = {}, nil
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
    if not specIndex then return className end
    local _, specName = GetSpecializationInfo(specIndex)
    return specName .. ' ' .. className
end

function CooldownFlash.RegisterAnchorCallback(callback) anchorCallback = callback end

local function NewEntry(spellID)
    return {
        id = spellID,
        enabled = true,
        size = 48,
        holdSeconds = 2.5,
        color = { 1, 1, 1 },
        opacity = 100,
        glow = 'both',
        showIcon = true,
        text = '',
        showText = false,
        font = BUI.C.GLOBAL_OPTION,
        textSize = 14,
        textColor = { r = 1, g = 1, b = 1, a = 1 },
        sound = 'None',
        tts = false,
        ttsText = '',
    }
end

local function MigrateLists()
    for _, list in pairs(GetConfig().specs) do
        for index, entry in ipairs(list) do
            if type(entry) == 'number' then
                list[index] = NewEntry(entry)
            else
                for key, value in pairs(NewEntry(entry.id)) do
                    if entry[key] == nil then entry[key] = value end
                end
                if entry.sound == 'default' then entry.sound = 'None' end
                if entry.glow == true then entry.glow = 'both' elseif entry.glow == false then entry.glow = 'none' end
            end
        end
    end
end

local function EntryFor(spellID)
    for _, entry in ipairs(CooldownFlash.GetSpells()) do
        if entry.id == spellID then return entry end
    end
end

local function Known(value) return not Tools.IsSecretValue(value) end

local function BuffShowing(spellID)
    local entry = scan.GetEntry(spellID)
    return entry ~= nil and scan.FrameHasAura(entry)
end

local function ReadState(spellID)
    local charges = GetSpellCharges(spellID)
    if charges and Known(charges.currentCharges) and Known(charges.maxCharges) and charges.maxCharges > 1 then
        return charges.currentCharges < charges.maxCharges, charges.currentCharges
    end
    local info = GetSpellCooldown(spellID)
    if not info or not Known(info.isActive) or not Known(info.isOnGCD) then return nil end
    return (info.isActive and not info.isOnGCD) or BuffShowing(spellID)
end

local function AnyBusy()
    for _, spellState in pairs(state) do
        if spellState.busy then return true end
    end
    return false
end

local function BeamHalf(beam, side)
    local half = beam:CreateTexture(nil, 'OVERLAY')
    half:SetColorTexture(1, 1, 1, 1)
    half:SetBlendMode('ADD')
    half:SetPoint('TOP' .. side)
    half:SetPoint('BOTTOM' .. side)
    return half
end

local function NewSweep(slot, body)
    local clip = CreateFrame('Frame', nil, body)
    clip:SetAllPoints()
    clip:SetClipsChildren(true)
    local beam = CreateFrame('Frame', nil, clip)
    slot.lead = BeamHalf(beam, 'LEFT')
    slot.trail = BeamHalf(beam, 'RIGHT')
    local sweep = beam:CreateAnimationGroup()
    local slide = sweep:CreateAnimation('Translation')
    slide:SetDuration(SWEEP_SECONDS)
    slide:SetSmoothing('IN_OUT')
    slide:SetEndDelay(SWEEP_PAUSE)
    sweep:SetLooping('REPEAT')
    slot.clip, slot.beam, slot.slide, slot.sweep = clip, beam, slide, sweep
end

local function NewGlow(slot, body)
    local halo = CreateFrame('Frame', nil, body)
    halo:SetFrameLevel(slot:GetFrameLevel())
    halo:SetAllPoints()
    local rings = {}
    for index = 1, #GLOW_RINGS do
        local ring = CreateFrame('Frame', nil, halo)
        ring:SetFrameLevel(halo:GetFrameLevel())
        rings[index] = ring
    end
    local pulse = halo:CreateAnimationGroup()
    local dim = pulse:CreateAnimation('Alpha')
    dim:SetOrder(1)
    dim:SetFromAlpha(1)
    dim:SetToAlpha(GLOW_PULSE_LOW)
    dim:SetDuration(GLOW_PULSE_SECONDS)
    dim:SetSmoothing('IN_OUT')
    local lift = pulse:CreateAnimation('Alpha')
    lift:SetOrder(2)
    lift:SetFromAlpha(GLOW_PULSE_LOW)
    lift:SetToAlpha(1)
    lift:SetDuration(GLOW_PULSE_SECONDS)
    lift:SetSmoothing('IN_OUT')
    pulse:SetLooping('REPEAT')
    slot.halo, slot.rings, slot.pulse = halo, rings, pulse
end

local function Fit(slot, size)
    local width = size * SWEEP_WIDTH
    slot.beam:SetSize(width, size)
    slot.beam:SetPoint('CENTER', slot.clip, 'LEFT', -width / 2, 0)
    slot.lead:SetWidth(width / 2)
    slot.trail:SetWidth(width / 2)
    slot.slide:SetOffset(size + width, 0)
    for index, ring in ipairs(slot.rings) do
        local reach = Pixel.PixelSizeFor(ring, GLOW_RING_PIXELS * index)
        ring:SetPoint('TOPLEFT', slot.body, 'TOPLEFT', -reach, reach)
        ring:SetPoint('BOTTOMRIGHT', slot.body, 'BOTTOMRIGHT', reach, -reach)
    end
end

local function Style(slot, entry)
    local red, green, blue = entry.color[1], entry.color[2], entry.color[3]
    local body, showIcon, glow = slot.body, entry.showIcon, entry.glow
    local sweeping = showIcon and (glow == 'both' or glow == 'sweep')
    local ringing = showIcon and (glow == 'both' or glow == 'ring')
    body:SetAlpha(entry.opacity / 100)
    slot.icon:SetShown(showIcon)
    if showIcon then Pixel.ShowBorder(body) else Pixel.HideBorder(body) end
    slot.clip:SetShown(sweeping)
    slot.lead:SetGradient('HORIZONTAL', CreateColor(red, green, blue, 0), CreateColor(red, green, blue, SWEEP_ALPHA))
    slot.trail:SetGradient('HORIZONTAL', CreateColor(red, green, blue, SWEEP_ALPHA), CreateColor(red, green, blue, 0))
    for index, ring in ipairs(slot.rings) do
        Pixel.ApplyBorder(ring, GLOW_RING_PIXELS, red, green, blue, GLOW_RINGS[index])
    end
    slot.halo:SetShown(ringing)
    if ringing then slot.pulse:Play() else slot.pulse:Stop() end

    local label, color = slot.label, entry.textColor
    Pixel.ApplyFont(label, entry.textSize, BUI.GetModuleFont(entry), BUI.GetFontOutline())
    label:SetText(entry.text ~= '' and entry.text or GetSpellName(entry.id))
    label:SetTextColor(color.r, color.g, color.b, color.a)
    label:ClearAllPoints()
    if showIcon then
        label:SetPoint('TOP', body, 'BOTTOM', 0, -Pixel.Scale(TEXT_GAP))
    else
        label:SetPoint('CENTER', body, 'CENTER', 0, 0)
    end
    label:SetShown(entry.showText)
end

local function Layout()
    local gap, least = Pixel.Scale(SPACING), Pixel.Scale(ANCHOR_SIZE)
    local x, height, count = 0, 0, 0
    for _, entry in ipairs(CooldownFlash.GetSpells()) do
        local slot = active[entry.id]
        if slot then
            local size = Pixel.Scale(entry.size)
            slot:SetSize(size, size)
            Fit(slot, size)
            slot:ClearAllPoints()
            slot:SetPoint('LEFT', root, 'LEFT', x, 0)
            x = x + size + gap
            height = math.max(height, size)
            count = count + 1
        end
    end
    root:SetSize(math.max(x - gap, least), math.max(height, least))
    root:SetShown(count > 0 or GetConfig().showAnchor)
end

local function NewSlot()
    local slot = CreateFrame('Frame', nil, root)
    local body = CreateFrame('Frame', nil, slot)
    body:SetAllPoints()
    slot.body = body
    slot.icon = body:CreateTexture(nil, 'ARTWORK')
    slot.icon:SetAllPoints()
    slot.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    Pixel.ApplyBorder(body, 1, 0, 0, 0, 1)
    NewSweep(slot, body)
    NewGlow(slot, body)
    slot.label = body:CreateFontString(nil, 'OVERLAY')
    slot.label:SetJustifyH('CENTER')

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
    fade:SetScript('OnFinished', function()
        if GetConfig().showAnchor then slot.enter:Play() else Release(slot) end
    end)
    slot.fade, slot.hold = fade, hold

    local enter = slot:CreateAnimationGroup()
    local appear = enter:CreateAnimation('Alpha')
    appear:SetFromAlpha(0)
    appear:SetToAlpha(1)
    appear:SetDuration(POP_SECONDS)
    appear:SetSmoothing('OUT')
    local scale = enter:CreateAnimation('Scale')
    scale:SetScaleFrom(POP_SCALE, POP_SCALE)
    scale:SetScaleTo(1, 1)
    scale:SetDuration(POP_SECONDS)
    scale:SetSmoothing('OUT')
    slot.enter = enter

    local exit = slot:CreateAnimationGroup()
    local vanish = exit:CreateAnimation('Alpha')
    vanish:SetFromAlpha(1)
    vanish:SetToAlpha(0)
    vanish:SetDuration(FADE_SECONDS)
    vanish:SetSmoothing('IN')
    exit:SetScript('OnFinished', function() Release(slot) end)
    slot.exit = exit
    return slot
end

Release = function(slot)
    slot.sweep:Stop()
    slot.pulse:Stop()
    slot.fade:Stop()
    slot.enter:Stop()
    slot:Hide()
    active[slot.spellID] = nil
    slot.spellID = nil
    pool[#pool + 1] = slot
    Layout()
end

local function Dismiss(slot)
    if slot.exit:IsPlaying() then return end
    slot.fade:Stop()
    slot.enter:Stop()
    slot.exit:Play()
end

local function DismissAll()
    for _, slot in pairs(active) do Dismiss(slot) end
end

local function Show(entry, seconds)
    local spellID = entry.id
    local slot = active[spellID]
    local fresh = slot == nil
    if fresh then
        slot = table.remove(pool) or NewSlot()
        active[spellID] = slot
        slot.spellID = spellID
    end
    slot.icon:SetTexture(GetSpellTexture(spellID))
    Style(slot, entry)
    slot.exit:Stop()
    slot.fade:Stop()
    slot:SetAlpha(1)
    slot:Show()
    Layout()
    slot.sweep:Stop()
    slot.sweep:Play()
    if fresh or seconds then
        slot.enter:Stop()
        slot.enter:Play()
    end
    if seconds then
        slot.hold:SetDuration(seconds)
        slot.fade:Play()
    end
end

local function Announce(entry)
    BUI.PlaySoundByName(entry.sound)
    if entry.tts then BUI.TTS.Speak(entry.ttsText ~= '' and entry.ttsText or GetSpellName(entry.id)) end
end
CooldownFlash.Announce = Announce

local function Flash(entry)
    Show(entry, entry.holdSeconds)
    Announce(entry)
end

function CooldownFlash.FlashNow(spellID)
    local entry = root and EntryFor(spellID)
    if entry then Flash(entry) end
end

local function Evaluate(entry, mayFlash)
    local spellID = entry.id
    local busy, charges = ReadState(spellID)
    if busy == nil then return end
    local spellState = state[spellID]
    if not spellState then
        state[spellID] = { busy = busy, charges = charges }
        return
    end
    local ready = (charges and spellState.charges and charges > spellState.charges)
        or (not charges and spellState.busy and not busy)
    spellState.busy, spellState.charges = busy, charges
    if ready and mayFlash then Flash(entry) end
end

local function Scan(mayFlash)
    for _, entry in ipairs(CooldownFlash.GetSpells()) do
        if entry.enabled then Evaluate(entry, mayFlash) end
    end
    BUI.Scheduler.SetUpdateEnabled(EVENT_KEY, AnyBusy())
end

local function OnCooldowns() Scan(true) end

local function SyncTracked()
    wipe(tracked)
    for _, entry in ipairs(CooldownFlash.GetSpells()) do
        if entry.enabled then tracked[entry.id] = true else state[entry.id] = nil end
    end
    scan.ScheduleRebuild()
end

local function Restart()
    wipe(state)
    DismissAll()
    SyncTracked()
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
        DismissAll()
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
    if watching then SyncTracked() end
    for _, entry in ipairs(CooldownFlash.GetSpells()) do
        local slot = active[entry.id]
        if settings.showAnchor and entry.enabled then
            Show(entry)
        elseif slot and not slot.fade:IsPlaying() then
            Dismiss(slot)
        end
    end
    Layout()
end

function CooldownFlash.AddSpell(spellID)
    if not GetSpellName(spellID) or EntryFor(spellID) then return false end
    local spells = CooldownFlash.GetSpells()
    spells[#spells + 1] = NewEntry(spellID)
    CooldownFlash.Refresh()
    return true
end

function CooldownFlash.RemoveSpell(spellID)
    local spells = CooldownFlash.GetSpells()
    for index = #spells, 1, -1 do
        if spells[index].id == spellID then table.remove(spells, index) end
    end
    state[spellID] = nil
    local slot = active[spellID]
    if slot then Dismiss(slot) end
    CooldownFlash.Refresh()
end

function CooldownFlash.ReorderSpells(ordered)
    local spells = CooldownFlash.GetSpells()
    wipe(spells)
    for index, entry in ipairs(ordered) do spells[index] = entry end
    Layout()
end

local function OnSpecChanged(_, unit)
    if unit ~= 'player' then return end
    CooldownFlash.Refresh()
    if watching then Restart() end
end

local function UpdateOpacity()
    root:SetAlpha((BUI.Visibility.GetContextualOpacity(EVENT_KEY) or 100) / 100)
end

local function Initialize()
    MigrateLists()
    scan = BUI.BuffTracking.NewCDMScan(tracked, function()
        if watching then Scan(false) end
    end)
    BUI.Scheduler.RegisterUpdate(EVENT_KEY, OnCooldowns, POLL_SECONDS, false)
    BUI.Events:RegisterUnit('PLAYER_SPECIALIZATION_CHANGED', 'player', EVENT_KEY, OnSpecChanged)
    CooldownFlash.Refresh()
    BUI.Visibility.Register(EVENT_KEY, UpdateOpacity, true)
end

BUI.Events:OnLogin(EVENT_KEY, Initialize)

BUI.Anchor.Follow(EVENT_KEY, function()
    return GetConfig().enabled and root
end, GetConfig)
