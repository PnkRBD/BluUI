local _, BUI = ...

local _G = _G
local pairs, abs, min, max = pairs, math.abs, math.min, math.max

local CreateFrame = CreateFrame
local UIParent = UIParent
local GetCursorPosition = GetCursorPosition
local IsMouseButtonDown = IsMouseButtonDown
local IsControlKeyDown = IsControlKeyDown
local InCombatLockdown = InCombatLockdown

local CDM = BUI.CDM
local Pixel = BUI.Pixel
local FrameData = CDM.FrameData
local GetFrameData = CDM.GetFrameData
CDM.Detached = {}
local Detached = CDM.Detached

local DragFrame = nil
local DragIcon = nil
local DragSpellID = nil
local DragViewerKey = nil
local DragStartX, DragStartY = 0, 0
local DragOffsetX, DragOffsetY = 0, 0

local SNAP_ENGAGE = 12
local SNAP_RELEASE = 18
local snapTargetCount = 0
local snappedOnX, snappedOnY = false, false

local POOL_SIZE = 64
local snapTargetPool = {}
for poolIndex = 1, POOL_SIZE do
    snapTargetPool[poolIndex] = { l = 0, r = 0, t = 0, b = 0, cx = 0, cy = 0 }
end

local snapHighlight

local function GetSnapHighlight()
    if snapHighlight then return snapHighlight end
    snapHighlight = CreateFrame("Frame", nil, UIParent)
    snapHighlight:SetFrameStrata("TOOLTIP")
    snapHighlight:SetFrameLevel(200)
    Pixel.ApplyBorder(snapHighlight, 2, 0.43, 0, 0.99, 0.9)
    snapHighlight:Hide()
    return snapHighlight
end

local function ShowSnapHighlight(icon, isSnapped)
    if not isSnapped then
        if snapHighlight then snapHighlight:Hide() end
        return
    end
    local highlight = GetSnapHighlight()
    local gap = Pixel.PixelSize(1)
    highlight:ClearAllPoints()
    highlight:SetPoint("TOPLEFT", icon, "TOPLEFT", -gap, gap)
    highlight:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", gap, -gap)
    highlight:Show()
end

local function HideSnapHighlight()
    if snapHighlight then snapHighlight:Hide() end
end

local function CollectSnapTarget(icon)
    if icon == DragIcon then return end
    if not icon:IsShown() or not icon:IsVisible() then return end
    local frameData = FrameData[icon]
    if frameData and frameData.hidden then return end
    local left, bottom, width, height = icon:GetRect()
    if not left then return end
    snapTargetCount = snapTargetCount + 1
    if not snapTargetPool[snapTargetCount] then
        snapTargetPool[snapTargetCount] = { l = 0, r = 0, t = 0, b = 0, cx = 0, cy = 0 }
    end
    local target = snapTargetPool[snapTargetCount]
    target.l = left; target.r = left + width; target.t = bottom + height; target.b = bottom
    target.cx = left + width * 0.5; target.cy = bottom + height * 0.5
end

local function CollectSnapTargets()
    snapTargetCount = 0

    CDM.ForAllIcons(CollectSnapTarget)

    for _, entry in pairs(BUI.C.ANCHOR_FRAMES) do
        local frame = _G[entry.tag]
        if frame and frame:IsShown() and frame:IsVisible() and frame ~= DragIcon then
            local left, bottom, width, height = frame:GetRect()
            if left and width and width > 0 then
                snapTargetCount = snapTargetCount + 1
                if not snapTargetPool[snapTargetCount] then
                    snapTargetPool[snapTargetCount] = { l = 0, r = 0, t = 0, b = 0, cx = 0, cy = 0 }
                end
                local snapTarget = snapTargetPool[snapTargetCount]
                snapTarget.l = left; snapTarget.r = left + width; snapTarget.t = bottom + height; snapTarget.b = bottom
                snapTarget.cx = left + width * 0.5; snapTarget.cy = bottom + height * 0.5
            end
        end
    end
end

local pixelGap = 0

