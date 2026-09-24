local _, BUI = ...
BUI.C.ANCHOR_FRAMES = {
    { tag = "BUI_PlayerFrame", desc = "BUI_PlayerFrame" },
    { tag = "BUI_TargetFrame", desc = "BUI_TargetFrame" },
    { tag = "BUI_FocusFrame", desc = "BUI_FocusFrame" },
    { tag = "BUI_PetFrame", desc = "BUI_PetFrame" },
    { tag = "BUI_GroupParty", desc = "BUI_GroupParty" },
    { tag = "BUI_Castbar_player", desc = "BUI_Castbar_player" },
    { tag = "BUI_Castbar_target", desc = "BUI_Castbar_target" },
    { tag = "BUI_Castbar_focus", desc = "BUI_Castbar_focus" },
    { tag = "BUI_PowerBarAny", desc = "BUI_PowerBarAny" },
    { tag = "BUI_EssentialCooldownViewer", desc = "BUI_EssentialCooldownViewer" },
    { tag = "BUI_UtilityCooldownViewer", desc = "BUI_UtilityCooldownViewer" },
    { tag = "BUI_BuffCooldownViewer", desc = "BUI_BuffCooldownViewer" },
    { tag = "BUI_ActionBar1", desc = "BUI_ActionBar1" },
    { tag = "BUI_ActionBar2", desc = "BUI_ActionBar2" },
    { tag = "BUI_ActionBar3", desc = "BUI_ActionBar3" },
    { tag = "BUI_PetBar", desc = "BUI_PetBar" },
    { tag = "BUI_StanceBar", desc = "BUI_StanceBar" },
    { tag = "BUI_MarkerBar", desc = "BUI_MarkerBar" },
}

BUI.C.ANCHOR_FRAMES_WITH_MOUSE = { { tag = "Mouse", desc = "Mouse" } }
for frameIndex = 1, #BUI.C.ANCHOR_FRAMES do
    BUI.C.ANCHOR_FRAMES_WITH_MOUSE[frameIndex + 1] = BUI.C.ANCHOR_FRAMES[frameIndex]
end

