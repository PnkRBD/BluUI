local _, BUI = ...

local debugprofilestop, GetTime, InCombatLockdown, hooksecurefunc = debugprofilestop, GetTime, InCombatLockdown, hooksecurefunc
local pairs, ipairs, next, type, wipe = pairs, ipairs, next, type, wipe
local sort, concat, format, floor, max, min = table.sort, table.concat, string.format, math.floor, math.max, math.min
local issecretvalue = issecretvalue

local CDM = BUI.CDM
local Profiler = BUI.Profiler
local Running = Profiler.Running
local Top, CountsText, Clock = Profiler.Top, Profiler.CountsText, Profiler.Clock
local FrameData = CDM.FrameData
local LibEMO = LibStub('LibEditModeOverride-1.0')

local CDMProfiler = {}
BUI.CDMProfiler = CDMProfiler

local EVENT_KEY = 'Cooldown profiler'
local FLUSH_LABEL = 'CDM.DirtyTracking flush'
local BUFF_FLUSH_LABEL = 'CDM.BuffCenter flush'
local UNLABELLED = 'outside any BluUI label'
local KEEP_FRAMES = 5
local TOP_CAUSES = 5
local TOP_HANDLERS = 20
local TOP_HOOKS = 15
local TOP_PEAKS = 8
local NOT_MEASURED = 'Not measured: code outside BluUI labels and the wrapped CDM functions, alpha-only changes, BluUI work that starts inside a Blizzard method (hooks run after it), and the time Blizzard spends in its own viewer code.'

local VIEWER_TITLES = {
	essential = 'Essential', utility = 'Utility', buffs = 'Buff icons', bars = 'Buff bars',
	all = 'all viewers', other = 'other frames',
}
local KEY_ORDER = { 'essential', 'utility', 'buffs', 'bars', 'all', 'other' }
local VIEWER_METHODS = {
	'RefreshLayout', 'RefreshData', 'OnAcquireItemFrame', 'OnCooldownDataChanged', 'UpdateShownState',
	'SetIsEditing', 'UpdateSystemSetting', 'ApplySystemAnchor', 'SetPoint',
}
local EDIT_MODE_WRITES = {
	LoadLayouts = 'emoLoad', ReanchorFrame = 'emoReanchor', SetFrameSetting = 'emoSetting',
	SaveOnly = 'emoSave', ApplyChanges = 'emoApply',
}
local FRAME_WRITES = { ReanchorFrame = true, SetFrameSetting = true }
local LABEL_KINDS = {
	[FLUSH_LABEL] = 'flush',
	[BUFF_FLUSH_LABEL] = 'buffFlush',
	['CDM.CustomBars cooldown flush'] = 'barsFlush',
	['CDM.Custom dispatch flush'] = 'customFlush',
	['CDM.Keybinds refresh'] = 'keybindRefresh',
	['CDM.Keybinds NotifyDependents'] = 'keybindApply',
	['CDM.Keybinds RefreshLayout'] = 'keybindRequest',
	['CDM.Events cd poll'] = 'cdPoll',
	['Next frame CDM.CDWatch'] = 'cdCheck',
	['CDM.Events cd end'] = 'cdEnd',
	['CDM.Events item cd end'] = 'cdEnd',
	['CDM.Events cooldown done'] = 'cdDone',
	['CDM.Events layout refresh'] = 'editLayoutRefresh',
	['EDIT_MODE_LAYOUTS_UPDATED CDM.Layout'] = 'editModeEvent',
	['CDM.EditModeLock edit mode show'] = 'editModeOpen',
	['CDM.Glow ShowAlert'] = 'procShow',
	['CDM.Glow ActionButton_ShowOverlayGlow'] = 'procShow',
	['CDM.Glow HideAlert'] = 'procHide',
	['CDM.Glow ActionButton_HideOverlayGlow'] = 'procHide',
}
local KINDS = {
	{ 'mark', 'Dirty marks (full)' },
	{ 'markLayout', 'Dirty marks (layout only)' },
	{ 'markAll', 'Mark-everything calls' },
	{ 'hiddenMark', 'Marks while the viewer was hidden' },
	{ 'iconCache', 'Icon list invalidations' },
	{ 'skinReset', 'Skin resets (every icon restyles on its next pass)' },
	{ 'flush', 'Dirty flushes' },
	{ 'layout', 'Layout passes' },
	{ 'layoutSame', 'Layout passes that changed nothing' },
	{ 'layoutRepeat', 'Layout passes again in the same frame' },
	{ 'refreshAll', 'Full refreshes' },
	{ 'refreshLayout', 'Layout-only refreshes' },
	{ 'refreshSkin', 'Skin setting refreshes' },
	{ 'refreshSize', 'Size setting refreshes' },
	{ 'opacity', 'Opacity passes' },
	{ 'buffCenterRequest', 'Buff centering requests' },
	{ 'buffCenterNow', 'Buff centering calls' },
	{ 'buffFlush', 'Buff centering flushes' },
	{ 'anchorPass', 'All-anchor passes' },
	{ 'anchorApply', 'Anchor position passes' },
	{ 'anchorMove', 'Anchor moves' },
	{ 'anchorMoveSame', 'Anchors re-anchored to the same spot' },
	{ 'anchorResize', 'Anchor resizes' },
	{ 'iconMove', 'Icons moved by BluUI' },
	{ 'iconMoveSame', 'Icons re-anchored to the same spot' },
	{ 'iconMoveOther', 'Icons moved by Blizzard or other code' },
	{ 'snapBack', 'Icons BluUI snapped back' },
	{ 'detachedPlace', 'Detached icon placements' },
	{ 'restyle', 'Icon restyles' },
	{ 'restyleSkip', 'Restyle calls on icons already styled' },
	{ 'restyleRepeat', 'Icons restyled again in the same frame' },
	{ 'reclaim', 'Style reclaims on icons shown again' },
	{ 'cooldownRestyle', 'Cooldown swipe restyles' },
	{ 'glowStart', 'Glows started' },
	{ 'glowStartSkip', 'Glow starts that changed nothing' },
	{ 'glowStop', 'Glows stopped' },
	{ 'glowStopSkip', 'Glow stops on icons with no glow' },
	{ 'procShow', 'Blizzard proc alerts shown' },
	{ 'procHide', 'Blizzard proc alerts hidden' },
	{ 'keybindRequest', 'Keybind rebuild requests' },
	{ 'keybindRefresh', 'Keybind rebuilds' },
	{ 'keybindApply', 'Keybind apply checks' },
	{ 'keybindViewer', 'Keybind viewer restyles' },
	{ 'cdCheck', 'Cooldown watch checks' },
	{ 'cdPoll', 'Cooldown polls' },
	{ 'cdEnd', 'Cooldown end timers' },
	{ 'cdDone', 'Cooldown finished callbacks' },
	{ 'customRefresh', 'Custom icon refreshes' },
	{ 'customFlush', 'Custom icon update flushes' },
	{ 'barsRefresh', 'Custom bar refreshes' },
	{ 'barsFlush', 'Custom bar cooldown flushes' },
	{ 'editModeEvent', 'Edit Mode layout events' },
	{ 'editModeOpen', 'Edit Mode opened' },
	{ 'editLayoutRefresh', 'Edit Mode layout refreshes' },
	{ 'editSave', 'Edit Mode save attempts' },
	{ 'emoLoad', 'Edit Mode layouts loaded' },
	{ 'emoReanchor', 'Edit Mode re-anchors written' },
	{ 'emoSetting', 'Edit Mode settings written' },
	{ 'emoSave', 'Edit Mode saves' },
	{ 'emoApply', 'Edit Mode applies' },
}
local KIND_NAMES, LAYOUT_NAMES = {}, {}
for _, entry in ipairs(KINDS) do KIND_NAMES[entry[1]] = entry[2] end
for _, key in ipairs(CDM.VIEWER_KEYS) do LAYOUT_NAMES[key] = VIEWER_TITLES[key] .. ' layout' end
local MARK_KINDS = { 'mark', 'markLayout' }

