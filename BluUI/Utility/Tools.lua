local _, BUI = ...

local C_SpellBook = C_SpellBook
local C_Spell = C_Spell

local Tools = {}
BUI.Tools = Tools

function Tools.IsSpellUsable(spellID)
    if not spellID then return false end
    return C_SpellBook.IsSpellKnown(spellID)
end

local EMPOWER_RACE_TOKENS = { EarthenDwarf = true }
function Tools.PlayerCanEmpower()
    if select(2, UnitClass('player')) == 'EVOKER' then return true end
    return EMPOWER_RACE_TOKENS[select(2, UnitRace('player'))]
end

function Tools.IsGroupInCombat()
    if IsInRaid() then
        for memberIndex = 1, GetNumGroupMembers() do
            local unit = "raid" .. memberIndex
            if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitAffectingCombat(unit) then
                return true
            end
        end
        return false
    end
    if IsInGroup() then
        for memberIndex = 1, GetNumSubgroupMembers() do
            local unit = "party" .. memberIndex
            if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitAffectingCombat(unit) then
                return true
            end
        end
    end
    return false
end

local overrideCache = {}
local overrideCacheSize = 0
local overrideCacheVersion = 1
local MAX_OVERRIDE_CACHE = 1024

function Tools.GetOverrideSpell(spellID)
    if not spellID then return spellID end
    local entry = overrideCache[spellID]
    if entry then
        if entry[2] == overrideCacheVersion then return entry[1] end
    end
    local overrideID = C_Spell.GetOverrideSpell(spellID)
    local result
    if overrideID and overrideID ~= 0 and overrideID ~= spellID then
        result = overrideID
    else
        result = spellID
    end
    if entry then
        entry[1] = result; entry[2] = overrideCacheVersion
    else
        if overrideCacheSize >= MAX_OVERRIDE_CACHE then
            wipe(overrideCache)
            overrideCacheSize = 0
        end
        overrideCache[spellID] = { result, overrideCacheVersion }
        overrideCacheSize = overrideCacheSize + 1
    end
    return result
end

function Tools.InvalidateOverrideCache()
    overrideCacheVersion = overrideCacheVersion + 1
end

local spellBookIconCache = {}
local spellBookCacheBuilt = false

