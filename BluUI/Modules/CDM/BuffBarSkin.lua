local _, BUI = ...

local _G = _G
local ipairs = ipairs
local UnitClass = UnitClass

local CDM = BUI.CDM
local Pixel = BUI.Pixel

local hooked = false
local skinnedItems = setmetatable({}, { __mode = "k" })
local previewShelf
local restacking = false
local positioning = false
local anchorRetryScheduled

local BAR_ATLAS_PREFIX = "UI-HUD-CoolDownManager"
local ICON_GAP = 1

local function GetSettings()
    return BUI.GetDB().cdm.buffBars
end

local function GetEffectiveBarWidth(config)
    if config.matchAnchorWidth and config.anchorFrame ~= "" then
        local resolvedAnchor = BUI.ResolveAnchorFrame(config.anchorFrame, config.anchorPoint)
        if resolvedAnchor and resolvedAnchor.GetWidth then
            local point = config.anchorPoint
            local anchorWidth
            if point == "BOTTOM" or point == "BOTTOMLEFT" or point == "BOTTOMRIGHT" then
                anchorWidth = resolvedAnchor._bottomRowW or resolvedAnchor._topRowW or resolvedAnchor._row1W
            else
                anchorWidth = resolvedAnchor._topRowW or resolvedAnchor._row1W
            end
            anchorWidth = anchorWidth or resolvedAnchor:GetWidth() or 0
            local reserved = (config.showIcon ~= false) and (config.iconSize + ICON_GAP) or 0
            local width = anchorWidth - reserved
            if width >= 20 then return width end
        end
    end
    return config.barWidth
end

local function GetBarColor(config)
    if config.useClassColor then
        local _, class = UnitClass("player")
        local color = class and RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b, 1 end
    end
    local barColor = config.barColor
    return barColor[1], barColor[2], barColor[3], barColor[4] or 1
end

local function StripCDMAtlases(frame)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region:GetObjectType() == "Texture" then
            local atlas = region:GetAtlas()
            if atlas and atlas:find(BAR_ATLAS_PREFIX) then
                region:SetTexture(nil)
                region:SetAtlas(nil)
                region:Hide()
            end
        end
    end
end

local function RemoveMasks(texture)
    if not texture or not texture.GetMaskTexture then return end
    local mask = texture:GetMaskTexture(1)
    while mask do
        texture:RemoveMaskTexture(mask)
        mask = texture:GetMaskTexture(1)
    end
end

local function PlaceStacks(text, config, iconFrame, bar, showIcon)
    local point = config.stackPoint
    local target = (showIcon and config.stackAttach == "ICON") and iconFrame or bar
    text:ClearAllPoints()
    text:SetPoint(point, target, point, config.stackOffsetX, config.stackOffsetY)
    text:SetShown(config.showStacks ~= false)
end

local function HAlignOf(point)
    if type(point) ~= "string" then return "" end
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

local function PositionViewer()
    local viewer = _G.BuffBarCooldownViewer
    local config = GetSettings()
    if not viewer or not config.skinEnabled then return end

    positioning = true
    local resolved = ApplyAnchor(viewer, config)
    positioning = false

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

local ScheduleReposition = BUI.Dispatcher.New(PositionViewer, 'CDM.BuffBarReposition')

local HookItemVisibility

