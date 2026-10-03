local _, BUI = ...

local Druid = {}
BUI.BuffTracking.Druid = Druid

local SETTINGS_KEY = 'druidLifebloom'
local FRAME_NAME   = 'BUI_DruidLifebloom'
local CLEARCASTING_KEY   = 'druidClearcasting'
local CLEARCASTING_FRAME = 'BUI_DruidClearcasting'
local LIFEBLOOM    = 33763
local UNDERGROWTH  = 392301
local LIFEBLOOM_SECONDS = 15
local PANDEMIC_SECONDS  = 4.5
local FERAL        = 2
local RESTORATION  = 4
local CLEARCASTING_BY_SPEC = { [FERAL] = 135700, [RESTORATION] = 16870 }
local TEXT_UPDATE_SECONDS = 0.1
local MAX_RAID_UNITS  = 40
local MAX_PARTY_UNITS = 4

local playerIsDruid = select(2, UnitClass('player')) == 'DRUID'
local spec
local isRestoration = false

function Druid.IsRestoration() return isRestoration end
function Druid.IsFeral() return spec == FERAL end
function Druid.HasClearcasting() return CLEARCASTING_BY_SPEC[spec] ~= nil end

if not playerIsDruid then return end

local Engine = BUI.AuraEngine
local Tools  = BUI.Tools

local LIFEBLOOM_SPELLS = { [LIFEBLOOM] = true }
local NO_COMPONENTS = {}
local RAID_UNITS  = {}
local PARTY_UNITS = { 'player' }
for index = 1, MAX_RAID_UNITS do RAID_UNITS[index] = 'raid' .. index end
for index = 1, MAX_PARTY_UNITS do PARTY_UNITS[index + 1] = 'party' .. index end

local tracker
local containers = {}
local buttons = {}
local textOptions = {}
local stylePending = false

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

local function GetStacks()
    return isRestoration and 1 or 0
end

local function BuildTextBinding(settings)
    local color = settings.textColor
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, CreateColor(color.r, color.g, color.b, 1))
    curve:AddPoint(settings.refreshSeconds, CreateColor(color.r, color.g, color.b, 0))
    local binding = C_DurationUtil.CreateDurationTextBinding()
    binding:SetUpdateInterval(TEXT_UPDATE_SECONDS)
    binding:SetTextFormat(settings.customText, NO_COMPONENTS)
    binding:SetTextColorCurve(curve, Enum.DurationTextBindingProperty.RemainingDuration)
    return binding
end

local function StyleText(text, settings)
    BUI.Pixel.ApplyFont(text, settings.textSize, BUI.GetModuleFont(settings), BUI.GetFontOutline())
end

