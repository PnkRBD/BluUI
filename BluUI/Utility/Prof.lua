local _, BUI = ...

local debugprofilestop = debugprofilestop
local collectgarbage = collectgarbage
local sort = table.sort
local min = math.min
local wipe = wipe

local Prof = { active = false }
BUI.Prof = Prof

local data = {}
local startedAt = 0
local fileLoadStart = debugprofilestop()
local startupCapture = false
local marks = {}
local STARTUP_SETTLE_SECONDS = 5

local frameKeys = {}
local frameKeyCount = 0
local frameInstrumented = 0
local previousKeys = {}
local previousKeyCount = 0
local previousInstrumented = 0

function Prof.Add(key, milliseconds, allocationKB)
	local entry = data[key]
	if not entry then
		entry = { total = 0, count = 0, max = 0, alloc = 0 }
		data[key] = entry
	end
	entry.total = entry.total + milliseconds
	entry.count = entry.count + 1
	if milliseconds > entry.max then entry.max = milliseconds end
	if allocationKB and allocationKB > 0 then entry.alloc = entry.alloc + allocationKB end
	frameInstrumented = frameInstrumented + milliseconds
	if milliseconds >= 0.5 then
		frameKeyCount = frameKeyCount + 1
		frameKeys[frameKeyCount] = key
		frameKeys[-frameKeyCount] = milliseconds
	end
end

local counters = {}

function Prof.Count(key)
	if not Prof.active then return end
	counters[key] = (counters[key] or 0) + 1
end

local wrapperOf = setmetatable({}, { __mode = 'k' })
local rawOf = setmetatable({}, { __mode = 'k' })

function Prof.Wrap(key, callback)
	local wrapper = function(...)
		if not Prof.active then return callback(...) end
		local startKB = collectgarbage('count')
		local startTime = debugprofilestop()
		callback(...)
		Prof.Add(key, debugprofilestop() - startTime, collectgarbage('count') - startKB)
	end
	rawOf[wrapper] = callback
	return wrapper
end

function Prof.Measure(key, callback, ...)
	if not Prof.active then return callback(...) end
	local startKB = collectgarbage('count')
	local startTime = debugprofilestop()
	local result = callback(...)
	Prof.Add(key, debugprofilestop() - startTime, collectgarbage('count') - startKB)
	return result
end

function Prof.Unwrap(callback)
	return rawOf[callback] or callback
end

function Prof.WrapScript(key, callback, perEvent)
	if callback == nil or rawOf[callback] then return callback end
	local wrapper = wrapperOf[callback]
	if wrapper then return wrapper end
	if perEvent then
		wrapper = function(self, event, ...)
			if not Prof.active then return callback(self, event, ...) end
			local startKB = collectgarbage('count')
			local startTime = debugprofilestop()
			callback(self, event, ...)
			Prof.Add(key .. '#' .. tostring(event), debugprofilestop() - startTime, collectgarbage('count') - startKB)
		end
		rawOf[wrapper] = callback
	else
		wrapper = Prof.Wrap(key, callback)
	end
	wrapperOf[callback] = wrapper
	return wrapper
end

local function AssertScriptArgs(prefix, script)
	if type(script) == 'string' then return end
	error(('BluUI %s: script helpers take (frame, script, callback), but the script name arrived as a %s. A colon call passes self as the frame.')
		:format(tostring(prefix), type(script)), 3)
end

function Prof.Scripts(prefix)
	local function SetScript(frame, script, callback)
		AssertScriptArgs(prefix, script)
		if script == 'OnEvent' then
			frame:SetScript(script, Prof.WrapScript(prefix, callback, true))
		else
			frame:SetScript(script, Prof.WrapScript(prefix .. '#' .. script, callback))
		end
	end
	local function HookScript(frame, script, callback)
		AssertScriptArgs(prefix, script)
		if script == 'OnEvent' then
			frame:HookScript(script, Prof.WrapScript(prefix, callback, true))
		else
			frame:HookScript(script, Prof.WrapScript(prefix .. '#' .. script, callback))
		end
	end
	return SetScript, HookScript
end

function Prof.SetScript(prefix, frame, script, callback)
	AssertScriptArgs(prefix, script)
	if script == 'OnEvent' then
		frame:SetScript(script, Prof.WrapScript(prefix, callback, true))
	else
		frame:SetScript(script, Prof.WrapScript(prefix .. '#' .. script, callback))
	end
