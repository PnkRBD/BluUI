local _, BUI = ...

BUI.GCDHistory = {}
local GCDHistory = BUI.GCDHistory
local Pixel = BUI.Pixel

local wipe, ipairs = wipe, ipairs
local floor, min = math.floor, math.min
local tinsert, tremove = table.insert, table.remove
local GetTime = GetTime
local CreateFrame = CreateFrame
local C_Spell = C_Spell
local C_Item = C_Item
local GetInventorySlotInfo = GetInventorySlotInfo
local GetInventoryItemID = GetInventoryItemID
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local issecretvalue = issecretvalue

local function GetDB() return BUI.GetDB().gcdHistory end

local AUTO_ATTACK_IDS = {
    [6603] = true, [75] = true, [240022] = true,
    [467718] = true, [1228085] = true, [463429] = true, [7268] = true,
}

local BLANK_ICON              = 136243
local PREVIEW_TEXTURES        = { 134400, 136048, 135735 }
local PREVIEW_CAST_TEXTURE    = 135994
local FADE_DURATION           = 0.5
local REPEAT_GAP              = 0.5
local CHANNEL_INTERRUPT_MS    = 500

local EQUIP_SLOTS = {
    'HeadSlot', 'NeckSlot', 'ShoulderSlot', 'BackSlot', 'ChestSlot',
    'WristSlot', 'MainHandSlot', 'SecondaryHandSlot', 'HandsSlot',
    'WaistSlot', 'LegsSlot', 'FeetSlot', 'Finger0Slot', 'Finger1Slot',
    'Trinket0Slot', 'Trinket1Slot',
}

local container, activeCast
local iconFrames = {}
local history    = {}
local fading     = {}
local fadePool   = {}
local itemSpellMap = {}
local enabled       = false
local eventsActive  = false
local channelActive = false
local channelEndMs, channelSpellID

local function RebuildItemSpellMap()
    wipe(itemSpellMap)
    for _, slotName in ipairs(EQUIP_SLOTS) do
        local slotID = GetInventorySlotInfo(slotName:upper())
        local itemID = slotID and GetInventoryItemID('player', slotID)
        if itemID then
            local _, spellID = C_Item.GetItemSpell(itemID)
            if spellID then itemSpellMap[spellID] = itemID end
        end
    end
end

local function ResolveIcon(spellID)
    if not spellID or spellID == 0 or issecretvalue(spellID) then return nil end
    local itemID = itemSpellMap[spellID]
    if itemID then
        local texture = select(10, C_Item.GetItemInfo(itemID))
        if texture then return texture end
    end
    return C_Spell.GetSpellTexture(spellID)
end

local function ResolveValidIcon(spellID)
    if not spellID or spellID == 0 or issecretvalue(spellID) then return nil end
    local settings = GetDB()
    if settings.hideAutoAttacks and AUTO_ATTACK_IDS[spellID] then return nil end
    if settings.blacklist[spellID] then return nil end
    local texture = ResolveIcon(spellID)
    if not texture or texture == BLANK_ICON then return nil end
    local name = C_Spell.GetSpellName(spellID)
    if name and not issecretvalue(name) then
        if name:find('%[DNT%]') or name:find('%(DNT%)') then return nil end
        if name:find(' [Ee]nd$') or name:find(' [Hh]it$') or name:find(' [Aa]ura$') then return nil end
    end
    return texture
end

local styleGeneration = 0

local function StyleIcon(icon, size, borderSize, borderColor, zoom)
    if icon._styleGen == styleGeneration then return end
    icon._styleGen = styleGeneration
    icon:SetSize(Pixel.Scale(size), Pixel.Scale(size))
    local edge  = borderSize
    local color = borderColor
    Pixel.ApplyBorder(icon, edge, color[1], color[2], color[3], color[4])
    local scaledEdge = Pixel.Scale(edge)
    icon.tex:ClearAllPoints()
    icon.tex:SetPoint('TOPLEFT',     scaledEdge,  -scaledEdge)
    icon.tex:SetPoint('BOTTOMRIGHT', -scaledEdge,  scaledEdge)
    local zoomFactor = zoom
    icon.tex:SetTexCoord(zoomFactor, 1 - zoomFactor, zoomFactor, 1 - zoomFactor)
    icon._edge        = edge
    icon._borderColor = color
end

