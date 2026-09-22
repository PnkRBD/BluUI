local _, BUI = ...

local ipairs = ipairs

BUI.Power.Stack = {}
local Stack = BUI.Power.Stack

local MEMBERS = {
    {
        key = 'primary', tag = 'BUI_PowerBar',
        getDB = function() return BUI.Power.GetPrimaryDB() end,
        apply = function() BUI.Power.Primary.Apply() end,
    },
    {
        key = 'secondary', tag = 'BUI_SecondaryPower',
        getDB = function() return BUI.Power.GetSecondaryDB() end,
        apply = function() BUI.Power.Secondary.Apply() end,
    },
}
local TAG_TO_KEY = {}
for _, member in ipairs(MEMBERS) do TAG_TO_KEY[member.tag] = member.key end

local function MemberByKey(key)
    for _, member in ipairs(MEMBERS) do
        if member.key == key then return member end
    end
end

function Stack.TagToKey(tag) return TAG_TO_KEY[tag] end

function Stack.GetDB()
    local db = BUI.Power.GetPrimaryDB()
    if not db.stack then
        db.stack = { enabled = false, anchorFrame = '', anchorPoint = 'TOP', gap = 0, order = { 'primary', 'secondary' }, matchAnchorWidth = true }
    end
    if not db.stack.order then db.stack.order = { 'primary', 'secondary' } end
    return db.stack
end

function Stack.IsEnabled()
    return Stack.GetDB().enabled
end

function Stack.IsMemberActive(key)
    if key == 'primary' then
        local db = BUI.Power.GetPrimaryDB()
        if BUI.ClassPowers.IsPrimaryHiddenForForm() then return false end
        return db.enabled and db.source ~= 'none'
    end
    local db = BUI.Power.GetSecondaryDB()
    return db.enabled and BUI.Power.Secondary.HasSecondary()
end

function Stack.GetFirstAvailableFrame(anchorPoint)
    local fallback
    local function Pick(frame)
        if not frame then return nil end
        if frame:IsShown() then return frame end
        fallback = fallback or frame
        return nil
    end
    local settings = Stack.GetDB()
    if settings.enabled then
        local order = settings.order
        if anchorPoint and anchorPoint:find('BOTTOM') then
            for orderIndex = #order, 1, -1 do
                local member = MemberByKey(order[orderIndex])
                local frame = Pick(member and _G[member.tag])
                if frame then return frame end
            end
        else
            for orderIndex = 1, #order do
                local member = MemberByKey(order[orderIndex])
                local frame = Pick(member and _G[member.tag])
                if frame then return frame end
            end
        end
    end
    for _, member in ipairs(MEMBERS) do
        local frame = Pick(_G[member.tag])
        if frame then return frame end
    end
    return fallback
end

function Stack.HasMember(key)
    local settings = Stack.GetDB()
    if not settings.enabled or not Stack.IsMemberActive(key) then return false end
    for _, orderedKey in ipairs(settings.order) do
        if orderedKey == key then return true end
    end
    return false
end

local function ForceBarModes()
    BUI.Power.GetPrimaryDB().barMode = true
    local secondaryDB = BUI.Power.GetSecondaryDB()
    local config = BUI.Power.Secondary.GetDisplayConfig()
    if config and config.prefix then
        if config.mode == 'bar' then
            secondaryDB[config.prefix .. 'BarMode'] = true
        else
            secondaryDB[config.prefix .. 'NumberOnly'] = false
        end
    end
end

local function SetMemberAnchor(memberDB, frameName, point, offsetX, offsetY, flush, matchWidth)
    memberDB.anchorFrame = frameName
    memberDB.anchorPoint = point
    memberDB.anchorOffsetX = offsetX
    memberDB.anchorOffsetY = offsetY
    memberDB.centerHorizontally = false
    memberDB.matchAnchorWidth = matchWidth
    memberDB.noGap = flush or nil
    memberDB.scaleOffsets = flush and false or nil
end

local function CaptureCenter(tag)
    local frame = _G[tag]
    if not frame or not frame:IsShown() then return nil, nil end
    return BUI.Dragging.GetCenterOffset(frame)
end

local function ClearMemberAnchor(memberDB)
    memberDB.anchorFrame = ''
    memberDB.anchorPoint = nil
    memberDB.anchorOffsetX = nil
    memberDB.anchorOffsetY = nil
    memberDB.centerHorizontally = false
    memberDB.matchAnchorWidth = nil
    memberDB.noGap = nil
    memberDB.scaleOffsets = nil
    memberDB.stackFlushEdge = nil
end

local SNAPSHOT_FIELDS = {
    'anchorFrame', 'anchorPoint', 'anchorOffsetX', 'anchorOffsetY',
    'centerHorizontally', 'matchAnchorWidth', 'noGap', 'scaleOffsets',
    'stackFlushEdge', 'posX', 'posY',
}

local function SnapshotMembers(settings)
    settings.preStack = {}
    for _, member in ipairs(MEMBERS) do
        local memberDB, snapshot = member.getDB(), {}
        for _, field in ipairs(SNAPSHOT_FIELDS) do snapshot[field] = memberDB[field] end
        settings.preStack[member.key] = snapshot
    end
