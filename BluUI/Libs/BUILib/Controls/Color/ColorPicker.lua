local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget

local floor, min, max = math.floor, math.min, math.max
local abs, format = math.abs, string.format

local MAX_FAVORITES = 12
local MAX_RECENT    = 10
local GRID_SIZE     = 260
local GRID_RES      = 40
local GRID_CELL     = GRID_SIZE / GRID_RES
local STRIP_HEIGHT  = 12
local SWATCH_SIZE   = 16
local SWATCH_GAP    = 2
local PADDING       = 14
local PREVIEW_SIZE  = 28
local LABEL_HEIGHT  = 14
local SECTION_GAP   = 8
local ROW_GAP       = 9
local BUTTON_HEIGHT = 26
local BOTTOM_PAD    = 20

local CLASS_ORDER = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER",
    "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE",
    "SHAMAN", "WARLOCK", "WARRIOR",
}
local CLASS_LABEL = {
    DEATHKNIGHT = "Death Knight", DEMONHUNTER = "Demon Hunter", DRUID = "Druid",
    EVOKER = "Evoker", HUNTER = "Hunter", MAGE = "Mage", MONK = "Monk",
    PALADIN = "Paladin", PRIEST = "Priest", ROGUE = "Rogue", SHAMAN = "Shaman",
    WARLOCK = "Warlock", WARRIOR = "Warrior",
}

local function HSVtoRGB(hue, saturation, value)
    if saturation == 0 then return value, value, value end
    hue = hue * 6
    local sector = floor(hue)
    local fraction = hue - sector
    local low = value * (1 - saturation)
    local falling = value * (1 - saturation * fraction)
    local rising = value * (1 - saturation * (1 - fraction))
    if sector == 0 then return value, rising, low
    elseif sector == 1 then return falling, value, low
    elseif sector == 2 then return low, value, rising
    elseif sector == 3 then return low, falling, value
    elseif sector == 4 then return rising, low, value
    else return value, low, falling end
end

local function RGBtoHSV(red, green, blue)
    local maxChannel, minChannel = max(red, green, blue), min(red, green, blue)
    local delta = maxChannel - minChannel
    local hue, saturation, value = 0, 0, maxChannel
    if maxChannel ~= 0 then
        saturation = delta / maxChannel
        if delta ~= 0 then
            if maxChannel == red then hue = ((green - blue) / delta) % 6
            elseif maxChannel == green then hue = (blue - red) / delta + 2
            else hue = (red - green) / delta + 4 end
            hue = hue / 6
            if hue < 0 then hue = hue + 1 end
        end
    end
    return hue, saturation, value
end

local function RGBtoHex(red, green, blue)
    return format("%02X%02X%02X", floor(red * 255 + 0.5), floor(green * 255 + 0.5), floor(blue * 255 + 0.5))
end

local function HexToRGB(hex)
    hex = hex:gsub("^#", "")
    if #hex ~= 6 then return nil end
    local redByte = tonumber(hex:sub(1, 2), 16)
    local greenByte = tonumber(hex:sub(3, 4), 16)
    local blueByte = tonumber(hex:sub(5, 6), 16)
    if not redByte or not greenByte or not blueByte then return nil end
    return redByte / 255, greenByte / 255, blueByte / 255
end

local function ClassColor(class)
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if classColor then return classColor.r, classColor.g, classColor.b end
    return 1, 1, 1
end

function Controls.SetColorPickerDB(getter) Controls.__pickerDBGetter = getter end

local function GetFavorites()

    local client = BUILib.GetActiveClient()
    local dbGetter = (client and client.getDB) or Controls.__pickerDBGetter
    if not dbGetter then return {} end
    local db = dbGetter()
    if not db or not db.general then return {} end
    db.general.colorPickerFavorites = db.general.colorPickerFavorites or {}
    return db.general.colorPickerFavorites
end

local fallbackRecent = {}

local function GetRecent()
    local client = BUILib.GetActiveClient()
    if not client then return fallbackRecent end
    client.__colorPickerRecent = client.__colorPickerRecent or {}
    return client.__colorPickerRecent
end

local function AddRecent(red, green, blue, alpha)
    local recentColors = GetRecent()
    for index = 1, #recentColors do
        local color = recentColors[index]
        if abs(color[1] - red) < 0.02 and abs(color[2] - green) < 0.02 and abs(color[3] - blue) < 0.02 then
            table.remove(recentColors, index)
            break
        end
    end
    table.insert(recentColors, 1, {red, green, blue, alpha})
    if #recentColors > MAX_RECENT then recentColors[#recentColors] = nil end
