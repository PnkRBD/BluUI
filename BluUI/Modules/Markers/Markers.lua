local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Markers.Markers')

local Pixel  = BUI.Pixel
local Tools  = BUI.Tools
local Events = BUI.Events
local BUILib = BluUI.BUILibClient

local Markers = {}
BUI.Markers = Markers

local WHITE8 = 'Interface\\Buttons\\WHITE8x8'
local TILE_FILL = { 0.07, 0.07, 0.08, 0.92 }
local TILE_EDGE = { 0, 0, 0, 1 }
local SEPARATOR_COLOR = { 1, 1, 1, 0.14 }
local CLEAR_COLOR = { 0.92, 0.3, 0.3 }
local READY_COLOR = { 0.35, 0.85, 0.45 }
local ICON_CROP = 0.09
local GLYPH_RATIO = 0.5

local MARKS = {
    { name = 'Skull',    raid = 8, world = 8, tint = { 1,    1,    1    } },
    { name = 'Cross',    raid = 7, world = 4, tint = { 1,    0.14, 0.14 } },
    { name = 'Square',   raid = 6, world = 1, tint = { 0,    0.44, 0.87 } },
    { name = 'Moon',     raid = 5, world = 7, tint = { 0.41, 0.8,  0.94 } },
    { name = 'Triangle', raid = 4, world = 2, tint = { 0.24, 0.88, 0.25 } },
    { name = 'Diamond',  raid = 3, world = 3, tint = { 0.64, 0.19, 0.79 } },
    { name = 'Circle',   raid = 2, world = 6, tint = { 1,    0.49, 0.04 } },
    { name = 'Star',     raid = 1, world = 5, tint = { 1,    1,    0    } },
}

local bar
local markerButtons = {}
local controls = {}
local built = false

local function GetConfig()
    return BUI.GetDB().markers
end

local function ModuleEnabled()
    return BUI.IsModuleEnabled('markers')
end

local function ShowTip(button, header, ...)
    if not GetConfig().tooltips then return end
    GameTooltip:SetOwner(button, 'ANCHOR_TOP')
    GameTooltip:ClearLines()
    GameTooltip:AddLine(header, 1, 1, 1)
    for lineIndex = 1, select('#', ...) do
        local line = select(lineIndex, ...)
        if line then GameTooltip:AddLine(line, 0.7, 0.7, 0.7) end
    end
    GameTooltip:Show()
end

local function HideTip() GameTooltip:Hide() end

local function CanControlGroup()
    if not IsInGroup() then return true end
    return UnitIsGroupLeader('player') or UnitIsGroupAssistant('player')
end

local function UpdateIndicators()
    if not built then return end
    for markIndex = 1, #MARKS do
        local button = markerButtons[markIndex]
        button.worldLine:SetAlphaFromBoolean(IsRaidMarkerActive(MARKS[markIndex].world), 1, 0)
    end
end

local function ScheduleIndicatorUpdate()
    BUI.Prof.After('Markers.Markers', 0.2, UpdateIndicators)
end

local function UpdateUsability()
    if not built then return end
    local alpha = CanControlGroup() and 1 or 0.35
    controls.ready:SetAlpha(alpha)
    controls.timer:SetAlpha(alpha)
end

local function UpdateVisibility()
    if not built then return end
    if InCombatLockdown() then
        Events:AfterCombat(function() UpdateVisibility() end, 'Markers.Visibility')
        return
    end
    local config = GetConfig()
    local shown = ModuleEnabled() and (not config.onlyInGroup or IsInGroup())
    bar:SetShown(shown)
end

local FADE_SETTLE = 0.01
local fadeGroup, fadeAnim
local hovered, hoverPending, hoverHooked = false, false, false

local function EnsureFader()
    if fadeGroup then return end
    fadeGroup = bar:CreateAnimationGroup()
    fadeGroup:SetToFinalAlpha(true)
    fadeAnim = fadeGroup:CreateAnimation('Alpha')
    fadeAnim:SetSmoothing('IN_OUT')
end

local function TargetAlpha()
    local config = GetConfig()
    local alpha = config.alpha / 100
    alpha = alpha * BUI.Visibility.GetContextualOpacity('Markers') / 100
    if config.fadeEnabled and not hovered then
        alpha = alpha * config.fadeAlpha / 100
    end
    return alpha
end

