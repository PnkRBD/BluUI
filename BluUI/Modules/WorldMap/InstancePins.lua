local _, BUI = ...

local Pixel = BUI.Pixel

BUI.WorldMapInstancePins = {}

local BASE_PIN_SIZE = 20
local MIN_PIN_SIZE, MAX_PIN_SIZE = 14, 64
local BASE_FONT_SIZE = 9
local MIN_FONT_SIZE, MAX_FONT_SIZE = 6, 32

local container
local pins = {}

local function IsEnabled()
    if BUI.GetDB().interface.worldMapDungeonPins ~= true then return false end
    return BUI.Skinning.IsSkinEnabled('worldmap')
end

local function GetContainer(canvas)
    if container then return container end
    container = CreateFrame('Frame', nil, canvas)
    container:SetAllPoints(canvas)
    container:SetFrameLevel(canvas:GetFrameLevel() + 12)
    return container
end

local function CanvasScale()
    local scale = WorldMapFrame:GetCanvasScale()
    if scale <= 0 then scale = 1 end
    return scale
end

local function IsRaidAtlas(atlasName)
    return type(atlasName) == 'string' and atlasName:lower():find('raid', 1, true) ~= nil
end

local function AcquirePin(shelf)
    local pin = CreateFrame('Button', nil, shelf)
    pin.icon = pin:CreateTexture(nil, 'ARTWORK')
    pin.icon:SetAllPoints()
    pin.label = pin:CreateFontString(nil, 'OVERLAY')
    pin.label:SetShadowColor(0, 0, 0, 0.9)
    pin.label:SetShadowOffset(1, -1)
    pin.label:SetPoint('TOP', pin, 'BOTTOM', 0, -1)
    pin:SetScript('OnEnter', function(self)
        self.icon:SetVertexColor(1, 0.82, 0)
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:SetText(self._name or '', 1, 1, 1)
        if self._isRaid then
            GameTooltip:AddLine(RAID, 1, 0.5, 0.25)
        else
            GameTooltip:AddLine(LFG_TYPE_DUNGEON, 0.25, 0.78, 0.92)
        end
        if self._zoneName then
            GameTooltip:AddLine(self._zoneName, 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine('Click to view zone', 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    pin:SetScript('OnLeave', function(self)
        self.icon:SetVertexColor(1, 1, 1)
        GameTooltip:Hide()
    end)
    pin:SetMouseClickEnabled(false)
    return pin
end

local function Update()
    if not container and not IsEnabled() then return end
    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end
    local shelf = GetContainer(canvas)

    local mapID = WorldMapFrame:GetMapID()
    local info = mapID and C_Map.GetMapInfo(mapID)
    local GetEntrances = C_EncounterJournal.GetDungeonEntrancesForMap
    if not IsEnabled() or not info or info.mapType ~= Enum.UIMapType.Continent then
        shelf:Hide()
        return
    end

    local width, height = canvas:GetWidth(), canvas:GetHeight()
    if width <= 0 or height <= 0 then
        shelf:Hide()
        return
    end

    local scale = CanvasScale()
    local pinSize = math.min(MAX_PIN_SIZE, math.max(MIN_PIN_SIZE, BASE_PIN_SIZE / scale))
    local fontSize = math.min(MAX_FONT_SIZE, math.max(MIN_FONT_SIZE, BASE_FONT_SIZE / scale))
    local font = BUI.C.FONT_PATH
    local pinCount = 0

    local function PlacePin(entrance, zone, minX, minY, spanX, spanY)
        local position = entrance.position
        if not position then return end
        pinCount = pinCount + 1
        local pin = pins[pinCount]
        if not pin then
            pin = AcquirePin(shelf)
            pins[pinCount] = pin
        end
        local isRaid = IsRaidAtlas(entrance.atlasName)
        pin._name = entrance.name
        pin._zoneName = zone.name
        pin._isRaid = isRaid
        pin:SetSize(pinSize, pinSize)
        pin.icon:SetAtlas(entrance.atlasName or 'Dungeon', false)
        pin.icon:SetVertexColor(1, 1, 1)
        Pixel.ApplyFont(pin.label, fontSize, font, 'OUTLINE')
        pin.label:SetText(entrance.name)
        pin.label:SetTextColor(1, 1, 1, isRaid and 0.95 or 0.8)
        local centerX = minX + position.x * spanX
        local centerY = minY + position.y * spanY
        pin:ClearAllPoints()
        pin:SetPoint('CENTER', canvas, 'TOPLEFT', centerX * width, -(centerY * height))
        pin:Show()
    end

    local seen = {}
    for _, zone in ipairs(C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Zone, true) or {}) do
        local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(zone.mapID, mapID)
        if minX and maxX and maxX > minX then
            for _, entrance in ipairs(GetEntrances(zone.mapID) or {}) do
                local key = entrance.journalInstanceID or entrance.name
                if not (key and seen[key]) then
                    if key then seen[key] = true end
                    PlacePin(entrance, zone, minX, minY, maxX - minX, maxY - minY)
                end
            end
        end
    end

    for pinIndex = pinCount + 1, #pins do pins[pinIndex]:Hide() end
    shelf:Show()
end

BUI.WorldMapInstancePins.Refresh = Update

local OnCanvasScaleChanged = BUI.Dispatcher.New(Update, 'WorldMapPins.Rescale')

BUI.Events:OnLogin('WorldMapInstancePins', function()
    if not WorldMapFrame then return end
    hooksecurefunc(WorldMapFrame, 'OnMapChanged', Update)
    WorldMapFrame:HookScript('OnShow', Update)
    local scroll = WorldMapFrame.ScrollContainer
    if scroll and scroll.SetCanvasScale then
        hooksecurefunc(scroll, 'SetCanvasScale', OnCanvasScaleChanged)
    end
end)
