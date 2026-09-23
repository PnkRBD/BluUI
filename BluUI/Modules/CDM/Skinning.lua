local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('CDM.Skinning')

local hooksecurefunc = BUI.Prof.MakeHooker('cdmskin')

local CDM = BUI.CDM
local Pixel = BUI.Pixel
local BLANK = BUI.C.FALLBACK_TEXTURE
local FrameData = CDM.FrameData
local GetFrameData = CDM.GetFrameData
local PackInto = CDM.PackInto
local COUNT_HOST_LEVEL = 30

function CDM.ResolveSwipeColor(settings)
    local swipeColor = settings and settings.swipeColor
    if swipeColor then return swipeColor[1] or 0, swipeColor[2] or 0, swipeColor[3] or 0, swipeColor[4] or 0.58 end
    return 0, 0, 0, 0.58
end

local function OnBlizzardIconEnter()
    local db = BUI.GetDB()
    if db.cdm.showTooltips == false then
        GameTooltip:Hide()
    end
end

function CDM.GetAspectTexCoords(zoom, frameWidth, frameHeight, keepAspect)
    if not keepAspect or not frameWidth or not frameHeight or frameWidth == frameHeight then
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
local regionBuffer2 = {}

local function SuppressShow(self)
    self:Hide()
    self:SetAlpha(0)
end

local function KillOverlays(icon)
    local iconFrameData = FrameData[icon]
    if iconFrameData and iconFrameData.overlaysKilled then return end

    local regions, numRegions = PackInto(regionBuffer, icon:GetRegions())
    for regionIndex = 1, numRegions do
        local region = regions[regionIndex]
        if region and region:IsObjectType("Texture") then
            local atlas = region:GetAtlas()
            if atlas and atlas:find("CoolDownManager.*Overlay") then
                region:SetTexture(nil)
                region:SetAtlas(nil)
                region:Hide()
                region:SetAlpha(0)
                hooksecurefunc(region, "Show", SuppressShow)
            end
        end
    end
    if not iconFrameData then iconFrameData = GetFrameData(icon) end
    iconFrameData.overlaysKilled = true
end

local function KillDebuffBorder(icon)
    local debuffBorder = icon.DebuffBorder
    if not debuffBorder then return end
    local borderFrameData = FrameData[debuffBorder]
    if borderFrameData and borderFrameData.killed then return end

    debuffBorder:Hide()
    debuffBorder:SetAlpha(0)
    hooksecurefunc(debuffBorder, "Show", SuppressShow)

    if debuffBorder.Texture then
        debuffBorder.Texture:Hide()
        debuffBorder.Texture:SetAlpha(0)
        hooksecurefunc(debuffBorder.Texture, "Show", SuppressShow)
    end

    if not borderFrameData then borderFrameData = GetFrameData(debuffBorder) end
    borderFrameData.killed = true
end

local function StripBlizzard(icon)
    for elementIndex = 1, CDM.STRIP_ELEMENTS_COUNT do
        local element = CDM.STRIP_ELEMENTS[elementIndex]
        if icon[element] then
            icon[element]:Hide()
        end
    end

    if icon.SetBackdrop then
        icon:SetBackdrop(nil)
    end
    if icon.SetNormalTexture then
        icon:SetNormalTexture(nil)
    end
    if icon.SetHighlightTexture then
        icon:SetHighlightTexture(nil)
    end
    if icon.SetPushedTexture then
        icon:SetPushedTexture(nil)
    end

    icon:EnableMouse(false)
end

local function RemoveMasks(texture)
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
    if not gcdInfo or not gcdInfo.startTime or not gcdInfo.duration or gcdInfo.duration <= 0 then
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
    return durationObject:EvaluateRemainingDuration(gcdFilterCurve, 0) or 0
end

local buffOverrideEnabled = false
function CDM.RefreshBuffOverrideCache()
    buffOverrideEnabled = BUI.GetDB().cdm.showBuffDuration == false
end

local function IsBuffOverrideEnabled()
    return buffOverrideEnabled
end

local function ShouldOverrideBuffDuration(cooldown)
    if not IsBuffOverrideEnabled() then return false end
    local icon = cooldown:GetParent()
    if not icon then return false end
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
CDM.ForceSpellCooldownIfBuffHidden = ApplyAuraCooldownOverride

