local _, BUI = ...
BUI.Lookup = {}
local Lookup = BUI.Lookup
local MISSING_ICON = 134400
local RESULT_CAP   = 10
local BAG_IDS      = { 0, 1, 2, 3, 4, -1, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
local GEAR_SLOTS   = 19

local function SearchBagsAndGear(needle, hits, already, cap)
    for index = 1, #BAG_IDS do
        local bagID = BAG_IDS[index]
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info then
                local key = "i" .. info.itemID
                if not already[key] and info.itemName:lower():find(needle, 1, true) then
                    already[key] = true
                    hits[#hits + 1] = {
                        id = info.itemID,
                        name = info.itemName .. " [Item]",
                        icon = info.iconFileID,
                        isItem = true,
                    }
                    if #hits >= cap then return true end
                end
            end
        end
    end
    for gearSlot = 1, GEAR_SLOTS do
        local gearID = GetInventoryItemID("player", gearSlot)
        if gearID then
            local key = "i" .. gearID
            if not already[key] then
                local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(gearID)
                if name and name:lower():find(needle, 1, true) then
                    already[key] = true
                    hits[#hits + 1] = {
                        id = gearID,
                        name = name .. " [Item]",
                        icon = icon,
                        isItem = true,
                    }
                    if #hits >= cap then return true end
                end
            end
        end
    end
    return false
end

local function ExtractItemID(input)
    return tonumber(input:match("item:(%d+)") or input:match("item=(%d+)") or input:match("item/(%d+)"))
end

local function ExtractSpellID(input)
    return tonumber(input:match("spell:(%d+)") or input:match("spell=(%d+)") or input:match("spell/(%d+)"))
end

local function FetchItemIcon(itemID)
    local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    if not name then
        local _, _, _, _, instantIcon = C_Item.GetItemInfoInstant(itemID)
        icon = instantIcon
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return icon, name
end

local function SpellHit(spellID, isItem)
    local info = C_Spell.GetSpellInfo(spellID)
    return {
        id = spellID,
        name = info and info.name or ("Spell " .. spellID),
        icon = info and info.iconID or MISSING_ICON,
        isItem = isItem,
    }
end

function Lookup.GetItemInfo(itemID)
    local numericItemID = tonumber(itemID)
    if not numericItemID then return nil, nil, nil end
    local icon, name = FetchItemIcon(numericItemID)
    return icon, name, numericItemID
end

local craftedQualityCache = {}

function Lookup.CraftedQualityInfo(itemID)
    local info = craftedQualityCache[itemID]
    if info then return info end
    info = C_TradeSkillUI.GetItemCraftedQualityInfo(itemID) or C_TradeSkillUI.GetItemReagentQualityInfo(itemID)
    if info then craftedQualityCache[itemID] = info end
    return info
end

function Lookup.CraftedQuality(itemID)
    local info = Lookup.CraftedQualityInfo(itemID)
    if not info then return 0, nil end
    return info.quality, info.iconInventory
end

function Lookup.ParseSpellInput(input)
    if not input or input == "" then return nil end
    local numericID = tonumber(input)
    if numericID then return numericID end
    local extractedSpellID = ExtractSpellID(input)
    if extractedSpellID then return extractedSpellID end
    local itemID = ExtractItemID(input)
    if itemID then
        local _, spellID = C_Item.GetItemSpell(itemID)
        if spellID then return spellID end
    end
    local info = C_Spell.GetSpellInfo(input)
    return info and info.spellID
end

function Lookup.GetSpellInfo(spellID)
    local numericSpellID = tonumber(spellID)
    if not numericSpellID then return nil, nil, nil end
    local info = C_Spell.GetSpellInfo(numericSpellID)
    if not info then return MISSING_ICON, nil, numericSpellID end
    return info.iconID, info.name, numericSpellID
end

local function SearchTalents(needle, hits, already, cap, includePassive)
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return false end

    local specID = PlayerUtil.GetCurrentSpecID()
    if not specID then return false end

    local seenTrees = {}
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    if treeID then seenTrees[treeID] = true end
    local configInfo = C_Traits.GetConfigInfo(configID)
    if configInfo then
        for _, configTreeID in ipairs(configInfo.treeIDs) do seenTrees[configTreeID] = true end
    end

    for seenTreeID in pairs(seenTrees) do
        local nodeIDs = C_Traits.GetTreeNodes(seenTreeID)
        if nodeIDs then
            for _, nodeID in ipairs(nodeIDs) do
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                if nodeInfo then
                    for _, entryID in ipairs(nodeInfo.entryIDs) do
                        local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                        if entryInfo and entryInfo.definitionID then
                            local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                            local spellID = definitionInfo and definitionInfo.spellID
                            if spellID and not already[spellID] then
                                local info = C_Spell.GetSpellInfo(spellID)
                                if info and info.name:lower():find(needle, 1, true) then
                                    if includePassive or not C_Spell.IsSpellPassive(spellID) then
                                        already[spellID] = true
                                        hits[#hits + 1] = { id = spellID, name = info.name, icon = info.iconID }
                                        if #hits >= cap then return true end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

local function MatchSpellBookItem(spell, needle, hits, already, cap)
    if spell.itemType == Enum.SpellBookItemType.Flyout then
        local _, _, numInFlyout = GetFlyoutInfo(spell.actionID)
        for flyoutIndex = 1, numInFlyout do
            local flySpellID, _, flyKnown = GetFlyoutSlotInfo(spell.actionID, flyoutIndex)
            if flySpellID and flyKnown and not already[flySpellID] then
                local flyInfo = C_Spell.GetSpellInfo(flySpellID)
                if flyInfo and flyInfo.name:lower():find(needle, 1, true) then
                    already[flySpellID] = true
                    hits[#hits + 1] = { id = flySpellID, name = flyInfo.name, icon = flyInfo.iconID }
                    if #hits >= cap then return true end
                end
            end
        end
    elseif spell.spellID and not already[spell.spellID] then
        if spell.name:lower():find(needle, 1, true) then
            already[spell.spellID] = true
            hits[#hits + 1] = { id = spell.spellID, name = spell.name, icon = spell.iconID }
            if #hits >= cap then return true end
        end
    end
    return false
end

function Lookup.SearchSpells(query, maxResults, viewerKey)
    if not query or query == "" then return {} end
    local cap = maxResults or RESULT_CAP
    local needle = query:lower()
    local hits = {}
    local already = {}
    local includePassive = viewerKey == 'buffs'

    local numericSpellID = tonumber(query) or ExtractSpellID(query)
    if numericSpellID then
        return { SpellHit(numericSpellID) }
    end

    if BUI.Tools.EachSpellBookItem(MatchSpellBookItem, needle, hits, already, cap) then return hits end
    if SearchTalents(needle, hits, already, cap, includePassive) then return hits end

    if #hits == 0 then
        local directLookup = C_Spell.GetSpellInfo(query)
        if directLookup then
            hits[#hits + 1] = { id = directLookup.spellID, name = directLookup.name, icon = directLookup.iconID }
        end
    end

    return hits
end

function Lookup.ParseSpellOrItemInput(input)
    if not input or input == "" then return nil, nil end
    local itemID = ExtractItemID(input)
    if itemID then return itemID, true end
    local spellID = ExtractSpellID(input)
    if spellID then return spellID, false end

    local numericID = tonumber(input)
    if numericID then
        local itemName = C_Item.GetItemInfo(numericID)
        if itemName and C_Item.GetItemCount(numericID, true) > 0 then
            return numericID, true
        end
        return numericID, false
    end

    local info = C_Spell.GetSpellInfo(input)
    if info then
        return info.spellID, false
    end

    local foundItemID = C_Item.GetItemInfoInstant(input)
    if foundItemID then
        return foundItemID, true
    end

    return nil, nil
end

function Lookup.SearchSpellsAndItems(query, maxResults, viewerKey)
    if not query or query == "" then return {} end
    local cap = maxResults or RESULT_CAP
    local needle = query:lower()
    local hits = {}
    local already = {}
    local includePassive = viewerKey == 'buffs'

    local itemID = ExtractItemID(query)
    if itemID then
        local icon, name = FetchItemIcon(itemID)
        return {{ id = itemID, name = (name and name .. " [Item]") or ("Item " .. itemID), icon = icon or MISSING_ICON, isItem = true }}
    end
    local spellID = ExtractSpellID(query)
    if spellID then
        return { SpellHit(spellID, false) }
    end

    local numericID = tonumber(query)
    if numericID then
        hits[1] = SpellHit(numericID, false)
        local itemIcon, itemName = FetchItemIcon(numericID)
        hits[2] = {
            id = numericID,
            name = (itemName and itemName .. " [Item]") or ("Item " .. numericID .. " [Item]"),
            icon = itemIcon or MISSING_ICON,
            isItem = true,
        }
        return hits
    end

    BUI.Tools.EachSpellBookItem(MatchSpellBookItem, needle, hits, already, cap)
    if #hits < cap then
        SearchTalents(needle, hits, already, cap, includePassive)
    end
    if #hits < cap then
        SearchBagsAndGear(needle, hits, already, cap)
    end

    return hits
end
