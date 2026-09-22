local _, BUI = ...

local TrueStats = {}
BUI.TrueStats = TrueStats

local IsSecretValue = BUI.Tools.IsSecretValue
local floor = math.floor
local ipairs, pairs, type = ipairs, pairs, type

local PRECISION = 100

local SECONDARY_CURVE = {
    { raw = 0,   gain = 0 },
    { raw = 30,  gain = 30 },
    { raw = 40,  gain = 39 },
    { raw = 50,  gain = 47 },
    { raw = 60,  gain = 54 },
    { raw = 80,  gain = 66 },
    { raw = 200, gain = 126 },
}

local TERTIARY_CURVE = {
    { raw = 0,   gain = 0 },
    { raw = 10,  gain = 10 },
    { raw = 15,  gain = 14 },
    { raw = 20,  gain = 17 },
    { raw = 25,  gain = 19 },
    { raw = 100, gain = 49 },
}

local CURVES = {
    [CR_CRIT_MELEE]              = SECONDARY_CURVE,
    [CR_HASTE_MELEE]             = SECONDARY_CURVE,
    [CR_MASTERY]                 = SECONDARY_CURVE,
    [CR_VERSATILITY_DAMAGE_DONE] = SECONDARY_CURVE,
    [CR_LIFESTEAL]               = TERTIARY_CURVE,
    [CR_AVOIDANCE]               = TERTIARY_CURVE,
    [CR_SPEED]                   = TERTIARY_CURVE,
}

local DAMAGE_RATINGS = {
    [CR_CRIT_MELEE]              = 'Critical Strike',
    [CR_HASTE_MELEE]             = 'Haste',
    [CR_VERSATILITY_DAMAGE_DONE] = 'Versatility',
}

local SHARPNESS = {
    { upTo = 0,    red = 0.42, green = 0.89, blue = 0.46 },
    { upTo = 0.2,  red = 0.82, green = 0.90, blue = 0.40 },
    { upTo = 0.4,  red = 1.00, green = 0.76, blue = 0.31 },
    { upTo = 0.6,  red = 1.00, green = 0.52, blue = 0.29 },
    { upTo = 1.01, red = 1.00, green = 0.35, blue = 0.38 },
}

local readings = {}
local stale = true

for ratingID in pairs(CURVES) do readings[ratingID] = { usable = false } end

local function Round(value)
    return floor(value * PRECISION + 0.5) / PRECISION
end

local function Slope(from, to)
    return (to.gain - from.gain) / (to.raw - from.raw)
end