local function ApplyAlpha(instant)
    if not built then return end
    local config = GetConfig()
    local target = TargetAlpha()
    local seconds = 0
    if not instant and config.fadeEnabled and config.fadeAnimated then
        seconds = config.fadeDuration
    end
    if fadeGroup then fadeGroup:Stop() end
    local current = bar:GetAlpha()
    if seconds <= 0 or math.abs(current - target) < FADE_SETTLE then
        bar:SetAlpha(target)
        return
    end
    EnsureFader()
    bar:SetAlpha(current)
    fadeAnim:SetFromAlpha(current)
    fadeAnim:SetToAlpha(target)
    fadeAnim:SetDuration(seconds)
    fadeGroup:Play()
end

local function EvaluateHover()
    hoverPending = false
    if not built then return end
    local over = bar:IsMouseOver() and true or false
    if over ~= hovered then
        hovered = over
        ApplyAlpha()
    end
end

local function QueueHoverCheck()
    if hoverPending or not built or not GetConfig().fadeEnabled then return end
    hoverPending = true
    BUI.Prof.After('Markers.Fade', 0, EvaluateHover)
end

local function EnsureHoverHooks()
    if hoverHooked or not built then return end
    hoverHooked = true
    HookScript(bar, 'OnEnter', QueueHoverCheck)
    HookScript(bar, 'OnLeave', QueueHoverCheck)
    for _, child in ipairs({ bar:GetChildren() }) do
        HookScript(child, 'OnEnter', QueueHoverCheck)
        HookScript(child, 'OnLeave', QueueHoverCheck)
    end
end

local function RefreshFade()
    if not built then return end
    EnsureHoverHooks()
    hovered = GetConfig().fadeEnabled and bar:IsMouseOver() and true or false
    ApplyAlpha(true)
end

local function DecorateButton(button)
    Pixel.SetTemplate(button, TILE_FILL[1], TILE_FILL[2], TILE_FILL[3], TILE_FILL[4], TILE_EDGE[1], TILE_EDGE[2], TILE_EDGE[3], TILE_EDGE[4], 1)
    button:SetHighlightTexture(WHITE8)
    button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
    button:SetPushedTexture(WHITE8)
    button:GetPushedTexture():SetVertexColor(1, 1, 1, 0.2)
end

local function Glyph(button, key, color)
    local glyph = button:CreateTexture(nil, 'ARTWORK')
    glyph:SetTexture(BUILib.GetLibMedia(key))
    glyph:SetVertexColor(color[1], color[2], color[3], 1)
    glyph:SetPoint('CENTER')
    button.glyph = glyph
    return glyph
end

local function InsetIcon(texture, button, inset)
    texture:ClearAllPoints()
    texture:SetPoint('TOPLEFT', button, 'TOPLEFT', inset, -inset)
    texture:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -inset, inset)
end

local function FitTile(button, buttonSize, edge)
    button:SetSize(buttonSize, buttonSize)
    InsetIcon(button:GetHighlightTexture(), button, edge)
    InsetIcon(button:GetPushedTexture(), button, edge)
    if button.icon then InsetIcon(button.icon, button, edge + Pixel.PixelSize(1)) end
    if button.glyph then
        local glyphSize = Pixel.ScaleEven(math.floor(buttonSize * GLYPH_RATIO))
        button.glyph:SetSize(glyphSize, glyphSize)
    end
end