end

function Prof.HookScript(prefix, frame, script, callback)
	AssertScriptArgs(prefix, script)
	if script == 'OnEvent' then
		frame:HookScript(script, Prof.WrapScript(prefix, callback, true))
	else
		frame:HookScript(script, Prof.WrapScript(prefix .. '#' .. script, callback))
	end
end

function Prof.Hook(prefix, target, method, callback)
	if callback == nil then
		hooksecurefunc(target, Prof.Wrap(prefix .. '#' .. target, method))
	else
		hooksecurefunc(target, method, Prof.Wrap(prefix .. '#' .. method, callback))
	end
end

function Prof.NewTimer(prefix, delay, callback)
	return C_Timer.NewTimer(delay, Prof.Wrap('timer#' .. prefix, callback))
end

function Prof.After(prefix, delay, callback)
	C_Timer.After(delay, Prof.Wrap('timer#' .. prefix, callback))
end

function Prof.NewTicker(prefix, interval, callback, iterations)
	return C_Timer.NewTicker(interval, Prof.Wrap('tick#' .. prefix, callback), iterations)
end

function Prof.WrapTag(key, method)
	return function(unit, realUnit)
		if not Prof.active then return method(unit, realUnit) end
		local startKB = collectgarbage('count')
		local startTime = debugprofilestop()
		local result = method(unit, realUnit)
		Prof.Add(key, debugprofilestop() - startTime, collectgarbage('count') - startKB)
		return result
	end
end

function Prof.MakeHooker(prefix)
	return function(target, method, callback)
		if callback == nil then
			hooksecurefunc(target, Prof.Wrap(prefix .. '#' .. target, method))
		else
			hooksecurefunc(target, method, Prof.Wrap(prefix .. '#' .. method, callback))
		end
	end
end

local sampleTicker
local attributedMilliseconds = 0
local allocationChurnKB = 0
local lastAllocationKB = 0

local function ExternalMetric(name)
	local metricEnum = Enum.AddOnProfilerMetric
	if not metricEnum[name] then return nil end
	return C_AddOnProfiler.GetAddOnMetric('BluUI', metricEnum[name])
end

local SPIKE_METRICS = { 'CountTimeOver1Ms', 'CountTimeOver5Ms', 'CountTimeOver10Ms', 'CountTimeOver50Ms', 'CountTimeOver100Ms', 'CountTimeOver500Ms' }
local spikeStart = {}

local function SnapshotSpikes()
	for _, name in ipairs(SPIKE_METRICS) do spikeStart[name] = ExternalMetric(name) or 0 end
end

