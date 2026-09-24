local _, BUI = ...
local Pixel = BUI.Pixel

local KillCommandOverlay = {}
BUI.BuffTracking.KillCommandOverlay = KillCommandOverlay

local KILL_COMMAND_IDS = { 34026, 259489 }
local SETTINGS_KEY = 'killCommandOverlay'
local PREVIEW_READY_SECONDS = 4
local PREVIEW_TICK_SECONDS = 8

local OPPOSITE_ANCHOR = {
    TOP         = 'BOTTOM',      BOTTOM      = 'TOP',
    LEFT        = 'RIGHT',       RIGHT       = 'LEFT',
    TOPLEFT     = 'BOTTOMRIGHT', TOPRIGHT    = 'BOTTOMLEFT',
    BOTTOMLEFT  = 'TOPRIGHT',    BOTTOMRIGHT = 'TOPLEFT',
    CENTER      = 'CENTER',
}

local function GetHunter() return BUI.BuffTracking.Hunter end

local function IsHunterLoaded()
    return GetHunter().PlayerIsHunter
end

local function GetConfig() return BUI.GetDB()[SETTINGS_KEY] end

local function StyleFontString(fontString, size)
    Pixel.ApplyFont(fontString, size, BUI.GetGlobalFont(), 'OUTLINE')
end

local function AnchorTarget(icon) return icon.Icon or icon end

local cachedIcon
local cacheDirty = true
local cachedTimerStamp

local function ResolveKillCommandIcon()
    local CDM = BUI.CDM
    for spellIndex = 1, #KILL_COMMAND_IDS do
        local icon = CDM.FindIconForSpell(KILL_COMMAND_IDS[spellIndex], true)
        if icon then return icon end
    end
    return nil
end

local function CachedIconIsStillKillCommand()
    for spellIndex = 1, #KILL_COMMAND_IDS do
        if BUI.CDM.IconMatchesSpell(cachedIcon, KILL_COMMAND_IDS[spellIndex]) then return true end
    end
    return false
end

local function GetCachedIcon()
    if cachedIcon and not CachedIconIsStillKillCommand() then
        cachedIcon = nil
        cacheDirty = true
    end
    if cacheDirty or not cachedIcon then
        cachedIcon = ResolveKillCommandIcon()
        cacheDirty = cachedIcon == nil
    end
    return cachedIcon
end

local function MarkCacheDirty()
    cacheDirty = true
    cachedIcon = nil
    cachedTimerStamp = nil
end

local overlay

local function EnsureOverlay(icon)
    if not overlay then
        local frame = CreateFrame('Frame', nil, UIParent)

        local cooldown = CreateFrame('Cooldown', nil, frame, 'CooldownFrameTemplate')
        cooldown:SetDrawSwipe(false)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetHideCountdownNumbers(false)
        cooldown:SetAllPoints(frame)
        cooldown:SetCountdownMillisecondsThreshold(0)

        local beastText = frame:CreateFontString(nil, 'OVERLAY', nil, 7)
        beastText:SetJustifyH('CENTER')
        beastText:SetJustifyV('MIDDLE')
        StyleFontString(beastText, 12)

        overlay = {
            frame            = frame,
            cooldown         = cooldown,
            timerFS          = BUI.Tools.CooldownFontString(cooldown),
            beastText        = beastText,
            lastPreviewPhase = nil,
        }
    end

    if overlay.icon ~= icon then
        overlay.icon = icon
        overlay.frame:SetFrameStrata(icon:GetFrameStrata())
        overlay.frame:SetFrameLevel(icon:GetFrameLevel() + BUI.CDM.GLOW_LAYER + 1)
        overlay.frame:ClearAllPoints()
        overlay.frame:SetPoint('TOPLEFT',     icon, 'TOPLEFT', 0, 0)
        overlay.frame:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', 0, 0)
        overlay.timerSize, overlay.timerAnchor, overlay.timerOX, overlay.timerOY = nil, nil, nil, nil
        overlay.beastSize, overlay.beastAnchor, overlay.beastOX, overlay.beastOY = nil, nil, nil, nil
        overlay.timerR, overlay.cdThreshold = nil, nil
        overlay.lastPreviewPhase = nil
        if overlay.liveDriver then overlay.liveDriver.stamp = nil end
    end

    return overlay
end

local function LiveTimerStamp(config, icon)
    if cachedTimerStamp then return cachedTimerStamp end
    local timerColor = config.timerColor
    cachedTimerStamp = table.concat({
        config.timerSize, config.timerAnchor,
        config.timerOffsetX, config.timerOffsetY,
        config.showDecimals and config.decimalThreshold or 0,
        ('%.2f:%.2f:%.2f'):format(timerColor.r, timerColor.g, timerColor.b),
        BUI.GetGlobalFont(),
        math.floor(icon:GetWidth() + 0.5),
    }, '|')
    return cachedTimerStamp
end

