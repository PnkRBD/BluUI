local _, BUI = ...

local Datatext = BUI.Datatext

local coordX, coordY = 0, 0

local function Read()
    local map = C_Map.GetBestMapForUnit('player')
    if not map then return end
    local position = C_Map.GetPlayerMapPosition(map, 'player')
    if not position then return end
    local mapX = math.floor(position.x * 1000 + 0.5) / 10
    local mapY = math.floor(position.y * 1000 + 0.5) / 10
    if mapX ~= coordX or mapY ~= coordY then
        coordX, coordY = mapX, mapY
        return true
    end
end

Datatext.Register('coords', {
    name = 'Coordinates', show = 'showCoords', label = 'XY:',
    interval = 0.5,
    OnUpdate = function()
        if Read() then Datatext.Refresh() end
    end,
    build = function(config, valueHex, self)
        return Datatext.Label(config, self) .. Datatext.Colored(coordX, valueHex) .. ', ' .. Datatext.Colored(coordY, valueHex)
    end,
    sample = function(config, label, colorize) return label .. colorize('50.0') .. ', ' .. colorize('50.0') end,
})
