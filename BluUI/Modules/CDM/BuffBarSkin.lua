local _, BUI = ...

local _G = _G

local CDM = BUI.CDM
local Pixel = BUI.Pixel

local hooked = false
local skinnedItems = setmetatable({}, { __mode = "k" })
local previewShelf
local restacking = false
local positioning = false
local fitting = false
local viewerMoved = true
local placedAnchor, placedAnchorPoint, placedOffsetX, placedOffsetY
local placedGrowDirection, placedCentered, placedPositionX, placedPositionY
local anchorRetryScheduled

local BAR_ATLAS_PREFIX = "UI-HUD-CoolDownManager"
local ICON_GAP = 1

local function GetSettings()
    return BUI.GetDB().cdm.buffBars
end

local function GetEffectiveBarWidth(config)
    if config.matchAnchorWidth and config.anchorFrame ~= "" then
        local resolvedAnchor = BUI.ResolveAnchorFrame(config.anchorFrame, config.anchorPoint)
        if resolvedAnchor then
            local point = config.anchorPoint
            local anchorWidth
            if point == "BOTTOM" or point == "BOTTOMLEFT" or point == "BOTTOMRIGHT" then
                anchorWidth = resolvedAnchor._bottomRowW or resolvedAnchor._topRowW or resolvedAnchor._row1W
            else
                anchorWidth = resolvedAnchor._topRowW or resolvedAnchor._row1W
            end
            anchorWidth = anchorWidth or resolvedAnchor:GetWidth()
            local reserved = config.showIcon and (config.iconSize + ICON_GAP) or 0
            local width = anchorWidth - reserved
            if width >= 20 then return width end
        end
    end
    return config.barWidth
end

local function GetBarColor(config)
    if config.useClassColor then
        local red, green, blue = BUI.Tools.GetUnitClassColor("player")
        if red then return red, green, blue, 1 end
    end
    local barColor = config.barColor
    return barColor[1], barColor[2], barColor[3], barColor[4]
end

local regionBuffer = {}

local function StripCDMAtlases(frame)
    local regions, count = CDM.PackInto(regionBuffer, frame:GetRegions())
    for regionIndex = 1, count do
        local region = regions[regionIndex]
        if region:GetObjectType() == "Texture" then
            local atlas = region:GetAtlas()
            if atlas and atlas:find(BAR_ATLAS_PREFIX) then
                region:SetTexture(nil)
                region:SetAtlas(nil)
                region:Hide()
            end
        end
    end
end

local function PlaceStacks(text, config, iconFrame, bar, showIcon)
    local point = config.stackPoint
    local target = (showIcon and config.stackAttach == "ICON") and iconFrame or bar
    local color = config.stackColor
    text:ClearAllPoints()
    text:SetPoint(point, target, point, config.stackOffsetX, config.stackOffsetY)
    text:SetTextColor(color[1], color[2], color[3], color[4])
    text:SetShown(config.showStacks)
end

local function PlaceDuration(text, config, bar)
    local point = config.durationPoint
    text:ClearAllPoints()
    text:SetPoint(point, bar, point, config.durationOffsetX, config.durationOffsetY)
    text:SetShown(config.showDuration)
end

local function HAlignOf(point)
    if point:find("LEFT",  1, true) then return "LEFT"  end
    if point:find("RIGHT", 1, true) then return "RIGHT" end
    return ""
end

local function CornerFrom(anchorPoint, goingUp)
    local vertical = goingUp and "BOTTOM" or "TOP"
    return vertical .. HAlignOf(anchorPoint)
end

local function ApplyAnchor(frame, config)
    local goingUp = config.growDirection == "UP"
    frame:ClearAllPoints()
    local anchor = config.anchorFrame ~= "" and BUI.ResolveAnchorFrame(config.anchorFrame, config.anchorPoint)
    if anchor then
        local anchorPoint = config.anchorPoint
        frame:SetPoint(CornerFrom(anchorPoint, goingUp), anchor, anchorPoint, config.anchorOffsetX, config.anchorOffsetY)
        return true
    end
    local positionX = config.centerHorizontally and 0 or config.positionX
    local positionY = config.positionY
    frame:SetPoint(goingUp and "BOTTOM" or "TOP", UIParent, "CENTER", positionX, positionY)
    return false
end

local anchorRetries = 0