end

local function RestoreMembers(settings)
    if not settings.preStack then return false end
    for _, member in ipairs(MEMBERS) do
        local snapshot = settings.preStack[member.key]
        if snapshot then
            local memberDB = member.getDB()
            for _, field in ipairs(SNAPSHOT_FIELDS) do memberDB[field] = snapshot[field] end
        end
    end
    settings.preStack = nil
    return true
end

local function ApplyMembers()
    local settings = Stack.GetDB()
    if not settings.enabled then return end

    local point = settings.anchorPoint or 'TOP'
    local growUp = not point:find('BOTTOM')
    local matchWidth = (settings.matchAnchorWidth ~= false) and true or nil

    local active = {}
    for _, key in ipairs(settings.order) do
        if Stack.IsMemberActive(key) then active[#active + 1] = key end
    end

    local sequence = {}
    if growUp then
        for activeIndex = #active, 1, -1 do sequence[#sequence + 1] = active[activeIndex] end
    else
        for activeIndex = 1, #active do sequence[#sequence + 1] = active[activeIndex] end
    end

    local baseKey = (not settings.anchorFrame or settings.anchorFrame == '') and sequence[1] or nil
    if baseKey then
        if settings.baseMember and settings.baseMember ~= baseKey then
            local oldBase, newBase = MemberByKey(settings.baseMember), MemberByKey(baseKey)
            if oldBase and newBase then
                local oldBaseDB, newBaseDB = oldBase.getDB(), newBase.getDB()
                newBaseDB.posX, newBaseDB.posY = oldBaseDB.posX, oldBaseDB.posY
                newBaseDB.centerHorizontally = oldBaseDB.centerHorizontally
            end
        end
        settings.baseMember = baseKey
    else
        settings.baseMember = nil
    end

    local previousFrameName = settings.anchorFrame
    local first = true
    for _, key in ipairs(sequence) do
        local member = MemberByKey(key)
        local memberDB = member.getDB()
        if previousFrameName and previousFrameName ~= '' then
            if first then
                memberDB.stackFlushEdge = nil
                SetMemberAnchor(memberDB, previousFrameName, point, settings.anchorOffsetX or 0, settings.anchorOffsetY or 0, false, matchWidth)
            else
                local gap = settings.gap or 0
                local edge = BUI.Pixel.Scale(BUI.Pixel.ClampBorder(memberDB.borderSize or 1))
                local offsetY = (gap == 0) and -edge or gap
                memberDB.stackFlushEdge = nil
                SetMemberAnchor(memberDB, previousFrameName, point, 0, growUp and offsetY or -offsetY, true, matchWidth)
            end
        else
            memberDB.stackFlushEdge = nil
            memberDB.anchorFrame = ''
            memberDB.matchAnchorWidth = nil
            memberDB.noGap = nil
            memberDB.scaleOffsets = nil
        end
        previousFrameName = member.tag
        first = false
        member.apply()
    end
end

function Stack.Apply()
    ApplyMembers()
    BUI.Anchor.OnAnchorSizeChanged()
end

function Stack.SetEnabled(on)
    local settings = Stack.GetDB()
    if on then
        if not settings.enabled then SnapshotMembers(settings) end
        settings.enabled = true
        settings.anchorOffsetX, settings.anchorOffsetY = 0, 0
        ForceBarModes()
        Stack.Apply()
    else
        settings.enabled = false
        settings.baseMember = nil

        if not RestoreMembers(settings) then
            local primaryX, primaryY = CaptureCenter('BUI_PowerBar')
            local secondaryX, secondaryY = CaptureCenter('BUI_SecondaryPower')
            local primaryDB = BUI.Power.GetPrimaryDB()
            local secondaryDB = BUI.Power.GetSecondaryDB()
            ClearMemberAnchor(primaryDB)
            ClearMemberAnchor(secondaryDB)
            if primaryX then primaryDB.posX, primaryDB.posY = primaryX, primaryY end
            if secondaryX then secondaryDB.posX, secondaryDB.posY = secondaryX, secondaryY end
        end

        BUI.Power.Primary.Apply()
        BUI.Power.Secondary.Apply()

        BUI.Anchor.OnAnchorSizeChanged()
    end
end

function Stack.OnMemberToggled()
    if Stack.IsEnabled() then Stack.Apply() end
end

BUI.Events:OnLogin('PowerStack', function()
    BUI.Anchor.RegisterCallback('PowerStack', function()
        if Stack.IsEnabled() then ApplyMembers() end
    end)

    local function Reapply()
        if Stack.IsEnabled() then Stack.Apply() end
    end
    BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'PowerStack', function(_, unit)
        if unit and unit ~= 'player' then return end
        Reapply()
    end)
    BUI.Events:Register('PLAYER_TALENT_UPDATE', 'PowerStack', Reapply)
    BUI.Events:RegisterUnit('UNIT_DISPLAYPOWER', 'player', 'PowerStack', Reapply)

    if Stack.IsEnabled() then Stack.Apply() end
end)

BUI.RegisterModuleControl('power', function()
    BUI.Power.Primary.Apply()
    BUI.Power.Secondary.Apply()
    if Stack.IsEnabled() then Stack.Apply() end
end)
