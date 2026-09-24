local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Controls = BUILib.Controls
local Modals = BUILib.Modals
local Layout = BUILib.Layout
local Pixel = BUI.Pixel

local floor = math.floor
local FONT = BUI.C.FONT_PATH

local PageKit = BUILib.PageKit
local PopRow = PageKit.PopRow

local selectedText, selectedPanel
local activeKind = 'TEXT'

local function Bars() return BUI.Datatext.GetBars() end
local function KindOf(bar) return bar.kind == 'PANEL' and 'PANEL' or 'TEXT' end

local function FirstOfKind(kind)
    for barIndex, bar in ipairs(Bars()) do
        if KindOf(bar) == kind then return barIndex end
    end
end

local function ValidIndex(index, kind)
    local list = Bars()
    if index and list[index] and KindOf(list[index]) == kind then return index end
    return FirstOfKind(kind)
end

local function CurText()
    selectedText = ValidIndex(selectedText, 'TEXT')
    return selectedText and Bars()[selectedText]
end

local function CurPanel()
    selectedPanel = ValidIndex(selectedPanel, 'PANEL')
    return selectedPanel and Bars()[selectedPanel]
end

local function ActiveCur()
    if activeKind == 'PANEL' then return CurPanel() end
    return CurText()
end

local ANCHOR_POINTS = BUI.C.ANCHOR_POINT_OPTIONS_SHORT
local STRATA_ITEMS = BUI.C.STRATA_OPTIONS

local ORIENTATIONS = {
    { value = 'HORIZONTAL', text = 'Horizontal' },
    { value = 'VERTICAL',   text = 'Vertical'   },
}

local ALIGNMENTS = {
    { value = 'LEFT',   text = 'Left'   },
    { value = 'CENTER', text = 'Center' },
    { value = 'RIGHT',  text = 'Right'  },
    { value = 'SPREAD', text = 'Spread Evenly' },
}

local previewLayout = { textLeft = {}, textWidth = {}, hitLeft = {}, hitWidth = {}, lineTop = {} }

local function BuildSampleParts(cfg)
    return BUI.Datatext.BuildSampleParts(cfg)
end

