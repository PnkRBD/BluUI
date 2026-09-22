local _, BUI = ...

local Pixel = BUI.Pixel
local UnitFrames = BUI.UnitFrames
local Tools = BUI.Tools
local oUF = BUI.oUF

local floor = math.floor
local format = string.format
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local type = type
local unpack = unpack
local wipe = wipe

local AbbreviateNumbers = AbbreviateNumbers
local GetRealmName = GetRealmName
local IsResting = IsResting
local UnitAffectingCombat = UnitAffectingCombat
local UnitClass = UnitClass
local UnitClassification = UnitClassification
local UnitCreatureFamily = UnitCreatureFamily
local UnitCreatureType = UnitCreatureType
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitHealthPercent = UnitHealthPercent
local UnitIsAFK = UnitIsAFK
local UnitIsConnected = UnitIsConnected
local UnitIsDND = UnitIsDND
local UnitIsDead = UnitIsDead
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local UnitIsPlayer = UnitIsPlayer
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerPercent = UnitPowerPercent
local UnitPowerType = UnitPowerType
local UnitRace = UnitRace
local UnitReaction = UnitReaction
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitPVPName = UnitPVPName
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local GetAverageItemLevel = GetAverageItemLevel
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetSpecializationInfoByID = GetSpecializationInfoByID
local GetInspectSpecialization = GetInspectSpecialization
local GetInstanceInfo = GetInstanceInfo
local GetDifficultyInfo = GetDifficultyInfo
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local IsInRaid = IsInRaid
local issecretvalue = issecretvalue

local ScaleTo100 = CurveConstants.ScaleTo100
local PowerTypeMana = Enum.PowerType.Mana

local function TintHex(red, green, blue, brightness)
	local factor = brightness
	return format('%02x%02x%02x',
		floor(red * factor * 255 + 0.5),
		floor(green * factor * 255 + 0.5),
		floor(blue * factor * 255 + 0.5))
end

local restingFrames = {}
local restingIndex = 1
local restingTicker

local function BuildRestingFrames(red, green, blue)
	red, green, blue = red or 1, green or 1, blue or 1
	wipe(restingFrames)

	local steps = {
		{1.0, 0.5, 0.3},  {0.8, 0.7, 0.3},  {0.55, 1.0, 0.37},
		{0.4, 0.8, 0.55}, {0.3, 0.55, 1.0},  {0.3, 0.4, 0.8},
		{0.3, 0.3, 0.55}, {0.3, 0.3, 0.37},  {0.37, 0.3, 0.3},
		{0.55, 0.3, 0.3}, {0.75, 0.37, 0.3},  {0.9, 0.4, 0.3},
	}
	for stepIndex, step in ipairs(steps) do
		restingFrames[stepIndex] = '|cff' .. TintHex(red, green, blue, step[1]) .. 'Z|r'
			.. '|cff' .. TintHex(red, green, blue, step[2]) .. 'z|r'
			.. '|cff' .. TintHex(red, green, blue, step[3]) .. 'z|r'
	end
end

function UnitFrames.SetRestingAnimation(red, green, blue)
	BuildRestingFrames(red, green, blue)
end

BuildRestingFrames(1, 1, 1)

local AbbrevDataDecimal = {
	breakpointData = {
		{breakpoint = 1e12, abbreviation = 'T', significandDivisor = 1e10, fractionDivisor = 100, abbreviationIsGlobal = false},
		{breakpoint = 1e11, abbreviation = 'B', significandDivisor = 1e8,  fractionDivisor = 10,  abbreviationIsGlobal = false},
		{breakpoint = 1e10, abbreviation = 'B', significandDivisor = 1e8,  fractionDivisor = 10,  abbreviationIsGlobal = false},
		{breakpoint = 1e9,  abbreviation = 'B', significandDivisor = 1e7,  fractionDivisor = 100, abbreviationIsGlobal = false},
		{breakpoint = 1e8,  abbreviation = 'M', significandDivisor = 1e5,  fractionDivisor = 10,  abbreviationIsGlobal = false},
		{breakpoint = 1e7,  abbreviation = 'M', significandDivisor = 1e5,  fractionDivisor = 10,  abbreviationIsGlobal = false},
		{breakpoint = 1e6,  abbreviation = 'M', significandDivisor = 1e4,  fractionDivisor = 100, abbreviationIsGlobal = false},
		{breakpoint = 1e5,  abbreviation = 'K', significandDivisor = 100,  fractionDivisor = 10,  abbreviationIsGlobal = false},
		{breakpoint = 1e4,  abbreviation = 'K', significandDivisor = 100,  fractionDivisor = 10,  abbreviationIsGlobal = false},
		{breakpoint = 1e3,  abbreviation = 'K', significandDivisor = 10,   fractionDivisor = 100, abbreviationIsGlobal = false},
	},
}

local useDecimalAbbreviations = false

function UnitFrames.RefreshAbbreviationSetting()
	local db = BUI.db and BUI.db.profile
	useDecimalAbbreviations = db and db.general and db.general.showDecimalAbbreviations or false
end

local function Abbreviate(number)
	if not number then return '0' end
	if useDecimalAbbreviations then
		return AbbreviateNumbers(number, AbbrevDataDecimal)
	end
	return AbbreviateNumbers(number)
end

local ALL = {player = true, target = true, targettarget = true, focus = true, pet = true, boss = true}
local PLAYER_ONLY = {player = true}
local NO_PET = {player = true, target = true, targettarget = true, focus = true, boss = true}
local PLAYERS = {player = true, target = true, targettarget = true, focus = true}
local HOSTILE = {target = true, targettarget = true, focus = true, boss = true}
local TARGETABLE = {player = true, target = true, targettarget = true, focus = true, pet = true, boss = true}
local CREATURES = {target = true, targettarget = true, focus = true, pet = true, boss = true}

