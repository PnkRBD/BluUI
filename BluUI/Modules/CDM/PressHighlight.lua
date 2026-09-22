local _, BUI = ...
local SetScript = BUI.Prof.Scripts('CDM.PressHighlight')

local CDM = BUI.CDM
local Pixel = BUI.Pixel
local FrameData = CDM.FrameData
local LibCustomGlow = LibStub('LibCustomGlow-1.0')

local pairs, wipe, next = pairs, wipe, next
local IsKeyDown = IsKeyDown
local IsMouseButtonDown = IsMouseButtonDown
local IsShiftKeyDown = IsShiftKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsAltKeyDown = IsAltKeyDown
local GetCurrentKeyBoardFocus = GetCurrentKeyBoardFocus
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local GetTime = GetTime

local PressHighlight = {}
CDM.PressHighlight = PressHighlight

local PRESS_GLOW_KEY = '_BUIPressHL'

local OVERLAY_STYLES = {
    { value = 'tint',       text = 'Color Tint' },
    { value = 'pressed',    text = 'Pressed' },
    { value = 'glow',       text = 'Glow (White)' },
    { value = 'glow-green', text = 'Glow (Green)' },
    { value = 'glow-blue',  text = 'Glow (Blue)' },
    { value = 'glow-purple',text = 'Glow (Purple)' },
    { value = 'glow-orange',text = 'Glow (Orange)' },
    { value = 'pixel',      text = 'Pixel Spin',     animated = true },
    { value = 'autocast',   text = 'Autocast',        animated = true },
    { value = 'proc',       text = 'Proc Swirl',      animated = true },
    { value = 'buttonglow', text = 'Action Glow',     animated = true },
    { value = 'pulse',      text = 'Pulse',           animated = 'custom' },
    { value = 'explode',    text = 'Explode',         animated = 'custom' },
    { value = 'strobe',     text = 'Strobe',          animated = 'custom' },
    { value = 'ripple',     text = 'Ripple',          animated = 'custom' },
    { value = 'glass',      text = 'Glass Shine',     animated = 'custom' },
}
PressHighlight.OVERLAY_STYLES = OVERLAY_STYLES

local OVERLAY_ATLAS = {
    pressed       = 'UI-HUD-ActionBar-IconFrame-Down',
    glow          = 'bags-glow-white',
    ['glow-green']  = 'bags-glow-green',
    ['glow-blue']   = 'bags-glow-blue',
    ['glow-purple'] = 'bags-glow-purple',
    ['glow-orange'] = 'bags-glow-orange',
}

local ANIMATED = {}
for _, style in ipairs(OVERLAY_STYLES) do
    if style.animated then ANIMATED[style.value] = true end
end

local running = false
local showTint = true
local showBorder = false
local overlayStyle = 'tint'
local isAnimatedStyle = false
local tintColor = { 1, 1, 1, 0.3 }
local borderColor = { 1, 1, 1, 1 }

local bindingsByKey = {}
local keyModMasks = {}
local mouseButtonForKey = {}
local builtGeneration = -1

local activeIcons = {}
local activeCount = 0
local activeSet = {}

local function GetModifierMask()
    return (IsShiftKeyDown() and 1 or 0)
         + (IsControlKeyDown() and 2 or 0)
         + (IsAltKeyDown() and 4 or 0)
end

local function ParseBinding(rawBinding)
    if not rawBinding or rawBinding == '' then return nil, 0 end
    local modifierMask = 0
    local remaining = rawBinding
    while true do
        if remaining:sub(1, 6) == 'SHIFT-' then
            modifierMask = modifierMask + 1; remaining = remaining:sub(7)
        elseif remaining:sub(1, 5) == 'CTRL-' then
            modifierMask = modifierMask + 2; remaining = remaining:sub(6)
        elseif remaining:sub(1, 4) == 'ALT-' then
            modifierMask = modifierMask + 4; remaining = remaining:sub(5)
        else
            break
        end
    end
    if remaining == '' then return nil, 0 end
    return remaining, modifierMask
end

local function RawKeyForSlot(slot)
    local command = CDM.Keybinds.BindingForSlot(slot)
    if not command then return nil end
    local rawKey = GetBindingKey(command)
    return (rawKey and rawKey ~= '') and rawKey or nil
end

local collectSeen = {}
local collectVariants = {}
local collectResult = {}

