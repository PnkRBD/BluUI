local _, BUI = ...

local AuraRules = {}
BUI.AuraRules = AuraRules

AuraRules.CATALOG = {
	{
		id = 'dispellable', polarity = 'HARMFUL', label = 'Dispellable By Me',
		desc = 'Debuffs you can dispel.',
		engineFilter = 'HARMFUL|RAID',
		icon = 135894,
	},
	{
		id = 'groupDispellable', polarity = 'HARMFUL', label = 'Dispellable By My Group',
		desc = 'Debuffs someone in your group can dispel.',
		engineFilter = 'HARMFUL|RAID_PLAYER_DISPELLABLE',
		icon = 'Interface\\Icons\\Spell_Holy_DispelMagic',
	},
	{
		id = 'crowdControl', polarity = 'HARMFUL', label = 'Crowd Control',
		desc = 'Stuns, fears, roots and other loss-of-control effects.',
		engineFilter = 'HARMFUL|CROWD_CONTROL',
		icon = 136071,
	},
	{
		id = 'bossAura', polarity = 'HARMFUL', label = 'Boss & Role Debuffs',
		desc = 'Encounter debuffs, plus the ones Blizzard flags for your role, like tank swap debuffs.',
		engineCandidates = { isBossOrRoleAura = true },
		icon = 237555,
	},
	{
		id = 'bossDebuff', polarity = 'HARMFUL', label = 'Boss Debuffs',
		desc = 'Debuffs Blizzard marks as boss encounter debuffs.',
		engineCandidates = { isBossAura = true },
		icon = 'Interface\\Icons\\INV_Misc_Head_Dragon_01',
	},
	{
		id = 'roleDebuff', polarity = 'HARMFUL', label = 'Role Debuffs',
		desc = 'Debuffs Blizzard marks for a role, like tank swap stacks.',
		engineCandidates = { isRoleAura = true },
		icon = 'Interface\\Icons\\Ability_Warrior_DefensiveStance',
	},
	{
		id = 'npcHarmful', polarity = 'HARMFUL', label = 'Debuffs From NPCs',
		desc = 'Debuffs from monsters and bosses, not from players or their pets.',
		engineCandidates = { isFromPlayerOrPlayerPet = false },
		icon = 'Interface\\Icons\\Spell_Shadow_DeathScream',
	},
	{
		id = 'priorityDebuff', polarity = 'HARMFUL', label = 'Priority Debuffs',
		desc = 'Debuffs Blizzard\'s own raid frames always put first.',
		engineCandidates = { isPriorityAura = true },
		icon = C_Spell.GetSpellTexture(589),
	},
	{
		id = 'anyDispellable', polarity = 'HARMFUL', label = 'Dispellable By Anyone',
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
		id = 'mineKeyDebuffs', polarity = 'HARMFUL', label = 'My Tracked Debuffs',
		desc = 'Your debuffs the game says to keep an eye on, like DoTs. Leaves out crowd control.',
		engineFilter = 'HARMFUL|PLAYER|!CROWD_CONTROL',
		engineCandidates = { nameplateShowPersonal = true },
		icon = C_Spell.GetSpellTexture(172),
	},
	{
		id = 'keyDebuffs', polarity = 'HARMFUL', label = 'Major Debuffs',
		desc = 'Big debuffs from anyone that the game shows to everyone. Leaves out crowd control.',
		engineFilter = 'HARMFUL|!CROWD_CONTROL',
		engineCandidates = { nameplateShowAll = true, nameplateShowPersonal = false },
		icon = C_Spell.GetSpellTexture(12294),
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
		desc = 'Important buffs no other rule shows. The rules below it show important buffs first.',
		engineFilter = 'HELPFUL|IMPORTANT',
		sortFirst = 'ImportantOnly',
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

AuraRules.UNIT_DEFAULTS = {
	player       = { buff = { 'mineRaidCombat' }, debuff = { 'allHarmful' } },
	target       = { buff = { 'bossBuff', 'important', 'stealable', 'fromPlayers' }, debuff = { 'mineKeyDebuffs', 'keyDebuffs' } },
	targettarget = { buff = { 'allHelpful' }, debuff = { 'mineHarmful' } },
	focus        = { buff = { 'allHelpful' }, debuff = { 'mineHarmful' } },
	boss         = { buff = { 'allHelpful' }, debuff = { 'mineHarmful' } },
}

function AuraRules.DefaultAllRule(polarity)
	return polarity == 'HELPFUL' and 'allHelpful' or 'allHarmful'
end

function AuraRules.DropdownItems(polarity, withoutSorts)
	local items = {}
	for _, rule in ipairs(AuraRules.CATALOG) do
		if rule.polarity == polarity and not (withoutSorts and rule.sortFirst) then
			items[#items + 1] = { value = rule.id, text = rule.label, tip = rule.desc }
		end
	end
	return items
end

function AuraRules.DropSortRules(rules)
	for ruleIndex = #rules, 1, -1 do
		local id = rules[ruleIndex]
		local rule = AuraRules.BY_ID[id]
		if rule and rule.sortFirst then
			table.remove(rules, ruleIndex)
			if rules.hidden then rules.hidden[id] = nil end
		end
	end
	if rules.hidden and next(rules.hidden) == nil then rules.hidden = nil end
end

function AuraRules.Label(id)
	local rule = AuraRules.BY_ID[id]
	return rule and rule.label or tostring(id)
end

function AuraRules.Icon(id)
	local rule = AuraRules.BY_ID[id]
	return rule and rule.icon or 134400
end

function AuraRules.Description(id)
	local rule = AuraRules.BY_ID[id]
	return rule and rule.desc
end

function AuraRules.EnsureRules(config, key, polarity, defaultRules)
	local rules = config[key]
	if type(rules) == 'table' then return rules end
	rules = {}
	local sourceRules = config.source and AuraRules.SOURCE_TO_RULES[config.source] or defaultRules
	if sourceRules then
		for ruleIndex = 1, #sourceRules do rules[ruleIndex] = sourceRules[ruleIndex] end
	end
	if #rules == 0 then rules[1] = AuraRules.DefaultAllRule(polarity) end
	config[key] = rules
	return rules
end
