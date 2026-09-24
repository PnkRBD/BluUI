local _, BUI = ...

local pairs, ipairs = pairs, ipairs
local sort = table.sort
local concat = table.concat
local min = math.min

local CDM = BUI.CDM
local Prof = BUI.Prof

local hookers = {}

function CDM.ProfHooker(viewerKey)
	viewerKey = viewerKey or 'shared'
	local hooker = hookers[viewerKey]
	if not hooker then
		hooker = Prof.MakeHooker('cdm:' .. viewerKey)
		hookers[viewerKey] = hooker
	end
	return hooker
end

local profKeys = {}

function CDM.ProfKey(name, viewerKey)
	viewerKey = viewerKey or 'shared'
	local byName = profKeys[viewerKey]
	if not byName then
		byName = {}
		profKeys[viewerKey] = byName
	end
	local profKey = byName[name]
	if not profKey then
		profKey = 'cdm:' .. viewerKey .. '.' .. name
		byName[name] = profKey
	end
	return profKey
end

local Profiler = {}
CDM.Profiler = Profiler

local GROUPS = { 'buffs', 'essential', 'utility', 'bars', 'shared' }
local GROUP_LABELS = {
	buffs = 'Buff icons',
	essential = 'Essential',
	utility = 'Utility',
	bars = 'Buff bars',
	shared = 'Shared',
}
local VIEWER_FRAMES = {
	essential = 'EssentialCooldownViewer',
	utility = 'UtilityCooldownViewer',
	buffs = 'BuffIconCooldownViewer',
	bars = 'BuffBarCooldownViewer',
}
local TRIGGERS = { 'RefreshLayout', 'OnAcquireItemFrame', 'RefreshData', 'OnActiveStateChanged' }
local SHARED_PREFIXES = { 'keybinds#', 'glow#', 'assist#', 'editmodelock#', 'procmenu#', 'tick#cdwatchpoll' }
local BAR_PREFIXES = { 'buffbarskin#', 'cdm.buffbarskin', 'timer#cdm.buffbarskin' }

local running = false
local tallies = {}
local eventTallies = {}
local hookedItems = setmetatable({}, { __mode = 'k' })
local viewersHooked = {}

for _, viewerKey in ipairs(GROUPS) do tallies[viewerKey] = {} end

local function ResetTallies()
	for _, byTrigger in pairs(tallies) do
		for trigger in pairs(byTrigger) do byTrigger[trigger] = 0 end
	end
	for name in pairs(eventTallies) do eventTallies[name] = 0 end
end

local function Tallier(viewerKey, trigger)
	local byTrigger = tallies[viewerKey]
	byTrigger[trigger] = 0
	return function()
		if running then byTrigger[trigger] = byTrigger[trigger] + 1 end
	end
end

local function HookItem(item, viewerKey)
	if hookedItems[item] then return end
	hookedItems[item] = true
	if item.RefreshData then hooksecurefunc(item, 'RefreshData', Tallier(viewerKey, 'RefreshData')) end
	if item.OnActiveStateChanged then hooksecurefunc(item, 'OnActiveStateChanged', Tallier(viewerKey, 'OnActiveStateChanged')) end
end

local function HookViewers()
	for viewerKey, frameName in pairs(VIEWER_FRAMES) do
		local viewer = _G[frameName]
		if viewer and not viewersHooked[viewerKey] then
			viewersHooked[viewerKey] = true
			if viewer.RefreshLayout then hooksecurefunc(viewer, 'RefreshLayout', Tallier(viewerKey, 'RefreshLayout')) end
			if viewer.OnAcquireItemFrame then
				local tallyAcquire = Tallier(viewerKey, 'OnAcquireItemFrame')
				hooksecurefunc(viewer, 'OnAcquireItemFrame', function(_, item)
					tallyAcquire()
					HookItem(item, viewerKey)
				end)
			end
			local pool = viewer.itemFramePool
			if pool and pool.EnumerateActive then
				for item in pool:EnumerateActive() do HookItem(item, viewerKey) end
			end
		end
	end
end

local AURA_EVENT_NAMES = {
	player = { partial = 'UNIT_AURA player', full = 'UNIT_AURA player (full)', secret = 'UNIT_AURA player (secret)' },
	target = { partial = 'UNIT_AURA target', full = 'UNIT_AURA target (full)', secret = 'UNIT_AURA target (secret)' },
}

local function AuraEventName(unit, updateInfo)
	local names = AURA_EVENT_NAMES[unit]
	if not updateInfo then return names.full end
	local isFullUpdate = updateInfo.isFullUpdate
	if issecretvalue(isFullUpdate) then return names.secret end
	return isFullUpdate and names.full or names.partial
end

local eventFrame = CreateFrame('Frame')
eventFrame:SetScript('OnEvent', function(_, event, unit, updateInfo)
	local name = event
	if event == 'UNIT_AURA' then
		name = AuraEventName(unit, updateInfo)
	end
	eventTallies[name] = (eventTallies[name] or 0) + 1
end)

