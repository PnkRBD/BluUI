local _, BUI = ...

local CDM = BUI.CDM
local Pixel = BUI.Pixel

local C_Spell = C_Spell
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local pairs, wipe = pairs, wipe

local Tools = BUI.Tools
local IsSecret = BUI.Tools.IsSecretValue
local IsSpellOverlayed = C_SpellActivationOverlay.IsSpellOverlayed
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

CDM.PROC_MSG_POSITIONS = {
	{ value = 'above',  text = 'Above Icon' },
	{ value = 'top',    text = 'Top' },
	{ value = 'center', text = 'Center' },
	{ value = 'bottom', text = 'Bottom' },
	{ value = 'below',  text = 'Below Icon' },
}

local ANCHOR_POINTS = {
	above  = { 'BOTTOM', 'TOP', 2 },
	top    = { 'TOP', 'TOP', -1 },
	center = { 'CENTER', 'CENTER', 0 },
	bottom = { 'BOTTOM', 'BOTTOM', 1 },
	below  = { 'TOP', 'BOTTOM', -2 },
}

local function GlowDB()
	return BUI.GetDB().cdm.glow
end

local function GetEntry(spellID)
	local perSpell = GlowDB().perSpell
	return perSpell and perSpell[spellID] or nil
end

local function SpellName(spellID)
	local info = C_Spell.GetSpellInfo(spellID)
	return info and info.name or ('Spell ' .. spellID)
end

local function MessageText(spellID, entry)
	local text = entry and entry.msgText
	if text and text ~= '' then return text end
	return SpellName(spellID) .. ' Proc!'
end

local function IconTexture(icon)
	local region = icon.Icon
	if not region then return nil end
	if region.GetTexture then return region:GetTexture() end
	local nested = region.Icon
	if nested and nested.GetTexture then return nested:GetTexture() end
	return nil
end

local function OverlayAnchor(icon)
	if icon.Bar then return icon end
	return icon.Icon or icon
end

local watcher = CreateFrame('Frame')
local activeEntries = {}
local activeIcons = {}
local appearManaged = {}
local overlays = setmetatable({}, { __mode = 'k' })

local function GetOverlay(icon)
	local overlay = overlays[icon]
	if overlay then return overlay end
	local frame = CreateFrame('Frame', nil, icon)
	frame:SetAllPoints(OverlayAnchor(icon))
	frame:SetFrameLevel((icon:GetFrameLevel() or 0) * 2 + 40)
	local text = frame:CreateFontString(nil, 'OVERLAY', nil, 7)
	text:SetJustifyH('CENTER')
	overlay = { frame = frame, text = text }
	overlays[icon] = overlay
	return overlay
end

function CDM.GetProcMsgAnchor(key)
	local anchor = ANCHOR_POINTS[key or 'center'] or ANCHOR_POINTS.center
	return anchor[1], anchor[2], anchor[3]
end

local function ApplyOverlay(icon, key, entry)
	local overlay = GetOverlay(icon)
	local font = BUI.GetGlobalFont()
	local color = entry.msgColor or entry.color or GlowDB().color
	if overlay.entry == entry and overlay.font == font and overlay.color == color and overlay.frame:IsShown() then return end
	overlay.entry, overlay.font, overlay.color = entry, font, color
	local anchor = ANCHOR_POINTS[entry.msgAnchor or 'center'] or ANCHOR_POINTS.center
	local target = OverlayAnchor(icon)
	Pixel.ApplyFont(overlay.text, entry.msgSize or 14, font, 'OUTLINE')
	overlay.text:ClearAllPoints()
	overlay.text:SetPoint(anchor[1], target, anchor[2], Pixel.Scale(entry.msgOffsetX or 0), Pixel.Scale(anchor[3] + (entry.msgOffsetY or 0)))
	overlay.text:SetTextColor(color[1], color[2], color[3], 1)
	overlay.text:SetText(MessageText(key, entry))
	overlay.frame:Show()
