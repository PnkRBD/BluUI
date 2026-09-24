local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Controls, Layout, Modals = BUILib.Controls, BUILib.Layout, BUILib.Modals
local Widget = BUILib.Widget

local PowerType = Enum.PowerType
local POWER_SOURCE_ITEMS = {
    { value = 'auto',                          text = 'Automatic' },
    { value = PowerType.Mana,       text = 'Mana' },
    { value = PowerType.Rage,       text = 'Rage' },
    { value = PowerType.Focus,      text = 'Focus' },
    { value = PowerType.Energy,     text = 'Energy' },
    { value = PowerType.RunicPower, text = 'Runic Power' },
    { value = PowerType.LunarPower, text = 'Astral Power' },
    { value = PowerType.Maelstrom,  text = 'Maelstrom' },
    { value = PowerType.Insanity,   text = 'Insanity' },
    { value = PowerType.Fury,       text = 'Fury' },
    { value = PowerType.Pain,       text = 'Pain' },
}

local POWER_NAME_BY_VALUE = {}
for _, sourceItem in ipairs(POWER_SOURCE_ITEMS) do
    if type(sourceItem.value) == 'number' then POWER_NAME_BY_VALUE[sourceItem.value] = sourceItem.text end
end

local function BuildSourceItems(autoLabel, includeNone)
    local items = {}
    for itemIndex, sourceItem in ipairs(POWER_SOURCE_ITEMS) do
        items[itemIndex] = { value = sourceItem.value, text = sourceItem.text }
    end
    items[1].text = autoLabel and ('Automatic (' .. autoLabel .. ')') or 'Automatic'
    if includeNone then items[#items + 1] = { value = 'none', text = 'None (Off)' } end
    return items
end

local sourceAutoRefreshers = {}

local function RefreshSourceLabels()
    for _, refreshLabel in pairs(sourceAutoRefreshers) do refreshLabel() end
end

local function RefreshSourceLabelsIfShown()
    local engine = BUI.PageEngine
    if engine.frame and engine.frame:IsShown() then RefreshSourceLabels() end
end

local function RegisterSourceLabelRefresh(key, refresh)
    sourceAutoRefreshers[key] = refresh
    BUI.Events:OnTalentBurst('Pages.PowerSourceLabels', RefreshSourceLabels)
    BUI.Events:Register('UPDATE_SHAPESHIFT_FORM', 'Pages.PowerSourceLabels', RefreshSourceLabelsIfShown)
end

local DRUID_FORM_POWER_ITEMS = {
    { value = 'auto',                    text = 'Auto' },
    { value = 'none',                    text = 'None' },
    { value = PowerType.Mana,       text = 'Mana' },
    { value = PowerType.Rage,       text = 'Rage' },
    { value = PowerType.Energy,     text = 'Energy' },
    { value = PowerType.LunarPower, text = 'Astral Power' },
}

local DRUID_FORMS = {
    { label = 'Human Form',   form = 0 },
    { label = 'Bear Form',    form = 5 },
    { label = 'Cat Form',     form = 1 },
    { label = 'Travel Form',  form = 3 },
    { label = 'Moonkin Form', form = 31 },
}

local DRUID_SECONDARY_ITEMS = {
    { value = 'auto',       text = 'Auto' },
    { value = 'none',       text = 'None' },
    { value = 'combo',      text = 'Combo Points' },
    { value = 'casterMana', text = 'Mana' },
}

local DRUID_POWER_NAME = {}
for _, powerItem in ipairs(DRUID_FORM_POWER_ITEMS) do
    if type(powerItem.value) == 'number' then DRUID_POWER_NAME[powerItem.value] = powerItem.text end
end

local function CloneItemsWithAuto(baseItems, autoText)
    local items = {}
    for itemIndex, baseItem in ipairs(baseItems) do items[itemIndex] = { value = baseItem.value, text = baseItem.text } end
    items[1].text = 'Auto (' .. autoText .. ')'
    return items
end

local function DruidAutoSecondaryName(form)
    if form == 1 then return 'Combo Points' end
    if BUI.ClassPowers.IsBalance() then return 'Mana' end
    return 'None'
end

local POWER_SCOPE_ITEMS = {
    { value = 'profile', text = 'Full Profile' },
    { value = 'class',   text = 'Per Class' },
    { value = 'spec',    text = 'Per Spec' },
}

local function StrataOption(db, apply)
    return { kind = 'dropdown', label = 'Strata', items = BUI.C.STRATA_OPTIONS, controlWidth = 120,
        get = function() return db.textStrata or 'HIGH' end,
        set = function(value) db.textStrata = value; apply() end }
end

local DbRGB = BUILib.PageKit.DbRGB
local DbRGBA = BUILib.PageKit.DbRGBA

local function ResourceColorSwatch(parent, db, config, applyFn, label)
    local colorKey = BUI.Colors.ResourceKey(config)
    local store = colorKey and BUI.Colors.GetStore()
    local storedColor = store and store[colorKey]
    if not storedColor then return DbRGB(parent, db, config.prefix .. 'Color', applyFn, label) end
    return Controls.ColorSwatch(parent, { r = storedColor.r, g = storedColor.g, b = storedColor.b, a = 1, callback = function(red, green, blue)
        storedColor.r, storedColor.g, storedColor.b = red, green, blue; applyFn()
    end, tooltip = label })
end

local function AddTickMarkRow(sections, db, applyFn)
    if not db.tickMarks then db.tickMarks = {} end
    sections:Add({
        spanFull = true,
        title = 'Tick Marks',
        description = 'Click the track to add a marker, drag markers to move them.',
        plain = true,
        accessoryWidth = 350,
        accessories = function(row)
            local editor = Controls.TickEditor(row, {
                get = function() return db.tickMarks end,
                color = function()
                    local markColor = db.tickMarkColor or {1, 1, 1, 0.6}
                    return markColor[1], markColor[2], markColor[3], markColor[4]
                end,
                width = function() return db.tickMarkWidth or 1 end,
                onChange = applyFn,
            })
            local tickColor = db.tickMarkColor or {1, 1, 1, 0.6}
            local colorSwatch = Controls.ColorSwatch(row, { r = tickColor[1], g = tickColor[2], b = tickColor[3], a = tickColor[4],
                tooltip = 'Tick color',
                callback = function(red, green, blue, alpha)
                    db.tickMarkColor = {red, green, blue, alpha}; applyFn(); editor:Refresh()
                end })
            local settingsIcon = Controls.Icon(row, {
                title = 'TICKS', tooltip = 'Tick settings',
                options = {
                    { kind = 'slider', label = 'Tick Width', min = 1, max = 4, step = 1,
                      get = function() return db.tickMarkWidth or 1 end,
                      set = function(value) db.tickMarkWidth = value; applyFn(); editor:Refresh() end },
                },
            })
            local clearButton = Controls.Icon(row, {
                texture = BUILib.GetLibMedia('clear'), tooltip = 'Clear all tick marks',
                onClick = function()
                    wipe(db.tickMarks); applyFn(); editor:Refresh()
                end,
            })
            return { clearButton, settingsIcon, colorSwatch, editor }
        end,
    })
end

local function LockAnchorCardIfStacked(card, selfTag)
    local memberKey = BUI.Power.Stack.TagToKey(selfTag)
    if not memberKey then return end
    local Widget = BUILib.Widget
    local frame = Widget.Unwrap(card)
    local function IsStackedMember()
        if BUI.Power.Stack.HasMember(memberKey) then return true end
        return BUI.Power.Container.HasMember(memberKey) or false
    end
    local function refresh()
        if not IsStackedMember() then
            if frame._lockedOverlay then frame._lockedOverlay:Hide() end
            return
        end
        local overlay, text = Widget.AttachLockOverlay(frame, { nonGridPad = 0 })
        text:SetText('STACKED')
        overlay:Show()
        overlay:SetScript('OnEnter', function(overlayFrame) Widget.ShowTip(overlayFrame, 'Position is set by Stacking. Detach the bar to edit it.') end)
        overlay:SetScript('OnLeave', function() Widget.HideTip() end)
    end
    refresh()
    if not frame._buiStackLockHook then
        frame._buiStackLockHook = true
        frame:HookScript('OnShow', refresh)
    end
end

local function RowSections(tab)
    local sections = { grids = {} }
    local grid
    function sections:Section(title)
        if grid then grid:Flush() end
        Layout.Section(tab, title)
        grid = BUILib.PageKit.RowGrid(tab)
        self.grids[#self.grids + 1] = grid
    end
    function sections:Add(config)
        return grid:Add(config)
    end
    function sections:Flush()
        if grid then grid:Flush() end
    end
    function sections:SyncDim(enabled)
        for gridIndex = 1, #self.grids do self.grids[gridIndex]:SyncDim(enabled) end
    end
    return sections
end

local function AddPositionRow(sections, positionDb, applyFn, selfTag)
    sections:Add({
        title = 'Position',
        description = 'Screen position, or anchor to another frame.',
        plain = true,
        accessoryWidth = 36,
        accessories = function(row)
            LockAnchorCardIfStacked(row, selfTag)
            return { BUI.AlertMover(row, positionDb, applyFn, {
                selfTag = selfTag,
                matchWidth = {
                    get = function() return positionDb.matchAnchorWidth == true end,
                    set = function(value) positionDb.matchAnchorWidth = value; C_Timer.After(0.1, applyFn) end,
                },
            }) }
        end,
    })
end

local function AddLowPowerRow(sections, db, applyFn)
    sections:Add({
        spanFull = true,
        title = 'Low Power Color',
        description = 'Warning colors when power drops below the thresholds.',
        checked = db.lowPowerEnabled,
        callback = function(value) db.lowPowerEnabled = value; applyFn() end,
        accessoryWidth = 116,
        accessories = function(row)
            local settingsIcon = BUILib.PageKit.SettingsIcon(row, {
                title = 'LOW POWER COLOR', tooltip = 'Warning thresholds', width = 300,
                options = {
                    { kind = 'slider', label = 'Low Threshold %', min = 5, max = 95, step = 1,
                      get = function() return db.lowPowerThreshold or 30 end,
                      set = function(value) db.lowPowerThreshold = value; applyFn() end },
                    { kind = 'slider', label = 'High Threshold %', min = 5, max = 95, step = 1,
                      get = function() return db.highPowerThreshold or 70 end,
                      set = function(value) db.highPowerThreshold = value; applyFn() end },
                },
            })
            local mediumSwatch = DbRGB(row, db, 'medPowerColor', applyFn, 'Medium')
            local lowSwatch = DbRGB(row, db, 'lowPowerColor', applyFn, 'Low')
            return { settingsIcon, mediumSwatch, lowSwatch }
        end,
    })
end

local previewRefresh
local secondaryEditConfig
local powerSelectedTab = 'general'

local UpdateScopeBadge

local function ScopeInfo()
    local scope = BUI.Power.GetScope()
    if scope == 'spec' then
        local specIndex = GetSpecialization()
        local _, name = GetSpecializationInfo(specIndex or 0)
        return scope, 'PER SPEC', name
    elseif scope == 'class' then
        local name = UnitClass('player')
        return scope, 'PER CLASS', name
    end
    return scope, 'FULL PROFILE', nil
end

local function ScopeStatusText()
    local scope, _, detail = ScopeInfo()
    if scope == 'spec' then
        return ('Applies to %s only - other specs keep their own setup.'):format(detail or 'this spec')
    elseif scope == 'class' then
        return ('Applies to every %s on this profile.'):format(detail or 'class')
    end
    return 'Applies to every character on this profile.'
end

local function MakeScopeDropdown(parent)
    local currentScope = BUI.Power.GetScope()
    local dropdown = Controls.Dropdown(parent, nil, POWER_SCOPE_ITEMS, currentScope, function(value)
        BUI.Power.SetScope(value)
        UpdateScopeBadge()
        BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
    end, 'Where Power settings are saved: shared across the profile, or a separate set per spec / per class.', 220)
    dropdown.frame._noGridStretch = true
    return dropdown
end

local function BuildPowerPreview(parent)
    local Pixel = BUI.Pixel
    local WHITE = 'Interface\\Buttons\\WHITE8x8'
    local FILL = 0.7
    local kind = 'primary'
    local kindProvider

    local function PreviewFont()
        return kind == 'primary' and BUI.GetPowerFont() or BUI.GetSecondaryPowerFont()
    end

    local card, stage = BUILib.PageKit.PreviewStage(parent)

    local EVENT_KEY = 'Pages.PowerPreview'
    local POLL_KEY = 'PowerPagePreview'

    local function ResolveSecondaryConfig()
        local SecondaryPower = BUI.Power.Secondary
        local settings = BUI.Power.GetSecondaryDB()
        local config = SecondaryPower.GetActiveConfig()
        local previewId = SecondaryPower.GetEditPreview()
        if previewId and secondaryEditConfig and secondaryEditConfig.id == previewId then config = secondaryEditConfig end
        if settings.source == 'none' then config = nil end
        return config, settings
    end

    local function StackedSecondaryOn()
        if BUI.Power.Container.IsEnabled() then return BUI.Power.Container.HasMember('secondary') end
        return BUI.Power.Stack.IsEnabled() and BUI.Power.Stack.IsMemberActive('secondary')
    end

    local function NeedsPoll()
        local config
        if kind == 'secondary' then
            config = ResolveSecondaryConfig()
        elseif kind == 'general' and StackedSecondaryOn() then
            config = BUI.Power.Secondary.GetDisplayConfig()
        end
        return (config and config.trigger and (not config.check or config.check())) and true or false
    end

    local pollActive = false
    local function SyncPoll(shouldPoll)
        shouldPoll = (shouldPoll and card:IsVisible()) and true or false
        if shouldPoll == pollActive then return end
        pollActive = shouldPoll
        if shouldPoll then
            BUI.Scheduler.RegisterUpdate(POLL_KEY, function() card:UpdatePreview() end, 0.2, true)
        else
            BUI.Scheduler.UnregisterUpdate(POLL_KEY)
        end
    end

    local QueueUpdate = BUI.Dispatcher.New(function()
        if card:IsVisible() then card:UpdatePreview() end
    end, 'Power.Preview')

    card:SetScript('OnShow', function()
        BUI.Events:RegisterUnit('UNIT_POWER_FREQUENT', 'player', EVENT_KEY, QueueUpdate)
        BUI.Events:RegisterUnit('UNIT_POWER_POINT_CHARGE', 'player', EVENT_KEY, QueueUpdate)
        BUI.Events:RegisterUnit('UNIT_MAXPOWER', 'player', EVENT_KEY, QueueUpdate)
        BUI.Events:RegisterUnit('UNIT_DISPLAYPOWER', 'player', EVENT_KEY, QueueUpdate)
        BUI.Events:Register('RUNE_POWER_UPDATE', EVENT_KEY, QueueUpdate)
        QueueUpdate()
    end)
    card:SetScript('OnHide', function()
        BUI.Events:UnregisterAll(EVENT_KEY)
        SyncPoll(false)
    end)

    local bar = CreateFrame('Frame', nil, stage)
    bar:SetPoint('CENTER')
    local barBg = bar:CreateTexture(nil, 'BACKGROUND')
    barBg:SetTexture(WHITE); barBg:SetAllPoints()
    local barFill = bar:CreateTexture(nil, 'ARTWORK')
    barFill:SetTexture(WHITE)
    barFill:SetPoint('TOPLEFT'); barFill:SetPoint('BOTTOMLEFT')
    local barPredict = bar:CreateTexture(nil, 'ARTWORK')
    barPredict:SetTexture(WHITE)
    barPredict:SetPoint('TOPLEFT', barFill, 'TOPRIGHT')
    barPredict:SetPoint('BOTTOMLEFT', barFill, 'BOTTOMRIGHT')
    local barText = bar:CreateFontString(nil, 'OVERLAY')

    local ticks = {}
    local function Tick(tickIndex)
        if not ticks[tickIndex] then
            ticks[tickIndex] = bar:CreateTexture(nil, 'OVERLAY')
            ticks[tickIndex]:SetTexture(WHITE)
        end
        return ticks[tickIndex]
    end

    local bigText = stage:CreateFontString(nil, 'OVERLAY')
    bigText:SetPoint('CENTER')

    local segmentFills, segmentBackgrounds, segmentBorders = {}, {}, {}
    local function Segment(segmentIndex)
        if not segmentFills[segmentIndex] then
            segmentBorders[segmentIndex] = stage:CreateTexture(nil, 'BACKGROUND')
            segmentBorders[segmentIndex]:SetTexture(WHITE)
            segmentBackgrounds[segmentIndex] = stage:CreateTexture(nil, 'BORDER')
            segmentBackgrounds[segmentIndex]:SetTexture(WHITE)
            segmentFills[segmentIndex] = stage:CreateTexture(nil, 'ARTWORK')
            segmentFills[segmentIndex]:SetTexture(WHITE)
        end
        return segmentFills[segmentIndex], segmentBackgrounds[segmentIndex], segmentBorders[segmentIndex]
    end
    local segmentText = stage:CreateFontString(nil, 'OVERLAY')
    local cooldownText = stage:CreateFontString(nil, 'OVERLAY')

    local stackBars = {}
    local function StackBar(barIndex)
        if not stackBars[barIndex] then
            local stackBar = {}
            stackBar.border = stage:CreateTexture(nil, 'BACKGROUND'); stackBar.border:SetTexture(WHITE)
            stackBar.bg = stage:CreateTexture(nil, 'BORDER'); stackBar.bg:SetTexture(WHITE)
            stackBar.fill = stage:CreateTexture(nil, 'ARTWORK'); stackBar.fill:SetTexture(WHITE)
            stackBar.txt = stage:CreateFontString(nil, 'OVERLAY')
            stackBars[barIndex] = stackBar
        end
        return stackBars[barIndex]
    end

    local function HideAll()
        bar:Hide(); bigText:Hide(); segmentText:Hide(); cooldownText:Hide()
        for _, texture in ipairs(segmentFills) do texture:Hide() end
        for _, texture in ipairs(segmentBackgrounds) do texture:Hide() end
        for _, texture in ipairs(segmentBorders) do texture:Hide() end
        for _, stackBar in pairs(stackBars) do stackBar.bg:Hide(); stackBar.fill:Hide(); if stackBar.txt then stackBar.txt:Hide() end; if stackBar.border then stackBar.border:Hide() end end
    end

    local function ShowBar(options)
        bar:SetSize(options.w, options.h)
        local fillWidth = math.max(0.5, options.w * math.min(1, math.max(0, options.frac or FILL)))
        barFill:SetWidth(fillWidth)
        barFill:SetVertexColor(options.r or 1, options.g or 1, options.b or 1, 1)
        local backgroundColor = options.bg or {}
        barBg:SetVertexColor(backgroundColor[1] or 0.1, backgroundColor[2] or 0.1, backgroundColor[3] or 0.1, backgroundColor[4] or 1)
        if options.predict then
            barPredict:SetWidth(math.max(0.5, math.min(options.w - fillWidth, options.w * 0.15)))
            barPredict:SetVertexColor(options.predict[1] or 1, options.predict[2] or 1, options.predict[3] or 1, options.predict[4] or 0.35)
            barPredict:Show()
        else
            barPredict:Hide()
        end
        local tickCount = 0
        if options.ticks then
            local tickColor = options.tickColor or { 1, 1, 1, 0.6 }
            for tickIndex, percent in ipairs(options.ticks) do
                tickCount = tickIndex
                local tick = Tick(tickIndex)
                tick:SetSize(options.tickWidth or 1, options.h)
                tick:ClearAllPoints()
                tick:SetPoint('CENTER', bar, 'LEFT', options.w * (percent / 100), 0)
                tick:SetVertexColor(tickColor[1] or 1, tickColor[2] or 1, tickColor[3] or 1, tickColor[4] or 0.6)
                tick:Show()
            end
        end
        for tickIndex = tickCount + 1, #ticks do ticks[tickIndex]:Hide() end
        if options.text then
            Pixel.ApplyFont(barText, options.textSize or 14, PreviewFont())
            barText:SetText(options.text)
            barText:SetTextColor(options.tr or 1, options.tg or 1, options.tb or 1, 1)
            barText:ClearAllPoints()
            if options.textAbove then
                barText:SetPoint('BOTTOM', bar, 'TOP', options.textX or 0, 2 + (options.textY or 0))
            else
                barText:SetPoint('CENTER', bar, 'CENTER', options.textX or 0, options.textY or 0)
            end
            barText:Show()
        else
            barText:Hide()
        end
        bar:Show()
    end

    local function ShowText(text, size, red, green, blue, flags)
        Pixel.ApplyFont(bigText, size or 26, PreviewFont(), flags)
        bigText:SetText(text)
        bigText:SetTextColor(red or 1, green or 1, blue or 1, 1)
        bigText:Show()
    end

    local function ShowSegments(totalWidth, segmentCount, height, spacing, backgroundColor, getFillColor, offsetY)
        if not segmentCount or segmentCount < 1 then return 0 end
        offsetY = offsetY or 0
        local db = BUI.Power.GetSecondaryDB()
        local edge = Pixel.ClampBorder(db.borderSize or 1)
        local borderColor = db.borderColor or { 0, 0, 0, 1 }
        local visualGap = spacing == 0 and -edge or spacing
        local segmentWidth = math.max(edge * 2 + 1, (totalWidth - (segmentCount - 1) * spacing) / segmentCount)
        local innerWidth = math.max(0.5, segmentWidth - edge * 2)
        local innerHeight = math.max(0.5, height - edge * 2)
        local rowWidth = segmentCount * segmentWidth + (segmentCount - 1) * visualGap
        local x = -rowWidth / 2
        for segmentIndex = 1, segmentCount do
            local fillTexture, backgroundTexture, borderTexture = Segment(segmentIndex)
            borderTexture:SetSize(segmentWidth, height)
            borderTexture:ClearAllPoints()
            borderTexture:SetPoint('LEFT', stage, 'CENTER', x, offsetY)
            borderTexture:SetVertexColor(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderColor[4] or 1)
            borderTexture:Show()
            backgroundTexture:SetSize(innerWidth, innerHeight)
            backgroundTexture:ClearAllPoints()
            backgroundTexture:SetPoint('LEFT', stage, 'CENTER', x + edge, offsetY)
            backgroundTexture:SetVertexColor(backgroundColor[1] or 0.15, backgroundColor[2] or 0.15, backgroundColor[3] or 0.15, backgroundColor[4] or 1)
            backgroundTexture:Show()
            local red, green, blue, alpha, fraction = getFillColor(segmentIndex)
            fillTexture:SetSize(math.max(0.5, innerWidth * math.min(1, fraction or 1)), innerHeight)
            fillTexture:ClearAllPoints()
            fillTexture:SetPoint('LEFT', stage, 'CENTER', x + edge, offsetY)
            fillTexture:SetVertexColor(red or 1, green or 1, blue or 1, alpha or 1)
            fillTexture:Show()
            x = x + segmentWidth + visualGap
        end
        return segmentWidth
    end

    local function FormatBarValue(settings, prefix, value, percent)
        local showValue = settings[prefix .. 'ShowValue'] ~= false
        local showPercent = settings[prefix .. 'ShowPercent'] == true
        if showPercent then return percent .. '%' end
        if showValue then return tostring(value) end
        return nil
    end

    local function SecondaryTextColor(settings, config)
        if settings.useClassColor then
            return BUI.Power.Secondary.GetResourceColor(config)
        elseif config.id == 'runes' then
            return settings.runeTextColorR or 1, settings.runeTextColorG or 1, settings.runeTextColorB or 1
        elseif config.id == 'stagger' then
            return settings.staggerTextColorR or 1, settings.staggerTextColorG or 1, settings.staggerTextColorB or 1
        end
        local prefix = config.prefix
        local resourceRed, resourceGreen, resourceBlue = BUI.Power.Secondary.GetResourceColor(config)
        return settings[prefix .. 'TextColorR'] or resourceRed, settings[prefix .. 'TextColorG'] or resourceGreen, settings[prefix .. 'TextColorB'] or resourceBlue
    end

    local function LowPowerTint(settings, percent, red, green, blue)
        if percent < (settings.lowPowerThreshold or 30) then
            return settings.lowPowerColorR or 1, settings.lowPowerColorG or 0.2, settings.lowPowerColorB or 0.2
        elseif percent < (settings.highPowerThreshold or 70) then
            return settings.medPowerColorR or 1, settings.medPowerColorG or 1, settings.medPowerColorB or 0.2
        end
        return red, green, blue
    end

    local SafeNum = BUI.Tools.SafeNum
    local function LiveValue(config)
        if config.check and not config.check() then return nil, nil end
        local value, maxValue
        if config.getValue then
            value, maxValue = config.getValue()
        elseif config.power then
            value, maxValue = UnitPower('player', config.power), UnitPowerMax('player', config.power)
        end
        return SafeNum(value), SafeNum(maxValue)
    end

    local function ShowStacked()
        local Stack = BUI.Power.Stack
        local Container = BUI.Power.Container
        local containerDb = Container.IsEnabled() and Container.GetDB() or nil
        local stackDb = Stack.GetDB()
        local order = (containerDb and containerDb.order) or (stackDb and stackDb.order) or { 'primary', 'secondary' }
        local gap = (containerDb and containerDb.gap) or (stackDb and stackDb.gap) or 0

        local primaryDb = BUI.Power.GetPrimaryDB()
        local secondaryDb = BUI.Power.GetSecondaryDB()
        local SecondaryPower = BUI.Power.Secondary
        local config = SecondaryPower.GetDisplayConfig()

        local function MemberOn(memberKey)
            if containerDb then
                if not containerDb.attached[memberKey] then return false end
                if memberKey == 'castbar' then
                    local castbarSettings = BUI.CastBar.GetSettings('player')
                    return (castbarSettings and castbarSettings.enabled) and true or false
                end
            elseif memberKey == 'castbar' then
                return false
            end
            return Stack.IsMemberActive(memberKey) or false
        end

        local members = {}
        for _, memberKey in ipairs(order) do
            if MemberOn(memberKey) then
                if memberKey == 'castbar' then
                    local castbarSettings = BUI.CastBar.GetSettings('player')
                    members[#members + 1] = {
                        w = castbarSettings.width or 200, h = castbarSettings.height or 18,
                        r = 1, g = 0.72, b = 0.2, frac = 0.55,
                        bg = { 0.12, 0.12, 0.12, 1 },
                        text = 'Cast',
                    }
                elseif memberKey == 'primary' then
                    local powerType, isMana = BUI.ClassPowers.GetPrimaryPowerType()
                    if isMana then powerType = Enum.PowerType.Mana end
                    local powerRed, powerGreen, powerBlue = primaryDb.barColorR or 1, primaryDb.barColorG or 1, primaryDb.barColorB or 1
                    if primaryDb.classColorPower then
                        local classColor = RAID_CLASS_COLORS[select(2, UnitClass('player'))]
                        if classColor then powerRed, powerGreen, powerBlue = classColor.r, classColor.g, classColor.b end
                    else
                        local colorKey = BUI.Colors.PowerKey(powerType)
                        if colorKey then powerRed, powerGreen, powerBlue = BUI.Colors.Get(colorKey) end
                    end
                    local powerCurrent, powerMax = SafeNum(UnitPower('player', powerType)), SafeNum(UnitPowerMax('player', powerType))
                    if not (powerCurrent and powerMax and powerMax > 0) then powerCurrent, powerMax = 70, 100 end
                    local powerFraction = powerCurrent / powerMax
                    local powerPercent = math.floor(powerFraction * 100 + 0.5)
                    members[#members + 1] = {
                        w = primaryDb.barWidth or 200, h = primaryDb.barHeight or 16,
                        r = powerRed, g = powerGreen, b = powerBlue, frac = powerFraction,
                        bg = { primaryDb.barBgColorR or 0.12, primaryDb.barBgColorG or 0.12, primaryDb.barBgColorB or 0.12, 1 },
                        text = isMana and ((primaryDb.hidePercentSign and tostring(powerPercent)) or (powerPercent .. '%')) or tostring(powerCurrent),
                    }
                elseif config then
                    local secondaryRed, secondaryGreen, secondaryBlue = SecondaryPower.GetBarColor(config)
                    local prefix = config.prefix
                    local secondaryCurrent, secondaryMax = LiveValue(config)
                    if config.mode == 'bar' then
                        if not (secondaryCurrent and secondaryMax and secondaryMax > 0) then secondaryCurrent, secondaryMax = 60, 100 end
                        members[#members + 1] = {
                            w = secondaryDb[prefix .. 'BarWidth'] or 200, h = secondaryDb[prefix .. 'BarHeight'] or 16,
                            r = secondaryRed, g = secondaryGreen, b = secondaryBlue, frac = secondaryCurrent / secondaryMax,
                            bg = { secondaryDb[prefix .. 'BgColorR'] or 0.12, secondaryDb[prefix .. 'BgColorG'] or 0.12, secondaryDb[prefix .. 'BgColorB'] or 0.12, 1 },
                            text = FormatBarValue(secondaryDb, prefix, secondaryCurrent, math.floor((secondaryCurrent / secondaryMax) * 100 + 0.5)) or '',
                        }
                    else
                        secondaryMax = SafeNum(secondaryMax) or config.max or 5
                        if secondaryMax < 1 then secondaryMax = config.max or 5 end
                        secondaryCurrent = SafeNum(secondaryCurrent) or math.ceil(secondaryMax * 0.6)
                        local isRunes = config.id == 'runes'
                        members[#members + 1] = {
                            segments = true, n = secondaryMax, cur = secondaryCurrent,
                            w = (isRunes and secondaryDb.runeTotalWidth or secondaryDb[prefix .. 'TotalWidth']) or 200,
                            h = (isRunes and secondaryDb.runeHeight or secondaryDb[prefix .. 'Height']) or 12,
                            spacing = (isRunes and secondaryDb.runeSpacing or secondaryDb[prefix .. 'Spacing']) or 2,
                            r = secondaryRed, g = secondaryGreen, b = secondaryBlue,
                            bg = { secondaryDb[prefix .. 'BgColorR'] or 0.12, secondaryDb[prefix .. 'BgColorG'] or 0.12, secondaryDb[prefix .. 'BgColorB'] or 0.12, 1 },
                        }
                    end
                end
            end
        end

        if #members == 0 then
            ShowText('NO ACTIVE BARS', 26, 0.45, 0.45, 0.5, 'THICKOUTLINE')
            return
        end

        if containerDb then
            if containerDb.matchWidth then
                for _, member in ipairs(members) do member.w = containerDb.width or 230 end
            end
        elseif stackDb and stackDb.matchAnchorWidth ~= false then
            local matchedWidth
            if stackDb.anchorFrame and stackDb.anchorFrame ~= '' then
                local anchorTarget = BUI.ResolveAnchorFrame(stackDb.anchorFrame, stackDb.anchorPoint)
                matchedWidth = anchorTarget and anchorTarget.GetWidth and anchorTarget:GetWidth()
                if matchedWidth then matchedWidth = math.min(matchedWidth, 700) end
            else
                local anchorPoint = stackDb.anchorPoint or 'TOP'
                local baseMember = anchorPoint:find('BOTTOM') and members[1] or members[#members]
                matchedWidth = baseMember and baseMember.w
            end
            if not matchedWidth or matchedWidth <= 0 then
                matchedWidth = 0
                for _, member in ipairs(members) do matchedWidth = math.max(matchedWidth, member.w) end
            end
            for _, member in ipairs(members) do member.w = matchedWidth end
        end

        local edge = Pixel.Scale(1)
        local totalHeight = -gap
        for memberIndex = 1, #members do totalHeight = totalHeight + members[memberIndex].h + gap end
        local yTop = totalHeight / 2
        for memberIndex, member in ipairs(members) do
            local y = yTop - member.h / 2
            if member.segments then
                ShowSegments(member.w, member.n, member.h, member.spacing, member.bg,
                    function(segmentIndex)
                        if segmentIndex <= member.cur then return member.r, member.g, member.b end
                        return 0, 0, 0, 0
                    end, y)
                Pixel.ApplyFont(segmentText, 10, PreviewFont())
                segmentText:SetText(tostring(member.cur))
                segmentText:SetTextColor(1, 1, 1, 1)
                segmentText:ClearAllPoints()
                segmentText:SetPoint('CENTER', stage, 'CENTER', 0, y)
                segmentText:Show()
            else
                local stackBar = StackBar(memberIndex)
                stackBar.border:SetSize(member.w, member.h)
                stackBar.border:ClearAllPoints()
                stackBar.border:SetPoint('CENTER', stage, 'CENTER', 0, y)
                stackBar.border:SetVertexColor(0, 0, 0, 1)
                stackBar.border:Show()
                stackBar.bg:SetSize(member.w - 2 * edge, member.h - 2 * edge)
                stackBar.bg:ClearAllPoints()
                stackBar.bg:SetPoint('CENTER', stackBar.border, 'CENTER', 0, 0)
                stackBar.bg:SetVertexColor(member.bg[1], member.bg[2], member.bg[3], member.bg[4])
                stackBar.bg:Show()
                stackBar.fill:SetSize(math.max(1, (member.w - 2 * edge) * math.min(1, member.frac)), member.h - 2 * edge)
                stackBar.fill:ClearAllPoints()
                stackBar.fill:SetPoint('LEFT', stackBar.bg, 'LEFT', 0, 0)
                stackBar.fill:SetVertexColor(member.r, member.g, member.b, 1)
                stackBar.fill:Show()
                Pixel.ApplyFont(stackBar.txt, 10, PreviewFont())
                stackBar.txt:SetText(member.text)
                stackBar.txt:SetTextColor(1, 1, 1, 1)
                stackBar.txt:ClearAllPoints()
                stackBar.txt:SetPoint('CENTER', stackBar.border, 'CENTER', 0, 0)
                stackBar.txt:Show()
            end
            yTop = yTop - member.h - gap
        end
    end

    function card:SetKind(newKind) kind = newKind; card:UpdatePreview() end

    function card:SetKindProvider(provider) kindProvider = provider end

    function card:UpdatePreview()
        if kindProvider then kind = kindProvider() end
        SyncPoll(NeedsPoll())
        HideAll()
        if kind == 'general' and (BUI.Power.Container.IsEnabled() or BUI.Power.Stack.IsEnabled()) then
            ShowStacked()
            return
        end
        if kind == 'primary' or kind == 'general' then
            local primaryDb = BUI.Power.GetPrimaryDB()
            local powerType, isMana = BUI.ClassPowers.GetPrimaryPowerType()
            if isMana then powerType = Enum.PowerType.Mana end
            local current, maxValue = SafeNum(UnitPower('player', powerType)), SafeNum(UnitPowerMax('player', powerType))
            if not (current and maxValue and maxValue > 0) then current, maxValue = 70, 100 end
            local fraction = current / maxValue
            local percent = math.floor(fraction * 100 + 0.5)

            local valueText = isMana and ((primaryDb.hidePercentSign and tostring(percent)) or (percent .. '%')) or tostring(current)
            if primaryDb.barMode then
                local red, green, blue = primaryDb.barColorR or 1, primaryDb.barColorG or 1, primaryDb.barColorB or 1
                if primaryDb.classColorPower then
                    local classColor = RAID_CLASS_COLORS[select(2, UnitClass('player'))]
                    if classColor then red, green, blue = classColor.r, classColor.g, classColor.b end
                else
                    local colorKey = BUI.Colors.PowerKey(powerType)
                    if colorKey then red, green, blue = BUI.Colors.Get(colorKey) end
                end
                if primaryDb.lowPowerEnabled then red, green, blue = LowPowerTint(primaryDb, percent, red, green, blue) end
                ShowBar({
                    w = primaryDb.barWidth or 200, h = primaryDb.barHeight or 16, frac = fraction, r = red, g = green, b = blue,
                    bg = { primaryDb.barBgColorR, primaryDb.barBgColorG, primaryDb.barBgColorB, primaryDb.barBgColorA },
                    text = (not primaryDb.barHideText) and valueText or nil, textSize = primaryDb.barTextSize,
                    tr = primaryDb.barTextColorR, tg = primaryDb.barTextColorG, tb = primaryDb.barTextColorB,
                    textX = primaryDb.barTextOffsetX, textY = primaryDb.barTextOffsetY, textAbove = primaryDb.barTextAbove,
                    ticks = primaryDb.tickMarks, tickColor = primaryDb.tickMarkColor, tickWidth = primaryDb.tickMarkWidth,
                    predict = (primaryDb.showPrediction ~= false) and { primaryDb.predictionColorR, primaryDb.predictionColorG, primaryDb.predictionColorB, primaryDb.predictionColorA } or nil,
                })
            else
                local red, green, blue = primaryDb.textColorR or 1, primaryDb.textColorG or 1, primaryDb.textColorB or 1
                if primaryDb.lowPowerEnabled then red, green, blue = LowPowerTint(primaryDb, percent, red, green, blue) end
                ShowText(valueText, primaryDb.textSize, red, green, blue)
            end
        else
            local SecondaryPower = BUI.Power.Secondary
            local config, settings = ResolveSecondaryConfig()
            if not config then
                ShowText('NO SECONDARY POWER', 32, 0.45, 0.45, 0.5, 'THICKOUTLINE')
            elseif config.id == 'runes' then
                local readyRunes, maxRunes = LiveValue(config)
                maxRunes = maxRunes or 6
                readyRunes = readyRunes or math.ceil(maxRunes * 0.6)
                if settings.runeNumberOnly then
                    local red, green, blue = SecondaryTextColor(settings, config)
                    ShowText(settings.runeShowMax and (readyRunes .. '/' .. maxRunes) or tostring(readyRunes), settings.runeTextSize, red, green, blue)
                else
                    local spacing = settings.runeSpacing or 0
                    local segmentWidth = ShowSegments(settings.runeTotalWidth or 240, maxRunes, settings.runeHeight or 12, spacing,
                        { settings.runeBgColorR, settings.runeBgColorG, settings.runeBgColorB, settings.runeBgColorA },
                        function(segmentIndex)
                            if segmentIndex <= readyRunes then return settings.runeColorR, settings.runeColorG, settings.runeColorB end
                            return settings.runeRechargingColorR or 0.5, settings.runeRechargingColorG or 0.5, settings.runeRechargingColorB or 1, 1, 0.55
                        end)
                    if settings.showRuneCooldown and readyRunes < maxRunes then
                        Pixel.ApplyFont(cooldownText, settings.runeCooldownSize or 10, PreviewFont())
                        cooldownText:SetText('3.4')
                        cooldownText:SetTextColor(settings.runeCooldownColorR or 1, settings.runeCooldownColorG or 1, settings.runeCooldownColorB or 1, 1)
                        cooldownText:ClearAllPoints()
                        cooldownText:SetPoint('CENTER', stage, 'CENTER', -(settings.runeTotalWidth or 240) / 2 + readyRunes * (segmentWidth + spacing) + segmentWidth / 2, 0)
                        cooldownText:Show()
                    end
                end
            elseif config.id == 'stagger' then
                local percent = 25
                local value = 188
                if not config.check or config.check() then
                    local liveValue, livePercent = config.getValue()
                    percent = SafeNum(livePercent) or 25
                    value = SafeNum(liveValue) or 188
                end

                local roundedPercent = math.floor(percent + 0.5)
                local percentText = roundedPercent .. '%'
                local valueText
                if settings.staggerShowValue ~= false and settings.staggerShowPercent ~= false then
                    valueText = value .. ' (' .. percentText .. ')'
                elseif settings.staggerShowPercent ~= false then
                    valueText = percentText
                elseif settings.staggerShowValue ~= false then
                    valueText = tostring(value)
                end
                if settings.staggerBarMode then
                    local red, green, blue
                    if percent >= 60 then
                        red, green, blue = settings.staggerHeavyColorR or 1, settings.staggerHeavyColorG or 0.2, settings.staggerHeavyColorB or 0.2
                    elseif percent >= 30 then
                        red, green, blue = settings.staggerModerateColorR or 1, settings.staggerModerateColorG or 0.6, settings.staggerModerateColorB or 0
                    else
                        red, green, blue = settings.staggerLightColorR or 0.2, settings.staggerLightColorG or 0.8, settings.staggerLightColorB or 0.2
                    end
                    ShowBar({
                        w = settings.staggerBarWidth or 200, h = settings.staggerBarHeight or 16, frac = percent / 100,
                        r = red, g = green, b = blue,
                        bg = { settings.staggerBgColorR, settings.staggerBgColorG, settings.staggerBgColorB, settings.staggerBgColorA },
                        text = (not settings.staggerHideBarText) and valueText or nil, textSize = settings.staggerValueSize,
                        tr = settings.staggerValueColorR, tg = settings.staggerValueColorG, tb = settings.staggerValueColorB,
                        textX = settings.staggerValueOffsetX, textY = settings.staggerValueOffsetY,
                        ticks = settings.tickMarks, tickColor = settings.tickMarkColor, tickWidth = settings.tickMarkWidth,
                    })
                else
                    local red, green, blue = SecondaryTextColor(settings, config)
                    ShowText(valueText or '', settings.textSize, red, green, blue)
                end
            elseif config.mode == 'bar' then
                local prefix = config.prefix
                local value, maxValue = LiveValue(config)
                if not (value and maxValue and maxValue > 0) then value, maxValue = 70, 100 end
                local fraction = value / maxValue
                local percent = math.floor(fraction * 100 + 0.5)
                local valueText = FormatBarValue(settings, prefix, value, percent)
                if settings[prefix .. 'BarMode'] then
                    local red, green, blue = SecondaryPower.GetBarColor(config)

                    if settings.lowPowerEnabled and config.power then
                        red, green, blue = LowPowerTint(settings, percent, red, green, blue)
                    end
                    ShowBar({
                        w = settings[prefix .. 'BarWidth'] or 200, h = settings[prefix .. 'BarHeight'] or 16, frac = fraction,
                        r = red, g = green, b = blue,
                        bg = { settings[prefix .. 'BgColorR'], settings[prefix .. 'BgColorG'], settings[prefix .. 'BgColorB'], settings[prefix .. 'BgColorA'] },
                        text = (not settings[prefix .. 'HideBarText']) and valueText or nil, textSize = settings[prefix .. 'ValueSize'],
                        tr = settings[prefix .. 'ValueColorR'], tg = settings[prefix .. 'ValueColorG'], tb = settings[prefix .. 'ValueColorB'],
                        textX = settings[prefix .. 'ValueOffsetX'], textY = settings[prefix .. 'ValueOffsetY'],
                        ticks = settings.tickMarks, tickColor = settings.tickMarkColor, tickWidth = settings.tickMarkWidth,
                    })
                else
                    local red, green, blue = SecondaryTextColor(settings, config)
                    ShowText(valueText or '', settings.textSize, red, green, blue)
                end
            else
                local prefix = config.prefix
                local value, maxValue = LiveValue(config)
                maxValue = maxValue or config.max or 5
                value = value or math.ceil(maxValue * 0.6)
                if settings[prefix .. 'NumberOnly'] then
                    local red, green, blue = SecondaryTextColor(settings, config)
                    ShowText(settings[prefix .. 'ShowMax'] and (value .. '/' .. maxValue) or tostring(value), settings.textSize, red, green, blue)
                else

                    local chargedSet
                    if config.id == 'combo' and (not config.check or config.check()) then
                        local charged = GetUnitChargedPowerPoints('player')
                        if charged and #charged > 0 then
                            chargedSet = {}
                            for chargedIndex = 1, #charged do chargedSet[charged[chargedIndex]] = true end
                        end
                    end
                    local fillRed, fillGreen, fillBlue = SecondaryPower.GetBarColor(config)
                    ShowSegments(settings[prefix .. 'TotalWidth'] or 200, maxValue, settings[prefix .. 'Height'] or 12, settings[prefix .. 'Spacing'] or 0,
                        { settings[prefix .. 'BgColorR'], settings[prefix .. 'BgColorG'], settings[prefix .. 'BgColorB'], settings[prefix .. 'BgColorA'] },
                        function(segmentIndex)
                            if chargedSet and chargedSet[segmentIndex] and segmentIndex <= value then
                                return settings[prefix .. 'ChargedColorR'] or 0.96, settings[prefix .. 'ChargedColorG'] or 0.55, settings[prefix .. 'ChargedColorB'] or 0.73
                            elseif segmentIndex <= value then
                                return fillRed, fillGreen, fillBlue
                            end
                            return 0, 0, 0, 0
                        end)

                    if not settings[prefix .. 'HideBarText'] then
                        Pixel.ApplyFont(segmentText, settings[prefix .. 'CenterTextSize'] or 14, PreviewFont())
                        segmentText:SetText(value)
                        segmentText:SetTextColor(settings[prefix .. 'ValueColorR'] or 1, settings[prefix .. 'ValueColorG'] or 1, settings[prefix .. 'ValueColorB'] or 1, 1)
                        segmentText:ClearAllPoints()
                        segmentText:SetPoint('CENTER', stage, 'CENTER', settings[prefix .. 'ValueOffsetX'] or 0, settings[prefix .. 'ValueOffsetY'] or 0)
                        segmentText:Show()
                    end
                end
            end
        end
    end

    card:UpdatePreview()
    return card
end

local function AddDruidFormRows(sections, db, Apply)
    sections:Section('Druid Forms')
    for _, formDef in ipairs(DRUID_FORMS) do
        local form = formDef.form
        local autoName = DRUID_POWER_NAME[BUI.ClassPowers.GetDruidAutoPowerForForm(form)] or 'Mana'
        local items = CloneItemsWithAuto(DRUID_FORM_POWER_ITEMS, autoName)
        local currentValue = (db.formPowerOverrides and db.formPowerOverrides[form]) or 'auto'
        sections:Add({
            title = formDef.label,
            description = 'Power shown in this form.',
            controlWidth = 170,
            control = function(row)
                return Controls.Dropdown(row, nil, items, currentValue, function(value)
                    db.formPowerOverrides = db.formPowerOverrides or {}
                    db.formPowerOverrides[form] = (value ~= 'auto') and value or nil
                    Apply()
                    BUI.Power.Stack.OnMemberToggled()
                end, 'Which power the primary bar shows in this form (Auto = the built-in default; None hides it).', 160)
            end,
        })
    end
end

local function AddDruidSecondaryRows(sections, db, Apply)
    sections:Section('Druid Forms')
    for _, formDef in ipairs(DRUID_FORMS) do
        local form = formDef.form
        local items = CloneItemsWithAuto(DRUID_SECONDARY_ITEMS, DruidAutoSecondaryName(form))
        local currentValue = (db.formOverrides and db.formOverrides[form]) or 'auto'
        sections:Add({
            title = formDef.label,
            description = 'Resource shown in this form.',
            controlWidth = 190,
            control = function(row)
                return Controls.Dropdown(row, nil, items, currentValue, function(value)
                    db.formOverrides = db.formOverrides or {}
                    db.formOverrides[form] = (value ~= 'auto') and value or nil
                    Apply()
                    BUI.Power.Stack.OnMemberToggled()
                end, 'Which secondary resource this form shows (Auto = the built-in default; None hides it).', 180)
            end,
        })
    end
end

local function BuildPrimaryTab(tab)
    local PrimaryPower = BUI.Power.Primary
    local PageKit = BUILib.PageKit
    local db = BUI.Power.GetPrimaryDB()
    local Apply = function() PrimaryPower.Apply(); previewRefresh() end
    local function Rebuild()
        BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
    end
    local sections = RowSections(tab)
    local positionDb = BUI.Anchor.ModePos(db, not db.barMode)

    sections:Section('General')

    local function PrimaryAutoLabel()
        local autoType = BUI.ClassPowers.GetAutoPowerType()
        return autoType and POWER_NAME_BY_VALUE[autoType]
    end
    sections:Add({
        spanFull = true,
        title = 'Source',
        description = 'Which power the bar tracks.',
        controlWidth = 230,
        control = function(row)
            local dropdown = Controls.Dropdown(row, nil, BuildSourceItems(PrimaryAutoLabel(), true), db.source or 'auto', function(value)
                db.source = (value ~= 'auto') and value or nil
                Apply()
                BUI.Power.Stack.OnMemberToggled()
            end, 'Which power the bar tracks (Automatic = your current power; None hides it).', 220)
            RegisterSourceLabelRefresh('primary', function()
                dropdown:SetItems(BuildSourceItems(PrimaryAutoLabel(), true))
            end)
            return dropdown
        end,
    })

    AddPositionRow(sections, positionDb, Apply, 'BUI_PowerBar')

    sections:Add({
        title = 'Bar Mode',
        description = 'Show a power bar instead of a plain number.',
        checked = db.barMode,
        callback = function(value) db.barMode = value; Apply(); Rebuild() end,
    })

    if db.barMode then
        sections:Section('Bar')

        sections:Add({
            title = 'Bar Style',
            description = 'Colors, width and height.',
            plain = true,
            accessoryWidth = 118,
            accessories = function(row)
                local sizeIcon = PageKit.SizeIcon(row, { title = 'BAR SIZE', options = {
                    { kind = 'slider', label = 'Width', min = 50, max = 400, step = 1,
                      get = function() return db.barWidth or 200 end, set = function(value) db.barWidth = value; Apply() end },
                    { kind = 'slider', label = 'Height', min = 4, max = 40, step = 1,
                      get = function() return db.barHeight or 16 end, set = function(value) db.barHeight = value; Apply() end },
                } })
                local barSwatch
                local primaryPowerType = BUI.ClassPowers.GetPrimaryPowerType()
                local colorKey = BUI.Colors.PowerKey(primaryPowerType)
                if colorKey then
                    local colorRed, colorGreen, colorBlue = BUI.Colors.Get(colorKey)
                    barSwatch = Controls.ColorSwatch(row, { r = colorRed, g = colorGreen, b = colorBlue, a = 1, callback = function(red, green, blue)
                        local store = BUI.Colors.GetStore()
                        if store and store[colorKey] then store[colorKey].r, store[colorKey].g, store[colorKey].b = red, green, blue end
                        BUI.ApplyColors()
                        Apply()
                    end, tooltip = 'Bar Color' })
                else
                    barSwatch = DbRGB(row, db, 'barColor', Apply, 'Bar Color')
                end
                local backgroundSwatch = DbRGBA(row, db, 'barBgColor', Apply, 'Background')
                return { sizeIcon, backgroundSwatch, barSwatch }
            end,
        })

        sections:Add({
            title = 'Class Color Power',
            description = 'Color the bar by your class instead of the power type.',
            checked = db.classColorPower,
            callback = function(value) db.classColorPower = value; Apply() end,
        })

        sections:Add({
            title = 'Show Prediction',
            description = 'Preview incoming power while casting.',
            checked = db.showPrediction ~= false,
            callback = function(value) db.showPrediction = value; Apply() end,
            accessoryWidth = 40,
            accessories = function(row)
                return { DbRGBA(row, db, 'predictionColor', Apply, 'Prediction') }
            end,
        })

        AddTickMarkRow(sections, db, Apply)

        sections:Section('Text')

        sections:Add({
            spanFull = true,
            title = 'Bar Text',
            description = 'Power value shown on the bar.',
            checked = not db.barHideText,
            callback = function(value) db.barHideText = not value; Apply() end,
            accessoryWidth = 296,
            accessories = function(row)
                local fontDropdown = Controls.Dropdown(row, nil, BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), BUI.GetDB().general.powerFont or BUI.C.GLOBAL_OPTION, function(value)
                    BUI.GetDB().general.powerFont = value ~= BUI.C.GLOBAL_OPTION and value or nil; Apply()
                end, nil, 160)
                local settingsIcon = PageKit.SettingsIcon(row, { title = 'TEXT', tooltip = 'Text display & style', options = {
                    { label = 'Show % Symbol',
                      get = function() return not db.hidePercentSign end, set = function(value) db.hidePercentSign = not value; Apply() end },
                    { kind = 'slider', label = 'Text Size', min = 8, max = 50, step = 1,
                      get = function() return db.barTextSize or 14 end, set = function(value) db.barTextSize = value; Apply() end },
                    { kind = 'dropdown', label = 'Strata', items = BUI.C.STRATA_OPTIONS, controlWidth = 120,
                      get = function() return db.textStrata or 'MEDIUM' end, set = function(value) db.textStrata = value; Apply() end },
                } })
                local mover = PageKit.OffsetMover(row, {
                    getX = function() return db.barTextOffsetX or 0 end, setX = function(value) db.barTextOffsetX = value; Apply() end,
                    getY = function() return db.barTextOffsetY or 0 end, setY = function(value) db.barTextOffsetY = value; Apply() end,
                })
                local colorSwatch = DbRGB(row, db, 'barTextColor', Apply, 'Text Color')
                return { settingsIcon, mover, colorSwatch, fontDropdown }
            end,
        })

        AddLowPowerRow(sections, db, Apply)
    else
        sections:Section('Text')

        sections:Add({
            spanFull = true,
            title = 'Text Display',
            description = 'Number size, color and font.',
            plain = true,
            accessoryWidth = 250,
            accessories = function(row)
                local fontDropdown = Controls.Dropdown(row, nil, BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), BUI.GetDB().general.powerFont or BUI.C.GLOBAL_OPTION, function(value)
                    BUI.GetDB().general.powerFont = value ~= BUI.C.GLOBAL_OPTION and value or nil; Apply()
                end, nil, 160)
                local settingsIcon = PageKit.SettingsIcon(row, { title = 'TEXT', tooltip = 'Text size & format', options = {
                    { kind = 'slider', label = 'Text Size', min = 10, max = 50, step = 1,
                      get = function() return db.textSize or 26 end, set = function(value) db.textSize = value; Apply() end },
                    { label = 'Show % Symbol',
                      get = function() return not db.hidePercentSign end, set = function(value) db.hidePercentSign = not value; Apply() end },
                    { kind = 'dropdown', label = 'Strata', items = BUI.C.STRATA_OPTIONS, controlWidth = 120,
                      get = function() return db.frameStrata or 'MEDIUM' end, set = function(value) db.frameStrata = value; Apply() end },
                } })
                local colorSwatch = DbRGB(row, db, 'textColor', Apply, 'Text Color')
                return { settingsIcon, colorSwatch, fontDropdown }
            end,
        })

        AddLowPowerRow(sections, db, Apply)
    end

    if BUI.ClassPowers.IsDruid() then
        AddDruidFormRows(sections, db, Apply)
    end

    sections:Flush()
    PrimaryPower._syncDim = function() sections:SyncDim(db.enabled) end
    sections:SyncDim(db.enabled)
end

local function SecondaryFontDropdown(parent)
    return Controls.Dropdown(parent, nil, BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), BUI.GetDB().general.secondaryPowerFont or BUI.C.GLOBAL_OPTION, function(value)
        BUI.GetDB().general.secondaryPowerFont = value ~= BUI.C.GLOBAL_OPTION and value or nil
        BUI.Power.Secondary.UpdateAppearance()
    end, nil, 160)
