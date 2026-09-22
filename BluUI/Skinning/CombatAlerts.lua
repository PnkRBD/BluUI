local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local SKIN_ID = 'combatalerts'
local ART_KEYS = { 'Border', 'BorderFrame', 'Background', 'BackgroundTile', 'NineSlice', 'Inset', 'PortraitContainer', 'TitleBg', 'blackBg', 'RedLineTop', 'RedLineBottom', 'AbilityFrame' }
local CLOSE_KEYS = { 'CloseButton', 'CloseXButton', 'closeButton' }
local MIRROR_COUNT = 3
local FONT_DEPTH = 2

local skinnedFrames = {}
local testShown = {}
local TEST_NAMES = { 'LossOfControlFrame', 'DeathRecapFrame', 'MirrorTimer1' }

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeArt, FadeKeys = context.Fade, context.FadeArt, context.FadeKeys
local Shell, Close, Button = context.Shell, context.Close, context.Button
local CropIcon = Skin.CropIcon

local function Track(frame)
	skinnedFrames[#skinnedFrames + 1] = frame
end

local function SkinLossOfControl(frame)
	if not frame or frame._buiCombatAlert then return end
	frame._buiCombatAlert = true
	Track(frame)
	local icon = frame.Icon
	if icon and icon.SetTexCoord then
		icon.__buiSkin = true
		CropIcon(icon)
	end
	FadeArt(frame)
	FadeKeys(frame, ART_KEYS)
	if icon and icon.SetTexCoord then Skin.TipIconFrame(frame, icon) end
	Skin.TipFaceTree(frame, FONT_DEPTH)
end

local function SkinDeathRecap(frame)
	if not frame or frame._buiCombatAlert then return end
	frame._buiCombatAlert = true
	Track(frame)
	FadeArt(frame)
	FadeKeys(frame, ART_KEYS)
	Shell(frame)
	for index = 1, #CLOSE_KEYS do Close(frame[CLOSE_KEYS[index]]) end
	Button(frame.RecapButton)
	Skin.HideHelpButtons(frame)
	Skin.TipFaceTree(frame, FONT_DEPTH)
end

local function SkinMirrorTimer(timer)
	if not timer or timer._buiCombatAlert then return end
	timer._buiCombatAlert = true
	Track(timer)
	FadeArt(timer)
	FadeKeys(timer, ART_KEYS)
	local bar = timer.StatusBar or timer
	if bar.SetStatusBarTexture then
		bar:SetStatusBarTexture(BUI.GetGlobalTexture())
		FadeArt(bar)
		Shell(bar)
	end
	Skin.TipFaceTree(timer, FONT_DEPTH)
end

local function MirrorTimers()
	local container = _G.MirrorTimerContainer
	if container and container.GetChildren then
		for _, child in ipairs({ container:GetChildren() }) do SkinMirrorTimer(child) end
		return
	end
	for index = 1, MIRROR_COUNT do SkinMirrorTimer(_G['MirrorTimer' .. index]) end
end

local function Apply()
	if not Enabled() then return end
	SkinLossOfControl(_G.LossOfControlFrame)
	SkinDeathRecap(_G.DeathRecapFrame)
	MirrorTimers()
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		for index = 1, #skinnedFrames do skinnedFrames[index]._buiCombatAlert = nil end
		Apply()
	else
		context.Restore()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Combat Alerts',
	description = 'Loss of control, the death recap window, and the breath and fatigue timers.',
	icon = 'Interface/Icons/Spell_Shadow_DeathScream',
	test = function()
		pcall(C_AddOns.LoadAddOn, 'Blizzard_DeathRecap')
		Apply()
		local shown = {}
		for index = 1, #TEST_NAMES do
			local frame = _G[TEST_NAMES[index]]
			if frame and not frame:IsShown() and pcall(frame.Show, frame) then
				testShown[#testShown + 1] = frame
				shown[#shown + 1] = frame
			end
		end
		return unpack(shown)
	end,
	stopTest = function()
		for index = 1, #testShown do pcall(testShown[index].Hide, testShown[index]) end
		wipe(testShown)
	end,
})

BUI.Events:Register('ADDON_LOADED', 'Skin.CombatAlerts', Apply)
BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Skin.CombatAlerts', Apply)
BUI.Events:Once('PLAYER_LOGIN', 'Skin.CombatAlerts', Apply)
