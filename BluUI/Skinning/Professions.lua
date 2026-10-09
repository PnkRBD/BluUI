local _, BUI = ...

local ipairs = ipairs
local SecureHook = BUI.Profiler.Hooker('Skin.Professions')
local Wrap = BUI.Profiler.Wrap

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Theme = BUILib.Theme

local CUSTOMER_FRAME_ART = { 'MoneyFrameInset', 'MoneyFrameBorder' }
local LIST_ART = { 'Background', 'NineSlice' }
local RECIPE_LIST_ART = { 'Background', 'BackgroundNineSlice' }
local SCHEMATIC_ART = { 'Background', 'MinimalBackground', 'NineSlice' }
local QUALITY_PANE_ART = { 'BackgroundTop', 'BackgroundMiddle', 'BackgroundBottom', 'BackgroundMinimized' }
local RANK_BAR_ART = { 'Background', 'Border' }
local CATEGORY_ART = { 'LeftPiece', 'RightPiece', 'CenterPiece' }
local HEADER_ART = { 'Left', 'Middle', 'Right' }
local PANEL_BUTTON_ART = { 'Left', 'Middle', 'Right' }
local STRETCH_BUTTON_ART = { 'TopLeft', 'TopRight', 'BottomLeft', 'BottomRight', 'TopMiddle', 'MiddleLeft', 'MiddleRight', 'BottomMiddle', 'MiddleMiddle' }
local REAGENT_CONTAINER_KEYS = { 'Reagents', 'OptionalReagents', 'FinishingReagents' }
local QUALITY_CONTAINER_KEYS = { 'Container1', 'Container2', 'Container3' }
local SCHEMATIC_BODY_KEYS = { 'OutputSubText', 'Description', 'RequiredTools', 'RecraftingDescription', 'RecraftingRequiredTools' }
local CRAFTING_BUTTON_KEYS = { 'CreateButton', 'CreateAllButton', 'ViewGuildCraftersButton' }
local SPEC_BUTTON_KEYS = { 'ApplyButton', 'UnlockTabButton', 'ViewTreeButton', 'BackToPreviewButton', 'ViewPreviewButton', 'BackToFullTreeButton' }
local ORDER_INFO_LABEL_KEYS = { 'PostedByTitle', 'CommissionTitle', 'ConsortiumCutTitle', 'FinalTipTitle', 'TimeRemainingTitle' }
local ORDER_INFO_BODY_KEYS = { 'PostedByValue', 'TimeRemainingValue' }
local ORDER_INFO_BUTTON_KEYS = { 'BackButton', 'StartOrderButton', 'DeclineOrderButton', 'ReleaseOrderButton' }
local ORDER_VIEW_BUTTON_KEYS = { 'CreateButton', 'CompleteOrderButton', 'StartRecraftButton', 'StopRecraftButton' }
local PAYMENT_LABEL_KEYS = { 'Tip', 'Duration', 'TimeRemaining', 'PostingFee', 'TotalPrice' }
local FORM_PANEL_KEYS = { 'LeftPanelBackground', 'RightPanelBackground' }
local BOOK_ROW_NAMES = { 'PrimaryProfession1', 'PrimaryProfession2', 'SecondaryProfession1', 'SecondaryProfession2', 'SecondaryProfession3' }
local BOOK_BAR_ART = { 'Left', 'Right', 'BGLeft', 'BGRight', 'BGMiddle' }
local BOOK_PAGE_NAMES = { 'ProfessionsBookPage1', 'ProfessionsBookPage2' }
local NOTE_FONT, NOTE_HINT_FONT = 'BUI_ProfessionsNoteFont', 'BUI_ProfessionsNoteHintFont'
local CATEGORY_FILL_ALPHA = 0.04
local ROW_SELECTED_ALPHA = 0.18
local ROW_HOVER_ALPHA = 0.06
local OUTPUT_TITLE_SCALE = 1.2
local OUTPUT_CRIT_SCALE = 0.8
local PREVIEW_TITLE_SCALE = 1.5
local CATEGORY_TITLE_SCALE = 12 / 11
local TAB_BASELINE_OFFSET = 8
local BOOK = { NAME_SCALE = 14 / 12, MARGIN = 12, TOP = -34, CARD_WIDTH = 526, CARD_HEIGHT = 72, GAP = 8, PAD = 10, BAR = 14, LINE = 3 }
local SPELL = { SIZE = 36, LABEL_GAP = 8, LABEL_WIDTH = 100, SLOT_GAP = 12, COLUMN_GAP = 16 }
SPELL.SLOT = SPELL.SIZE + SPELL.LABEL_GAP + SPELL.LABEL_WIDTH
BOOK.TEXT_WIDTH = BOOK.CARD_WIDTH - BOOK.PAD * 2 - SPELL.SLOT * 2 - SPELL.SLOT_GAP - SPELL.COLUMN_GAP
local UNLEARN_GAP = 8