local function BuildDatatextPreview(parent, width, height)
    local card, stage = BUILib.PageKit.PreviewStage(parent, { inset = Pixel.Scale(14) })

    local textFontString = stage:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(textFontString, 12, FONT, '')
    textFontString:SetPoint('CENTER')
    textFontString:SetJustifyH('CENTER')

    local panelTexture = stage:CreateTexture(nil, 'ARTWORK')
    panelTexture:Hide()

    local panelTitleFontString = stage:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(panelTitleFontString, 12, FONT, '')
    panelTitleFontString:Hide()

    local cells = {}

    local function HideAll()
        textFontString:Hide()
        panelTexture:Hide()
        panelTitleFontString:Hide()
        for cellIndex = 1, #cells do cells[cellIndex]:Hide() end
    end

    function card:UpdatePreview()
        HideAll()

        if activeKind == 'PANEL' then
            local cfg = CurPanel()
            if not cfg then
                textFontString:SetText('|cff555555(no panels yet)|r'); textFontString:Show()
                return
            end
            local backgroundColor = cfg.bgColor
            local panelWidth = cfg.width > 0 and cfg.width or 200
            local panelHeight = cfg.height > 0 and cfg.height or 100
            local scale = math.min(1, 180 / math.max(panelWidth, panelHeight, 1))
            panelTexture:SetColorTexture(backgroundColor.r, backgroundColor.g, backgroundColor.b, math.max(cfg.bgAlpha, 0.15))
            panelTexture:ClearAllPoints()
            panelTexture:SetPoint('CENTER', stage, 'CENTER')
            panelTexture:SetSize(panelWidth * scale, panelHeight * scale)
            panelTexture:Show()
            if cfg.title and cfg.title ~= '' then
                local fontPath = BUI.GetModuleFont(cfg)
                Pixel.ApplyFont(panelTitleFontString, math.max(8, floor(cfg.titleSize * scale + 0.5)), fontPath, '')
                panelTitleFontString:SetText(cfg.title)
                local titleColor = cfg.titleColor
                panelTitleFontString:SetTextColor(titleColor.r, titleColor.g, titleColor.b)
                local anchor = cfg.titleAnchor
                panelTitleFontString:ClearAllPoints()
                panelTitleFontString:SetPoint(anchor, panelTexture, anchor, cfg.titleX * scale, cfg.titleY * scale)
                panelTitleFontString:Show()
            end
            return
        end

        local cfg = CurText()
        if not cfg then
            textFontString:SetText('|cff555555(no bars yet)|r'); textFontString:Show()
            return
        end
        local fontPath = BUI.GetModuleFont(cfg)
        Pixel.ApplyFont(textFontString, cfg.fontSize, fontPath, '')

        local parts = BuildSampleParts(cfg)
        local partCount = #parts
        if partCount == 0 then
            textFontString:SetText('|cff555555(no modules enabled)|r'); textFontString:Show()
            return
        end

        local widths = {}
        for partIndex = 1, partCount do
            local fontString = cells[partIndex]
            if not fontString then fontString = stage:CreateFontString(nil, 'OVERLAY'); cells[partIndex] = fontString end
            Pixel.ApplyFont(fontString, cfg.fontSize, fontPath, '')
            fontString:SetWordWrap(false)
            fontString:SetText(parts[partIndex])
            widths[partIndex] = fontString:GetStringWidth()
        end

        local Datatext = BUI.Datatext
        local LAYOUT = Datatext.LAYOUT
        local spacing = Pixel.Scale(cfg.spacing or 0)
        local align = cfg.align or 'LEFT'
        local fixedWidth = (cfg.width or 0) > 0 and math.min(Pixel.Scale(cfg.width), stage:GetWidth()) or nil
        if cfg.orientation == 'VERTICAL' then
            local lineHeight = Pixel.Scale(cfg.fontSize + LAYOUT.lineExtra)
            local barWidth, barHeight = Datatext.LayoutColumn(widths, partCount, spacing, Pixel.Scale(LAYOUT.columnInset),
                lineHeight, fixedWidth, nil, previewLayout)
            local justify = align == 'SPREAD' and 'CENTER' or align
            for partIndex = 1, partCount do
                local fontString = cells[partIndex]
                fontString:ClearAllPoints()
                fontString:SetPoint('TOPLEFT', stage, 'CENTER', -barWidth / 2 + previewLayout.lineLeft, barHeight / 2 - previewLayout.lineTop[partIndex])
                fontString:SetSize(previewLayout.lineWidth, lineHeight)
                fontString:SetJustifyH(justify)
                fontString:SetJustifyV('MIDDLE')
                fontString:Show()
            end
        else
            local barWidth = Datatext.LayoutRow(widths, partCount, spacing, Pixel.Scale(LAYOUT.rowInset), fixedWidth, align, 0, previewLayout)
            for partIndex = 1, partCount do
                local fontString = cells[partIndex]
                fontString:ClearAllPoints()
                fontString:SetPoint('LEFT', stage, 'CENTER', -barWidth / 2 + previewLayout.textLeft[partIndex], 0)
                fontString:SetWidth(previewLayout.textWidth[partIndex])
                fontString:SetHeight(0)
                fontString:SetJustifyH('CENTER')
                fontString:Show()
            end
        end
    end

    card:UpdatePreview()
    return card
end

