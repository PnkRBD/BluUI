local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning
local BUILib = BluUI.BUILibClient or LibStub('BUILib')

local BOOK_ART = { 'TopBar', 'BookBGHalved', 'BookBGLeft', 'BookBGRight', 'BookCornerFlipbook', 'Bookmark' }
local ITEM_ART = { 'Border', 'BorderSheen', 'IconHighlight' }
local TALENT_CHROME = { 'BlackBG', 'BottomBar' }
local PVP_LIST_ART = { 'Top', 'Middle', 'Bottom' }
local PVP_ROW_ART = { 'Border', 'Selected' }
local SPEC_ART = { 'BlackBG', 'Background' }
local DIALOG_BUTTON_KEYS = { 'AcceptButton', 'CancelButton', 'DeleteButton' }
local LOADOUT_DIALOG_NAMES = { 'ClassTalentLoadoutImportDialog', 'ClassTalentLoadoutCreateDialog', 'ClassTalentLoadoutEditDialog' }
local DIVIDER_INSET = 20
local TREE_ART_ALPHA = 0.7
local RESULT_ROW_HIGHLIGHT_ALPHA = 0.08
local SCALE = {
	name = 1.15, header = 1.4, currencyLabel = 1.3, currencyAmount = 2,
	heroLabel = 1.3, heroChoose = { 1.2, 1.6 }, heroLocked = { 1.3, 1.1 }, heroPoints = 1.8, heroSpecName = 1.8,
	specName = 2.2, specText = 1.2, specActive = 1.3,
}

local context = Skin.Define('spellbook', {
	name = 'Spellbook',
	description = 'The spellbook, talents and specialization window: dark pages, framed spell icons, segmented category tabs, card rows for PvP talents, dimmed talent tree, loadout and hero talent dialogs.',
	icon = 'Interface/Icons/INV_Misc_Book_09',
	newLook = true,
})
local Hook = context.Hook
local Fade, FadeRegions, FadeKeys, FadeArt = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt
local Shell, Button, Card, Dropdown, EditBox, CheckBox, TextBox = context.Shell, context.Button, context.Card, context.Dropdown, context.EditBox, context.CheckBox, context.TextBox
local ScrollBar, Face, Body, Title = context.ScrollBar, context.Face, context.Body, context.Title
local CropIcon = Skin.CropIcon

local dimmed = {}

local function Refade(texture)
	Fade(texture)
	texture:SetAlpha(0)
end

local function AccentIconEdge(icon, active)
	if active then
		Skin.SetIconEdgeColor(icon, BUILib.Theme.GetAccent())
	else
		Skin.SetIconEdgeColor(icon)
	end
end

local function StyleSpellItem(item)
	if item:IsForbidden() then return end
	local button = item.Button
	Fade(item.Backplate)
	FadeKeys(button, ITEM_ART)
	if item._buiSpell then return end
	item._buiSpell = true
	CropIcon(button.Icon)
	Skin.TipIconFrame(button, button.Icon)
	Skin.TipFont(item.Name, 'title', SCALE.name)
	Skin.TipFont(item.SubName, 'label')
	Skin.TipFont(item.RequiredLevel, 'label')
end

local function OnSpellEnter(item)
	Refade(item.Backplate)
	AccentIconEdge(item.Button.Icon, true)
end

local function OnSpellLeave(item)
	Refade(item.Backplate)
	Refade(item.Button.IconHighlight)
	AccentIconEdge(item.Button.Icon, false)
end

local function StyleHeader(header)
	if header:IsForbidden() then return end
	Fade(header.Backplate)
	Fade(header.Border)
	Skin.TipFont(header.Text, 'title', SCALE.header)
	if header._buiDivider then return end
	local line = context.Own(header:CreateTexture(nil, 'OVERLAY'))
	line:SetHeight(1)
	BUI.Painter.Fill(line, 'skinBorder')
	BUILib.Skin.PixelLine(line, header.Border, false, DIVIDER_INSET, 0)
	header._buiDivider = line
end

local function StylePages(book)
	for _, element in book.PagedSpellsFrame:EnumerateFrames() do
		if element.Button then
			StyleSpellItem(element)
		elseif element.Border then
			StyleHeader(element)
		end
	end
end