local templatesInstalled = false
local waitingForWidth = false
local bookLaidOut = false

local context = Skin.Define('professions', {
	name = 'Professions',
	description = 'The professions book, crafting window and crafting orders: recipe list, schematic panel, flat rank bar, tabs, specializations, the crafter order browser and order view, and the customer order window (NPC only, so the preview shows the book).',
	icon = 'Interface/Icons/Trade_Engineering',
	newLook = true,
})
local Enabled, Hook, Own, Chrome = context.Enabled, context.Hook, context.Own, context.Chrome
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Card = context.Shell, context.Button, context.Card
local Dropdown, EditBox, CheckBox = context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Tab, Body, Title = context.ScrollBar, context.Tab, context.Body, context.Title
local FlatTexture, AccentTexture, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.CropIcon

local function NoteFonts()
	if _G[NOTE_FONT] then return end
	Skin.TipFont(CreateFont(NOTE_FONT), 'body')
	Skin.TipFont(CreateFont(NOTE_HINT_FONT), 'label')
end

local function SkinIconButton(button)
	Fade(button:GetNormalTexture())
	Fade(button:GetPushedTexture())
	Fade(button:GetDisabledTexture())
	Fade(button:GetHighlightTexture())
	Shell(button)
	Skin.AccentHover(button)
end

local function SkinDialog(dialog)
	Chrome(dialog, dialog.ClosePanelButton)
end

local function TrackArrowState(arrow)
	local refresh = Wrap('Skin.Professions arrow state', Skin.RefreshPageButton)
	arrow:HookScript('OnEnable', refresh)
	arrow:HookScript('OnDisable', refresh)
end

local function SkinSpinner(spinner)
	EditBox(spinner)
	Skin.TipPageButton(spinner.DecrementButton, 'previous')
	Skin.TipPageButton(spinner.IncrementButton, 'next')
	if spinner._buiSpinner then return end
	spinner._buiSpinner = true
	TrackArrowState(spinner.DecrementButton)
	TrackArrowState(spinner.IncrementButton)
end

local function SkinItemButton(button)
	if not button or button._buiItemButton then return end
	button._buiItemButton = true
	Fade(button:GetNormalTexture())
	CropIcon(button.icon)
	Skin.TipIconFrame(button, button.icon)
end

local function SkinSlotButton(button)
	if not button or button._buiSlotButton then return end
	button._buiSlotButton = true
	Fade(button:GetNormalTexture())
	Fade(button.SlotBackground)
	CropIcon(button.Icon)
	Skin.TipIconFrame(button, button.Icon)
	Skin.TipCount(button.Count)
end

local function SkinNoteEditBox(scrolling)
	local editBox = scrolling:GetEditBox()
	NoteFonts()
	editBox.fontName, editBox.defaultFontName = NOTE_FONT, NOTE_HINT_FONT
	Skin.TipFace(editBox, 'body')
end

local function SkinNoteFrame(note)
	Fade(note.Border)
	Shell(note)
	Skin.TipFont(note.TitleBox.Title, 'label')
	SkinNoteEditBox(note.ScrollingEditBox)
end

local function DividerLine(frame, vertical)
	FadeRegions(frame)
	if frame._buiLine then return end
	local line = BUI.Painter.Fill(Own(frame:CreateTexture(nil, 'ARTWORK')), 'skinBorder')
	if vertical then
		line:SetPoint('TOP')
		line:SetPoint('BOTTOM')
		line:SetWidth(1)
		BUILib.Skin.PixelLine(line, frame, true)
	else
		line:SetPoint('BOTTOMLEFT', 0, TAB_BASELINE_OFFSET)
		line:SetPoint('BOTTOMRIGHT', 0, TAB_BASELINE_OFFSET)
		line:SetHeight(1)
		BUILib.Skin.PixelAlign(frame, frame, function(left, right, _, bottom, pixel)
			local offsetY = BUILib.Widget.SnapY(bottom + TAB_BASELINE_OFFSET, pixel) - bottom
			line:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', BUILib.Widget.SnapX(left, pixel) - left, offsetY)
			line:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', BUILib.Widget.SnapX(right, pixel) - right, offsetY)
			line:SetHeight(pixel)
		end)
	end
	frame._buiLine = line
