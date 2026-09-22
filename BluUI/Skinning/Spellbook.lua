local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('Spellbook')

local hooksecurefunc = BUI.Prof.MakeHooker('spellbook')
local ipairs = ipairs

local Skin = BUI.Skinning

local SKIN_ID = 'spellbook'
local MAIN_ART = { 'Bg', 'TopTileStreaks' }
local BOOK_ART = { 'TopBar', 'BookBGHalved', 'BookBGLeft', 'BookBGRight', 'BookCornerFlipbook', 'Bookmark' }
local ITEM_BUTTON_ART = { 'Border', 'BorderSheen', 'IconHighlight' }
local NAME_SCALE = 1.15
local HEADER_SCALE = 1.4
local DIVIDER_MAX_HEIGHT = 30
local DIVIDER_MIN_WIDTH = 80
local DIVIDER_INSET = 20
local TALENT_CHROME = { 'BlackBG', 'BottomBar' }
local TREE_ART_ALPHA = 0.7
local CURRENCY_LABEL_SCALE = 1.3
local CURRENCY_AMOUNT_SCALE = 2
local PVP_LIST_ART = { 'Top', 'Middle', 'Bottom' }
local RESULT_ROW_HIGHLIGHT_ALPHA = 0.08
local HERO_LABEL_SCALE = 1.3
local HERO_CHOOSE_SCALES = { 1.2, 1.6 }
local HERO_LOCKED_SCALES = { 1.3, 1.1 }
local HERO_POINTS_SCALE = 1.8
local HERO_SPEC_NAME_SCALE = 1.8
local SPEC_NAME_SCALE = 2.2
local SPEC_TEXT_SCALE = 1.2
local SPEC_ACTIVE_SCALE = 1.3
local SPEC_ART = { 'BlackBG', 'Background' }
local DIALOG_BUTTON_KEYS = { 'AcceptButton', 'CancelButton', 'DeleteButton' }
local LOADOUT_DIALOG_NAMES = { 'ClassTalentLoadoutImportDialog', 'ClassTalentLoadoutCreateDialog', 'ClassTalentLoadoutEditDialog' }

local installed = false
local skinned = false
local dimmed = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys, FadeArt = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt
local Shell, Button, Close, Dropdown, EditBox, CheckBox, TextBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.CheckBox, context.TextBox
local ScrollBar, Body, Title = context.ScrollBar, context.Body, context.Title
local FlatTexture, CropIcon, RowHighlight = Skin.FlatTexture, Skin.CropIcon, Skin.RowHighlight

local function FadeAgain(texture)
	if not texture then return end
	Fade(texture)
	texture:SetAlpha(0)
end

local function Dim(texture, alpha)
	if not texture or not texture.SetAlpha then return end
	dimmed[texture] = true
	texture:SetAlpha(alpha)
end

local function FlatHighlight(button, alpha)
	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if not highlight then return end
	highlight:SetBlendMode('BLEND')
	RowHighlight(button, alpha)
end

local function StyleSpellItem(item)
	if not Enabled() or not item or item:IsForbidden() then return end
	FadeAgain(item.Backplate)
	local button = item.Button
	if button then
		for keyIndex = 1, #ITEM_BUTTON_ART do FadeAgain(button[ITEM_BUTTON_ART[keyIndex]]) end
		if not item._buiSpell then
			CropIcon(button.Icon)
			Skin.TipIconFrame(button, button.Icon)
		end
	end
	item._buiSpell = true
	Skin.TipFont(item.Name, 'title', NAME_SCALE)
	Skin.TipFont(item.SubName, 'label')
	Skin.TipFont(item.RequiredLevel, 'label')
end

local function ReplaceDivider(texture)
	FadeAgain(texture)
	if texture._buiDividerLine then return end
	local line = texture:GetParent():CreateTexture(nil, 'OVERLAY')
	line.__buiSkin = true
	line:SetHeight(1)
	line:SetPoint('LEFT', texture, 'LEFT', DIVIDER_INSET, 0)
	line:SetPoint('RIGHT', texture, 'RIGHT', 0, 0)
	local edge = Skin.PANEL_EDGE
	FlatTexture(line, edge[1], edge[2], edge[3], edge[4])
	texture._buiDividerLine = line