local running = false
local swaps = {}
local hooked = setmetatable({}, { __mode = 'k' })
local viewerKeyOf = setmetatable({}, { __mode = 'k' })
local anchorKeyOf = setmetatable({}, { __mode = 'k' })
local spots = setmetatable({}, { __mode = 'k' })
local sizes = setmetatable({}, { __mode = 'k' })
local prettyNames, causeNames, dirtyNames = {}, {}, {}

local labelInfo, kindStats, blizzard = {}, {}, {}
local pendingCause, pendingRoot, pendingInner = {}, {}, {}
local frameKinds, frameLabelMs, frameCauses, frameLayouts, frameRestyled = {}, {}, {}, {}, {}
local secondKinds, worstFrames, repeatFrames = {}, {}, {}
local SESSION_TABLES = {
	labelInfo, kindStats, blizzard, pendingCause, pendingRoot, pendingInner,
	frameKinds, frameLabelMs, frameCauses, frameLayouts, frameRestyled, secondKinds, worstFrames, repeatFrames,
}
local spanStart, spanMs, driverName, driverDepth = {}, {}, {}, {}
local spanTop, driverTop, markDepth, outputs = 0, 0, 0, 0
local frameAt, frameCombat, frameMs, frameLayoutRepeats, frameRestyleRepeats = nil, false, 0, 0, 0
local currentSecond = 0
local startedAt, stoppedAt, clockAtStart, specAtStart, zoneAtStart
local totalMs, combatMs, busyFrames, repeatFrameCount = 0, 0, 0, 0
local inCombat, combatSince, combatTime = false, 0, 0

local function ByValue(left, right) return left.value > right.value end
local function ByMs(left, right) return left.ms > right.ms end
local function ByRepeats(left, right) return left.repeats > right.repeats end

