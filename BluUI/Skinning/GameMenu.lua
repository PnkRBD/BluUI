local _, BUI = ...

local ipairs = ipairs
local max = math.max

local BUILib = BluUI.BUILibClient
local Skin = BUI.Skinning

local BUTTON_HEIGHT = 30
local CARD_INSET = 1
local CARD_SIDE = 18
local CARD_INSETS = { left = CARD_SIDE, right = CARD_SIDE, top = CARD_INSET, bottom = CARD_INSET }
local SECTION_GAP = 12
local PANEL_PAD = 24
local DIM_ALPHA = 0.6
local NEW_TAG_KEYS = { 'NewOptionsFrame', 'NewExternalEventFrame' }

local context = Skin.Define('gameMenu', {
	name = 'Game Menu',
	description = 'The Escape menu in the dark shell, with card buttons and a BluUI shortcut on top.',
	icon = 'Interface\\Icons\\INV_Misc_Gear_01',
	newLook = true,
})
local Fade, Shell, Card = context.Fade, context.Shell, context.Card

local shortcut, dim

local function SkinPoolButton(button)
	if not button._buiMenuButton then
		button._buiMenuButton = true
		BUILib.Skin.StripButton(button)
		Skin.TipButtonFonts(button)
		button:SetHeight(BUTTON_HEIGHT)
	end
	if button.topPadding then button.topPadding = SECTION_GAP end
	button._buiHoverEdge = nil
	Card(button, CARD_INSETS)
end

local function SkinButtons(frame)
	for button in frame.buttonPool:EnumerateActive() do SkinPoolButton(button) end
end

local function OpenBluUI()
	HideUIPanel(GameMenuFrame)
	BUI.PageEngine.Toggle()
end

local function BuildShortcut(frame)
	local button = CreateFrame('Button', nil, frame)
	local bottom = SECTION_GAP - frame.topPadding
	button:SetPoint('BOTTOMLEFT', frame, 'TOPLEFT', frame.leftPadding, bottom)
	button:SetPoint('BOTTOMRIGHT', frame, 'TOPRIGHT', -frame.rightPadding, bottom)
	button:SetHeight(BUTTON_HEIGHT)
	button:SetScript('OnClick', BUI.Profiler.Script('Skin.GameMenu shortcut OnClick', OpenBluUI))
	Skin.TipButtonFonts(button)
	button:SetText('BluUI')
	button:Hide()
	return button
end

local function SwallowWheel() end

local function BuildDim()
	local frame = CreateFrame('Frame', nil, UIParent)
	frame:SetAllPoints()
	frame:EnableMouse(true)
	frame:EnableMouseWheel(true)
	frame:SetScript('OnMouseWheel', BUI.Profiler.Timed('Skinning.GameMenu BuildDim frame OnMouseWheel', SwallowWheel))
	local fill = BUI.Painter.Fill(frame:CreateTexture(nil, 'BACKGROUND'), 'skinBackground')
	fill:SetAllPoints()
	fill:SetAlpha(DIM_ALPHA)
	frame:Hide()
	return frame
end

local function PanelInsets(frame)
	return {
		left = frame.leftPadding + CARD_SIDE - PANEL_PAD,
		right = frame.rightPadding + CARD_SIDE - PANEL_PAD,
		top = frame.topPadding - SECTION_GAP - BUTTON_HEIGHT + CARD_INSET - PANEL_PAD,
		bottom = frame.bottomPadding + CARD_INSET - PANEL_PAD,
	}
end

local function SkinMenu(frame)
	Fade(frame.Border)
	Fade(frame.Header)
	for _, key in ipairs(NEW_TAG_KEYS) do Fade(frame[key]) end
	Shell(frame, PanelInsets(frame))
	Card(shortcut, CARD_INSETS)
	Skin.SetAccentEdge(shortcut, true)
	shortcut:Show()
	SkinButtons(frame)
end

local function ShowMenu(frame)
	dim:SetFrameStrata(frame:GetFrameStrata())
	dim:SetFrameLevel(max(0, frame:GetFrameLevel() - 1))
	dim:Show()
end

local function HideDim()
	dim:Hide()
end

context.Window('GameMenuFrame', {
	skin = SkinMenu,
	show = ShowMenu,
	install = function(frame)
		shortcut = BuildShortcut(frame)
		dim = BuildDim()
		context.Hook(frame, 'InitButtons', SkinButtons)
		frame:HookScript('OnHide', BUI.Profiler.Wrap('Skin.GameMenu dim hide', HideDim))
	end,
})

context.OnDisable(function()
	if not shortcut then return end
	shortcut:Hide()
	dim:Hide()
end)
