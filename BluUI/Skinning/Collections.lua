local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning
local SELECTED, LABEL_TEXT, BODY_TEXT = Skin.SELECTED_COLOR, Skin.MUTED_COLOR, Skin.BODY_COLOR

local TAB_COUNT = 6
local MOUNT_INSET_KEYS = { 'LeftInset', 'BottomLeftInset', 'RightInset', 'MountCount' }
local MOUNT_DISPLAY_ART = { 'YesMountsTex', 'NoMountsTex' }
local PET_INSET_KEYS = { 'LeftInset', 'PetCardInset', 'RightInset', 'PetCount', 'loadoutBorder' }
local SPELL_SLOT_ART = { 'slotFrameCollected', 'slotFrameUncollected', 'slotFrameUncollectedInnerGlow' }
local TOY_BUTTON_COUNT = 18
local WARDROBE_TAB_KEYS = { 'ItemsTab', 'SetsTab' }
local ROW_SELECTED_ALPHA = 0.12
local ROW_HOVER_ALPHA = 0.06
local UNUSABLE_ROW_ALPHA = 0.12
local MUTED_TEXT_THRESHOLD = 0.6

local context = Skin.Define('collections', {
	name = 'Collections',
	description = 'Mounts, pets, toys, heirlooms, appearances and campsites: dark panels, clean lists, flat progress bars and library style search and filters.',
	icon = 'Interface/Icons/MountJournalPortrait',
})
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Tab, Body, Title, Paging = context.ScrollBar, context.Tab, context.Body, context.Title, context.Paging
local FlatTexture, SelectedTexture, CropIcon = Skin.FlatTexture, Skin.SelectedTexture, Skin.CropIcon

local function SetColor(fontString, color)
	fontString:SetTextColor(color[1], color[2], color[3], color[4])
end

local function IsMutedText(fontString)
	local red, green = fontString:GetTextColor()
	return red < MUTED_TEXT_THRESHOLD or green < MUTED_TEXT_THRESHOLD
end

local function SkinBackgroundFrame(frame)
	FadeRegions(frame)
	Fade(frame.NineSlice)
	Shell(frame)
end

local function SkinCountInset(inset)
	Body(inset.Count)
	Skin.TipFont(inset.Label, 'label')
end

local function SkinProgressBar(bar)
	if bar._buiProgress then return end
	bar._buiProgress = true
	Fade(bar.border)
	bar:SetStatusBarTexture(BUI.GetGlobalTexture())
	bar:SetStatusBarColor(SELECTED[1], SELECTED[2], SELECTED[3], 1)
	Shell(bar)
	Skin.TipFace(bar.text, 'body')
end

local function RefreshPaging(paging)
	Skin.RefreshPageButtons(paging.PrevPageButton, paging.NextPageButton)
end

local function SkinRowTextures(row, selected, highlight)
	selected:SetBlendMode('BLEND')
	SelectedTexture(selected, ROW_SELECTED_ALPHA)
	highlight:SetBlendMode('BLEND')
	FlatTexture(highlight, 1, 1, 1, ROW_HOVER_ALPHA)
end

local function RecolorName(name)
	SetColor(name, IsMutedText(name) and LABEL_TEXT or BODY_TEXT)
end

local function SkinListRow(row, icon)
	if row._buiRow then return end
	row._buiRow = true
	Fade(row.background)
	SkinRowTextures(row, row.selectedTexture, row:GetHighlightTexture())
	Skin.SquareIcon(row, icon)
	Skin.TipFace(row.name, 'body')
end

local function OnMountRow(button)
	SkinListRow(button, button.icon)
	if not button._buiFill then
		local fill = context.Own(button:CreateTexture(nil, 'BACKGROUND'))
		fill:SetAllPoints(button)
		button._buiFill = fill
	end
	local _, green = button.background:GetVertexColor()
	FlatTexture(button._buiFill, 1, 0, 0, green < MUTED_TEXT_THRESHOLD and UNUSABLE_ROW_ALPHA or 0)
	Skin.TipFace(button.name, 'body')
	RecolorName(button.name)
	Skin.TipFont(button.SteadyFlightLabel, 'label')
end

local function OnPetRow(pet)
	SkinListRow(pet, pet.icon)
	Skin.TipFace(pet.name, 'body')
	RecolorName(pet.name)
	Skin.TipFont(pet.subName, 'label')
end

local function OnSetsRow(row)
	if row._buiRow then return end
	row._buiRow = true
	Fade(row.Background)
	SkinRowTextures(row, row.SelectedTexture, row.HighlightTexture)
	Skin.SquareIcon(row.IconFrame, row.IconFrame.Icon)
	Skin.TipFace(row.Name, 'body')
	Skin.TipFace(row.Label, 'body')
end

local function SkinSpellButton(button)
	if button._buiSpell then return end
	button._buiSpell = true
	FadeKeys(button, SPELL_SLOT_ART)
	CropIcon(button.iconTextureUncollected)
	Skin.SquareIcon(button, button.iconTexture)
	Skin.TipFace(button.name, 'body')
end

local function OnToyButton(button)
	SkinSpellButton(button)
	RecolorName(button.name)
	RefreshPaging(_G.ToyBox.PagingFrame)
end

local function OnToyEvent(button)
	RecolorName(button.name)
