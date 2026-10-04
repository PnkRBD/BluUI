local addonName, BUI = ...

local debugprofilestop, GetTime, InCombatLockdown, hooksecurefunc, issecurevariable = debugprofilestop, GetTime, InCombatLockdown, hooksecurefunc, issecurevariable
local pairs, ipairs, sort, format, concat, wipe, remove, max = pairs, ipairs, table.sort, string.format, table.concat, wipe, table.remove, math.max
local GetAddOnMetric = C_AddOnProfiler.GetAddOnMetric
local GetOverallMetric = C_AddOnProfiler.GetOverallMetric
local GetApplicationMetric = C_AddOnProfiler.GetApplicationMetric
local GetTopKAddOnsForMetric = C_AddOnProfiler.GetTopKAddOnsForMetric
local Metric = Enum.AddOnProfilerMetric

local Profiler = { active = false }
BUI.Profiler = Profiler

local HITCH_MS = 30
local HITCH_KEEP = 100
local TOP_HITCHES = 5
local PREVIEW_TOTAL = 8
local TOP_TOTAL = 15
local TOP_MAX = 10
local TOP_IN_FRAME = 4
local TOP_ADDONS = 5
local CALIBRATION_CALLS = 2000
local SPIKE_MS = 50
local GAME_SPIKE_MS = 50
local TOP_SPIKE_ADDONS = 3
local SPIKE_KEEP = 60
local TOP_SPIKES = 6
local LOADING_GRACE = 3
local STARTUP_WINDOW = 15
local COUNTERS = {
	{ label = '5ms', metric = Metric.CountTimeOver5Ms },
	{ label = '10ms', metric = Metric.CountTimeOver10Ms },
	{ label = '50ms', metric = Metric.CountTimeOver50Ms },
	{ label = '100ms', metric = Metric.CountTimeOver100Ms },
	{ label = '500ms', metric = Metric.CountTimeOver500Ms },
}
local STYLE_LABELS = { ['BluUI'] = 'Unit frame', ['BluUI-Group'] = 'Group frame' }
local AREA_ALIASES = {
	['Group frame'] = 'GroupFrames', ['Unit frame'] = 'UnitFrames', GF = 'GroupFrames', UF = 'UnitFrames',
	CB = 'CastBar', Skin = 'Skins', Skinning = 'Skins', Glow = 'Glows',
}
local TOP_AREAS = 8
local TOP_IN_AREA = 5
local ACTION_LIBRARY = 'LibActionButton-1.0-BluUI'
local SHARED_LIBRARIES = {
	{ major = 'LibCustomGlow-1.0', probe = 'PixelGlow_Start' },
	{ major = 'LibRangeCheck-3.0', probe = 'GetRange' },
	{ major = 'LibSharedMedia-3.0', probe = 'Fetch' },
	{ major = 'LibKeyBound-1.0', probe = 'Toggle' },
}
local GLOWS = {
	{ start = 'PixelGlow_Start', label = 'Glow pixel', keyArg = 10, prefix = '_PixelGlow' },
	{ start = 'AutoCastGlow_Start', label = 'Glow autocast', keyArg = 8, prefix = '_AutoCastGlow' },
	{ start = 'ButtonGlow_Start', label = 'Glow button', prefix = '_ButtonGlow' },
}

local FILE_LOAD_LABEL = 'Loading BluUI files'
local fileLoadStart = debugprofilestop()

local ALERT_MS = 100
local ALERT_GAP = 30

local stats, frameSpent, lastSpent, hitches, labels, baseline, libraryOwners = {}, {}, {}, {}, {}, {}, {}
local noted, lastNoted, unseen = {}, {}, {}
local scriptWrappers = setmetatable({}, { __mode = 'kv' })
local frameTotal, lastTotal, depth, watchDepth, notedTotal = 0, 0, 0, 0, 0
local lastAlertAt = 0
local seenOver, unseenCount = GetAddOnMetric(addonName, Metric.CountTimeOver50Ms), 0
local namedTotal, actualTotal, ticks = 0, 0, 0
local startedAt, stoppedAt = 0, 0
local overheadPerCall = 0
local loginPending = false
local spikes, spikeCount = {}, 0
local loadedAt, loadingScreen, loadingEndedAt = GetTime(), true, 0

