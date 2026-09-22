local _, BUI = ...

local CDAnnouncer = {}
BUI.CDAnnouncer = CDAnnouncer

local Tools      = BUI.Tools
local TimeFormat = BUI.TimeFormat
local Pixel      = BUI.Pixel

local SETTINGS_KEY = 'cdAnnouncer'
local FRAME_NAME   = 'BUI_CDAnnouncerFrame'
local MODULE_KEY   = 'CDAnnouncer'
local TOOLTIP_SCANNER_NAME = 'BUI_CDAnnouncerTooltipScanner'
local MISSING_ICON = 134400

local TICK_INTERVAL            = 0.1
local DECIMAL_THRESHOLD        = 10
local PREVIEW_REMAINING        = 12
local ROW_SPACING              = 2
local DEFAULT_GROWTH           = 'center'

local DEFAULT_CD_FORMAT    = '[spell] [time]'
local DEFAULT_READY_FORMAT = '[spell] Ready'

local DEFAULT_LOW_COLOR   = { r = 1,   g = 0.2,  b = 0.2, a = 1 }

local SPELL_DEFAULTS = {
    showIcon           = true,
    showIconReady      = true,
    showText           = true,
    showTextReady      = true,
    timeInIcon         = false,
    iconTimeAnchor     = 'CENTER',
    iconTimeX          = 0,
    iconTimeY          = 0,
    iconSize           = 22,
    lowThreshold       = 5,
    flashLow           = false,
    countdownLow       = false,
    countdownText      = '[spell] in [time]',
    readyMode          = 'flash',
    flashScope         = 'both',
    glowDuration       = 1,
    cdDisplayFormat    = DEFAULT_CD_FORMAT,
    readyDisplayFormat = DEFAULT_READY_FORMAT,
    font               = BUI.C.GLOBAL_OPTION,
    fontSize           = 16,
    cdPhase            = true,
    lowPhase           = true,
    readyPhase         = true,
    useCustomPos       = false,
    posAnchor          = 'CENTER',
    posX               = 0,
    posY               = 0,
}

local rows  = {}
local state = {}
local resolvedDurationCache = {}
local renderContext = {}

local root, stack, anchorTexture, anchorTexturet
local tooltipScanner
local positionCallback, anchorCallback
local loginEpoch
local previewActive = false
local previewTimer
local castEventsActive = false
local itemEventsActive = false

local function GetConfig() return BUI.GetDB()[SETTINGS_KEY] end
local function NowEpoch() return loginEpoch + GetTime() end

local cachedCharacterKey
local function GetCharacterKey()
    if not cachedCharacterKey then
        cachedCharacterKey = UnitName('player') .. '-' .. GetRealmName()
    end
    return cachedCharacterKey
end

local function GetCharacterSlot()
    local profile = GetConfig()
    local key = GetCharacterKey()
    profile.charSpells[key] = profile.charSpells[key] or {}
    return profile.charSpells[key]
end

local function GetSpellList()
    local slot = GetCharacterSlot()
    slot.spells = slot.spells or {}
    return slot.spells
end

local function GetActiveTable()
    local slot = GetCharacterSlot()
    slot.active = slot.active or {}
    return slot.active
end

local function PersistCast(spellID, castEpoch)
    GetActiveTable()[spellID] = castEpoch
end

local function ClearCast(spellID)
    GetActiveTable()[spellID] = nil
end

local function ClearAllActiveCooldowns()
    for spellID, spellState in pairs(state) do
        spellState.castEpoch      = nil
        spellState.onCD           = false
        spellState.remaining      = nil
        spellState.readyEndTime   = nil
        spellState.rechargeAnchor = nil
        ClearCast(spellID)
    end
end

function CDAnnouncer.RegisterPositionCallback(callback) positionCallback = callback end
function CDAnnouncer.UnregisterPositionCallback()   positionCallback = nil end
function CDAnnouncer.RegisterAnchorCallback(callback)   anchorCallback = callback   end
function CDAnnouncer.UnregisterAnchorCallback()     anchorCallback   = nil end

function CDAnnouncer.GetSpells()
    return GetSpellList()
end

local function ActiveID(entry)
    if entry.kind == 'item' then return entry.spellID end
    return Tools.GetActiveChoice(entry.spellID) or entry.spellID
end

local function MatchesChoiceNode(entry, spellID)
    if entry.kind == 'item' then return false end
    local alternatives = Tools.GetChoiceAlternatives(entry.spellID)
    if not alternatives then return false end
    for _, alternative in ipairs(alternatives) do
        if alternative.spellID == spellID then return true end
    end
    return false
end

local function MatchesOverride(entry, spellID)
    if entry.kind == 'item' then return false end
    if Tools.GetOverrideSpell(entry.spellID) == spellID then return true end
    if Tools.GetOverrideSpell(spellID) == entry.spellID then return true end
    return false
end

function CDAnnouncer.FindEntry(spellID)
    for index, entry in ipairs(CDAnnouncer.GetSpells()) do
        if entry.spellID == spellID then return entry, index end
        if entry.aliases then
            for _, alias in ipairs(entry.aliases) do
                if alias == spellID then return entry, index end
            end
        end
        if MatchesChoiceNode(entry, spellID) then return entry, index end
        if MatchesOverride(entry, spellID) then return entry, index end
    end
end

function CDAnnouncer.ApplyEntryDefaults(entry)
    for key, value in pairs(SPELL_DEFAULTS) do
        if entry[key] == nil then entry[key] = value end
    end
end

local function MatchCooldownText(text)
    if not text or Tools.IsSecretValue(text) then return nil end
    local seconds = text:match('([%d%.]+) sec cooldown') or text:match('([%d%.]+) sec recharge')
    if seconds then return tonumber(seconds) end
    local minutes = text:match('([%d%.]+) min cooldown') or text:match('([%d%.]+) min recharge')
    if minutes then return tonumber(minutes) * 60 end
    return nil
end

local function ScanTooltipForCooldown(setterName, sourceID)
    if not tooltipScanner then
        tooltipScanner = CreateFrame('GameTooltip', TOOLTIP_SCANNER_NAME, UIParent, 'GameTooltipTemplate')
        tooltipScanner:SetOwner(UIParent, 'ANCHOR_NONE')
    end
    tooltipScanner:ClearLines()
    tooltipScanner[setterName](tooltipScanner, sourceID)
    for line = 1, tooltipScanner:NumLines() do
        local left  = _G[TOOLTIP_SCANNER_NAME .. 'TextLeft' .. line]
        local match = left and MatchCooldownText(left:GetText())
        if match then return match end
        local right = _G[TOOLTIP_SCANNER_NAME .. 'TextRight' .. line]
        match = right and MatchCooldownText(right:GetText())
        if match then return match end
    end
    return nil
end

