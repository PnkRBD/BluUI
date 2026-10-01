local _, BUI = ...
local Pixel = BUI.Pixel

local CastBar = BUI.CastBar

local UnitCanAttack = UnitCanAttack
local UnitClass = UnitClass
local UnitExists = UnitExists
local EvaluateColorValueFromBoolean = C_CurveUtil.EvaluateColorValueFromBoolean
local IsSecret = BUI.Tools.IsSecretValue

local WHITE = 'Interface\\Buttons\\WHITE8X8'
local PREVIEW_SECONDS = 4
local PREVIEW_READY_AT = 0.6
local PREVIEW_STEP = 0.03

local CLASS_INTERRUPTS = {
	DEATHKNIGHT = {47528}, DEMONHUNTER = {183752},
	DRUID = {106839, 78675, 38675}, EVOKER = {351338},
	HUNTER = {147362, 187707}, MAGE = {2139}, MONK = {116705},
	PALADIN = {96231, 31935}, PRIEST = {15487}, ROGUE = {1766},
	SHAMAN = {57994}, WARLOCK = {89766, 119910, 132409, 1276467, 19647, 115781, 119909},
	WARRIOR = {6552},
}
local PET_BANK = Enum.SpellBookSpellBank.Pet
local candidateInterrupts = CLASS_INTERRUPTS[select(2, UnitClass('player'))]
local interruptSpells = {}
for _, spellID in ipairs(candidateInterrupts) do interruptSpells[spellID] = true end
local knownInterrupts = {}
local kickCooldowns = {}
local interruptReadyAt = 0

local function SampleKickCooldowns()
	wipe(kickCooldowns)
	for index, spellID in ipairs(knownInterrupts) do
		kickCooldowns[index] = C_Spell.GetSpellCooldownDuration(spellID)
	end
	return kickCooldowns
end

local function KickReady(cooldown)
	return not cooldown or cooldown:IsZero()
end

