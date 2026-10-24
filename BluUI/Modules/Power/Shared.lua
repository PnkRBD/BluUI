local _, BUI = ...

BUI.Power.Shared = {}
local Shared = BUI.Power.Shared
local Pixel = BUI.Pixel

function Shared.BuildLowPowerCurve(curve, db, baseRed, baseGreen, baseBlue)
    curve = curve or C_CurveUtil.CreateColorCurve()
    curve:ClearPoints()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0.0, CreateColor(db.lowPowerColorR, db.lowPowerColorG, db.lowPowerColorB, 1))
    curve:AddPoint(db.lowPowerThreshold / 100, CreateColor(db.medPowerColorR, db.medPowerColorG, db.medPowerColorB, 1))
    curve:AddPoint(db.highPowerThreshold / 100, CreateColor(baseRed, baseGreen, baseBlue, 1))
    return curve
end

function Shared.StyleTicks(bar, db, fallbackWidth, fallbackHeight, edge)
    if not bar._tickMarks then bar._tickMarks = {} end
    local ticks = db.tickMarks
    local color = db.tickMarkColor
    local width = Pixel.Scale(db.tickMarkWidth)
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
        tick:SetColorTexture(color[1], color[2], color[3], color[4])
        tick:SetSize(width, barHeight)
        tick:ClearAllPoints()
        local offset = Pixel.Scale(barWidth * (percent / 100))
        tick:SetPoint("TOP", bar, "TOPLEFT", offset, 0)
        tick:SetPoint("BOTTOM", bar, "BOTTOMLEFT", offset, 0)
        tick:Show()
    end
    for tickIndex = #ticks + 1, #bar._tickMarks do bar._tickMarks[tickIndex]:Hide() end
end

function Shared.InsetBar(container, bar, edge)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", container, "TOPLEFT", edge, -edge)
    bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -edge, edge)
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
    return BUI.Anchor.ShouldRefreshOnAnchorChange(db)
end

function Shared.DeferRefresh(getFrame, getDB, reposition)
    C_Timer.After(0.1, function()
        if getFrame() and getDB().enabled then reposition() end
    end)
end
