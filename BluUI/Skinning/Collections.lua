local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning
local SELECTED = Skin.SELECTED_COLOR

local COLLECTIONS_ADDON = 'Blizzard_Collections'
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
local BODY_TEXT = { 0.87, 0.87, 0.9, 1 }
local LABEL_TEXT = { 0.55, 0.55, 0.6, 1 }

local context = Skin.Define('collections', {
	name = 'Collections',
	description = 'Mounts, pets, toys, heirlooms, appearances and campsites: dark panels, clean lists, flat progress bars and library style search and filters.',
	icon = 'Interface/Icons/MountJournalPortrait',
	test = function()
		C_AddOns.LoadAddOn(COLLECTIONS_ADDON)
		local frame = _G.CollectionsJournal
		if not frame:IsShown() then ToggleCollectionsJournal(1) end
		return frame
	end,
	stopTest = function()
		if _G.CollectionsJournal then HideUIPanel(_G.CollectionsJournal) end
	end,
})
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Tab, Body, Title = context.ScrollBar, context.Tab, context.Body, context.Title
local FlatTexture, SelectedTexture, CropIcon = Skin.FlatTexture, Skin.SelectedTexture, Skin.CropIcon

local function SetColor(fontString, color)
	if fontString then fontString:SetTextColor(color[1], color[2], color[3], color[4]) end
end

local function IsMutedText(fontString)
	local red, green = fontString:GetTextColor()
	return red < MUTED_TEXT_THRESHOLD or green < MUTED_TEXT_THRESHOLD
end

local function SkinBackgroundFrame(frame)
	if not frame then return end
	FadeRegions(frame)
	Fade(frame.NineSlice)
	Shell(frame)
end

local function SkinCountInset(inset)
	if not inset then return end
	Body(inset.Count)
	Skin.TipFont(inset.Label, 'label')
end

local function SkinProgressBar(bar)
	if not bar or bar._buiProgress then return end
	bar._buiProgress = true
	Fade(bar.border)
	bar:SetStatusBarTexture(BUI.GetGlobalTexture())
	bar:SetStatusBarColor(SELECTED[1], SELECTED[2], SELECTED[3], 1)
	Shell(bar)
	Skin.TipFace(bar.text, 'body')
end

local function SkinPaging(paging)
	if not paging then return end
	Skin.TipPageButton(paging.PrevPageButton, 'previous')
	Skin.TipPageButton(paging.NextPageButton, 'next')
	Body(paging.PageText)
end

local function RefreshPaging(paging)
	if not paging then return end
	Skin.RefreshPageButton(paging.PrevPageButton)
	Skin.RefreshPageButton(paging.NextPageButton)
end

local function SkinRowTextures(row, selected, highlight)
	if selected then
		selected:SetBlendMode('BLEND')
		SelectedTexture(selected, ROW_SELECTED_ALPHA)
	end
	if highlight then
		highlight:SetBlendMode('BLEND')
		FlatTexture(highlight, 1, 1, 1, ROW_HOVER_ALPHA)
	end
end

local function RecolorName(name)
	SetColor(name, IsMutedText(name) and LABEL_TEXT or BODY_TEXT)
end

local function SkinListRow(row, icon)
	if row._buiRow then return end
	row._buiRow = true
	Fade(row.background)
	SkinRowTextures(row, row.selectedTexture, row:GetHighlightTexture())
	CropIcon(icon)
	Skin.TipIconFrame(row, icon)
	Skin.TipFace(row.name, 'body')
end

local function OnMountRow(button)
	SkinListRow(button, button.icon)
	if not button._buiFill then
		local fill = button:CreateTexture(nil, 'BACKGROUND')
		fill.__buiSkin = true
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
	if row.IconFrame then
		CropIcon(row.IconFrame.Icon)
		Skin.TipIconFrame(row.IconFrame, row.IconFrame.Icon)
	end
	Skin.TipFace(row.Name, 'body')
	Skin.TipFace(row.Label, 'body')
end

local function SkinSpellButton(button)
	if not button or button._buiSpell then return end
	button._buiSpell = true
	FadeKeys(button, SPELL_SLOT_ART)
	CropIcon(button.iconTexture)
	CropIcon(button.iconTextureUncollected)
	Skin.TipIconFrame(button, button.iconTexture)
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
	if not journal then return end
	FadeKeys(journal, MOUNT_INSET_KEYS)
	SkinCountInset(journal.MountCount)
	EditBox(journal.searchBox)
	Dropdown(journal.FilterDropdown)
	ScrollBar(journal.ScrollBar)
	Button(journal.MountButton)
	local display = journal.MountDisplay
	if display then
		FadeKeys(display, MOUNT_DISPLAY_ART)
		Shell(display)
		Title(display.NoMounts)
	end
