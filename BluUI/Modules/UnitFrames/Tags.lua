local _, BUI = ...

local Wrap = BUI.Profiler.Wrap

local Pixel = BUI.Pixel
local UnitFrames = BUI.UnitFrames
local Tools = BUI.Tools
local Range = BUI.Range
local Hex = BUI.Hex
local oUF = BUI.oUF
local sharedMedia = LibStub('LibSharedMedia-3.0')

local floor = math.floor
local format = string.format
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
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
local GetSpecialization = C_SpecializationInfo.GetSpecialization
local GetSpecializationInfo = C_SpecializationInfo.GetSpecializationInfo
local GetInspectSpecialization = C_SpecializationInfo.GetInspectSpecialization
local GetSpecializationInfoByID = GetSpecializationInfoByID
local GetInspectItemLevel = C_PaperDollInfo.GetInspectItemLevel
local GetInstanceInfo = GetInstanceInfo
local GetDifficultyInfo = GetDifficultyInfo
local WrapString = C_StringUtil.WrapString
local issecretvalue = issecretvalue

local ScaleTo100 = CurveConstants.ScaleTo100
local PowerTypeMana = Enum.PowerType.Mana
local GLOBAL_OPTION = BUI.C.GLOBAL_OPTION
local COMBAT_ICON = '|TInterface\\AddOns\\BluUI\\Media\\Textures\\combat:14:14|t'

local RESTING_STEPS = {
	{1.0, 0.5, 0.3},  {0.8, 0.7, 0.3},  {0.55, 1.0, 0.37},
	{0.4, 0.8, 0.55}, {0.3, 0.55, 1.0},  {0.3, 0.4, 0.8},
	{0.3, 0.3, 0.55}, {0.3, 0.3, 0.37},  {0.37, 0.3, 0.3},
	{0.55, 0.3, 0.3}, {0.75, 0.37, 0.3},  {0.9, 0.4, 0.3},
}
local restingFrames = {}
local restingIndex = 1
local restingTicker

local function BuildRestingFrames(red, green, blue)
	for stepIndex, step in ipairs(RESTING_STEPS) do
		restingFrames[stepIndex] = '|cff' .. Hex(red * step[1], green * step[1], blue * step[1]) .. 'Z|r'
			.. '|cff' .. Hex(red * step[2], green * step[2], blue * step[2]) .. 'z|r'
			.. '|cff' .. Hex(red * step[3], green * step[3], blue * step[3]) .. 'z|r'
	end
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
	useDecimalAbbreviations = BUI.GetDB().general.showDecimalAbbreviations
end

local function Abbreviate(number)
	if useDecimalAbbreviations then return AbbreviateNumbers(number, AbbrevDataDecimal) end
	return AbbreviateNumbers(number)
end

local function HealthPlusAbsorb(unit)
	local health, absorb = UnitHealth(unit), UnitGetTotalAbsorbs(unit)
	if issecretvalue(health) or issecretvalue(absorb) then return health end
	return health + absorb
end

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
	['combat']         = 'UNIT_FLAGS PLAYER_REGEN_ENABLED PLAYER_REGEN_DISABLED',
	['combattime']     = 'PLAYER_REGEN_ENABLED PLAYER_REGEN_DISABLED',
	['creature']       = 'UNIT_NAME_UPDATE',
	['creaturefamily'] = 'UNIT_NAME_UPDATE',
	['creaturetype']   = 'UNIT_NAME_UPDATE',
	['server']         = 'UNIT_NAME_UPDATE',
	['target']         = 'UNIT_TARGET UNIT_NAME_UPDATE',
	['name:target']    = 'UNIT_TARGET UNIT_NAME_UPDATE',
	['itemlevel']      = 'INSPECT_READY PLAYER_AVG_ITEM_LEVEL_UPDATE UNIT_NAME_UPDATE',
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

local reactionColorCodes = {}
local classColorCodes = {}
local statusTexts = {}
do
	local originalInvalidate = UnitFrames.InvalidateSettingsCache
	UnitFrames.InvalidateSettingsCache = function(...)
		wipe(reactionColorCodes)
		wipe(classColorCodes)
		wipe(statusTexts)
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
	local codes = reactionColorCodes[parentType]
	if not codes then
		codes = {}
		reactionColorCodes[parentType] = codes
	end
	local code = codes[bucket]
	if not code then
		local reactionColor = UnitFrames.GetUnitSettings(parentType)[bucket]
		code = '|cff' .. Hex(reactionColor[1], reactionColor[2], reactionColor[3])
		codes[bucket] = code
	end
	return code