function CDAnnouncer.ResolveCooldownSeconds(spellID, kind)
    if kind == 'item' then
        local _, duration = C_Container.GetItemCooldown(spellID)
        if duration and duration > 1.5 then return duration end
        local fromTooltip = ScanTooltipForCooldown('SetItemByID', spellID)
        if fromTooltip then return fromTooltip end
        local _, itemSpellID = C_Item.GetItemSpell(spellID)
        if itemSpellID then return CDAnnouncer.ResolveCooldownSeconds(itemSpellID, 'spell') end
        return
    end
    local fromTooltip = ScanTooltipForCooldown('SetSpellByID', spellID)
    if fromTooltip then return fromTooltip end
    local baseCooldownMS = GetSpellBaseCooldown(spellID)
    if baseCooldownMS and baseCooldownMS > 1500 then return baseCooldownMS / 1000 end
end

local function EffectiveDuration(entry)
    if entry.kind == 'item' then return entry.duration end
    local activeID = ActiveID(entry)
    if activeID == entry.spellID then return entry.duration end
    local cached = resolvedDurationCache[activeID]
    if cached == nil then
        cached = CDAnnouncer.ResolveCooldownSeconds(activeID, 'spell') or false
        resolvedDurationCache[activeID] = cached
    end
    return cached or entry.duration
end

local function LookupInfo(entry, activeID)
    if entry.kind == 'item' then
        local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(entry.spellID)
        if name then return { name = name, iconID = icon } end
        return nil
    end
    return C_Spell.GetSpellInfo(activeID or ActiveID(entry))
end

local function ResolveIconTexture(entry, info, activeID)
    if entry.kind == 'item' then return (info and info.iconID) or MISSING_ICON end
    return (info and info.iconID) or C_Spell.GetSpellTexture(activeID or ActiveID(entry)) or MISSING_ICON
end

local function ApplyText(fontString, text)
    if fontString._text == text then return end
    fontString._text = text
    fontString:SetText(text or '')
end

local function ApplyColor(fontString, red, green, blue, alpha)
    if fontString._cr == red and fontString._cg == green and fontString._cb == blue and fontString._ca == alpha then return end
    fontString._cr, fontString._cg, fontString._cb, fontString._ca = red, green, blue, alpha
    fontString:SetTextColor(red, green, blue, alpha)
end

local function ApplyFont(fontString, font, size, outline)
    if fontString._font == font and fontString._size == size and fontString._outline == outline then return end
    fontString._font, fontString._size, fontString._outline = font, size, outline
    fontString:SetFont(font, size, outline)
end

local function GetDisplayParts(entry, info, spellState)
    local name        = info.name or ''
    local cdFormat    = entry.cdDisplayFormat    or DEFAULT_CD_FORMAT
    local readyFormat = entry.readyDisplayFormat or DEFAULT_READY_FORMAT
    if spellState._dispName == name and spellState._dispCd == cdFormat and spellState._dispReady == readyFormat then return end
    spellState._dispName, spellState._dispCd, spellState._dispReady = name, cdFormat, readyFormat

    local resolved = cdFormat:gsub('%[spell%]', name):gsub('%[name%]', name)
    local timeStart, timeEnd = resolved:find('[time]', 1, true)
    if timeStart then
        spellState.cdPre  = resolved:sub(1, timeStart - 1)
        spellState.cdPost = resolved:sub(timeEnd + 1)
    else
        spellState.cdPre, spellState.cdPost = resolved, ''
    end

    spellState.readyText = readyFormat:gsub('%[spell%]', name):gsub('%[name%]', name)
end

local function StartFlash(row)
    local anim = row._flashAnim
    if anim and anim:IsPlaying() then return end
    if not anim then
        anim = row.text:CreateAnimationGroup()
        anim:SetLooping('REPEAT')
        local fadeOut = anim:CreateAnimation('Alpha')
        fadeOut:SetFromAlpha(1);   fadeOut:SetToAlpha(0.45); fadeOut:SetDuration(0.35); fadeOut:SetOrder(1); fadeOut:SetSmoothing('IN_OUT')
        local fadeIn = anim:CreateAnimation('Alpha')
        fadeIn:SetFromAlpha(0.45); fadeIn:SetToAlpha(1);     fadeIn:SetDuration(0.35);  fadeIn:SetOrder(2);  fadeIn:SetSmoothing('IN_OUT')
        row._flashAnim = anim
    end
    anim:Play()
end

local function StopFlash(row)
    if row._flashAnim and row._flashAnim:IsPlaying() then
        row._flashAnim:Stop()
        row.text:SetAlpha(1)
    end
end

local function StopReadyPulse(row)
    if row._readyPulse and row._readyPulse:IsPlaying() then
        row._readyPulse:Stop()
    end
    row:SetAlpha(1)
end

local function StartReadyPulse(row)
    StopReadyPulse(row)
    local anim = row._readyPulse
    if not anim then
        anim = row:CreateAnimationGroup()
        anim:SetLooping('REPEAT')
        local fadeOut = anim:CreateAnimation('Alpha')
        fadeOut:SetFromAlpha(1);   fadeOut:SetToAlpha(0.45); fadeOut:SetDuration(0.35); fadeOut:SetOrder(1); fadeOut:SetSmoothing('IN_OUT')
        local fadeIn = anim:CreateAnimation('Alpha')
        fadeIn:SetFromAlpha(0.45); fadeIn:SetToAlpha(1);     fadeIn:SetDuration(0.35);  fadeIn:SetOrder(2);  fadeIn:SetSmoothing('IN_OUT')
        row._readyPulse = anim
    end
    anim:Play()
end

local function PlayReadyBlink(row)
    local anim = row._readyBlink
    if not anim then
        anim = row:CreateAnimationGroup()
        local steps = { { 1, 0.4, 0.09 }, { 0.4, 1, 0.12 }, { 1, 0.4, 0.09 }, { 0.4, 1, 0.12 } }
        for stepIndex, step in ipairs(steps) do
            local stepAnim = anim:CreateAnimation('Alpha')
            stepAnim:SetOrder(stepIndex); stepAnim:SetSmoothing('IN_OUT')
            stepAnim:SetFromAlpha(step[1]); stepAnim:SetToAlpha(step[2]); stepAnim:SetDuration(step[3])
        end
        row._readyBlink = anim
    end
    anim:Stop()
    anim:Play()
end

local function PlayEnter(row)
    if row._readyPulse and row._readyPulse:IsPlaying() then return end
    local anim = row._enterAnim
    if not anim then
        anim = row:CreateAnimationGroup()
        local fade = anim:CreateAnimation('Alpha')
        fade:SetFromAlpha(0); fade:SetToAlpha(1); fade:SetDuration(0.18); fade:SetSmoothing('OUT')
        local grow = anim:CreateAnimation('Scale')
        grow:SetScaleFrom(0.9, 0.9); grow:SetScaleTo(1, 1); grow:SetDuration(0.18); grow:SetSmoothing('OUT')
        row._enterAnim = anim
    end
    anim:Play()
end

local function StopRowEffects(row)
    StopFlash(row)
    StopReadyPulse(row)
    if row._enterAnim and row._enterAnim:IsPlaying() then row._enterAnim:Stop() end
    if row._readyBlink and row._readyBlink:IsPlaying() then row._readyBlink:Stop() end
end

