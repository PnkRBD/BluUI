local _, BUI = ...
local Profiler = BUI.Profiler
local Widget = BUI.BUILibClient.Widget
BUI.C.ANCHOR_FRAMES = {
    { tag = "BUI_PlayerFrame", desc = "Player frame" },
    { tag = "BUI_TargetFrame", desc = "Target frame" },
    { tag = "BUI_FocusFrame", desc = "Focus frame" },
    { tag = "BUI_PetFrame", desc = "Pet frame" },
    { tag = "BUI_GroupParty", desc = "Party frames" },
    { tag = "BUI_Castbar_player", desc = "Player cast bar" },
    { tag = "BUI_Castbar_target", desc = "Target cast bar" },
    { tag = "BUI_Castbar_focus", desc = "Focus cast bar" },
    { tag = "BUI_PowerBarAny", desc = "Power bar" },
    { tag = "BUI_EssentialCooldownViewer", desc = "Essential cooldowns" },
    { tag = "BUI_UtilityCooldownViewer", desc = "Utility cooldowns" },
    { tag = "BUI_BuffCooldownViewer", desc = "Buff icons" },
    { tag = "BUI_ActionBar1", desc = "Action bar 1" },
    { tag = "BUI_ActionBar2", desc = "Action bar 2" },
    { tag = "BUI_ActionBar3", desc = "Action bar 3" },
    { tag = "BUI_PetBar", desc = "Pet bar" },
    { tag = "BUI_StanceBar", desc = "Stance bar" },
    { tag = "BUI_MarkerBar", desc = "Marker bar" },
    { tag = "BUI_BuffFrame", desc = "Buffs" },
    { tag = "BUI_DebuffFrame", desc = "Debuffs" },
    { tag = "Minimap", desc = "Minimap" },
}

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
    if name == "BUI_PowerBarAny" then return BUI.Power.Container.AnchorFrame() end
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

local CENTERED_SIDES = { TOP = true, BOTTOM = true, CENTER = true }

function Anchor.IsCenteredSide(anchorPoint, horizontalMode)
    if horizontalMode then return false end
    return CENTERED_SIDES[(Anchor.ResolveAnchorPoint(anchorPoint))] == true
end

function Anchor.CentersOnAnchor(settings)
    return settings.centerHorizontally == true and Anchor.IsCenteredSide(settings.anchorPoint, settings.horizontalMode)
end

local anchorCallbacks = {}
local armedAt

function Anchor.RegisterCallback(key, callback)
    anchorCallbacks[key] = callback
end

local FlushAnchors
FlushAnchors = BUI.Dispatcher.New(function()
    if armedAt == GetTime() then
        FlushAnchors()
        return
    end
    for key, callback in pairs(anchorCallbacks) do
        Profiler.Run(Profiler.Label('Anchor moved', key), callback)
    end
end, 'Anchors')

function Anchor.OnAnchorSizeChanged()
    armedAt = GetTime()
    FlushAnchors()
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
    follower:SetScript("OnUpdate", Profiler.Wrap("Utility.Anchors mouse follow", function(self)
        local x, y = GetCursorPosition()
        if x == self._lastX and y == self._lastY then return end
        self._lastX, self._lastY = x, y
        local effectiveScale = UIParent:GetEffectiveScale()

        frame:SetPoint(framePoint, UIParent, "BOTTOMLEFT", x / effectiveScale + offsetX, y / effectiveScale + offsetY)
    end))
end

local MODE_POS_KEYS = {
    posX = true, posY = true, centerHorizontally = true,
    anchorFrame = true, anchorPoint = true, anchorOffsetX = true, anchorOffsetY = true,
    matchAnchorWidth = true, matchAnchorHeight = true,
}
local function PrefixedKey(prefix, key) return prefix .. key:sub(1, 1):upper() .. key:sub(2) end

local TEXT_POS_KEYS = {}
for key in pairs(MODE_POS_KEYS) do TEXT_POS_KEYS[key] = PrefixedKey('text', key) end

function Anchor.PrefixedSettings(getDB, prefix)
    local fields = {}
    for key in pairs(MODE_POS_KEYS) do fields[key] = PrefixedKey(prefix, key) end
    return setmetatable({}, {
        __index = function(_, key) return getDB()[fields[key] or key] end,
        __newindex = function(_, key, value) getDB()[fields[key] or key] = value end,
    })
end

local modePosProxies = setmetatable({}, { __mode = 'kv' })

function Anchor.ModePos(db, isText)
    if not isText then return db end
    local proxy = modePosProxies[db]
    if proxy then return proxy end
    proxy = setmetatable({}, {
        __index = function(_, key)
            local textKey = TEXT_POS_KEYS[key]
            if textKey then
                local value = db[textKey]
                if value ~= nil then return value end
            end
            return db[key]
        end,
        __newindex = function(_, key, value)
            db[TEXT_POS_KEYS[key] or key] = value
        end,
    })
    modePosProxies[db] = proxy
    return proxy
end

local OFFSET_TOLERANCE = 0.01

local function PlaceIntent(frame)
    local intent = frame._pixelIntent
    frame:SetPoint(intent.point, intent.relativeTo, intent.relativePoint, intent.x, intent.y)
    intent.placedX, intent.placedY = intent.x, intent.y
    local left, top = frame:GetLeft(), frame:GetTop()
    if not left or not top or issecretvalue(left) or issecretvalue(top) then return end
    local pixel = BUI.Pixel.PixelSizeFor(frame, 1)
    local shiftX = Widget.SnapX(left, pixel) - left
    local shiftY = Widget.SnapY(top, pixel) - top
    if shiftX == 0 and shiftY == 0 then return end
    intent.placedX, intent.placedY = intent.x + shiftX, intent.y + shiftY
    frame:SetPoint(intent.point, intent.relativeTo, intent.relativePoint, intent.placedX, intent.placedY)