local function GroupOf(key)
	local viewerKey = key:match('^cdm:(%a+)')
	if viewerKey then return tallies[viewerKey] and viewerKey or 'shared' end
	local lowered = key:lower()
	for _, prefix in ipairs(BAR_PREFIXES) do
		if lowered:sub(1, #prefix) == prefix then return 'bars' end
	end
	if lowered:find('cdm', 1, true) then return 'shared' end
	for _, prefix in ipairs(SHARED_PREFIXES) do
		if lowered:sub(1, #prefix) == prefix then return 'shared' end
	end
	return nil
end

local function PerSecond(count, seconds)
	return seconds > 0 and count / seconds or 0
end

function Profiler.IsRunning()
	return running
end

function Profiler.Start()
	HookViewers()
	ResetTallies()
	eventFrame:RegisterUnitEvent('UNIT_AURA', 'player', 'target')
	eventFrame:RegisterEvent('SPELL_UPDATE_COOLDOWN')
	eventFrame:RegisterEvent('PLAYER_TARGET_CHANGED')
	running = true
	Prof.Start()
	BUI.Print('CDM profiler running. Play normally or do a pull, then /cdm cpu again for the report.')
end

function Profiler.Stop()
	running = false
	eventFrame:UnregisterAllEvents()
	Prof.Stop()
	Profiler.Report(20)
end

function Profiler.Toggle()
	if running then
		Profiler.Stop()
	elseif Prof.active then
		BUI.Print('The full profiler is already running. Finish it with /bui cpu first.')
	else
		Profiler.Start()
	end
end

function Profiler.Report(limit)
	local data, wallTime, attributed, exact = Prof.Entries()
	local seconds = wallTime / 1000

	local rows = {}
	local groupTotals = {}
	local cdmTotal, allTotal = 0, 0
	for key, entry in pairs(data) do
		allTotal = allTotal + entry.total
		local group = GroupOf(key)
		if group then
			rows[#rows + 1] = { key = key, entry = entry, group = group }
			groupTotals[group] = (groupTotals[group] or 0) + entry.total
			cdmTotal = cdmTotal + entry.total
		end
	end
	sort(rows, function(rowA, rowB) return rowA.entry.total > rowB.entry.total end)

	BUI.Print(('CDM profile: %.1fs window. CDM handlers took %.0fms (%.2f%% of one core), %.0f%% of all instrumented BluUI time.'):format(
		seconds, cdmTotal, wallTime > 0 and (cdmTotal / wallTime * 100) or 0, allTotal > 0 and (cdmTotal / allTotal * 100) or 0))
	if attributed > 0 then
		print(('  Blizzard attributes %s%.0fms to all of BluUI in this window.'):format(exact and '' or '~', attributed))
	end

	local parts = {}
	for _, group in ipairs(GROUPS) do
		local total = groupTotals[group] or 0
		parts[#parts + 1] = ('%s |cffffd200%.0fms|r (%.2fms/s)'):format(GROUP_LABELS[group], total, PerSecond(total, seconds))
	end
	print('  By viewer: ' .. concat(parts, ', '))

	print('  Blizzard triggers per second:')
	for _, group in ipairs(GROUPS) do
		local byTrigger = tallies[group]
		if viewersHooked[group] then
			local triggerParts = {}
			for _, trigger in ipairs(TRIGGERS) do
				local count = byTrigger[trigger] or 0
				triggerParts[#triggerParts + 1] = ('%s %.1f'):format(trigger, PerSecond(count, seconds))
			end
			print(('    %s: %s'):format(GROUP_LABELS[group], concat(triggerParts, ', ')))
		end
	end

	local eventNames = {}
	for name in pairs(eventTallies) do eventNames[#eventNames + 1] = name end
	sort(eventNames)
	local eventParts = {}
	for _, name in ipairs(eventNames) do
		eventParts[#eventParts + 1] = ('%s %.1f'):format(name, PerSecond(eventTallies[name], seconds))
	end
	if #eventParts > 0 then print('    Events: ' .. concat(eventParts, ', ')) end

	BUI.Print(('Top %d CDM handlers by total time (nested handlers count more than once):'):format(min(limit, #rows)))
	for rowIndex = 1, min(limit, #rows) do
		local row = rows[rowIndex]
		local entry = row.entry
		print(('  |cff6D00FD%2d|r [%s] %s  |cffffd200%.1fms|r  n=%d (%.1f/s)  avg=%.3fms  max=%.2fms'):format(
			rowIndex, GROUP_LABELS[row.group], row.key, entry.total, entry.count, PerSecond(entry.count, seconds),
			entry.total / entry.count, entry.max))
	end
	if #rows == 0 then BUI.Print('No CDM samples recorded.') end
end
