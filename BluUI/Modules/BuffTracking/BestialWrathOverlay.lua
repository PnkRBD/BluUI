local _, BUI = ...
local Pixel = BUI.Pixel

local BestialWrathOverlay = {}
BUI.BuffTracking.BestialWrathOverlay = BestialWrathOverlay

local SETTINGS_KEY = 'bestialWrathOverlay'
local SCREEN_FRAME_NAME = 'BUI_BestialWrathCallout'
local BESTIAL_WRATH = 19574
local WILD_THRASH = 1264359
local WILD_THRASH_IDS = { [1264359] = true, [1264355] = true }
local WILD_THRASH_COOLDOWN = 8
local BEAST_CLEAVE_SECONDS = 10
local THRASH_PROMPT_SECONDS = 2
local READY_WINDOW = 1.6
local HOLD_THRASH_FROM = 10
local HOLD_THRASH_UNTIL = 13
local TICK_SECONDS = 0.1
local PREVIEW_PHASES = { 'hold', 'send', 'thrash', 'holdThrash' }
local PREVIEW_PHASE_SECONDS = 1.5
local SCREEN_WIDTH, SCREEN_HEIGHT = 320, 48

local HOLD_COLOR   = { 1, 0.3, 0.3 }
local SEND_COLOR   = { 0.35, 1, 0.45 }
local THRASH_COLOR = { 1, 0.82, 0 }

local CUE_SPEECH = {
    hold        = 'Hold',
    send        = 'Send',
    thrashFirst = 'Thrash first',
    thrash      = 'Thrash',
    holdThrash  = 'Hold thrash',
}
local HOLD_CUES = { hold = true, holdThrash = true }

local IsSpellKnown = C_SpellBook.IsSpellKnown
local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCooldownDuration = C_Spell.GetSpellCooldownDuration
local InCombatLockdown = InCombatLockdown
local issecretvalue = issecretvalue
local GetTime = GetTime
local StepCurve = BUI.Tools.StepCurve

local READY_SOON_CURVE = StepCurve(0, 1, READY_WINDOW, 0)
local NOT_READY_CURVE  = StepCurve(0, 0, READY_WINDOW, 1)
local HOLD_THRASH_CURVE = StepCurve(0, 0, HOLD_THRASH_FROM, 1)
HOLD_THRASH_CURVE:AddPoint(HOLD_THRASH_UNTIL, 0)

local function GetConfig() return BUI.GetDB()[SETTINGS_KEY] end
local function GetHunter() return BUI.BuffTracking.Hunter end

local function WantsIcon(config) return config.displayMode ~= 'screen' end
local function WantsScreen(config) return config.displayMode ~= 'icon' end

local lastThrashAt = -math.huge
local thrashPromptUntil = 0
local bwDuration, wtDuration

local function Evaluate(duration, curve, readyValue)
    if not duration then return readyValue end
    return duration:EvaluateRemainingDuration(curve, 0)
end

local function ReadRemaining(spellID, now)
    local info = GetSpellCooldown(spellID)
    if not info then return 0 end
    local startTime, duration, onGCD = info.startTime, info.duration, info.isOnGCD
    if issecretvalue(startTime) or issecretvalue(duration) or issecretvalue(onGCD) then return nil end
    if onGCD or duration == 0 then return 0 end
    local remaining = startTime + duration - now
    return remaining > 0 and remaining or 0
end

local function Speak(cue)
    BUI.TTS.Stop()
    BUI.TTS.Speak(CUE_SPEECH[cue])
end

local function WantsCue(config, cue)
    return config.tts and (config.ttsHold or not HOLD_CUES[cue])
end

local iconCache = {}
local Wake

local OnIconVisibility = BUI.Profiler.Wrap('BuffTracking.BestialWrathOverlay icon visibility', function() Wake() end)

local function IconFor(spellID)
    local CDM = BUI.CDM
    local icon = iconCache[spellID]
    if icon == false then return nil end
    if icon and CDM.IconMatchesSpell(icon, spellID) then return icon end
    icon = CDM.FindIconForSpell(spellID, true)
    iconCache[spellID] = icon or false
    if icon and not icon._buiBWOHooked then
        icon._buiBWOHooked = true
        icon:HookScript('OnShow', OnIconVisibility)
        icon:HookScript('OnHide', OnIconVisibility)
    end
    return icon
