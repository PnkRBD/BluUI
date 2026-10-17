local _, BUI = ...

local Hook = BUI.Profiler.Hooker('CDM.Skinning')

local CDM = BUI.CDM
local Pixel = BUI.Pixel
local BLANK = BUI.C.FALLBACK_TEXTURE
local FrameData = CDM.FrameData
local GetFrameData = CDM.GetFrameData
local PackInto = CDM.PackInto

local COUNT_HOST_LEVEL = 30

function CDM.ApplyCooldownSwipeStyle(cooldown, settings)
    local cooldownFrameData = FrameData[cooldown]
    local swipeColor = settings.swipeColor
    local reverse, showEdge = settings.reverseSwipe, settings.showEdge
    local swipeRed, swipeGreen, swipeBlue, swipeAlpha = swipeColor[1], swipeColor[2], swipeColor[3], swipeColor[4]
    cooldownFrameData.reverseSwipe = reverse
    cooldownFrameData.showEdge = showEdge
    cooldownFrameData.swR, cooldownFrameData.swG, cooldownFrameData.swB, cooldownFrameData.swA = swipeRed, swipeGreen, swipeBlue, swipeAlpha
    cooldown:SetUseCircularEdge(false)
    cooldown:SetSwipeTexture(BLANK)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawEdge(showEdge)
    cooldown:SetReverse(reverse)
    cooldown:SetSwipeColor(swipeRed, swipeGreen, swipeBlue, swipeAlpha)
end

local function OnBlizzardIconEnter()
    local db = BUI.GetDB()
    if db.cdm.showTooltips == false then
        GameTooltip:Hide()
    end
end

function CDM.GetAspectTexCoords(zoom, frameWidth, frameHeight, keepAspect)
    if not keepAspect or frameWidth == frameHeight then
        return zoom, 1 - zoom, zoom, 1 - zoom
    end
    local available = 1 - 2 * zoom
    if frameWidth > frameHeight then
        local pad = available * (1 - frameHeight / frameWidth) / 2
        return zoom, 1 - zoom, zoom + pad, 1 - zoom - pad
    else
        local pad = available * (1 - frameWidth / frameHeight) / 2
        return zoom + pad, 1 - zoom - pad, zoom, 1 - zoom
    end
end

local regionBuffer = {}

local function SuppressShow(self)
    self:Hide()
    self:SetAlpha(0)
end

local function KillOverlays(icon)
    local iconFrameData = GetFrameData(icon)
    if iconFrameData.overlaysKilled then return end

    local regions, numRegions = PackInto(regionBuffer, icon:GetRegions())
    for regionIndex = 1, numRegions do
        local region = regions[regionIndex]
        if region:IsObjectType("Texture") then
            local atlas = region:GetAtlas()
            if atlas and atlas:find("CoolDownManager.*Overlay") then
                region:SetTexture(nil)
                region:SetAtlas(nil)
                region:Hide()
                region:SetAlpha(0)
                Hook(region, "Show", SuppressShow)
            end
        end
    end
    iconFrameData.overlaysKilled = true
end

local function KillDebuffBorder(icon)
    local debuffBorder = icon.DebuffBorder
    if not debuffBorder then return end
    local borderFrameData = GetFrameData(debuffBorder)
    if borderFrameData.killed then return end

    debuffBorder:Hide()
    debuffBorder:SetAlpha(0)
    Hook(debuffBorder, "Show", SuppressShow)

    debuffBorder.Texture:Hide()
    debuffBorder.Texture:SetAlpha(0)
    Hook(debuffBorder.Texture, "Show", SuppressShow)

    borderFrameData.killed = true
end

function CDM.RemoveMasks(texture)
    local mask = texture:GetMaskTexture(1)
    while mask do
        texture:RemoveMaskTexture(mask)
        mask = texture:GetMaskTexture(1)
    end
end

local cooldownOverrideGuard = setmetatable({}, { __mode = 'k' })

local GCD_SPELL_ID = 61304

local gcdFilterCurve = C_CurveUtil.CreateCurve()
gcdFilterCurve:SetType(Enum.LuaCurveType.Step)

