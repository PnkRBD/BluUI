local _, BUI = ...

local C_SpellBook = C_SpellBook
local C_Spell = C_Spell
local format = string.format

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

local overrideCache = { size = 0 }
local baseCache = { size = 0 }
local spellCacheVersion = 1
local MAX_SPELL_CACHE = 1024

local function CachedSpell(cache, spellID, resolve)
    local entry = cache[spellID]
    if entry then
        if entry[2] ~= spellCacheVersion then
            entry[1], entry[2] = resolve(spellID), spellCacheVersion
        end
        return entry[1]
    end
    if cache.size >= MAX_SPELL_CACHE then
        wipe(cache)
        cache.size = 0
    end
    local result = resolve(spellID)
    cache[spellID] = { result, spellCacheVersion }
    cache.size = cache.size + 1
    return result
end

local function ResolveOverrideSpell(spellID)
    local overrideID = C_Spell.GetOverrideSpell(spellID)
    if overrideID ~= 0 and overrideID ~= spellID then return overrideID end
    return spellID
end

local function ResolveBaseSpell(spellID)
    local baseID = C_Spell.GetBaseSpell(spellID)
    if baseID ~= 0 and baseID ~= spellID then return baseID end
    return spellID
end

function Tools.GetOverrideSpell(spellID)
    if not spellID then return spellID end
    return CachedSpell(overrideCache, spellID, ResolveOverrideSpell)
end

function Tools.GetBaseSpell(spellID)
    if not spellID then return spellID end
    return CachedSpell(baseCache, spellID, ResolveBaseSpell)
end

function Tools.InvalidateOverrideCache()
    spellCacheVersion = spellCacheVersion + 1
end

function Tools.EachSpellBookItem(callback, ...)
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if lineInfo then
            for slot = lineInfo.itemIndexOffset + 1, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
                if item and callback(item, ...) then return true end
            end
        end
    end
    local numPetSpells = C_SpellBook.HasPetSpells()
    if numPetSpells then
        for slot = 1, numPetSpells do
            local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Pet)
            if item and callback(item, ...) then return true end
        end
    end
    return false
end

local spellBookIconCache = {}
local spellBookCacheBuilt = false

local function CacheSpellBookIcon(spell)
    if spell.spellID then
        spellBookIconCache[spell.spellID] = spell.iconID
    end
end

local function BuildSpellBookIconCache()
    wipe(spellBookIconCache)
    Tools.EachSpellBookItem(CacheSpellBookIcon)
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
    return info and info.iconID
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

    local specID = PlayerUtil.GetCurrentSpecID()
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

local function StepCurve(x1, y1, x2, y2)
    local curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(x1, y1)
    curve:AddPoint(x2, y2)
    return curve
end

Tools.OnCooldownCurve = StepCurve(0, 0, 0.001, 1)
Tools.IsReadyCurve = StepCurve(0, 1, 0.001, 0)
Tools.GCDFilterCurve = StepCurve(0, 0, 1.6, 1)

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

local AGGRO_EDGES = {
    { 'TOPLEFT', 'TOPRIGHT', 'HORIZONTAL' },
    { 'BOTTOMLEFT', 'BOTTOMRIGHT', 'HORIZONTAL' },
    { 'TOPLEFT', 'BOTTOMLEFT', 'VERTICAL' },
    { 'TOPRIGHT', 'BOTTOMRIGHT', 'VERTICAL' },
}
local AGGRO_MIN_STATUS, AGGRO_TANKING_STATUS = 1, 2
local AggroOutline = {}

function AggroOutline:SetLook(red, green, blue, alpha, thickness)
    local size = BUI.Pixel.Scale(thickness)
    for _, edge in ipairs(self.edges) do
        edge:SetStatusBarColor(red, green, blue, alpha)
        if edge:GetOrientation() == 'VERTICAL' then edge:SetWidth(size) else edge:SetHeight(size) end
    end
end

function AggroOutline:TrackThreat(unit)
    local status = UnitThreatSituation(unit)
    if not issecretvalue(status) and status == nil then status = 0 end
    for _, edge in ipairs(self.edges) do edge:SetValue(status) end
end

function AggroOutline:Empty()
    for _, edge in ipairs(self.edges) do edge:SetValue(0) end
end