local function EnsureRow(index)
    local row = rows[index]
    if row then return row end

    row = CreateFrame('Frame', nil, root)
    row:SetSize(Pixel.Scale(160), Pixel.Scale(24))

    row.icon = row:CreateTexture(nil, 'ARTWORK')
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.icon:Hide()

    row.iconBorder = CreateFrame('Frame', nil, row, 'BackdropTemplate')
    row.iconBorder:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 })
    row.iconBorder:SetBackdropBorderColor(0, 0, 0, 1)
    row.iconBorder:SetPoint('TOPLEFT',     row.icon, 'TOPLEFT',     Pixel.Scale(-1),  Pixel.Scale(1))
    row.iconBorder:SetPoint('BOTTOMRIGHT', row.icon, 'BOTTOMRIGHT',  Pixel.Scale(1), Pixel.Scale(-1))
    row.iconBorder:Hide()

    row.text = row:CreateFontString(nil, 'OVERLAY')
    row.text:SetPoint('LEFT', row, 'LEFT', 0, 0)

    row.iconTime = row:CreateFontString(nil, 'OVERLAY')
    row.iconTime:SetPoint('CENTER', row.icon, 'CENTER', 0, 0)
    row.iconTime:Hide()

    rows[index] = row
    return row
end

local function ApplyPosition()
    local config = GetConfig()
    root:ClearAllPoints()
    local offsetX = config.centerHorizontally and 0 or config.posX
    root:SetPoint('CENTER', UIParent, 'CENTER', offsetX, config.posY)
end

local function HideAllRows()
    for rowIndex = 1, #rows do rows[rowIndex]:Hide() end
end

local function HideRow(row)
    if row:IsShown() then row:Hide() end
    row._anchorTo = nil
    row._cAnchor  = nil
    StopRowEffects(row)
end

local function ShowRow(row)
    if not row:IsShown() then
        row:Show()
        row:SetAlpha(1)
        PlayEnter(row)
    end
end

local function ResolveRowDisplay(entry, spellState, now, showAnchor)
    local onCD         = spellState.onCD
    local remaining    = spellState.remaining or 0
    local cdEnabled    = entry.cdPhase ~= false
    local readyEnabled = entry.readyPhase ~= false

    if showAnchor and not onCD then
        if cdEnabled then return true, 'cd', PREVIEW_REMAINING, false, false end
        return true, 'ready', 0, false, false
    end

    if onCD then
        if readyEnabled and spellState.readyEndTime and now < spellState.readyEndTime then
            local hideText, hideIcon = false, false
            local scope = entry.flashScope or 'both'
            if scope == 'icon' then hideText = true
            elseif scope == 'text' then hideIcon = true end
            return true, 'ready', 0, hideText, hideIcon
        end
        if cdEnabled then return true, 'cd', remaining, false, false end
        if entry.lowPhase ~= false and remaining > 0 and remaining <= (entry.lowThreshold or 5) then
            return true, 'cd', remaining, false, false
        end
        return false
    end

    if not readyEnabled then return false end

    local readyMode   = entry.readyMode or 'flash'
    local readyActive = spellState.readyEndTime and now < spellState.readyEndTime
    if readyMode ~= 'persist' and not readyActive then return false end

    local hideText, hideIcon = false, false
    if readyActive then
        local scope = entry.flashScope or 'both'
        if scope == 'icon' then hideText = true
        elseif scope == 'text' then hideIcon = true end
    end
    return true, 'ready', 0, hideText, hideIcon
end

local function ResolveRowText(entry, spellState, isCD, remaining, hideText, context)
    if not isCD then
        return spellState.readyText, entry.readyColor or context.globalReady, false,
               hideText or entry.showTextReady == false
    end
    local text         = spellState.cdPre .. TimeFormat.Format(remaining, DECIMAL_THRESHOLD) .. spellState.cdPost
    local lowThreshold = entry.lowThreshold or 5
    if entry.lowPhase ~= false and remaining > 0 and remaining <= lowThreshold then
        return text, entry.lowColor or DEFAULT_LOW_COLOR, entry.flashLow,
               hideText or entry.showText == false
    end
    return text, entry.color or context.globalCD, false,
           hideText or entry.showText == false
end

local function ApplyRowVisuals(row, entry, info, activeID, text, color, font, outline, fontSize, hideText, hideIcon, isCD)
    ApplyFont(row.text, font, fontSize, outline)
    ApplyText(row.text, text)
    ApplyColor(row.text, color.r, color.g, color.b, color.a or 1)
    row.text:SetShown(not hideText)

    local iconAllowed = (isCD and entry.showIcon ~= false) or (not isCD and entry.showIconReady ~= false)
    if hideIcon or not iconAllowed then
        row.icon:Hide()
        row.iconBorder:Hide()
        if row._layoutKey ~= 'noicon' then
            row._layoutKey = 'noicon'
            row.text:ClearAllPoints()
            row.text:SetPoint('LEFT', row, 'LEFT', 0, 0)
        end
        return false
    end

    if row.icon._spellID ~= activeID then
        row.icon._spellID = activeID
        row.icon:SetTexture(ResolveIconTexture(entry, info, activeID))
    end
    local iconSize = entry.iconSize or (fontSize + 4)
    local scaledIcon = Pixel.Scale(iconSize)
    local textAnchor = entry.textAnchor or 'right'
    local layoutKey = textAnchor .. scaledIcon
    if row._layoutKey ~= layoutKey then
        row._layoutKey = layoutKey
        row.icon:SetSize(scaledIcon, scaledIcon)
        row.icon:ClearAllPoints()
        row.text:ClearAllPoints()

        if textAnchor == 'top' then
            row.icon:SetPoint('BOTTOM', row, 'BOTTOM', 0, 0)
            row.text:SetPoint('BOTTOM', row.icon, 'TOP', 0, Pixel.Scale(4))
        elseif textAnchor == 'bottom' then
            row.icon:SetPoint('TOP', row, 'TOP', 0, 0)
            row.text:SetPoint('TOP', row.icon, 'BOTTOM', 0, Pixel.Scale(-4))
        else
            row.icon:SetPoint('LEFT', row, 'LEFT', 0, 0)
            row.text:SetPoint('LEFT', row.icon, 'RIGHT', Pixel.Scale(6), 0)
        end
    end
    row.icon:Show()
    row.iconBorder:Show()
    return true
end

local function MeasureRow(row, entry, fontSize, iconShown)
    local textWidth = row.text:IsShown() and row.text:GetStringWidth() or 0
    local iconWidth = iconShown and row.icon:GetWidth()  or 0
    local iconHeight = iconShown and row.icon:GetHeight() or 0
    local textAnchor = entry.textAnchor or 'right'

    local rowWidth, rowHeight
    if iconShown and (textAnchor == 'top' or textAnchor == 'bottom') then
        rowWidth = math.max(textWidth, iconWidth)
        rowHeight = iconHeight + (textWidth > 0 and (fontSize + 6) or 0)
    else
        rowWidth = textWidth + (iconShown and (iconWidth + 6) or 0)
        rowHeight = math.max(fontSize + 2, iconHeight)
    end
    return math.max(rowWidth, 16), rowHeight