local function ViewerPlacementCurrent(anchor, config)
    return not viewerMoved and anchor == placedAnchor and config.anchorPoint == placedAnchorPoint
        and config.anchorOffsetX == placedOffsetX and config.anchorOffsetY == placedOffsetY
        and config.growDirection == placedGrowDirection and config.centerHorizontally == placedCentered
        and config.positionX == placedPositionX and config.positionY == placedPositionY
end

local function PositionViewer()
    local viewer = _G.BuffBarCooldownViewer
    local config = GetSettings()
    if not viewer or not config.skinEnabled then return end

    local anchor = config.anchorFrame ~= "" and BUI.ResolveAnchorFrame(config.anchorFrame, config.anchorPoint)
    local resolved = anchor and true or false
    if not ViewerPlacementCurrent(anchor, config) then
        positioning = true
        resolved = ApplyAnchor(viewer, config)
        positioning = false
        viewerMoved = false
        placedAnchor, placedAnchorPoint = anchor, config.anchorPoint
        placedOffsetX, placedOffsetY = config.anchorOffsetX, config.anchorOffsetY
        placedGrowDirection, placedCentered = config.growDirection, config.centerHorizontally
        placedPositionX, placedPositionY = config.positionX, config.positionY
    end

    if resolved then
        anchorRetries = 0
    elseif config.anchorFrame ~= "" and not anchorRetryScheduled and anchorRetries < 5 then
        anchorRetries = anchorRetries + 1
        anchorRetryScheduled = true
        C_Timer.After(1, function()
            anchorRetryScheduled = nil
            PositionViewer()
        end)
    end
end

BUI.Anchor.RegisterCallback('CDM.BuffBarSkin', function()
    anchorRetries = 0
    PositionViewer()
end)

local ScheduleReposition = BUI.Dispatcher.New(PositionViewer)

local HookItemVisibility

local function FitBarItem(item, config)
    local showIcon = config.showIcon
    local iconSize = config.iconSize
    local barHeight = config.barHeight
    local barWidth = GetEffectiveBarWidth(config)
    fitting = true
    item:SetSize((showIcon and (iconSize + ICON_GAP) or 0) + barWidth, math.max(showIcon and iconSize or 0, barHeight))
    fitting = false

    local iconFrame = item.Icon
    iconFrame:SetShown(showIcon)

    local bar = item.Bar
    bar:ClearAllPoints()
    if showIcon then
        bar:SetPoint("LEFT", iconFrame, "RIGHT", ICON_GAP, 0)
    else
        bar:SetPoint("LEFT", item, "LEFT", 0, 0)
    end
    bar:SetSize(barWidth, barHeight)
    bar.Name:SetShown(config.showName)
    PlaceDuration(bar.Duration, config, bar)
end

local function HideSelf(self)
    self:Hide()
end

local function HidePip(self)
    self:Hide()
    self:SetAlpha(0)
end

local function SkinBarItem(item)
    if skinnedItems[item] then return end
    local config = GetSettings()
    if not config.skinEnabled then return end

    skinnedItems[item] = true
    HookItemVisibility(item)

    local texture = BUI.GetGlobalTexture()
    local font = BUI.GetCDMFont()
    local border = config.borderColor
    local borderSize = config.borderSize
    local backgroundColor = config.bgColor
    local showIcon = config.showIcon
    local iconSize = config.iconSize
    FitBarItem(item, config)

    item.DebuffBorder:Hide()
    if not item._buiDebuffBorderHooked then
        item._buiDebuffBorderHooked = true
        BUI.Hook('BuffBarSkin.HideSelf', item.DebuffBorder, "Show", HideSelf)
    end

    local iconFrame = item.Icon
    if showIcon then
        iconFrame:SetSize(iconSize, iconSize)
        StripCDMAtlases(iconFrame)
        local inner = iconFrame.Icon
        CDM.RemoveMasks(inner)
        inner:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        inner:ClearAllPoints()
        inner:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
        inner:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
        Pixel.ApplyBorder(iconFrame, borderSize, border[1], border[2], border[3], border[4])
    end

    local bar = item.Bar
    bar:SetStatusBarTexture(texture)
    bar:SetStatusBarColor(GetBarColor(config))

    bar.BarBG:SetTexture(texture)
    bar.BarBG:SetVertexColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
    bar.BarBG:ClearAllPoints()
    bar.BarBG:SetAllPoints(bar)

    bar.Pip:Hide()
    bar.Pip:SetAlpha(0)
    if not bar._buiPipHooked then
        bar._buiPipHooked = true
        BUI.Hook('BuffBarSkin.HidePip', bar.Pip, "Show", HidePip)
    end

    if not bar._buiBorderHost then
        bar._buiBorderHost = CreateFrame("Frame", nil, bar)
        bar._buiBorderHost:SetFrameLevel(bar:GetFrameLevel() + 1)
    end
    bar._buiBorderHost:ClearAllPoints()
    bar._buiBorderHost:SetAllPoints(bar)
    Pixel.ApplyBorder(bar._buiBorderHost, borderSize, border[1], border[2], border[3], border[4])

    local stacks = iconFrame.Applications
    if not bar._buiTextLayer then
        bar._buiTextLayer = CreateFrame("Frame", nil, bar._buiBorderHost)
        bar._buiTextLayer:SetAllPoints(bar)
    end
    stacks:SetParent(bar._buiTextLayer)
    Pixel.ApplyFont(stacks, math.max(6, config.stackSize), font)
    PlaceStacks(stacks, config, iconFrame, bar, showIcon)

    Pixel.ApplyFont(bar.Name, math.max(6, config.nameSize), font)
    Pixel.ApplyFont(bar.Duration, math.max(6, config.durationSize), font)
