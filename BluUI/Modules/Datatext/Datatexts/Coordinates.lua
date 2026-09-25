local _, BUI = ...

local Datatext = BUI.Datatext

local coordX, coordY = 0, 0

local PVP_LABELS = {
    sanctuary = { 'Sanctuary', 0.41, 0.8, 0.94 },
    friendly  = { 'Friendly', 0.1, 1, 0.1 },
    hostile   = { 'Hostile', 1, 0.1, 0.1 },
    contested = { 'Contested', 1, 0.7, 0 },
    combat    = { 'Combat', 1, 0.1, 0.1 },
    arena     = { 'Arena', 1, 0.1, 0.1 },
}

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
    OnClick = function(_, button)
        if button ~= 'LeftButton' or InCombatLockdown() then return end
        ToggleWorldMap()
        return true
    end,
    OnEnter = function(hit)
        local tooltip = Datatext.Tooltip(hit)
        tooltip:AddLine(GetRealZoneText(), 1, 1, 1)
        local subZone = GetSubZoneText()
        if subZone ~= '' then
            tooltip:AddDoubleLine('Subzone', subZone, 0.7, 0.7, 0.7, 1, 1, 1)
        end
        tooltip:AddDoubleLine('Coordinates', ('%.1f, %.1f'):format(coordX, coordY), 0.7, 0.7, 0.7, 1, 1, 1)
        local pvpLabel = PVP_LABELS[C_PvP.GetZonePVPInfo()]
        if pvpLabel then
            tooltip:AddDoubleLine('Zone', pvpLabel[1], 0.7, 0.7, 0.7, pvpLabel[2], pvpLabel[3], pvpLabel[4])
        end
        tooltip:AddLine(' ')
        tooltip:AddLine('Left-Click  |cffffffffWorld Map|r', 1, 0.82, 0)
        tooltip:Show()
    end,
    sample = function(config, label, colorize) return label .. colorize('50.0') .. ', ' .. colorize('50.0') end,
})