end

local function UpdateRow(entry, index, context)
    local row = EnsureRow(index)

    if not entry.enabled then
        StopFlash(row)
        return false
    end

    local activeID = ActiveID(entry)

    if context.hideUnusable and entry.kind ~= 'item' and activeID and not IsPlayerSpell(activeID) then
        StopFlash(row)
        return false
    end

    local info = LookupInfo(entry, activeID)
    if not info then
        StopFlash(row)
        return false
    end

    local spellState = state[entry.spellID]
    if not spellState then spellState = {}; state[entry.spellID] = spellState end

    local show, phase, remaining, hideText, hideIcon = ResolveRowDisplay(entry, spellState, context.now, context.forcePreview)
    if not show then
        StopFlash(row)
        return false
    end

    GetDisplayParts(entry, info, spellState)

    local isCD = phase == 'cd'
    local text, color, wantFlash, finalHideText = ResolveRowText(entry, spellState, isCD, remaining, hideText, context)
    if wantFlash then StartFlash(row) else StopFlash(row) end

    local fontSize = entry.fontSize or 16
    local font     = context.font
    if entry.font and entry.font ~= BUI.C.GLOBAL_OPTION then
        font = BUI.GetModuleFont({ font = entry.font })
    end
    local iconShown = ApplyRowVisuals(row, entry, info, activeID, text, color,
        font, context.outline, fontSize, finalHideText, hideIcon, isCD)

    if isCD and entry.timeInIcon and iconShown then
        local iconSize = entry.iconSize or 22
        local timeSize = entry.iconTimeSize or math.max(8, math.floor(iconSize * 0.45))
        ApplyFont(row.iconTime, font, timeSize, context.outline)
        local anchor = entry.iconTimeAnchor or 'CENTER'
        local offsetX, offsetY = entry.iconTimeX or 0, entry.iconTimeY or 0
        if row._itAnchor ~= anchor or row._itX ~= offsetX or row._itY ~= offsetY then
            row._itAnchor, row._itX, row._itY = anchor, offsetX, offsetY
            row.iconTime:ClearAllPoints()
            row.iconTime:SetPoint(anchor, row.icon, anchor, offsetX, offsetY)
        end
        ApplyText(row.iconTime, TimeFormat.Format(remaining, DECIMAL_THRESHOLD))
        ApplyColor(row.iconTime, color.r, color.g, color.b, color.a or 1)
        if not row.iconTime:IsShown() then row.iconTime:Show() end
    elseif row.iconTime:IsShown() then
        row.iconTime:Hide()
    end

    local rowWidth, rowHeight = MeasureRow(row, entry, fontSize, iconShown)
    return true, rowWidth, rowHeight
end

local function PlaceRow(row, entry, rowWidth, rowHeight, previousRow, totalHeight, maxWidth, growth)
    row:SetSize(rowWidth, rowHeight)

    if entry.useCustomPos then
        local anchor = entry.posAnchor or 'CENTER'
        local posX, posY = entry.posX or 0, entry.posY or 0
        if row._cAnchor ~= anchor or row._cX ~= posX or row._cY ~= posY then
            row._cAnchor, row._cX, row._cY = anchor, posX, posY
            row._anchorTo = nil
            row:ClearAllPoints()
            row:SetPoint(anchor, UIParent, anchor, posX, posY)
        end
        ShowRow(row)
        return previousRow, totalHeight, maxWidth
    end

    row._cAnchor = nil
    local anchorTarget = previousRow or stack
    if row._anchorTo ~= anchorTarget or row._growth ~= growth then
        row._anchorTo, row._growth = anchorTarget, growth
        row:ClearAllPoints()
        if growth == 'up' then
            if previousRow then
                row:SetPoint('BOTTOM', previousRow, 'TOP', 0, Pixel.Scale(ROW_SPACING))
            else
                row:SetPoint('BOTTOM', stack, 'BOTTOM', 0, 0)
            end
        elseif previousRow then
            row:SetPoint('TOP', previousRow, 'BOTTOM', 0, Pixel.Scale(-ROW_SPACING))
        else
            row:SetPoint('TOP', stack, 'TOP', 0, 0)
        end
    end
    ShowRow(row)
    return row, totalHeight + rowHeight + ROW_SPACING, math.max(maxWidth, rowWidth)
end

local function ApplyGrowth(growth)
    if stack._growth == growth then return end
    stack._growth = growth
    stack:ClearAllPoints()
    anchorTexturet:ClearAllPoints()
    if growth == 'up' then
        stack:SetPoint('BOTTOM', root, 'BOTTOM', 0, 0)
        anchorTexturet:SetPoint('TOP', root, 'BOTTOM', 0, Pixel.Scale(-2))
        anchorTexturet:SetText('Drag to Reposition | Right-Click to Lock\nNew rows stack upward from here')
    elseif growth == 'down' then
        stack:SetPoint('TOP', root, 'TOP', 0, 0)
        anchorTexturet:SetPoint('BOTTOM', root, 'TOP', 0, Pixel.Scale(2))
        anchorTexturet:SetText('Drag to Reposition | Right-Click to Lock\nNew rows stack downward from here')
    else
        stack:SetPoint('CENTER', root, 'CENTER', 0, 0)
        anchorTexturet:SetPoint('BOTTOM', root, 'TOP', 0, Pixel.Scale(2))
        anchorTexturet:SetText('Drag to Reposition | Right-Click to Lock\nRows stack out from the middle')
    end
end

local function SizeRoot(maxWidth, totalHeight, anchorHeight)
    local width  = math.max(maxWidth + 8, 120)
    local height = math.max(totalHeight, 20)
    if stack._width ~= width or stack._height ~= height then
        stack._width, stack._height = width, height
        stack:SetSize(width, height)
    end
    anchorHeight = math.max(anchorHeight or 0, 20)
    if root._width ~= width or root._height ~= anchorHeight then
        root._width, root._height = width, anchorHeight
        root:SetSize(width, anchorHeight)
    end
    if not root:IsShown() then root:Show() end
end

local function Render()
    local config     = GetConfig()
    local showAnchor = config.showAnchor

    if not config.enabled and not showAnchor and not previewActive then
        HideAllRows()
        root:Hide()
        return
    end
    if not showAnchor and not previewActive and UnitIsDeadOrGhost('player') then
        HideAllRows()
        root:Hide()
        return
    end

    local context = renderContext
    context.font         = BUI.GetModuleFont(config)
    context.outline      = BUI.GetFontOutline()
    context.globalCD     = config.cdColor
    context.globalReady  = config.readyColor
    context.now          = GetTime()
    context.showAnchor   = showAnchor

    context.hideUnusable = config.hideUnusable and not showAnchor

    local spells = GetSpellList()
    local visible, maxWidth, totalHeight = 0, 0, 0
    local previousRow, firstRowHeight
    local growth = config.growth or DEFAULT_GROWTH
    ApplyGrowth(growth)

    for spellIndex = 1, #spells do
        context.forcePreview = showAnchor and visible == 0
        local shown, rowWidth, rowHeight = UpdateRow(spells[spellIndex], spellIndex, context)
        local row = rows[spellIndex]
        if shown then
            previousRow, totalHeight, maxWidth = PlaceRow(row, spells[spellIndex], rowWidth, rowHeight, previousRow, totalHeight, maxWidth, growth)
            visible = visible + 1
            firstRowHeight = firstRowHeight or rowHeight
        else
            HideRow(row)
        end
    end

    for rowIndex = #spells + 1, #rows do
        HideRow(rows[rowIndex])
    end

    if visible == 0 and not showAnchor then
        root:Hide()
        return
    end

    SizeRoot(maxWidth, totalHeight, firstRowHeight)
