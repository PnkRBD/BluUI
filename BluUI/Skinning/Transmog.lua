local _, BUI = ...

local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SLOT_ART_KEYS = { 'Border', 'ShowEquippedIcon' }
local SLOT_KEEP_KEYS = { 'Icon', 'DisabledIcon', 'HiddenVisualIcon' }
local SLOT_POOLS = { 'CharacterAppearanceSlotFramePool', 'CharacterIllusionSlotFramePool' }
local TOGGLE_KEYS = { 'HideIgnoredToggle', 'SheatheWeaponToggle', 'PreviewedWeaponToggle' }
local OUTFIT_ART = { 'NormalTexture', 'HighlightTexture', 'Selected', 'SelectedPurple', 'Glow', 'GlowPurple' }
local ITEM_MODEL_ART = { 'Border', 'BorderHighlight', 'StateTexture' }
local SET_MODEL_ART = { 'Border', 'Highlight', 'TransmogStateTexture' }
local PAGED_FRAMES = { 'ItemsFrame', 'SetsFrame', 'CustomSetsFrame' }
local DROPDOWN_KEYS = { 'FilterButton', 'WeaponDropdown', 'WeaponSheatheDropdown' }
local DISPLAY_ICON = { scale = 0.8, x = 4, textX = 42 }
local TABS = { x = 23, y = -22, level = 10 }
local NEW_SET = { x = -29, y = -22 }

local context = Skin.Define('transmog', {
	name = 'Transmogrify',
	description = 'The transmogrifier at the vendor: outfit cards, framed slot icons around the model, item and set cards with an accent edge on the applied look, and the appearance tabs on the house tab strip.',
	icon = 'Interface/Icons/INV_Arcane_Orb',
	newLook = true,
})
local Hook = context.Hook
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Card, CheckBox = context.Shell, context.Button, context.Card, context.CheckBox
local Dropdown, EditBox, ScrollBar = context.Dropdown, context.EditBox, context.ScrollBar
local Body, Title = context.Body, context.Title
local CropIcon = Skin.CropIcon

local function KeepKeys(frame, keys)
	for _, key in ipairs(keys) do
		local texture = frame[key]
		if texture then texture.__buiSkin = true end
	end
end

local function AccentIconEdge(icon, active)
	if active then
		Skin.SetIconEdgeColor(icon, BUILib.Theme.GetAccent())
	else
		Skin.SetIconEdgeColor(icon)
	end
end

local function FramedIcon(owner, icon)
	CropIcon(icon)
	Skin.TipIconFrame(owner, icon)
end

local function PaintOutfit(entry)
	local button = entry.OutfitButton
	local text = button.TextContent
	local selected = button.Selected:IsShown()
	Skin.SetActiveEdge(button, selected)
	Skin.TipFont(text.Name, selected and 'title' or 'body')
	Skin.TipFont(text.SituationInfo, 'label')
	text:Layout()
	AccentIconEdge(entry.OutfitIcon.Icon, entry.OutfitIcon.OverlayActive:IsShown())
end

local function SkinOutfit(entry)
	if not entry._buiOutfit then
		entry._buiOutfit = true
		local icon = entry.OutfitIcon
		Fade(icon.Border)
		Fade(icon.OverlayActive)
		Fade(icon:GetHighlightTexture())
		FramedIcon(icon, icon.Icon)
		FadeKeys(entry.OutfitButton, OUTFIT_ART)
		Hook(entry, 'SetSelected', PaintOutfit)
	end
	Card(entry.OutfitButton)
	PaintOutfit(entry)
end

local function SkinOutfits(outfits)
	FadeRegions(outfits)
	Body(outfits.UsableDiscountText)
	local spell = outfits.ShowEquippedGearSpellFrame
	Fade(spell.Button.Border)
	Fade(spell.OverlayFX.OverlayActive)
	FramedIcon(spell.Button, spell.Button.Icon)
	Title(spell.Label)
	FadeRegions(outfits.OutfitList)
	ScrollBar(outfits.OutfitList.ScrollBar)
	Skin.SweepScrollBox(outfits.OutfitList.ScrollBox, context.Guard(SkinOutfit))
	local purchase = outfits.PurchaseOutfitButton
	purchase.Icon.__buiSkin = true
	Button(purchase)
	Button(outfits.SaveOutfitButton)
	FadeRegions(outfits.MoneyFrame)
end

local function PaintSlot(slot)
	AccentIconEdge(slot.Icon, slot.SelectedFrame:IsShown())
end

local function SkinSlot(slot)
	if not slot._buiSlot then
		slot._buiSlot = true
		KeepKeys(slot, SLOT_KEEP_KEYS)
		FadeRegions(slot)
		FadeKeys(slot, SLOT_ART_KEYS)
		Fade(slot.SelectedFrame.Border)
		CropIcon(slot.Icon)
		Skin.TipIconFrame(slot, slot.Icon, 1)
		Hook(slot, 'SetSelected', PaintSlot)
	end
	PaintSlot(slot)
end

local function SweepSlots(preview)
	for _, key in ipairs(SLOT_POOLS) do
		for slot in preview[key]:EnumerateActive() do SkinSlot(slot) end
	end
end

