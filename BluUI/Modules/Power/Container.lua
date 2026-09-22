local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Power.Container')

local ipairs = ipairs
local wipe = wipe
local math = math

BUI.Power.Container = {}
local Container = BUI.Power.Container
local Pixel = BUI.Pixel

local MEMBER_KEYS = { 'primary', 'secondary', 'castbar' }
local FRAME_NAMES = {
    primary = 'BUI_PowerBar',
    secondary = 'BUI_SecondaryPower',
    castbar = 'BUI_Castbar_player',
}
local stackFrame
local layoutY = {}
local hooked = {}
local queueFrame
local RestyleMembers
local IsActive
local PositionStack
local lastLayoutSignature
local relaying = false

local lastFullHeight, lastCollapsedHeight = 0, 0
local transientEdge

local function FrameFor(key) return _G[FRAME_NAMES[key]] end

local function CastbarSettings()
    return BUI.CastBar.GetSettings('player')
end

function Container.GetDB()
    local db = BUI.Power.GetPrimaryDB()
    if not db.stackLab then
        db.stackLab = {
            enabled = false,
            order = { 'primary', 'secondary', 'castbar' },
            attached = { primary = true, secondary = true, castbar = false },
            gap = 0,
            width = 230,
            matchWidth = true,
            matchAnchorWidth = false,
            castbarMode = 'collapse',
            locked = true,
            posX = 0, posY = -220, centerHorizontally = true,
            anchorFrame = '', anchorPoint = 'BOTTOM',
            anchorOffsetX = 0, anchorOffsetY = 0,
        }
    end
    local settings = db.stackLab
    if not settings.order then settings.order = { 'primary', 'secondary', 'castbar' } end
    if not settings.attached then settings.attached = { primary = true, secondary = true } end
    return settings
end

function Container.IsEnabled()
    return Container.GetDB().enabled or false
end

local function MemberKeyFor(frame)
    if not stackFrame or not stackFrame:IsShown() then return nil end
    local settings = Container.GetDB()
    if not settings.enabled then return nil end
    for keyIndex = 1, #MEMBER_KEYS do
        local key = MEMBER_KEYS[keyIndex]
        if settings.attached[key] and frame == FrameFor(key) then return key end
    end
end

local function StackWidthPx(settings)
    if settings.matchAnchorWidth and settings.anchorFrame and settings.anchorFrame ~= '' then
        local target = BUI.ResolveAnchorFrame(settings.anchorFrame, settings.anchorPoint)
        if target and target ~= stackFrame then
            local point = settings.anchorPoint or 'BOTTOM'
            local width
            if point == 'BOTTOM' or point == 'BOTTOMLEFT' or point == 'BOTTOMRIGHT' then
                width = target._bottomRowW or target._topRowW or target._row1W or target:GetWidth()
            else
                width = target._topRowW or target._row1W or target:GetWidth()
            end
            if width and width > 0 then
                if target._castbarIconWidth and target._castbarIconWidth > 0 then width = width + target._castbarIconWidth end
                return width
            end
        end
    end
    return Pixel.Scale(settings.width or 230)
end

function Container.PlaceMember(frame)
    local key = MemberKeyFor(frame)
    if not key then return false end
    local settings = Container.GetDB()
    local y = layoutY[key] or 0

    frame:ClearAllPoints()
    if key == 'castbar' then
        local iconWidth = frame._castbarIconWidth or 0
        if settings.matchWidth then
            frame:SetWidth(math.max(Pixel.Scale(20), StackWidthPx(settings) - iconWidth))
            frame:SetPoint('TOPRIGHT', stackFrame, 'TOPRIGHT', 0, y)
        else
            frame:SetPoint('TOP', stackFrame, 'TOP', iconWidth / 2, y)
        end
    else
        frame:SetPoint('TOP', stackFrame, 'TOP', 0, y)
    end
    frame._anchorTarget = stackFrame
    frame._isAnchored = true
    return true
end

function Container.GetMemberWidth(frame)
    local key = MemberKeyFor(frame)
    if not key then return nil end
    local settings = Container.GetDB()
    if not settings.matchWidth then return nil end
    return StackWidthPx(settings)