local function GainAt(curve, raw)
    for index = 2, #curve do
        local from, to = curve[index - 1], curve[index]
        if raw <= to.raw then
            return from.gain + (raw - from.raw) * Slope(from, to)
        end
    end
    return curve[#curve].gain
end

local function RawAt(curve, gain)
    for index = 2, #curve do
        local from, to = curve[index - 1], curve[index]
        if gain <= to.gain then
            return from.raw + (gain - from.gain) / Slope(from, to)
        end
    end
    return nil
end

local function SegmentAt(curve, raw)
    for index = 2, #curve do
        local from, to = curve[index - 1], curve[index]
        if raw <= to.raw then
            local ahead = curve[index + 1]
            return 1 - Slope(from, to), ahead and 1 - Slope(to, ahead) or 1, to.raw - raw
        end
    end
    return 1, 1, 0
end

function TrueStats.PenaltyColor(penalty)
    for _, step in ipairs(SHARPNESS) do
        if penalty <= step.upTo then return step.red, step.green, step.blue end
    end
    local last = SHARPNESS[#SHARPNESS]
    return last.red, last.green, last.blue
end

local function Read(ratingID, curve, reading)
    local rating = GetCombatRating(ratingID)
    local gain = GetCombatRatingBonus(ratingID)
    if type(rating) ~= 'number' or type(gain) ~= 'number' then return end
    if IsSecretValue(rating) or IsSecretValue(gain) then return end
    if rating <= 0 or gain <= 0 then return end

    local raw = RawAt(curve, gain)
    if not raw or raw <= 0 then return end

    local perPercent = rating / raw
    local penalty, nextPenalty, rawToNext = SegmentAt(curve, raw)

    reading.rating = rating
    reading.gain = gain
    reading.raw = Round(raw)
    reading.perPercent = perPercent
    reading.effective = Round(gain * perPercent)
    reading.wasted = Round(rating - gain * perPercent)
    reading.penalty = penalty
    reading.nextPenalty = nextPenalty
    reading.toNext = Round(rawToNext * perPercent)
    reading.usable = true
end

local function StatsAreSecret()
    return C_Secrets and C_Secrets.ShouldUnitStatsBeSecret and C_Secrets.ShouldUnitStatsBeSecret('player')
end

local function Settle()
    if not stale then return end
    stale = false
    local secret = StatsAreSecret()
    for ratingID, curve in pairs(CURVES) do
        local reading = readings[ratingID]
        reading.usable = false
        if not secret then Read(ratingID, curve, reading) end
    end
end

function TrueStats.Refresh()
    stale = true
end

function TrueStats.Get(ratingID)
    Settle()
    local reading = readings[ratingID]
    if reading and reading.usable then return reading end
    return nil
end

function TrueStats.IsDamageRating(ratingID)
    return DAMAGE_RATINGS[ratingID] ~= nil
end

local function Cheaper(best, cost)
    if not cost or cost <= 0 then return best end
    if not best or cost < best then return cost end
    return best
end

local function Append(line, label, cost, best)
    if not cost or cost <= 0 then return line end
    local part = label .. ' ' .. floor(cost + 0.5)
    if cost == best then part = '|cff6be375' .. part .. '|r' end
    if not line then return part end
    return line .. '   ' .. part
end

function TrueStats.DamageCosts()
    local crit = TrueStats.CostOfNext(CR_CRIT_MELEE, 1)
    local haste = TrueStats.CostOfNext(CR_HASTE_MELEE, 1)
    local vers = TrueStats.CostOfNext(CR_VERSATILITY_DAMAGE_DONE, 1)
    local best = Cheaper(Cheaper(Cheaper(nil, crit), haste), vers)
    if not best then return nil end
    local line = Append(nil, 'Crit', crit, best)
    line = Append(line, 'Haste', haste, best)
    line = Append(line, 'Vers', vers, best)
    return line
end

function TrueStats.GainFrom(ratingID, amount)
    local reading = TrueStats.Get(ratingID)
    local curve = CURVES[ratingID]
    if not reading or not curve or type(amount) ~= 'number' then return nil end
    local gain = GainAt(curve, (reading.rating + amount) / reading.perPercent)
    return Round(gain - reading.gain)
end

function TrueStats.CostOfNext(ratingID, percent)
    local reading = TrueStats.Get(ratingID)
    if not reading then return nil end
    return TrueStats.RatingFor(ratingID, reading.gain + (percent or 1))
end

function TrueStats.RatingFor(ratingID, targetGain)
    local reading = TrueStats.Get(ratingID)
    local curve = CURVES[ratingID]
    if not reading or not curve or type(targetGain) ~= 'number' then return nil end
    if targetGain <= reading.gain then return 0 end
    local raw = RawAt(curve, targetGain)
    if not raw then return nil end
    return Round(raw * reading.perPercent - reading.rating)
end

BUI.Events:Register('PLAYER_ENTERING_WORLD', 'TrueStats', TrueStats.Refresh)
BUI.Events:Register('PLAYER_LEVEL_UP', 'TrueStats', TrueStats.Refresh)
BUI.Events:Register('COMBAT_RATING_UPDATE', 'TrueStats', TrueStats.Refresh)
BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'TrueStats', TrueStats.Refresh)
BUI.Events:Register('PLAYER_REGEN_ENABLED', 'TrueStats', TrueStats.Refresh)