local function SkinPreview(preview)
	FadeRegions(preview)
	Fade(preview.Gradients)
	for _, key in ipairs(TOGGLE_KEYS) do
		local toggle = preview.ToggleOptions[key]
		CheckBox(toggle.Checkbox)
		Body(toggle.Text)
	end
	preview.ClearAllPendingButton.Icon.__buiSkin = true
	Button(preview.ClearAllPendingButton)
	SweepSlots(preview)
end

local function PaintDisplayButtons(items)
	for _, button in ipairs({ items.DisplayTypes:GetChildren() }) do
		if button.StateTexture then
			button:GetNormalTexture():SetAlpha(0)
			Skin.TipButtonFonts(button)
			Skin.SetActiveEdge(button, button.StateTexture:IsShown())
		end
	end
end

local function SkinDisplayButtons(items)
	for _, button in ipairs({ items.DisplayTypes:GetChildren() }) do
		if button.StateTexture then
			Button(button)
			Fade(button.StateTexture)
			local iconFrame = button.IconFrame
			Fade(iconFrame.Border)
			iconFrame:SetScale(DISPLAY_ICON.scale)
			iconFrame:ClearAllPoints()
			iconFrame:SetPoint('LEFT', button, 'LEFT', DISPLAY_ICON.x / DISPLAY_ICON.scale, 0)
			button.Text:SetPoint('LEFT', button, 'LEFT', DISPLAY_ICON.textX, 1)
		end
	end
	PaintDisplayButtons(items)
end

local function ThemedDropdown(dropdown)
	Dropdown(dropdown)
	Skin.TipFont(dropdown.Text, 'body')
end

local function SkinPager(paged)
	local content = paged.PagedContent
	local controls = content.PagingControls
	Skin.TipPageButton(controls.PrevPageButton, 'previous')
	Skin.TipPageButton(controls.NextPageButton, 'next')
	Body(controls.PageText)
	Body(content.NoEntriesText)
end

local function SkinItems(items)
	Skin.TipFont(items.ActiveSlotTitle, 'title', 1.5)
	for _, key in ipairs(DROPDOWN_KEYS) do ThemedDropdown(items[key]) end
	SkinDisplayButtons(items)
	local toggle = items.SecondaryAppearanceToggle
	CheckBox(toggle.Checkbox)
	Body(toggle.Text)
end

local function SkinSituations(situations)
	Body(situations.DescriptionText)
	Button(situations.DefaultsButton)
	Button(situations.ApplyButton)
	CheckBox(situations.EnabledToggle.Checkbox)
	Body(situations.EnabledToggle.Text)
end

local function SkinWardrobe(collection)
	FadeRegions(collection)
	local content = collection.TabContent
	FadeRegions(content)
	Shell(content)
	local headers = collection.TabHeaders
	for _, tab in ipairs(headers.tabs) do Fade(tab.SelectedHighlight) end
	context.SegmentTabs(headers)
	headers:ClearAllPoints()
	headers:SetPoint('TOPLEFT', content, 'TOPLEFT', TABS.x, TABS.y)
	headers:SetFrameLevel(content:GetFrameLevel() + TABS.level)
	for _, key in ipairs(PAGED_FRAMES) do
		local paged = content[key]
		ThemedDropdown(paged.FilterButton)
		EditBox(paged.SearchBox)
		SkinPager(paged)
	end
	SkinItems(content.ItemsFrame)
	local newSet = content.CustomSetsFrame.NewCustomSetButton
	Button(newSet)
	newSet:ClearAllPoints()
	newSet:SetPoint('TOPRIGHT', content.CustomSetsFrame, 'TOPRIGHT', NEW_SET.x, NEW_SET.y)
	SkinSituations(content.SituationsFrame)
end

local function SkinModel(model, art, state)
	if not model._buiModel then
		model._buiModel = true
		FadeKeys(model, art)
	end
	Card(model)
	Skin.SetActiveEdge(model, model[state]:IsShown())
end

local function OnItemModel(model)
	SkinModel(model, ITEM_MODEL_ART, 'StateTexture')
end

local function OnSetModel(model)
	SkinModel(model, SET_MODEL_ART, 'TransmogStateTexture')
end

local function SkinFrame(frame)
	context.Chrome(frame)
	SkinOutfits(frame.OutfitCollection)
	SkinPreview(frame.CharacterPreview)
	SkinWardrobe(frame.WardrobeCollection)
	Skin.TipIconPopup(context, frame.OutfitPopup)
end

local function InstallFrame(frame)
	Hook(frame.CharacterPreview, 'SetupSlots', SweepSlots)
	Hook(frame.WardrobeCollection.TabContent.ItemsFrame, 'RefreshDisplayTypeButtons', PaintDisplayButtons)
	Hook(TransmogItemModelMixin, 'UpdateItemBorder', OnItemModel)
	Hook(TransmogSetModelMixin, 'UpdateSet', OnSetModel)
	Hook(TransmogCustomSetModelMixin, 'UpdateSet', OnSetModel)
end

local function RefreshFrame(frame)
	SweepSlots(frame.CharacterPreview)
end

context.Window('TransmogFrame', { skin = SkinFrame, show = RefreshFrame, install = InstallFrame })