end

function IsActive(key, settings)
    local frame = FrameFor(key)
    if not frame then return false end
    if key == 'castbar' then
        local castbarSettings = CastbarSettings()
        if not castbarSettings or not castbarSettings.enabled then return false end
        if settings.castbarMode == 'hold' then return true end
        return frame:IsShown()
    end
    return frame:IsShown()
end

local function MemberHeight(key, settings)
    local frame = FrameFor(key)
    if key == 'castbar' and not frame:IsShown() then
        local castbarSettings = CastbarSettings()
        return castbarSettings and Pixel.ScaleEven(castbarSettings.height) or 0
    end
    return frame:GetHeight()
end

local function MemberBorderPx(key)
    local size
    if key == 'castbar' then
        local castbarSettings = CastbarSettings()
        size = castbarSettings and castbarSettings.borderSize
    elseif key == 'secondary' then
        size = BUI.Power.GetSecondaryDB().borderSize
    else
        size = BUI.Power.GetPrimaryDB().borderSize
    end
    return Pixel.Scale(Pixel.ClampBorder(size or 1))
end

local function LayoutPass(settings, gap, skipCastbar, slots)
    local y, count = 0, 0
    local prevKey, castbarIndex
    for _, key in ipairs(settings.order) do
        if settings.attached[key] and IsActive(key, settings) and not (skipCastbar and key == 'castbar') then
            if count > 0 and gap == 0 then
                y = y - math.min(MemberBorderPx(prevKey), MemberBorderPx(key))
            end
            if slots then slots[key] = -y end
            y = y + MemberHeight(key, settings) + gap
            count = count + 1
            prevKey = key
            if key == 'castbar' then castbarIndex = count end
        elseif slots and settings.attached[key] and FrameFor(key) then
            slots[key] = -y
        end
    end
    if count > 0 then y = y - gap end
    return y, count, castbarIndex
end

local function MemberVisualWidth(key)
    local frame = FrameFor(key)
    local width = frame:GetWidth()
    if key == 'castbar' then width = width + (frame._castbarIconWidth or 0) end
    return width
end

local function OnMemberVisibility()
    if not Container.IsEnabled() then return end
    if relaying then Container.QueueRelayout() else Container.Relayout() end
end

local function HookMembers()
    for keyIndex = 1, #MEMBER_KEYS do
        local frame = FrameFor(MEMBER_KEYS[keyIndex])
        if frame and not hooked[frame] then
            hooked[frame] = true
            HookScript(frame, 'OnShow', OnMemberVisibility)
            HookScript(frame, 'OnHide', OnMemberVisibility)
            HookScript(frame, 'OnSizeChanged', function() Container.QueueRelayout() end)
        end
    end
end

local function EnsureStackFrame()
    if stackFrame then
        stackFrame:Show()
        return
    end
    stackFrame = CreateFrame('Frame', 'BUI_StackLab', UIParent)
    stackFrame:SetSize(Pixel.Scale(230), Pixel.Scale(30))
    stackFrame:SetFrameStrata('LOW')

    BUI.Dragging.MakeDraggable(stackFrame, {
        showHint = true,
        showUnlockedBg = true,
        hintAnchor = 'TOP',
        isLocked = function()
            return Container.GetDB().locked
        end,
        onPositionChanged = function(x, y)
            local settings = Container.GetDB()
            if settings.centerHorizontally then
                local _, centerY = BUI.Dragging.GetCenterOffset(stackFrame)
                x, y = 0, centerY
            end
            if transientEdge == 'top' then
                y = y - (lastFullHeight - lastCollapsedHeight) / 2
            elseif transientEdge == 'bottom' or transientEdge == 'middle' then
                y = y + (lastFullHeight - lastCollapsedHeight) / 2
            end
            settings.posX, settings.posY = x, y
            PositionStack(settings)
        end,
        onRightClick = function() Container.SetLocked(true) end,
        usePointPosition = true,
    })
end

