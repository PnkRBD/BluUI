local _, BUI = ...

BUI.Power.Shared = {}
local Shared = BUI.Power.Shared
local Pixel = BUI.Pixel

function Shared.BuildLowPowerCurve(curve, db, baseRed, baseGreen, baseBlue)
    curve = curve or C_CurveUtil.CreateColorCurve()
    curve:ClearPoints()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0.0, CreateColor(db.lowPowerColorR or 1, db.lowPowerColorG or 0.2, db.lowPowerColorB or 0.2, 1))
    curve:AddPoint((db.lowPowerThreshold or 30) / 100, CreateColor(db.medPowerColorR or 1, db.medPowerColorG or 1, db.medPowerColorB or 0.2, 1))
    curve:AddPoint((db.highPowerThreshold or 70) / 100, CreateColor(baseRed or 1, baseGreen or 1, baseBlue or 1, 1))
    return curve
end

function Shared.StyleTicks(bar, db, fallbackWidth, fallbackHeight, edge)
    if not bar._tickMarks then bar._tickMarks = {} end
    local ticks = db.tickMarks or {}
    local color = db.tickMarkColor or { 1, 1, 1, 0.6 }
    local width = Pixel.Scale(db.tickMarkWidth or 1)
    local barWidth = bar:GetWidth()
    if barWidth <= 0 then barWidth = fallbackWidth - (edge * 2) end
    local barHeight = bar:GetHeight()
    if barHeight <= 0 then barHeight = fallbackHeight - (edge * 2) end
    for tickIndex, percent in ipairs(ticks) do
        local tick = bar._tickMarks[tickIndex]
        if not tick then
            tick = bar:CreateTexture(nil, "OVERLAY")
            bar._tickMarks[tickIndex] = tick
        end
        tick:SetColorTexture(color[1], color[2], color[3], color[4] or 0.6)
        tick:SetSize(width, barHeight)
        tick:ClearAllPoints()
        local offset = Pixel.Scale(barWidth * (percent / 100))
        tick:SetPoint("TOP", bar, "TOPLEFT", offset, 0)
        tick:SetPoint("BOTTOM", bar, "BOTTOMLEFT", offset, 0)
        tick:Show()
    end
    for tickIndex = #ticks + 1, #bar._tickMarks do bar._tickMarks[tickIndex]:Hide() end
end

function Shared.ApplyStackFlush(container, bar, flushEdge, edge, backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha)
    local topInset, bottomInset = -edge, edge
    if flushEdge == 'BOTTOM' then bottomInset = 0
    elseif flushEdge == 'TOP' then topInset = 0 end
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", container, "TOPLEFT", edge, topInset)
    bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -edge, bottomInset)

    local cover = container._stackFlushCover
    if not flushEdge then
        if cover then cover:Hide() end
        return
    end
    if not cover then
        cover = container:CreateTexture(nil, "ARTWORK")
        container._stackFlushCover = cover
    end
    cover:SetColorTexture(backgroundRed or 0.1, backgroundGreen or 0.1, backgroundBlue or 0.1, backgroundAlpha or 1)
    cover:ClearAllPoints()
    if flushEdge == 'BOTTOM' then
        cover:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        cover:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    else
        cover:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        cover:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    end
    cover:SetHeight(edge)
    cover:Show()
end

function Shared.IsAnchoredFor(db, isText)
    local anchorFrame = db.anchorFrame
    if isText then
        local textAnchorFrame = db.textAnchorFrame
        if textAnchorFrame ~= nil then anchorFrame = textAnchorFrame end
    end
    return BUI.ResolveAnchorFrame(anchorFrame) ~= nil
end

function Shared.ShouldReanchor(frame, db)
    if not frame then return false end
    if not db.enabled then return false end
    if BUI.Power.Stack.IsEnabled() then return false end
    return BUI.Anchor.ShouldRefreshOnAnchorChange(db)
end

function Shared.DeferRefresh(getFrame, getDB, reposition)
    BUI.Prof.After('Power.Shared', 0.1, function()
        if getFrame() and getDB().enabled then reposition() end
    end)
end