end

local function HideOverlayFor(key)
	local icon = activeIcons[key]
	if not icon then return end
	activeIcons[key] = nil
	local overlay = overlays[icon]
	if overlay then overlay.frame:Hide() end
end

local function RefreshActiveOverlays()
	local perSpell = GlowDB().perSpell
	for key, icon in pairs(activeIcons) do
		local entry = perSpell and perSpell[key]
		if appearManaged[key] then
			if not entry or not entry.msg then HideOverlayFor(key) end
		elseif not entry or not entry.msg then
			HideOverlayFor(key)
		else
			local fresh = CDM.FindIconForSpell(key) or icon
			if fresh ~= icon then
				local overlay = overlays[icon]
				if overlay then overlay.frame:Hide() end
				activeIcons[key] = fresh
			end
			ApplyOverlay(fresh, key, entry)
		end
	end
end

local function RemoveActive(spellID)
	activeEntries[spellID] = nil
	if not appearManaged[spellID] then HideOverlayFor(spellID) end
end

local function ResolveEntry(spellID)
	local perSpell = GlowDB().perSpell
	if not perSpell then return nil end
	local entry = perSpell[spellID]
	if entry then return entry, spellID end
	local base = C_Spell.GetBaseSpell(spellID)
	if base and base ~= spellID then
		entry = perSpell[base]
		if entry then return entry, base end
	end
end

watcher:SetScript('OnEvent', function(_, event, spellID)
	if not spellID or IsSecret(spellID) then return end
	if event == 'SPELL_ACTIVATION_OVERLAY_GLOW_HIDE' then
		RemoveActive(spellID)
		local base = C_Spell.GetBaseSpell(spellID)
		if base and base ~= spellID then RemoveActive(base) end
		return
	end
	local entry, key = ResolveEntry(spellID)
	if not entry or activeEntries[key] then return end
	if entry.trigger == 'appear' then return end
	activeEntries[key] = true
	if entry.msg and not appearManaged[key] then
		local icon = CDM.FindIconForSpell(key)
		if icon then
			activeIcons[key] = icon
			ApplyOverlay(icon, key, entry)
		end
	end
	if entry.tts then
		BUI.TTS.Speak(MessageText(key, entry))
	end
	if entry.sound then
		PlaySound(entry.sound, 'Master')
	end
end)

local appearWatchEnabled = false
local appearActive = {}
local appearCooldownActive = {}
local appearStamps = {}
local appearHooked

local appearTimers = {}

local function IsAppearIconLive(key, icon)
	local set = appearActive[key]
	if set and set[icon] then return true end
	return appearCooldownActive[key] == icon
end

local function CancelAppearTimer(icon)
	local timer = appearTimers[icon]
	if timer then
		timer:Cancel()
		appearTimers[icon] = nil
	end
end

local appearGlowConfig = { enabled = true }

local function AppearGlowNow(icon, entry)
	appearGlowConfig.style = entry.style
	appearGlowConfig.color = entry.color
	appearGlowConfig.speed = entry.speed
	appearGlowConfig.lines = entry.lines
	appearGlowConfig.thickness = entry.thickness
	CDM.StartProcGlow(icon, appearGlowConfig)
end

local function WantsSteadyGlow(entry)
	local mode = entry.glowMode or 'always'
	return mode == 'always' or not entry.duration
end

local function StartAppearGlow(key, icon, entry)
	CancelAppearTimer(icon)
	local mode = entry.glowMode or 'always'
	local duration = entry.duration
	if mode == 'always' or not duration then
		AppearGlowNow(icon, entry)
		return
	end
	local threshold = entry.glowThreshold or 5
	local untilThreshold = duration - threshold
	if mode == 'below' then
		if untilThreshold <= 0 then
			AppearGlowNow(icon, entry)
		else
			appearTimers[icon] = C_Timer.NewTimer(untilThreshold, function()
				appearTimers[icon] = nil
				if IsAppearIconLive(key, icon) and icon:IsShown() then
					AppearGlowNow(icon, entry)
				end
			end)
		end
	elseif mode == 'above' then
		AppearGlowNow(icon, entry)
		if untilThreshold > 0 then
			appearTimers[icon] = C_Timer.NewTimer(untilThreshold, function()
				appearTimers[icon] = nil
				if IsAppearIconLive(key, icon) then
					CDM.StopProcGlow(icon)
				end
			end)
		end
	end
