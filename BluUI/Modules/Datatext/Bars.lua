local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Datatext.Bars')

local Datatext = BUI.Datatext
local Pixel = BUI.Pixel

local registry = Datatext.registry
local IsPanel = Datatext.IsPanel
local GetBars, GetBarConfig, GetMinimapConfig, ModuleEnabled =
    Datatext.GetBars, Datatext.GetBarConfig, Datatext.GetMinimapDB, Datatext.ModuleEnabled

local LAYOUT = {
    rowInset    = 6,
    columnInset = 6,
    rowHeight   = 26,
    emptyWidth  = 120,
    lineExtra   = 4,
}
Datatext.LAYOUT = LAYOUT

local bars = {}
local minimapBar
local measureFontString, measureFontSize, measureFontPath

local parts, partEntries, partCount = {}, {}, 0
local textWidths = {}
local layout = { textLeft = {}, textWidth = {}, hitLeft = {}, hitWidth = {}, lineTop = {} }
local cachedHex, cachedRed, cachedGreen, cachedBlue
local fontGeneration = 0

local function MirroredChatRect()
    local chatFrame = _G.BUI_ChatPanel
    if not chatFrame or not chatFrame:IsShown() or not chatFrame:GetLeft() then chatFrame = _G.ChatFrame1 end
    if not chatFrame or not chatFrame:GetLeft() then return end
    local scale = chatFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return -BUI.Round(chatFrame:GetLeft() * scale), BUI.Round(chatFrame:GetBottom() * scale),
        BUI.Round(chatFrame:GetWidth() * scale), BUI.Round(chatFrame:GetHeight() * scale)
end

local function ColorHex(config)
    local color = config.colorValue
    if cachedRed ~= color.r or cachedGreen ~= color.g or cachedBlue ~= color.b then
        cachedRed, cachedGreen, cachedBlue = color.r, color.g, color.b
        cachedHex = BUI.Hex(color.r, color.g, color.b)
    end
    return cachedHex
end

local function BuildText(config)
    partCount = 0
    local valueHex = ColorHex(config)
    local order = Datatext.ResolveOrder(config)
    local hitSignature = ''

    for orderIndex = 1, #order do
        local entry = registry[order[orderIndex]]
        if entry and config[entry.show] then
            local text = entry.build(config, valueHex, entry)
            if text and text ~= '' then
                partCount = partCount + 1
                parts[partCount] = text
                partEntries[partCount] = entry
                if entry.interactive then hitSignature = hitSignature .. entry.id .. '@' .. partCount .. ',' end
            end
        end
    end

    return hitSignature
end

local function EnsureMeasureFontString(config)
    local fontPath = BUI.GetModuleFont(config)
    if not measureFontString then
        measureFontString = UIParent:CreateFontString(nil, 'ARTWORK')
        measureFontString:SetAlpha(0)
        measureFontString:SetPoint('TOP', UIParent, 'BOTTOM', 0, -100)
    end
    if measureFontSize ~= config.fontSize or measureFontPath ~= fontPath then
        measureFontSize, measureFontPath = config.fontSize, fontPath
        Pixel.ApplyFont(measureFontString, config.fontSize, fontPath)
    end
end

local function MeasureText(text)
    measureFontString:SetText(text)
    local width = measureFontString:GetStringWidth()
    local stable = text:gsub('%d', '8')
    if stable ~= text then
        measureFontString:SetText(stable)
        local stableWidth = measureFontString:GetStringWidth()
        if stableWidth > width then width = stableWidth end
    end
    return width
end

local function LockBar(bar)
    local config = bar.getConfig()
    if not config or config.lock then return end
    config.lock = true
    local toggle = Datatext._lockToggle
    if toggle and toggle.SetValue and Datatext._lockToggleIndex == bar.index then
        toggle:SetValue(false)
    end
    Datatext.Apply()
end

local function BarUnlocked(bar)
    local config = bar.index and bar.getConfig()
    return (config and not config.lock) and true or false
end

local function BeginBarDrag(bar)
    bar.frame:StartMoving()
    bar.dragging = true
end

local function EndBarDrag(bar)
    local frame = bar.frame
    frame:StopMovingOrSizing()
    bar.dragging = nil
    local config = bar.getConfig()
    if not config then return end
    local point, _, relPoint, offsetX, offsetY = frame:GetPoint()
    config.point, config.relPoint, config.x, config.y = point, relPoint, offsetX, offsetY
    config.alignMinimap = false