local function CollectRawKeysForSpell(spellID)
    if not spellID then return nil end
    wipe(collectSeen)

    local variantCount = 1
    collectVariants[1] = spellID
    local baseSpellID = C_Spell.GetBaseSpell(spellID)
    if baseSpellID and baseSpellID ~= 0 and baseSpellID ~= spellID then
        variantCount = variantCount + 1
        collectVariants[variantCount] = baseSpellID
    end
    local overrideSpellID = BUI.Tools.GetOverrideSpell(spellID)
    if overrideSpellID and overrideSpellID ~= spellID then
        variantCount = variantCount + 1
        collectVariants[variantCount] = overrideSpellID
    end

    local resultCount = 0
    for variantIndex = 1, variantCount do
        local slots = C_ActionBar.FindSpellActionButtons(collectVariants[variantIndex])
        if slots then
            for _, slot in ipairs(slots) do
                local rawKey = RawKeyForSlot(slot)
                if rawKey and not collectSeen[rawKey] then
                    collectSeen[rawKey] = true
                    resultCount = resultCount + 1
                    collectResult[resultCount] = rawKey
                end
            end
        end
    end

    if resultCount == 0 then return nil end

    local keys = {}
    for keyIndex = 1, resultCount do keys[keyIndex] = collectResult[keyIndex] end
    return keys
end

local function CollectRawKeysForItem(itemID)
    if not itemID then return nil end
    wipe(collectSeen)
    local resultCount = 0
    for slot = 1, 180 do
        if HasAction(slot) then
            local actionType, id = GetActionInfo(slot)
            if actionType == 'item' and id == itemID then
                local rawKey = RawKeyForSlot(slot)
                if rawKey and not collectSeen[rawKey] then
                    collectSeen[rawKey] = true
                    resultCount = resultCount + 1
                    collectResult[resultCount] = rawKey
                end
            end
        end
    end
    if resultCount == 0 then return nil end
    local keys = {}
    for keyIndex = 1, resultCount do keys[keyIndex] = collectResult[keyIndex] end
    return keys
end

local iconKeyCache = {}
local KEY_CACHE_EVENTS = {
    'UPDATE_BINDINGS', 'ACTIONBAR_SLOT_CHANGED', 'ACTIONBAR_PAGE_CHANGED', 'UPDATE_BONUS_ACTIONBAR',
    'UPDATE_OVERRIDE_ACTIONBAR', 'UPDATE_VEHICLE_ACTIONBAR', 'PLAYER_SPECIALIZATION_CHANGED', 'SPELLS_CHANGED',
}

local function WipeKeyCache() wipe(iconKeyCache) end

local function GetAllRawKeysForIcon(icon)
    local frameData = CDM.FrameData[icon]
    local cacheKey, isItem

    if frameData and frameData.isItemByPrefix then
        cacheKey = frameData.itemID or (frameData.customSpellID and tonumber(tostring(frameData.customSpellID):match('%d+')))
        isItem = true
    else
        local stableID = CDM.GetStableSpellID(icon)
        if type(stableID) == 'string' then
            local numericID = tonumber(stableID:match('%d+'))
            if not numericID then return nil end
            stableID = numericID
        end
        cacheKey = stableID
    end

    local cached = cacheKey and iconKeyCache[cacheKey]
    if cached then return cached end

    local result
    if isItem then
        result = CollectRawKeysForItem(cacheKey)
    else
        result = CollectRawKeysForSpell(cacheKey)
        if not result then
            local rawKey = CDM.Keybinds.GetRawBindingForIcon(icon)
            if rawKey then result = {rawKey} end
        end
    end
    if cacheKey and result then iconKeyCache[cacheKey] = result end
    return result
end