local function InitButton(button)
    button:SetMouseClickEnabled(false)
    button:SetMouseMotionEnabled(false)
    local text = button:CreateFontString(nil, 'OVERLAY')
    text:SetPoint('CENTER', tracker.frame, 'CENTER')
    StyleText(text, GetSettings())
    button:SetDurationText(text, textOptions)
    button._buiRefreshText = text
    buttons[#buttons + 1] = button
end

local function ApplyButtonStyles()
    stylePending = Tools.ShouldAurasBeSecret() or Tools.AuraQueriesBlocked()
    if stylePending then return end
    for index = 1, #buttons do
        local button = buttons[index]
        button:SetDurationText(button._buiRefreshText, textOptions)
    end
end

local function ApplyPendingStyles()
    if stylePending then ApplyButtonStyles() end
end

local function ContainerAt(index)
    local container = containers[index]
    if container then return container end
    container = Engine.NewContainer(tracker.frame, false, 1)
    container:SetPoint('CENTER', tracker.frame, 'CENTER')
    container:AddAuraGroup('lifebloom', 'HELPFUL|PLAYER', {
        maxFrameCount = 1,
        candidateFilters = { includeSpellIDs = LIFEBLOOM_SPELLS },
        layout = { elementWidth = 1, elementHeight = 1, layoutIndex = 1 },
        initializeFrame = InitButton,
    })
    containers[index] = container
    return container
end

local function SyncContainers()
    local units, count = PARTY_UNITS, GetNumSubgroupMembers() + 1
    if IsInRaid() then units, count = RAID_UNITS, GetNumGroupMembers() end
    if not (isRestoration and GetSettings().enabled) then count = 0 end
    for index = 1, count do Engine.BindUnit(ContainerAt(index), units[index]) end
    for index = count + 1, #containers do Engine.BindUnit(containers[index], nil) end
end

local function Restyle()
    local settings = GetSettings()
    textOptions.binding = BuildTextBinding(settings)
    for index = 1, #buttons do StyleText(buttons[index]._buiRefreshText, settings) end
    ApplyButtonStyles()
    SyncContainers()
end

local function OnEnteringWorld()
    SyncContainers()
    ApplyPendingStyles()
end

local lifeblooms = {}

local function ClearLifeblooms()
    for index = #lifeblooms, 1, -1 do
        lifeblooms[index].timer:Cancel()
        lifeblooms[index] = nil
    end
end

local function RemoveLifebloom(entry)
    for index = #lifeblooms, 1, -1 do
        if lifeblooms[index] == entry then table.remove(lifeblooms, index) end
    end
end

local function AnnounceRefresh(entry)
    RemoveLifebloom(entry)
    local settings = GetSettings()
    if not (isRestoration and settings.enabled) then return end
    BUI.BuffTracking.Display.Announce(settings)
end

local function SoonestLifebloom()
    local soonest
    for _, entry in ipairs(lifeblooms) do
        if not soonest or entry.expires < soonest.expires then soonest = entry end
    end
    return soonest
end

local function OnLifebloomCast(_, _, _, spellID)
    if spellID ~= LIFEBLOOM or not isRestoration then return end
    local settings = GetSettings()
    if not settings.enabled then return end
    local now = GetTime()
    local soonest = SoonestLifebloom()
    local limit = IsPlayerSpell(UNDERGROWTH) and 2 or 1
    local refreshing = soonest and (#lifeblooms >= limit or soonest.expires - now <= settings.refreshSeconds)
    local carried = 0
    if refreshing then
        carried = math.min(math.max(soonest.expires - now, 0), PANDEMIC_SECONDS)
        soonest.timer:Cancel()
        RemoveLifebloom(soonest)
    end
    local entry = { expires = now + LIFEBLOOM_SECONDS + carried }
    entry.timer = C_Timer.NewTimer(math.max(entry.expires - settings.soundSeconds - now, 0), function() AnnounceRefresh(entry) end)
    lifeblooms[#lifeblooms + 1] = entry
end

local function OnSpecChanged(_, unit)
    if unit ~= 'player' then return end
    DetectSpec()
    SyncContainers()
    ClearLifeblooms()
end

function Druid.Initialize()
    DetectSpec()
    tracker = BUI.BuffTracking.Display.CreateTracker({
        settingsKey     = SETTINGS_KEY,
        frameName       = FRAME_NAME,
        getStacks       = GetStacks,
        isActive        = Druid.IsRestoration,
        maxStacks       = 1,
        textOnly        = true,
        previewTextOnly = true,
        onRefresh       = Restyle,
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
    BUI.Events:Register('GROUP_ROSTER_UPDATE', 'BuffTrackingDruid', SyncContainers)
    BUI.Events:Register('PLAYER_ENTERING_WORLD', 'BuffTrackingDruid', OnEnteringWorld)
    BUI.Events:Register('PLAYER_REGEN_ENABLED', 'BuffTrackingDruid', ApplyPendingStyles)
    BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'BuffTrackingDruid', OnSpecChanged)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_SUCCEEDED', 'player', 'BuffTrackingDruid', OnLifebloomCast)
end

BUI.Events:OnLogin('BuffTrackingDruid', Druid.Initialize, 'buffTracking')