local function CreateIconFrame()
    local icon = CreateFrame('Frame', nil, container, 'BackdropTemplate')
    icon.tex = icon:CreateTexture(nil, 'ARTWORK')

    icon.failX = icon:CreateTexture(nil, 'OVERLAY')
    icon.failX:SetAllPoints(icon.tex)
    icon.failX:SetTexture([[Interface\RaidFrame\ReadyCheck-NotReady]])
    icon.failX:Hide()

    icon.badge = icon:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(icon.badge, 14, BUI.GetGlobalFont(), 'OUTLINE')
    icon.badge:SetPoint('CENTER')
    icon.badge:SetTextColor(1, 1, 1, 1)
    icon.badge:Hide()

    icon.highlight = icon:CreateTexture(nil, 'ARTWORK', nil, 1)
    icon.highlight:SetAllPoints(icon.tex)
    BUI.Tools.SetColorTex(icon.highlight, 0, 1, 0, 0.3)
    icon.highlight:Hide()

    local settings = GetDB()
    StyleIcon(icon, settings.iconSize, settings.borderSize, settings.borderColor, settings.zoom)
    return icon
end

local function SetFailed(icon, failed)
    if failed then
        Pixel.ApplyBorder(icon, icon._edge, 1, 0, 0, 1)
        icon.failX:Show()
    else
        local color = icon._borderColor
        Pixel.ApplyBorder(icon, icon._edge, color[1], color[2], color[3], color[4])
        icon.failX:Hide()
    end
    icon.highlight:Hide()
end

local function GetIcon(index)
    if not iconFrames[index] then iconFrames[index] = CreateIconFrame() end
    return iconFrames[index]
end

local function AcquireFade()
    local frame = tremove(fadePool)
    if frame then
        frame:SetParent(container)
        frame:SetAlpha(1)
        return frame
    end
    return CreateIconFrame()
end