function BUI.AnchorFramesExcept(selfTag)
    if not selfTag or selfTag == "" then return BUI.C.ANCHOR_FRAMES end
    local filtered = {}
    for frameIndex = 1, #BUI.C.ANCHOR_FRAMES do
        local entry = BUI.C.ANCHOR_FRAMES[frameIndex]
        if entry.tag ~= selfTag then filtered[#filtered + 1] = entry end
    end
    return filtered
end

local CDM_FRAMES = {
    BUI_EssentialCooldownViewer = true,
    BUI_UtilityCooldownViewer = true,
    BUI_BuffCooldownViewer = true,
}

local POWER_FRAMES = {
    BUI_PowerBar = true,
    BUI_SecondaryPower = true,
    BUI_PowerBarAny = true,
}

local OPPOSITES_VERTICAL = {
    TOP = "BOTTOM", BOTTOM = "TOP",
    LEFT = "RIGHT", RIGHT = "LEFT",
    TOPLEFT = "BOTTOMLEFT", TOPRIGHT = "BOTTOMRIGHT",
    BOTTOMLEFT = "TOPLEFT", BOTTOMRIGHT = "TOPRIGHT",
    CENTER = "CENTER",
}

local OPPOSITES_HORIZONTAL = {
    TOP = "BOTTOM", BOTTOM = "TOP",
    LEFT = "RIGHT", RIGHT = "LEFT",
    TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT",
    BOTTOMLEFT = "BOTTOMRIGHT", BOTTOMRIGHT = "BOTTOMLEFT",
    CENTER = "CENTER",
}

function BUI.ResolveAnchorFrame(name, anchorPoint)
    if not name or name == "" then return nil end
    if name == "BUI_PowerBarAny" then
        local powerContainer = BUI.Power and BUI.Power.Container
        if powerContainer and powerContainer.IsEnabled and powerContainer.IsEnabled() then
            local stackFrame = _G["BUI_StackLab"]
            if stackFrame then return stackFrame end
        end
        local Stack = BUI.Power and BUI.Power.Stack
        return Stack and Stack.GetFirstAvailableFrame(anchorPoint) or nil
    end
    return _G[name]
end

local function GetCDMAnchorOffset(frameName, anchorPoint)
    if not CDM_FRAMES[frameName] then return 0 end
    local anchor = _G[frameName]
    if not anchor then return 0 end
    if anchorPoint == "TOP" or anchorPoint == "TOPLEFT" or anchorPoint == "TOPRIGHT" then
        return -(anchor._topEdgeOffset or 0)
    elseif anchorPoint == "BOTTOM" or anchorPoint == "BOTTOMLEFT" or anchorPoint == "BOTTOMRIGHT" then
        return anchor._bottomEdgeOffset or 0
    end
    return 0
end

local function GetPointInUIParent(frame, point)
    if not frame then return nil, nil end
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then return nil, nil end
    local centerX = (left + right) / 2
    local centerY = (top + bottom) / 2
    if point == "TOPLEFT" then return left, top
    elseif point == "TOP" then return centerX, top
    elseif point == "TOPRIGHT" then return right, top
    elseif point == "LEFT" then return left, centerY
    elseif point == "RIGHT" then return right, centerY
    elseif point == "BOTTOMLEFT" then return left, bottom
    elseif point == "BOTTOM" then return centerX, bottom
    elseif point == "BOTTOMRIGHT" then return right, bottom
    end
    return centerX, centerY
end

local Anchor = {}
BUI.Anchor = Anchor

function Anchor.ResolveAnchorPoint(anchorPoint, horizontalMode)
    anchorPoint = anchorPoint or "BOTTOM"
    local insidePoint = anchorPoint:match("^INSIDE_(.+)$")
    if insidePoint then return insidePoint, insidePoint, true end
    local opposites = horizontalMode and OPPOSITES_HORIZONTAL or OPPOSITES_VERTICAL
    return anchorPoint, opposites[anchorPoint] or "CENTER", false
end

local anchorCallbacks = {}
local flushFrame

function Anchor.RegisterCallback(key, callback)
    anchorCallbacks[key] = callback
end

local function FlushAnchorCallbacks(self)
    if self._armTime == GetTime() then return end
    self:Hide()
    for _, callback in pairs(anchorCallbacks) do callback() end
end

function Anchor.OnAnchorSizeChanged()
    if not flushFrame then
        flushFrame = CreateFrame("Frame", "BUI_AnchorFlush")
        flushFrame:Hide()
        flushFrame:SetScript("OnUpdate", FlushAnchorCallbacks)
    end
    flushFrame._armTime = GetTime()
    flushFrame:Show()
end

function Anchor.WouldCycle(frame, candidate)
    if not frame or not candidate then return false end
    local current, depth = candidate, 0
    while current and depth < 16 do
        if current == frame then return true end
        current = current._anchorTarget
        depth = depth + 1
    end
    return false
end

local function ClearMouseFollow(frame)
    if frame._mouseFollower then
        frame._mouseFollower:SetScript("OnUpdate", nil)
        frame._mouseFollower:Hide()
    end
end

local function ApplyMouseAnchor(frame, settings)
    local anchorPoint, framePoint = Anchor.ResolveAnchorPoint(settings.anchorPoint, settings.horizontalMode)
    local offsetX = settings.anchorOffsetX or 0
    local offsetY = settings.anchorOffsetY or 0

    if not frame._mouseFollower then
        frame._mouseFollower = CreateFrame("Frame")
    end
    local follower = frame._mouseFollower
    follower._lastX, follower._lastY = nil, nil

    frame:ClearAllPoints()
    frame:SetPoint(framePoint, UIParent, "BOTTOMLEFT", 0, 0)
    frame._anchorTarget = nil
    frame._isAnchored = true

    follower:Show()
    follower:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        if x == self._lastX and y == self._lastY then return end
        self._lastX, self._lastY = x, y
        local effectiveScale = UIParent:GetEffectiveScale()

        frame:SetPoint(framePoint, UIParent, "BOTTOMLEFT", x / effectiveScale + offsetX, y / effectiveScale + offsetY)
    end)
end

