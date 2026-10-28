local _, BUI = ...

local Perf = {}
BUI.Perf = Perf

local ADDONS = { 'BluUI', 'BluUI_Options' }
local TOP_ADDONS = 5
local TOP_HANDLERS = 20
local tracked = {}

function Perf.Track(name, callback)
	tracked[#tracked + 1] = { name = name, callback = callback }
end

local function Line(label, value)
	print('  |cff' .. BUI.C.COLOR_BRAND .. label .. '|r  ' .. value)
end

local function Ms(value)
	return ('%.2f ms'):format(value or 0)
end

local function Metric(name, metric)
	return C_AddOnProfiler.GetAddOnMetric(name, metric) or 0
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

local function Count(value)
	return ("%d frames"):format(value or 0)
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
		BUI.Print('Function timing is off. Run /console scriptProfile 1 and /reload, play a pull, then /bui perf handlers. Afterwards run /console scriptProfile 0 and /reload, since timing costs frames on its own.')
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
	BUI.Print(('Heaviest event handlers, %s total for BluUI since the last reset'):format(Ms(GetAddOnCPUUsage('BluUI'))))
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
