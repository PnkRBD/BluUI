local _, BUI = ...

local debugprofilestop, GetTime, InCombatLockdown, issecretvalue = debugprofilestop, GetTime, InCombatLockdown, issecretvalue
local pairs, ipairs, rawget, wipe, setmetatable = pairs, ipairs, rawget, wipe, setmetatable
local sort, concat, format, floor, max, min = table.sort, table.concat, string.format, math.floor, math.max, math.min

local Profiler = BUI.Profiler
local Engine = BUI.AuraEngine
local oUF = BUI.oUF
local CountsText, Clock = Profiler.CountsText, Profiler.Clock

local UnitFrameProfiler = {}
BUI.UnitFrameProfiler = UnitFrameProfiler

local EVENT_KEY = 'Unit frame profiler'
local GROUP_STYLE = 'BluUI-Group'
local KEEP_FRAMES = 5
local TOP_EVENTS = 15
local TOP_BUSY = 10
local TOP_TAGS = 12
local TOP_HANDLERS = 15
local TOP_IN_FRAME = 3
local TOP_CAUSES = 3
local CAST_BAR_SUFFIX = ' cast bar'
local OWN_LABELS = { 'UnitFrames', 'GroupFrames', 'UFAuras', ' UF.', 'AuraEngine', 'AuraContainerEngine' }
local UNIT_NAMES = {
	player = 'Player', target = 'Target', targettarget = 'Target of target', focus = 'Focus', focustarget = 'Focus target',
	pet = 'Pet', boss = 'Boss', arena = 'Arena', party = 'Party', raid = 'Raid', previews = 'Options previews', other = 'Other',
}
local UNIT_ORDER = { 'player', 'target', 'targettarget', 'focus', 'focustarget', 'pet', 'boss', 'arena', 'party', 'raid', 'previews', 'other' }
local UNIT_RANK = {}
for index, key in ipairs(UNIT_ORDER) do UNIT_RANK[key] = index end
local NOT_MEASURED = 'Not measured: what Blizzard does in its own code (drawing bars, sorting and drawing aura icons), BluUI code without a label, and frames made in combat until combat ends.'

local running = false
local swapped = {}
local keyOf = setmetatable({}, { __mode = 'k' })
local seenAt = setmetatable({}, { __mode = 'k' })
local fullAt = setmetatable({}, { __mode = 'k' })
local barSetAt = setmetatable({}, { __mode = 'k' })
local lastValue = setmetatable({}, { __mode = 'k' })
local causeNames = {}

local unitStats, tagStats, labelInfo, watchedBars, countedTexts = {}, {}, {}, {}, {}
local frameUnits, frameEvents, frameLabels, worstFrames, unwatched = {}, {}, {}, {}, {}
local SESSION_TABLES = { unitStats, tagStats, labelInfo, watchedBars, countedTexts, frameUnits, frameEvents, frameLabels, worstFrames, unwatched }
local spanStart, spanMs = {}, {}
local spanTop = 0
local frameAt, frameCombat, frameMs = nil, false, 0
local currentSecond, secondMs, secondEvents = 0, 0, 0
local peakMs, peakMsAt, peakEvents, peakEventsAt = 0, 0, 0, 0
local startedAt, stoppedAt, clockAtStart, zoneAtStart, groupAtStart
local totalMs, combatMs, busyFrames, draws, watched, frameCount = 0, 0, 0, 0, 0, 0
local inCombat, combatSince, combatTime = false, 0, 0
local currentEvent, currentUnit

local function ByMs(left, right) return left.ms > right.ms end
local function ByCount(left, right) return left.count > right.count end

local function Or(text)
	return text ~= '' and text or 'none'
end

local function UnitName(key)
	return UNIT_NAMES[key] or key
end

local function KeyOf(object)
	local key = keyOf[object]
	if key then return key end
	if rawget(object, '_stage') then
		key = 'previews'
	elseif object.style == GROUP_STYLE then
		local header = object:GetParent()
		local name = header and header:GetName()
		key = name and name:find('Party', 1, true) and 'party' or 'raid'
	else
		local unitType = object._unitType or object.unit or 'other'
		key = unitType:match('^boss') and 'boss' or unitType:match('^arena') and 'arena' or unitType
	end
	keyOf[object] = key
	return key
