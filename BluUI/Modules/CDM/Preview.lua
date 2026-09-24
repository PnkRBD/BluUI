local _, BUI = ...

local floor, max = math.floor, math.max

local CreateFrame = CreateFrame
local UIParent = UIParent

local CDM = BUI.CDM
local Pixel = BUI.Pixel

local function CreateIcon(parent, index, iconID)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(Pixel.Scale(50), Pixel.Scale(50))

    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints()
    icon.Icon:SetTexture(iconID)

    local textOverlay = CreateFrame("Frame", nil, icon)
    textOverlay:SetAllPoints()
    textOverlay:SetFrameLevel(icon:GetFrameLevel() + 20)
    icon.textOverlay = textOverlay

    icon.Count = textOverlay:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(icon.Count, 14, BUI.GetGlobalFont())
    icon.Count:SetText(index > 1 and tostring(index) or "")

    icon.cdText = textOverlay:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(icon.cdText, 12, BUI.GetGlobalFont())
    icon.cdText:SetText(index == 1 and "" or tostring(index + 3))

    return icon
end

local function UpdateIcon(icon, settings)
    local iconWidth = settings.iconWidth
    local iconHeight = settings.iconHeight
    icon:SetSize(Pixel.Scale(iconWidth), Pixel.Scale(iconHeight))

    local scaledEdge = Pixel.Scale(settings.borderSize)
    icon.Icon:ClearAllPoints()
    icon.Icon:SetPoint("TOPLEFT", scaledEdge, -scaledEdge)
    icon.Icon:SetPoint("BOTTOMRIGHT", -scaledEdge, scaledEdge)
    icon.Icon:SetTexCoord(CDM.GetAspectTexCoords(settings.zoom, iconWidth, iconHeight, settings.keepAspectRatio))

    if settings.borderSize > 0 then
        local borderColor = settings.borderColor
        Pixel.ApplyBorder(icon, settings.borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        Pixel.ShowBorder(icon)
    else
        Pixel.HideBorder(icon)
    end

    icon.Count:ClearAllPoints()
    icon.Count:SetPoint(settings.textPosition, icon.Icon, settings.textPosition, settings.textOffsetX, settings.textOffsetY)
    Pixel.ApplyFont(icon.Count, settings.textSize, BUI.GetGlobalFont())
    local textColor = settings.textColor
    icon.Count:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])

    icon.cdText:ClearAllPoints()
    icon.cdText:SetPoint(settings.cooldownTextPosition, icon.Icon, settings.cooldownTextPosition, settings.cooldownTextOffsetX, settings.cooldownTextOffsetY)
    Pixel.ApplyFont(icon.cdText, settings.cooldownTextSize, BUI.GetGlobalFont())
    local cdTextColor = settings.cooldownTextColor
    icon.cdText:SetTextColor(cdTextColor[1], cdTextColor[2], cdTextColor[3], cdTextColor[4])
end

local function LayoutIcons(icons, container, settings)
    local count = #icons

    local iconWidth = Pixel.Scale(settings.iconWidth)
    local iconHeight = Pixel.Scale(settings.iconHeight)
    local gap = Pixel.Scale(settings.spacing)
    local perRow = settings.iconsPerRow > 0 and settings.iconsPerRow or count
    local growUp = settings.rowGrowth == "Up"

    local rowCount, maxColumns = CDM.RowMetrics(count, perRow)

    local iconIndex = 1
    local remaining = count
    for row = 1, rowCount do
        local rowIconCount = CDM.NextRowSize(row, remaining, perRow)
        remaining = remaining - rowIconCount
        local rowWidth = rowIconCount * iconWidth + (rowIconCount - 1) * gap
        for col = 0, rowIconCount - 1 do
            if iconIndex > count then break end
            local icon = icons[iconIndex]
            UpdateIcon(icon, settings)
            local x = floor(-rowWidth / 2 + iconWidth / 2 + col * (iconWidth + gap))
            local y = floor((growUp and 1 or -1) * (row - 1) * (iconHeight + gap))
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", container, "CENTER", x, y)
            iconIndex = iconIndex + 1
        end
    end

    return maxColumns * iconWidth + (maxColumns - 1) * gap, rowCount * iconHeight + (rowCount - 1) * gap
end

function CDM.ShowBuffsPreview(buffsSettings)
    local state = CDM.state
    if state.buffsPreview then
        state.buffsPreview:Show()
        state.buffsPreview.Update()
        return
    end

    local previewFrame = CreateFrame("Frame", "BUI_CDM_BuffsPreview", UIParent)
    previewFrame:SetFrameStrata("TOOLTIP")
    previewFrame:SetMovable(true)
    previewFrame:EnableMouse(true)
    previewFrame:RegisterForDrag("LeftButton")
    previewFrame:SetClampedToScreen(true)

    previewFrame:SetScript("OnDragStart", function(self)
        if not self._anchorLocked then self:StartMoving() end
    end)
    previewFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if self._anchorLocked then return end
        local centerX, centerY = self:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        local x, y = centerX - parentX, centerY - parentY
        local db = BUI.GetDB().cdm.buffs
        if not db.centerHorizontally then
            db.positionX = x
        end
        db.positionY = y
        CDM.RefreshAll()
    end)

    previewFrame:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "RightButton" then
            self:Hide()
            if state.buffsPreviewButton then state.buffsPreviewButton:SetText("Show Preview") end
        end
    end)

    local title = previewFrame:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(title, 11, BUI.GetGlobalFont())
    title:SetText("Drag to Reposition | Right-Click to Lock")
    title:SetPoint("BOTTOM", previewFrame, "TOP", 0, Pixel.Scale(5))

    previewFrame.container = CreateFrame("Frame", nil, previewFrame)
    previewFrame.container:SetPoint("CENTER")

    previewFrame.icons = {}
    for iconIndex = 1, 7 do
        previewFrame.icons[iconIndex] = CreateIcon(previewFrame.container, iconIndex, CDM.PreviewIcons[((iconIndex - 1) % #CDM.PreviewIcons) + 1])
        previewFrame.icons[iconIndex]:Show()
    end

    previewFrame.Update = function()
        local currentSettings = BUI.GetDB().cdm.buffs
        local width, height = LayoutIcons(previewFrame.icons, previewFrame.container, currentSettings)
        previewFrame.container:SetSize(width, height)
        previewFrame:SetSize(Pixel.Scale(max(width + 20, 200)), Pixel.Scale(height + 40))
        previewFrame:ClearAllPoints()
        local buffsAnchor = CDM.Anchors.buffs
        local anchorTarget = BUI.ResolveAnchorFrame(currentSettings.anchorFrame, currentSettings.anchorPoint)
        previewFrame._anchorLocked = (buffsAnchor and anchorTarget) and true or false
        if previewFrame._anchorLocked then
            previewFrame:SetPoint("CENTER", buffsAnchor, "CENTER", 0, 0)
            title:SetText("Anchored to Frame | Right-Click to Lock")
        else
            previewFrame:SetPoint("CENTER", UIParent, "CENTER", currentSettings.centerHorizontally and 0 or currentSettings.positionX, currentSettings.positionY)
            title:SetText("Drag to Reposition | Right-Click to Lock")
        end
    end

    previewFrame.Update()
    state.buffsPreview = previewFrame
end

function CDM.HideBuffsPreview()
    if CDM.state.buffsPreview then CDM.state.buffsPreview:Hide() end
end

function CDM.RefreshBuffsPreview()
    local previewFrame = CDM.state.buffsPreview
    if previewFrame and previewFrame:IsShown() and previewFrame.Update then previewFrame.Update() end
end