end

local function SweepChrome(host)
	if not host or host:IsForbidden() then return end
	for regionIndex = 1, select('#', host:GetRegions()) do
		local region = select(regionIndex, host:GetRegions())
		if region.__buiSkin then
		elseif region:IsObjectType('FontString') then
			Skin.TipFont(region, 'title', HEADER_SCALE)
		elseif region:IsObjectType('Texture') then
			local width, height = region:GetSize()
			if width > 0 and height > 0 then
				if height <= DIVIDER_MAX_HEIGHT and width > DIVIDER_MIN_WIDTH then
					ReplaceDivider(region)
				else
					FadeAgain(region)
				end
			end
		end
	end
end

local function SweepElements(paged)
	for _, element in paged:EnumerateFrames() do
		if element.HasValidData and element:HasValidData() then
			StyleSpellItem(element)
		else
			FadeAgain(element.Backplate)
			SweepChrome(element)
		end
	end
end

local function SweepPages(book)
	if not Enabled() or not book then return end
	local paged = book.PagedSpellsFrame
	if not paged then return end
	SweepChrome(paged.View1)
	SweepChrome(paged.View2)
	if paged.EnumerateFrames then pcall(SweepElements, paged) end
end

local QueuePageSweep = BUI.Dispatcher.New(function()
	local frame = _G.PlayerSpellsFrame
	if frame and frame:IsVisible() then SweepPages(frame.SpellBookFrame) end
end, 'Skinning.SpellbookPages')

local function StyleSearchPreview(container)
	if not Enabled() or not container or container:IsForbidden() then return end
	for _, child in ipairs({ container:GetChildren() }) do
		if child:IsObjectType('Button') then
			if not child._buiPreviewRow then
				child._buiPreviewRow = true
				FlatHighlight(child, RESULT_ROW_HIGHLIGHT_ALPHA)
				CropIcon(child.Icon)
			end
			Skin.TipFaceTree(child, 1, 'body')
		end
	end
end

local function SkinSearchPreview(container)
	if not container or container._buiPreview then return end
	container._buiPreview = true
	FadeArt(container)
	Shell(container)
	HookScript(container, 'OnShow', StyleSearchPreview)
	StyleSearchPreview(container)
end

local function SkinSpellBook(book)
	if not book then return end
	FadeRegions(book)
	FadeKeys(book, BOOK_ART)
	Skin.RegisterTabSystem(book.CategoryTabSystem, context)
	EditBox(book.SearchBox)
	SkinSearchPreview(book.SearchPreviewContainer)
	local paged = book.PagedSpellsFrame
	local paging = paged and paged.PagingControls
	if paging then
		Skin.TipPageButton(paging.PrevPageButton, 'previous')
		Skin.TipPageButton(paging.NextPageButton, 'next')
		Body(paging.PageText)
	end
	if book._buiSweepHooked then return end
	book._buiSweepHooked = true
	if book.SetTab then hooksecurefunc(book, 'SetTab', QueuePageSweep) end
	HookScript(book, 'OnShow', QueuePageSweep)
	if paged then HookScript(paged, 'OnMouseWheel', QueuePageSweep) end
	if paging and paging.PrevPageButton then HookScript(paging.PrevPageButton, 'OnClick', QueuePageSweep) end
	if paging and paging.NextPageButton then HookScript(paging.NextPageButton, 'OnClick', QueuePageSweep) end
end

local function SkinCurrencyDisplay(display)
	if not display then return end
	Skin.TipFont(display.CurrencyLabel, 'title', CURRENCY_LABEL_SCALE)
	local amountContainer = display.CurrentAmountContainer
	if amountContainer then Skin.TipFace(amountContainer.CurrencyAmount, 'title', CURRENCY_AMOUNT_SCALE) end
end

local function StylePvpTalentRow(row)
	if not Enabled() or not row or row:IsForbidden() then return end
	FadeAgain(row.Border)
	if not row._buiPvpRow then
		row._buiPvpRow = true
		FlatHighlight(row, RESULT_ROW_HIGHLIGHT_ALPHA)
		CropIcon(row.Icon)
		Skin.TipIconFrame(row, row.Icon)
	end
	Body(row.Name)
