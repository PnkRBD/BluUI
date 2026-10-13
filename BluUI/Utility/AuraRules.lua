local _, BUI = ...

local AuraRules = {}
BUI.AuraRules = AuraRules

AuraRules.CATALOG = {
	{
		id = 'dispellable', polarity = 'HARMFUL', label = 'Dispellable By Me',
		desc = 'Debuffs you can currently dispel.',
		engineFilter = 'HARMFUL|RAID_PLAYER_DISPELLABLE',
		icon = 135894,
	},
	{
		id = 'crowdControl', polarity = 'HARMFUL', label = 'Crowd Control',
		desc = 'Stuns, fears, roots and other loss-of-control effects.',
		engineFilter = 'HARMFUL|CROWD_CONTROL',
		icon = 136071,
	},
	{
		id = 'bossAura', polarity = 'HARMFUL', label = 'Boss & Role Auras',
		desc = 'Encounter debuffs, plus the ones Blizzard flags for your role, like tank swap debuffs.',
		engineCandidates = { isBossOrRoleAura = true },
		icon = 237555,
	},
	{
		id = 'priorityDebuff', polarity = 'HARMFUL', label = 'Priority Debuffs',
		desc = 'Debuffs Blizzard\'s own raid frames always put first.',
		engineCandidates = { isPriorityAura = true },
		icon = C_Spell.GetSpellTexture(589),
	},
	{
		id = 'anyDispellable', polarity = 'HARMFUL', label = 'Any Dispel Type',
		desc = 'Debuffs with a dispel type (Magic, Curse, Disease, Poison, Bleed), dispellable by anyone.',
		engineFilter = 'HARMFUL|DISPELLABLE',
		icon = 135739,
	},
	{
		id = 'mineHarmful', polarity = 'HARMFUL', label = 'My Debuffs',
		desc = 'Debuffs you applied.',
		engineFilter = 'HARMFUL|PLAYER',
		icon = 132212,
	},
	{
		id = 'bigDefensive', polarity = 'HELPFUL', label = 'Big Defensives',
		desc = 'Major personal damage-reduction cooldowns.',
		engineFilter = 'HELPFUL|BIG_DEFENSIVE',
		icon = 132362,
	},
	{
		id = 'externalDefensive', polarity = 'HELPFUL', label = 'External Defensives',
		desc = 'Defensives cast on the unit by someone else.',
		engineFilter = 'HELPFUL|EXTERNAL_DEFENSIVE|!BIG_DEFENSIVE',
		icon = 135936,
	},
	{
		id = 'mineHelpful', polarity = 'HELPFUL', label = 'My Buffs',
		desc = 'Buffs you applied.',
		engineFilter = 'HELPFUL|PLAYER',
		icon = 135932,
	},
	{
		id = 'important', polarity = 'HELPFUL', label = 'Important Buffs',
		desc = 'Buffs Blizzard flags as important, the ones enemy nameplates always show.',
		engineFilter = 'HELPFUL|IMPORTANT',
		icon = C_Spell.GetSpellTexture(10060),
	},
	{
		id = 'bossBuff', polarity = 'HELPFUL', label = 'Boss & Role Buffs',
		desc = 'Encounter buffs, plus the ones Blizzard flags for your role.',
		engineCandidates = { isBossOrRoleAura = true },
		icon = 237555,
	},
	{
		id = 'stealable', polarity = 'HELPFUL', label = 'Stealable Buffs',
		desc = 'Buffs Blizzard marks as stealable, the ones a mage can take off an enemy.',
		engineCandidates = { isStealable = true },
		icon = C_Spell.GetSpellTexture(30449),
	},
	{
		id = 'fromPlayers', polarity = 'HELPFUL', label = 'Buffs From Players',
		desc = 'Buffs any player or their pet cast, like a friend\'s own buffs and procs. Leaves out NPC buffs.',
		engineCandidates = { isFromPlayerOrPlayerPet = true },
		icon = C_Spell.GetSpellTexture(21562),
	},
	{
		id = 'canApply', polarity = 'HELPFUL', label = 'Buffs I Can Cast',
		desc = 'Buffs you could put on the unit yourself.',
		engineCandidates = { canApplyAura = true },
		icon = C_Spell.GetSpellTexture(1126),
	},
	{
		id = 'mineRaidCombat', polarity = 'HELPFUL', label = 'My Healing Buffs',
		desc = 'Buffs you cast that raid frames track (HoTs, externals, absorbs). Hides procs, food and flasks.',
		engineFilter = 'HELPFUL|PLAYER|RAID_IN_COMBAT',
		icon = 136041,
	},
	{
		id = 'raidRelevant', polarity = 'HELPFUL', label = 'Raid-Relevant Buffs',
		desc = 'Buffs that matter in group content; hides world-buff noise.',
		engineFilter = 'HELPFUL|RAID',
		icon = 135987,
	},
	{
		id = 'allHarmful', polarity = 'HARMFUL', label = 'All Debuffs',
		desc = 'Everything harmful not blacklisted.',
		icon = 136207,
	},
	{
		id = 'allHelpful', polarity = 'HELPFUL', label = 'All Buffs',
		desc = 'Everything helpful not blacklisted.',
		icon = 135938,
	},
}

AuraRules.BY_ID = {}
for _, rule in ipairs(AuraRules.CATALOG) do AuraRules.BY_ID[rule.id] = rule end

AuraRules.SOURCE_TO_RULES = {
	mine    = { 'mineRaidCombat' },
	mineAll = { 'mineHelpful' },
	raid    = { 'raidRelevant' },
	all     = {},
	bossmob = { 'bossAura', 'priorityDebuff' },
}

function AuraRules.DefaultAllRule(polarity)
	return polarity == 'HELPFUL' and 'allHelpful' or 'allHarmful'
end

function AuraRules.DropdownItems(polarity, chosen)
	local taken = {}
	if chosen then
		for chosenIndex = 1, #chosen do taken[chosen[chosenIndex]] = true end
	end
	local items = {}
	for _, rule in ipairs(AuraRules.CATALOG) do
		if rule.polarity == polarity and not taken[rule.id] then
			items[#items + 1] = { value = rule.id, text = rule.label }
		end
	end
	return items
end

function AuraRules.Label(id)
	local rule = AuraRules.BY_ID[id]
	return rule and rule.label or tostring(id)
end

function AuraRules.Icon(id)
	local rule = AuraRules.BY_ID[id]
	return rule and rule.icon or 134400
end

function AuraRules.EnsureRules(config, polarity, defaultRules)
	local rules = config.rules
	if type(rules) == 'table' then return rules end
	rules = {}
	local sourceRules = config.source and AuraRules.SOURCE_TO_RULES[config.source] or defaultRules
	if sourceRules then
		for ruleIndex = 1, #sourceRules do rules[ruleIndex] = sourceRules[ruleIndex] end
	end
	if #rules == 0 then rules[1] = AuraRules.DefaultAllRule(polarity) end
	config.rules = rules
	return rules
end