local function Build()
    if built or not ModuleEnabled() then return end
    if InCombatLockdown() then
        Events:AfterCombat(function() Markers.Refresh() end, 'Markers.Build')
        return
    end
    built = true

    bar = CreateFrame('Frame', 'BUI_MarkerBar', UIParent)
    bar:SetFrameStrata('MEDIUM')
    bar:SetClampedToScreen(true)
    bar.separator = bar:CreateTexture(nil, 'ARTWORK')
    Tools.SetColorTex(bar.separator, SEPARATOR_COLOR[1], SEPARATOR_COLOR[2], SEPARATOR_COLOR[3], SEPARATOR_COLOR[4])

    for markIndex, mark in ipairs(MARKS) do
        local button = CreateFrame('Button', 'BUI_Marker' .. mark.name, bar, 'SecureActionButtonTemplate')
        button:RegisterForClicks('AnyUp', 'AnyDown')
        DecorateButton(button)

        button.icon = button:CreateTexture(nil, 'ARTWORK')
        button.icon:SetTexture('interface\\targetingframe\\ui-raidtargetingicon_' .. mark.raid)
        button.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

        button:SetAttribute('type1', 'macro')
        button:SetAttribute('macrotext1', '/tm ' .. mark.raid)
        button:SetAttribute('shift-type1', 'macro')
        button:SetAttribute('shift-macrotext1', '/wm ' .. mark.world)
        button:SetAttribute('shift-type2', 'macro')
        button:SetAttribute('shift-macrotext2', '/cwm ' .. mark.world)

        local line = button:CreateTexture(nil, 'OVERLAY')
        Tools.SetColorTex(line, mark.tint[1], mark.tint[2], mark.tint[3], 0.95)
        line:SetAlpha(0)
        button.worldLine = line

        SetScript(button, 'OnEnter', function(self)
            ShowTip(self, _G['BINDING_NAME_RAIDTARGET' .. mark.raid],
                'Click: mark target',
                'Shift-Click: place world marker',
                'Shift-Right-Click: clear world marker')
        end)
        SetScript(button, 'OnLeave', HideTip)
        SetScript(button, 'PostClick', ScheduleIndicatorUpdate)

        markerButtons[markIndex] = button
    end

    local clear = CreateFrame('Button', 'BUI_MarkerClear', bar, 'SecureActionButtonTemplate')
    clear:RegisterForClicks('AnyUp', 'AnyDown')
    DecorateButton(clear)
    Glyph(clear, 'x', CLEAR_COLOR)
    clear:SetAttribute('type1', 'macro')
    clear:SetAttribute('macrotext1', '/tm 0')
    clear:SetAttribute('shift-type1', 'macro')
    clear:SetAttribute('shift-macrotext1', '/cwm all')
    SetScript(clear, 'OnEnter', function(self)
        ShowTip(self, 'Clear',
            'Click: remove mark from target',
            'Shift-Click: clear all world markers')
    end)
    SetScript(clear, 'OnLeave', HideTip)
    SetScript(clear, 'PostClick', ScheduleIndicatorUpdate)
    controls.clear = clear

    local ready = CreateFrame('Button', 'BUI_MarkerReadyCheck', bar, 'BackdropTemplate')
    ready:RegisterForClicks('LeftButtonUp')
    DecorateButton(ready)
    Glyph(ready, 'check', READY_COLOR)
    SetScript(ready, 'OnClick', function() DoReadyCheck() end)
    SetScript(ready, 'OnEnter', function(self)
        ShowTip(self, READY_CHECK, 'Click: start a ready check',
            'Requires lead or assist')
    end)
    SetScript(ready, 'OnLeave', HideTip)
    controls.ready = ready

    local timer = CreateFrame('Button', 'BUI_MarkerCountdown', bar, 'BackdropTemplate')
    timer:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    DecorateButton(timer)
    timer.text = timer:CreateFontString(nil, 'OVERLAY')
    timer.text:SetPoint('CENTER', 0, 0)
    Pixel.ApplyFont(timer.text, 12)
    timer.text:SetText('5')
    local accentRed, accentGreen, accentBlue = BUILib.Theme.GetAccent()
    timer.text:SetTextColor(accentRed, accentGreen, accentBlue, 1)
    SetScript(timer, 'OnClick', function(_, mouseButton)
        local config = GetConfig()
        if IsShiftKeyDown() then
            C_PartyInfo.DoCountdown(0)
        elseif mouseButton == 'RightButton' then
            if config.countdownTime2 > 0 then C_PartyInfo.DoCountdown(config.countdownTime2) end
        elseif config.countdownTime > 0 then
            C_PartyInfo.DoCountdown(config.countdownTime)
        end
    end)
    SetScript(timer, 'OnEnter', function(self)
        local config = GetConfig()
        ShowTip(self, 'Countdown',
            ('Click: %ds countdown'):format(config.countdownTime),
            ('Right-Click: %ds countdown'):format(config.countdownTime2),
            'Shift-Click: cancel countdown')
    end)
    SetScript(timer, 'OnLeave', HideTip)
    controls.timer = timer

    BUI.Dragging.MakeDraggable(bar, {
        skipClickThrough = true,
        onPositionChanged = function(x, y)
            local config = GetConfig()
            config.posX, config.posY = x, y
        end,
    })

    local function OnButtonDragStart()
        bar:StartMoving()
    end
    local function OnButtonDragStop()
        bar:StopMovingOrSizing()
        local config = GetConfig()
        config.posX, config.posY = BUI.Dragging.GetCenterOffset(bar)
        bar:ClearAllPoints()
        bar:SetPoint('CENTER', UIParent, 'CENTER', config.posX, config.posY)
    end
    local function ForwardDrag(button)
        button:RegisterForDrag('LeftButton')
        SetScript(button, 'OnDragStart', OnButtonDragStart)
        SetScript(button, 'OnDragStop', OnButtonDragStop)
    end
    for _, button in ipairs(markerButtons) do ForwardDrag(button) end
    for _, button in pairs(controls) do ForwardDrag(button) end