local function RebuildBindings()
    for _, bindingArray in pairs(bindingsByKey) do wipe(bindingArray) end
    wipe(bindingsByKey)
    wipe(keyModMasks)
    wipe(mouseButtonForKey)
    builtGeneration = CDM.Keybinds.GetGeneration()

    for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
        local viewerKey = CDM.VIEWER_KEYS[viewerIndex]
        if viewerKey ~= 'buffs' and CDM.IsViewerEnabled(viewerKey) then
            local icons, iconCount = CDM.GetTrackedIcons(viewerKey)
            for iconIndex = 1, iconCount do
                local icon = icons[iconIndex]
                local rawKeys = GetAllRawKeysForIcon(icon)
                if rawKeys then
                    for _, rawBinding in ipairs(rawKeys) do
                        local keyName, modifierMask = ParseBinding(rawBinding)
                        if keyName then
                            local bindingArray = bindingsByKey[keyName]
                            if not bindingArray then
                                bindingArray = {}
                                bindingsByKey[keyName] = bindingArray
                                keyModMasks[keyName] = {}
                                local buttonNumber = keyName:match('^BUTTON(%d+)$')
                                if buttonNumber then mouseButtonForKey[keyName] = tonumber(buttonNumber) end
                            end
                            bindingArray[#bindingArray + 1] = modifierMask
                            bindingArray[#bindingArray + 1] = icon
                            keyModMasks[keyName][modifierMask] = true
                        end
                    end
                end
            end
        end
    end
end

local function GetOverlay(icon)
    local frameData = CDM.GetFrameData(icon)
    if frameData._pressOverlay then return frameData._pressOverlay end
    local overlay = icon:CreateTexture(nil, 'OVERLAY', nil, 7)
    overlay:Hide()
    frameData._pressOverlay = overlay
    return overlay
end

local function ConfigureOverlay(overlay, icon)
    local atlas = OVERLAY_ATLAS[overlayStyle]
    overlay:ClearAllPoints()
    if atlas then
        overlay:SetAtlas(atlas, false)
        overlay:SetAllPoints(icon)
    else
        overlay:SetColorTexture(1, 1, 1, 1)
        overlay:SetAllPoints(icon.Icon or icon)
    end
    overlay:SetVertexColor(tintColor[1], tintColor[2], tintColor[3], tintColor[4])
end

local function GetBorderRing(icon)
    local frameData = CDM.GetFrameData(icon)
    if frameData._pressBorder then return frameData._pressBorder end
    local ring = CreateFrame('Frame', nil, icon, 'BackdropTemplate')
    ring:SetFrameLevel(icon:GetFrameLevel() + 3)
    ring:SetPoint('TOPLEFT', Pixel.Scale(-1), Pixel.Scale(1))
    ring:SetPoint('BOTTOMRIGHT', Pixel.Scale(1), Pixel.Scale(-1))
    ring:SetBackdrop({ edgeFile = BUI.C.FALLBACK_TEXTURE, edgeSize = 1 })
    ring:Hide()
    frameData._pressBorder = ring
    return ring
end

local function SetupOverlayForAnim(icon)
    local overlay = GetOverlay(icon)
    overlay:SetColorTexture(1, 1, 1, 1)
    overlay:ClearAllPoints()
    overlay:SetAllPoints(icon.Icon or icon)
    overlay:SetVertexColor(tintColor[1], tintColor[2], tintColor[3], tintColor[4])
    overlay:Show()
    return overlay
end

local function GetPulseGroup(icon)
    local frameData = CDM.GetFrameData(icon)
    if frameData._pressPulseGroup then return frameData._pressPulseGroup end
    local overlay = GetOverlay(icon)
    local group = overlay:CreateAnimationGroup()
    group:SetLooping('REPEAT')
    local fadeOut = group:CreateAnimation('Alpha')
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.15)
    fadeOut:SetDuration(0.4)
    fadeOut:SetOrder(1)
    fadeOut:SetSmoothing('IN_OUT')
    local fadeIn = group:CreateAnimation('Alpha')
    fadeIn:SetFromAlpha(0.15)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.4)
    fadeIn:SetOrder(2)
    fadeIn:SetSmoothing('IN_OUT')
    frameData._pressPulseGroup = group
    return group
end

local function StartPulse(icon)
    SetupOverlayForAnim(icon)
    GetPulseGroup(icon):Play()
end