local cachedGCDInfo, cachedGCDTime, cachedGCDCurveTime = nil, -1, -1

local function GetGCDInfo()
    local now = GetTime()
    if now ~= cachedGCDTime then
        cachedGCDInfo = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
        cachedGCDTime = now
    end
    return cachedGCDInfo
end

local cooldownInfoCache = {}
local cooldownInfoCacheTime = -1
local cooldownDurationCache = {}
local cooldownDurationCacheTime = -1

local function GetCachedSpellCooldown(spellID)
    local now = GetTime()
    if now ~= cooldownInfoCacheTime then
        cooldownInfoCacheTime = now
        wipe(cooldownInfoCache)
    end
    local entry = cooldownInfoCache[spellID]
    if entry == nil then
        entry = C_Spell.GetSpellCooldown(spellID) or false
        cooldownInfoCache[spellID] = entry
    end
    return entry or nil
end

local function GetCachedSpellCooldownDuration(spellID)
    local now = GetTime()
    if now ~= cooldownDurationCacheTime then
        cooldownDurationCacheTime = now
        wipe(cooldownDurationCache)
    end
    local entry = cooldownDurationCache[spellID]
    if entry == nil then
        entry = C_Spell.GetSpellCooldownDuration(spellID) or false
        cooldownDurationCache[spellID] = entry
    end
    return entry or nil
end

local function EvaluateGCDFilteredDesaturation(durationObject)
    local gcdInfo = GetGCDInfo()
    if not gcdInfo or gcdInfo.duration <= 0 then
        return nil
    end
    local gcdRemaining = math.floor(((gcdInfo.startTime + gcdInfo.duration) - GetTime()) * 1000 + 0.5) / 1000
    if gcdRemaining <= 0.0011 then
        return nil
    end
    if cachedGCDTime ~= cachedGCDCurveTime then
        cachedGCDCurveTime = cachedGCDTime
        gcdFilterCurve:ClearPoints()
        gcdFilterCurve:AddPoint(0,                     0)
        gcdFilterCurve:AddPoint(0.0001,                1)
        gcdFilterCurve:AddPoint(gcdRemaining - 0.001,  0)
        gcdFilterCurve:AddPoint(gcdRemaining + 0.001,  0)
        gcdFilterCurve:AddPoint(gcdRemaining + 0.0011, 1)
    end
    return durationObject:EvaluateRemainingDuration(gcdFilterCurve, 0)
end

local buffOverrideEnabled = false
function CDM.RefreshBuffOverrideCache()
    buffOverrideEnabled = BUI.GetDB().cdm.showBuffDuration == false
end

local function ShouldOverrideBuffDuration(cooldown)
    if not buffOverrideEnabled then return false end
    local icon = cooldown:GetParent()
    local iconFrameData = FrameData[icon]
    if iconFrameData and iconFrameData.viewerKey == 'buffs' then return false end
    return true, icon
end

local function ApplyAuraCooldownOverride(cooldown)
    if cooldownOverrideGuard[cooldown] then return end

    local override, icon = ShouldOverrideBuffDuration(cooldown)
    if not override then return end

    local info = icon.cooldownInfo
    if not info then return end
    local spellID = info.overrideSpellID or info.spellID
    if not spellID then return end

    local hasChargeSource = icon:HasVisualDataSource_Charges()
    local replacement = (hasChargeSource and C_Spell.GetSpellChargeDuration(spellID))
        or GetCachedSpellCooldownDuration(spellID)
    if not replacement then return end

    cooldownOverrideGuard[cooldown] = true
    cooldown:SetCooldownFromDurationObject(replacement)
    cooldownOverrideGuard[cooldown] = nil
end

local function ResolveDesaturationValue(icon)
    local info = icon.cooldownInfo
    if not info then return nil end
    local spellID = info.overrideSpellID or info.spellID
    if not spellID then return nil end

    if icon:HasVisualDataSource_Charges() then
        return 0
    end

    local cooldownInfo = GetCachedSpellCooldown(spellID)
    if not cooldownInfo or not cooldownInfo.isActive then return 0 end

    local durationObject = GetCachedSpellCooldownDuration(spellID)
    if not durationObject then return 1 end

    if cooldownInfo.isOnGCD or icon.isOnGCD then
        local gcdResult = EvaluateGCDFilteredDesaturation(durationObject)
        if gcdResult ~= nil then return gcdResult end
    end

    return durationObject:EvaluateRemainingDuration(BUI.Tools.OnCooldownCurve, 0)
