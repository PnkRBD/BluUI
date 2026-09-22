local _, BUI = ...

local Datatext = BUI.Datatext

local localHour, localMinute = -1, -1
local realmHour, realmMinute = -1, -1

local raids, dungeons, worldBosses = {}, {}, {}

local function ReadClock()
    local localTime = date('*t')
    local realmTime = C_DateAndTime.GetCurrentCalendarTime()
    local newLocalHour, newLocalMinute = localTime.hour, localTime.min
    local newRealmHour, newRealmMinute = realmTime.hour, realmTime.minute
    if newLocalHour ~= localHour or newLocalMinute ~= localMinute or newRealmHour ~= realmHour or newRealmMinute ~= realmMinute then
        localHour, localMinute, realmHour, realmMinute = newLocalHour, newLocalMinute, newRealmHour, newRealmMinute
        return true
    end
end

local function FormatClock(hour, minute, twentyFour)
    if twentyFour then return string.format('%02d:%02d', hour, minute) end
    local suffix = hour >= 12 and 'PM' or 'AM'
    local displayHour = hour % 12
    if displayHour == 0 then displayHour = 12 end
    return string.format('%d:%02d %s', displayHour, minute, suffix)
end

local function SortByName(first, second) return first.name < second.name end

local function ReadLockouts()
    wipe(raids); wipe(dungeons); wipe(worldBosses)
    for instanceIndex = 1, GetNumSavedInstances() do
        local name, _, reset, _, locked, extended, _, isRaid, _, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(instanceIndex)
        if name and (locked or extended) then
            local list = isRaid and raids or dungeons
            list[#list + 1] = {
                name = name, reset = reset, extended = extended,
                difficulty = difficultyName, encounters = numEncounters, progress = encounterProgress,
            }
        end
    end
    table.sort(raids, SortByName)
    table.sort(dungeons, SortByName)
    for bossIndex = 1, GetNumSavedWorldBosses() do
        local name, _, reset = GetSavedWorldBossInfo(bossIndex)
        if name then worldBosses[#worldBosses + 1] = { name = name, reset = reset } end
    end
    table.sort(worldBosses, SortByName)
end

local function ResetText(seconds)
    if not seconds or seconds <= 0 then return '--' end
    return SecondsToTime(seconds, true, nil, 2)
end

local function AddLockoutRows(tooltip, list)
    for rowIndex = 1, #list do
        local lockout = list[rowIndex]
        local left = lockout.name
        if lockout.difficulty and lockout.difficulty ~= '' then left = left .. ' |cff8a8a90(' .. lockout.difficulty .. ')|r' end
        if lockout.encounters and lockout.encounters > 0 then
            left = left .. ' |cff8a8a90' .. (lockout.progress or 0) .. '/' .. lockout.encounters .. '|r'
        end
        local red, green, blue = 0.8, 0.8, 0.8
        if lockout.extended then red, green, blue = 0.3, 1, 0.3 end
        tooltip:AddDoubleLine(left, ResetText(lockout.reset), 1, 1, 1, red, green, blue)
    end
end

Datatext.Register('time', {
    name = 'Time', show = 'showTime', label = 'Time:',
    events = { 'UPDATE_INSTANCE_INFO', 'BOSS_KILL', 'PLAYER_ENTERING_WORLD' },
    interval = 1,
    defaults = { time24 = false, timeLocal = true },
    OnActivate = function()
        RequestRaidInfo()
    end,
    OnEvent = function(event)
        if event == 'UPDATE_INSTANCE_INFO' then
            ReadLockouts()
        else
            RequestRaidInfo()
        end
    end,
    OnUpdate = function()
        if ReadClock() then Datatext.Refresh() end
    end,
    build = function(config, valueHex, self)
        local hour, minute = localHour, localMinute
        if config.timeLocal == false then hour, minute = realmHour, realmMinute end
        if hour < 0 then return '' end
        return Datatext.Label(config, self) .. Datatext.Colored(FormatClock(hour, minute, config.time24), valueHex)
    end,
    OnClick = function(_, button)
        if button ~= 'LeftButton' or InCombatLockdown() then return end
        if ToggleCalendar then ToggleCalendar() end
        return true
    end,
    OnEnter = function(hit, bar)
        local config = bar.getConfig()
        local twentyFour = config and config.time24
        local tooltip = Datatext.Tooltip(hit)
        tooltip:AddLine('Time', 1, 1, 1)
        tooltip:AddDoubleLine('Local', FormatClock(localHour, localMinute, twentyFour), 0.7, 0.7, 0.7, 1, 1, 1)
        tooltip:AddDoubleLine('Realm', FormatClock(realmHour, realmMinute, twentyFour), 0.7, 0.7, 0.7, 1, 1, 1)

        local daily = C_DateAndTime.GetSecondsUntilDailyReset()
        local weekly = C_DateAndTime.GetSecondsUntilWeeklyReset()
        tooltip:AddLine(' ')
        tooltip:AddDoubleLine('Daily Reset', ResetText(daily), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
        tooltip:AddDoubleLine('Weekly Reset', ResetText(weekly), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)

        if #raids > 0 then
            tooltip:AddLine(' ')
            tooltip:AddLine('Saved Raids', 1, 1, 1)
            AddLockoutRows(tooltip, raids)
        end
        if #dungeons > 0 then
            tooltip:AddLine(' ')
            tooltip:AddLine('Saved Dungeons', 1, 1, 1)
            AddLockoutRows(tooltip, dungeons)
        end
        if #worldBosses > 0 then
            tooltip:AddLine(' ')
            tooltip:AddLine('World Bosses', 1, 1, 1)
            for bossIndex = 1, #worldBosses do
                local boss = worldBosses[bossIndex]
                tooltip:AddDoubleLine(boss.name, ResetText(boss.reset), 1, 1, 1, 0.8, 0.8, 0.8)
            end
        end

        tooltip:AddLine(' ')
        tooltip:AddLine('Left-Click  |cffffffffCalendar|r', 1, 0.82, 0)
        tooltip:Show()
    end,
    options = function(getConfig, apply)
        return {
            {
                label = '24-Hour Clock',
                get = function() return getConfig().time24 == true end,
                set = function(value) getConfig().time24 = value; apply() end,
            },
            {
                label = 'Local Time',
                get = function() return getConfig().timeLocal ~= false end,
                set = function(value) getConfig().timeLocal = value; apply() end,
            },
        }
    end,
    sample = function(config, label, colorize) return label .. colorize(FormatClock(14, 30, config.time24)) end,
})
