local _, BUI = ...

local Datatext = BUI.Datatext
local WHITE, RESET = Datatext.WHITE, Datatext.RESET
local SLASH = WHITE .. '/' .. RESET

local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS
local REAGENT_BAG = Enum.BagIndex.ReagentBag
local ICON = '|T%s:14:14:0:0:64:64:5:59:5:59|t  %s'

local BAG_FORMATS = {
    { value = 'FREE',       text = 'Free'       },
    { value = 'USED',       text = 'Used'       },
    { value = 'FREE_TOTAL', text = 'Free/Total' },
}

local freeSlots, totalSlots = 0, 0
local reagentFree, reagentTotal = 0, 0

local function Read()
    local freeCount, totalCount, reagentFreeCount, reagentTotalCount = 0, 0, 0, 0
    for bagIndex = 0, LAST_BAG do
        local bagFree, bagType = C_Container.GetContainerNumFreeSlots(bagIndex)
        if bagFree and (not bagType or bagType == 0) then
            local bagTotal = C_Container.GetContainerNumSlots(bagIndex)
            if bagIndex == REAGENT_BAG then
                reagentFreeCount, reagentTotalCount = reagentFreeCount + bagFree, reagentTotalCount + bagTotal
            else
                freeCount, totalCount = freeCount + bagFree, totalCount + bagTotal
            end
        end
    end
    if freeCount ~= freeSlots or totalCount ~= totalSlots or reagentFreeCount ~= reagentFree or reagentTotalCount ~= reagentTotal then
        freeSlots, totalSlots, reagentFree, reagentTotal = freeCount, totalCount, reagentFreeCount, reagentTotalCount
        return true
    end
end

local function FullnessColor(used, totalCount)
    local ratio = totalCount > 0 and (used / totalCount) or 0
    if ratio < 0.5 then return 0.3 + ratio * 1.4, 1, 0.3 end
    return 1, 1 - (ratio - 0.5) * 1.4, 0.3
end

Datatext.Register('bags', {
    name = 'Bags', show = 'showBags', label = 'Bags:',
    events = { 'BAG_UPDATE_DELAYED', 'PLAYER_ENTERING_WORLD' },
    defaults = { bagsFormat = 'FREE' },
    OnActivate = Read,
    OnEvent = function()
        if Read() then Datatext.Refresh() end
    end,
    build = function(config, valueHex, self)
        local label = Datatext.Label(config, self)
        local format = config.bagsFormat
        if format == 'USED' then
            return label .. Datatext.Colored(totalSlots - freeSlots, valueHex)
        elseif format == 'FREE_TOTAL' then
            return label .. Datatext.Colored(freeSlots, valueHex) .. SLASH .. Datatext.Colored(totalSlots, valueHex)
        end
        return label .. Datatext.Colored(freeSlots, valueHex)
    end,
    OnClick = function(_, button)
        if button ~= 'LeftButton' then return end
        ToggleAllBags()
        return true
    end,
    OnEnter = function(hit)
        local tooltip = Datatext.Tooltip(hit)
        tooltip:AddLine('Bags', 1, 1, 1)
        for bagIndex = 0, LAST_BAG do
            local name = C_Container.GetBagName(bagIndex)
            if name then
                local totalCount = C_Container.GetContainerNumSlots(bagIndex)
                local freeCount = C_Container.GetContainerNumFreeSlots(bagIndex)
                local used = totalCount - freeCount
                local icon
                if bagIndex > 0 then
                    local inventoryID = C_Container.ContainerIDToInventoryID(bagIndex)
                    icon = inventoryID and GetInventoryItemTexture('player', inventoryID)
                end
                local red, green, blue = FullnessColor(used, totalCount)
                tooltip:AddDoubleLine(string.format(ICON, icon or 130716, name), used .. ' / ' .. totalCount, 0.85, 0.85, 0.88, red, green, blue)
            end
        end
        tooltip:AddLine(' ')
        tooltip:AddDoubleLine('Free', freeSlots .. ' / ' .. totalSlots, 0.7, 0.7, 0.7, 1, 1, 1)
        if reagentTotal > 0 then
            tooltip:AddDoubleLine('Reagent Free', reagentFree .. ' / ' .. reagentTotal, 0.7, 0.7, 0.7, 1, 1, 1)
        end
        tooltip:AddLine(' ')
        tooltip:AddLine('Left-Click  |cffffffffOpen Bags|r', 1, 0.82, 0)
        tooltip:Show()
    end,
    options = function(getConfig, apply)
        return {
            {
                kind = 'dropdown', label = 'Bag Count', items = BAG_FORMATS, controlWidth = 150,
                get = function() return getConfig().bagsFormat or 'FREE' end,
                set = function(value) getConfig().bagsFormat = value; apply() end,
            },
        }
    end,
    sample = function(config, label, colorize)
        if config.bagsFormat == 'USED' then return label .. colorize('98') end
        if config.bagsFormat == 'FREE_TOTAL' then return label .. colorize('42') .. SLASH .. colorize('140') end
        return label .. colorize('42')
    end,
})