end

local function CategoryLabel(category)
	Skin.TipFace(category.Label, 'title')
end

local function OnCategoryInit(category)
	if not category._buiCategory then
		category._buiCategory = true
		FadeKeys(category, CATEGORY_ART)
		local fill = Own(category:CreateTexture(nil, 'BACKGROUND'))
		fill:SetAllPoints(category)
		FlatTexture(fill, 1, 1, 1, CATEGORY_FILL_ALPHA)
	end
	CategoryLabel(category)
end

local function FillRow(texture, row)
	texture:ClearAllPoints()
	texture:SetAllPoints(row)
	texture:SetBlendMode('BLEND')
end

local function OnRecipeInit(row)
	if row._buiRecipe then return end
	row._buiRecipe = true
	FillRow(row.SelectedOverlay, row)
	AccentTexture(row.SelectedOverlay, ROW_SELECTED_ALPHA)
	FillRow(row.HighlightOverlay, row)
	row.HighlightOverlay:SetAlpha(1)
	FlatTexture(row.HighlightOverlay, 1, 1, 1, ROW_HOVER_ALPHA)
	Skin.TipFace(row.Label, 'body')
	Skin.TipFace(row.Count, 'body')
	Skin.TipFace(row.SkillUps.Text, 'body')
end

local function OnSlotInit(slot)
	SkinSlotButton(slot.Button)
	Skin.TipFace(slot.Name, 'body')
	if slot.Checkbox and not slot._buiCheck then
		slot._buiCheck = true
		CheckBox(slot.Checkbox)
	end
end

local function OnModifyingRequired(button, isModifyingRequired)
	local alpha = isModifyingRequired and 1 or 0
	button:GetNormalTexture():SetAlpha(alpha)
	button:GetPushedTexture():SetAlpha(alpha)
end

local function OnHeaderInit(header)
	if header._buiHeader then return end
	header._buiHeader = true
	FadeKeys(header, HEADER_ART)
	Fade(header:GetHighlightTexture())
	Skin.TipFont(header.Text, 'label')
	local red, green, blue = Theme.GetAccent()
	header.Arrow:SetVertexColor(red, green, blue, 1)
end

local function SkinCell(cell)
	if cell._buiCell then return end
	cell._buiCell = true
	Skin.TipFace(cell.Text, 'title')
	if cell.IconBorder then
		Fade(cell.IconBorder)
		CropIcon(cell.Icon)
		Skin.TipIconFrame(cell, cell.Icon)
	end
end

local function OnTableRow(row)
	local highlight = row.HighlightTexture
	highlight:SetBlendMode('BLEND')
	FlatTexture(highlight, 1, 1, 1, ROW_HOVER_ALPHA)
	if row.cells then
		for _, cell in ipairs(row.cells) do SkinCell(cell) end
	end
end

local function SkinList(list)
	FadeKeys(list, LIST_ART)
	Shell(list.NineSlice)
	ScrollBar(list.ScrollBar)
	Body(list.ResultsText)
	for _, header in ipairs({ list.HeaderContainer:GetChildren() }) do
		if header.Arrow then OnHeaderInit(header) end
	end
	Skin.SweepScrollBox(list.ScrollBox, OnTableRow)
end

local function SkinRecipeList(list)
	FadeKeys(list, RECIPE_LIST_ART)
	Shell(list)
	Dropdown(list.FilterDropdown)
	EditBox(list.SearchBox)
	ScrollBar(list.ScrollBar)
	Body(list.NoResultsText)
end

local function SkinQualityDialog(dialog)
	SkinDialog(dialog)
	for _, key in ipairs(QUALITY_CONTAINER_KEYS) do
		local container = dialog[key]
		SkinSlotButton(container.Button)
		SkinSpinner(container.EditBox)
	end
	Button(dialog.AcceptButton)
	Button(dialog.CancelButton)
end