end

local function MarkIconsDirty()
    wipe(iconCache)
end

local function NewLayer(parent)
    local layer = CreateFrame('Frame', nil, parent)
    layer:SetAllPoints(parent)
    return layer
end

local function NewText(parent, label, color)
    local fontString = parent:CreateFontString(nil, 'OVERLAY', nil, 7)
    Pixel.ApplyFont(fontString, 13, BUI.GetGlobalFont(), 'OUTLINE')
    fontString:SetJustifyH('CENTER')
    fontString:SetText(label)
    fontString:SetTextColor(color[1], color[2], color[3], 1)
    fontString:SetPoint('CENTER', parent, 'CENTER', 0, 0)
    return fontString
end

local function NewCallout(root, holdThrashLabel)
    local readyLayer = NewLayer(root)
    local sendLayer = NewLayer(readyLayer)
    local holdLayer = NewLayer(readyLayer)
    local thrashReadyLayer = NewLayer(root)
    local thrashHoldLayer = NewLayer(thrashReadyLayer)
    return {
        root             = root,
        readyLayer       = readyLayer,
        sendLayer        = sendLayer,
        holdLayer        = holdLayer,
        thrashReadyLayer = thrashReadyLayer,
        thrashHoldLayer  = thrashHoldLayer,
        sendText         = NewText(sendLayer, 'SEND BW', SEND_COLOR),
        holdText         = NewText(holdLayer, 'HOLD BW', HOLD_COLOR),
        thrashText       = NewText(root, 'THRASH!', THRASH_COLOR),
        holdThrashText   = NewText(thrashHoldLayer, holdThrashLabel, HOLD_COLOR),
    }
end

local function CalloutTexts(callout)
    return callout.sendText, callout.holdText, callout.thrashText, callout.holdThrashText
end

local function SetLayerShown(region, shown)
    if region._buiShown == shown then return end
    region._buiShown = shown
    region:SetShown(shown)
end

local function SetLayerAlpha(region, alpha)
    if issecretvalue(alpha) then
        region._buiAlpha = nil
    elseif region._buiAlpha == alpha then
        return
    else
        region._buiAlpha = alpha
    end
    region:SetAlpha(alpha)
end

local function StyleCallout(callout, size, anchor, offsetX, offsetY)
    local font = BUI.GetGlobalFont()
    for index = 1, 4 do
        local fontString = select(index, CalloutTexts(callout))
        Pixel.ApplyFont(fontString, size, font, 'OUTLINE')
        fontString:ClearAllPoints()
        fontString:SetPoint(anchor, fontString:GetParent(), anchor, offsetX, offsetY)
    end
end

local function SetSendLabel(callout, label)
    if callout.sendLabel == label then return end
    callout.sendLabel = label
    callout.sendText:SetText(label)
end

local function RenderHoldThrash(callout)
    SetLayerShown(callout.thrashReadyLayer, true)
    SetLayerAlpha(callout.thrashReadyLayer, Evaluate(wtDuration, READY_SOON_CURVE, 1))
    SetLayerAlpha(callout.thrashHoldLayer, Evaluate(bwDuration, HOLD_THRASH_CURVE, 0))
end

local function RenderCallout(callout, now, cleaveUp, showHoldThrash)
    if now < thrashPromptUntil then
        SetLayerShown(callout.thrashText, true)
        SetLayerShown(callout.readyLayer, false)
        SetLayerShown(callout.thrashReadyLayer, false)
        return
    end
    SetLayerShown(callout.thrashText, false)
    SetLayerShown(callout.readyLayer, true)
    SetSendLabel(callout, cleaveUp and 'SEND BW' or 'THRASH FIRST')
    SetLayerAlpha(callout.readyLayer, Evaluate(bwDuration, READY_SOON_CURVE, 1))
    SetLayerAlpha(callout.sendLayer, Evaluate(wtDuration, READY_SOON_CURVE, 1))
    SetLayerAlpha(callout.holdLayer, Evaluate(wtDuration, NOT_READY_CURVE, 0))
    if showHoldThrash then
        RenderHoldThrash(callout)
    else
        SetLayerShown(callout.thrashReadyLayer, false)
    end