end

local function HitOnDragStart(self)
    if not BarUnlocked(self.bar) then return end
    BeginBarDrag(self.bar)
end

local function HitOnDragStop(self)
    local bar = self.bar
    if not bar.dragging then return end
    EndBarDrag(bar)
    self.draggedAt = GetTime()
end

local function SetHitDrag(hit, enabled)
    if hit._dragEnabled == enabled then return end
    hit._dragEnabled = enabled
    if enabled then
        hit:RegisterForDrag('LeftButton')
        SetScript(hit, 'OnDragStart', HitOnDragStart)
        SetScript(hit, 'OnDragStop', HitOnDragStop)
    else
        hit:RegisterForDrag()
        SetScript(hit, 'OnDragStart', nil)
        SetScript(hit, 'OnDragStop', nil)
    end
end

local function HitOnClick(self, mouseButton)
    if self.draggedAt and GetTime() - self.draggedAt < 0.1 then
        self.draggedAt = nil
        return
    end
    local entry, bar = self.entry, self.bar
    if entry.OnClick and entry.OnClick(self, mouseButton, bar) then return end
    if mouseButton == 'RightButton' then
        LockBar(bar)
    elseif mouseButton == 'LeftButton' and bar.index and not InCombatLockdown() then
        ToggleCharacter('PaperDollFrame')
    end
end

local function HitOnEnter(self)
    if Datatext.HoversBlocked() then return end
    local entry = self.entry
    if not entry.OnEnter then return end
    if entry._profOnEnter == nil or entry._profOnEnterRaw ~= entry.OnEnter then
        entry._profOnEnterRaw = entry.OnEnter
        entry._profOnEnter = BUI.Prof.Wrap('datatext#' .. tostring(entry.id) .. '.OnEnter', entry.OnEnter)
    end
    entry._profOnEnter(self, self.bar)
end

local function HitOnLeave(self)
    local entry = self.entry
    if entry.OnLeave then entry.OnLeave(self, self.bar) end
    if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end

local function GetHit(bar, entry)
    local hit = bar.hits[entry.id]
    if not hit then
        hit = CreateFrame('Button', nil, bar.frame)
        hit:SetFrameStrata(bar.frame:GetFrameStrata())
        hit:SetFrameLevel(bar.frame:GetFrameLevel() + 10)
        hit:EnableMouse(true)
        hit:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
        SetScript(hit, 'OnClick', HitOnClick)
        SetScript(hit, 'OnEnter', HitOnEnter)
        SetScript(hit, 'OnLeave', HitOnLeave)
        hit.isDatatextHit = true
        hit.bar = bar
        hit:Hide()
        bar.hits[entry.id] = hit
    end
    hit.entry = entry
    SetHitDrag(hit, bar.dragEnabled and true or false)
    return hit
end

local function HideHits(bar)
    for _, hit in pairs(bar.hits) do hit:Hide() end
end

local function ApplyPartFont(fontString, config, fontPath)
    if fontString._fontGen == fontGeneration and fontString._fontSize == config.fontSize and fontString._fontPath == fontPath then return end
    fontString._fontGen, fontString._fontSize, fontString._fontPath = fontGeneration, config.fontSize, fontPath
    Pixel.ApplyFont(fontString, config.fontSize, fontPath)
end

function Datatext.LayoutRow(widths, count, spacing, inset, fixedWidth, align, spread, out)
    local textLeft, textWidth, hitLeft, hitWidth = out.textLeft, out.textWidth, out.hitLeft, out.hitWidth
    local sum = 0
    for index = 1, count do sum = sum + widths[index] end
    local barWidth = fixedWidth or (sum + (count - 1) * spacing + 2 * inset)
    local inner = barWidth - 2 * inset

    if fixedWidth and align == 'SPREAD' then
        local slot = inner / count
        for index = 1, count do
            local left = inset + (index - 1) * slot
            local width = math.min(widths[index], slot)
            textLeft[index], textWidth[index] = left + (slot - width) / 2, width
            hitLeft[index], hitWidth[index] = left, slot
        end
        return barWidth
    end

    local gap = spacing
    if fixedWidth and spread > 0 and count > 1 then
        local leftover = inner - sum - (count - 1) * spacing
        if leftover > 0 then gap = spacing + leftover * spread / (count - 1) end
    end
    local groupWidth = sum + (count - 1) * gap
    local cursor = inset
    if fixedWidth then
        if align == 'RIGHT' then
            cursor = barWidth - inset - groupWidth
        elseif align ~= 'LEFT' then
            cursor = (barWidth - groupWidth) / 2
        end
    end
    for index = 1, count do
        local width = widths[index]
        textLeft[index], textWidth[index] = cursor, width
        local left = math.max(cursor - gap / 2, 0)
        local right = math.min(cursor + width + gap / 2, barWidth)
        hitLeft[index], hitWidth[index] = left, math.max(right - left, 1)
        cursor = cursor + width + gap
    end
    return barWidth