local function SkinSchematicText(form)
	CheckBox(form.TrackRecipeCheckbox)
	CheckBox(form.AllocateBestQualityCheckbox)
	local track = form.TrackRecipeCheckbox
	track:SetPoint('TOPRIGHT', -(track.text:GetStringWidth() + 20), -16)
	Skin.TipFont(form.OutputText, 'title', OUTPUT_TITLE_SCALE)
	Skin.TipFace(form.RecraftingOutputText, 'title')
	for _, key in ipairs(SCHEMATIC_BODY_KEYS) do Skin.TipFace(form[key], 'body') end
	for _, key in ipairs(REAGENT_CONTAINER_KEYS) do Skin.TipFont(form[key].Label, 'label') end
	Body(form.RecipeSourceButton.Text)
	FadeKeys(form.Details, QUALITY_PANE_ART)
	Skin.TipFont(form.Details.Label, 'label')
	SkinQualityDialog(form.QualityDialog)
end

local function UpdateRankFill(rankBar)
	local ratio = rankBar.ratio or 0
	local fill = rankBar._buiFill
	fill:SetShown(ratio > 0)
	if ratio > 0 then fill:SetWidth((rankBar:GetWidth() - 2 - rankBar:GetHeight()) * ratio) end
	rankBar.Flare:Hide()
end

local function LayoutRankBar(rankBar)
	local expansion = rankBar.ExpansionDropdownButton
	expansion:ClearAllPoints()
	expansion:SetPoint('TOPRIGHT')
	expansion:SetPoint('BOTTOMRIGHT')
	expansion:SetWidth(rankBar:GetHeight())
	local divider = BUI.Painter.Fill(Own(rankBar:CreateTexture(nil, 'OVERLAY')), 'skinBorder')
	divider:SetPoint('TOPRIGHT', expansion, 'TOPLEFT', 0, -1)
	divider:SetPoint('BOTTOMRIGHT', expansion, 'BOTTOMLEFT', 0, 1)
	PixelUtil.SetWidth(divider, 1, 1)
	rankBar.Rank:ClearAllPoints()
	rankBar.Rank:SetPoint('TOPLEFT')
	rankBar.Rank:SetPoint('BOTTOMRIGHT', expansion, 'BOTTOMLEFT')
end

local function SkinRankBar(rankBar)
	FadeKeys(rankBar, RANK_BAR_ART)
	Fade(rankBar.Fill)
	Shell(rankBar)
	if not rankBar._buiFill then
		local fill = Own(rankBar:CreateTexture(nil, 'ARTWORK'))
		fill:SetPoint('TOPLEFT', 1, -1)
		fill:SetPoint('BOTTOMLEFT', 1, 1)
		fill:SetTexture(BUI.GetGlobalTexture())
		rankBar._buiFill = fill
		LayoutRankBar(rankBar)
		Hook(rankBar, 'Update', UpdateRankFill)
	end
	local red, green, blue = Theme.GetAccent()
	rankBar._buiFill:SetVertexColor(red, green, blue, 1)
	local text = rankBar.Rank.Text
	Skin.TipFace(text, 'body')
	local font, size = text:GetFont()
	text:SetFont(font, size, 'OUTLINE')
	local expansion = rankBar.ExpansionDropdownButton
	Fade(expansion.Texture)
	Skin.TipArrow(expansion, true)
	UpdateRankFill(rankBar)
end

local function OnOutputEntry(entry)
	local container = entry.ItemContainer
	if not entry._buiOutput then
		entry._buiOutput = true
		FadeRegions(container)
		Shell(container)
		SkinItemButton(container.Item)
		Skin.TipFace(container.Text, 'title')
		Skin.TipFace(container.CritText, 'body', OUTPUT_CRIT_SCALE)
		for _, row in ipairs(entry.Rows) do
			Fade(row.Bracket)
			Body(row.Text)
			SkinItemButton(row.Item)
		end
	end
	Skin.TipShellEdges(container, container.CritFrame:IsShown())
	for button in entry.itemButtonPool:EnumerateActive() do SkinSlotButton(button) end
end

local function SkinOutputLog(log)
	SkinDialog(log)
	ScrollBar(log.ScrollBar)
end