local function GetExplodeFrames(icon)
    local frameData = CDM.GetFrameData(icon)
    if frameData._pressExplode then return frameData._pressExplode end

    local iconRegion = icon.Icon or icon
    local clip = CreateFrame('Frame', nil, icon)
    clip:SetAllPoints(iconRegion)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(icon:GetFrameLevel() + 4)

    local flash = clip:CreateTexture(nil, 'OVERLAY', nil, 6)
    flash:SetAtlas('bags-glow-white')
    flash:SetPoint('CENTER')
    flash:SetBlendMode('ADD')
    flash:SetAlpha(0)

    local flashGroup = flash:CreateAnimationGroup()
    flashGroup:SetLooping('REPEAT')
    local flashIn = flashGroup:CreateAnimation('Alpha')
    flashIn:SetFromAlpha(0); flashIn:SetToAlpha(1); flashIn:SetDuration(0.02); flashIn:SetOrder(1)
    local flashOut = flashGroup:CreateAnimation('Alpha')
    flashOut:SetFromAlpha(1); flashOut:SetToAlpha(0); flashOut:SetDuration(0.2); flashOut:SetOrder(2)
    flashOut:SetSmoothing('OUT')
    local flashPause = flashGroup:CreateAnimation('Alpha')
    flashPause:SetFromAlpha(0); flashPause:SetToAlpha(0); flashPause:SetDuration(0.5); flashPause:SetOrder(3)

    local sparks = {}
    local sparkGroups = {}
    local offsets = { {1, 1}, {-1, 1}, {1, -1}, {-1, -1} }
    for sparkIndex = 1, 4 do
        local spark = clip:CreateTexture(nil, 'OVERLAY', nil, 7)
        spark:SetAtlas('bags-glow-white')
        spark:SetPoint('CENTER')
        spark:SetBlendMode('ADD')
        spark:SetAlpha(0)
        sparks[sparkIndex] = spark

        local group = spark:CreateAnimationGroup()
        group:SetLooping('REPEAT')
        local move = group:CreateAnimation('Translation')
        move:SetDuration(0.18); move:SetSmoothing('OUT'); move:SetOrder(1)
        local sparkFadeIn = group:CreateAnimation('Alpha')
        sparkFadeIn:SetFromAlpha(0); sparkFadeIn:SetToAlpha(1); sparkFadeIn:SetDuration(0.02); sparkFadeIn:SetOrder(1)
        local sparkFadeOut = group:CreateAnimation('Alpha')
        sparkFadeOut:SetFromAlpha(1); sparkFadeOut:SetToAlpha(0); sparkFadeOut:SetDuration(0.18); sparkFadeOut:SetStartDelay(0.02); sparkFadeOut:SetOrder(1)
        local sparkPause = group:CreateAnimation('Alpha')
        sparkPause:SetFromAlpha(0); sparkPause:SetToAlpha(0); sparkPause:SetDuration(0.5); sparkPause:SetOrder(2)

        group._move = move
        group._dir = offsets[sparkIndex]
        sparkGroups[sparkIndex] = group
    end

    clip.flash = flash
    clip.flashGroup = flashGroup
    clip.sparks = sparks
    clip.sparkGroups = sparkGroups
    clip:Hide()
    frameData._pressExplode = clip
    return clip
end

local function StartExplode(icon)
    local clip = GetExplodeFrames(icon)
    local frameData = FrameData[icon]
    local width = frameData and frameData.sizeW
    local height = frameData and frameData.sizeH
    if not width or not height or width < 1 or height < 1 then return end

    clip.flash:SetSize(width * 1.2, height * 1.2)
    clip.flash:SetVertexColor(tintColor[1], tintColor[2], tintColor[3], 1)

    local sparkSize = width * 0.45
    local travelDistance = width * 0.5
    for sparkIndex = 1, 4 do
        clip.sparks[sparkIndex]:SetSize(sparkSize, sparkSize)
        clip.sparks[sparkIndex]:SetVertexColor(tintColor[1], tintColor[2], tintColor[3], 1)
        local direction = clip.sparkGroups[sparkIndex]._dir
        clip.sparkGroups[sparkIndex]._move:SetOffset(direction[1] * travelDistance, direction[2] * travelDistance)
    end

    clip:Show()
    clip.flashGroup:Play()
    for sparkIndex = 1, 4 do clip.sparkGroups[sparkIndex]:Play() end
end

local function GetStrobeGroup(icon)
    local frameData = CDM.GetFrameData(icon)
    if frameData._pressStrobeGroup then return frameData._pressStrobeGroup end
    local overlay = GetOverlay(icon)
    local group = overlay:CreateAnimationGroup()
    group:SetLooping('REPEAT')

    local firstFlashOn = group:CreateAnimation('Alpha')
    firstFlashOn:SetFromAlpha(0); firstFlashOn:SetToAlpha(0.7); firstFlashOn:SetDuration(0.06); firstFlashOn:SetOrder(1)
    local firstFlashOff = group:CreateAnimation('Alpha')
    firstFlashOff:SetFromAlpha(0.7); firstFlashOff:SetToAlpha(0); firstFlashOff:SetDuration(0.06); firstFlashOff:SetOrder(2)
    local secondFlashOn = group:CreateAnimation('Alpha')
    secondFlashOn:SetFromAlpha(0); secondFlashOn:SetToAlpha(0.7); secondFlashOn:SetDuration(0.06); secondFlashOn:SetOrder(3)
    local secondFlashOff = group:CreateAnimation('Alpha')
    secondFlashOff:SetFromAlpha(0.7); secondFlashOff:SetToAlpha(0); secondFlashOff:SetDuration(0.06); secondFlashOff:SetOrder(4)
    local pause = group:CreateAnimation('Alpha')
    pause:SetFromAlpha(0); pause:SetToAlpha(0); pause:SetDuration(0.35); pause:SetOrder(5)

    frameData._pressStrobeGroup = group
    return group