end

local function BuildGridCells(parent)
    local cells = {}
    for row = 0, GRID_RES - 1 do
        cells[row] = {}
        for column = 0, GRID_RES - 1 do
            local texture = parent:CreateTexture(nil, "ARTWORK")
            texture:SetTexture(Widget.WHITE)
            texture:SetSize(GRID_CELL + 0.5, GRID_CELL + 0.5)
            texture:SetPoint("TOPLEFT", column * GRID_CELL, -row * GRID_CELL)
            texture:SetSnapToPixelGrid(false)
            texture:SetTexelSnappingBias(0)
            cells[row][column] = texture
        end
    end
    return cells
end

local function PaintGrid(cells, hue)
    for row = 0, GRID_RES - 1 do
        local value = 1 - row / GRID_RES
        for column = 0, GRID_RES - 1 do
            local red, green, blue = HSVtoRGB(hue, column / GRID_RES, value)
            cells[row][column]:SetVertexColor(red, green, blue, 1)
        end
    end
end

local function NewLabel(parent, text)
    local fontString = parent:CreateFontString(nil, "OVERLAY")
    fontString:SetFont(BUILib.Font, 10, "OUTLINE")
    fontString:SetTextColor(0.45, 0.45, 0.45)
    fontString:SetText(text)
    return fontString
end

local function NewButton(parent, text, width, height)
    local buttonWidget = Widget.New(parent, "Button", nil, {bg = Theme.button.normal, border = Theme.border.default, size = {width, height}})
    local button = buttonWidget.frame
    local fontString = button:CreateFontString(nil, "OVERLAY")
    fontString:SetFont(BUILib.Font, 11, "OUTLINE")
    fontString:SetPoint("CENTER")
    fontString:SetText(text)
    fontString:SetTextColor(1, 1, 1)
    buttonWidget:SetHover(Theme.button.normal, Theme.button.hover)
    return button
end

local function NewSwatch(parent, size)
    local swatch = Widget.New(parent, "Button", nil, {bg = {0.1, 0.1, 0.1, 1}, border = Theme.border.dark, size = {size, size}}).frame
    swatch:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        if self.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
            GameTooltip:SetText(self.tooltip, 1, 1, 1)
            GameTooltip:SetFrameStrata("TOOLTIP")
            GameTooltip:SetFrameLevel(200)
            GameTooltip:Show()
        end
    end)
    swatch:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(Theme.border.dark))
        GameTooltip:Hide()
    end)
    return swatch
end

local function BuildCheckerboard(parent, cellSize, columnCount, rowCount)
    for row = 0, rowCount - 1 do
        for column = 0, columnCount - 1 do
            local texture = parent:CreateTexture(nil, "BACKGROUND")
            texture:SetTexture(Widget.WHITE)
            texture:SetSize(cellSize, cellSize)
            texture:SetPoint("TOPLEFT", column * cellSize, -row * cellSize)
            local shade = ((row + column) % 2 == 0) and 0.25 or 0.1
            texture:SetVertexColor(shade, shade, shade, 1)
        end
    end
end

local function MakeDraggable(strip, onMove)
    strip:EnableMouse(true)
    strip:SetScript("OnMouseDown", function(self)
        onMove()
        self:SetScript("OnUpdate", function(updateFrame)
            if IsMouseButtonDown("LeftButton") then onMove()
            else updateFrame:SetScript("OnUpdate", nil) end
        end)
    end)
end

local picker