local function CheckSnap(iconLeft, iconRight, iconTop, iconBottom, iconCenterX, iconCenterY)
    local bestDX, bestAbsDX = 0, SNAP_ENGAGE + 1
    local bestDY, bestAbsDY = 0, SNAP_ENGAGE + 1
    local deltaX, absDeltaX, deltaY, absDeltaY

    for targetIndex = 1, snapTargetCount do
        local target = snapTargetPool[targetIndex]

        deltaX = iconLeft - target.l; absDeltaX = abs(deltaX)
        if absDeltaX < bestAbsDX then bestDX, bestAbsDX = deltaX, absDeltaX end

        deltaX = iconRight - target.r; absDeltaX = abs(deltaX)
        if absDeltaX < bestAbsDX then bestDX, bestAbsDX = deltaX, absDeltaX end

        deltaX = iconLeft - target.r - pixelGap; absDeltaX = abs(deltaX)
        if absDeltaX < bestAbsDX then bestDX, bestAbsDX = deltaX, absDeltaX end

        deltaX = iconRight - target.l + pixelGap; absDeltaX = abs(deltaX)
        if absDeltaX < bestAbsDX then bestDX, bestAbsDX = deltaX, absDeltaX end

        deltaX = iconCenterX - target.cx; absDeltaX = abs(deltaX)
        if absDeltaX < bestAbsDX then bestDX, bestAbsDX = deltaX, absDeltaX end

        deltaY = iconTop - target.t; absDeltaY = abs(deltaY)
        if absDeltaY < bestAbsDY then bestDY, bestAbsDY = deltaY, absDeltaY end

        deltaY = iconBottom - target.b; absDeltaY = abs(deltaY)
        if absDeltaY < bestAbsDY then bestDY, bestAbsDY = deltaY, absDeltaY end

        deltaY = iconBottom - target.t - pixelGap; absDeltaY = abs(deltaY)
        if absDeltaY < bestAbsDY then bestDY, bestAbsDY = deltaY, absDeltaY end

        deltaY = iconTop - target.b + pixelGap; absDeltaY = abs(deltaY)
        if absDeltaY < bestAbsDY then bestDY, bestAbsDY = deltaY, absDeltaY end

        deltaY = iconCenterY - target.cy; absDeltaY = abs(deltaY)
        if absDeltaY < bestAbsDY then bestDY, bestAbsDY = deltaY, absDeltaY end
    end

    local thresholdX = snappedOnX and SNAP_RELEASE or SNAP_ENGAGE
    local thresholdY = snappedOnY and SNAP_RELEASE or SNAP_ENGAGE
    local nowSnappedX = bestAbsDX <= thresholdX
    local nowSnappedY = bestAbsDY <= thresholdY
    snappedOnX = nowSnappedX
    snappedOnY = nowSnappedY

    return
        nowSnappedX and bestDX or 0,
        nowSnappedY and bestDY or 0,
        nowSnappedX,
        nowSnappedY
end

local lastDragX, lastDragY = 0, 0

local function DragFrameOnUpdate(self)
    if not DragIcon then
        self:Hide()
        return
    end

    if not IsMouseButtonDown("LeftButton") then
        Detached.StopDrag()
        return
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale

    local parentCenterX, parentCenterY = UIParent:GetCenter()
    local rawX = BUI.Round(cursorX - parentCenterX - DragOffsetX)
    local rawY = BUI.Round(cursorY - parentCenterY - DragOffsetY)

    local width, height = DragIcon:GetSize()
    local halfWidth, halfHeight = width * 0.5, height * 0.5
    local absCenterX, absCenterY = parentCenterX + rawX, parentCenterY + rawY
    local iconLeft = absCenterX - halfWidth
    local iconRight = absCenterX + halfWidth
    local iconBottom = absCenterY - halfHeight
    local iconTop = absCenterY + halfHeight

    local x, y
    if BUI.GetDB().cdm.disableSnapping then
        x, y = rawX, rawY
        HideSnapHighlight()
    else
        local snapDX, snapDY, didSnapX, didSnapY = CheckSnap(iconLeft, iconRight, iconTop, iconBottom, absCenterX, absCenterY)
        x = rawX - BUI.Round(snapDX)
        y = rawY - BUI.Round(snapDY)
        ShowSnapHighlight(DragIcon, didSnapX or didSnapY)
    end

    if x == lastDragX and y == lastDragY then return end
    lastDragX, lastDragY = x, y

    local frameData = GetFrameData(DragIcon)
    frameData.locking = true
    DragIcon:ClearAllPoints()
    DragIcon:SetPoint("CENTER", UIParent, "CENTER", x, y)
    frameData.locking = false
end

local function GetDragFrame()
    if DragFrame then return DragFrame end
    DragFrame = CreateFrame("Frame", "BUI_CDM_DetachDragFrame", UIParent)
    DragFrame:SetFrameStrata("TOOLTIP")
    DragFrame:SetSize(Pixel.Scale(50), Pixel.Scale(50))
    DragFrame:Hide()
    DragFrame:SetScript("OnUpdate", DragFrameOnUpdate)
    return DragFrame
end

local function IsIndividualMoveEnabled()
    local db = BUI.GetDB()
    return db.cdm.allowIndividualMove
end

