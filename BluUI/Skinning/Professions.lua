local _, BUI = ...

local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Theme = BUILib.Theme

local SKIN_ID = 'professions'
local MAIN_ART = { 'Bg', 'TopTileStreaks', 'Inset' }
local CUSTOMER_MAIN_ART = { 'MoneyFrameInset', 'MoneyFrameBorder' }
local RECIPE_LIST_ART = { 'Background', 'BackgroundNineSlice' }
local SCHEMATIC_ART = { 'Background', 'MinimalBackground', 'NineSlice' }
local RANK_BAR_ART = { 'Background', 'Border' }
local CATEGORY_ART = { 'LeftPiece', 'RightPiece', 'CenterPiece' }
local LIST_ART = { 'Background', 'NineSlice' }
local HEADER_ART = { 'Left', 'Middle', 'Right' }
local DIALOG_ART = { 'NineSlice', 'Bg' }
local REAGENT_CONTAINER_KEYS = { 'Reagents', 'OptionalReagents', 'FinishingReagents' }
local QUALITY_CONTAINER_KEYS = { 'Container1', 'Container2', 'Container3' }
local SCHEMATIC_BODY_KEYS = { 'OutputSubText', 'Description', 'RequiredTools', 'RecraftingDescription', 'RecraftingRequiredTools' }
local ORDER_TYPE_TAB_KEYS = { 'PublicOrdersButton', 'GuildOrdersButton', 'NpcOrdersButton', 'PersonalOrdersButton' }
local ORDER_INFO_LABEL_KEYS = { 'PostedByTitle', 'CommissionTitle', 'ConsortiumCutTitle', 'FinalTipTitle', 'TimeRemainingTitle' }
local ORDER_INFO_BODY_KEYS = { 'PostedByValue', 'TimeRemainingValue' }
local ORDER_INFO_BUTTON_KEYS = { 'BackButton', 'StartOrderButton', 'DeclineOrderButton', 'ReleaseOrderButton' }
local ORDER_VIEW_BUTTON_KEYS = { 'CreateButton', 'CompleteOrderButton', 'StartRecraftButton', 'StopRecraftButton' }
local PAYMENT_LABEL_KEYS = { 'Tip', 'Duration', 'TimeRemaining', 'PostingFee', 'TotalPrice' }
local FORM_PANEL_KEYS = { 'LeftPanelBackground', 'RightPanelBackground' }
local BOOK_ROW_NAMES = { 'PrimaryProfession1', 'PrimaryProfession2', 'SecondaryProfession1', 'SecondaryProfession2', 'SecondaryProfession3' }
local BOOK_BAR_ART = { 'Left', 'Right', 'BGLeft', 'BGRight', 'BGMiddle' }
local BOOK_PAGE_NAMES = { 'ProfessionsBookPage1', 'ProfessionsBookPage2' }
local CATEGORY_FILL_ALPHA = 0.04
local ROW_SELECTED_ALPHA = 0.18
local ROW_HOVER_ALPHA = 0.06
local OUTPUT_TITLE_SCALE = 1.2
local BOOK_TITLE_SCALE = 1.25
local BOOK_SUBTITLE_SCALE = 1.1
local BOOK_CARD_WIDTH = 437
local BOOK_COLUMN_X = 56
local BOOK_TOP_Y = -67
local PRIMARY_CARD_COUNT = 2
local PRIMARY_CARD_HEIGHT, SECONDARY_CARD_HEIGHT = 88, 64
local BOOK_CARD_GAP, BOOK_GROUP_GAP = 10, 18
local BOOK_CARD_PADDING = 10
local BOOK_ICON_SIZE, BOOK_ICON_GAP = 64, 12
local BOOK_BAR_WIDTH, BOOK_BAR_HEIGHT = 100, 14
local SPELL_LABEL_WIDTH = 100
local SPELL_BUTTON_SIZE = 40
local SECONDARY_TEXT_WIDTH = 120

