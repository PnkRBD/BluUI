local _, BUI = ...

local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local GetSpecialization = GetSpecialization
local IsSpellKnown = C_SpellBook.IsSpellKnown
local GetTime = GetTime
local Tools = BUI.Tools

local Hunter = {}
BUI.BuffTracking.Hunter = Hunter

Hunter.PlayerIsHunter = select(2, UnitClass('player')) == 'HUNTER'

local isSurvival     = false
local isMarksmanship = false
local isBeastMastery = false
local hasPackLeader  = false

local tipOfSpearStacks = 0
local bulletstormShotsLeft = 0
local bulletstormArmed = false
local bulletstormArmedUntil = 0
local cobraFangStacks = 0

local TIP_OF_SPEAR_BUFF  = 260286
local RAPTOR_SWIPE_BUFF  = 1273155
local PRECISE_SHOTS_BUFF = 260242
local LOCK_AND_LOAD_BUFF = 194594
local BULLETSTORM_BUFFS  = { 389020, 471419, 471574 }
local BULLETSTORM_WINDOW_SECONDS = 15
local ACCURACY_BY_VOLUME_TALENT = 471428
local RAPID_FIRE_SPELL = 257044
local AIMED_SHOT_SPELL = 19434
local NATURES_ALLY_PROCS = { 1273126, 1276720 }

local KILL_COMMAND_BEAST_MASTERY_ID = 34026
local KILL_COMMAND_SURVIVAL_ID      = 259489

local COBRA_SHOT_SPELL  = 193455
local BARBED_SHOT_SPELL = 217200
local COBRA_FANG_BUFF   = 1299389
local COBRA_FANG_MAX_STACKS = 4
local COBRA_FANG_STACKS_PER_BARBED_SHOT = 2

local PACK_LEADER_TALENT    = 471876
local PACK_LEADER_COUNTDOWN = 471877

Hunter.PackLeaderCountdownSpell = PACK_LEADER_COUNTDOWN

Hunter.PackLeaderBeasts = {
	{ spell = 472324, name = 'Boar',   id = 'boar',   short = 'Bo' },
	{ spell = 472325, name = 'Bear',   id = 'bear',   short = 'Be' },
	{ spell = 471878, name = 'Wyvern', id = 'wyvern', short = 'Wy' },
}
Hunter.NextBeastId = { boar = 'bear', bear = 'wyvern', wyvern = 'boar' }
Hunter.BeastById = {}
Hunter.PackLeaderSpellSet = { [PACK_LEADER_TALENT] = true, [PACK_LEADER_COUNTDOWN] = true }
for _, beast in ipairs(Hunter.PackLeaderBeasts) do
	Hunter.BeastById[beast.id] = beast
	Hunter.PackLeaderSpellSet[beast.spell] = true
end

function Hunter.BeastColor(beastId)
	local color = BUI.GetDB().packLeader.beastColors[beastId]
	return color.r or color[1], color.g or color[2], color.b or color[3]
end

local TRACKED_SPELL_IDS = {
	[PRECISE_SHOTS_BUFF] = true,
	[RAPTOR_SWIPE_BUFF]  = true,
	[LOCK_AND_LOAD_BUFF] = true,
	[COBRA_FANG_BUFF]    = true,
}
for spellID in pairs(Hunter.PackLeaderSpellSet) do TRACKED_SPELL_IDS[spellID] = true end
for _, spellID in ipairs(NATURES_ALLY_PROCS) do TRACKED_SPELL_IDS[spellID] = true end
for _, spellID in ipairs(BULLETSTORM_BUFFS) do TRACKED_SPELL_IDS[spellID] = true end

Hunter.PreciseShotsSpellSet = { [PRECISE_SHOTS_BUFF] = true }
Hunter.LockAndLoadSpellSet  = { [LOCK_AND_LOAD_BUFF] = true }
Hunter.CobraFangSpellSet    = { [COBRA_FANG_BUFF] = true }
Hunter.NaturesAllySpellSet  = {}
for _, spellID in ipairs(NATURES_ALLY_PROCS) do Hunter.NaturesAllySpellSet[spellID] = true end

