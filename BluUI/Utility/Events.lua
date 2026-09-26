local _, BUI = ...
local pairs, next, ipairs, type = pairs, next, ipairs, type
local debugprofilestop = debugprofilestop

local Events = {}
BUI.Events = Events

local globalFrame = CreateFrame('Frame')
local globalCallbacks = {}
local onceCallbacks = {}
local onceSnapshot = {}

globalFrame:SetScript('OnEvent', function(_, event, ...)
    if globalCallbacks[event] then
        for _, callback in pairs(globalCallbacks[event]) do
            xpcall(callback, geterrorhandler(), event, ...)
        end
    end

    if onceCallbacks[event] then
        for key, callback in pairs(onceCallbacks[event]) do
            onceSnapshot[key] = callback
        end
        for key, callback in pairs(onceSnapshot) do
            onceSnapshot[key] = nil
            if onceCallbacks[event] then
                onceCallbacks[event][key] = nil
            end
            xpcall(callback, geterrorhandler(), event, ...)
        end
        if onceCallbacks[event] and not next(onceCallbacks[event]) then
            onceCallbacks[event] = nil
            if not globalCallbacks[event] or not next(globalCallbacks[event]) then
                globalFrame:UnregisterEvent(event)
            end
        end
    end
end)

local function EnsureGlobalEvent(event)
    if not globalCallbacks[event] then
        globalCallbacks[event] = {}
        globalFrame:RegisterEvent(event)
    end
end

local function CleanupGlobalEvent(event)
    local hasGlobal = globalCallbacks[event] and next(globalCallbacks[event])
    local hasOnce = onceCallbacks[event] and next(onceCallbacks[event])
    if not hasGlobal and not hasOnce then
        globalCallbacks[event] = nil
        globalFrame:UnregisterEvent(event)
    end
end

local unitFramePool = {}
local unitCallbacks = {}
local retiredUnitFrames = {}

local function AcquireUnitFrame(event, unit)
    if not unitFramePool[event] then unitFramePool[event] = {} end
    if unitFramePool[event][unit] then return unitFramePool[event][unit] end

    local frame = table.remove(retiredUnitFrames) or CreateFrame('Frame')
    frame:RegisterUnitEvent(event, unit)
    frame:SetScript('OnEvent', function(_, firedEvent, ...)
        local handlers = unitCallbacks[firedEvent] and unitCallbacks[firedEvent][unit]
        if handlers then
            for _, callback in pairs(handlers) do
                xpcall(callback, geterrorhandler(), firedEvent, ...)
            end
        end
    end)

    unitFramePool[event][unit] = frame
    return frame
end

