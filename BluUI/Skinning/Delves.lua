local _, BUI = ...

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SKIN_ID = 'delves'
local CHROME_FRAMES = { 'NineSlice', 'Border' }
local BUTTON_KEYS = { 'EnterDelveButton', 'StartDelveButton', 'ActivateButton', 'ConfirmButton', 'CancelButton', 'TieredEntranceViewRewardsButton' }
local DROPDOWN_KEYS = { 'Dropdown', 'DifficultyDropdown', 'TierDropdown' }
local CLOSE_KEYS = { 'CloseButton', 'ClosePanelButton', 'closeButton' }
local CLOSE_INSET = -4
local WINDOW_NAMES = { 'DelvesDifficultyPickerFrame', 'DelvesCompanionConfigurationFrame', 'DelvesCompanionAbilityListFrame' }
local FONT_DEPTH = 3
local SHELL_CLEAR = { 0, 0, 0, 0 }
local COVER_PAD = 6
local COVER_SUBLEVEL = -7

local skinnedWindows = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions = context.Fade, context.FadeRegions
local Shell, Close, Button, Dropdown, ScrollBar = context.Shell, context.Close, context.Button, context.Dropdown, context.ScrollBar
local CropIcon = Skin.CropIcon

local function CloseButtonOf(frame)
	for index = 1, #CLOSE_KEYS do
		local button = frame[CLOSE_KEYS[index]]
		if button and button.SetPoint then return button end
	end
	local name = frame.GetName and frame:GetName()
	local global = name and _G[name .. 'CloseButton']
	if global and global.SetPoint then return global end
	return nil
end

local function DelveCover(frame)
	local cover = frame._buiDelveCover
	if cover then return cover end
	cover = frame:CreateTexture(nil, 'BACKGROUND', nil, COVER_SUBLEVEL)
	cover.__buiSkin = true
	local fill = Skin.PANEL_FILL
	cover:SetColorTexture(fill[1], fill[2], fill[3], fill[4] or 1)
	cover:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -1, -1)
	cover:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -1, 1)
	frame._buiDelveCover = cover
	return cover
end

local function FitCover(frame)
	local rewards = frame.DelveRewardsContainerFrame
	if not rewards then return false end
	local right, left = frame:GetRight(), rewards:GetLeft()
	if not right or not left or right <= left then return false end
	DelveCover(frame):SetWidth(right - left + COVER_PAD)
	return true
end

local function SkinReward(row)
	if not row or row._buiDelveReward then return end
	row._buiDelveReward = true
	local icon = row.Icon
	if icon and icon.SetTexCoord then
		icon.__buiSkin = true
		CropIcon(icon)
		Skin.TipIconFrame(row, icon)
	end
	Fade(row.NameFrame)
	Fade(row.IconBorder)
	Skin.TipFaceTree(row, 2)
end

local function SkinWindow(frame)
	if not frame or frame._buiDelves or frame:IsForbidden() then return end
	frame._buiDelves = true
	skinnedWindows[#skinnedWindows + 1] = frame

	for index = 1, #CHROME_FRAMES do FadeRegions(frame[CHROME_FRAMES[index]]) end
	Shell(frame)
	BUILib.Skin.SetShellFill(frame, SHELL_CLEAR)
	local close = CloseButtonOf(frame)
	if close then
		Close(close)
		close:ClearAllPoints()
		close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', CLOSE_INSET, CLOSE_INSET)
	end
	ScrollBar(frame.ScrollBar)
	for index = 1, #BUTTON_KEYS do Button(frame[BUTTON_KEYS[index]]) end
	for index = 1, #DROPDOWN_KEYS do Dropdown(frame[DROPDOWN_KEYS[index]]) end
	local rewards = frame.DelveRewardsContainerFrame
	if rewards then
		FadeRegions(rewards)
		if rewards.ScrollBox then Skin.SweepScrollBox(rewards.ScrollBox, SkinReward) end
		frame:HookScript('OnShow', FitCover)
		if not FitCover(frame) then C_Timer.After(0, function() FitCover(frame) end) end
	end
	Skin.TipFaceTree(frame, FONT_DEPTH)
end

local function Apply()
	if not Enabled() then return end
	for index = 1, #WINDOW_NAMES do SkinWindow(_G[WINDOW_NAMES[index]]) end
end

Skin.OnToggle(SKIN_ID, function(enabled)
	context.Restore()
	if enabled then
		for index = 1, #skinnedWindows do skinnedWindows[index]._buiDelves = nil end
		Apply()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Delves',
	description = 'The delve entrance window where you pick a tier, plus the companion panels: the metal frame stripped off, the delve scene left alone.',
	icon = 'Interface/Icons/INV_Misc_Cave_01',
})

BUI.Events:Register('ADDON_LOADED', 'Skin.Delves', Apply)
BUI.Events:Once('PLAYER_LOGIN', 'Skin.Delves', Apply)