end

local function ApplyDesaturation(texture)
    if not buffOverrideEnabled then return end
    local icon = texture:GetParent()
    local iconFrameData = FrameData[icon]
    if iconFrameData and iconFrameData.viewerKey == 'buffs' then return end
    local target = ResolveDesaturationValue(icon)
    if target then texture:SetDesaturation(target) end
end

function CDM.SetShowBuffDuration(show)
    BUI.GetDB().cdm.showBuffDuration = show
    CDM.RefreshBuffOverrideCache()
    for cooldown in pairs(CDM.CDMCooldowns) do
        ApplyAuraCooldownOverride(cooldown)
        local texture = cooldown:GetParent().Icon
        if show then texture:SetDesaturation(0) else ApplyDesaturation(texture) end
    end
end

local desaturating = setmetatable({}, { __mode = 'k' })

local function ReapplyDesaturation(texture)
    if desaturating[texture] then return end
    local iconFrameData = FrameData[texture:GetParent()]
    if iconFrameData and iconFrameData.hidden then return end
    desaturating[texture] = true
    ApplyDesaturation(texture)
    desaturating[texture] = nil
end

local function HookIconDesaturation(texture)
    local frameData = GetFrameData(texture)
    if frameData.desatHooked then return end
    frameData.desatHooked = true

    Hook(texture, "SetDesaturation", ReapplyDesaturation)
    Hook(texture, "SetDesaturated", ReapplyDesaturation)
end

local function ReenforceCooldownStyle(cooldown)
    if cooldownOverrideGuard[cooldown] then return end
    local cooldownFrameData = FrameData[cooldown]
    if not cooldownFrameData or not cooldownFrameData.cdSetup then return end
    ApplyAuraCooldownOverride(cooldown)
end

local reclaimingStyle = setmetatable({}, { __mode = 'k' })

local function OnCooldownApplied(cooldown)
    local iconFrameData = FrameData[cooldown:GetParent()]
    if iconFrameData and iconFrameData.hidden then return end
    ReenforceCooldownStyle(cooldown)
    reclaimingStyle[cooldown] = true
    CDM.RestyleCooldown(cooldown)
    reclaimingStyle[cooldown] = nil
end

function CDM.ReclaimShownIconStyle(icon)
    OnCooldownApplied(icon.Cooldown)
    ApplyDesaturation(icon.Icon)
end

local function ReclaimDrawEdge(cooldown, drawEdge)
    if reclaimingStyle[cooldown] then return end
    local cooldownFrameData = FrameData[cooldown]
    if not cooldownFrameData or not cooldownFrameData.cdSetup then return end
    local wanted = cooldownFrameData.showEdge or false
    if not issecretvalue(drawEdge) and (drawEdge and true or false) == wanted then return end
    reclaimingStyle[cooldown] = true
    cooldown:SetDrawEdge(wanted)
    reclaimingStyle[cooldown] = nil
end

local function ReclaimReverse(cooldown, reverse)
    if reclaimingStyle[cooldown] then return end
    local cooldownFrameData = FrameData[cooldown]
    if not cooldownFrameData or not cooldownFrameData.cdSetup then return end
    local wanted = cooldownFrameData.reverseSwipe or false
    if not issecretvalue(reverse) and (reverse and true or false) == wanted then return end
    reclaimingStyle[cooldown] = true
    cooldown:SetReverse(wanted)
    reclaimingStyle[cooldown] = nil
end

local function SwipeColorMatches(cooldownFrameData, red, green, blue, alpha)
    if issecretvalue(red) or issecretvalue(green) or issecretvalue(blue) or issecretvalue(alpha) then return false end
    return red == cooldownFrameData.swR and green == cooldownFrameData.swG and blue == cooldownFrameData.swB and alpha == cooldownFrameData.swA
end