function PositionStack(settings)
    if not stackFrame then return end
    if settings.anchorFrame and settings.anchorFrame ~= '' then
        local point = settings.anchorPoint or 'BOTTOM'
        local pinned = (point:find('TOP') and 'BOTTOM') or (point:find('BOTTOM') and 'TOP') or 'CENTER'
        local delta = lastFullHeight - lastCollapsedHeight
        local extraY = 0
        if delta > 0 and transientEdge and pinned == 'CENTER' then
            if transientEdge == 'top' then
                extraY = delta / 2
            elseif transientEdge == 'bottom' then
                extraY = -delta / 2
            end
        end
        if extraY ~= 0 then
            local proxy = setmetatable({
                anchorOffsetY = (settings.anchorOffsetY or 0) + extraY,
            }, { __index = settings })
            BUI.Anchor.ApplyPosition(stackFrame, proxy)
        else
            BUI.Anchor.ApplyPosition(stackFrame, settings)
        end
        return
    end
    local x = Pixel.Scale(settings.centerHorizontally and 0 or (settings.posX or 0))
    local yCenter = Pixel.Scale(settings.posY or 0)
    stackFrame:ClearAllPoints()
    if transientEdge == 'top' then
        stackFrame:SetPoint('BOTTOM', UIParent, 'CENTER', x, yCenter - lastCollapsedHeight / 2)
    elseif transientEdge == 'bottom' or transientEdge == 'middle' then
        stackFrame:SetPoint('TOP', UIParent, 'CENTER', x, yCenter + lastCollapsedHeight / 2)
    else
        stackFrame:SetPoint('CENTER', UIParent, 'CENTER', x, yCenter)
    end
    stackFrame._anchorTarget = nil
    stackFrame._isAnchored = false
end

function Container.Relayout()
    local settings = Container.GetDB()
    if not settings.enabled then
        if stackFrame then stackFrame:Hide() end
        return
    end
    if relaying then
        Container.QueueRelayout()
        return
    end
    relaying = true
    EnsureStackFrame()
    HookMembers()

    local gap = Pixel.Scale(settings.gap or 0)
    wipe(layoutY)
    local y, count, castbarIndex = LayoutPass(settings, gap, false, layoutY)

    lastFullHeight = count > 0 and math.max(y, 1) or Pixel.Scale(20)
    lastCollapsedHeight = lastFullHeight
    transientEdge = nil
    if castbarIndex and settings.castbarMode ~= 'hold' and count > 1 then
        transientEdge = (castbarIndex == 1 and 'top') or (castbarIndex == count and 'bottom') or 'middle'
        local collapsedHeight = LayoutPass(settings, gap, true, nil)
        lastCollapsedHeight = math.max(collapsedHeight, 1)
    end

    local width
    if settings.matchWidth or (settings.matchAnchorWidth and settings.anchorFrame and settings.anchorFrame ~= '') then
        width = StackWidthPx(settings)
    else
        width = 0
        for key in pairs(layoutY) do
            width = math.max(width, MemberVisualWidth(key))
        end
    end

    stackFrame:SetSize(math.max(width, Pixel.Scale(20)), lastFullHeight)
    PositionStack(settings)

    for key in pairs(layoutY) do
        Container.PlaceMember(FrameFor(key))
    end

    local signature = ('%.1f:%.1f'):format(width, y)
    for _, key in ipairs(settings.order) do
        signature = signature .. ':' .. key .. '=' .. (layoutY[key] and ('%.1f'):format(layoutY[key]) or 'x')
    end
    relaying = false
    if signature ~= lastLayoutSignature then
        lastLayoutSignature = signature
        BUI.Anchor.OnAnchorSizeChanged()
    end
end

function Container.QueueRelayout()
    if not queueFrame then
        queueFrame = CreateFrame('Frame')
        queueFrame:Hide()
        SetScript(queueFrame, 'OnUpdate', function(self)
            self:Hide()
            Container.Relayout()
        end)
    end
    queueFrame:Show()
end

local function ApplyCastbar()
    local UF = BUI.UnitFrames
    if UF.player then
        BUI.CastBar.ApplyCastbar(UF.player, 'player')
    end
end

function RestyleMembers()
    BUI.Power.Primary.Apply()
    BUI.Power.Secondary.Apply()
    ApplyCastbar()
