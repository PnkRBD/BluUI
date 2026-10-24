local _, BUI = ...
BUI.Dragging = {}
local Dragging = BUI.Dragging
local Pixel = BUI.Pixel
local Scale = Pixel.Scale
local HintText = "Drag to Reposition | Right-Click to Lock"
local HintFontSize, UnlockBgAlpha = 11, 0.3

function Dragging.GetCenterOffset(frame)
    if not frame then return 0, 0 end
    local parentX, parentY = UIParent:GetCenter()
    if not parentX or not parentY then return 0, 0 end
    local frameX, frameY
    if frame.dragSnapCenter then
        local left, bottom = frame:GetLeft(), frame:GetBottom()
        if not left or not bottom then return 0, 0 end
        frameX = left + frame:GetWidth() / 2
        frameY = bottom + frame:GetHeight() / 2
    else
        frameX, frameY = frame:GetCenter()
        if not frameX or not frameY then return 0, 0 end
    end
    return Scale(frameX - parentX), Scale(frameY - parentY)
end

local OnDragUpdate = function(self)
    if not self.dragActive then return end

    if self.dragLockHorizontal and self._dragLockedX then
        local _, offsetY = Dragging.GetCenterOffset(self)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", self._dragLockedX, offsetY)
        if self.dragOnDragging then self.dragOnDragging(self._dragLockedX, offsetY) end

    elseif self.dragOnDragging then
        local offsetX, offsetY
        if self.dragUsePoint then
            local _, _, _, pointX, pointY = self:GetPoint()
            offsetX, offsetY = Scale(pointX), Scale(pointY)
        else
            offsetX, offsetY = Dragging.GetCenterOffset(self)
        end
        self.dragOnDragging(offsetX, offsetY)
    end
end

local function OnDragStart(self)
    local locked = self.dragLocked
    if self.dragIsLockedFn then locked = self.dragIsLockedFn() end
    if locked then return end

    if InCombatLockdown() and self:IsProtected() then return end

    self.dragActive = true
    self.dragMoved = true

    if self.dragLockHorizontal then
        local rawX = self.dragGetLockedX and self.dragGetLockedX() or Dragging.GetCenterOffset(self)
        self._dragLockedX = Scale(rawX)
    end

    self:StartMoving()
    if not self.dragKeepPlacement then self:SetUserPlaced(false) end
    if self.dragLockHorizontal or self.dragOnDragging then
        self.dragUpdating = true
        self:SetScript("OnUpdate", OnDragUpdate)
    end
end

local function OnDragStop(self)
    if not self.dragActive then return end
    self:StopMovingOrSizing()
    self.dragActive = false
    if self.dragUpdating then
        self.dragUpdating = nil
        self:SetScript("OnUpdate", nil)
    end

    local offsetX, offsetY = Dragging.GetCenterOffset(self)

    if self.dragLockHorizontal and self._dragLockedX then
        offsetX = self._dragLockedX
    end

    if not self.dragKeepPlacement then
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
    end

    if self.dragOnPosition then
        if self.dragUsePoint then
            local point, _, _, pointX, pointY = self:GetPoint()
            self.dragOnPosition(Scale(pointX), Scale(pointY), point)
        else
            self.dragOnPosition(offsetX, offsetY)
        end
    end
end

local function OnMouseUp(self, button)
    if button == "RightButton" and not self.dragActive and self.dragOnRightClick then
        self.dragOnRightClick()
    end
end

local function ApplyClickThroughToChildren(enabled, ...)
    local inset = enabled and 10000 or 0
    for index = 1, select('#', ...) do
        local child = select(index, ...)
        if not (child:IsForbidden() or child._buiSkipMouseWalk) then
            if not child._keepMouseForTooltip then
                child:EnableMouse(false)
                child:SetHitRectInsets(inset, inset, inset, inset)
            end
            ApplyClickThroughToChildren(enabled, child:GetChildren())
        end
    end
end

local function SetClickThrough(frame, enabled)
    local inset = enabled and 10000 or 0
    frame:EnableMouse(not enabled)
    frame:SetHitRectInsets(inset, inset, inset, inset)
    ApplyClickThroughToChildren(enabled, frame:GetChildren())
end

local function UpdateDragVisuals(frame)
    local locked = frame.dragLocked
    if not frame.dragSkipClickThrough then
        SetClickThrough(frame, locked)
    end
    if frame.dragUnlockBg then frame.dragUnlockBg:SetShown(not locked) end
    if frame.dragHint then frame.dragHint:SetShown(not locked) end
end

local function CreateHintUI(parent, options)
    local hint = CreateFrame("Frame", nil, parent)
    hint:SetClampedToScreen(true)
    hint:SetFrameLevel(parent:GetFrameLevel() + 10)

    local anchor = options.hintAnchor or "TOP"
    local opposite = anchor == "TOP" and "BOTTOM" or "TOP"
    hint:SetPoint(opposite, parent, anchor, 0, Pixel.Scale(anchor == "TOP" and 5 or -5))

    local label = hint:CreateFontString(nil, "OVERLAY")
    BUI.Pixel.ApplyFont(label, HintFontSize, BUI.GetGlobalFont())
    label:SetPoint("CENTER")
    label:SetTextColor(1, 1, 1, 1)
    label:SetText(options.hintText or HintText)
    hint.text = label

    C_Timer.After(0, function()
        if hint:IsShown() then hint:SnapSize(label:GetStringWidth() + 16, 20) end
    end)
    hint:SnapSize(120, 20)

    hint:Hide()
    return hint