local function SkinBarItem(item)
    if not item then return end
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
    local showIcon = config.showIcon ~= false
    local iconSize = config.iconSize
    local barHeight = config.barHeight
    local barWidth = GetEffectiveBarWidth(config)
    local itemWidth = (showIcon and (iconSize + ICON_GAP) or 0) + barWidth
    local itemHeight = math.max(showIcon and iconSize or 0, barHeight)
    item:SetSize(itemWidth, itemHeight)

    if item.PandemicIcon then
        item.PandemicIcon:Hide()
        if not item._buiPandemicHooked then
            item._buiPandemicHooked = true
            hooksecurefunc(item.PandemicIcon, "Show", function(self) self:Hide() end)
            if item.ShowPandemicStateFrame then
                hooksecurefunc(item, "ShowPandemicStateFrame", function(self)
                    if self.PandemicIcon then self.PandemicIcon:Hide() end
                end)
            end
        end
    end
    if item.CooldownFlash then
        item.CooldownFlash:Hide()
        if not item._buiCdFlashHooked then
            item._buiCdFlashHooked = true
            hooksecurefunc(item.CooldownFlash, "Show", function(self)
                self:Hide()
                if self.FlashAnim then self.FlashAnim:Stop() end
            end)
        end
    end
    if item.DebuffBorder then
        item.DebuffBorder:Hide()
        if not item._buiDebuffBorderHooked then
            item._buiDebuffBorderHooked = true
            hooksecurefunc(item.DebuffBorder, "Show", function(self) self:Hide() end)
        end
    end

    local iconFrame = item.Icon
    if iconFrame then
        iconFrame:SetShown(showIcon)
        if showIcon then
            iconFrame:SetSize(iconSize, iconSize)
            StripCDMAtlases(iconFrame)
            local inner = iconFrame.Icon
            if inner then
                RemoveMasks(inner)
                if inner.SetTexCoord then inner:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
                inner:ClearAllPoints()
                inner:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
                inner:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
            end
            Pixel.ApplyBorder(iconFrame, borderSize, border[1], border[2], border[3], border[4] or 1)
        end
    end

    local bar = item.Bar
    if bar then
        bar:ClearAllPoints()
        if showIcon and iconFrame then
            bar:SetPoint("LEFT", iconFrame, "RIGHT", ICON_GAP, 0)
        else
            bar:SetPoint("LEFT", item, "LEFT", 0, 0)
        end
        bar:SetSize(barWidth, barHeight)
        bar:SetStatusBarTexture(texture)
        bar:SetStatusBarColor(GetBarColor(config))

        if bar.BarBG then
            bar.BarBG:SetTexture(texture)
            bar.BarBG:SetVertexColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4] or 1)
            bar.BarBG:ClearAllPoints()
            bar.BarBG:SetAllPoints(bar)
        end

        if bar.Pip then
            bar.Pip:Hide()
            bar.Pip:SetAlpha(0)
            if not bar._buiPipHooked then
                bar._buiPipHooked = true
                hooksecurefunc(bar.Pip, "Show", function(self) self:Hide(); self:SetAlpha(0) end)
            end
        end
        if bar.Spark then bar.Spark:Hide() end

        if not bar._buiBorderHost then
            bar._buiBorderHost = CreateFrame("Frame", nil, bar)
            bar._buiBorderHost:SetFrameLevel(bar:GetFrameLevel() + 1)
        end
        bar._buiBorderHost:ClearAllPoints()
        bar._buiBorderHost:SetAllPoints(bar)
        Pixel.ApplyBorder(bar._buiBorderHost, borderSize, border[1], border[2], border[3], border[4] or 1)

        local stacks = iconFrame and iconFrame.Applications
        if stacks then
            if not bar._buiTextLayer then
                bar._buiTextLayer = CreateFrame("Frame", nil, bar._buiBorderHost)
                bar._buiTextLayer:SetAllPoints(bar)
            end
            stacks:SetParent(bar._buiTextLayer)
            Pixel.ApplyFont(stacks, math.max(6, config.stackSize), font)
            PlaceStacks(stacks, config, iconFrame, bar, showIcon)
        end

        if bar.Name then
            Pixel.ApplyFont(bar.Name, math.max(6, config.nameSize), font)
            bar.Name:SetShown(config.showName ~= false)
        end
        if bar.Duration then
            Pixel.ApplyFont(bar.Duration, math.max(6, config.durationSize), font)
            bar.Duration:SetShown(config.showDuration ~= false)
        end
    end
end

local rackItems = {}
local function SortByLayoutIndexAsc(left, right)
    return (left.layoutIndex or 0) < (right.layoutIndex or 0)
end

local function RestackItems(viewer)
    viewer = viewer or _G.BuffBarCooldownViewer
    if not viewer or not viewer.itemFramePool or not viewer.itemFramePool.EnumerateActive then return end
    local config = GetSettings()
    if not config.skinEnabled then return end

    PositionViewer()

    local spacing = config.spacing
    local iconSize = config.iconSize
    local barHeight = config.barHeight
    local slotHeight = math.max(config.showIcon ~= false and iconSize or 0, barHeight)
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
    if previewShelf then ApplyAnchor(previewShelf, GetSettings()) end
end

local ScheduleReflow = BUI.Dispatcher.New(RestackItems, 'CDM.BuffBarReflow')

HookItemVisibility = function(item)
    if item._buiVisHooked then return end
    item._buiVisHooked = true
    hooksecurefunc(item, "Show", ScheduleReflow)
    hooksecurefunc(item, "Hide", ScheduleReflow)
    hooksecurefunc(item, "SetShown", ScheduleReflow)
    hooksecurefunc(item, "SetSize", ScheduleReflow)
    hooksecurefunc(item, "SetWidth", ScheduleReflow)
    hooksecurefunc(item, "SetHeight", ScheduleReflow)
    hooksecurefunc(item, "SetPoint", function()
        if not restacking then ScheduleReflow() end
    end)