end

local function GetClassColorCode(unit)
	local _, class = UnitClass(unit)
	if not class or issecretvalue(class) then return nil end
	local code = classColorCodes[class]
	if code == nil then
		local red, green, blue = Tools.GetUnitClassColor(unit)
		code = red and ('|cff' .. Hex(red, green, blue)) or false
		classColorCodes[class] = code
	end
	return code or nil
end

local function ClassColoredName(unit, name, parentUnitType)
	local code
	if UnitIsPlayer(unit) then
		code = GetClassColorCode(unit)
	else
		code = GetReactionColorCode(unit, parentUnitType)
	end
	if not code then return name end
	return WrapString(name, code, '|r')
end

local function StatusText(status)
	local text = statusTexts[status]
	if not text then
		local color = UnitFrames.GetSettings().statusColors[status]
		text = '|cff' .. Hex(color[1], color[2], color[3]) .. status:upper() .. '|r'
		statusTexts[status] = text
	end
	return text
end
UnitFrames.StatusText = StatusText

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
		return UnitHealth(unit)
	end,
	['hp:short'] = function(unit)
		if UnitIsDeadOrGhost(unit) then return 'Dead' end
		return Abbreviate(UnitHealth(unit))
	end,
	['maxhp'] = UnitHealthMax,
	['maxhp:short'] = function(unit) return Abbreviate(UnitHealthMax(unit)) end,
	['perhp'] = function(unit) return format('%d', UnitHealthPercent(unit, true, ScaleTo100)) end,
	['pp'] = UnitPower,
	['pp:short'] = function(unit) return Abbreviate(UnitPower(unit)) end,
	['maxpp'] = UnitPowerMax,
	['maxpp:short'] = function(unit) return Abbreviate(UnitPowerMax(unit)) end,
	['perpp'] = function(unit) return format('%d', UnitPowerPercent(unit, nil, true, ScaleTo100)) end,
	['mana'] = function(unit) return UnitPower(unit, PowerTypeMana) end,
	['mana:short'] = function(unit) return Abbreviate(UnitPower(unit, PowerTypeMana)) end,
	['maxmana'] = function(unit) return UnitPowerMax(unit, PowerTypeMana) end,
	['maxmana:short'] = function(unit) return Abbreviate(UnitPowerMax(unit, PowerTypeMana)) end,
	['permana'] = function(unit)
		return format('%d', UnitPowerPercent(unit, PowerTypeMana, true, ScaleTo100))
	end,
	['powertype'] = function(unit) local _, tokenName = UnitPowerType(unit) return tokenName or 'Mana' end,
	['absorbs'] = function(unit) return Abbreviate(UnitGetTotalAbsorbs(unit)) end,
	['hpabsorb'] = function(unit)
		if UnitIsDeadOrGhost(unit) then return 'Dead' end
		return HealthPlusAbsorb(unit)
	end,
	['hpabsorb:short'] = function(unit)
		if UnitIsDeadOrGhost(unit) then return 'Dead' end
		return Abbreviate(HealthPlusAbsorb(unit))
	end,
	['name'] = function(unit) return UnitName(unit) or '' end,
	['name:short'] = function(unit) local name = UnitName(unit) return name and Tools.TruncateName(name, 10) or '' end,
	['level'] = function(unit) local level = UnitLevel(unit) return level == -1 and '??' or level end,
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
		if not UnitIsConnected(unit) then return StatusText('Offline')
		elseif UnitIsGhost(unit) then return StatusText('Ghost')
		elseif UnitIsDead(unit) then return StatusText('Dead') end
		return ''
	end,
	['dead'] = function(unit)
		if UnitIsGhost(unit) then return StatusText('Ghost') end
		if UnitIsDead(unit) then return StatusText('Dead') end
		return ''
	end,
	['offline'] = function(unit) return not UnitIsConnected(unit) and StatusText('Offline') or '' end,
	['afk'] = function(unit) return UnitIsAFK(unit) and StatusText('AFK') or '' end,
	['dnd'] = function(unit) return UnitIsDND(unit) and StatusText('DND') or '' end,

	['resting'] = function(unit)
		if unit ~= 'player' and unit ~= 'vehicle' then return '' end
		return IsResting() and restingFrames[restingIndex] or ''
	end,
	['combat'] = function(unit) return UnitAffectingCombat(unit) and COMBAT_ICON or '' end,
	['combattime'] = function() return combatTimerText end,
	['range'] = function(unit) return Range.DisplayText(unit) end,
	['threat'] = function()
		if not UnitExists('target') then return '' end
		local _, _, threatPercent = UnitDetailedThreatSituation('player', 'target')
		if threatPercent and not issecretvalue(threatPercent) then return format('%d%%', threatPercent) end
		return ''
	end,
	['creature'] = function(unit) return UnitCreatureFamily(unit) or UnitCreatureType(unit) or '' end,
	['creaturefamily'] = function(unit) return UnitCreatureFamily(unit) or '' end,
	['creaturetype'] = function(unit) return UnitCreatureType(unit) or '' end,
	['server'] = function(unit) local _, realm = UnitName(unit) return realm or GetRealmName() end,
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
		local itemLevel = GetInspectItemLevel(unit)
		if itemLevel > 0 then return format('%d', itemLevel) end
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
		if not issecretvalue(specID) and specID > 0 then
			local _, name = GetSpecializationInfoByID(specID)
			return name or ''
		end
		return ''
	end,
	['title'] = function(unit)
		local name = UnitPVPName(unit)
		local plainName = UnitName(unit)
		if issecretvalue(name) or issecretvalue(plainName) then return '' end
		if name and plainName and name ~= plainName then
			return name:gsub(plainName, ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub(',%s*$', '')
		end
		return ''
	end,
	['difficulty'] = function()
		local _, _, difficultyID = GetInstanceInfo()
		if difficultyID == 0 then return '' end
		return GetDifficultyInfo(difficultyID) or ''
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

for _, event in ipairs({ 'INSPECT_READY', 'PLAYER_AVG_ITEM_LEVEL_UPDATE', 'PLAYER_DIFFICULTY_CHANGED', 'ZONE_CHANGED_NEW_AREA', 'PLAYER_ROLES_ASSIGNED', 'UNIT_THREAT_LIST_UPDATE' }) do
	oUF.Tags.SharedEvents[event] = true
end

for tag, handler in pairs(Handlers) do
	oUF.Tags.Methods['bui:' .. tag] = handler
	oUF.Tags.Events['bui:' .. tag] = TagEvents[tag]
end

local directGroups = {
	resting = { fontStrings = {}, count = 0 },
	combattime = { fontStrings = {}, count = 0 },
}
local taggedStrings = {}
local directCacheDirty = true

local function CacheDirectFontStrings()
	if not directCacheDirty then return end
	directCacheDirty = false

	for _, groupData in pairs(directGroups) do
		wipe(groupData.fontStrings)
		groupData.count = 0
	end

	for fontString, frame in pairs(taggedStrings) do
		local tagString = frame._unitType == 'player' and fontString.UpdateTag and fontString._tagString
		if tagString then
			for tagName, groupData in pairs(directGroups) do
				if tagString:find(tagName, 1, true) then
					groupData.count = groupData.count + 1
					groupData.fontStrings[groupData.count] = fontString
				end
			end
		end
	end
end

local function UpdateDirectGroup(group)
	local groupData = directGroups[group]
	for fontStringIndex = 1, groupData.count do
		local fontString = groupData.fontStrings[fontStringIndex]
		if fontString.UpdateTag and fontString:IsVisible() then fontString:UpdateTag() end
	end
end

local UpdateRestingTags = Wrap('UnitFrames.Tags resting', function()
	restingIndex = restingIndex % #restingFrames + 1
	UpdateDirectGroup('resting')
end)

local function StartRestingAnimation()
	if restingTicker then return end
	restingIndex = 1
	restingTicker = C_Timer.NewTicker(0.1, UpdateRestingTags)
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
		if IsResting() and not InCombatLockdown() and not UnitAffectingCombat('player') and directGroups.resting.count > 0 then
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

	local IsGroupInCombat = Tools.IsGroupInCombat

	local GROUP_WATCH_UNITS = {'player'}
	for partyIndex = 1, 4 do GROUP_WATCH_UNITS[#GROUP_WATCH_UNITS + 1] = 'party' .. partyIndex end
	for raidIndex = 1, 40 do GROUP_WATCH_UNITS[#GROUP_WATCH_UNITS + 1] = 'raid' .. raidIndex end

	local UpdateCombatTimerTags = Wrap('UnitFrames.Tags combat timer', function()
		if directGroups.combattime.count == 0 then return end
		combatTimerText = FormatCombatTime(GetTime() - combatStartTime)
		UpdateDirectGroup('combattime')
	end)

	local function StopWatchingGroup()
		if not groupWatchActive then return end
		groupWatchActive = false
		BUI.Events:Unregister('UNIT_FLAGS',          'UF.Tags.CombatTimer.GroupWatch')
		BUI.Events:Unregister('PLAYER_DEAD',         'UF.Tags.CombatTimer.GroupWatch')
		BUI.Events:Unregister('GROUP_ROSTER_UPDATE', 'UF.Tags.CombatTimer.GroupWatch')
	end

	local function StartCombatTimer()
		if combatTicker then return end
		CacheDirectFontStrings()
		if directGroups.combattime.count == 0 then return end
		combatStartTime = GetTime()
		combatTimerText = FormatCombatTime(0)
		combatTicker = C_Timer.NewTicker(0.1, UpdateCombatTimerTags)
	end

	local function FinalizeStop()
		StopWatchingGroup()
		if not combatTicker then return end
		combatTicker:Cancel()
		combatTicker = nil
		combatTimerText = ''
		CacheDirectFontStrings()
		UpdateDirectGroup('combattime')
	end

	local GroupCombatCheck = BUI.Dispatcher.New(function()
		if UnitAffectingCombat('player') then
			StopWatchingGroup()
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

	local function OnPlayerLeftCombat()
		if combatTicker and IsInGroup() and IsGroupInCombat() then
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
		oUF.Tags.Methods['bui:' .. tagName] = function(unit) local name = UnitName(unit) return name and Tools.TruncateName(name, limit) or '' end
		oUF.Tags.Events['bui:' .. tagName] = 'UNIT_NAME_UPDATE'
		return true
	end

	local nameLength, targetLength, separator = tagName:match('^name(%d*):target(%d*)(.*)$')
	if nameLength then
		local nameLimit = tonumber(nameLength)
		local targetLimit = tonumber(targetLength)
		if separator == '' then separator = '>' end
		oUF.Tags.Methods['bui:' .. tagName] = function(unit)
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
		end
		oUF.Tags.Events['bui:' .. tagName] = 'UNIT_TARGET UNIT_NAME_UPDATE'
		return true
	end
	return false
end

local function ConvertTag(tag)
	if EnsureRegistered(tag) then return '[bui:' .. tag .. ']' end
end

function UnitFrames.ConvertTagFormat(formatString)
	return (formatString:gsub('%[(.-)%]', ConvertTag))
end

local TAG_FIELDS = { 'Name', 'HealthText', 'PowerText', 'LevelText', 'StatusText' }
UnitFrames.TAG_FIELDS = TAG_FIELDS

local FALLBACK_FORMATS = { nameFormat = '[name]', healthFormat = '[perhp]%', powerFormat = '[perpp]%', statusFormat = '[status]' }

function UnitFrames.ResolveTextFormat(unitSettings, settings, key)
	local value = unitSettings[key]
	if value and value ~= '' then return value end
	value = settings[key]
	if value ~= '' then return value end
	return FALLBACK_FORMATS[key] or value
end

local function ApplyTag(frame, fontString, formatString)
	local converted = UnitFrames.ConvertTagFormat(formatString)
	fontString._tagString = converted
	taggedStrings[fontString] = frame
	fontString.frequentUpdates = converted:find('[bui:range]', 1, true) and 0.25 or nil
	frame:Tag(fontString, converted)
end

function UnitFrames.TagFontStrings(frame)
	directCacheDirty = true
	local unitType = frame._unitType
	local settings = UnitFrames.GetSettings()
	local unitSettings = UnitFrames.GetUnitSettings(unitType)

	for _, key in ipairs(TAG_FIELDS) do
		local fontString = frame[key]
		frame:Untag(fontString)
		fontString._tagString = nil
	end

	if (unitType == 'player' or unitType == 'pet') and unitSettings.customName ~= '' then
		frame.Name:SetText(unitSettings.customName)
	else
		ApplyTag(frame, frame.Name, UnitFrames.ResolveTextFormat(unitSettings, settings, 'nameFormat'))
	end
	ApplyTag(frame, frame.HealthText, UnitFrames.ResolveTextFormat(unitSettings, settings, 'healthFormat'))
	ApplyTag(frame, frame.PowerText, UnitFrames.ResolveTextFormat(unitSettings, settings, 'powerFormat'))
	ApplyTag(frame, frame.StatusText, UnitFrames.ResolveTextFormat(unitSettings, settings, 'statusFormat'))
	if settings.levelFormat ~= '' then ApplyTag(frame, frame.LevelText, settings.levelFormat) end

	UnitFrames.ApplyCustomTags(frame)

	if unitType == 'player' then CacheDirectFontStrings() end
end

function UnitFrames.ApplyCustomTags(frame)
	directCacheDirty = true
	local unitSettings = UnitFrames.GetUnitSettings(frame._unitType)
	local font = UnitFrames.GetFont()
	local overlay = frame.TextOverlay
	local fontStrings = frame._customTags
	if not fontStrings then
		fontStrings = {}
		frame._customTags = fontStrings
	end

	for _, fontString in ipairs(fontStrings) do
		frame:Untag(fontString)
		fontString:Hide()
	end

	for tagIndex, entry in ipairs(unitSettings.customTags) do
		local tag = entry.tag
		if tag and tag ~= '' and entry.enabled ~= false then
			local fontString = fontStrings[tagIndex]
			if not fontString then
				fontString = overlay:CreateFontString(nil, 'OVERLAY')
				fontStrings[tagIndex] = fontString
			end

			local tagFont = font
			if entry.font and entry.font ~= GLOBAL_OPTION then
				tagFont = sharedMedia:Fetch('font', entry.font, true) or font
			end
			local point = entry.point
			Pixel.ApplyFont(fontString, entry.fontSize, tagFont)
			fontString:SetDrawLayer(entry.drawLayer, entry.drawSubLevel)
			fontString:ClearAllPoints()
			fontString:SetPoint(point, overlay, point, entry.x, entry.y)
			fontString:SetJustifyH(point:find('LEFT', 1, true) and 'LEFT' or point:find('RIGHT', 1, true) and 'RIGHT' or 'CENTER')
			fontString:SetWordWrap(false)
			fontString:SetNonSpaceWrap(false)

			local color = entry.color
			fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
			if tag:find('[resting]', 1, true) then BuildRestingFrames(color[1], color[2], color[3]) end

			ApplyTag(frame, fontString, tag)
			fontString:Show()
		end
	end
end

local PreviewCache = {}
local PreviewTags = {
	['hp'] = function(healthPercent) return tostring(floor(healthPercent * 5000000)) end,
	['hp:short'] = function(healthPercent) return Abbreviate(floor(healthPercent * 5000000)) end,
	['maxhp'] = function() return '500000000' end,
	['maxhp:short'] = function() return Abbreviate(500000000) end,
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
	['name:short'] = function() return 'Bluetempes' end,
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
	['resting'] = function() return restingFrames[1] end,
	['combat'] = function() return COMBAT_ICON end,
	['combattime'] = function() return '01:23.4' end,
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
		local display = Tools.TruncateName('Bluetempest', tonumber(shortLength))
		return function() return display end
	end
	local nameLength, targetLength, separator = tag:match('^name(%d*):target(%d*)(.*)$')
	if nameLength then
		local displayName, displayTarget = 'Bluetempest', 'Ragnaros'
		if nameLength ~= '' then displayName = Tools.TruncateName(displayName, tonumber(nameLength)) end
		if targetLength ~= '' then displayTarget = Tools.TruncateName(displayTarget, tonumber(targetLength)) end
		if separator == '' then separator = '>' end
		local result = format('%s |cFFFFFFFF%s|r |cFFC79C6E%s|r', displayName, separator, displayTarget)
		return function() return result end
	end
	return nil
end

local valueBuffer = {}

function UnitFrames.ParsePreviewTags(formatString, healthPercent, powerPercent)
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