end

local function StopAppearAlert(key, icons)
	appearManaged[key] = nil
	appearStamps[key] = nil
	if icons then
		for icon in pairs(icons) do
			CancelAppearTimer(icon)
			CDM.StopProcGlow(icon)
		end
	end
	local cooldownIcon = appearCooldownActive[key]
	if cooldownIcon then
		appearCooldownActive[key] = nil
		CancelAppearTimer(cooldownIcon)
		CDM.StopProcGlow(cooldownIcon)
	end
	HideOverlayFor(key)
	if activeEntries[key] then
		if type(key) == 'number' and not IsSpellOverlayed(key) then
			activeEntries[key] = nil
		else
			local perSpell = GlowDB().perSpell
			local entry = perSpell and perSpell[key]
			if entry and entry.msg then
				local icon = CDM.FindIconForSpell(key)
				if icon then
					activeIcons[key] = icon
					ApplyOverlay(icon, key, entry)
				end
			end
		end
	end
end

local function IsAppearTrigger(entry)
	return entry.trigger == 'appear' or entry.trigger == 'both'
end

local function IsOwnBuffTrigger(entry)
	return IsAppearTrigger(entry) and not entry.watchSpell
end

local scanPresent, scanStamps = {}, {}
local scanCarried, scanCarriedKeys, scanBridgedKeys = {}, {}, {}
local scratchPool, scratchPoolCount = {}, 0

local function AcquireScratch()
	if scratchPoolCount > 0 then
		local scratch = scratchPool[scratchPoolCount]
		scratchPoolCount = scratchPoolCount - 1
		return scratch
	end
	return {}
end

local function ResetScanScratch()
	for key, set in pairs(scanPresent) do
		wipe(set)
		scratchPoolCount = scratchPoolCount + 1
		scratchPool[scratchPoolCount] = set
		scanPresent[key] = nil
	end
	for key, stamps in pairs(scanStamps) do
		wipe(stamps)
		scratchPoolCount = scratchPoolCount + 1
		scratchPool[scratchPoolCount] = stamps
		scanStamps[key] = nil
	end
	wipe(scanCarried)
	wipe(scanCarriedKeys)
	wipe(scanBridgedKeys)
end

local candidateEntries, candidateKeys, candidateRanks = {}, {}, {}
local candidateCount = 0

local function AddCandidate(perSpell, id)
	if type(id) ~= 'number' or IsSecret(id) then return end
	local entry, key = perSpell[id], id
	if not entry then
		local base = C_Spell.GetBaseSpell(id)
		if base and base ~= id and perSpell[base] then
			entry, key = perSpell[base], base
		end
	end
	if not entry then return end
	for candidateIndex = 1, candidateCount do
		if candidateEntries[candidateIndex] == entry then return end
	end
	candidateCount = candidateCount + 1
	candidateEntries[candidateCount] = entry
	candidateKeys[candidateCount] = key
end

local mergedEntries = setmetatable({}, { __mode = 'k' })

