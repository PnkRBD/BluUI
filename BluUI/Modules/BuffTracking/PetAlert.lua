local _, BUI = ...

local PetAlert = {}
BUI.BuffTracking.PetAlert = PetAlert

local SETTINGS_KEY = 'petAlert'
local FRAME_NAME   = 'BUI_BuffTrackingPetAlert'
local EVENT_KEY    = 'BuffTrackingPetAlert'

local GRACE_SECONDS = 0.5

local playerIsHunter = select(2, UnitClass('player')) == 'HUNTER'

local active = false
local notAttackingSince = nil
local pendingTimer = nil
local activeTracker = nil

local function ShouldAlert()
    if not InCombatLockdown() then return false end
    if not UnitExists('pet') or UnitIsDead('pet') then return false end
    if not UnitExists('target') or UnitIsDead('target') then return false end
    if not UnitCanAttack('player', 'target') then return false end
    if not UnitExists('pettarget') then return false end
    local sameTarget = UnitIsUnit('pettarget', 'target')
    if issecretvalue(sameTarget) then return false end
    return not sameTarget
end

local function CancelPending()
    if pendingTimer and not pendingTimer:IsCancelled() then
        pendingTimer:Cancel()
    end
    pendingTimer = nil
end

local function SetActive(shouldBeActive)
    if active == shouldBeActive then return end
    active = shouldBeActive
    if activeTracker then activeTracker.Update() end
end

local function Reevaluate()
    if not ShouldAlert() then
        CancelPending()
        notAttackingSince = nil
        SetActive(false)
        return
    end

    local now = GetTime()
    notAttackingSince = notAttackingSince or now
    local elapsed = now - notAttackingSince

    if elapsed >= GRACE_SECONDS then
        CancelPending()
        SetActive(true)
    elseif not pendingTimer or pendingTimer:IsCancelled() then
        pendingTimer = BUI.Prof.NewTimer('BuffTracking.PetAlert', GRACE_SECONDS - elapsed, Reevaluate)
    end
end

local function GetStacks()
    return active and 1 or 0
end

function PetAlert.Create()
    if not playerIsHunter then return nil end
    local Display = BUI.BuffTracking.Display

    activeTracker = Display.CreateTracker({
        settingsKey = SETTINGS_KEY,
        frameName   = FRAME_NAME,
        getStacks   = GetStacks,
        isActive    = Display.AlwaysActive,
        maxStacks   = 1,
        textOnly    = true,
    })

    BUI.Events:RegisterUnit('UNIT_TARGET', 'pet',    EVENT_KEY, Reevaluate)
    BUI.Events:RegisterUnit('UNIT_FLAGS',  'pet',    EVENT_KEY, Reevaluate)
    BUI.Events:RegisterUnit('UNIT_FLAGS',  'target', EVENT_KEY, Reevaluate)
    BUI.Events:RegisterUnit('UNIT_PET',    'player', EVENT_KEY, Reevaluate)
    BUI.Events:Register('PLAYER_TARGET_CHANGED', EVENT_KEY, Reevaluate)
    BUI.Events:Register('PET_BAR_UPDATE',        EVENT_KEY, Reevaluate)
    BUI.Events:Register('PLAYER_REGEN_DISABLED', EVENT_KEY, Reevaluate)
    BUI.Events:Register('PLAYER_REGEN_ENABLED',  EVENT_KEY, Reevaluate)
    BUI.Events:Register('PLAYER_ENTERING_WORLD', EVENT_KEY, Reevaluate)

    return activeTracker
end
