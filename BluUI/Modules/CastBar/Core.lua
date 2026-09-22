local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('CastBar.Core')
local Pixel = BUI.Pixel

local CastBar = BUI.CastBar

local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local UnitClass = UnitClass
local UnitExists = UnitExists
local EvaluateColorValueFromBoolean = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean

local function KickReadyState(spell)
	local cooldown = spell and C_Spell.GetSpellCooldownDuration(spell)
	if not cooldown or not cooldown.IsZero then return true end
	return cooldown:IsZero()
end

local CLASS_INTERRUPTS = {
	DEATHKNIGHT = {47528}, DEMONHUNTER = {183752},
	DRUID = {106839, 78675, 38675}, EVOKER = {351338},
	HUNTER = {147362, 187707}, MAGE = {2139}, MONK = {116705},
	PALADIN = {96231, 31935}, PRIEST = {15487}, ROGUE = {1766},
	SHAMAN = {57994}, WARLOCK = {89766, 119910, 132409, 1276467, 19647, 115781, 119909},
	WARRIOR = {6552},
}
local PET_BANK = Enum.SpellBookSpellBank.Pet
local candidateInterrupts = CLASS_INTERRUPTS[select(2, UnitClass('player'))] or {}
local knownInterrupts = {}

local function IsInterruptUsable(spellID)
	return C_SpellBook.IsSpellKnownOrInSpellBook(spellID)
		or C_SpellBook.IsSpellKnownOrInSpellBook(spellID, PET_BANK)
end

