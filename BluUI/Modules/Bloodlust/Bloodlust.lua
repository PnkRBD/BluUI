local _, BUI = ...
local Pixel = BUI.Pixel

local Bloodlust = {}
BUI.Bloodlust = Bloodlust

local SETTINGS_KEY  = 'bloodlust'
local MODULE_KEY    = 'Bloodlust'
local FRAME_NAME    = 'BUI_BloodlustFrame'
local BLOODLUST     = 2825
local TICK_INTERVAL = 0.1

local LOCKOUT       = { 57723, 57724, 80354, 264689, 390435 }

local BUFF_DURATION = 40

local frame, text
local wasLockedOut       = false
local previewState       = nil
local lastSpellName      = nil
local usedMessageUntil   = 0
local readyMessageUntil  = 0
local flashAnimationGroup            = nil
local flashGeneration           = 0
local warnPlayed         = false
local lastRenderedText   = nil
local lastState, lastBucket
local iconPrefix         = ''

local noLockoutSeen      = false
local lastFitWidth           = 0

local warmupUntil        = math.huge
local WARMUP_SECS        = 5
local noLockoutStreak    = 0
local STABLE_NO_LOCKOUT_TICKS = 10

local function GetConfig() return BUI.GetDB()[SETTINGS_KEY] end

local lockoutInstanceID

local LOCKOUT_SET = {}
for spellIndex = 1, #LOCKOUT do LOCKOUT_SET[LOCKOUT[spellIndex]] = true end

local cachedLockout
local cachedLockoutValid = false
local nextForcedScan = 0
local FORCED_SCAN_INTERVAL = 1

local function InvalidateLockoutCache()
	cachedLockoutValid = false
end

local function Sleep()
	BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, false)
end

local function Wake()
	InvalidateLockoutCache()
	BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, true)
end

BUI.Tools.OnAuraQueriesUnblocked(Wake)

local function OnPlayerAura(_, _, updateInfo)
	local config = GetConfig()
	if not config.enabled then return end
	if not updateInfo then
		Wake()
		return
	end
	local IsSecretValue = BUI.Tools.IsSecretValue
	local full = updateInfo.isFullUpdate
	local added = updateInfo.addedAuras
	local removed = updateInfo.removedAuraInstanceIDs
	local updated = updateInfo.updatedAuraInstanceIDs
	if IsSecretValue(full) or IsSecretValue(added) or IsSecretValue(removed) or IsSecretValue(updated) or full then
		Wake()
		return
	end
	if added then
		for auraIndex = 1, #added do
			local aura = added[auraIndex]
			if IsSecretValue(aura) then
				Wake()
				return
			end
			local id = aura.spellId
			if id and not IsSecretValue(id) and LOCKOUT_SET[id] then
				Wake()
				return
			end
		end
	end
	if lockoutInstanceID then
		if removed then
			for removedIndex = 1, #removed do
				local id = removed[removedIndex]
				if IsSecretValue(id) or id == lockoutInstanceID then
					Wake()
					return
				end
			end
		end
		if updated then
			for updatedIndex = 1, #updated do
				local id = updated[updatedIndex]
				if IsSecretValue(id) or id == lockoutInstanceID then
					Wake()
					return
				end
			end
		end
	end
end

local function GetLockoutAura()
	for spellIndex = 1, #LOCKOUT do
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(LOCKOUT[spellIndex])
		if aura then return aura end
	end
end

local function GetLockoutCached(now)
	if cachedLockoutValid and cachedLockout then
		local expiration = cachedLockout.expirationTime
		if expiration and not BUI.Tools.IsSecretValue(expiration) and now >= expiration then
			cachedLockoutValid = false
		end
	end
	if not cachedLockoutValid or now >= nextForcedScan then
		cachedLockout = GetLockoutAura()
		cachedLockoutValid = true
		nextForcedScan = now + FORCED_SCAN_INTERVAL
	end
	return cachedLockout
end

local function GetActiveRemaining(lockout, now)
	if not lockout or not lockout.expirationTime or not lockout.duration then return nil end
	local IsSecretValue = BUI.Tools.IsSecretValue
	if IsSecretValue(lockout.expirationTime) or IsSecretValue(lockout.duration) then
		return nil
	end
	local castTime  = lockout.expirationTime - lockout.duration
	local remaining = castTime + BUFF_DURATION - now
	if remaining > 0 then return remaining end
	return nil