function Detached.StartDrag(icon, key)
    if Detached.IsDragging() then return end
    if InCombatLockdown() then return end

    local spellID = CDM.GetStableSpellID(icon)
    if not spellID then return end

    local db = BUI.GetDB()
    local settings = db.cdm[key]
    if not settings then return end

    DragIcon = icon
    DragSpellID = spellID
    DragViewerKey = key
    lastDragX, lastDragY = -99999, -99999

    pixelGap = Pixel.PixelSize(1)
    snappedOnX, snappedOnY = false, false

    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    local iconCenterX, iconCenterY = icon:GetCenter()
    DragOffsetX = cursorX - iconCenterX
    DragOffsetY = cursorY - iconCenterY

    local position = CDM.GetDetachedPosition(settings, spellID)
    if position then
        DragStartX, DragStartY = position.x, position.y
    else
        local parentCenterX, parentCenterY = UIParent:GetCenter()
        DragStartX = BUI.Round(iconCenterX - parentCenterX)
        DragStartY = BUI.Round(iconCenterY - parentCenterY)
    end

    if not CDM.IsIconDetached(settings, spellID) then
        CDM.SetDetachedIcon(settings, spellID, DragStartX, DragStartY)
    end

    local frameData = GetFrameData(icon)
    frameData.anchor = nil

    CollectSnapTargets()
    GetDragFrame():Show()
end

local function ResetDragState()
    DragIcon = nil
    DragSpellID = nil
    DragViewerKey = nil
    if DragFrame then DragFrame:Hide() end
    HideSnapHighlight()
    snapTargetCount = 0
end

function Detached.StopDrag()
    if not DragIcon or not DragSpellID or not DragViewerKey then
        ResetDragState()
        return
    end

    local iconCenterX, iconCenterY = DragIcon:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    local x = BUI.Round(iconCenterX - parentCenterX)
    local y = BUI.Round(iconCenterY - parentCenterY)

    local db = BUI.GetDB()
    local settings = db.cdm[DragViewerKey]
    if settings then
        local position = CDM.GetDetachedPosition(settings, DragSpellID)
        local width, height = position and position.w, position and position.h
        CDM.SetDetachedIcon(settings, DragSpellID, x, y, width, height)
    end

    ResetDragState()
    CDM.SetUpdatePending(true)
end

function Detached.IsDragging()
    return DragIcon ~= nil
end

local RESIZE_STEP = 2
local RESIZE_MIN  = 16
local RESIZE_MAX  = 128

local function IsIndividualResizeEnabled()
    local db = BUI.GetDB()
    return db.cdm.allowIndividualResize
end

local function ResizeDetachedIcon(icon, key, delta)
    if InCombatLockdown() then return end
    if not IsIndividualResizeEnabled() then return end

    local spellID = CDM.GetStableSpellID(icon)
    if not spellID then return end

    local db = BUI.GetDB()
    local settings = db.cdm[key]
    if not settings then return end

    local position = CDM.GetDetachedPosition(settings, spellID)
    if not position then return end

    local currentWidth = position.w or settings.iconWidth
    local currentHeight = position.h or settings.iconHeight
    local newWidth = min(max(currentWidth + delta * RESIZE_STEP, RESIZE_MIN), RESIZE_MAX)
    local newHeight = min(max(currentHeight + delta * RESIZE_STEP, RESIZE_MIN), RESIZE_MAX)
    if newWidth == currentWidth and newHeight == currentHeight then return end

    CDM.SetDetachedIcon(settings, spellID, position.x, position.y, newWidth, newHeight)

    local scaledWidth = Pixel.Scale(newWidth)
    local scaledHeight = Pixel.Scale(newHeight)
    local frameData = GetFrameData(icon)
    frameData.sizeW = scaledWidth
    frameData.sizeH = scaledHeight
    frameData.locking = true
    icon:SetSize(scaledWidth, scaledHeight)
    frameData.locking = false

    CDM.SkinIcon(icon, settings, key)
end

local function EnsureOverlay(icon, key)
    local iconFrameData = FrameData[icon]
    if iconFrameData and iconFrameData.detachOverlay then return iconFrameData.detachOverlay end

    local overlay = CreateFrame("Button", nil, icon)
    overlay:SetAllPoints(icon)
    overlay:SetFrameLevel(icon:GetFrameLevel() + 10)
    overlay:RegisterForClicks("AnyDown")

    overlay:SetScript("OnMouseDown", function(self, button)
        if not IsIndividualMoveEnabled() then return end
        if InCombatLockdown() then return end

        if button == "LeftButton" and IsControlKeyDown() then
            Detached.StartDrag(icon, key)
        elseif button == "RightButton" and IsControlKeyDown() then
            local spellID = CDM.GetStableSpellID(icon)
            local db = BUI.GetDB()
            local settings = db.cdm[key]
            if spellID and settings and CDM.IsIconDetached(settings, spellID) then
                CDM.ClearDetachedIcon(settings, spellID)
                CDM.SetUpdatePending(true)
            end
        end
    end)

    overlay:EnableMouseWheel(true)
    overlay:SetScript("OnMouseWheel", function(_, delta)
        if not IsControlKeyDown() then return end
        ResizeDetachedIcon(icon, key, delta)
    end)

    overlay:EnableMouse(true)
    if not iconFrameData then iconFrameData = GetFrameData(icon) end
    iconFrameData.detachOverlay = overlay
    return overlay
