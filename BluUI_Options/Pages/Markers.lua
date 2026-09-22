local BUI = BluUI
local SetScript = BUI.Prof.Scripts('Pages.Markers')

local BUILib = BluUI.BUILibClient
local Layout = BUILib.Layout
local PageKit = BUILib.PageKit

local function GetConfig() return BUI.GetDB().markers end

BUI.PageEngine.RegisterPage('markers', {
    title = 'Markers',
    buttonText = 'Markers',
    minContentWidth  = 924,
    minContentHeight = 480,
    OnBuild = function(pageFrame)
        local DASH_WIDTH = BUILib.Layout.PAGE_CONTENT_W

        local watermark = pageFrame:CreateTexture(nil, 'BACKGROUND', nil, 1)
        watermark:SetTexture(BUI.Tools.GetLogo())
        watermark:SetSize(520, 520)
        watermark:SetPoint('CENTER')
        watermark:SetVertexColor(1, 1, 1, 0.06)

        local SyncDim
        local titleHeight, titleBar = PageKit.PageTitle(pageFrame, 'Markers', DASH_WIDTH, {
            desc = 'Raid target and world marker bar. Click marks your target, '
                .. 'Shift-Click places a world marker, Shift-Right-Click clears it.',
            enable = { value = BUI.IsModuleEnabled('markers'), onToggle = function(enabled)
                BUI.SetModuleEnabled('markers', enabled); SyncDim()
            end },
        })
        local contentTop = PageKit.PAD + titleHeight

        local host = CreateFrame('Frame', nil, pageFrame)
        host:SetPoint('TOPLEFT', pageFrame, 'TOPLEFT', 0, -contentTop)
        host:SetPoint('BOTTOMRIGHT', pageFrame, 'BOTTOMRIGHT', 0, 0)
        local page = Layout.Page(host, nil, DASH_WIDTH)
        local tab = page:GetTab(1)
        tab.topPadding = 0

        local refreshers = {}
        local function AddRefresh(refreshFunction) refreshers[#refreshers + 1] = refreshFunction end

        local function Apply() BUI.Markers.Refresh() end

        local function flatSetting(key)
            return {
                get = function() return GetConfig()[key] end,
                set = function(value) GetConfig()[key] = value end,
            }
        end

        local grids = {}
        local grid
        local function Section(title)
            if grid then grid:Flush() end
            Layout.Section(tab, title)
            grid = PageKit.RowGrid(tab)
            grids[#grids + 1] = grid
        end

        SyncDim = function()
            local enabled = BUI.IsModuleEnabled('markers')
            for gridIndex = 1, #grids do grids[gridIndex]:SyncDim(enabled) end
        end

        AddRefresh(function() titleBar.enableToggle:SetValue(BUI.IsModuleEnabled('markers')) end)

        Section('General')

        do
            local onlyGroup = flatSetting('onlyInGroup')
            local row = grid:Add({
                title = 'Show Only In Group',
                description = 'Hide the bar while not in a party or raid.',
                checked = onlyGroup.get() and true or false,
                callback = function(checked) onlyGroup.set(checked); Apply() end,
            })
            if row then AddRefresh(function() row:SetValue(onlyGroup.get() and true or false) end) end
        end

        do
            local tips = flatSetting('tooltips')
            local row = grid:Add({
                title = 'Show Tooltips',
                description = 'Explain each button on mouseover.',
                checked = tips.get() and true or false,
                callback = function(checked) tips.set(checked) end,
            })
            if row then AddRefresh(function() row:SetValue(tips.get() and true or false) end) end
        end

        do
            grid:Add({
                title = 'Position & Anchor',
                description = 'Screen position, or anchor the bar to another BluUI frame and match its width.',
                plain = true,
                accessoryWidth = 36,
                accessories = function(row)
                    return { BUI.AlertMover(row, GetConfig(), Apply, {
                        selfTag = 'BUI_MarkerBar',
                        noCenter = true,
                        matchWidth = {
                            get = function() return GetConfig().matchAnchorWidth and true or false end,
                            set = function(value) GetConfig().matchAnchorWidth = value; Apply() end,
                        },
                    }) }
                end,
            })
        end

        do
            local fade = flatSetting('fadeEnabled')
            local row = grid:Add({
                title = 'Mouseover Fade',
                description = 'Fade the bar out until the cursor is over it. The cog sets opacity and whether the fade is animated or instant.',
                checked = fade.get() and true or false,
                accessoryWidth = 36,
                callback = function(checked) fade.set(checked and true or false); Apply() end,
                accessories = function(row)
                    return { PageKit.SettingsIcon(row, { title = 'FADING', tooltip = 'Opacity, animation and fade time', options = {
                        { kind = 'slider', label = 'Bar Opacity %', min = 10, max = 100,
                          get = flatSetting('alpha').get, set = flatSetting('alpha').set, apply = Apply },
                        { kind = 'slider', label = 'Faded Opacity %', min = 0, max = 100,
                          get = flatSetting('fadeAlpha').get, set = flatSetting('fadeAlpha').set, apply = Apply },
                        { label = 'Animated',
                          get = flatSetting('fadeAnimated').get, set = flatSetting('fadeAnimated').set, apply = Apply },
                        { kind = 'slider', label = 'Fade Time (s)', min = 0.05, max = 1, step = 0.05,
                          get = flatSetting('fadeDuration').get, set = flatSetting('fadeDuration').set, apply = Apply },
                    } }) }
                end,
            })
            if row then AddRefresh(function() row:SetValue(fade.get() and true or false) end) end
        end

        do
            local size = flatSetting('iconSize')
            local spacing = flatSetting('spacing')
            grid:Add({
                title = 'Bar Size',
                description = 'Icon size and spacing. Applied after combat ends.',
                plain = true,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.SizeIcon(row, { title = 'BAR SIZE', tooltip = 'Icon size and spacing', options = {
                        { kind = 'slider', label = 'Icon Size', min = 16, max = 40,
                          get = size.get, set = size.set, apply = Apply },
                        { kind = 'slider', label = 'Spacing', min = 0, max = 12,
                          get = spacing.get, set = spacing.set, apply = Apply },
                    } }) }
                end,
            })
        end

        Section('Utility Buttons')

        do
            local show = flatSetting('showControls')
            local row = grid:Add({
                title = 'Show Utility Buttons',
                description = 'Clear, ready check, and countdown beside the markers.',
                checked = show.get() ~= false,
                callback = function(checked) show.set(checked and true or false); Apply() end,
            })
            if row then AddRefresh(function() row:SetValue(show.get() ~= false) end) end
        end

        do
            local primaryTime = flatSetting('countdownTime')
            local secondaryTime = flatSetting('countdownTime2')
            grid:Add({
                title = 'Countdown Timers',
                description = 'Click starts the primary countdown, Right-Click the secondary, '
                    .. 'Shift-Click cancels.',
                plain = true,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.SettingsIcon(row, { title = 'COUNTDOWN SECONDS', tooltip = 'Countdown durations', options = {
                        { kind = 'slider', label = 'Primary', min = 0, max = 60,
                          get = primaryTime.get, set = primaryTime.set, apply = Apply },
                        { kind = 'slider', label = 'Secondary', min = 0, max = 60,
                          get = secondaryTime.get, set = secondaryTime.set, apply = Apply },
                    } }) }
                end,
            })
        end

        grid:Flush()

        SyncDim()

        SetScript(pageFrame, 'OnShow', function()
            for _, refresh in ipairs(refreshers) do refresh() end
            SyncDim()
        end)

        page:AutoRefresh()
    end,
})