BUI.PageEngine.RegisterPage('datatext', {
    title = 'Datatext',
    buttonText = 'Datatext',
    minContentWidth  = 924,
    minContentHeight = 600,
    OnBuild = function(pageFrame)
        local DASH_WIDTH     = BUILib.Layout.PAGE_CONTENT_W
        local PREVIEW_HEIGHT  = BUILib.Layout.PAGE_PREVIEW_H

        local Datatext = BUI.Datatext
        local function RebuildPage() BUI.PageEngine.RefreshCurrentPage() end

        local SyncDim, titleBar, RefreshPreview
        local dimGrids = {}

        SyncDim = function()
            local enabled = Datatext.ModuleEnabled() and CurText() and CurText().enabled
            for gridIndex = 1, #dimGrids do dimGrids[gridIndex]:SyncDim(enabled and true or false) end
        end

        local refreshers = {}
        local function AddRefresh(refreshFunction) refreshers[#refreshers + 1] = refreshFunction end

        local function OpenPositionPopover(button, GetConfig)
            local isPanel = Datatext.IsPanel(GetConfig())
            Controls.Popover({
                anchor = button, width = 260, title = 'POSITION', height = isPanel and 298 or 258,
                build = function(panel)
                    local alignMinimapCheckbox

                    PopRow(panel, 18, 'Anchor', Controls.Dropdown(panel, nil, ANCHOR_POINTS, GetConfig().point or 'BOTTOM', function(value)
                        GetConfig().point = value; GetConfig().relPoint = value
                        GetConfig().alignMinimap = false
                        alignMinimapCheckbox:SetValue(false)
                        Datatext.Apply()
                    end, nil, 150))

                    PopRow(panel, 58, 'X Position', Controls.CompactSlider(panel, nil, -1500, 1500, GetConfig().x, function(value)
                        GetConfig().x = value; Datatext.Apply()
                    end, 1, 150))
                    PopRow(panel, 98, 'Y Position', Controls.CompactSlider(panel, nil, -1500, 1500, GetConfig().y or 0, function(value)
                        GetConfig().y = value; Datatext.Apply()
                    end, 1, 150))

                    alignMinimapCheckbox = Controls.StampCheckbox(panel, nil, GetConfig().alignMinimap, function(value)
                        GetConfig().alignMinimap = value
                        Datatext.Apply()
                    end)
                    PopRow(panel, 138, 'Align Below Minimap', alignMinimapCheckbox)

                    local y = 178
                    if isPanel then
                        PopRow(panel, y, 'Mirror Chat Window', Controls.StampCheckbox(panel, nil, GetConfig().mirrorChat, function(value)
                            GetConfig().mirrorChat = value; Datatext.Apply()
                        end, nil, nil, 'Keep this panel sized and positioned as a mirror image of the chat window'))
                        y = y + 40
                    end

                    PopRow(panel, y, 'Strata', Controls.Dropdown(panel, nil, STRATA_ITEMS, GetConfig().strata or 'MEDIUM', function(value)
                        GetConfig().strata = value; Datatext.Apply()
                    end, nil, 150))
                    PopRow(panel, y + 40, 'Frame Level', Controls.CompactSlider(panel, nil, 0, 100, GetConfig().frameLevel or 2, function(value)
                        GetConfig().frameLevel = value; Datatext.Apply()
                    end, 1, 150))
                end,
            })
        end

        local function OpenBackgroundPopover(button, GetConfig)
            Controls.Popover({
                anchor = button, width = 260, title = 'BACKGROUND & SIZE', height = 178,
                build = function(panel)
                    local bgSlider = Controls.CompactSlider(panel, nil, 0, 100, floor((GetConfig().bgAlpha or 0) * 100), function(value)
                        GetConfig().bgAlpha = value / 100; Datatext.Apply(); RefreshPreview()
                    end, 1, 150)
                    PopRow(panel, 18, 'Opacity', bgSlider)
                    local backgroundColor = GetConfig().bgColor or { r = 0, g = 0, b = 0 }
                    PageKit.AttachLeft(Controls.ColorSwatch(panel, { r = backgroundColor.r, g = backgroundColor.g, b = backgroundColor.b, callback = function(red, green, blue)
                        GetConfig().bgColor = { r = red, g = green, b = blue }; Datatext.Apply(); RefreshPreview()
                    end, tooltip = 'Background Color' }), bgSlider)

                    local borderCheckbox = Controls.StampCheckbox(panel, nil, GetConfig().border, function(value)
                        GetConfig().border = value; Datatext.Apply()
                    end)
                    PopRow(panel, 58, 'Border', borderCheckbox)
                    local borderColor = GetConfig().borderColor or { r = 0.2, g = 0.2, b = 0.24, a = 1 }
                    PageKit.AttachLeft(Controls.ColorSwatch(panel, { r = borderColor.r, g = borderColor.g, b = borderColor.b, a = borderColor.a, callback = function(red, green, blue, alpha)
                        GetConfig().borderColor = { r = red, g = green, b = blue, a = alpha }; Datatext.Apply()
                    end, tooltip = 'Border Color' }), borderCheckbox)

                    PopRow(panel, 98, 'Width', Controls.CompactSlider(panel, nil, 0, 1200, GetConfig().width or 0, function(value)
                        GetConfig().width = value; Datatext.Apply(); RefreshPreview()
                    end, 1, 150))
                    PopRow(panel, 138, 'Height', Controls.CompactSlider(panel, nil, 0, 600, GetConfig().height or 0, function(value)
                        GetConfig().height = value; Datatext.Apply(); RefreshPreview()
                    end, 1, 150))
                end,
            })
        end

        local function BuildSelectorRows(AddRow, kind, GetConfig, getIndex, setIndex, labels)
            local function NewButton(row)
                return Controls.Button(row, labels.newLabel, 100, function()
                    setIndex(Datatext.AddBar(kind))
                    activeKind = kind
                    RebuildPage()
                end)
            end

            if not GetConfig() then
                AddRow({
                    spanFull = true,
                    title = labels.label,
                    description = labels.emptyDesc,
                    plain = true,
                    accessoryWidth = 110,
                    accessories = function(row)
                        return { NewButton(row) }
                    end,
                })
                return
            end

            local items = {}
            for barIndex, bar in ipairs(Bars()) do
                if KindOf(bar) == kind then
                    items[#items + 1] = { value = barIndex, text = bar.name or ('#' .. barIndex) }
                end
            end
            local function NameNumber(text) return tonumber(text:match('(%d+)%s*$')) end
            table.sort(items, function(left, right)
                local leftNumber, rightNumber = NameNumber(left.text), NameNumber(right.text)
                if leftNumber and rightNumber and leftNumber ~= rightNumber then return leftNumber < rightNumber end
                if (leftNumber ~= nil) ~= (rightNumber ~= nil) then return leftNumber ~= nil end
                if left.text ~= right.text then return left.text < right.text end
                return left.value < right.value
            end)

            AddRow({
                spanFull = true,
                title = labels.label,
                description = labels.desc,
                controlWidth = 190,
                control = function(row)
                    return Controls.Dropdown(row, nil, items, getIndex(), function(value)
                        setIndex(value)
                        RebuildPage()
                    end, nil, 180)
                end,
                accessoryWidth = 200,
                accessories = function(row)
                    local moverButton = Controls.Icon(row, {
                        texture = BUILib.GetLibMedia('mover'), tooltip = 'Anchor & position',
                        onClick = function(button) OpenPositionPopover(button, GetConfig) end,
                    })
                    local bgCog = Controls.Icon(row, {
                        tooltip = 'Background, border & size',
                        onClick = function(button) OpenBackgroundPopover(button, GetConfig) end,
                    })
                    local deleteButton = Controls.Icon(row, {
                        texture = BUILib.GetLibMedia('delete'), tooltip = 'Delete',
                        onClick = function()
                            local current = GetConfig()
                            Modals.Confirm({
                                parent = BUI.PageEngine.window.frame,
                                title = 'Delete',
                                message = 'Delete "' .. ((current and current.name) or 'this') .. '"?',
                                confirmText = 'Delete', cancelText = 'Cancel',
                                onConfirm = function()
                                    Datatext.DeleteBar(getIndex())
                                    setIndex(nil)
                                    RebuildPage()
                                end,
                            })
                        end,
                    })
                    return { moverButton, bgCog, deleteButton, NewButton(row) }
                end,
            })

            local enableRow = AddRow({
                spanFull = true,
                title = labels.enableLabel,
                description = labels.enableDesc,
                checked = GetConfig().enabled and true or false,
                callback = function(enabled)
                    GetConfig().enabled = enabled; Datatext.Apply(); SyncDim(); RefreshPreview()
                end,
            })
            AddRefresh(function() if GetConfig() then enableRow:SetValue(GetConfig().enabled) end end)
        end

        local function BuildTextTab(tab)
            local grid
            local function Section(title, dim)
                if grid then grid:Flush() end
                Layout.Section(tab, title)
                grid = PageKit.RowGrid(tab)
                if dim then dimGrids[#dimGrids + 1] = grid end
            end
            local function AddRow(config) return grid:Add(config) end

            Section('Bars')

            BuildSelectorRows(AddRow, 'TEXT', CurText,
                function() return selectedText end,
                function(barIndex) selectedText = barIndex end,
                {
                    label = 'Selected Bar', newLabel = 'New Bar',
                    desc = 'Pick a bar to edit, or create a new one.',
                    emptyDesc = 'No bars yet.',
                    enableLabel = 'Enable Bar',
                    enableDesc = 'Show this bar on screen.',
                })

            AddRow({
                title = 'Hide Tooltips in Combat',
                description = 'Suppress datatext tooltips and hover panels while fighting.',
                checked = BUI.GetDB().datatextHideHoversInCombat ~= false,
                callback = function(value) BUI.GetDB().datatextHideHoversInCombat = value end,
            })

            AddRow({
                title = 'Roster Tooltips',
                description = 'Member details (M+ score, key, click hints) when hovering Friends and Guild rows.',
                checked = BUI.GetDB().datatextRosterTooltips ~= false,
                callback = function(value) BUI.GetDB().datatextRosterTooltips = value end,
            })

            if CurText() then
                Section('Style', true)

                local fontDropdown
                local fonts = BUI.BuildFontDropdownItems('GLOBAL')
                AddRow({
                    spanFull = true,
                    title = 'Text Style',
                    description = 'Font and value color, with size, spacing and orientation.',
                    controlWidth = 170,
                    control = function(row)
                        fontDropdown = Controls.Dropdown(row, nil, fonts, CurText().font, function(value)
                            CurText().font = value; Datatext.Apply(); RefreshPreview()
                        end, nil, 160)
                        return fontDropdown
                    end,
                    accessoryWidth = 64,
                    accessories = function(row)
                        local fontCog = Controls.Icon(row, {
                            title = 'STYLE', tooltip = 'Size, spacing & orientation',
                            onChange = function() RefreshPreview() end,
                            options = {
                                { kind = 'slider', label = 'Font Size', min = 8, max = 24, step = 1,
                                  get = function() return CurText().fontSize end,
                                  set = function(value) CurText().fontSize = value; Datatext.Apply() end },
                                { kind = 'slider', label = 'Spacing (px)', min = 0, max = 160, step = 1,
                                  get = function() return CurText().spacing or 0 end,
                                  set = function(value) CurText().spacing = value; Datatext.Apply() end },
                                { kind = 'dropdown', label = 'Orientation', items = ORIENTATIONS,
                                  get = function() return CurText().orientation or 'HORIZONTAL' end,
                                  set = function(value) CurText().orientation = value; Datatext.Apply() end },
                                { kind = 'dropdown', label = 'Text Align', items = ALIGNMENTS,
                                  get = function() return CurText().align or 'LEFT' end,
                                  set = function(value) CurText().align = value; Datatext.Apply() end },
                                { label = 'Hide Labels',
                                  get = function() return CurText().hideLabels end,
                                  set = function(value) CurText().hideLabels = value; Datatext.Apply() end },
                            },
                        })
                        local valueColor = CurText().colorValue
                        local swatch = Controls.ColorSwatch(row, { r = valueColor.r, g = valueColor.g, b = valueColor.b, a = valueColor.a, callback = function(red, green, blue, alpha)
                            CurText().colorValue = {r = red, g = green, b = blue, a = alpha}; Datatext.Apply(); RefreshPreview()
                        end, tooltip = 'Value Color' })
                        return { fontCog, swatch }
                    end,
                })
                AddRefresh(function() fontDropdown:SetValue(CurText().font) end)

                Section('Modules', true)

                local moduleOptions = Datatext.BuildModuleOptions(CurText, Datatext.Apply)

                AddRow({
                    spanFull = true,
                    title = 'Display Modules',
                    description = 'Choose which readouts show, and their order.',
                    plain = true,
                    accessoryWidth = 64,
                    accessories = function(row)
                        local modulesCog = Controls.Icon(row, {
                            title = 'DISPLAY MODULES', tooltip = 'Choose which modules show',
                            texture = BUILib.GetLibMedia('modules5'),
                            options = moduleOptions, columns = 2, onChange = function() RefreshPreview() end,
                        })
                        local orderButton = Controls.Icon(row, {
                            texture = BUILib.GetLibMedia('shuffle'), tooltip = 'Reorder modules',
                            onClick = function(button)
                                Datatext.OpenOrderPopover(button, CurText(), function() Datatext.Apply(); RefreshPreview() end)
                            end,
                        })
                        return { modulesCog, orderButton }
                    end,
                })
            end

            grid:Flush()
        end

        local function BuildPanelsTab(tab)
            local grid
            local function Section(title)
                if grid then grid:Flush() end
                Layout.Section(tab, title)
                grid = PageKit.RowGrid(tab)
            end
            local function AddRow(config) return grid:Add(config) end

            Section('Panels')

            BuildSelectorRows(AddRow, 'PANEL', CurPanel,
                function() return selectedPanel end,
                function(barIndex) selectedPanel = barIndex end,
                {
                    label = 'Selected Panel', newLabel = 'New Panel',
                    desc = 'Pick a panel to edit, or create a new one.',
                    emptyDesc = 'No panels yet.',
                    enableLabel = 'Enable Panel',
                    enableDesc = 'Show this panel on screen.',
                })

            if CurPanel() then
                AddRow({
                    spanFull = true,
                    title = 'Panel Title',
                    description = 'Optional text label shown on the panel.',
                    controlWidth = 170,
                    control = function(row)
                        return Controls.TextBox(row, nil, CurPanel().title or '', function(text)
                            CurPanel().title = text or ''
                            Datatext.Apply(); RefreshPreview()
                        end, 'Panel title text (empty = none)', 160)
                    end,
                    accessoryWidth = 64,
                    accessories = function(row)
                        local titleCog = Controls.Icon(row, {
                            title = 'PANEL TITLE', tooltip = 'Title anchor, offsets & size',
                            onChange = function() RefreshPreview() end,
                            options = {
                                { kind = 'dropdown', label = 'Anchor', items = ANCHOR_POINTS,
                                  get = function() return CurPanel().titleAnchor or 'TOP' end,
                                  set = function(value) CurPanel().titleAnchor = value; Datatext.Apply() end },
                                { kind = 'slider', label = 'Offset X', min = -300, max = 300, step = 1,
                                  get = function() return CurPanel().titleX or 0 end,
                                  set = function(value) CurPanel().titleX = value; Datatext.Apply() end },
                                { kind = 'slider', label = 'Offset Y', min = -300, max = 300, step = 1,
                                  get = function() return CurPanel().titleY or 0 end,
                                  set = function(value) CurPanel().titleY = value; Datatext.Apply() end },
                                { kind = 'slider', label = 'Font Size', min = 8, max = 32, step = 1,
                                  get = function() return CurPanel().titleSize or 12 end,
                                  set = function(value) CurPanel().titleSize = value; Datatext.Apply() end },
                            },
                        })
                        local titleColor = CurPanel().titleColor or { r = 1, g = 1, b = 1 }
                        local titleSwatch = Controls.ColorSwatch(row, { r = titleColor.r, g = titleColor.g, b = titleColor.b, callback = function(red, green, blue)
                            CurPanel().titleColor = { r = red, g = green, b = blue }
                            Datatext.Apply(); RefreshPreview()
                        end, tooltip = 'Title Color' })
                        return { titleCog, titleSwatch }
                    end,
                })
            end

            grid:Flush()
        end

        local root, pinned
        root, pinned, titleBar = PageKit.Scaffold(pageFrame, {
            title = 'Datatext', titleDesc = 'Info bars with FPS, ping, gold, and more, plus blank background panels.',
            previewH = PREVIEW_HEIGHT, watermark = BUI.Tools.GetLogo(),
            titleEnable = { value = Datatext.ModuleEnabled(), gate = function() return BUI.IsModuleEnabled('datatext') end, onToggle = function(enabled)
                BUI.GetDB().datatextEnabled = enabled; Datatext.Apply(); SyncDim()
            end },
            titleAnchor = { value = ActiveCur() and not ActiveCur().lock or false, onToggle = function(unlocked)
                local current = ActiveCur()
                if not current then return end
                current.lock = not unlocked; Datatext.Apply()
            end },
            hostTabs = {
                defs = {
                    { key = 'text',   title = 'DATATEXTS', image = 'Interface\\Icons\\INV_Misc_Note_01' },
                    { key = 'panels', title = 'PANELS',    image = 'Interface\\Icons\\INV_Box_01' },
                },
                defaultKey = activeKind == 'PANEL' and 'panels' or 'text',
                onSelect = function(key)
                    activeKind = (key == 'panels') and 'PANEL' or 'TEXT'
                    local current = ActiveCur()
                    titleBar.anchorToggle:SetValue(current and not current.lock or false)
                    Datatext.SetLockToggle(titleBar.anchorToggle, activeKind == 'PANEL' and selectedPanel or selectedText)
                    RefreshPreview()
                end,
                build = function(def, tab)
                    if def.key == 'panels' then BuildPanelsTab(tab) else BuildTextTab(tab) end
                end,
            },
        })

        local preview = BuildDatatextPreview(pinned, DASH_WIDTH, PREVIEW_HEIGHT)
        RefreshPreview = function() preview:UpdatePreview() end

        AddRefresh(function() titleBar.enableToggle:SetValue(Datatext.ModuleEnabled()) end)
        AddRefresh(function()
            local current = ActiveCur()
            titleBar.anchorToggle:SetValue(current and not current.lock or false)
        end)
        Datatext.SetLockToggle(titleBar.anchorToggle, activeKind == 'PANEL' and selectedPanel or selectedText)

        SyncDim()

        pageFrame:SetScript('OnShow', function()
            for _, refresh in ipairs(refreshers) do refresh() end
            SyncDim(); RefreshPreview()
        end)
    end,
})