end

local rackItems = {}
local function SortByLayoutIndexAsc(left, right)
    return (left.layoutIndex or 0) < (right.layoutIndex or 0)
end

local function RestackItems(viewer)
    viewer = viewer or _G.BuffBarCooldownViewer
    if not viewer then return end
    local config = GetSettings()
    if not config.skinEnabled then return end

    PositionViewer()

    local spacing = config.spacing
    local iconSize = config.iconSize
    local barHeight = config.barHeight
    local slotHeight = math.max(config.showIcon and iconSize or 0, barHeight)
    local goingUp = config.growDirection == "UP"

    wipe(rackItems)
    local items, itemCount = rackItems, 0
    for item in viewer.itemFramePool:EnumerateActive() do
        if item:IsShown() then
            itemCount = itemCount + 1; items[itemCount] = item
        end
    end
    if itemCount == 0 then return end

    table.sort(items, SortByLayoutIndexAsc)

    local corner = CornerFrom(config.anchorPoint, goingUp)
    local yDirection = goingUp and 1 or -1
    restacking = true
    for itemIndex = 1, itemCount do
        local bar = items[itemIndex]
        bar:ClearAllPoints()
        local offsetY = (itemIndex - 1) * (slotHeight + spacing) * yDirection
        bar:SetPoint(corner, viewer, corner, 0, offsetY)
    end
    restacking = false
end

function CDM.RepositionBuffBarRack()
    PositionViewer()
    CDM.EditModeLock.SyncBarsLock()
    if previewShelf then ApplyAnchor(previewShelf, GetSettings()) end
end

local ScheduleReflow = BUI.Dispatcher.New(RestackItems)

local function ReflowUnlessFitting()
    if not fitting then ScheduleReflow() end
end

local function ReflowUnlessRestacking()
    if not restacking then ScheduleReflow() end
end

HookItemVisibility = function(item)
    if item._buiVisHooked then return end
    item._buiVisHooked = true
    BUI.Hook('BuffBarSkin.ScheduleReflow', item, "Show", ScheduleReflow)
    BUI.Hook('BuffBarSkin.ScheduleReflow', item, "Hide", ScheduleReflow)
    BUI.Hook('BuffBarSkin.ScheduleReflow', item, "SetShown", ScheduleReflow)
    BUI.Hook('BuffBarSkin.ReflowUnlessFitting', item, "SetSize", ReflowUnlessFitting)
    BUI.Hook('BuffBarSkin.ReflowUnlessFitting', item, "SetWidth", ReflowUnlessFitting)
    BUI.Hook('BuffBarSkin.ReflowUnlessFitting', item, "SetHeight", ReflowUnlessFitting)
    BUI.Hook('BuffBarSkin.ReflowUnlessRestacking', item, "SetPoint", ReflowUnlessRestacking)
end

function CDM.RefreshBuffBarSkin()
    local viewer = _G.BuffBarCooldownViewer
    if not viewer then return end
    for item in viewer.itemFramePool:EnumerateActive() do
        skinnedItems[item] = nil
        SkinBarItem(item)
    end
    RestackItems(viewer)
    if CDM.IsBuffBarPreviewShown() then CDM.ShowBuffBarPreview() end
end

