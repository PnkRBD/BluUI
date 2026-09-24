local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Controls, Layout, Colors, Modals = BUILib.Controls, BUILib.Layout, BUILib.Colors, BUILib.Modals
local CastBar = BUI.CastBar
local FONT = BUI.C.FONT_PATH

local STRATA_OPTIONS = BUI.C.STRATA_OPTIONS

local previewRefresh

local function RefreshCastBars()
    local unitFrames = BUI.UnitFrames
    for _, barType in ipairs({ 'player', 'target', 'focus' }) do
        local frame = unitFrames[barType]
        if frame then CastBar.ApplyCastbar(frame, barType) end
    end
    previewRefresh()
end

local function BuildCastPreview(parent, width, height)
    local Pixel = BUI.Pixel
    local sharedMedia = LibStub('LibSharedMedia-3.0')

    local card, stage = BUILib.PageKit.PreviewStage(parent)

    local bar = CreateFrame('StatusBar', nil, stage)
    bar:SetPoint('CENTER', 0, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.65)

    local background = bar:CreateTexture(nil, 'BACKGROUND')
    background:SetAllPoints()

    local iconHost = CreateFrame('Frame', nil, card)
    local icon = iconHost:CreateTexture(nil, 'ARTWORK')
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(136048)

    local nameFontString = bar:CreateFontString(nil, 'OVERLAY')
    local timeFontString = bar:CreateFontString(nil, 'OVERLAY')

    Pixel.ApplyFont(nameFontString, 12, FONT)
    Pixel.ApplyFont(timeFontString, 12, FONT)
    nameFontString:SetText('Bloodlust')
    timeFontString:SetText('1.4')

    local unit = 'player'
    function card:SetUnit(newUnit) unit = newUnit; self:UpdatePreview() end

    function card:UpdatePreview()
        local settings = CastBar.GetSettings(unit)

        local texturePath
        if settings.texture and settings.texture ~= 'GLOBAL' then texturePath = sharedMedia:Fetch('statusbar', settings.texture) end
        texturePath = texturePath or BUI.GetGlobalTexture()
        bar:SetStatusBarTexture(texturePath)
        background:SetTexture(texturePath)

        local barWidth = math.min(settings.width, width - 120)
        local barHeight = settings.height
        bar:SetSize(barWidth, barHeight)

        if settings.useClassColor then
            local _, class = UnitClass('player')
            local classColor = class and RAID_CLASS_COLORS[class]
            if classColor then bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1) else bar:SetStatusBarColor(unpack(settings.barColor)) end
        else
            bar:SetStatusBarColor(unpack(settings.barColor))
        end
        local backgroundColor = settings.bgColor
        background:SetVertexColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4] or 1)

        local borderColor = settings.borderColor
        Pixel.ApplyBorder(bar, settings.borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)

        iconHost:SetShown(settings.showIcon or false)
        iconHost:SetSize(barHeight, barHeight)
        iconHost:ClearAllPoints()
        iconHost:SetPoint('RIGHT', bar, 'LEFT', -2, 0)

        Pixel.ApplyFont(nameFontString, settings.textSize, FONT)
        Pixel.ApplyFont(timeFontString, settings.textSize, FONT)
        local textColor = settings.textColor
        nameFontString:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
        timeFontString:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
        nameFontString:ClearAllPoints()
        nameFontString:SetPoint('LEFT', bar, 'LEFT', 6 + settings.textOffsetX, settings.textOffsetY)
        timeFontString:SetPoint('RIGHT', bar, 'RIGHT', -6, 0)
        nameFontString:SetShown(settings.showSpellName ~= false)
        timeFontString:SetShown(settings.showTimer ~= false)
    end

    card:UpdatePreview()
    return card
end