end

function Datatext.LayoutColumn(widths, count, spacing, inset, lineHeight, fixedWidth, fixedHeight, out)
    local maxWidth = 0
    for index = 1, count do
        if widths[index] > maxWidth then maxWidth = widths[index] end
    end
    local barWidth = fixedWidth or (maxWidth + 2 * inset)
    local contentHeight = count * lineHeight + (count - 1) * spacing
    local barHeight = fixedHeight or (contentHeight + 2 * inset)
    local top = (barHeight - contentHeight) / 2
    for index = 1, count do
        out.lineTop[index] = top + (index - 1) * (lineHeight + spacing)
    end
    out.lineLeft, out.lineWidth = inset, math.max(barWidth - 2 * inset, 1)
    return barWidth, barHeight
end

local function SetBarSize(bar, width, height)
    local frame = bar.frame
    if not bar.anchoredWidth then frame:SetWidth(width) end
    if not bar.anchoredHeight then frame:SetHeight(height) end
end

local function HidePartStrings(bar, fromIndex)
    local strings = bar.partStrings
    if not strings then return end
    for partIndex = fromIndex, #strings do strings[partIndex]:Hide() end
end

local function FixedSide(anchored, setting)
    if anchored then return anchored > 0 and anchored or nil end
    return setting and setting > 0 and Pixel.Scale(setting) or nil
end