local function BuildPicker()
    local frameWidth = GRID_SIZE + PADDING * 2

    local frame = CreateFrame("Frame", "BUILibColorPicker", UIParent, "BackdropTemplate")
    frame.isBluUIWindow = true
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop(Widget.BACKDROP)
    frame:SetBackdropColor(unpack(Theme.bg.dark))
    frame:SetBackdropBorderColor(unpack(Theme.border.default))
    frame:SetWidth(frameWidth)

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local title = titleBar:CreateFontString(nil, "OVERLAY")
    title:SetFont(BUILib.Font, 12, "OUTLINE")
    title:SetPoint("CENTER")
    title:SetText("Color Picker")
    title:SetTextColor(1, 1, 1)

    local closeButton = Controls.Icon(titleBar, { preset = "close", size = 20, onClick = function() frame:Hide() end })
    closeButton:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)

    local saturationValueField = Widget.New(frame, "Frame", nil, {bg = {0, 0, 0, 1}, border = Theme.border.dark, size = {GRID_SIZE, GRID_SIZE}}).frame
    local saturationValueCells = BuildGridCells(saturationValueField)

    local cursor = CreateFrame("Frame", nil, saturationValueField)
    cursor:SetSize(14, 14)
    cursor:SetFrameLevel(saturationValueField:GetFrameLevel() + 10)
    local cursorOuter = cursor:CreateTexture(nil, "OVERLAY", nil, 5)
    cursorOuter:SetTexture(Widget.WHITE); cursorOuter:SetSize(14, 14); cursorOuter:SetPoint("CENTER")
    cursorOuter:SetVertexColor(0, 0, 0, 0.9)
    local cursorMid = cursor:CreateTexture(nil, "OVERLAY", nil, 6)
    cursorMid:SetTexture(Widget.WHITE); cursorMid:SetSize(10, 10); cursorMid:SetPoint("CENTER")
    cursorMid:SetVertexColor(1, 1, 1, 0.95)
    local cursorInner = cursor:CreateTexture(nil, "OVERLAY", nil, 7)
    cursorInner:SetTexture(Widget.WHITE); cursorInner:SetSize(6, 6); cursorInner:SetPoint("CENTER")

    local hueLabel = NewLabel(frame, "HUE")
    local hueStrip = Widget.New(frame, "Frame", nil, {bg = {0, 0, 0, 1}, border = Theme.border.dark, size = {GRID_SIZE, STRIP_HEIGHT}}).frame

    local HUE_STOPS = {{1,0,0},{1,1,0},{0,1,0},{0,1,1},{0,0,1},{1,0,1},{1,0,0}}
    local segmentWidth = GRID_SIZE / 6
    for segmentIndex = 1, 6 do
        local segment = hueStrip:CreateTexture(nil, "ARTWORK")
        segment:SetTexture(Widget.WHITE)
        segment:SetSize(segmentWidth + 1, STRIP_HEIGHT)
        segment:SetPoint("LEFT", (segmentIndex - 1) * segmentWidth, 0)
        local startStop, endStop = HUE_STOPS[segmentIndex], HUE_STOPS[segmentIndex + 1]
        segment:SetGradient("HORIZONTAL", CreateColor(startStop[1], startStop[2], startStop[3], 1), CreateColor(endStop[1], endStop[2], endStop[3], 1))
    end

    local hueThumb = Widget.New(hueStrip, "Frame", nil, {bg = {1, 1, 1, 0.9}, border = {0, 0, 0, 1}, size = {4, STRIP_HEIGHT + 6}}).frame
    hueThumb:SetFrameLevel(hueStrip:GetFrameLevel() + 5)

    local opacityLabel = NewLabel(frame, "OPACITY")
    local opacityStrip = Widget.New(frame, "Frame", nil, {bg = {0, 0, 0, 1}, border = Theme.border.dark, size = {GRID_SIZE, STRIP_HEIGHT}}).frame
    BuildCheckerboard(opacityStrip, 6, floor(GRID_SIZE / 6), 2)
    local opacityGradient = opacityStrip:CreateTexture(nil, "ARTWORK")
    opacityGradient:SetTexture(Widget.WHITE); opacityGradient:SetAllPoints()
    local opacityThumb = Widget.New(opacityStrip, "Frame", nil, {bg = {1, 1, 1, 0.9}, border = {0, 0, 0, 1}, size = {4, STRIP_HEIGHT + 6}}).frame
    opacityThumb:SetFrameLevel(opacityStrip:GetFrameLevel() + 5)

    local previewBg = Widget.New(frame, "Frame", nil, {bg = {0, 0, 0, 1}, border = Theme.border.dark, size = {PREVIEW_SIZE, PREVIEW_SIZE}}).frame
    BuildCheckerboard(previewBg, 7, 4, 4)
    local previewTex = previewBg:CreateTexture(nil, "ARTWORK")
    previewTex:SetTexture(Widget.WHITE); previewTex:SetAllPoints()

    local hexBox = Widget.New(frame, "EditBox", nil, {bg = Theme.bg.input, border = Theme.border.input, size = {82, PREVIEW_SIZE}}).frame
    hexBox:SetPoint("LEFT", previewBg, "RIGHT", 6, 0)
    hexBox:SetAutoFocus(false)
    hexBox:SetMaxLetters(7)
    hexBox:SetFont(BUILib.Font, 11, "OUTLINE")
    hexBox:SetTextColor(1, 1, 1)
    hexBox:SetTextInsets(6, 6, 0, 0)

    local alphaText = frame:CreateFontString(nil, "OVERLAY")
    alphaText:SetFont(BUILib.Font, 12, "OUTLINE")
    alphaText:SetPoint("LEFT", hexBox, "RIGHT", 10, 0)
    alphaText:SetTextColor(0.6, 0.6, 0.6)

    local classLabel = NewLabel(frame, "CLASS")
    local classSwatches = {}
    for classIndex, token in ipairs(CLASS_ORDER) do
        local swatch = NewSwatch(frame, SWATCH_SIZE)
        local red, green, blue = ClassColor(token)
        swatch:SetBackdropColor(red, green, blue, 1)
        swatch.tooltip = CLASS_LABEL[token]
        swatch.color = {red, green, blue, 1}
        classSwatches[classIndex] = swatch
    end

    local favoritesLabel = NewLabel(frame, "SAVED")
    local favoritesHint = frame:CreateFontString(nil, "OVERLAY")
    favoritesHint:SetFont(BUILib.Font, 8, "OUTLINE")
    favoritesHint:SetTextColor(0.3, 0.3, 0.3)
    favoritesHint:SetText("R-click save  |  Shift-R clear")
    favoritesHint:SetPoint("LEFT", favoritesLabel, "RIGHT", 6, 0)

    local favoriteSwatches = {}
    for favoriteIndex = 1, MAX_FAVORITES do
        local swatch = NewSwatch(frame, SWATCH_SIZE)
        swatch:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        favoriteSwatches[favoriteIndex] = swatch
    end

    local recentLabel = NewLabel(frame, "RECENT")
    local recentSwatches = {}
    for recentIndex = 1, MAX_RECENT do
        local swatch = NewSwatch(frame, SWATCH_SIZE)
        swatch:Hide()
        recentSwatches[recentIndex] = swatch
    end

    local okButton = NewButton(frame, "OK", 80, BUTTON_HEIGHT)
    okButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PADDING, 10)
    local cancelButton = NewButton(frame, "Cancel", 80, BUTTON_HEIGHT)
    cancelButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, 10)

    frame.h, frame.s, frame.v, frame.a = 0, 1, 1, 1
    frame.lastGridHue = -1
    frame.hasOpacity = true
    local gradientStart = CreateColor(0, 0, 0, 0)
    local gradientEnd   = CreateColor(1, 1, 1, 1)

    local function Render()
        local hue, saturation, value, alpha = frame.h, frame.s, frame.v, frame.a
        local red, green, blue = HSVtoRGB(hue, saturation, value)

        if abs(hue - frame.lastGridHue) > 0.003 then
            PaintGrid(saturationValueCells, hue)
            frame.lastGridHue = hue
        end

        cursor:ClearAllPoints()
        cursor:SetPoint("CENTER", saturationValueField, "TOPLEFT", saturation * GRID_SIZE, -(1 - value) * GRID_SIZE)
        cursorInner:SetVertexColor(red, green, blue, 1)

        hueThumb:ClearAllPoints()
        hueThumb:SetPoint("CENTER", hueStrip, "LEFT", hue * GRID_SIZE, 0)

        if frame.hasOpacity then
            gradientStart.r, gradientStart.g, gradientStart.b = red, green, blue
            gradientEnd.r,   gradientEnd.g,   gradientEnd.b   = red, green, blue
            opacityGradient:SetGradient("HORIZONTAL", gradientStart, gradientEnd)
            opacityThumb:ClearAllPoints()
            opacityThumb:SetPoint("CENTER", opacityStrip, "LEFT", alpha * GRID_SIZE, 0)
            alphaText:SetText(floor(alpha * 100 + 0.5) .. "%")
        end

        previewTex:SetVertexColor(red, green, blue, alpha)
        if not hexBox:HasFocus() then hexBox:SetText("#" .. RGBtoHex(red, green, blue)) end
        if frame.callback then frame.callback(red, green, blue, alpha, false, 'preview') end
    end
    frame.Render = Render

    MakeDraggable(saturationValueField, function()
        local scale = saturationValueField:GetEffectiveScale()
        local mouseX, mouseY = GetCursorPosition()
        frame.s = max(0, min(1, (mouseX / scale - saturationValueField:GetLeft()) / GRID_SIZE))
        frame.v = max(0, min(1, (mouseY / scale - saturationValueField:GetBottom()) / GRID_SIZE))
        Render()
    end)

    MakeDraggable(hueStrip, function()
        local mouseX = GetCursorPosition() / hueStrip:GetEffectiveScale()
        frame.h = max(0, min(0.999, (mouseX - hueStrip:GetLeft()) / GRID_SIZE))
        Render()
    end)

    MakeDraggable(opacityStrip, function()
        if not frame.hasOpacity then return end
        local mouseX = GetCursorPosition() / opacityStrip:GetEffectiveScale()
        frame.a = max(0, min(1, (mouseX - opacityStrip:GetLeft()) / GRID_SIZE))
        Render()
    end)

    hexBox:SetScript("OnEnterPressed", function(self)
        local hexRed, hexGreen, hexBlue = HexToRGB(self:GetText())
        if hexRed then
            frame.h, frame.s, frame.v = RGBtoHSV(hexRed, hexGreen, hexBlue)
            Render()
        end
        self:ClearFocus()
    end)
    hexBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local function ApplyColor(red, green, blue, alpha)
        frame.h, frame.s, frame.v = RGBtoHSV(red, green, blue)
        frame.a = frame.hasOpacity and (alpha or 1) or 1
        Render()
    end

    for _, swatch in ipairs(classSwatches) do
        swatch:SetScript("OnClick", function(self)
            local color = self.color
            ApplyColor(color[1], color[2], color[3], 1)
        end)
    end

    for favoriteIndex, swatch in ipairs(favoriteSwatches) do
        swatch:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                local favorites = GetFavorites()
                if IsShiftKeyDown() then
                    favorites[favoriteIndex] = nil
                    self:SetBackdropColor(0.1, 0.1, 0.1, 1)
                else
                    local red, green, blue = HSVtoRGB(frame.h, frame.s, frame.v)
                    favorites[favoriteIndex] = {red, green, blue, frame.a}
                    self:SetBackdropColor(red, green, blue, frame.a)
                end
            else
                local favorite = GetFavorites()[favoriteIndex]
                if favorite then ApplyColor(favorite[1], favorite[2], favorite[3], favorite[4]) end
            end
        end)
    end

    for _, swatch in ipairs(recentSwatches) do
        swatch:SetScript("OnClick", function(self)
            local color = self.color
            if color then ApplyColor(color[1], color[2], color[3], color[4]) end
        end)
    end

    local function RefreshFavorites()
        local favorites = GetFavorites()
        for favoriteIndex = 1, MAX_FAVORITES do
            local favorite = favorites[favoriteIndex]
            if favorite then favoriteSwatches[favoriteIndex]:SetBackdropColor(favorite[1], favorite[2], favorite[3], favorite[4] or 1)
            else favoriteSwatches[favoriteIndex]:SetBackdropColor(0.1, 0.1, 0.1, 1) end
        end
    end
    frame.RefreshFavorites = RefreshFavorites

    local function RefreshRecent()
        local recentColors = GetRecent()
        for recentIndex = 1, MAX_RECENT do
            local swatch = recentSwatches[recentIndex]
            local color = recentColors[recentIndex]
            if color then
                swatch.color = color
                swatch:SetBackdropColor(color[1], color[2], color[3], color[4] or 1)
                swatch:Show()
            else
                swatch:Hide()
            end
        end
    end
    frame.RefreshRecent = RefreshRecent

    okButton:SetScript("OnClick", function()
        frame.confirmed = true
        local red, green, blue = HSVtoRGB(frame.h, frame.s, frame.v)
        AddRecent(red, green, blue, frame.a)
        if frame.callback then frame.callback(red, green, blue, frame.a, false, 'commit') end
        frame:Hide()
    end)

    cancelButton:SetScript("OnClick", function() frame:Hide() end)

    frame:SetScript("OnHide", function()
        if not frame.confirmed and frame.cancelFunc then frame.cancelFunc() end
        frame.confirmed = nil
    end)

    local function ReflowLayout()
        local y = -32
        saturationValueField:ClearAllPoints()
        saturationValueField:SetPoint("TOP", 0, y)
        y = y - GRID_SIZE - SECTION_GAP

        hueLabel:ClearAllPoints()
        hueLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
        y = y - LABEL_HEIGHT
        hueStrip:ClearAllPoints()
        hueStrip:SetPoint("TOP", 0, y)
        y = y - STRIP_HEIGHT - SECTION_GAP

        if frame.hasOpacity then
            opacityLabel:Show(); opacityStrip:Show(); alphaText:Show()
            opacityLabel:ClearAllPoints()
            opacityLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
            y = y - LABEL_HEIGHT
            opacityStrip:ClearAllPoints()
            opacityStrip:SetPoint("TOP", 0, y)
            y = y - STRIP_HEIGHT - (SECTION_GAP + 2)
        else
            opacityLabel:Hide(); opacityStrip:Hide(); alphaText:Hide()
        end

        previewBg:ClearAllPoints()
        previewBg:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
        y = y - PREVIEW_SIZE - (SECTION_GAP + 2)

        classLabel:ClearAllPoints()
        classLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
        y = y - LABEL_HEIGHT
        for swatchIndex, swatch in ipairs(classSwatches) do
            swatch:ClearAllPoints()
            swatch:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + (swatchIndex - 1) * (SWATCH_SIZE + SWATCH_GAP), y)
        end
        y = y - SWATCH_SIZE - ROW_GAP

        favoritesLabel:ClearAllPoints()
        favoritesLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
        y = y - LABEL_HEIGHT
        for swatchIndex, swatch in ipairs(favoriteSwatches) do
            swatch:ClearAllPoints()
            swatch:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + (swatchIndex - 1) * (SWATCH_SIZE + SWATCH_GAP), y)
        end
        y = y - SWATCH_SIZE - ROW_GAP

        recentLabel:ClearAllPoints()
        recentLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
        y = y - LABEL_HEIGHT
        for swatchIndex, swatch in ipairs(recentSwatches) do
            swatch:ClearAllPoints()
            swatch:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + (swatchIndex - 1) * (SWATCH_SIZE + SWATCH_GAP), y)
        end
        y = y - SWATCH_SIZE - 11

        frame:SetHeight(abs(y) + BUTTON_HEIGHT + BOTTOM_PAD)
    end
    frame.ReflowLayout = ReflowLayout

    table.insert(UISpecialFrames, "BUILibColorPicker")
    return frame
