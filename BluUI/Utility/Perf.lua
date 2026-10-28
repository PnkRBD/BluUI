local _, BUI = ...

local Perf = {}
BUI.Perf = Perf

local ADDONS = { 'BluUI', 'BluUI_Options' }
local TOP_ADDONS = 5
local TOP_HANDLERS = 20
local SAMPLE_SECONDS = 1
local tracked = {}
local session

function Perf.Track(name, callback)
	tracked[#tracked + 1] = { name = name, callback = callback }
end

local function Line(label, value)
	print('  |cff' .. BUI.C.COLOR_BRAND .. label .. '|r  ' .. value)
end

local function Ms(value)
	return ('%.2f ms'):format(value or 0)
end

local function Count(value)
	return ('%d frames'):format(value or 0)
end

local function Metric(name, metric)
	return C_AddOnProfiler.GetAddOnMetric(name, metric) or 0
end

local function Duration(seconds)
	return ('%dm %02ds'):format(math.floor(seconds / 60), math.floor(seconds % 60))
end

local function LoadedAddons()
	local names = {}
	for index = 1, C_AddOns.GetNumAddOns() do
		if C_AddOns.IsAddOnLoaded(index) then names[#names + 1] = C_AddOns.GetAddOnInfo(index) end
	end
	return names
end

local function CountMetrics()
	local metrics = Enum.AddOnProfilerMetric
	return { metrics.CountTimeOver5Ms, metrics.CountTimeOver10Ms, metrics.CountTimeOver50Ms, metrics.CountTimeOver100Ms }
end

local function Snapshot(names)
	local counts, metrics = {}, CountMetrics()
	for _, name in ipairs(names) do
		local row = {}
		for index, metric in ipairs(metrics) do row[index] = Metric(name, metric) end
		counts[name] = row
	end
	return counts
end

local function Sample()
	local recent = Enum.AddOnProfilerMetric.RecentAverageTime
	for _, name in ipairs(session.names) do
		local value = Metric(name, recent)
		local sample = session.samples[name]
		sample.sum, sample.count = sample.sum + value, sample.count + 1
		if value > sample.max then sample.max = value end
	end
	local ok, overall = pcall(C_AddOnProfiler.GetOverallMetric, recent)
	if ok and overall then
		session.overall.sum, session.overall.count = session.overall.sum + overall, session.overall.count + 1
		if overall > session.overall.max then session.overall.max = overall end
	end
end

local function Start()
	local names = LoadedAddons()
	session = { startedAt = GetTime(), names = names, counts = Snapshot(names), samples = {}, overall = { sum = 0, max = 0, count = 0 } }
	for _, name in ipairs(names) do session.samples[name] = { sum = 0, max = 0, count = 0 } end
	session.ticker = C_Timer.NewTicker(SAMPLE_SECONDS, Sample)
	if ResetCPUUsage then ResetCPUUsage() end
	BUI.Print('Measuring. Type /bui perf again when the pull is over.')
end

local function Average(sample)
	return sample.count > 0 and sample.sum / sample.count or 0
end

local function TopBy(rows, key, Format, label)
	table.sort(rows, function(a, b) return a[key] > b[key] end)
	BUI.Print(label)
	local shown = 0
	for _, row in ipairs(rows) do
		if row[key] <= 0 or shown >= TOP_ADDONS then break end
		Line(row.name, Format(row[key]))
		shown = shown + 1
	end
	if shown == 0 then Line('none', '-') end
end

local function Stop()
	session.ticker:Cancel()
	Sample()
	local after = Snapshot(session.names)
	local rows = {}
	for _, name in ipairs(session.names) do
		local before, now, sample = session.counts[name], after[name], session.samples[name]
		rows[#rows + 1] = {
			name = name, average = Average(sample), worst = sample.max,
			over5 = now[1] - before[1], over10 = now[2] - before[2], over50 = now[3] - before[3], over100 = now[4] - before[4],
		}
	end
	BUI.Print(('Measured %s'):format(Duration(GetTime() - session.startedAt)))
	Line('all addons, average per frame', Ms(Average(session.overall)))
	Line('all addons, worst second', Ms(session.overall.max))
	for _, row in ipairs(rows) do
		for _, name in ipairs(ADDONS) do
			if row.name == name then
				BUI.Print(name)
				Line('average per frame', Ms(row.average))
				Line('worst second', Ms(row.worst))
				Line('frames over 5 / 10 / 50 / 100 ms', ('%d / %d / %d / %d'):format(row.over5, row.over10, row.over50, row.over100))
			end
		end
	end
	TopBy(rows, 'average', Ms, 'Heaviest addons, average per frame')
	TopBy(rows, 'worst', Ms, 'Heaviest addons, worst second')
	TopBy(rows, 'over50', Count, 'Most frames over 50 ms')
	TopBy(rows, 'over10', Count, 'Most frames over 10 ms')
	BUI.Print('Mouse scripts such as clicks and tooltips are not counted. /bui perf handlers breaks BluUI down further.')
	session = nil
end

function Perf.Toggle()
	if not C_AddOnProfiler then
		BUI.Print('This client has no addon profiler.')
		return
	end
	if session then Stop() else Start() end
end

local function ReportAddon(name)
	if not C_AddOns.IsAddOnLoaded(name) then return end
	local metrics = Enum.AddOnProfilerMetric
	BUI.Print(name)
	Line('encounter average', Ms(Metric(name, metrics.EncounterAverageTime)))
	Line('last 60 frames', Ms(Metric(name, metrics.RecentAverageTime)))
	Line('session average', Ms(Metric(name, metrics.SessionAverageTime)))
	Line('worst frame', Ms(Metric(name, metrics.PeakTime)))
	Line('frames over 5 / 10 / 50 ms', ('%d / %d / %d'):format(
		Metric(name, metrics.CountTimeOver5Ms), Metric(name, metrics.CountTimeOver10Ms), Metric(name, metrics.CountTimeOver50Ms)))
end

local function ReportTop(metric, label, Format)
	BUI.Print(label)
	for _, entry in ipairs(C_AddOnProfiler.GetTopKAddOnsForMetric(metric, TOP_ADDONS)) do
		Line(entry.addOnName, (Format or Ms)(entry.metricValue))
	end
end

function Perf.Report()
	if not C_AddOnProfiler then
		BUI.Print('This client has no addon profiler.')
		return
	end
	local metrics = Enum.AddOnProfilerMetric
	for _, name in ipairs(ADDONS) do ReportAddon(name) end
	local ok, overall = pcall(C_AddOnProfiler.GetOverallMetric, metrics.EncounterAverageTime)
	if ok and overall then Line('all addons, encounter average', Ms(overall)) end
	ReportTop(metrics.EncounterAverageTime, 'Heaviest addons this encounter')
	ReportTop(metrics.PeakTime, 'Heaviest single frame since login')
	ReportTop(metrics.CountTimeOver50Ms, 'Most frames over 50 ms since login', Count)
	ReportTop(metrics.CountTimeOver10Ms, 'Most frames over 10 ms since login', Count)
	BUI.Print('Numbers reset on reload. Mouse scripts such as clicks and tooltips are not counted.')
end

function Perf.Handlers()
	if not GetFunctionCPUUsage then
		BUI.Print('This client cannot time individual functions.')
		return
	end
	if not C_CVar.GetCVarBool('scriptProfile') then
		BUI.Print('Function timing is off. Run /console scriptProfile 1 and /reload, then /bui perf before and after a pull, then /bui perf handlers. Afterwards run /console scriptProfile 0 and /reload, since timing costs frames on its own.')
		return
	end
	UpdateAddOnCPUUsage()
	local rows, seen = {}, {}
	BUI.Events:EachHandler(function(event, key, callback, unit)
		if seen[callback] then return end
		seen[callback] = true
		local usage, calls = GetFunctionCPUUsage(callback, true)
		if calls > 0 then
			rows[#rows + 1] = { event = event, key = key, unit = unit, usage = usage, calls = calls }
		end
	end)
	table.sort(rows, function(a, b) return a.usage > b.usage end)
	BUI.Print(('Heaviest event handlers, %s total for BluUI since the last /bui perf start'):format(Ms(GetAddOnCPUUsage('BluUI'))))
	for index = 1, math.min(TOP_HANDLERS, #rows) do
		local row = rows[index]
		local where = row.unit and (row.event .. ' ' .. row.unit) or row.event
		Line(row.key .. ' on ' .. where, ('%s over %d calls, %.3f ms each'):format(Ms(row.usage), row.calls, row.usage / row.calls))
	end
	local hooks = {}
	for _, entry in ipairs(tracked) do
		local usage, calls = GetFunctionCPUUsage(entry.callback, true)
		if calls > 0 then hooks[#hooks + 1] = { name = entry.name, usage = usage, calls = calls } end
	end
	table.sort(hooks, function(a, b) return a.usage > b.usage end)
	BUI.Print('Watched hooks and layout passes')
	for _, row in ipairs(hooks) do
		Line(row.name, ('%s over %d calls, %.3f ms each'):format(Ms(row.usage), row.calls, row.usage / row.calls))
	end
	BUI.Print('Handlers are the event side only. Frame scripts and unit frame elements show in the addon total but not in this list.')
end

function Perf.Reset()
	if ResetCPUUsage then ResetCPUUsage() end
	BUI.Print('Function timers reset.')
end
