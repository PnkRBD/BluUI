local _, BUI = ...
local Pixel = BUI.Pixel
local IsSecret = BUI.Tools.IsSecretValue

local Bloodlust = {}
BUI.Bloodlust = Bloodlust

local MODULE_KEY = 'Bloodlust'
local FRAME_NAME = 'BUI_BloodlustFrame'
local BLOODLUST = 2825
local SPELL_TEXT = 'Bloodlust'
local TICK_INTERVAL = 0.1
local BUFF_DURATION = 40
local DECIMALS_BELOW = 10
local WARMUP_SECS = 5
local STABLE_NO_LOCKOUT_TICKS = 10
local FORCED_SCAN_INTERVAL = 1
local FLASH_HALF_PERIOD = 0.3
local FLASH_LOW_ALPHA = 0.25
local PREVIEW_ACTIVE_DURATION = 5
local PREVIEW_CD_DURATION = 3

local LOCKOUT = { 57723, 57724, 80354, 264689, 390435 }
local LOCKOUT_SET = {}
for _, spellID in ipairs(LOCKOUT) do LOCKOUT_SET[spellID] = true end

local frame, text, flash
local tile, tileIcon, swipe, tileTimer
local iconLook = false
local iconPrefix = ''
local lastText, lastState, lastBucket
local previewState
local wasLockedOut = false
local noLockoutSeen = false
local noLockoutStreak = 0
local warnPlayed = false
local usedMessageUntil = 0
local readyMessageUntil = 0
local flashGeneration = 0
local warmupUntil = math.huge
local lockoutInstanceID
local cachedLockout
local cachedLockoutValid = false
local nextForcedScan = 0

local function GetConfig() return BUI.GetDB().bloodlust end

local function Sleep()
	BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, false)
end

local function Wake()
	cachedLockoutValid = false
	BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, true)
end

local countdownWakePending = false

local function CountdownWake()
	countdownWakePending = false
	Wake()
end

local function SleepUntilNextSecond(remaining)
	Sleep()
	if countdownWakePending then return end
	countdownWakePending = true
	BUI.Profiler.After('Bloodlust.Bloodlust countdown wake', remaining % 1, CountdownWake)
end

BUI.Tools.OnAuraQueriesUnblocked(Wake, 'Bloodlust')

local function TouchesLockout(instanceIDs)
	if not instanceIDs then return false end
	for _, instanceID in ipairs(instanceIDs) do
		if IsSecret(instanceID) or instanceID == lockoutInstanceID then return true end
	end
	return false
end

local function OnPlayerAura(_, _, updateInfo)
	if not GetConfig().enabled then return end
	if not updateInfo then
		Wake()
		return
	end
	local full, added = updateInfo.isFullUpdate, updateInfo.addedAuras
	local removed, updated = updateInfo.removedAuraInstanceIDs, updateInfo.updatedAuraInstanceIDs
	if IsSecret(full) or IsSecret(added) or IsSecret(removed) or IsSecret(updated) or full then
		Wake()
		return
	end
	if added then
		for _, aura in ipairs(added) do
			if IsSecret(aura) or (not IsSecret(aura.spellId) and LOCKOUT_SET[aura.spellId]) then
				Wake()
				return
			end
		end
	end
	if lockoutInstanceID and (TouchesLockout(removed) or TouchesLockout(updated)) then Wake() end
end

local function GetLockoutAura()
	for _, spellID in ipairs(LOCKOUT) do
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
		if aura then return aura end
	end
end

local function GetLockoutCached(now)
	if cachedLockoutValid and cachedLockout then
		local expiration = cachedLockout.expirationTime
		if not IsSecret(expiration) and now >= expiration then cachedLockoutValid = false end
	end
	if not cachedLockoutValid or now >= nextForcedScan then
		cachedLockout = GetLockoutAura()
		cachedLockoutValid = true
		nextForcedScan = now + FORCED_SCAN_INTERVAL
	end
	return cachedLockout
end

local function LockoutStart(lockout)
	if not lockout or IsSecret(lockout.expirationTime) or IsSecret(lockout.duration) then return nil end
	return lockout.expirationTime - lockout.duration