local MODE_POS_KEYS = {
    posX = true, posY = true, centerHorizontally = true,
    anchorFrame = true, anchorPoint = true, anchorOffsetX = true, anchorOffsetY = true,
    matchAnchorWidth = true, matchAnchorHeight = true,
}
local function modePosKey(key) return 'text' .. key:sub(1, 1):upper() .. key:sub(2) end

function Anchor.ModePos(db, isText)
    if not isText then return db end
    return setmetatable({}, {
        __index = function(_, key)
            if MODE_POS_KEYS[key] then
                local value = db[modePosKey(key)]
                if value ~= nil then return value end
            end
            return db[key]
        end,
        __newindex = function(_, key, value)
            db[MODE_POS_KEYS[key] and modePosKey(key) or key] = value
        end,
    })
end

function Anchor.SetCentered(frame, posX, posY)
    if not frame then return end
    local Scale = BUI.Pixel.Scale
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", Scale(posX or 0), Scale(posY or 0))
end

function Anchor.ApplyPosition(frame, settings)
    if not frame then return end

    local powerContainer = BUI.Power and BUI.Power.Container
    if powerContainer and powerContainer.PlaceMember and powerContainer.PlaceMember(frame) then
        return frame._anchorTarget
    end

    if settings.anchorFrame == "Mouse" then
        ApplyMouseAnchor(frame, settings)
        return nil
    end
    ClearMouseFollow(frame)

    frame:ClearAllPoints()
    local anchorTarget = BUI.ResolveAnchorFrame(settings.anchorFrame, settings.anchorPoint)
    if anchorTarget == frame then anchorTarget = nil end

    if anchorTarget and Anchor.WouldCycle(frame, anchorTarget) then anchorTarget = nil end
    if anchorTarget then
        local anchorPoint, framePoint, isInside = Anchor.ResolveAnchorPoint(settings.anchorPoint, settings.horizontalMode)
        local offsetX = settings.anchorOffsetX or 0
        local offsetY = settings.anchorOffsetY or 0

        offsetY = offsetY + GetCDMAnchorOffset(settings.anchorFrame, anchorPoint)

        if not settings.noGap then
            local gap = BUI.Pixel.PixelSize(1)
            if isInside then gap = -gap end
            if anchorPoint == "BOTTOM" or anchorPoint == "BOTTOMLEFT" or anchorPoint == "BOTTOMRIGHT" then
                offsetY = offsetY - gap
            elseif anchorPoint == "TOP" or anchorPoint == "TOPLEFT" or anchorPoint == "TOPRIGHT" then
                offsetY = offsetY + gap
            end
            if anchorPoint == "LEFT" or anchorPoint == "TOPLEFT" or anchorPoint == "BOTTOMLEFT" then
                offsetX = offsetX - gap
            elseif anchorPoint == "RIGHT" or anchorPoint == "TOPRIGHT" or anchorPoint == "BOTTOMRIGHT" then
                offsetX = offsetX + gap
            end
        end

        if settings.scaleOffsets then
            offsetX = BUI.Pixel.Scale(offsetX)
            offsetY = BUI.Pixel.Scale(offsetY)
        end
        if anchorTarget._castbarIconWidth and anchorTarget._castbarIconWidth > 0 then
            local iconWidth = anchorTarget._castbarIconWidth
            if anchorPoint:match("LEFT") then
                offsetX = offsetX - iconWidth
            elseif not anchorPoint:match("RIGHT") then
                offsetX = offsetX - (iconWidth / 2)
            end
        end
        if CDM_FRAMES[settings.anchorFrame] then
            local anchorX, anchorY = GetPointInUIParent(anchorTarget, anchorPoint)
            if anchorX and anchorY then
                if anchorPoint == "TOP" or anchorPoint == "BOTTOM" or anchorPoint == "CENTER" then
                    local rowCenterOffsetX = anchorTarget._row1CenterOffsetX
                    if anchorPoint == "TOP" and anchorTarget._topRowCenterOffsetX then
                        rowCenterOffsetX = anchorTarget._topRowCenterOffsetX
                    elseif anchorPoint == "BOTTOM" and anchorTarget._bottomRowCenterOffsetX then
                        rowCenterOffsetX = anchorTarget._bottomRowCenterOffsetX
                    end
                    if rowCenterOffsetX then anchorX = anchorX + rowCenterOffsetX end
                end

                if anchorTarget._topRowCenterOffsetY
                    and (anchorPoint == "LEFT" or anchorPoint == "RIGHT" or anchorPoint == "CENTER") then
                    anchorY = anchorY + anchorTarget._topRowCenterOffsetY
                end

                if anchorTarget._topRowW and (anchorPoint == "LEFT" or anchorPoint == "RIGHT") then
                    local frameWidth = anchorTarget._layoutW or anchorTarget:GetWidth() or 0
                    local inset = (frameWidth - anchorTarget._topRowW) / 2
                    if inset > 0 then
                        anchorX = anchorPoint == "LEFT" and (anchorX + inset) or (anchorX - inset)
                    end
                end

                frame:SetPoint(framePoint, UIParent, "BOTTOMLEFT", anchorX + offsetX, anchorY + offsetY)
                frame._anchorTarget = anchorTarget
                frame._isAnchored = true
                return anchorTarget
            end
        end
        frame:SetPoint(framePoint, anchorTarget, anchorPoint, offsetX, offsetY)
        frame._anchorTarget = anchorTarget
        frame._isAnchored = true
        return anchorTarget
    else
        frame._anchorTarget = nil
        frame._isAnchored = false
        local x = settings.centerHorizontally and 0 or (settings.posX or 0)
        Anchor.SetCentered(frame, x, settings.posY or 0)
    end
