local _, BUI = ...

local Datatext = BUI.Datatext
local WHITE, RED, YELLOW, RESET = Datatext.WHITE, Datatext.RED, Datatext.YELLOW, Datatext.RESET
local PERCENT = WHITE .. '%' .. RESET

local SLOTS = {
    { 1,  'Head' }, { 3,  'Shoulder' }, { 5,  'Chest' }, { 6,  'Waist' },
    { 7,  'Legs' }, { 8,  'Feet' },     { 9,  'Wrist' }, { 10, 'Hands' },
    { 16, 'Main Hand' }, { 17, 'Off Hand' }, { 18, 'Ranged' },
}

local lowest = 100
local slotPercent = {}

local function ThresholdColor(percent, valueHex)
    if percent <= 30 then return RED end
    if percent < 60 then return YELLOW end
    return '|cff' .. valueHex
end

local function Read()
    local minimum, sampled = 100, false
    for slotIndex = 1, #SLOTS do
        local slot = SLOTS[slotIndex][1]
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 then
            sampled = true
            local percent = (current / maximum) * 100
            slotPercent[slot] = percent
            if percent < minimum then minimum = percent end
        else
            slotPercent[slot] = nil
        end
    end
    if sampled then lowest = minimum end
end

Datatext.Register('durability', {
    name = 'Durability', show = 'showDurability', label = 'D:',
    events = { 'UPDATE_INVENTORY_DURABILITY', 'MERCHANT_SHOW', 'PLAYER_EQUIPMENT_CHANGED', 'PLAYER_ENTERING_WORLD' },
    OnActivate = Read,
    OnEvent = function()
        Read()
        Datatext.Refresh()
    end,
    build = function(config, valueHex, self)
        local percent = math.floor(lowest)
        return Datatext.Label(config, self) .. ThresholdColor(percent, valueHex) .. percent .. RESET .. PERCENT
    end,
    OnClick = function(_, button)
        if button ~= 'LeftButton' or InCombatLockdown() then return end
        ToggleCharacter('PaperDollFrame')
        return true
    end,
    OnEnter = function(hit, bar)
        local tooltip = Datatext.Tooltip(hit)
        tooltip:AddLine('Durability', 1, 1, 1)
        local config = bar.getConfig()
        local valueHex = BUI.Hex(config.colorValue.r, config.colorValue.g, config.colorValue.b)
        local shown = false
        for slotIndex = 1, #SLOTS do
            local slot, name = SLOTS[slotIndex][1], SLOTS[slotIndex][2]
            local percent = slotPercent[slot]
            if percent then
                local rounded = math.floor(percent)
                tooltip:AddDoubleLine(name, ThresholdColor(rounded, valueHex) .. rounded .. '%' .. RESET, 0.8, 0.8, 0.8)
                shown = true
            end
        end
        if not shown then tooltip:AddLine('Nothing equipped with durability', 0.5, 0.5, 0.5) end
        tooltip:AddLine(' ')
        tooltip:AddLine('Left-Click  |cffffffffCharacter Sheet|r', 1, 0.82, 0)
        tooltip:Show()
    end,
    sample = function(config, label, colorize) return label .. colorize('95') .. PERCENT end,
})
