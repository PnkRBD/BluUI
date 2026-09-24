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

GroupFrames.AuraRegistry = {
	satedIDs          = SATED_IDS,
	deserterIDs       = DESERTER_IDS,
	skyridingIDs      = SKYRIDING_IDS,
	debuffBlacklist   = DEBUFF_BLACKLIST,
	flatRaidBuffs     = FLAT_RAID_BUFFS,
}
