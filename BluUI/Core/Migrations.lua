local _, BUI = ...

local MigratedMediaNames = {
	['AUI Gradient']       = 'BUI Gradient',
	['Azor Wailing Arrow'] = 'None',
}

local function FixLegacyValue(value)
	local mapped = MigratedMediaNames[value]
	if mapped then return mapped end
	value = value:gsub('^Interface\\AddOns\\AzortharionUI\\Media\\Fonts\\', 'Interface\\AddOns\\BluUI\\Media\\Fonts\\')
	if value:sub(1, 4) == 'AUI_' then
		value = 'BUI_' .. value:sub(5)
	end
	return value
end

local function FixLegacyValues(targetTable, depth)
	if type(targetTable) ~= 'table' or depth > 20 then return end
	for key, value in pairs(targetTable) do
		if type(value) == 'string' then
			local fixed = FixLegacyValue(value)
			if fixed ~= value then targetTable[key] = fixed end
		elseif type(value) == 'table' then
			FixLegacyValues(value, depth + 1)
		end
	end
end

function BUI.FixLegacyValues(targetTable)
	FixLegacyValues(targetTable, 1)
end

local PROFILE_MIGRATION_VERSION = 29

local AURA_GROUP_KINDS = { 'buffs', 'debuffs', 'bigDef', 'crowdControl' }

local function ZeroInsideAuraOffsets(profile)
	local groupFrames = profile.groupFrames
	if type(groupFrames) ~= 'table' then return end
	for _, sectionKey in ipairs({ 'party', 'raid' }) do
		local section = groupFrames[sectionKey]
		if type(section) == 'table' then
			for _, kind in ipairs(AURA_GROUP_KINDS) do
				local group = section[kind]
				if type(group) == 'table' and group.anchorPoint and group.anchorPoint == group.relativePoint then
					if group.offsetX == nil then group.offsetX = 0 end
					if group.offsetY == nil then group.offsetY = 0 end
				end
			end
		end
	end
end

local CDM_VIEWER_KEYS = { 'essential', 'utility', 'buffs' }

local function StripAutoSlots(list)
	if type(list) ~= 'table' then return end
	for slotIndex = #list, 1, -1 do
		local entry = list[slotIndex]
		if type(entry) == 'string' and (entry:match('^trinket:%d$') or entry:match('^racial:%d$')) then
			table.remove(list, slotIndex)
		end
	end
end

local function SettleGlowTypes(node, validTypes)
	if type(node) ~= 'table' then return end
	for key, value in pairs(node) do
		if key == 'glow' and type(value) == 'table' then
			if type(value.type) == 'string' and not validTypes[value.type] then value.type = 'pixel' end
			if type(value.style) == 'string' and not validTypes[value.style] then value.style = 'pixel' end
		elseif type(value) == 'table' then
			SettleGlowTypes(value, validTypes)
		end
	end
end