end

local OnPlacedSizeChanged = Profiler.Wrap("Utility.Anchors placed resize", function(frame)
    local intent = frame._pixelIntent
    if not intent or frame:GetNumPoints() ~= 1 then return end
    if InCombatLockdown() and frame:IsProtected() then return end
    local point, relativeTo, _, x, y = frame:GetPoint(1)
    if point ~= intent.point or relativeTo ~= intent.relativeTo
        or math.abs(x - intent.placedX) > OFFSET_TOLERANCE or math.abs(y - intent.placedY) > OFFSET_TOLERANCE then
        frame._pixelIntent = nil
        return
    end
    PlaceIntent(frame)
end)

function Anchor.PlaceOnPixels(frame, point, relativeTo, relativePoint, x, y)
    local intent = frame._pixelSlot
    if not intent then
        intent = {}
        frame._pixelSlot = intent
        frame:HookScript("OnSizeChanged", OnPlacedSizeChanged)
    end
    intent.point, intent.relativeTo, intent.relativePoint, intent.x, intent.y = point, relativeTo, relativePoint, x or 0, y or 0
    frame._pixelIntent = intent
    PlaceIntent(frame)
end

function Anchor.SetCentered(frame, posX, posY)
    frame:ClearAllPoints()
    local scale = frame:GetScale()
    Anchor.PlaceOnPixels(frame, "CENTER", UIParent, "CENTER", posX / scale, posY / scale)
end

function Anchor.ApplyPosition(frame, settings)
    if not frame then return end

    if BUI.Power.Container.PlaceMember(frame) then
        return frame._anchorTarget
    end

    if settings.anchorFrame == "Mouse" then
        ApplyMouseAnchor(frame, settings)
        return nil
    end
    ClearMouseFollow(frame)

    frame:ClearAllPoints()
    frame._pixelIntent = nil
    local anchorTarget = BUI.ResolveAnchorFrame(settings.anchorFrame, settings.anchorPoint)
    if anchorTarget == frame then anchorTarget = nil end

    if anchorTarget and Anchor.WouldCycle(frame, anchorTarget) then anchorTarget = nil end
    if anchorTarget then
        local anchorPoint, framePoint, isInside = Anchor.ResolveAnchorPoint(settings.anchorPoint, settings.horizontalMode)
        local offsetX = Anchor.CentersOnAnchor(settings) and 0 or (settings.anchorOffsetX or 0)
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

                if anchorTarget._row1W and (anchorPoint == "LEFT" or anchorPoint == "RIGHT") then
                    local frameWidth = anchorTarget._layoutW or anchorTarget:GetWidth()
                    local inset = (frameWidth - anchorTarget._row1W) / 2
                    if inset > 0 then
                        anchorX = anchorPoint == "LEFT" and (anchorX + inset) or (anchorX - inset)
                    end
                end

                Anchor.PlaceOnPixels(frame, framePoint, UIParent, "BOTTOMLEFT", anchorX + offsetX, anchorY + offsetY)
                frame._anchorTarget = anchorTarget
                frame._isAnchored = true
                return anchorTarget
            end
        end
        Anchor.PlaceOnPixels(frame, framePoint, anchorTarget, anchorPoint, offsetX, offsetY)
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
    local memberWidth = BUI.Power.Container.GetMemberWidth(frame)
    if memberWidth then return memberWidth end
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
    if anchorWidth > 0 then
        if target._castbarIconWidth and target._castbarIconWidth > 0 then
            anchorWidth = anchorWidth + target._castbarIconWidth
        end
        return anchorWidth
    end
end

function Anchor.GetAnchorHeight(settings)
    if not settings.matchAnchorHeight then return nil end
    local target = BUI.ResolveAnchorFrame(settings.anchorFrame, settings.anchorPoint)
    if not target then return nil end
    local anchorHeight = target._cachedScaledH or target:GetHeight()
    if anchorHeight > 0 then return anchorHeight end
end

function Anchor.ShouldRefreshOnAnchorChange(settings)
    if not settings.anchorFrame or settings.anchorFrame == "" then return false end

    if CDM_FRAMES[settings.anchorFrame] then return true end
    if POWER_FRAMES[settings.anchorFrame] then return true end
    return settings.matchAnchorWidth or settings.matchAnchorHeight
end

local function NeedsReanchor(frame, settings)
    if Anchor.ShouldRefreshOnAnchorChange(settings) then return true end
    local anchorFrame = settings.anchorFrame
    return anchorFrame ~= nil and anchorFrame ~= "" and not frame._isAnchored
end

function Anchor.SaveDrop(frame, settings)
    local x, y = BUI.Dragging.GetCenterOffset(frame)
    local anchorX, anchorY = Anchor.SaveDragOffsets(frame, settings)
    if anchorX then
        settings.anchorOffsetX = BUI.Round(anchorX)
        settings.anchorOffsetY = BUI.Round(anchorY)
    else
        settings.posX = settings.centerHorizontally and 0 or BUI.Round(x)
        settings.posY = BUI.Round(y)
    end
    Anchor.ApplyPosition(frame, settings)
end

function Anchor.Follow(key, getFrame, getSettings)
    Anchor.RegisterCallback(key, function()
        local frame = getFrame()
        if not frame then return end
        local settings = getSettings()
        if NeedsReanchor(frame, settings) then Anchor.ApplyPosition(frame, settings) end
    end)
end