local TagMeta = {
	['hp']             = {u = ALL,        d = 'Current HP or Dead'},
	['hp:short']       = {u = ALL,        d = 'HP abbreviated or Dead'},
	['maxhp']          = {u = ALL,        d = 'Max HP'},
	['maxhp:short']    = {u = ALL,        d = 'Max HP abbreviated'},
	['perhp']          = {u = ALL,        d = 'HP percent'},
	['pp']             = {u = ALL,        d = 'Current power'},
	['pp:short']       = {u = ALL,        d = 'Power abbreviated'},
	['maxpp']          = {u = ALL,        d = 'Max power'},
	['maxpp:short']    = {u = ALL,        d = 'Max power abbreviated'},
	['perpp']          = {u = ALL,        d = 'Power percent'},
	['mana']           = {u = ALL,        d = 'Current mana'},
	['mana:short']     = {u = ALL,        d = 'Mana abbreviated'},
	['maxmana']        = {u = ALL,        d = 'Max mana'},
	['maxmana:short']  = {u = ALL,        d = 'Max mana abbreviated'},
	['permana']        = {u = ALL,        d = 'Mana percent'},
	['powertype']      = {u = ALL,        d = 'Power type name'},
	['absorbs']        = {u = ALL,        d = 'Absorb shield amount'},
	['hpabsorb']       = {u = ALL,        d = 'HP plus absorb shield'},
	['hpabsorb:short'] = {u = ALL,        d = 'HP plus absorb (abbreviated)'},
	['name']           = {u = ALL,        d = 'Unit name'},
	['name:short']     = {u = ALL,        d = 'Name truncated (10 chars)'},
	['level']          = {u = ALL,        d = 'Unit level'},
	['class']          = {u = PLAYERS,    d = 'Class uppercase'},
	['classname']      = {u = PLAYERS,    d = 'Class name'},
	['race']           = {u = PLAYERS,    d = 'Race'},
	['classification'] = {u = HOSTILE,    d = 'Elite/Rare/Boss'},
	['status']         = {u = ALL,        d = 'Dead/Ghost/Offline'},
	['dead']           = {u = ALL,        d = 'Dead indicator'},
	['offline']        = {u = NO_PET,     d = 'Offline indicator'},
	['afk']            = {u = NO_PET,     d = 'AFK indicator'},
	['dnd']            = {u = NO_PET,     d = 'DND indicator'},
	['resting']        = {u = PLAYER_ONLY,d = 'Resting indicator'},
	['combat']         = {u = ALL,        d = 'In combat indicator'},
	['combattime']     = {u = PLAYER_ONLY,d = 'Combat duration timer'},
	['creature']       = {u = CREATURES,  d = 'Pet family or creature type'},
	['creaturefamily'] = {u = CREATURES,  d = 'Pet family'},
	['creaturetype']   = {u = CREATURES,  d = 'Creature type'},
	['server']         = {u = ALL,        d = 'Server name'},
	['target']         = {u = TARGETABLE, d = "Target's name"},
	['name:target']    = {u = TARGETABLE, d = 'Name > Target'},
	['group']          = {u = ALL,        d = 'Raid group number'},
	['itemlevel']      = {u = NO_PET,     d = 'Item level'},
	['spec']           = {u = PLAYERS,    d = 'Specialization name'},
	['title']          = {u = PLAYERS,    d = 'Player title'},
	['difficulty']     = {u = PLAYER_ONLY,d = 'Instance difficulty'},
	['role']           = {u = NO_PET,     d = 'Role icon (tank/healer/dps)'},
	['role:text']      = {u = NO_PET,     d = 'Role text (Tank/Healer/DPS)'},
	['threat']         = {u = PLAYER_ONLY,d = 'Threat % on target'},
	['range']          = {u = HOSTILE,    d = 'Distance estimate in yards'},
}