local function ReclaimSwipeColor(cooldown, red, green, blue, alpha)
    if reclaimingStyle[cooldown] then return end
    local cooldownFrameData = FrameData[cooldown]
    if not cooldownFrameData or not cooldownFrameData.cdSetup or cooldownFrameData.swA == nil then return end
    if SwipeColorMatches(cooldownFrameData, red, green, blue, alpha) then return end
    reclaimingStyle[cooldown] = true
    cooldown:SetSwipeColor(cooldownFrameData.swR, cooldownFrameData.swG, cooldownFrameData.swB, cooldownFrameData.swA)
    reclaimingStyle[cooldown] = nil
end

local function ReclaimBling(cooldown, drawBling)
    if reclaimingStyle[cooldown] then return end
    local cooldownFrameData = FrameData[cooldown]
    if not cooldownFrameData or not cooldownFrameData.cdSetup then return end
    if not issecretvalue(drawBling) and not drawBling then return end
    reclaimingStyle[cooldown] = true
    cooldown:SetDrawBling(false)
    reclaimingStyle[cooldown] = nil
end

function CDM.RefreshCooldownStyleFlags()
    for cooldown in pairs(CDM.CDMCooldowns) do
        FrameData[cooldown].styleVer = nil
    end
    for keyIndex = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[keyIndex]
        local settings = CDM.GetSettings(key)
        local list, count = CDM.GetTrackedIcons(key)
        for iconIndex = 1, count do
            local cooldown = list[iconIndex].Cooldown
            local cooldownFrameData = FrameData[cooldown]
            if cooldownFrameData and cooldownFrameData.cdSetup then
                cooldownFrameData.showEdge = settings.showEdge
                cooldown:SetDrawEdge(settings.showEdge)
            end
        end
    end
end

local function SetupCooldown(cooldown)
    local cooldownFrameData = GetFrameData(cooldown)
    if cooldownFrameData.cdSetup then return end
    cooldownFrameData.cdSetup = true

    CDM.CDMCooldowns[cooldown] = true

    cooldown:SetDrawSwipe(true)
    cooldown:SetHideCountdownNumbers(false)

    if not cooldownFrameData.cdHooked then
        cooldownFrameData.cdHooked = true
        Hook(cooldown, 'SetCooldown', OnCooldownApplied)
        Hook(cooldown, 'SetCooldownFromDurationObject', ReenforceCooldownStyle)
        Hook(cooldown, 'SetDrawEdge', ReclaimDrawEdge)
        Hook(cooldown, 'SetReverse', ReclaimReverse)
        Hook(cooldown, 'SetSwipeColor', ReclaimSwipeColor)
        Hook(cooldown, 'SetDrawBling', ReclaimBling)
    end
end

function CDM.CooldownTextCenterDrop(fontSize)
    return math.floor(fontSize * 0.1 + 0.5)
end

local function StyleCooldownText(cooldown, settings)
    local fontString = BUI.Tools.CooldownFontString(cooldown)
    if not fontString then return end

    local fontSize = settings.cooldownTextSize
    local position = settings.cooldownTextPosition
    local offsetY = settings.cooldownTextOffsetY
    if position == "CENTER" and fontSize > 0 then
        offsetY = offsetY - CDM.CooldownTextCenterDrop(fontSize)
    end
    local cdTextColor = settings.cooldownTextColor

    Pixel.ApplyFont(fontString, fontSize, BUI.GetCDMFont())
    fontString:ClearAllPoints()
    fontString:SetPoint(position, cooldown, position, settings.cooldownTextOffsetX, offsetY)
    fontString:SetTextColor(cdTextColor[1], cdTextColor[2], cdTextColor[3], cdTextColor[4])
    fontString:SetDrawLayer("OVERLAY", 7)
end

function CDM.ApplyFlashGeometry(icon, settings)
    local flash = icon.CooldownFlash
    if not flash then return end
    local overhangX = Pixel.Scale(settings.iconWidth * 0.12 - 4)
    local overhangY = Pixel.Scale(settings.iconHeight * 0.12 - 4)
    flash:ClearAllPoints()
    flash:SetPoint("TOPLEFT", icon, "TOPLEFT", -overhangX, overhangY)
    flash:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", overhangX, -overhangY)
