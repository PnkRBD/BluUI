local _, BUI = ...
local Pixel = BUI.Pixel
local IsSecretValue = BUI.Tools.IsSecretValue

local SecondaryStats = {}
BUI.Auras.SecondaryStats = SecondaryStats

local FRAME_NAME = 'BUI_SecondaryStats'
local EVENT_KEY = 'SecondaryStats'
local FIRST_SPELL_SCHOOL = 2
local PAINT_DELAY = 0.1
local LINE_GAP = 2
local PAD = 6
local SAMPLE_VALUE = '888,888'
local SAMPLE_RATING = 88888
local SAMPLE_PERCENT = 88.88

local EDGES = {
    LEFT = { 'TOPLEFT', 1 },
    CENTER = { 'TOP', 0 },
    RIGHT = { 'TOPRIGHT', -1 },
}

local FORMATS = {
    value = '%s: %%s',
    both = '%s: %%d (%%.2f%%%%)',
    percent = '%s: %%.2f%%%%',
    rating = '%s: %%d',
}

local STAMINA = 3
local PRIMARY_NAMES = { [1] = 'Strength', [2] = 'Agility', [4] = 'Intellect' }

local UPDATE_EVENTS = {
    'COMBAT_RATING_UPDATE', 'MASTERY_UPDATE', 'PLAYER_DAMAGE_DONE_MODS',
    'LIFESTEAL_UPDATE', 'AVOIDANCE_UPDATE', 'SPEED_UPDATE', 'ADDON_RESTRICTION_STATE_CHANGED',
}

local PLAYER_EVENTS = {
    'UNIT_SPELL_HASTE', 'UNIT_ATTACK_SPEED', 'UNIT_STATS', 'UNIT_AURA',
}

local critRating, critSchool = CR_CRIT_MELEE, nil
local primaryStat

local function PickCrit()
    local melee = GetCritChance()
    if IsSecretValue(melee) then return end
    local school, spell = FIRST_SPELL_SCHOOL, GetSpellCritChance(FIRST_SPELL_SCHOOL)
    for index = FIRST_SPELL_SCHOOL + 1, MAX_SPELL_SCHOOLS do
        local chance = GetSpellCritChance(index)
        if chance < spell then school, spell = index, chance end
    end
    local ranged = GetRangedCritChance()
    if spell >= ranged and spell >= melee then
        critRating, critSchool = CR_CRIT_SPELL, school
    elseif ranged >= melee then
        critRating, critSchool = CR_CRIT_RANGED, nil
    else
        critRating, critSchool = CR_CRIT_MELEE, nil
    end
end

local function CritPercent()
    if critSchool then return GetSpellCritChance(critSchool) end
    if critRating == CR_CRIT_RANGED then return GetRangedCritChance() end
    return GetCritChance()
end

local function VersPercent()
    local bonus = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
    if IsSecretValue(bonus) then return bonus end
    return bonus + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
end

local function UnitStatValue(index)
    local _, value = UnitStat('player', index)
    return BreakUpLargeNumbers(value)
end

local STATS = {
    primary = { value = function() return UnitStatValue(primaryStat) end },
    stamina = { label = 'Stamina', value = function() return UnitStatValue(STAMINA) end },
    crit = { label = 'Crit', read = function() return GetCombatRating(critRating), CritPercent() end },
    haste = { label = 'Haste', read = function() return GetCombatRating(CR_HASTE_MELEE), GetHaste() end },
    mastery = { label = 'Mastery', read = function() return GetCombatRating(CR_MASTERY), (GetMasteryEffect()) end },
    vers = { label = 'Vers', read = function() return GetCombatRating(CR_VERSATILITY_DAMAGE_DONE), VersPercent() end },
    leech = { label = 'Leech', read = function() return GetCombatRating(CR_LIFESTEAL), GetLifesteal() end },
    avoidance = { label = 'Avoidance', read = function() return GetCombatRating(CR_AVOIDANCE), GetAvoidance() end },
    speed = { label = 'Speed', read = function() return GetCombatRating(CR_SPEED), GetSpeed() end },
}

local DEFAULT_ORDER = { 'primary', 'crit', 'haste', 'mastery', 'vers', 'stamina', 'leech', 'avoidance', 'speed' }

local holder, measure, lines, lockListener
local shown, critShown = 0, false
local enabled, inCombat = false, false

local function GetDB() return BUI.GetDB().secondaryStats end