local function ResolveDesaturationValue(icon)
    local info = icon and icon.cooldownInfo
    if not info then return nil end
    local spellID = info.overrideSpellID or info.spellID
    if not spellID then return nil end

    if type(icon.HasVisualDataSource_Charges) == "function" and icon:HasVisualDataSource_Charges() then
        return 0
    end

    local cooldownInfo = GetCachedSpellCooldown(spellID)
    if not cooldownInfo or not cooldownInfo.isActive then return 0 end

    local durationObject = GetCachedSpellCooldownDuration(spellID)
    if not durationObject or not durationObject.EvaluateRemainingDuration then return 1 end

    if cooldownInfo.isOnGCD or icon.isOnGCD then
        local gcdResult = EvaluateGCDFilteredDesaturation(durationObject)
        if gcdResult ~= nil then return gcdResult end
    end

    return durationObject:EvaluateRemainingDuration(BUI.Tools.OnCooldownCurve, 0) or 0
end

local function ApplyDesaturation(texture)
    if not IsBuffOverrideEnabled() then return end
    local icon = texture:GetParent()
    if not icon then return end
    local iconFrameData = FrameData[icon]
    if iconFrameData and iconFrameData.viewerKey == 'buffs' then return end
    local target = ResolveDesaturationValue(icon)
    if target then texture:SetDesaturation(target) end
end
CDM.RefreshIconDesaturation = ApplyDesaturation

local function HookIconDesaturation(icon)
    local texture = icon and icon.Icon
    if not texture then return end
    local frameData = FrameData[texture] or GetFrameData(texture)
    if frameData.desatHooked then return end
    frameData.desatHooked = true

    local applying = false
    local function reapply()
        if applying then return end
        applying = true
        ApplyDesaturation(texture)
        applying = false
    end

    hooksecurefunc(texture, "SetDesaturation", reapply)
    hooksecurefunc(texture, "SetDesaturated", reapply)
end

local function ReenforceCooldownStyle(cooldown)
    if cooldownOverrideGuard[cooldown] then return end
    local cooldownFrameData = FrameData[cooldown]
    if not cooldownFrameData or not cooldownFrameData.cdSetup then return end
    ApplyAuraCooldownOverride(cooldown)
end

local function OnCooldownApplied(cooldown)
    ReenforceCooldownStyle(cooldown)
    CDM.RestyleCooldown(cooldown)
end

local reclaimingStyle = false

local function ReclaimDrawEdge(cooldown)
    if reclaimingStyle then return end
    local cooldownFrameData = FrameData[cooldown]
    if not cooldownFrameData or not cooldownFrameData.cdSetup then return end
    reclaimingStyle = true
    cooldown:SetDrawEdge(cooldownFrameData.showEdge or false)
    reclaimingStyle = false
end

local function ReclaimReverse(cooldown)
    if reclaimingStyle then return end
    local cooldownFrameData = FrameData[cooldown]
    if not cooldownFrameData or not cooldownFrameData.cdSetup then return end
    reclaimingStyle = true
    cooldown:SetReverse(cooldownFrameData.reverseSwipe or false)
    reclaimingStyle = false
end

local function ReclaimSwipeColor(cooldown)
    if reclaimingStyle then return end
    local cooldownFrameData = FrameData[cooldown]
    if not cooldownFrameData or not cooldownFrameData.cdSetup or cooldownFrameData.swA == nil then return end
    reclaimingStyle = true
    cooldown:SetSwipeColor(cooldownFrameData.swR, cooldownFrameData.swG, cooldownFrameData.swB, cooldownFrameData.swA)
    reclaimingStyle = false
end

local function ReclaimBling(cooldown)
    if reclaimingStyle then return end
    local cooldownFrameData = FrameData[cooldown]
    if not cooldownFrameData or not cooldownFrameData.cdSetup then return end
    reclaimingStyle = true
    cooldown:SetDrawBling(false)
    reclaimingStyle = false
end