local function RenderCells(bar, config)
    local frame = bar.frame
    bar.partStrings = bar.partStrings or {}
    local partTotal = partCount
    local fixedWidth = FixedSide(bar.anchoredWidth and frame:GetWidth(), config.width)
    local fixedHeight = FixedSide(bar.anchoredHeight and frame:GetHeight(), config.height)
    if partTotal == 0 then
        HidePartStrings(bar, 1)
        SetBarSize(bar, fixedWidth or Pixel.Scale(LAYOUT.emptyWidth), fixedHeight or Pixel.Scale(LAYOUT.rowHeight))
        return
    end

    local fontPath = BUI.GetModuleFont(config)
    EnsureMeasureFontString(config)
    for partIndex = 1, partTotal do
        local fontString = bar.partStrings[partIndex]
        if not fontString then
            fontString = frame:CreateFontString(nil, 'ARTWORK')
            fontString:SetWordWrap(false)
            bar.partStrings[partIndex] = fontString
        end
        ApplyPartFont(fontString, config, fontPath)
        fontString:SetText(parts[partIndex])
        fontString._lastText = parts[partIndex]
        textWidths[partIndex] = MeasureText(parts[partIndex])
    end

    local spacing = Pixel.Scale(config.spacing)
    local align = config.align or 'CENTER'

    if config.orientation == 'VERTICAL' then
        local lineHeight = Pixel.Scale(config.fontSize + LAYOUT.lineExtra)
        local barWidth, barHeight = Datatext.LayoutColumn(textWidths, partTotal, spacing, Pixel.Scale(LAYOUT.columnInset),
            lineHeight, fixedWidth, fixedHeight, layout)
        SetBarSize(bar, barWidth, barHeight)
        local justify = align == 'SPREAD' and 'CENTER' or align
        for partIndex = 1, partTotal do
            local fontString = bar.partStrings[partIndex]
            fontString:ClearAllPoints()
            fontString:SetPoint('TOPLEFT', frame, 'TOPLEFT', layout.lineLeft, -layout.lineTop[partIndex])
            fontString:SetSize(layout.lineWidth, lineHeight)
            fontString:SetJustifyH(justify)
            fontString:SetJustifyV('MIDDLE')
            fontString:Show()
            local entry = partEntries[partIndex]
            if entry.interactive then
                local hit = GetHit(bar, entry)
                hit:ClearAllPoints()
                hit:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, -layout.lineTop[partIndex])
                hit:SetSize(barWidth, lineHeight)
                hit:Show()
            end
        end
    else
        if not fixedWidth then
            local cacheKey = table.concat({ config.fontSize, config.spacing, fontGeneration, partTotal }, '\1')
            if bar._cellKey ~= cacheKey then
                bar._cellKey = cacheKey
                bar._cellWidths = {}
            end
            local cellWidths = bar._cellWidths
            for partIndex = 1, partTotal do
                if textWidths[partIndex] > (cellWidths[partIndex] or 0) then cellWidths[partIndex] = textWidths[partIndex] end
                textWidths[partIndex] = cellWidths[partIndex]
            end
        end
        local spread = (tonumber(config.spread) or 0) / 100
        local barWidth = Datatext.LayoutRow(textWidths, partTotal, spacing, Pixel.Scale(LAYOUT.rowInset), fixedWidth, align, spread, layout)
        SetBarSize(bar, barWidth, fixedHeight or Pixel.Scale(LAYOUT.rowHeight))
        for partIndex = 1, partTotal do
            local fontString = bar.partStrings[partIndex]
            fontString:ClearAllPoints()
            if align == 'SPREAD' then
                fontString:SetPoint('CENTER', frame, 'LEFT', layout.hitLeft[partIndex] + layout.hitWidth[partIndex] / 2, 0)
            else
                fontString:SetPoint('LEFT', frame, 'LEFT', layout.textLeft[partIndex], 0)
            end
            fontString:SetWidth(0)
            fontString:SetHeight(0)
            fontString:SetJustifyH('CENTER')
            fontString:SetJustifyV('MIDDLE')
            fontString:Show()
            local entry = partEntries[partIndex]
            if entry.interactive then
                local hit = GetHit(bar, entry)
                hit:ClearAllPoints()
                hit:SetPoint('TOPLEFT', frame, 'TOPLEFT', layout.hitLeft[partIndex], 0)
                hit:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', layout.hitLeft[partIndex], 0)
                hit:SetWidth(layout.hitWidth[partIndex])
                hit:Show()
            end
        end
    end
    HidePartStrings(bar, partTotal + 1)
end

local function RenderBar(bar)
    if not bar then return end
    local config = bar.getConfig()
    if not config or not config.enabled or IsPanel(config) then return end
    if not bar.frame:IsShown() then
        bar._pendingRender = true
        return
    end
    bar._pendingRender = nil
    local hitSignature = BuildText(config)

    local signature = table.concat({
        config.orientation or 'HORIZONTAL', config.align or 'LEFT', config.width or 0, config.height or 0,
        config.fontSize, config.spacing, tostring(config.spread or 0), fontGeneration, partCount, hitSignature,
        bar.anchoredWidth and bar.frame:GetWidth() or 0,
    }, '\1')
    for partIndex = 1, partCount do
        signature = signature .. '\2' .. (parts[partIndex]:gsub('%d', '8'))
    end
    if bar._renderSig == signature then
        for partIndex = 1, partCount do
            local fontString = bar.partStrings and bar.partStrings[partIndex]
            if fontString and fontString._lastText ~= parts[partIndex] then
                fontString._lastText = parts[partIndex]
                fontString:SetText(parts[partIndex])
            end
        end
        return
    end
    bar._renderSig = signature
    HideHits(bar)
    RenderCells(bar, config)
end

local function RenderAll()
    for _, bar in pairs(bars) do RenderBar(bar) end
    if minimapBar then RenderBar(minimapBar) end
end

local DispatchRender = BUI.Dispatcher.New(RenderAll, 'Datatext.Render')

function Datatext.Refresh()
    if Datatext._initialized then DispatchRender() end
end

local function SetEntryActive(entry, active)
    if entry.active == active then return end
    entry.active = active
    if entry.events then
        if active then
            for eventIndex = 1, #entry.events do
                BUI.Events:Register(entry.events[eventIndex], entry.key, entry.OnEvent)
            end
        else
            BUI.Events:UnregisterAll(entry.key)
        end
    end
    if entry.OnUpdate then
        if not entry._scheduled then
            BUI.Scheduler.RegisterUpdate(entry.key, entry.OnUpdate, entry.interval or 1, active)
            entry._scheduled = true
        else
            BUI.Scheduler.SetUpdateEnabled(entry.key, active)
        end
    end
    if active then
        if entry.OnActivate then entry.OnActivate() end
    elseif entry.OnDeactivate then
        entry.OnDeactivate()
    end
