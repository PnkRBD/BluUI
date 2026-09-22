local _, BUI = ...

local Datatext = BUI.Datatext
local BUILib = LibStub('BUILib')
local Controls = BUILib.Controls

local CURRENT_SPEC_ICON = 132222

local lootSpecName, currentSpecName = '', ''

local function CurrentSpecInfo()
    local specIndex = GetSpecialization()
    if not specIndex then return nil, 'None' end
    local specID, name = GetSpecializationInfo(specIndex)
    return specID, name or '?'
end

local function Read()
    local _, current = CurrentSpecInfo()
    local loot
    local lootSpecID = GetLootSpecialization()
    if lootSpecID == 0 then
        loot = current
    else
        local _, name = GetSpecializationInfoByID(lootSpecID)
        loot = name or '?'
    end
    if loot ~= lootSpecName or current ~= currentSpecName then
        lootSpecName, currentSpecName = loot, current
        return true
    end
end

local function ActiveText(text, isActive)
    if not isActive then return text end
    local red, green, blue = BUILib.Theme.GetAccent()
    return '|cff' .. BUI.Hex(red, green, blue) .. text .. '|r'
end

local function OpenLootSpecMenu()
    if InCombatLockdown() then return end
    local lootSpecID = GetLootSpecialization()
    local _, currentName = CurrentSpecInfo()
    local items = {
        { title = 'Loot Specialization' },
        {
            text = ActiveText('Current Specialization (' .. currentName .. ')', lootSpecID == 0),
            icon = CURRENT_SPEC_ICON,
            callback = function() SetLootSpecialization(0) end,
        },
        { separator = true },
    }
    for specIndex = 1, GetNumSpecializations() do
        local specID, name, _, icon = GetSpecializationInfo(specIndex)
        if specID then
            items[#items + 1] = {
                text = ActiveText(name, lootSpecID == specID),
                icon = icon,
                callback = function() SetLootSpecialization(specID) end,
            }
        end
    end
    Controls.ContextMenu(items, { atCursor = true, width = 220 })
end

Datatext.Register('lootSpec', {
    name = 'Loot Spec', show = 'showLootSpec', label = 'Loot:',
    events = { 'PLAYER_LOOT_SPEC_UPDATED', 'PLAYER_SPECIALIZATION_CHANGED', 'PLAYER_ENTERING_WORLD' },
    OnActivate = Read,
    OnEvent = function(event, unit)
        if event == 'PLAYER_SPECIALIZATION_CHANGED' and unit and unit ~= 'player' then return end
        if Read() then Datatext.Refresh() end
    end,
    build = function(config, valueHex, self)
        return Datatext.Label(config, self) .. Datatext.Colored(lootSpecName, valueHex)
    end,
    OnClick = function(_, button)
        if button ~= 'LeftButton' then return end
        OpenLootSpecMenu()
        return true
    end,
    OnEnter = function(hit)
        local tooltip = Datatext.Tooltip(hit)
        tooltip:AddLine('Loot Specialization', 1, 1, 1)
        tooltip:AddDoubleLine('Loot', lootSpecName, 0.7, 0.7, 0.7, 1, 1, 1)
        tooltip:AddDoubleLine('Current Spec', currentSpecName, 0.7, 0.7, 0.7, 1, 1, 1)
        if GetLootSpecialization() == 0 then
            tooltip:AddLine('Following current specialization', 0.5, 0.5, 0.5)
        end
        tooltip:AddLine(' ')
        tooltip:AddLine('Left-Click  |cffffffffChange Loot Spec|r', 1, 0.82, 0)
        tooltip:Show()
    end,
    sample = function(config, label, colorize) return label .. colorize('Spec') end,
})