end

local bwCallout, thrashCallout, screenCallout

local function BuildIconCallouts()
    if bwCallout then return end
    local bwRoot = CreateFrame('Frame', nil, UIParent)
    bwRoot:Hide()
    bwCallout = NewCallout(bwRoot, 'HOLD')

    local thrashRoot = CreateFrame('Frame', nil, UIParent)
    thrashRoot:Hide()
    thrashCallout = NewCallout(thrashRoot, 'HOLD')
    SetLayerShown(thrashCallout.readyLayer, false)
    SetLayerShown(thrashCallout.thrashText, false)
end

local function BuildScreenCallout()
    if screenCallout then return end
    local root = CreateFrame('Frame', SCREEN_FRAME_NAME, UIParent)
    root:SetSize(SCREEN_WIDTH, SCREEN_HEIGHT)
    root:SetFrameStrata('HIGH')
    root:SetFrameLevel(98)
    root:Hide()
    screenCallout = NewCallout(root, 'HOLD THRASH')

    BUI.Dragging.MakeAnchoredAlert(root, {
        settings = GetConfig,
        isLocked = function() return GetConfig().screenLocked ~= false end,
        onRightClick = function()
            GetConfig().screenLocked = true
            BestialWrathOverlay.Refresh()
        end,
    })
end

local function AttachToIcon(callout, icon)
    if callout.icon == icon then return end
    callout.icon = icon
    local root = callout.root
    root:SetFrameStrata(icon:GetFrameStrata())
    root:SetFrameLevel(icon:GetFrameLevel() + BUI.CDM.GLOW_LAYER + 1)
    root:ClearAllPoints()
    root:SetAllPoints(icon)
end

local function ShowOnIcon(callout, spellID)
    local icon = IconFor(spellID)
    if not icon or not icon:IsShown() then
        callout.root:Hide()
        return false
    end
    AttachToIcon(callout, icon)
    callout.root:Show()
    return true
end

local function HideIconCallouts()
    if not bwCallout then return end
    bwCallout.root:Hide()
    thrashCallout.root:Hide()
end

local function HideAll()
    HideIconCallouts()
    if screenCallout then screenCallout.root:Hide() end
end

local function IsActive()
    local Hunter = GetHunter()
    return Hunter.PlayerIsHunter and Hunter.IsBeastMastery() and IsSpellKnown(WILD_THRASH) == true
end

local lastCue

local function LiveCue(now, cleaveUp, showHoldThrash)
    if now < thrashPromptUntil then return 'thrash' end
    local bwRemaining = ReadRemaining(BESTIAL_WRATH, now)
    if not bwRemaining then return nil end
    local bwReady = bwRemaining < READY_WINDOW
    local inHoldBand = showHoldThrash and bwRemaining >= HOLD_THRASH_FROM and bwRemaining < HOLD_THRASH_UNTIL
    if not bwReady and not inHoldBand then return 'idle' end
    local wtRemaining = ReadRemaining(WILD_THRASH, now)
    if not wtRemaining then
        wtRemaining = lastThrashAt + WILD_THRASH_COOLDOWN - now
    end
    local thrashReady = wtRemaining < READY_WINDOW
    if bwReady then
        if not thrashReady then return 'hold' end
        return cleaveUp and 'send' or 'thrashFirst'
    end
    return thrashReady and 'holdThrash' or 'idle'
end

local function UpdateVoice(config, now, cleaveUp)
    if not config.tts or not InCombatLockdown() then
        lastCue = nil
        return
    end
    local cue = LiveCue(now, cleaveUp, config.showHoldThrash)
    if not cue or cue == lastCue then return end
    lastCue = cue
    if WantsCue(config, cue) and cue ~= 'idle' and cue ~= 'thrash' then Speak(cue) end
end

local previewActive = false
local previewPhase

