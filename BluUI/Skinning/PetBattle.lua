local _, BUI = ...

local hooksecurefunc = BUI.Prof.MakeHooker('petbattle')
local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Pixel = BUI.Pixel

local SKIN_ID = 'petBattle'
local BLIZZARD_ADDON = 'Blizzard_PetBattleUI'
local HOVER_ALPHA = 0.15
local PRESS_ALPHA = 0.25
local SELECTED_ALPHA = 0.35
local BAR_ART_KEYS = { 'LeftEndCap', 'RightEndCap', 'Background' }
local BAR_FRAME_KEYS = { 'FlowFrame', 'Delimiter', 'MicroButtonFrame' }
local FIXED_BUTTON_KEYS = { 'SwitchPetButton', 'CatchButton', 'ForfeitButton' }

local installed = false
local skinned = false
local skinnedButtons = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys

local function BorderSettings()
	local actionBars = BUI.ActionBars
	local settings = actionBars and actionBars.GetSettings and actionBars.GetSettings()
	local color = settings and settings.borderColor or { 0, 0, 0, 1 }
	return settings and settings.borderSize or 1, color
end

local function FlattenOverlay(texture, red, green, blue, alpha, button)
	if not texture then return end
	Skin.FlatTexture(texture, red, green, blue, alpha)
	texture:ClearAllPoints()
	texture:SetAllPoints(button)
end

local function SkinActionButton(button)
	if not button or button._buiPetSkin then return end
	button._buiPetSkin = true
	skinnedButtons[#skinnedButtons + 1] = button
	Fade(button.NormalTexture or button:GetNormalTexture())
	Fade(button.CooldownShadow)
	Skin.CropIcon(button.Icon)
	FlattenOverlay(button:GetHighlightTexture(), 1, 1, 1, HOVER_ALPHA, button)
	FlattenOverlay(button:GetPushedTexture(), 1, 1, 1, PRESS_ALPHA, button)
	local red, green, blue = BUILib.Theme.GetAccent()
	FlattenOverlay(button.SelectedHighlight, red, green, blue, SELECTED_ALPHA, button)
	local size, color = BorderSettings()
	Pixel.ApplyBorder(button, size, color[1], color[2], color[3], color[4])
end

local function SkinAbilityButtons(bottom)
	local buttons = bottom and bottom.abilityButtons
	if not buttons then return end
	for _, button in ipairs(buttons) do SkinActionButton(button) end
end

local function SkinBar(bottom)
	FadeKeys(bottom, BAR_ART_KEYS)
	for _, key in ipairs(BAR_FRAME_KEYS) do FadeRegions(bottom[key]) end
end

local function Apply()
	if skinned or not Enabled() then return end
	local frame = _G.PetBattleFrame
	if not frame or not frame.BottomFrame then return end
	skinned = true
	local bottom = frame.BottomFrame
	SkinBar(bottom)
	for _, key in ipairs(FIXED_BUTTON_KEYS) do SkinActionButton(bottom[key]) end
	SkinAbilityButtons(bottom)
end

local function OnActionBarLayout(frame)
	if skinned and Enabled() then SkinAbilityButtons(frame.BottomFrame) end
end

local function Install()
	if installed or not Enabled() then return end
	if not _G.PetBattleFrame then return end
	installed = true
	hooksecurefunc('PetBattleFrame_UpdateActionBarLayout', OnActionBarLayout)
	Apply()
end

local function TryInstall(_, addonName)
	if addonName ~= BLIZZARD_ADDON and addonName then return end
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.PetBattle') end
end

local function Deactivate()
	context.Restore()
	for _, button in ipairs(skinnedButtons) do Pixel.HideBorder(button) end
	skinned = false
	BUI.Print('Pet battle skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.PetBattle', TryInstall)
		else
			for _, button in ipairs(skinnedButtons) do button._buiPetSkin = nil end
			wipe(skinnedButtons)
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Pet Battle Bar',
	description = 'The pet battle action bar: square ability, swap, trap and forfeit buttons with the action bar border, no ornate bar art. No preview: it only shows during a pet battle.',
	icon = 'Interface/Icons/INV_Pet_BattlePetTraining',
})
