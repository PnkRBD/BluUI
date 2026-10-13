local _, BUI = ...

local GroupFrames = BUI.GroupFrames

local function BuildLookupSet(...)
	local lookup = {}
	for index = 1, select("#", ...) do lookup[select(index, ...)] = true end
	return lookup
end

local SATED_IDS = BuildLookupSet(
	57723,
	57724,
	80354,
	95809,
	160455,
	264689,
	390435
)

local DESERTER_IDS = BuildLookupSet(
	26013,
	71041
)

local SKYRIDING_IDS = BuildLookupSet(
	427490,
	447959,
	447960
)

local DEBUFF_BLACKLIST = BuildLookupSet(
	206151,
	374609
)

local EVOKER_BLESSING = BuildLookupSet(
	381732, 381741, 381746, 381748, 381749, 381750, 381751,
	381752, 381753, 381754, 381756, 381757, 381758
)

local CLASS_RAID_BUFF = {
	DRUID   = 1126,
	PRIEST  = 21562,
	WARRIOR = 6673,
	SHAMAN  = 462854,
	MAGE    = 1459,
}

local FLAT_RAID_BUFFS = {}
for _, spellID in pairs(CLASS_RAID_BUFF) do FLAT_RAID_BUFFS[spellID] = true end
for spellID in pairs(EVOKER_BLESSING) do FLAT_RAID_BUFFS[spellID] = true end

local HEALER_HOTS = {
	[105] = {
		{ id = 774,    color = { 0.85, 0.35, 0.85 } },
		{ id = 155777, color = { 0.55, 0.30, 0.90 } },
		{ id = 33763,  color = { 0.35, 0.90, 0.35 } },
		{ id = 8936,   color = { 0.15, 0.65, 0.35 } },
		{ id = 48438,  color = { 0.95, 0.60, 0.15 } },
		{ id = 102351, color = { 0.95, 0.85, 0.30 } },
	},
	[256] = {
		{ id = 194384, color = { 0.95, 0.85, 0.50 } },
		{ id = 17,     color = { 0.85, 0.85, 0.85 } },
		{ id = 41635,  color = { 0.40, 0.75, 0.95 } },
		{ id = 139,    color = { 0.40, 0.85, 0.40 } },
	},
	[257] = {
		{ id = 139,    color = { 0.40, 0.85, 0.40 } },
		{ id = 41635,  color = { 0.40, 0.75, 0.95 } },
		{ id = 77489,  color = { 0.85, 0.95, 0.60 } },
		{ id = 17,     color = { 0.85, 0.85, 0.85 } },
	},
	[264] = {
		{ id = 61295,  color = { 0.25, 0.65, 1.00 } },
		{ id = 974,    color = { 0.70, 0.50, 0.25 }, also = { 383648 } },
	},
	[65] = {
		{ id = 53563,  color = { 1.00, 0.85, 0.30 } },
		{ id = 156910, color = { 1.00, 0.65, 0.20 } },
		{ id = 200025, color = { 1.00, 0.95, 0.55 } },
		{ id = 156322, color = { 1.00, 0.50, 0.20 } },
		{ id = 287280, color = { 0.95, 0.95, 0.80 } },
	},
	[270] = {
		{ id = 119611, color = { 0.35, 0.95, 0.75 } },
		{ id = 124682, color = { 0.25, 0.75, 0.55 } },
		{ id = 115175, color = { 0.65, 0.95, 0.90 } },
	},
	[1468] = {
		{ id = 364343, color = { 0.45, 0.95, 0.75 } },
		{ id = 366155, color = { 0.30, 0.85, 0.95 }, also = { 367364 } },
		{ id = 355941, color = { 0.40, 0.55, 0.95 }, also = { 376788 } },
		{ id = 373267, color = { 0.95, 0.45, 0.40 } },
		{ id = 363502, color = { 0.60, 0.45, 0.95 } },
	},
}

GroupFrames.AuraRegistry = {
	satedIDs          = SATED_IDS,
	deserterIDs       = DESERTER_IDS,
	skyridingIDs      = SKYRIDING_IDS,
	debuffBlacklist   = DEBUFF_BLACKLIST,
	flatRaidBuffs     = FLAT_RAID_BUFFS,
	healerHots        = HEALER_HOTS,
}