end

local function ScanItemCooldowns()
    local spells = GetSpellList()
    local started = false
    for spellIndex = 1, #spells do
        local entry = spells[spellIndex]
        if entry.kind == 'item' and entry.enabled and entry.spellID then
            local startTime, duration, isEnabled = C_Container.GetItemCooldown(entry.spellID)
            if isEnabled == 1 and duration and duration > 1.5 then
                local spellID   = entry.spellID
                local castEpoch = loginEpoch + startTime
                local spellState = state[spellID]
                if not spellState then spellState = {}; state[spellID] = spellState end
                if spellState.castEpoch ~= castEpoch then
                    spellState.castEpoch    = castEpoch
                    spellState.onCD         = true
                    spellState.remaining    = duration
                    entry.duration = duration
                    PersistCast(spellID, castEpoch)
                    started = true
                end
            end
        end
    end
    if started then
        BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, true)
    end
end

local function FireReadyEffects(entry, row, mode, duration, visualOnly)
    if not row then return end
    StopFlash(row)
    row:SetAlpha(1)
    if mode == 'flash' then
        StartReadyPulse(row)
    else
        PlayReadyBlink(row)
    end
    if visualOnly then return end
    if entry.soundReady and entry.soundReady ~= 'None' then
        BUI.PlaySoundByName(entry.soundReady)
    end
    if entry.tts and BUI.TTS.IsAvailable() then
        local info = LookupInfo(entry)
        local name = info and info.name or ''
        local phrase = (entry.ttsText or '[spell] ready')
            :gsub('%[spell%]', name):gsub('%[name%]', name)
        BUI.TTS.Speak(phrase)
    end
end

local TTS_COUNT_LEAD  = 0.35
local TTS_PHRASE_LEAD = 1.0

local function FireLowEffects(entry, spellState)
    local lowThreshold = entry.lowThreshold or 5
    local remaining = spellState.onCD and spellState.remaining
    if entry.lowPhase == false or not remaining or remaining > lowThreshold + TTS_PHRASE_LEAD then
        spellState.lowSoundFired = nil
        spellState.spokenCount   = nil
        spellState.announceFired = nil
        return
    end

    if entry.countdownLow and BUI.TTS.IsAvailable() then
        if not spellState.announceFired then
            spellState.announceFired = true
            local phraseSeconds = math.min(lowThreshold, math.ceil(remaining - TTS_COUNT_LEAD))
            if phraseSeconds >= 1 then
                spellState.spokenCount = phraseSeconds
                local info = LookupInfo(entry)
                local name = info and info.name or ''
                local phrase = (entry.countdownText or '[spell] in [time]')
                    :gsub('%[spell%]', name):gsub('%[name%]', name)
                    :gsub('%[time%]', tostring(phraseSeconds))
                BUI.TTS.Speak(phrase)
            end
        else
            local seconds = math.ceil(remaining - TTS_COUNT_LEAD)
            if seconds >= 1 and seconds < (spellState.spokenCount or lowThreshold) then
                spellState.spokenCount = seconds
                BUI.TTS.Stop()
                BUI.TTS.Speak(tostring(seconds))
            end
        end
    end

    if remaining > lowThreshold then return end
    if entry.soundLow and entry.soundLow ~= 'None' and not spellState.lowSoundFired then
        spellState.lowSoundFired = true
        BUI.PlaySoundByName(entry.soundLow)
    end
end

local function ChargeRecharging(entry)
    if entry.kind == 'item' then return nil end
    local activeID = ActiveID(entry)
    if not Tools.IsChargeSpell(activeID) then return nil end
    local info = C_Spell.GetSpellCharges(activeID)
    if not info then return nil end
    local maxCharges = info.maxCharges
    if Tools.IsSecretValue(maxCharges) or (maxCharges or 0) <= 1 then return nil end
    local currentCharges = Tools.SafeNum(info.currentCharges)
    if currentCharges and currentCharges >= maxCharges then return false, info end
    return info.isActive == true, info
end

local function LiveCooldownState(spellID)
    local cdInfo = C_Spell.GetSpellCooldown(spellID)
    if not cdInfo then return nil end
    local isActive, isOnGCD = cdInfo.isActive, cdInfo.isOnGCD
    if Tools.IsSecretValue(isActive) or Tools.IsSecretValue(isOnGCD) then return nil end
    if isActive == false then return false end
    if isOnGCD == false then return true end
    return nil
end

local function LiveItemCooldownState(itemID)
    local startTime, duration = C_Container.GetItemCooldown(itemID)
    startTime = Tools.SafeNum(startTime)
    duration = Tools.SafeNum(duration)
    if not startTime or not duration then return nil end
    return startTime > 0 and duration > 1.5
end