end

local function SkinPvpTalentList(list)
	if not list then return end
	FadeKeys(list, PVP_LIST_ART)
	Shell(list)
	ScrollBar(list.ScrollBar)
	local box = list.ScrollBox
	Skin.ForEachScrollFrame(box, StylePvpTalentRow)
end

local function SkinPvpSlotTray(tray)
	if not tray then return end
	Skin.TipFont(tray.Label, 'title')
	local slots = tray.Slots
	if not slots then return end
	for slotIndex = 1, #slots do Fade(slots[slotIndex].Shadow) end
end

local function SkinHeroContainer(container)
	if not container then return end
	Skin.TipFont(container.HeroSpecLabel, 'title', HERO_LABEL_SCALE)
	for labelIndex = 1, 2 do
		Skin.TipFace(container['ChooseSpecLabel' .. labelIndex], 'title', HERO_CHOOSE_SCALES[labelIndex])
		Skin.TipFace(container['LockedLabel' .. labelIndex], 'title', HERO_LOCKED_SCALES[labelIndex])
	end
	if container.CurrencyFrame then Skin.TipFace(container.CurrencyFrame.Text, 'title', HERO_POINTS_SCALE) end
end

local function SkinTalents(talents)
	if not talents then return end
	FadeKeys(talents, TALENT_CHROME)
	Dim(talents.Background, TREE_ART_ALPHA)
	Button(talents.ApplyButton)
	Button(talents.InspectCopyButton)
	local loadSystem = talents.LoadSystem
	if loadSystem then Dropdown(loadSystem.GetDropdown and loadSystem:GetDropdown() or loadSystem.Dropdown) end
	EditBox(talents.SearchBox)
	SkinSearchPreview(talents.SearchPreviewContainer)
	SkinCurrencyDisplay(talents.ClassCurrencyDisplay)
	SkinCurrencyDisplay(talents.SpecCurrencyDisplay)
	SkinPvpTalentList(talents.PvPTalentList)
	SkinPvpSlotTray(talents.PvPTalentSlotTray)
	if talents.WarmodeButton then Fade(talents.WarmodeButton.Indent) end
	SkinHeroContainer(talents.HeroTalentsContainer)
end

local function StyleSpecSpell(spell)
	if not spell or spell._buiSpecSpell then return end
	spell._buiSpecSpell = true
	Fade(spell.Ring)
	if spell.CircleMask then spell.CircleMask:Hide() end
	CropIcon(spell.Icon)
	Skin.TipIconFrame(spell, spell.Icon)
end

local function StyleSpecContent(content)
	if not content or content:IsForbidden() then return end
	if not content._buiSpecContent then
		content._buiSpecContent = true
		Button(content.ActivateButton)
		Skin.TipFont(content.SpecName, 'title', SPEC_NAME_SCALE)
		Skin.TipFont(content.Description, 'body', SPEC_TEXT_SCALE)
		Skin.TipFont(content.RoleName, 'body', SPEC_TEXT_SCALE)
		Skin.TipFont(content.SampleAbilityText, 'label', SPEC_TEXT_SCALE)
		Skin.TipFace(content.ActivatedText, 'title', SPEC_ACTIVE_SCALE)
	end
	local pool = content.SpellButtonPool
	if not pool then return end
	for spell in pool:EnumerateActive() do StyleSpecSpell(spell) end
end

local function SweepSpecContents(specFrame)
	if not Enabled() or not specFrame or not specFrame.SpecContentFramePool then return end
	for content in specFrame.SpecContentFramePool:EnumerateActive() do StyleSpecContent(content) end
end

local function SkinSpecFrame(specFrame)
	if not specFrame then return end
	FadeKeys(specFrame, SPEC_ART)
	SweepSpecContents(specFrame)
end

