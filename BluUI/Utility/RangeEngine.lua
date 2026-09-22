local _, BUI = ...

BUI.Range = {}
local Range = BUI.Range

local CACHE_DURATION = 0.1
local ATTACK_RANGE = 40
local COLOR_IN_RANGE, COLOR_EDGE, COLOR_OUT_OF_RANGE = '|cff2bff62', '|cffffd100', '|cffff4040'

local rangeCheck = LibStub('LibRangeCheck-3.0')

function Range.SpellBracket(unit)
    if not unit or not UnitExists(unit) then return nil end
    return rangeCheck:GetRange(unit, false, false, CACHE_DURATION)
end

local function Colorize(text, minYards, maxYards)
    local color
    if maxYards and maxYards <= ATTACK_RANGE then
        color = COLOR_IN_RANGE
    elseif minYards and minYards >= ATTACK_RANGE then
        color = COLOR_OUT_OF_RANGE
    else
        color = COLOR_EDGE
    end
    return color .. text .. '|r'
end

function Range.DisplayText(unit)
    if not unit or not UnitExists(unit) then return '' end
    if UnitIsUnit(unit, 'player') then return '' end
    local minYards, maxYards = Range.SpellBracket(unit)
    if minYards == nil then return '' end
    if maxYards then return Colorize(minYards .. '-' .. maxYards, minYards, maxYards) end
    if minYards > 0 then return Colorize(minYards .. '+', minYards, nil) end
    return ''
end