local TagEvents = {
	['hp']             = 'UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION',
	['hp:short']       = 'UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION',
	['maxhp']          = 'UNIT_MAXHEALTH',
	['maxhp:short']    = 'UNIT_MAXHEALTH',
	['perhp']          = 'UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION',

	['pp']             = 'UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_DISPLAYPOWER',
	['pp:short']       = 'UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_DISPLAYPOWER',
	['maxpp']          = 'UNIT_MAXPOWER UNIT_DISPLAYPOWER',
	['maxpp:short']    = 'UNIT_MAXPOWER UNIT_DISPLAYPOWER',
	['perpp']          = 'UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_DISPLAYPOWER',
	['mana']           = 'UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_DISPLAYPOWER',
	['mana:short']     = 'UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_DISPLAYPOWER',
	['maxmana']        = 'UNIT_MAXPOWER',
	['maxmana:short']  = 'UNIT_MAXPOWER',
	['permana']        = 'UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_DISPLAYPOWER',
	['powertype']      = 'UNIT_DISPLAYPOWER',
	['absorbs']        = 'UNIT_ABSORB_AMOUNT_CHANGED',
	['hpabsorb']       = 'UNIT_HEALTH UNIT_MAXHEALTH UNIT_ABSORB_AMOUNT_CHANGED UNIT_CONNECTION',
	['hpabsorb:short'] = 'UNIT_HEALTH UNIT_MAXHEALTH UNIT_ABSORB_AMOUNT_CHANGED UNIT_CONNECTION',
	['name']           = 'UNIT_NAME_UPDATE',
	['name:short']     = 'UNIT_NAME_UPDATE',
	['level']          = 'UNIT_LEVEL PLAYER_LEVEL_UP',
	['class']          = 'UNIT_NAME_UPDATE',
	['classname']      = 'UNIT_NAME_UPDATE',
	['race']           = 'UNIT_NAME_UPDATE',
	['classification'] = 'UNIT_CLASSIFICATION_CHANGED',
	['status']         = 'UNIT_HEALTH UNIT_CONNECTION',
	['dead']           = 'UNIT_HEALTH',
	['offline']        = 'UNIT_CONNECTION',
	['afk']            = 'PLAYER_FLAGS_CHANGED',
	['dnd']            = 'PLAYER_FLAGS_CHANGED',
	['resting']        = 'PLAYER_UPDATE_RESTING',
	['combat']         = 'PLAYER_REGEN_ENABLED PLAYER_REGEN_DISABLED',
	['combattime']     = 'PLAYER_REGEN_ENABLED PLAYER_REGEN_DISABLED',
	['creature']       = 'UNIT_NAME_UPDATE',
	['creaturefamily'] = 'UNIT_NAME_UPDATE',
	['creaturetype']   = 'UNIT_NAME_UPDATE',
	['server']         = 'UNIT_NAME_UPDATE',
	['target']         = 'UNIT_TARGET UNIT_NAME_UPDATE',
	['name:target']    = 'UNIT_TARGET UNIT_NAME_UPDATE',
	['group']          = 'GROUP_ROSTER_UPDATE',
	['itemlevel']      = 'INSPECT_READY UNIT_NAME_UPDATE',
	['spec']           = 'PLAYER_SPECIALIZATION_CHANGED UNIT_NAME_UPDATE',
	['title']          = 'UNIT_NAME_UPDATE',
	['difficulty']     = 'PLAYER_DIFFICULTY_CHANGED ZONE_CHANGED_NEW_AREA',
	['role']           = 'PLAYER_ROLES_ASSIGNED GROUP_ROSTER_UPDATE',
	['role:text']      = 'PLAYER_ROLES_ASSIGNED GROUP_ROSTER_UPDATE',
	['threat']         = 'UNIT_THREAT_LIST_UPDATE UNIT_THREAT_SITUATION_UPDATE PLAYER_TARGET_CHANGED',
	['range']          = 'PLAYER_TARGET_CHANGED PLAYER_FOCUS_CHANGED',
}

local parentUnitCache = {}
local function GetParentUnitType(unit)
	local cached = parentUnitCache[unit]
	if cached then return cached end
	local result
	if unit:match('^boss%d') then result = 'boss'
	elseif unit:match('target$') then
		local parent = unit:gsub('target$', '')
		if parent:match('^boss%d') then result = 'boss'
		elseif parent == '' then result = 'target'
		else result = parent end
	else result = unit end
	parentUnitCache[unit] = result
	return result
end

local reactionColorCache = {}
do
	local originalInvalidate = UnitFrames.InvalidateSettingsCache
	UnitFrames.InvalidateSettingsCache = function(...)
		wipe(reactionColorCache)
		return originalInvalidate(...)
	end
end

local function GetReactionColorCode(unit, parentUnitType)
	local reaction = UnitReaction(unit, 'player')
	if not reaction then return nil end
	local bucket = reaction >= 5 and 'friendlyNameColor'
		or reaction >= 4 and 'neutralNameColor'
		or 'hostileNameColor'
	local parentType = parentUnitType or GetParentUnitType(unit)
	local cacheKey = parentType .. ':' .. bucket
	local cached = reactionColorCache[cacheKey]
	if cached then return cached ~= '' and cached or nil end
	local unitSettings = UnitFrames.GetUnitSettings(parentType)
	local reactionColor = unitSettings and unitSettings[bucket]
	if reactionColor then
		local code = format('|cFF%02x%02x%02x', reactionColor[1] * 255, reactionColor[2] * 255, reactionColor[3] * 255)
		reactionColorCache[cacheKey] = code
		return code
	end
	reactionColorCache[cacheKey] = ''
	return nil
end

local function ClassColoredName(unit, name, parentUnitType)
	if not name then return '' end
	if issecretvalue(name) then
		if UnitIsPlayer(unit) then
			local red, green, blue = BUI.Tools.GetUnitClassColor(unit)
			if red then
				return format('|cFF%02x%02x%02x', red * 255, green * 255, blue * 255) .. name .. '|r'
			end
		else
			local code = GetReactionColorCode(unit, parentUnitType)
			if code then return code .. name .. '|r' end
		end
		return name
	end
	if type(name) ~= 'string' or name == '' then return '' end
	if UnitIsPlayer(unit) then
		local red, green, blue = BUI.Tools.GetUnitClassColor(unit)
		if red then
			return format('|cFF%02x%02x%02x%s|r', red * 255, green * 255, blue * 255, name)
		end
	else
		local code = GetReactionColorCode(unit, parentUnitType)
		if code then return format('%s%s|r', code, name) end
	end
	return name
end

local combatStartTime = 0
local combatTimerText = ''

local function FormatCombatTime(seconds)
	local minutes = floor(seconds / 60)
	local wholeSeconds = floor(seconds % 60)
	local tenths = floor((seconds * 10) % 10)
	return format('%02d:%02d.%d', minutes, wholeSeconds, tenths)
end