local function RefreshKnownInterrupts()
	wipe(knownInterrupts)
	for _, spellID in ipairs(candidateInterrupts) do
		if C_SpellBook.IsSpellKnownOrInSpellBook(spellID) or C_SpellBook.IsSpellKnownOrInSpellBook(spellID, PET_BANK) then
			knownInterrupts[#knownInterrupts + 1] = spellID
		end
	end
end

for _, event in ipairs({ 'PLAYER_LOGIN', 'SPELLS_CHANGED', 'PET_BAR_UPDATE' }) do
	BUI.Events:Register(event, 'CB.InterruptCache', RefreshKnownInterrupts)
end
BUI.Events:RegisterUnit('UNIT_PET', 'player', 'CB.InterruptCache', RefreshKnownInterrupts)

BUI.Events:RegisterUnit('UNIT_SPELLCAST_SUCCEEDED', { 'player', 'pet' }, 'CB.InterruptClock', function(_, _, _, spellID)
	if not interruptSpells[spellID] then return end
	local baseMs = GetSpellBaseCooldown(spellID)
	if baseMs and baseMs > 0 then interruptReadyAt = GetTime() + baseMs / 1000 end
end)

local function HiddenStatusBar(castbar)
	local bar = CreateFrame('StatusBar', nil, castbar)
	bar:SetFrameLevel(castbar:GetFrameLevel() + 2)
	bar:SetStatusBarTexture(WHITE)
	bar:GetStatusBarTexture():SetAlpha(0)
	bar:Hide()
	return bar
end

local function EnsureInterruptTick(castbar)
	if castbar._intBar then return end
	castbar._intPos = HiddenStatusBar(castbar)
	castbar._intBar = HiddenStatusBar(castbar)

	local zone = castbar:CreateTexture(nil, 'ARTWORK', nil, 5)
	zone:SetTexture(WHITE)
	zone:Hide()
	castbar._intZone = zone

	local tick = castbar:CreateTexture(nil, 'OVERLAY', nil, 6)
	tick:Hide()
	castbar._intTick = tick

	local mask = castbar:CreateMaskTexture()
	mask:SetTexture(WHITE, 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')
	mask:SetAllPoints(castbar)
	tick:AddMaskTexture(mask)
	zone:AddMaskTexture(mask)
end

local function PaintInterruptMarks(castbar, settings)
	local tickColor, windowColor = settings.interruptTickColor, settings.interruptWindowColor
	castbar._intTick:SetColorTexture(tickColor[1], tickColor[2], tickColor[3], tickColor[4] or 1)
	castbar._intTick:SetWidth(Pixel.PixelSize(settings.interruptTickWidth))
	castbar._intZone:SetColorTexture(windowColor[1], windowColor[2], windowColor[3], windowColor[4] or 0.8)
end

local function HideInterruptTick(castbar)
	if not castbar._intBar then return end
	castbar._intTick:Hide()
	castbar._intZone:Hide()
	castbar._intBar:Hide()
	castbar._intPos:Hide()
	castbar._intTickActive = nil
end

local trackedCastbars = setmetatable({}, { __mode = 'k' })
local interruptTicker
local CheckInterruptCooldowns

local function StopInterruptPoller()
	if not interruptTicker then return end
	interruptTicker:Cancel()
	interruptTicker = nil
end

function CastBar.HideInterruptOverlays(castbar)
	if castbar._readyOverlays then
		for _, overlay in ipairs(castbar._readyOverlays) do overlay:SetAlpha(0) end
		castbar._niOverlay:SetAlpha(0)
	end
	HideInterruptTick(castbar)
	castbar._intPreview = nil
	castbar._intStyleTex = nil
	trackedCastbars[castbar] = nil
	if not next(trackedCastbars) then StopInterruptPoller() end
end

local function StyleInterruptOverlays(castbar, barColor, settings)
	local barTexture = castbar:GetStatusBarTexture()
	local texturePath = barTexture:GetTexture()
	if castbar._intStyleTex == texturePath and castbar._intStyleCount == #knownInterrupts then return end
	castbar._intStyleTex = texturePath
	castbar._intStyleCount = #knownInterrupts

	local baseColor = #knownInterrupts > 0 and settings.interruptOnCDColor or barColor
	castbar:SetStatusBarColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1)

	local readyColor = settings.interruptReadyColor
	castbar._readyOverlays = castbar._readyOverlays or {}
	castbar._readyShown = castbar._readyShown or {}
	wipe(castbar._readyShown)
	for index = 1, #knownInterrupts do
		local overlay = castbar._readyOverlays[index]
		if not overlay then
			overlay = castbar:CreateTexture(nil, 'ARTWORK', nil, 2)
			castbar._readyOverlays[index] = overlay
		end
		overlay:SetTexture(texturePath)
		overlay:SetVertexColor(readyColor[1], readyColor[2], readyColor[3], readyColor[4] or 1)
		overlay:SetAllPoints(barTexture)
	end
	for index = #knownInterrupts + 1, #castbar._readyOverlays do
		castbar._readyOverlays[index]:SetAlpha(0)
	end

	local interruptColor = settings.interruptColor
	castbar._niOverlay = castbar._niOverlay or castbar:CreateTexture(nil, 'ARTWORK', nil, 4)
	castbar._niOverlay:SetTexture(texturePath)
	castbar._niOverlay:SetVertexColor(interruptColor[1], interruptColor[2], interruptColor[3], interruptColor[4] or 1)
	castbar._niOverlay:SetAllPoints(barTexture)
end

local function PaintKickReady(castbar, cooldowns)
	local shown = castbar._readyShown
	for index = 1, #knownInterrupts do
		local ready = KickReady(cooldowns[index])
		if IsSecret(ready) then
			shown[index] = nil
			castbar._readyOverlays[index]:SetAlphaFromBoolean(ready, 1, 0)
		elseif shown[index] ~= ready then
			shown[index] = ready
			castbar._readyOverlays[index]:SetAlphaFromBoolean(ready, 1, 0)
		end
	end
end

local function PaintInterruptColor(castbar, barColor, settings, cooldowns)
	StyleInterruptOverlays(castbar, barColor, settings)
	PaintKickReady(castbar, cooldowns)
	castbar._niOverlay:SetAlphaFromBoolean(castbar.notInterruptible, 1, 0)
end

local function ShowTickParts(castbar, tickShown, zoneShown)
	if castbar._intTickShown == tickShown and castbar._intZoneShown == zoneShown then return end
	castbar._intTickShown, castbar._intZoneShown = tickShown, zoneShown
	castbar._intTick:SetShown(tickShown)
	castbar._intZone:SetShown(zoneShown)
end

local function RefreshInterruptTick(castbar, cooldowns)
	if not castbar._intTickActive or castbar._intPreview then return end

	local kickCooldown = cooldowns[1]
	if not kickCooldown then
		ShowTickParts(castbar, false, false)
		return
	end

	local settings = castbar._intSettings
	ShowTickParts(castbar, settings.interruptTick and true or false, settings.interruptWindow and true or false)

	local interruptibleAlpha = EvaluateColorValueFromBoolean(castbar.notInterruptible, 0, 1)
	local alpha = EvaluateColorValueFromBoolean(kickCooldown:IsZero(), 0, interruptibleAlpha)
	local secretAlpha = IsSecret(alpha)
	if not secretAlpha and alpha == 0 and castbar._intAlpha == 0 then return end

	castbar._intPos:SetValue(castbar:GetTimerDuration():GetElapsedDuration())
	castbar._intBar:SetValue(kickCooldown:GetRemainingDuration())

	if secretAlpha or castbar._intAlpha ~= alpha then
		castbar._intAlpha = not secretAlpha and alpha or nil
		castbar._intTick:SetAlpha(alpha)
		castbar._intZone:SetAlpha(alpha)
	end
end

local function SetupInterruptTick(castbar, settings)
	local duration = castbar:GetTimerDuration()
	local width = castbar:GetWidth()
	if not (settings.interruptTick or settings.interruptWindow) or #knownInterrupts == 0 or width <= 0 or not duration then
		HideInterruptTick(castbar)
		return
	end

	EnsureInterruptTick(castbar)
	local positioner, marker, tick, zone = castbar._intPos, castbar._intBar, castbar._intTick, castbar._intZone
	local total = duration:GetTotalDuration()
	local height = castbar:GetHeight()
	local drains = castbar.channeling == true and not castbar.empowering

	positioner:SetMinMaxValues(0, total)
	positioner:SetSize(width, height)
	positioner:SetReverseFill(drains)
	marker:SetMinMaxValues(0, total)
	marker:SetSize(width, height)
	marker:SetReverseFill(drains)

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

	PaintInterruptMarks(castbar, settings)
	positioner:Show()
	marker:Show()
	castbar._intTickActive = true
	castbar._intTickShown, castbar._intZoneShown, castbar._intAlpha = nil, nil, nil
	RefreshInterruptTick(castbar, SampleKickCooldowns())
end

local function CheckInterruptTTS(castbar, cooldowns)
	local settings = castbar._intSettings
	if not settings.interruptTTS and not settings.interruptTTSSoon then return end
	if castbar._ttsAnnounced or castbar._interrupted or #knownInterrupts == 0 then return end
	local notInterruptible = castbar.notInterruptible
	if not IsSecret(notInterruptible) and notInterruptible then return end

	local ready = KickReady(cooldowns[1])
	if not IsSecret(ready) and ready then
		castbar._ttsAnnounced = true
		if settings.interruptTTS then BUI.TTS.Speak(settings.interruptTTSText) end
	elseif settings.interruptTTSSoon and not castbar._ttsSoonAnnounced then
		local remaining = interruptReadyAt - GetTime()
		if remaining > 0 and remaining <= settings.interruptTTSSoonWindow then
			castbar._ttsSoonAnnounced = true
			BUI.TTS.Speak(settings.interruptTTSSoonText)
		end
	end
end

local function CanInterruptUnit(unit)
	local attackable = UnitCanAttack('player', unit)
	return IsSecret(attackable) or attackable
end

function CastBar.TrackInterrupts(castbar, settings, barColor, unit)
	castbar._intHostile = CanInterruptUnit(unit)
	if not castbar._intHostile then
		CastBar.HideInterruptOverlays(castbar)
		castbar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1)
		return
	end
	castbar._intBarColor = barColor
	castbar._intSettings = settings
	castbar._ttsAnnounced = nil
	castbar._ttsSoonAnnounced = nil
	if not castbar._intHideHooked then
		castbar._intHideHooked = true
		castbar:HookScript('OnHide', BUI.Profiler.Wrap('CastBar.Core interrupt hide', CastBar.HideInterruptOverlays))
	end
	trackedCastbars[castbar] = true
	if not interruptTicker then interruptTicker = C_Timer.NewTicker(0.1, CheckInterruptCooldowns) end
	local cooldowns = SampleKickCooldowns()
	PaintInterruptColor(castbar, barColor, settings, cooldowns)
	SetupInterruptTick(castbar, settings)
	CheckInterruptTTS(castbar, cooldowns)
