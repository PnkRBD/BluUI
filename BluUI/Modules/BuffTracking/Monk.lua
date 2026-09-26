local _, BUI = ...

local Monk = {}
BUI.BuffTracking.Monk = Monk

local SETTINGS_KEY = 'monkVivaciousVivification'
local FRAME_NAME   = 'BUI_MonkVivaciousVivification'
local BUFF_ID      = 392883
local TRACKED_SPELL_IDS = { [BUFF_ID] = true }

local playerIsMonk = select(2, UnitClass('player')) == 'MONK'
local isMistweaver = false

function Monk.IsMistweaver() return isMistweaver end

if not playerIsMonk then return end

local scan = BUI.BuffTracking.NewCDMScan(TRACKED_SPELL_IDS)

local function DetectSpec()
    isMistweaver = GetSpecialization() == 2
end

local function GetStacks()
    if not isMistweaver then return 0 end
    local entry = scan.GetEntry(BUFF_ID)
    if entry ~= nil and scan.FrameHasAura(entry) then return 1 end
    return 0
end

function Monk.Initialize()
    DetectSpec()
    scan.Build()
    local Display = BUI.BuffTracking.Display
    local tracker = Display.CreateTracker({
        settingsKey  = SETTINGS_KEY,
        frameName    = FRAME_NAME,
        auraSpellSet = TRACKED_SPELL_IDS,
        getStacks    = GetStacks,
        isActive     = Monk.IsMistweaver,
        maxStacks    = 1,
        textOnly     = true,
    })
    tracker.Initialize()
end

BUI.Events:OnLogin('BuffTrackingMonk', Monk.Initialize, 'buffTracking')
BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'BuffTrackingMonk', function(_, unit)
    if unit == 'player' then DetectSpec() end
end)