end

local function MainOnDragStart(self)
    BeginBarDrag(self.bar)
    self.justDragged = true
end

local function MainOnDragStop(self)
    EndBarDrag(self.bar)
end

local function MainOnMouseUp(self, mouseButton)
    if self.justDragged then
        self.justDragged = false
        return
    end
    if mouseButton == 'LeftButton' then
        if not IsPanel(self.bar.getConfig()) and not InCombatLockdown() then
            ToggleCharacter('PaperDollFrame')
        end
    elseif mouseButton == 'RightButton' then
        LockBar(self.bar)
    end
end

local function MainOnShow(self)
    if self.bar._pendingRender then RenderBar(self.bar) end
end

local EDGE_POINTS = {
    { 'TOPLEFT', 'TOPRIGHT', true },
    { 'BOTTOMLEFT', 'BOTTOMRIGHT', true },
    { 'TOPLEFT', 'BOTTOMLEFT', false },
    { 'TOPRIGHT', 'BOTTOMRIGHT', false },
}

local function CreateBorderEdges(frame)
    frame.border = {}
    for edgeIndex = 1, 4 do
        local edge = EDGE_POINTS[edgeIndex]
        local texture = frame:CreateTexture(nil, 'BORDER')
        texture:SetPoint(edge[1], frame, edge[1], 0, 0)
        texture:SetPoint(edge[2], frame, edge[2], 0, 0)
        if edge[3] then texture:SetHeight(Pixel.Scale(1)) else texture:SetWidth(Pixel.Scale(1)) end
        texture:Hide()
        frame.border[edgeIndex] = texture
    end
end

local function ApplyBorder(frame, config)
    local borderColor = config.borderColor
    for edgeIndex = 1, 4 do
        local texture = frame.border[edgeIndex]
        if config.border then
            BUI.Tools.SetColorTex(texture, borderColor.r, borderColor.g, borderColor.b, borderColor.a)
            texture:Show()
        else
            texture:Hide()
        end
    end
end

local function CreateMainBarObject(frameName, configProvider)
    local frame = CreateFrame('Frame', frameName, UIParent)
    frame:SetSize(Pixel.Scale(200), Pixel.Scale(LAYOUT.rowHeight))
    frame:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')

    frame.bg = frame:CreateTexture(nil, 'BACKGROUND')
    frame.bg:SetAllPoints()
    BUI.Tools.SetColorTex(frame.bg, 0, 0, 0, 0.5)
    frame.bg:Hide()

    CreateBorderEdges(frame)

    frame.hint = frame:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(frame.hint, 10)
    frame.hint:SetPoint('BOTTOM', frame, 'TOP', 0, Pixel.Scale(5))
    frame.hint:SetText('Drag to Reposition | Right-Click to Lock')
    frame.hint:Hide()

    local bar = { getConfig = configProvider, frame = frame, hits = {} }
    frame.bar = bar

    SetScript(frame, 'OnMouseUp', MainOnMouseUp)
    SetScript(frame, 'OnShow', MainOnShow)
    return bar
end

local function EnsureBarObject(barIndex)
    if bars[barIndex] then return bars[barIndex] end
    local name = (barIndex == 1) and 'BUI_Datatext' or ('BUI_Datatext' .. barIndex)
    local bar = CreateMainBarObject(name, function() return GetBarConfig(barIndex) end)
    bar.index = barIndex
    bars[barIndex] = bar
    return bar
end

local function HideBarObject(bar)
    if not bar then return end
    bar.frame:Hide()
    HideHits(bar)
end