end

function CastBar.RefreshInterruptible(castbar, barColor, settings)
	if not castbar._intHostile then return end
	PaintInterruptColor(castbar, barColor, settings, SampleKickCooldowns())
	SetupInterruptTick(castbar, settings)
end

CheckInterruptCooldowns = BUI.Dispatcher.New(function()
	if #knownInterrupts == 0 then return end
	local cooldowns = SampleKickCooldowns()
	for castbar in pairs(trackedCastbars) do
		if not castbar:IsShown() then
			trackedCastbars[castbar] = nil
		elseif not castbar._interrupted then
			StyleInterruptOverlays(castbar, castbar._intBarColor, castbar._intSettings)
			PaintKickReady(castbar, cooldowns)
			RefreshInterruptTick(castbar, cooldowns)
			CheckInterruptTTS(castbar, cooldowns)
		end
	end
	if not next(trackedCastbars) then StopInterruptPoller() end
end, 'CastBar.InterruptCheck')

local previewTickers = {}

local function ApplyBar(frame, barType)
	if barType == 'boss' then CastBar.ApplyBossCastbar(frame, 1) else CastBar.ApplyCastbar(frame, barType) end
end

function CastBar.StopInterruptPreview(barType)
	local preview = previewTickers[barType]
	if not preview then return end
	previewTickers[barType] = nil
	preview.ticker:Cancel()
	local castbar = preview.castbar
	castbar._intPreview = nil
	castbar._intTick:Hide()
	castbar._intZone:Hide()
	castbar.holdTime = 0.5
	castbar._container:SetFrameStrata(preview.strata)
	castbar._container:SetParent(preview.parent)
	ApplyBar(preview.frame, barType)