end

local function OnCooldownFlashShow(self)
    local frameData = FrameData[self]
    if not frameData then return end
    local settings = frameData.viewerKey and CDM.GetSettings(frameData.viewerKey)
    if settings and not settings.showFlash then
        self:Hide()
        self.FlashAnim:Stop()
    end
end

local function OnCooldownFlashPlay(self)
    local flash = self:GetParent()
    local frameData = FrameData[flash]
    if not frameData then return end
    local settings = frameData.viewerKey and CDM.GetSettings(frameData.viewerKey)
    if settings and not settings.showFlash then
        self:Stop()
        flash:Hide()
    end
end

local function ResolveOverrideTexture(icon, iconFrameData)
    if iconFrameData.customIcon then return nil end
    local info = icon.cooldownInfo
    if not info then return nil end
    local overrides = CDM.GetIconOverrides(BUI.GetDB().cdm[iconFrameData.viewerKey])
    local overrideID = BUI.Tools.SafeNum(info.overrideSpellID)
    local baseID = BUI.Tools.SafeNum(info.spellID)
    return (overrideID and overrides[overrideID]) or (baseID and overrides[baseID])
end

local function ApplyIconOverrideTexture(icon, iconFrameData)
    local wantedTexture = ResolveOverrideTexture(icon, iconFrameData)
    if not wantedTexture then return end
    local texture = icon.Icon
    local current = texture:GetTexture()
    if issecretvalue(current) then current = nil end
    if current == wantedTexture then return end
    iconFrameData.locking = true
    texture:SetTexture(wantedTexture)
    iconFrameData.locking = false
end

local function OnIconTextureChanged(texture)
    local icon = texture:GetParent()
    local iconFrameData = FrameData[icon]
    if not iconFrameData or iconFrameData.locking then return end
    ApplyIconOverrideTexture(icon, iconFrameData)
end

function CDM.RefreshIconOverrideForSpell(spellID)
    CDM.ForAllIcons(function(icon)
        local iconFrameData = FrameData[icon]
        if iconFrameData.customIcon then return end
        local info = icon.cooldownInfo
        if not info then return end
        local base = BUI.Tools.SafeNum(info.spellID)
        local override = BUI.Tools.SafeNum(info.overrideSpellID)
        if base ~= spellID and override ~= spellID then return end
        local wantedTexture = ResolveOverrideTexture(icon, iconFrameData)
            or (override and C_Spell.GetSpellTexture(override))
            or (base and C_Spell.GetSpellTexture(base))
        if not wantedTexture then return end
        iconFrameData.locking = true
        icon.Icon:SetTexture(wantedTexture)
        iconFrameData.locking = false
    end)
end

