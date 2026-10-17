local _, BUI = ...

local Pixel = BUI.Pixel
local Overlay = BUI.WorldMapOverlay

local BASE_PIN_SIZE = 20
local MIN_PIN_SIZE, MAX_PIN_SIZE = 14, 64
local BASE_FONT_SIZE = 9
local MIN_FONT_SIZE, MAX_FONT_SIZE = 6, 32

local pins = {}
local seen = {}

local PinEnter = BUI.Profiler.Script('WorldMap.InstancePins pin OnEnter', function(self)
    self.icon:SetVertexColor(1, 0.82, 0)
    GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
    GameTooltip:SetText(self._name, 1, 1, 1)
    if self._isRaid then
        GameTooltip:AddLine(RAID, 1, 0.5, 0.25)
    else
        GameTooltip:AddLine(LFG_TYPE_DUNGEON, 0.25, 0.78, 0.92)
    end
    GameTooltip:AddLine(self._zoneName, 0.7, 0.7, 0.7)
    GameTooltip:AddLine('Click to view zone', 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)

local PinLeave = BUI.Profiler.Script('WorldMap.InstancePins pin OnLeave', function(self)
    self.icon:SetVertexColor(1, 1, 1)
    GameTooltip:Hide()
end)

local function CreatePin(shelf)
    local pin = CreateFrame('Button', nil, shelf)
    pin.icon = pin:CreateTexture(nil, 'ARTWORK')
    pin.icon:SetAllPoints()
    pin.label = pin:CreateFontString(nil, 'OVERLAY')
    pin.label:SetShadowColor(0, 0, 0, 0.9)
    pin.label:SetShadowOffset(1, -1)
    pin.label:SetPoint('TOP', pin, 'BOTTOM', 0, -1)
    pin:SetScript('OnEnter', PinEnter)
    pin:SetScript('OnLeave', PinLeave)
    pin:SetMouseClickEnabled(false)
    return pin
end

local function PlacePin(overlay, index, entrance, zoneName, centerX, centerY, pinSize, fontSize)
    local pin = pins[index]
    if not pin then
        pin = CreatePin(overlay.shelf)
        pins[index] = pin
    end
    local isRaid = entrance.atlasName:lower():find('raid', 1, true) ~= nil
    pin._name = entrance.name
    pin._zoneName = zoneName
    pin._isRaid = isRaid
    pin:SetSize(pinSize, pinSize)
    pin.icon:SetAtlas(entrance.atlasName, false)
    pin.icon:SetVertexColor(1, 1, 1)
    Pixel.ApplyFont(pin.label, fontSize, BUI.C.FONT_PATH, 'OUTLINE')
    pin.label:SetText(entrance.name)
    pin.label:SetTextColor(1, 1, 1, isRaid and 0.95 or 0.8)
    pin:ClearAllPoints()
    pin:SetPoint('CENTER', overlay.canvas, 'TOPLEFT', centerX * overlay.width, -(centerY * overlay.height))
    pin:Show()
end

local function DrawPins(overlay, mapID)
    local pinSize = Overlay.Fit(overlay, BASE_PIN_SIZE, MIN_PIN_SIZE, MAX_PIN_SIZE)
    local fontSize = Overlay.Fit(overlay, BASE_FONT_SIZE, MIN_FONT_SIZE, MAX_FONT_SIZE)
    local count = 0
    wipe(seen)
    local zones = C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Zone, true)
    if zones then
        for _, zone in ipairs(zones) do
            local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(zone.mapID, mapID)
            if minX and maxX > minX then
                for _, entrance in ipairs(C_EncounterJournal.GetDungeonEntrancesForMap(zone.mapID)) do
                    local key = entrance.journalInstanceID
                    if not seen[key] then
                        seen[key] = true
                        count = count + 1
                        local position = entrance.position
                        PlacePin(overlay, count, entrance, zone.name,
                            minX + position.x * (maxX - minX), minY + position.y * (maxY - minY), pinSize, fontSize)
                    end
                end
            end
        end
    end
    for pinIndex = count + 1, #pins do pins[pinIndex]:Hide() end
end

local overlay = Overlay.New('worldMapDungeonPins', 12, DrawPins)
BUI.WorldMapInstancePins = { Refresh = overlay.Refresh }