function CDM.RefreshCooldownStyleFlags()
    for keyIndex = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[keyIndex]
        local settings = CDM.GetSettings(key)
        if settings then
            local list, count = CDM.GetTrackedIcons(key)
            for iconIndex = 1, count do
                local icon = list[iconIndex]
                local cooldown = icon and icon.Cooldown
                local cooldownFrameData = cooldown and FrameData[cooldown]
                if cooldownFrameData and cooldownFrameData.cdSetup then
                    cooldownFrameData.showEdge = settings.showEdge
                    cooldown:SetDrawEdge(cooldownFrameData.showEdge)
                end
            end
        end
    end
end

local function SetupCooldown(icon)
    local cooldown = icon.Cooldown
    if not cooldown then return end
    local cooldownFrameData = FrameData[cooldown]
    if cooldownFrameData and cooldownFrameData.cdSetup then return end
    if not cooldownFrameData then cooldownFrameData = GetFrameData(cooldown) end
    cooldownFrameData.cdSetup = true

    CDM.CDMCooldowns[cooldown] = true

    cooldown:SetDrawSwipe(true)
    cooldown:SetUseCircularEdge(false)
    cooldown:SetSwipeTexture(BLANK)
    cooldown:SetHideCountdownNumbers(false)

    local iconFrameData = FrameData[icon]
    local viewerKey = iconFrameData and iconFrameData.viewerKey
    local settings = viewerKey and CDM.GetSettings(viewerKey)
    cooldownFrameData.swR, cooldownFrameData.swG, cooldownFrameData.swB, cooldownFrameData.swA = CDM.ResolveSwipeColor(settings)
    cooldown:SetSwipeColor(cooldownFrameData.swR, cooldownFrameData.swG, cooldownFrameData.swB, cooldownFrameData.swA)
    cooldownFrameData.reverseSwipe = settings and settings.reverseSwipe or false
    cooldownFrameData.showEdge = settings and settings.showEdge or false
    cooldown:SetReverse(cooldownFrameData.reverseSwipe)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawEdge(cooldownFrameData.showEdge)

    if not cooldownFrameData.cdHooked then
        cooldownFrameData.cdHooked = true
        hooksecurefunc(cooldown, 'SetCooldown', OnCooldownApplied)
        hooksecurefunc(cooldown, 'SetCooldownFromDurationObject', ReenforceCooldownStyle)
        hooksecurefunc(cooldown, 'SetDrawEdge', ReclaimDrawEdge)
        hooksecurefunc(cooldown, 'SetReverse', ReclaimReverse)
        hooksecurefunc(cooldown, 'SetSwipeColor', ReclaimSwipeColor)
        hooksecurefunc(cooldown, 'SetDrawBling', ReclaimBling)
    end
end

function CDM.CooldownTextCenterDrop(fontSize)
    return math.floor(fontSize * 0.1 + 0.5)
end