local function ReleaseUnitFrame(event, unit)
    if not unitFramePool[event] or not unitFramePool[event][unit] then return end
    local frame = unitFramePool[event][unit]
    frame:UnregisterAllEvents()
    frame:SetScript('OnEvent', nil)
    unitFramePool[event][unit] = nil
    retiredUnitFrames[#retiredUnitFrames + 1] = frame
    if not next(unitFramePool[event]) then unitFramePool[event] = nil end
end

function Events:Register(event, key, callback)
    EnsureGlobalEvent(event)
    globalCallbacks[event][key] = callback
end

function Events:RegisterUnit(event, units, key, callback)
    local unitList = type(units) == 'string' and { units } or units
    for _, unit in ipairs(unitList) do
        if not unitCallbacks[event] then unitCallbacks[event] = {} end
        if not unitCallbacks[event][unit] then unitCallbacks[event][unit] = {} end
        unitCallbacks[event][unit][key] = callback
        AcquireUnitFrame(event, unit)
    end
end

function Events:Once(event, key, callback)
    if not onceCallbacks[event] then onceCallbacks[event] = {} end
    onceCallbacks[event][key] = callback
    globalFrame:RegisterEvent(event)
end

function Events:Unregister(event, key)
    if globalCallbacks[event] and globalCallbacks[event][key] then
        globalCallbacks[event][key] = nil
        if not next(globalCallbacks[event]) then globalCallbacks[event] = nil end
        CleanupGlobalEvent(event)
    end

    if onceCallbacks[event] and onceCallbacks[event][key] then
        onceCallbacks[event][key] = nil
        if not next(onceCallbacks[event]) then onceCallbacks[event] = nil end
        CleanupGlobalEvent(event)
    end

    if unitCallbacks[event] then
        for unit, handlers in pairs(unitCallbacks[event]) do
            if handlers[key] then
                handlers[key] = nil
                if not next(handlers) then
                    unitCallbacks[event][unit] = nil
                    ReleaseUnitFrame(event, unit)
                end
            end
        end
        if not next(unitCallbacks[event]) then unitCallbacks[event] = nil end
    end
end

function Events:UnregisterAll(key)
    for event, handlers in pairs(globalCallbacks) do
        if handlers[key] then
            handlers[key] = nil
            if not next(handlers) then globalCallbacks[event] = nil end
            CleanupGlobalEvent(event)
        end
    end

    for event, handlers in pairs(onceCallbacks) do
        if handlers[key] then
            handlers[key] = nil
            if not next(handlers) then onceCallbacks[event] = nil end
            CleanupGlobalEvent(event)
        end
    end

    for event, units in pairs(unitCallbacks) do
        for unit, handlers in pairs(units) do
            if handlers[key] then
                handlers[key] = nil
                if not next(handlers) then
                    units[unit] = nil
                    ReleaseUnitFrame(event, unit)
                end
            end
        end
        if not next(units) then unitCallbacks[event] = nil end
    end
end

local TALENT_BURST_PRELUDES = {
    'ACTIVE_TALENT_GROUP_CHANGED', 'TRAIT_CONFIG_CREATED', 'TRAIT_CONFIG_UPDATED',
    'PLAYER_TALENT_UPDATE', 'PLAYER_PVP_TALENT_UPDATE', 'WAR_MODE_STATUS_UPDATE',
}
local TALENT_BURST_BACKSTOP_SECS = 3

local talentBurstCallbacks = {}
local talentBurstSubscribed = false
local talentBurstPending = false
local talentBurstBackstopToken = 0

local FlushTalentBurst = BUI.Dispatcher.New(function()
    if not talentBurstPending then return end
    talentBurstPending = false
    talentBurstBackstopToken = talentBurstBackstopToken + 1
    for _, callback in pairs(talentBurstCallbacks) do callback() end
end, 'TalentBurst')

local function MarkTalentBurstPending()
    talentBurstPending = true
    talentBurstBackstopToken = talentBurstBackstopToken + 1
    local myToken = talentBurstBackstopToken
    C_Timer.After(TALENT_BURST_BACKSTOP_SECS, function()
        if myToken ~= talentBurstBackstopToken then return end
        if talentBurstPending then FlushTalentBurst() end
    end)
end

local function OnTerminalSpellsChanged()
    if not talentBurstPending then return end
    FlushTalentBurst()
end

function Events:OnTalentBurst(key, callback)
    if not talentBurstSubscribed then
        talentBurstSubscribed = true
        for _, event in ipairs(TALENT_BURST_PRELUDES) do
            self:Register(event, '_TalentBurst:' .. event, MarkTalentBurstPending)
        end
        self:Register('SPELLS_CHANGED', '_TalentBurst:SPELLS_CHANGED', OnTerminalSpellsChanged)
    end
    talentBurstCallbacks[key] = callback
end

function Events:OnLogin(key, callback, module)
    if not module then
        self:Once('PLAYER_LOGIN', key, callback)
        return
    end
    self:Once('PLAYER_LOGIN', key, function(...)
        if BUI.IsModuleEnabled(module) then callback(...) end
    end)
end

local SETTLE_DELAY = 0.35
local FLUSH_BUDGET_MS = 4

local combatTasks = {}
local combatTaskOrder = {}
local combatTaskCursor = 1
local settlePending = false

local flushDriver = CreateFrame('Frame')
flushDriver:Hide()

local function FlushTick(self)
    local startTime = debugprofilestop()
    while true do
        local key = combatTaskOrder[combatTaskCursor]
        if not key then
            combatTasks, combatTaskOrder, combatTaskCursor = {}, {}, 1
            self:Hide()
            return
        end
        if InCombatLockdown() then
            self:Hide()
            return
        end
        combatTaskCursor = combatTaskCursor + 1
        local task = combatTasks[key]
        combatTasks[key] = nil
        if task then xpcall(task, geterrorhandler()) end
        if debugprofilestop() - startTime > FLUSH_BUDGET_MS then return end
    end
end

local function EnsureFlushDriver()
    if flushDriver._ready then return end
    flushDriver._ready = true
    flushDriver:SetScript('OnUpdate', FlushTick)
end

local function Enqueue(callback, key)
    key = key or tostring(callback)
    if combatTasks[key] == nil then
        combatTaskOrder[#combatTaskOrder + 1] = key
    end
    combatTasks[key] = callback
end

local function ArmSettle()
    if settlePending then return end
    settlePending = true
    C_Timer.After(SETTLE_DELAY, function()
        settlePending = false
        if InCombatLockdown() then return end
        if combatTaskOrder[combatTaskCursor] then
            EnsureFlushDriver()
            flushDriver:Show()
        end
    end)
end

function Events:AfterCombat(callback, key)
    if not InCombatLockdown() then
        callback()
        return
    end
    Enqueue(callback, key)
end

function Events:AfterCombatSettled(callback, key)
    Enqueue(callback, key)
    if InCombatLockdown() then return end
    ArmSettle()
end

Events:Register('PLAYER_REGEN_ENABLED', '_CombatQueue', function()
    if combatTaskOrder[combatTaskCursor] then ArmSettle() end
end)