end

function CastBar.IsPreviewingInterrupt(barType)
	return previewTickers[barType] ~= nil
end

function CastBar.PreviewInterrupt(barType)
	if InCombatLockdown() then return end
	CastBar.StopInterruptPreview(barType)

	local frame = BUI.UnitFrames[barType == 'boss' and 'boss1' or barType]
	local castbar = frame and frame.Castbar
	if not castbar then return end
	local settings = CastBar.GetSettings(barType)

	ApplyBar(frame, barType)
	EnsureInterruptTick(castbar)
	castbar:SetStatusBarTexture(CastBar.GetTexturePath(settings.texture))
	CastBar.HideInterruptOverlays(castbar)

	local container = castbar._container
	local width = castbar:GetWidth()
	if width <= 0 then return end

	local parent, strata = container:GetParent(), container:GetFrameStrata()
	container:SetParent(UIParent)
	container:SetFrameStrata('FULLSCREEN_DIALOG')
	container:Show()

	castbar._intPreview = true
	castbar.holdTime = 1e9
	castbar:SetMinMaxValues(0, 1)
	castbar.Icon:SetTexture(136243)
	castbar.Icon:SetShown(settings.showIcon)
	castbar._iconFrame:SetShown(settings.showIcon)
	castbar:Show()

	local tick, zone = castbar._intTick, castbar._intZone
	local readyX = width * PREVIEW_READY_AT
	PaintInterruptMarks(castbar, settings)
	tick:ClearAllPoints()
	tick:SetPoint('TOP', castbar, 'TOP')
	tick:SetPoint('BOTTOM', castbar, 'BOTTOM')
	tick:SetPoint('LEFT', castbar, 'LEFT', readyX, 0)
	zone:ClearAllPoints()
	zone:SetPoint('TOP', castbar, 'TOP')
	zone:SetPoint('BOTTOM', castbar, 'BOTTOM')
	zone:SetPoint('LEFT', castbar, 'LEFT', readyX, 0)
	zone:SetPoint('RIGHT', castbar, 'RIGHT')

	local onCooldownColor, readyColor = settings.interruptOnCDColor, settings.interruptReadyColor
	local elapsed = 0
	local spokeSoon, spokeReady = false, false
	local ticker = C_Timer.NewTicker(PREVIEW_STEP, BUI.Profiler.Wrap('CastBar.Core interrupt preview', function()
		elapsed = elapsed + PREVIEW_STEP
		local progress = elapsed / PREVIEW_SECONDS
		if progress >= 1 then
			CastBar.StopInterruptPreview(barType)
			return
		end
		castbar:SetValue(progress)
		castbar.Time:SetFormattedText('%.1f', PREVIEW_SECONDS - elapsed)
		castbar.Time:Show()
		if progress < PREVIEW_READY_AT then
			castbar:SetStatusBarColor(onCooldownColor[1], onCooldownColor[2], onCooldownColor[3], onCooldownColor[4] or 1)
			castbar.Text:SetText('Interrupt on CD')
			castbar.Text:Show()
			tick:SetShown(settings.interruptTick)
			zone:SetShown(settings.interruptWindow)
			if settings.interruptTTSSoon and not spokeSoon then
				spokeSoon = true
				BUI.TTS.Speak(settings.interruptTTSSoonText)
			end
		else
			castbar:SetStatusBarColor(readyColor[1], readyColor[2], readyColor[3], readyColor[4] or 1)
			castbar.Text:SetText('Can Interrupt!')
			castbar.Text:Show()
			tick:Hide()
			zone:Hide()
			if settings.interruptTTS and not spokeReady then
				spokeReady = true
				BUI.TTS.Speak(settings.interruptTTSText)
			end
		end
	end))
	previewTickers[barType] = { ticker = ticker, castbar = castbar, parent = parent, strata = strata, frame = frame }