end

local function StartStrobe(icon)
    SetupOverlayForAnim(icon)
    GetStrobeGroup(icon):Play()
end

local function GetRippleFrames(icon)
    local frameData = CDM.GetFrameData(icon)
    if frameData._pressRipple then return frameData._pressRipple end

    local iconRegion = icon.Icon or icon
    local clip = CreateFrame('Frame', nil, icon)
    clip:SetAllPoints(iconRegion)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(icon:GetFrameLevel() + 4)

    local waves = {}
    local waveGroups = {}
    local delays = { 0, 0.12, 0.24 }

    for waveIndex = 1, 3 do
        local wave = clip:CreateTexture(nil, 'OVERLAY', nil, 7 - waveIndex)
        wave:SetAtlas('bags-glow-white')
        wave:SetPoint('CENTER')
        wave:SetBlendMode('ADD')
        wave:SetAlpha(0)
        waves[waveIndex] = wave

        local group = wave:CreateAnimationGroup()
        group:SetLooping('REPEAT')

        local scaleUp = group:CreateAnimation('Scale')
        scaleUp:SetScaleFrom(0.3, 0.3); scaleUp:SetScaleTo(1.4, 1.4)
        scaleUp:SetDuration(0.3); scaleUp:SetSmoothing('OUT')
        scaleUp:SetStartDelay(delays[waveIndex]); scaleUp:SetOrder(1)

        local fadeIn = group:CreateAnimation('Alpha')
        fadeIn:SetFromAlpha(0); fadeIn:SetToAlpha(0.4 - (waveIndex * 0.08))
        fadeIn:SetDuration(0.06); fadeIn:SetStartDelay(delays[waveIndex]); fadeIn:SetOrder(1)

        local fadeOut = group:CreateAnimation('Alpha')
        fadeOut:SetFromAlpha(0.4 - (waveIndex * 0.08)); fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(0.24); fadeOut:SetStartDelay(delays[waveIndex] + 0.06); fadeOut:SetOrder(1)

        local hold = group:CreateAnimation('Alpha')
        hold:SetFromAlpha(0); hold:SetToAlpha(0)
        hold:SetDuration(0.6 - delays[waveIndex]); hold:SetOrder(2)

        waveGroups[waveIndex] = group
    end

    clip.waves = waves
    clip.waveGroups = waveGroups
    clip:Hide()
    frameData._pressRipple = clip
    return clip
end

local function StartRipple(icon)
    local clip = GetRippleFrames(icon)
    local frameData = FrameData[icon]
    local width = frameData and frameData.sizeW
    local height = frameData and frameData.sizeH
    if not width or not height or width < 1 or height < 1 then return end

    for waveIndex = 1, 3 do
        clip.waves[waveIndex]:SetSize(width, height)
        clip.waves[waveIndex]:SetVertexColor(tintColor[1], tintColor[2], tintColor[3], 1)
    end
    clip:Show()
    for waveIndex = 1, 3 do clip.waveGroups[waveIndex]:Play() end
end

local GLASS_ROTATION = math.rad(25)

local function GetGlassShine(icon)
    local frameData = CDM.GetFrameData(icon)
    if frameData._pressGlass then return frameData._pressGlass end

    local iconRegion = icon.Icon or icon

    local clip = CreateFrame('Frame', nil, icon)
    clip:SetAllPoints(iconRegion)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(icon:GetFrameLevel() + 4)

    local broad = clip:CreateTexture(nil, 'OVERLAY', nil, 6)
    broad:SetColorTexture(1, 1, 1, 1)
    broad:SetRotation(GLASS_ROTATION)

    local sharp = clip:CreateTexture(nil, 'OVERLAY', nil, 7)
    sharp:SetColorTexture(1, 1, 1, 1)
    sharp:SetRotation(GLASS_ROTATION)

    clip.broad = broad
    clip.sharp = sharp
    clip:Hide()

    frameData._pressGlass = clip
    return clip
end