local function ReleaseFade(frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame.badge:Hide()
    frame.failX:Hide()
    tinsert(fadePool, frame)
end

local fadeDriver = CreateFrame('Frame')
fadeDriver:Hide()
fadeDriver:SetScript('OnUpdate', function(_, deltaTime)
    local alive = false
    for fadeIndex = #fading, 1, -1 do
        local fadeFrame = fading[fadeIndex]
        local alpha = fadeFrame:GetAlpha() - deltaTime / FADE_DURATION
        if alpha > 0.01 then
            fadeFrame:SetAlpha(alpha)
            alive = true
        else
            tremove(fading, fadeIndex)
            ReleaseFade(fadeFrame)
        end
    end
    if not alive then fadeDriver:Hide() end
end)

local function GetActiveCastGap(settings)
    if not settings.showActiveCast or not activeCast then return 0 end
    local scaledSize = Pixel.Scale(settings.iconSize)
    return scaledSize * settings.activeCastScale / 2 + Pixel.Scale(settings.spacing) + scaledSize / 2
end

local function StartFadeOut(texture, slotIndex, settings)
    local growRight = settings.growDirection == 'RIGHT'
    local size      = settings.iconSize
    local offset    = Pixel.Snap(GetActiveCastGap(settings) + slotIndex * (size + settings.spacing))
    local frame = AcquireFade()
    StyleIcon(frame, size, settings.borderSize, settings.borderColor, settings.zoom)
    frame:ClearAllPoints()
    frame:SetPoint('CENTER', container, 'CENTER', growRight and offset or -offset, 0)
    frame.tex:SetTexture(texture)
    frame:SetAlpha(1)
    frame:Show()
    tinsert(fading, frame)
    fadeDriver:Show()
end

local function StyleActiveCast()
    local settings   = GetDB()
    local size       = settings.iconSize * settings.activeCastScale
    local scaledEdge = Pixel.Scale(settings.borderSize)
    local zoomFactor = settings.zoom
    local color      = settings.borderColor

    activeCast:SetSize(Pixel.Scale(size), Pixel.Scale(size))
    activeCast.tex:ClearAllPoints()
    activeCast.tex:SetPoint('TOPLEFT',      scaledEdge, -scaledEdge)
    activeCast.tex:SetPoint('BOTTOMRIGHT', -scaledEdge,  scaledEdge)
    activeCast.tex:SetTexCoord(zoomFactor, 1 - zoomFactor, zoomFactor, 1 - zoomFactor)
    Pixel.ApplyBorder(activeCast, settings.borderSize, color[1], color[2], color[3], color[4])
    local cdEdge = scaledEdge - Pixel.PixelSize(1)
    if cdEdge < 0 then cdEdge = 0 end
    activeCast.cd:ClearAllPoints()
    activeCast.cd:SetPoint('TOPLEFT',      cdEdge, -cdEdge)
    activeCast.cd:SetPoint('BOTTOMRIGHT', -cdEdge,  cdEdge)
end

local function BuildActiveCast()
    if activeCast then return end
    activeCast = CreateFrame('Frame', nil, container, 'BackdropTemplate')
    activeCast:SetFrameLevel(container:GetFrameLevel() + 5)
    activeCast.tex = activeCast:CreateTexture(nil, 'ARTWORK')

    activeCast.cd = CreateFrame('Cooldown', nil, activeCast, 'CooldownFrameTemplate')
    activeCast.cd:SetDrawEdge(false)
    activeCast.cd:SetDrawBling(false)
    activeCast.cd:SetHideCountdownNumbers(true)
    activeCast.cd:SetSwipeColor(0, 0, 0, 0.6)

    if activeCast.cd.CooldownFlash then
        hooksecurefunc(activeCast.cd.CooldownFlash, 'Show', function(self)
            self:Hide()
            if self.FlashAnim then self.FlashAnim:Stop() end
        end)
    end

    StyleActiveCast()
    activeCast:Hide()
end

local BOUNCE_PEAK  = 1.3
local BOUNCE_UP    = 0.08
local BOUNCE_DOWN  = 0.12
local BOUNCE_TOTAL = BOUNCE_UP + BOUNCE_DOWN

local function BounceOnUpdate(self, deltaTime)
    local elapsed = (self._bounceElapsed or 0) + deltaTime
    if elapsed >= BOUNCE_TOTAL then
        self:SetScale(1)
        self:SetScript('OnUpdate', nil)
        self._bounceElapsed = nil
        return
    end
    self._bounceElapsed = elapsed
    if elapsed < BOUNCE_UP then
        self:SetScale(1 + (BOUNCE_PEAK - 1) * (elapsed / BOUNCE_UP))
    else
        local progress = (elapsed - BOUNCE_UP) / BOUNCE_DOWN
        self:SetScale(BOUNCE_PEAK + (1 - BOUNCE_PEAK) * progress * progress)
    end
end

local function PlayBounce(frame)
    frame._bounceElapsed = 0
    frame:SetScale(1)
    frame:SetScript('OnUpdate', BounceOnUpdate)
end

local function ShowActiveCast(spellID, startMs, endMs, isChannel)
    local settings = GetDB()
    if not settings.showActiveCast or not activeCast then return end
    local texture = ResolveIcon(spellID)
    if not texture then return end

    activeCast.tex:SetTexture(texture)
    activeCast.cd:SetReverse(isChannel == true)
    if startMs and endMs then
        local duration = (endMs - startMs) / 1000
        if duration > 0 then
            activeCast.cd:SetCooldown(endMs / 1000 - duration, duration)
        else
            activeCast.cd:Clear()
        end
    end
    activeCast:Show()
    PlayBounce(activeCast)
end

local function HideActiveCast()
    if not activeCast then return end
    activeCast:Hide()
    activeCast.cd:Clear()
    activeCast.cd:SetReverse(false)
end

local function UpdateLayout()
    if not container then return end
    local settings  = GetDB()
    local growRight = settings.growDirection == 'RIGHT'
    local size      = settings.iconSize
    local spacing   = settings.spacing

    BUI.Anchor.ApplyPosition(container, settings)
    container:SetSize(Pixel.Scale(size), Pixel.Scale(size))

    if activeCast then
        StyleActiveCast()
        activeCast:ClearAllPoints()
        activeCast:SetPoint('CENTER', container, 'CENTER', 0, 0)
    end

    local castGap = GetActiveCastGap(settings)

    for historyIndex, entry in ipairs(history) do
        local icon   = GetIcon(historyIndex)
        local offset = Pixel.Snap(castGap + (historyIndex - 1) * (size + spacing))
        StyleIcon(icon, size, settings.borderSize, settings.borderColor, settings.zoom)
        icon:ClearAllPoints()
        icon:SetPoint('CENTER', container, 'CENTER', growRight and offset or -offset, 0)
        icon.tex:SetTexture(entry.texture)
        SetFailed(icon, entry.failed)
        icon.badge:Hide()
        icon:SetAlpha(1)
        icon:Show()
    end

    for iconIndex = #history + 1, #iconFrames do
        if iconFrames[iconIndex]:IsShown() then iconFrames[iconIndex]:Hide() end
    end
end

local function ClearIcons()
    wipe(history)
    for _, icon in ipairs(iconFrames) do
        SetFailed(icon, false)
        icon.badge:Hide()
        icon.highlight:Hide()
        icon:Hide()
    end
    for _, fadeFrame in ipairs(fading) do ReleaseFade(fadeFrame) end
    wipe(fading)
    HideActiveCast()
    fadeDriver:Hide()
    channelActive = false
    channelEndMs, channelSpellID = nil, nil
end

local function ShowPreview()
    if not container then return end
    local settings = GetDB()
    ClearIcons()
    for previewIndex = 1, min(3, settings.maxIcons) do
        history[previewIndex] = { texture = PREVIEW_TEXTURES[previewIndex] }
    end
    if settings.showActiveCast and activeCast then
        activeCast.tex:SetTexture(PREVIEW_CAST_TEXTURE)
        activeCast.cd:Clear()
        activeCast:Show()
    end
    container:Show()
    UpdateLayout()
    if iconFrames[1] then iconFrames[1].highlight:Show() end
end

local function AddSpell(spellID, failed)
    local settings = GetDB()
    if not settings.locked then return end

    local texture = ResolveValidIcon(spellID)
    if GCDHistory.debug then
        local name = C_Spell.GetSpellName(spellID)
        print(string.format(
            '|cff6D00FDGCD:|r AddSpell id=%s name=%s texture=%s failed=%s validIcon=%s channelActive=%s',
            tostring(spellID), tostring(name), tostring(texture), tostring(failed),
            tostring(texture ~= nil), tostring(channelActive)))
    end
    if not texture then
        if GCDHistory.debug then print('|cff6D00FDGCD:|r  -> filtered (back-end / blacklisted)') end
        return
    end

    local now = GetTime()
    for _, entry in ipairs(history) do
        if (now - entry.time) >= REPEAT_GAP then break end
        if entry.spellID == spellID or entry.texture == texture then
            if GCDHistory.debug then
                print(string.format('|cff6D00FDGCD:|r  -> skipped (recent dupe id=%s within %.2fs)', tostring(entry.spellID), now - entry.time))
            end
            return
        end
    end

    tinsert(history, 1, { spellID = spellID, texture = texture, time = now, failed = failed or false })
    if enabled then BUI.Scheduler.SetUpdateEnabled('GCDHistory_Expire', true) end

    while #history > settings.maxIcons do
        local overflow = tremove(history)
        StartFadeOut(overflow.texture, settings.maxIcons, settings)
    end

    UpdateLayout()
end

local function CheckExpired()
    if #history == 0 then
        BUI.Scheduler.SetUpdateEnabled('GCDHistory_Expire', false)
        return
    end
    local settings = GetDB()
    if not settings.locked or settings.fadeOldIcons == false or not container then return end

    local now      = GetTime()
    local lifetime = settings.fadeTime
    local changed  = false

    for historyIndex = #history, 1, -1 do
        if now - history[historyIndex].time >= lifetime then
            local entry = history[historyIndex]
            StartFadeOut(entry.texture, historyIndex - 1, settings)
            tremove(history, historyIndex)
            changed = true
        end
    end

    if changed then UpdateLayout() end
end

local function OnSpellEvent(event, unit, _, spellID)
    if GCDHistory.debug then
        local name = spellID and C_Spell.GetSpellName(spellID)
        print(string.format(
            '|cff6D00FDGCD:|r %s unit=%s id=%s name=%s casting=%s channeling=%s',
            tostring(event), tostring(unit), tostring(spellID), tostring(name),
            tostring(UnitCastingInfo('player') ~= nil), tostring(UnitChannelInfo('player') ~= nil)))
    end
    if unit ~= 'player' then return end
    local settings = GetDB()

    if event == 'UNIT_SPELLCAST_START' then
        if settings.showActiveCast then
            local _, _, _, startMs, endMs = UnitCastingInfo('player')
            if startMs and endMs then ShowActiveCast(spellID, startMs, endMs) end
        end

    elseif event == 'UNIT_SPELLCAST_CHANNEL_START' then
        local _, _, _, startMs, endMs = UnitChannelInfo('player')
        channelActive  = true
        channelEndMs   = endMs
        channelSpellID = spellID
        if settings.showActiveCast and startMs and endMs then
            ShowActiveCast(spellID, startMs, endMs, true)
        end

    elseif event == 'UNIT_SPELLCAST_STOP' then
        if not UnitCastingInfo('player') then HideActiveCast() end

    elseif event == 'UNIT_SPELLCAST_CHANNEL_STOP' then
        if channelActive then
            local interrupted = channelEndMs and (channelEndMs - GetTime() * 1000) > CHANNEL_INTERRUPT_MS
            AddSpell(channelSpellID or spellID, interrupted == true)
        end
        channelActive  = false
        channelEndMs   = nil
        channelSpellID = nil
        if not UnitChannelInfo('player') then HideActiveCast() end

    elseif event == 'UNIT_SPELLCAST_SUCCEEDED' then
        if channelActive then return end
        AddSpell(spellID)

    elseif event == 'UNIT_SPELLCAST_INTERRUPTED' then
        AddSpell(spellID, true)
        HideActiveCast()
    end
end

local function StartEvents()
    if eventsActive then return end
    eventsActive = true
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_SUCCEEDED',     'player', 'GCDHistory', OnSpellEvent)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_START',         'player', 'GCDHistory', OnSpellEvent)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_STOP',          'player', 'GCDHistory', OnSpellEvent)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_INTERRUPTED',   'player', 'GCDHistory', OnSpellEvent)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_CHANNEL_START', 'player', 'GCDHistory', OnSpellEvent)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_CHANNEL_STOP',  'player', 'GCDHistory', OnSpellEvent)
    BUI.Events:Register('PLAYER_EQUIPMENT_CHANGED', 'GCDHistory', RebuildItemSpellMap)
    BUI.Events:Register('PLAYER_ENTERING_WORLD',    'GCDHistory', RebuildItemSpellMap)