local function ShowCustomSpellsModal(settings)
    local overlay, dialog, Close = Modals.CreateBase(520, 520, true)
    local titleFontString = Modals.CreateTitle(dialog, "Custom Spell Colors")

    local function AccentColor()
        local red, green, blue = Colors.GetAccent()
        return { red, green, blue, 1 }
    end

    local list
    list = Controls.SpellColorList(dialog, "Drag spell here, search, or paste link/ID...", 460, 372,
        function(text)
            local id = BUI.Lookup.ParseSpellInput(text)
            if not id or settings.spellColors[id] then return end
            settings.spellColors[id] = AccentColor()
            local icon, name = BUI.Lookup.GetSpellInfo(id)
            list:AddItem(icon or 134400, name or "Spell " .. id, id, settings.spellColors[id])
        end,
        function(rowData)
            if rowData.id then settings.spellColors[rowData.id] = nil end
        end,
        function(spellId, color)
            if spellId then settings.spellColors[spellId] = color end
        end,
        BUI.Lookup.SearchSpells,
        function(item)
            if settings.spellColors[item.id] then return end
            settings.spellColors[item.id] = AccentColor()
            list:AddItem(item.icon or 134400, item.name or "Spell " .. item.id, item.id, settings.spellColors[item.id])
        end)
    local listFrame = list.frame
    listFrame:SetPoint("TOP", titleFontString, "BOTTOM", 0, -18)

    for id, color in pairs(settings.spellColors) do
        local icon, name = BUI.Lookup.GetSpellInfo(id)
        list:AddItem(icon or 134400, name or "Spell " .. id, id, color)
    end

    Modals.LayoutButtons(dialog, {
        { text = "Close", color = Modals.BTN_NEUTRAL },
    }, Close)

    overlay:Show()
end