local function SpikeLine()
	if ExternalMetric('CountTimeOver1Ms') == nil then return nil end
	local window, session = {}, {}
	for _, name in ipairs(SPIKE_METRICS) do
		local threshold = name:match('Over(%d+)Ms')
		local total = ExternalMetric(name) or 0
		window[#window + 1] = ('>%sms: %d'):format(threshold, total - (spikeStart[name] or 0))
		session[#session + 1] = ('>%sms: %d'):format(threshold, total)
	end
	return 'Frames over budget this window (Blizzard addon profiler): ' .. table.concat(window, ', ')
		.. '\nSince the game session started (survives reloads): ' .. table.concat(session, ', ')
end

local SPIKE_FRAME_MS = 50
local exactAttribution = false
local SPIKE_LOG_LIMIT = 20
local spikeLog = {}
local watchdog

local function RecordSpike(attributed)
	if #spikeLog >= SPIKE_LOG_LIMIT then return end
	local keys = {}
	for index = 1, previousKeyCount do
		keys[#keys + 1] = { key = previousKeys[index], ms = previousKeys[-index] }
	end
	sort(keys, function(left, right) return left.ms > right.ms end)
	spikeLog[#spikeLog + 1] = {
		at = debugprofilestop() - startedAt,
		attributed = attributed,
		instrumented = previousInstrumented,
		keys = keys,
	}
end

local function WatchdogTick()
	if not Prof.active then return end
	local lastTime = ExternalMetric('LastTime')
	if lastTime then
		exactAttribution = true
		attributedMilliseconds = attributedMilliseconds + lastTime
		if lastTime >= SPIKE_FRAME_MS then RecordSpike(lastTime) end
	end
	frameKeys, previousKeys = previousKeys, frameKeys
	previousKeyCount, previousInstrumented = frameKeyCount, frameInstrumented
	frameKeyCount = 0
	frameInstrumented = 0
end

local function StartWatchdog()
	if not watchdog then
		watchdog = CreateFrame('Frame')
		watchdog:SetScript('OnUpdate', WatchdogTick)
	end
	wipe(spikeLog)
	frameKeyCount = 0
	frameInstrumented = 0
	watchdog:Show()
end

local function StopWatchdog()
	if watchdog then watchdog:Hide() end
end

local function ReportSpikes()
	if #spikeLog == 0 then
		BUI.Print(('No frames with %dms or more attributed to BluUI in this window.'):format(SPIKE_FRAME_MS))
		return
	end
	BUI.Print(('Spike frames (%dms+ attributed to BluUI): %d%s'):format(SPIKE_FRAME_MS, #spikeLog, #spikeLog >= SPIKE_LOG_LIMIT and ' (log full)' or ''))
	for index = 1, #spikeLog do
		local spike = spikeLog[index]
		local parts = {}
		for keyIndex = 1, min(5, #spike.keys) do
			local entry = spike.keys[keyIndex]
			parts[#parts + 1] = ('%s %.1fms'):format(entry.key, entry.ms)
		end
		local missing = spike.attributed - spike.instrumented
		print(('  |cff6D00FD%2d|r +%.1fs  |cffffd200%.0fms|r attributed, %.0fms instrumented, ~%.0fms not instrumented  %s'):format(
			index, spike.at / 1000, spike.attributed, spike.instrumented, missing > 0 and missing or 0,
			#parts > 0 and table.concat(parts, ', ') or 'no instrumented handler ran'))
	end
end

local function SampleExternal()
	local recentAverage = ExternalMetric('RecentAverageTime')
	if recentAverage and not exactAttribution then
		attributedMilliseconds = attributedMilliseconds + recentAverage * GetFramerate()
	end
	local allocationKB = collectgarbage('count')
	local delta = allocationKB - lastAllocationKB
	if delta > 0 then allocationChurnKB = allocationChurnKB + delta end
	lastAllocationKB = allocationKB
end

function Prof.Start()
	wipe(data)
	wipe(counters)
	startedAt = debugprofilestop()
	attributedMilliseconds = 0
	allocationChurnKB = 0
	lastAllocationKB = collectgarbage('count')
	if sampleTicker then sampleTicker:Cancel() end
	SnapshotSpikes()
	sampleTicker = C_Timer.NewTicker(1, SampleExternal)
	StartWatchdog()
	Prof.active = true
end

function Prof.Mark(name)
	if not Prof.active then return end
	marks[#marks + 1] = { name = name, at = debugprofilestop() - fileLoadStart }
end

function Prof.CheckStartupCapture()
	if not (BluUI_DB and BluUI_DB.__profileNextLoad) then return end
	BluUI_DB.__profileNextLoad = nil
	Prof.Start()
	startupCapture = true
	wipe(marks)
	if BUI.loadStart then Prof.Add('startup#LibraryExecution', fileLoadStart - BUI.loadStart) end
	Prof.Add('startup#FileExecution', debugprofilestop() - fileLoadStart)
	Prof.Mark('files executed')
	BUI.Events:Once('PLAYER_LOGIN', 'Prof.StartupCapture', function()
		Prof.Mark('PLAYER_LOGIN')
	end)
	BUI.Events:Once('PLAYER_ENTERING_WORLD', 'Prof.StartupCapture', function()
		Prof.Mark('PLAYER_ENTERING_WORLD')
		C_Timer.After(STARTUP_SETTLE_SECONDS, function()
			Prof.Mark('report')
			Prof.Stop()
			Prof.Report(30)
			startupCapture = false
			Prof.Start()
			BUI.Print('Profiler kept running after startup. Play until the hitch, then /bui cpu for the next report.')
		end)
	end)
end

function Prof.Stop()
	Prof.active = false
	StopWatchdog()
	if sampleTicker then
		sampleTicker:Cancel()
		sampleTicker = nil
	end
	SampleExternal()
end

function Prof.Report(limit)
	limit = limit or 20
	local wallTime = debugprofilestop() - startedAt
	if startupCapture then
		wallTime = debugprofilestop() - fileLoadStart
		local parts = {}
		for _, mark in ipairs(marks) do
			parts[#parts + 1] = ('%s @ %.0fms'):format(mark.name, mark.at)
		end
		BUI.Print('Startup capture, times since BluUI files began executing: ' .. table.concat(parts, ', '))
	end
	local rows = {}
	local grandTotal = 0
	for key, entry in pairs(data) do
		rows[#rows + 1] = { key = key, e = entry }
		grandTotal = grandTotal + entry.total
	end
	sort(rows, function(rowA, rowB) return rowA.e.total > rowB.e.total end)
	BUI.Print(('CPU profile: %.1fs window, %.0fms total (%.2f%% of one core) in %d handlers. Top %d by total time:'):format(
		wallTime / 1000, grandTotal, wallTime > 0 and (grandTotal / wallTime * 100) or 0, #rows, min(limit, #rows)))
	for rowIndex = 1, min(limit, #rows) do
		local row = rows[rowIndex]
		print(('  |cff6D00FD%2d|r %s  |cffffd200%.1fms|r (%.2f%%)  n=%d  max=%.2fms'):format(
			rowIndex, row.key, row.e.total, wallTime > 0 and (row.e.total / wallTime * 100) or 0, row.e.count, row.e.max))
	end
	if #rows == 0 then
		BUI.Print('No samples recorded.')
	end
	if next(counters) then
		local parts = {}
		for key, count in pairs(counters) do parts[#parts + 1] = ('%s x%d'):format(key, count) end
		sort(parts)
		BUI.Print('Counted but not timed (UI-wide hooks, too hot to time): ' .. table.concat(parts, ', '))
	end

	local allocationRows = {}
	local instrumentedAllocKB = 0
	for _, row in ipairs(rows) do
		local alloc = row.e.alloc or 0
		if alloc > 0 then
			allocationRows[#allocationRows + 1] = row
			instrumentedAllocKB = instrumentedAllocKB + alloc
		end
	end
	if #allocationRows > 0 then
		sort(allocationRows, function(rowA, rowB) return rowA.e.alloc > rowB.e.alloc end)
		BUI.Print(('Top allocators (%.1f MB instrumented of %.1f MB total churn):'):format(
			instrumentedAllocKB / 1024, allocationChurnKB / 1024))
		for rowIndex = 1, min(10, #allocationRows) do
			local row = allocationRows[rowIndex]
			print(('  |cff6D00FD%2d|r %s  |cffffd200%.0f KB|r  n=%d  (%.2f KB/call)'):format(
				rowIndex, row.key, row.e.alloc, row.e.count, row.e.alloc / row.e.count))
		end
	end

	if attributedMilliseconds > 0 then
		local unaccounted = attributedMilliseconds - grandTotal
		BUI.Print(('Blizzard attributes %s%.0fms to BluUI this window (%.2f%% of one core). Instrumented: %.0fms (nested handlers count more than once). Not instrumented: ~%.0fms (%.0f%%) = lib internals, event dispatch, GC, closure overhead.'):format(
			exactAttribution and '' or '~', attributedMilliseconds, wallTime > 0 and (attributedMilliseconds / wallTime * 100) or 0, grandTotal,
			unaccounted > 0 and unaccounted or 0, attributedMilliseconds > 0 and (math.max(0, unaccounted) / attributedMilliseconds * 100) or 0))
		local sessionAverage = ExternalMetric('SessionAverageTime')
		local peak = ExternalMetric('PeakTime')
		local encounterAverage = ExternalMetric('EncounterAverageTime')
		BUI.Print(('Session avg %.3fms/frame, encounter avg %.3fms/frame, peak frame %.1fms.'):format(
			sessionAverage or 0, encounterAverage or 0, peak or 0))
		local spikes = SpikeLine()
		if spikes then BUI.Print(spikes) end
	end
	ReportSpikes()
	BUI.Print(('Lua allocation churn: %.1f MB over the window (%.0f KB/s), whole Lua state including Blizzard UI. GC cost scales with this and is invisible to handler timings.'):format(
		allocationChurnKB / 1024, wallTime > 0 and (allocationChurnKB / (wallTime / 1000)) or 0))
end

LibStub('BUILib').Profiler = Prof