end

local function BuildSecondaryTab(tab)
    local SecondaryPower = BUI.Power.Secondary
    local PageKit = BUILib.PageKit
    local db = BUI.Power.GetSecondaryDB()
    local Apply = function() SecondaryPower.Apply(); previewRefresh() end
    local function Rebuild()
        BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
    end
    local sections = RowSections(tab)

    local available = SecondaryPower.GetConfigsForClass()
    local config = SecondaryPower.GetActiveConfig() or available[1]
    secondaryEditConfig = config
    SecondaryPower.SetEditPreview((config and SecondaryPower.GetActiveConfig() ~= config and not db.locked) and config.id or nil)

    if config then
        local prefix = config.prefix
        local isBar = config.mode == 'bar'
        local barActive = (isBar and db[prefix .. 'BarMode']) and true or false
        local textActive = false
        if not barActive then
            if config.id == 'runes' then textActive = db.runeNumberOnly and true or false
            elseif isBar then textActive = true
            else textActive = db[prefix .. 'NumberOnly'] and true or false end
        end
        local isBarControls = isBar and config.id ~= 'runes' and config.id ~= 'stagger'
        local hasTickMarks = (isBarControls and db[prefix .. 'BarMode']) and true or false
        local positionDb = BUI.Anchor.ModePos(db, textActive)
        local segmented = config.id == 'runes' or not isBar

        sections:Section('General')

        local function SecondaryAutoLabel()
            for _, candidate in ipairs(available) do
                if candidate.check and candidate.check() then return candidate.label end
            end
        end
        sections:Add({
            spanFull = true,
            title = 'Source',
            description = 'Which resource the secondary bar tracks.',
            controlWidth = 230,
            control = function(row)
                local dropdown = Controls.Dropdown(row, nil, BuildSourceItems(SecondaryAutoLabel() or 'None', true), db.source or 'auto', function(value)
                    db.source = (value ~= 'auto') and value or nil
                    Apply()
                    BUI.Power.Stack.OnMemberToggled()
                    Rebuild()
                end, 'Which resource the secondary bar tracks (Automatic = your class resource; None hides it).', 220)
                RegisterSourceLabelRefresh('secondary', function()
                    dropdown:SetItems(BuildSourceItems(SecondaryAutoLabel() or 'None', true))
                end)
                return dropdown
            end,
        })

        AddPositionRow(sections, positionDb, Apply, 'BUI_SecondaryPower')

        local modeChecked, modeSet
        if config.id == 'runes' then
            modeChecked = not db.runeNumberOnly
            modeSet = function(value) db.runeNumberOnly = not value end
        elseif isBar then
            modeChecked = db[prefix .. 'BarMode'] and true or false
            modeSet = function(value) db[prefix .. 'BarMode'] = value end
        else
            modeChecked = not db[prefix .. 'NumberOnly']
            modeSet = function(value) db[prefix .. 'NumberOnly'] = not value end
        end
        sections:Add({
            title = 'Bar Mode',
            description = segmented and 'Show segments instead of a plain number.'
                or 'Show a bar instead of a plain number.',
            checked = modeChecked,
            callback = function(value) modeSet(value); Apply(); Rebuild() end,
        })

        if not textActive then
            sections:Section(segmented and 'Segments' or 'Bar')

            if config.id == 'runes' then
                sections:Add({
                    title = 'Segment Style',
                    description = 'Colors, size and spacing.',
                    plain = true,
                    accessoryWidth = 150,
                    accessories = function(row)
                        local sizeIcon = PageKit.SizeIcon(row, { title = 'SEGMENTS', options = {
                            { kind = 'slider', label = 'Width', min = 100, max = 400, step = 1,
                              get = function() return db.runeTotalWidth or 240 end, set = function(value) db.runeTotalWidth = value; Apply() end },
                            { kind = 'slider', label = 'Height', min = 4, max = 30, step = 1,
                              get = function() return db.runeHeight or 12 end, set = function(value) db.runeHeight = value; Apply() end },
                            { kind = 'slider', label = 'Spacing', min = 0, max = 20, step = 1,
                              get = function() return db.runeSpacing or 0 end, set = function(value) db.runeSpacing = value; Apply() end },
                        } })
                        local backgroundSwatch = DbRGBA(row, db, 'runeBgColor', Apply, 'Background')
                        local rechargingSwatch = DbRGB(row, db, 'runeRechargingColor', Apply, 'Recharging Color')
                        local readySwatch = DbRGB(row, db, 'runeColor', Apply, 'Ready Color')
                        return { sizeIcon, backgroundSwatch, rechargingSwatch, readySwatch }
                    end,
                })
            elseif config.id == 'stagger' then
                sections:Add({
                    title = 'Bar Style',
                    description = 'Stagger colors, width and height.',
                    plain = true,
                    accessoryWidth = 188,
                    accessories = function(row)
                        local sizeIcon = PageKit.SizeIcon(row, { title = 'BAR SIZE', options = {
                            { kind = 'slider', label = 'Width', min = 50, max = 400, step = 1,
                              get = function() return db.staggerBarWidth or 200 end, set = function(value) db.staggerBarWidth = value; Apply() end },
                            { kind = 'slider', label = 'Height', min = 4, max = 40, step = 1,
                              get = function() return db.staggerBarHeight or 16 end, set = function(value) db.staggerBarHeight = value; Apply() end },
                        } })
                        local backgroundSwatch = DbRGBA(row, db, 'staggerBgColor', Apply, 'Background')
                        local heavySwatch = DbRGB(row, db, 'staggerHeavyColor', Apply, 'Heavy Stagger (60%+)')
                        local moderateSwatch = DbRGB(row, db, 'staggerModerateColor', Apply, 'Moderate (30-60%)')
                        local lightSwatch = DbRGB(row, db, 'staggerLightColor', Apply, 'Light Stagger (0-30%)')
                        return { sizeIcon, backgroundSwatch, heavySwatch, moderateSwatch, lightSwatch }
                    end,
                })
            elseif isBar then
                sections:Add({
                    title = 'Bar Style',
                    description = 'Colors, width and height.',
                    plain = true,
                    accessoryWidth = 118,
                    accessories = function(row)
                        local sizeIcon = PageKit.SizeIcon(row, { title = 'BAR SIZE', options = {
                            { kind = 'slider', label = 'Width', min = 50, max = 400, step = 1,
                              get = function() return db[prefix .. 'BarWidth'] or 200 end, set = function(value) db[prefix .. 'BarWidth'] = value; Apply() end },
                            { kind = 'slider', label = 'Height', min = 4, max = 40, step = 1,
                              get = function() return db[prefix .. 'BarHeight'] or 16 end, set = function(value) db[prefix .. 'BarHeight'] = value; Apply() end },
                        } })
                        local backgroundSwatch = DbRGBA(row, db, prefix .. 'BgColor', Apply, 'Background')
                        local barSwatch = ResourceColorSwatch(row, db, config, Apply, 'Bar Color')
                        return { sizeIcon, backgroundSwatch, barSwatch }
                    end,
                })
            else
                sections:Add({
                    title = 'Segment Style',
                    description = 'Colors, size and spacing.',
                    plain = true,
                    accessoryWidth = prefix == 'combo' and 150 or 118,
                    accessories = function(row)
                        local sizeIcon = PageKit.SizeIcon(row, { title = 'SEGMENTS', options = {
                            { kind = 'slider', label = 'Width', min = 100, max = 400, step = 1,
                              get = function() return db[prefix .. 'TotalWidth'] or 200 end, set = function(value) db[prefix .. 'TotalWidth'] = value; Apply() end },
                            { kind = 'slider', label = 'Height', min = 4, max = 30, step = 1,
                              get = function() return db[prefix .. 'Height'] or 12 end, set = function(value) db[prefix .. 'Height'] = value; Apply() end },
                            { kind = 'slider', label = 'Spacing', min = 0, max = 20, step = 1,
                              get = function() return db[prefix .. 'Spacing'] or 2 end, set = function(value) db[prefix .. 'Spacing'] = value; Apply() end },
                        } })
                        local accessoryList = { sizeIcon, DbRGBA(row, db, prefix .. 'BgColor', Apply, 'Background') }
                        if prefix == 'combo' then
                            accessoryList[#accessoryList + 1] = DbRGB(row, db, 'comboChargedColor', Apply, 'Charged Color')
                        end
                        accessoryList[#accessoryList + 1] = ResourceColorSwatch(row, db, config, Apply, 'Active Color')
                        return accessoryList
                    end,
                })
            end

            if hasTickMarks then AddTickMarkRow(sections, db, Apply) end
        end

        sections:Section('Text')

        if config.id == 'runes' then
            if not db.runeNumberOnly then
                sections:Add({
                    spanFull = true,
                    title = 'Rune Cooldown',
                    description = 'Countdown text on recharging runes.',
                    checked = db.showRuneCooldown,
                    callback = function(value) db.showRuneCooldown = value; Apply() end,
                    accessoryWidth = 250,
                    accessories = function(row)
                        local fontDropdown = SecondaryFontDropdown(row)
                        local settingsIcon = PageKit.SettingsIcon(row, { title = 'TEXT', tooltip = 'Text display & style', options = {
                            { kind = 'slider', label = 'Text Size', min = 6, max = 20, step = 1,
                              get = function() return db.runeCooldownSize or 10 end,
                              set = function(value) db.runeCooldownSize = value; Apply() end },
                            StrataOption(db, Apply),
                        } })
                        local colorSwatch = DbRGB(row, db, 'runeCooldownColor', Apply, 'Text Color')
                        return { settingsIcon, colorSwatch, fontDropdown }
                    end,
                })
            else
                sections:Add({
                    title = 'Class Color',
                    description = 'Color the number by your class.',
                    checked = db.useClassColor ~= false,
                    callback = function(value) db.useClassColor = value; Apply() end,
                })
                sections:Add({
                    spanFull = true,
                    title = 'Display',
                    description = 'Number size, color and font.',
                    plain = true,
                    accessoryWidth = 250,
                    accessories = function(row)
                        local fontDropdown = SecondaryFontDropdown(row)
                        local settingsIcon = PageKit.SettingsIcon(row, { title = 'TEXT', tooltip = 'Text display & style', options = {
                            { label = 'Show Max',
                              get = function() return db.runeShowMax end,
                              set = function(value) db.runeShowMax = value; Apply() end },
                            { kind = 'slider', label = 'Text Size', min = 10, max = 50, step = 1,
                              get = function() return db.runeTextSize or 26 end,
                              set = function(value) db.runeTextSize = value; Apply() end },
                            StrataOption(db, Apply),
                        } })
                        local colorSwatch = DbRGB(row, db, 'runeTextColor', Apply, 'Text Color')
                        return { settingsIcon, colorSwatch, fontDropdown }
                    end,
                })
            end
        elseif config.id == 'stagger' then
            if db.staggerBarMode then
                sections:Add({
                    spanFull = true,
                    title = 'Bar Text',
                    description = 'Stagger value shown on the bar.',
                    checked = not db.staggerHideBarText,
                    callback = function(value) db.staggerHideBarText = not value; Apply() end,
                    accessoryWidth = 296,
                    accessories = function(row)
                        local fontDropdown = SecondaryFontDropdown(row)
                        local settingsIcon = PageKit.SettingsIcon(row, { title = 'TEXT', tooltip = 'Text display & style', options = {
                            { label = 'Show Value',
                              get = function() return db.staggerShowValue ~= false end,
                              set = function(value) db.staggerShowValue = value; Apply() end },
                            { label = 'Show Percent',
                              get = function() return db.staggerShowPercent ~= false end,
                              set = function(value) db.staggerShowPercent = value; Apply() end },
                            { kind = 'slider', label = 'Text Size', min = 8, max = 50, step = 1,
                              get = function() return db.staggerValueSize or 14 end,
                              set = function(value) db.staggerValueSize = value; Apply() end },
                            StrataOption(db, Apply),
                        } })
                        local mover = PageKit.OffsetMover(row, {
                            getX = function() return db.staggerValueOffsetX or 0 end,
                            setX = function(value) db.staggerValueOffsetX = value; Apply() end,
                            getY = function() return db.staggerValueOffsetY or 0 end,
                            setY = function(value) db.staggerValueOffsetY = value; Apply() end,
                        })
                        local colorSwatch = DbRGB(row, db, 'staggerValueColor', Apply, 'Text Color')
                        return { settingsIcon, mover, colorSwatch, fontDropdown }
                    end,
                })
            else
                sections:Add({
                    title = 'Class Color',
                    description = 'Color the text by your class.',
                    checked = db.useClassColor ~= false,
                    callback = function(value) db.useClassColor = value; Apply() end,
                })
                sections:Add({
                    spanFull = true,
                    title = 'Display',
                    description = 'Text size, color and font.',
                    plain = true,
                    accessoryWidth = 250,
                    accessories = function(row)
                        local fontDropdown = SecondaryFontDropdown(row)
                        local settingsIcon = PageKit.SettingsIcon(row, { title = 'TEXT', tooltip = 'Text display & style', options = {
                            { label = 'Show Value',
                              get = function() return db.staggerShowValue ~= false end,
                              set = function(value) db.staggerShowValue = value; Apply() end },
                            { label = 'Show Percent',
                              get = function() return db.staggerShowPercent ~= false end,
                              set = function(value) db.staggerShowPercent = value; Apply() end },
                            { kind = 'slider', label = 'Text Size', min = 10, max = 50, step = 1,
                              get = function() return db.textSize or 26 end,
                              set = function(value) db.textSize = value; Apply() end },
                            StrataOption(db, Apply),
                        } })
                        local colorSwatch = DbRGB(row, db, 'staggerTextColor', Apply, 'Text Color')
                        return { settingsIcon, colorSwatch, fontDropdown }
                    end,
                })
            end
        elseif isBar then
            if db[prefix .. 'BarMode'] then
                sections:Add({
                    spanFull = true,
                    title = 'Bar Text',
                    description = 'Power value shown on the bar.',
                    checked = not db[prefix .. 'HideBarText'],
                    callback = function(value) db[prefix .. 'HideBarText'] = not value; Apply() end,
                    accessoryWidth = 296,
                    accessories = function(row)
                        local fontDropdown = SecondaryFontDropdown(row)
                        local settingsIcon = PageKit.SettingsIcon(row, { title = 'TEXT', tooltip = 'Text display & style', options = {
                            { label = 'Show Percent',
                              get = function() return db[prefix .. 'ShowPercent'] end,
                              set = function(value) db[prefix .. 'ShowPercent'] = value; Apply() end },
                            { label = 'Hide % Sign',
                              get = function() return db[prefix .. 'HidePercentSign'] == true end,
                              set = function(value) db[prefix .. 'HidePercentSign'] = value; Apply() end },
                            { kind = 'slider', label = 'Text Size', min = 8, max = 50, step = 1,
                              get = function() return db[prefix .. 'ValueSize'] or 14 end,
                              set = function(value) db[prefix .. 'ValueSize'] = value; Apply() end },
                            StrataOption(db, Apply),
                        } })
                        local mover = PageKit.OffsetMover(row, {
                            getX = function() return db[prefix .. 'ValueOffsetX'] or 0 end,
                            setX = function(value) db[prefix .. 'ValueOffsetX'] = value; Apply() end,
                            getY = function() return db[prefix .. 'ValueOffsetY'] or 0 end,
                            setY = function(value) db[prefix .. 'ValueOffsetY'] = value; Apply() end,
                        })
                        local colorSwatch = DbRGB(row, db, prefix .. 'ValueColor', Apply, 'Text Color')
                        return { settingsIcon, mover, colorSwatch, fontDropdown }
                    end,
                })
            else
                sections:Add({
                    title = 'Class Color',
                    description = 'Color the number by your class.',
                    checked = db.useClassColor ~= false,
                    callback = function(value) db.useClassColor = value; Apply() end,
                })
                sections:Add({
                    spanFull = true,
                    title = 'Display',
                    description = 'Number size, color and font.',
                    plain = true,
                    accessoryWidth = 250,
                    accessories = function(row)
                        local fontDropdown = SecondaryFontDropdown(row)
                        local settingsIcon = PageKit.SettingsIcon(row, { title = 'TEXT', tooltip = 'Text display & style', options = {
                            { label = 'Show Percent',
                              get = function() return db[prefix .. 'ShowPercent'] end,
                              set = function(value) db[prefix .. 'ShowPercent'] = value; Apply() end },
                            { kind = 'slider', label = 'Text Size', min = 10, max = 50, step = 1,
                              get = function() return db.textSize or 26 end,
                              set = function(value) db.textSize = value; Apply() end },
                            StrataOption(db, Apply),
                        } })
                        local colorSwatch = DbRGB(row, db, prefix .. 'TextColor', Apply, 'Text Color')
                        return { settingsIcon, colorSwatch, fontDropdown }
                    end,
                })
            end
            AddLowPowerRow(sections, db, Apply)
        else
            if not db[prefix .. 'NumberOnly'] then
                sections:Add({
                    spanFull = true,
                    title = 'Value Text',
                    description = 'Count shown on the segments.',
                    checked = not db[prefix .. 'HideBarText'],
                    callback = function(value) db[prefix .. 'HideBarText'] = not value; Apply() end,
                    accessoryWidth = 296,
                    accessories = function(row)
                        local fontDropdown = SecondaryFontDropdown(row)
                        local settingsIcon = PageKit.SettingsIcon(row, { title = 'TEXT', tooltip = 'Text display & style', options = {
                            { kind = 'slider', label = 'Text Size', min = 8, max = 50, step = 1,
                              get = function() return db[prefix .. 'CenterTextSize'] or 14 end,
                              set = function(value) db[prefix .. 'CenterTextSize'] = value; Apply() end },
                            StrataOption(db, Apply),
                        } })
                        local mover = PageKit.OffsetMover(row, {
                            getX = function() return db[prefix .. 'ValueOffsetX'] or 0 end,
                            setX = function(value) db[prefix .. 'ValueOffsetX'] = value; BUI.Power.Secondary.UpdateAppearance() end,
                            getY = function() return db[prefix .. 'ValueOffsetY'] or 0 end,
                            setY = function(value) db[prefix .. 'ValueOffsetY'] = value; BUI.Power.Secondary.UpdateAppearance() end,
                        })
                        local colorSwatch = DbRGB(row, db, prefix .. 'ValueColor', Apply, 'Text Color')
                        return { settingsIcon, mover, colorSwatch, fontDropdown }
                    end,
                })
            else
                sections:Add({
                    title = 'Class Color',
                    description = 'Color the number by your class resource.',
                    checked = db.useClassColor ~= false,
                    callback = function(value) db.useClassColor = value; Apply() end,
                })
                sections:Add({
                    spanFull = true,
                    title = 'Display',
                    description = 'Number size, color and font.',
                    plain = true,
                    accessoryWidth = 250,
                    accessories = function(row)
                        local fontDropdown = SecondaryFontDropdown(row)
                        local settingsIcon = PageKit.SettingsIcon(row, { title = 'TEXT', tooltip = 'Text display & style', options = {
                            { label = 'Show Max',
                              get = function() return db[prefix .. 'ShowMax'] end,
                              set = function(value) db[prefix .. 'ShowMax'] = value; Apply() end },
                            { kind = 'slider', label = 'Text Size', min = 10, max = 50, step = 1,
                              get = function() return db.textSize or 26 end,
                              set = function(value) db.textSize = value; BUI.Power.Secondary.UpdateAppearance() end },
                            StrataOption(db, Apply),
                        } })
                        local colorSwatch = Controls.ColorSwatch(row, {
                            r = db[prefix .. 'TextColorR'] or db[prefix .. 'ColorR'] or 1,
                            g = db[prefix .. 'TextColorG'] or db[prefix .. 'ColorG'] or 1,
                            b = db[prefix .. 'TextColorB'] or db[prefix .. 'ColorB'] or 1,
                            a = 1,
                            callback = function(red, green, blue)
                                db[prefix .. 'TextColorR'], db[prefix .. 'TextColorG'], db[prefix .. 'TextColorB'] = red, green, blue
                                Apply()
                            end, tooltip = 'Text Color' })
                        return { settingsIcon, colorSwatch, fontDropdown }
                    end,
                })
            end
        end
    end

    if BUI.ClassPowers.IsDruid() then
        AddDruidSecondaryRows(sections, db, Apply)
    end

    sections:Flush()
    SecondaryPower._syncDim = function() sections:SyncDim(db.enabled) end
    sections:SyncDim(db.enabled)
end

local STACK_ORDER_OPTIONS = {
    { value = 'primary,secondary,castbar', text = 'Primary / Secondary / Castbar' },
    { value = 'primary,castbar,secondary', text = 'Primary / Castbar / Secondary' },
    { value = 'secondary,primary,castbar', text = 'Secondary / Primary / Castbar' },
    { value = 'secondary,castbar,primary', text = 'Secondary / Castbar / Primary' },
    { value = 'castbar,primary,secondary', text = 'Castbar / Primary / Secondary' },
    { value = 'castbar,secondary,primary', text = 'Castbar / Secondary / Primary' },
}

local function BuildGeneralTab(tab)
    local Container = BUI.Power.Container
    local settings = Container.GetDB()
    local PageKit = BUILib.PageKit

    local function AddRow(config)
        config.width = tab.width
        local row = Controls.SettingRow(tab.child, config)
        Layout.Add(tab, row, 8)
        return row
    end

    local function StackApply()
        if Container.IsEnabled() then Container.ApplyAll() end
        previewRefresh()
    end

    local STACK_MEMBER_LABELS = { primary = 'Primary Power', secondary = 'Secondary Power' }

    local function TextModeMembers(onlyKey)
        local issues = {}
        if settings.attached.primary and (not onlyKey or onlyKey == 'primary') then
            local primaryDb = BUI.Power.GetPrimaryDB()
            if primaryDb and primaryDb.enabled and primaryDb.source ~= 'none' and not primaryDb.barMode then
                issues[#issues + 1] = 'primary'
            end
        end
        if settings.attached.secondary and (not onlyKey or onlyKey == 'secondary') then
            local secondaryDb = BUI.Power.GetSecondaryDB()
            local SecondaryPower = BUI.Power.Secondary
            local config = SecondaryPower.GetDisplayConfig()
            if secondaryDb and secondaryDb.enabled and config and config.prefix then
                local textMode
                if config.id == 'runes' then
                    textMode = secondaryDb.runeNumberOnly
                elseif config.mode == 'bar' then
                    textMode = not secondaryDb[config.prefix .. 'BarMode']
                else
                    textMode = secondaryDb[config.prefix .. 'NumberOnly']
                end
                if textMode then issues[#issues + 1] = 'secondary' end
            end
        end
        return issues
    end

    local function SwitchToBarMode(issues)
        for _, key in ipairs(issues) do
            if key == 'primary' then
                BUI.Power.GetPrimaryDB().barMode = true
            else
                local secondaryDb = BUI.Power.GetSecondaryDB()
                local SecondaryPower = BUI.Power.Secondary
                local config = SecondaryPower.GetDisplayConfig()
                if config and config.prefix then
                    if config.id == 'runes' then
                        secondaryDb.runeNumberOnly = false
                    elseif config.mode == 'bar' then
                        secondaryDb[config.prefix .. 'BarMode'] = true
                    else
                        secondaryDb[config.prefix .. 'NumberOnly'] = false
                    end
                end
            end
        end
    end

    local function ConfirmBarMode(issues, onConfirm, onCancel)
        local names = {}
        for issueIndex, key in ipairs(issues) do names[issueIndex] = STACK_MEMBER_LABELS[key] end
        local verb = #names > 1 and ' are' or ' is'
        Modals.Confirm({
            parent = BUI.PageEngine.window.frame,
            title = 'Text Mode Doesn\'t Stack',
            message = table.concat(names, ' and ') .. verb .. ' in Text Mode, which can\'t line up in a stack of bars. Switch to Bar Mode and continue?',
            confirmText = 'Use Bar Mode', cancelText = 'Cancel',
            onConfirm = function()
                SwitchToBarMode(issues)
                onConfirm()
                BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
            end,
            onCancel = onCancel,
        })
    end

    Layout.Section(tab, 'General')

    AddRow({
        title = 'Save Power Settings',
        description = 'Shared across the whole profile, or a separate setup per spec or class',
        plain = true,
        accessoryWidth = 240,
        accessories = function(row) return { MakeScopeDropdown(row) } end,
    })

    AddRow({
        title = 'Copy Power Setup',
        description = 'Overwrite this setup with the Power settings saved for another spec or class',
        plain = true,
        accessoryWidth = 320,
        accessories = function(row)
            local items = BUI.Power.ListCopySources()
            if #items == 0 then
                return { Controls.Text(row, 'No other saved setups yet', 11, { 0.65, 0.68, 0.72, 1 }) }
            end
            local selectedSource = items[1].value
            local dropdown = Controls.Dropdown(row, nil, items, selectedSource, function(value) selectedSource = value end, nil, 200)
            dropdown.frame._noGridStretch = true
            local copyButton = Controls.GhostButton(row, 'Copy From', 90, function()
                if not selectedSource then return end
                local sourceText
                for _, item in ipairs(items) do
                    if item.value == selectedSource then sourceText = item.text break end
                end
                local _, _, detail = ScopeInfo()
                Modals.Confirm({
                    parent = BUI.PageEngine.window.frame,
                    title = 'Copy Power Setup',
                    message = ("Overwrite the %s Power setup with the one saved for '%s'?"):format(detail or 'current', sourceText or selectedSource),
                    confirmText = 'Copy', cancelText = 'Cancel',
                    onConfirm = function()
                        if BUI.Power.CopyFrom(selectedSource) then
                            BUI.Print(('Copied Power setup from %s.'):format(sourceText or selectedSource))
                            BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
                        end
                    end,
                })
            end)
            return { copyButton, dropdown }
        end,
    })

    AddRow({
        title = 'Power & Resource Colors',
        description = 'Bar colors for every power type and class resource',
        plain = true,
        accessoryWidth = 60,
        accessories = function(row)
            return { Controls.Icon(row, {
                tooltip = 'Open Appearance > Power & Resources',
                onClick = function() BUI.OpenAppearance('power') end,
            }) }
        end,
    })

    Layout.Section(tab, 'Stacking')

    local stackFrames = {}
    for _, anchorFrame in ipairs(BUI.C.ANCHOR_FRAMES) do
        if anchorFrame.tag ~= 'BUI_PowerBar' and anchorFrame.tag ~= 'BUI_SecondaryPower'
            and anchorFrame.tag ~= 'BUI_Castbar_player' and anchorFrame.tag ~= 'BUI_PowerBarAny' then
            stackFrames[#stackFrames + 1] = anchorFrame
        end
    end

    local stackingRow
    stackingRow = AddRow({
        title = 'Power Stacking',
        description = 'Stack the members below into one container that moves as a unit.',
        checked = settings.enabled,
        callback = function(value)
            if value then
                local issues = TextModeMembers()
                if #issues > 0 then
                    ConfirmBarMode(issues, function()
                        Container.SetEnabled(true)
                        previewRefresh()
                    end, function()
                        stackingRow:SetValue(false)
                    end)
                    return
                end
            end
            Container.SetEnabled(value)
            previewRefresh()
        end,
        accessoryWidth = 120,
        accessories = function(row)
            local unlockToggle = Controls.IconToggle(row, not settings.locked, function(value)
                Container.SetLocked(not value)
            end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Unlock (drag to move)' })
            Container._lockToggle = unlockToggle
            local mover = BUI.AlertMover(row, settings, StackApply, {
                frames = stackFrames,
                unlock = {
                    get = function() return not settings.locked end,
                    set = function(value) Container.SetLocked(not value) end,
                },
                matchWidth = {
                    get = function() return settings.matchAnchorWidth == true end,
                    set = function(value) settings.matchAnchorWidth = value; StackApply() end,
                },
            })
            local settingsIcon = PageKit.SettingsIcon(row, {
                title = 'STACKING', tooltip = 'Width & spacing', options = {
                    { kind = 'slider', label = 'Stack Width', min = 60, max = 600, step = 1,
                      get = function() return settings.width or 230 end,
                      set = function(value) settings.width = value end, apply = StackApply },
                    { kind = 'slider', label = 'Gap', min = -10, max = 40, step = 1,
                      get = function() return settings.gap or 0 end,
                      set = function(value) settings.gap = value end, apply = StackApply },
                },
            })
            return { unlockToggle, mover, settingsIcon }
        end,
    })

    AddRow({
        title = 'Match Member Widths',
        description = 'Resize every attached member to the stack width for one flush column',
        checked = settings.matchWidth,
        callback = function(value) settings.matchWidth = value; StackApply() end,
    })

    Layout.Section(tab, 'Stack Members')

    AddRow({
        title = 'Stack Order',
        description = 'Top-to-bottom order of the members below',
        plain = true,
        accessoryWidth = 250,
        accessories = function(row)
            return { Controls.Dropdown(row, nil, STACK_ORDER_OPTIONS, table.concat(settings.order, ','), function(value)
                local order = {}
                for key in value:gmatch('[^,]+') do order[#order + 1] = key end
                settings.order = order
                StackApply()
            end, nil, 240) }
        end,
    })

    local function AttachMember(key, row, value)
        if value and settings.enabled then
            settings.attached[key] = true
            local issues = TextModeMembers(key)
            if #issues > 0 then
                ConfirmBarMode(issues, StackApply, function()
                    settings.attached[key] = false
                    row:SetValue(false)
                end)
                return
            end
        end
        settings.attached[key] = value
        StackApply()
    end

    local primaryRow
    primaryRow = AddRow({
        title = 'Primary Power Bar',
        description = 'Whatever your spec runs on.',
        checked = settings.attached.primary,
        callback = function(value) AttachMember('primary', primaryRow, value) end,
    })

    local secondaryRow
    secondaryRow = AddRow({
        title = 'Secondary Power Bar',
        description = 'Combo points, holy power, soul shards and other class resources',
        checked = settings.attached.secondary,
        callback = function(value) AttachMember('secondary', secondaryRow, value) end,
    })

    AddRow({
        title = 'Player Castbar',
        description = 'Slot your castbar into the stack.',
        checked = settings.attached.castbar,
        callback = function(value) settings.attached.castbar = value; StackApply() end,
        accessoryWidth = 230,
        accessories = function(row)
            local modeDropdown = Controls.Dropdown(row, nil, {
                { value = 'collapse', text = 'Collapse when not casting' },
                { value = 'hold', text = 'Hold space when not casting' },
            }, settings.castbarMode or 'collapse', function(value)
                settings.castbarMode = value; StackApply()
            end, nil, 220)
            return { modeDropdown }
        end,
    })
end

BUI.PageEngine.RegisterPage("power", {
    title = "Power",
    buttonText = "Power",
    OnHide = function()
        BUI.Power.Secondary.SetEditPreview(nil)
        local Container = BUI.Power.Container
        local containerDb = Container.GetDB()
        if containerDb and not containerDb.locked then Container.SetLocked(true) end
    end,
    OnBuild = function(pageFrame)
        local PageKit = BUILib.PageKit
        local PREVIEW_H = BUILib.Layout.PAGE_PREVIEW_H

        local TABS = {
            { key = 'general',   title = 'GENERAL',   image = 'Interface\\Icons\\INV_Misc_Gear_01',
              db = function() return BUI.Power.GetPrimaryDB() end,    module = function() return nil end,
              build = BuildGeneralTab },
            { key = 'primary',   title = 'PRIMARY',   image = 'Interface\\Icons\\INV_Elemental_Mote_Mana',
              db = function() return BUI.Power.GetPrimaryDB() end,    module = function() return BUI.Power.Primary end,
              build = BuildPrimaryTab },
            { key = 'secondary', title = 'SECONDARY', image = 'Interface\\Icons\\Ability_Rogue_SliceDice',
              db = function() return BUI.Power.GetSecondaryDB() end, module = function() return BUI.Power.Secondary end,
              build = BuildSecondaryTab },
        }
        local selected = powerSelectedTab
        local function SelectedTab()
            for _, tabDef in ipairs(TABS) do if tabDef.key == selected then return tabDef end end
        end

        local preview, titleBar
        local function SyncTitle()
            local tabDef = SelectedTab()
            local db = tabDef and tabDef.db()
            if not db or not titleBar then return end
            local enableFrame = Widget.Unwrap(titleBar.enableToggle)
            local anchorFrame = Widget.Unwrap(titleBar.anchorToggle)
            if tabDef.key == 'general' then
                enableFrame:Hide()
                if titleBar.enableHint then titleBar.enableHint:Hide() end
                anchorFrame:Hide()
                return
            end
            enableFrame:Show()
            titleBar.enableToggle:SetValue(db.enabled)
            titleBar.anchorToggle:SetValue(not db.locked)
            anchorFrame:Show()
        end

        local root, pinned
        root, pinned, titleBar = PageKit.Scaffold(pageFrame, {
            title = 'Power', titleDesc = 'Primary and secondary power bars with anchoring, colors, and tick marks.',
            previewH = PREVIEW_H, watermark = BUI.Tools.GetLogo(),

            titleEnable = { value = BUI.Power.GetPrimaryDB().enabled, gate = function() return BUI.IsModuleEnabled('power') end, onToggle = function(value)
                local tabDef = SelectedTab()
                if tabDef.key == 'general' then return end
                local db, tabModule = tabDef.db(), tabDef.module()
                if not db then return end
                db.enabled = value
                tabModule.Toggle(value); if tabModule._syncDim then tabModule._syncDim() end
                BUI.Power.Stack.OnMemberToggled()
            end },
            titleAnchor = { value = not BUI.Power.GetPrimaryDB().locked, onToggle = function(value)
                local tabDef = SelectedTab()
                if tabDef.key == 'general' then return end
                local db, tabModule = tabDef.db(), tabDef.module()
                if not db then return end
                db.locked = not value
                tabModule.SetLocked(not value)

                if selected == 'secondary' then
                    local SecondaryPower = BUI.Power.Secondary
                    SecondaryPower.SetEditPreview((value and secondaryEditConfig and SecondaryPower.GetActiveConfig() ~= secondaryEditConfig)
                        and secondaryEditConfig.id or nil)
                end
            end },
            hostTabs = {
                defs = TABS, defaultKey = powerSelectedTab,
                onSelect = function(key)
                    selected = key
                    powerSelectedTab = key
                    SyncTitle()
                    if preview then preview:SetKind(key) end

                    local SecondaryPower = BUI.Power.Secondary
                    if key == 'secondary' and secondaryEditConfig and SecondaryPower.GetActiveConfig() ~= secondaryEditConfig
                        and not BUI.Power.GetSecondaryDB().locked then
                        SecondaryPower.SetEditPreview(secondaryEditConfig.id)
                    else
                        SecondaryPower.SetEditPreview(nil)
                    end
                end,
                build = function(tabDef, tab) tabDef.build(tab) end,
            },
        })

        for _, tabDef in ipairs(TABS) do
            local tabModule = tabDef.module()
            if tabModule then
                local key = tabDef.key
                tabModule._lockToggle = { SetValue = function(_, value)
                    if selected == key then titleBar.anchorToggle:SetValue(value) end
                end }
            end
        end

        preview = BuildPowerPreview(pinned)
        previewRefresh = function() preview:UpdatePreview() end
        preview:SetKindProvider(function() return selected end)
        preview:SetKind(selected)

        local badge = CreateFrame('Frame', nil, pinned)
        badge:SetHeight(22)
        badge:SetPoint('TOPLEFT', pinned, 'TOPLEFT', 0, -4)
        badge:SetFrameLevel(pinned:GetFrameLevel() + 20)
        badge:EnableMouse(true)
        badge.rect = Widget.DrawRoundedRect(badge, 5, { 1, 1, 1, 0.07 }, 'BACKGROUND', 0, 0)
        badge.fs = badge:CreateFontString(nil, 'OVERLAY')
        badge.fs:SetFont(BUILib.Font, 10, 'OUTLINE')
        badge.fs:SetPoint('CENTER')
        badge:SetScript('OnEnter', function(self)
            Widget.ShowTip(self, ScopeStatusText() .. '\nChange under General > Settings Scope.')
        end)
        badge:SetScript('OnLeave', function() Widget.HideTip() end)

        UpdateScopeBadge = function()
            local scope, label, detail = ScopeInfo()
            badge.fs:SetText(detail and (label .. '  -  ' .. detail:upper()) or label)
            badge:SetWidth(badge.fs:GetStringWidth() + 24)
            if scope == 'profile' then
                Widget.SetRectColor(badge.rect, 1, 1, 1, 0.07)
                badge.fs:SetTextColor(0.65, 0.68, 0.72, 1)
            else
                local red, green, blue = BUILib.Theme.GetAccent()
                Widget.SetRectColor(badge.rect, red, green, blue, 0.16)
                badge.fs:SetTextColor(red, green, blue, 1)
            end
        end
        UpdateScopeBadge()

        pageFrame:SetScript('OnShow', function()
            SyncTitle()
            preview:UpdatePreview()
            UpdateScopeBadge()
        end)
    end,
})