local function MergedEntry(primaryEntry, appearEntry)
	local byAppear = mergedEntries[primaryEntry]
	if not byAppear then
		byAppear = setmetatable({}, { __mode = 'k' })
		mergedEntries[primaryEntry] = byAppear
	end
	local merged = byAppear[appearEntry]
	if merged then return merged end
	merged = {
		trigger = appearEntry.trigger,
		glowTarget = primaryEntry.glowTarget or appearEntry.glowTarget,
		glowTargetSpell = primaryEntry.glowTargetSpell or appearEntry.glowTargetSpell,
		glowMode = primaryEntry.glowMode or appearEntry.glowMode,
		glowThreshold = primaryEntry.glowThreshold or appearEntry.glowThreshold,
		duration = primaryEntry.duration or appearEntry.duration,
		style = primaryEntry.style or appearEntry.style,
		color = primaryEntry.color or appearEntry.color,
		speed = primaryEntry.speed or appearEntry.speed,
		lines = primaryEntry.lines or appearEntry.lines,
		thickness = primaryEntry.thickness or appearEntry.thickness,
		msg = appearEntry.msg,
		msgText = appearEntry.msgText,
		msgColor = appearEntry.msgColor,
		msgAnchor = appearEntry.msgAnchor,
		msgSize = appearEntry.msgSize,
		msgOffsetX = appearEntry.msgOffsetX,
		msgOffsetY = appearEntry.msgOffsetY,
		tts = appearEntry.tts,
		sound = appearEntry.sound,
	}
	byAppear[appearEntry] = merged
	return merged
end

local function ResolveEntryForIcon(icon, perSpell)
	candidateCount = 0
	local cooldownInfo = icon.cooldownInfo
	if cooldownInfo and not IsSecret(cooldownInfo.overrideSpellID) then
		AddCandidate(perSpell, cooldownInfo.overrideSpellID)
	end
	AddCandidate(perSpell, CDM.GetStableSpellID(icon))
	local linked = cooldownInfo and cooldownInfo.linkedSpellIDs
	if linked then
		for _, linkedSpellID in ipairs(linked) do
			AddCandidate(perSpell, linkedSpellID)
		end
	end

	if candidateCount == 0 then return end
	if candidateCount > 1 then
		local texture = IconTexture(icon)
		local shownTexture = (texture and not IsSecret(texture)) and texture or nil
		for candidateIndex = 1, candidateCount do
			local key = candidateKeys[candidateIndex]
			local castable = C_SpellBook.IsSpellKnown(key)
			local texMatch = shownTexture and C_Spell.GetSpellTexture(key) == shownTexture
			if texMatch and not castable then candidateRanks[candidateIndex] = 1
			elseif not castable then candidateRanks[candidateIndex] = 2
			elseif texMatch then candidateRanks[candidateIndex] = 3
			else candidateRanks[candidateIndex] = 4 end
		end
		for candidateIndex = 2, candidateCount do
			local entry, key, rank = candidateEntries[candidateIndex], candidateKeys[candidateIndex], candidateRanks[candidateIndex]
			local compareIndex = candidateIndex - 1
			while compareIndex >= 1 and candidateRanks[compareIndex] > rank do
				candidateEntries[compareIndex + 1] = candidateEntries[compareIndex]
				candidateKeys[compareIndex + 1] = candidateKeys[compareIndex]
				candidateRanks[compareIndex + 1] = candidateRanks[compareIndex]
				compareIndex = compareIndex - 1
			end
			candidateEntries[compareIndex + 1] = entry
			candidateKeys[compareIndex + 1] = key
			candidateRanks[compareIndex + 1] = rank
		end
	end

	local primaryEntry = candidateEntries[1]
	if IsOwnBuffTrigger(primaryEntry) then
		return primaryEntry, candidateKeys[1]
	end
	local appearEntry, appearKey
	for candidateIndex = 2, candidateCount do
		if IsOwnBuffTrigger(candidateEntries[candidateIndex]) then
			appearEntry, appearKey = candidateEntries[candidateIndex], candidateKeys[candidateIndex]
			break
		end
	end
	if not appearEntry then return end
	return MergedEntry(primaryEntry, appearEntry), appearKey
end