local frameInstalled, bookInstalled, customerInstalled = false, false, false
local frameSkinned, bookSkinned, customerSkinned = false, false, false
local templatesHooked = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Tab, Body, Title = context.ScrollBar, context.Tab, context.Body, context.Title
local FlatTexture, AccentTexture, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.CropIcon

local function AccentColor(fontString)
	local red, green, blue = Theme.GetAccent()
	fontString:SetTextColor(red, green, blue, 1)
end

local function FadeStateTextures(button)
	Fade(button:GetNormalTexture())
	Fade(button:GetPushedTexture())
	Fade(button:GetDisabledTexture())
	Fade(button:GetHighlightTexture())
end

local function IconButtonEnter(button)
	Skin.TipShellEdges(button, true)
end

local function IconButtonLeave(button)
	Skin.TipShellEdges(button, false)
end

local function SkinIconButton(button)
	if not button then return end
	if not button._buiIconButton then
		button._buiIconButton = true
		FadeStateTextures(button)
		button:HookScript('OnEnter', IconButtonEnter)
		button:HookScript('OnLeave', IconButtonLeave)
	end
	Shell(button)
end

local function SkinPanelFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	FadeRegions(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
end

local function SkinDialogPanel(panel)
	if not panel then return end
	FadeRegions(panel)
	FadeKeys(panel, DIALOG_ART)
	Shell(panel)
	Title(panel.TitleContainer and panel.TitleContainer.TitleText)
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
	Skin.TipFace(button.Count, 'body')
end

local function SkinStatusBar(bar)
	if not bar or bar._buiBar then return end
	bar._buiBar = true
	bar:SetStatusBarTexture(BUI.GetGlobalTexture())
	local red, green, blue = Theme.GetAccent()
	bar:SetStatusBarColor(red, green, blue, 1)
	Shell(bar)
end

local function OnCategoryRow(category)
	if not Enabled() or category._buiCategory then return end
	category._buiCategory = true
	FadeKeys(category, CATEGORY_ART)
	local fill = category:CreateTexture(nil, 'BACKGROUND')
	fill.__buiSkin = true
	fill:SetAllPoints(category)
	FlatTexture(fill, 1, 1, 1, CATEGORY_FILL_ALPHA)
	Skin.TipFace(category.Label, 'title')
end

local function OnRecipeRow(row)
	if not Enabled() or row._buiRecipe then return end
	row._buiRecipe = true
	row.SelectedOverlay:SetBlendMode('BLEND')
	AccentTexture(row.SelectedOverlay, ROW_SELECTED_ALPHA)
	row.HighlightOverlay:SetBlendMode('BLEND')
	FlatTexture(row.HighlightOverlay, 1, 1, 1, ROW_HOVER_ALPHA)
	Skin.TipFace(row.Label, 'body')
	Skin.TipFace(row.Count, 'body')
	if row.SkillUps then Skin.TipFace(row.SkillUps.Text, 'body') end
end

local function OnReagentSlot(slot)
	if not Enabled() then return end
	SkinSlotButton(slot.Button)
	Skin.TipFace(slot.Name, 'body')
	if slot.Checkbox and not slot._buiCheck then
		slot._buiCheck = true
		CheckBox(slot.Checkbox)
	end
end

local function OnHeaderInit(header)
	if not Enabled() or header._buiHeader or not header.Arrow then return end
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
	if cell.Icon and cell.IconBorder then
		Fade(cell.IconBorder)
		CropIcon(cell.Icon)
		Skin.TipIconFrame(cell, cell.Icon)
	end
end

local function OnTableRow(row)
	if not Enabled() then return end
	local highlight = row.HighlightTexture
	if highlight then
		highlight:SetBlendMode('BLEND')
		FlatTexture(highlight, 1, 1, 1, ROW_HOVER_ALPHA)
	end
	for _, cell in ipairs(row.cells or {}) do SkinCell(cell) end
end

local function SkinList(list)
	if not list or list._buiList then return end
	list._buiList = true
	FadeKeys(list, LIST_ART)
	Shell(list.NineSlice)
	Shell(list.HeaderContainer)
	ScrollBar(list.ScrollBar)
	Body(list.ResultsText)
	if list.HeaderContainer then
		for _, header in ipairs({ list.HeaderContainer:GetChildren() }) do OnHeaderInit(header) end
	end
	Skin.SweepScrollBox(list.ScrollBox, OnTableRow)
end

local function SkinRecipeList(list)
	if not list then return end
	FadeKeys(list, RECIPE_LIST_ART)
	Shell(list)
	Dropdown(list.FilterDropdown)
	EditBox(list.SearchBox)
	ScrollBar(list.ScrollBar)
	Body(list.NoResultsText)
end

local function SkinSchematicText(form)
	CheckBox(form.TrackRecipeCheckbox)
	CheckBox(form.AllocateBestQualityCheckbox)
	Skin.TipFont(form.OutputText, 'title', OUTPUT_TITLE_SCALE)
	Skin.TipFace(form.RecraftingOutputText, 'title')
	for _, key in ipairs(SCHEMATIC_BODY_KEYS) do Skin.TipFace(form[key], 'body') end
	for _, key in ipairs(REAGENT_CONTAINER_KEYS) do
		local container = form[key]
		if container then Skin.TipFont(container.Label, 'label') end
	end
	if form.RecipeSourceButton then Body(form.RecipeSourceButton.Text) end
end

local function SkinQualitySpinner(spinner)
	EditBox(spinner)
	Skin.TipPageButton(spinner.DecrementButton, 'previous')
	Skin.TipPageButton(spinner.IncrementButton, 'next')
end

local function SkinQualityDialog(dialog)
	if not dialog then return end
	SkinDialogPanel(dialog)
	Close(dialog.ClosePanelButton)
	for _, key in ipairs(QUALITY_CONTAINER_KEYS) do
		local container = dialog[key]
		SkinItemButton(container.Button)
		SkinQualitySpinner(container.EditBox)
	end
	Button(dialog.AcceptButton)
	Button(dialog.CancelButton)
end

local function SkinSchematic(form)
	if not form then return end
	FadeKeys(form, SCHEMATIC_ART)
	Shell(form)
	SkinSchematicText(form)
	SkinQualityDialog(form.QualityDialog)
end

local function SkinRankBar(rankBar)
	if not rankBar then return end
	FadeKeys(rankBar, RANK_BAR_ART)
	Shell(rankBar)
end

local function SkinConcentration(concentration)
	if not concentration then return end
	Body(concentration.Amount)
	Skin.TipFont(concentration.Label, 'label')
end

local function SkinCraftingPage(page)
	if not page then return end
	SkinRecipeList(page.RecipeList)
	SkinSchematic(page.SchematicForm)
	SkinRankBar(page.RankBar)
	Button(page.CreateButton)
	Button(page.CreateAllButton)
	Button(page.ViewGuildCraftersButton)
	local spinner = page.CreateMultipleInputBox
	if spinner then
		EditBox(spinner)
		Skin.TipPageButton(spinner.DecrementButton, 'previous')
		Skin.TipPageButton(spinner.IncrementButton, 'next')
	end
	for _, slot in ipairs(page.InventorySlots or {}) do SkinItemButton(slot) end
	SkinConcentration(page.ConcentrationDisplay)
	EditBox(page.MinimizedSearchBox)
end

local function OnOrderTypeTab(tab, selected)
	if Enabled() then Skin.TipTabSelected(tab, selected == true) end
end

local function SkinOrderTypeTabs(browse)
	for _, key in ipairs(ORDER_TYPE_TAB_KEYS) do
		local tab = browse[key]
		if tab then
			Tab(tab)
			Skin.TipTabSelected(tab, tab.isSelected == true)
			if not tab._buiTypeTab then
				tab._buiTypeTab = true
				hooksecurefunc(tab, 'SetTabSelected', OnOrderTypeTab)
			end
		end
	end
end

local function SkinOrderBrowse(browse)
	if not browse then return end
	SkinRecipeList(browse.RecipeList)
	SkinIconButton(browse.FavoritesSearchButton)
	Button(browse.SearchButton)
	Skin.TipPageButton(browse.BackButton, 'previous')
	SkinList(browse.OrderList)
	SkinOrderTypeTabs(browse)
	local remaining = browse.OrdersRemainingDisplay
	if remaining then
		Fade(remaining.Background)
		Body(remaining.OrdersRemaining)
	end
end

local function SkinNoteFrame(note)
	if not note then return end
	Fade(note.Border)
	Shell(note)
	if note.TitleBox then Skin.TipFont(note.TitleBox.Title, 'label') end
	local scrolling = note.ScrollingEditBox
	local editBox = scrolling and scrolling.GetEditBox and scrolling:GetEditBox()
	if editBox then Skin.TipFace(editBox, 'body') end
end

local function SkinNoteBox(box)
	if not box then return end
	if box.Background then Fade(box.Background.Border) end
	Shell(box)
	Skin.TipFont(box.NoteTitle, 'label')
	Skin.TipFace(box.NoteText, 'body')
end

local function SkinOrderInfo(info)
	if not info then return end
	FadeKeys(info, LIST_ART)
	Fade(info.CutDivider)
	Shell(info)
	for _, key in ipairs(ORDER_INFO_LABEL_KEYS) do Skin.TipFont(info[key], 'label') end
	for _, key in ipairs(ORDER_INFO_BODY_KEYS) do Body(info[key]) end
	for _, key in ipairs(ORDER_INFO_BUTTON_KEYS) do Button(info[key]) end
	SkinIconButton(info.SocialDropdown)
	SkinNoteBox(info.NoteBox)
	if info.OrderReagentsWarning then Skin.TipFace(info.OrderReagentsWarning.Text, 'body') end
	local rewards = info.NPCRewardsFrame
	if rewards then
		Fade(rewards.Background)
		Skin.TipFont(rewards.RewardText, 'label')
		for _, item in ipairs(rewards.RewardItems or {}) do SkinSlotButton(item) end
	end
end

local function SkinOrderDetails(details)
	if not details then return end
	FadeKeys(details, LIST_ART)
	Shell(details)
	local form = details.SchematicForm
	if form then
		FadeKeys(form, SCHEMATIC_ART)
		SkinSchematicText(form)
	end
	local fulfillment = details.FulfillmentForm
	if fulfillment then
		Skin.TipFace(fulfillment.ItemName, 'title', OUTPUT_TITLE_SCALE)
		Body(fulfillment.OrderCompleteText)
		SkinNoteFrame(fulfillment.NoteEditBox)
	end
end

local function SkinDeclineDialog(dialog)
	if not dialog then return end
	SkinDialogPanel(dialog)
	Body(dialog.ConfirmationText)
	SkinNoteFrame(dialog.NoteEditBox)
	Button(dialog.CancelButton)
	Button(dialog.ConfirmButton)
end

local function OnOrderSet(view)
	if not Enabled() then return end
	local info = view.OrderInfo
	if info.NoteBox then Skin.TipFont(info.NoteBox.NoteTitle, 'label') end
	if info.NPCRewardsFrame then
		for _, item in ipairs(info.NPCRewardsFrame.RewardItems or {}) do SkinSlotButton(item) end
	end
end

local function SkinOrderView(view)
	if not view then return end
	SkinOrderInfo(view.OrderInfo)
	SkinOrderDetails(view.OrderDetails)
	SkinRankBar(view.RankBar)
	SkinConcentration(view.ConcentrationDisplay)
	for _, key in ipairs(ORDER_VIEW_BUTTON_KEYS) do Button(view[key]) end
	SkinDeclineDialog(view.DeclineOrderDialog)
	if not view._buiOrderHook and view.SetOrder then
		view._buiOrderHook = true
		hooksecurefunc(view, 'SetOrder', OnOrderSet)
	end
end

local function SkinOrdersPage(page)
	if not page then return end
	SkinOrderBrowse(page.BrowseFrame)
	SkinOrderView(page.OrderView)
end

local function SkinProfessionsFrame(frame)
	SkinPanelFrame(frame)
	if frame.MaximizeMinimize then
		Skin.TipPageButton(frame.MaximizeMinimize.MaximizeButton, 'expand')
		Skin.TipPageButton(frame.MaximizeMinimize.MinimizeButton, 'condense')
	end
	Skin.RegisterTabSystem(frame.TabSystem, context, frame)
	SkinCraftingPage(frame.CraftingPage)
	SkinOrdersPage(frame.OrdersPage)
end

local function RecolorCategoryButton(button)
	if not Enabled() or button.isSpacer then return end
	local text = button.Text
	if not text then return end
	local info = button.categoryInfo
	local primary = info and info.type == Enum.CraftingOrderCustomerCategoryType.Primary
	Skin.TipFont(text, primary and 'title' or 'body')
	if button.SelectedTexture:IsShown() then AccentColor(text) end
end

local function OnCategoryButton(button)
	if not Enabled() or button.isSpacer then return end
	button.NormalTexture:SetAlpha(0)
	button.Lines:SetAlpha(0)
	local selected, highlight = button.SelectedTexture, button.HighlightTexture
	selected:SetBlendMode('BLEND')
	AccentTexture(selected, ROW_SELECTED_ALPHA)
	highlight:SetBlendMode('BLEND')
	FlatTexture(highlight, 1, 1, 1, ROW_HOVER_ALPHA)
	if not button._buiCategoryButton and button.UpdateSelected then
		button._buiCategoryButton = true
		hooksecurefunc(button, 'UpdateSelected', RecolorCategoryButton)
	end
	RecolorCategoryButton(button)
end

local function SkinSearchBar(bar)
	if not bar then return end
	SkinIconButton(bar.FavoritesSearchButton)
	EditBox(bar.SearchBox)
	Button(bar.SearchButton)
	Dropdown(bar.FilterDropdown)
end

local function SkinBrowseOrders(page)
	if not page then return end
	SkinSearchBar(page.SearchBar)
	local categories = page.CategoryList
	if categories then
		FadeKeys(categories, LIST_ART)
		Shell(categories)
		ScrollBar(categories.ScrollBar)
		Skin.SweepScrollBox(categories.ScrollBox, OnCategoryButton)
	end
	SkinList(page.RecipeList)
end

local function SkinMyOrders(page)
	if not page then return end
	SkinIconButton(page.RefreshButton)
	SkinList(page.OrderList)
end

local function SkinMoneyInput(frame)
	if not frame then return end
	for _, child in ipairs({ frame:GetChildren() }) do
		if child:IsObjectType('EditBox') then EditBox(child) end
	end
end

local function SkinPayment(payment)
	if not payment then return end
	for _, key in ipairs(PAYMENT_LABEL_KEYS) do Skin.TipFont(payment[key], 'label') end
	SkinNoteFrame(payment.NoteEditBox)
	SkinMoneyInput(payment.TipMoneyInputFrame)
	if payment.TimeRemainingDisplay then Body(payment.TimeRemainingDisplay.Text) end
	Dropdown(payment.DurationDropdown)
	Button(payment.ListOrderButton)
	Button(payment.CancelOrderButton)
end

local function SkinListings(listings)
	if not listings then return end
	SkinDialogPanel(listings)
	SkinList(listings.OrderList)
	Button(listings.CloseButton)
end

local function SkinCustomerForm(form)
	if not form then return end
	Fade(form.RecipeHeader)
	Skin.TipFace(form.RecipeName, 'title', OUTPUT_TITLE_SCALE)
	Skin.TipFace(form.RecraftRecipeName, 'title', OUTPUT_TITLE_SCALE)
	Skin.TipFont(form.ProfessionText, 'label')
	Body(form.OrderStateText)
	for _, key in ipairs(FORM_PANEL_KEYS) do
		local panel = form[key]
		if panel then
			FadeKeys(panel, LIST_ART)
			Shell(panel)
		end
	end
	Button(form.BackButton)
	local minimum = form.MinimumQuality
	if minimum then
		Skin.TipFont(minimum.Text, 'label')
		Dropdown(minimum.Dropdown)
	end
	Dropdown(form.OrderRecipientDropdown)
	EditBox(form.OrderRecipientTarget)
	local recipient = form.OrderRecipientDisplay
	if recipient then
		Skin.TipFont(recipient.PostedTo, 'label')
		Skin.TipFont(recipient.Crafter, 'label')
		Body(recipient.CrafterValue)
		SkinIconButton(recipient.SocialDropdown)
	end
	local reagents = form.ReagentContainer
	if reagents then
		for _, key in ipairs(REAGENT_CONTAINER_KEYS) do
			local container = reagents[key]
			if container then Skin.TipFont(container.Label, 'label') end
		end
		Skin.TipFace(reagents.RecraftInfoText, 'body')
	end
	SkinPayment(form.PaymentContainer)
	local track = form.TrackRecipeCheckbox
	if track then
		Skin.TipFont(track.Text, 'label')
		CheckBox(track.Checkbox)
	end
	CheckBox(form.AllocateBestQualityCheckbox)
	SkinListings(form.CurrentListings)
end

local function SkinCustomerFrame(frame)
	SkinPanelFrame(frame)
	FadeKeys(frame, CUSTOMER_MAIN_ART)
	Skin.RegisterTabStrip(frame, frame.Tabs, context)
	SkinBrowseOrders(frame.BrowseOrders)
	SkinMyOrders(frame.MyOrdersPage)
	SkinCustomerForm(frame.Form)
end

local function SkinBookSpellButton(button)
	if not button then return end
	local name = button:GetName()
	Fade(name and _G[name .. 'NameFrame'])
	CropIcon(button.IconTexture)
	Skin.TipIconFrame(button, button.IconTexture)
	Body(button.spellString)
	Skin.TipFont(button.subSpellString, 'label')
end

local function SkinBookBar(bar)
	if not bar then return end
	local name = bar:GetName()
	for _, key in ipairs(BOOK_BAR_ART) do Fade(name and _G[name .. key]) end
	SkinStatusBar(bar)
	Skin.TipFace(bar.rankText, 'body')
end

local function PlaceSpellButton(button, point, relativeTo, relativePoint, x, y)
	if not button then return end
	button:ClearAllPoints()
	button:SetPoint(point, relativeTo, relativePoint, x, y)
end

local function LayoutPrimaryCard(row)
	local textX = BOOK_CARD_PADDING + BOOK_ICON_SIZE + BOOK_ICON_GAP
	local border = _G[row:GetName() .. 'IconBorder']
	if border then
		border:ClearAllPoints()
		border:SetSize(BOOK_ICON_SIZE, BOOK_ICON_SIZE)
		border:SetPoint('LEFT', row, 'LEFT', BOOK_CARD_PADDING, 0)
	end
	row.professionName:ClearAllPoints()
	row.professionName:SetPoint('TOPLEFT', row, 'TOPLEFT', textX, -BOOK_CARD_PADDING)
	row.specialization:ClearAllPoints()
	row.specialization:SetPoint('TOPLEFT', row.professionName, 'BOTTOMLEFT', 0, -2)
	row.rank:ClearAllPoints()
	row.rank:SetPoint('TOPLEFT', row.specialization, 'BOTTOMLEFT', 0, -4)
	local bar = row.statusBar
	bar:ClearAllPoints()
	bar:SetSize(BOOK_BAR_WIDTH, BOOK_BAR_HEIGHT)
	bar:SetPoint('BOTTOMLEFT', row, 'BOTTOMLEFT', textX, BOOK_CARD_PADDING)
	row.UnlearnButton:ClearAllPoints()
	row.UnlearnButton:SetPoint('LEFT', bar, 'RIGHT', 8, 0)
	row.missingHeader:ClearAllPoints()
	row.missingHeader:SetPoint('TOPLEFT', row, 'TOPLEFT', textX, -BOOK_CARD_PADDING - 4)
	PlaceSpellButton(row.SpellButton2, 'TOPRIGHT', row, 'TOPRIGHT', -(SPELL_LABEL_WIDTH + BOOK_CARD_PADDING), -4)
	PlaceSpellButton(row.SpellButton1, 'TOPLEFT', row.SpellButton2, 'BOTTOMLEFT', 0, 0)
end

local function LayoutSecondaryCard(row)
	row.professionName:ClearAllPoints()
	row.professionName:SetPoint('TOPLEFT', row, 'TOPLEFT', BOOK_CARD_PADDING, -BOOK_CARD_PADDING)
	row.rank:ClearAllPoints()
	row.rank:SetWidth(SECONDARY_TEXT_WIDTH)
	row.rank:SetWordWrap(false)
	row.rank:SetPoint('TOPLEFT', row.professionName, 'BOTTOMLEFT', 0, -2)
	local bar = row.statusBar
	bar:ClearAllPoints()
	bar:SetSize(BOOK_BAR_WIDTH, BOOK_BAR_HEIGHT)
	bar:SetPoint('BOTTOMLEFT', row, 'BOTTOMLEFT', BOOK_CARD_PADDING, BOOK_CARD_PADDING)
	row.missingHeader:ClearAllPoints()
	row.missingHeader:SetPoint('TOPLEFT', row, 'TOPLEFT', BOOK_CARD_PADDING, -BOOK_CARD_PADDING)
	local buttonY = -math.floor((SECONDARY_CARD_HEIGHT - SPELL_BUTTON_SIZE) / 2)
	PlaceSpellButton(row.SpellButton1, 'TOPRIGHT', row, 'TOPRIGHT', -(SPELL_LABEL_WIDTH + BOOK_CARD_PADDING), buttonY)
	PlaceSpellButton(row.SpellButton2, 'TOPRIGHT', row.SpellButton1, 'TOPLEFT', -(SPELL_LABEL_WIDTH + BOOK_CARD_PADDING), 0)
end

local function SkinBookRow(row, primary)
	if not row then return end
	Fade(_G[row:GetName() .. 'IconBorder'])
	if row.icon then
		if row.CircleMask then row.icon:RemoveMaskTexture(row.CircleMask) end
		row.icon:SetBlendMode('BLEND')
		CropIcon(row.icon)
		Skin.TipIconFrame(row, row.icon)
	end
	Shell(row)
	Skin.TipFont(row.professionName, 'title', primary and BOOK_TITLE_SCALE or BOOK_SUBTITLE_SCALE)
	Body(row.specialization)
	Skin.TipFont(row.rank, 'label')
	Title(row.missingHeader)
	Body(row.missingText)
	SkinBookSpellButton(row.SpellButton1)
	SkinBookSpellButton(row.SpellButton2)
	SkinBookBar(row.statusBar)
	if primary then LayoutPrimaryCard(row) else LayoutSecondaryCard(row) end
end

local function LayoutBookCards(frame)
	local previous
	for index, name in ipairs(BOOK_ROW_NAMES) do
		local row = _G[name]
		if row then
			local primary = index <= PRIMARY_CARD_COUNT
			row:SetSize(BOOK_CARD_WIDTH, primary and PRIMARY_CARD_HEIGHT or SECONDARY_CARD_HEIGHT)
			row:ClearAllPoints()
			if previous then
				row:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', 0, -(index == PRIMARY_CARD_COUNT + 1 and BOOK_GROUP_GAP or BOOK_CARD_GAP))
			else
				row:SetPoint('TOPLEFT', frame, 'TOPLEFT', BOOK_COLUMN_X, BOOK_TOP_Y)
			end
			SkinBookRow(row, primary)
			previous = row
		end
	end
end

local function SkinBook(frame)
	SkinPanelFrame(frame)
	for _, name in ipairs(BOOK_PAGE_NAMES) do Fade(_G[name]) end
	LayoutBookCards(frame)
end

local function ApplyFrame()
	local frame = _G.ProfessionsFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not frameSkinned then
		frameSkinned = true
		SkinProfessionsFrame(frame)
	end
	Skin.RefreshTabSystem(frame.TabSystem)
end

local function ApplyBook()
	local frame = _G.ProfessionsBookFrame
	if not frame or frame:IsForbidden() or not Enabled() or bookSkinned then return end
	bookSkinned = true
	SkinBook(frame)
end

local function ApplyCustomer()
	local frame = _G.ProfessionsCustomerOrdersFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not customerSkinned then
		customerSkinned = true
		SkinCustomerFrame(frame)
	end
	Skin.RefreshTabStrip(frame)
end

local function HookMixin(mixin, method, callback)
	if mixin and mixin[method] then hooksecurefunc(mixin, method, callback) end
end

local function HookTemplates()
	if templatesHooked or not _G.ProfessionsCrafterTableHeaderStringMixin then return end
	templatesHooked = true
	HookMixin(_G.ProfessionsCrafterTableHeaderStringMixin, 'Init', OnHeaderInit)
	HookMixin(_G.ProfessionsReagentSlotMixin, 'Init', OnReagentSlot)
end

local function InstallFrame()
	if frameInstalled then return end
	local frame = _G.ProfessionsFrame
	if not frame then return end
	frameInstalled = true
	frame:HookScript('OnShow', ApplyFrame)
	HookMixin(_G.ProfessionsRecipeListCategoryMixin, 'Init', OnCategoryRow)
	HookMixin(_G.ProfessionsRecipeListRecipeMixin, 'Init', OnRecipeRow)
	HookTemplates()
	if frame:IsShown() then ApplyFrame() end
end

local function InstallBook()
	if bookInstalled then return end
	local frame = _G.ProfessionsBookFrame
	if not frame then return end
	bookInstalled = true
	frame:HookScript('OnShow', ApplyBook)
	if frame:IsShown() then ApplyBook() end
end

local function InstallCustomer()
	if customerInstalled then return end
	local frame = _G.ProfessionsCustomerOrdersFrame
	if not frame then return end
	customerInstalled = true
	frame:HookScript('OnShow', ApplyCustomer)
	HookTemplates()
	if frame:IsShown() then ApplyCustomer() end
end

local function AllInstalled()
	return frameInstalled and bookInstalled and customerInstalled
end

local function TryInstall()
	InstallFrame()
	InstallBook()
	InstallCustomer()
	if AllInstalled() then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Professions') end
end

local function Deactivate()
	context.Restore()
	frameSkinned = false
	bookSkinned = false
	customerSkinned = false
	BUI.Print('Professions skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		TryInstall()
		if not AllInstalled() then BUI.Events:Register('ADDON_LOADED', 'Skin.Professions', TryInstall) end
		ApplyFrame()
		ApplyBook()
		ApplyCustomer()
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Professions',
	description = 'The professions book, crafting window and crafting orders: recipe list, schematic panel, rank bar, tabs, the crafter order browser and order view, and the customer order window (NPC only, so the preview shows the book).',
	icon = 'Interface/Icons/Trade_Engineering',
})

BUI.Events:Once('PLAYER_LOGIN', 'Skin.ProfessionsInstall', function()
	if not Enabled() then return end
	TryInstall()
	if not AllInstalled() then BUI.Events:Register('ADDON_LOADED', 'Skin.Professions', TryInstall) end
end)