local packLeaderPhase = 'off'
local packLeaderBeast = nil
local packLeaderNextBeastId = 'boar'
local packLeaderHasCooldownBuff = false
local packLeaderDirty = true

local scan

local function UpdateTalents()
	hasPackLeader = (isBeastMastery or isSurvival) and IsSpellKnown(PACK_LEADER_TALENT) == true
end

local function AuraActive(spellID)
	if not Tools.ShouldAurasBeSecret() and not Tools.AuraQueriesBlocked() then
		return GetPlayerAuraBySpellID(spellID) ~= nil
	end
	local entry = scan.GetEntry(spellID)
	return entry ~= nil and scan.FrameHasAura(entry)
end

local function SaveState()
	BUI.db.char.plNextBeastId = packLeaderNextBeastId
end

local function RestoreState()
	local saved = BUI.db.char.plNextBeastId
	if saved and Hunter.NextBeastId[saved] then packLeaderNextBeastId = saved end
end

local function ClearPackLeaderState()
	packLeaderPhase = 'off'
	packLeaderBeast = nil
	packLeaderHasCooldownBuff = false
	packLeaderDirty = true
end

local function PollPackLeader()
	if not hasPackLeader then
		if packLeaderPhase ~= 'off' then ClearPackLeaderState() end
		return
	end

	local hadCooldown = packLeaderHasCooldownBuff
	local hadReady = packLeaderPhase == 'ready'
	local previousBeast = packLeaderBeast

	local hasCooldownNow = AuraActive(PACK_LEADER_TALENT) or AuraActive(PACK_LEADER_COUNTDOWN)
	local readyBeast
	local beasts = Hunter.PackLeaderBeasts
	for beastIndex = 1, #beasts do
		if AuraActive(beasts[beastIndex].spell) then
			readyBeast = beasts[beastIndex]
			break
		end
	end
	local isReadyNow = readyBeast ~= nil

	local changed = false
	if isReadyNow and not hadReady then
		packLeaderPhase = 'ready'
		packLeaderBeast = readyBeast
		packLeaderNextBeastId = readyBeast.id
		packLeaderHasCooldownBuff = false
		changed = true
		SaveState()
	elseif isReadyNow then
		packLeaderBeast = readyBeast
	elseif hadReady then
		packLeaderPhase = hasCooldownNow and 'ticking' or 'off'
		packLeaderBeast = nil
		packLeaderNextBeastId = previousBeast and Hunter.NextBeastId[previousBeast.id] or 'boar'
		changed = true
		SaveState()
	end

	if hasCooldownNow ~= hadCooldown then
		packLeaderHasCooldownBuff = hasCooldownNow
		if hasCooldownNow and packLeaderPhase == 'off' then packLeaderPhase = 'ticking' end
		changed = true
	end

	if packLeaderPhase == 'ticking' and not hasCooldownNow and not isReadyNow then
		packLeaderPhase = 'off'
		changed = true
	end

	if changed then packLeaderDirty = true end
end

function Hunter.GetPackLeaderPhase()      return packLeaderPhase end
function Hunter.GetPackLeaderReadyBeast() return packLeaderBeast end
function Hunter.IsPackLeaderActive()      return hasPackLeader end
function Hunter.GetNextBeastData()        return Hunter.BeastById[packLeaderNextBeastId] end

function Hunter.ConsumePackLeaderDirty()
	if not packLeaderDirty then return false end
	packLeaderDirty = false
	return true
end

function Hunter.GetTipStacks()         return tipOfSpearStacks end
function Hunter.IsSurvivalHunter()     return isSurvival end
function Hunter.IsMarksmanshipHunter() return isMarksmanship end
function Hunter.IsBeastMastery()       return isBeastMastery end
function Hunter.IsBeastMasteryOrSurvival() return isBeastMastery or isSurvival end