local function StyleLiveTimer(cooldown, button)
    local config = GetConfig()
    cooldown:SetDrawSwipe(false)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(false)
    cooldown:SetCountdownMillisecondsThreshold(config.showDecimals and config.decimalThreshold or 0)
    local fontString = BUI.Tools.CooldownFontString(cooldown)
    if not fontString then return end
    local color = config.timerColor
    local anchor = config.timerAnchor
    fontString:SetFont(BUI.GetGlobalFont(), config.timerSize, 'OUTLINE')
    fontString:SetTextColor(color.r, color.g, color.b, 1)
    fontString:ClearAllPoints()
    fontString:SetPoint(anchor, button, anchor, Pixel.Scale(config.timerOffsetX), Pixel.Scale(config.timerOffsetY))
end

local function EnsureLiveTimer(entry, config, wanted)
    local Hunter = GetHunter()
    local Engine = BUI.AuraEngine
    if not entry.liveDriver then entry.liveDriver = Engine.NewAuraCooldownDriver(entry.frame) end
    local icon = entry.icon
    local width, height = icon:GetWidth(), icon:GetHeight()
    if width <= 0 then width = 40 end
    if height <= 0 then height = 40 end
    Engine.SyncAuraCooldownDriver(entry.liveDriver, wanted, Hunter.PackLeaderSpellSet,
        LiveTimerStamp(config, icon), width, height, StyleLiveTimer)
end

local function ClearOverlay()
    overlay.cooldown:Clear()
    overlay.cooldown:Hide()
    overlay.beastText:SetText('')
    overlay.beastText:Hide()
    overlay.lastPreviewPhase = nil
end

local function HideAllOverlays()
    if not overlay then return end
    ClearOverlay()
    overlay.frame:Hide()
end

local function SoftIdle()
    if overlay then ClearOverlay() end
end

local function ApplyTimerLayout(entry, icon, config)
    local fontString = entry.timerFS
    if not fontString then return end

    local size    = config.timerSize
    local anchor  = config.timerAnchor
    local offsetX = config.timerOffsetX
    local offsetY = config.timerOffsetY
    local color   = config.timerColor
    local threshold = config.showDecimals and config.decimalThreshold or 0

    if entry.timerSize ~= size then
        fontString:SetFont(BUI.GetGlobalFont(), size, 'OUTLINE')
        entry.timerSize = size
        entry.timerR = nil
    end
    if entry.timerR ~= color.r or entry.timerG ~= color.g or entry.timerB ~= color.b then
        fontString:SetTextColor(color.r, color.g, color.b, 1)
        entry.timerR, entry.timerG, entry.timerB = color.r, color.g, color.b
    end

    if entry.timerAnchor ~= anchor or entry.timerOX ~= offsetX or entry.timerOY ~= offsetY then
        fontString:ClearAllPoints()
        fontString:SetPoint(anchor, AnchorTarget(icon), anchor, Pixel.Scale(offsetX), Pixel.Scale(offsetY))
        entry.timerAnchor, entry.timerOX, entry.timerOY = anchor, offsetX, offsetY
    end

    if entry.cdThreshold ~= threshold then
        entry.cooldown:SetCountdownMillisecondsThreshold(threshold)
        entry.cdThreshold = threshold
    end
end

local function ApplyBeastLayout(entry, icon, config)
    local size    = config.beastSize
    local anchor  = config.beastAnchor
    local offsetX = config.beastOffsetX
    local offsetY = config.beastOffsetY

    if entry.beastSize ~= size then
        StyleFontString(entry.beastText, size)
        entry.beastSize = size
    end
    if entry.beastAnchor ~= anchor or entry.beastOX ~= offsetX or entry.beastOY ~= offsetY then
        entry.beastText:ClearAllPoints()
        entry.beastText:SetPoint(OPPOSITE_ANCHOR[anchor], AnchorTarget(icon), anchor, Pixel.Scale(offsetX), Pixel.Scale(offsetY))
        entry.beastAnchor, entry.beastOX, entry.beastOY = anchor, offsetX, offsetY
    end
end

local previewActive = false
local previewBeastIndex = 1

local function GetPreviewState(Hunter)
    if not previewActive then return nil end
    local total = PREVIEW_READY_SECONDS + PREVIEW_TICK_SECONDS
    local elapsedInCycle = GetTime() % total
    local beast = Hunter.PackLeaderBeasts[previewBeastIndex]
    if elapsedInCycle < PREVIEW_READY_SECONDS then
        return 'ready', beast, PREVIEW_READY_SECONDS - elapsedInCycle
    end
    return 'ticking', beast, total - elapsedInCycle
end

