local _, BUI = ...

local AuraRules = {}
BUI.AuraRules = AuraRules

local GetUnitAuras = C_UnitAuras.GetUnitAuras
local IsSecret     = issecretvalue
local CanAccess    = canaccessvalue

local MAX_SCAN = 40

local function IsBossMobAura(data)
	local isPlayer = data.isPlayerAura
	if CanAccess(isPlayer) and isPlayer then return false end
	local fromPlayer = data.isFromPlayerOrPlayerPet
	return not (CanAccess(fromPlayer) and fromPlayer)
end

local function IsWorldNoise(data)
	local canApply   = data.canApplyAura
	local fromPlayer = data.isFromPlayerOrPlayerPet
	if not (CanAccess(canApply) and CanAccess(fromPlayer)) then return false end
	return not (canApply or fromPlayer)
end

AuraRules.CATALOG = {
	{
		id = 'dispellable', polarity = 'HARMFUL', label = 'Dispellable By Me',
		desc = 'Debuffs you can currently dispel.',
		setFilter = 'HARMFUL|RAID_PLAYER_DISPELLABLE',
		engineFilter = 'HARMFUL|RAID_PLAYER_DISPELLABLE',
		engineExcludeToken = 'RAID_PLAYER_DISPELLABLE',
		unitFrames = true, icon = 135894,
	},
	{
		id = 'crowdControl', polarity = 'HARMFUL', label = 'Crowd Control',
		desc = 'Stuns, fears, roots and other loss-of-control effects.',
		setFilter = 'HARMFUL|CROWD_CONTROL',
		engineFilter = 'HARMFUL|CROWD_CONTROL',
		engineExcludeToken = 'CROWD_CONTROL',
		unitFrames = true, icon = 136071,
	},
	{
		id = 'bossAura', polarity = 'HARMFUL', label = 'Boss & Mob Auras',
		desc = 'Debuffs applied by enemies rather than players.',
		predicate = IsBossMobAura,
		engineCandidates = { isBossAura = true },
		unitFrames = true, icon = 237555,
	},
	{
		id = 'anyDispellable', polarity = 'HARMFUL', label = 'Any Dispel Type',
		desc = 'Debuffs with a dispel type (Magic, Curse, Disease, Poison, Bleed), dispellable by anyone.',
		predicate = function(data)
			local dispelName = data.dispelName
			if not CanAccess(dispelName) then return false end
			return dispelName ~= nil and dispelName ~= ''
		end,
		engineFilter = 'HARMFUL|DISPELLABLE',
		engineExcludeToken = 'DISPELLABLE',
		unitFrames = true, icon = 135739,
	},
	{
		id = 'mineHarmful', polarity = 'HARMFUL', label = 'My Debuffs',
		desc = 'Debuffs you applied.',
		setFilter = 'HARMFUL|PLAYER',
		engineFilter = 'HARMFUL|PLAYER',
		engineExcludeToken = 'PLAYER',
		unitFrames = true, icon = 132212,
	},
	{
		id = 'bigDefensive', polarity = 'HELPFUL', label = 'Big Defensives',
		desc = 'Major personal damage-reduction cooldowns.',
		setFilter = 'HELPFUL|BIG_DEFENSIVE',
		engineFilter = 'HELPFUL|BIG_DEFENSIVE',
		engineExcludeToken = 'BIG_DEFENSIVE',
		unitFrames = true, icon = 132362,
	},
	{
		id = 'externalDefensive', polarity = 'HELPFUL', label = 'External Defensives',
		desc = 'Defensives cast on the unit by someone else.',
		setFilter = 'HELPFUL|EXTERNAL_DEFENSIVE',
		engineFilter = 'HELPFUL|EXTERNAL_DEFENSIVE|!BIG_DEFENSIVE',
		engineExcludeToken = 'EXTERNAL_DEFENSIVE',
		unitFrames = true, icon = 135936,
	},
	{
		id = 'mineHelpful', polarity = 'HELPFUL', label = 'My Buffs',
		desc = 'Buffs you applied.',
		setFilter = 'HELPFUL|PLAYER',
		engineFilter = 'HELPFUL|PLAYER',
		engineExcludeToken = 'PLAYER',
		unitFrames = true, icon = 135932,
	},
	{
		id = 'important', polarity = 'HELPFUL', label = 'Important Buffs',
		desc = 'Buffs Blizzard flags as important, the ones enemy nameplates always show.',
		setFilter = 'HELPFUL|IMPORTANT',
		engineFilter = 'HELPFUL|IMPORTANT',
		engineExcludeToken = 'IMPORTANT',
		unitFrames = true, icon = C_Spell.GetSpellTexture(10060),
	},
	{
		id = 'mineRaidCombat', polarity = 'HELPFUL', label = 'My Healing Buffs',
		desc = 'Buffs you cast that raid frames track (HoTs, externals, absorbs). Hides procs, food and flasks.',
		setFilter = 'HELPFUL|PLAYER|RAID_IN_COMBAT',
		engineFilter = 'HELPFUL|PLAYER|RAID_IN_COMBAT',
		unitFrames = true, icon = 136041,
	},
	{
		id = 'raidRelevant', polarity = 'HELPFUL', label = 'Raid-Relevant Buffs',
		desc = 'Buffs that matter in group content; hides world-buff noise.',
		setFilter = 'HELPFUL|RAID',
		predicate = function(data) return not IsWorldNoise(data) end,
		engineFilter = 'HELPFUL|RAID',
		engineExcludeToken = 'RAID',
		unitFrames = true, icon = 135987,
	},
	{
		id = 'allHarmful', polarity = 'HARMFUL', label = 'All Debuffs',
		desc = 'Everything harmful not blacklisted.',
		always = true,
		unitFrames = true, icon = 136207,
	},
	{
		id = 'allHelpful', polarity = 'HELPFUL', label = 'All Buffs',
		desc = 'Everything helpful not blacklisted.',
		always = true,
		unitFrames = true, icon = 135938,
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

function AuraRules.DropdownItems(polarity, chosen, unitFramesOnly)
	local taken = {}
	if chosen then
		for chosenIndex = 1, #chosen do taken[chosen[chosenIndex]] = true end
	end
	local items = {}
	for _, rule in ipairs(AuraRules.CATALOG) do
		if rule.polarity == polarity and not taken[rule.id]
			and (not unitFramesOnly or rule.unitFrames) then
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

function AuraRules.BuildSets(unit, rules, sets)
	sets = sets or {}
	for ruleIndex = 1, #rules do
		local rule = AuraRules.BY_ID[rules[ruleIndex]]
		if rule and rule.setFilter then
			local set = sets[rule.id]
			if set then wipe(set) else set = {}; sets[rule.id] = set end
			local auras = GetUnitAuras(unit, rule.setFilter, MAX_SCAN, 0, 0)
			if auras then
				for auraIndex = 1, #auras do
					local instanceID = auras[auraIndex].auraInstanceID
					if instanceID then set[instanceID] = true end
				end
			end
		end
	end
	return sets
end

function AuraRules.Evaluate(rules, data, sets)
	local instanceID = data.auraInstanceID
	for ruleIndex = 1, #rules do
		local rule = AuraRules.BY_ID[rules[ruleIndex]]
		if rule then
			if rule.always then return ruleIndex end
			local ok = true
			if rule.setFilter then
				local set = sets and sets[rule.id]
				ok = (set and instanceID and set[instanceID]) and true or false
			end
			if ok and rule.predicate then
				ok = rule.predicate(data) and true or false
			end
			if ok then return ruleIndex end
		end
	end
	return nil
end

function AuraRules.Compare(auraA, auraB)
	local priorityA = auraA._bluPri or 1000
	local priorityB = auraB._bluPri or 1000
	if priorityA ~= priorityB then return priorityA < priorityB end
	local instanceA, instanceB = auraA.auraInstanceID, auraB.auraInstanceID
	if instanceA and instanceB and not IsSecret(instanceA) and not IsSecret(instanceB) and instanceA ~= instanceB then
		return instanceA < instanceB
	end
	return false
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