local Handlers = {
	['hp'] = function(unit)
		if UnitIsDeadOrGhost(unit) then return 'Dead' end
		return tostring(UnitHealth(unit))
	end,
	['hp:short'] = function(unit)
		if UnitIsDeadOrGhost(unit) then return 'Dead' end
		return Abbreviate(UnitHealth(unit))
	end,
	['maxhp'] = function(unit) return tostring(UnitHealthMax(unit)) end,
	['maxhp:short'] = function(unit) return Abbreviate(UnitHealthMax(unit)) end,
	['perhp'] = function(unit) return format('%d', UnitHealthPercent(unit, true, ScaleTo100)) end,
	['pp'] = function(unit) return tostring(UnitPower(unit)) end,
	['pp:short'] = function(unit) return Abbreviate(UnitPower(unit)) end,
	['maxpp'] = function(unit) return tostring(UnitPowerMax(unit)) end,
	['maxpp:short'] = function(unit) return Abbreviate(UnitPowerMax(unit)) end,
	['perpp'] = function(unit) return format('%d', UnitPowerPercent(unit, nil, true, ScaleTo100)) end,
	['mana'] = function(unit) return tostring(UnitPower(unit, PowerTypeMana)) end,
	['mana:short'] = function(unit) return Abbreviate(UnitPower(unit, PowerTypeMana)) end,
	['maxmana'] = function(unit) return tostring(UnitPowerMax(unit, PowerTypeMana)) end,
	['maxmana:short'] = function(unit) return Abbreviate(UnitPowerMax(unit, PowerTypeMana)) end,
	['permana'] = function(unit)
		return format('%d', UnitPowerPercent(unit, PowerTypeMana, true, ScaleTo100))
	end,
	['powertype'] = function(unit) local _, tokenName = UnitPowerType(unit) return tokenName or 'Mana' end,
	['absorbs'] = function(unit) return Abbreviate(UnitGetTotalAbsorbs(unit)) end,
	['hpabsorb'] = function(unit)
		if UnitIsDeadOrGhost(unit) then return 'Dead' end
		local health = UnitHealth(unit) or 0
		local absorb = UnitGetTotalAbsorbs(unit) or 0
		return tostring(health + absorb)
	end,
	['hpabsorb:short'] = function(unit)
		if UnitIsDeadOrGhost(unit) then return 'Dead' end
		local health = UnitHealth(unit) or 0
		local absorb = UnitGetTotalAbsorbs(unit) or 0
		return Abbreviate(health + absorb)
	end,
	['name'] = function(unit) return UnitName(unit) or '' end,
	['name:short'] = function(unit) local name = UnitName(unit) return name and Tools.TruncateName(name, 10) or '' end,
	['level'] = function(unit) local level = UnitLevel(unit) return level == -1 and '??' or tostring(level) end,
	['class'] = function(unit) local _, class = UnitClass(unit) return class or '' end,
	['classname'] = function(unit) return UnitClass(unit) or '' end,
	['race'] = function(unit) return UnitRace(unit) or '' end,
	['classification'] = function(unit)
		local classification = UnitClassification(unit)
		if classification == 'worldboss' then return 'Boss'
		elseif classification == 'rareelite' then return 'Rare+'
		elseif classification == 'elite' then return '+'
		elseif classification == 'rare' then return 'Rare' end
		return ''
	end,
	['status'] = function(unit)
		if not UnitIsConnected(unit) then return 'Offline'
		elseif UnitIsGhost(unit) then return 'Ghost'
		elseif UnitIsDead(unit) then return 'Dead' end
		return ''
	end,
	['dead'] = function(unit)
		if UnitIsGhost(unit) then return 'Ghost' end
		if UnitIsDead(unit) then return 'Dead' end
		return ''
	end,
	['offline'] = function(unit) return not UnitIsConnected(unit) and 'Offline' or '' end,
	['afk'] = function(unit) return UnitIsAFK(unit) and 'AFK' or '' end,
	['dnd'] = function(unit) return UnitIsDND(unit) and 'DND' or '' end,

	['resting'] = function() return IsResting() and restingFrames[restingIndex] or '' end,
	['combat'] = function(unit) return UnitAffectingCombat(unit) and '|TInterface\\AddOns\\BluUI\\Media\\Textures\\combat:14:14|t' or '' end,
	['combattime'] = function() return combatTimerText or '' end,
	['range'] = function(unit) return BUI.Range.DisplayText(unit) or '' end,
	['threat'] = function()
		if not UnitExists('target') then return '' end
		local _, _, threatPercent = UnitDetailedThreatSituation('player', 'target')
		if threatPercent and not issecretvalue(threatPercent) then return format('%d%%', threatPercent) end
		return ''
	end,
	['creature'] = function(unit) return UnitCreatureFamily(unit) or UnitCreatureType(unit) or '' end,
	['creaturefamily'] = function(unit) return UnitCreatureFamily(unit) or '' end,
	['creaturetype'] = function(unit) return UnitCreatureType(unit) or '' end,
	['server'] = function(unit) local _, realm = UnitName(unit) return realm or GetRealmName() or '' end,
	['group'] = function(unit)
		if not IsInRaid() then return '' end
		local name = UnitName(unit)
		if not name then return '' end
		for memberIndex = 1, GetNumGroupMembers() do
			local rosterName, _, subgroup = GetRaidRosterInfo(memberIndex)
			if rosterName == name then return tostring(subgroup) end
		end
		return ''
	end,
	['target'] = function(unit)
		local targetUnit = unit .. 'target'
		local targetName = UnitName(targetUnit)
		return targetName and ClassColoredName(targetUnit, targetName, GetParentUnitType(unit)) or ''
	end,
	['name:target'] = function(unit)
		local name = UnitName(unit) or ''
		local targetUnit = unit .. 'target'
		local targetName = UnitName(targetUnit)
		if targetName then
			return format('%s |cFFFFFFFF>|r %s', name, ClassColoredName(targetUnit, targetName, GetParentUnitType(unit)))
		end
		return name
	end,
	['itemlevel'] = function(unit)
		if unit == 'player' then
			local _, equipped = GetAverageItemLevel()
			return format('%d', equipped)
		end
		local itemLevel = C_PaperDollInfo.GetInspectItemLevel(unit)
		if itemLevel and itemLevel > 0 then return format('%d', itemLevel) end
		return ''
	end,
	['spec'] = function(unit)
		if unit == 'player' then
			local specialization = GetSpecialization()
			if specialization then
				local _, name = GetSpecializationInfo(specialization)
				return name or ''
			end
			return ''
		end
		local specID = GetInspectSpecialization(unit)
		if specID and specID > 0 then
			local _, name = GetSpecializationInfoByID(specID)
			return name or ''
		end
		return ''
	end,
	['title'] = function(unit)
		local name = UnitPVPName(unit)
		local plainName = UnitName(unit)
		if name and plainName and name ~= plainName then
			return name:gsub(plainName, ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub(',%s*$', '')
		end
		return ''
	end,
	['difficulty'] = function()
		local _, _, difficultyID = GetInstanceInfo()
		if not difficultyID or difficultyID == 0 then return '' end
		local name = GetDifficultyInfo(difficultyID)
		return name or ''
	end,
	['role'] = function(unit)
		local role = UnitGroupRolesAssigned(unit)
		if role == 'TANK' then return '|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t'
		elseif role == 'HEALER' then return '|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t'
		elseif role == 'DAMAGER' then return '|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t'
		end
		return ''
	end,
	['role:text'] = function(unit)
		local role = UnitGroupRolesAssigned(unit)
		if role == 'TANK' then return 'Tank'
		elseif role == 'HEALER' then return 'Healer'
		elseif role == 'DAMAGER' then return 'DPS'
		end
		return ''
	end,
}

for tag, handler in pairs(Handlers) do
	oUF.Tags.Methods['bui:' .. tag] = BUI.Prof.WrapTag('tag#bui:' .. tag, handler)
	oUF.Tags.Events['bui:' .. tag] = TagEvents[tag]
end

local directTagRegistry = {}
local directGroups = {}
local directCacheDirty = true

local function RegisterDirectTag(tagName, group, getText)
	directTagRegistry[tagName] = { group = group, getText = getText }
	if not directGroups[group] then
		directGroups[group] = { fontStrings = {}, count = 0, getText = getText }
	end
end

local function CacheDirectFontStrings()
	if not directCacheDirty then return end
	directCacheDirty = false

	for _, groupData in pairs(directGroups) do
		groupData.count = 0
	end

	for _, frameObject in next, oUF.objects do
		if frameObject.unit == 'player' and frameObject.__tags then
			for fontString in next, frameObject.__tags do
				if fontString._tagString then
					for tagName, registration in pairs(directTagRegistry) do
						if fontString._tagString:find(tagName) then
							local groupData = directGroups[registration.group]
							groupData.count = groupData.count + 1
							groupData.fontStrings[groupData.count] = fontString
						end
					end
				end
			end
		end
	end

	for _, groupData in pairs(directGroups) do
		for fontStringIndex = groupData.count + 1, #groupData.fontStrings do groupData.fontStrings[fontStringIndex] = nil end
	end
end

local function UpdateDirectGroup(group)
	local groupData = directGroups[group]
	if not groupData or groupData.count == 0 then return end
	local text = groupData.getText()
	for fontStringIndex = 1, groupData.count do
		local fontString = groupData.fontStrings[fontStringIndex]
		if fontString:IsVisible() then fontString:SetText(text) end
	end
end

RegisterDirectTag('resting', 'resting', function()
	return IsResting() and restingFrames[restingIndex] or ''
end)

RegisterDirectTag('combattime', 'combattime', function()
	return combatTimerText or ''
end)

local function UpdateRestingTags()
	restingIndex = restingIndex % #restingFrames + 1
	UpdateDirectGroup('resting')
end

local function StartRestingAnimation()
	if restingTicker then return end
	restingIndex = 1
	restingTicker = BUI.Prof.NewTicker('UnitFrames.Tags', 0.1, BUI.Prof.Wrap('tick#RestingTag', UpdateRestingTags))
end

local function StopRestingAnimation()
	if not restingTicker then return end
	restingTicker:Cancel()
	restingTicker = nil
	UpdateDirectGroup('resting')
end

do
	local function OnRestingEvent()
		CacheDirectFontStrings()
		if IsResting() and not InCombatLockdown() and directGroups.resting.count > 0 then
			StartRestingAnimation()
		else
			StopRestingAnimation()
		end
	end
	BUI.Events:Register('PLAYER_UPDATE_RESTING', 'UF.Tags.Resting', OnRestingEvent)
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'UF.Tags.Resting', OnRestingEvent)
	BUI.Events:Register('PLAYER_REGEN_DISABLED', 'UF.Tags.Resting', OnRestingEvent)
	BUI.Events:Register('PLAYER_REGEN_ENABLED', 'UF.Tags.Resting', OnRestingEvent)