local function UpdateEntryState(entry, nowEpoch, nowFrame, index)
    local spellID = entry.spellID
    local spellState = state[spellID]
    if not spellState then spellState = {}; state[spellID] = spellState end

    local wasOnCD = spellState.onCD

    local recharging, chargeInfo
    if not spellState.isPreview then recharging, chargeInfo = ChargeRecharging(entry) end
    if recharging ~= nil then
        local duration = EffectiveDuration(entry) or 0
        if not recharging then
            spellState.onCD, spellState.remaining, spellState.castEpoch, spellState.rechargeAnchor = false, nil, nil, nil
            spellState.lastCharges = nil
            ClearCast(spellID)
        else
            local liveStartTime = chargeInfo and Tools.SafeNum(chargeInfo.cooldownStartTime)
            local liveDuration  = chargeInfo and Tools.SafeNum(chargeInfo.cooldownDuration)
            if liveStartTime and liveDuration and liveDuration > 0 then
                spellState.rechargeAnchor = liveStartTime
                duration = liveDuration
            elseif not spellState.rechargeAnchor then
                spellState.rechargeAnchor = nowFrame
            end

            local chargeReady = false
            local currentCharges = chargeInfo and Tools.SafeNum(chargeInfo.currentCharges)
            if currentCharges then
                if spellState.lastCharges and currentCharges > spellState.lastCharges then chargeReady = true end
                spellState.lastCharges = currentCharges
            end
            if duration > 0 then
                while nowFrame >= spellState.rechargeAnchor + duration do
                    spellState.rechargeAnchor = spellState.rechargeAnchor + duration
                    if not currentCharges then chargeReady = true end
                end
            end

            spellState.onCD      = true
            spellState.remaining = math.max(0, spellState.rechargeAnchor + duration - nowFrame)

            if chargeReady and not spellState.suppressReady and entry.readyPhase ~= false then
                local mode = entry.readyMode    or 'flash'
                local glowDuration = entry.glowDuration or 1
                if mode ~= 'persist' then spellState.readyEndTime = nowFrame + glowDuration end
                spellState.readyFiredAt = nowFrame
                FireReadyEffects(entry, rows[index], mode, glowDuration, spellState.visualOnly)
            end
        end
    else
        local duration = EffectiveDuration(entry)
        if spellState.castEpoch and duration then
            local remaining = spellState.castEpoch + duration - nowEpoch
            local elapsed = nowEpoch - spellState.castEpoch

            local finished
            if spellState.isPreview then
                finished = remaining <= 0
            else
                local liveState
                if entry.kind == 'item' then
                    liveState = LiveItemCooldownState(spellID)
                else
                    liveState = LiveCooldownState(ActiveID(entry))
                end
                if liveState == false and elapsed > 0.5 then
                    finished = true
                elseif liveState == true then
                    finished = elapsed > duration * 2
                else
                    finished = remaining <= 0
                end
            end

            if finished then
                spellState.onCD, spellState.remaining, spellState.castEpoch = false, nil, nil
                ClearCast(spellID)
            else
                spellState.onCD, spellState.remaining = true, remaining > 0 and remaining or 0
            end
        else
            spellState.onCD, spellState.remaining = false, nil
        end
    end

    if not spellState.visualOnly then FireLowEffects(entry, spellState) end

    if wasOnCD and not spellState.onCD and not spellState.suppressReady and entry.readyPhase ~= false
        and not (spellState.readyFiredAt and nowFrame - spellState.readyFiredAt < 1) then
        local mode = entry.readyMode    or 'flash'
        local glowDuration = entry.glowDuration or 1
        spellState.readyEndTime = (mode == 'flash') and (nowFrame + glowDuration) or nil
        spellState.readyFiredAt = nowFrame
        FireReadyEffects(entry, rows[index], mode, glowDuration, spellState.visualOnly)
    end
end

local function AnyLiveState(spells, nowFrame)
    for spellIndex = 1, #spells do
        local spellState = state[spells[spellIndex].spellID]
        if spellState and (spellState.onCD or spellState.rechargeAnchor or spellState.isPreview or (spellState.readyEndTime and spellState.readyEndTime > nowFrame)) then
            return true
        end
    end
    return false
end

local function Tick()
    if not GetConfig().enabled and not previewActive then return end
    local spells = GetSpellList()
    if #spells == 0 then
        Render()
        BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, false)
        return
    end

    local nowEpoch = NowEpoch()
    local nowFrame = GetTime()
    for spellIndex = 1, #spells do
        local entry = spells[spellIndex]
        if entry.enabled then
            UpdateEntryState(entry, nowEpoch, nowFrame, spellIndex)
        end
    end

    Render()

    if not previewActive and not GetConfig().showAnchor and not AnyLiveState(spells, nowFrame) then
        BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, false)
    end
end

local function StartCooldown(entry, index, castEpoch)
    if not entry or not entry.enabled or entry.kind == 'item' then return end

    if ChargeRecharging(entry) ~= nil then
        local spellState = state[entry.spellID]
        if not spellState then spellState = {}; state[entry.spellID] = spellState end
        spellState.isPreview, spellState.suppressReady, spellState.visualOnly = nil, nil, nil
        spellState.readyEndTime = nil
        if not spellState.rechargeAnchor then spellState.rechargeAnchor = GetTime() end
        local row = index and rows[index]
        if row then StopReadyPulse(row) end
        UpdateEntryState(entry, NowEpoch(), GetTime(), index)
        BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, true)
        Render()
        return
    end

    if not InCombatLockdown() then
        local freshDuration = CDAnnouncer.ResolveCooldownSeconds(entry.spellID, entry.kind)
        if freshDuration and freshDuration > 1.5 then entry.duration = freshDuration end
    end

    local duration = EffectiveDuration(entry)
    if not duration or duration <= 0 then return end
    local spellID = entry.spellID
    local spellState = state[spellID]
    if not spellState then spellState = {}; state[spellID] = spellState end
    spellState.castEpoch     = castEpoch
    spellState.onCD          = true
    spellState.remaining     = duration
    spellState.readyEndTime  = nil
    spellState.suppressReady = nil
    spellState.isPreview     = nil
    spellState.visualOnly    = nil
    local row = index and rows[index]
    if row then StopReadyPulse(row) end
    PersistCast(spellID, castEpoch)
    BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, true)
    Render()
end

local function OnSpellCastSucceeded(_, _, _, spellID)
    if not spellID or Tools.IsSecretValue(spellID) then return end
    local entry, index = CDAnnouncer.FindEntry(spellID)
    if not entry then return end
    StartCooldown(entry, index, NowEpoch())
end

local function OnPlayerDead()
    ClearAllActiveCooldowns()
    Render()
end

local function OnTalentBurst()
    wipe(resolvedDurationCache)
    if not InCombatLockdown() then
        local spells = GetSpellList()
        for spellIndex = 1, #spells do
            local entry = spells[spellIndex]
            if entry.enabled then
                local freshDuration = CDAnnouncer.ResolveCooldownSeconds(entry.spellID, entry.kind)
                if freshDuration and freshDuration > 1.5 then entry.duration = freshDuration end
            end
        end
    end
    Render()
end

local function RestorePersistedCooldowns()
    local active = GetActiveTable()
    if not next(active) then return end
    local now = NowEpoch()
    for spellID, castEpoch in pairs(active) do
        local entry = CDAnnouncer.FindEntry(spellID)
        local duration = entry and EffectiveDuration(entry)
        local remaining = duration and (castEpoch + duration - now)
        if entry and entry.enabled and remaining and remaining > 0 then
            state[spellID] = { castEpoch = castEpoch, onCD = true, remaining = remaining }
        else
            active[spellID] = nil
        end
    end
end