local function StartGlass(icon)
    local clip = GetGlassShine(icon)
    local frameData = FrameData[icon]
    local width = frameData and frameData.sizeW
    local height = frameData and frameData.sizeH
    if not width or not height or width < 1 or height < 1 then return end

    local broad = clip.broad
    local sharp = clip.sharp

    broad:SetSize(width * 0.5, height * 3)
    sharp:SetSize(width * 0.12, height * 3)

    broad:SetVertexColor(tintColor[1], tintColor[2], tintColor[3], 0.15)
    sharp:SetVertexColor(tintColor[1], tintColor[2], tintColor[3], 0.5)

    local startOffset = -width * 0.7
    broad:ClearAllPoints()
    broad:SetPoint('CENTER', clip, 'CENTER', startOffset, 0)
    sharp:ClearAllPoints()
    sharp:SetPoint('CENTER', clip, 'CENTER', startOffset, 0)

    local sweepDistance = width * 1.4

    if not clip.broadGroup then
        clip.broadGroup = broad:CreateAnimationGroup()
        clip.broadGroup:SetLooping('REPEAT')
        clip.broadSweep = clip.broadGroup:CreateAnimation('Translation')
        clip.broadSweep:SetSmoothing('OUT')
        clip.broadSweep:SetOrder(1)
        clip.broadHold = clip.broadGroup:CreateAnimation('Translation')
        clip.broadHold:SetOffset(0, 0)
        clip.broadHold:SetOrder(2)

        clip.sharpGroup = sharp:CreateAnimationGroup()
        clip.sharpGroup:SetLooping('REPEAT')
        clip.sharpSweep = clip.sharpGroup:CreateAnimation('Translation')
        clip.sharpSweep:SetSmoothing('OUT')
        clip.sharpSweep:SetOrder(1)
        clip.sharpHold = clip.sharpGroup:CreateAnimation('Translation')
        clip.sharpHold:SetOffset(0, 0)
        clip.sharpHold:SetOrder(2)
    end

    clip.broadSweep:SetOffset(sweepDistance, 0)
    clip.broadSweep:SetDuration(0.7)
    clip.broadHold:SetDuration(0.4)

    clip.sharpSweep:SetOffset(sweepDistance, 0)
    clip.sharpSweep:SetDuration(0.7)
    clip.sharpHold:SetDuration(0.4)

    clip:Show()
    clip.broadGroup:Play()
    clip.sharpGroup:Play()
end

local procOptions = {
    color = tintColor,
    duration = 1.0,
    key = PRESS_GLOW_KEY,
    frameLevel = 15,
    startAnim = false,
}

local function GetButtonGlowProxy(icon)
    local frameData = CDM.GetFrameData(icon)
    if frameData._pressButtonProxy then
        frameData._pressButtonProxy:Show()
        return frameData._pressButtonProxy
    end
    local proxy = CreateFrame('Frame', nil, icon)
    proxy:SetAllPoints(icon)
    proxy:SetClipsChildren(true)
    proxy:SetFrameLevel(icon:GetFrameLevel() + 4)
    frameData._pressButtonProxy = proxy
    return proxy
end

local function StartAnimatedGlow(icon)
    local style = overlayStyle
    if style == 'pulse' then StartPulse(icon)
    elseif style == 'explode' then StartExplode(icon)
    elseif style == 'strobe' then StartStrobe(icon)
    elseif style == 'ripple' then StartRipple(icon)
    elseif style == 'glass' then StartGlass(icon)
    elseif style == 'pixel' then
        LibCustomGlow.PixelGlow_Start(icon, tintColor, 8, 0.25, nil, 2, 0, 0, true, PRESS_GLOW_KEY, 15)
    elseif style == 'autocast' then
        LibCustomGlow.AutoCastGlow_Start(icon, tintColor, 4, 0.6, 1.0, 0, 0, PRESS_GLOW_KEY, 15)
    elseif style == 'proc' then
        procOptions.color = tintColor
        LibCustomGlow.ProcGlow_Start(icon, procOptions)
    elseif style == 'buttonglow' then
        local proxy = GetButtonGlowProxy(icon)
        LibCustomGlow.ButtonGlow_Start(proxy, tintColor, 0.1, 1)
    end
end

local function StopAllEffects(icon, frameData)
    if frameData._pressPulseGroup then frameData._pressPulseGroup:Stop() end
    if frameData._pressStrobeGroup then frameData._pressStrobeGroup:Stop() end
    if frameData._pressOverlay then frameData._pressOverlay:Hide() end
    local explode = frameData._pressExplode
    if explode then
        if explode.flashGroup then explode.flashGroup:Stop() end
        if explode.sparkGroups then for sparkIndex = 1, 4 do explode.sparkGroups[sparkIndex]:Stop() end end
        explode:Hide()
    end
    local ripple = frameData._pressRipple
    if ripple then
        if ripple.waveGroups then for waveIndex = 1, 3 do ripple.waveGroups[waveIndex]:Stop() end end
        ripple:Hide()
    end
    local clip = frameData._pressGlass
    if clip then
        if clip.broadGroup then clip.broadGroup:Stop() end
        if clip.sharpGroup then clip.sharpGroup:Stop() end
        clip:Hide()
    end
    LibCustomGlow.PixelGlow_Stop(icon, PRESS_GLOW_KEY)
    LibCustomGlow.AutoCastGlow_Stop(icon, PRESS_GLOW_KEY)
    LibCustomGlow.ProcGlow_Stop(icon, PRESS_GLOW_KEY)
    local proxy = frameData._pressButtonProxy
    if proxy then LibCustomGlow.ButtonGlow_Stop(proxy); proxy:Hide() end