local function Pretty(label)
	local pretty = prettyNames[label]
	if pretty then return pretty end
	local method = Profiler.HookedMethod(label)
	if method then
		local group = label:sub(1, #label - #method - 1)
		local viewer = VIEWER_TITLES[group:match('^CDM%.(%l+)$')]
		pretty = viewer and format('Blizzard %s %s', viewer, method) or format('Blizzard %s (%s)', method, group)
	else
		local event, key = label:match('^([%u_]+) (.+)$')
		pretty = event and format('%s (%s)', event, key) or label
	end
	prettyNames[label] = pretty
	return pretty
end

local function KindName(kind)
	return KIND_NAMES[kind]
end

local function MsText(map, count)
	local parts = {}
	for _, item in ipairs(Top(map, count)) do parts[#parts + 1] = format('%s %.1fms', Pretty(item.name), item.value) end
	return concat(parts, '; ')
end

local function Or(text)
	return text ~= '' and text or 'none'
end

local function CauseName(first, via)
	if not via or via == first then return Pretty(first) end
	local byVia = causeNames[first]
	if not byVia then
		byVia = {}
		causeNames[first] = byVia
	end
	local name = byVia[via]
	if not name then
		name = Pretty(first) .. ' > ' .. Pretty(via)
		byVia[via] = name
	end
	return name
end

local function DirtyName(cause)
	local name = dirtyNames[cause]
	if not name then
		name = 'marks from ' .. cause
		dirtyNames[cause] = name
	end
	return name
end

local function LabelInfo(label)
	local info = labelInfo[label]
	if info == nil then
		local cdm = label:find('CDM', 1, true) or label:find('CustomBars', 1, true) or label:find('Custom bars', 1, true)
		info = cdm and {
			count = 0, combat = 0, ms = 0, max = 0, outputs = 0, from = {}, work = {},
			kind = LABEL_KINDS[label], hook = Profiler.HookedMethod(label),
		} or false
		labelInfo[label] = info
	end
	return info
end

local function NewKindStat()
	return { count = 0, combat = 0, ms = 0, max = 0, peak = 0, peakAt = 0, keys = {}, causes = {}, keyCauses = {} }
end

local EMPTY_STAT = NewKindStat()

local function Stat(kind)
	return kindStats[kind] or EMPTY_STAT
end

local function KeyCount(kind, key)
	return Stat(kind).keys[key] or 0
end

local function Keep(list, entry, compare)
	list[#list + 1] = entry
	sort(list, compare)
	list[KEEP_FRAMES + 1] = nil
end

local function KeepWorstFrame()
	Keep(worstFrames, {
		at = frameAt - startedAt, ms = frameMs, combat = frameCombat,
		work = CountsText(frameKinds, 5, KindName), handlers = MsText(frameLabelMs, 3), causes = CountsText(frameCauses, 3),
	}, ByMs)
end

local function KeepRepeatFrame(repeats)
	local parts = {}
	for _, key in ipairs(KEY_ORDER) do
		local times = frameLayouts[key]
		if times and times > 1 then parts[#parts + 1] = format('%s laid out %d times', VIEWER_TITLES[key], times) end
	end
	if frameRestyleRepeats > 0 then parts[#parts + 1] = format('%d icon restyles repeated', frameRestyleRepeats) end
	Keep(repeatFrames, {
		at = frameAt - startedAt, repeats = repeats, combat = frameCombat,
		text = concat(parts, ', '), causes = CountsText(frameCauses, 3),
	}, ByRepeats)
end

local function CloseFrame()
	busyFrames = busyFrames + 1
	totalMs = totalMs + frameMs
	if frameCombat then combatMs = combatMs + frameMs end
	local lastWorst = worstFrames[KEEP_FRAMES]
	if not lastWorst or frameMs > lastWorst.ms then KeepWorstFrame() end
	local repeats = frameLayoutRepeats + frameRestyleRepeats
	if repeats > 0 then
		repeatFrameCount = repeatFrameCount + 1
		local lastRepeat = repeatFrames[KEEP_FRAMES]
		if not lastRepeat or repeats > lastRepeat.repeats then KeepRepeatFrame(repeats) end
	end
	wipe(frameKinds)
	wipe(frameLabelMs)
	wipe(frameCauses)
	wipe(frameLayouts)
	wipe(frameRestyled)
	frameMs, frameLayoutRepeats, frameRestyleRepeats, spanTop = 0, 0, 0, 0
end

local function CloseSecond()
	for kind, count in pairs(secondKinds) do
		local stat = kindStats[kind]
		if count > stat.peak then
			stat.peak = count
			stat.peakAt = currentSecond
		end
	end
	wipe(secondKinds)
end

local function Touch()
	local now = GetTime()
	if now == frameAt then return end
	if frameAt then CloseFrame() end
	frameAt = now
	frameCombat = inCombat
	driverTop, markDepth = 0, 0
	local second = floor(now - startedAt)
	if second ~= currentSecond then
		CloseSecond()
		currentSecond = second
	end
end

local function Cause()
	Touch()
	local depth, root, inner = Running()
	local first, via = root, inner
	if driverTop > 0 then
		if driverDepth[1] == 0 then first = driverName[1] end
		if driverDepth[driverTop] >= depth then via = driverName[driverTop] end
	end
	return CauseName(first or UNLABELLED, via), root, inner
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

local function Attribute(label, kind)
	local info = label and LabelInfo(label)
	if info then info.work[kind] = (info.work[kind] or 0) + 1 end
end

local function CountKind(kind, key, ms, cause, root, inner)
	local stat = kindStats[kind]
	if not stat then
		stat = NewKindStat()
		kindStats[kind] = stat
	end
	stat.count = stat.count + 1
	if inCombat then stat.combat = stat.combat + 1 end
	if ms then
		stat.ms = stat.ms + ms
		if ms > stat.max then stat.max = ms end
	end
	frameKinds[kind] = (frameKinds[kind] or 0) + 1
	secondKinds[kind] = (secondKinds[kind] or 0) + 1
	if key then stat.keys[key] = (stat.keys[key] or 0) + 1 end
	if not cause then return end
	stat.causes[cause] = (stat.causes[cause] or 0) + 1
	frameCauses[cause] = (frameCauses[cause] or 0) + 1
	if key then
		local byKey = stat.keyCauses[key]
		if not byKey then
			byKey = {}
			stat.keyCauses[key] = byKey
		end
		byKey[cause] = (byKey[cause] or 0) + 1
	end
	Attribute(root, kind)
	if inner ~= root then Attribute(inner, kind) end
end

local function Output(inner)
	outputs = outputs + 1
	local info = inner and LabelInfo(inner)
	if info then info.outputs = info.outputs + 1 end
end

local function Trace(label, start, elapsed)
	local info = labelInfo[label]
	if info == nil then info = LabelInfo(label) end
	if not info then return end
	local cause = Cause()
	Span(start, elapsed)
	info.count = info.count + 1
	info.ms = info.ms + elapsed
	if elapsed > info.max then info.max = elapsed end
	if inCombat then info.combat = info.combat + 1 end
	info.from[cause] = (info.from[cause] or 0) + 1
	frameLabelMs[label] = (frameLabelMs[label] or 0) + elapsed
	if info.kind then CountKind(info.kind, nil, elapsed) end
end

local function Driver(name)
	Touch()
	driverTop = driverTop + 1
	driverName[driverTop] = name
	driverDepth[driverTop] = (Running())
end

local function Done(kind, key, start, ...)
	local elapsed = debugprofilestop() - start
	driverTop = driverTop - 1
	Span(start, elapsed)
	CountKind(kind, key, elapsed, Cause())
	return ...
end

local function Timed(original, kind, name, keyOf)
	return function(...)
		if not running then return original(...) end
		Driver(name)
		return Done(kind, keyOf and keyOf(...), debugprofilestop(), original(...))
	end
end

local function Counted(original, kind, keyOf, visible)
	return function(...)
		if not running then return original(...) end
		local cause, root, inner = Cause()
		CountKind(kind, keyOf and keyOf(...), nil, cause, root, inner)
		if visible then Output(inner) end
		return original(...)
	end
end

local function FirstKey(key) return key end
local function FirstKeyOrAll(key) return key or 'all' end
local function SecondKey(_, key) return key end
local function FrameKey(_, frame) return viewerKeyOf[frame] or 'other' end
local function IconKey(icon) return FrameData[icon].viewerKey end

local function NoteViewerMark(key, cause, root, inner)
	local viewer = _G[CDM.VIEWERS[key]]
	if viewer and not viewer:IsShown() then CountKind('hiddenMark', key, nil, cause, root, inner) end
	if not pendingCause[key] then
		pendingCause[key], pendingRoot[key], pendingInner[key] = cause, root, inner
	end
end

local function EndMark(...)
	markDepth = markDepth - 1
	driverTop = driverTop - 1
	return ...
end

local function MarkWrapper(original, kind, name)
	return function(key)
		if not running or markDepth > 0 then return original(key) end
		local cause, root, inner = Cause()
		CountKind(kind, key, nil, cause, root, inner)
		if key then
			NoteViewerMark(key, cause, root, inner)
		else
			for index = 1, CDM.VIEWER_KEYS_COUNT do NoteViewerMark(CDM.VIEWER_KEYS[index], cause, root, inner) end
		end
		markDepth = markDepth + 1
		Driver(name)
		return EndMark(original(key))
	end
end

local function EndLayout(key, cause, root, inner, anchor, shown, before, start, ...)
	local elapsed = debugprofilestop() - start
	driverTop = driverTop - 1
	Span(start, elapsed)
	CountKind('layout', key, elapsed, cause, root, inner)
	if outputs == before and not (anchor and anchor:IsShown() ~= shown) then
		CountKind('layoutSame', key, nil, cause, root, inner)
	end
	local times = (frameLayouts[key] or 0) + 1
	frameLayouts[key] = times
	if times > 1 then
		frameLayoutRepeats = frameLayoutRepeats + 1
		CountKind('layoutRepeat', key, nil, cause, root, inner)
	end
	return ...
end

local function LayoutWrapper(original)
	return function(key)
		if not running then return original(key) end
		local cause, root, inner = Cause()
		if inner == FLUSH_LABEL and pendingCause[key] then
			cause, root, inner = DirtyName(pendingCause[key]), pendingRoot[key], pendingInner[key]
		end
		pendingCause[key] = nil
		local anchor = CDM.Anchors[key]
		Driver(LAYOUT_NAMES[key])
		return EndLayout(key, cause, root, inner, anchor, anchor and anchor:IsShown(), outputs, debugprofilestop(), original(key))
	end
end

local function EndSkin(icon, key, before, cause, root, inner, start, ...)
	local elapsed = debugprofilestop() - start
	driverTop = driverTop - 1
	Span(start, elapsed)
	local frameData = FrameData[icon]
	if not (frameData and frameData.skinVer ~= before) then
		CountKind('restyleSkip', key, elapsed, cause, root, inner)
		return ...
	end
	CountKind('restyle', key, elapsed, cause, root, inner)
	Output(inner)
	local times = (frameRestyled[icon] or 0) + 1
	frameRestyled[icon] = times
	if times > 1 then
		frameRestyleRepeats = frameRestyleRepeats + 1
		CountKind('restyleRepeat', key, nil, cause, root, inner)
	end
	return ...
end

local function SkinWrapper(original)
	return function(icon, settings, key)
		if not running then return original(icon, settings, key) end
		local frameData = FrameData[icon]
		local before = frameData and frameData.skinVer
		local cause, root, inner = Cause()
		Driver('Restyle')
		return EndSkin(icon, key, before, cause, root, inner, debugprofilestop(), original(icon, settings, key))
	end
end

local function EndCooldown(frameData, before, ...)
	if frameData and frameData.styleVer ~= before then CountKind('cooldownRestyle', nil, nil, Cause()) end
	return ...
end

local function CooldownWrapper(original)
	return function(cooldown)
		if not running or issecretvalue(cooldown) then return original(cooldown) end
		local frameData = FrameData[cooldown]
		return EndCooldown(frameData, frameData and frameData.styleVer, original(cooldown))
	end
end

local function EndGlowStart(icon, wasActive, wasType, wasColor, cause, root, inner, start, ...)
	local elapsed = debugprofilestop() - start
	driverTop = driverTop - 1
	Span(start, elapsed)
	local frameData = FrameData[icon]
	local started = frameData and frameData.glowActive
		and not (wasActive and frameData.glowType == wasType and frameData.glowColor == wasColor)
	CountKind(started and 'glowStart' or 'glowStartSkip', frameData and frameData.viewerKey, elapsed, cause, root, inner)
	return ...
end

local function GlowStartWrapper(original)
	return function(icon, perIconGlow)
		if not running then return original(icon, perIconGlow) end
		local frameData = FrameData[icon]
		local wasActive, wasType, wasColor
		if frameData then wasActive, wasType, wasColor = frameData.glowActive, frameData.glowType, frameData.glowColor end
		local cause, root, inner = Cause()
		Driver('Glow start')
		return EndGlowStart(icon, wasActive, wasType, wasColor, cause, root, inner, debugprofilestop(), original(icon, perIconGlow))
	end
end

local function GlowStopWrapper(original)
	return function(icon)
		if not running then return original(icon) end
		local frameData = FrameData[icon]
		local cause, root, inner = Cause()
		CountKind(frameData and frameData.glowActive and 'glowStop' or 'glowStopSkip', frameData and frameData.viewerKey, nil, cause, root, inner)
		return original(icon)
	end
end

local function SameSpot(frame, point, relativeTo, relativePoint, x, y)
	local spot = spots[frame]
	if not spot then
		spot = {}
		spots[frame] = spot
	end
	local same = spot[1] == point and spot[2] == relativeTo and spot[3] == relativePoint and spot[4] == x and spot[5] == y
	spot[1], spot[2], spot[3], spot[4], spot[5] = point, relativeTo, relativePoint, x, y
	return same
end

local function OnIconSetPoint(icon, point, relativeTo, relativePoint, x, y)
	if not running then return end
	local frameData = FrameData[icon]
	local key = frameData.viewerKey
	local cause, root, inner = Cause()
	if frameData.locking then
		if SameSpot(icon, point, relativeTo, relativePoint, x, y) then
			CountKind('iconMoveSame', key, nil, cause, root, inner)
		else
			CountKind('iconMove', key, nil, cause, root, inner)
			Output(inner)
		end
		return
	end
	CountKind('iconMoveOther', key, nil, cause, root, inner)
	if frameData.anchor then
		CountKind('snapBack', key, nil, cause, root, inner)
	else
		spots[icon] = nil
	end
end

local function OnAnchorSetPoint(anchor, point, relativeTo, relativePoint, x, y)
	if not running then return end
	local cause, root, inner = Cause()
	if SameSpot(anchor, point, relativeTo, relativePoint, x, y) then
		CountKind('anchorMoveSame', anchorKeyOf[anchor], nil, cause, root, inner)
		return
	end
	CountKind('anchorMove', anchorKeyOf[anchor], nil, cause, root, inner)
	Output(inner)
end

local function OnAnchorSetSize(anchor, width, height)
	if not running then return end
	local size = sizes[anchor]
	if not size then
		size = {}
		sizes[anchor] = size
	end
	if size[1] == width and size[2] == height then return end
	size[1], size[2] = width, height
	local cause, root, inner = Cause()
	CountKind('anchorResize', anchorKeyOf[anchor], nil, cause, root, inner)
	Output(inner)
end

local function OnViewerCall(viewer, method)
	local key = viewerKeyOf[viewer]
	local byMethod = blizzard[key]
	if not byMethod then
		byMethod = {}
		blizzard[key] = byMethod
	end
	local stat = byMethod[method]
	if not stat then
		stat = { count = 0, combat = 0, inside = 0, from = {} }
		byMethod[method] = stat
	end
	local cause, root = Cause()
	stat.count = stat.count + 1
	if inCombat then stat.combat = stat.combat + 1 end
	if root or driverTop > 0 then
		stat.inside = stat.inside + 1
		stat.from[cause] = (stat.from[cause] or 0) + 1
	end
end

local viewerHooks = {}
for _, method in ipairs(VIEWER_METHODS) do
	viewerHooks[method] = function(viewer)
		if running then OnViewerCall(viewer, method) end
	end
end

local function HookIcon(icon)
	if hooked[icon] or not FrameData[icon] then return end
	hooked[icon] = true
	hooksecurefunc(icon, 'SetPoint', OnIconSetPoint)
end

local function HookAnchor(anchor, key)
	if hooked[anchor] then return end
	hooked[anchor] = true
	anchorKeyOf[anchor] = key
	hooksecurefunc(anchor, 'SetPoint', OnAnchorSetPoint)
	hooksecurefunc(anchor, 'SetSize', OnAnchorSetSize)
end

local function HookViewerFrame(viewer, key)
	if not viewer or hooked[viewer] then return end
	hooked[viewer] = true
	viewerKeyOf[viewer] = key
	for _, method in ipairs(VIEWER_METHODS) do
		if type(viewer[method]) == 'function' then hooksecurefunc(viewer, method, viewerHooks[method]) end
	end
end

local function HookFrames()
	for key, viewerName in pairs(CDM.VIEWERS) do
		HookViewerFrame(_G[viewerName], key)
		local anchor = CDM.Anchors[key]
		if anchor then HookAnchor(anchor, key) end
		local tracked, trackedCount = CDM.GetTrackedIcons(key)
		for index = 1, trackedCount do HookIcon(tracked[index]) end
		local custom, customCount = CDM.Custom.GetIcons(key)
		for index = 1, customCount do HookIcon(custom[index]) end
	end
	HookViewerFrame(_G.BuffBarCooldownViewer, 'bars')
end

local function HookIconWrapper(original)
	return function(icon, key)
		if not running then return original(icon, key) end
		original(icon, key)
		HookIcon(icon)
	end
end

local function Swap(owner, key, make, ...)
	local original = owner[key]
	local wrapper = make(original, ...)
	swaps[#swaps + 1] = { owner = owner, key = key, original = original, wrapper = wrapper }
	owner[key] = wrapper
end

local function Unswap()
	for index = #swaps, 1, -1 do
		local swap = swaps[index]
		if swap.owner[swap.key] == swap.wrapper then swap.owner[swap.key] = swap.original end
		swaps[index] = nil
	end
end

local function InstallSwaps()
	local Keybinds = CDM.Keybinds
	Swap(CDM, 'MarkDirty', MarkWrapper, 'mark', 'MarkDirty')
	Swap(CDM, 'MarkLayoutDirty', MarkWrapper, 'markLayout', 'MarkLayoutDirty')
	Swap(CDM, 'MarkAllDirty', MarkWrapper, 'markAll', 'MarkAllDirty')
	Swap(CDM, 'InvalidateIconCache', Counted, 'iconCache', FirstKeyOrAll)
	Swap(CDM, 'InvalidateSkinCache', Timed, 'skinReset', 'InvalidateSkinCache')
	Swap(CDM, 'ApplyIconPositions', LayoutWrapper)
	Swap(CDM, 'RefreshAll', Timed, 'refreshAll', 'RefreshAll')
	Swap(CDM, 'RefreshLayoutOnly', Timed, 'refreshLayout', 'RefreshLayoutOnly')
	Swap(CDM, 'RefreshSkinSettings', Timed, 'refreshSkin', 'RefreshSkinSettings')
	Swap(CDM, 'RefreshSizeSettings', Timed, 'refreshSize', 'RefreshSizeSettings')
	Swap(CDM, 'UpdateOpacity', Timed, 'opacity', 'UpdateOpacity')
	Swap(CDM, 'MarkBuffCenterDirty', Counted, 'buffCenterRequest')
	Swap(CDM, 'CenterBuffsNow', Timed, 'buffCenterNow', 'CenterBuffsNow')
	Swap(CDM, 'ApplyAllPositions', Timed, 'anchorPass', 'ApplyAllPositions')
	Swap(CDM, 'ApplyAnchorPosition', Timed, 'anchorApply', 'ApplyAnchorPosition', FirstKey)
	Swap(CDM, 'SaveToEditModeLayout', Timed, 'editSave', 'SaveToEditModeLayout', FirstKey)
	Swap(CDM, 'HookIconFrame', HookIconWrapper)
	Swap(CDM, 'SkinIcon', SkinWrapper)
	Swap(CDM, 'RestyleCooldown', CooldownWrapper)
	Swap(CDM, 'ReclaimShownIconStyle', Counted, 'reclaim', IconKey, true)
	Swap(CDM, 'StartProcGlow', GlowStartWrapper)
	Swap(CDM, 'StopProcGlow', GlowStopWrapper)
	Swap(CDM.Detached, 'PlaceIcon', Timed, 'detachedPlace', 'Detached.PlaceIcon', SecondKey)
	Swap(CDM.Custom, 'Refresh', Timed, 'customRefresh', 'Custom.Refresh', FirstKeyOrAll)
	Swap(Keybinds, 'ScheduleRebuild', Counted, 'keybindRequest')
	Swap(Keybinds, 'RefreshViewer', Timed, 'keybindViewer', 'Keybinds.RefreshViewer', FirstKey)
	Swap(Keybinds, 'StyleViewer', Timed, 'keybindViewer', 'Keybinds.StyleViewer', FirstKey)
	Swap(BUI.CustomBars, 'RefreshAllBars', Timed, 'barsRefresh', 'CustomBars.RefreshAllBars')
	for method, kind in pairs(EDIT_MODE_WRITES) do
		if LibEMO[method] then Swap(LibEMO, method, Timed, kind, 'Edit Mode ' .. method, FRAME_WRITES[method] and FrameKey) end
	end
end

local function SpecName()
	local className = UnitClass('player')
	local index = GetSpecialization()
	local specName = index and select(2, GetSpecializationInfo(index))
	return specName and format('%s %s', specName, className) or className
end

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

local function KeysText(keys)
	local parts = {}
	for _, key in ipairs(KEY_ORDER) do
		local count = keys[key]
		if count then parts[#parts + 1] = format('%s %d', VIEWER_TITLES[key], count) end
	end
	return concat(parts, ', ')
end

local function Peak(kind, stat)
	local current = secondKinds[kind] or 0
	if current > stat.peak then return current, currentSecond end
	return stat.peak, stat.peakAt
end

local function MergedCauses(kinds, key)
	local merged = {}
	for _, kind in ipairs(kinds) do
		local causes = Stat(kind).keyCauses[key]
		if causes then
			for cause, count in pairs(causes) do merged[cause] = (merged[cause] or 0) + count end
		end
	end
	return merged
end

local function CauseLine(lines, prefix, causes)
	if causes and next(causes) then lines[#lines + 1] = prefix .. CountsText(causes, TOP_CAUSES) end
end

local function SummaryLines(lines)
	local duration, combat = Duration(), CombatSeconds()
	local spec = SpecName()
	lines[#lines + 1] = format('CDM profile: %s, %s of it in combat. %s, started in %s at %s.%s',
		Clock(duration), Clock(combat), specAtStart, zoneAtStart, clockAtStart,
		spec ~= specAtStart and format(' Spec is now %s.', spec) or '')
	lines[#lines + 1] = format('CDM work: %.0fms in total, %.2fms a second (%.2f in combat, %.2f out of combat). It ran in %d frames; the worst took %.1fms.',
		totalMs, totalMs / duration, combat > 0 and combatMs / combat or 0, (totalMs - combatMs) / max(duration - combat, 1),
		busyFrames, worstFrames[1] and worstFrames[1].ms or 0)
	local markAll = Stat('markAll').count
	for _, key in ipairs(CDM.VIEWER_KEYS) do
		local layouts = KeyCount('layout', key)
		local marks = KeyCount('mark', key) + KeyCount('markLayout', key) + markAll
		if layouts + marks > 0 then
			lines[#lines + 1] = format('%s laid out %d times (%.1f/s), %d of them again in the same frame, %d changed nothing. Marked dirty %d times, %d while hidden.',
				VIEWER_TITLES[key], layouts, Rate(layouts), KeyCount('layoutRepeat', key), KeyCount('layoutSame', key), marks, KeyCount('hiddenMark', key))
		end
	end
	lines[#lines + 1] = format('Restyles: %d, %d of them again in the same frame; %d restyle calls found the icon already styled. Glows: %d started, %d stopped.',
		Stat('restyle').count, Stat('restyleRepeat').count, Stat('restyleSkip').count, Stat('glowStart').count, Stat('glowStop').count)
	lines[#lines + 1] = format('Moves: BluUI moved icons %d times and re-anchored them to the same spot %d times. Blizzard or other code moved icons %d times; BluUI snapped %d of them back.',
		Stat('iconMove').count, Stat('iconMoveSame').count, Stat('iconMoveOther').count, Stat('snapBack').count)
	lines[#lines + 1] = format('Edit Mode: %d layout events, %d layout refreshes, %d saves, %d re-anchors written.',
		Stat('editModeEvent').count, Stat('editLayoutRefresh').count, Stat('emoSave').count, Stat('emoReanchor').count)
	lines[#lines + 1] = 'The full report is in the copy box: press Ctrl+C there to copy it.'
end

local function KindLines(lines)
	lines[#lines + 1] = '-- What CDM did (count, rate, busiest second, in combat, time including nested work) --'
	for _, entry in ipairs(KINDS) do
		local kind = entry[1]
		local stat = kindStats[kind]
		if stat then
			local peak, peakAt = Peak(kind, stat)
			local parts = { format('  %s: %d (%.1f/s, busiest second %d at +%s), %d in combat',
				entry[2], stat.count, Rate(stat.count), peak, Clock(peakAt), stat.combat) }
			if stat.ms > 0 then parts[#parts + 1] = format(', %.1fms (%.2f avg, %.1f max)', stat.ms, stat.ms / stat.count, stat.max) end
			local keys = KeysText(stat.keys)
			if keys ~= '' then parts[#parts + 1] = '. ' .. keys end
			local top = Top(stat.causes, 1)[1]
			if top then parts[#parts + 1] = format('. Mostly from %s (%d)', top.name, top.value) end
			lines[#lines + 1] = concat(parts) .. '.'
		end
	end
end

local function ViewerCauseLines(lines)
	lines[#lines + 1] = '-- What made each viewer lay out again --'
	local markAll = Stat('markAll')
	for _, key in ipairs(CDM.VIEWER_KEYS) do
		local full, layoutOnly, layouts = KeyCount('mark', key), KeyCount('markLayout', key), KeyCount('layout', key)
		if full + layoutOnly + layouts > 0 then
			lines[#lines + 1] = format('  %s: marked dirty %d times (%d full, %d layout only) plus %d mark-everything calls, %d of all marks while hidden. That turned into %d layout passes.',
				VIEWER_TITLES[key], full + layoutOnly, full, layoutOnly, markAll.count, KeyCount('hiddenMark', key), layouts)
			CauseLine(lines, '    Marks came from: ', MergedCauses(MARK_KINDS, key))
			CauseLine(lines, '    Layout passes came from: ', Stat('layout').keyCauses[key])
			CauseLine(lines, '    Passes that changed nothing came from: ', Stat('layoutSame').keyCauses[key])
		end
	end
	CauseLine(lines, '  Mark-everything calls came from: ', markAll.causes)
	CauseLine(lines, '  Restyles came from: ', Stat('restyle').causes)
	CauseLine(lines, '  Icon list invalidations came from: ', Stat('iconCache').causes)
end

local function WasteLines(lines)
	lines[#lines + 1] = '-- Repeats and waste --'
	local layoutRepeat = Stat('layoutRepeat')
	lines[#lines + 1] = format('  Frames with a repeat: %d. Layout passes again in the same frame: %d (%s). Icons restyled again in the same frame: %d.',
		repeatFrameCount, layoutRepeat.count, Or(KeysText(layoutRepeat.keys)), Stat('restyleRepeat').count)
	local sameParts = {}
	for _, key in ipairs(CDM.VIEWER_KEYS) do
		local layouts = KeyCount('layout', key)
		if layouts > 0 then
			local same = KeyCount('layoutSame', key)
			sameParts[#sameParts + 1] = format('%s %d of %d (%.0f%%)', VIEWER_TITLES[key], same, layouts, same / layouts * 100)
		end
	end
	if #sameParts > 0 then lines[#lines + 1] = '  Layout passes that changed nothing: ' .. concat(sameParts, ', ') .. '.' end
	local hiddenMark = Stat('hiddenMark')
	lines[#lines + 1] = format('  Marks while the viewer was hidden: %d (%s).', hiddenMark.count, Or(KeysText(hiddenMark.keys)))
	lines[#lines + 1] = format('  Restyle calls on icons already styled: %d. Glow starts that changed nothing: %d. Glow stops on icons with no glow: %d.',
		Stat('restyleSkip').count, Stat('glowStartSkip').count, Stat('glowStopSkip').count)
	local iconSame = Stat('iconMoveSame')
	lines[#lines + 1] = format('  BluUI re-anchored icons to the same spot %d times (%s) and its anchors %d times.',
		iconSame.count, Or(KeysText(iconSame.keys)), Stat('anchorMoveSame').count)
	local iconOther = Stat('iconMoveOther')
	lines[#lines + 1] = format('  Blizzard or other code moved icons %d times (%s); BluUI snapped %d of them back.',
		iconOther.count, Or(KeysText(iconOther.keys)), Stat('snapBack').count)
	for _, label in ipairs({ FLUSH_LABEL, BUFF_FLUSH_LABEL }) do
		local info = labelInfo[label]
		if info then lines[#lines + 1] = format('  %s ran %d times and made %d visible changes.', label, info.count, info.outputs) end
	end
	lines[#lines + 1] = 'Worst frames for repeats:'
	for _, frame in ipairs(repeatFrames) do
		lines[#lines + 1] = format('  +%s%s: %s. Causes: %s', Clock(frame.at), frame.combat and ' in combat' or '', frame.text, Or(frame.causes))
	end
end

local function PeakLines(lines)
	lines[#lines + 1] = '-- Worst frames by CDM time --'
	for _, frame in ipairs(worstFrames) do
		lines[#lines + 1] = format('  +%s%s: %.1fms. Work: %s. Handlers: %s. Causes: %s',
			Clock(frame.at), frame.combat and ' in combat' or '', frame.ms, Or(frame.work), Or(frame.handlers), Or(frame.causes))
	end
	local peaks = {}
	for kind, stat in pairs(kindStats) do peaks[#peaks + 1] = { name = kind, value = (Peak(kind, stat)) } end
	sort(peaks, ByValue)
	local parts = {}
	for index = 1, min(TOP_PEAKS, #peaks) do
		local kind = peaks[index].name
		local peak, peakAt = Peak(kind, kindStats[kind])
		parts[#parts + 1] = format('%s %d at +%s', KIND_NAMES[kind], peak, Clock(peakAt))
	end
	lines[#lines + 1] = 'Busiest second per kind: ' .. Or(concat(parts, '; '))
end

local function BlizzardLines(lines)
	lines[#lines + 1] = "-- Blizzard's viewers: how often its own methods ran, and how many of those ran during BluUI work --"
	for _, key in ipairs(KEY_ORDER) do
		local byMethod = blizzard[key]
		if byMethod then
			local parts = {}
			for _, method in ipairs(VIEWER_METHODS) do
				local stat = byMethod[method]
				if stat then parts[#parts + 1] = format('%s %d (%d during BluUI work, %d in combat)', method, stat.count, stat.inside, stat.combat) end
			end
			lines[#lines + 1] = format('  %s: %s', VIEWER_TITLES[key], concat(parts, ', '))
			for _, method in ipairs(VIEWER_METHODS) do
				local stat = byMethod[method]
				if stat and stat.inside > 0 then lines[#lines + 1] = format('    %s during BluUI work came from: %s', method, CountsText(stat.from, 3)) end
			end
		end
	end
	lines[#lines + 1] = "-- BluUI hooks on Blizzard methods (time is BluUI's hook only) --"
	local hooks = {}
	for label, info in pairs(labelInfo) do
		if info and info.hook then hooks[#hooks + 1] = { name = label, value = info.count } end
	end
	sort(hooks, ByValue)
	for index = 1, min(TOP_HOOKS, #hooks) do
		local label = hooks[index].name
		local info = labelInfo[label]
		lines[#lines + 1] = format('  %s: %d (%.1f/s), %.1fms. Led to: %s. From: %s',
			Pretty(label), info.count, Rate(info.count), info.ms, Or(CountsText(info.work, 4, KindName)), Or(CountsText(info.from, 3)))
	end
end

local function HandlerLines(lines)
	lines[#lines + 1] = '-- BluUI CDM handlers by time (includes nested work) --'
	local handlers = {}
	for label, info in pairs(labelInfo) do
		if info and not info.hook then handlers[#handlers + 1] = { name = label, value = info.ms } end
	end
	sort(handlers, ByValue)
	for index = 1, min(TOP_HANDLERS, #handlers) do
		local label = handlers[index].name
		local info = labelInfo[label]
		lines[#lines + 1] = format('  %s: %d runs (%.1f/s), %.1fms, %.2f avg, %.1f max, %d in combat, %d visible changes. Led to: %s. From: %s',
			Pretty(label), info.count, Rate(info.count), info.ms, info.ms / max(info.count, 1), info.max, info.combat, info.outputs,
			Or(CountsText(info.work, 3, KindName)), Or(CountsText(info.from, 2)))
	end
end

local function Build()
	local lines = {}
	SummaryLines(lines)
	local preview = #lines
	KindLines(lines)
	ViewerCauseLines(lines)
	WasteLines(lines)
	PeakLines(lines)
	BlizzardLines(lines)
	HandlerLines(lines)
	lines[#lines + 1] = NOT_MEASURED
	return lines, preview
end

local function ResetSession()
	for _, map in ipairs(SESSION_TABLES) do wipe(map) end
	startedAt, stoppedAt = GetTime(), nil
	frameAt, frameMs, frameLayoutRepeats, frameRestyleRepeats = nil, 0, 0, 0
	spanTop, driverTop, markDepth, currentSecond = 0, 0, 0, 0
	totalMs, combatMs, busyFrames, repeatFrameCount = 0, 0, 0, 0
	inCombat, combatSince, combatTime = InCombatLockdown(), startedAt, 0
	specAtStart, zoneAtStart, clockAtStart = SpecName(), GetRealZoneText(), date('%H:%M')
end

function CDMProfiler.IsRunning()
	return running
end

function CDMProfiler.Start()
	if not CDM.state.initialized then
		BUI.Print('The Cooldown Manager module is off, so there is nothing to profile.')
		return false
	end
	if BUI.LaunchTrace.IsTracing() then
		BUI.Print('A launch trace is still recording. Try again in a few seconds.')
		return false
	end
	ResetSession()
	running = true
	HookFrames()
	InstallSwaps()
	Profiler.AddTracer(Trace)
	BUI.Events:Register('PLAYER_REGEN_DISABLED', EVENT_KEY, OnCombatStart)
	BUI.Events:Register('PLAYER_REGEN_ENABLED', EVENT_KEY, OnCombatEnd)
	return true
end

function CDMProfiler.Stop()
	if frameAt then CloseFrame() end
	CloseSecond()
	OnCombatEnd()
	running = false
	stoppedAt = GetTime()
	frameAt = nil
	Profiler.RemoveTracer(Trace)
	Unswap()
	BUI.Events:Unregister('PLAYER_REGEN_DISABLED', EVENT_KEY)
	BUI.Events:Unregister('PLAYER_REGEN_ENABLED', EVENT_KEY)
end

function CDMProfiler.Reset()
	ResetSession()
	if not running then startedAt = nil end
end

function CDMProfiler.Report()
	if startedAt then return Build() end
end