local function TopOf(map, count, field)
	local list = {}
	for label, value in pairs(map) do list[#list + 1] = { label = label, value = field and value[field] or value } end
	sort(list, function(left, right) return left.value > right.value end)
	for index = count + 1, #list do list[index] = nil end
	return list
end

local function Combined(first, second)
	local combined = {}
	for label, spent in pairs(first) do combined[label] = spent end
	for label, spent in pairs(second) do combined[label] = (combined[label] or 0) + spent end
	return combined
end

function Profiler.Label(group, key)
	local byKey = labels[group]
	if not byKey then
		byKey = {}
		labels[group] = byKey
	end
	local label = byKey[key]
	if not label then
		label = group .. ' ' .. tostring(key)
		byKey[key] = label
	end
	return label
end

local function Record(label, elapsed)
	local stat = stats[label]
	if not stat then
		stat = { total = 0, own = 0, calls = 0, max = 0 }
		stats[label] = stat
	end
	stat.total = stat.total + elapsed
	stat.calls = stat.calls + 1
	if elapsed > stat.max then stat.max = elapsed end
	if depth > 0 then return end
	stat.own = stat.own + elapsed
	frameSpent[label] = (frameSpent[label] or 0) + elapsed
	frameTotal = frameTotal + elapsed
	namedTotal = namedTotal + elapsed
end

local running, runningDepth = {}, 0
local tracer

local function Enter(label)
	local mine = runningDepth + 1
	runningDepth = mine
	running[mine] = label
	return mine
end

local function Leave(label, start, elapsed, mine)
	runningDepth = mine - 1
	if tracer then tracer(label, start, elapsed, mine, running[mine - 1]) end
end

local function Close(label, start, mine, ...)
	depth = depth - 1
	local elapsed = debugprofilestop() - start
	Record(label, elapsed)
	Leave(label, start, elapsed, mine)
	return ...
end

local function Run(label, callback, ...)
	depth = depth + 1
	local mine = Enter(label)
	return Close(label, debugprofilestop(), mine, callback(...))
end

local function Settle(label, start, mine, ...)
	watchDepth = watchDepth - 1
	local elapsed = debugprofilestop() - start
	noted[label] = (noted[label] or 0) + elapsed
	if watchDepth == 0 then notedTotal = notedTotal + elapsed end
	Leave(label, start, elapsed, mine)
	return ...
end

local function Watch(label, callback, ...)
	watchDepth = watchDepth + 1
	local mine = Enter(label)
	return Settle(label, debugprofilestop(), mine, callback(...))
end

function Profiler.SetTracer(callback)
	tracer = callback
end

function Profiler.Run(label, callback, ...)
	if not Profiler.active then return Watch(label, callback, ...) end
	return Run(label, callback, ...)
end

local function SpikeContext()
	local parts = {}
	if GetTime() - loadedAt < STARTUP_WINDOW then parts[#parts + 1] = 'just after reload' end
	if loadingScreen or GetTime() - loadingEndedAt < LOADING_GRACE then parts[#parts + 1] = 'loading screen' end
	if InCombatLockdown() then parts[#parts + 1] = 'in combat' end
	local window = BUI.PageEngine and BUI.PageEngine.frame
	if window and window:IsShown() then parts[#parts + 1] = 'settings window open' end
	parts[#parts + 1] = GetRealZoneText()
	return concat(parts, ', ')
end

local function HeaviestAddOns()
	local parts = {}
	for _, entry in ipairs(GetTopKAddOnsForMetric(Metric.LastTime, TOP_SPIKE_ADDONS)) do
		parts[#parts + 1] = format('%s %.0f', entry.addOnName, entry.metricValue)
	end
	return concat(parts, ', ')
end

local function RecordSpike(game, addons, actual)
	spikeCount = spikeCount + 1
	spikes[#spikes + 1] = {
		at = GetTime(), game = game, addons = addons, actual = actual, context = SpikeContext(), heaviest = HeaviestAddOns(),
		top = TopOf(Profiler.active and Combined(lastSpent, frameSpent) or Combined(lastNoted, noted), TOP_IN_FRAME),
	}
	if #spikes > SPIKE_KEEP then remove(spikes, 1) end
end

local function RecordUnseen(count)
	unseenCount = unseenCount + count
	local work = Profiler.active and Combined(frameSpent, noted) or noted
	local named = notedTotal + (Profiler.active and frameTotal or 0)
	unseen[#unseen + 1] = { at = GetTime(), count = count, named = named, context = SpikeContext(), top = TopOf(work, TOP_IN_FRAME) }
	if #unseen > SPIKE_KEEP then remove(unseen, 1) end
end

local function TopParts(top)
	local parts = {}
	for _, item in ipairs(top) do parts[#parts + 1] = format('%s %.0f', item.label, item.value) end
	return concat(parts, '; ')
end

local function AlertSpike(actual)
	local global = BUI.db and BUI.db.global
	if not (global and global.profileAlerts) or loadingScreen then return end
	local now = GetTime()
	if now - lastAlertAt < ALERT_GAP or now - loadedAt < STARTUP_WINDOW then return end
	lastAlertAt = now
	local top = spikes[#spikes].top
	BUI.Print(format('a frame took %.0fms in BluUI (%s)%s. /bui profile report for more.',
		actual, SpikeContext(), #top > 0 and ': ' .. TopParts(top) or ', nothing named'))
end

local driver = CreateFrame('Frame')
driver:SetScript('OnUpdate', function()
	depth, watchDepth = 0, 0
	local actual = GetAddOnMetric(addonName, Metric.LastTime)
	local addons = GetOverallMetric(Metric.LastTime)
	local game = GetApplicationMetric(Metric.LastTime)
	local over = GetAddOnMetric(addonName, Metric.CountTimeOver50Ms)
	local missed = over - seenOver - (actual >= SPIKE_MS and 1 or 0)
	seenOver = over
	if missed > 0 then RecordUnseen(missed) end
	if actual >= SPIKE_MS or addons >= SPIKE_MS or game >= GAME_SPIKE_MS then
		RecordSpike(game, addons, actual)
		if actual >= ALERT_MS then AlertSpike(actual) end
	end
	lastNoted, noted = noted, lastNoted
	wipe(noted)
	notedTotal = 0
	if not Profiler.active then return end
	actualTotal = actualTotal + actual
	ticks = ticks + 1
	if loginPending then
		loginPending = false
		local unnamed = actual - lastTotal - frameTotal
		if unnamed > 0 then Record('Login loading and setup', unnamed) end
	end
	if actual >= HITCH_MS then
		hitches[#hitches + 1] = { at = GetTime(), actual = actual, named = lastTotal + frameTotal, top = TopOf(Combined(lastSpent, frameSpent), TOP_IN_FRAME) }
		if #hitches > HITCH_KEEP then remove(hitches, 1) end
	end
	lastSpent, frameSpent = frameSpent, lastSpent
	wipe(frameSpent)
	lastTotal, frameTotal = frameTotal, 0
end)

function Profiler.Wrap(label, callback)
	return function(...)
		if not Profiler.active then return Watch(label, callback, ...) end
		return Run(label, callback, ...)
	end
end

function Profiler.Hot(label, callback)
	return function(...)
		if not Profiler.active then return callback(...) end
		return Run(label, callback, ...)
	end
end

function Profiler.Script(label, callback)
	if callback == nil then return nil end
	local wrapper = scriptWrappers[callback]
	if not wrapper then
		wrapper = Profiler.Wrap(label, callback)
		scriptWrappers[callback] = wrapper
	end
	return wrapper
end

local hookers = {}

function Profiler.Hooker(group)
	local hooker = hookers[group]
	if not hooker then
		hooker = function(target, method, callback)
			if callback == nil then
				hooksecurefunc(target, Profiler.Wrap(Profiler.Label(group, target), method))
			else
				hooksecurefunc(target, method, Profiler.Wrap(Profiler.Label(group, method), callback))
			end
		end
		hookers[group] = hooker
	end
	return hooker
end

function Profiler.After(label, delay, callback)
	C_Timer.After(delay, Profiler.Wrap(label, callback))
end

function Profiler.NewTimer(label, delay, callback)
	return C_Timer.NewTimer(delay, Profiler.Wrap(label, callback))
end

local function LibraryOwner(entry)
	local owner = libraryOwners[entry.major]
	if owner == nil then
		local library = LibStub(entry.major, true)
		local taint = library and library[entry.probe] and select(2, issecurevariable(library, entry.probe))
		owner = taint or false
		libraryOwners[entry.major] = owner
	end
	return owner
end

local function TimeScript(frame, script, label)
	if not frame then return end
	local handler = frame:GetScript(script)
	local key = '_bluTimed' .. script
	if not handler or handler == frame[key] then return end
	frame[key] = Profiler.Wrap(label, handler)
	frame:SetScript(script, frame[key])
end

local function TimeEvents(frame, group)
	local onEvent = frame:GetScript('OnEvent')
	if not onEvent or onEvent == frame._bluTimedEvents then return end
	frame._bluTimedEvents = function(self, event, ...)
		return Profiler.Run(Profiler.Label(group, event), onEvent, self, event, ...)
	end
	frame:SetScript('OnEvent', frame._bluTimedEvents)
end

local glowsWatched = false

local function WatchGlows()
	if glowsWatched then return end
	glowsWatched = true
	for _, entry in ipairs(SHARED_LIBRARIES) do LibraryOwner(entry) end
	if libraryOwners['LibCustomGlow-1.0'] ~= addonName then return end
	local glowLibrary = LibStub('LibCustomGlow-1.0')
	for _, glow in ipairs(GLOWS) do
		local keyArg, prefix, label = glow.keyArg, glow.prefix, glow.label
		hooksecurefunc(glowLibrary, glow.start, function(target, ...)
			if not Profiler.active then return end
			local key = keyArg and select(keyArg - 1, ...)
			TimeScript(target[prefix .. (keyArg and (key or '') or '')], 'OnUpdate', label)
		end)
	end
end

local function StyleLabel(object)
	return STYLE_LABELS[object.style] or object.style
end

local tagOriginals, tagWrappers = {}, {}
local oUFHooked = false

local function FieldName(object, region)
	for key, value in pairs(object) do
		if value == region then return key end
	end
	return 'tag'
end

local function TimeTag(object, fontString)
	local update = fontString.UpdateTag
	if not update or update == tagWrappers[fontString] then return end
	local wrapper = Profiler.Wrap(Profiler.Label(StyleLabel(object) .. ' text', FieldName(object, fontString)), update)
	tagOriginals[fontString], tagWrappers[fontString] = update, wrapper
	fontString.UpdateTag = wrapper
end

local function TimeTagsIn(object, frame)
	if rawget(frame, '_buiAuraContainer') then return end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.__owner == object then TimeTag(object, region) end
	end
	for _, child in ipairs({ frame:GetChildren() }) do TimeTagsIn(object, child) end
end

local function OnTag(object, fontString)
	if Profiler.active then TimeTag(object, fontString) end
end

local function RestoreTags()
	for fontString, original in pairs(tagOriginals) do
		if fontString.UpdateTag == tagWrappers[fontString] then fontString.UpdateTag = original end
	end
	wipe(tagOriginals)
	wipe(tagWrappers)
end

local function HookOUF(methods)
	oUFHooked = true
	hooksecurefunc(methods, 'Tag', OnTag)
	local updateAll = methods.UpdateAllElements
	methods.UpdateAllElements = function(self, event)
		return Profiler.Run(Profiler.Label(StyleLabel(self), 'full update'), updateAll, self, event)
	end
end

local function TimeUnitFrame(object)
	if not oUFHooked then HookOUF(getmetatable(object).__index) end
	if Profiler.active then TimeTagsIn(object, object) end
	if object._bluProfiled or object:GetAttribute('oUF-enableArenaPrep') then return end
	if object:IsProtected() and InCombatLockdown() then return end
	object._bluProfiled = true
	local style = StyleLabel(object)
	local onEvent = object:GetScript('OnEvent')
	if onEvent then
		object:SetScript('OnEvent', function(self, event, ...)
			return Profiler.Run(Profiler.Label(style, event), onEvent, self, event, ...)
		end)
	end
	local castbar = object.Castbar
	local castUpdate = castbar and (castbar.OnUpdate or castbar:GetScript('OnUpdate'))
	if castUpdate then
		castbar.OnUpdate = Profiler.Wrap(style .. ' cast bar', castUpdate)
		if castbar:GetScript('OnUpdate') then castbar:SetScript('OnUpdate', castbar.OnUpdate) end
	end
end

local unitFramesWatched = false

local function TimeUnitFrames()
	if not unitFramesWatched then
		unitFramesWatched = true
		BUI.oUF:RegisterInitCallback(TimeUnitFrame)
	end
	for _, object in ipairs(BUI.oUF.objects) do TimeUnitFrame(object) end
	if InCombatLockdown() then BUI.Events:AfterCombat(TimeUnitFrames, 'Profiler.UnitFrames') end
end

local actionButtonsHooked = false

local function TimeActionButtons()
	local library = LibStub(ACTION_LIBRARY, true)
	if not library then return end
	if not actionButtonsHooked then
		actionButtonsHooked = true
		hooksecurefunc(library, 'CreateButton', TimeActionButtons)
	end
	TimeEvents(library.eventFrame, 'ActionBars.Library')
	TimeScript(library.eventFrame, 'OnUpdate', 'ActionBars.Library range and flash')
	TimeScript(library.cooldownPassFrame, 'OnUpdate', 'ActionBars.Library cooldown pass')
end

local function Calibrate()
	local probe = function() end
	local start = debugprofilestop()
	for _ = 1, CALIBRATION_CALLS do Run('', probe) end
	overheadPerCall = (debugprofilestop() - start) / CALIBRATION_CALLS
end

function Profiler.Start()
	Calibrate()
	wipe(stats)
	wipe(frameSpent)
	wipe(lastSpent)
	wipe(hitches)
	frameTotal, lastTotal, depth = 0, 0, 0
	namedTotal, actualTotal, ticks = 0, 0, 0
	startedAt = GetTime()
	for _, counter in ipairs(COUNTERS) do baseline[counter.label] = GetAddOnMetric(addonName, counter.metric) end
	Profiler.active = true
	WatchGlows()
	TimeUnitFrames()
	TimeActionButtons()
end

function Profiler.Stop()
	Profiler.active = false
	stoppedAt = GetTime()
	RestoreTags()
end

local function AddOnComparison(metric)
	local parts = {}
	for _, entry in ipairs(GetTopKAddOnsForMetric(metric, TOP_ADDONS)) do
		parts[#parts + 1] = format('%s %.2f', entry.addOnName, entry.metricValue)
	end
	return format('BluUI %.2f, all addons %.2f. Heaviest: %s', GetAddOnMetric(addonName, metric), GetOverallMetric(metric), concat(parts, ', '))
end

local function SharedLibraryLine()
	local billedHere, billedElsewhere = {}, {}
	for _, entry in ipairs(SHARED_LIBRARIES) do
		local owner = LibraryOwner(entry)
		if owner == addonName then
			billedHere[#billedHere + 1] = entry.major
		elseif owner then
			billedElsewhere[#billedElsewhere + 1] = format('%s to %s', entry.major, owner)
		end
	end
	return format('Shared libraries running BluUI\'s copy, so every addon\'s use of them counts as BluUI: %s. Running another addon\'s copy, so BluUI\'s use counts there: %s.',
		#billedHere > 0 and concat(billedHere, ', ') or 'none', #billedElsewhere > 0 and concat(billedElsewhere, ', ') or 'none')
end

local function AreaOf(label)
	local key = label:match('^[%u_]+ (.+)$')
	if key then label = key end
	local area = label:match('(%a+)%.%a') or label:match('^(%a+ frame) ') or label:match('^(%a+)') or label
	return AREA_ALIASES[area] or area
end

local function Areas()
	local totals, members = {}, {}
	for label, stat in pairs(stats) do
		local area = AreaOf(label)
		totals[area] = (totals[area] or 0) + stat.own
		local inArea = members[area]
		if not inArea then
			inArea = {}
			members[area] = inArea
		end
		inArea[label] = stat.total
	end
	return TopOf(totals, TOP_AREAS), members
end

local function HitchLine(hitch)
	return format('  +%.0fs: %.0fms, %.0f named. %s', hitch.at - startedAt, hitch.actual, hitch.named, TopParts(hitch.top))
end

local function Clock(seconds)
	seconds = math.floor(seconds)
	return format('%dm%02ds', math.floor(seconds / 60), seconds % 60)
end

local function SpikeLine(spike)
	local line = format('  %s after reload: game %.0fms, all addons %.0fms, BluUI %.0fms (%s). Heaviest: %s',
		Clock(spike.at - loadedAt), spike.game, spike.addons, spike.actual, spike.context, spike.heaviest)
	if #spike.top == 0 then return line end
	return line .. '. BluUI handlers: ' .. TopParts(spike.top)
end

local function UnseenLine(entry)
	local line = format('  %s after reload: %d %s (%s), %.0fms of BluUI work named',
		Clock(entry.at - loadedAt), entry.count, entry.count == 1 and 'frame' or 'frames', entry.context, entry.named)
	if #entry.top == 0 then return line end
	return line .. ': ' .. TopParts(entry.top)
end

local function AddUnseenSpikes(lines)
	lines[#lines + 1] = format('Blizzard counts BluUI frames since load over 50ms: %d, over 100ms: %d. %d of the over-50ms frames came while BluUI could not watch frame by frame (login, loading screens). Biggest:',
		GetAddOnMetric(addonName, Metric.CountTimeOver50Ms), GetAddOnMetric(addonName, Metric.CountTimeOver100Ms), unseenCount)
	local biggest = {}
	for index, entry in ipairs(unseen) do biggest[index] = entry end
	sort(biggest, function(left, right) return left.named > right.named end)
	for index = 1, math.min(TOP_SPIKES, #biggest) do lines[#lines + 1] = UnseenLine(biggest[index]) end
end

local function AddSessionSpikes(lines)
	local biggest = {}
	for index, spike in ipairs(spikes) do biggest[index] = spike end
	sort(biggest, function(left, right) return left.game > right.game end)
	lines[#lines + 1] = format('Since reload (%s ago), slow frames (game over %dms, or addons or BluUI over %dms): %d. Biggest:', Clock(GetTime() - loadedAt), GAME_SPIKE_MS, SPIKE_MS, spikeCount)
	for index = 1, math.min(TOP_SPIKES, #biggest) do lines[#lines + 1] = SpikeLine(biggest[index]) end
end

local function Share(metric)
	local mine, game = GetAddOnMetric(addonName, metric), GetApplicationMetric(metric)
	return mine, game > 0 and mine / game * 100 or 0
end

local function BlizzardLine()
	local counts = {}
	for _, counter in ipairs(COUNTERS) do counts[#counts + 1] = format('%s %d', counter.label, GetAddOnMetric(addonName, counter.metric)) end
	local recent, recentShare = Share(Metric.RecentAverageTime)
	local session, sessionShare = Share(Metric.SessionAverageTime)
	local encounter, encounterShare = Share(Metric.EncounterAverageTime)
	return format("Blizzard's numbers for BluUI, the same ones addon managers show: now %.2fms a frame (%.2f%% of the game), since load %.2fms (%.2f%%), last boss %.2fms (%.2f%%), worst frame %.0fms. Frames over %s since load.",
		recent, recentShare, session, sessionShare, encounter, encounterShare, GetAddOnMetric(addonName, Metric.PeakTime), concat(counts, ', '))
end

function Profiler.Report()
	if startedAt == 0 then
		local lines = { BlizzardLine() }
		AddSessionSpikes(lines)
		AddUnseenSpikes(lines)
		lines[#lines + 1] = 'No profile run yet. Type /bui profile to start one.'
		return lines, #lines
	end
	local now = Profiler.active and GetTime() or stoppedAt
	local lines = { BlizzardLine() }
	local overCounts = {}
	for _, counter in ipairs(COUNTERS) do
		overCounts[#overCounts + 1] = format('%s %d', counter.label, GetAddOnMetric(addonName, counter.metric) - baseline[counter.label])
	end
	local calls = 0
	for _, stat in pairs(stats) do calls = calls + stat.calls end
	lines[#lines + 1] = format('BluUI profile over %.0fs. Ticks over %s', now - startedAt, concat(overCounts, ', '))
	lines[#lines + 1] = format('BluUI used %.0fms over %d frames (%.2fms a frame). Named below: %.0fms (%.0f%%). Timing itself cost about %.0fms of that.',
		actualTotal, ticks, actualTotal / max(ticks, 1), namedTotal, actualTotal > 0 and namedTotal / actualTotal * 100 or 0, calls * overheadPerCall)
	lines[#lines + 1] = SharedLibraryLine()
	if GetAddOnMetric(addonName, Metric.EncounterAverageTime) > 0 then
		lines[#lines + 1] = 'Last boss, ms a frame: ' .. AddOnComparison(Metric.EncounterAverageTime)
	end
	lines[#lines + 1] = 'Since reload, ms a frame: ' .. AddOnComparison(Metric.SessionAverageTime)
	AddSessionSpikes(lines)
	AddUnseenSpikes(lines)
	local areas, members = Areas()
	local areaParts = {}
	for _, item in ipairs(areas) do areaParts[#areaParts + 1] = format('%s %.0fms', item.label, item.value) end
	lines[#lines + 1] = 'By area: ' .. concat(areaParts, ', ')
	local biggest = {}
	for index, hitch in ipairs(hitches) do biggest[index] = hitch end
	sort(biggest, function(left, right) return left.actual > right.actual end)
	lines[#lines + 1] = format('Biggest frames over %dms (%d in total; time since start, BluUI time that frame, named in it and the frame before, top handlers):', HITCH_MS, #hitches)
	for index = 1, math.min(TOP_HITCHES, #biggest) do lines[#lines + 1] = HitchLine(biggest[index]) end
	lines[#lines + 1] = 'Most time:'
	local preview
	for index, item in ipairs(TopOf(stats, TOP_TOTAL, 'total')) do
		local stat = stats[item.label]
		lines[#lines + 1] = format('  %s: %.0fms, %d calls, %.2f avg, %.1f max', item.label, stat.total, stat.calls, stat.total / stat.calls, stat.max)
		if index == PREVIEW_TOTAL then preview = #lines end
	end
	preview = preview or #lines
	lines[#lines + 1] = 'Inside each area (time includes anything nested inside it):'
	for _, area in ipairs(areas) do
		local parts = {}
		for _, item in ipairs(TopOf(members[area.label], TOP_IN_AREA)) do parts[#parts + 1] = format('%s %.0f', item.label, item.value) end
		lines[#lines + 1] = format('  %s %.0fms: %s', area.label, area.value, concat(parts, '; '))
	end
	lines[#lines + 1] = 'Slowest single calls:'
	for _, item in ipairs(TopOf(stats, TOP_MAX, 'max')) do
		lines[#lines + 1] = format('  %s: %.1fms', item.label, item.value)
	end
	lines[#lines + 1] = 'Every frame over ' .. HITCH_MS .. 'ms, in order:'
	for _, hitch in ipairs(hitches) do lines[#lines + 1] = HitchLine(hitch) end
	return lines, preview
end

local loadingWatcher = CreateFrame('Frame')
loadingWatcher:RegisterEvent('LOADING_SCREEN_ENABLED')
loadingWatcher:RegisterEvent('LOADING_SCREEN_DISABLED')
loadingWatcher:SetScript('OnEvent', function(_, event)
	loadingScreen = event == 'LOADING_SCREEN_ENABLED'
	if not loadingScreen then loadingEndedAt = GetTime() end
end)

local loadWatcher = CreateFrame('Frame')
loadWatcher:RegisterEvent('ADDON_LOADED')
loadWatcher:SetScript('OnEvent', function(self, _, loaded)
	if loaded ~= addonName then return end
	local loading = debugprofilestop() - fileLoadStart
	noted[FILE_LOAD_LABEL] = loading
	notedTotal = notedTotal + loading
	self:UnregisterEvent('ADDON_LOADED')
	TimeUnitFrames()
	TimeActionButtons()
	local saved = _G.BluUI_DB
	local global = saved and saved.global
	if global and global.profileNextLogin then
		global.profileNextLogin = nil
		Profiler.Start()
		loginPending = true
	end
end)

local logoutWatcher = CreateFrame('Frame')
logoutWatcher:RegisterEvent('PLAYER_LOGOUT')
logoutWatcher:SetScript('OnEvent', function()
	local global = BUI.db and BUI.db.global
	if not global then return end
	global.profileLog = { saved = date('%Y-%m-%d %H:%M'), zone = GetRealZoneText(), lines = (Profiler.Report()) }
end)
