local BUI = BluUI
local SetScript = BUI.Prof.Scripts('Pages.Cursor')
local Pixel = BUI.Pixel

local BUILib = BluUI.BUILibClient
local Controls = BUILib.Controls
local Layout = BUILib.Layout
local Theme = BUILib.Theme
local MouseCursor = BUI.MouseCursor
local RING_TEXTURE = BUI.C.CURSOR_RING_TEXTURE

local SLOT_DISPLAY = {
    { key = 'main',  header = 'MAIN RING'  },
    { key = 'inner', header = 'INNER RING' },
    { key = 'outer', header = 'OUTER RING' },
}

local MODE_OPTIONS = {
    { value = 'off',    text = 'Off'           },
    { value = 'static', text = 'Static Ring'   },
    { value = 'click',  text = 'Click Ring'    },
    { value = 'gcd',    text = 'GCD Swipe'     },
    { value = 'cast',   text = 'Cast Progress' },
}

local function GetCursorConfig() return BUI.GetDB().cursor end
local function Slot(name) return GetCursorConfig().slots[name] end

local PageKit = BUILib.PageKit

local function BuildPreview(parent)
    local card, stage = PageKit.PreviewStage(parent, { inset = 12 })
    card:SetClipsChildren(true)

    local holder = CreateFrame('Frame', nil, stage)
    holder:SetSize(1, 1)
    holder:SetPoint('CENTER')
    local holderLevel = holder:GetFrameLevel()

    local LOOP_DURATION, LOOP_GAP, CLICK_SWIPE_DURATION = 1.6, 0.3, 1.0
    local IDLE_CLICK_ALPHA = 0.35

    local widgets = {}
    for _, slotInfo in ipairs(SLOT_DISPLAY) do
        local layer = CreateFrame('Frame', nil, holder)
        layer:SetSize(1, 1)
        layer:SetPoint('CENTER')

        local ringTexture = layer:CreateTexture(nil, 'OVERLAY')
        ringTexture:SetTexture(RING_TEXTURE); ringTexture:SetPoint('CENTER'); ringTexture:Hide()

        local cooldown = CreateFrame('Cooldown', nil, layer)
        cooldown:SetPoint('CENTER')
        cooldown:SetSwipeTexture(RING_TEXTURE)
        cooldown:SetReverse(true)
        cooldown:SetDrawSwipe(true); cooldown:SetDrawEdge(false); cooldown:SetDrawBling(false)
        cooldown:SetHideCountdownNumbers(true)
        cooldown:Hide()

        widgets[slotInfo.key] = { layer = layer, tex = ringTexture, cd = cooldown, kind = 'none', nextLoop = 0 }
    end

    local dotLayer = CreateFrame('Frame', nil, holder)
    dotLayer:SetSize(1, 1)
    dotLayer:SetPoint('CENTER')
    dotLayer:SetFrameLevel(holderLevel + 20)
    local dot = dotLayer:CreateTexture(nil, 'OVERLAY')
    dot:SetTexture(BUILib.Widget.WHITE)
    dot:SetSize(Pixel.Scale(3), Pixel.Scale(3))
    dot:SetPoint('CENTER')
    do
        local red, green, blue = Theme.GetAccent()
        dot:SetVertexColor(red, green, blue, 0.9)
    end
    Theme.RegisterAccentElement(dot, function(element, red, green, blue) element:SetVertexColor(red, green, blue, 0.9) end)

    local function SlotDiameter(name)
        local config = GetCursorConfig()
        local settings = config.slots[name]
        return math.max(4, config.size + settings.offset)
    end

    function card:UpdateRing()
        for _, slotInfo in ipairs(SLOT_DISPLAY) do
            local key = slotInfo.key
            local settings = Slot(key)
            local widget = widgets[key]
            if not settings.enabled or settings.kind == 'none' then
                widget.kind = 'none'
                widget.tex:Hide(); widget.cd:Hide()
            else
                widget.kind = settings.kind
                widget.alpha = settings.alpha
                widget.nextLoop = 0
                widget.layer:SetFrameLevel(holderLevel + settings.zOrder)
                local diameter = Pixel.Scale(SlotDiameter(key))
                widget.tex:SetSize(diameter, diameter)
                widget.tex:SetVertexColor(settings.colorR, settings.colorG, settings.colorB, settings.alpha)
                widget.cd:SetSize(diameter, diameter)
                widget.cd:SetSwipeColor(settings.colorR, settings.colorG, settings.colorB, settings.alpha)

                widget.tex:Hide(); widget.cd:Hide()
                if widget.kind == 'static' then
                    widget.tex:Show()
                elseif widget.kind == 'click' then
                    widget.tex:SetVertexColor(settings.colorR, settings.colorG, settings.colorB, settings.alpha * IDLE_CLICK_ALPHA)
                    widget.tex:Show()
                elseif widget.kind == 'gcd' or widget.kind == 'cast' then
                    widget.cd:Show()
                end
            end
        end
    end

    local demoX, demoY, wasDown
    SetScript(card, 'OnUpdate', function(self, elapsed)
        local stageLeft, stageBottom = stage:GetLeft(), stage:GetBottom()
        local stageWidth, stageHeight = stage:GetWidth(), stage:GetHeight()
        if not stageLeft or not stageWidth or stageWidth <= 0 then return end

        local targetX, targetY = stageWidth / 2, stageHeight / 2
        local over = self:IsMouseOver()
        if over then
            local scale = stage:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            cursorX, cursorY = cursorX / scale - stageLeft, cursorY / scale - stageBottom
            targetX = math.min(math.max(cursorX, 0), stageWidth)
            targetY = math.min(math.max(cursorY, 0), stageHeight)
        end
        local smoothing = 1 - math.exp(-14 * elapsed)
        demoX = demoX and (demoX + (targetX - demoX) * smoothing) or targetX
        demoY = demoY and (demoY + (targetY - demoY) * smoothing) or targetY
        holder:ClearAllPoints()
        holder:SetPoint('CENTER', stage, 'BOTTOMLEFT', demoX, demoY)

        local now = GetTime()
        local down = over and IsMouseButtonDown('LeftButton')
        for _, slotInfo in ipairs(SLOT_DISPLAY) do
            local widget = widgets[slotInfo.key]
            if widget.kind == 'gcd' or widget.kind == 'cast' then
                if down and not wasDown and widget.kind == 'gcd' then
                    widget.cd:SetCooldown(now, CLICK_SWIPE_DURATION)
                    widget.nextLoop = now + CLICK_SWIPE_DURATION + LOOP_GAP
                elseif now >= widget.nextLoop then
                    widget.cd:SetCooldown(now, LOOP_DURATION)
                    widget.nextLoop = now + LOOP_DURATION + LOOP_GAP
                end
            elseif widget.kind == 'click' and down ~= wasDown then
                local slotSettings = Slot(slotInfo.key)
                local alpha = down and slotSettings.alpha or (slotSettings.alpha * IDLE_CLICK_ALPHA)
                widget.tex:SetVertexColor(slotSettings.colorR, slotSettings.colorG, slotSettings.colorB, alpha)
            end
        end
        wasDown = down
    end)

    card:UpdateRing()
    return card