local function SettleIconOrderKeys(iconOrder)
	if type(iconOrder) ~= 'table' then return end
	local numericKeys = {}
	for key in pairs(iconOrder) do
		if type(key) == 'number' then numericKeys[#numericKeys + 1] = key end
	end
	for _, key in ipairs(numericKeys) do
		local list = iconOrder[key]
		iconOrder[key] = nil
		local stringKey = tostring(key)
		if type(list) == 'table' and not iconOrder[stringKey] then
			for entryIndex, id in ipairs(list) do
				local itemID = type(id) == 'string' and id:match('^item:(%d+)$')
				if itemID then list[entryIndex] = 'custom:' .. itemID end
			end
			iconOrder[stringKey] = list
		end
	end
end

local function MergePotionPrios(cdm, customBars)
	local merged = type(cdm.potionPrio) == 'table' and cdm.potionPrio or {}
	cdm.potionPrio = merged
	local function Absorb(config)
		local source = type(config) == 'table' and config.potionPrio
		if type(source) ~= 'table' then return end
		for buildKey, bucket in pairs(source) do
			if type(bucket) == 'table' then
				local destination = merged[buildKey]
				if not destination then destination = {}; merged[buildKey] = destination end
				for id, priority in pairs(bucket) do
					local key = BUI.CDM.PotionPrioKey(id)
					if destination[key] == nil then destination[key] = priority end
				end
			end
		end
		config.potionPrio = nil
	end
	for _, key in ipairs(CDM_VIEWER_KEYS) do Absorb(cdm[key]) end
	if type(customBars) == 'table' then
		for _, bar in ipairs(customBars) do Absorb(bar) end
	end
	cdm._potionPrioShared = nil
end

local function ConsumablesBarFromTracking(tracking)
	local bar = {
		name = 'Consumables', enabled = tracking.enabled ~= false,
		locked = tracking.locked, iconSize = tracking.iconSize, spacing = tracking.spacing,
		zoom = tracking.zoom or 0.08, borderSize = tracking.borderSize, borderColor = tracking.borderColor,
		growDirection = tracking.growDirection, growVertical = tracking.growVertical, maxPerRow = tracking.maxPerRow,
		showTrinkets = tracking.showTrinkets, showStackText = tracking.showStackText, showCooldownText = tracking.showCooldownText,
		stackTextPosition = tracking.stackTextPosition, stackTextOffsetX = tracking.stackTextOffsetX, stackTextOffsetY = tracking.stackTextOffsetY,
		cooldownTextPosition = tracking.cooldownTextPosition, cooldownTextOffsetX = tracking.cooldownTextOffsetX, cooldownTextOffsetY = tracking.cooldownTextOffsetY,
		stackTextSize = tracking.stackTextSize, cooldownTextSize = tracking.cooldownTextSize,
		posX = tracking.posX, posY = tracking.posY, anchorFrame = tracking.anchorFrame,
		anchorPoint = tracking.anchorPoint or 'BOTTOM', anchorOffsetX = tracking.anchorOffsetX, anchorOffsetY = tracking.anchorOffsetY,
		customSpells = {},
	}
	if type(tracking.customItems) == 'table' then
		for _, itemID in ipairs(tracking.customItems) do
			bar.customSpells[#bar.customSpells + 1] = 'item:' .. itemID
		end
	end
	return bar
end

local function FoldLegacyBarLists(bar)
	if not (bar.items or bar.spells) then return end
	bar.customSpells = type(bar.customSpells) == 'table' and bar.customSpells or {}
	local list, seen = bar.customSpells, {}
	for _, value in ipairs(list) do seen[tostring(value)] = true end
	for _, itemID in ipairs(type(bar.items) == 'table' and bar.items or {}) do
		local stored = 'item:' .. itemID
		if not seen[stored] then list[#list + 1] = stored; seen[stored] = true end
	end
	for _, spellID in ipairs(type(bar.spells) == 'table' and bar.spells or {}) do
		if not seen[tostring(spellID)] then list[#list + 1] = spellID; seen[tostring(spellID)] = true end
	end
	bar.items, bar.spells, bar.blacklist = nil, nil, nil
end

local function ScanTrinketsOnTrinketBar(bar)
	if bar._trinketMigrated or type(bar.name) ~= 'string' or not bar.name:lower():find('trinket') or bar.showTrinkets then return end
	bar.showTrinkets = true
	if type(bar.customSpells) ~= 'table' then return end
	local kept = {}
	for _, value in ipairs(bar.customSpells) do
		local itemID = tonumber(tostring(value):match('^item:(%d+)$'))
		local equipSlot = itemID and select(4, C_Item.GetItemInfoInstant(itemID))
		if equipSlot ~= 'INVTYPE_TRINKET' then kept[#kept + 1] = value end
	end
	bar.customSpells = kept
end

local function SettleCustomBarShapes(profile)
	if type(profile.trackingBars) == 'table' then
		if next(profile.trackingBars) and not (type(profile.customBars) == 'table' and next(profile.customBars)) then
			profile.customBars = profile.trackingBars
		end
		profile.trackingBars = nil
	end
	local tracking = profile.tracking
	if type(tracking) == 'table' then
		local first = type(profile.customBars) == 'table' and profile.customBars[1]
		if not (type(first) == 'table' and first.name) then
			profile.customBars = { ConsumablesBarFromTracking(tracking) }
		end
		profile.tracking = nil
	end
	if type(profile.customBars) ~= 'table' then return end
	for _, bar in ipairs(profile.customBars) do
		if type(bar) == 'table' then
			FoldLegacyBarLists(bar)
			ScanTrinketsOnTrinketBar(bar)
			bar._trinketMigrated = nil
		end
	end
end

local LEGACY_SKIN_IDS = { miscpanels = true, shop = true, micromenu = true, combatalerts = true, lossofcontrol = true }

local OLD_TARGET_BUFF_RULES = { { 'mineHelpful' }, { 'bossBuff', 'important', 'stealable', 'mineHelpful' } }
local OLD_TARGET_DEBUFF_RULES = { { 'mineHarmful' }, { 'mineHarmful', 'bossAura', 'dispellable' } }
local SHOW_MODE_RULES = {
	debuffShowMode = { key = 'debuffRules', modes = { all = 'allHarmful', mine = 'mineHarmful', dispellable = 'dispellable', allDispellable = 'anyDispellable', blizzardRaid = 'allHarmful' } },
	buffShowMode   = { key = 'buffRules', modes = { all = 'allHelpful', mine = 'mineHelpful', mineAll = 'mineHelpful', raid = 'raidRelevant' } },
}
local RETIRED_AURA_KEYS = {
	'buffShowMode', 'debuffShowMode', 'debuffFilter', 'onlyPlayerDebuffs', 'debuffOnlyMine', 'debuffImportant',
	'onlyDispellableDebuffs', 'onlyPlayerBuffs', 'buffImportant',
	'playerBuffRulesNarrowed', 'targetAuraRulesFixed', 'targetBuffRulesWidened', 'targetKeyDebuffs',
}

local function SameRules(rules, expected)
	if type(rules) ~= 'table' or #rules ~= #expected then return false end
	for index = 1, #expected do
		if rules[index] ~= expected[index] then return false end
	end
	return true
end

local function ReplaceOldRules(rules, oldLists, replacement)
	for _, old in ipairs(oldLists) do
		if SameRules(rules, old) then
			for index = #rules, 1, -1 do rules[index] = nil end
			for index, rule in ipairs(replacement) do rules[index] = rule end
			return
		end
	end
end

local function SettleUnitAuraRules(unitFrames)
	for _, unit in pairs(unitFrames) do
		if type(unit) == 'table' then
			for showKey, legacy in pairs(SHOW_MODE_RULES) do
				local rule = legacy.modes[unit[showKey]]
				if rule and type(unit[legacy.key]) ~= 'table' then unit[legacy.key] = { rule } end
			end
		end
	end
	local player, target = unitFrames.player, unitFrames.target
	if type(player) == 'table' and not player.playerBuffRulesNarrowed and SameRules(player.buffRules, { 'mineHelpful' }) then
		player.buffRules[1] = 'mineRaidCombat'
	end
	if type(target) == 'table' then
		local defaults = BUI.AuraRules.UNIT_DEFAULTS.target
		if not target.targetAuraRulesFixed then ReplaceOldRules(target.buffRules, OLD_TARGET_BUFF_RULES, defaults.buff) end
		if not target.targetKeyDebuffs then ReplaceOldRules(target.debuffRules, OLD_TARGET_DEBUFF_RULES, defaults.debuff) end
	end
	for _, unit in pairs(unitFrames) do
		if type(unit) == 'table' then
			for _, key in ipairs(RETIRED_AURA_KEYS) do unit[key] = nil end
		end
	end
end
local MERGED_RULES = { bossDebuff = 'bossAura', roleDebuff = 'bossAura' }

local function MergeRetiredRules(rules)
	if type(rules) ~= 'table' then return end
	local retired = false
	for _, id in ipairs(rules) do retired = retired or MERGED_RULES[id] ~= nil end
	if not retired then return end
	local hidden = type(rules.hidden) == 'table' and rules.hidden or {}
	local kept, hide = {}, {}
	for _, id in ipairs(rules) do
		local merged = MERGED_RULES[id] or id
		if hide[merged] == nil then
			kept[#kept + 1] = merged
			hide[merged] = hidden[id] == true
		end
	end
	for index = #rules, 1, -1 do rules[index] = nil end
	rules.hidden = nil
	for index, id in ipairs(kept) do
		rules[index] = id
		if hide[id] then
			rules.hidden = rules.hidden or {}
			rules.hidden[id] = true
		end
	end
end

local function MergeRetiredRuleLists(profile)
	for _, unit in pairs(type(profile.unitFrames) == 'table' and profile.unitFrames or {}) do
		if type(unit) == 'table' then
			MergeRetiredRules(unit.buffRules)
			MergeRetiredRules(unit.debuffRules)
		end
	end
	for _, section in pairs(type(profile.groupFrames) == 'table' and profile.groupFrames or {}) do
		if type(section) == 'table' then
			for _, container in pairs(section) do
				if type(container) == 'table' then MergeRetiredRules(container.rules) end
			end
		end
	end
end

local FRAME_BLACKLIST_KEYS = { buff = 'buffBlacklist', debuff = 'debuffBlacklist' }

local function Shared(value, sharedByDefault)
	if value == nil then return sharedByDefault end
	return value == true
end

local function KeepBuffFrameBlacklist(profile, sharedByDefault)
	local frames = type(profile.buffFrames) == 'table' and profile.buffFrames or nil
	if not Shared(frames and frames.shareBlacklist, sharedByDefault) then
		if frames then frames.shareBlacklist = nil end
		return
	end
	local filters = type(profile.auraFilters) == 'table' and profile.auraFilters or {}
	local groupFrames = type(profile.groupFrames) == 'table' and profile.groupFrames or {}
	local overrides = type(groupFrames.blacklistOverrides) == 'table' and groupFrames.blacklistOverrides or {}
	for key, unitKey in pairs(FRAME_BLACKLIST_KEYS) do
		local hidden = {}
		if Shared(filters.shareBlacklists, sharedByDefault) then
			for spellID, mode in pairs(type(overrides[key]) == 'table' and overrides[key] or {}) do
				if mode == 'hide' then hidden[spellID] = true end
			end
		else
			for spellID, active in pairs(type(filters[unitKey]) == 'table' and filters[unitKey] or {}) do
				if active then hidden[spellID] = true end
			end
		end
		if next(hidden) then
			frames = frames or {}
			profile.buffFrames = frames
			frames.blacklist = type(frames.blacklist) == 'table' and frames.blacklist or {}
			local list = type(frames.blacklist[key]) == 'table' and frames.blacklist[key] or {}
			frames.blacklist[key] = list
			for spellID in pairs(hidden) do list[spellID] = true end
		end
	end
	if frames then frames.shareBlacklist = nil end
end

local LEGACY_UNIT_KEYS = { 'player', 'target', 'targettarget', 'focus', 'focustarget', 'pet', 'boss', 'arena', 'party' }
local HEALING_RULE = 'mineRaidCombat'

local function PutHealingBuffsFirst(container, key, stockRule)
	local rules = container[key]
	if type(rules) ~= 'table' or #rules == 0 or (#rules == 1 and rules[1] == stockRule) then
		container[key] = { HEALING_RULE }
		return
	end
	for _, rule in ipairs(rules) do
		if rule == HEALING_RULE then return end
	end
	table.insert(rules, 1, HEALING_RULE)
end

local function SettleVisibilityPriority(general)
	local saved = general.visibilityPriority
	if type(saved) ~= 'table' then return end
	local defaults, conditions = BUI.Visibility.DEFAULT_PRIORITY, BUI.Visibility.CONDITIONS
	local last = #defaults
	for key in pairs(saved) do
		if type(key) == 'number' and key > last then last = key end
	end
	local order, seen = {}, {}
	local function Keep(key)
		if conditions[key] and not seen[key] then
			seen[key] = true
			order[#order + 1] = key
		end
	end
	for index = 1, last do Keep(rawget(saved, index) or defaults[index]) end
	for _, key in ipairs(defaults) do Keep(key) end
	for key in pairs(saved) do saved[key] = nil end
	for index, key in ipairs(order) do saved[index] = key end
end

local function DropRetiredKeys(profile)
	profile.general.gradientColor = nil
	if type(profile.interface) == 'table' then profile.interface.minimapIconDock = nil end
	local unitFrames = profile.unitFrames
	if type(unitFrames) ~= 'table' then return end
	for _, unitKey in ipairs(LEGACY_UNIT_KEYS) do
		local unit = unitFrames[unitKey]
		if type(unit) == 'table' then unit.powerColor = nil end
	end
end

local STACK_SNAPSHOT_FIELDS = {
	'anchorFrame', 'anchorPoint', 'anchorOffsetX', 'anchorOffsetY',
	'centerHorizontally', 'matchAnchorWidth', 'noGap', 'scaleOffsets',
	'posX', 'posY',
}

local function ClearStackAnchor(memberDB)
	memberDB.anchorFrame = ''
	memberDB.anchorPoint = nil
	memberDB.anchorOffsetX = nil
	memberDB.anchorOffsetY = nil
	memberDB.centerHorizontally = false
	memberDB.matchAnchorWidth = nil
	memberDB.noGap = nil
	memberDB.scaleOffsets = nil
end

local function RetireClassicPowerStack(powerBar, secondaryPower)
	if type(powerBar) ~= 'table' then return end
	local stack = powerBar.stack
	powerBar.stack, powerBar.stackFlushEdge = nil, nil
	if type(secondaryPower) == 'table' then secondaryPower.stackFlushEdge = nil end
	if type(stack) ~= 'table' or not stack.enabled then return end
	local members = { primary = powerBar }
	if type(secondaryPower) == 'table' then members.secondary = secondaryPower end

	local settings = type(powerBar.stackLab) == 'table' and powerBar.stackLab or {}
	powerBar.stackLab = settings
	local order = { 'primary', 'secondary', 'castbar' }
	if type(stack.order) == 'table' and stack.order[1] == 'secondary' then order = { 'secondary', 'primary', 'castbar' } end
	settings.enabled = true
	settings.order = order
	settings.attached = { primary = true, secondary = true, castbar = false }
	settings.gap = stack.gap or 0
	settings.width = powerBar.barWidth or settings.width or 230
	settings.matchWidth = stack.matchAnchorWidth ~= false
	if settings.matchAnchorWidth == nil then settings.matchAnchorWidth = false end
	if settings.castbarMode == nil then settings.castbarMode = 'collapse' end
	if settings.locked == nil then settings.locked = true end

	if stack.anchorFrame and stack.anchorFrame ~= '' then
		settings.anchorFrame = stack.anchorFrame
		settings.anchorPoint = stack.anchorPoint or 'TOP'
		settings.anchorOffsetX = stack.anchorOffsetX or 0
		settings.anchorOffsetY = stack.anchorOffsetY or 0
		settings.centerHorizontally = false
		settings.posX = settings.posX or 0
		settings.posY = settings.posY or -220
	else
		local base = members[stack.baseMember] or members[order[1]] or powerBar
		settings.anchorFrame = ''
		settings.anchorPoint = settings.anchorPoint or 'BOTTOM'
		settings.anchorOffsetX, settings.anchorOffsetY = 0, 0
		settings.centerHorizontally = base.centerHorizontally == true
		settings.posX = base.posX or 0
		settings.posY = base.posY or 0
	end

	if type(stack.preStack) == 'table' then
		for key, memberDB in pairs(members) do
			local snapshot = stack.preStack[key]
			if type(snapshot) == 'table' then
				for _, field in ipairs(STACK_SNAPSHOT_FIELDS) do memberDB[field] = snapshot[field] end
			end
		end
	else
		for _, memberDB in pairs(members) do ClearStackAnchor(memberDB) end
	end
end

local function RetireClassicPowerStacks(profile)
	RetireClassicPowerStack(profile.powerBar, profile.secondaryPower)
	if type(profile.powerVariants) ~= 'table' then return end
	for _, variant in pairs(profile.powerVariants) do
		if type(variant) == 'table' then RetireClassicPowerStack(variant.powerBar, variant.secondaryPower) end
	end
end

local function SettleMoveFramesMode(moveFrames)
	if type(moveFrames) ~= 'table' then return end
	if moveFrames.autoReset then
		moveFrames.positionMode = 'reset'
	elseif moveFrames.rememberPositions == false then
		moveFrames.positionMode = 'session'
	end
	moveFrames.autoReset, moveFrames.rememberPositions = nil, nil
end

local function AnnouncerSlotKey(charKey)
	return (charKey:gsub(' %- ', '-', 1))
end

local function AdoptAnnouncerLists(slot, source)
	if type(source) ~= 'table' then return end
	if type(source.spells) == 'table' and #source.spells > 0 and #(slot.spells or {}) == 0 then
		slot.spells = CopyTable(source.spells)
	end
	if type(source.active) == 'table' and next(source.active) and not next(slot.active or {}) then
		slot.active = CopyTable(source.active)
	end
end

local function AdoptLegacyAnnouncer(profile, announcer)
	local sv = BUI.db and BUI.db.sv
	if type(sv) ~= 'table' or type(sv.profileKeys) ~= 'table' or type(sv.profiles) ~= 'table' then return end
	local profileName
	for name, saved in pairs(sv.profiles) do
		if saved == profile then profileName = name end
	end
	if not profileName then return end
	announcer.charSpells = type(announcer.charSpells) == 'table' and announcer.charSpells or {}
	for charKey, usedProfile in pairs(sv.profileKeys) do
		if usedProfile == profileName then
			local charData = type(sv.char) == 'table' and sv.char[charKey]
			local charScope = type(charData) == 'table' and charData.cdAnnouncer or nil
			local slotKey = AnnouncerSlotKey(charKey)
			local slot = type(announcer.charSpells[slotKey]) == 'table' and announcer.charSpells[slotKey] or {}
			if not slot._migrated then
				AdoptAnnouncerLists(slot, charScope)
				AdoptAnnouncerLists(slot, announcer)
				if next(slot) then announcer.charSpells[slotKey] = slot end
			end
		end
	end
end

local function SettleAnnouncerEntries(spells)
	for index = #spells, 1, -1 do
		local entry = spells[index]
		if type(entry) ~= 'table' or entry.kind == 'bloodlust' then table.remove(spells, index) end
	end
	for _, entry in ipairs(spells) do
		if type(entry.soundReady) == 'number' then entry.soundReady = nil end
		if entry.hideWhileOnCD == true then entry.cdPhase = false end
		entry.hideWhileOnCD, entry.fontPath, entry.readyIconSize = nil, nil, nil
		entry._cachedDuration, entry._cachedDurationFor = nil, nil
	end
end

local function SettleAnnouncer(profile)
	local announcer = profile.cdAnnouncer
	if type(announcer) ~= 'table' then return end
	local color = announcer.cdColor
	if type(color) == 'table' and color.r == 1 and color.g == 0.55 and color.b == 0.4 then
		color.r, color.g, color.b, color.a = 1, 1, 1, 1
	end
	AdoptLegacyAnnouncer(profile, announcer)
	announcer.spells, announcer.active = nil, nil
	if type(announcer.charSpells) ~= 'table' then return end
	for _, slot in pairs(announcer.charSpells) do
		if type(slot) == 'table' then
			slot._migrated = nil
			if type(slot.spells) == 'table' then SettleAnnouncerEntries(slot.spells) end
		end
	end
end

function BUI.MigrateProfile(profile)
	profile.general = profile.general or {}
	local general = profile.general
	if (general._buiMigrationVersion or 0) >= PROFILE_MIGRATION_VERSION then return end

	FixLegacyValues(profile, 1)

	if profile.unitFrames and not general._absorbColorBluFramesMigrated_v3 then
		general._absorbColorBluFramesMigrated_v3 = true
		profile.unitFrames.shieldColor           = { 1, 1, 1, 0.6 }
		profile.unitFrames.shieldDirection       = 'right'
		profile.unitFrames.shieldOverlay         = 'Stripes'
		profile.unitFrames.healAbsorbColor       = { 0.9, 0.1, 0.1, 0.6 }
		profile.unitFrames.healAbsorbDirection   = 'left'
		profile.unitFrames.healAbsorbOverlay     = 'Stripes'
		profile.unitFrames.shieldShowTexture     = nil
		profile.unitFrames.healAbsorbShowTexture = nil
	end

	if profile.unitFrames and not general._absorbColorGreenFix_v4 then
		general._absorbColorGreenFix_v4 = true
		profile.unitFrames.shieldColor = { 0, 1, 0.239, 0.5 }
	end

	if not general._fontShadowMigrated then
		general._fontShadowMigrated = true
		general.fontShadowEnabled = nil
		general.fontShadowX       = nil
		general.fontShadowY       = nil
		general.fontShadowAlpha   = nil
	end

	if profile.unitFrames and not general._dispelHighlightBluForced then
		general._dispelHighlightBluForced = true
		local deadKeys = { 'debuffHighlight', 'debuffHighlightAlert', 'debuffHighlightTint', 'debuffHighlightTintAlpha', 'debuffHighlightStripes', 'debuffHighlightStripeTexture', 'debuffHighlightStripeBlend', 'debuffHighlightStripeAlpha' }
		for _, unitKey in ipairs(LEGACY_UNIT_KEYS) do
			local unitTable = profile.unitFrames[unitKey]
			if type(unitTable) == 'table' then
				unitTable.debuffHighlightBar = true
				unitTable.debuffHighlightBadge = true
				unitTable.debuffHighlightClassFilter = true
				for _, deadKey in ipairs(deadKeys) do unitTable[deadKey] = nil end
			end
		end
	end

	if profile.unitFrames then
		local unitFrames = profile.unitFrames
		local mode = unitFrames.cdmSyncMode or (unitFrames.alignWithCDM and 'full') or 'off'
		if mode == 'full' or mode == 'positionOnly' then
			local shouldMatchHeight = mode == 'full'

			local UNIT_OF = { BUI_PlayerFrame = 'player', BUI_TargetFrame = 'target', BUI_FocusFrame = 'focus',
			                  BUI_PetFrame = 'pet', BUI_TargetTargetFrame = 'targettarget', BUI_FocusTargetFrame = 'focustarget' }
			local SELF_NAME = { player = 'BUI_PlayerFrame', target = 'BUI_TargetFrame', pet = 'BUI_PetFrame' }
			local function savedReaches(fromName, targetName)
				local name, depth = fromName, 0
				while name and depth < 16 do
					if name == targetName then return true end
					local unit = UNIT_OF[name]
					if not unit then return false end
					name = unitFrames[unit] and unitFrames[unit].anchorFrame
					depth = depth + 1
				end
				return false
			end
			local function migrate(unit, anchorFrame, point, matchWidth, matchHeight)
				unitFrames[unit] = unitFrames[unit] or {}
				if unitFrames[unit].anchorFrame and unitFrames[unit].anchorFrame ~= '' then return end
				if SELF_NAME[unit] and savedReaches(anchorFrame, SELF_NAME[unit]) then return end
				unitFrames[unit].anchorFrame = anchorFrame
				unitFrames[unit].anchorPoint = point
				unitFrames[unit].anchorOffsetX, unitFrames[unit].anchorOffsetY = 0, 0
				unitFrames[unit].matchAnchorWidth, unitFrames[unit].matchAnchorHeight = matchWidth, matchHeight
			end
			migrate('player', 'BUI_EssentialCooldownViewer', 'LEFT', false, shouldMatchHeight)
			migrate('target', 'BUI_EssentialCooldownViewer', 'RIGHT', false, shouldMatchHeight)
			if not unitFrames.excludePetFromSync then
				migrate('pet', 'BUI_PlayerFrame', 'LEFT', false, false)
			end
		end
		unitFrames.cdmSyncMode = nil
		unitFrames.cdmSyncSpacing = nil
		unitFrames.alignWithCDM = nil
		unitFrames.syncPositions = nil
		unitFrames._cdmPosCache = nil
		general._cdmSyncToAnchorMigrated = nil
	end

	if profile.unitFrames and not general._syncPlayerTargetOptIn then
		general._syncPlayerTargetOptIn = true
		if profile.unitFrames.syncPlayerTarget then
			profile.unitFrames.syncPlayerTarget = false
		end
	end

	if profile.unitFrames and not general._ufMatchWidthReset then
		general._ufMatchWidthReset = true
		for _, unit in ipairs(LEGACY_UNIT_KEYS) do
			local unitTable = profile.unitFrames[unit]
			if type(unitTable) == 'table' and unitTable.matchAnchorWidth then unitTable.matchAnchorWidth = false end
		end
	end

	if not general._cursorMasterUnified then
		general._cursorMasterUnified = true
		if profile.cursor and profile.cursor.enabled == false then
			profile.modules = profile.modules or {}
			profile.modules.cursor = false
		end
	end

	if not general._skinMasterRetired then
		general._skinMasterRetired = true
		local masterOn = profile.interface and profile.interface.skinBlizzardFrames == true
		local hasSkinningTable = type(profile.skinning) == 'table' and next(profile.skinning) ~= nil
		if not masterOn and not hasSkinningTable then
			profile.skinning = profile.skinning or {}
			local _, order = BUI.Skinning.GetSkinRegistry()
			for _, id in ipairs(order) do
				profile.skinning[id] = false
			end
		end
	end

	if not general._powerBarAnyAnchorMigrated then
		general._powerBarAnyAnchorMigrated = true
		local POWER_TAGS = { BUI_PowerBar = true, BUI_SecondaryPower = true }
		local function migrateAnchors(targetTable, depth)
			if type(targetTable) ~= 'table' or depth > 12 then return end
			for key, value in pairs(targetTable) do
				if (key == 'anchorFrame' or key == 'textAnchorFrame') and POWER_TAGS[value] then
					targetTable[key] = 'BUI_PowerBarAny'
				elseif type(value) == 'table' then
					migrateAnchors(value, depth + 1)
				end
			end
		end
		for key, value in pairs(profile) do
			if key ~= 'powerBar' and key ~= 'secondaryPower' and type(value) == 'table' then
				migrateAnchors(value, 1)
			end
		end
	end

	local interface = profile.interface
	if interface then
		if type(interface.minimapIconPos) == 'table' then
			local scales = type(interface.minimapIconScale) == 'table' and interface.minimapIconScale or {}
			local defaultScales = { queue = 0.8, difficulty = 0.9, mail = 0.8, crafting = 0.8, missions = 0.8 }
			for _, shapePositions in pairs(interface.minimapIconPos) do
				if type(shapePositions) == 'table' then
					for key, iconPosition in pairs(shapePositions) do
						if type(iconPosition) == 'table' and iconPosition.v == 2 then
							local scale = tonumber(scales[key]) or defaultScales[key] or 0.8
							if scale > 0 and type(iconPosition[2]) == 'number' and type(iconPosition[3]) == 'number' then
								iconPosition[2] = iconPosition[2] / scale
								iconPosition[3] = iconPosition[3] / scale
							end
							iconPosition.v = nil
						end
					end
				end
			end
		end
		interface.minimapDockOrder = nil
		interface.minimapIconFree = nil
		interface.minimapShape = nil
		if type(interface.minimapIconPos) == 'table' then
			interface.minimapIconPos.circle = nil
		end
	end

	if not general._rangeTagSeeded then
		general._rangeTagSeeded = true
		profile.unitFrames = profile.unitFrames or {}
		local targetSettings = profile.unitFrames.target
		if type(targetSettings) ~= 'table' then targetSettings = {}; profile.unitFrames.target = targetSettings end
		targetSettings.customTags = targetSettings.customTags or {}
		local exists = false
		for _, entry in ipairs(targetSettings.customTags) do
			if type(entry) == 'table' and type(entry.tag) == 'string' and entry.tag:find('[range]', 1, true) then
				exists = true
				break
			end
		end
		if not exists then
			targetSettings.customTags[#targetSettings.customTags + 1] = {
				name = 'Range', tag = '[range]', enabled = true,
				point = 'TOPRIGHT', x = 0, y = 16, fontSize = 12,
				color = { 1, 1, 1, 1 }, drawLayer = 'OVERLAY', drawSubLevel = 0,
			}
		end
	end

	if not general._dispelColorsShared then
		general._dispelColorsShared = true
		local legacyKeys = {
			dispelColorMagic   = 'dispel_magic',
			dispelColorCurse   = 'dispel_curse',
			dispelColorDisease = 'dispel_disease',
			dispelColorPoison  = 'dispel_poison',
			dispelColorBleed   = 'dispel_bleed',
		}
		local unitFrames = profile.unitFrames
		if type(unitFrames) == 'table' then
			profile.colors = profile.colors or {}
			for legacyKey, sharedKey in pairs(legacyKeys) do
				local legacyColor = unitFrames[legacyKey]
				if type(legacyColor) == 'table' and not profile.colors[sharedKey] then
					profile.colors[sharedKey] = {
						r = legacyColor[1], g = legacyColor[2], b = legacyColor[3], a = legacyColor[4] or 1,
					}
				end
				unitFrames[legacyKey] = nil
			end
		end
	end

	if not general._smoothBarsShared then
		general._smoothBarsShared = true
		local unitFrames, groupFrames = profile.unitFrames, profile.groupFrames
		if (type(unitFrames) == 'table' and unitFrames.smoothBars == false)
			or (type(groupFrames) == 'table' and groupFrames.smoothBars == false) then
			general.smoothBars = false
		end
		if type(unitFrames) == 'table' then unitFrames.smoothBars = nil end
		if type(groupFrames) == 'table' then groupFrames.smoothBars = nil end
	end

	profile.killCommandSend = nil

	if not general._actionBarFadePerBarMigrated then
		general._actionBarFadePerBarMigrated = true
		local actionBars = profile.actionBars
		if actionBars and (actionBars.fadeAnimated ~= nil or actionBars.fadeDuration ~= nil) then
			local function MigrateBar(barSettings)
				if type(barSettings) ~= 'table' then return end
				if actionBars.fadeAnimated ~= nil and barSettings.fadeAnimated == nil then barSettings.fadeAnimated = actionBars.fadeAnimated end
				if actionBars.fadeDuration ~= nil and barSettings.fadeDuration == nil then barSettings.fadeDuration = actionBars.fadeDuration end
			end
			if type(actionBars.bars) == 'table' then
				for _, barSettings in pairs(actionBars.bars) do MigrateBar(barSettings) end
			end
			for _, settingsKey in ipairs({ 'petBar', 'stanceBar', 'vehicleBar', 'microBar', 'bagBar', 'extraBar' }) do
				MigrateBar(actionBars[settingsKey])
			end
			actionBars.fadeAnimated = nil
			actionBars.fadeDuration = nil
		end
	end

	if not general._ldbDatatextsRemoved then
		general._ldbDatatextsRemoved = true
		local function StripLDB(config)
			if type(config) ~= 'table' then return end
			for key in pairs(config) do
				if type(key) == 'string' and key:sub(1, 7) == 'showLDB' then config[key] = nil end
			end
			if type(config.order) == 'table' then
				local kept = {}
				for orderIndex = 1, #config.order do
					local id = config.order[orderIndex]
					if not (type(id) == 'string' and id:sub(1, 4) == 'ldb:') then kept[#kept + 1] = id end
				end
				config.order = kept
			end
		end
		if type(profile.datatextBars) == 'table' then
			for _, barConfig in pairs(profile.datatextBars) do StripLDB(barConfig) end
		end
		StripLDB(profile.datatextMinimap)
	end

	if not general._combatAlertsSplit then
		general._combatAlertsSplit = true
		local skinning = profile.skinning
		if type(skinning) == 'table' and skinning.combatalerts ~= nil then
			skinning.deathrecap = skinning.combatalerts
			skinning.mirrortimers = skinning.combatalerts
		end
	end

	if not general._datatextLabelsSplit then
		general._datatextLabelsSplit = true
		local entries = BUI.Datatext.List()
		local function SplitLabels(config)
			if type(config) ~= 'table' then return end
			if config.hideLabels then
				for _, entry in ipairs(entries) do config[entry.hideLabel] = true end
			end
			config.hideLabels = nil
		end
		if type(profile.datatextBars) == 'table' then
			for _, barConfig in pairs(profile.datatextBars) do SplitLabels(barConfig) end
		end
		SplitLabels(profile.datatextMinimap)
	end

	if not general._minimapDatatextAligned then
		general._minimapDatatextAligned = true
		local minimapBar = profile.datatextMinimap
		if type(minimapBar) == 'table' and minimapBar.spread ~= nil then
			if minimapBar.spread == true or (tonumber(minimapBar.spread) or 0) > 0 then minimapBar.align = 'SPREAD' end
			minimapBar.spread = nil
		end
	end

	if not general._addonButtonsMode then
		general._addonButtonsMode = true
		local interface = profile.interface
		if type(interface) == 'table' then
			local buttonBar = interface.buttonBar
			if type(buttonBar) == 'table' and buttonBar.enabled then
				interface.addonButtons = 'BAR'
			elseif interface.drawerEnabled == false then
				interface.addonButtons = 'NONE'
			end
			interface.drawerEnabled = nil
			if type(buttonBar) == 'table' then buttonBar.enabled = nil end
		end
	end

	if not general._dashboardLayoutFixed then
		general._dashboardLayoutFixed = true
		local dashboard = profile.dashboard
		if type(dashboard) == 'table' then dashboard.layout, dashboard.topCols = nil, nil end
	end

	if not general._dispelBorderDropped then
		general._dispelBorderDropped = true
		if type(profile.unitFrames) == 'table' then
			for _, unitKey in ipairs(LEGACY_UNIT_KEYS) do
				local unitTable = profile.unitFrames[unitKey]
				if type(unitTable) == 'table' then
					if unitTable.debuffHighlightBorder == false and rawget(unitTable, 'debuffHighlightBar') == nil then unitTable.debuffHighlightBar = false end
					unitTable.debuffHighlightBorder = nil
					if unitTable.debuffHighlightStyle == 'strip' then unitTable.debuffHighlightStyle = 'bar' end
				end
			end
		end
		if type(profile.groupFrames) == 'table' then
			for _, sectionKey in ipairs({ 'party', 'raid' }) do
				local section = profile.groupFrames[sectionKey]
				local border = type(section) == 'table' and section.dispelBorder
				if type(border) == 'table' then
					if border.enabled == false and rawget(border, 'tintBar') == nil then border.tintBar = false end
					border.enabled = nil
					if border.tintStyle == 'strip' then border.tintStyle = 'bar' end
				end
			end
		end
	end

	if not general._statusColorsShared then
		general._statusColorsShared = true
		local groupFrames = type(profile.groupFrames) == 'table' and profile.groupFrames
		local raid = groupFrames and type(groupFrames.raid) == 'table' and groupFrames.raid
		local raidColors = raid and type(raid.statusText) == 'table' and rawget(raid.statusText, 'colors')
		if type(raidColors) == 'table' then
			if type(profile.unitFrames) ~= 'table' then profile.unitFrames = {} end
			local shared = rawget(profile.unitFrames, 'statusColors') or {}
			profile.unitFrames.statusColors = shared
			for status, color in pairs(raidColors) do shared[status] = CopyTable(color) end
		end
		for _, sectionKey in ipairs({ 'party', 'raid' }) do
			local section = groupFrames and type(groupFrames[sectionKey]) == 'table' and groupFrames[sectionKey]
			if section and type(section.statusText) == 'table' then section.statusText.colors = nil end
		end
	end

	if not general._customTagFields then
		general._customTagFields = true
		local unitFrames = type(profile.unitFrames) == 'table' and profile.unitFrames or {}
		for _, unit in pairs(unitFrames) do
			local tags = type(unit) == 'table' and rawget(unit, 'customTags')
			for _, entry in ipairs(type(tags) == 'table' and tags or {}) do
				if type(entry) == 'table' then
					if entry.point == nil then entry.point = 'CENTER' end
					if entry.x == nil then entry.x = 0 end
					if entry.y == nil then entry.y = 0 end
					if entry.fontSize == nil then entry.fontSize = 12 end
					if entry.color == nil then entry.color = { 1, 1, 1, 1 } end
					if entry.drawLayer == nil then entry.drawLayer = 'OVERLAY' end
					if entry.drawSubLevel == nil then entry.drawSubLevel = 0 end
				end
			end
		end
	end

	if not general._textDefaultsShared then
		general._textDefaultsShared = true
		local unitFrames = type(profile.unitFrames) == 'table' and profile.unitFrames or {}
		local sizes = {
			player = { nameTextSize = 12, healthTextSize = 12, powerTextSize = 11 },
			target = { nameTextSize = 12, healthTextSize = 12, powerTextSize = 10 },
			targettarget = { nameTextSize = 10, healthTextSize = 10, powerTextSize = 8 },
			focus = { nameTextSize = 11, healthTextSize = 11, powerTextSize = 9 },
			focustarget = { nameTextSize = 10, healthTextSize = 10, powerTextSize = 8 },
			pet = { nameTextSize = 10, healthTextSize = 10, powerTextSize = 8 },
			boss = { nameTextSize = 11, healthTextSize = 10, powerTextSize = 9 },
		}
		local stash = rawget(unitFrames, '_syncStash')
		for unitKey, old in pairs(sizes) do
			local unit = unitFrames[unitKey]
			if type(unit) == 'table' then
				local source = (type(stash) == 'table' and stash[unitKey]) and sizes.player or old
				for key, value in pairs(source) do
					if rawget(unit, key) == nil then unit[key] = value end
				end
			end
		end
	end

	if not general._healingBuffsDefault then
		general._healingBuffsDefault = true
		if type(profile.unitFrames) ~= 'table' then profile.unitFrames = {} end
		if type(profile.unitFrames.player) ~= 'table' then profile.unitFrames.player = {} end
		PutHealingBuffsFirst(profile.unitFrames.player, 'buffRules', 'allHelpful')
		if type(profile.groupFrames) ~= 'table' then profile.groupFrames = {} end
		if type(profile.groupFrames.raid) ~= 'table' then profile.groupFrames.raid = {} end
		if type(profile.groupFrames.raid.buffs) ~= 'table' then profile.groupFrames.raid.buffs = {} end
		PutHealingBuffsFirst(profile.groupFrames.raid.buffs, 'rules', 'raidRelevant')
	end

	if not general._customBarsInCDM then
		general._customBarsInCDM = true
		local modules = type(profile.modules) == 'table' and profile.modules
		if modules then
			if modules.customBars == false or modules.tracking == false then
				for _, key in ipairs({ 'customBars', 'trackingBars' }) do
					for _, bar in ipairs(type(profile[key]) == 'table' and profile[key] or {}) do
						if type(bar) == 'table' then bar.enabled = false end
					end
				end
			end
			modules.customBars, modules.tracking = nil, nil
		end
	end

	if not general._fadeTimeOnly then
		general._fadeTimeOnly = true
		local function FoldAnimated(settings)
			if type(settings) ~= 'table' then return end
			if settings.fadeAnimated == false then settings.fadeDuration = 0 end
			settings.fadeAnimated = nil
		end
		FoldAnimated(profile.markers)
		local actionBars = profile.actionBars
		if type(actionBars) == 'table' then
			for _, barSettings in pairs(type(actionBars.bars) == 'table' and actionBars.bars or {}) do FoldAnimated(barSettings) end
			for _, settingsKey in ipairs({ 'petBar', 'stanceBar', 'vehicleBar', 'microBar', 'bagBar', 'extraBar' }) do
				FoldAnimated(actionBars[settingsKey])
			end
		end
	end

	if not general._buffFramesOwnBlacklist then
		general._buffFramesOwnBlacklist = true
		KeepBuffFrameBlacklist(profile, general._oneBlacklist == true)
	end

	if not general._oneBlacklist then
		general._oneBlacklist = true
		local groupFrames = type(profile.groupFrames) == 'table' and profile.groupFrames
		if groupFrames then
			groupFrames.blacklistOverrides = type(groupFrames.blacklistOverrides) == 'table' and groupFrames.blacklistOverrides or {}
			local overrides = groupFrames.blacklistOverrides
			local filters = type(profile.auraFilters) == 'table' and profile.auraFilters or {}
			local function Merge(key, polarity, list)
				if type(list) ~= 'table' then return end
				overrides[key] = type(overrides[key]) == 'table' and overrides[key] or {}
				local curated = BUI.AuraBlacklist.Curated(polarity)
				for spellID in pairs(list) do
					if curated[spellID] then overrides[key][spellID] = nil else overrides[key][spellID] = 'hide' end
				end
			end
			Merge('buff', 'HELPFUL', filters.buffBlacklist)
			Merge('debuff', 'HARMFUL', filters.debuffBlacklist)
			if type(profile.auraFilters) == 'table' then profile.auraFilters.shareBlacklists = true end
			BUI.AuraBlacklist.Invalidate()
		end
	end

	if not general._auraRuleListsSettled then
		general._auraRuleListsSettled = true
		if type(profile.unitFrames) == 'table' then SettleUnitAuraRules(profile.unitFrames) end
	end

	if not general._bossRoleRulesMerged then
		general._bossRoleRulesMerged = true
		MergeRetiredRuleLists(profile)
	end

	if not general._legacySkinIdsDropped then
		general._legacySkinIdsDropped = true
		local skinning = profile.skinning
		if type(skinning) == 'table' then
			for id, info in pairs(BUI.Skinning.GetSkinRegistry()) do
				if LEGACY_SKIN_IDS[info.legacy] and skinning[id] == nil and skinning[info.legacy] == false then skinning[id] = false end
			end
			for id in pairs(LEGACY_SKIN_IDS) do skinning[id] = nil end
		end
	end

	if not general._customBarShapesSettled then
		general._customBarShapesSettled = true
		SettleCustomBarShapes(profile)
	end

	if not general._cdmLoginShimsSettled then
		general._cdmLoginShimsSettled = true
		local cdm = profile.cdm
		if type(cdm) == 'table' then
			local validGlowTypes = {}
			for _, entry in ipairs(BUI.CDM.GLOW_TYPES) do validGlowTypes[entry.id] = true end
			SettleGlowTypes(cdm, validGlowTypes)
			for _, key in ipairs(CDM_VIEWER_KEYS) do
				local viewer = cdm[key]
				if type(viewer) == 'table' then
					viewer._pxW, viewer._pxH, viewer._pxGap = nil, nil, nil
					SettleIconOrderKeys(viewer.iconOrder)
					if key ~= 'buffs' then StripAutoSlots(viewer.customSpells) end
				end
			end
			if type(cdm.assist) == 'table' then cdm.assist.enabled = nil end
			MergePotionPrios(cdm, profile.customBars)
		end
	end

	if not general._insideAuraOffsetsZeroed then
		general._insideAuraOffsetsZeroed = true
		ZeroInsideAuraOffsets(profile)
	end

	if not general._visibilityPrioritySettled then
		general._visibilityPrioritySettled = true
		SettleVisibilityPriority(general)
	end

	if not general._retiredKeysDropped then
		general._retiredKeysDropped = true
		DropRetiredKeys(profile)
	end

	if not general._minimapEnabledFolded then
		general._minimapEnabledFolded = true
		local interface = profile.interface
		if type(interface) == 'table' then
			if interface.minimapEnabled == false then
				profile.modules = type(profile.modules) == 'table' and profile.modules or {}
				profile.modules.minimap = false
			end
			interface.minimapEnabled = nil
		end
	end

	if not general._classicPowerStackRetired then
		general._classicPowerStackRetired = true
		general._classicPowerStackMigrated = nil
		RetireClassicPowerStacks(profile)
	end

	if not general._moveFramesModeSettled then
		general._moveFramesModeSettled = true
		SettleMoveFramesMode(profile.moveFrames)
	end

	if not general._cdAnnouncerSettled then
		general._cdAnnouncerSettled = true
		SettleAnnouncer(profile)
	end

	general._buiMigrationVersion = PROFILE_MIGRATION_VERSION
end

function BUI.RunMigrations()
	local global = BUI.db.global
	global.cdmProfile = nil
	if not global._layoutCenteredMigrated then
		global._layoutCenteredMigrated = true
		global.layoutStyle = 'centered'
	end
	if global.charTrackingSpells then
		global.charCustomBarsSpells = global.charCustomBarsSpells or global.charTrackingSpells
		global.charTrackingSpells = nil
	end

	for _, profile in pairs(BUI.db.profiles) do
		BUI.MigrateProfile(profile)
	end

	if not global._cdAnnouncerCharScopeCleared then
		global._cdAnnouncerCharScopeCleared = true
		local sv = BUI.db.sv
		for _, charData in pairs(type(sv) == 'table' and type(sv.char) == 'table' and sv.char or {}) do
			if type(charData) == 'table' then charData.cdAnnouncer = nil end
		end
	end
end