local function SkinCraftingPage(page)
	SkinRecipeList(page.RecipeList)
	local form = page.SchematicForm
	FadeKeys(form, SCHEMATIC_ART)
	Shell(form)
	SkinSchematicText(form)
	SkinRankBar(page.RankBar)
	for _, key in ipairs(CRAFTING_BUTTON_KEYS) do Button(page[key]) end
	SkinSpinner(page.CreateMultipleInputBox)
	for _, slot in ipairs(page.InventorySlots) do SkinItemButton(slot) end
	FadeRegions(page.GearSlotDivider)
	Body(page.ConcentrationDisplay.Amount)
	EditBox(page.MinimizedSearchBox)
	local results = page.MinimizedSearchResults
	Chrome(results)
	ScrollBar(results.ScrollBar)
	SkinOutputLog(page.CraftingOutputLog)
end

local function OnTabSelected(tab, selected)
	Skin.TipTabSelected(tab, selected == true)
end

local function SkinSelectTab(tab)
	if not tab._buiSelectTab then
		tab._buiSelectTab = true
		Tab(tab)
		Hook(tab, 'SetTabSelected', OnTabSelected)
	end
	Skin.TipTabSelected(tab, tab.isSelected == true)
end

local function SkinSpecTab(tab)
	tab.StateIcon.__buiSkin = true
	tab.StateIconGlow.__buiSkin = true
	SkinSelectTab(tab)
end

local function SweepSpecTabs(spec)
	for tab in spec.tabsPool:EnumerateActive() do SkinSpecTab(tab) end
end

local function SkinSpecPage(spec)
	FadeRegions(spec.PanelFooter)
	local tree = spec.TreeView
	Fade(tree.Background)
	Title(tree.TreeName)
	Body(tree.TreeDescription)
	local detailed = spec.DetailedView
	Fade(detailed.Background)
	Title(detailed.PathName)
	Fade(detailed.UnspentPoints.CurrencyBackground)
	Body(detailed.UnspentPoints.Count)
	Button(detailed.SpendPointsButton)
	Button(detailed.UnlockPathButton)
	DividerLine(spec.VerticalDivider, true)
	DividerLine(spec.TopDivider, false)
	local preview = spec.TreePreview
	Fade(preview.Background)
	Shell(preview)
	Skin.TipFont(preview.Title, 'title', PREVIEW_TITLE_SCALE)
	Body(preview.Description)
	Skin.TipFont(preview.HighlightsHeader, 'label')
	for _, highlight in ipairs(preview.Highlights) do Body(highlight.Description) end
	for _, key in ipairs(SPEC_BUTTON_KEYS) do Button(spec[key]) end
	if not spec._buiSpecHooked then
		spec._buiSpecHooked = true
		Hook(spec, 'InitializeTabs', SweepSpecTabs)
	end
	SweepSpecTabs(spec)
end

local function SkinOrderBrowse(browse)
	SkinRecipeList(browse.RecipeList)
	SkinIconButton(browse.FavoritesSearchButton)
	Button(browse.SearchButton)
	FadeKeys(browse.BackButton, PANEL_BUTTON_ART)
	Skin.TipPageButton(browse.BackButton, 'previous')
	SkinList(browse.OrderList)
	for _, tab in ipairs(browse.orderTypeTabs) do SkinSelectTab(tab) end
	local remaining = browse.OrdersRemainingDisplay
	Fade(remaining.Background)
	Body(remaining.OrdersRemaining)
end

local function SkinStretchButton(button)
	FadeKeys(button, STRETCH_BUTTON_ART)
	SkinIconButton(button)
end

local function SkinOrderRewards(info)
	for _, item in ipairs(info.NPCRewardsFrame.RewardItems) do SkinSlotButton(item) end
end

local function SkinOrderInfo(info)
	FadeKeys(info, LIST_ART)
	Fade(info.CutDivider)
	Shell(info)
	for _, key in ipairs(ORDER_INFO_LABEL_KEYS) do Skin.TipFont(info[key], 'label') end
	for _, key in ipairs(ORDER_INFO_BODY_KEYS) do Body(info[key]) end
	for _, key in ipairs(ORDER_INFO_BUTTON_KEYS) do Button(info[key]) end
	SkinStretchButton(info.SocialDropdown)
	local noteBox = info.NoteBox
	Fade(noteBox.Background.Border)
	Shell(noteBox)
	Skin.TipFont(noteBox.NoteTitle, 'label')
	Skin.TipFace(noteBox.NoteText, 'body')
	Skin.TipFace(info.OrderReagentsWarning.Text, 'body')
	local rewards = info.NPCRewardsFrame
	Fade(rewards.Background)
	Skin.TipFont(rewards.RewardText, 'label')
	SkinOrderRewards(info)
end

