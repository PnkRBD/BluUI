local _, BUI = ...

local Hook = BUI.Profiler.Hooker('WorldMap.ZoneLabels')

local Pixel = BUI.Pixel

local BASE_FONT_SIZE = 13
local MIN_FONT_SIZE, MAX_FONT_SIZE = 8, 30

local MANUAL_POSITIONS = {
    [12] = {
        { mapID = 97,  x = 0.28, y = 0.16 },
        { mapID = 106, x = 0.27, y = 0.10 },
    },
}

local overlays = {}

local function Fit(overlay, base, minimum, maximum)
    return math.min(maximum, math.max(minimum, base / overlay.scale))
end

local function NewOverlay(settingKey, levelOffset, draw)
    local overlay = {}

    local function IsEnabled()
        return BUI.GetDB().interface[settingKey] and BUI.Skinning.IsSkinEnabled('worldmap')
    end

    function overlay.Refresh()
        local shelf = overlay.shelf
        if not shelf and not IsEnabled() then return end
        local canvas = WorldMapFrame:GetCanvas()
        if not shelf then
            shelf = CreateFrame('Frame', nil, canvas)
            shelf:SetAllPoints(canvas)
            shelf:SetFrameLevel(canvas:GetFrameLevel() + levelOffset)
            overlay.shelf = shelf
        end
        local mapID = WorldMapFrame:GetMapID()
        local info = mapID and C_Map.GetMapInfo(mapID)
        local width, height = canvas:GetWidth(), canvas:GetHeight()
        if not IsEnabled() or not info or info.mapType ~= Enum.UIMapType.Continent or width <= 0 or height <= 0 then
            shelf:Hide()
            return
        end
        overlay.canvas, overlay.width, overlay.height = canvas, width, height
        overlay.scale = WorldMapFrame:GetCanvasScale()
        draw(overlay, mapID)
        shelf:Show()
    end

    overlays[#overlays + 1] = overlay
    return overlay
end

BUI.WorldMapOverlay = { New = NewOverlay, Fit = Fit }

local labels = {}
local placed = {}

local function PlaceLabel(overlay, index, name, size, centerX, centerY)
    local fontString = labels[index]
    if not fontString then
        fontString = overlay.shelf:CreateFontString(nil, 'OVERLAY')
        fontString:SetShadowColor(0, 0, 0, 0.8)
        fontString:SetShadowOffset(1, -1)
        fontString:SetTextColor(1, 1, 1, 0.75)
        labels[index] = fontString
    end
    Pixel.ApplyFont(fontString, size, BUI.C.FONT_PATH, 'OUTLINE')
    fontString:SetText(name)
    fontString:ClearAllPoints()
    fontString:SetPoint('CENTER', overlay.canvas, 'TOPLEFT', centerX * overlay.width, -(centerY * overlay.height))
    fontString:Show()
end

local function PlaceChildren(overlay, mapID, children, count, size)
    if not children then return count end
    for _, child in ipairs(children) do
        local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(child.mapID, mapID)
        if minX and maxX > minX and child.name ~= '' then
            placed[child.mapID] = true
            count = count + 1
            PlaceLabel(overlay, count, child.name, size, (minX + maxX) * 0.5, (minY + maxY) * 0.5)
        end
    end
    return count
end

local function DrawLabels(overlay, mapID)
    local size = Fit(overlay, BASE_FONT_SIZE, MIN_FONT_SIZE, MAX_FONT_SIZE)
    wipe(placed)
    local count = PlaceChildren(overlay, mapID, C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Zone), 0, size)
    count = PlaceChildren(overlay, mapID, C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Continent), count, size)
    local manual = MANUAL_POSITIONS[mapID]
    if manual then
        for _, entry in ipairs(manual) do
            if not placed[entry.mapID] then
                local zoneInfo = C_Map.GetMapInfo(entry.mapID)
                if zoneInfo then
                    count = count + 1
                    PlaceLabel(overlay, count, zoneInfo.name, size, entry.x, entry.y)
                end
            end
        end
    end
    for labelIndex = count + 1, #labels do labels[labelIndex]:Hide() end
end

local overlay = NewOverlay('worldMapZoneNames', 10, DrawLabels)
BUI.WorldMapLabels = { Refresh = overlay.Refresh }

local function RefreshAll()
    for _, entry in ipairs(overlays) do entry.Refresh() end
end

local OnCanvasScaleChanged = BUI.Dispatcher.New(RefreshAll, 'WorldMapOverlays.Rescale')

BUI.Events:OnLogin('WorldMapOverlays', function()
    Hook(WorldMapFrame, 'OnMapChanged', RefreshAll)
    Hook(WorldMapFrame, 'OnCanvasScaleChanged', OnCanvasScaleChanged)
    WorldMapFrame:HookScript('OnShow', BUI.Profiler.Wrap('WorldMap.ZoneLabels map shown', RefreshAll))
end)