end

local function GetActiveRemaining(start, now)
	if not start then return nil end
	local remaining = start + BUFF_DURATION - now
	if remaining > 0 then return remaining end
end

local function Format(formatString, seconds)
	local timeText = seconds and BUI.TimeFormat.Format(seconds, DECIMALS_BELOW) or ''
	return (formatString:gsub('%[spell%]', SPELL_TEXT):gsub('%[time%]', timeText))
end

local function Build()
	if frame then return end
	frame = CreateFrame('Frame', FRAME_NAME, UIParent)
	frame:SetFrameStrata('MEDIUM')
	frame:Hide()

	text = frame:CreateFontString(nil, 'OVERLAY')
	text:SetPoint('CENTER')
	text:SetJustifyH('CENTER')
	text:SetWordWrap(false)

	flash = frame:CreateAnimationGroup()
	flash:SetLooping('REPEAT')
	local fadeOut = flash:CreateAnimation('Alpha')
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(FLASH_LOW_ALPHA)
	fadeOut:SetDuration(FLASH_HALF_PERIOD)
	fadeOut:SetOrder(1)
	fadeOut:SetSmoothing('IN_OUT')
	local fadeIn = flash:CreateAnimation('Alpha')
	fadeIn:SetFromAlpha(FLASH_LOW_ALPHA)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(FLASH_HALF_PERIOD)
	fadeIn:SetOrder(2)
	fadeIn:SetSmoothing('IN_OUT')
end

local function BuildTile()
	if tile then return end
	tile = CreateFrame('Frame', nil, frame)
	tile:SetAllPoints()

	tileIcon = tile:CreateTexture(nil, 'ARTWORK')
	tileIcon:SetTexture(C_Spell.GetSpellTexture(BLOODLUST))
	tileIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	swipe = CreateFrame('Cooldown', nil, tile, 'CooldownFrameTemplate')
	swipe:SetAllPoints(tileIcon)
	swipe:SetDrawEdge(false)
	swipe:SetDrawBling(false)
	swipe:SetHideCountdownNumbers(true)
	swipe:SetSwipeColor(0, 0, 0, 0.65)

	local overlay = CreateFrame('Frame', nil, tile)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(swipe:GetFrameLevel() + 2)

	tileTimer = overlay:CreateFontString(nil, 'OVERLAY')
	tileTimer:SetPoint('CENTER')
end

local function BuildIconPrefix(config)
	if not config.showIcon then return '' end
	return ('|T%s:%d:%d:0:0:64:64:5:59:5:59|t  '):format(C_Spell.GetSpellTexture(BLOODLUST), config.iconSize, config.iconSize)
end

local function ApplyLayout()
	Build()
	local config = GetConfig()
	local font = BUI.GetModuleFont(config)
	iconLook = config.style == 'icon'
	if iconLook then
		BuildTile()
		local size = Pixel.Scale(config.tileSize)
		frame:SetSize(size, size)
		Pixel.ApplyBorder(tile, 1, 0, 0, 0, 1)
		local edge = Pixel.GetBorderSize(tile)
		tileIcon:ClearAllPoints()
		tileIcon:SetPoint('TOPLEFT', tile, 'TOPLEFT', edge, -edge)
		tileIcon:SetPoint('BOTTOMRIGHT', tile, 'BOTTOMRIGHT', -edge, edge)
		Pixel.ApplyFont(tileTimer, config.fontSize, font, BUI.GetFontOutline())
	else
		local size = math.max(config.iconSize, config.fontSize + 4)
		frame:SetSize(size, size)
		Pixel.ApplyFont(text, config.fontSize, font, BUI.GetFontOutline())
		iconPrefix = BuildIconPrefix(config)
	end
	if tile then tile:SetShown(iconLook) end
	text:SetShown(not iconLook)
	BUI.Anchor.ApplyPosition(frame, config)
	lastText, lastState, lastBucket = nil, nil, nil
end

local function PaintTile(state, startTime, duration)
	tileIcon:SetDesaturated(state == 'cd')
	if startTime then swipe:SetCooldown(startTime, duration) else swipe:Clear() end
end

