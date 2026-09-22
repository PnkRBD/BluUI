local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('DressUp')

local hooksecurefunc = BUI.Prof.MakeHooker('dressup')
local ipairs = ipairs

local Skin = BUI.Skinning

local SKIN_ID = 'dressup'
local MAIN_ART = { 'Bg', 'TopTileStreaks', 'Inset', 'ModelBackground' }
local PANEL_INSET = 6
local SET_TITLE_SCALE = 1.2
local ROW_SELECTED_ALPHA = 0.2
local ROW_HOVER_ALPHA = 0.06
local BOTTOM_BUTTON_KEYS = { 'LinkButton', 'ResetButton' }

local installed = false
local skinned = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, Dropdown = context.Shell, context.Button, context.Close, context.Dropdown
local ScrollBar, Title = context.ScrollBar, context.Title
local FlatTexture, AccentTexture, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.CropIcon

local function SkinSetRow(row)
	if not Enabled() or row._buiRow then return end
	row._buiRow = true
	Fade(row.BackgroundTexture)
	row.SelectedTexture:SetBlendMode('BLEND')
	AccentTexture(row.SelectedTexture, ROW_SELECTED_ALPHA)
	row.HighlightTexture:SetBlendMode('BLEND')
	FlatTexture(row.HighlightTexture, 1, 1, 1, ROW_HOVER_ALPHA)
	CropIcon(row.Icon)
	Skin.TipFace(row.ItemName, 'title')
	Skin.TipFace(row.ItemSlot, 'body')
end

local function OnSlotDetails(slot)
	if Enabled() then Skin.TipFace(slot.Name, 'body') end
end

local function SkinSidePanel(panel)
	if not panel then return end
	FadeRegions(panel)
	Shell(panel, PANEL_INSET)
end

local function SkinSetSelection(panel)
	if not panel then return end
	SkinSidePanel(panel)
	Skin.TipFont(panel.SetName, 'title', SET_TITLE_SCALE)
	ScrollBar(panel.ScrollBar)
	Skin.SweepScrollBox(panel.ScrollBox, SkinSetRow)
end

local function SkinCustomSetDropdown(dropdown)
	if not dropdown then return end
	Dropdown(dropdown)
	for _, child in ipairs({ dropdown:GetChildren() }) do
		if child:IsObjectType('Button') and child.GetText and child:GetText() then Button(child) end
	end
end

local function SkinMaximize(frame)
	if not frame then return end
	Skin.TipPageButton(frame.MaximizeButton, 'expand')
	Skin.TipPageButton(frame.MinimizeButton, 'condense')
end

local function SkinMainFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	FadeRegions(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
	SkinCustomSetDropdown(frame.CustomSetDropdown)
	SkinMaximize(frame.MaximizeMinimizeFrame)
	for _, key in ipairs(BOTTOM_BUTTON_KEYS) do Button(frame[key]) end
	Button(_G.DressUpFrameCancelButton)
	SkinSidePanel(frame.CustomSetDetailsPanel)
	SkinSetSelection(frame.SetSelectionPanel)
end

local function SkinSideDressUp(frame)
	if not frame then return end
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	FadeRegions(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Button(frame.ResetButton)
	Close(frame.CloseButton or _G.SideDressUpFrameCloseButton)
end

local function ApplySide()
	local frame = _G.SideDressUpFrame
	if not frame or frame:IsForbidden() or not Enabled() or frame._buiSideSkinned then return end
	frame._buiSideSkinned = true
	SkinSideDressUp(frame)
end

local function Apply()
	ApplySide()
	local frame = _G.DressUpFrame
	if not frame or frame:IsForbidden() or not Enabled() or skinned then return end
	skinned = true
	SkinMainFrame(frame)
end

local function Install()
	if installed then return end
	local frame = _G.DressUpFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	if _G.SideDressUpFrame then HookScript(_G.SideDressUpFrame, 'OnShow', ApplySide) end
	local slotMixin = _G.DressUpCustomSetDetailsSlotMixin
	if slotMixin and slotMixin.SetDetails then hooksecurefunc(slotMixin, 'SetDetails', OnSlotDetails) end
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.DressUp') end
end

local function Deactivate()
	context.Restore()
	skinned = false
	if _G.SideDressUpFrame then _G.SideDressUpFrame._buiSideSkinned = nil end
	BUI.Print('Dressing Room skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.DressUp', TryInstall)
		elseif _G.DressUpFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Dressing Room',
	description = 'The dressing room and its outfit panels: dark shell, house buttons and dropdown, flat set list and glyph maximize buttons.',
	icon = 'Interface/Icons/INV_Chest_Cloth_17',
})

BUI.Events:Once('PLAYER_LOGIN', 'Skin.DressUpInstall', function()
	if not Enabled() then return end
	Install()
	if not installed then BUI.Events:Register('ADDON_LOADED', 'Skin.DressUp', TryInstall) end
end)