function CDAnnouncer.AddSpell(input, isItem)
    local entryID = tonumber(input)
    if not entryID or CDAnnouncer.FindEntry(entryID) then return false end
    local kind = isItem and 'item' or 'spell'
    if kind == 'spell' and not C_Spell.GetSpellInfo(entryID) then return false end
    if kind == 'item'  and not C_Item.GetItemInfo(entryID)  then return false end
    local entry = {
        spellID  = entryID,
        kind     = kind,
        enabled  = true,
        duration = CDAnnouncer.ResolveCooldownSeconds(entryID, kind),
    }
    CDAnnouncer.ApplyEntryDefaults(entry)
    local spells = CDAnnouncer.GetSpells()
    spells[#spells + 1] = entry
    CDAnnouncer.Refresh()
    if CDAnnouncer.OpenSpellEditor then CDAnnouncer.OpenSpellEditor(entryID) end
    return true
end

function CDAnnouncer.DuplicateSpell(sourceID, input, isItem)
    local source = CDAnnouncer.FindEntry(tonumber(sourceID))
    if not source then return false end
    local entryID = tonumber(input)
    if not entryID or CDAnnouncer.FindEntry(entryID) then return false end
    local kind = isItem and 'item' or 'spell'
    if kind == 'spell' and not C_Spell.GetSpellInfo(entryID) then return false end
    if kind == 'item'  and not C_Item.GetItemInfo(entryID)  then return false end

    local entry = Tools.DeepCopy(source)
    entry.spellID  = entryID
    entry.kind     = kind
    entry.enabled  = true
    entry.aliases  = nil
    entry.duration = CDAnnouncer.ResolveCooldownSeconds(entryID, kind)
    CDAnnouncer.ApplyEntryDefaults(entry)

    local spells = CDAnnouncer.GetSpells()
    spells[#spells + 1] = entry
    CDAnnouncer.Refresh()
    return entryID
end

function CDAnnouncer.RefreshSpellDuration(spellID)
    local entry = CDAnnouncer.FindEntry(tonumber(spellID))
    if not entry then return end
    entry.duration = CDAnnouncer.ResolveCooldownSeconds(entry.spellID, entry.kind)
    CDAnnouncer.Refresh()
end

function CDAnnouncer.RemoveSpell(spellID)
    spellID = tonumber(spellID)
    local _, index = CDAnnouncer.FindEntry(spellID)
    if not index then return end
    table.remove(GetSpellList(), index)
    state[spellID] = nil
    ClearCast(spellID)
    CDAnnouncer.Refresh()
end

function CDAnnouncer.SetSpellEnabled(spellID, enabled)
    local entry = CDAnnouncer.FindEntry(tonumber(spellID))
    if not entry then return end
    entry.enabled = enabled and true or false
    if not entry.enabled then
        state[spellID] = nil
        ClearCast(spellID)
    end
    CDAnnouncer.Refresh()
end

function CDAnnouncer.ReorderSpells(orderedIDs)
    local spells = CDAnnouncer.GetSpells()
    local byID = {}
    for _, entry in ipairs(spells) do byID[entry.spellID] = entry end
    local rebuilt = {}
    for _, orderedID in ipairs(orderedIDs) do
        if byID[orderedID] then rebuilt[#rebuilt + 1] = byID[orderedID]; byID[orderedID] = nil end
    end
    for _, leftover in pairs(byID) do rebuilt[#rebuilt + 1] = leftover end
    GetCharacterSlot().spells = rebuilt
    CDAnnouncer.Refresh()
end

local function StartPreview(spellID, mode, duration)
    spellID = tonumber(spellID)
    local entry, index = CDAnnouncer.FindEntry(spellID)
    if not entry then return end

    local spellState = state[spellID] or {}
    state[spellID] = spellState
    local row = index and rows[index]
    if row then StopRowEffects(row) end
    ClearCast(spellID)

    local readyMode     = entry.readyMode    or 'flash'
    local readyDuration = entry.glowDuration or 1
    local lifetime

    if mode == 'cooldown' or mode == 'full' then
        local fullDuration = EffectiveDuration(entry)
        if not fullDuration then return end
        spellState.castEpoch     = NowEpoch() + duration - fullDuration
        spellState.onCD          = true
        spellState.remaining     = duration
        spellState.readyEndTime  = nil
        spellState.suppressReady = (mode == 'cooldown') or nil
        spellState.isPreview     = true
        spellState.visualOnly    = nil
        lifetime        = (mode == 'cooldown') and (duration + 0.5) or (duration + readyDuration + 1)
    elseif mode == 'ready' then
        spellState.castEpoch     = nil
        spellState.onCD          = false
        spellState.remaining     = nil
        spellState.readyEndTime  = (readyMode == 'flash') and (GetTime() + readyDuration) or nil
        spellState.suppressReady = nil
        spellState.isPreview     = true
        spellState.visualOnly    = nil
        lifetime        = readyDuration + 1
    else
        return
    end

    previewActive = true
    root:SetFrameStrata('FULLSCREEN_DIALOG')
    BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, true)

    if previewTimer then previewTimer:Cancel() end
    previewTimer = BUI.Prof.NewTimer('CDAnnouncer.CDAnnouncer', lifetime, function()
        previewActive = false
        previewTimer  = nil
        local current = state[spellID]
        if current and current.isPreview then state[spellID] = nil end
        for _, existingRow in ipairs(rows) do StopRowEffects(existingRow) end
        root:SetFrameStrata('MEDIUM')
        CDAnnouncer.Refresh()
    end)

    Render()

    if mode == 'ready' and index then
        local readyRow = rows[index]
        if readyRow then FireReadyEffects(entry, readyRow, readyMode, readyDuration) end
    end
end

function CDAnnouncer.PreviewSpell(spellID, duration)    StartPreview(spellID, 'full', duration) end

local drivenPreviewID

function CDAnnouncer.DriveLivePreview(spellID, phase, remaining)
    spellID = tonumber(spellID)
    local entry, index = CDAnnouncer.FindEntry(spellID)
    if not entry then return end

    if previewTimer then previewTimer:Cancel(); previewTimer = nil end

    local spellState = state[spellID]
    if not spellState then spellState = {}; state[spellID] = spellState end
    local wasReady = spellState.drivenReady

    drivenPreviewID = spellID
    previewActive   = true
    spellState.isPreview     = true
    spellState.suppressReady = true
    spellState.visualOnly    = nil

    if phase == 'ready' then
        spellState.castEpoch, spellState.onCD, spellState.remaining = nil, false, nil
        spellState.drivenReady  = true
        spellState.readyEndTime = (entry.readyMode ~= 'persist') and (GetTime() + 0.3) or nil
        if not wasReady then
            local row = index and rows[index]
            if row then
                FireReadyEffects(entry, row, entry.readyMode or 'flash', entry.glowDuration or 1)
            end
        end
    else
        if wasReady then
            spellState.drivenReady = nil
            local row = index and rows[index]
            if row then StopReadyPulse(row) end
        end
        local fullDuration = EffectiveDuration(entry) or remaining
        spellState.onCD         = true
        spellState.remaining    = remaining
        spellState.castEpoch    = NowEpoch() - math.max(0, fullDuration - remaining)
        spellState.readyEndTime = nil
    end

    root:SetFrameStrata('FULLSCREEN_DIALOG')
    BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, true)
    Render()
end

function CDAnnouncer.StopLivePreview()
    if not drivenPreviewID then return end
    local spellID = drivenPreviewID
    drivenPreviewID = nil
    if previewTimer then previewTimer:Cancel(); previewTimer = nil end
    previewActive = false

    local spellState = state[spellID]
    if spellState and spellState.isPreview then
        state[spellID] = nil
        local entry = CDAnnouncer.FindEntry(spellID)
        local castEpoch = GetActiveTable()[spellID]
        local duration = entry and EffectiveDuration(entry)
        if entry and castEpoch and duration and (castEpoch + duration) > NowEpoch() then
            state[spellID] = {
                castEpoch = castEpoch,
                onCD      = true,
                remaining = castEpoch + duration - NowEpoch(),
            }
        end
    end
    for _, existingRow in ipairs(rows) do StopRowEffects(existingRow) end
    root:SetFrameStrata('MEDIUM')
    CDAnnouncer.Refresh()
end

local function SaveFramePosition()
    local config = GetConfig()
    BUI.Dragging.SaveCenterPosition(root, config, true)
    if positionCallback then positionCallback(config.posX, config.posY) end
end

local function EnableDragging()
    BUI.Dragging.EnableAnchorDrag(root, {
        isCentered = function() return GetConfig().centerHorizontally end,
        onSave     = SaveFramePosition,
        onRightClick = function()
            GetConfig().showAnchor = false
            CDAnnouncer.Refresh()
            if anchorCallback then anchorCallback(false) end
        end,
    })
    anchorTexture:Show()
    anchorTexturet:Show()
end

local function DisableDragging()
    BUI.Dragging.DisableAnchorDrag(root)
    anchorTexture:Hide()
    anchorTexturet:Hide()
end

local function BuildFrame()
    root = CreateFrame('Frame', FRAME_NAME, UIParent)
    root:SetFrameStrata('MEDIUM')
    root:SetFrameLevel(10)
    root:SetClampedToScreen(true)
    root:SetSize(Pixel.Scale(160), Pixel.Scale(24))
    root:Hide()

    stack = CreateFrame('Frame', nil, root)
    stack:SetSize(Pixel.Scale(160), Pixel.Scale(24))
    stack:SetPoint('CENTER', root, 'CENTER', 0, 0)

    anchorTexture = root:CreateTexture(nil, 'BACKGROUND', nil, -8)
    anchorTexture:SetAllPoints()
    Tools.SetColorTex(anchorTexture, 0, 0, 0, 0.3)
    anchorTexture:Hide()

    anchorTexturet = root:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(anchorTexturet, 10, BUI.GetGlobalFont(), 'OUTLINE')
    anchorTexturet:SetPoint('BOTTOM', root, 'TOP', 0, Pixel.Scale(2))
    anchorTexturet:SetJustifyH('CENTER')
    anchorTexturet:SetText('Drag to Reposition | Right-Click to Lock')
    anchorTexturet:Hide()
end

local function UpdateOpacity()
    local opacity = (BUI.Visibility.GetContextualOpacity('CDAnnouncer') or 100) / 100
    root:SetAlpha(opacity)
end

local QueueItemScan = BUI.Dispatcher.New(ScanItemCooldowns, 'CDA.ItemScan')

local function HasEnabledItemEntry()
    for _, entry in ipairs(GetSpellList()) do
        if entry.kind == 'item' and entry.enabled then return true end
    end
    return false
end

local function SyncEventRegistration()
    local enabled = GetConfig().enabled

    if enabled ~= castEventsActive then
        castEventsActive = enabled
        if enabled then
            BUI.Events:RegisterUnit('UNIT_SPELLCAST_SUCCEEDED', 'player', MODULE_KEY, OnSpellCastSucceeded)
            BUI.Events:Register('PLAYER_DEAD', MODULE_KEY, OnPlayerDead)
        else
            BUI.Events:Unregister('UNIT_SPELLCAST_SUCCEEDED', MODULE_KEY)
            BUI.Events:Unregister('PLAYER_DEAD', MODULE_KEY)
        end
    end

    local needsItemEvents = enabled and HasEnabledItemEntry()
    if needsItemEvents ~= itemEventsActive then
        itemEventsActive = needsItemEvents
        if needsItemEvents then
            BUI.Events:Register('BAG_UPDATE_COOLDOWN',   MODULE_KEY, QueueItemScan)
            BUI.Events:Register('SPELL_UPDATE_COOLDOWN', MODULE_KEY, QueueItemScan)
        else
            BUI.Events:Unregister('BAG_UPDATE_COOLDOWN',   MODULE_KEY)
            BUI.Events:Unregister('SPELL_UPDATE_COOLDOWN', MODULE_KEY)
        end
    end
end

local function UpdateTickState()
    local config = GetConfig()
    local active = previewActive or (config.enabled and #GetSpellList() > 0)
    BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, active or false)
end

function CDAnnouncer.Refresh()
    ApplyPosition()
    if GetConfig().showAnchor then EnableDragging() else DisableDragging() end
    SyncEventRegistration()
    if GetConfig().enabled then ScanItemCooldowns() end
    UpdateTickState()
    Render()
end

local function MigrateToProfileCharScope()
    local slot = GetCharacterSlot()
    if slot._migrated then return end
    slot._migrated = true

    local charScope = BUI.db.char.cdAnnouncer
    if charScope and charScope.spells and #charScope.spells > 0 and #(slot.spells or {}) == 0 then
        slot.spells = Tools.DeepCopy(charScope.spells)
    end
    if charScope and charScope.active and next(charScope.active) and not next(slot.active or {}) then
        slot.active = Tools.DeepCopy(charScope.active)
    end
    if charScope then
        charScope.spells = nil
        charScope.active = nil
        charScope._migratedFromProfile = nil
    end

    local profile = GetConfig()
    if profile.spells and #profile.spells > 0 and #(slot.spells or {}) == 0 then
        slot.spells = Tools.DeepCopy(profile.spells)
    end
    if profile.active and next(profile.active) and not next(slot.active or {}) then
        slot.active = Tools.DeepCopy(profile.active)
    end
end

local function MigrateCdColor()
    local cdColor = GetConfig().cdColor
    if cdColor.r == 1 and cdColor.g == 0.55 and cdColor.b == 0.4 then
        cdColor.r, cdColor.g, cdColor.b, cdColor.a = 1, 1, 1, 1
    end
end

local function MigrateEntries()
    local spells = GetSpellList()
    for spellIndex = #spells, 1, -1 do
        if spells[spellIndex].kind == 'bloodlust' then table.remove(spells, spellIndex) end
    end

    for _, entry in ipairs(spells) do
        if type(entry.soundReady) == 'number' then entry.soundReady = nil end
        if entry.hideWhileOnCD ~= nil then
            if entry.hideWhileOnCD == true then entry.cdPhase = false end
            entry.hideWhileOnCD = nil
        end
        entry.fontPath           = nil
        entry.readyIconSize      = nil
        entry._cachedDuration    = nil
        entry._cachedDurationFor = nil
    end
end

local function Initialize()
    loginEpoch = time() - GetTime()
    MigrateToProfileCharScope()
    MigrateCdColor()
    MigrateEntries()
    BuildFrame()
    RestorePersistedCooldowns()
    BUI.Scheduler.RegisterUpdate(MODULE_KEY, Tick, TICK_INTERVAL, GetConfig().enabled)
    BUI.Events:OnTalentBurst(MODULE_KEY, OnTalentBurst)
    BUI.Visibility.Register('CDAnnouncer', UpdateOpacity, true)
    CDAnnouncer.Refresh()
end

BUI.Events:OnLogin('CDAnnouncer', Initialize)