local function RefitActiveItems()
    local viewer = _G.BuffBarCooldownViewer
    local config = GetSettings()
    if not config.skinEnabled then return end
    for item in viewer.itemFramePool:EnumerateActive() do
        if skinnedItems[item] then
            FitBarItem(item, config)
        else
            SkinBarItem(item)
        end
    end
    RestackItems(viewer)
end

local ScheduleRefit = BUI.Dispatcher.New(RefitActiveItems)

local function OnBarItemAcquired(_, item)
    SkinBarItem(item)
    ScheduleReflow()
end

local function HookBuffBarViewer()
    if hooked then return true end
    if not CDM.HookBarViewer(OnBarItemAcquired, ScheduleRefit) then return false end
    hooked = true

    local viewer = _G.BuffBarCooldownViewer
    for item in viewer.itemFramePool:EnumerateActive() do
        SkinBarItem(item)
    end
    RestackItems(viewer)
    PositionViewer()

    BUI.Hook('BuffBarSkin.SetPoint', viewer, "SetPoint", function()
        if positioning then return end
        viewerMoved = true
        if GetSettings().skinEnabled then ScheduleReposition() end
    end)

    return true
end

function CDM.InitBuffBarSkin()
    if HookBuffBarViewer() then return end
    BUI.Events:Register("COOLDOWN_VIEWER_DATA_LOADED", "CDM.BuffBarSkin", function()
        if HookBuffBarViewer() then
            BUI.Events:Unregister("COOLDOWN_VIEWER_DATA_LOADED", "CDM.BuffBarSkin")
        end
    end)
end

local PREVIEW_COUNT = 5
local PREVIEW_ICONS = { 136048, 135994, 136018, 136085, 135936 }
local PREVIEW_NAMES = { "Bloodlust", "Avenging Wrath", "Bestial Wrath", "Rapid Fire", "Arcane Power" }
local PREVIEW_STACKS = { "3", "", "2", "", "5" }
local previewFrames

local function GetPreviewShelf(viewer)
    if previewShelf then return previewShelf end
    previewShelf = CreateFrame("Frame", "BUI_BuffBarRack", UIParent)
    previewShelf:SetSize(1, 1)
    if viewer then
        previewShelf:SetFrameStrata(viewer:GetFrameStrata())
        previewShelf:SetFrameLevel(viewer:GetFrameLevel() + 1)
    end
    return previewShelf
end

local function BuildPreviewFrame(previewIndex, shelf)
    local frame = CreateFrame("Frame", nil, shelf)
    frame.Icon = CreateFrame("Frame", nil, frame)
    frame.Icon.Icon = frame.Icon:CreateTexture(nil, "ARTWORK")
    frame.Bar = CreateFrame("StatusBar", nil, frame)
    frame.BarBG = frame.Bar:CreateTexture(nil, "BACKGROUND")
    frame.TextLayer = CreateFrame("Frame", nil, frame.Bar)
    frame.TextLayer:SetFrameLevel(frame.Bar:GetFrameLevel() + 2)
    frame.Stacks = frame.TextLayer:CreateFontString(nil, "OVERLAY")
    frame.Bar.Name = frame.Bar:CreateFontString(nil, "OVERLAY")
    frame.Bar.Duration = frame.Bar:CreateFontString(nil, "OVERLAY")
    return frame
end

