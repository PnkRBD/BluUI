local _, BUI = ...

local Celebrations = {}
BUI.Celebrations = Celebrations

local EVENT_KEY = 'Celebrations'
local KILLED = 1

local function Settings()
	return BUI.GetDB().celebrations
end

local function Readable(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function OnEncounterEnd(_, _, _, _, _, success)
	if not Readable(success) or success ~= KILLED then return end
	local settings = Settings()
	local _, instanceType = GetInstanceInfo()
	if instanceType == 'raid' and settings.raidBoss then
		BUI.Confetti.BurstOnScreen()
	elseif instanceType == 'party' and settings.dungeonBoss then
		BUI.Confetti.BurstOnScreen()
	end
end

local function OnKeyCompleted()
	if not Settings().timedKey then return end
	local info = C_ChallengeMode.GetChallengeCompletionInfo and C_ChallengeMode.GetChallengeCompletionInfo()
	local onTime = info and info.onTime
	if Readable(onTime) and onTime then BUI.Confetti.BurstOnScreen() end
end

function Celebrations.Test()
	BUI.Confetti.BurstOnScreen()
end

BUI.Events:OnLogin('Celebrations', function()
	BUI.Events:Register('ENCOUNTER_END', EVENT_KEY, OnEncounterEnd)
	BUI.Events:Register('CHALLENGE_MODE_COMPLETED', EVENT_KEY, OnKeyCompleted)
end)