end

function Dragging.MakeDraggable(frame, options)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    if options.clamp then frame:SetClampedToScreen(true) end
    frame.dragSnapCenter = options.snapCenter or false
    frame.dragKeepPlacement = options.keepPlacement

    frame.dragLocked = type(options.isLocked) == "function" and options.isLocked() or false
    frame.dragOnPosition = options.onPositionChanged
    frame.dragOnDragging = options.onDragging
    frame.dragOnRightClick = options.onRightClick
    frame.dragUsePoint = options.usePointPosition
    frame.dragIsLockedFn = type(options.isLocked) == "function" and options.isLocked or nil

    if type(options.lockHorizontal) == "function" then
        frame.dragLockHorizontalFn = options.lockHorizontal
        frame.dragLockHorizontal = options.lockHorizontal()
    else
        frame.dragLockHorizontal = options.lockHorizontal or false
    end
    frame.dragGetLockedX = options.getLockedX
    frame.dragSkipClickThrough = options.skipClickThrough

    if options.showUnlockedBg then
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        BUI.Tools.SetColorTex(background, 0, 0, 0, UnlockBgAlpha)
        frame.dragUnlockBg = background
    end

    if options.showHint then frame.dragHint = CreateHintUI(frame, options) end

    frame:SetScript("OnDragStart", OnDragStart)
    frame:SetScript("OnDragStop", OnDragStop)
    if options.onRightClick then
        frame:SetScript("OnMouseUp", OnMouseUp)
    end
    UpdateDragVisuals(frame)

    function frame:RefreshDragState()
        if self.dragIsLockedFn then self.dragLocked = self.dragIsLockedFn() end
        if self.dragLockHorizontalFn then self.dragLockHorizontal = self.dragLockHorizontalFn() end
        UpdateDragVisuals(self)
    end
end

function Dragging.Release(frame)
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    frame:SetScript("OnMouseUp", nil)
    frame:SetScript("OnUpdate", nil)
    frame:SetMovable(false)
    frame:RegisterForDrag()
    if frame.dragHint then frame.dragHint:Hide() end
    if frame.dragUnlockBg then frame.dragUnlockBg:Hide() end
    frame.dragActive = nil
    frame.dragLocked = nil
    frame.dragOnPosition = nil
    frame.dragOnDragging = nil
    frame.dragOnRightClick = nil
    frame.dragIsLockedFn = nil
    frame.RefreshDragState = nil
end

function Dragging.MakeAnchoredAlert(frame, options)
    Dragging.MakeDraggable(frame, {
        showHint = true,
        showUnlockedBg = true,
        hintAnchor = "TOP",
        isLocked = options.isLocked,
        onRightClick = options.onRightClick,
        onPositionChanged = function() BUI.Anchor.SaveDrop(frame, options.settings()) end,
    })
end

function Dragging.SetLocked(frame, locked)
    if not frame then return end
    frame.dragLocked = locked
    UpdateDragVisuals(frame)
end

function Dragging.SaveCenterPosition(frame, config, honorCenter)
    local frameScale = frame:GetEffectiveScale()
    local uiScale = UIParent:GetEffectiveScale()
    local x, y = frame:GetCenter()
    local uiX, uiY = UIParent:GetCenter()
    local offsetX = BUI.Round((x * frameScale - uiX * uiScale) / uiScale)
    local offsetY = BUI.Round((y * frameScale - uiY * uiScale) / uiScale)
    config.posX = (honorCenter and config.centerHorizontally) and 0 or offsetX
    config.posY = offsetY
    return config.posX, config.posY
end

local CenterDragOnUpdate = function(frame)
    local _, centerY = frame:GetCenter()
    local _, uiCenterY = UIParent:GetCenter()
    if centerY and uiCenterY then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, BUI.Round(centerY - uiCenterY))
    end
end

function Dragging.EnableAnchorDrag(frame, options)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
        self:SetUserPlaced(false)
        if options.isCentered and options.isCentered() then
            self._centerDrag = true
            self:SetScript("OnUpdate", CenterDragOnUpdate)
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if self._centerDrag then
            self:SetScript("OnUpdate", nil)
            self._centerDrag = nil
        end
        if options.onSave then options.onSave() end
    end)

    frame:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" and options.onRightClick then
            options.onRightClick()
        end
    end)
end

function Dragging.DisableAnchorDrag(frame)
    if frame._centerDrag then
        frame:SetScript("OnUpdate", nil)
        frame._centerDrag = nil
    end
    frame:EnableMouse(false)
    frame:SetMovable(false)
    frame:RegisterForDrag()
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    frame:SetScript("OnMouseDown", nil)
end