end

local function SkinPets(journal)
	if not journal then return end
	FadeKeys(journal, PET_INSET_KEYS)
	SkinCountInset(journal.PetCount)
	EditBox(journal.searchBox)
	Dropdown(journal.FilterDropdown)
	ScrollBar(journal.ScrollBar)
	Button(journal.SummonButton)
	Button(journal.FindBattleButton)
end

local function SkinToys(toyBox)
	if not toyBox then return end
	SkinProgressBar(toyBox.progressBar)
	EditBox(toyBox.searchBox)
	Dropdown(toyBox.FilterDropdown)
	SkinBackgroundFrame(toyBox.iconsFrame)
	SkinPaging(toyBox.PagingFrame)
	for buttonIndex = 1, TOY_BUTTON_COUNT do SkinSpellButton(toyBox.iconsFrame['spellButton' .. buttonIndex]) end
end

local function SkinHeirlooms(journal)
	if not journal then return end
	SkinProgressBar(journal.progressBar)
	EditBox(journal.SearchBox)
	Dropdown(journal.FilterDropdown)
	Dropdown(journal.ClassDropdown)
	SkinBackgroundFrame(journal.iconsFrame)
	SkinPaging(journal.PagingFrame)
end

local function RefreshWardrobeTabs(frame)
	for _, key in ipairs(WARDROBE_TAB_KEYS) do
		local tab = frame[key]
		if tab then Skin.TipTabSelected(tab, tab:GetID() == frame.selectedTab) end
	end
end

local function SkinWardrobe(frame)
	if not frame then return end
	for _, key in ipairs(WARDROBE_TAB_KEYS) do Tab(frame[key]) end
	EditBox(frame.SearchBox)
	SkinProgressBar(frame.progressBar)
	Dropdown(frame.FilterButton)
	Dropdown(frame.ClassDropdown)
	local items = frame.ItemsCollectionFrame
	if items then
		SkinBackgroundFrame(items)
		SkinPaging(items.PagingFrame)
		Dropdown(items.WeaponDropdown)
	end
	local sets = frame.SetsCollectionFrame
	if sets then
		Fade(sets.LeftInset and sets.LeftInset.NineSlice)
		if sets.LeftInset then FadeRegions(sets.LeftInset) end
		SkinBackgroundFrame(sets.RightInset)
		if sets.ListContainer then ScrollBar(sets.ListContainer.ScrollBar) end
		if sets.DetailsFrame then Dropdown(sets.DetailsFrame.VariantSetsDropdown) end
	end
end

local function SkinWarbandScenes(journal)
	if not journal then return end
	SkinBackgroundFrame(journal.IconsFrame)
	local controls = journal.Controls or (journal.IconsFrame and journal.IconsFrame.Controls)
	if controls and controls.ShowOwned then CheckBox(controls.ShowOwned.Checkbox) end
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
	if _G.WardrobeCollectionFrame then RefreshWardrobeTabs(_G.WardrobeCollectionFrame) end
end

local function InstallJournal()
	context.Hook('MountJournal_InitMountButton', OnMountRow)
	context.Hook('PetJournal_InitPetButton', OnPetRow)
	context.Hook('ToySpellButton_UpdateButton', OnToyButton)
	local toyEvent = BUI.Profiler.Wrap('Skin.Collections toy event', context.Guard(OnToyEvent))
	for buttonIndex = 1, TOY_BUTTON_COUNT do _G.ToyBox.iconsFrame['spellButton' .. buttonIndex]:HookScript('OnEvent', toyEvent) end
	context.Hook(_G.HeirloomsJournal, 'UpdateButton', OnHeirloomButton)
	local items = _G.WardrobeCollectionFrame and _G.WardrobeCollectionFrame.ItemsCollectionFrame
	if items then context.Hook(items, 'UpdateItems', OnWardrobeItems) end
	local setsMixin = _G.WardrobeSetsScrollFrameButtonMixin
	if setsMixin then context.Hook(setsMixin, 'Init', OnSetsRow) end
	context.Hook('PanelTemplates_UpdateTabs', OnTabsUpdated)
end

context.Window('CollectionsJournal', { install = InstallJournal, skin = SkinMainFrame, show = ShowJournal })