do
	local function RefreshKnownInterrupts()
		wipe(knownInterrupts)
		for interruptIndex = 1, #candidateInterrupts do
			local spellID = candidateInterrupts[interruptIndex]
			if IsInterruptUsable(spellID) then
				knownInterrupts[#knownInterrupts + 1] = spellID
			end
		end
	end
	for _, event in ipairs({ 'PLAYER_LOGIN', 'SPELLS_CHANGED', 'UNIT_PET', 'PET_BAR_UPDATE' }) do
		BUI.Events:Register(event, 'CB.InterruptCache', RefreshKnownInterrupts)
	end
end

local interruptReadyAt = 0
BUI.Events:RegisterUnit('UNIT_SPELLCAST_SUCCEEDED', { 'player', 'pet' }, 'CB.InterruptClock', function(_, unit, _, spellID)
	if unit ~= 'player' and unit ~= 'pet' then return end
	for interruptIndex = 1, #candidateInterrupts do
		if candidateInterrupts[interruptIndex] == spellID then
			local baseMs = GetSpellBaseCooldown(spellID)
			if baseMs and baseMs > 0 then interruptReadyAt = GetTime() + baseMs / 1000 end
			return
		end
	end
end)

local function EnsureOverlay(castbar, key, drawLayer, subLevel)
	if castbar[key] then return castbar[key] end
	local overlay = castbar:CreateTexture(nil, drawLayer, nil, subLevel)
	overlay:SetAllPoints(castbar:GetStatusBarTexture())
	castbar[key] = overlay
	return overlay
end

local function SyncOverlayAnchors(castbar)
	local barTexture = castbar:GetStatusBarTexture()
	if not barTexture then return end
	if castbar._readyOverlays then
		for _, overlay in ipairs(castbar._readyOverlays) do overlay:SetAllPoints(barTexture) end
	end
	if castbar._niOverlay then castbar._niOverlay:SetAllPoints(barTexture) end
end

local function UnsnapFill(statusBar)
	local fillTexture = statusBar:GetStatusBarTexture()
	if fillTexture and fillTexture.SetSnapToPixelGrid then
		fillTexture:SetSnapToPixelGrid(false)
		fillTexture:SetTexelSnappingBias(0)
	end
end

local function EnsureInterruptTick(castbar)
	if castbar._intBar then return end

	local positioner = CreateFrame('StatusBar', nil, castbar)
	positioner:SetFrameLevel(castbar:GetFrameLevel() + 2)
	positioner:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8')
	positioner:GetStatusBarTexture():SetAlpha(0)
	positioner:Hide()
	castbar._intPos = positioner

	local interruptBar = CreateFrame('StatusBar', nil, castbar)
	interruptBar:SetFrameLevel(castbar:GetFrameLevel() + 2)
	interruptBar:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8')
	interruptBar:GetStatusBarTexture():SetAlpha(0)
	interruptBar:Hide()
	castbar._intBar = interruptBar

	local zone = castbar:CreateTexture(nil, 'ARTWORK', nil, 5)
	zone:SetTexture('Interface\\Buttons\\WHITE8X8')
	zone:Hide()
	castbar._intZone = zone

	local tick = castbar:CreateTexture(nil, 'OVERLAY', nil, 6)
	tick:Hide()
	castbar._intTick = tick

	local mask = castbar:CreateMaskTexture()
	mask:SetTexture('Interface\\Buttons\\WHITE8X8', 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')
	mask:SetAllPoints(castbar)
	tick:AddMaskTexture(mask)
	zone:AddMaskTexture(mask)
	castbar._intMask = mask
end

local trackedCastbars = setmetatable({}, { __mode = 'k' })

local interruptTicker
local CheckInterruptCooldowns

local function StartInterruptPoller()
	if interruptTicker then return end
	interruptTicker = BUI.Prof.NewTicker('CastBar.Core', 0.1, CheckInterruptCooldowns)
end

local function StopInterruptPoller()
	if not interruptTicker then return end
	interruptTicker:Cancel()
	interruptTicker = nil
end

function CastBar.StartTrackingInterrupts(castbar)
	if not castbar then return end
	if not castbar._intHideHooked then
		castbar._intHideHooked = true
		HookScript(castbar, 'OnHide', CastBar.HideInterruptOverlays)
	end
	trackedCastbars[castbar] = true
	StartInterruptPoller()
end

function CastBar.HideInterruptOverlays(castbar)
	if castbar._readyOverlays then
		for _, overlay in ipairs(castbar._readyOverlays) do overlay:SetAlpha(0) end
	end
	if castbar._niOverlay then castbar._niOverlay:SetAlpha(0) end
	if castbar._intTick then castbar._intTick:Hide() end
	if castbar._intZone then castbar._intZone:Hide() end
	if castbar._intBar then castbar._intBar:Hide() end
	if castbar._intPos then castbar._intPos:Hide() end
	castbar._intTickActive = nil
	castbar._intPreview = nil
	castbar._intTTSWant = nil
	castbar._intTTSSoonWant = nil
	castbar._intStyleTex = nil
	trackedCastbars[castbar] = nil
	if not next(trackedCastbars) then StopInterruptPoller() end
end

local function InterruptReady()
	local spell = knownInterrupts[1]
	if not spell then return false end
	local ready = KickReadyState(spell)
	if BUI.Tools.IsSecretValue(ready) then return false end
	return ready and true or false
end

function CastBar.CheckInterruptTTS(castbar)
	if not castbar._intTTSWant and not castbar._intTTSSoonWant then return end
	if castbar._ttsAnnounced or castbar._interrupted then return end
	local notInterruptible = castbar.notInterruptible
	if not BUI.Tools.IsSecretValue(notInterruptible) and notInterruptible then return end
	if #knownInterrupts == 0 then return end
	local now = GetTime()
	if InterruptReady() then
		castbar._ttsAnnounced = true
		if castbar._intTTSWant then
			BUI.TTS.Speak(castbar._intTTSText or 'Kick')
		end
	elseif castbar._intTTSSoonWant and not castbar._ttsSoonAnnounced then
		local remaining = interruptReadyAt - now
		if remaining > 0 then
			local endTime = BUI.Tools.SafeNum(castbar.endTime)
			local soon
			if endTime then
				soon = interruptReadyAt < endTime
			else
				soon = remaining <= (castbar._intTTSSoonWindow or 4)
			end
			if soon then
				castbar._ttsSoonAnnounced = true
				BUI.TTS.Speak(castbar._intTTSSoonText or 'Kick soon')
			end
		end
	end
end

local function ValidColor(color, fallback)
	if type(color) == 'table' and type(color[1]) == 'number' then return color end
	return fallback
end

function CastBar.ApplyInterruptColor(castbar, barColor, interruptColor, onCDColor, readyColor)
	barColor = ValidColor(barColor, { 1, 1, 1, 1 })
	local resolvedInterrupt = ValidColor(interruptColor, barColor)
	local resolvedOnCD = ValidColor(onCDColor, resolvedInterrupt)
	local resolvedReady = ValidColor(readyColor, barColor)
	local barTexture = castbar:GetStatusBarTexture()
	if not barTexture then return end
	local texturePath = barTexture:GetTexture()

	if castbar._intStyleTex ~= texturePath or castbar._intStyleCount ~= #knownInterrupts then
		castbar._intStyleTex = texturePath
		castbar._intStyleCount = #knownInterrupts

		if #knownInterrupts > 0 then
			castbar:SetStatusBarColor(resolvedOnCD[1], resolvedOnCD[2], resolvedOnCD[3], resolvedOnCD[4] or 1)
		else
			castbar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1)
		end

		if not castbar._readyOverlays then castbar._readyOverlays = {} end
		for overlayIndex = 1, #knownInterrupts do
			local overlay = castbar._readyOverlays[overlayIndex]
			if not overlay then
				overlay = castbar:CreateTexture(nil, 'ARTWORK', nil, 2)
				castbar._readyOverlays[overlayIndex] = overlay
			end
			overlay:SetTexture(texturePath)
			overlay:SetVertexColor(resolvedReady[1], resolvedReady[2], resolvedReady[3], resolvedReady[4] or 1)
			overlay:SetAllPoints(barTexture)
		end
		for overlayIndex = #knownInterrupts + 1, #castbar._readyOverlays do
			castbar._readyOverlays[overlayIndex]:SetAlpha(0)
		end

		local notInterruptibleOverlay = EnsureOverlay(castbar, '_niOverlay', 'ARTWORK', 4)
		notInterruptibleOverlay:SetTexture(texturePath)
		notInterruptibleOverlay:SetVertexColor(resolvedInterrupt[1], resolvedInterrupt[2], resolvedInterrupt[3], resolvedInterrupt[4] or 1)

		SyncOverlayAnchors(castbar)
	end

	for overlayIndex, spell in ipairs(knownInterrupts) do
		castbar._readyOverlays[overlayIndex]:SetAlphaFromBoolean(KickReadyState(spell), 1, 0)
	end

	local notInterruptible = castbar.notInterruptible
	if notInterruptible ~= nil then
		castbar._niOverlay:SetAlphaFromBoolean(notInterruptible, 1, 0)
	else
		castbar._niOverlay:SetAlpha(0)
	end
end

local function HideInterruptTick(castbar)
	if castbar._intTick then castbar._intTick:Hide() end
	if castbar._intZone then castbar._intZone:Hide() end
	if castbar._intBar then castbar._intBar:Hide() end
	if castbar._intPos then castbar._intPos:Hide() end
	castbar._intTickActive = nil
end

function CastBar.SetupInterruptTick(castbar, settings)
	local wantTick = settings.interruptTick ~= false
	local wantZone = settings.interruptWindow == true
	local durationObj = castbar.GetTimerDuration and castbar:GetTimerDuration()
	local plainTotal = (castbar.endTime or 0) - (castbar.startTime or 0)
	local width = castbar:GetWidth()

	if (not wantTick and not wantZone) or #knownInterrupts == 0 or width <= 0 or (not durationObj and plainTotal <= 0) then
		HideInterruptTick(castbar)
		return
	end
	local total = durationObj and durationObj:GetTotalDuration() or plainTotal

	EnsureInterruptTick(castbar)
	local positioner, marker, tick, zone = castbar._intPos, castbar._intBar, castbar._intTick, castbar._intZone
	local height = castbar:GetHeight()
	local drains = castbar.channeling and not castbar.empowering

	positioner:SetMinMaxValues(0, total)
	positioner:SetSize(width, height)
	positioner:SetReverseFill(drains and true or false)
	marker:SetMinMaxValues(0, total)
	marker:SetSize(width, height)
	marker:SetReverseFill(drains and true or false)
	UnsnapFill(positioner)
	UnsnapFill(marker)

	positioner:ClearAllPoints()
	marker:ClearAllPoints()
	tick:ClearAllPoints()
	zone:ClearAllPoints()
	positioner:SetPoint('TOPLEFT', castbar, 'TOPLEFT')
	marker:SetPoint('TOP', castbar, 'TOP')
	marker:SetPoint('BOTTOM', castbar, 'BOTTOM')
	tick:SetPoint('TOP', castbar, 'TOP')
	tick:SetPoint('BOTTOM', castbar, 'BOTTOM')
	zone:SetPoint('TOP', castbar, 'TOP')
	zone:SetPoint('BOTTOM', castbar, 'BOTTOM')

	local positionerTexture = positioner:GetStatusBarTexture()
	local markerTexture = marker:GetStatusBarTexture()
	if drains then
		marker:SetPoint('RIGHT', positionerTexture, 'LEFT')
		tick:SetPoint('RIGHT', markerTexture, 'LEFT')
		zone:SetPoint('RIGHT', markerTexture, 'LEFT')
		zone:SetPoint('LEFT', castbar, 'LEFT')
	else
		marker:SetPoint('LEFT', positionerTexture, 'RIGHT')
		tick:SetPoint('LEFT', markerTexture, 'RIGHT')
		zone:SetPoint('LEFT', markerTexture, 'RIGHT')
		zone:SetPoint('RIGHT', castbar, 'RIGHT')
	end

	local tickColor = ValidColor(settings.interruptTickColor, { 1, 1, 1, 1 })
	tick:SetColorTexture(tickColor[1], tickColor[2], tickColor[3], tickColor[4] or 1)
	tick:SetWidth(Pixel.PixelSize(settings.interruptTickWidth))

	local windowColor = ValidColor(settings.interruptWindowColor, { 1, 0.82, 0, 0.8 })
	zone:SetColorTexture(windowColor[1], windowColor[2], windowColor[3], windowColor[4] or 0.8)

	positioner:Show()
	marker:Show()
	castbar._intTickActive = true
	castbar._intTickWant = wantTick
	castbar._intZoneWant = wantZone
	castbar._intTickSpell = knownInterrupts[1]
	CastBar.RefreshInterruptTick(castbar)
end

function CastBar.RefreshInterruptTick(castbar)
	if not castbar._intTickActive or castbar._intPreview then return end
	local tick, zone = castbar._intTick, castbar._intZone

	local spell = castbar._intTickSpell
	local kickCooldown = spell and C_Spell.GetSpellCooldownDuration(spell)
	if not kickCooldown then tick:Hide(); zone:Hide(); return end

	local interruptibleAlpha = 1
	local notInterruptible = castbar.notInterruptible
	if notInterruptible ~= nil and EvaluateColorValueFromBoolean then
		interruptibleAlpha = EvaluateColorValueFromBoolean(notInterruptible, 0, 1)
	end

	local kickReady = false
	if kickCooldown.IsZero then kickReady = kickCooldown:IsZero() end
	local alpha = EvaluateColorValueFromBoolean
		and EvaluateColorValueFromBoolean(kickReady, 0, interruptibleAlpha)
		or interruptibleAlpha

	local durationObj = castbar.GetTimerDuration and castbar:GetTimerDuration()
	local elapsed
	if durationObj then
		elapsed = durationObj:GetElapsedDuration()
	else
		elapsed = GetTime() - (castbar.startTime or 0)
	end
	castbar._intPos:SetValue(elapsed)
	castbar._intBar:SetValue(kickCooldown:GetRemainingDuration())

	tick:SetShown(castbar._intTickWant)
	zone:SetShown(castbar._intZoneWant)
	tick:SetAlpha(alpha)
	zone:SetAlpha(alpha)
end

local previewTickers = {}

function CastBar.StopInterruptPreview(barType)
	local preview = previewTickers[barType]
	if not preview then return end
	previewTickers[barType] = nil
	if preview.ticker then preview.ticker:Cancel() end
	local castbar = preview.castbar
	if not castbar then return end
	castbar._intPreview = nil
	if castbar._intTick then castbar._intTick:Hide() end
	if castbar._intZone then castbar._intZone:Hide() end
	castbar.holdTime = 0.5
	if preview.strata then castbar._container:SetFrameStrata(preview.strata) end
	if preview.parent then castbar._container:SetParent(preview.parent) end
	if preview.frame then
		if barType == 'boss' then CastBar.ApplyBossCastbar(preview.frame, 1)
		else CastBar.ApplyCastbar(preview.frame, barType) end
	end
end

function CastBar.PreviewInterrupt(barType)
	if InCombatLockdown() then return end
	CastBar.StopInterruptPreview(barType)

	local UF = BUI.UnitFrames
	local frame = barType == 'boss' and UF.boss1 or UF[barType]
	local castbar = frame and frame.Castbar
	if not castbar or not castbar._container then return end
	local settings = CastBar.GetSettings(barType)
	if not settings then return end

	if barType == 'boss' then CastBar.ApplyBossCastbar(frame, 1) else CastBar.ApplyCastbar(frame, barType) end
	EnsureInterruptTick(castbar)
	castbar:SetStatusBarTexture(CastBar.GetTexturePath(settings.texture))

	if castbar._readyOverlays then for _, overlay in ipairs(castbar._readyOverlays) do overlay:SetAlpha(0) end end
	if castbar._niOverlay then castbar._niOverlay:SetAlpha(0) end

	local container = castbar._container
	local width = castbar:GetWidth()
	if width <= 0 then return end

	local parent = container:GetParent()
	local strata = container:GetFrameStrata()
	container:SetParent(UIParent)
	container:SetFrameStrata('FULLSCREEN_DIALOG')
	container:Show()

	castbar._intPreview = true
	castbar.holdTime = 1e9
	castbar:SetMinMaxValues(0, 1)
	castbar.Icon:SetTexture(136243)
	castbar.Icon:SetShown(settings.showIcon)
	if castbar._iconFrame then castbar._iconFrame:SetShown(settings.showIcon) end
	castbar:Show()

	local readyFrac = 0.6
	local readyX = width * readyFrac
	local tick, zone = castbar._intTick, castbar._intZone
	tick:ClearAllPoints()
	tick:SetPoint('TOP', castbar, 'TOP'); tick:SetPoint('BOTTOM', castbar, 'BOTTOM')
	tick:SetPoint('LEFT', castbar, 'LEFT', Pixel.Scale(readyX), 0)
	local tickColor = ValidColor(settings.interruptTickColor, { 1, 1, 1, 1 })
	tick:SetColorTexture(tickColor[1], tickColor[2], tickColor[3], tickColor[4] or 1)
	tick:SetWidth(Pixel.PixelSize(settings.interruptTickWidth))

	local readyColor = ValidColor(settings.interruptReadyColor, ValidColor(settings.barColor, { 0, 1, 0, 1 }))
	local windowColor = ValidColor(settings.interruptWindowColor, { 1, 0.82, 0, 0.8 })
	zone:ClearAllPoints()
	zone:SetPoint('TOP', castbar, 'TOP'); zone:SetPoint('BOTTOM', castbar, 'BOTTOM')
	zone:SetPoint('LEFT', castbar, 'LEFT', Pixel.Scale(readyX), 0)
	zone:SetPoint('RIGHT', castbar, 'RIGHT')
	zone:SetColorTexture(windowColor[1], windowColor[2], windowColor[3], windowColor[4] or 0.8)

	local onCD = ValidColor(settings.interruptOnCDColor, { 0.9, 0.5, 0, 1 })
	local elapsed, duration = 0, 4
	local spokeSoon, spokeReady = false, false
	local ticker = BUI.Prof.NewTicker('CastBar.Core', 0.03, BUI.Prof.Wrap('tick#CastbarPreview', function()
		elapsed = elapsed + 0.03
		local frac = elapsed / duration
		if frac >= 1 then CastBar.StopInterruptPreview(barType); return end
		castbar:SetValue(frac)
		if castbar.Time then castbar.Time:SetFormattedText('%.1f', duration * (1 - frac)); castbar.Time:Show() end
		if frac < readyFrac then
			castbar:SetStatusBarColor(onCD[1], onCD[2], onCD[3], onCD[4] or 1)
			if castbar.Text then castbar.Text:SetText('Interrupt on CD'); castbar.Text:Show() end
			tick:SetShown(settings.interruptTick ~= false)
			zone:SetShown(settings.interruptWindow == true)
			if settings.interruptTTSSoon and not spokeSoon then
				spokeSoon = true
				BUI.TTS.Speak(settings.interruptTTSSoonText)
			end
		else
			castbar:SetStatusBarColor(readyColor[1], readyColor[2], readyColor[3], readyColor[4] or 1)
			if castbar.Text then castbar.Text:SetText('Can Interrupt!'); castbar.Text:Show() end
			tick:Hide(); zone:Hide()
			if settings.interruptTTS and not spokeReady then
				spokeReady = true
				BUI.TTS.Speak(settings.interruptTTSText)
			end
		end
	end))
	previewTickers[barType] = { ticker = ticker, castbar = castbar, parent = parent, strata = strata, frame = frame }
end

CheckInterruptCooldowns = BUI.Dispatcher.New(function()
	if #knownInterrupts == 0 then return end
	if not next(trackedCastbars) then return end

	for castbar in pairs(trackedCastbars) do
		if not castbar:IsShown() then
			trackedCastbars[castbar] = nil
		elseif not castbar._interrupted then
			if castbar._intBarColor then
				CastBar.ApplyInterruptColor(castbar, castbar._intBarColor, castbar._intInterruptColor, castbar._intOnCDColor, castbar._intReadyColor)
			end
			if castbar._intTickActive then
				CastBar.RefreshInterruptTick(castbar)
			end
			CastBar.CheckInterruptTTS(castbar)
		end
	end
	if not next(trackedCastbars) then StopInterruptPoller() end
end, 'CastBar.InterruptCheck')

function CastBar.GetUnitClassColor(unit)
	if not unit or not UnitExists(unit) then return nil end
	local _, class = UnitClass(unit)
	if not class or not RAID_CLASS_COLORS[class] then return nil end
	local classColor = RAID_CLASS_COLORS[class]
	return { classColor.r, classColor.g, classColor.b, 1 }
end

local function UpdateEmpoweredStageColor(castbar)
	if not castbar.empowering then return end
	local settings = castbar._empoweredSettings
	if not settings or not settings.stageColorsEnabled then return end
	if settings.stageColorBackground ~= false then return end

	local stageColors = settings.stageColors
	if not stageColors or not next(stageColors) then return end

	local pipFractions = castbar._pipFractions
	if not pipFractions then return end

	local durationObj = castbar:GetTimerDuration()
	if not durationObj then return end
	local elapsed = durationObj:GetElapsedDuration()
	local total = durationObj:GetTotalDuration()
	if not elapsed or not total or total <= 0 then return end

	local currentStage = 1
	for i, frac in ipairs(pipFractions) do
		if elapsed / total >= frac then currentStage = i + 1 end
	end
	local numStages = castbar._numStages or #pipFractions
	if currentStage > numStages then currentStage = numStages end

	if currentStage ~= castbar._lastStage then
		castbar._lastStage = currentStage
		local stageColor = stageColors[currentStage]
		if stageColor then
			castbar:SetStatusBarColor(stageColor[1], stageColor[2], stageColor[3], stageColor[4] or 1)
		end
	end
end

local function TimeTextHandler(self, duration)
	local display = self._countdown and duration:GetRemainingDuration() or duration:GetElapsedDuration()
	if not display then return end
	if self._showTotalTime then
		local total = duration:GetTotalDuration()
		if total then
			self.Time:SetFormattedText('%.1f / %.1f', display, total)
			UpdateEmpoweredStageColor(self)
			return
		end
	end
	self.Time:SetFormattedText('%.1f', display)
	UpdateEmpoweredStageColor(self)
end

function CastBar.SetupTimeText(castbar, settings)
	castbar._showTotalTime = settings.showTotalTime
	castbar._countdown = settings.countdown
	castbar.CustomTimeText = TimeTextHandler
end

CastBar._containers = {}

function CastBar.TrackContainer(container)
	if not container or container._visibilityTracked then return end
	container._visibilityTracked = true
	container:SetIgnoreParentAlpha(true)
	CastBar._containers[#CastBar._containers + 1] = container
	container:SetAlpha(BUI.Visibility.GetContextualOpacity("CastBars") / 100)
end

local function UpdateCastbarOpacity()
	local alpha = BUI.Visibility.GetContextualOpacity("CastBars") / 100
	local containers = CastBar._containers
	for i = 1, #containers do
		local container = containers[i]
		if container then container:SetAlpha(alpha) end
	end
end

BUI.Visibility.Register("CastBars", UpdateCastbarOpacity, true)

CastBar.CHANNEL_TICKS = {
	[234153] = 5,
	[198590] = 4,
	[755]    = 5,
	[15407]  = 6,
	[48045]  = 6,
	[47757]  = 3,
	[47758]  = 3,
	[373129] = 3,
	[400171] = 3,
	[205065] = 3,
	[64843]  = 4,
	[64901]  = 4,
	[64902]  = 5,
	[5143]   = 4,
	[12051]  = 6,
	[205021] = 5,
	[314791] = 4,
	[740]    = 4,
	[206931] = 3,
	[198013] = 10,
	[212084] = 10,
	[120360] = 15,
	[257044] = 10,
	[113656] = 4,
	[117952] = 4,
	[115175] = 8,
	[356995] = 3,
	[370960] = 5,
	[305483] = 5,
	[291944] = 6,
	[20577]  = 5,
}

function CastBar.ApplyCastTarget(castbar, settings, unit)
	if not settings.showCastTarget or not settings.showSpellName then return end
	if not unit or BUI.Tools.IsSecretValue(castbar.spellName) then return end
	local tunit = unit .. 'target'
	if not UnitExists(tunit) then return end
	local name
	if UnitIsUnit(tunit, 'player') then
		name = '|cffff2020YOU|r'
	else
		name = UnitName(tunit)
		if not name or BUI.Tools.IsSecretValue(name) then return end
		local _, class = UnitClass(tunit)
		local classColor = class and RAID_CLASS_COLORS[class]
		if classColor and classColor.colorStr then
			name = '|c' .. classColor.colorStr .. name .. '|r'
		end
	end
	local current = castbar.Text:GetText()
	if not current or current == '' then return end
	castbar.Text:SetFormattedText('%s > %s', current, name)
end

function CastBar.HideChannelTicks(castbar)
	if not castbar._chanTicks then return end
	for _, tex in ipairs(castbar._chanTicks) do tex:Hide() end
end

function CastBar.UpdateChannelTicks(castbar, settings)
	if not settings.channelTicks or not castbar.channeling then
		CastBar.HideChannelTicks(castbar)
		return
	end
	local spellID = castbar.spellID
	if not spellID or BUI.Tools.IsSecretValue(spellID) then
		CastBar.HideChannelTicks(castbar)
		return
	end
	local info = CastBar.CHANNEL_TICKS[spellID]
	local ticks = type(info) == 'table' and info.ticks or info
	if type(info) == 'table' and info.hasted then
		ticks = math.floor(ticks * (1 + GetHaste() / 100) + 0.5)
	end
	local width = castbar:GetWidth()
	if not ticks or ticks < 2 or width <= 0 then
		CastBar.HideChannelTicks(castbar)
		return
	end

	castbar._chanTicks = castbar._chanTicks or {}
	local color = settings.channelTickColor
	local tickW = Pixel.PixelSize(settings.channelTickWidth)
	for i = 1, ticks - 1 do
		local tex = castbar._chanTicks[i]
		if not tex then
			tex = castbar:CreateTexture(nil, 'OVERLAY', nil, 3)
			castbar._chanTicks[i] = tex
		end
		tex:SetColorTexture(color[1], color[2], color[3], color[4] or 0.85)
		tex:SetWidth(tickW)
		tex:ClearAllPoints()
		local x = width * (i / ticks)
		tex:SetPoint('TOP', castbar, 'TOPLEFT', x, 0)
		tex:SetPoint('BOTTOM', castbar, 'BOTTOMLEFT', x, 0)
		tex:Show()
	end
	for i = ticks, #castbar._chanTicks do
		castbar._chanTicks[i]:Hide()
	end
end

function CastBar.TruncateSpellName(castbar, settings)
	if not castbar.spellName or BUI.Tools.IsSecretValue(castbar.spellName) then return end
	local name = castbar.spellName
	local maxLength = settings.spellNameMaxLength
	if not maxLength or maxLength <= 0 or strlenutf8(name) <= maxLength then return end
	local bytePos = 0
	local charCount = 0
	while charCount < maxLength and bytePos < #name do
		local byte = name:byte(bytePos + 1)
		if byte < 0x80 then bytePos = bytePos + 1
		elseif byte < 0xE0 then bytePos = bytePos + 2
		elseif byte < 0xF0 then bytePos = bytePos + 3
		else bytePos = bytePos + 4 end
		charCount = charCount + 1
	end
	castbar.Text:SetText(name:sub(1, bytePos))
end