function Hunter.GetPreciseShotsStacks()
	if isMarksmanship and AuraActive(PRECISE_SHOTS_BUFF) then return 2 end
	return 0
end

function Hunter.GetLockAndLoadStacks()
	if isMarksmanship and AuraActive(LOCK_AND_LOAD_BUFF) then return 1 end
	return 0
end

function Hunter.GetKillCommandStacks()
	for procIndex = 1, #NATURES_ALLY_PROCS do
		if AuraActive(NATURES_ALLY_PROCS[procIndex]) then return 1 end
	end
	return 0
end

local function HasRaptorSwipe()
	return isSurvival and AuraActive(RAPTOR_SWIPE_BUFF)
end

function Hunter.GetRaptorSwipeStacks()
	return HasRaptorSwipe() and 1 or 0
end

function Hunter.GetRaptorSwipeColorStacks()
	if not HasRaptorSwipe() then return 0 end
	return tipOfSpearStacks == 0 and 2 or 1
end

function Hunter.GetRaptorPromptStacks()
	if tipOfSpearStacks > 0 or HasRaptorSwipe() then return 0 end
	local spellID = isBeastMastery and KILL_COMMAND_BEAST_MASTERY_ID or KILL_COMMAND_SURVIVAL_ID
	if Tools.IsSpellOnCooldown(spellID) ~= true then return 0 end
	return 1
end

local function MaxBulletstormShots()
	return IsSpellKnown(ACCURACY_BY_VOLUME_TALENT) and 2 or 1
end

local function ProbeBulletstormBuff()
	if not Tools.ShouldAurasBeSecret() and not Tools.AuraQueriesBlocked() then
		for buffIndex = 1, #BULLETSTORM_BUFFS do
			local aura = GetPlayerAuraBySpellID(BULLETSTORM_BUFFS[buffIndex])
			if aura then
				local applications = Tools.SafeNum(aura.applications)
				if applications and applications > 0 then return true, applications end
				return true, nil
			end
		end
		return false
	end
	local sawFrame = false
	for buffIndex = 1, #BULLETSTORM_BUFFS do
		local entry = scan.GetEntry(BULLETSTORM_BUFFS[buffIndex])
		if entry then
			if scan.FrameHasAura(entry) then return true, nil end
			if entry.cdmFrame then sawFrame = true end
		end
	end
	if sawFrame then return false end
	return nil
end

function Hunter.GetBulletstormStacks()
	if not isMarksmanship then return 0 end
	local buffPresent, applications = ProbeBulletstormBuff()
	if buffPresent == false then
		bulletstormShotsLeft = 0
		bulletstormArmed = false
		return 0
	end
	if buffPresent == nil and bulletstormArmed and GetTime() > bulletstormArmedUntil then
		bulletstormShotsLeft = 0
		bulletstormArmed = false
		return 0
	end
	if buffPresent then
		if not bulletstormArmed then
			bulletstormArmed = true
			bulletstormShotsLeft = applications or MaxBulletstormShots()
			bulletstormArmedUntil = GetTime() + BULLETSTORM_WINDOW_SECONDS
		elseif applications then
			bulletstormShotsLeft = applications
		end
	end
	if bulletstormArmed then return bulletstormShotsLeft end
	return 0
end

local function ProbeCobraFangBuff()
	if not Tools.ShouldAurasBeSecret() and not Tools.AuraQueriesBlocked() then
		local aura = GetPlayerAuraBySpellID(COBRA_FANG_BUFF)
		if not aura then return false end
		local applications = Tools.SafeNum(aura.applications)
		if applications and applications > 0 then return true, applications end
		return true, nil
	end
	local entry = scan.GetEntry(COBRA_FANG_BUFF)
	if entry then
		if scan.FrameHasAura(entry) then return true, nil end
		if entry.cdmFrame then return false end
	end
	return nil