local function Show(config, state, remaining, startTime, duration)
	local bucket = remaining and BUI.TimeFormat.Bucket(remaining, DECIMALS_BELOW)
	if lastState == state and lastBucket == bucket and frame:IsShown() then return end
	local color = config[state .. 'Color']
	if iconLook then
		if lastState ~= state then PaintTile(state, startTime, duration) end
		tileTimer:SetText(remaining and BUI.TimeFormat.Format(remaining, DECIMALS_BELOW) or '')
		tileTimer:SetTextColor(color[1], color[2], color[3], color[4])
	else
		local newText = iconPrefix .. Format(config[state .. 'Format'], remaining)
		if newText ~= lastText then
			lastText = newText
			text:SetText(newText)
		end
		text:SetTextColor(color[1], color[2], color[3], color[4])
	end
	lastState, lastBucket = state, bucket
	frame:Show()
end

local function ShownHere(hideInTown, dungeonOnly)
	if hideInTown and BUI.Tools.IsInTown() then return false end
	if dungeonOnly and select(2, IsInInstance()) ~= 'party' then return false end
	return true
end

local function StopFlash()
	flashGeneration = flashGeneration + 1
	flash:Stop()
	frame:SetAlpha(1)
end

local function PlayFlash(seconds)
	flashGeneration = flashGeneration + 1
	local generation = flashGeneration
	flash:Stop()
	flash:Play()
	BUI.Profiler.After('Bloodlust.Bloodlust flash stop', seconds, function()
		if generation == flashGeneration then StopFlash() end
	end)
end

local function FireUsedAlert(config)
	usedMessageUntil = GetTime() + config.usedHoldDuration
	if config.flashOnUsed then PlayFlash(math.min(config.flashDuration, config.usedHoldDuration)) end
	BUI.PlaySoundByName(config.soundOnUsed)
	if config.ttsOnUsed then BUI.TTS.Speak((config.ttsUsedText:gsub('%[spell%]', SPELL_TEXT))) end
end

local function FireReadyAlert(config)
	readyMessageUntil = GetTime() + config.readyHoldDuration
	if config.flashOnReady then PlayFlash(math.min(config.flashReadyDuration, config.readyHoldDuration)) end
	BUI.PlaySoundByName(config.soundOnReady)
	if config.ttsOnReady then BUI.TTS.Speak(config.ttsReadyText) end
end

local function FireWarnIfDue(config, remaining)
	if warnPlayed or config.warnBeforeReady <= 0 or remaining > config.warnBeforeReady then return end
	warnPlayed = true
	BUI.PlaySoundByName(config.soundOnWarn)
	if config.ttsOnWarn then BUI.TTS.Speak(config.ttsWarnText) end
end

local function EnterPreviewPhase(phase, now)
	previewState.phase = phase
	previewState.startedAt = now
end

local function TickPreview(config)
	local now = GetTime()
	local elapsed = now - previewState.startedAt
	local phase = previewState.phase

	if phase == 'used' then
		if elapsed < config.usedHoldDuration then
			Show(config, 'used')
			return
		end
		EnterPreviewPhase('active', now)
		elapsed, phase = 0, 'active'
	end

	if phase == 'active' then
		local remaining = PREVIEW_ACTIVE_DURATION - elapsed
		if remaining > 0 then
			if config.showWhenActive then Show(config, 'active', remaining, previewState.startedAt, PREVIEW_ACTIVE_DURATION) else frame:Hide() end
			return
		end
		if config.showWhenCD then
			EnterPreviewPhase('cd', now)
			elapsed, phase = 0, 'cd'
		else
			FireReadyAlert(config)
			EnterPreviewPhase('ready', now)
			elapsed, phase = 0, 'ready'
		end
	end

	if phase == 'cd' then
		local remaining = PREVIEW_CD_DURATION - elapsed
		if remaining > 0 then
			Show(config, 'cd', remaining, previewState.startedAt, PREVIEW_CD_DURATION)
			FireWarnIfDue(config, remaining)
			return
		end
		FireReadyAlert(config)
		EnterPreviewPhase('ready', now)
		elapsed = 0
	end

	if elapsed < config.readyHoldDuration or config.showWhenReady then
		Show(config, 'ready')
	else
		Bloodlust.StopPreview()
	end
