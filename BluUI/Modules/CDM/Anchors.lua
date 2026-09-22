local _, BUI = ...

local _G = _G

local CreateFrame = CreateFrame
local UIParent = UIParent

local CDM = BUI.CDM
local Pixel = BUI.Pixel
local LibEMO = LibStub("LibEditModeOverride-1.0")
CDM.Anchors = {}
local Anchors = CDM.Anchors

local ANCHOR_NAMES = {
    essential = "BUI_EssentialCooldownViewer",
    utility = "BUI_UtilityCooldownViewer",
    buffs = "BUI_BuffCooldownViewer",
}

local function PlaceContainerTopLeft(frame, x, y)
    local width = frame._layoutW or frame:GetWidth() or 0
    local height = frame._layoutH or frame:GetHeight() or 0
    frame:ClearAllPoints()
    if width <= 0 or height <= 0 then
        frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
        frame._snappedCenterX = x
        frame._snappedCenterY = y
        return
    end
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    local halfWidth, halfHeight = width / 2, height / 2
    local leftOffset = Pixel.Snap(parentCenterX + x - halfWidth) - parentCenterX
    local topOffset = Pixel.Snap(parentCenterY + y + halfHeight) - parentCenterY
    frame:SetPoint("TOPLEFT", UIParent, "CENTER", leftOffset, topOffset)

    frame._snappedCenterX = leftOffset + halfWidth
    frame._snappedCenterY = topOffset - halfHeight
end

function CDM.CreateAnchor(key)
    local frameName = ANCHOR_NAMES[key]
    if not frameName then return end

    local db = BUI.GetDB()
    local settings = db.cdm[key]
    if not settings then return end

    local frame = CreateFrame("Frame", frameName, UIParent)

    local iconWidth = settings.iconWidth
    local iconHeight = settings.iconHeight
    local spacing = settings.spacing
    local columns = settings.iconsPerRow
    if columns <= 0 then columns = 8 end

    local scaledWidth = Pixel.Scale(iconWidth)
    local scaledHeight = Pixel.Scale(iconHeight)
    local scaledSpacing = Pixel.Scale(spacing)
    local width = columns * scaledWidth + (columns - 1) * scaledSpacing
    local height = scaledHeight
    frame:SetSize(width, height)
    frame._layoutW, frame._layoutH = width, height

    frame._cachedScaledW = scaledWidth
    frame._cachedScaledH = scaledHeight
    frame._cachedScaledSpacing = scaledSpacing

    local resolved
    if settings.anchorFrame and settings.anchorFrame ~= "" then
        resolved = BUI.Anchor.ApplyPosition(frame, {
            anchorFrame = settings.anchorFrame,
            anchorPoint = settings.anchorPoint,
            anchorOffsetX = settings.anchorOffsetX,
            anchorOffsetY = settings.anchorOffsetY,
        })
    end
    if not resolved then
        local x = settings.centerHorizontally and 0 or settings.positionX
        local y = settings.positionY
        PlaceContainerTopLeft(frame, x, y)
    end

    frame:SetFrameStrata("MEDIUM")
    CDM.GetFrameData(frame).key = key
    frame._topEdgeOffset = 0
    frame._bottomEdgeOffset = 0
    frame._row1CenterOffsetX = 0
    frame._topRowCenterOffsetY = 0
    Anchors[key] = frame
    return frame
end

function CDM.ApplyAnchorPosition(key)
    local anchor = Anchors[key]
    if not anchor then return end

    local db = BUI.GetDB()
    local settings = db.cdm[key]
    if not settings then return end

    if settings.anchorFrame and settings.anchorFrame ~= "" then
        local target = BUI.ResolveAnchorFrame(settings.anchorFrame, settings.anchorPoint)
        if not target and anchor._everAnchored then
            return
        end
        if target then
            BUI.Anchor.ApplyPosition(anchor, {
                anchorFrame = settings.anchorFrame,
                anchorPoint = settings.anchorPoint,
                anchorOffsetX = settings.anchorOffsetX,
                anchorOffsetY = settings.anchorOffsetY,
            })
            anchor._everAnchored = true
            return
        end
    end

    local x = settings.centerHorizontally and 0 or settings.positionX
    local y = settings.positionY

    PlaceContainerTopLeft(anchor, x, y)
end

local lastSavedX, lastSavedY = {}, {}
local ANCHOR_EPSILON = 0.5

local function StoredAnchorMatches(viewer, x, y)
    local systemInfo = viewer.systemInfo
    local anchor = systemInfo and not systemInfo.isInDefaultPosition and systemInfo.anchorInfo
    if not anchor then return false end
    return anchor.point == "CENTER" and anchor.relativeTo == "UIParent" and anchor.relativePoint == "CENTER"
        and math.abs((anchor.offsetX or 0) - x) < ANCHOR_EPSILON
        and math.abs((anchor.offsetY or 0) - (y or 0)) < ANCHOR_EPSILON
end

local function ReanchorViewer(key)
    local viewerName = CDM.VIEWERS[key]
    local viewer = viewerName and _G[viewerName]
    if not viewer then return false end

    local db = BUI.GetDB()
    local settings = db.cdm[key]
    if not settings then return false end

    local x = settings.centerHorizontally and 0 or settings.positionX
    local y = settings.positionY
    if lastSavedX[key] == x and lastSavedY[key] == y then return false end

    if not LibEMO:IsReady() then return false end
    if StoredAnchorMatches(viewer, x, y) then
        lastSavedX[key], lastSavedY[key] = x, y
        return false
    end
    LibEMO:LoadLayouts()
    if not LibEMO:CanEditActiveLayout() then return false end
    if not LibEMO:HasEditModeSettings(viewer) then return false end

    LibEMO:ReanchorFrame(viewer, "CENTER", UIParent, "CENTER", x, y)
    lastSavedX[key], lastSavedY[key] = x, y
    return true
end

function CDM.SaveToEditModeLayout(key)
    if not BUI.CanWriteEditModeLayout() then return end
    if ReanchorViewer(key) then LibEMO:SaveOnly() end
end

function CDM.ApplyAllPositions()
    local dirty = false
    local canWrite = BUI.CanWriteEditModeLayout()
    for keyIndex = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[keyIndex]
        CDM.ApplyAnchorPosition(key)
        if canWrite and ReanchorViewer(key) then dirty = true end
    end
    if dirty then LibEMO:SaveOnly() end
end

function CDM.OnCenterHorizontallyChanged(key, enabled)
    local db = BUI.GetDB()
    local settings = db.cdm[key]
    if not settings then return end

    settings.centerHorizontally = enabled

    if enabled then
        settings.positionX = 0
    end

    CDM.ApplyAnchorPosition(key)
    CDM.SaveToEditModeLayout(key)

    if key == "buffs" then
        CDM.RefreshAll(true)
        CDM.RefreshBuffsPreview()
    else
        CDM.MarkLayoutDirty(key)
    end
end

function CDM.ApplyPosition(key)
    CDM.ApplyAnchorPosition(key)
    CDM.SaveToEditModeLayout(key)
    CDM.MarkLayoutDirty(key)
    if key == "buffs" then CDM.RefreshBuffsPreview() end
end