local function StylePreviewFrame(frame, previewIndex, config)
    local showIcon = config.showIcon
    local iconSize = config.iconSize
    local barWidth = GetEffectiveBarWidth(config)
    local barHeight = config.barHeight
    local border = config.borderColor
    local borderSize = config.borderSize
    local backgroundColor = config.bgColor
    local texture = BUI.GetGlobalTexture()
    local font = BUI.GetCDMFont()
    local slotHeight = math.max(showIcon and iconSize or 0, barHeight)

    frame:SetSize((showIcon and (iconSize + ICON_GAP) or 0) + barWidth, slotHeight)

    frame.Icon:SetShown(showIcon)
    if showIcon then
        frame.Icon:ClearAllPoints()
        frame.Icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
        frame.Icon:SetSize(iconSize, iconSize)
        Pixel.ApplyBorder(frame.Icon, borderSize, border[1], border[2], border[3], border[4])
        frame.Icon.Icon:ClearAllPoints()
        frame.Icon.Icon:SetPoint("TOPLEFT", frame.Icon, "TOPLEFT", Pixel.Scale(1), Pixel.Scale(-1))
        frame.Icon.Icon:SetPoint("BOTTOMRIGHT", frame.Icon, "BOTTOMRIGHT", Pixel.Scale(-1), Pixel.Scale(1))
        frame.Icon.Icon:SetTexture(PREVIEW_ICONS[((previewIndex - 1) % #PREVIEW_ICONS) + 1])
        frame.Icon.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    frame.Bar:ClearAllPoints()
    if showIcon then
        frame.Bar:SetPoint("LEFT", frame.Icon, "RIGHT", Pixel.Scale(ICON_GAP), 0)
    else
        frame.Bar:SetPoint("LEFT", frame, "LEFT", 0, 0)
    end
    frame.Bar:SetSize(barWidth, barHeight)
    frame.Bar:SetStatusBarTexture(texture)
    frame.Bar:SetStatusBarColor(GetBarColor(config))
    frame.Bar:SetMinMaxValues(0, 1)
    frame.Bar:SetValue(0.15 + (previewIndex * 0.17) % 0.85)
    frame.BarBG:SetTexture(texture)
    frame.BarBG:SetVertexColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
    frame.BarBG:ClearAllPoints()
    frame.BarBG:SetAllPoints(frame.Bar)
    if not frame.Bar._buiBorderHost then
        frame.Bar._buiBorderHost = CreateFrame("Frame", nil, frame.Bar)
        frame.Bar._buiBorderHost:SetFrameLevel(frame.Bar:GetFrameLevel() + 1)
    end
    frame.Bar._buiBorderHost:ClearAllPoints()
    frame.Bar._buiBorderHost:SetAllPoints(frame.Bar)
    Pixel.ApplyBorder(frame.Bar._buiBorderHost, borderSize, border[1], border[2], border[3], border[4])

    Pixel.ApplyFont(frame.Stacks, math.max(6, config.stackSize), font, "OUTLINE")
    frame.Stacks:SetText(PREVIEW_STACKS[((previewIndex - 1) % #PREVIEW_STACKS) + 1])
    PlaceStacks(frame.Stacks, config, frame.Icon, frame.Bar, showIcon)

    Pixel.ApplyFont(frame.Bar.Name, math.max(6, config.nameSize), font)
    frame.Bar.Name:ClearAllPoints()
    frame.Bar.Name:SetPoint("LEFT", frame.Bar, "LEFT", Pixel.Scale(4), 0)
    frame.Bar.Name:SetText(PREVIEW_NAMES[((previewIndex - 1) % #PREVIEW_NAMES) + 1])
    frame.Bar.Name:SetShown(config.showName)

    Pixel.ApplyFont(frame.Bar.Duration, math.max(6, config.durationSize), font)
    frame.Bar.Duration:SetText(((PREVIEW_COUNT + 1 - previewIndex) * 3) .. "s")
    PlaceDuration(frame.Bar.Duration, config, frame.Bar)
end

local function PositionPreviewFrame(frame, previewIndex, config, shelf)
    local iconSize = config.iconSize
    local barHeight = config.barHeight
    local slotHeight = math.max(config.showIcon and iconSize or 0, barHeight)
    local spacing = config.spacing
    local goingUp = config.growDirection == "UP"
    local corner = CornerFrom(config.anchorPoint, goingUp)
    local yDirection = goingUp and 1 or -1
    frame:ClearAllPoints()
    frame:SetPoint(corner, shelf, corner, 0, (previewIndex - 1) * (slotHeight + spacing) * yDirection)
end

function CDM.ShowBuffBarPreview()
    local viewer = _G.BuffBarCooldownViewer
    local config = GetSettings()
    local shelf = GetPreviewShelf(viewer)
    ApplyAnchor(shelf, config)

    if not previewFrames then previewFrames = {} end
    for previewIndex = 1, PREVIEW_COUNT do
        local frame = previewFrames[previewIndex]
        if not frame then
            frame = BuildPreviewFrame(previewIndex, shelf)
            previewFrames[previewIndex] = frame
        end
        if frame:GetParent() ~= shelf then frame:SetParent(shelf) end
        StylePreviewFrame(frame, previewIndex, config)
        PositionPreviewFrame(frame, previewIndex, config, shelf)
        frame:Show()
    end
end

function CDM.HideBuffBarPreview()
    if not previewFrames then return end
    for previewIndex = 1, #previewFrames do previewFrames[previewIndex]:Hide() end
end

function CDM.IsBuffBarPreviewShown()
    return previewFrames and previewFrames[1] and previewFrames[1]:IsShown() or false
end

BUI.Perf.Track('CDM.RestackItems', RestackItems)