end

local function DisableOverlay(icon)
    local iconFrameData = FrameData[icon]
    if iconFrameData and iconFrameData.detachOverlay then
        iconFrameData.detachOverlay:EnableMouse(false)
    end
end

local overlayCtrlHeld = false
local overlaysActive = false

local function UpdateOverlayIcon(icon, key)
    local iconFrameData = FrameData[icon]
    if iconFrameData and iconFrameData.detachHooked and icon:IsShown() then
        if overlayCtrlHeld and key then
            EnsureOverlay(icon, key):EnableMouse(true)
        elseif iconFrameData.detachOverlay then
            iconFrameData.detachOverlay:EnableMouse(false)
        end
    end
end

local function UpdateOverlayState()
    if not IsIndividualMoveEnabled() or InCombatLockdown() then
        if overlaysActive then
            overlaysActive = false
            CDM.ForAllIcons(DisableOverlay)
        end
        return
    end

    overlayCtrlHeld = IsControlKeyDown()
    if not overlayCtrlHeld and not overlaysActive then return end
    overlaysActive = overlayCtrlHeld
    CDM.ForAllIcons(UpdateOverlayIcon)
end

local modifierWatcherActive = false

local function OnCombatEvent()
    if not CDM.state.initComplete then return end

    if InCombatLockdown() and Detached.IsDragging() then
        Detached.StopDrag()
    end
    UpdateOverlayState()
end

local function OnModifierState(event, key)
    if not CDM.state.initComplete then return end
    if key == "LCTRL" or key == "RCTRL" then
        UpdateOverlayState()
    end
end

BUI.Events:Register("PLAYER_REGEN_DISABLED", "CDM.Detached.Combat", OnCombatEvent)
BUI.Events:Register("PLAYER_REGEN_ENABLED", "CDM.Detached.Combat2", OnCombatEvent)

function Detached.UpdateModifierWatcher()
    local shouldWatch = IsIndividualMoveEnabled()
    if shouldWatch and not modifierWatcherActive then
        modifierWatcherActive = true
        BUI.Events:Register("MODIFIER_STATE_CHANGED", "CDM.Detached.Modifier", OnModifierState)
    elseif not shouldWatch and modifierWatcherActive then
        modifierWatcherActive = false
        BUI.Events:Unregister("MODIFIER_STATE_CHANGED", "CDM.Detached.Modifier")
        CDM.ForAllIcons(DisableOverlay)
    end
end

function Detached.HookIcon(icon, key)
    local iconFrameData = FrameData[icon]
    if iconFrameData and iconFrameData.detachHooked then return end
    if not iconFrameData then iconFrameData = GetFrameData(icon) end
    iconFrameData.detachHooked = true
end

function Detached.PlaceIcon(icon, key, iconWidth, iconHeight, settings)
    if icon == DragIcon then return true end

    local spellID = CDM.GetStableSpellID(icon)
    if not spellID then return false end

    local position = CDM.GetDetachedPosition(settings, spellID)
    if not position then return false end

    Detached.HookIcon(icon, key)
    CDM.HookIconFrame(icon, key)

    local detachedWidth = position.w or iconWidth
    local detachedHeight = position.h or iconHeight
    local scaledWidth = Pixel.Scale(detachedWidth)
    local scaledHeight = Pixel.Scale(detachedHeight)
    local iconData = GetFrameData(icon)

    local cornerX = Pixel.Snap(position.x - scaledWidth / 2)
    local cornerY = Pixel.Snap(position.y + scaledHeight / 2)
    iconData.anchor = UIParent
    iconData.posX = position.x
    iconData.posY = position.y
    iconData.selfPoint = "TOPLEFT"
    iconData.relPoint = "CENTER"
    iconData.posCornerX = cornerX
    iconData.posCornerY = cornerY
    iconData.sizeW = scaledWidth
    iconData.sizeH = scaledHeight

    if iconData.skinVer ~= CDM.state.skinVersion then
        CDM.SkinIcon(icon, settings, key)
    end

    iconData.locking = true

    icon:SetScale(1)
    icon:SetSize(scaledWidth, scaledHeight)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", UIParent, "CENTER", cornerX, cornerY)

    iconData.parked = nil
    icon:SetAlpha(CDM.GetContextualOpacity(key) / 100)

    iconData.locking = false

    return true
end

function Detached.ClearAll(key)
    local db = BUI.GetDB()
    local settings = db.cdm[key]
    if not settings then return end
    CDM.ClearAllDetachedIcons(settings)
    CDM.SetUpdatePending(true)
end