end

local function ContainerKey(container)
	local frame = container:GetParent()
	while frame do
		if keyOf[frame] or rawget(frame, 'style') then return KeyOf(frame) end
		frame = frame:GetParent()
	end
	return 'other'
end

local function NewBarStat()
	return { sets = 0, same = 0, hidden = 0, again = 0 }
end

local function UnitStat(key)
	local stat = unitStats[key]
	if not stat then
		stat = {
			events = 0, combat = 0, ms = 0, hidden = 0, hiddenMs = 0, again = 0, byEvent = {},
			full = 0, fullMs = 0, fullAgain = 0, fullCauses = {},
			tags = 0, tagMs = 0, draws = 0,
			auras = 0, aurasMs = 0, binds = 0, bindsMs = 0,
			health = NewBarStat(), power = NewBarStat(),
		}
		unitStats[key] = stat
	end
	return stat
end

local function EventStat(unit, event)
	local stat = unit.byEvent[event]
	if not stat then
		stat = { count = 0, ms = 0, max = 0, hidden = 0, again = 0, combat = 0 }
		unit.byEvent[event] = stat
	end
	return stat
end

local function CauseName(key, event)
	local byEvent = causeNames[key]
	if not byEvent then
		byEvent = {}
		causeNames[key] = byEvent
	end
	local name = byEvent[event]
	if not name then
		name = format('%s on %s', event, UnitName(key))
		byEvent[event] = name
	end
	return name
end

