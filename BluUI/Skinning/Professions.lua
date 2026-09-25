local _, BUI = ...

local ipairs, pairs, xpcall, geterrorhandler, hooksecurefunc = ipairs, pairs, xpcall, geterrorhandler, hooksecurefunc

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Theme = BUILib.Theme

local SKIN_ID = 'professions'
local FRAME_ART = { 'NineSlice', 'Bg', 'TopTileStreaks', 'Inset' }
local CUSTOMER_FRAME_ART = { 'MoneyFrameInset', 'MoneyFrameBorder' }
local DIALOG_ART = { 'NineSlice', 'Bg' }
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

local frameInstalled, bookInstalled, customerInstalled, templatesInstalled = false, false, false, false
local frameSkinned, bookSkinned, bookLaidOut, customerSkinned = false, false, false, false
local owned = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Tab, Body, Title = context.ScrollBar, context.Tab, context.Body, context.Title
local FlatTexture, AccentTexture, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.CropIcon

local function Safely(handler, ...)
	xpcall(handler, geterrorhandler(), ...)
end

local function Guard(handler)
	return function(...)
		if Enabled() then xpcall(handler, geterrorhandler(), ...) end
	end
end

local function Hook(target, method, handler)
	hooksecurefunc(target, method, Guard(handler))
end

local function Own(texture)
	texture.__buiSkin = true
	owned[texture] = true
	return texture
end

local function NoteFonts()
	if _G[NOTE_FONT] then return end
	Skin.TipFont(CreateFont(NOTE_FONT), 'body')
	Skin.TipFont(CreateFont(NOTE_HINT_FONT), 'label')
end

local function HoverEdges(button)
	if button._buiHoverEdges then return end
	local red, green, blue = Theme.GetAccent()
	local edges = {}
	for edgeIndex = 1, 4 do
		local edge = Own(button:CreateTexture(nil, 'HIGHLIGHT'))
		edge:SetColorTexture(red, green, blue, 1)
		edges[edgeIndex] = edge
	end
	edges[1]:SetPoint('TOPLEFT'); edges[1]:SetPoint('TOPRIGHT'); edges[1]:SetHeight(1)
	edges[2]:SetPoint('BOTTOMLEFT'); edges[2]:SetPoint('BOTTOMRIGHT'); edges[2]:SetHeight(1)
	edges[3]:SetPoint('TOPLEFT'); edges[3]:SetPoint('BOTTOMLEFT'); edges[3]:SetWidth(1)
	edges[4]:SetPoint('TOPRIGHT'); edges[4]:SetPoint('BOTTOMRIGHT'); edges[4]:SetWidth(1)
	button._buiHoverEdges = edges
end

local function SkinButton(button)
	if not button then return end
	Button(button)
	HoverEdges(button)
end

local function FadeStateTextures(button)
	Fade(button:GetNormalTexture())
	Fade(button:GetPushedTexture())
	Fade(button:GetDisabledTexture())
	Fade(button:GetHighlightTexture())
end

local function SkinIconButton(button)
	if not button then return end
	FadeStateTextures(button)
	Shell(button)
	HoverEdges(button)
end