end

function Controls.OpenColorPicker(opts)
    if not picker then picker = BuildPicker() end
    opts = opts or {}

    picker.hasOpacity = opts.hasOpacity ~= false
    picker.ReflowLayout()

    local red, green, blue = opts.r or 1, opts.g or 1, opts.b or 1
    local alpha = picker.hasOpacity and (opts.a or 1) or 1

    picker.h, picker.s, picker.v = RGBtoHSV(red, green, blue)
    picker.a = alpha
    picker.lastGridHue = -1
    picker.callback = opts.callback

    local originalRed, originalGreen, originalBlue, originalAlpha = red, green, blue, alpha
    picker.cancelFunc = function()
        if opts.callback then opts.callback(originalRed, originalGreen, originalBlue, originalAlpha, true, 'cancel') end
    end

    picker.RefreshFavorites()
    picker.RefreshRecent()
    picker.Render()
    picker:ClearAllPoints()

    local addonFrame = BUILib.GetPopupParent()

    if addonFrame and opts.anchorTo then
        picker:SetPoint("TOPRIGHT", addonFrame, "TOPRIGHT", -10, -10)
    elseif opts.anchorTo then
        picker:SetPoint("TOPRIGHT", opts.anchorTo, "TOPLEFT", -10, 0)
    else
        picker:SetPoint("CENTER")
    end

    picker:SetFrameStrata(BUILib.GetPopupStrata())
    picker:SetFrameLevel(BUILib.GetPopupLevel())

    picker:Show()
    picker:Raise()

    if addonFrame and opts.anchorTo then
        if not picker._slideTicker then picker._slideTicker = CreateFrame("Frame") end
        local ticker = picker._slideTicker
        local startTime = GetTime()
        local DURATION = 0.24
        local pickerWidth = picker:GetWidth()
        local finalOffset = -10
        local startOffset = pickerWidth
        picker:ClearAllPoints()
        picker:SetPoint("TOPRIGHT", addonFrame, "TOPRIGHT", startOffset, -10)
        picker:SetAlpha(0)
        ticker:SetScript("OnUpdate", function(self)
            local progress = (GetTime() - startTime) / DURATION
            if progress >= 1 or not picker:IsShown() then
                picker:ClearAllPoints()
                picker:SetPoint("TOPRIGHT", addonFrame, "TOPRIGHT", finalOffset, -10)
                picker:SetAlpha(1)
                self:SetScript("OnUpdate", nil)
            else
                local eased = 1 - (1 - progress) ^ 3
                local offset = startOffset + (finalOffset - startOffset) * eased
                picker:ClearAllPoints()
                picker:SetPoint("TOPRIGHT", addonFrame, "TOPRIGHT", offset, -10)
                picker:SetAlpha(eased)
            end
        end)
    end
end
