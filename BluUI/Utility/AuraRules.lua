local _, BUI = ...

local AuraRules = {}
BUI.AuraRules = AuraRules

AuraRules.CATALOG = {
	{
		id = 'dispellable', polarity = 'HARMFUL', label = 'Dispellable By Me',
		desc = 'Debuffs you can currently dispel.',
		engineFilter = 'HARMFUL|RAID_PLAYER_DISPELLABLE',
		engineExcludeToken = 'RAID_PLAYER_DISPELLABLE',
		icon = 135894,
	},
	{
		id = 'crowdControl', polarity = 'HARMFUL', label = 'Crowd Control',
		desc = 'Stuns, fears, roots and other loss-of-control effects.',
		engineFilter = 'HARMFUL|CROWD_CONTROL',
		engineExcludeToken = 'CROWD_CONTROL',
		icon = 136071,
	},
	{
		id = 'bossAura', polarity = 'HARMFUL', label = 'Boss & Mob Auras',
		desc = 'Debuffs applied by enemies rather than players.',
		engineCandidates = { isBossAura = true },
		icon = 237555,
	},
	{
		id = 'anyDispellable', polarity = 'HARMFUL', label = 'Any Dispel Type',
		desc = 'Debuffs with a dispel type (Magic, Curse, Disease, Poison, Bleed), dispellable by anyone.',
		engineFilter = 'HARMFUL|DISPELLABLE',
		engineExcludeToken = 'DISPELLABLE',
		icon = 135739,
	},
	{
		id = 'mineHarmful', polarity = 'HARMFUL', label = 'My Debuffs',
		desc = 'Debuffs you applied.',
		engineFilter = 'HARMFUL|PLAYER',
		engineExcludeToken = 'PLAYER',
		icon = 132212,
	},
	{
		id = 'bigDefensive', polarity = 'HELPFUL', label = 'Big Defensives',
		desc = 'Major personal damage-reduction cooldowns.',
		engineFilter = 'HELPFUL|BIG_DEFENSIVE',
		engineExcludeToken = 'BIG_DEFENSIVE',
		icon = 132362,
	},
	{
		id = 'externalDefensive', polarity = 'HELPFUL', label = 'External Defensives',
		desc = 'Defensives cast on the unit by someone else.',
		engineFilter = 'HELPFUL|EXTERNAL_DEFENSIVE|!BIG_DEFENSIVE',
		engineExcludeToken = 'EXTERNAL_DEFENSIVE',
		icon = 135936,
	},
	{
		id = 'mineHelpful', polarity = 'HELPFUL', label = 'My Buffs',
		desc = 'Buffs you applied.',
		engineFilter = 'HELPFUL|PLAYER',
		engineExcludeToken = 'PLAYER',
		icon = 135932,
	},
	{
		id = 'important', polarity = 'HELPFUL', label = 'Important Buffs',
		desc = 'Buffs Blizzard flags as important, the ones enemy nameplates always show.',
		engineFilter = 'HELPFUL|IMPORTANT',
		engineExcludeToken = 'IMPORTANT',
		icon = C_Spell.GetSpellTexture(10060),
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
		engineExcludeToken = 'RAID',
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
	bossmob = { 'bossAura' },
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

function AuraRules.ExcludeSuffix(rules)
	local seen, parts
	for ruleIndex = 1, #rules do
		local rule = AuraRules.BY_ID[rules[ruleIndex]]
		local token = rule and rule.engineExcludeToken
		if token and not (seen and seen[token]) then
			seen = seen or {}
			seen[token] = true
			parts = parts or {}
			parts[#parts + 1] = '!' .. token
		end
	end
	return parts and table.concat(parts, '|') or nil
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