local function SkinPanel(frame)
	FadeKeys(frame, FRAME_ART)
	FadeRegions(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
end

local function SkinDialog(dialog)
	FadeRegions(dialog)
	FadeKeys(dialog, DIALOG_ART)
	Shell(dialog)
	Title(dialog.TitleContainer and dialog.TitleContainer.TitleText)
	Close(dialog.ClosePanelButton)
end

local function TrackArrowState(arrow)
	arrow:HookScript('OnEnable', Skin.RefreshPageButton)
	arrow:HookScript('OnDisable', Skin.RefreshPageButton)
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
	Skin.TipFace(button.Count, 'body')
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
	local line = Own(frame:CreateTexture(nil, 'ARTWORK'))
	local edge = BUI.C.PANEL_BACKDROP
	line:SetColorTexture(edge[5], edge[6], edge[7], edge[8])
	if vertical then
		line:SetPoint('TOP')
		line:SetPoint('BOTTOM')
		line:SetWidth(1)
	else
		line:SetPoint('BOTTOMLEFT', 0, TAB_BASELINE_OFFSET)
		line:SetPoint('BOTTOMRIGHT', 0, TAB_BASELINE_OFFSET)
		line:SetHeight(1)
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
	SkinButton(dialog.AcceptButton)
	SkinButton(dialog.CancelButton)
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
	if ratio > 0 then fill:SetWidth((rankBar:GetWidth() - 2) * ratio) end
	rankBar.Flare:Hide()
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
		Hook(rankBar, 'Update', UpdateRankFill)
	end
	local red, green, blue = Theme.GetAccent()
	rankBar._buiFill:SetVertexColor(red, green, blue, 1)
	Skin.TipFace(rankBar.Rank.Text, 'body')
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
	for _, key in ipairs(CRAFTING_BUTTON_KEYS) do SkinButton(page[key]) end
	SkinSpinner(page.CreateMultipleInputBox)
	for _, slot in ipairs(page.InventorySlots) do SkinItemButton(slot) end
	FadeRegions(page.GearSlotDivider)
	Body(page.ConcentrationDisplay.Amount)
	EditBox(page.MinimizedSearchBox)
	SkinPanel(page.MinimizedSearchResults)
	ScrollBar(page.MinimizedSearchResults.ScrollBar)
	SkinOutputLog(page.CraftingOutputLog)
end

local function OnSpecTabSelected(tab, selected)
	Skin.TipTabSelected(tab, selected == true)
end

local function SkinSpecTab(tab)
	if not tab._buiSpecTab then
		tab._buiSpecTab = true
		tab.StateIcon.__buiSkin = true
		tab.StateIconGlow.__buiSkin = true
		Tab(tab)
		Hook(tab, 'SetTabSelected', OnSpecTabSelected)
	end
	Skin.TipTabSelected(tab, tab.isSelected == true)
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
	SkinButton(detailed.SpendPointsButton)
	SkinButton(detailed.UnlockPathButton)
	DividerLine(spec.VerticalDivider, true)
	DividerLine(spec.TopDivider, false)
	local preview = spec.TreePreview
	Fade(preview.Background)
	Shell(preview)
	Skin.TipFont(preview.Title, 'title', PREVIEW_TITLE_SCALE)
	Body(preview.Description)
	Skin.TipFont(preview.HighlightsHeader, 'label')
	for _, highlight in ipairs(preview.Highlights) do Body(highlight.Description) end
	for _, key in ipairs(SPEC_BUTTON_KEYS) do SkinButton(spec[key]) end
	if not spec._buiSpecHooked then
		spec._buiSpecHooked = true
		Hook(spec, 'InitializeTabs', SweepSpecTabs)
	end
	SweepSpecTabs(spec)
end

local function OnOrderTypeTab(tab, selected)
	Skin.TipTabSelected(tab, selected == true)
end

local function SkinOrderBrowse(browse)
	SkinRecipeList(browse.RecipeList)
	SkinIconButton(browse.FavoritesSearchButton)
	SkinButton(browse.SearchButton)
	FadeKeys(browse.BackButton, PANEL_BUTTON_ART)
	Skin.TipPageButton(browse.BackButton, 'previous')
	SkinList(browse.OrderList)
	for _, tab in ipairs(browse.orderTypeTabs) do
		Tab(tab)
		Skin.TipTabSelected(tab, tab.isSelected == true)
		if not tab._buiTypeTab then
			tab._buiTypeTab = true
			Hook(tab, 'SetTabSelected', OnOrderTypeTab)
		end
	end
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
	for _, key in ipairs(ORDER_INFO_BUTTON_KEYS) do SkinButton(info[key]) end
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
	for _, key in ipairs(ORDER_VIEW_BUTTON_KEYS) do SkinButton(view[key]) end
	local decline = view.DeclineOrderDialog
	SkinDialog(decline)
	Body(decline.ConfirmationText)
	SkinNoteFrame(decline.NoteEditBox)
	SkinButton(decline.CancelButton)
	SkinButton(decline.ConfirmButton)
	SkinOutputLog(view.CraftingOutputLog)
	if not view._buiOrderHook then
		view._buiOrderHook = true
		Hook(view, 'SetOrder', OnOrderSet)
	end
end

local function SkinProfessionsFrame(frame)
	SkinPanel(frame)
	Skin.TipPageButton(frame.MaximizeMinimize.MaximizeButton, 'expand')
	Skin.TipPageButton(frame.MaximizeMinimize.MinimizeButton, 'condense')
	Skin.RegisterTabSystem(frame.TabSystem, context, frame)
	Skin.RefreshTabSystem(frame.TabSystem)
	SkinCraftingPage(frame.CraftingPage)
	SkinSpecPage(frame.SpecPage)
	SkinOrderBrowse(frame.OrdersPage.BrowseFrame)
	SkinOrderView(frame.OrdersPage.OrderView)
end

local function OnCategoryButton(button)
	if button.isSpacer then return end
	button.NormalTexture:SetAlpha(0)
	button.Lines:SetAlpha(0)
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
	SkinButton(bar.SearchButton)
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
	SkinButton(payment.ListOrderButton)
	SkinButton(payment.CancelOrderButton)
end

local function SkinListings(listings)
	SkinDialog(listings)
	FadeKeys(listings, FRAME_ART)
	SkinList(listings.OrderList)
	SkinButton(listings.CloseButton)
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
	SkinButton(form.BackButton)
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
	SkinPanel(frame)
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

local function PlaceSpellButton(button, point, relativeTo, relativePoint, x, y)
	button:ClearAllPoints()
	button:SetPoint(point, relativeTo, relativePoint, x, y)
end

local function LayoutPrimaryCard(row)
	local textX = BOOK_CARD_PADDING + BOOK_ICON_SIZE + BOOK_ICON_GAP
	local border = _G[row:GetName() .. 'IconBorder']
	border:ClearAllPoints()
	border:SetSize(BOOK_ICON_SIZE, BOOK_ICON_SIZE)
	border:SetPoint('LEFT', row, 'LEFT', BOOK_CARD_PADDING, 0)
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

local function LayoutBookCards(frame)
	if bookLaidOut or not Enabled() then return end
	local previous
	for index, name in ipairs(BOOK_ROW_NAMES) do
		local row = _G[name]
		local primary = index <= PRIMARY_CARD_COUNT
		row:SetSize(BOOK_CARD_WIDTH, primary and PRIMARY_CARD_HEIGHT or SECONDARY_CARD_HEIGHT)
		row:ClearAllPoints()
		if previous then
			row:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', 0, -(index == PRIMARY_CARD_COUNT + 1 and BOOK_GROUP_GAP or BOOK_CARD_GAP))
		else
			row:SetPoint('TOPLEFT', frame, 'TOPLEFT', BOOK_COLUMN_X, BOOK_TOP_Y)
		end
		if primary then LayoutPrimaryCard(row) else LayoutSecondaryCard(row) end
		local rankText = row.statusBar.rankText
		rankText:ClearAllPoints()
		rankText:SetPoint('CENTER', row.statusBar, 'CENTER', 0, 0)
		previous = row
	end
	bookLaidOut = true
end

local function SkinBookRow(row, primary)
	local icon = row.icon
	if icon then
		Fade(_G[row:GetName() .. 'IconBorder'])
	end
	if icon and not row._buiIcon then
		row._buiIcon = true
		icon:RemoveMaskTexture(row.CircleMask)
		icon:SetBlendMode('BLEND')
		icon:SetAlpha(1)
		icon:SetDesaturation(0)
		CropIcon(icon)
		Skin.TipIconFrame(row, icon)
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
end

local function SkinBook(frame)
	SkinPanel(frame)
	for _, name in ipairs(BOOK_PAGE_NAMES) do Fade(_G[name]) end
	for index, name in ipairs(BOOK_ROW_NAMES) do SkinBookRow(_G[name], index <= PRIMARY_CARD_COUNT) end
	BUI.Events:AfterCombat(function() Safely(LayoutBookCards, frame) end, 'Skin.ProfessionsBookLayout')
end

local function ApplyFrame()
	local frame = _G.ProfessionsFrame
	if frameSkinned or not frame or frame:IsForbidden() or not Enabled() then return end
	SkinProfessionsFrame(frame)
	frameSkinned = true
end

local function ApplyBook()
	local frame = _G.ProfessionsBookFrame
	if bookSkinned or not frame or frame:IsForbidden() or not Enabled() then return end
	SkinBook(frame)
	bookSkinned = true
end

local function ApplyCustomer()
	local frame = _G.ProfessionsCustomerOrdersFrame
	if customerSkinned or not frame or frame:IsForbidden() or not Enabled() then return end
	SkinCustomerFrame(frame)
	customerSkinned = true
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

local function InstallFrame()
	local frame = _G.ProfessionsFrame
	if frameInstalled or not frame then return end
	frameInstalled = true
	InstallTemplates()
	Hook(ProfessionsCraftingOutputLogElementMixin, 'Init', OnOutputEntry)
	frame:HookScript('OnShow', Guard(ApplyFrame))
	Safely(ApplyFrame)
end

local function InstallBook()
	local frame = _G.ProfessionsBookFrame
	if bookInstalled or not frame then return end
	bookInstalled = true
	frame:HookScript('OnShow', Guard(ApplyBook))
	Safely(ApplyBook)
end

local function InstallCustomer()
	local frame = _G.ProfessionsCustomerOrdersFrame
	if customerInstalled or not frame then return end
	customerInstalled = true
	InstallTemplates()
	frame:HookScript('OnShow', Guard(ApplyCustomer))
	Safely(ApplyCustomer)
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

local function SetOwnedShown(shown)
	for texture in pairs(owned) do texture:SetShown(shown) end
end

local function Deactivate()
	context.Restore()
	SetOwnedShown(false)
	frameSkinned, bookSkinned, customerSkinned = false, false, false
	BUI.Print('Professions skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		SetOwnedShown(true)
		TryInstall()
		if not AllInstalled() then BUI.Events:Register('ADDON_LOADED', 'Skin.Professions', TryInstall) end
		Safely(ApplyFrame)
		Safely(ApplyBook)
		Safely(ApplyCustomer)
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Professions',
	description = 'The professions book, crafting window and crafting orders: recipe list, schematic panel, flat rank bar, tabs, specializations, the crafter order browser and order view, and the customer order window (NPC only, so the preview shows the book).',
	icon = 'Interface/Icons/Trade_Engineering',
})

BUI.Events:Once('PLAYER_LOGIN', 'Skin.ProfessionsInstall', function()
	if not Enabled() then return end
	TryInstall()
	if not AllInstalled() then BUI.Events:Register('ADDON_LOADED', 'Skin.Professions', TryInstall) end
end)