local function SkinLoadoutDialog(dialog)
	if not dialog or dialog:IsForbidden() then return end
	FadeArt(dialog.Border)
	FadeRegions(dialog)
	Shell(dialog)
	Title(dialog.Title)
	for _, key in ipairs(DIALOG_BUTTON_KEYS) do Button(dialog[key]) end
	local nameControl = dialog.NameControl
	if nameControl then
		Skin.TipFont(nameControl.Label, 'label')
		EditBox(nameControl.EditBox)
	end
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
	if not content or content:IsForbidden() or content._buiHeroSpec then return end
	content._buiHeroSpec = true
	Skin.TipFont(content.SpecName, 'title', HERO_SPEC_NAME_SCALE)
	Skin.TipFont(content.Description, 'body', SPEC_TEXT_SCALE)
	Skin.TipFace(content.ActivatedText, 'title', SPEC_ACTIVE_SCALE)
	local currency = content.CurrencyFrame
	if currency then
		Skin.TipFace(currency.LabelText, 'body')
		Skin.TipFace(currency.AmountText, 'title', CURRENCY_AMOUNT_SCALE)
	end
	Button(content.ActivateButton)
	Button(content.ApplyChangesButton)
end

local function SweepHeroSpecContents(dialog)
	if not Enabled() or not dialog or not dialog.SpecContentFramePool then return end
	for content in dialog.SpecContentFramePool:EnumerateActive() do StyleHeroSpecContent(content) end
end

local function SkinHeroDialog(dialog)
	if not dialog or dialog:IsForbidden() then return end
	Fade(dialog.NineSlice)
	FadeKeys(dialog, MAIN_ART)
	Fade(dialog.Background)
	Shell(dialog)
	Title(dialog.TitleContainer and dialog.TitleContainer.TitleText)
	Close(dialog.CloseButton)
	SweepHeroSpecContents(dialog)
end

local function SkinMainFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	FadeRegions(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
	local maxMin = frame.MaximizeMinimizeButton or frame.MaxMinButtonFrame
	if maxMin then
		Skin.TipPageButton(maxMin.MaximizeButton, 'expand')
		Skin.TipPageButton(maxMin.MinimizeButton, 'condense')
	end
	Skin.RegisterTabSystem(frame.TabSystem, context, frame)
	SkinSpellBook(frame.SpellBookFrame)
	SkinTalents(frame.TalentsFrame)
	SkinSpecFrame(frame.SpecFrame)
	for _, dialogName in ipairs(LOADOUT_DIALOG_NAMES) do SkinLoadoutDialog(_G[dialogName]) end
	SkinHeroDialog(_G.HeroTalentsSelectionDialog)
end

local function Apply()
	local frame = _G.PlayerSpellsFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
		SkinMainFrame(frame)
	end
	Skin.RefreshTabSystem(frame.TabSystem)
	if frame.SpellBookFrame then Skin.RefreshTabSystem(frame.SpellBookFrame.CategoryTabSystem) end
	SweepPages(frame.SpellBookFrame)
	SweepSpecContents(frame.SpecFrame)
	QueuePageSweep()
end

local function HookMixin(mixin, method, callback)
	if mixin and mixin[method] then hooksecurefunc(mixin, method, callback) end
end

local function Install()
	if installed then return end
	local frame = _G.PlayerSpellsFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	HookMixin(_G.SpellBookItemMixin, 'UpdateVisuals', StyleSpellItem)
	HookMixin(_G.SpellBookItemMixin, 'OnIconEnter', StyleSpellItem)
	HookMixin(_G.SpellBookItemMixin, 'OnIconLeave', StyleSpellItem)
	HookMixin(_G.PvPTalentListButtonMixin, 'Update', StylePvpTalentRow)
	HookMixin(frame.SpecFrame, 'UpdateSpecFrame', SweepSpecContents)
	HookMixin(_G.HeroTalentsSelectionDialog, 'ShowDialog', SweepHeroSpecContents)
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Spellbook') end
end

local function Deactivate()
	context.Restore()
	for texture in pairs(dimmed) do texture:SetAlpha(1) end
	wipe(dimmed)
	skinned = false
	BUI.Print('Spellbook skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.Spellbook', TryInstall)
		elseif _G.PlayerSpellsFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Spellbook',
	description = 'The spellbook, talents and specialization window: dark pages, framed spell icons, house tabs, search and paging, dimmed talent tree, loadout and hero talent dialogs.',
	icon = 'Interface/Icons/INV_Misc_Book_09',
})