local function BuildCastBarSettings(tab, tabId)
    local settings = CastBar.GetSettings(tabId)

    local PageKit = BUILib.PageKit
    local apply = RefreshCastBars

    local grids = {}
    local grid
    local function Section(title)
        if grid then grid:Flush() end
        Layout.Section(tab, title)
        grid = PageKit.RowGrid(tab)
        grids[#grids + 1] = grid
    end
    local function AddRow(config)
        return grid:Add(config)
    end

    Section('Bar')

    AddRow({
        title = 'Position & Size',
        description = 'Placement, bar width and height.',
        plain = true,
        accessoryWidth = 64,
        accessories = function(row)
            local mover = BUI.AlertMover(row, settings, apply)
            local size = PageKit.SizeIcon(row, { title = 'BAR SIZE', options = {
                { kind = 'slider', label = 'Width', min = 100, max = 500,
                  get = function() return settings.width end,
                  set = function(value) settings.width = value; apply() end },
                { kind = 'slider', label = 'Height', min = 4, max = 50,
                  get = function() return settings.height end,
                  set = function(value) settings.height = value; apply() end },
                { kind = 'slider', label = 'Border Size', min = 0, max = 5,
                  get = function() return settings.borderSize end,
                  set = function(value) settings.borderSize = value; apply() end },
                { kind = 'dropdown', label = 'Bar Strata', items = STRATA_OPTIONS, controlWidth = 120,
                  get = function() return settings.frameStrata end,
                  set = function(value) settings.frameStrata = value; apply() end },
            } })
            return { mover, size }
        end,
    })

    AddRow({
        title = 'Texture',
        description = 'Bar fill texture.',
        controlWidth = 170,
        control = function(row)
            return Controls.Dropdown(row, nil, BUI.BuildTextureDropdownItems('GLOBAL'), settings.texture, function(value)
                settings.texture = value; apply()
            end, nil, 160)
        end,
    })

    AddRow({
        title = 'Colors',
        description = 'Bar, border and background.',
        plain = true,
        accessoryWidth = 92,
        accessories = function(row)
            local barColor = settings.barColor
            local barSwatch = Controls.ColorSwatch(row, { r = barColor[1], g = barColor[2], b = barColor[3], a = barColor[4],
                tooltip = 'Bar color',
                callback = function(red, green, blue, alpha) settings.barColor = { red, green, blue, alpha }; apply() end })
            local borderColor = settings.borderColor
            local borderSwatch = Controls.ColorSwatch(row, { r = borderColor[1], g = borderColor[2], b = borderColor[3], a = borderColor[4],
                tooltip = 'Border color',
                callback = function(red, green, blue, alpha) settings.borderColor = { red, green, blue, alpha }; apply() end })
            local backgroundColor = settings.bgColor
            local backgroundSwatch = Controls.ColorSwatch(row, { r = backgroundColor[1], g = backgroundColor[2], b = backgroundColor[3], a = backgroundColor[4],
                tooltip = 'Background color',
                callback = function(red, green, blue, alpha) settings.bgColor = { red, green, blue, alpha }; apply() end })
            return { barSwatch, borderSwatch, backgroundSwatch }
        end,
    })

    AddRow({
        title = 'Use Class Color',
        description = 'Color the bar by your class.',
        checked = settings.useClassColor and true or false,
        callback = function(value) settings.useClassColor = value; apply() end,
    })

    AddRow({
        title = 'Icon',
        description = 'Spell icon beside the bar.',
        checked = settings.showIcon and true or false,
        callback = function(value) settings.showIcon = value; apply() end,
    })

    if tabId == 'player' then
        AddRow({
            title = 'Channel Ticks',
            description = 'Tick marks on channeled casts.',
            checked = settings.channelTicks and true or false,
            callback = function(value) settings.channelTicks = value; apply() end,
            accessoryWidth = 64,
            accessories = function(row)
                local cog = PageKit.SettingsIcon(row, { title = 'CHANNEL TICKS', tooltip = 'Tick width', options = {
                    { kind = 'slider', label = 'Tick Width', min = 1, max = 6,
                      get = function() return settings.channelTickWidth end,
                      set = function(value) settings.channelTickWidth = value; apply() end },
                } })
                local tickColor = settings.channelTickColor
                local swatch = Controls.ColorSwatch(row, { r = tickColor[1], g = tickColor[2], b = tickColor[3], a = tickColor[4],
                    tooltip = 'Tick color',
                    callback = function(red, green, blue, alpha) settings.channelTickColor = { red, green, blue, alpha }; apply() end })
                return { cog, swatch }
            end,
        })
    end

    Section('Text')

    AddRow({
        spanFull = true,
        title = 'Text',
        description = 'Font, color, and what the bar shows.',
        controlWidth = 170,
        control = function(row)
            return Controls.Dropdown(row, nil, BUI.BuildFontDropdownItems('GLOBAL'), settings.font or BUI.C.GLOBAL_OPTION, function(val)
                settings.font = val; apply()
            end, nil, 160)
        end,
        accessoryWidth = tabId == 'player' and 130 or 100,
        accessories = function(row)
            local textOptions = {
                { kind = 'slider', label = 'Text Size', min = 8, max = 24,
                  get = function() return settings.textSize end,
                  set = function(value) settings.textSize = value; apply() end },
                { label = 'Show Timer',
                  get = function() return settings.showTimer end,
                  set = function(value) settings.showTimer = value; apply() end },
                { label = 'Show Total Time',
                  get = function() return settings.showTotalTime ~= false end,
                  set = function(value) settings.showTotalTime = value; apply() end },
                { label = 'Countdown',
                  get = function() return settings.countdown ~= false end,
                  set = function(value) settings.countdown = value; apply() end },
                { label = 'Show Spell Name',
                  get = function() return settings.showSpellName end,
                  set = function(value) settings.showSpellName = value; apply() end },
                { label = 'Show Cast Target',
                  get = function() return settings.showCastTarget end,
                  set = function(value) settings.showCastTarget = value; apply() end },
                { kind = 'slider', label = 'Name Max Length', min = 0, max = 30,
                  get = function() return settings.spellNameMaxLength or 0 end,
                  set = function(value) settings.spellNameMaxLength = value > 0 and value or nil; apply() end },
                { kind = 'dropdown', label = 'Text Strata', items = STRATA_OPTIONS, controlWidth = 120,
                  get = function() return settings.textStrata end,
                  set = function(value) settings.textStrata = value; apply() end },
            }
            if tabId == 'player' then
                textOptions[#textOptions + 1] = { label = 'Show Latency',
                    get = function() return settings.showLatency end,
                    set = function(value) settings.showLatency = value; apply() end }
            end
            local cog = PageKit.SettingsIcon(row, { title = 'TEXT', tooltip = 'Text display options', width = 280, options = textOptions })
            local mover = PageKit.OffsetMover(row, {
                getX = function() return settings.textOffsetX end, setX = function(value) settings.textOffsetX = value; apply() end,
                getY = function() return settings.textOffsetY end, setY = function(value) settings.textOffsetY = value; apply() end,
            })
            local textColor = settings.textColor
            local textSwatch = Controls.ColorSwatch(row, { r = textColor[1], g = textColor[2], b = textColor[3], a = textColor[4],
                tooltip = 'Text color',
                callback = function(red, green, blue, alpha) settings.textColor = { red, green, blue, alpha }; apply() end })
            local out = { cog, mover, textSwatch }
            if tabId == 'player' then
                local latencyColor = settings.latencyColor
                out[#out + 1] = Controls.ColorSwatch(row, { r = latencyColor[1], g = latencyColor[2], b = latencyColor[3], a = latencyColor[4],
                    tooltip = 'Latency color',
                    callback = function(red, green, blue, alpha) settings.latencyColor = { red, green, blue, alpha }; apply() end })
            end
            return out
        end,
    })

    if (tabId == 'target' or tabId == 'focus') and settings.interruptColor then
        Section('Interrupts')

        AddRow({
            title = 'Cast Colors',
            description = 'Bar color by interrupt state.',
            plain = true,
            accessoryWidth = 122,
            accessories = function(row)
                local interruptColor = settings.interruptColor
                local interruptSwatch = Controls.ColorSwatch(row, { r = interruptColor[1], g = interruptColor[2], b = interruptColor[3], a = interruptColor[4],
                    tooltip = 'Non-interruptible',
                    callback = function(red, green, blue, alpha) settings.interruptColor = { red, green, blue, alpha }; apply() end })
                local cooldownColor = settings.interruptOnCDColor
                local cooldownSwatch = Controls.ColorSwatch(row, { r = cooldownColor[1], g = cooldownColor[2], b = cooldownColor[3], a = cooldownColor[4],
                    tooltip = 'Interrupt on cooldown',
                    callback = function(red, green, blue, alpha) settings.interruptOnCDColor = { red, green, blue, alpha }; apply() end })
                local readyColor = settings.interruptReadyColor
                local readySwatch = Controls.ColorSwatch(row, { r = readyColor[1], g = readyColor[2], b = readyColor[3], a = readyColor[4],
                    tooltip = 'Can interrupt',
                    callback = function(red, green, blue, alpha) settings.interruptReadyColor = { red, green, blue, alpha }; apply() end })
                local windowColor = settings.interruptWindowColor
                local windowSwatch = Controls.ColorSwatch(row, { r = windowColor[1], g = windowColor[2], b = windowColor[3], a = windowColor[4],
                    tooltip = 'Interrupt soon',
                    callback = function(red, green, blue, alpha) settings.interruptWindowColor = { red, green, blue, alpha }; apply() end })
                return { windowSwatch, readySwatch, cooldownSwatch, interruptSwatch }
            end,
        })

        AddRow({
            title = 'Ready Line',
            description = 'Line marking when your kick is back up.',
            checked = settings.interruptTick ~= false,
            callback = function(value) settings.interruptTick = value; apply() end,
            accessoryWidth = 64,
            accessories = function(row)
                local cog = PageKit.SettingsIcon(row, { title = 'INTERRUPT LINES', tooltip = 'Line width & window', options = {
                    { kind = 'slider', label = 'Line Width', min = 1, max = 6,
                      get = function() return settings.interruptTickWidth end,
                      set = function(value) settings.interruptTickWidth = value; apply() end },
                    { label = 'Show Interrupt Window',
                      get = function() return settings.interruptWindow ~= false end,
                      set = function(value) settings.interruptWindow = value; apply() end },
                } })
                local tickColor = settings.interruptTickColor
                local swatch = Controls.ColorSwatch(row, { r = tickColor[1], g = tickColor[2], b = tickColor[3], a = tickColor[4],
                    tooltip = 'Ready line color',
                    callback = function(red, green, blue, alpha) settings.interruptTickColor = { red, green, blue, alpha }; apply() end })
                return { cog, swatch }
            end,
        })

        AddRow({
            spanFull = true,
            title = 'Interrupt Voice',
            description = 'Spoken alerts when your kick is ready, or will be before the cast ends.',
            plain = true,
            accessoryWidth = 140,
            accessories = function(row)
                local preview = Controls.GhostButton(row, 'Preview', 90, function() CastBar.PreviewInterrupt(tabId) end)
                local cog = PageKit.SettingsIcon(row, { title = 'INTERRUPT VOICE', tooltip = 'Voice lines & timing', options = {
                    { label = 'Kick Ready',
                      get = function() return settings.interruptTTS == true end,
                      set = function(value) settings.interruptTTS = value; apply() end },
                    { kind = 'textbox', label = 'Ready Text',
                      get = function() return settings.interruptTTSText end,
                      set = function(value) settings.interruptTTSText = (value and value ~= '') and value or 'Kick' end },
                    { label = 'Kick Soon',
                      get = function() return settings.interruptTTSSoon == true end,
                      set = function(value) settings.interruptTTSSoon = value; apply() end },
                    { kind = 'textbox', label = 'Soon Text',
                      get = function() return settings.interruptTTSSoonText end,
                      set = function(value) settings.interruptTTSSoonText = (value and value ~= '') and value or 'Kick soon' end },
                    { kind = 'slider', label = 'Soon Lead (s)', min = 1, max = 10, step = 0.5,
                      get = function() return settings.interruptTTSSoonWindow end,
                      set = function(value) settings.interruptTTSSoonWindow = value; apply() end },
                } })
                return { preview, cog }
            end,
        })
    end

    if tabId == 'player' then
        if BUI.Tools.PlayerCanEmpower() then
            Section('Empowered Casts')

            AddRow({
                title = 'Stage Pips',
                description = 'Lines splitting the empower stages.',
                plain = true,
                accessoryWidth = 64,
                accessories = function(row)
                    local cog = PageKit.SettingsIcon(row, { title = 'STAGE PIPS', tooltip = 'Pip width & glow', options = {
                        { kind = 'slider', label = 'Line Width', min = 1, max = 6,
                          get = function() return settings.pipWidth end,
                          set = function(value) settings.pipWidth = value; apply() end },
                        { label = 'Glow',
                          get = function() return settings.pipGlow ~= false end,
                          set = function(value) settings.pipGlow = value; apply() end },
                    } })
                    local pipColor = settings.pipColor
                    local swatch = Controls.ColorSwatch(row, { r = pipColor[1], g = pipColor[2], b = pipColor[3], a = pipColor[4],
                        tooltip = 'Pip color',
                        callback = function(red, green, blue, alpha) settings.pipColor = { red, green, blue, alpha }; apply() end })
                    return { cog, swatch }
                end,
            })

            local baseBar = settings.barColor
            for stageIndex = 1, 4 do
                settings.stageColors[stageIndex] = settings.stageColors[stageIndex] or { baseBar[1], baseBar[2], baseBar[3], baseBar[4] }
            end

            AddRow({
                spanFull = true,
                title = 'Stage Colors',
                description = 'Tint the bar per empower stage.',
                checked = settings.stageColorsEnabled == true,
                callback = function(value) settings.stageColorsEnabled = value end,
                accessoryWidth = 280,
                accessories = function(row)
                    local dropdown = Controls.Dropdown(row, nil, {
                        { value = 'background', text = 'Background' },
                        { value = 'foreground', text = 'Bar Fill' },
                    }, (settings.stageColorBackground ~= false) and 'background' or 'foreground',
                    function(value) settings.stageColorBackground = (value == 'background') end, nil, 140)
                    local out = { dropdown }
                    for stageIndex = 4, 1, -1 do
                        local stageColor = settings.stageColors[stageIndex]
                        out[#out + 1] = Controls.ColorSwatch(row, { r = stageColor[1], g = stageColor[2], b = stageColor[3], a = stageColor[4],
                            tooltip = 'Stage ' .. stageIndex,
                            callback = function(red, green, blue, alpha) settings.stageColors[stageIndex] = { red, green, blue, alpha } end })
                    end
                    return out
                end,
            })
        end

        Section('Custom Spells')

        AddRow({
            spanFull = true,
            title = 'Custom Spell Colors',
            description = 'Per-spell bar colors for specific casts.',
            checked = settings.useSpellColors and true or false,
            callback = function(value) settings.useSpellColors = value end,
            accessoryWidth = 36,
            accessories = function(row)
                return { Controls.Icon(row, {
                    tooltip = 'Edit custom spell colors',
                    onClick = function() ShowCustomSpellsModal(settings) end,
                }) }
            end,
        })
    end

    grid:Flush()

    local unitGrid = {
        SyncDim = function(_, enabled)
            for gridIndex = 1, #grids do grids[gridIndex]:SyncDim(enabled) end
        end,
    }
    unitGrid:SyncDim(settings.enabled)
    return unitGrid