local function ApplyMainBar(bar)
    local config = bar.getConfig()
    local frame = bar.frame

    if not config or not config.enabled or not ModuleEnabled() then
        HideBarObject(bar)
        return
    end

    frame:Show()
    frame:SetFrameStrata(config.strata)
    frame:SetFrameLevel(config.frameLevel)
    bar.dragEnabled = not config.lock
    for _, hit in pairs(bar.hits) do
        hit:SetFrameStrata(frame:GetFrameStrata())
        hit:SetFrameLevel(frame:GetFrameLevel() + 10)
        SetHitDrag(hit, bar.dragEnabled)
    end
    bar._cellWidths = nil
    bar._cellKey = nil

    frame:ClearAllPoints()
    local minimapEnabled = BUI.GetDB().interface.minimapEnabled ~= false

    local mirrorX, mirrorY, mirrorWidth, mirrorHeight
    if IsPanel(config) and config.mirrorChat then mirrorX, mirrorY, mirrorWidth, mirrorHeight = MirroredChatRect() end

    if mirrorX then
        frame:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', mirrorX, mirrorY)
    elseif config.alignMinimap and minimapEnabled then
        frame:SetPoint('TOP', _G.Minimap, 'BOTTOM', config.x, -2)
    elseif config.alignMinimap then
        frame:SetPoint('BOTTOM', UIParent, 'BOTTOM', config.x, config.offsetBottom)
    else
        frame:SetPoint(config.point, UIParent, config.relPoint, config.x, config.y)
    end

    local bgAlpha = config.bgAlpha
    local backgroundColor = config.bgColor
    if config.lock then
        SetScript(frame, 'OnDragStart', nil)
        SetScript(frame, 'OnDragStop', nil)
        BUI.Tools.SetColorTex(frame.bg, backgroundColor.r, backgroundColor.g, backgroundColor.b, bgAlpha)
        frame.bg:SetShown(bgAlpha > 0)
        frame.hint:Hide()
    else
        SetScript(frame, 'OnDragStart', MainOnDragStart)
        SetScript(frame, 'OnDragStop', MainOnDragStop)
        BUI.Tools.SetColorTex(frame.bg, backgroundColor.r, backgroundColor.g, backgroundColor.b, math.max(bgAlpha, 0.5))
        frame.bg:Show()
        frame.hint:Show()
    end

    ApplyBorder(frame, config)

    if IsPanel(config) then
        HidePartStrings(bar, 1)
        HideHits(bar)
        local panelWidth = mirrorWidth or (config.width > 0 and config.width or 200)
        local panelHeight = mirrorHeight or (config.height > 0 and config.height or 100)
        frame:SetSize(Pixel.Scale(panelWidth), Pixel.Scale(panelHeight))

        frame:EnableMouse(not config.lock)

        local title = frame.panelTitle
        if config.title and config.title ~= '' then
            if not title then
                title = frame:CreateFontString(nil, 'OVERLAY')
                frame.panelTitle = title
            end
            Pixel.ApplyFont(title, config.titleSize, BUI.GetModuleFont(config))
            title:SetText(config.title)
            local titleColor = config.titleColor
            title:SetTextColor(titleColor.r, titleColor.g, titleColor.b)
            local anchor = config.titleAnchor
            title:ClearAllPoints()
            title:SetPoint(anchor, frame, anchor, Pixel.Scale(config.titleX), Pixel.Scale(config.titleY))
            title:Show()
        elseif title then
            title:Hide()
        end
    else
        frame:EnableMouse(not config.lock)
        if frame.panelTitle then frame.panelTitle:Hide() end
    end
end

local MINIMAP_ANCHORS = {
    BOTTOM = { selfPoint = 'TOP',    minimapPoint = 'BOTTOM', fullWidth = true,  offsetX =  0, offsetY = -1 },
    TOP    = { selfPoint = 'BOTTOM', minimapPoint = 'TOP',    fullWidth = true,  offsetX =  0, offsetY =  1 },
    LEFT   = { selfPoint = 'RIGHT',  minimapPoint = 'LEFT',   fullWidth = false, offsetX = -1, offsetY =  0 },
    RIGHT  = { selfPoint = 'LEFT',   minimapPoint = 'RIGHT',  fullWidth = false, offsetX =  1, offsetY =  0 },
    INSIDE_BOTTOM = { selfPoint = 'BOTTOM', minimapPoint = 'BOTTOM', fullWidth = true, offsetX = 0, offsetY =  1 },
    INSIDE_TOP    = { selfPoint = 'TOP',    minimapPoint = 'TOP',    fullWidth = true, offsetX = 0, offsetY = -1 },
}