local function Tick()
    local config = GetConfig()
    if not config.enabled and not previewActive then
        HideAllOverlays()
        return nil
    end

    local icon = GetCachedIcon()
    local Hunter = GetHunter()
    if not icon then
        HideAllOverlays()
        return nil
    end

    local phase, beast, remaining = GetPreviewState(Hunter)
    local isPreview = phase ~= nil
    if not isPreview then
        phase = Hunter.GetPackLeaderPhase()
        if phase == 'off' then
            SoftIdle()
            return nil
        end
        if phase == 'ready' then
            beast = Hunter.GetPackLeaderReadyBeast()
        else
            beast = Hunter.GetNextBeastData()
        end
        if not icon:IsShown() then
            HideAllOverlays()
            return nil
        end
    end

    local entry = EnsureOverlay(icon)
    entry.frame:Show()

    ApplyTimerLayout(entry, icon, config)
    ApplyBeastLayout(entry, icon, config)

    if config.showTimer and isPreview then
        local total = phase == 'ready' and PREVIEW_READY_SECONDS or PREVIEW_TICK_SECONDS
        if entry.lastPreviewPhase ~= phase then
            entry.cooldown:SetCooldown(GetTime() - (total - remaining), total)
            entry.lastPreviewPhase = phase
        end
        entry.cooldown:Show()
    else
        entry.cooldown:Clear()
        entry.cooldown:Hide()
        entry.lastPreviewPhase = nil
    end
    EnsureLiveTimer(entry, config, config.showTimer and not isPreview)

    if config.showBeastName then
        local red, green, blue = Hunter.BeastColor(beast.id)
        if entry.beastId ~= beast.id or entry.beastPhase ~= phase or entry.beastR ~= red or entry.beastG ~= green or entry.beastB ~= blue then
            entry.beastId, entry.beastPhase = beast.id, phase
            entry.beastR, entry.beastG, entry.beastB = red, green, blue
            local label = beast.short
            if phase == 'ready' then label = 'SEND ' .. label:upper() end
            entry.beastText:SetText(label)
            entry.beastText:SetTextColor(red, green, blue, 1)
        end
        entry.beastText:Show()
    else
        if entry.beastId then
            entry.beastId, entry.beastPhase = nil, nil
            entry.beastText:SetText('')
        end
        entry.beastText:Hide()
    end

    return true
end

local ticker
local wakeArmed = false
local QueueTick
local SyncWrapped

local function StopTicker()
    if ticker then ticker:Cancel() end
    ticker = nil
end

local function StartTicker()
    StopTicker()
    ticker = C_Timer.NewTicker(1, SyncWrapped)
end

local function DisarmWake()
    if not wakeArmed then return end
    wakeArmed = false
    BUI.Events:Unregister('UNIT_AURA', 'KCO.Wake')
    BUI.Events:Unregister('SPELL_UPDATE_COOLDOWN', 'KCO.Wake')
end

local function ArmWake()
    if wakeArmed then return end
    wakeArmed = true
    BUI.Events:RegisterUnit('UNIT_AURA', 'player', 'KCO.Wake', QueueTick)
    BUI.Events:Register('SPELL_UPDATE_COOLDOWN', 'KCO.Wake', QueueTick)
end

local function Sync()
    local live = Tick()
    if GetConfig().enabled or previewActive then
        ArmWake()
    else
        DisarmWake()
    end
    if live then
        if not ticker then StartTicker() end
    else
        StopTicker()
    end
end

SyncWrapped = Sync
QueueTick = BUI.Dispatcher.New(Sync, 'KCO.Tick')

function KillCommandOverlay.Refresh()
    if not IsHunterLoaded() then return end
    MarkCacheDirty()
    local config = GetConfig()
    if config.enabled or previewActive then
        if config.enabled then
            local icon = GetCachedIcon()
            if icon then
                local entry = EnsureOverlay(icon)
                entry.frame:Show()
                EnsureLiveTimer(entry, config, config.showTimer)
            end
        end
        Sync()
    else
        StopTicker()
        DisarmWake()
        HideAllOverlays()
        if overlay then EnsureLiveTimer(overlay, config, false) end
    end
end

function KillCommandOverlay.StartPreview()
    previewActive = true
    previewBeastIndex = previewBeastIndex % #GetHunter().PackLeaderBeasts + 1
    Sync()
end

function KillCommandOverlay.StopPreview()
    previewActive = false
    Sync()
end

function KillCommandOverlay.IsPreviewing() return previewActive end

function KillCommandOverlay.Initialize()
    if not IsHunterLoaded() then return end
    BUI.CDM.OnTrackedIconsChanged(function(viewerKey)
        if viewerKey == 'buffs' then return end
        MarkCacheDirty()
        QueueTick()
    end)
    KillCommandOverlay.Refresh()
end

BUI.Events:OnLogin('BuffTrackingKCO', KillCommandOverlay.Initialize)

local QueueRefresh = BUI.Dispatcher.New(KillCommandOverlay.Refresh, 'KCO.Refresh')

local function DirtyAndRefresh()
    MarkCacheDirty()
    QueueRefresh()
end

BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'BuffTrackingKCO', DirtyAndRefresh)
BUI.Events:Register('TRAIT_CONFIG_UPDATED', 'BuffTrackingKCO', DirtyAndRefresh)
BUI.Events:Register('PLAYER_ENTERING_WORLD', 'BuffTrackingKCO', DirtyAndRefresh)
BUI.Events:Register('PLAYER_REGEN_DISABLED', 'BuffTrackingKCO', MarkCacheDirty)
BUI.Events:Register('PLAYER_REGEN_ENABLED', 'BuffTrackingKCO', DirtyAndRefresh)
BUI.Events:Register('COOLDOWN_VIEWER_DATA_LOADED', 'BuffTrackingKCO', DirtyAndRefresh)