local function StyleCooldownText(icon, settings)
    local cooldown = icon.Cooldown
    if not cooldown then return end

    local fontSize = settings.cooldownTextSize
    local position = settings.cooldownTextPosition
    local offsetX, offsetY = settings.cooldownTextOffsetX, settings.cooldownTextOffsetY
    if position == "CENTER" and fontSize > 0 then
        offsetY = offsetY - CDM.CooldownTextCenterDrop(fontSize)
    end
    local cdTextColor = settings.cooldownTextColor

    local cooldownFrameData = FrameData[cooldown]
    if cooldownFrameData and cooldownFrameData.cdTextStyled then
        local fontString = cooldownFrameData.cdTextFS
        if fontString then
            if fontSize > 0 then
                Pixel.ApplyFont(fontString, fontSize, BUI.GetCDMFont())
            end
            fontString:ClearAllPoints()
            fontString:SetPoint(position, cooldown, position, offsetX, offsetY)
            if cdTextColor then fontString:SetTextColor(cdTextColor[1], cdTextColor[2], cdTextColor[3], cdTextColor[4]) end
            fontString:SetDrawLayer("OVERLAY", 7)
        end
        return
    end

    local foundFontString = nil
    local regions, numRegions = PackInto(regionBuffer, cooldown:GetRegions())
    for regionIndex = 1, numRegions do
        local region = regions[regionIndex]
        if region and region:GetObjectType() == "FontString" then
            if fontSize > 0 then
                Pixel.ApplyFont(region, fontSize, BUI.GetCDMFont())
            end
            region:ClearAllPoints()
            region:SetPoint(position, cooldown, position, offsetX, offsetY)
            if cdTextColor then region:SetTextColor(cdTextColor[1], cdTextColor[2], cdTextColor[3], cdTextColor[4]) end
            region:SetDrawLayer("OVERLAY", 7)
            foundFontString = region
        end
    end

    if not foundFontString then
        local children, numChildren = PackInto(regionBuffer, cooldown:GetChildren())
        for childIndex = 1, numChildren do
            local child = children[childIndex]
            if child and child.GetRegions then
                local childRegions, numChildRegions = PackInto(regionBuffer2, child:GetRegions())
                for childRegionIndex = 1, numChildRegions do
                    local region = childRegions[childRegionIndex]
                    if region and region:GetObjectType() == "FontString" then
                        if fontSize > 0 then
                            Pixel.ApplyFont(region, fontSize, BUI.GetCDMFont())
                        end
                        region:ClearAllPoints()
                        region:SetPoint(position, child, position, offsetX, offsetY)
                        if cdTextColor then region:SetTextColor(cdTextColor[1], cdTextColor[2], cdTextColor[3], cdTextColor[4]) end
                        region:SetDrawLayer("OVERLAY", 7)
                        foundFontString = region
                    end
                end
            end
        end
    end

    if not cooldownFrameData then cooldownFrameData = GetFrameData(cooldown) end
    cooldownFrameData.cdTextStyled = true
    cooldownFrameData.cdTextFS = foundFontString
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

function CDM.OnCooldownFlashShow(self)
    local frameData = FrameData[self]
    if not frameData then return end
    local settings = frameData.viewerKey and CDM.GetSettings(frameData.viewerKey)
    if settings and not settings.showFlash then
        self:Hide()
        if self.FlashAnim then self.FlashAnim:Stop() end
    end
end

function CDM.OnCooldownFlashPlay(self)
    local flash = self:GetParent()
    local frameData = flash and FrameData[flash]
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
    local key = iconFrameData.viewerKey
    local config = key and BUI.GetDB().cdm[key]
    if not config then return nil end
    local overrides = CDM.GetIconOverrides(config)
    local overrideID = BUI.Tools.SafeNum(info.overrideSpellID)
    local baseID = BUI.Tools.SafeNum(info.spellID)
    return (overrideID and overrides[overrideID]) or (baseID and overrides[baseID]) or nil
end

function CDM.ApplyIconOverrideTexture(icon)
    local texture = icon.Icon
    if not texture then return end
    local iconFrameData = FrameData[icon]
    if not iconFrameData then return end
    local wantedTexture = ResolveOverrideTexture(icon, iconFrameData)
    if not wantedTexture then return end
    local current = texture:GetTexture()
    if issecretvalue(current) then current = nil end
    if current == wantedTexture then return end
    iconFrameData.locking = true
    texture:SetTexture(wantedTexture)
    iconFrameData.locking = false
end

local function OnIconTextureChanged(texture)
    local icon = texture:GetParent()
    local iconFrameData = icon and FrameData[icon]
    if not iconFrameData or iconFrameData.locking then return end
    CDM.ApplyIconOverrideTexture(icon)
end

function CDM.RefreshIconOverrideForSpell(spellID)
    CDM.ForAllIcons(function(icon)
        local iconFrameData = FrameData[icon]
        if not iconFrameData or iconFrameData.customIcon then return end
        local info = icon.cooldownInfo
        if not info then return end
        local base = BUI.Tools.SafeNum(info.spellID)
        local override = BUI.Tools.SafeNum(info.overrideSpellID)
        if base ~= spellID and override ~= spellID then return end
        local texture = icon.Icon
        if not texture then return end
        local wantedTexture = ResolveOverrideTexture(icon, iconFrameData)
            or (override and C_Spell.GetSpellTexture(override))
            or (base and C_Spell.GetSpellTexture(base))
        if not wantedTexture then return end
        iconFrameData.locking = true
        texture:SetTexture(wantedTexture)
        iconFrameData.locking = false
    end)
end

