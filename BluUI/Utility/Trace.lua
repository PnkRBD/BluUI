local _, BUI = ...

local Trace = {}
BUI.Trace = Trace

local debugprofilestop = debugprofilestop
local pairs, type, rawget, tonumber = pairs, type, rawget, tonumber
local sort = table.sort

local SKIP_KEYS = {
	Trace = true, Prof = true, db = true, Defaults = true, C = true,
	oUF = true, BUILibClient = true, Libs = true, DefaultProfile = true,
}
local MAX_DEPTH = 4
local DUMP_LIMIT = 45
local DUMP_MIN_MS = 0.005

local stats = {}
local wrapperOf = {}
local active = false
local startedAt = 0
local instrumentedCount = 0

local function Finish(entry, startTime, ...)
	local elapsed = debugprofilestop() - startTime
	entry.total = entry.total + elapsed
	if elapsed > entry.max then entry.max = elapsed end
	return ...
end

local function Wrap(path, original)
	local entry = { count = 0, total = 0, max = 0, path = path }
	stats[path] = entry
	local wrapper = function(...)
		if not active then return original(...) end
		entry.count = entry.count + 1
		return Finish(entry, debugprofilestop(), original(...))
	end
	wrapperOf[wrapper] = original
	return wrapper
end

local function InstrumentTable(container, prefix, depth, seen)
	if seen[container] or depth > MAX_DEPTH then return end
	seen[container] = true
	for key, value in pairs(container) do
		if type(key) == 'string' and not SKIP_KEYS[key] and key:sub(1, 1) ~= '_' then
			local kind = type(value)
			if kind == 'function' then
				if not wrapperOf[value] and not stats[prefix .. key] then
					container[key] = Wrap(prefix .. key, value)
					instrumentedCount = instrumentedCount + 1
				end
			elseif kind == 'table' and rawget(value, 0) == nil then
				InstrumentTable(value, prefix .. key .. '.', depth + 1, seen)
			end
		end
	end
end

local function CollectRows()
	local rows = {}
	for _, entry in pairs(stats) do
		if entry.count > 0 then
			rows[#rows + 1] = { path = entry.path, count = entry.count, total = entry.total, max = entry.max }
		end
	end
	local profData, profCounters = BUI.Prof.GetData()
	for key, entry in pairs(profData) do
		if entry.count > 0 then
			rows[#rows + 1] = { path = '@' .. key, count = entry.count, total = entry.total, max = entry.max }
		end
	end
	for key, count in pairs(profCounters) do
		if count > 0 then
			rows[#rows + 1] = { path = '@' .. key, count = count, total = 0, max = 0 }
		end
	end
	return rows
end

local function CpuPerSecond()
	if not C_AddOnProfiler then return nil end
	local metricEnum = Enum.AddOnProfilerMetric
	if not metricEnum or not metricEnum.RecentAverageTime then return nil end
	local recent = C_AddOnProfiler.GetAddOnMetric('BluUI', metricEnum.RecentAverageTime)
	local fps = GetFramerate()
	if not recent or not fps or fps <= 0 then return nil end
	return recent * fps
end

local function Report()
	local window = (debugprofilestop() - startedAt) / 1000
	local rows = CollectRows()
	local billed = CpuPerSecond()
	local seen = 0
	for rowIndex = 1, #rows do seen = seen + rows[rowIndex].total end
	sort(rows, function(left, right)
		if left.total ~= right.total then return left.total > right.total end
		return left.count > right.count
	end)

	local shown, restMs, restCount = 0, 0, 0
	for rowIndex = 1, #rows do
		if shown < DUMP_LIMIT and rows[rowIndex].total >= DUMP_MIN_MS then
			shown = shown + 1
		else
			restMs = restMs + rows[rowIndex].total
			restCount = restCount + 1
		end
	end

	BUI.Print(('BURST %.2fs  |  |cffffd200billed %s|r, |cffffd200seen %.1fms/s|r  |  %d entries, top %d by time:'):format(
		window, billed and ('%.1fms/s (%.2f%% of a core)'):format(billed, billed / 10) or 'unknown',
		window > 0 and seen / window or 0, #rows, shown))
	for rowIndex = 1, shown do
		local entry = rows[rowIndex]
		print(('  |cff6D00FD%3d|r %s  |cffffd200%.2fms|r  x%d  (%.1f/s)  %.4fms/call  max %.2fms'):format(
			rowIndex, entry.path, entry.total, entry.count,
			window > 0 and entry.count / window or 0,
			entry.total / entry.count, entry.max))
	end
	if restCount > 0 then
		BUI.Print(('%d further entries account for %.2fms combined.'):format(restCount, restMs))
	end
end

function Trace.Burst(seconds)
	if active then
		BUI.Print('A burst is already running.')
		return
	end
	seconds = tonumber(seconds) or 10
	if seconds < 1 then seconds = 1 end
	if seconds > 60 then seconds = 60 end
	if instrumentedCount == 0 then InstrumentTable(BUI, '', 1, {}) end
	for _, entry in pairs(stats) do
		entry.count, entry.total, entry.max = 0, 0, 0
	end
	BUI.Prof.Start()
	startedAt = debugprofilestop()
	active = true
	BUI.Print(('Capturing %d seconds across %d functions and every named handler. Go now.'):format(seconds, instrumentedCount))
	C_Timer.After(seconds, function()
		active = false
		BUI.Prof.Stop()
		Report()
	end)
end