end

function Anchor.SaveDragOffsets(frame, settings)
    if not frame then return nil end
    local anchorFrame = settings.anchorFrame
    if not anchorFrame or anchorFrame == "" or anchorFrame == "Mouse" then return nil end

    local droppedX, droppedY = frame:GetLeft(), frame:GetBottom()
    if not droppedX or not droppedY then return nil end

    local savedX, savedY = settings.anchorOffsetX, settings.anchorOffsetY
    settings.anchorOffsetX, settings.anchorOffsetY = 0, 0
    local anchorTarget = Anchor.ApplyPosition(frame, settings)
    settings.anchorOffsetX, settings.anchorOffsetY = savedX, savedY
    if not anchorTarget then return nil end

    local baseX, baseY = frame:GetLeft(), frame:GetBottom()
    if not baseX or not baseY then return nil end

    return droppedX - baseX, droppedY - baseY
end

function Anchor.GetAnchorWidth(frame, settings)
    local powerContainer = BUI.Power and BUI.Power.Container
    if powerContainer and powerContainer.GetMemberWidth then
        local memberWidth = powerContainer.GetMemberWidth(frame)
        if memberWidth then return memberWidth end
    end
    if not settings.matchAnchorWidth then return nil end
    if not frame or not frame._anchorTarget then return nil end

    local target = frame._anchorTarget

    local point = settings.anchorPoint or "BOTTOM"
    local anchorWidth
    if point == "BOTTOM" or point == "BOTTOMLEFT" or point == "BOTTOMRIGHT" then
        anchorWidth = target._bottomRowW or target._topRowW or target._row1W or target:GetWidth()
    else
        anchorWidth = target._topRowW or target._row1W or target:GetWidth()
    end
    if anchorWidth and anchorWidth > 0 then
        if target._castbarIconWidth and target._castbarIconWidth > 0 then
            anchorWidth = anchorWidth + target._castbarIconWidth
        end
        return anchorWidth
    end
end

function Anchor.GetAnchorHeight(settings)
    if not settings or not settings.matchAnchorHeight then return nil end
    local target = BUI.ResolveAnchorFrame(settings.anchorFrame, settings.anchorPoint)
    if not target then return nil end
    local anchorHeight = target._cachedScaledH or target:GetHeight()
    if anchorHeight and anchorHeight > 0 then return anchorHeight end
end

function Anchor.ShouldRefreshOnAnchorChange(settings)
    if not settings.anchorFrame or settings.anchorFrame == "" then return false end

    if CDM_FRAMES[settings.anchorFrame] then return true end
    if POWER_FRAMES[settings.anchorFrame] then return true end
    return settings.matchAnchorWidth or settings.matchAnchorHeight
end