end

local function OnHeirloomButton(journal, button)
	SkinSpellButton(button)
	RecolorName(button.name)
	RefreshPaging(journal.PagingFrame)
end

local function SkinMounts(journal)
	FadeKeys(journal, MOUNT_INSET_KEYS)
	SkinCountInset(journal.MountCount)
	EditBox(journal.searchBox)
	Dropdown(journal.FilterDropdown)
	ScrollBar(journal.ScrollBar)
	Button(journal.MountButton)
	local display = journal.MountDisplay
	FadeKeys(display, MOUNT_DISPLAY_ART)
	Shell(display)
	Title(display.NoMounts)
end

local function SkinPets(journal)
	FadeKeys(journal, PET_INSET_KEYS)
	SkinCountInset(journal.PetCount)
	EditBox(journal.searchBox)
	Dropdown(journal.FilterDropdown)
	ScrollBar(journal.ScrollBar)
	Button(journal.SummonButton)
	Button(journal.FindBattleButton)
end

local function SkinToys(toyBox)
	SkinProgressBar(toyBox.progressBar)
	EditBox(toyBox.searchBox)
	Dropdown(toyBox.FilterDropdown)
	SkinBackgroundFrame(toyBox.iconsFrame)
	Paging(toyBox.PagingFrame)
	for buttonIndex = 1, TOY_BUTTON_COUNT do SkinSpellButton(toyBox.iconsFrame['spellButton' .. buttonIndex]) end
end

local function SkinHeirlooms(journal)
	SkinProgressBar(journal.progressBar)
	EditBox(journal.SearchBox)
	Dropdown(journal.FilterDropdown)
	Dropdown(journal.ClassDropdown)
	SkinBackgroundFrame(journal.iconsFrame)
	Paging(journal.PagingFrame)
end

local function RefreshWardrobeTabs(frame)
	for _, key in ipairs(WARDROBE_TAB_KEYS) do
		local tab = frame[key]
		Skin.TipTabSelected(tab, tab:GetID() == frame.selectedTab)
	end
end

local function SkinWardrobe(frame)
	for _, key in ipairs(WARDROBE_TAB_KEYS) do Tab(frame[key]) end
	EditBox(frame.SearchBox)
	SkinProgressBar(frame.progressBar)
	Dropdown(frame.FilterButton)
	Dropdown(frame.ClassDropdown)
	local items = frame.ItemsCollectionFrame
	SkinBackgroundFrame(items)
	Paging(items.PagingFrame)
	Dropdown(items.WeaponDropdown)
	local sets = frame.SetsCollectionFrame
	Fade(sets.LeftInset.NineSlice)
	FadeRegions(sets.LeftInset)
	SkinBackgroundFrame(sets.RightInset)
	ScrollBar(sets.ListContainer.ScrollBar)
	Dropdown(sets.DetailsFrame.VariantSetsDropdown)
end

local function SkinWarbandScenes(journal)
	SkinBackgroundFrame(journal.IconsFrame)
	CheckBox(journal.IconsFrame.Icons.Controls.ShowOwned.Checkbox)
end

local function SkinMainFrame(frame)
	context.Chrome(frame)
	local tabs = {}
	for tabIndex = 1, TAB_COUNT do tabs[tabIndex] = _G['CollectionsJournalTab' .. tabIndex] end
	Skin.RegisterTabStrip(frame, tabs, context)
	SkinMounts(_G.MountJournal)
	SkinPets(_G.PetJournal)
	SkinToys(_G.ToyBox)
	SkinHeirlooms(_G.HeirloomsJournal)
	SkinWardrobe(_G.WardrobeCollectionFrame)
	SkinWarbandScenes(_G.WarbandSceneJournal)
end

local function OnTabsUpdated(frame)
	if frame == _G.WardrobeCollectionFrame and _G.CollectionsJournal:IsShown() then RefreshWardrobeTabs(frame) end
end

local function OnWardrobeItems(collection)
	RefreshPaging(collection.PagingFrame)
end

local function ShowJournal(frame)
	Skin.RefreshTabStrip(frame)
	RefreshWardrobeTabs(_G.WardrobeCollectionFrame)
end

local function InstallJournal()
	context.Hook('MountJournal_InitMountButton', OnMountRow)
	context.Hook('PetJournal_InitPetButton', OnPetRow)
	context.Hook('ToySpellButton_UpdateButton', OnToyButton)
	local toyEvent = BUI.Profiler.Wrap('Skin.Collections toy event', context.Guard(OnToyEvent))
	for buttonIndex = 1, TOY_BUTTON_COUNT do _G.ToyBox.iconsFrame['spellButton' .. buttonIndex]:HookScript('OnEvent', toyEvent) end
	context.Hook(_G.HeirloomsJournal, 'UpdateButton', OnHeirloomButton)
	context.Hook(_G.WardrobeCollectionFrame.ItemsCollectionFrame, 'UpdateItems', OnWardrobeItems)
	context.Hook(_G.WardrobeSetsScrollFrameButtonMixin, 'Init', OnSetsRow)
	context.Hook('PanelTemplates_UpdateTabs', OnTabsUpdated)
end

context.Window('CollectionsJournal', { install = InstallJournal, skin = SkinMainFrame, show = ShowJournal })