local function BuildSpellBookIconCache()
    wipe(spellBookIconCache)
    local banks = Enum.SpellBookSpellBank
    local bankList = { banks.Player }
    if banks.Pet ~= nil then bankList[#bankList + 1] = banks.Pet end
    for _, bank in ipairs(bankList) do
        local numLines = C_SpellBook.GetNumSpellBookSkillLines(bank) or 0
        for line = 1, numLines do
            local tabInfo = C_SpellBook.GetSpellBookSkillLineInfo(line, bank)
            if tabInfo and tabInfo.numSpellBookItems and tabInfo.itemIndexOffset then
                for itemIndex = 1, tabInfo.numSpellBookItems do
                    local slot = tabInfo.itemIndexOffset + itemIndex
                    local spell = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                    if spell and spell.spellID and spell.iconID then
                        spellBookIconCache[spell.spellID] = spell.iconID
                    end
                end
            end
        end
    end
end

function Tools.InvalidateSpellBookIconCache()
    spellBookCacheBuilt = false
    wipe(spellBookIconCache)
end

function Tools.GetStableSpellTexture(spellID)
    if not spellID then return nil end
    if not spellBookCacheBuilt then
        BuildSpellBookIconCache()
        spellBookCacheBuilt = true
    end
    local booked = spellBookIconCache[spellID]
    if booked then return booked end
    local info = C_Spell.GetSpellInfo(spellID)
    return (info and info.iconID) or C_Spell.GetSpellTexture(spellID)
end

local choiceCache = {}
local choiceCacheConfigID = nil
local choiceCacheBuilt = false
local choiceCacheInvalidationHooked = false

local function InvalidateChoiceCache()
    wipe(choiceCache)
    choiceCacheBuilt = false
end

local function BuildChoiceCache(configID)
    choiceCacheBuilt = true
    if not choiceCacheInvalidationHooked then
        choiceCacheInvalidationHooked = true
        BUI.Events:OnTalentBurst('Tools.ChoiceCache', InvalidateChoiceCache)
    end

    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    if not specID then return end
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    if not treeID then return end
    local nodeIDs = C_Traits.GetTreeNodes(treeID)
    if not nodeIDs then return end

    for _, nodeID in ipairs(nodeIDs) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo and nodeInfo.type == Enum.TraitNodeType.Selection and nodeInfo.entryIDs then
            local results = {}
            local lookupSpellIDs = {}
            for _, entryID in ipairs(nodeInfo.entryIDs) do
                local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                if entryInfo and entryInfo.definitionID then
                    local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                    if definitionInfo and definitionInfo.spellID then
                        local isActive = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID == entryID
                        results[#results + 1] = {
                            spellID = definitionInfo.spellID,
                            entryID = entryID,
                            active = isActive and true or false,
                        }
                        lookupSpellIDs[#lookupSpellIDs + 1] = definitionInfo.spellID
                        if definitionInfo.overriddenSpellID then
                            lookupSpellIDs[#lookupSpellIDs + 1] = definitionInfo.overriddenSpellID
                        end
                    end
                end
            end
            if #results > 0 then
                for _, lookupSpellID in ipairs(lookupSpellIDs) do
                    choiceCache[lookupSpellID] = results
                end
            end
        end
    end
end

function Tools.GetChoiceAlternatives(spellID)
    if not spellID then return nil end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return nil end
    if choiceCacheConfigID ~= configID then
        InvalidateChoiceCache()
        choiceCacheConfigID = configID
    end
    if not choiceCacheBuilt then
        BuildChoiceCache(configID)
    end
    return choiceCache[spellID]
end

function Tools.GetActiveChoice(spellID)
    if not spellID then return spellID end
    local alternatives = Tools.GetChoiceAlternatives(spellID)
    if not alternatives then return spellID end
    for _, alternative in ipairs(alternatives) do
        if alternative.active then return alternative.spellID end
    end
    return spellID
end

local function TwoPointStep(x1, y1, x2, y2)
    local curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(x1, y1)
    curve:AddPoint(x2, y2)
    return curve
end

Tools.OnCooldownCurve = TwoPointStep(0, 0, 0.001, 1)
Tools.IsReadyCurve = TwoPointStep(0, 1, 0.001, 0)
Tools.GCDFilterCurve = TwoPointStep(0, 0, 1.6, 1)

local alphaCurves = {}

function Tools.ThresholdAlphaCurve(threshold)
    local curve = alphaCurves[threshold]
    if curve then return curve end
    curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, CreateColor(1, 1, 1, 1))
    curve:AddPoint(threshold / 100, CreateColor(1, 1, 1, 0))
    alphaCurves[threshold] = curve
    return curve
end

function Tools.IsSpellOnCooldown(spellID)
    if Tools.IsChargeSpell(spellID) then
        local chargeInfo = C_Spell.GetSpellCharges(spellID)
        if not chargeInfo then return nil end
        local recharging = chargeInfo.isActive
        if Tools.IsSecretValue(recharging) then return nil end
        if not recharging then return false end
    end
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    if not cooldownInfo then return nil end
    if Tools.IsSecretValue(cooldownInfo.isActive) or Tools.IsSecretValue(cooldownInfo.isOnGCD) then return nil end
    return cooldownInfo.isActive and not cooldownInfo.isOnGCD
end

local chargeSpellCache = {}
local chargeSpellCacheInvalidationHooked = false

function Tools.InvalidateChargeSpellCache()
    wipe(chargeSpellCache)
end

function Tools.IsChargeSpell(spellID)
    local cached = chargeSpellCache[spellID]
    if cached ~= nil then return cached end
    if not chargeSpellCacheInvalidationHooked then
        chargeSpellCacheInvalidationHooked = true
        BUI.Events:Register('SPELLS_CHANGED', 'Tools.ChargeSpellCache', Tools.InvalidateChargeSpellCache)
    end
    local info = C_Spell.GetSpellCharges(spellID)
    if not info then
        chargeSpellCache[spellID] = false
        return false
    end
    local maxCharges = info.maxCharges
    if Tools.IsSecretValue(maxCharges) then
        return false
    end
    local isCharge = (maxCharges or 0) > 1
    chargeSpellCache[spellID] = isCharge
    return isCharge
end

function Tools.CallAuraDuration(unit, instanceID)
    if not instanceID then return nil end
    return C_UnitAuras.GetAuraDuration(unit or 'player', instanceID)
end

function Tools.GetAuraDurationObject(instanceID)
    if not instanceID then return nil end
    if Tools.IsSecretValue(instanceID) then return nil end
    if Tools.ShouldAurasBeSecret() or Tools.AuraQueriesBlocked() then return nil end
    local data = C_UnitAuras.GetAuraDataByAuraInstanceID('player', instanceID)
    if not data then return nil end
    return Tools.CallAuraDuration('player', instanceID)
end

function Tools.GetAuraStacks(unit, spellID)
    if unit ~= 'player' then return nil end
    if Tools.ShouldAurasBeSecret() then return nil end
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    if not aura then return 0 end
    local stackCount = Tools.SafeNum(aura.applications)
    if stackCount and stackCount > 0 then return stackCount end
    return 1
end

function Tools.GetAuraStacksText(unit, instanceID, minShown)
    if not instanceID then return nil end
    return C_UnitAuras.GetAuraApplicationDisplayCount(unit, instanceID, minShown or 1, 1000)
end

function Tools.CountText(count)
    if count == nil then return nil end
    return C_StringUtil.TruncateWhenZero(count)
end

if C_Secrets and C_Secrets.HasSecretRestrictions() then
    function Tools.IsSecretValue(value)
        if value == nil then return false end
        return issecretvalue(value)
    end

    function Tools.SafeNum(value)
        if type(value) ~= "number" or issecretvalue(value) then return nil end
        return value
    end

    function Tools.ShouldAurasBeSecret()
        return C_Secrets.ShouldAurasBeSecret()
    end

    local auraProbeTime, auraProbeBlocked = -1, false
    function Tools.AuraQueriesBlocked()
        local now = GetTime()
        if now ~= auraProbeTime then
            auraProbeTime = now
            auraProbeBlocked = not pcall(C_UnitAuras.GetAuraDataByIndex, 'player', 1, 'HELPFUL')
        end
        return auraProbeBlocked
    end

    local WAKE_EDGES = {
        'PLAYER_REGEN_ENABLED', 'PLAYER_ENTERING_WORLD',
        'ZONE_CHANGED_NEW_AREA', 'CVAR_UPDATE',
    }

    local wakeSubscribers = {}

    function Tools.OnAuraQueriesUnblocked(callback)
        if type(callback) ~= 'function' then return end
        wakeSubscribers[#wakeSubscribers + 1] = callback
    end

    local function RunWakeNow()
        if Tools.ShouldAurasBeSecret() or Tools.AuraQueriesBlocked() then return end
        for subscriberIndex = 1, #wakeSubscribers do
            xpcall(wakeSubscribers[subscriberIndex], geterrorhandler())
        end
    end

    local function RunWakeSubscribers(event, cvarName)
        if #wakeSubscribers == 0 then return end
        if event == 'CVAR_UPDATE' then
            if type(cvarName) ~= 'string' then return end
            if not cvarName:find('RestrictionsForced', 1, true) then return end
        end
        if event == 'PLAYER_REGEN_ENABLED' then
            BUI.Events:AfterCombatSettled(RunWakeNow, 'Tools.AuraWake')
            return
        end
        RunWakeNow()
    end

    for edgeIndex = 1, #WAKE_EDGES do
        BUI.Events:Register(WAKE_EDGES[edgeIndex], 'Tools.AuraWake', RunWakeSubscribers)
    end
else
    local function Never() return false end
    Tools.IsSecretValue          = Never
    Tools.ShouldAurasBeSecret    = Never
    Tools.AuraQueriesBlocked     = Never
    function Tools.OnAuraQueriesUnblocked() end

    function Tools.SafeNum(value)
        if type(value) ~= "number" then return nil end
        return value
    end
end

function Tools.GetUnitClassColor(unit)
    if not unit or not UnitExists(unit) then return nil end
    local _, class = UnitClass(unit)
    if Tools.IsSecretValue(class) then return nil end
    local classColor = class and RAID_CLASS_COLORS[class]
    if not classColor then return nil end
    return classColor.r, classColor.g, classColor.b
end

function Tools.SafeUnitClass(unit)
    if not unit then return nil, nil end
    local className, classToken = UnitClass(unit)
    if Tools.IsSecretValue(classToken) then return nil, nil end
    if Tools.IsSecretValue(className) then return nil, classToken end
    return className, classToken
end

do
    local function numOrDefault(value, fallback) return type(value) == 'number' and value or fallback end
    function Tools.SetColorTex(texture, red, green, blue, alpha)
        texture:SetColorTexture(numOrDefault(red, 0), numOrDefault(green, 0), numOrDefault(blue, 0), numOrDefault(alpha, 1))
    end
end

local function DeepCopy(original)
    if type(original) ~= 'table' then return original end
    local copy = {}
    for key, value in pairs(original) do copy[key] = DeepCopy(value) end
    return copy
end
Tools.DeepCopy = DeepCopy

function Tools.GetLogo()
    return BUI.C.ICON_PATH
end

function Tools.AddPageWatermark(frame)
    local mark = frame:CreateTexture(nil, 'BACKGROUND', nil, 1)
    mark:SetTexture(Tools.GetLogo())
    mark:SetSize(BUI.Pixel.Scale(520), BUI.Pixel.Scale(520))
    mark:SetPoint('CENTER')
    mark:SetVertexColor(1, 1, 1, 0.06)
    return mark
end

local OUTSIDE_PLACEMENTS = {
    OUTSIDE_TOPLEFT     = { 'BOTTOMLEFT',  'TOPLEFT',      0,  1, 'LEFT'   },
    OUTSIDE_TOP         = { 'BOTTOM',      'TOP',          0,  1, 'CENTER' },
    OUTSIDE_TOPRIGHT    = { 'BOTTOMRIGHT', 'TOPRIGHT',     0,  1, 'RIGHT'  },
    OUTSIDE_LEFT        = { 'RIGHT',       'LEFT',        -1,  0, 'RIGHT'  },
    OUTSIDE_RIGHT       = { 'LEFT',        'RIGHT',        1,  0, 'LEFT'   },
    OUTSIDE_BOTTOMLEFT  = { 'TOPLEFT',     'BOTTOMLEFT',   0, -1, 'LEFT'   },
    OUTSIDE_BOTTOM      = { 'TOP',         'BOTTOM',       0, -1, 'CENTER' },
    OUTSIDE_BOTTOMRIGHT = { 'TOPRIGHT',    'BOTTOMRIGHT',  0, -1, 'RIGHT'  },
}

local INSIDE_PLACEMENTS = {
    TOPLEFT     = {  1, -1, 'LEFT'   },
    TOP         = {  0, -1, 'CENTER' },
    TOPRIGHT    = { -1, -1, 'RIGHT'  },
    LEFT        = {  1,  0, 'LEFT'   },
    CENTER      = {  0,  0, 'CENTER' },
    RIGHT       = { -1,  0, 'RIGHT'  },
    BOTTOMLEFT  = {  1,  1, 'LEFT'   },
    BOTTOM      = {  0,  1, 'CENTER' },
    BOTTOMRIGHT = { -1,  1, 'RIGHT'  },
}

function Tools.ResolvePlacement(placement, marginX, marginY)
    marginX = marginX or 0
    marginY = marginY or 0

    local outside = OUTSIDE_PLACEMENTS[placement]
    if outside then
        return outside[1], outside[2], outside[3] * marginX, outside[4] * marginY, outside[5]
    end

    local point = INSIDE_PLACEMENTS[placement] and placement or 'CENTER'
    local inside = INSIDE_PLACEMENTS[point]
    return point, point, inside[1] * marginX, inside[2] * marginY, inside[3]
end


function Tools.PoolGet(pool, index, factory, parent)
    if not pool[index] then pool[index] = factory(parent) end
    return pool[index]
end

function Tools.PoolHideFrom(pool, startIndex)
    for poolIndex = startIndex, #pool do pool[poolIndex]:Hide() end
end

function Tools.CooldownFontString(cooldown)
    local region = cooldown._buiCountdown
    if region then return region end
    for index = 1, select('#', cooldown:GetRegions()) do
        region = select(index, cooldown:GetRegions())
        if region:GetObjectType() == 'FontString' then
            cooldown._buiCountdown = region
            return region
        end
    end
    return nil
end