local function StyleSearchPreview(container)
	for _, child in ipairs({ container:GetChildren() }) do
		if child:IsObjectType('Button') then
			if not child._buiPreviewRow then
				child._buiPreviewRow = true
				child.HighlightTexture:SetColorTexture(1, 1, 1, RESULT_ROW_HIGHLIGHT_ALPHA)
				child.HighlightTexture:SetBlendMode('BLEND')
				CropIcon(child.Icon)
			end
			Skin.TipFaceTree(child, 1, 'body')
		end
	end
end

local function SkinSearchPreview(container)
	FadeArt(container)
	Shell(container)
	StyleSearchPreview(container)
end

local function SkinSpellBook(book)
	FadeRegions(book)
	FadeKeys(book, BOOK_ART)
	context.SegmentTabs(book.CategoryTabSystem)
	EditBox(book.SearchBox)
	SkinSearchPreview(book.SearchPreviewContainer)
	local paging = book.PagedSpellsFrame.PagingControls
	Skin.TipPageButton(paging.PrevPageButton, 'previous')
	Skin.TipPageButton(paging.NextPageButton, 'next')
	Body(paging.PageText)
	StylePages(book)
end

local function SkinCurrencyDisplay(display)
	Skin.TipFont(display.CurrencyLabel, 'title', SCALE.currencyLabel)
	Skin.TipFace(display.CurrentAmountContainer.CurrencyAmount, 'title', SCALE.currencyAmount)
end

local function StylePvpTalentRow(row)
	if row:IsForbidden() then return end
	FadeKeys(row, PVP_ROW_ART)
	Fade(row:GetHighlightTexture())
	Card(row)
	if not row._buiPvpRow then
		row._buiPvpRow = true
		CropIcon(row.Icon)
		Skin.TipIconFrame(row, row.Icon)
		Face(row.Name)
	end
	Skin.SetActiveEdge(row, row.selectedHere == true)
end

local function SkinPvpTalentList(list)
	FadeKeys(list, PVP_LIST_ART)
	Shell(list)
	ScrollBar(list.ScrollBar)
	Skin.ForEachScrollFrame(list.ScrollBox, StylePvpTalentRow)
end

local function SkinPvpSlotTray(tray)
	Skin.TipFont(tray.Label, 'title')
	for _, slot in ipairs(tray.Slots) do Fade(slot.Shadow) end
end

local function SkinHeroContainer(container)
	Skin.TipFont(container.HeroSpecLabel, 'title', SCALE.heroLabel)
	for labelIndex = 1, 2 do
		Skin.TipFace(container['ChooseSpecLabel' .. labelIndex], 'title', SCALE.heroChoose[labelIndex])
		Skin.TipFace(container['LockedLabel' .. labelIndex], 'title', SCALE.heroLocked[labelIndex])
	end
	Skin.TipFace(container.CurrencyFrame.Text, 'title', SCALE.heroPoints)
end

local function SkinTalents(talents)
	FadeKeys(talents, TALENT_CHROME)
	dimmed[talents.Background] = true
	talents.Background:SetAlpha(TREE_ART_ALPHA)
	Button(talents.ApplyButton)
	Button(talents.InspectCopyButton)
	Dropdown(talents.LoadSystem:GetDropdown())
	EditBox(talents.SearchBox)
	SkinSearchPreview(talents.SearchPreviewContainer)
	SkinCurrencyDisplay(talents.ClassCurrencyDisplay)
	SkinCurrencyDisplay(talents.SpecCurrencyDisplay)
	SkinPvpTalentList(talents.PvPTalentList)
	SkinPvpSlotTray(talents.PvPTalentSlotTray)
	Fade(talents.WarmodeButton.Indent)
	SkinHeroContainer(talents.HeroTalentsContainer)
end

local function StyleSpecSpell(spell)
	Fade(spell.Ring)
	if spell._buiSpecSpell then return end
	spell._buiSpecSpell = true
	spell.CircleMask:Hide()
	CropIcon(spell.Icon)
	Skin.TipIconFrame(spell, spell.Icon)
end