local function OnOrderSet(view)
	Skin.TipFont(view.OrderInfo.NoteBox.NoteTitle, 'label')
	SkinOrderRewards(view.OrderInfo)
end

local function SkinOrderView(view)
	SkinOrderInfo(view.OrderInfo)
	local details = view.OrderDetails
	FadeKeys(details, LIST_ART)
	Shell(details)
	SkinSchematicText(details.SchematicForm)
	local fulfillment = details.FulfillmentForm
	Skin.TipFace(fulfillment.ItemName, 'title', OUTPUT_TITLE_SCALE)
	Body(fulfillment.OrderCompleteText)
	SkinNoteFrame(fulfillment.NoteEditBox)
	SkinRankBar(view.RankBar)
	Body(view.ConcentrationDisplay.Amount)
	for _, key in ipairs(ORDER_VIEW_BUTTON_KEYS) do Button(view[key]) end
	local decline = view.DeclineOrderDialog
	SkinDialog(decline)
	Body(decline.ConfirmationText)
	SkinNoteFrame(decline.NoteEditBox)
	Button(decline.CancelButton)
	Button(decline.ConfirmButton)
	SkinOutputLog(view.CraftingOutputLog)
	if not view._buiOrderHook then
		view._buiOrderHook = true
		Hook(view, 'SetOrder', OnOrderSet)
	end
end

local function SkinProfessionsFrame(frame)
	Chrome(frame)
	Skin.RegisterTabSystem(frame.TabSystem, context, frame)
	SkinCraftingPage(frame.CraftingPage)
	SkinSpecPage(frame.SpecPage)
	SkinOrderBrowse(frame.OrdersPage.BrowseFrame)
	SkinOrderView(frame.OrdersPage.OrderView)
end

local function OnCategoryButton(button)
	if button.isSpacer then return end
	Fade(button.NormalTexture)
	Fade(button.Lines)
	local selected, highlight = button.SelectedTexture, button.HighlightTexture
	selected:SetBlendMode('BLEND')
	AccentTexture(selected, ROW_SELECTED_ALPHA)
	highlight:SetBlendMode('BLEND')
	FlatTexture(highlight, 1, 1, 1, ROW_HOVER_ALPHA)
	local info = button.categoryInfo
	local primary = info == nil or info.type == Enum.CraftingOrderCustomerCategoryType.Primary
	Skin.TipButtonFonts(button, primary and CATEGORY_TITLE_SCALE or nil)
end

local function SkinSearchBar(bar)
	SkinIconButton(bar.FavoritesSearchButton)
	EditBox(bar.SearchBox)
	Button(bar.SearchButton)
	Dropdown(bar.FilterDropdown)
end

local function SkinBrowseOrders(page)
	SkinSearchBar(page.SearchBar)
	local categories = page.CategoryList
	FadeKeys(categories, LIST_ART)
	Shell(categories)
	ScrollBar(categories.ScrollBar)
	Skin.SweepScrollBox(categories.ScrollBox, OnCategoryButton)
	SkinList(page.RecipeList)
end

local function SkinMoneyInput(frame)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child:IsObjectType('EditBox') then EditBox(child) end
	end
end

local function OnDurationDropdown(form)
	Skin.TipFace(form.PaymentContainer.DurationDropdown.Text, 'body')
end

local function SkinPayment(payment)
	for _, key in ipairs(PAYMENT_LABEL_KEYS) do Skin.TipFont(payment[key], 'label') end
	SkinNoteFrame(payment.NoteEditBox)
	SkinMoneyInput(payment.TipMoneyInputFrame)
	Body(payment.TimeRemainingDisplay.Text)
	Dropdown(payment.DurationDropdown)
	Button(payment.ListOrderButton)
	Button(payment.CancelOrderButton)
end

local function SkinListings(listings)
	SkinDialog(listings)
	SkinList(listings.OrderList)
	Button(listings.CloseButton)
end