end

local function StopEvents()
    if not eventsActive then return end
    BUI.Events:UnregisterAll('GCDHistory')
    eventsActive = false
end

local function CreateContainer()
    if container then return end
    container = CreateFrame('Frame', 'BUI_GCDHistory', UIParent)
    container:SetSize(Pixel.Scale(200), Pixel.Scale(50))
    container:SetClampedToScreen(true)
    container:SetFrameStrata('HIGH')
    container:Hide()

    BUI.Dragging.MakeDraggable(container, {
        isLocked = function() return GetDB().locked or container._isAnchored end,
        onPositionChanged = function(x, y)
            local settings = GetDB()
            settings.posX, settings.posY = floor(x), floor(y)
        end,
        onRightClick = function()
            GCDHistory.SetLocked(true)
            print('|cff6D00FDBluUI:|r GCD History locked.')
        end,
        showHint   = true,
        hintAnchor = 'TOP',
    })

    BuildActiveCast()
end


GCDHistory.debug = false
function GCDHistory.SetDebug(on)
    GCDHistory.debug = on and true or false
    print(string.format('|cff6D00FDBluUI:|r GCD History debug %s', GCDHistory.debug and '|cff44ff44ON|r' or '|cffff4444OFF|r'))
end

function GCDHistory.Enable()
    if enabled then return end
    CreateContainer()
    local settings = GetDB()
    if settings.locked then UpdateLayout() else ShowPreview() end
    BUI.Dragging.SetLocked(container, settings.locked or container._isAnchored)
    StartEvents()
    RebuildItemSpellMap()
    BUI.Scheduler.RegisterUpdate('GCDHistory_Expire', CheckExpired, 0.2, true)
    enabled = true
    container:Show()