local function MsText(map, count)
	local parts = {}
	for _, item in ipairs(Profiler.Top(map, count)) do parts[#parts + 1] = format('%s %.1fms', item.name, item.value) end
	return concat(parts, '; ')
end

local function KeepWorstFrame()
	worstFrames[#worstFrames + 1] = {
		at = frameAt - startedAt, ms = frameMs, combat = frameCombat,
		units = CountsText(frameUnits, TOP_IN_FRAME, UnitName), events = CountsText(frameEvents, TOP_IN_FRAME),
		handlers = MsText(frameLabels, TOP_IN_FRAME),
	}
	sort(worstFrames, ByMs)
	worstFrames[KEEP_FRAMES + 1] = nil
end

local function CloseFrame()
	busyFrames = busyFrames + 1
	totalMs = totalMs + frameMs
	secondMs = secondMs + frameMs
	if frameCombat then combatMs = combatMs + frameMs end
	local lastWorst = worstFrames[KEEP_FRAMES]
	if not lastWorst or frameMs > lastWorst.ms then KeepWorstFrame() end
	wipe(frameUnits)
	wipe(frameEvents)
	wipe(frameLabels)
	frameMs, spanTop = 0, 0
end

local function CloseSecond()
	if secondMs > peakMs then peakMs, peakMsAt = secondMs, currentSecond end
	if secondEvents > peakEvents then peakEvents, peakEventsAt = secondEvents, currentSecond end
	secondMs, secondEvents = 0, 0
end

local function Touch()
	local now = GetTime()
	if now == frameAt then return end
	if frameAt then CloseFrame() end
	frameAt = now
	frameCombat = inCombat
	currentEvent, currentUnit = nil, nil
	local second = floor(now - startedAt)
	if second ~= currentSecond then
		CloseSecond()
		currentSecond = second
	end
end

local function Span(start, elapsed)
	local covered = 0
	while spanTop > 0 and spanStart[spanTop] >= start do
		covered = covered + spanMs[spanTop]
		spanTop = spanTop - 1
	end
	spanTop = spanTop + 1
	spanStart[spanTop] = start
	spanMs[spanTop] = elapsed
	frameMs = frameMs + elapsed - covered
end

local function OnEvent(label, onEvent, frame, event, ...)
	if not running then return Profiler.Run(label, onEvent, frame, event, ...) end
	Touch()
	local key = KeyOf(frame)
	local visible = frame:IsVisible()
	local outerEvent, outerUnit = currentEvent, currentUnit
	currentEvent, currentUnit = event, key
	local start = debugprofilestop()
	Profiler.Run(label, onEvent, frame, event, ...)
	local elapsed = debugprofilestop() - start
	currentEvent, currentUnit = outerEvent, outerUnit
	Span(start, elapsed)
	local unit = UnitStat(key)
	local stat = EventStat(unit, event)
	unit.events = unit.events + 1
	unit.ms = unit.ms + elapsed
	stat.count = stat.count + 1
	stat.ms = stat.ms + elapsed
	if elapsed > stat.max then stat.max = elapsed end
	if inCombat then
		unit.combat = unit.combat + 1
		stat.combat = stat.combat + 1
	end
	if not visible then
		unit.hidden = unit.hidden + 1
		unit.hiddenMs = unit.hiddenMs + elapsed
		stat.hidden = stat.hidden + 1
	end
	local seen = seenAt[frame]
	if not seen then
		seen = {}
		seenAt[frame] = seen
	end
	if seen[event] == frameAt then
		unit.again = unit.again + 1
		stat.again = stat.again + 1
	else
		seen[event] = frameAt
	end
	frameUnits[key] = (frameUnits[key] or 0) + 1
	frameEvents[event] = (frameEvents[event] or 0) + 1
	secondEvents = secondEvents + 1
end

local function OnFullUpdate(label, updateAll, frame, event)
	if not running then return Profiler.Run(label, updateAll, frame, event) end
	Touch()
	local start = debugprofilestop()
	Profiler.Run(label, updateAll, frame, event)
	local elapsed = debugprofilestop() - start
	Span(start, elapsed)
	local unit = UnitStat(KeyOf(frame))
	unit.full = unit.full + 1
	unit.fullMs = unit.fullMs + elapsed
	local cause = event or 'no reason given'
	unit.fullCauses[cause] = (unit.fullCauses[cause] or 0) + 1
	if fullAt[frame] == frameAt then
		unit.fullAgain = unit.fullAgain + 1
	else
		fullAt[frame] = frameAt
	end
end

local function Swap(owner, key, wrapper)
	swapped[#swapped + 1] = { owner = owner, key = key, previous = rawget(owner, key), wrapper = wrapper }
	owner[key] = wrapper
end

local function Unswap()
	for index = #swapped, 1, -1 do
		local swap = swapped[index]
		if rawget(swap.owner, swap.key) == swap.wrapper then swap.owner[swap.key] = swap.previous end
		swapped[index] = nil
	end
end

local function CountDraws(fontString)
	if countedTexts[fontString] then return end
	countedTexts[fontString] = true
	local method = fontString.SetFormattedText
	Swap(fontString, 'SetFormattedText', function(self, ...)
		draws = draws + 1
		return method(self, ...)
	end)
end

local function TagStat(key, field)
	local byField = tagStats[key]
	if not byField then
		byField = {}
		tagStats[key] = byField
	end
	local stat = byField[field]
	if not stat then
		stat = { count = 0, ms = 0, max = 0, draws = 0 }
		byField[field] = stat
	end
	return stat
end

local function WrapTag(object, fontString)
	local original = rawget(fontString, 'UpdateTag')
	if not original then return end
	local key = KeyOf(object)
	local stat = TagStat(key, Profiler.TagName(object, fontString))
	CountDraws(fontString)
	Swap(fontString, 'UpdateTag', function(self)
		if not running then return original(self) end
		Touch()
		local before = draws
		local start = debugprofilestop()
		original(self)
		local elapsed = debugprofilestop() - start
		Span(start, elapsed)
		local unit = UnitStat(key)
		stat.count = stat.count + 1
		stat.ms = stat.ms + elapsed
		if elapsed > stat.max then stat.max = elapsed end
		unit.tags = unit.tags + 1
		unit.tagMs = unit.tagMs + elapsed
		if draws ~= before then
			stat.draws = stat.draws + 1
			unit.draws = unit.draws + 1
		end
	end)
end

local function CountBar(bar, key, which, value)
	Touch()
	local stat = UnitStat(key)[which]
	stat.sets = stat.sets + 1
	if issecretvalue(value) then
		stat.hidden = stat.hidden + 1
		lastValue[bar] = nil
	else
		if lastValue[bar] == value then stat.same = stat.same + 1 end
		lastValue[bar] = value
	end
	if barSetAt[bar] == frameAt then
		stat.again = stat.again + 1
	else
		barSetAt[bar] = frameAt
	end
end

local function WatchBar(object, field, which)
	local bar = rawget(object, field)
	if not bar or watchedBars[bar] then return end
	watchedBars[bar] = true
	local key = KeyOf(object)
	local method = bar.SetValue
	Swap(bar, 'SetValue', function(self, value, ...)
		if running then CountBar(self, key, which, value) end
		return method(self, value, ...)
	end)
end

local function WatchObject(object)
	if rawget(object, '_bluProfiled') then
		watched = watched + 1
	else
		unwatched[#unwatched + 1] = object:GetName() or UnitName(KeyOf(object))
	end
	WatchBar(object, 'Health', 'health')
	WatchBar(object, 'Power', 'power')
	Profiler.EachTag(object, WrapTag)
end

local function OnSpawn(object)
	if not running then return end
	frameCount = frameCount + 1
	WatchObject(object)
end

local function AuraWrapper(method, countField, msField)
	return function(container, ...)
		if not running then return method(container, ...) end
		Touch()
		local start = debugprofilestop()
		method(container, ...)
		local elapsed = debugprofilestop() - start
		Span(start, elapsed)
		local unit = UnitStat(ContainerKey(container))
		unit[countField] = unit[countField] + 1
		unit[msField] = unit[msField] + elapsed
	end
end

local function IsOwnLabel(label)
	for index = 1, #OWN_LABELS do
		if label:find(OWN_LABELS[index], 1, true) then return true end
	end
	return false
end

local function LabelInfo(label)
	local info = labelInfo[label]
	if info == nil then
		local castBar = label:sub(-#CAST_BAR_SUFFIX) == CAST_BAR_SUFFIX
		info = (castBar or IsOwnLabel(label)) and { count = 0, ms = 0, max = 0, combat = 0, from = {} } or false
		labelInfo[label] = info
	end
	return info
end

local function Trace(label, start, elapsed, _, parent)
	if not running then return end
	local info = labelInfo[label]
	if info == nil then info = LabelInfo(label) end
	if not info then return end
	Touch()
	Span(start, elapsed)
	info.count = info.count + 1
	info.ms = info.ms + elapsed
	if elapsed > info.max then info.max = elapsed end
	if inCombat then info.combat = info.combat + 1 end
	frameLabels[label] = (frameLabels[label] or 0) + elapsed
	local from = currentEvent and CauseName(currentUnit, currentEvent) or parent or 'its own event or timer'
	info.from[from] = (info.from[from] or 0) + 1
end

local WATCHER = { Event = OnEvent, FullUpdate = OnFullUpdate, Tag = function(object, fontString) if running then WrapTag(object, fontString) end end }

local function OnCombatStart()
	if inCombat then return end
	inCombat = true
	combatSince = GetTime()
end

local function OnCombatEnd()
	if not inCombat then return end
	inCombat = false
	combatTime = combatTime + GetTime() - combatSince
end

local function Duration()
	return max((stoppedAt or GetTime()) - startedAt, 1)
end

local function CombatSeconds()
	if inCombat then return combatTime + GetTime() - combatSince end
	return combatTime
end

local function Rate(count)
	return count / Duration()
end

local function Percent(part, whole)
	return whole > 0 and part / whole * 100 or 0
end

local function GroupText()
	local members = GetNumGroupMembers()
	if members == 0 then return 'solo' end
	return format('in a %s of %d', IsInRaid() and 'raid' or 'party', members)
end

local function UnitKeys()
	local keys = {}
	for key in pairs(unitStats) do keys[#keys + 1] = key end
	sort(keys, function(left, right)
		local leftRank, rightRank = UNIT_RANK[left] or #UNIT_ORDER + 1, UNIT_RANK[right] or #UNIT_ORDER + 1
		if leftRank ~= rightRank then return leftRank < rightRank end
		return left < right
	end)
	return keys
end

local function Sum(field, sub)
	local total = 0
	for _, stat in pairs(unitStats) do total = total + (sub and stat[sub][field] or stat[field]) end
	return total
end

local function SummaryLines(lines)
	local duration, combat = Duration(), CombatSeconds()
	lines[#lines + 1] = format('Unit frame profile: %s, %s of it in combat. Started in %s at %s, %s.',
		Clock(duration), Clock(combat), zoneAtStart, clockAtStart, groupAtStart)
	lines[#lines + 1] = format('Unit frame work: %.0fms in total, %.2fms a second (%.2f in combat, %.2f out of combat). It ran in %d frames; the worst took %.1fms. Busiest second: %.1fms at +%s.',
		totalMs, totalMs / duration, combat > 0 and combatMs / combat or 0, (totalMs - combatMs) / max(duration - combat, 1),
		busyFrames, worstFrames[1] and worstFrames[1].ms or 0, max(peakMs, secondMs), Clock(secondMs > peakMs and currentSecond or peakMsAt))
	local events = Sum('events')
	lines[#lines + 1] = format('Events: %d (%.0f a second). %d reached hidden frames, %d were the same event again on the same frame in one frame. Busiest second: %d events at +%s.',
		events, Rate(events), Sum('hidden'), Sum('again'), max(peakEvents, secondEvents), Clock(secondEvents > peakEvents and currentSecond or peakEventsAt))
	local tags = Sum('tags')
	lines[#lines + 1] = format('Full refreshes: %d. Text: %d tag updates, %d of them redrew (%.0f%%). Health set %d times, power %d times.',
		Sum('full'), tags, Sum('draws'), Percent(Sum('draws'), tags), Sum('sets', 'health'), Sum('sets', 'power'))
	lines[#lines + 1] = format('Watching %d of %d frames.%s', watched, frameCount,
		#unwatched > 0 and (' Not watched yet (made in combat, they join after it): ' .. concat(unwatched, ', ') .. '.') or '')
	lines[#lines + 1] = 'The full report is in the copy box: press Ctrl+C there to copy it.'
end

local function BarText(name, stat)
	if stat.sets == 0 then return nil end
	return format('%s set %d times: %d changed nothing, %d again in the same frame, %d hidden by Blizzard so not checked', name, stat.sets, stat.same, stat.again, stat.hidden)
end

local function UnitLines(lines)
	lines[#lines + 1] = '-- By unit (time includes nested work) --'
	for _, key in ipairs(UnitKeys()) do
		local stat = unitStats[key]
		lines[#lines + 1] = format('  %s: %d events (%.1f/s), %.1fms, %d in combat. %d reached the frame while hidden (%.1fms), %d were a repeat in the same frame.',
			UnitName(key), stat.events, Rate(stat.events), stat.ms, stat.combat, stat.hidden, stat.hiddenMs, stat.again)
		if stat.full > 0 then
			lines[#lines + 1] = format('    Full refreshes: %d (%.1fms), %d again in the same frame. From: %s.',
				stat.full, stat.fullMs, stat.fullAgain, Or(CountsText(stat.fullCauses, TOP_CAUSES)))
		end
		local bars = {}
		bars[#bars + 1] = BarText('Health', stat.health)
		bars[#bars + 1] = BarText('Power', stat.power)
		if #bars > 0 then lines[#lines + 1] = '    ' .. concat(bars, '. ') .. '.' end
		if stat.tags + stat.auras + stat.binds > 0 then
			lines[#lines + 1] = format('    Text: %d updates (%.1fms), %d redrew. Auras: %d setups (%.1fms), %d unit binds (%.1fms).',
				stat.tags, stat.tagMs, stat.draws, stat.auras, stat.aurasMs, stat.binds, stat.bindsMs)
		end
	end
end

local function EventRows()
	local rows = {}
	for key, unit in pairs(unitStats) do
		for event, stat in pairs(unit.byEvent) do
			rows[#rows + 1] = { key = key, event = event, ms = stat.ms, count = stat.count, stat = stat }
		end
	end
	return rows
end

local function EventLine(row)
	local stat = row.stat
	return format('  %s on %s: %d (%.1f/s), %.1fms, %.3f avg, %.2f max. %d hidden, %d repeats, %d in combat.',
		row.event, UnitName(row.key), stat.count, Rate(stat.count), stat.ms, stat.ms / stat.count, stat.max, stat.hidden, stat.again, stat.combat)
end

local function EventLines(lines)
	local rows = EventRows()
	lines[#lines + 1] = '-- Costliest events --'
	sort(rows, ByMs)
	for index = 1, min(TOP_EVENTS, #rows) do lines[#lines + 1] = EventLine(rows[index]) end
	lines[#lines + 1] = '-- Most frequent events --'
	sort(rows, ByCount)
	for index = 1, min(TOP_BUSY, #rows) do lines[#lines + 1] = EventLine(rows[index]) end
end

local function TagLines(lines)
	lines[#lines + 1] = '-- Text tags (updates, how many redrew, time) --'
	local rows = {}
	for key, byField in pairs(tagStats) do
		for field, stat in pairs(byField) do rows[#rows + 1] = { key = key, field = field, ms = stat.ms, stat = stat } end
	end
	sort(rows, ByMs)
	for index = 1, min(TOP_TAGS, #rows) do
		local row = rows[index]
		local stat = row.stat
		lines[#lines + 1] = format('  %s %s: %d updates (%.1f/s), %d redrew (%.0f%%), %.1fms, %.3f avg, %.2f max.',
			UnitName(row.key), row.field, stat.count, Rate(stat.count), stat.draws, Percent(stat.draws, stat.count),
			stat.ms, stat.ms / max(stat.count, 1), stat.max)
	end
end

local function PerUnit(field, sub)
	local map = {}
	for key, stat in pairs(unitStats) do
		local value = sub and stat[sub][field] or stat[field]
		if value > 0 then map[UnitName(key)] = value end
	end
	return map
end

local function RepeatPairs()
	local map = {}
	for key, unit in pairs(unitStats) do
		for event, stat in pairs(unit.byEvent) do
			if stat.again > 0 then map[CauseName(key, event)] = stat.again end
		end
	end
	return map
end

local function WasteLines(lines)
	lines[#lines + 1] = '-- Waste --'
	lines[#lines + 1] = format('  Events on hidden frames: %d (%.1fms). By unit: %s.', Sum('hidden'), Sum('hiddenMs'), Or(CountsText(PerUnit('hidden'), 6)))
	lines[#lines + 1] = format('  Same event again on the same frame in one frame: %d. Top: %s.', Sum('again'), Or(CountsText(RepeatPairs(), 5)))
	lines[#lines + 1] = format('  Full refreshes again in the same frame: %d (%s).', Sum('fullAgain'), Or(CountsText(PerUnit('fullAgain'), 6)))
	for _, which in ipairs({ 'health', 'power' }) do
		local sets, same, hidden = Sum('sets', which), Sum('same', which), Sum('hidden', which)
		lines[#lines + 1] = format('  %s sets that changed nothing: %d of %d checked (%.0f%%), %d set again in the same frame, %d hidden by Blizzard. By unit: %s.',
			which == 'health' and 'Health' or 'Power', same, sets - hidden, Percent(same, sets - hidden), Sum('again', which), hidden,
			Or(CountsText(PerUnit('same', which), 6)))
	end
	local tags, tagDraws = Sum('tags'), Sum('draws')
	lines[#lines + 1] = format('  Tag updates that drew nothing new: %d of %d (%.0f%%).', tags - tagDraws, tags, Percent(tags - tagDraws, tags))
end

local function PeakLines(lines)
	lines[#lines + 1] = '-- Worst frames by unit frame time --'
	for _, frame in ipairs(worstFrames) do
		lines[#lines + 1] = format('  +%s%s: %.1fms. Units: %s. Events: %s. Handlers: %s.',
			Clock(frame.at), frame.combat and ' in combat' or '', frame.ms, Or(frame.units), Or(frame.events), Or(frame.handlers))
	end
end

local function HandlerLines(lines)
	lines[#lines + 1] = '-- BluUI unit frame handlers by time (includes nested work) --'
	local handlers = {}
	for label, info in pairs(labelInfo) do
		if info then handlers[#handlers + 1] = { name = label, ms = info.ms } end
	end
	sort(handlers, ByMs)
	for index = 1, min(TOP_HANDLERS, #handlers) do
		local label = handlers[index].name
		local info = labelInfo[label]
		lines[#lines + 1] = format('  %s: %d runs (%.1f/s), %.1fms, %.2f avg, %.1f max, %d in combat. From: %s.',
			label, info.count, Rate(info.count), info.ms, info.ms / max(info.count, 1), info.max, info.combat, Or(CountsText(info.from, 2)))
	end
end

local function Build()
	local lines = {}
	SummaryLines(lines)
	local preview = #lines
	UnitLines(lines)
	EventLines(lines)
	TagLines(lines)
	WasteLines(lines)
	PeakLines(lines)
	HandlerLines(lines)
	lines[#lines + 1] = NOT_MEASURED
	return lines, preview
end

local function ResetSession()
	for _, map in ipairs(SESSION_TABLES) do wipe(map) end
	startedAt, stoppedAt = GetTime(), nil
	frameAt, frameMs, spanTop, currentSecond = nil, 0, 0, 0
	secondMs, secondEvents, peakMs, peakMsAt, peakEvents, peakEventsAt = 0, 0, 0, 0, 0, 0
	totalMs, combatMs, busyFrames, draws, watched, frameCount = 0, 0, 0, 0, 0, 0
	currentEvent, currentUnit = nil, nil
	inCombat, combatSince, combatTime = InCombatLockdown(), startedAt, 0
	zoneAtStart, clockAtStart, groupAtStart = GetRealZoneText(), date('%H:%M'), GroupText()
end

local function WatchAll()
	Unswap()
	wipe(watchedBars)
	wipe(countedTexts)
	wipe(unwatched)
	watched = 0
	frameCount = #oUF.objects
	for _, object in ipairs(oUF.objects) do WatchObject(object) end
	Swap(Engine, 'Configure', AuraWrapper(Engine.Configure, 'auras', 'aurasMs'))
	Swap(Engine, 'ConfigureSets', AuraWrapper(Engine.ConfigureSets, 'auras', 'aurasMs'))
	Swap(Engine, 'BindUnit', AuraWrapper(Engine.BindUnit, 'binds', 'bindsMs'))
end

local spawnHooked = false

function UnitFrameProfiler.IsRunning()
	return running
end

function UnitFrameProfiler.Start()
	if #oUF.objects == 0 then
		BUI.Print('There are no unit or group frames to profile.')
		return false
	end
	if not spawnHooked then
		spawnHooked = true
		oUF:RegisterInitCallback(OnSpawn)
	end
	ResetSession()
	running = true
	WatchAll()
	Profiler.WatchUnitFrames(WATCHER)
	Profiler.AddTracer(Trace)
	BUI.Events:Register('PLAYER_REGEN_DISABLED', EVENT_KEY, OnCombatStart)
	BUI.Events:Register('PLAYER_REGEN_ENABLED', EVENT_KEY, OnCombatEnd)
	return true
end

function UnitFrameProfiler.Stop()
	if frameAt then CloseFrame() end
	CloseSecond()
	OnCombatEnd()
	running = false
	stoppedAt = GetTime()
	frameAt = nil
	Profiler.WatchUnitFrames(nil)
	Profiler.RemoveTracer(Trace)
	Unswap()
	BUI.Events:Unregister('PLAYER_REGEN_DISABLED', EVENT_KEY)
	BUI.Events:Unregister('PLAYER_REGEN_ENABLED', EVENT_KEY)
end

function UnitFrameProfiler.Reset()
	ResetSession()
	if running then WatchAll() else startedAt = nil end
end

function UnitFrameProfiler.Report()
	if startedAt then return Build() end
end