end

do
	local combatTicker
	local groupWatchActive = false

	local IsGroupInCombat = BUI.Tools.IsGroupInCombat

	local GROUP_WATCH_UNITS = {'player'}
	for partyIndex = 1, 4 do GROUP_WATCH_UNITS[#GROUP_WATCH_UNITS + 1] = 'party' .. partyIndex end
	for raidIndex = 1, 40 do GROUP_WATCH_UNITS[#GROUP_WATCH_UNITS + 1] = 'raid' .. raidIndex end

	local function UpdateCombatTimerTags()
		if directGroups.combattime.count == 0 then return end
		combatTimerText = FormatCombatTime(GetTime() - combatStartTime)
		UpdateDirectGroup('combattime')
	end

	local StopWatchingGroup

	local function StartCombatTimer()
		if combatTicker then return end
		CacheDirectFontStrings()
		if directGroups.combattime.count == 0 then return end
		combatStartTime = GetTime()
		combatTimerText = FormatCombatTime(0)
		combatTicker = BUI.Prof.NewTicker('UnitFrames.Tags', 0.1, BUI.Prof.Wrap('tick#CombatTimeTag', UpdateCombatTimerTags))
	end

	local function FinalizeStop()
		if StopWatchingGroup then StopWatchingGroup() end
		if not combatTicker then return end
		combatTicker:Cancel()
		combatTicker = nil
		combatTimerText = ''
		CacheDirectFontStrings()
		UpdateDirectGroup('combattime')
	end

	local GroupCombatCheck = BUI.Dispatcher.New(function()
		if UnitAffectingCombat('player') then
			if StopWatchingGroup then StopWatchingGroup() end
			return
		end
		if not IsGroupInCombat() then
			FinalizeStop()
		end
	end, 'UF.Tags.GroupCombat')

	local function OnGroupCombatSignal()
		GroupCombatCheck()
	end

	local function StartWatchingGroup()
		if groupWatchActive then return end
		groupWatchActive = true
		BUI.Events:RegisterUnit('UNIT_FLAGS', GROUP_WATCH_UNITS, 'UF.Tags.CombatTimer.GroupWatch', OnGroupCombatSignal)
		BUI.Events:Register('PLAYER_DEAD',         'UF.Tags.CombatTimer.GroupWatch', OnGroupCombatSignal)
		BUI.Events:Register('GROUP_ROSTER_UPDATE', 'UF.Tags.CombatTimer.GroupWatch', OnGroupCombatSignal)
		OnGroupCombatSignal()
	end

	StopWatchingGroup = function()
		if not groupWatchActive then return end
		groupWatchActive = false
		BUI.Events:Unregister('UNIT_FLAGS',          'UF.Tags.CombatTimer.GroupWatch')
		BUI.Events:Unregister('PLAYER_DEAD',         'UF.Tags.CombatTimer.GroupWatch')
		BUI.Events:Unregister('GROUP_ROSTER_UPDATE', 'UF.Tags.CombatTimer.GroupWatch')
	end

	local function OnPlayerLeftCombat()
		if IsInGroup() and IsGroupInCombat() then
			StartWatchingGroup()
		else
			FinalizeStop()
		end
	end

	local function OnCombatTimerEvent(event)
		if event == 'PLAYER_REGEN_DISABLED' then
			StopWatchingGroup()
			StartCombatTimer()
		elseif event == 'PLAYER_REGEN_ENABLED' then
			OnPlayerLeftCombat()
		elseif event == 'PLAYER_ENTERING_WORLD' then
			CacheDirectFontStrings()
			if UnitAffectingCombat('player') then
				StopWatchingGroup()
				StartCombatTimer()
			else
				OnPlayerLeftCombat()
			end
		end
	end
	BUI.Events:Register('PLAYER_REGEN_DISABLED', 'UF.Tags.CombatTimer', OnCombatTimerEvent)
	BUI.Events:Register('PLAYER_REGEN_ENABLED', 'UF.Tags.CombatTimer', OnCombatTimerEvent)
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'UF.Tags.CombatTimer', OnCombatTimerEvent)
end

local function EnsureRegistered(tagName)
	if oUF.Tags.Methods['bui:' .. tagName] then return true end

	local shortLength = tagName:match('^name:short(%d+)$')
	if shortLength then
		local limit = tonumber(shortLength)
		oUF.Tags.Methods['bui:' .. tagName] = BUI.Prof.WrapTag('tag#bui:' .. tagName, function(unit) local name = UnitName(unit) return name and Tools.TruncateName(name, limit) or '' end)
		oUF.Tags.Events['bui:' .. tagName] = 'UNIT_NAME_UPDATE'
		return true
	end

	local nameLength, targetLength, separator = tagName:match('^name(%d*):target(%d*)(.*)$')
	if nameLength or targetLength then
		local nameLimit = nameLength ~= '' and tonumber(nameLength) or nil
		local targetLimit = targetLength ~= '' and tonumber(targetLength) or nil
		separator = (separator and separator ~= '') and separator or '>'
		oUF.Tags.Methods['bui:' .. tagName] = BUI.Prof.WrapTag('tag#bui:' .. tagName, function(unit)
			local name = UnitName(unit) or ''
			local targetUnit = unit .. 'target'
			local targetName = UnitName(targetUnit)
			if nameLimit then name = Tools.TruncateName(name, nameLimit) end
			if targetName and (issecretvalue(targetName) or targetName ~= '') then
				if targetLimit then targetName = Tools.TruncateName(targetName, targetLimit) end
				targetName = ClassColoredName(targetUnit, targetName, GetParentUnitType(unit))
				return format('%s |cFFFFFFFF%s|r %s', name, separator, targetName)
			end
			return name
		end)
		oUF.Tags.Events['bui:' .. tagName] = 'UNIT_TARGET UNIT_NAME_UPDATE'
		return true
	end
	return false
end

function UnitFrames.ConvertTagFormat(formatString)
	if not formatString or formatString == '' then return '' end

	return formatString:gsub('%[(.-)%]', function(tag)
		if EnsureRegistered(tag) then return '[bui:' .. tag .. ']' end
		return '[' .. tag .. ']'
	end)
end

function UnitFrames.TagFontStrings(frame)
	directCacheDirty = true
	local unitType = frame._unitType
	local settings = UnitFrames.GetSettings()
	local unitSettings = UnitFrames.GetUnitSettings(unitType)

	local function resolve(unitValue, globalValue, fallback)
		if unitValue and unitValue ~= '' then return unitValue end
		if globalValue and globalValue ~= '' then return globalValue end
		return fallback
	end

	local function applyTag(fontString, formatString)
		local converted = UnitFrames.ConvertTagFormat(formatString)
		fontString._tagString = converted
		fontString.frequentUpdates = converted:find('%[bui:range%]') and 0.25 or nil
		frame:Tag(fontString, converted)
	end

	if frame.Name then frame:Untag(frame.Name); frame.Name._tagString = nil end
	if frame.HealthText then frame:Untag(frame.HealthText); frame.HealthText._tagString = nil end
	if frame.PowerText then frame:Untag(frame.PowerText); frame.PowerText._tagString = nil end
	if frame.LevelText then frame:Untag(frame.LevelText); frame.LevelText._tagString = nil end

	if frame.Name then
		if (unitType == 'player' or unitType == 'pet') and unitSettings.customName and unitSettings.customName ~= '' then
			frame.Name:SetText(unitSettings.customName)
		else
			applyTag(frame.Name, resolve(unitSettings.nameFormat, settings.nameFormat, '[name]'))
		end
	end
	if frame.HealthText then
		applyTag(frame.HealthText, resolve(unitSettings.healthFormat, settings.healthFormat, '[perhp]%'))
	end
	if frame.PowerText then
		applyTag(frame.PowerText, resolve(unitSettings.powerFormat, settings.powerFormat, '[perpp]%'))
	end
	if frame.LevelText then
		local levelFormat = settings.levelFormat
		if levelFormat and levelFormat ~= '' then applyTag(frame.LevelText, levelFormat) end
	end

	UnitFrames.ApplyCustomTags(frame)

	if unitType == 'player' then CacheDirectFontStrings() end
end

function UnitFrames.ApplyCustomTags(frame)
	directCacheDirty = true
	local unitType = frame._unitType
	local unitSettings = UnitFrames.GetUnitSettings(unitType)
	local entries = unitSettings.customTags
	local font = UnitFrames.GetFont()
	local overlay = frame.TextOverlay or frame

	frame._customTags = frame._customTags or {}

	for _, fontString in ipairs(frame._customTags) do
		frame:Untag(fontString)
		fontString:Hide()
	end

	for tagIndex, entry in ipairs(entries) do
		if entry.tag and entry.tag ~= '' and entry.enabled ~= false then
			local fontString = frame._customTags[tagIndex]
			if not fontString then
				fontString = overlay:CreateFontString(nil, 'OVERLAY')
				frame._customTags[tagIndex] = fontString
			end

			local tagFont = font
			if entry.font and entry.font ~= '' and entry.font ~= 'GLOBAL' then
				tagFont = LibStub('LibSharedMedia-3.0'):Fetch('font', entry.font) or font
			end
			Pixel.ApplyFont(fontString, entry.fontSize or 12, tagFont)
			fontString:SetDrawLayer(entry.drawLayer or 'OVERLAY', entry.drawSubLevel or 0)
			fontString:ClearAllPoints()
			fontString:SetPoint(entry.point or 'CENTER', overlay, entry.point or 'CENTER',
				entry.x or 0, entry.y or 0)
			fontString:SetJustifyH(entry.point and entry.point:match('LEFT') and 'LEFT'
				or entry.point and entry.point:match('RIGHT') and 'RIGHT'
				or 'CENTER')
			fontString:SetWordWrap(false)
			fontString:SetNonSpaceWrap(false)

			local color = entry.color
			if color then fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
			else fontString:SetTextColor(1, 1, 1, 1) end

			if entry.tag:find('%[resting%]') then
				local red, green, blue = 1, 1, 1
				if color then red, green, blue = color[1] or 1, color[2] or 1, color[3] or 1 end
				UnitFrames.SetRestingAnimation(red, green, blue)
			end

			local convertedTag = UnitFrames.ConvertTagFormat(entry.tag)
			fontString._tagString = convertedTag
			fontString.frequentUpdates = convertedTag:find('%[bui:range%]') and 0.25 or nil
			frame:Tag(fontString, convertedTag)
			fontString:Show()
		end
	end
end

function UnitFrames.IsTagValidForUnit(tagName, unitType)
	local base = tagName:match('^name:short%d+$') and 'name:short'
		or tagName:match('^name%d*:target') and 'name:target'
		or tagName
	local meta = TagMeta[base]
	if not meta then return true end
	return meta.u[unitType] == true
end

local PreviewCache = {}
local PreviewTags = {
	['hp'] = function(healthPercent) return tostring(floor(healthPercent * 5000000)) end,
	['hp:short'] = function(healthPercent) return Abbreviate(floor(healthPercent * 5000000)) end,
	['maxhp'] = function() return '100000' end,
	['maxhp:short'] = function() return Abbreviate(50000000) end,
	['perhp'] = function(healthPercent) return tostring(healthPercent) end,
	['pp'] = function(_, powerPercent) return tostring(floor(powerPercent * 100)) end,
	['pp:short'] = function(_, powerPercent) return Abbreviate(floor(powerPercent * 100)) end,
	['maxpp'] = function() return '10000' end,
	['maxpp:short'] = function() return Abbreviate(10000) end,
	['perpp'] = function(_, powerPercent) return tostring(powerPercent) end,
	['mana'] = function() return '8000' end,
	['mana:short'] = function() return '8K' end,
	['maxmana'] = function() return '10000' end,
	['maxmana:short'] = function() return '10K' end,
	['permana'] = function() return '80' end,
	['powertype'] = function() return 'Mana' end,
	['absorbs'] = function() return '0' end,
	['hpabsorb'] = function(healthPercent) return tostring(floor(healthPercent * 5000000)) end,
	['hpabsorb:short'] = function(healthPercent) return Abbreviate(floor(healthPercent * 5000000)) end,
	['name'] = function() return 'Bluetempest' end,
	['name:short'] = function() return 'Bluetempes...' end,
	['level'] = function() return '80' end,
	['class'] = function() return 'HUNTER' end,
	['classname'] = function() return 'Hunter' end,
	['race'] = function() return 'Night Elf' end,
	['classification'] = function() return '' end,
	['status'] = function() return '' end,
	['dead'] = function() return '' end,
	['offline'] = function() return '' end,
	['afk'] = function() return '' end,
	['dnd'] = function() return '' end,
	['resting'] = function() return restingFrames[1] or 'Zzz' end,
	['combat'] = function() return '|TInterface\\AddOns\\BluUI\\Media\\Textures\\combat:14:14|t' end,
	['combattime'] = function() return '[01:23]' end,
	['range'] = function() return '|cff2bff6225-30|r' end,
	['creature'] = function() return 'Cat' end,
	['creaturefamily'] = function() return 'Cat' end,
	['creaturetype'] = function() return 'Beast' end,
	['server'] = function() return 'Tarren Mill' end,
	['target'] = function() return '|cFFC79C6ERagnaros|r' end,
	['name:target'] = function() return 'Bluetempest |cFFFFFFFF>|r |cFFC79C6ERagnaros|r' end,
	['group'] = function() return '3' end,
	['itemlevel'] = function() return '639' end,
	['spec'] = function() return 'Marksmanship' end,
	['title'] = function() return 'the Exalted' end,
	['difficulty'] = function() return 'Mythic' end,
	['role'] = function() return '|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t' end,
	['role:text'] = function() return 'DPS' end,
	['threat'] = function() return '42%' end,
}

local function ResolvePreviewTag(tag)
	if PreviewTags[tag] then return PreviewTags[tag] end
	local shortLength = tag:match('^name:short(%d+)$')
	if shortLength then
		local fullName = 'Bluetempest'
		local limit = tonumber(shortLength)
		local display = #fullName > limit and fullName:sub(1, limit) or fullName
		return function() return display end
	end
	local nameLength, targetLength, separator = tag:match('^name(%d*):target(%d*)(.*)$')
	if nameLength or targetLength then
		local displayName = 'Bluetempest'
		local displayTarget = 'Ragnaros'
		if nameLength and nameLength ~= '' and #displayName > tonumber(nameLength) then displayName = displayName:sub(1, tonumber(nameLength)) end
		if targetLength and targetLength ~= '' and #displayTarget > tonumber(targetLength) then displayTarget = displayTarget:sub(1, tonumber(targetLength)) end
		separator = (separator and separator ~= '') and separator or '>'
		local result = format('%s |cFFFFFFFF%s|r |cFFC79C6E%s|r', displayName, separator, displayTarget)
		return function() return result end
	end
	return nil
end

local valueBuffer = {}

function UnitFrames.ParsePreviewTags(formatString, healthPercent, powerPercent)
	if not formatString then return '' end
	healthPercent = healthPercent or 75
	powerPercent = powerPercent or 60
	local cached = PreviewCache[formatString]
	if not cached then
		local handlers = {}
		local count = 0
		local pattern = ''
		local position = 1
		while position <= #formatString do
			local tagStart = formatString:find('[', position, true)
			if not tagStart then pattern = pattern .. formatString:sub(position):gsub('%%', '%%%%') break end
			if tagStart > position then pattern = pattern .. formatString:sub(position, tagStart - 1):gsub('%%', '%%%%') end
			local tagEnd = formatString:find(']', tagStart + 1, true)
			if not tagEnd then pattern = pattern .. formatString:sub(tagStart):gsub('%%', '%%%%') break end
			local handler = ResolvePreviewTag(formatString:sub(tagStart + 1, tagEnd - 1))
			if handler then count = count + 1 handlers[count] = handler pattern = pattern .. '%s'
			else pattern = pattern .. ('[' .. formatString:sub(tagStart + 1, tagEnd - 1) .. ']'):gsub('%%', '%%%%') end
			position = tagEnd + 1
		end
		if count == 0 then cached = function() return pattern end
		elseif count == 1 and pattern == '%s' then
			local handler = handlers[1]
			cached = function(healthValue, powerValue) return handler(healthValue, powerValue) or '' end
		else
			cached = function(healthValue, powerValue)
				for handlerIndex = 1, count do valueBuffer[handlerIndex] = handlers[handlerIndex](healthValue, powerValue) or '' end
				return format(pattern, unpack(valueBuffer, 1, count))
			end
		end
		PreviewCache[formatString] = cached
	end
	return cached(healthPercent, powerPercent)
end

function UnitFrames.InvalidateTagCache()
	wipe(PreviewCache)
end

