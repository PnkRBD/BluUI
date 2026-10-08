local _, BUI = ...

local Druid = {}
BUI.BuffTracking.Druid = Druid

local SETTINGS_KEY = 'druidLifebloom'
local FRAME_NAME   = 'BUI_DruidLifebloom'
local CLEARCASTING_KEY   = 'druidClearcasting'
local CLEARCASTING_FRAME = 'BUI_DruidClearcasting'
local LIFEBLOOM    = 33763
local UNDERGROWTH  = 392301
local FLOURISH     = 197721
local OVERGROWTH   = 203651
local NATURES_SWIFTNESS = 132158
local REGROWTH     = 8936
local SWIFTNESS_SPENDERS = { [REGROWTH] = true, [20484] = true, [339] = true }
local LIFEBLOOM_SECONDS = 15
local PANDEMIC_SECONDS  = 4.5
local FLOURISH_SECONDS  = 6
local FERAL        = 2
local RESTORATION  = 4
local CLEARCASTING_BY_SPEC = { [FERAL] = 135700, [RESTORATION] = 16870 }
local TIMER_LABEL  = 'BuffTracking.Druid lifebloom'

local playerIsDruid = select(2, UnitClass('player')) == 'DRUID'
local spec
local isRestoration = false

function Druid.IsRestoration() return isRestoration end
function Druid.IsFeral() return spec == FERAL end
function Druid.HasClearcasting() return CLEARCASTING_BY_SPEC[spec] ~= nil end

if not playerIsDruid then return end

local tracker

local function GetSettings() return BUI.GetDB()[SETTINGS_KEY] end

local CLEARCASTING_SPELLS = {}
for _, spellID in pairs(CLEARCASTING_BY_SPEC) do CLEARCASTING_SPELLS[spellID] = true end
local clearcastingScan = BUI.BuffTracking.NewCDMScan(CLEARCASTING_SPELLS)

local function DetectSpec()
    spec = GetSpecialization()
    isRestoration = spec == RESTORATION
end

local function ClearcastingStacks()
    local spellID = CLEARCASTING_BY_SPEC[spec]
    local entry = spellID and clearcastingScan.GetEntry(spellID)
    if entry ~= nil and clearcastingScan.FrameHasAura(entry) then return 1 end
    return 0
end

local lifeblooms = {}
local pendingCast, pendingTarget
local swiftnessArmed = false

local function RefreshDue()
    local now, refreshSeconds = GetTime(), GetSettings().refreshSeconds
    for _, entry in ipairs(lifeblooms) do
        if entry.expires - now <= refreshSeconds then return 1 end
    end
    return 0
end

local function CancelTimers(entry)
    for _, timer in ipairs(entry.timers) do timer:Cancel() end
end

local function RemoveLifebloom(entry)
    CancelTimers(entry)
    for index = #lifeblooms, 1, -1 do
        if lifeblooms[index] == entry then table.remove(lifeblooms, index) end
    end
end

local function ClearLifeblooms()
    for index = #lifeblooms, 1, -1 do
        CancelTimers(lifeblooms[index])
        lifeblooms[index] = nil
    end
    pendingCast, pendingTarget = nil, nil
    swiftnessArmed = false
    tracker.Update()
end

local function Announce()
    local settings = GetSettings()
    if isRestoration and settings.enabled then BUI.BuffTracking.Display.Announce(settings) end
end

local function Expire(entry)
    RemoveLifebloom(entry)
    tracker.Update()
end

local function After(seconds, callback)
    return BUI.Profiler.NewTimer(TIMER_LABEL, math.max(seconds, 0), callback)
end

local function Schedule(entry, settings)
    if entry.timers then CancelTimers(entry) end
    local left = entry.expires - GetTime()
    entry.timers = {
        After(left - settings.soundSeconds, Announce),
        After(left - settings.refreshSeconds, tracker.Update),
        After(left, function() Expire(entry) end),
    }
end

local function SoonestLifebloom()
    local soonest
    for _, entry in ipairs(lifeblooms) do
        if not soonest or entry.expires < soonest.expires then soonest = entry end
    end
    return soonest
end

local function LifebloomOn(target)
    for _, entry in ipairs(lifeblooms) do
        if entry.target == target then return entry end
    end
end

local function OnCastSent(_, _, target, castGUID, spellID)
    if (spellID == LIFEBLOOM or spellID == REGROWTH) and not issecretvalue(target) then pendingCast, pendingTarget = castGUID, target end
end

local function OnLifebloomCast(target, settings)
    local now = GetTime()
    local limit = IsPlayerSpell(UNDERGROWTH) and 2 or 1
    local refreshed = target and LifebloomOn(target)
    local soonest = SoonestLifebloom()
    local replaced = refreshed or (soonest and (#lifeblooms >= limit or (not target and soonest.expires - now <= settings.refreshSeconds)) and soonest)
    local carried = 0
    if replaced then
        if refreshed or not target then carried = math.min(math.max(replaced.expires - now, 0), PANDEMIC_SECONDS) end
        RemoveLifebloom(replaced)
    end
    local entry = { target = target, expires = now + LIFEBLOOM_SECONDS + carried }
    Schedule(entry, settings)
    lifeblooms[#lifeblooms + 1] = entry
    tracker.Update()
end

local function OnFlourish(settings)
    for _, entry in ipairs(lifeblooms) do
        entry.expires = entry.expires + FLOURISH_SECONDS
        Schedule(entry, settings)
    end
    tracker.Update()
end

local function OnPlayerCast(_, _, castGUID, spellID)
    local target
    if castGUID == pendingCast then
        target = pendingTarget
        pendingCast, pendingTarget = nil, nil
    end
    if not isRestoration then return end
    local settings = GetSettings()
    if not settings.enabled then return end
    if spellID == LIFEBLOOM then
        OnLifebloomCast(target, settings)
    elseif spellID == FLOURISH then
        OnFlourish(settings)
    elseif spellID == NATURES_SWIFTNESS then
        swiftnessArmed = true
    elseif swiftnessArmed and SWIFTNESS_SPENDERS[spellID] then
        swiftnessArmed = false
        if spellID == REGROWTH and IsPlayerSpell(OVERGROWTH) then OnLifebloomCast(target, settings) end
    end
end

local function OnSpecChanged(_, unit)
    if unit ~= 'player' then return end
    DetectSpec()
    ClearLifeblooms()
end

function Druid.Initialize()
    DetectSpec()
    tracker = BUI.BuffTracking.Display.CreateTracker({
        settingsKey = SETTINGS_KEY,
        frameName   = FRAME_NAME,
        getStacks   = RefreshDue,
        isActive    = Druid.IsRestoration,
        maxStacks   = 1,
        textOnly    = true,
        quiet       = true,
    })
    tracker.Initialize()
    clearcastingScan.Build()
    BUI.BuffTracking.Display.CreateTracker({
        settingsKey  = CLEARCASTING_KEY,
        frameName    = CLEARCASTING_FRAME,
        auraSpellSet = CLEARCASTING_SPELLS,
        getStacks    = ClearcastingStacks,
        isActive     = Druid.HasClearcasting,
        maxStacks    = 1,
        textOnly     = true,
    }).Initialize()
    BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'BuffTrackingDruid', OnSpecChanged)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_SENT', 'player', 'BuffTrackingDruid', OnCastSent)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_SUCCEEDED', 'player', 'BuffTrackingDruid', OnPlayerCast)
end

BUI.Events:OnLogin('BuffTrackingDruid', Druid.Initialize, 'buffTracking')
