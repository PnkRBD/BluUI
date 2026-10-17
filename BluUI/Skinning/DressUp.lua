local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local PANEL_INSET = 6
local SET_TITLE_SCALE = 1.2
local ROW_SELECTED_ALPHA = 0.12
local ROW_HOVER_ALPHA = 0.06
local BOTTOM_BUTTON_KEYS = { 'LinkButton', 'ResetButton' }

local context = Skin.Define('dressup', {
	name = 'Dressing Room',
	description = 'The dressing room and its outfit panels: dark shell, library buttons and dropdown, flat set list and glyph maximize buttons.',
	icon = 'Interface/Icons/INV_Chest_Cloth_17',
})
local Enabled = context.Enabled
local Fade, FadeRegions = context.Fade, context.FadeRegions
local Shell, Button, Close, Dropdown = context.Shell, context.Button, context.Close, context.Dropdown
local ScrollBar = context.ScrollBar
local FlatTexture, SelectedTexture, CropIcon = Skin.FlatTexture, Skin.SelectedTexture, Skin.CropIcon

local function SkinSetRow(row)
	if not Enabled() then return end
	Fade(row.BackgroundTexture)
	if row._buiRow then return end
	row._buiRow = true
	row.SelectedTexture:SetBlendMode('BLEND')
	SelectedTexture(row.SelectedTexture, ROW_SELECTED_ALPHA)
	row.HighlightTexture:SetBlendMode('BLEND')
	FlatTexture(row.HighlightTexture, 1, 1, 1, ROW_HOVER_ALPHA)
	CropIcon(row.Icon)
	Skin.TipFace(row.ItemName, 'title')
	Skin.TipFace(row.ItemSlot, 'body')
end

local function OnSlotDetails(slot)
	Skin.TipFace(slot.Name, 'body')
end

local function SkinSidePanel(panel)
	FadeRegions(panel)
	Shell(panel, PANEL_INSET)
end

local function SkinSetSelection(panel)
	SkinSidePanel(panel)
	Skin.TipFont(panel.SetName, 'title', SET_TITLE_SCALE)
	ScrollBar(panel.ScrollBar)
	Skin.SweepScrollBox(panel.ScrollBox, SkinSetRow)
end

local function SkinMainFrame(frame)
	context.Chrome(frame)
	Dropdown(frame.CustomSetDropdown)
	Button(frame.CustomSetDropdown.SaveButton)
	for _, key in ipairs(BOTTOM_BUTTON_KEYS) do Button(frame[key]) end
	Button(_G.DressUpFrameCancelButton)
	SkinSidePanel(frame.CustomSetDetailsPanel)
	SkinSetSelection(frame.SetSelectionPanel)
end

local function SkinSideFrame(frame)
	FadeRegions(frame)
	Shell(frame)
	Button(frame.ResetButton)
	Close(_G.SideDressUpFrameCloseButton)
end

local function InstallFrame()
	context.Hook(DressUpCustomSetDetailsSlotMixin, 'SetUp', OnSlotDetails)
end

context.Window('DressUpFrame', { skin = SkinMainFrame, install = InstallFrame })
context.Window('SideDressUpFrame', { skin = SkinSideFrame })
