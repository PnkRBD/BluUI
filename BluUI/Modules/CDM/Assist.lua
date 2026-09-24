local _, BUI = ...

local CDM = BUI.CDM

local GetCVarBool = GetCVarBool

local LibCustomGlow = LibStub('LibCustomGlow-1.0')
local ASSIST_KEY = '_BUIAssist'
local ASSIST_LAYER = 14

local activeIcon
local lastSpellID
local hooked = false
local eventsRegistered = false
local EVENT_KEY = 'CDM.Assist'

local function ReadAssistDB()
	return BUI.GetDB().cdm.assist
end

local glowOptions = {
	duration = 1.0,
	key = ASSIST_KEY,
	frameLevel = ASSIST_LAYER,
	startAnim = false,
}

local function ApplyHighlight(icon)
	glowOptions.color = ReadAssistDB().color
	LibCustomGlow.ProcGlow_Start(icon, glowOptions)
end

local function ClearHighlight(icon)
	LibCustomGlow.ProcGlow_Stop(icon, ASSIST_KEY)
end

local function Resolve(spellID)
	if spellID == lastSpellID then return end
	lastSpellID = spellID

	local newIcon = spellID and CDM.FindIconForSpell(spellID, true) or nil
	if newIcon == activeIcon then return end

	if activeIcon then
		ClearHighlight(activeIcon)
		activeIcon = nil
	end
	if newIcon then
		ApplyHighlight(newIcon)
		activeIcon = newIcon
	end
end

local function IsHighlightEnabled()
	return GetCVarBool('assistedCombatHighlight')
end

local function CurrentSuggestion()
	return AssistedCombatManager and AssistedCombatManager.lastNextCastSpellID or nil
end

local function DesiredSpell(spellID)
	if not IsHighlightEnabled() or CDM.HighlightsSuppressed() then return nil end
	return spellID
end

local function ReEval()
	Resolve(DesiredSpell(CurrentSuggestion()))
end

local function InstallHooks()
	if hooked then return end
	local manager = AssistedCombatManager
	if not (manager and manager.UpdateAllAssistedHighlightFramesForSpell) then return end
	hooked = true

	hooksecurefunc(manager, 'UpdateAllAssistedHighlightFramesForSpell', function(_, spellID)
		Resolve(DesiredSpell(spellID))
	end)

	EventRegistry:RegisterCallback('AssistedCombatManager.OnSetUseAssistedHighlight', function()
		Resolve(DesiredSpell(CurrentSuggestion()))
	end, {})
end

local function Sync()
	InstallHooks()
	if activeIcon then
		ClearHighlight(activeIcon)
		activeIcon = nil
	end
	lastSpellID = nil
	Resolve(DesiredSpell(CurrentSuggestion()))
end

function CDM.InitAssistHighlight()
	ReadAssistDB().enabled = nil
	if not eventsRegistered then
		eventsRegistered = true
		BUI.Events:Register('PLAYER_DEAD', EVENT_KEY, ReEval)
		BUI.Events:Register('PLAYER_UNGHOST', EVENT_KEY, ReEval)
		BUI.Events:Register('PLAYER_ALIVE', EVENT_KEY, ReEval)
		BUI.Events:RegisterUnit('UNIT_SPELLCAST_START', 'player', EVENT_KEY, ReEval)
		BUI.Events:RegisterUnit('UNIT_SPELLCAST_STOP', 'player', EVENT_KEY, ReEval)
		BUI.Events:RegisterUnit('UNIT_SPELLCAST_CHANNEL_START', 'player', EVENT_KEY, ReEval)
		BUI.Events:RegisterUnit('UNIT_SPELLCAST_CHANNEL_STOP', 'player', EVENT_KEY, ReEval)
	end
	Sync()
end

function CDM.RefreshAssistHighlight()
	Sync()
end
