local _, BUI = ...

local Datatext = BUI.Datatext

local equippedLevel, overallLevel = 0, 0

local function Read()
    local overall, equipped = GetAverageItemLevel()
    overall, equipped = math.floor(overall), math.floor(equipped)
    if overall ~= overallLevel or equipped ~= equippedLevel then
        overallLevel, equippedLevel = overall, equipped
        return true
    end
end

Datatext.Register('ilvl', {
    name = 'Item Level', show = 'showIlvl', label = 'iLvl:',
    events = { 'PLAYER_AVG_ITEM_LEVEL_UPDATE', 'PLAYER_EQUIPMENT_CHANGED', 'PLAYER_ENTERING_WORLD' },
    OnActivate = Read,
    OnEvent = function()
        if Read() then Datatext.Refresh() end
    end,
    build = function(config, valueHex, self)
        return Datatext.Label(config, self) .. Datatext.Colored(equippedLevel, valueHex)
    end,
    OnClick = function(_, button)
        if button ~= 'LeftButton' or InCombatLockdown() then return end
        ToggleCharacter('PaperDollFrame')
        return true
    end,
    OnEnter = function(hit)
        local tooltip = Datatext.Tooltip(hit)
        tooltip:AddLine('Item Level', 1, 1, 1)
        tooltip:AddDoubleLine('Equipped', equippedLevel, 0.7, 0.7, 0.7, 1, 1, 1)
        tooltip:AddDoubleLine('Overall', overallLevel, 0.7, 0.7, 0.7, 1, 1, 1)
        tooltip:AddLine(' ')
        tooltip:AddLine('Left-Click  |cffffffffCharacter Sheet|r', 1, 0.82, 0)
        tooltip:Show()
    end,
    sample = function(config, label, colorize) return label .. colorize('540') end,
})
