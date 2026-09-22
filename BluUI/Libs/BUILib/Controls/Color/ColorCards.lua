local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Widget = BUILib.Widget

local ROW_HEIGHT = 30

function Controls.ColorGrid(parent, colors, options)
    options = options or {}
    colors = colors or {}
    local width = options.width or 360
    local cellWidth = options.cellWidth or 180
    local columns = options.columns or math.max(1, math.floor(width / cellWidth))
    local onChange = options.onChange
    local columnWidth = width / columns
    local rows = math.max(1, math.ceil(#colors / columns))

    local parentFrame = Widget.Unwrap(parent)
    local container = CreateFrame("Frame", nil, parentFrame)
    container:SetWidth(width)
    container:SetHeight(rows * ROW_HEIGHT)

    for entryIndex, entry in ipairs(colors) do
        local columnIndex = (entryIndex - 1) % columns
        local rowIndex = math.floor((entryIndex - 1) / columns)
        local cellX = columnIndex * columnWidth
        local cellY = rowIndex * ROW_HEIGHT

        local highlight = container:CreateTexture(nil, "BACKGROUND")
        highlight:SetColorTexture(1, 1, 1, 0.05)
        highlight:SetPoint("TOPLEFT", cellX, -(cellY + 1))
        highlight:SetSize(columnWidth - 6, ROW_HEIGHT - 4)
        highlight:Hide()

        local red, green, blue, alpha
        if entry.get then red, green, blue, alpha = entry.get() end
        local swatch = Controls.ColorSwatch(container, { r = red, g = green, b = blue, a = alpha, callback = function(newRed, newGreen, newBlue, newAlpha, cancelled, phase)
            if not cancelled and entry.set then entry.set(newRed, newGreen, newBlue, newAlpha, cancelled, phase) end
            if onChange then onChange(entry, newRed, newGreen, newBlue, newAlpha) end
        end, label = entry.label, tooltip = entry.tooltip, width = columnWidth - 14 })
        local RESET_SIZE = 18
        local resetGap = entry.reset and (RESET_SIZE + 6) or 0
        local swatchX = cellX + 4 + resetGap

        local swatchFrame = Widget.Unwrap(swatch)
        swatchFrame:ClearAllPoints()
        swatchFrame:SetPoint("TOPLEFT", swatchX, -(cellY + (ROW_HEIGHT - 18) / 2))
        entry._swatch = swatchFrame

        local swatchButton = swatchFrame.swatch
        if swatchButton then
            swatchButton:HookScript("OnEnter", function() highlight:Show() end)
            swatchButton:HookScript("OnLeave", function() highlight:Hide() end)
        end

        if entry.reset then
            local resetButton = Controls.Icon(container, {
                size = RESET_SIZE,
                texture = BUILib.GetLibMedia('reset'),
                tooltip = 'Reset to default',
                onClick = function()
                    entry.reset()
                    if entry._swatch and entry._swatch.SetColor and entry.get then entry._swatch:SetColor(entry.get()) end
                    if onChange then onChange(entry, entry.get and entry.get()) end
                end,
            })
            local resetFrame = Widget.Unwrap(resetButton)
            resetFrame:ClearAllPoints()
            resetFrame:SetPoint("TOPLEFT", cellX + 4, -(cellY + (ROW_HEIGHT - RESET_SIZE) / 2))
            resetFrame:SetFrameLevel(container:GetFrameLevel() + 6)
            resetFrame:HookScript("OnEnter", function() highlight:Show() end)
            resetFrame:HookScript("OnLeave", function() highlight:Hide() end)
        end

        if swatchButton then
            local clicker = CreateFrame("Button", nil, container)
            clicker:SetPoint("TOPLEFT", swatchX - 2, -(cellY + 1))
            clicker:SetSize(math.max(1, (cellX + columnWidth - 6) - (swatchX - 2)), ROW_HEIGHT - 4)
            clicker:SetFrameLevel(container:GetFrameLevel() + 5)
            clicker:RegisterForClicks("AnyUp")
            clicker:SetScript("OnEnter", function() highlight:Show() end)
            clicker:SetScript("OnLeave", function() highlight:Hide() end)
            clicker:SetScript("OnClick", function() swatchButton:Click() end)
        end
    end

    container.layoutHeight = container:GetHeight()

    function container:RefreshColors()
        for _, entry in ipairs(colors) do
            if entry._swatch and entry.get then
                entry._swatch:SetColor(entry.get())
            end
        end
    end

    return Widget.Wrap(container)
end