end

local function Format(formatString, seconds, spellName)
	formatString = (formatString or '')
		:gsub('%[spell%]', spellName or 'Bloodlust')
		:gsub('%[name%]',  spellName or 'Bloodlust')
	if seconds then
		local timeText = BUI.TimeFormat.Format(seconds, 10)
		formatString = formatString:gsub('%[time%]', timeText)
	else
		formatString = formatString:gsub('%[time%]', '')
	end
	return formatString
end

local function Build()
	if frame then return end
	frame = CreateFrame('Frame', FRAME_NAME, UIParent)
	frame:SetFrameStrata('MEDIUM')
	frame:SetSize(Pixel.Scale(160), Pixel.Scale(28))
	frame:Hide()

	text = frame:CreateFontString(nil, 'OVERLAY')
	text:SetJustifyH('LEFT')
end

local function BuildIconPrefix(config)
	if config.showIcon == false then return '' end
	local iconSize = config.iconSize
	local texture = C_Spell.GetSpellTexture(BLOODLUST)
	if not texture then return '' end
	return ('|T%s:%d:%d:0:0:64:64:5:59:5:59|t  '):format(texture, iconSize, iconSize)
end

local function ApplyLayout()
	local config = GetConfig()
	Build()

	BUI.Anchor.ApplyPosition(frame, config)

	text:ClearAllPoints()
	text:SetPoint('CENTER', frame, 'CENTER', 0, 0)
	text:SetJustifyH('CENTER')

	local font = BUI.GetModuleFont(config)
	local outline = BUI.GetFontOutline()
	Pixel.ApplyFont(text, config.fontSize, font, outline)

	lastRenderedText, lastFitWidth = nil, 0
	lastState, lastBucket = nil, nil
	iconPrefix = BuildIconPrefix(config)
end

local function FitFrameToContent(config)
	local width = text:GetStringWidth()
	local height = math.max(config.iconSize, config.fontSize + 4)
	if math.abs(width - lastFitWidth) < 0.5 then return end
	lastFitWidth = width
	frame:SetSize(math.max(width, 1), height)
end

local function SetTextIfChanged(newText)
	if newText == lastRenderedText then return false end
	lastRenderedText = newText
	text:SetText(newText)
	return true
end

local function ShowState(config, state, formatString, color, remaining, spellName)
	local bucket = remaining and BUI.TimeFormat.Bucket(remaining, 10)
	if lastState == state and lastBucket == bucket and frame:IsShown() then return end
	lastState, lastBucket = state, bucket
	if SetTextIfChanged(iconPrefix .. Format(formatString, remaining, spellName)) then
		FitFrameToContent(config)
	end
	text:SetTextColor(color[1], color[2], color[3], color[4])
	frame:Show()
end

local function ShowCD(config, remaining)
	ShowState(config, 'cd', config.cdFormat, config.cdColor, remaining)
end

local function ShowReady(config)
	ShowState(config, 'ready', config.readyFormat, config.readyColor)
end

local function ShowUsed(config)
	ShowState(config, 'used', config.usedFormat, config.usedColor, nil, lastSpellName)
end

local function ShowActive(config, remaining)
	ShowState(config, 'active', config.activeFormat, config.activeColor, remaining)
end

local FLASH_HALF_PERIOD = 0.3
local FLASH_LOW_ALPHA   = 0.25

local function EnsureFlashAnimationGroup()
	if flashAnimationGroup or not text then return end
	flashAnimationGroup = text:CreateAnimationGroup()
	flashAnimationGroup:SetLooping('REPEAT')
	local fadeOut = flashAnimationGroup:CreateAnimation('Alpha')
	fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(FLASH_LOW_ALPHA)
	fadeOut:SetDuration(FLASH_HALF_PERIOD); fadeOut:SetOrder(1); fadeOut:SetSmoothing('IN_OUT')
	local fadeIn = flashAnimationGroup:CreateAnimation('Alpha')
	fadeIn:SetFromAlpha(FLASH_LOW_ALPHA); fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(FLASH_HALF_PERIOD); fadeIn:SetOrder(2); fadeIn:SetSmoothing('IN_OUT')