function CDM.SkinIcon(icon, settings, key)
    local texture = icon.Icon
    local currentVersion = CDM.state.skinVersion
    local iconFrameData = GetFrameData(icon)
    iconFrameData.viewerKey = key
    if iconFrameData.skinVer == currentVersion then return end

    if not iconFrameData.texHooked then
        iconFrameData.texHooked = true
        Hook(texture, 'SetTexture', OnIconTextureChanged)
    end
    ApplyIconOverrideTexture(icon, iconFrameData)

    CDM.RemoveMasks(texture)

    local borderSize = settings.borderSize
    local scaledEdge = Pixel.Scale(borderSize)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", icon, "TOPLEFT", scaledEdge, -scaledEdge)
    texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -scaledEdge, scaledEdge)
    texture:SetSnapToPixelGrid(false)
    texture:SetTexelSnappingBias(0)
    texture:SetTexCoord(CDM.GetAspectTexCoords(settings.zoom, settings.iconWidth, settings.iconHeight, settings.keepAspectRatio))

    KillOverlays(icon)
    KillDebuffBorder(icon)
    icon:EnableMouse(false)
    HookIconDesaturation(texture)

    local cooldown = icon.Cooldown
    SetupCooldown(cooldown)

    local cooldownEdge = scaledEdge - Pixel.PixelSize(1)
    if cooldownEdge < 0 then cooldownEdge = 0 end
    cooldown:ClearAllPoints()
    cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", cooldownEdge, -cooldownEdge)
    cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -cooldownEdge, cooldownEdge)
    local cooldownFrameData = FrameData[cooldown]
    cooldownFrameData.anchoredParent = nil
    cooldownFrameData.styleVer = nil
    CDM.ApplyCooldownSwipeStyle(cooldown, settings)
    local decimalThreshold = settings.showCooldownDecimals and settings.cooldownDecimalThreshold or 0
    cooldown:SetCountdownMillisecondsThreshold(decimalThreshold)
    cooldown:SetCountdownFormatter(BUI.TimeFormat.GetFormatter(decimalThreshold, settings.cooldownWarnSeconds, settings.cooldownWarnColor))

    local flash = icon.CooldownFlash
    if flash then
        flash:SetAlpha(1)
        CDM.ApplyFlashGeometry(icon, settings)
        flash.Flipbook:SetBlendMode("ADD")
        local flashFrameData = GetFrameData(flash)
        if not flashFrameData.showHooked then
            flashFrameData.showHooked = true
            Hook(flash, "Show", OnCooldownFlashShow)
            Hook(flash.FlashAnim, "Play", OnCooldownFlashPlay)
        end
        flashFrameData.viewerKey = key
        if not settings.showFlash then
            flash:Hide()
            flash.FlashAnim:Stop()
        end
    end
    if icon.OutOfRange then
        icon.OutOfRange:ClearAllPoints()
        icon.OutOfRange:SetAllPoints(texture)
        icon.OutOfRange:SetSnapToPixelGrid(false)
        icon.OutOfRange:SetTexelSnappingBias(0)
    end

    CDM.HideBlizzardGlow(icon)

    local countFont = CDM.GetCountFont(icon)
    if countFont then
        local countHost = countFont:GetParent()
        if countHost ~= icon then countHost:SetFrameLevel(icon:GetFrameLevel() + COUNT_HOST_LEVEL) end
        countFont:SetDrawLayer("OVERLAY", 7)
        countFont:ClearAllPoints()
        countFont:SetPoint(settings.textPosition, texture, settings.textPosition, settings.textOffsetX, settings.textOffsetY)
        Pixel.ApplyFont(countFont, settings.textSize, BUI.GetCDMFont())
        local textColor = settings.textColor
        countFont:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
    end

    StyleCooldownText(cooldown, settings)

    local borderColor = settings.borderColor
    if borderSize > 0 then
        Pixel.ApplyBorder(icon, borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    else
        Pixel.HideBorder(icon)
    end

    if not iconFrameData.customIcon and not iconFrameData.tooltipHooked then
        iconFrameData.tooltipHooked = true
        icon:HookScript("OnEnter", BUI.Profiler.Script('CDM.Skinning icon OnEnter', OnBlizzardIconEnter))
    end

    iconFrameData.skinVer = currentVersion

    ApplyDesaturation(texture)
end

local function UnskinIcon(icon)
    Pixel.HideBorder(icon)
    icon:EnableMouse(true)

    CDM.StopProcGlow(icon)
    CDM.ShowBlizzardGlow(icon)

    local texture = icon.Icon
    texture:ClearAllPoints()
    texture:SetAllPoints(icon)
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local cooldown = icon.Cooldown
    local cooldownFrameData = FrameData[cooldown]
    if cooldownFrameData then cooldownFrameData.cdSetup = nil end
    CDM.CDMCooldowns[cooldown] = nil
    cooldown:ClearAllPoints()
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawSwipe(true)
    cooldown:SetDrawBling(true)
    cooldown:SetDrawEdge(true)
    cooldown:SetReverse(false)
    cooldown:SetHideCountdownNumbers(false)
    cooldown:SetSwipeColor(0, 0, 0, 0.58)

    if icon.CooldownFlash then
        icon.CooldownFlash:SetAlpha(1)
    end

    FrameData[icon].skinVer = nil
end

function CDM.UnskinViewer(key)
    local list, count = CDM.GetTrackedIcons(key)
    for iconIndex = 1, count do
        UnskinIcon(list[iconIndex])
    end
end