local function SkinCustomerForm(form)
	Fade(form.RecipeHeader)
	Skin.TipFace(form.RecipeName, 'title', OUTPUT_TITLE_SCALE)
	Skin.TipFace(form.RecraftRecipeName, 'title', OUTPUT_TITLE_SCALE)
	Skin.TipFont(form.ProfessionText, 'label')
	Body(form.OrderStateText)
	for _, key in ipairs(FORM_PANEL_KEYS) do
		local panel = form[key]
		FadeKeys(panel, LIST_ART)
		Shell(panel)
	end
	Button(form.BackButton)
	Skin.TipFont(form.MinimumQuality.Text, 'label')
	Dropdown(form.MinimumQuality.Dropdown)
	Dropdown(form.OrderRecipientDropdown)
	EditBox(form.OrderRecipientTarget)
	local recipient = form.OrderRecipientDisplay
	Skin.TipFont(recipient.PostedTo, 'label')
	Skin.TipFont(recipient.Crafter, 'label')
	Body(recipient.CrafterValue)
	SkinStretchButton(recipient.SocialDropdown)
	local reagents = form.ReagentContainer
	Skin.TipFont(reagents.Reagents.Label, 'label')
	Skin.TipFont(reagents.OptionalReagents.Label, 'label')
	Skin.TipFace(reagents.RecraftInfoText, 'body')
	SkinPayment(form.PaymentContainer)
	local track = form.TrackRecipeCheckbox
	Skin.TipFont(track.Text, 'label')
	CheckBox(track.Checkbox)
	track:Layout()
	CheckBox(form.AllocateBestQualityCheckbox)
	SkinListings(form.CurrentListings)
	if not form._buiDurationHook then
		form._buiDurationHook = true
		Hook(form, 'SetupDurationDropdown', OnDurationDropdown)
	end
end

local function SkinCustomerFrame(frame)
	Chrome(frame)
	FadeKeys(frame, CUSTOMER_FRAME_ART)
	Skin.RegisterTabStrip(frame, frame.Tabs, context)
	Skin.RefreshTabStrip(frame)
	SkinBrowseOrders(frame.BrowseOrders)
	SkinIconButton(frame.MyOrdersPage.RefreshButton)
	SkinList(frame.MyOrdersPage.OrderList)
	SkinCustomerForm(frame.Form)
end

local function RecolorSpellButton(button)
	Body(button.spellString)
end

local function SkinBookSpellButton(button)
	local name = button:GetName()
	Fade(_G[name .. 'NameFrame'])
	CropIcon(button.IconTexture)
	Skin.TipIconFrame(button, button.IconTexture)
	Skin.TipFont(button.subSpellString, 'label')
	RecolorSpellButton(button)
	if button._buiSpellHook then return end
	button._buiSpellHook = true
	Hook(button, 'UpdateButton', RecolorSpellButton)
end

local function SkinBookBar(bar)
	local name = bar:GetName()
	for _, key in ipairs(BOOK_BAR_ART) do Fade(_G[name .. key]) end
	bar:SetStatusBarTexture(BUI.GetGlobalTexture())
	local red, green, blue = Theme.GetAccent()
	bar:SetStatusBarColor(red, green, blue, 1)
	Shell(bar)
	Skin.TipFace(bar.rankText, 'body')
end

local function LayoutSpellButton(button, relativeTo, relativePoint, x)
	button:SetSize(SPELL.SIZE, SPELL.SIZE)
	button:ClearAllPoints()
	button:SetPoint('RIGHT', relativeTo, relativePoint, x, 0)
	button.spellString:ClearAllPoints()
	button.spellString:SetPoint('LEFT', button, 'RIGHT', SPELL.LABEL_GAP, 0)
end

local function LayoutBookCard(row)
	local name, rank, header, bar = row.professionName, row.rank, row.missingHeader, row.statusBar
	name:ClearAllPoints()
	name:SetPoint('TOPLEFT', row, 'TOPLEFT', BOOK.PAD, -BOOK.PAD)
	rank:ClearAllPoints()
	rank:SetPoint('TOPLEFT', name, 'BOTTOMLEFT', 0, -BOOK.LINE)
	rank:SetWidth(BOOK.TEXT_WIDTH)
	rank:SetWordWrap(false)
	header:ClearAllPoints()
	header:SetPoint('TOPLEFT', row, 'TOPLEFT', BOOK.PAD, -BOOK.PAD)
	row.missingText:ClearAllPoints()
	row.missingText:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', 0, -BOOK.LINE)
	row.missingText:SetWidth(BOOK.CARD_WIDTH - BOOK.PAD * 2)
	bar:ClearAllPoints()
	bar:SetSize(BOOK.TEXT_WIDTH, BOOK.BAR)
	bar:SetPoint('BOTTOMLEFT', row, 'BOTTOMLEFT', BOOK.PAD, BOOK.PAD)
	bar.rankText:ClearAllPoints()
	bar.rankText:SetPoint('CENTER', bar, 'CENTER', 0, 0)
	if row.UnlearnButton then
		row.UnlearnButton:ClearAllPoints()
		row.UnlearnButton:SetPoint('LEFT', name, 'RIGHT', UNLEARN_GAP, 0)
	end
	LayoutSpellButton(row.SpellButton1, row, 'RIGHT', -(BOOK.PAD + SPELL.LABEL_GAP + SPELL.LABEL_WIDTH))
	LayoutSpellButton(row.SpellButton2, row.SpellButton1, 'LEFT', -(SPELL.LABEL_GAP + SPELL.LABEL_WIDTH + SPELL.SLOT_GAP))