end

local function StopFlash()
	flashGeneration = flashGeneration + 1
	if flashAnimationGroup and flashAnimationGroup:IsPlaying() then flashAnimationGroup:Stop() end
	if text then text:SetAlpha(1) end
end

local function PlayFlash(durationSec)
	EnsureFlashAnimationGroup()
	if not flashAnimationGroup then return end
	flashGeneration = flashGeneration + 1
	local myGeneration = flashGeneration
	if flashAnimationGroup:IsPlaying() then flashAnimationGroup:Stop() end
	flashAnimationGroup:Play()
	C_Timer.After(durationSec, function()
		if myGeneration == flashGeneration then StopFlash() end
	end)
end

local function Speak(message)
	if not message or message == '' then return end
	BUI.TTS.Speak(message)
end

local function PlaySound(name)
	BUI.PlaySoundByName(name)
end

local function FireUsedAlert(config, spellName)
	lastSpellName = spellName
	usedMessageUntil = GetTime() + config.usedHoldDuration
	if config.flashOnUsed then
		PlayFlash(math.min(config.flashDuration, config.usedHoldDuration))
	end
	PlaySound(config.soundOnUsed)
	if config.ttsOnUsed then
		Speak(config.ttsUsedText:gsub('%[spell%]', spellName or 'Bloodlust'))
	end
end

local function FireReadyAlert(config)
	readyMessageUntil = GetTime() + config.readyHoldDuration
	if config.flashOnReady then
		PlayFlash(math.min(config.flashReadyDuration, config.readyHoldDuration))
	end
	PlaySound(config.soundOnReady)
	if config.ttsOnReady then Speak(config.ttsReadyText) end
end

local function FireWarnIfDue(config, remaining)
	if not config.warnBeforeReady or config.warnBeforeReady <= 0 then return end
	if warnPlayed or remaining > config.warnBeforeReady then return end
	PlaySound(config.soundOnWarn)
	if config.ttsOnWarn then Speak(config.ttsWarnText) end
	warnPlayed = true
end

local PREVIEW_ACTIVE_DURATION = 5
local PREVIEW_CD_DURATION     = 3

local function TickPreview(config)
	if not frame then Build(); ApplyLayout() end
	local now     = GetTime()
	local elapsed = now - previewState.startedAt
	local phase   = previewState.phase

	if phase == 'used' then
		if elapsed < config.usedHoldDuration then
			ShowUsed(config)
			return
		end
		previewState.phase = 'active'
		previewState.startedAt = now
		elapsed, phase = 0, 'active'
	end

	if phase == 'active' then
		local remaining = PREVIEW_ACTIVE_DURATION - elapsed
		if remaining > 0 then
			if config.showWhenActive ~= false then
				ShowActive(config, remaining)
			else
				frame:Hide()
			end
			return
		end

		if config.showWhenCD then
			previewState.phase = 'cd'
			previewState.startedAt = now
			elapsed, phase = 0, 'cd'
		else
			FireReadyAlert(config)
			previewState.phase = 'ready'
			previewState.startedAt = now
			elapsed, phase = 0, 'ready'
		end
	end

	if phase == 'cd' then
		local remaining = PREVIEW_CD_DURATION - elapsed
		if remaining > 0 then
			ShowCD(config, remaining)
			FireWarnIfDue(config, remaining)
			return
		end
		FireReadyAlert(config)
		previewState.phase = 'ready'
		previewState.startedAt = now
		elapsed, phase = 0, 'ready'
	end

	if phase == 'ready' then
		if elapsed < config.readyHoldDuration then
			ShowReady(config)
			return
		end
		if config.showWhenReady then
			ShowReady(config)
		else
			Bloodlust.StopPreview()
		end
	end
end

