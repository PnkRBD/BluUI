local _, BUI = ...

local Perf = {}
BUI.Perf = Perf

local ADDON = 'BluUI'
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

local function Metric(metric)
	return C_AddOnProfiler.GetAddOnMetric(ADDON, metric) or 0
end

local function Duration(seconds)
	return ('%dm %02ds'):format(math.floor(seconds / 60), math.floor(seconds % 60))
end

local function ScriptProfiling()
	return GetAddOnCPUUsage ~= nil and C_CVar.GetCVarBool('scriptProfile')
end

local function CountMetrics()
	local metrics = Enum.AddOnProfilerMetric
	return { metrics.CountTimeOver5Ms, metrics.CountTimeOver10Ms, metrics.CountTimeOver50Ms, metrics.CountTimeOver100Ms }
end

local function Snapshot()
	local counts = {}
	for index, metric in ipairs(CountMetrics()) do counts[index] = Metric(metric) end
	return counts
end

local function Sample()
	local value = Metric(Enum.AddOnProfilerMetric.RecentAverageTime)
	session.sum, session.count = session.sum + value, session.count + 1
	if value > session.max then session.max = value end
end

local function Start()
	session = { startedAt = GetTime(), counts = Snapshot(), sum = 0, max = 0, count = 0 }
	session.ticker = C_Timer.NewTicker(SAMPLE_SECONDS, Sample)
	if ResetCPUUsage then ResetCPUUsage() end
	if ScriptProfiling() then
		BUI.Print('Measuring with the script profiler on. Type /bui perf again when the pull is over.')
	else
		BUI.Print('Measuring event and timer work only. For hooks run from Blizzard code, such as the cooldown manager skin, set /console scriptProfile 1 and reload first. Type /bui perf again when the pull is over.')
	end
end

local function PrintTimed(rows, label)
	table.sort(rows, function(a, b) return a.usage > b.usage end)
	BUI.Print(label)
	for index = 1, math.min(TOP_HANDLERS, #rows) do
		local row = rows[index]
		Line(row.name, ('%s over %d calls, %.3f ms each'):format(Ms(row.usage), row.calls, row.usage / row.calls))
	end
	if #rows == 0 then Line('none', '-') end
end

local function Breakdown()
	UpdateAddOnCPUUsage()
	Line('total Lua time, every entry point', Ms(GetAddOnCPUUsage(ADDON)))
	local rows, seen = {}, {}
	BUI.Events:EachHandler(function(event, key, callback, unit)
		if seen[callback] then return end
		seen[callback] = true
		local usage, calls = GetFunctionCPUUsage(callback, true)
		if calls > 0 then
			rows[#rows + 1] = { name = key .. ' on ' .. (unit and (event .. ' ' .. unit) or event), usage = usage, calls = calls }
		end
	end)
	PrintTimed(rows, 'Heaviest event handlers')
	local hooks = {}
	for _, entry in ipairs(tracked) do
		local usage, calls = GetFunctionCPUUsage(entry.callback, true)
		if calls > 0 then hooks[#hooks + 1] = { name = entry.name, usage = usage, calls = calls } end
	end
	PrintTimed(hooks, 'Watched hooks and layout passes')
end

local function NameOf(frame)
	return frame:GetName()
end

local function ClientLoad()
	local total, named = 0, 0
	local frame = EnumerateFrames()
	while frame do
		total = total + 1
		local ok, name = pcall(NameOf, frame)
		if ok and type(name) == 'string' and name:find('^BUI') then named = named + 1 end
		frame = EnumerateFrames(frame)
	end
	Line('frames in the whole UI', ('%d, of which %d named BUI'):format(total, named))
	if BUI.AuraEngine and BUI.AuraEngine.CountAuraGroups then
		local containers, shown, groups, slots = BUI.AuraEngine.CountAuraGroups()
		Line('native aura containers', ('%d shown of %d, %d aura groups active, %d icon slots'):format(shown, containers, groups, slots))
	end
end

local function Stop()
	session.ticker:Cancel()
	Sample()
	local before, now = session.counts, Snapshot()
	BUI.Print(('BluUI over %s'):format(Duration(GetTime() - session.startedAt)))
	Line('average per frame', Ms(session.count > 0 and session.sum / session.count or 0))
	Line('worst second', Ms(session.max))
	Line('frames over 5 / 10 / 50 / 100 ms', ('%d / %d / %d / %d'):format(now[1] - before[1], now[2] - before[2], now[3] - before[3], now[4] - before[4]))
	ClientLoad()
	if ScriptProfiling() then
		Breakdown()
	else
		Line('note', 'event and timer work only; hooks run from Blizzard code need /console scriptProfile 1 and a reload')
	end
	session = nil
end

function Perf.Toggle()
	if not C_AddOnProfiler then
		BUI.Print('This client has no addon profiler.')
		return
	end
	if session then Stop() else Start() end
end

function Perf.Report()
	if not C_AddOnProfiler then
		BUI.Print('This client has no addon profiler.')
		return
	end
	local metrics = Enum.AddOnProfilerMetric
	BUI.Print('BluUI since login')
	Line('encounter average', Ms(Metric(metrics.EncounterAverageTime)))
	Line('last 60 frames', Ms(Metric(metrics.RecentAverageTime)))
	Line('session average', Ms(Metric(metrics.SessionAverageTime)))
	Line('worst frame', Ms(Metric(metrics.PeakTime)))
	Line('frames over 5 / 10 / 50 / 100 ms', ('%d / %d / %d / %d'):format(
		Metric(metrics.CountTimeOver5Ms), Metric(metrics.CountTimeOver10Ms), Metric(metrics.CountTimeOver50Ms), Metric(metrics.CountTimeOver100Ms)))
	ClientLoad()
	if ScriptProfiling() then Breakdown() end
end

function Perf.Handlers()
	if not GetFunctionCPUUsage then
		BUI.Print('This client cannot time individual functions.')
		return
	end
	if not ScriptProfiling() then
		BUI.Print('Function timing is off. Run /console scriptProfile 1 and /reload, then /bui perf before and after a pull. Afterwards run /console scriptProfile 0 and /reload, since timing costs frames on its own.')
		return
	end
	Breakdown()
end

function Perf.Reset()
	if ResetCPUUsage then ResetCPUUsage() end
	BUI.Print('Function timers reset.')
end