end

local function HighlightIcon(icon)
    if activeSet[icon] then return end
    activeCount = activeCount + 1
    activeIcons[activeCount] = icon
    activeSet[icon] = true

    if showTint then
        if isAnimatedStyle then
            StartAnimatedGlow(icon)
        else
            local overlay = GetOverlay(icon)
            ConfigureOverlay(overlay, icon)
            overlay:Show()
        end
    end
    if showBorder then
        local ring = GetBorderRing(icon)
        ring:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        ring:Show()
    end
end

local function UnhighlightIcon(icon)
    activeSet[icon] = nil
    local frameData = FrameData[icon]
    if not frameData then return end
    if frameData._pressOverlay then frameData._pressOverlay:Hide() end
    if frameData._pressBorder then frameData._pressBorder:Hide() end
    if isAnimatedStyle then StopAllEffects(icon, frameData) end
end

local function UnhighlightAll()
    for iconIndex = 1, activeCount do
        local icon = activeIcons[iconIndex]
        if activeSet[icon] then UnhighlightIcon(icon) end
        activeIcons[iconIndex] = nil
    end
    activeCount = 0
end

function PressHighlight.ForceClear()
    UnhighlightAll()
end

local pressedNow = {}
local heldKeys = {}
local listener

local MIN_VISIBLE = 0.05
local MAX_HOLD = 2.0

local pollFrame = CreateFrame('Frame')
pollFrame:Hide()

local function RefreshActive()
    local currentModifiers = GetModifierMask()
    wipe(pressedNow)
    for keyName in pairs(heldKeys) do
        local bindingArray = bindingsByKey[keyName]
        if bindingArray and keyModMasks[keyName][currentModifiers] then
            for entryIndex = 1, #bindingArray, 2 do
                if bindingArray[entryIndex] == currentModifiers then
                    pressedNow[bindingArray[entryIndex + 1]] = true
                end
            end
        end
    end

    if activeCount > 0 then
        local writeIndex = 0
        for readIndex = 1, activeCount do
            local icon = activeIcons[readIndex]
            if pressedNow[icon] then
                writeIndex = writeIndex + 1
                activeIcons[writeIndex] = icon
            else
                UnhighlightIcon(icon)
            end
        end
        for tailIndex = writeIndex + 1, activeCount do
            activeIcons[tailIndex] = nil
        end
        activeCount = writeIndex
    end

    for icon in pairs(pressedNow) do
        HighlightIcon(icon)
    end
end

local function VerifyHeld()
    local now = GetTime()
    local released = false
    for keyName, pressedAt in pairs(heldKeys) do
        local elapsed = now - pressedAt
        if elapsed >= MAX_HOLD then
            heldKeys[keyName] = nil
            released = true
        elseif elapsed >= MIN_VISIBLE then
            local mouseButton = mouseButtonForKey[keyName]
            local isDown = mouseButton and IsMouseButtonDown(mouseButton) or IsKeyDown(keyName)
            if not isDown then
                heldKeys[keyName] = nil
                released = true
            end
        end
    end
    if released then RefreshActive() end
    if not next(heldKeys) then pollFrame:Hide() end
end

SetScript(pollFrame, 'OnUpdate', VerifyHeld)

local function OnInputDown(keyName)
    if not running then return end
    if UnitIsDeadOrGhost('player') then return end
    if GetCurrentKeyBoardFocus() then return end
    if CDM.Keybinds.GetGeneration() ~= builtGeneration then RebuildBindings() end
    if not bindingsByKey[keyName] then return end
    heldKeys[keyName] = GetTime()
    RefreshActive()
    pollFrame:Show()
end

local function OnInputUp(keyName)
    local pressedAt = heldKeys[keyName]
    if not pressedAt then return end
    if GetTime() - pressedAt < MIN_VISIBLE then return end
    heldKeys[keyName] = nil
    RefreshActive()
end