local function Tick()
	local config = GetConfig()

	if previewState then
		TickPreview(config)
		return
	end

	if not config.enabled then
		if frame then frame:Hide() end
		wasLockedOut = false
		warnPlayed   = false
		Sleep()
		return
	end
	if not frame then Build(); ApplyLayout() end

	local now        = GetTime()
	local lockout    = GetLockoutCached(now)
	local hasLockout = lockout ~= nil
	local inWarmup   = now < warmupUntil

	local IsSecretValue = BUI.Tools and BUI.Tools.IsSecretValue
	local fieldsSecret = (hasLockout and IsSecretValue
		and (IsSecretValue(lockout.expirationTime) or IsSecretValue(lockout.duration))) or false

	if hasLockout then
		noLockoutStreak = 0
		local instanceID = lockout.auraInstanceID
		if IsSecretValue and IsSecretValue(instanceID) then
			lockoutInstanceID = nil
		else
			lockoutInstanceID = instanceID
		end
	else
		noLockoutStreak = noLockoutStreak + 1
		lockoutInstanceID = nil
	end

	local activeRemaining = GetActiveRemaining(lockout, now)

	if hasLockout and not wasLockedOut and noLockoutSeen and not inWarmup then
		FireUsedAlert(config, lastSpellName or 'Bloodlust')
	end

	if hasLockout and now < usedMessageUntil then
		ShowUsed(config)
		wasLockedOut = true
		return
	end

	if activeRemaining then
		if config.showWhenActive ~= false then
			ShowActive(config, activeRemaining)
		else
			frame:Hide()
		end
		wasLockedOut = true
		return
	end

	if hasLockout then
		if fieldsSecret then
			wasLockedOut = true
			return
		end
		local remaining = lockout.expirationTime - now
		if remaining > 0 then
			if config.showWhenCD then
				ShowCD(config, remaining)
				FireWarnIfDue(config, remaining)
			else
				frame:Hide()
				Sleep()
			end
			wasLockedOut = true
			return
		end
	end

	if not inWarmup and noLockoutStreak >= STABLE_NO_LOCKOUT_TICKS then
		if wasLockedOut then
			FireReadyAlert(config)
		end
		wasLockedOut  = false
		warnPlayed    = false
		noLockoutSeen = true
	end

	if now < readyMessageUntil then
		ShowReady(config)
		return
	end

	if config.showWhenReady then
		ShowReady(config)
	else
		frame:Hide()
	end

	if not hasLockout and not inWarmup and noLockoutStreak >= STABLE_NO_LOCKOUT_TICKS then
		Sleep()
	end
end

function Bloodlust.StartPreview()
	Build(); ApplyLayout()
	StopFlash()
	previewState = { startedAt = GetTime(), phase = 'used' }
	warnPlayed = false
	lastSpellName = 'Bloodlust'
	BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, true)
	Tick()
	FireUsedAlert(GetConfig(), lastSpellName)
end

function Bloodlust.StopPreview()
	local wasPreviewing = previewState ~= nil
	previewState = nil
	wasLockedOut = false
	StopFlash()
	usedMessageUntil  = 0
	readyMessageUntil = 0
	BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, GetConfig().enabled)
	Tick()
	if wasPreviewing and Bloodlust.onPreviewStop then Bloodlust.onPreviewStop() end
end

function Bloodlust.IsPreviewing() return previewState ~= nil end

function Bloodlust.Refresh()
	Build()
	ApplyLayout()
	BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, GetConfig().enabled)
	Tick()
end

function Bloodlust.Initialize()
	Build()

	local config = GetConfig()
	if config.usedFormat:find('%[caster%]', 1, false) then
		config.usedFormat = '[spell] used!'
	end
	if config.ttsUsedText:find('%[caster%]', 1, false) then
		config.ttsUsedText = 'Lust used'
	end
	ApplyLayout()

	BUI.Anchor.RegisterCallback('Bloodlust', function()
		local config = GetConfig()
		if config.enabled and BUI.Anchor.ShouldRefreshOnAnchorChange(config) then
			BUI.Anchor.ApplyPosition(frame, config)
		end
	end)

	BUI.Scheduler.RegisterUpdate(MODULE_KEY, Tick, TICK_INTERVAL, config.enabled)
	BUI.Events:RegisterUnit('UNIT_AURA', 'player', 'Bloodlust.Wake', OnPlayerAura)
end

BUI.Events:OnLogin('Bloodlust', Bloodlust.Initialize)

BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Bloodlust.Warmup', function()
	warmupUntil = GetTime() + WARMUP_SECS
end)