end

local function TimeTextHandler(self, duration)
	local display = self._countdown and duration:GetRemainingDuration() or duration:GetElapsedDuration()
	if not display then return end
	if self._showTotalTime then
		local total = duration:GetTotalDuration()
		if total then
			self.Time:SetFormattedText('%.1f / %.1f', display, total)
			return
		end
	end
	self.Time:SetFormattedText('%.1f', display)
end

function CastBar.SetupTimeText(castbar, settings)
	castbar._showTotalTime = settings.showTotalTime
	castbar._countdown = settings.countdown
	castbar.CustomTimeText = TimeTextHandler
end

local containers = {}

function CastBar.TrackContainer(container)
	container:SetIgnoreParentAlpha(true)
	container:SetAlpha(BUI.Visibility.GetContextualOpacity('CastBars') / 100)
	containers[#containers + 1] = container
end

BUI.Visibility.Register('CastBars', function()
	local alpha = BUI.Visibility.GetContextualOpacity('CastBars') / 100
	for _, container in ipairs(containers) do container:SetAlpha(alpha) end
end, true)

local CHANNEL_TICKS = {
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
	if not settings.showCastTarget or not settings.showSpellName or IsSecret(castbar.spellName) then return end
	local targetUnit = unit .. 'target'
	if not UnitExists(targetUnit) then return end
	local name
	if UnitIsUnit(targetUnit, 'player') then
		name = '|cffff2020YOU|r'
	else
		name = UnitName(targetUnit)
		if IsSecret(name) then return end
		local red, green, blue = BUI.Tools.GetUnitClassColor(targetUnit)
		if red then name = CreateColor(red, green, blue):WrapTextInColorCode(name) end
	end
	local current = castbar.Text:GetText()
	if not current or current == '' then return end
	castbar.Text:SetFormattedText('%s > %s', current, name)
end

function CastBar.HideChannelTicks(castbar)
	if not castbar._chanTicks then return end
	for _, tick in ipairs(castbar._chanTicks) do tick:Hide() end
end

function CastBar.UpdateChannelTicks(castbar, settings)
	local spellID = castbar.spellID
	local ticks = settings.channelTicks and castbar.channeling and not IsSecret(spellID) and CHANNEL_TICKS[spellID]
	local width = castbar:GetWidth()
	if not ticks or width <= 0 then
		CastBar.HideChannelTicks(castbar)
		return
	end

	castbar._chanTicks = castbar._chanTicks or {}
	local color = settings.channelTickColor
	local tickWidth = Pixel.PixelSize(settings.channelTickWidth)
	for index = 1, ticks - 1 do
		local tick = castbar._chanTicks[index]
		if not tick then
			tick = castbar:CreateTexture(nil, 'OVERLAY', nil, 3)
			castbar._chanTicks[index] = tick
		end
		local x = width * (index / ticks)
		tick:SetColorTexture(color[1], color[2], color[3], color[4] or 0.85)
		tick:SetWidth(tickWidth)
		tick:ClearAllPoints()
		tick:SetPoint('TOP', castbar, 'TOPLEFT', x, 0)
		tick:SetPoint('BOTTOM', castbar, 'BOTTOMLEFT', x, 0)
		tick:Show()
	end
	for index = ticks, #castbar._chanTicks do
		castbar._chanTicks[index]:Hide()
	end
end

function CastBar.TruncateSpellName(castbar, settings)
	local name = castbar.spellName
	local maxLength = settings.spellNameMaxLength
	if IsSecret(name) or not maxLength or strlenutf8(name) <= maxLength then return end
	local bytes, characters = 0, 0
	while characters < maxLength and bytes < #name do
		local byte = name:byte(bytes + 1)
		if byte < 0x80 then bytes = bytes + 1
		elseif byte < 0xE0 then bytes = bytes + 2
		elseif byte < 0xF0 then bytes = bytes + 3
		else bytes = bytes + 4 end
		characters = characters + 1
	end
	castbar.Text:SetText(name:sub(1, bytes))
end