end

local CONTROL_ORDER = { 'clear', 'ready', 'timer' }

local function ApplyLayout()
    if not built then return end
    local config = GetConfig()
    local size = config.iconSize
    local buttonSize = Pixel.ScaleEven(size)
    local edge = Pixel.PixelSize(1)
    local separator = Pixel.Scale(10)
    local showControls = config.showControls ~= false

    BUI.Anchor.ApplyPosition(bar, config)

    local buttonCount = #markerButtons + (showControls and #CONTROL_ORDER or 0)
    local gapSlots = (#markerButtons - 1) + (showControls and #CONTROL_ORDER or 0)
    local gap = Pixel.Scale(math.max(1, config.spacing))
    local natural = buttonCount * buttonSize + gap * gapSlots + (showControls and separator or 0)

    local anchorWidth = BUI.Anchor.GetAnchorWidth(bar, config)
    if anchorWidth and gapSlots > 0 and anchorWidth > natural then
        gap = gap + (anchorWidth - natural) / gapSlots
    end

    local x = 0
    for buttonIndex, button in ipairs(markerButtons) do
        FitTile(button, buttonSize, edge)
        button.worldLine:ClearAllPoints()
        button.worldLine:SetPoint('BOTTOMLEFT', button, 'BOTTOMLEFT', edge, edge)
        button.worldLine:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -edge, edge)
        button.worldLine:SetHeight(Pixel.PixelSize(2))
        button:ClearAllPoints()
        button:SetPoint('LEFT', bar, 'LEFT', x, 0)
        x = x + buttonSize + (buttonIndex < #markerButtons and gap or 0)
    end

    if showControls then
        bar.separator:ClearAllPoints()
        bar.separator:SetPoint('CENTER', bar, 'LEFT', x + gap + separator / 2, 0)
        bar.separator:SetSize(edge, buttonSize - Pixel.Scale(6))
        bar.separator:Show()
        x = x + gap + separator

        for controlIndex, key in ipairs(CONTROL_ORDER) do
            local button = controls[key]
            FitTile(button, buttonSize, edge)
            button:ClearAllPoints()
            button:SetPoint('LEFT', bar, 'LEFT', x, 0)
            button:Show()
            x = x + buttonSize + (controlIndex < #CONTROL_ORDER and gap or 0)
        end

        Pixel.ApplyFont(controls.timer.text, math.max(10, math.floor(size * 0.55)))
        local accentRed, accentGreen, accentBlue = BUILib.Theme.GetAccent()
        controls.timer.text:SetTextColor(accentRed, accentGreen, accentBlue, 1)
    else
        bar.separator:Hide()
        for _, key in ipairs(CONTROL_ORDER) do controls[key]:Hide() end
    end

    controls.timer.text:SetText(tostring(config.countdownTime))

    bar:SetSize(x, buttonSize)
    bar:EnableMouse(true)
end

function Markers.Refresh()
    if not ModuleEnabled() then
        if built then bar:Hide() end
        return
    end
    Build()
    if not built then return end
    Events:AfterCombat(ApplyLayout, 'Markers.Layout')
    UpdateVisibility()
    RefreshFade()
    UpdateIndicators()
    UpdateUsability()
end

function Markers.Initialize()
    Build()
    Markers.Refresh()

    BUI.Visibility.Register("Markers", ApplyAlpha, true)
    BUI.Anchor.RegisterCallback("Markers", function()
        if not built or InCombatLockdown() then return end
        if not BUI.Anchor.ShouldRefreshOnAnchorChange(GetConfig()) then return end
        ApplyLayout()
    end)

    Events:Register('RAID_TARGET_UPDATE', 'Markers', UpdateIndicators)
    Events:Register('GROUP_ROSTER_UPDATE', 'Markers', function()
        UpdateVisibility(); UpdateUsability(); UpdateIndicators()
    end)
    Events:Register('PARTY_LEADER_CHANGED', 'Markers', UpdateUsability)
    Events:Register('PLAYER_ENTERING_WORLD', 'Markers', function()
        UpdateVisibility(); UpdateUsability(); UpdateIndicators()
    end)
end

Events:OnLogin('Markers', Markers.Initialize)

BUI.RegisterModuleControl('markers', function(enabled)
    if enabled and not built then
        Markers.Initialize()
    else
        Markers.Refresh()
    end
end)