local function RenderPreview(callout, phase, withHoldThrash)
    SetLayerShown(callout.thrashText, phase == 'thrash')
    local bwPhase = phase == 'hold' or phase == 'send'
    SetLayerShown(callout.readyLayer, bwPhase)
    if bwPhase then
        SetSendLabel(callout, 'SEND BW')
        SetLayerAlpha(callout.readyLayer, 1)
        SetLayerAlpha(callout.sendLayer, phase == 'send' and 1 or 0)
        SetLayerAlpha(callout.holdLayer, phase == 'hold' and 1 or 0)
    end
    local holdThrash = withHoldThrash and phase == 'holdThrash'
    SetLayerShown(callout.thrashReadyLayer, holdThrash)
    if holdThrash then
        SetLayerAlpha(callout.thrashReadyLayer, 1)
        SetLayerAlpha(callout.thrashHoldLayer, 1)
    end
end

local function TickPreview(config, now)
    local phase = PREVIEW_PHASES[math.floor(now / PREVIEW_PHASE_SECONDS) % #PREVIEW_PHASES + 1]
    if phase ~= previewPhase then
        previewPhase = phase
        if WantsCue(config, phase) then Speak(phase) end
    end

    if WantsIcon(config) then
        BuildIconCallouts()
        if ShowOnIcon(bwCallout, BESTIAL_WRATH) then RenderPreview(bwCallout, phase, false) end
        if phase == 'holdThrash' and ShowOnIcon(thrashCallout, WILD_THRASH) then
            RenderPreview(thrashCallout, phase, true)
        else
            thrashCallout.root:Hide()
        end
    else
        HideIconCallouts()
    end

    if WantsScreen(config) then
        BuildScreenCallout()
        screenCallout.root:Show()
        RenderPreview(screenCallout, phase, true)
    elseif screenCallout then
        screenCallout.root:Hide()
    end
end

local function TickLive(config, now)
    local cleaveUp = now < lastThrashAt + BEAST_CLEAVE_SECONDS
    UpdateVoice(config, now, cleaveUp)

    local wantsIcon, wantsScreen = WantsIcon(config), WantsScreen(config)
    local screenHidden = wantsScreen and config.screenCombatOnly and config.screenLocked ~= false and not InCombatLockdown()
    if not wantsIcon and (not wantsScreen or screenHidden) then
        HideAll()
        return
    end

    bwDuration = GetSpellCooldownDuration(BESTIAL_WRATH)
    wtDuration = GetSpellCooldownDuration(WILD_THRASH)

    if wantsIcon then
        BuildIconCallouts()
        if ShowOnIcon(bwCallout, BESTIAL_WRATH) then RenderCallout(bwCallout, now, cleaveUp, false) end
        if config.showHoldThrash and now >= thrashPromptUntil and ShowOnIcon(thrashCallout, WILD_THRASH) then
            RenderHoldThrash(thrashCallout)
        else
            thrashCallout.root:Hide()
        end
    else
        HideIconCallouts()
    end

    if wantsScreen and not screenHidden then
        BuildScreenCallout()
        screenCallout.root:Show()
        RenderCallout(screenCallout, now, cleaveUp, config.showHoldThrash)
    elseif screenCallout then
        screenCallout.root:Hide()
    end

    bwDuration, wtDuration = nil, nil
end

local function Settled(now)
    if InCombatLockdown() or now < thrashPromptUntil or now < lastThrashAt + BEAST_CLEAVE_SECONDS then return false end
    return ReadRemaining(BESTIAL_WRATH, now) == 0 and ReadRemaining(WILD_THRASH, now) == 0
end

local Sleep

local function Tick()
    local config = GetConfig()
    local now = GetTime()
    if previewActive then
        TickPreview(config, now)
    elseif config.enabled and IsActive() then
        TickLive(config, now)
        if Settled(now) then Sleep() end
    else
        HideAll()
    end
end
local TickTimed = BUI.Profiler.Wrap('BuffTracking.BestialWrathOverlay tick', Tick)

local ticker
local sleeping = false

local function StopTicker()
    if ticker then ticker:Cancel() end
    ticker = nil
end

local function ClearSleep()
    if not sleeping then return end
    sleeping = false
    BUI.Events:UnregisterAll('BuffTrackingBWO.Sleep')
end

local function StartTicker()
    ClearSleep()
    if not ticker then ticker = C_Timer.NewTicker(TICK_SECONDS, TickTimed) end
end

Wake = function()
    if sleeping then StartTicker() end
end

local function OnSleepCooldown()
    local now = GetTime()
    if ReadRemaining(BESTIAL_WRATH, now) ~= 0 or ReadRemaining(WILD_THRASH, now) ~= 0 then Wake() end
end

Sleep = function()
    StopTicker()
    if sleeping then return end
    sleeping = true
    BUI.Events:Register('PLAYER_REGEN_DISABLED', 'BuffTrackingBWO.Sleep', Wake)
    BUI.Events:Register('SPELL_UPDATE_COOLDOWN', 'BuffTrackingBWO.Sleep', OnSleepCooldown)
end

local function OnSpellCast(_, _, _, spellID)
    if issecretvalue(spellID) then return end
    if spellID == BESTIAL_WRATH then
        thrashPromptUntil = GetTime() + THRASH_PROMPT_SECONDS
        local config = GetConfig()
        if WantsCue(config, 'thrash') then
            lastCue = 'thrash'
            Speak('thrash')
        end
        Wake()
    elseif WILD_THRASH_IDS[spellID] then
        lastThrashAt = GetTime()
        thrashPromptUntil = 0
        Wake()
    end
end

local function StyleAll(config)
    if bwCallout then
        local anchor = config.textAnchor
        local offsetX, offsetY = Pixel.Scale(config.textOffsetX), Pixel.Scale(config.textOffsetY)
        StyleCallout(bwCallout, config.textSize, anchor, offsetX, offsetY)
        StyleCallout(thrashCallout, config.textSize, anchor, offsetX, offsetY)
        bwCallout.icon, thrashCallout.icon = nil, nil
    end
    if screenCallout then
        StyleCallout(screenCallout, config.screenTextSize, 'CENTER', 0, 0)
        BUI.Anchor.ApplyPosition(screenCallout.root, config)
        BUI.Dragging.SetLocked(screenCallout.root, config.screenLocked ~= false)
    end
end

local castRegistered = false

local function SetCastWatch(wanted)
    if wanted == castRegistered then return end
    castRegistered = wanted
    if wanted then
        BUI.Events:RegisterUnit('UNIT_SPELLCAST_SUCCEEDED', 'player', 'BuffTrackingBWO', OnSpellCast)
    else
        BUI.Events:Unregister('UNIT_SPELLCAST_SUCCEEDED', 'BuffTrackingBWO')
    end
end

function BestialWrathOverlay.Refresh()
    if not GetHunter().PlayerIsHunter then return end
    MarkIconsDirty()
    local config = GetConfig()
    local live = config.enabled and IsActive()
    lastCue, previewPhase = nil, nil
    SetCastWatch(live)
    if live or previewActive then
        if WantsIcon(config) then BuildIconCallouts() end
        if WantsScreen(config) then BuildScreenCallout() end
        StyleAll(config)
        StartTicker()
        Tick()
    else
        StopTicker()
        ClearSleep()
        HideAll()
    end
end

function BestialWrathOverlay.StartPreview()
    previewActive = true
    BestialWrathOverlay.Refresh()
end

function BestialWrathOverlay.StopPreview()
    previewActive = false
    BestialWrathOverlay.Refresh()
end

function BestialWrathOverlay.IsPreviewing() return previewActive end

local function Initialize()
    if not GetHunter().PlayerIsHunter then return end
    BUI.CDM.OnTrackedIconsChanged(function(viewerKey)
        if viewerKey == 'buffs' then return end
        MarkIconsDirty()
        Wake()
    end)
    BestialWrathOverlay.Refresh()
end

BUI.Events:OnLogin('BuffTrackingBWO', Initialize, 'buffTracking')

BUI.Anchor.Follow('BuffTrackingBWO', function()
    local config = GetConfig()
    return config.enabled and WantsScreen(config) and screenCallout and screenCallout.root
end, GetConfig)

local QueueRefresh = BUI.Dispatcher.New(BestialWrathOverlay.Refresh, 'BWO.Refresh')
BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'BuffTrackingBWO', QueueRefresh)
BUI.Events:Register('TRAIT_CONFIG_UPDATED', 'BuffTrackingBWO', QueueRefresh)
BUI.Events:Register('PLAYER_ENTERING_WORLD', 'BuffTrackingBWO', QueueRefresh)
BUI.Events:Register('COOLDOWN_VIEWER_DATA_LOADED', 'BuffTrackingBWO', QueueRefresh)
