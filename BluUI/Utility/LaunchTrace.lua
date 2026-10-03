local _, BUI = ...

local debugprofilestop, format, concat, sort, wipe = debugprofilestop, string.format, table.concat, table.sort, wipe
local pairs, ipairs, type, getmetatable, rawget = pairs, ipairs, type, getmetatable, rawget

local LaunchTrace = {}
BUI.LaunchTrace = LaunchTrace

local Profiler = BUI.Profiler

local TRACE_SECONDS = 20
local TIMELINE_REPEATS = 3
local MAX_TIMELINE = 2500
local BUSY_CALLS = 20
local WRAP_DEPTH = 2
local VERBS = {
	Initialize = true, Init = true, Enable = true, Activate = true, Setup = true, Refresh = true, Rebuild = true,
	Apply = true, Reapply = true, Style = true, Restyle = true, Position = true, Layout = true, Relayout = true,
	Install = true, Build = true, Create = true, Spawn = true, Sweep = true, Skin = true, Toggle = true,
	Precreate = true, Restore = true, Sync = true, Register = true, Hook = true, Place = true, Ensure = true,
	Make = true, Anchor = true, Migrate = true, Rebind = true, Start = true, Mark = true, Invalidate = true, Track = true,
}
local SKIP = {
	Profiler = true, LaunchTrace = true, Events = true, Pixel = true, BUILibClient = true, oUF = true,
	Dispatcher = true, Scheduler = true, C = true, Defaults = true, db = true,
}
local PHASES = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, LOADING_SCREEN_DISABLED = true }
local MARKED_EVENTS = { 'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD', 'LOADING_SCREEN_DISABLED', 'SPELLS_CHANGED', 'EDIT_MODE_LAYOUTS_UPDATED', 'PLAYER_SPECIALIZATION_CHANGED' }
local MARK_COLOR = '|cff9f8cff'
local DIM_COLOR = '|cff888888'
local WARN_COLOR = '|cffffaa33'

local tracing = false
local origin = 0
local phase = 'ADDON_LOADED'
local timeline, stats, wrapped, marked = {}, {}, {}, {}
local report

local function Since(start)
	return (start - origin) / 1000
end

