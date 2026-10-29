local _, BUI = ...

local Perf = {}
BUI.Perf = Perf

local ADDON = 'BluUI'
local TOP_HANDLERS = 20
local TOP_FRAMES = 12
local TOP_ROOTS = 8
local SAMPLE_SECONDS = 1
local SCRIPTS = { 'OnEvent', 'OnUpdate', 'OnShow', 'OnHide', 'OnSizeChanged', 'OnAttributeChanged', 'OnValueChanged', 'OnEnter', 'OnLeave', 'OnClick' }
local tracked = {}
local trackedCallbacks = {}
local session

function Perf.Track(name, callback)
	if trackedCallbacks[callback] then return end
	trackedCallbacks[callback] = true
	tracked[#tracked + 1] = { name = name, callback = callback }
end

function Perf.Hook(name, target, method, handler)
	if handler then
		hooksecurefunc(target, method, handler)
		Perf.Track(name, handler)
	else
		hooksecurefunc(target, method)
		Perf.Track(name, method)
	end
end
BUI.Hook = Perf.Hook

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

local function PrintTimed(rows, label, limit)
	table.sort(rows, function(a, b) return a.usage > b.usage end)
	BUI.Print(label)
	for index = 1, math.min(limit or TOP_HANDLERS, #rows) do
		local row = rows[index]
		Line(row.name, ('%s over %d calls, %.3f ms each'):format(Ms(row.usage), row.calls, row.usage / row.calls))
	end
	if #rows == 0 then Line('none', '-') end
end

local function FrameRows(scripts)
	local rows, total = {}, 0
	for callback, name in pairs(scripts) do
		local usage, calls = GetFunctionCPUUsage(callback, true)
		if calls > 0 then
			rows[#rows + 1] = { name = name, usage = usage, calls = calls }
			total = total + usage
		end
	end
	return rows, total
end

local function HandlerRows()
	local rows = {}
	BUI.Events:EachHandler(function(event, key, callback, unit)
		local usage, calls = GetFunctionCPUUsage(callback, true)
		if calls > 0 then
			rows[#rows + 1] = { name = key .. ' on ' .. (unit and (event .. ' ' .. unit) or event), usage = usage, calls = calls }
		end
	end)
	return rows
end

local function HookRows()
	local rows, byName, total = {}, {}, 0
	for _, entry in ipairs(tracked) do
		local usage, calls = GetFunctionCPUUsage(entry.callback, true)
		if calls > 0 then
			local row = byName[entry.name]
			if not row then
				row = { name = entry.name, usage = 0, calls = 0 }
				byName[entry.name] = row
				rows[#rows + 1] = row
			end
			row.usage, row.calls = row.usage + usage, row.calls + calls
			total = total + usage
		end
	end
	return rows, total
end

local function Breakdown(scripts)
	UpdateAddOnCPUUsage()
	local total = GetAddOnCPUUsage(ADDON)
	Line('total Lua time, every entry point', Ms(total))
	local frameRows, frameTotal = FrameRows(scripts)
	PrintTimed(frameRows, 'Heaviest frame scripts, one row per script function on frames BluUI owns', TOP_FRAMES)
	PrintTimed(HandlerRows(), 'Heaviest event handlers')
	local hookRows, hookTotal = HookRows()
	PrintTimed(hookRows, 'Watched hooks, ticks and layout passes')
	Line('coverage', ('%s in frame scripts (Blizzard template code on BluUI frames included) and %s in watched hooks against %s of BluUI Lua; anything left is timers or library code'):format(Ms(frameTotal), Ms(hookTotal), Ms(total)))
end

local function RootName(root)
	local name = root._buiPerfName or root:GetName()
	if type(name) ~= 'string' then name = root._bluHolder and 'group header' or '(unnamed)' end
	return name
end

local function Inspect(frame)
	local root = frame
	local parent = root:GetParent()
	while parent and parent ~= UIParent do
		root = parent
		parent = root:GetParent()
	end
	return RootName(root), frame:GetNumRegions(), root ~= frame and root or nil
end

local function CollectScripts(frame, rootName, scripts)
	for _, script in ipairs(SCRIPTS) do
		if frame:HasScript(script) then
			local callback = frame:GetScript(script)
			if callback and not scripts[callback] then scripts[callback] = rootName .. ' ' .. script end
		end
	end
end

local function ClientLoad()
	local timing = ScriptProfiling()
	local total, ownedFrames, ownedRegions = 0, 0, 0
	local roots, scripts = {}, {}
	local frame = EnumerateFrames()
	while frame do
		total = total + 1
		local ok, rootName, regions, root = pcall(Inspect, frame)
		if ok and (rootName:find('^BUI') or rootName == 'group header' or (root or frame)._buiAuraContainer) then
			ownedFrames, ownedRegions = ownedFrames + 1, ownedRegions + regions
			local entry = roots[rootName] or { name = rootName, frames = 0, regions = 0 }
			roots[rootName] = entry
			entry.frames, entry.regions = entry.frames + 1, entry.regions + regions
			if timing then pcall(CollectScripts, frame, rootName, scripts) end
		end
		frame = EnumerateFrames(frame)
	end
	Line('frames in the whole UI', ('%d, BluUI owns %d frames and %d textures or texts'):format(total, ownedFrames, ownedRegions))
	local list = {}
	for _, entry in pairs(roots) do list[#list + 1] = entry end
	table.sort(list, function(a, b) return a.frames + a.regions > b.frames + b.regions end)
	for index = 1, math.min(TOP_ROOTS, #list) do
		Line(list[index].name, ('%d frames, %d textures or texts'):format(list[index].frames, list[index].regions))
	end
	if BUI.AuraEngine and BUI.AuraEngine.CountAuraGroups then
		local containers, shown, groups, slots = BUI.AuraEngine.CountAuraGroups()
		Line('native aura containers', ('%d shown of %d, %d aura groups active, %d icon slots'):format(shown, containers, groups, slots))
	end
	return scripts
end

local function Stop()
	session.ticker:Cancel()
	Sample()
	local before, now = session.counts, Snapshot()
	BUI.Print(('BluUI over %s'):format(Duration(GetTime() - session.startedAt)))
	Line('average per frame', Ms(session.count > 0 and session.sum / session.count or 0))
	Line('worst second', Ms(session.max))
	Line('frames over 5 / 10 / 50 / 100 ms', ('%d / %d / %d / %d'):format(now[1] - before[1], now[2] - before[2], now[3] - before[3], now[4] - before[4]))
	local scripts = ClientLoad()
	if ScriptProfiling() then
		Breakdown(scripts)
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
	local scripts = ClientLoad()
	if ScriptProfiling() then Breakdown(scripts) end
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
	Breakdown(ClientLoad())
end

function Perf.Reset()
	if ResetCPUUsage then ResetCPUUsage() end
	BUI.Print('Function timers reset.')
end
