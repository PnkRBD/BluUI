local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning
local Painter = BUI.Painter

local LEGACY_ID = 'combatalerts'
local FONT_DEPTH = 2
local BAR_ROLE = 'skinTitle'

local recapContext = Skin.Define('deathrecap', {
	name = 'Death Recap',
	description = 'The window listing the blows that killed you.',
	icon = 'Interface/Icons/Ability_Rogue_FeignDeath',
	legacy = LEGACY_ID,
})

local function SkinDeathRecap(frame)
	recapContext.FadeArt(frame)
	recapContext.Shell(frame)
	recapContext.Close(frame.CloseXButton)
	recapContext.Button(frame.CloseButton)
	Skin.TipFaceTree(frame, FONT_DEPTH)
end

recapContext.Window('DeathRecapFrame', { skin = SkinDeathRecap })

local mirrorContext = Skin.Define('mirrortimers', {
	name = 'Breath & Fatigue Timers',
	description = 'The breath, fatigue and feign death bars below the minimap.',
	icon = 'Interface/Icons/Spell_Shadow_DemonBreath',
	legacy = LEGACY_ID,
})

local function PaintBar(bar)
	if not mirrorContext.Enabled() then return end
	bar:SetStatusBarTexture(BUI.GetGlobalTexture())
	bar:SetStatusBarColor(Painter.Color(BAR_ROLE))
end

local function PaintTimer(timer)
	PaintBar(timer.StatusBar)
end

local function SkinTimers(container)
	for _, timer in ipairs(container.mirrorTimers) do
		mirrorContext.FadeArt(timer)
		mirrorContext.Shell(timer.StatusBar)
		Skin.TipCount(timer.Text)
		Painter.Custom(timer.StatusBar, PaintBar)
	end
end

local function InstallTimers(container)
	for _, timer in ipairs(container.mirrorTimers) do mirrorContext.Hook(timer, 'Setup', PaintTimer) end
end

mirrorContext.Window('MirrorTimerContainer', { install = InstallTimers, skin = SkinTimers })

mirrorContext.OnDisable(function()
	for _, timer in ipairs(MirrorTimerContainer.mirrorTimers) do
		local bar = timer.StatusBar
		bar:SetStatusBarColor(1, 1, 1)
		if timer.timer then bar:SetStatusBarTexture(MirrorTimerAtlas[timer.timer]) end
	end
end)
