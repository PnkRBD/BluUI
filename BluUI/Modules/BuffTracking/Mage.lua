local _, BUI = ...

local Mage = {}
BUI.BuffTracking.Mage = Mage

local SETTINGS_KEY = 'mageArcaneSalvo'
local FRAME_NAME   = 'BUI_MageArcaneSalvo'
local SALVO_BUFF   = 1242974
local ARCANE       = 1
local SALVO_SPELLS = { [SALVO_BUFF] = true }

local playerIsMage = select(2, UnitClass('player')) == 'MAGE'
local isArcane = false

function Mage.IsArcane() return isArcane end

if not playerIsMage then return end

local Tools = BUI.Tools
local scan = BUI.BuffTracking.NewCDMScan(SALVO_SPELLS)

local function DetectSpec()
    isArcane = GetSpecialization() == ARCANE
end

local function GetStacks()
    if not isArcane then return 0 end
    if not Tools.AuraQueriesBlocked() then
        local stacks = Tools.GetAuraStacks('player', SALVO_BUFF)
        if stacks then return stacks end
    end
    local entry = scan.GetEntry(SALVO_BUFF)
    if entry ~= nil and scan.FrameHasAura(entry) then return 1 end
    return 0
end

function Mage.Initialize()
    DetectSpec()
    scan.Build()
    local Display = BUI.BuffTracking.Display
    Display.CreateTracker({
        settingsKey   = SETTINGS_KEY,
        frameName     = FRAME_NAME,
        auraSpellSet  = SALVO_SPELLS,
        stackDriver   = true,
        getStacks     = GetStacks,
        getCustomText = Display.LabelWithCount,
        isActive      = Mage.IsArcane,
        textOnly      = true,
    }).Initialize()
end

BUI.Events:OnLogin('BuffTrackingMage', Mage.Initialize, 'buffTracking')
BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'BuffTrackingMage', function(_, unit)
    if unit == 'player' then DetectSpec() end
end)