end

BUI.PageEngine.RegisterPage("cursor", {
    title = "Cursor",
    buttonText = "Cursor",
    minContentWidth  = 924,
    minContentHeight = 560,
    OnBuild = function(pageFrame)
        local CONTENT_WIDTH  = BUILib.Layout.PAGE_CONTENT_W
        local PREVIEW_HEIGHT = BUILib.Layout.PAGE_PREVIEW_H

        local mark = pageFrame:CreateTexture(nil, 'BACKGROUND', nil, 1)
        mark:SetTexture(BUI.Tools.GetLogo())
        mark:SetSize(520, 520)
        mark:SetPoint('CENTER')
        mark:SetVertexColor(1, 1, 1, 0.06)

        local SyncDim
        local titleHeight, titleBar = PageKit.PageTitle(pageFrame, 'Cursor', CONTENT_WIDTH, {
            desc = 'Rings and cast feedback that follow your mouse cursor.',
            enable = { value = BUI.IsModuleEnabled('cursor'), onToggle = function(enabled)
                BUI.SetModuleEnabled('cursor', enabled); SyncDim()
            end },
        })
        local topY = PageKit.PAD + titleHeight

        local pinned = PageKit.PreviewBand(pageFrame, CONTENT_WIDTH, PREVIEW_HEIGHT, topY)
        local contentTop = topY + PREVIEW_HEIGHT + PageKit.GAP

        local host = CreateFrame('Frame', nil, pageFrame)
        host:SetPoint('TOPLEFT', pageFrame, 'TOPLEFT', 0, -contentTop)
        host:SetPoint('BOTTOMRIGHT', pageFrame, 'BOTTOMRIGHT', 0, 0)
        local page = Layout.Page(host, nil, CONTENT_WIDTH)
        local tab = page:GetTab(1)
        tab.topPadding = 0

        local preview = BuildPreview(pinned)
        local function RefreshPreview() preview:UpdateRing() end

        local refreshers = {}
        local function AddRefresh(refreshCallback) refreshers[#refreshers + 1] = refreshCallback end

        local function Apply() MouseCursor.Apply() end

        local function flatSetting(key)
            return {
                get = function() return GetCursorConfig()[key] end,
                set = function(value) GetCursorConfig()[key] = value end,
            }
        end
        local function slotSetting(slot, key)
            return {
                get = function() return Slot(slot)[key] end,
                set = function(value) Slot(slot)[key] = value end,
            }
        end
        local function slotMode(slot)
            return {
                get = function()
                    local slotSettings = Slot(slot)
                    if not slotSettings.enabled or slotSettings.kind == 'none' then return 'off' end
                    return slotSettings.kind
                end,
                set = function(value)
                    local slotSettings = Slot(slot)
                    if value == 'off' then
                        slotSettings.enabled = false
                    else
                        slotSettings.enabled = true
                        slotSettings.kind = value
                    end
                end,
            }
        end
        local function slotRGBA(slot)
            return {
                get = function() local slotSettings = Slot(slot); return slotSettings.colorR, slotSettings.colorG, slotSettings.colorB, slotSettings.alpha end,
                set = function(red, green, blue, alpha) local slotSettings = Slot(slot); slotSettings.colorR, slotSettings.colorG, slotSettings.colorB, slotSettings.alpha = red, green, blue, alpha end,
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
        local function AddRow(config)
            return grid:Add(config)
        end

        SyncDim = function()
            local enabled = BUI.IsModuleEnabled('cursor')
            for gridIndex = 1, #grids do grids[gridIndex]:SyncDim(enabled) end
        end

        AddRefresh(function() titleBar.enableToggle:SetValue(BUI.IsModuleEnabled('cursor')) end)

        Section('General')

        do
            local size = flatSetting('size')
            AddRow({
                title = 'Cursor Size',
                description = 'Diameter of the rings that follow your cursor.',
                plain = true,
                accessoryWidth = 36,
                accessories = function(row)
                    return { PageKit.SizeIcon(row, { title = 'CURSOR SIZE', tooltip = 'Ring size', onChange = RefreshPreview, options = {
                        { kind = 'slider', label = 'Size', min = 8, max = 160,
                          get = size.get, set = size.set, apply = Apply },
                    } }) }
                end,
            })
        end

        do
            local combatOnly = flatSetting('combatOnly')
            local combatRow = AddRow({
                title = 'Show Only In Combat',
                description = 'Hide the rings while out of combat.',
                checked = combatOnly.get() and true or false,
                callback = function(value) combatOnly.set(value); MouseCursor.Refresh(); RefreshPreview() end,
            })
            if combatRow then
                AddRefresh(function() combatRow:SetValue(combatOnly.get() and true or false) end)
            end
        end

        do
            local hideOverMenus = flatSetting('hideOverMenus')
            local menuRow = AddRow({
                title = 'Hide Over BluUI Menus',
                description = 'Hide the rings while the cursor is over BluUI windows, menus, and popups.',
                checked = hideOverMenus.get() and true or false,
                callback = function(value) hideOverMenus.set(value); MouseCursor.Apply() end,
            })
            if menuRow then
                AddRefresh(function() menuRow:SetValue(hideOverMenus.get() and true or false) end)
            end
        end

        Section('Rings')

        local RING_DESC = {
            main  = 'The base ring that follows your cursor.',
            inner = 'A second ring stacked with the main ring.',
            outer = 'A third ring stacked with the main ring.',
        }

        for _, slotInfo in ipairs(SLOT_DISPLAY) do
            local slot = slotInfo.key
            local mode = slotMode(slot)
            local color = slotRGBA(slot)
            local offset = slotSetting(slot, 'offset')
            local layer = slotSetting(slot, 'zOrder')

            AddRow({
                spanFull = true,
                title = slotInfo.header,
                description = RING_DESC[slot],
                controlWidth = 160,
                control = function(row)
                    local dropdown = Controls.Dropdown(row, nil, MODE_OPTIONS, mode.get(), function(value)
                        mode.set(value); Apply(); RefreshPreview()
                    end, nil, 150)
                    AddRefresh(function() dropdown:SetValue(mode.get()) end)
                    return dropdown
                end,
                accessoryWidth = 94,
                accessories = function(row)
                    local sizeIcon = PageKit.SizeIcon(row, { title = slotInfo.header .. ' SIZE', tooltip = 'Size offset', onChange = RefreshPreview, options = {
                        { kind = 'slider', label = 'Size Offset', min = -40, max = 80,
                          get = offset.get, set = offset.set, apply = Apply },
                    } })
                    local settingsIcon = PageKit.SettingsIcon(row, { title = slotInfo.header, tooltip = 'Stacking layer', onChange = RefreshPreview, options = {
                        { kind = 'slider', label = 'Layer', min = 1, max = 10,
                          get = layer.get, set = layer.set, apply = Apply },
                    } })
                    local red, green, blue, alpha = color.get()
                    local swatch = Controls.ColorSwatch(row, { r = red, g = green, b = blue, a = alpha, tooltip = 'Color',
                        callback = function(newRed, newGreen, newBlue, newAlpha)
                            color.set(newRed, newGreen, newBlue, newAlpha); MouseCursor.Apply(); RefreshPreview()
                        end })
                    AddRefresh(function() swatch:SetColor(color.get()) end)
                    return { sizeIcon, settingsIcon, swatch }
                end,
            })
        end

        grid:Flush()

        SyncDim()

        SetScript(pageFrame, "OnShow", function()
            for _, refresh in ipairs(refreshers) do refresh() end
            SyncDim(); RefreshPreview()
        end)

        page:AutoRefresh()
    end,
})
