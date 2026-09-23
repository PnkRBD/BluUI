local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local LOC_ID = 'lossofcontrol'
local RECAP_ID = 'deathrecap'
local MIRROR_ID = 'mirrortimers'
local LEGACY_ID = 'combatalerts'
local ART_KEYS = { 'Border', 'BorderFrame', 'Background', 'BackgroundTile', 'NineSlice', 'Inset', 'PortraitContainer', 'TitleBg', 'blackBg', 'RedLineTop', 'RedLineBottom', 'AbilityFrame' }
local CLOSE_KEYS = { 'CloseButton', 'CloseXButton', 'closeButton' }
local MIRROR_COUNT = 3
local FONT_DEPTH = 2

local CropIcon = Skin.CropIcon

local function LossOfControlEnabled()
	return Skin.IsSkinEnabled(LOC_ID)
end

local function DeathRecapEnabled()
	return Skin.IsSkinEnabled(RECAP_ID)
end

local function MirrorTimersEnabled()
	return Skin.IsSkinEnabled(MIRROR_ID)
end

local locContext = Skin.NewContext(LossOfControlEnabled)
local recapContext = Skin.NewContext(DeathRecapEnabled)
local mirrorContext = Skin.NewContext(MirrorTimersEnabled)

local mirrorTimers = {}

local function ApplyLossOfControl()
	if not LossOfControlEnabled() then return end
	local frame = _G.LossOfControlFrame
	if not frame or frame._buiLossOfControl then return end
	frame._buiLossOfControl = true

	local icon = frame.Icon
	if icon and icon.SetTexCoord then
		icon.__buiSkin = true
		CropIcon(icon)
	end
	locContext.FadeArt(frame)
	locContext.FadeKeys(frame, ART_KEYS)
	locContext.Shell(frame)
	if icon and icon.SetTexCoord then Skin.TipIconFrame(frame, icon) end
	Skin.TipFaceTree(frame, FONT_DEPTH)

	local timeLeft = frame.TimeLeft
	if timeLeft and timeLeft.SecondsText then
		timeLeft.secondsWidth = timeLeft.SecondsText:GetStringWidth()
	end
end

local function ApplyDeathRecap()
	if not DeathRecapEnabled() then return end
	local frame = _G.DeathRecapFrame
	if not frame or frame._buiDeathRecap then return end
	frame._buiDeathRecap = true

	recapContext.FadeArt(frame)
	recapContext.FadeKeys(frame, ART_KEYS)
	recapContext.Shell(frame)
	for index = 1, #CLOSE_KEYS do recapContext.Close(frame[CLOSE_KEYS[index]]) end
	recapContext.Button(frame.RecapButton)
	Skin.HideHelpButtons(frame)
	Skin.TipFaceTree(frame, FONT_DEPTH)
end

local function SkinMirrorTimer(timer)
	if not timer or timer._buiMirrorTimer then return end
	timer._buiMirrorTimer = true
	mirrorTimers[#mirrorTimers + 1] = timer

	mirrorContext.FadeArt(timer)
	mirrorContext.FadeKeys(timer, ART_KEYS)
	local bar = timer.StatusBar or timer
	if bar.SetStatusBarTexture then
		bar:SetStatusBarTexture(BUI.GetGlobalTexture())
		mirrorContext.FadeArt(bar)
		mirrorContext.Shell(bar)
	end
	Skin.TipFaceTree(timer, FONT_DEPTH)
end

local function ApplyMirrorTimers()
	if not MirrorTimersEnabled() then return end
	local container = _G.MirrorTimerContainer
	if container and container.GetChildren then
		for _, child in ipairs({ container:GetChildren() }) do SkinMirrorTimer(child) end
		return
	end
	for index = 1, MIRROR_COUNT do SkinMirrorTimer(_G['MirrorTimer' .. index]) end
end

local function Apply()
	ApplyLossOfControl()
	ApplyDeathRecap()
	ApplyMirrorTimers()
end

local function PreviewLossOfControl()
	local frame = _G.LossOfControlFrame
	if not frame or not frame.SetIsInEditMode then return end
	frame:SetIsInEditMode(true)
	return frame
end

local function StopPreviewLossOfControl()
	local frame = _G.LossOfControlFrame
	if frame and frame.SetIsInEditMode then frame:SetIsInEditMode(false) end
end

Skin.OnToggle(LOC_ID, function(enabled)
	if enabled then
		local frame = _G.LossOfControlFrame
		if frame then frame._buiLossOfControl = nil end
		ApplyLossOfControl()
	else
		locContext.Restore()
	end
end)

Skin.OnToggle(RECAP_ID, function(enabled)
	if enabled then
		local frame = _G.DeathRecapFrame
		if frame then frame._buiDeathRecap = nil end
		ApplyDeathRecap()
	else
		recapContext.Restore()
	end
end)

Skin.OnToggle(MIRROR_ID, function(enabled)
	if enabled then
		for index = 1, #mirrorTimers do mirrorTimers[index]._buiMirrorTimer = nil end
		ApplyMirrorTimers()
	else
		mirrorContext.Restore()
	end
end)

Skin.RegisterSkin(LOC_ID, {
	name = 'Loss of Control',
	description = 'The stun, fear and silence warning in the middle of the screen.',
	icon = 'Interface/Icons/Spell_Shadow_DeathScream',
	legacy = LEGACY_ID,
	test = PreviewLossOfControl,
	stopTest = StopPreviewLossOfControl,
})

Skin.RegisterSkin(RECAP_ID, {
	name = 'Death Recap',
	description = 'The window listing the blows that killed you.',
	icon = 'Interface/Icons/Ability_Rogue_FeignDeath',
	legacy = LEGACY_ID,
})

Skin.RegisterSkin(MIRROR_ID, {
	name = 'Breath & Fatigue Timers',
	description = 'The breath, fatigue and feign death bars below the minimap.',
	icon = 'Interface/Icons/Spell_Shadow_DemonBreath',
	legacy = LEGACY_ID,
})

BUI.Events:Register('ADDON_LOADED', 'Skin.CombatAlerts', Apply)
BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Skin.CombatAlerts', Apply)
BUI.Events:Once('PLAYER_LOGIN', 'Skin.CombatAlerts', Apply)