end

local function SkinAllActive(viewer)
    if viewer and viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
        for item in viewer.itemFramePool:EnumerateActive() do
            SkinBarItem(item)
        end
        RestackItems(viewer)
    end
end

function CDM.RefreshBuffBarSkin()
    local viewer = _G.BuffBarCooldownViewer
    if not viewer or not viewer.itemFramePool or not viewer.itemFramePool.EnumerateActive then return end
    for item in viewer.itemFramePool:EnumerateActive() do
        skinnedItems[item] = nil
        SkinBarItem(item)
    end
    RestackItems(viewer)
    if CDM.IsBuffBarPreviewShown() then CDM.ShowBuffBarPreview() end
end

local ScheduleReskin = BUI.Dispatcher.New(function() CDM.RefreshBuffBarSkin() end, 'CDM.BuffBarReskin')

local function HookBuffBarViewer()
    if hooked then return true end
    local viewer = _G.BuffBarCooldownViewer
    if not viewer then return false end
    hooked = true

    SkinAllActive(viewer)
    PositionViewer()

    hooksecurefunc(viewer, "OnAcquireItemFrame", function(self, item)
        SkinBarItem(item)
        ScheduleReflow()
    end)
    if viewer.RefreshLayout then
        hooksecurefunc(viewer, "RefreshLayout", ScheduleReskin)
    end
    hooksecurefunc(viewer, "SetPoint", function()
        if positioning then return end
        if GetSettings().skinEnabled then ScheduleReposition() end
    end)

    return true
end

function CDM.InitBuffBarSkin()
    if HookBuffBarViewer() then return end
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")
    watcher:RegisterEvent("PLAYER_LOGIN")
    watcher:SetScript("OnEvent", function(self)
        if HookBuffBarViewer() then
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
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
    local showIcon = config.showIcon ~= false
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
        Pixel.ApplyBorder(frame.Icon, borderSize, border[1], border[2], border[3], border[4] or 1)
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
    frame.BarBG:SetVertexColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4] or 1)
    frame.BarBG:ClearAllPoints()
    frame.BarBG:SetAllPoints(frame.Bar)
    if not frame.Bar._buiBorderHost then
        frame.Bar._buiBorderHost = CreateFrame("Frame", nil, frame.Bar)
        frame.Bar._buiBorderHost:SetFrameLevel(frame.Bar:GetFrameLevel() + 1)
    end
    frame.Bar._buiBorderHost:ClearAllPoints()
    frame.Bar._buiBorderHost:SetAllPoints(frame.Bar)
    Pixel.ApplyBorder(frame.Bar._buiBorderHost, borderSize, border[1], border[2], border[3], border[4] or 1)

    Pixel.ApplyFont(frame.Stacks, math.max(6, config.stackSize), font, "OUTLINE")
    frame.Stacks:SetText(PREVIEW_STACKS[((previewIndex - 1) % #PREVIEW_STACKS) + 1])
    PlaceStacks(frame.Stacks, config, frame.Icon, frame.Bar, showIcon)

    Pixel.ApplyFont(frame.Bar.Name, math.max(6, config.nameSize), font)
    frame.Bar.Name:ClearAllPoints()
    frame.Bar.Name:SetPoint("LEFT", frame.Bar, "LEFT", Pixel.Scale(4), 0)
    frame.Bar.Name:SetText(PREVIEW_NAMES[((previewIndex - 1) % #PREVIEW_NAMES) + 1])
    frame.Bar.Name:SetShown(config.showName ~= false)

    Pixel.ApplyFont(frame.Bar.Duration, math.max(6, config.durationSize), font)
    frame.Bar.Duration:ClearAllPoints()
    frame.Bar.Duration:SetPoint("RIGHT", frame.Bar, "RIGHT", Pixel.Scale(-4), 0)
    frame.Bar.Duration:SetText(((PREVIEW_COUNT + 1 - previewIndex) * 3) .. "s")
    frame.Bar.Duration:SetShown(config.showDuration ~= false)
end

local function PositionPreviewFrame(frame, previewIndex, config, shelf)
    local iconSize = config.iconSize
    local barHeight = config.barHeight
    local slotHeight = math.max(config.showIcon ~= false and iconSize or 0, barHeight)
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
