local _, BUI = ...

local pairs, ipairs, next = pairs, ipairs, next
local type = type
local tostring, tonumber = tostring, tonumber

local CDM = BUI.CDM
local GetBuildKey = CDM.GetBuildKey

local EMPTY = {}

local function PerSpecGet(config, field)
    if not config[field] then return EMPTY end
    return config[field][GetBuildKey()] or EMPTY
end

local function PerSpecSet(config, field, id, value)
    config[field] = config[field] or {}
    local key = GetBuildKey()
    config[field][key] = config[field][key] or {}
    config[field][key][id] = value
end

function CDM.GetIconOrder(config)
    return config.iconOrder[GetBuildKey()]
end

function CDM.SetIconOrder(config, newOrder)
    local key = GetBuildKey()
    local oldOrder = config.iconOrder[key]

    if oldOrder and #newOrder > 0 then
        local inNew = {}
        for _, id in ipairs(newOrder) do
            inNew[id] = true
        end
        for _, id in ipairs(oldOrder) do
            if not inNew[id] then
                newOrder[#newOrder + 1] = id
            end
        end
    end

    config.iconOrder[key] = newOrder
end

local function IsBuffsViewerConfig(config)
    return BUI.GetDB().cdm.buffs == config
end

local function BucketContains(list, entry)
    local target = tostring(entry)
    for _, value in ipairs(list) do
        if tostring(value) == target then return true end
    end
    return false
end

local function BucketAdd(list, entry)
    if BucketContains(list, entry) then return end
    list[#list + 1] = entry
end

local function BucketRemove(list, entry)
    if type(list) ~= 'table' then return end
    local target = tostring(entry)
    for entryIndex = #list, 1, -1 do
        if tostring(list[entryIndex]) == target then
            table.remove(list, entryIndex)
        end
    end
end

local function RemoveFromSpecLists(config, entry)
    for _, list in pairs(config.customSpells) do
        if type(list) == 'table' then BucketRemove(list, entry) end
    end
end

function CDM.GetCustomSpells(config)
    if IsBuffsViewerConfig(config) then
        local key = GetBuildKey()
        local perSpec = config.customSpells[key]
        local global = config.customSpellsGlobal
        local hasPerSpec = perSpec and perSpec[1] ~= nil
        local hasGlobal = global and global[1] ~= nil
        if not hasPerSpec and not hasGlobal then return EMPTY end
        if hasPerSpec and not hasGlobal then return perSpec end
        if hasGlobal and not hasPerSpec then return global end
        local merged = {}
        local seen = {}
        for _, value in ipairs(perSpec) do
            merged[#merged + 1] = value
            seen[tostring(value)] = true
        end
        for _, value in ipairs(global) do
            if not seen[tostring(value)] then
                merged[#merged + 1] = value
                seen[tostring(value)] = true
            end
        end
        return merged
    end
    return config.customSpells
end

function CDM.AddCustomSpell(config, entry, asGlobal)
    if IsBuffsViewerConfig(config) then
        if asGlobal then
            config.customSpellsGlobal = config.customSpellsGlobal or {}
            BucketAdd(config.customSpellsGlobal, entry)
            RemoveFromSpecLists(config, entry)
        else
            BucketRemove(config.customSpellsGlobal, entry)
            local key = GetBuildKey()
            config.customSpells[key] = config.customSpells[key] or {}
            BucketAdd(config.customSpells[key], entry)
        end
        return
    end
    BucketAdd(config.customSpells, entry)
end

function CDM.RemoveCustomSpell(config, entry)
    if IsBuffsViewerConfig(config) then
        BucketRemove(config.customSpellsGlobal, entry)
        RemoveFromSpecLists(config, entry)
        return
    end
    BucketRemove(config.customSpells, entry)
end

function CDM.ClearAllCustomSpells(config)
    if IsBuffsViewerConfig(config) then
        config.customSpells = {}
        config.customSpellsGlobal = {}
        config.manualBuffs = {}
        config.manualBuffsGlobal = {}
        return
    end
    config.customSpells = {}
end

function CDM.GetHiddenIcons(config) return PerSpecGet(config, 'hiddenIcons') end

function CDM.SetHiddenIcon(config, id, isHidden) PerSpecSet(config, 'hiddenIcons', id, isHidden and true or false) end

local UTILITY_AUTO_SLOTS = { ['racial:1'] = true, ['trinket:1'] = true, ['trinket:2'] = true }

function CDM.IsIconHiddenEffective(viewerKey, hiddenIcons, id)
    local hiddenState = hiddenIcons and hiddenIcons[id]
    if hiddenState == true then return true end
    if hiddenState ~= nil then return false end
    if viewerKey == 'utility' and UTILITY_AUTO_SLOTS[id] then return true end
    return false
end

function CDM.GetIconOverrides(config) return PerSpecGet(config, 'iconOverrides') end
function CDM.SetIconOverride(config, id, textureID) PerSpecSet(config, 'iconOverrides', id, textureID) end

local function PotionPrioKey(storedValue)
    if type(storedValue) == 'string' then
        return tonumber(storedValue)
            or tonumber(storedValue:match('^item:(%d+)'))
            or storedValue
    end
    return storedValue
end

CDM.PotionPrioKey = PotionPrioKey

function CDM.GetPotionPrioFor(storedValue)
    return PerSpecGet(BUI.GetDB().cdm, 'potionPrio')[PotionPrioKey(storedValue)]
end

function CDM.SetSharedPotionPrio(storedValue, priority)
    PerSpecSet(BUI.GetDB().cdm, 'potionPrio', PotionPrioKey(storedValue), priority)
end

function CDM.GetBuffTracking(config) return PerSpecGet(config, 'buffTracking') end
function CDM.SetBuffTracking(config, id, buffSpellID) PerSpecSet(config, 'buffTracking', id, buffSpellID) end

function CDM.GetManualBuffs(config)
    local perSpec = PerSpecGet(config, 'manualBuffs')
    local global = config.manualBuffsGlobal
    if not global or not next(global) then return perSpec end
    if perSpec == EMPTY or not next(perSpec) then return global end
    local merged = {}
    for id, data in pairs(global) do merged[id] = data end
    for id, data in pairs(perSpec) do merged[id] = data end
    return merged
end

function CDM.GetManualBuffScope(config, id)
    local global = config.manualBuffsGlobal
    if global and global[id] ~= nil then return global[id], 'global' end
    local perSpec = PerSpecGet(config, 'manualBuffs')
    if perSpec[id] ~= nil then return perSpec[id], 'spec' end
    return nil, nil
end

local function ClearSpecManualBuff(config, id)
    if not config.manualBuffs then return end
    for _, specBuffs in pairs(config.manualBuffs) do
        if type(specBuffs) == 'table' then specBuffs[id] = nil end
    end
end

function CDM.SetManualBuff(config, id, data, asGlobal)
    if data == nil then
        if config.manualBuffsGlobal then config.manualBuffsGlobal[id] = nil end
        ClearSpecManualBuff(config, id)
        BucketRemove(config.customSpellsGlobal, id)
        RemoveFromSpecLists(config, id)
        return
    end

    if asGlobal then
        config.manualBuffsGlobal = config.manualBuffsGlobal or {}
        config.manualBuffsGlobal[id] = data
        ClearSpecManualBuff(config, id)
        RemoveFromSpecLists(config, id)
        config.customSpellsGlobal = config.customSpellsGlobal or {}
        BucketAdd(config.customSpellsGlobal, id)
    else
        if config.manualBuffsGlobal then config.manualBuffsGlobal[id] = nil end
        local key = GetBuildKey()
        config.manualBuffs = config.manualBuffs or {}
        config.manualBuffs[key] = config.manualBuffs[key] or {}
        config.manualBuffs[key][id] = data
        BucketRemove(config.customSpellsGlobal, id)
        config.customSpells[key] = config.customSpells[key] or {}
        BucketAdd(config.customSpells[key], id)
    end
end

local function GetDetachedIcons(config) return PerSpecGet(config, 'detachedIcons') end

function CDM.IsIconDetached(config, id)
    return GetDetachedIcons(config)[id] ~= nil
end

function CDM.GetDetachedPosition(config, id)
    return GetDetachedIcons(config)[id]
end

function CDM.SetDetachedIcon(config, id, x, y, width, height)
    local key = GetBuildKey()
    config.detachedIcons[key] = config.detachedIcons[key] or {}
    config.detachedIcons[key][id] = { x = x, y = y, w = width, h = height }
end

function CDM.ClearDetachedIcon(config, id)
    local detached = config.detachedIcons[GetBuildKey()]
    if detached then detached[id] = nil end
end

function CDM.ClearAllDetachedIcons(config)
    config.detachedIcons[GetBuildKey()] = {}
end

function CDM.GetShowOnlyOnCD(config) return PerSpecGet(config, 'showOnlyOnCD') end

function CDM.IsShowOnlyOnCD(config, id)
    return PerSpecGet(config, 'showOnlyOnCD')[id] == true
end

function CDM.SetShowOnlyOnCD(config, id, enabled) PerSpecSet(config, 'showOnlyOnCD', id, enabled and true or nil) end

function CDM.GetAlwaysShow(config) return PerSpecGet(config, 'alwaysShow') end

function CDM.IsAlwaysShow(config, id)
    return PerSpecGet(config, 'alwaysShow')[id] == true
end

function CDM.SetAlwaysShow(config, id, enabled) PerSpecSet(config, 'alwaysShow', id, enabled and true or nil) end

function CDM.GetHideWhenZero(config) return PerSpecGet(config, 'hideWhenZero') end

function CDM.IsHideWhenZero(config, id)
    return PerSpecGet(config, 'hideWhenZero')[id] == true
end

function CDM.SetHideWhenZero(config, id, enabled) PerSpecSet(config, 'hideWhenZero', id, enabled and true or nil) end

function CDM.GetChoiceNodes(config) return PerSpecGet(config, 'choiceNodes') end
function CDM.SetChoiceNode(config, id, activeID) PerSpecSet(config, 'choiceNodes', id, activeID) end

function CDM.GetTrinketBlacklist(config)
    config.trinketBlacklist = config.trinketBlacklist or {}
    return config.trinketBlacklist
end
function CDM.IsTrinketBlacklisted(config, itemID)
    local blacklist = config.trinketBlacklist
    return blacklist and blacklist[itemID] == true
end
function CDM.SetTrinketBlacklisted(config, itemID, enabled)
    config.trinketBlacklist = config.trinketBlacklist or {}
    config.trinketBlacklist[itemID] = enabled and true or nil
end

function CDM.GetRacialBlacklist(config)
    config.racialBlacklist = config.racialBlacklist or {}
    return config.racialBlacklist
end
function CDM.IsRacialBlacklisted(config, spellID)
    local blacklist = config.racialBlacklist
    return blacklist and blacklist[spellID] == true
end
function CDM.SetRacialBlacklisted(config, spellID, enabled)
    config.racialBlacklist = config.racialBlacklist or {}
    config.racialBlacklist[spellID] = enabled and true or nil
end