local function BuildMinimapBar()
    if minimapBar then return end

    local frame = CreateFrame('Frame', 'BUI_DatatextMinimap', _G.Minimap)
    frame:SetFrameStrata('LOW')
    frame:SetFrameLevel(_G.Minimap:GetFrameLevel() + 6)
    frame:SetSize(_G.Minimap:GetWidth(), Pixel.Scale(16))

    frame.bg = frame:CreateTexture(nil, 'BACKGROUND')
    frame.bg:SetAllPoints()
    BUI.Tools.SetColorTex(frame.bg, 0, 0, 0, 0.5)

    CreateBorderEdges(frame)

    minimapBar = { getConfig = GetMinimapConfig, frame = frame, hits = {}, anchoredHeight = true }
    frame.bar = minimapBar
    SetScript(frame, 'OnShow', MainOnShow)
end

local function ApplyMinimapBar()
    local config = GetMinimapConfig()
    if type(config.spread) == 'boolean' then config.spread = config.spread and 100 or 0 end
    if not config.spacingPx then
        config.spacing = (tonumber(config.spacing) or 1) * 3
        config.spacingPx = true
    end
    if not config.enabled then
        if minimapBar then HideBarObject(minimapBar) end
        return
    end

    if not minimapBar then BuildMinimapBar() end
    local frame = minimapBar.frame
    minimapBar._cellWidths = nil
    minimapBar._cellKey = nil

    local anchor = MINIMAP_ANCHORS[config.anchor] or MINIMAP_ANCHORS.BOTTOM
    minimapBar.anchoredWidth = anchor.fullWidth
    frame:SetHeight(Pixel.Scale(config.height))
    local gap = Pixel.Scale(config.gap)
    local minimapRef = _G.Minimap
    local backdrop = _G.BUI_MinimapBackdrop
    if backdrop and backdrop:IsShown() then minimapRef = backdrop end
    frame:ClearAllPoints()
    if anchor.fullWidth then
        frame:SetPoint(anchor.selfPoint .. 'LEFT',  minimapRef, anchor.minimapPoint .. 'LEFT',  0, anchor.offsetY * gap)
        frame:SetPoint(anchor.selfPoint .. 'RIGHT', minimapRef, anchor.minimapPoint .. 'RIGHT', 0, anchor.offsetY * gap)
    elseif config.anchor == 'LEFT' then
        frame:SetPoint('TOPRIGHT',    minimapRef, 'TOPLEFT',    -gap, 0)
        frame:SetPoint('BOTTOMRIGHT', minimapRef, 'BOTTOMLEFT', -gap, 0)
    else
        frame:SetPoint('TOPLEFT',    minimapRef, 'TOPRIGHT',    gap, 0)
        frame:SetPoint('BOTTOMLEFT', minimapRef, 'BOTTOMRIGHT', gap, 0)
    end

    local backgroundColor = config.bgColor
    BUI.Tools.SetColorTex(frame.bg, backgroundColor.r, backgroundColor.g, backgroundColor.b, config.bgAlpha)
    frame.bg:Show()

    ApplyBorder(frame, config)

    frame:Show()
end

function Datatext.Apply()
    if not Datatext._initialized then return end
    fontGeneration = fontGeneration + 1

    local list = GetBars()
    local minimapConfig = GetMinimapConfig()
    local anyEnabled = minimapConfig.enabled
    if ModuleEnabled() then
        for barIndex = 1, #list do
            if list[barIndex].enabled and not IsPanel(list[barIndex]) then anyEnabled = true end
        end
    end

    local registryList = Datatext.registryList
    for listIndex = 1, #registryList do
        local entry = registryList[listIndex]
        SetEntryActive(entry, (anyEnabled and Datatext.AnyShows(entry.show)) and true or false)
    end

    for barIndex = 1, #list do
        if list[barIndex].enabled then
            ApplyMainBar(EnsureBarObject(barIndex))
        elseif bars[barIndex] then
            ApplyMainBar(bars[barIndex])
        end
    end
    for barIndex, bar in pairs(bars) do
        if barIndex > #list then HideBarObject(bar) end
    end
    ApplyMinimapBar()

    for _, bar in pairs(bars) do bar._renderSig = nil end
    if minimapBar then minimapBar._renderSig = nil end
    RenderAll()
end

function Datatext.SetLockToggle(toggle, index)
    Datatext._lockToggle = toggle
    Datatext._lockToggleIndex = index or 1
end
