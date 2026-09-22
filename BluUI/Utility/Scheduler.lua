local _, BUI = ...
local GetTime = GetTime
local C_Timer_After = C_Timer.After
local huge = math.huge

BUI.Scheduler = {}
local Scheduler = BUI.Scheduler

local registry = {}
local entries = {}
local activeCount = 0
local nextDue = huge
local dirty = false
local wakeScheduled = false

local frame = CreateFrame('Frame', 'BUI_SchedulerPump')
frame:Hide()

local loading = true

local loadWatcher = CreateFrame('Frame')
loadWatcher:RegisterEvent('LOADING_SCREEN_ENABLED')
loadWatcher:RegisterEvent('LOADING_SCREEN_DISABLED')
loadWatcher:RegisterEvent('PLAYER_ENTERING_WORLD')
loadWatcher:SetScript('OnEvent', function(_, event)
    if event == 'LOADING_SCREEN_ENABLED' then
        loading = true
        frame:Hide()
    else
        if not loading then return end
        loading = false
        if activeCount > 0 then frame:Show() end
    end
end)

local function RebuildEntries()
    local count = 0
    for _, entry in pairs(registry) do
        count = count + 1
        entries[count] = entry
    end
    for index = count + 1, #entries do entries[index] = nil end
    dirty = false
end

local function RecalcNextDue()
    local earliest = huge
    for index = 1, #entries do
        local entry = entries[index]
        if entry.active and entry.due < earliest then
            earliest = entry.due
        end
    end
    nextDue = earliest
end

local function ScheduleWake()
    if wakeScheduled or activeCount <= 0 then return end
    local delay = nextDue - GetTime()
    if delay < 0 then delay = 0 end
    wakeScheduled = true
    C_Timer_After(delay, function()
        wakeScheduled = false
        if activeCount > 0 and not loading then frame:Show() end
    end)
end

local function Refresh()
    RebuildEntries()
    RecalcNextDue()
    if activeCount > 0 then
        ScheduleWake()
    else
        frame:Hide()
    end
end

frame:SetScript('OnUpdate', function()
    frame:Hide()
    if loading then return end

    local now = GetTime()
    local earliest = huge
    for index = 1, #entries do
        local entry = entries[index]
        if entry.active then
            if now >= entry.due then
                entry.due = now + entry.interval
                local profiler = BUI.Prof
                if profiler.active then
                    local startKB = collectgarbage('count')
                    local startTime = debugprofilestop()
                    entry.fn()
                    profiler.Add('tick#' .. entry.name, debugprofilestop() - startTime, collectgarbage('count') - startKB)
                else
                    entry.fn()
                end
            end
            if entry.due < earliest then
                earliest = entry.due
            end
        end
    end
    nextDue = earliest

    if dirty then
        RebuildEntries()
        RecalcNextDue()
    end

    if activeCount > 0 then ScheduleWake() end
end)

function Scheduler.RegisterUpdate(name, callback, interval, active)
    local existing = registry[name]
    if existing and existing.active then activeCount = activeCount - 1 end

    local enabled = active ~= false
    registry[name] = {
        name     = name,
        fn       = callback,
        interval = interval or 0.1,
        due      = GetTime(),
        active   = enabled,
    }
    if enabled then activeCount = activeCount + 1 end
    Refresh()
end

function Scheduler.SetUpdateEnabled(name, enabled)
    local entry = registry[name]
    if not entry or entry.active == enabled then return end
    entry.active = enabled
    activeCount = activeCount + (enabled and 1 or -1)
    if enabled then entry.due = GetTime() end
    RecalcNextDue()
    if activeCount > 0 then
        ScheduleWake()
    else
        frame:Hide()
    end
end

function Scheduler.UnregisterUpdate(name)
    local entry = registry[name]
    if not entry then return end
    if entry.active then activeCount = activeCount - 1 end
    entry.active = false
    registry[name] = nil
    dirty = true
    RecalcNextDue()
    if activeCount > 0 then
        ScheduleWake()
    else
        frame:Hide()
    end
end
