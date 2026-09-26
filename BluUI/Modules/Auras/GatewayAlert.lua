local _, BUI = ...

local GatewayAlert = {}
BUI.Auras.GatewayAlert = GatewayAlert

local SETTINGS_KEY    = 'gatewayAlert'
local FRAME_NAME      = 'BUI_GatewayAlert'
local EVENT_KEY       = 'GatewayAlert'
local SHARD_ITEM      = 188152
local MAX_ACTION_SLOT = 180
local POLL_INTERVAL   = 0.5
local SCAN_EVENTS     = { 'UPDATE_MACROS', 'PLAYER_ENTERING_WORLD' }
local UPDATE_EVENTS   = { 'ACTIONBAR_UPDATE_USABLE', 'ACTIONBAR_UPDATE_STATE', 'PLAYER_DEAD', 'PLAYER_ALIVE', 'PLAYER_UNGHOST' }

local tracker
local scanLive = false
local updateLive = false
local shardSlots = {}
local shardCount = 0

local function GetSettings() return BUI.GetDB()[SETTINGS_KEY] end

local function SlotHoldsShard(slot)
    if not HasAction(slot) then return nil end
    local actionType, actionID = GetActionInfo(slot)
    if actionType == 'item' then return actionID == SHARD_ITEM or nil end
    if actionType == 'macro' and actionID then
        local _, itemLink = GetMacroItem(actionID)
        if itemLink and tonumber(itemLink:match('item:(%d+)')) == SHARD_ITEM then return true end
    end
    return nil
end

local function SetSlot(slot, holds)
    if shardSlots[slot] == holds then return false end
    shardSlots[slot] = holds
    shardCount = shardCount + (holds and 1 or -1)
    return true
end

local function ScanBars()
    wipe(shardSlots)
    shardCount = 0
    for slot = 1, MAX_ACTION_SLOT do
        if SlotHoldsShard(slot) then
            shardSlots[slot] = true
            shardCount = shardCount + 1
        end
    end
end

local function OnBar()
    return shardCount > 0
end

local function GateReady()
    if shardCount == 0 or UnitIsDeadOrGhost('player') then return false end
    for slot in pairs(shardSlots) do
        local usable = IsUsableAction(slot)
        if not issecretvalue(usable) and usable then return true end
    end
    return false
end

local function GetStacks()
    return GateReady() and 1 or 0
end

local Update = BUI.Dispatcher.New(function()
    if tracker and shardCount > 0 then tracker.Update() end
end, 'Auras.GatewayAlert')

local SyncEvents

local Recheck = BUI.Dispatcher.New(function()
    SyncEvents()
    if tracker then tracker.RecheckActive() end
end, 'Auras.GatewayAlert.Scan')

local function OnSlotChanged(_, slot)
    if not slot or slot == 0 then
        ScanBars()
        Recheck()
        return
    end
    if slot > MAX_ACTION_SLOT then return end
    if SetSlot(slot, SlotHoldsShard(slot)) then Recheck() end
end

local function FullRescan()
    ScanBars()
    Recheck()
end

local function SetRegistered(events, live, wanted, callback)
    if live == wanted then return live end
    for index = 1, #events do
        if wanted then
            BUI.Events:Register(events[index], EVENT_KEY, callback)
        else
            BUI.Events:Unregister(events[index], EVENT_KEY)
        end
    end
    return wanted
end

SyncEvents = function()
    local enabled = GetSettings().enabled and true or false
    if enabled and not scanLive then ScanBars() end
    if scanLive and not enabled then
        BUI.Events:Unregister('ACTIONBAR_SLOT_CHANGED', EVENT_KEY)
        wipe(shardSlots)
        shardCount = 0
    elseif enabled and not scanLive then
        BUI.Events:Register('ACTIONBAR_SLOT_CHANGED', EVENT_KEY, OnSlotChanged)
    end
    scanLive = SetRegistered(SCAN_EVENTS, scanLive, enabled, FullRescan)
    updateLive = SetRegistered(UPDATE_EVENTS, updateLive, enabled and shardCount > 0, Update)
end

function GatewayAlert.Refresh()
    if tracker then tracker.Refresh() end
end

BUI.Events:OnLogin(EVENT_KEY, function()
    local Display = BUI.BuffTracking.Display

    tracker = Display.CreateTracker({
        settingsKey    = SETTINGS_KEY,
        frameName      = FRAME_NAME,
        getStacks      = GetStacks,
        isActive       = OnBar,
        maxStacks      = 1,
        textOnly       = true,
        updateInterval = POLL_INTERVAL,
    })
    local trackerRefresh = tracker.Refresh
    tracker.Refresh = function()
        SyncEvents()
        trackerRefresh()
    end
    tracker.Initialize()
end, 'auras')