local function Mark(event)
	if marked[event] then return end
	marked[event] = true
	if PHASES[event] then phase = event end
	timeline[#timeline + 1] = { start = debugprofilestop(), marker = event }
end

local function Trace(label, start, elapsed, depth, parent)
	if label == '' then return end
	local stat = stats[label]
	if not stat then
		stat = { count = 0, total = 0, from = {} }
		stats[label] = stat
	end
	stat.count = stat.count + 1
	stat.total = stat.total + elapsed
	local from = parent or phase
	stat.from[from] = (stat.from[from] or 0) + 1
	if stat.count <= TIMELINE_REPEATS and #timeline < MAX_TIMELINE then
		timeline[#timeline + 1] = { start = start, label = label, elapsed = elapsed, depth = depth, nth = stat.count }
	end
end

local function PlainTable(value)
	return type(value) == 'table' and getmetatable(value) == nil and rawget(value, 0) == nil
end

local function WrapTable(owner, path, level, visited)
	visited[owner] = true
	for key, value in pairs(owner) do
		if type(key) == 'string' then
			local name = path == '' and key or (path .. '.' .. key)
			if type(value) == 'function' then
				local verb = key:match('^%u%l+')
				if verb and VERBS[verb] then
					local wrapper = Profiler.Wrap(name, value)
					wrapped[#wrapped + 1] = { owner = owner, key = key, original = value, wrapper = wrapper, name = name }
					owner[key] = wrapper
				end
			elseif level < WRAP_DEPTH and not SKIP[key] and PlainTable(value) and not visited[value] then
				WrapTable(value, name, level + 1, visited)
			end
		end
	end
end

local function Unwrap()
	for _, record in ipairs(wrapped) do
		if record.owner[record.key] == record.wrapper then record.owner[record.key] = record.original end
	end
end

local function FromList(stat)
	local parts = {}
	for from, count in pairs(stat.from) do parts[#parts + 1] = { from = from, count = count } end
	sort(parts, function(left, right) return left.count > right.count end)
	local text = {}
	for _, part in ipairs(parts) do text[#text + 1] = part.count > 1 and format('%s x%d', part.from, part.count) or part.from end
	return concat(text, ', '), #parts
end

local function TimelineLines()
	sort(timeline, function(left, right) return left.start < right.start end)
	local lines = {}
	for _, entry in ipairs(timeline) do
		if entry.marker then
			lines[#lines + 1] = format('%s-- %s at +%.2fs --|r', MARK_COLOR, entry.marker, Since(entry.start))
		else
			local indent = string.rep('    ', math.max(0, entry.depth - 1))
			local rerun = entry.nth > 1 and format('  %srun %d|r', WARN_COLOR, entry.nth) or ''
			lines[#lines + 1] = format('+%.3fs  %s%s  %s%.2fms|r%s', Since(entry.start), indent, entry.label, DIM_COLOR, entry.elapsed, rerun)
		end
	end
	return lines
end

local function RepeatLines()
	local doubled, again, busy = {}, {}, {}
	for label, stat in pairs(stats) do
		if stat.count > 1 then
			local from, places = FromList(stat)
			local item = { label = label, stat = stat, from = from }
			if stat.count > BUSY_CALLS then
				busy[#busy + 1] = item
			elseif places > 1 then
				doubled[#doubled + 1] = item
			else
				again[#again + 1] = item
			end
		end
	end
	local function ByCount(left, right) return left.stat.count > right.stat.count end
	sort(doubled, ByCount)
	sort(again, ByCount)
	sort(busy, ByCount)
	local lines = {}
	local function Section(title, items, color)
		if #items == 0 then return end
		lines[#lines + 1] = format('%s-- %s (%d) --|r', MARK_COLOR, title, #items)
		for _, item in ipairs(items) do
			lines[#lines + 1] = format('%s%s x%d|r  %s%.1fms|r  from %s', color or '', item.label, item.stat.count, DIM_COLOR, item.stat.total, item.from)
		end
		lines[#lines + 1] = ''
	end
	Section('Same thing from different places', doubled, WARN_COLOR)
	Section('Ran more than once from the same place', again)
	Section('Runs all the time (per frame or per event)', busy)
	if #lines == 0 then lines[1] = 'Nothing ran more than once.' end
	return lines, #doubled
end

local function NeverLines()
	local names = {}
	for _, record in ipairs(wrapped) do
		if not stats[record.name] then names[#names + 1] = record.name end
	end
	sort(names)
	local lines = { DIM_COLOR .. 'Not called in the first ' .. TRACE_SECONDS .. 's. Some only run on a profile change, a setting change or when a window opens.|r', '' }
	for _, name in ipairs(names) do lines[#lines + 1] = name end
	return lines, #names
end

local function Finish()
	if not tracing then return end
	tracing = false
	Profiler.SetTracer(nil)
	Unwrap()
	local repeats, doubled = RepeatLines()
	local never, unused = NeverLines()
	local ran = 0
	for _ in pairs(stats) do ran = ran + 1 end
	report = {
		saved = date('%Y-%m-%d %H:%M'),
		summary = format('First %ds after reload: %d handlers and functions ran, %d came from more than one place, %d of %d wrapped functions never ran.', TRACE_SECONDS, ran, doubled, unused, #wrapped),
		timeline = TimelineLines(),
		repeats = repeats,
		never = never,
	}
	BUI.db.global.launchTrace = report
	wipe(timeline)
	wipe(stats)
	wipe(wrapped)
	if InCombatLockdown() then
		BUI.Print('Launch trace ready. Type /bui trace show to see it.')
	else
		LaunchTrace.Show()
	end
end

local watcher = CreateFrame('Frame')
for _, event in ipairs(MARKED_EVENTS) do watcher:RegisterEvent(event) end
watcher:SetScript('OnEvent', function(self, event)
	self:UnregisterEvent(event)
	if not tracing then return end
	Mark(event)
	if event == 'PLAYER_ENTERING_WORLD' then C_Timer.After(TRACE_SECONDS, Finish) end
end)

function LaunchTrace.Begin(addon)
	local saved = _G.BluUI_DB
	local global = saved and saved.global
	if not (global and global.traceNextLogin) then return end
	global.traceNextLogin = nil
	tracing = true
	origin = debugprofilestop()
	Mark('ADDON_LOADED')
	WrapTable(BUI, '', 0, {})
	local onEnable = addon.OnEnable
	addon.OnEnable = Profiler.Wrap('OnEnable', function(...)
		Mark('PLAYER_LOGIN')
		return onEnable(...)
	end)
	Profiler.SetTracer(Trace)
end

function LaunchTrace.Start()
	BUI.db.global.traceNextLogin = true
	ReloadUI()
end

function LaunchTrace.Report()
	return report or BUI.db.global.launchTrace
end

function LaunchTrace.Show()
	if not LaunchTrace.Report() then
		BUI.Print('No launch trace yet. Type /bui trace to reload and record one.')
		return
	end
	if not BUI.PageEngine.EnsureLoaded() then return end
	BUI.ShowLaunchTrace(LaunchTrace.Report())
end
