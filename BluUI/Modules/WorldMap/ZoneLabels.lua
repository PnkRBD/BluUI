local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('WorldMap.ZoneLabels')

local hooksecurefunc = BUI.Prof.MakeHooker('zonelabels')
local Pixel = BUI.Pixel

BUI.WorldMapLabels = {}

local BASE_FONT_SIZE = 13
local MIN_FONT_SIZE, MAX_FONT_SIZE = 8, 30

local container
local labels = {}

local MANUAL_POSITIONS = {
    [12] = {
        { mapID = 97,  x = 0.28, y = 0.16 },
        { mapID = 106, x = 0.27, y = 0.10 },
    },
}

local function IsEnabled()
    if BUI.GetDB().interface.worldMapZoneNames ~= true then return false end
    return BUI.Skinning.IsSkinEnabled('worldmap')
end

local function GetContainer(canvas)
    if container then return container end
    container = CreateFrame('Frame', nil, canvas)
    container:SetAllPoints(canvas)

    container:SetFrameLevel(canvas:GetFrameLevel() + 10)
    return container
end

local function FontSize()
    local scale = WorldMapFrame:GetCanvasScale()
    if scale <= 0 then scale = 1 end
    return math.min(MAX_FONT_SIZE, math.max(MIN_FONT_SIZE, BASE_FONT_SIZE / scale))
end

local function Update()
    if not container and not IsEnabled() then return end
    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end
    local shelf = GetContainer(canvas)

    local mapID = WorldMapFrame:GetMapID()
    local info = mapID and C_Map.GetMapInfo(mapID)
    if not IsEnabled() or not info or info.mapType ~= Enum.UIMapType.Continent then
        shelf:Hide()
        return
    end

    local width, height = canvas:GetWidth(), canvas:GetHeight()
    if width <= 0 or height <= 0 then
        shelf:Hide()
        return
    end

    local size = FontSize()
    local font = BUI.C.FONT_PATH
    local labelCount = 0

    local function PlaceLabel(name, centerX, centerY)
        labelCount = labelCount + 1
        local fontString = labels[labelCount]
        if not fontString then
            fontString = shelf:CreateFontString(nil, 'OVERLAY')
            fontString:SetShadowColor(0, 0, 0, 0.8)
            fontString:SetShadowOffset(1, -1)
            labels[labelCount] = fontString
        end
        Pixel.ApplyFont(fontString, size, font, 'OUTLINE')
        fontString:SetText(name)
        fontString:SetTextColor(1, 1, 1, 0.75)
        fontString:ClearAllPoints()
        fontString:SetPoint('CENTER', canvas, 'TOPLEFT', centerX * width, -(centerY * height))
        fontString:Show()
    end

    local placed = {}
    local function PlaceChildren(children)
        for _, child in ipairs(children or {}) do
            local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(child.mapID, mapID)
            if minX and maxX and maxX > minX and child.name and child.name ~= '' then
                placed[child.mapID] = true
                PlaceLabel(child.name, (minX + maxX) * 0.5, (minY + maxY) * 0.5)
            end
        end
    end
    PlaceChildren(C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Zone))

    PlaceChildren(C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Continent))

    for _, entry in ipairs(MANUAL_POSITIONS[mapID] or {}) do
        if not placed[entry.mapID] then
            local zoneInfo = C_Map.GetMapInfo(entry.mapID)
            if zoneInfo and zoneInfo.name then
                PlaceLabel(zoneInfo.name, entry.x, entry.y)
            end
        end
    end

    for labelIndex = labelCount + 1, #labels do labels[labelIndex]:Hide() end
    shelf:Show()
end

BUI.WorldMapLabels.Refresh = Update

local OnCanvasScaleChanged = BUI.Dispatcher.New(Update, 'WorldMapLabels.Rescale')

BUI.Events:OnLogin('WorldMapLabels', function()
    if not WorldMapFrame then return end
    hooksecurefunc(WorldMapFrame, 'OnMapChanged', Update)
    HookScript(WorldMapFrame, 'OnShow', Update)
    local scroll = WorldMapFrame.ScrollContainer
    if scroll and scroll.SetCanvasScale then
        hooksecurefunc(scroll, 'SetCanvasScale', OnCanvasScaleChanged)
    end
end)