function Tools.AggroOutline(parent, levelOffset)
    local outline = CreateFrame('Frame', nil, parent)
    outline:SetAllPoints()
    outline:SetFrameLevel(parent:GetFrameLevel() + levelOffset)
    outline.edges = {}
    for index, spec in ipairs(AGGRO_EDGES) do
        local edge = CreateFrame('StatusBar', nil, outline)
        edge:SetPoint(spec[1])
        edge:SetPoint(spec[2])
        edge:SetOrientation(spec[3])
        edge:SetStatusBarTexture('Interface\\Buttons\\WHITE8x8')
        edge:SetMinMaxValues(AGGRO_MIN_STATUS, AGGRO_TANKING_STATUS)
        edge:SetValue(0)
        outline.edges[index] = edge
    end
    return Mixin(outline, AggroOutline)
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
    local isCharge = maxCharges > 1
    chargeSpellCache[spellID] = isCharge
    return isCharge
end

function Tools.GetAuraStacks(unit, spellID)
    if unit ~= 'player' then return nil end
    if Tools.ShouldAurasBeSecret() and C_Secrets.GetSpellAuraSecrecy(spellID) ~= Enum.SecrecyLevel.NeverSecret then return nil end
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

function Tools.IsSecretValue(value)
    if value == nil then return false end
    return issecretvalue(value)
end

function Tools.SafeNum(value)
    if type(value) ~= "number" or issecretvalue(value) then return nil end
    return value
end

function Tools.SafeBool(value)
    if issecretvalue(value) then return nil end
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

local Profiler = BUI.Profiler
local wakeSubscribers = {}
local wakeLabels = {}
local wakeCursor = 0
local wakeDriver = CreateFrame('Frame')
wakeDriver:Hide()

function Tools.OnAuraQueriesUnblocked(callback, label)
    wakeSubscribers[#wakeSubscribers + 1] = callback
    wakeLabels[#wakeLabels + 1] = label
end

wakeDriver:SetScript('OnUpdate', BUI.Profiler.Timed('Utility.Tools wakeDriver OnUpdate', function(self)
    wakeCursor = wakeCursor + 1
    local callback = wakeSubscribers[wakeCursor]
    if not callback or Tools.ShouldAurasBeSecret() or Tools.AuraQueriesBlocked() then
        self:Hide()
        return
    end
    Profiler.Run(Profiler.Label('Aura wake', wakeLabels[wakeCursor]), xpcall, callback, geterrorhandler())
end))

local function RunWakeNow()
    if Tools.ShouldAurasBeSecret() or Tools.AuraQueriesBlocked() then return end
    wakeCursor = 0
    wakeDriver:Show()
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

function Tools.IsInTown()
    return IsResting() and not IsInInstance()
end

function Tools.ChallengeMapForActivity(activityName)
    for _, mapID in ipairs(C_ChallengeMode.GetMapTable()) do
        local name, _, _, texture, background = C_ChallengeMode.GetMapUIInfo(mapID)
        if name and activityName:find(name, 1, true) then return name, texture, mapID, background end
    end
end

function Tools.LowestDurability()
    local lowest = 100
    for slotIndex = 1, 18 do
        local current, maximum = GetInventoryItemDurability(slotIndex)
        if current and maximum and maximum > 0 then
            local percent = current / maximum * 100
            if percent < lowest then lowest = percent end
        end
    end
    return math.floor(lowest)
end

function Tools.IsChatHeaderSecret(editBox)
    return editBox.header:IsAnchoringSecret()
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

function Tools.DeepCopy(original)
    if type(original) ~= 'table' then return original end
    return CopyTable(original)
end

function Tools.ReplaceTimer(holder, key, label, delay, callback, arg)
    local timer = holder[key]
    if timer then timer:Cancel() end
    holder[key] = BUI.Profiler.NewTimer(label, delay, function()
        holder[key] = nil
        callback(arg)
    end)
end

function Tools.AddPageWatermark(frame)
    local mark = frame:CreateTexture(nil, 'BACKGROUND', nil, 1)
    mark:SetTexture(BUI.C.ICON_PATH)
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
    for _, candidate in ipairs({ cooldown:GetRegions() }) do
        if candidate:GetObjectType() == 'FontString' then
            region = candidate
            cooldown._buiCountdown = region
            return region
        end
    end
    return nil
end

local truncateFormats = {}

function Tools.TruncateName(name, limit)
    local pattern = truncateFormats[limit]
    if not pattern then
        pattern = '%.' .. limit .. 's'
        truncateFormats[limit] = pattern
    end
    return format(pattern, name)
end