local function StyleSpecContent(content)
	if content:IsForbidden() then return end
	if not content._buiSpecContent then
		content._buiSpecContent = true
		Skin.TipFont(content.SpecName, 'title', SCALE.specName)
		Skin.TipFont(content.Description, 'body', SCALE.specText)
		Skin.TipFont(content.RoleName, 'body', SCALE.specText)
		Skin.TipFont(content.SampleAbilityText, 'label', SCALE.specText)
		Skin.TipFace(content.ActivatedText, 'title', SCALE.specActive)
	end
	Button(content.ActivateButton)
	for spell in content.SpellButtonPool:EnumerateActive() do StyleSpecSpell(spell) end
end

local function StyleSpecContents(specFrame)
	for content in specFrame.SpecContentFramePool:EnumerateActive() do StyleSpecContent(content) end
end

local function SkinLoadoutDialog(dialog)
	if dialog:IsForbidden() then return end
	FadeArt(dialog.Border)
	FadeRegions(dialog)
	Shell(dialog)
	Title(dialog.Title)
	for _, key in ipairs(DIALOG_BUTTON_KEYS) do Button(dialog[key]) end
	local nameControl = dialog.NameControl
	Skin.TipFont(nameControl.Label, 'label')
	EditBox(nameControl.EditBox)
	local importControl = dialog.ImportControl
	if importControl then
		Skin.TipFont(importControl.Label, 'label')
		TextBox(importControl.InputContainer)
	end
	local shared = dialog.UsesSharedActionBars
	if shared then
		CheckBox(shared.CheckButton)
		Skin.TipFace(shared.Label, 'body')
	end
end

local function StyleHeroSpecContent(content)
	if content:IsForbidden() then return end
	Button(content.ActivateButton)
	Button(content.ApplyChangesButton)
	if content._buiHeroSpec then return end
	content._buiHeroSpec = true
	Skin.TipFont(content.SpecName, 'title', SCALE.heroSpecName)
	Skin.TipFont(content.Description, 'body', SCALE.specText)
	Skin.TipFace(content.ActivatedText, 'title', SCALE.specActive)
	Skin.TipFace(content.CurrencyFrame.LabelText, 'body')
	Skin.TipFace(content.CurrencyFrame.AmountText, 'title', SCALE.currencyAmount)
end

local function StyleHeroSpecContents(dialog)
	for content in dialog.SpecContentFramePool:EnumerateActive() do StyleHeroSpecContent(content) end
end

local function SkinFrame(frame)
	context.Chrome(frame)
	Skin.RegisterTabSystem(frame.TabSystem, context, frame)
	SkinSpellBook(frame.SpellBookFrame)
	SkinTalents(frame.TalentsFrame)
	FadeKeys(frame.SpecFrame, SPEC_ART)
	StyleSpecContents(frame.SpecFrame)
	for _, dialogName in ipairs(LOADOUT_DIALOG_NAMES) do SkinLoadoutDialog(_G[dialogName]) end
	local hero = _G.HeroTalentsSelectionDialog
	FadeArt(hero)
	Fade(hero.Background)
	Shell(hero)
	Title(hero.TitleContainer.TitleText)
	context.Close(hero.CloseButton)
	StyleHeroSpecContents(hero)
end

local function RefreshFrame(frame)
	Skin.RefreshTabSystem(frame.TabSystem)
	StylePages(frame.SpellBookFrame)
end

local function InstallFrame(frame)
	Hook(SpellBookItemMixin, 'UpdateVisuals', StyleSpellItem)
	Hook(SpellBookItemMixin, 'OnIconEnter', OnSpellEnter)
	Hook(SpellBookItemMixin, 'OnIconLeave', OnSpellLeave)
	Hook(SpellBookHeaderMixin, 'Init', StyleHeader)
	Hook(PvPTalentListButtonMixin, 'Update', StylePvpTalentRow)
	Hook(frame.SpecFrame, 'UpdateSpecFrame', StyleSpecContents)
	Hook(_G.HeroTalentsSelectionDialog, 'ShowDialog', StyleHeroSpecContents)
	for _, container in ipairs({ frame.SpellBookFrame.SearchPreviewContainer, frame.TalentsFrame.SearchPreviewContainer }) do
		container:HookScript('OnShow', BUI.Profiler.Wrap('Skin.Spellbook search preview', context.Guard(StyleSearchPreview)))
	end
end

context.Window('PlayerSpellsFrame', { skin = SkinFrame, show = RefreshFrame, install = InstallFrame })

context.OnDisable(function()
	for texture in pairs(dimmed) do texture:SetAlpha(1) end
	wipe(dimmed)
end)