end

function GCDHistory.Disable()
    if not enabled then return end
    StopEvents()
    BUI.Scheduler.SetUpdateEnabled('GCDHistory_Expire', false)
    ClearIcons()
    if container then container:Hide() end
    enabled = false
end

function GCDHistory.SetLocked(locked)
    local settings = GetDB()
    settings.locked = locked
    if container then
        BUI.Dragging.SetLocked(container, locked or container._isAnchored)
        container:SetFrameStrata(locked and 'HIGH' or 'TOOLTIP')
        if locked then ClearIcons() else ShowPreview() end
        container:Show()
    end
    if GCDHistory._lockToggle and GCDHistory._lockToggle.SetValue then GCDHistory._lockToggle:SetValue(not locked) end
end

function GCDHistory.Toggle(on)
    if on then GCDHistory.Enable() else GCDHistory.Disable() end
end

function GCDHistory.UpdateAppearance()
    if not container or not enabled then return end
    styleGeneration = styleGeneration + 1
    local settings = GetDB()
    if settings.locked then UpdateLayout() else ShowPreview() end
    BUI.Dragging.SetLocked(container, settings.locked or container._isAnchored)
    container:Show()
end

BUI.Events:OnLogin('GCDHistory', function()
    if GetDB().enabled then GCDHistory.Enable() end
end)

BUI.Anchor.RegisterCallback('GCDHistory', function()
    if container and container:IsShown() and GetDB().locked then UpdateLayout() end
end)