end

function Hunter.GetCobraFangStacks()
	if not isBeastMastery then return 0 end
	local buffPresent, applications = ProbeCobraFangBuff()
	if buffPresent == false then
		cobraFangStacks = 0
		return 0
	end
	if applications then
		cobraFangStacks = math.min(applications, COBRA_FANG_MAX_STACKS)
	end
	return cobraFangStacks
end

local function PollTipStacks()
	if not isSurvival then
		tipOfSpearStacks = 0
		return
	end
	if Tools.AuraQueriesBlocked() then return end
	local aura = GetPlayerAuraBySpellID(TIP_OF_SPEAR_BUFF)
	if not aura then
		tipOfSpearStacks = 0
		return
	end
	local applications = Tools.SafeNum(aura.applications)
	if applications and applications > 0 then
		tipOfSpearStacks = applications
	else
		tipOfSpearStacks = 1
	end
end

local lastPolledTime = -1
function Hunter.Update()
	local now = GetTime()
	if now == lastPolledTime then return end
	lastPolledTime = now
	PollTipStacks()
	PollPackLeader()
end

local function DetectSpecialization(isSpecChange)
	local specializationIndex = GetSpecialization()
	isBeastMastery = Hunter.PlayerIsHunter and specializationIndex == 1
	isMarksmanship = Hunter.PlayerIsHunter and specializationIndex == 2
	isSurvival     = Hunter.PlayerIsHunter and specializationIndex == 3
	UpdateTalents()

	tipOfSpearStacks = 0
	bulletstormShotsLeft = 0
	bulletstormArmed = false
	bulletstormArmedUntil = 0
	cobraFangStacks = 0
	ClearPackLeaderState()
	if isSpecChange then
		packLeaderNextBeastId = 'boar'
		SaveState()
	end
end

local function OnTalentChange()
	UpdateTalents()
	packLeaderDirty = true
end

local function OnSpellCast(_, _, _, spellID)
	if isMarksmanship then
		if spellID == RAPID_FIRE_SPELL then
			bulletstormShotsLeft = MaxBulletstormShots()
			bulletstormArmed = true
			bulletstormArmedUntil = GetTime() + BULLETSTORM_WINDOW_SECONDS
		elseif spellID == AIMED_SHOT_SPELL and bulletstormShotsLeft > 0 then
			bulletstormShotsLeft = bulletstormShotsLeft - 1
		end
	elseif isBeastMastery then
		if spellID == BARBED_SHOT_SPELL then
			cobraFangStacks = math.min(cobraFangStacks + COBRA_FANG_STACKS_PER_BARBED_SHOT, COBRA_FANG_MAX_STACKS)
		elseif spellID == COBRA_SHOT_SPELL then
			cobraFangStacks = 0
		end
	end
end

function Hunter.Initialize()
	RestoreState()
	DetectSpecialization(false)
	scan.ScheduleRebuild()
end

if Hunter.PlayerIsHunter then
	scan = BUI.BuffTracking.NewCDMScan(TRACKED_SPELL_IDS, UpdateTalents)
	BUI.Events:OnLogin('BuffTrackingHunter', Hunter.Initialize)
	BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'BuffTrackingHunter', function(_, unit)
		if unit == 'player' then DetectSpecialization(true) end
	end)
	BUI.Events:Register('PLAYER_TALENT_UPDATE', 'BuffTrackingHunter', OnTalentChange)
	BUI.Events:Register('TRAIT_CONFIG_UPDATED', 'BuffTrackingHunter', OnTalentChange)
	BUI.Events:Register('PLAYER_REGEN_ENABLED', 'BuffTrackingHunter', function() packLeaderDirty = true end)
	BUI.Events:RegisterUnit('UNIT_SPELLCAST_SUCCEEDED', 'player', 'BuffTrackingHunter', OnSpellCast)
end
