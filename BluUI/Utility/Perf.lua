local _, BUI = ...

local Perf = {}
BUI.Perf = Perf

local ADDON = 'BluUI'
local TOP_HANDLERS = 20
local TOP_FRAMES = 12
local TOP_ROOTS = 8
local TOP_FUNCTIONS = 15
local TOP_CALLERS = 3
local NAMESPACE_DEPTH = 3
local NAMESPACE_SKIP = { db = true, Perf = true, C = true, oUF = true, Events = true, Dispatcher = true, Scheduler = true }
local SECRET_CHECK = 'Tools.IsSecretValue'
local SITE_FIRST, SITE_MID, SITE_EVERY, SITE_RARE = 100, 2000, 16, 256
local SAMPLE_SECONDS = 1
local CALIBRATION_CALLS = 20000
local SCRIPTS = { 'OnEvent', 'OnUpdate', 'OnShow', 'OnHide', 'OnSizeChanged', 'OnAttributeChanged', 'OnValueChanged', 'OnEnter', 'OnLeave', 'OnClick' }
local scriptFrames = {}
local tracked = {}
local trackedCallbacks = {}
local byWrapper = {}
local session
local current
local resetFrame

function Perf.Track(name, callback)
	if not callback or trackedCallbacks[callback] then return end
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
	if not GetFunctionCPUUsage or not C_CVar.GetCVarBool('scriptProfile') then return false end
	local probe = function() end
	probe()
	local _, calls = GetFunctionCPUUsage(probe, false)
	return calls > 0
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