local MOUSE_KEY = {
    LeftButton = 'BUTTON1', RightButton = 'BUTTON2', MiddleButton = 'BUTTON3',
    Button4 = 'BUTTON4', Button5 = 'BUTTON5',
}

local function StopInput()
    if listener then listener:Hide() end
    BUI.Events:Unregister('GLOBAL_MOUSE_DOWN', 'CDM.PressHL')
    for _, event in ipairs(KEY_CACHE_EVENTS) do BUI.Events:Unregister(event, 'CDM.PressHL.Keys') end
    BUI.Events:Unregister('GLOBAL_MOUSE_UP', 'CDM.PressHL')
    BUI.Events:Unregister('MODIFIER_STATE_CHANGED', 'CDM.PressHL')
    BUI.Events:Unregister('PLAYER_DEAD', 'CDM.PressHL')
    pollFrame:Hide()
    wipe(heldKeys)
    UnhighlightAll()
end

local function StartInput()
    if not listener then
        if InCombatLockdown() then
            BUI.Events:AfterCombat(function()
                if running then StartInput() end
            end, 'CDM.PressHL.Listener')
            return
        end
        listener = CreateFrame('Frame', nil, UIParent)
        listener:EnableKeyboard(true)
        listener:SetPropagateKeyboardInput(true)
        SetScript(listener, 'OnKeyDown', function(_, key) OnInputDown(key) end)
        SetScript(listener, 'OnKeyUp', function(_, key) OnInputUp(key) end)
    end
    listener:Show()
    for _, event in ipairs(KEY_CACHE_EVENTS) do BUI.Events:Register(event, 'CDM.PressHL.Keys', WipeKeyCache) end
    BUI.Events:Register('GLOBAL_MOUSE_DOWN', 'CDM.PressHL', function(_, button)
        local keyName = MOUSE_KEY[button]
        if keyName then OnInputDown(keyName) end
    end)
    BUI.Events:Register('GLOBAL_MOUSE_UP', 'CDM.PressHL', function(_, button)
        local keyName = MOUSE_KEY[button]
        if keyName then OnInputUp(keyName) end
    end)
    BUI.Events:Register('MODIFIER_STATE_CHANGED', 'CDM.PressHL', function()
        if next(heldKeys) then RefreshActive() end
    end)
    BUI.Events:Register('PLAYER_DEAD', 'CDM.PressHL', function()
        wipe(heldKeys)
        UnhighlightAll()
    end)
end

function PressHighlight.Invalidate()
    WipeKeyCache()
    builtGeneration = -1
end

local function SyncConfig()
    local config = BUI.GetDB().cdm.pressHighlight

    local newStyle = config.overlayStyle
    local willBeAnimated = ANIMATED[newStyle] or false
    if running and newStyle ~= overlayStyle and activeCount > 0 then
        for iconIndex = 1, activeCount do
            local icon = activeIcons[iconIndex]
            local frameData = FrameData[icon]
            if frameData then StopAllEffects(icon, frameData) end
        end
    end

    showTint = config.showTint ~= false
    showBorder = config.showBorder
    overlayStyle = newStyle
    isAnimatedStyle = willBeAnimated

    tintColor[1] = config.tintColor[1] or 1
    tintColor[2] = config.tintColor[2] or 1
    tintColor[3] = config.tintColor[3] or 1
    tintColor[4] = config.tintColor[4] or 0.3
    borderColor[1] = config.borderColor[1] or 1
    borderColor[2] = config.borderColor[2] or 1
    borderColor[3] = config.borderColor[3] or 1
    borderColor[4] = config.borderColor[4] or 1

    if config.enabled and not running then
        running = true
        StartInput()
    elseif not config.enabled and running then
        running = false
        StopInput()
        for _, bindingArray in pairs(bindingsByKey) do wipe(bindingArray) end
        wipe(bindingsByKey)
        wipe(keyModMasks)
        wipe(mouseButtonForKey)
    end
end

function PressHighlight.Refresh()
    SyncConfig()

    CDM.Keybinds.UpdateConsumerState()
    if running then
        builtGeneration = -1
        if not isAnimatedStyle then
            for iconIndex = 1, activeCount do
                local icon = activeIcons[iconIndex]
                local frameData = FrameData[icon]
                if frameData and frameData._pressOverlay and showTint then
                    ConfigureOverlay(frameData._pressOverlay, icon)
                end
            end
        end
    end
end

function PressHighlight.Initialize()
    SyncConfig()

    CDM.OnTrackedIconsChanged(PressHighlight.Invalidate)
end