local function UpdateAppearOverlay(key, entry, icons)
	if not entry.msg then return end
	local current = activeIcons[key]
	if current and icons[current] then
		ApplyOverlay(current, key, entry)
		return
	end
	if current then HideOverlayFor(key) end
	local icon = next(icons)
	if icon then
		activeIcons[key] = icon
		ApplyOverlay(icon, key, entry)
	end
end

local function AuraStamp(id)
	if type(id) ~= 'number' or IsSecret(id) then return nil end
	local aura = GetPlayerAuraBySpellID(id)
	if not aura then return nil end
	local expiration = aura.expirationTime
	if expiration ~= nil and not IsSecret(expiration) then return expiration end
	local instanceID = aura.auraInstanceID
	if instanceID ~= nil and not IsSecret(instanceID) then return instanceID end
	return true
end

local function IconBuffActive(icon)
	if Tools.ShouldAurasBeSecret() or Tools.AuraQueriesBlocked() then
		local instanceID = icon.auraInstanceID
		if not instanceID then return nil end
		if IsSecret(instanceID) then return true end
		return instanceID
	end
	local cooldownInfo = icon.cooldownInfo
	if cooldownInfo then
		local stamp = AuraStamp(cooldownInfo.overrideSpellID) or AuraStamp(cooldownInfo.spellID)
		if stamp then return stamp end
		if cooldownInfo.linkedSpellIDs then
			for _, linkedSpellID in ipairs(cooldownInfo.linkedSpellIDs) do
				stamp = AuraStamp(linkedSpellID)
				if stamp then return stamp end
			end
		end
		return nil
	end
	return AuraStamp(CDM.GetStableSpellID(icon))
end

local function CarryIcon(id, icon)
	if type(id) == 'number' and not IsSecret(id) and not scanCarried[id] then
		scanCarried[id] = icon
	end
end

local watchedBy, watchAny = {}, false

local function AddPresent(key, icon, entry, stamp)
	local set = scanPresent[key]
	if not set then
		set = AcquireScratch()
		scanPresent[key] = set
		scanStamps[key] = AcquireScratch()
	end
	set[icon] = entry
	scanStamps[key][icon] = stamp
end

local function CollectWatchers(icon, id, stamp, stampChecked)
	if type(id) ~= 'number' or IsSecret(id) then return stamp, stampChecked end
	local watchers = watchedBy[id]
	if not watchers then return stamp, stampChecked end
	if not stampChecked then
		stamp, stampChecked = IconBuffActive(icon), true
	end
	if stamp then
		for key, entry in pairs(watchers) do
			if IsAppearTrigger(entry) then AddPresent(key, icon, entry, stamp) end
		end
	end
	return stamp, stampChecked
end

local function CollectBuffSource(icon, perSpell)
	local entry, key = ResolveEntryForIcon(icon, perSpell)
	local cooldownInfo = icon.cooldownInfo
	local stableID = CDM.GetStableSpellID(icon)
	local overrideID = cooldownInfo and cooldownInfo.overrideSpellID
	local linked = cooldownInfo and cooldownInfo.linkedSpellIDs
	CarryIcon(stableID, icon)
	if cooldownInfo then
		CarryIcon(overrideID, icon)
		if linked then
			for _, linkedSpellID in ipairs(linked) do CarryIcon(linkedSpellID, icon) end
		end
	end
	local stamp, stampChecked = nil, false
	if entry then
		scanCarriedKeys[key] = true
		if IsAppearTrigger(entry) then
			stamp, stampChecked = IconBuffActive(icon), true
			if stamp then AddPresent(key, icon, entry, stamp) end
		end
	end
	if not watchAny then return end
	stamp, stampChecked = CollectWatchers(icon, stableID, stamp, stampChecked)
	stamp, stampChecked = CollectWatchers(icon, overrideID, stamp, stampChecked)
	if linked then
		for _, linkedSpellID in ipairs(linked) do
			stamp, stampChecked = CollectWatchers(icon, linkedSpellID, stamp, stampChecked)
		end
	end
end