end

BUI.PageEngine.RegisterPage("castbars", {
    title = "Cast Bars",
    buttonText = "Cast Bars",
    OnBuild = function(pageFrame)
        local PageKit = BUILib.PageKit
        local CONTENT_WIDTH = BUILib.Layout.PAGE_CONTENT_W
        local PREVIEW_HEIGHT = BUILib.Layout.PAGE_PREVIEW_H

        local selectedUnit = 'player'
        local unitGrids = {}
        local function GetUnitSettings(key) return CastBar.GetSettings(key) end

        local UNITS = {
            { key = 'player', title = 'PLAYER', image = 'Interface\\Icons\\Achievement_Character_Human_Male' },
            { key = 'target', title = 'TARGET', image = 'Interface\\Icons\\Ability_Hunter_SniperShot' },
            { key = 'focus',  title = 'FOCUS',  image = 'Interface\\Icons\\Ability_Hunter_MasterMarksman' },
        }

        local preview, titleBar
        local function SyncTitle()
            local unitSettings = GetUnitSettings(selectedUnit)
            if not titleBar then return end
            titleBar.enableToggle:SetValue(unitSettings.enabled)
            titleBar.anchorToggle:SetValue(not unitSettings.locked)
        end

        local root, pinned
        root, pinned, titleBar = PageKit.Scaffold(pageFrame, {
            title = 'Cast Bars', titleDesc = 'Player, target, and focus cast bars with anchoring, colors, and empower stages.',
            previewH = PREVIEW_HEIGHT, watermark = BUI.Tools.GetLogo(),

            titleEnable = { value = GetUnitSettings('player').enabled, gate = function() return BUI.IsModuleEnabled('castBars') end, onToggle = function(value)
                local unitSettings = GetUnitSettings(selectedUnit)
                unitSettings.enabled = value; RefreshCastBars()
                if unitGrids[selectedUnit] then unitGrids[selectedUnit]:SyncDim(value) end
            end },
            titleAnchor = { value = not GetUnitSettings('player').locked, onToggle = function(value)
                local unitSettings = GetUnitSettings(selectedUnit)
                unitSettings.locked = not value; RefreshCastBars()
            end },
            hostTabs = {
                defs = UNITS, defaultKey = 'player',
                onSelect = function(key)
                    selectedUnit = key
                    SyncTitle()
                    if preview then preview:SetUnit(key) end
                end,
                build = function(def, tab) unitGrids[def.key] = BuildCastBarSettings(tab, def.key) end,
            },
        })

        CastBar._lockToggles = {}
        for _, unitType in ipairs({ 'player', 'target', 'focus' }) do
            CastBar._lockToggles[unitType] = { SetValue = function(_, value)
                if unitType == selectedUnit then titleBar.anchorToggle:SetValue(value) end
            end }
        end

        preview = BuildCastPreview(pinned, CONTENT_WIDTH, PREVIEW_HEIGHT)
        previewRefresh = function() preview:UpdatePreview() end
        preview:SetUnit('player')

        pageFrame:SetScript('OnShow', SyncTitle)
    end,
    OnHide = function()
        for _, barType in ipairs({ "player", "target", "focus" }) do
            CastBar.StopInterruptPreview(barType)
        end
    end,
})