end

function Container.ApplyAll()
    local settings = Container.GetDB()
    if not settings.enabled then return end
    EnsureStackFrame()
    RestyleMembers()
    Container.Relayout()
end

function Container.SetEnabled(on)
    local settings = Container.GetDB()
    lastLayoutSignature = nil
    if on then
        if BUI.Power.Stack.IsEnabled() then
            BUI.Power.Stack.SetEnabled(false)
            BUI.Print('Classic Power Stacking disabled.')
        end
        settings.enabled = true
        Container.ApplyAll()
    else
        settings.enabled = false
        if stackFrame then stackFrame:Hide() end
        RestyleMembers()
        BUI.Anchor.OnAnchorSizeChanged()
    end
end

function Container.HasMember(key)
    local settings = Container.GetDB()
    return (settings.enabled and settings.attached[key]) or false
end

function Container.SetLocked(locked)
    local settings = Container.GetDB()
    settings.locked = locked
    if stackFrame then BUI.Dragging.SetLocked(stackFrame, locked) end
    if Container._lockToggle and Container._lockToggle.SetValue then
        Container._lockToggle:SetValue(not locked)
    end
end

local function MigrateClassicStack()
    local Stack = BUI.Power.Stack
    if not Stack.IsEnabled() then return end
    local oldDB = Stack.GetDB()
    local settings = Container.GetDB()

    local order = { 'primary', 'secondary' }
    if oldDB.order and oldDB.order[1] == 'secondary' then order = { 'secondary', 'primary' } end
    order[3] = 'castbar'
    settings.order = order
    settings.attached = { primary = true, secondary = true, castbar = false }
    settings.gap = oldDB.gap or 0
    settings.matchWidth = oldDB.matchAnchorWidth ~= false
    settings.width = BUI.Power.GetPrimaryDB().barWidth or settings.width or 230

    if oldDB.anchorFrame and oldDB.anchorFrame ~= '' then
        settings.anchorFrame = oldDB.anchorFrame
        settings.anchorPoint = oldDB.anchorPoint or 'TOP'
        settings.anchorOffsetX = oldDB.anchorOffsetX or 0
        settings.anchorOffsetY = oldDB.anchorOffsetY or 0
        settings.centerHorizontally = false
    else
        local count, sumX, sumY = 0, 0, 0
        for _, frameName in ipairs({ 'BUI_PowerBar', 'BUI_SecondaryPower' }) do
            local frame = _G[frameName]
            if frame and frame:IsShown() then
                local x, y = BUI.Dragging.GetCenterOffset(frame)
                if x then count, sumX, sumY = count + 1, sumX + x, sumY + y end
            end
        end
        settings.anchorFrame = ''
        if count > 0 then
            settings.centerHorizontally = false
            settings.posX, settings.posY = sumX / count, sumY / count
        end
    end

    Stack.SetEnabled(false)
    settings.enabled = true
    BUI.Print('Power Stacking migrated to the container stack.')
end

BUI.Events:OnLogin('StackLab', function()
    BUI.Anchor.RegisterCallback('StackLab', function()
        local settings = Container.GetDB()
        if settings.enabled and stackFrame and settings.anchorFrame and settings.anchorFrame ~= '' then
            Container.QueueRelayout()
        end
    end)

    local function RequestRelayout()
        if Container.IsEnabled() or (stackFrame and stackFrame:IsShown()) then
            Container.QueueRelayout()
        end
    end
    BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'StackLab', function(_, unit)
        if unit and unit ~= 'player' then return end
        RequestRelayout()
    end)
    BUI.Events:Register('UPDATE_SHAPESHIFT_FORM', 'StackLab', RequestRelayout)
    BUI.Events:Register('UPDATE_SHAPESHIFT_FORMS', 'StackLab', RequestRelayout)
    BUI.Events:RegisterUnit('UNIT_DISPLAYPOWER', 'player', 'StackLab', RequestRelayout)

    BUI.Prof.After('Power.Container', 0.3, function()
        MigrateClassicStack()
        if Container.IsEnabled() then Container.ApplyAll() end
    end)
end)