local function CallSites(stack)
	local parts = {}
	for line in stack:gmatch('[^\n]+') do
		if line ~= '...' then
			local site
			if line:find('^%[C%]') then
				site = '[C]'
			else
				line = line:gsub('^%[string "', ''):gsub('^%[', ''):gsub('"?%]:', ':'):gsub('Interface/AddOns/BluUI/', '')
				site = line:match('^(.-:%d+):') or line
			end
			local named = line:match("in function '([^']+)'")
			parts[#parts + 1] = named and (site .. ' in ' .. named) or site
		end
	end
	if #parts == 0 then return '?' end
	return table.concat(parts, ' <- ')
end

local function Finish(previous, ...)
	current = previous
	return ...
end

local function Tally(entry, level)
	local callers = entry.callers
	entry.count = entry.count + 1
	if current then
		callers[current] = (callers[current] or 0) + 1
		return
	end
	local external = entry.external + 1
	entry.external = external
	local weight = 0
	if external <= SITE_FIRST then
		weight = 1
	elseif external <= SITE_MID then
		weight = external % SITE_EVERY == 0 and SITE_EVERY or 0
	else
		weight = external % SITE_RARE == 0 and SITE_RARE or 0
	end
	if weight > 0 then
		local stack = debugstack(level, 2, 0)
		local site = issecretvalue(stack) and 'outside BluUI, stack hidden by the client' or CallSites(stack)
		callers[site] = (callers[site] or 0) + weight
	end
end

local function Wrap(entry)
	local name, original = entry.name, entry.original
	return function(...)
		if not entry.active then return original(...) end
		local previous = current
		Tally(entry, 3)
		current = name
		return Finish(previous, original(...))
	end
end

local function Collect(tbl, prefix, depth, seen, entries, queue)
	for key, value in pairs(tbl) do
		if type(key) == 'string' then
			local kind = type(value)
			if kind == 'function' and pcall(setfenv, value, getfenv(value)) then
				local wrapped = byWrapper[value]
				local original = wrapped and wrapped.original or value
				if not seen[original] then
					seen[original] = true
					entries[#entries + 1] = { owner = tbl, key = key, name = prefix .. key, original = original, count = 0, external = 0, callers = {} }
				end
			elseif kind == 'table' and depth < NAMESPACE_DEPTH and not seen[value] and type(rawget(value, 0)) ~= 'userdata' and not (depth == 0 and NAMESPACE_SKIP[key]) then
				seen[value] = true
				queue[#queue + 1] = { value, prefix .. key .. '.', depth + 1 }
			end
		end
	end
end

local function CollectAll()
	local entries, seen, queue = {}, { [BUI] = true }, { { BUI, '', 0 } }
	local index = 1
	while queue[index] do
		local item = queue[index]
		Collect(item[1], item[2], item[3], seen, entries, queue)
		index = index + 1
	end
	return entries
end

local function WrapAll()
	local entries = CollectAll()
	for _, entry in ipairs(entries) do
		entry.active = true
		if entry.name == SECRET_CHECK then
			BUI.Tools.TallySecretChecks(function() Tally(entry, 4) end)
		else
			entry.wrapper = Wrap(entry)
			byWrapper[entry.wrapper] = entry
			entry.owner[entry.key] = entry.wrapper
		end
	end
	if not resetFrame then
		resetFrame = CreateFrame('Frame')
		resetFrame._buiPerfName = 'BUI_PerfReset'
		resetFrame:SetScript('OnUpdate', function() current = nil end)
	end
	resetFrame:Show()
	return entries
end

local function UnwrapAll(entries)
	resetFrame:Hide()
	current = nil
	BUI.Tools.TallySecretChecks(nil)
	for _, entry in ipairs(entries) do
		entry.active = false
		if entry.wrapper then
			if entry.owner[entry.key] == entry.wrapper then entry.owner[entry.key] = entry.original end
			byWrapper[entry.wrapper] = nil
		end
	end
end

local function Start()
	session = { startedAt = GetTime(), counts = Snapshot(), sum = 0, max = 0, count = 0 }
	session.ticker = C_Timer.NewTicker(SAMPLE_SECONDS, Sample)
	if ResetCPUUsage then ResetCPUUsage() end
	session.entries = WrapAll()
	if ScriptProfiling() then
		BUI.Print('Measuring with the script profiler on, counting every BluUI function and who calls it. Type /bui perf again when the pull is over.')
	elseif C_CVar.GetCVarBool('scriptProfile') then
		BUI.Print('scriptProfile is set but does not run until you reload. Counting every BluUI function and who calls it, without timings. Type /bui perf again when the pull is over.')
	else
		BUI.Print('Counting every BluUI function and who calls it. For timings too, set /console scriptProfile 1 and reload first. Type /bui perf again when the pull is over.')
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

local function PrintCallers(callers, tallied)
	local list = {}
	for name, count in pairs(callers) do list[#list + 1] = { name = name, calls = count } end
	if #list == 0 then
		if tallied then Line('      from', 'stored references only, callers not visible') end
		return
	end
	table.sort(list, function(a, b) return a.calls > b.calls end)
	for index = 1, math.min(TOP_CALLERS, #list) do
		Line('      from ' .. list[index].name, ('%d'):format(list[index].calls))
	end
end

local function PrintCalled(rows, label, limit)
	table.sort(rows, function(a, b) return a.calls > b.calls end)
	BUI.Print(label)
	for index = 1, math.min(limit, #rows) do
		local row = rows[index]
		if row.timed then
			Line(row.name, ('%d calls, %s own, %s with callees'):format(row.calls, Ms(row.usage), Ms(row.total)))
		else
			Line(row.name, ('%d calls'):format(row.calls))
		end
		PrintCallers(row.callers, row.tallied)
	end
	if #rows == 0 then Line('none', '-') end
end

local function GlobalNames()
	local names = {}
	for name, value in pairs(_G) do
		if type(name) == 'string' then
			if type(value) == 'function' then
				names[value] = name
			elseif type(value) == 'table' and name:find('Mixin$') then
				for key, method in pairs(value) do
					if type(method) == 'function' and type(key) == 'string' and not names[method] then names[method] = name .. '.' .. key end
				end
			end
		end
	end
	return names
end

local function FrameRows(scripts)
	local rows, total = {}, 0
	local globals = GlobalNames()
	for callback, name in pairs(scripts) do
		local usage, calls = GetFunctionCPUUsage(callback, true)
		if calls > 0 then
			local globalName = globals[callback]
			if globalName then name = 'Blizzard ' .. globalName .. ', first seen on ' .. name end
			local shared = scriptFrames[callback]
			if shared and shared > 1 then name = ('%s on %d frames'):format(name, shared) end
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

local function NamespaceRows(entries)
	local timing = ScriptProfiling()
	local rows = {}
	for _, entry in ipairs(entries) do
		local usage, total, calls = 0, 0, entry.count
		if timing then
			usage, calls = GetFunctionCPUUsage(entry.original, false)
			total = GetFunctionCPUUsage(entry.original, true)
		end
		if calls > 0 then
			rows[#rows + 1] = { name = entry.name, usage = usage, total = total, calls = calls, callers = entry.callers, timed = timing, tallied = entry.active ~= nil }
		end
	end
	return rows
end

local function CallCount(rows)
	local calls = 0
	for _, row in ipairs(rows) do calls = calls + row.calls end
	return calls
end

local function ProfilerOverhead(calls)
	local probe = function() end
	local started = debugprofilestop()
	for _ = 1, CALIBRATION_CALLS do probe() end
	return (debugprofilestop() - started) / CALIBRATION_CALLS * calls
end

local function Breakdown(scripts, entries)
	UpdateAddOnCPUUsage()
	local total = GetAddOnCPUUsage(ADDON)
	Line('total Lua time, every entry point', Ms(total))
	local frameRows, frameTotal = FrameRows(scripts)
	PrintTimed(frameRows, 'Heaviest frame scripts, one row per script function on frames BluUI owns', TOP_FRAMES)
	local handlerRows = HandlerRows()
	PrintTimed(handlerRows, 'Heaviest event handlers')
	local hookRows, hookTotal = HookRows()
	PrintTimed(hookRows, 'Watched hooks, ticks and layout passes')
	local functionRows = NamespaceRows(entries or CollectAll())
	PrintCalled(functionRows, 'Most called BluUI functions and who called them', TOP_FUNCTIONS)
	PrintTimed(functionRows, 'Heaviest BluUI functions by own time, callees excluded', TOP_FUNCTIONS)
	local calls = CallCount(frameRows) + CallCount(handlerRows) + CallCount(hookRows)
	Line('coverage', ('%s in frame scripts (Blizzard template code on BluUI frames included) and %s in watched hooks against %s of BluUI Lua; the profiler itself costs about %s to count those %d calls, and anything left is timers or library code'):format(Ms(frameTotal), Ms(hookTotal), Ms(total), Ms(ProfilerOverhead(calls)), calls))
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
	local own = frame._buiPerfName or frame:GetName()
	local label = type(own) == 'string' and own ~= rootName and (own .. ' under ' .. rootName) or rootName
	for _, script in ipairs(SCRIPTS) do
		if frame:HasScript(script) then
			local callback = frame:GetScript(script)
			if callback then
				if not scripts[callback] then scripts[callback] = label .. ' ' .. script end
				scriptFrames[callback] = (scriptFrames[callback] or 0) + 1
			end
		end
	end
	if not frame.__unit then return end
	for key, value in pairs(frame) do
		if type(key) == 'string' and key:find('^[A-Z][A-Z_0-9]+$') then
			if type(value) == 'function' then
				if not scripts[value] then scripts[value] = key .. ' handler, first seen on ' .. rootName end
			elseif type(value) == 'table' then
				for _, callback in ipairs(value) do
					if type(callback) == 'function' and not scripts[callback] then scripts[callback] = key .. ' handler, first seen on ' .. rootName end
				end
			end
		end
	end
end

local function ClientLoad()
	local timing = ScriptProfiling()
	local total, ownedFrames, ownedRegions = 0, 0, 0
	local roots, scripts = {}, {}
	wipe(scriptFrames)
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
	UnwrapAll(session.entries)
	local before, now = session.counts, Snapshot()
	BUI.Print(('BluUI over %s'):format(Duration(GetTime() - session.startedAt)))
	Line('average per frame', Ms(session.count > 0 and session.sum / session.count or 0))
	Line('worst second', Ms(session.max))
	Line('frames over 5 / 10 / 50 / 100 ms', ('%d / %d / %d / %d'):format(now[1] - before[1], now[2] - before[2], now[3] - before[3], now[4] - before[4]))
	local scripts = ClientLoad()
	if ScriptProfiling() then
		Breakdown(scripts, session.entries)
	else
		PrintCalled(NamespaceRows(session.entries), 'Most called BluUI functions and who called them', TOP_FUNCTIONS)
		Line('note', 'counts only; for timings, hooks run from Blizzard code and frame scripts, set /console scriptProfile 1 and reload')
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
	if ScriptProfiling() then Breakdown(scripts, session and session.entries) end
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
	Breakdown(ClientLoad(), session and session.entries)
end

function Perf.Reset()
	if ResetCPUUsage then ResetCPUUsage() end
	BUI.Print('Function timers reset.')
end