local function BarSourcePool()
	local viewer = _G.BuffBarCooldownViewer
	local pool = viewer and viewer.itemFramePool
	if pool and pool.EnumerateActive then return pool end
	return nil
end

local HookBarViewer

local function ScanAppearIcons()
	if not appearWatchEnabled then return end
	HookBarViewer()
	ResetScanScratch()
	local perSpell = GlowDB().perSpell
	local present = scanPresent
	local presentStamps = scanStamps
	local carried, carriedKeys, bridgedKeys = scanCarried, scanCarriedKeys, scanBridgedKeys
	if perSpell then
		local list, count = CDM.GetTrackedIcons('buffs')
		if list and count then
			for iconIndex = 1, count do
				local icon = list[iconIndex]
				local frameData = icon and CDM.FrameData[icon]
				if icon and not (frameData and frameData.customIcon) then
					CollectBuffSource(icon, perSpell)
				end
			end
		end
		local barPool = BarSourcePool()
		if barPool then
			for bar in barPool:EnumerateActive() do
				if bar.cooldownInfo then CollectBuffSource(bar, perSpell) end
			end
		end
	end
	if perSpell then
		for key, entry in pairs(perSpell) do
			if entry.glowTargetSpell and not entry.watchSpell and not carriedKeys[key] and not present[key] then
				local icon = carried[entry.glowTargetSpell]
				if icon then bridgedKeys[key] = true end
				local stamp = icon and IconBuffActive(icon)
				if stamp then
					local set = AcquireScratch()
					set[icon] = entry
					present[key] = set
					local stamps = AcquireScratch()
					stamps[icon] = stamp
					presentStamps[key] = stamps
				end
			end
		end
	end
	for key, icons in pairs(present) do
		local groupEntry = perSpell[key]
		local active = appearActive[key]
		local hadAny = active and next(active) and true or false
		if not active then
			active = {}
			appearActive[key] = active
		end
		local stamps = presentStamps[key]
		local prevStamps = appearStamps[key]
		if not prevStamps then
			prevStamps = {}
			appearStamps[key] = prevStamps
		end
		local sampleIcon, sampleEntry = next(icons)
		local target = (sampleEntry and sampleEntry.glowTarget)
			or (groupEntry and groupEntry.glowTarget) or 'buff'
		local wantCooldownGlow = target == 'cooldown' or target == 'both'
		local targetSpell = (sampleEntry and sampleEntry.glowTargetSpell)
			or (groupEntry and groupEntry.glowTargetSpell) or key
		if bridgedKeys[key] then targetSpell = key end
		local cooldownIcon = wantCooldownGlow and CDM.FindIconForSpell(targetSpell, true) or nil
		local glowBuff = target ~= 'cooldown' or not cooldownIcon or bridgedKeys[key]
		for icon, iconEntry in pairs(icons) do
			local stamp = stamps and stamps[icon]
			if not active[icon] then
				active[icon] = true
				if glowBuff then StartAppearGlow(key, icon, iconEntry) end
			elseif glowBuff and stamp ~= prevStamps[icon] then
				StartAppearGlow(key, icon, iconEntry)
			elseif glowBuff and WantsSteadyGlow(iconEntry) then
				AppearGlowNow(icon, iconEntry)
			end
			prevStamps[icon] = stamp
		end
		for icon in pairs(active) do
			if not icons[icon] then
				active[icon] = nil
				prevStamps[icon] = nil
				CancelAppearTimer(icon)
				CDM.StopProcGlow(icon)
			end
		end
		local currentCooldownIcon = appearCooldownActive[key]
		local sampleStamp = stamps and sampleIcon and stamps[sampleIcon]
		if currentCooldownIcon ~= cooldownIcon then
			if currentCooldownIcon then
				CancelAppearTimer(currentCooldownIcon)
				CDM.StopProcGlow(currentCooldownIcon)
			end
			appearCooldownActive[key] = cooldownIcon
			if cooldownIcon then
				StartAppearGlow(key, cooldownIcon, sampleEntry or groupEntry)
			end
		elseif cooldownIcon and sampleStamp ~= prevStamps._cd then
			StartAppearGlow(key, cooldownIcon, sampleEntry or groupEntry)
		elseif cooldownIcon and WantsSteadyGlow(sampleEntry or groupEntry) then
			AppearGlowNow(cooldownIcon, sampleEntry or groupEntry)
		end
		prevStamps._cd = sampleStamp
		appearManaged[key] = true
		if groupEntry then
			if target == 'cooldown' and cooldownIcon then
				if groupEntry.msg then
					local currentIcon = activeIcons[key]
					if currentIcon and currentIcon ~= cooldownIcon then HideOverlayFor(key) end
					activeIcons[key] = cooldownIcon
					ApplyOverlay(cooldownIcon, key, groupEntry)
				end
			else
				UpdateAppearOverlay(key, groupEntry, icons)
			end
			if not hadAny then
				if groupEntry.tts then BUI.TTS.Speak(MessageText(key, groupEntry)) end
				if groupEntry.sound then PlaySound(groupEntry.sound, 'Master') end
			end
		end
	end
	for key, active in pairs(appearActive) do
		if not present[key] then
			appearActive[key] = nil
			StopAppearAlert(key, active)
		end
	end