function CDM.SkinIcon(icon, settings, key)
    local texture = icon.Icon
    if not texture then return end

    local currentVersion = CDM.state.skinVersion
    local iconFrameData = FrameData[icon] or GetFrameData(icon)
    iconFrameData.viewerKey = key
    if iconFrameData.skinVer == currentVersion then return end

    if not iconFrameData.texHooked then
        iconFrameData.texHooked = true
        hooksecurefunc(texture, 'SetTexture', OnIconTextureChanged)
    end
    CDM.ApplyIconOverrideTexture(icon)

    RemoveMasks(texture)

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
    StripBlizzard(icon)
    HookIconDesaturation(icon)

    for elementIndex = 1, CDM.HIDE_ELEMENTS_COUNT do
        local name = CDM.HIDE_ELEMENTS[elementIndex]
        if icon[name] then
            icon[name]:Hide()
        end
    end

    SetupCooldown(icon)

    local db = BUI.GetDB()
    local cooldown = icon.Cooldown
    if cooldown then
        local cooldownEdge = scaledEdge - Pixel.PixelSize(1)
        if cooldownEdge < 0 then cooldownEdge = 0 end
        cooldown:ClearAllPoints()
        cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", cooldownEdge, -cooldownEdge)
        cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -cooldownEdge, cooldownEdge)
        local swipeRed, swipeGreen, swipeBlue, swipeAlpha = CDM.ResolveSwipeColor(settings)
        local cooldownFrameData = FrameData[cooldown]
        if cooldownFrameData then
            cooldownFrameData.reverseSwipe = settings.reverseSwipe
            cooldownFrameData.showEdge = settings.showEdge
            cooldownFrameData.swR, cooldownFrameData.swG, cooldownFrameData.swB, cooldownFrameData.swA = swipeRed, swipeGreen, swipeBlue, swipeAlpha
        end
        cooldown:SetDrawBling(false)
        cooldown:SetDrawEdge(settings.showEdge)
        cooldown:SetReverse(settings.reverseSwipe)
        cooldown:SetSwipeColor(swipeRed, swipeGreen, swipeBlue, swipeAlpha)
        local decimalThreshold = settings.showCooldownDecimals and settings.cooldownDecimalThreshold or 0
        cooldown:SetCountdownMillisecondsThreshold(decimalThreshold)
        cooldown:SetCountdownFormatter(BUI.TimeFormat.GetFormatter(decimalThreshold, settings.cooldownWarnSeconds, settings.cooldownWarnColor))
    end
    if icon.CooldownFlash then
        icon.CooldownFlash:SetAlpha(1)
        CDM.ApplyFlashGeometry(icon, settings)

        if icon.CooldownFlash.Flipbook then
            icon.CooldownFlash.Flipbook:SetBlendMode("ADD")
        end
        local flashFrameData = FrameData[icon.CooldownFlash]
        if not flashFrameData or not flashFrameData.showHooked then
            if not flashFrameData then flashFrameData = GetFrameData(icon.CooldownFlash) end
            flashFrameData.showHooked = true
            hooksecurefunc(icon.CooldownFlash, "Show", CDM.OnCooldownFlashShow)
            local anim = icon.CooldownFlash.FlashAnim
            if anim then
                hooksecurefunc(anim, "Play", CDM.OnCooldownFlashPlay)
            end
        end
        flashFrameData.viewerKey = key
        if not settings.showFlash then
            icon.CooldownFlash:Hide()
            if icon.CooldownFlash.FlashAnim then icon.CooldownFlash.FlashAnim:Stop() end
        end
    end
    local textLevel = icon:GetFrameLevel() + CDM.GLOW_LAYER + 1
    if icon.ChargeCount and icon.ChargeCount.SetFrameLevel then icon.ChargeCount:SetFrameLevel(textLevel) end
    if icon.Applications and icon.Applications.SetFrameLevel then icon.Applications:SetFrameLevel(textLevel) end
    if icon.OutOfRange then
        icon.OutOfRange:ClearAllPoints()
        icon.OutOfRange:SetAllPoints(texture)
        icon.OutOfRange:SetSnapToPixelGrid(false)
        icon.OutOfRange:SetTexelSnappingBias(0)
    end

    if db.cdm.glow.enabled then
        CDM.HideBlizzardGlow(icon)
    else
        if icon.Glow then
            icon.Glow:Show()
        end
    end

    local countFont = CDM.GetCountFont(icon)
    if countFont then
        local countHost = countFont:GetParent()
        if countHost ~= icon then countHost:SetFrameLevel(icon:GetFrameLevel() + COUNT_HOST_LEVEL) end
        countFont:SetDrawLayer("OVERLAY", 7)
        countFont:ClearAllPoints()
        countFont:SetPoint(settings.textPosition, texture, settings.textPosition, settings.textOffsetX, settings.textOffsetY)
        local textSize = settings.textSize
        if textSize > 0 then
            Pixel.ApplyFont(countFont, textSize, BUI.GetCDMFont())
        end
        local textColor = settings.textColor
        countFont:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
    end

    StyleCooldownText(icon, settings)

    if icon.DurationBar then
        local bar = icon.DurationBar
        bar:SetStatusBarTexture(BUI.GetGlobalTexture())
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", scaledEdge, scaledEdge)
        bar:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -scaledEdge, scaledEdge)
        bar:SetHeight(Pixel.Scale(4))
        bar:SetAlpha(1)
        bar:Show()
    end

    local borderColor = settings.borderColor
    if borderSize > 0 then
        Pixel.ApplyBorder(icon, borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        Pixel.ShowBorder(icon)
    else
        Pixel.HideBorder(icon)
    end

    if not iconFrameData then iconFrameData = GetFrameData(icon) end
    if not iconFrameData.customIcon and not iconFrameData.tooltipHooked then
        iconFrameData.tooltipHooked = true
        HookScript(icon, "OnEnter", OnBlizzardIconEnter)
    end

    iconFrameData.viewerKey = key
    iconFrameData.skinVer = currentVersion

    if icon.Icon and IsBuffOverrideEnabled() and key ~= 'buffs' then
        ApplyDesaturation(icon.Icon)
    end
end

function CDM.UnskinIcon(icon)
    Pixel.HideBorder(icon)
    icon:EnableMouse(true)

    local iconFrameData = FrameData[icon]

    CDM.StopProcGlow(icon)
    CDM.ShowBlizzardGlow(icon)

    for elementIndex = 1, CDM.SHOW_ELEMENTS_COUNT do
        local name = CDM.SHOW_ELEMENTS[elementIndex]
        if icon[name] then
            icon[name]:Show()
        end
    end

    local texture = icon.Icon
    if texture then
        texture:ClearAllPoints()
        texture:SetAllPoints(icon)
        texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    if icon.Cooldown then
        local cooldownFrameData = FrameData[icon.Cooldown]
        if cooldownFrameData then cooldownFrameData.cdSetup = nil end
        CDM.CDMCooldowns[icon.Cooldown] = nil
        icon.Cooldown:ClearAllPoints()
        icon.Cooldown:SetAllPoints(icon)
        icon.Cooldown:SetDrawSwipe(true)
        icon.Cooldown:SetDrawBling(true)
        icon.Cooldown:SetDrawEdge(true)
        icon.Cooldown:SetReverse(false)
        icon.Cooldown:SetHideCountdownNumbers(false)
        icon.Cooldown:SetSwipeColor(0, 0, 0, 0.58)
    end

    if icon.CooldownFlash then
        icon.CooldownFlash:SetAlpha(1)
    end

    if iconFrameData then
        iconFrameData.skinVer = nil
    end
end

function CDM.UnskinViewer(key)
    local list, count = CDM.GetTrackedIcons(key)
    if count == 0 then return end

    for iconIndex = 1, count do
        local frame = list[iconIndex]
        if CDM.IsCooldownIcon(frame) then
            CDM.UnskinIcon(frame)
        end
    end
end

local RealSkinIcon = CDM.SkinIcon
function CDM.SkinIcon(icon, settings, key)
    local profiler = BUI.Prof
    if profiler.active then
        local startTime = debugprofilestop()
        RealSkinIcon(icon, settings, key)
        profiler.Add('cdm.skinIcon#' .. tostring(key), debugprofilestop() - startTime)
    else
        RealSkinIcon(icon, settings, key)
    end
end