end

local function Tick()
	local config = GetConfig()

	if previewState then
		TickPreview(config)
		return
	end

	if not config.enabled then
		frame:Hide()
		wasLockedOut = false
		warnPlayed = false
		Sleep()
		return
	end

	local now = GetTime()
	local lockout = GetLockoutCached(now)
	local hasLockout = lockout ~= nil
	local inWarmup = now < warmupUntil

	if hasLockout then
		noLockoutStreak = 0
		local instanceID = lockout.auraInstanceID
		lockoutInstanceID = not IsSecret(instanceID) and instanceID or nil
	else
		noLockoutStreak = noLockoutStreak + 1
		lockoutInstanceID = nil
	end

	if hasLockout and not wasLockedOut and noLockoutSeen and not inWarmup then
		FireUsedAlert(config)
	end

	local start = LockoutStart(lockout)
	local activeRemaining = GetActiveRemaining(start, now)

	if hasLockout and now < usedMessageUntil then
		Show(config, 'used', activeRemaining, start, BUFF_DURATION)
		wasLockedOut = true
		return
	end

	if activeRemaining then
		if config.showWhenActive then Show(config, 'active', activeRemaining, start, BUFF_DURATION) else frame:Hide() end
		wasLockedOut = true
		return
	end

	if hasLockout then
		if not start then
			wasLockedOut = true
			return
		end
		local remaining = lockout.expirationTime - now
		if remaining > 0 then
			wasLockedOut = true
			if config.showWhenCD and ShownHere(config.cdHideInTown, config.cdDungeonOnly) then
				Show(config, 'cd', remaining, start, lockout.duration)
				FireWarnIfDue(config, remaining)
				if remaining > DECIMALS_BELOW then SleepUntilNextSecond(remaining) end
			else
				frame:Hide()
				Sleep()
			end
			return
		end
	end

	local settled = not hasLockout and not inWarmup and noLockoutStreak >= STABLE_NO_LOCKOUT_TICKS
	if settled then
		if wasLockedOut then FireReadyAlert(config) end
		wasLockedOut = false
		warnPlayed = false
		noLockoutSeen = true
	end

	if now < readyMessageUntil then
		Show(config, 'ready')
		return
	end

	if config.showWhenReady and ShownHere(config.readyHideInTown, config.readyDungeonOnly) then
		Show(config, 'ready')
	else
		frame:Hide()
	end

	if settled then Sleep() end
end

function Bloodlust.StartPreview()
	ApplyLayout()
	StopFlash()
	previewState = { startedAt = GetTime(), phase = 'used' }
	warnPlayed = false
	BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, true)
	Tick()
	FireUsedAlert(GetConfig())
end

function Bloodlust.StopPreview()
	local wasPreviewing = previewState ~= nil
	previewState = nil
	wasLockedOut = false
	StopFlash()
	usedMessageUntil = 0
	readyMessageUntil = 0
	BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, GetConfig().enabled)
	Tick()
	if wasPreviewing then BUI.NotifyModuleChange('bloodlust') end
end

function Bloodlust.IsPreviewing() return previewState ~= nil end

function Bloodlust.Refresh()
	ApplyLayout()
	BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, GetConfig().enabled)
	Tick()
end

function Bloodlust.Initialize()
	local config = GetConfig()
	ApplyLayout()

	BUI.Anchor.Follow('Bloodlust', function() return GetConfig().enabled and frame end, GetConfig)
	BUI.Scheduler.RegisterUpdate(MODULE_KEY, Tick, TICK_INTERVAL, config.enabled)
	BUI.Events:RegisterUnit('UNIT_AURA', 'player', 'Bloodlust.Wake', OnPlayerAura)
end

BUI.Events:OnLogin('Bloodlust', Bloodlust.Initialize)

BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Bloodlust.Warmup', function()
	warmupUntil = GetTime() + WARMUP_SECS
	Wake()
end)

BUI.Events:Register('PLAYER_UPDATE_RESTING', 'Bloodlust.Resting', Wake)