end

local QueueAppearScan = BUI.Dispatcher.New(ScanAppearIcons, 'CDM.AppearScan')

local barViewerHooked = false
HookBarViewer = function()
	if barViewerHooked then return end
	local viewer = _G.BuffBarCooldownViewer
	if not viewer then return end
	barViewerHooked = true
	local function Wake()
		if appearWatchEnabled then QueueAppearScan() end
	end
	if viewer.OnAcquireItemFrame then hooksecurefunc(viewer, 'OnAcquireItemFrame', Wake) end
	if viewer.RefreshLayout then hooksecurefunc(viewer, 'RefreshLayout', Wake) end
end

local auraWatcher = CreateFrame('Frame')
auraWatcher:SetScript('OnEvent', function()
	if appearWatchEnabled then QueueAppearScan() end
end)

local trackHooked

function CDM.RefreshProcMsgWatcher()
	local perSpell = GlowDB().perSpell
	local procWant, appearWant = false, false
	wipe(watchedBy)
	watchAny = false
	if perSpell then
		for key, entry in pairs(perSpell) do
			local trigger = entry.trigger or 'proc'
			if trigger ~= 'proc' or entry.glowTargetSpell then
				appearWant = true
			end
			if trigger ~= 'appear' and (entry.msg or entry.tts or entry.sound) then
				procWant = true
			end
			local watchSpell = entry.watchSpell
			if watchSpell and trigger ~= 'proc' then
				local watchers = watchedBy[watchSpell]
				if not watchers then
					watchers = {}
					watchedBy[watchSpell] = watchers
				end
				watchers[key] = entry
				watchAny = true
			end
		end
	end

	if procWant then
		if not trackHooked then
			trackHooked = true
			CDM.OnTrackedIconsChanged(function()
				if next(activeIcons) then RefreshActiveOverlays() end
			end)
		end
		watcher:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
		watcher:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_HIDE')
	else
		watcher:UnregisterAllEvents()
		for key in pairs(activeEntries) do
			if not appearManaged[key] then HideOverlayFor(key) end
		end
		wipe(activeEntries)
	end

	appearWatchEnabled = appearWant
	if appearWant then
		HookBarViewer()
		if not appearHooked then
			appearHooked = true
			CDM.OnTrackedIconsChanged(function()
				if appearWatchEnabled then QueueAppearScan() end
			end)
		end
		auraWatcher:RegisterUnitEvent('UNIT_AURA', 'player')
		auraWatcher:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')
		QueueAppearScan()
	else
		auraWatcher:UnregisterAllEvents()
		for key, icons in pairs(appearActive) do
			appearActive[key] = nil
			StopAppearAlert(key, icons)
		end
	end