end

local function LayoutBookCards(frame)
	if bookLaidOut or not Enabled() then return end
	local previous
	for _, name in ipairs(BOOK_ROW_NAMES) do
		local row = _G[name]
		row:SetSize(BOOK.CARD_WIDTH, BOOK.CARD_HEIGHT)
		row:ClearAllPoints()
		if previous then
			row:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', 0, -BOOK.GAP)
		else
			row:SetPoint('TOPLEFT', frame, 'TOPLEFT', BOOK.MARGIN, BOOK.TOP)
		end
		LayoutBookCard(row)
		previous = row
	end
	local count = #BOOK_ROW_NAMES
	frame:SetHeight(BOOK.MARGIN - BOOK.TOP + count * BOOK.CARD_HEIGHT + (count - 1) * BOOK.GAP)
	bookLaidOut = true
end

local function SkinBookRow(row)
	if row.icon then
		Fade(row.icon)
		Fade(_G[row:GetName() .. 'IconBorder'])
	end
	Card(row)
	Skin.TipFont(row.professionName, 'title', BOOK.NAME_SCALE)
	Skin.TipFont(row.rank, 'label')
	Skin.TipFont(row.missingHeader, 'title', BOOK.NAME_SCALE)
	Body(row.missingText)
	SkinBookSpellButton(row.SpellButton1)
	SkinBookSpellButton(row.SpellButton2)
	SkinBookBar(row.statusBar)
end

local function SkinBook(frame)
	Chrome(frame)
	for _, name in ipairs(BOOK_PAGE_NAMES) do Fade(_G[name]) end
	for _, name in ipairs(BOOK_ROW_NAMES) do SkinBookRow(_G[name]) end
	BUI.Events:AfterCombat(function() context.Safely(LayoutBookCards, frame) end, 'Skin.ProfessionsBookLayout')
end

local function InstallTemplates()
	if templatesInstalled then return end
	templatesInstalled = true
	Hook(ProfessionsRecipeListCategoryMixin, 'Init', OnCategoryInit)
	Hook(ProfessionsRecipeListCategoryMixin, 'OnEnter', CategoryLabel)
	Hook(ProfessionsRecipeListCategoryMixin, 'OnLeave', CategoryLabel)
	Hook(ProfessionsRecipeListRecipeMixin, 'Init', OnRecipeInit)
	Hook(ProfessionsRecipeSlotBaseMixin, 'Init', OnSlotInit)
	Hook(ProfessionsReagentSlotButtonMixin, 'SetModifyingRequired', OnModifyingRequired)
	Hook(ProfessionsCrafterTableHeaderStringMixin, 'Init', OnHeaderInit)
end

local function RevealOnceSized(frame)
	if not waitingForWidth then return end
	waitingForWidth = false
	frame:SetAlpha(1)
end

local function HideUntilSized(frame)
	if frame.currentPageWidth then
		RevealOnceSized(frame)
		return
	end
	waitingForWidth = true
	frame:SetAlpha(0)
end

local function InstallCraftingHooks(frame)
	InstallTemplates()
	Hook(ProfessionsCraftingOutputLogElementMixin, 'Init', OnOutputEntry)
	frame:HookScript('OnShow', Wrap('Skin.Professions hide until sized', context.Guard(HideUntilSized)))
	SecureHook(frame, 'SetTab', RevealOnceSized)
	SecureHook(frame, 'ApplyDesiredWidth', RevealOnceSized)
end

context.Window('ProfessionsFrame', { skin = SkinProfessionsFrame, install = InstallCraftingHooks })
context.Window('ProfessionsBookFrame', { skin = SkinBook })
context.Window('ProfessionsCustomerOrdersFrame', { skin = SkinCustomerFrame, install = InstallTemplates })