function SecondaryStats.Order()
    local order, seen = {}, {}
    for _, id in ipairs(GetDB().order) do
        if STATS[id] and not seen[id] then
            seen[id] = true
            order[#order + 1] = id
        end
    end
    for _, id in ipairs(DEFAULT_ORDER) do
        if not seen[id] then order[#order + 1] = id end
    end
    return order
end

local function Show(text, format, mode, first, second)
    if mode == 'both' then
        text:SetFormattedText(format, first, second)
    elseif mode == 'percent' then
        text:SetFormattedText(format, second)
    else
        text:SetFormattedText(format, first)
    end
end

local function Paint()
    if not holder:IsShown() then return end
    if critShown then PickCrit() end
    for index = 1, shown do
        local line = lines[index]
        local stat = line.stat
        if stat.value then
            Show(line, line.format, 'value', stat.value())
        else
            Show(line, line.format, line.mode, stat.read())
        end
    end
end

local Update = BUI.Dispatcher.NewDelayed(Paint, PAINT_DELAY, 'Auras.SecondaryStats')

local function Build()
    if holder then return end
    holder = CreateFrame('Frame', FRAME_NAME, UIParent)
    holder:SetFrameStrata('HIGH')
    holder:Hide()
    measure = holder:CreateFontString(nil, 'OVERLAY')
    measure:Hide()
    lines = {}
    for index = 1, #DEFAULT_ORDER do
        lines[index] = holder:CreateFontString(nil, 'OVERLAY')
    end
    BUI.Dragging.MakeAnchoredAlert(holder, {
        settings = GetDB,
        isLocked = function() return GetDB().locked end,
        onRightClick = function() SecondaryStats.SetLocked(true) end,
    })
end

local function ReadPrimary()
    local spec = GetSpecialization()
    primaryStat = spec and select(6, GetSpecializationInfo(spec))
end

local function Listed(id)
    return GetDB().stats[id].shown and (id ~= 'primary' or primaryStat ~= nil)
end

local function Style()
    local db = GetDB()
    local font = BUI.GetModuleFont(db)
    ReadPrimary()
    Pixel.ApplyFont(measure, db.fontSize, font)
    shown, critShown = 0, Listed('crit')
    local width = 0
    for _, id in ipairs(SecondaryStats.Order()) do
        if Listed(id) then
            shown = shown + 1
            local stat, line = STATS[id], lines[shown]
            line.stat = stat
            line.mode = stat.value and 'value' or db.display
            line.format = FORMATS[line.mode]:format(stat.label or PRIMARY_NAMES[primaryStat])
            Pixel.ApplyFont(line, db.fontSize, font)
            line:SetJustifyH(db.align)
            line:SetTextColor(unpack(db.stats[id].color))
            Show(measure, line.format, line.mode, stat.value and SAMPLE_VALUE or SAMPLE_RATING, SAMPLE_PERCENT)
            width = math.max(width, measure:GetStringWidth())
        end
    end
    local step = measure:GetStringHeight() + LINE_GAP
    local point, inset = EDGES[db.align][1], EDGES[db.align][2] * PAD
    for index, line in ipairs(lines) do
        line:SetShown(index <= shown)
        line:ClearAllPoints()
        line:SetPoint(point, holder, point, inset, -PAD - (index - 1) * step)
    end
    holder:SnapSize(math.max(width, 1) + PAD * 2, math.max(step * shown - LINE_GAP, 1) + PAD * 2)
    BUI.Anchor.ApplyPosition(holder, db)
end

local function Sync()
    local db = GetDB()
    holder:SetShown(enabled and shown > 0 and (not db.locked or not db.combatOnly or inCombat))
    Paint()
end

local function Restyle()
    Style()
    Sync()
end

local function OnCombat(event)
    inCombat = event == 'PLAYER_REGEN_DISABLED'
    Sync()
end

local function Wire()
    for _, event in ipairs(UPDATE_EVENTS) do
        BUI.Events:Register(event, EVENT_KEY, Update)
    end
    for _, event in ipairs(PLAYER_EVENTS) do
        BUI.Events:RegisterUnit(event, 'player', EVENT_KEY, Update)
    end
    BUI.Events:RegisterUnit('PLAYER_SPECIALIZATION_CHANGED', 'player', EVENT_KEY, Restyle)
    BUI.Events:Register('PLAYER_ENTERING_WORLD', EVENT_KEY, Restyle)
    BUI.Events:Register('PLAYER_REGEN_DISABLED', EVENT_KEY, OnCombat)
    BUI.Events:Register('PLAYER_REGEN_ENABLED', EVENT_KEY, OnCombat)
end

function SecondaryStats.Enable()
    Build()
    if not enabled then
        enabled = true
        inCombat = InCombatLockdown()
        Wire()
    end
    BUI.Dragging.SetLocked(holder, GetDB().locked)
    Restyle()
end

function SecondaryStats.Disable()
    enabled = false
    BUI.Events:UnregisterAll(EVENT_KEY)
    if holder then holder:Hide() end
end

function SecondaryStats.SetLockListener(callback)
    lockListener = callback
end

function SecondaryStats.SetLocked(locked)
    local db = GetDB()
    db.locked = locked
    if lockListener then lockListener() end
    if db.enabled then SecondaryStats.Enable() end
end

function SecondaryStats.Refresh()
    if GetDB().enabled then SecondaryStats.Enable() else SecondaryStats.Disable() end
end

BUI.Anchor.Follow('Auras.SecondaryStats', function() return enabled and holder end, GetDB)

BUI.Events:OnLogin(EVENT_KEY, function()
    if GetDB().enabled then SecondaryStats.Enable() end
end, 'auras')