end

local BUFF_SOURCES = {
	{ viewer = 'buffs', label = 'Buff Icons', category = Enum.CooldownViewerCategory.TrackedBuff },
	{ viewer = 'bars', label = 'Buff Bars', category = Enum.CooldownViewerCategory.TrackedBar },
}

local function SafeEquals(value, spellID)
	return value ~= nil and not IsSecret(value) and value == spellID
end

local function CooldownInfoMatch(info, spellID)
	if SafeEquals(info.spellID, spellID) or SafeEquals(info.overrideSpellID, spellID) then return true, false end
	local linked = info.linkedSpellIDs
	if linked then
		for linkedIndex = 1, #linked do
			if SafeEquals(linked[linkedIndex], spellID) then return true, true end
		end
	end
	return false, false
end

function CDM.FindTrackedBuffSource(spellID)
	if type(spellID) ~= 'number' then return nil end
	local GetCategorySet = C_CooldownViewer.GetCooldownViewerCategorySet
	local GetCooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo
	local hiddenHit
	for sourceIndex = 1, #BUFF_SOURCES do
		local source = BUFF_SOURCES[sourceIndex]
		local allIDs = GetCategorySet(source.category, true)
		if allIDs then
			local shown = {}
			local shownIDs = GetCategorySet(source.category, false)
			if shownIDs then
				for idIndex = 1, #shownIDs do shown[shownIDs[idIndex]] = true end
			end
			for idIndex = 1, #allIDs do
				local cooldownID = allIDs[idIndex]
				local info = GetCooldownInfo(cooldownID)
				local matched, viaLinked = false, false
				if info then matched, viaLinked = CooldownInfoMatch(info, spellID) end
				if matched then
					local entrySpellID = info.spellID
					local hit = {
						viewer = source.viewer,
						label = source.label,
						cooldownID = cooldownID,
						displayed = shown[cooldownID] == true,
						viaSpellID = (viaLinked and type(entrySpellID) == 'number' and not IsSecret(entrySpellID)) and entrySpellID or nil,
					}
					if hit.displayed then return hit end
					hiddenHit = hiddenHit or hit
				end
			end
		end
	end
	return hiddenHit
end

function CDM.GetProcConfig(spellID)
	return GetEntry(spellID)
end

function CDM.GetProcMessageText(spellID)
	return MessageText(spellID, GetEntry(spellID))
end

function CDM.SetProcConfig(spellID, config)
	local glow = GlowDB()
	if config and (config.trigger or config.watchSpell or config.glowTarget or config.glowTargetSpell or config.glowMode or config.duration or config.color or config.style or config.speed or config.lines or config.thickness or config.msg or config.msgText or config.msgColor or config.tts or config.sound) then
		local perSpell = glow.perSpell
		if not perSpell then
			perSpell = {}
			glow.perSpell = perSpell
		end
		perSpell[spellID] = {
			trigger = config.trigger,
			watchSpell = config.watchSpell,
			glowTarget = config.glowTarget,
			glowTargetSpell = config.glowTargetSpell,
			glowMode = config.glowMode,
			glowThreshold = config.glowThreshold,
			duration = config.duration,
			color = config.color,
			style = config.style,
			speed = config.speed,
			lines = config.lines,
			thickness = config.thickness,
			msg = config.msg,
			msgText = config.msgText,
			msgColor = config.msgColor,
			msgAnchor = config.msgAnchor,
			msgSize = config.msgSize,
			msgOffsetX = config.msgOffsetX,
			msgOffsetY = config.msgOffsetY,
			tts = config.tts,
			sound = config.sound,
		}
	elseif glow.perSpell then
		glow.perSpell[spellID] = nil
		if not next(glow.perSpell) then glow.perSpell = nil end
	end
	CDM.RefreshActiveGlows()
	CDM.RefreshProcMsgWatcher()
	RefreshActiveOverlays()
end
