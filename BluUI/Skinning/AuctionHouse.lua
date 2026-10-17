local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning
local Painter = BUI.Painter

local BACKGROUND_KEYS = { 'Background', 'NineSlice' }
local MONEY_ART = { 'MoneyFrameInset', 'MoneyFrameBorder' }
local SELL_TAB_ART = { 'CreateAuctionTabLeft', 'CreateAuctionTabMiddle', 'CreateAuctionTabRight' }
local MULTISELL_ART = { 'Fill', 'Left', 'Right', 'Middle' }
local PROGRESS_ART = { 'DropShadow', 'TextBorder', 'Background', 'Border' }
local SELL_CONTROL_KEYS = { 'QuantityInput', 'PriceInput', 'Duration', 'Deposit', 'TotalPrice' }
local BUY_CONTROL_KEYS = { 'QuantityInput', 'UnitPrice', 'TotalPrice' }
local LABEL_KEYS = { 'Label', 'LabelTitle' }
local AUCTIONS_LIST_KEYS = { 'AllAuctionsList', 'BidsList', 'ItemList', 'CommoditiesList' }
local AUCTIONS_TAB_KEYS = { 'AuctionsTab', 'BidsTab' }
local DIALOG_BUTTON_KEYS = { 'BuyNowButton', 'CancelButton', 'OkayButton' }
local CELL_TEXT_KEYS = { 'Text', 'ExtraInfo', 'Prefix' }
local MONEY_DENOMINATION_KEYS = { 'GoldDisplay', 'SilverDisplay', 'CopperDisplay' }
local PRICE_COIN_KEYS = { 'GoldBox', 'SilverBox', 'CopperBox' }
local BID_COIN_KEYS = { 'gold', 'silver', 'copper' }
local LIBRARY_FONT_PREFIX = 'BUI_AuctionHouseFont'
local ROW_SELECTED_ALPHA = 0.12
local ROW_HOVER_ALPHA = 0.08
local ICON_HOVER_ALPHA = 0.2
local CARD_INSET = 1
local RESULT_CARD_INSET = { left = 2, right = 2, top = 1, bottom = 1 }
local BID_COIN_LEFT = -5
local PROGRESS_EDGE = -1
local NAME_SCALE = 1.2
local CATEGORY_SCALE = 12 / 11
local SEARCHING_SCALE = 1.5
local CONTROL_HEIGHT = 22

local context = Skin.Define('auctionhouse', {
	name = 'Auction House',
	description = 'The auction house with card lists, flat tables and library inputs.',
	icon = 'Interface/Icons/INV_Misc_Coin_01',
	newLook = true,
})
local Hook = context.Hook
local Fade, FadeKeys, FadeRegions = context.Fade, context.FadeKeys, context.FadeRegions
local Shell, Button, Card, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Card, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Tab, Body, Title, Face = context.ScrollBar, context.Tab, context.Body, context.Title, context.Face
local ToolButton, TableHeader = context.ToolButton, context.TableHeader
local FlatTexture, SelectedTexture = Skin.FlatTexture, Skin.SelectedTexture
local libraryFonts, libraryFontCount = {}, 0

local function LibraryFont(fontObject)
	local font = libraryFonts[fontObject]
	if font then return font end
	libraryFontCount = libraryFontCount + 1
	font = CreateFont(LIBRARY_FONT_PREFIX .. libraryFontCount)
	font:CopyFontObject(fontObject)
	Face(font)
	libraryFonts[fontObject], libraryFonts[font] = font, font
	return font
end

local function UseLibraryFont(fontString)
	local fontObject = fontString:GetFontObject()
	local font = LibraryFont(fontObject)
	if font ~= fontObject then fontString:SetFontObject(font) end
end

local function HoldLibraryFont(fontString)
	if not fontString._buiLibraryFont then
		fontString._buiLibraryFont = true
		Hook(fontString, 'SetFontObject', UseLibraryFont)
	end
	UseLibraryFont(fontString)
end

local function HoldMoney(display)
	for _, key in ipairs(MONEY_DENOMINATION_KEYS) do
		local denomination = display[key]
		HoldLibraryFont(denomination.Text)
		denomination:UpdateWidth()
	end
end

local function BarInset(control)
	return (control:GetHeight() - CONTROL_HEIGHT) / 2
end

local function BarInsets(control)
	local inset = BarInset(control)
	return { top = inset, bottom = inset }
end

local function InputInsets(box, left)
	local _, _, top, bottom = box:GetTextInsets()
	local inset, lift = BarInset(box), (bottom - top) / 2
	return { left = left, top = inset - lift, bottom = inset + lift }
end

local function SkinBackgroundFrame(frame)
	FadeKeys(frame, BACKGROUND_KEYS)
	Shell(frame)
end

local function SkinScrollPanel(panel)
	SkinBackgroundFrame(panel)
	ScrollBar(panel.ScrollBar)
end

local function SquareIcon(owner, icon, border)
	Fade(border)
	Skin.SquareIcon(owner, icon)
end

local function SelectedRow(texture)
	texture:SetBlendMode('BLEND')
	SelectedTexture(texture, ROW_SELECTED_ALPHA)
end

local function SkinItemButton(button)
	if not button._buiItemButton then
		button._buiItemButton = true
		button.Icon:RemoveMaskTexture(button.IconMask or button.CircleMask)
	end
	Fade(button.EmptyBackground)
	Fade(button.IconOverlay)
	Fade(button:GetPushedTexture())
	FlatTexture(button:GetHighlightTexture(), 1, 1, 1, ICON_HOVER_ALPHA)
	SquareIcon(button, button.Icon, button.IconBorder)
	Skin.TipCount(button.Count)
end

local function OnItemButtonQuality(button, quality)
	if button._buiItemButton then Skin.SetIconEdgeRarity(button.Icon, quality) end
end

local function SkinItemDisplay(display)
	FadeRegions(display)
	SkinBackgroundFrame(display)
	SkinItemButton(display.ItemButton)
	Skin.TipFont(display.Name, 'title', NAME_SCALE)
end

local function SkinCoinBoxes(frame, keys, coinKey, left)
	for _, key in ipairs(keys) do
		local box = frame[key]
		local coin = box[coinKey]
		for _, region in ipairs({ box:GetRegions() }) do
			if region ~= coin and region:IsObjectType('Texture') then Fade(region) end
		end
		EditBox(box, InputInsets(box, left))
	end
end

local function SkinAlignedControl(control)
	for _, key in ipairs(LABEL_KEYS) do Skin.TipFont(control[key], 'label') end
	Skin.TipFont(control.Subtext, 'label')
	Skin.TipFont(control.PerItemPostfix, 'label')
	local input, coins, dropdown, money = control.InputBox, control.MoneyInputFrame, control.Dropdown, control.MoneyDisplayFrame
	if input then
		EditBox(input, InputInsets(input))
		Button(control.MaxButton)
	end
	if coins then SkinCoinBoxes(coins, PRICE_COIN_KEYS, 'Icon') end
	if dropdown then
		Shell(dropdown, BarInsets(dropdown))
		Dropdown(dropdown, true)
	end
	if money then HoldMoney(money) end
end

local function OnLabelColor(control, color)
	if color ~= NORMAL_FONT_COLOR then return end
	for _, key in ipairs(LABEL_KEYS) do Painter.Text(control[key], 'skinLabel') end
end

local function SkinBidFrame(frame)
	SkinCoinBoxes(frame.BidAmount, BID_COIN_KEYS, 'texture', BID_COIN_LEFT)
	Button(frame.BidButton)
end

local function SkinItemList(list)
	SkinScrollPanel(list)
	Body(list.ResultsText)
	Skin.TipFont(list.LoadingSpinner.SearchingText, 'title', SEARCHING_SCALE)
	local refresh = list.RefreshFrame
	ToolButton(refresh.RefreshButton)
	Skin.TipFont(refresh.TotalQuantity, 'label')
end

local function SkinSearchBar(bar)
	local favorites, box, filter, search = bar.FavoritesSearchButton, bar.SearchBox, bar.FilterButton, bar.SearchButton
	ToolButton(favorites, BarInset(favorites))
	EditBox(box, BarInsets(box))
	Skin.TipFont(box.Instructions, 'label')
	Shell(filter, BarInsets(filter))
	context.TextDropdown(filter, true)
	Shell(search, BarInsets(search))
	Button(search)
end

local function SkinSellBase(frame)
	SkinBackgroundFrame(frame)
	FadeKeys(frame, SELL_TAB_ART)
	Title(frame.CreateAuctionLabel)
	SkinItemDisplay(frame.ItemDisplay)
	Button(frame.PostButton)
end

local function SkinSellFrame(frame)
	SkinSellBase(frame)
	for _, key in ipairs(SELL_CONTROL_KEYS) do SkinAlignedControl(frame[key]) end
end

local function SkinItemSell(frame)
	local check = frame.BuyoutModeCheckButton
	SkinSellFrame(frame)
	SkinAlignedControl(frame.SecondaryPriceInput)
	CheckBox(check, BarInset(check))
	Body(check.Text)
end

local function SkinItemBuy(frame)
	Button(frame.BackButton)
	SkinItemDisplay(frame.ItemDisplay)
	Button(frame.BuyoutFrame.BuyoutButton)
	SkinBidFrame(frame.BidFrame)
	SkinItemList(frame.ItemList)
end

local function SkinCommoditiesBuy(frame)
	local display = frame.BuyDisplay
	Button(frame.BackButton)
	SkinBackgroundFrame(display)
	SkinItemDisplay(display.ItemDisplay)
	for _, key in ipairs(BUY_CONTROL_KEYS) do SkinAlignedControl(display[key]) end
	Button(display.BuyButton)
	SkinItemList(frame.ItemList)
end

local function SkinBuyDialog(dialog)
	FadeRegions(dialog.Border)
	Fade(dialog.Notification.Button:GetHighlightTexture())
	Shell(dialog)
	dialog.DarkOverlay:SetAllPoints()
	Title(dialog.ItemDisplay.ItemText)
	HoldMoney(dialog.PriceFrame)
	for _, key in ipairs(DIALOG_BUTTON_KEYS) do Button(dialog[key]) end
	Face(dialog.TimeLeftText)
end

local function OnNotificationText(notification)
	Body(notification.Text)
end

local function SkinAuctionsFrame(frame)
	for _, key in ipairs(AUCTIONS_TAB_KEYS) do Tab(frame[key]) end
	Button(frame.CancelAuctionButton)
	Button(frame.BuyoutFrame.BuyoutButton)
	SkinBidFrame(frame.BidFrame)
	SkinScrollPanel(frame.SummaryList)
	SkinItemDisplay(frame.ItemDisplay)
	for _, key in ipairs(AUCTIONS_LIST_KEYS) do SkinItemList(frame[key]) end
	frame._buiTabsSkinned = true
end

local function RefreshAuctionsTabs(frame)
	for _, key in ipairs(AUCTIONS_TAB_KEYS) do
		local tab = frame[key]
		Skin.TipTabSelected(tab, tab:GetID() == frame.selectedTab)
	end
end

local function SkinTokenResults(frame)
	SkinBackgroundFrame(frame)
	Skin.TipFont(frame.BuyoutLabel, 'label')
	HoldLibraryFont(frame.BuyoutPrice)
	SkinItemDisplay(frame.TokenDisplay)
	Button(frame.Buyout)
	ScrollBar(frame.DummyScrollBar)
end

local function SkinTokenSell(frame)
	SkinSellBase(frame)
	Skin.TipFont(frame.BuyoutPriceLabel, 'label')
	HoldLibraryFont(frame.MarketPrice)
	Skin.TipFont(frame.EstimatedTime, 'label')
	Body(frame.TimeToSell)
	SkinBackgroundFrame(frame.DummyItemList)
	ScrollBar(frame.DummyItemList.DummyScrollBar)
	ToolButton(frame.DummyRefreshButton)
end

local function SkinMultisell(frame)
	local bar = frame.ProgressBar
	FadeKeys(frame, MULTISELL_ART)
	FadeKeys(bar, PROGRESS_ART)
	Shell(frame)
	Shell(bar, PROGRESS_EDGE)
	Painter.Fill(bar:GetStatusBarTexture(), 'skinTitle')
	Skin.SquareIcon(bar, bar.Icon)
	Body(bar.Text)
	context.Close(frame.CancelButton)
end

local function SkinFrame(frame)
	local money = frame.MoneyFrameBorder
	context.Chrome(frame)
	FadeKeys(frame, MONEY_ART)
	Shell(money)
	HoldMoney(money.MoneyFrame)
	HoldMoney(frame.DummyMoneyDisplayFrame)
	Skin.RegisterTabStrip(frame, frame.Tabs, context)
	SkinSearchBar(frame.SearchBar)
	SkinScrollPanel(frame.CategoriesList)
	SkinItemList(frame.BrowseResultsFrame.ItemList)
	SkinTokenResults(frame.WoWTokenResults)
	SkinCommoditiesBuy(frame.CommoditiesBuyFrame)
	SkinItemBuy(frame.ItemBuyFrame)
	SkinItemSell(frame.ItemSellFrame)
	SkinItemList(frame.ItemSellList)
	SkinSellFrame(frame.CommoditiesSellFrame)
	SkinItemList(frame.CommoditiesSellList)
	SkinTokenSell(frame.WoWTokenSellFrame)
	SkinAuctionsFrame(frame.AuctionsFrame)
	SkinBuyDialog(frame.BuyDialog)
	SkinMultisell(_G.AuctionHouseMultisellProgressFrame)
end

local function OnCategoryButton(button, info)
	Skin.TipCategoryButton(context, button, info.type == 'category' and CATEGORY_SCALE or nil)
end

local function FitToCard(texture)
	texture:ClearAllPoints()
	texture:SetPoint('TOPLEFT', RESULT_CARD_INSET.left, -RESULT_CARD_INSET.top)
	texture:SetPoint('BOTTOMRIGHT', -RESULT_CARD_INSET.right, RESULT_CARD_INSET.bottom)
end

local function OnRowSelected(highlight, shown)
	Skin.SetActiveEdge(highlight:GetParent(), shown and true or false)
end

local function OnRowCleared(highlight)
	Skin.SetActiveEdge(highlight:GetParent(), false)
end

local function OnRowPopulated(row)
	if row._buiRow then return end
	row._buiRow = true
	local selected, hover = row.SelectedHighlight, row.HighlightTexture
	Fade(row:GetNormalTexture())
	Card(row, RESULT_CARD_INSET)
	SelectedRow(selected)
	FitToCard(selected)
	hover:SetBlendMode('BLEND')
	FlatTexture(hover, 1, 1, 1, ROW_HOVER_ALPHA)
	FitToCard(hover)
	Hook(selected, 'SetShown', OnRowSelected)
	Hook(selected, 'Hide', OnRowCleared)
end

local function SkinCell(cell)
	if cell._buiCell then return end
	cell._buiCell = true
	for _, key in ipairs(CELL_TEXT_KEYS) do
		local text = cell[key]
		if text then HoldLibraryFont(text) end
	end
	if cell.MoneyDisplay then HoldMoney(cell.MoneyDisplay) end
	if cell.Icon and cell.IconBorder then SquareIcon(cell, cell.Icon, cell.IconBorder) end
end

local function OnCellsArranged(_, row)
	if not row.GetItemList then return end
	for _, cell in ipairs(row.cells) do SkinCell(cell) end
end

local function OnSummaryLine(line)
	if line._buiSummaryLine then return end
	line._buiSummaryLine = true
	SquareIcon(line, line.Icon, line.IconBorder)
	Fade(line.SelectedHighlight)
	Fade(line.HighlightTexture)
	Card(line, CARD_INSET)
	Body(line.Text)
end

local function OnTabsUpdated(frame)
	if frame._buiTabsSkinned then RefreshAuctionsTabs(frame) end
end

local function RefreshFrame(frame)
	Skin.RefreshTabStrip(frame)
	RefreshAuctionsTabs(frame.AuctionsFrame)
end

local function InstallFrame(frame)
	Hook(frame.BuyDialog.Notification, 'SetNotificationText', OnNotificationText)
	Hook(frame.ItemSellFrame.PriceInput, 'SetLabelColor', OnLabelColor)
	Hook('AuctionHouseFilterButton_SetUp', OnCategoryButton)
	Hook(AuctionHouseItemListLineMixin, 'Populate', OnRowPopulated)
	Hook(TableBuilderMixin, 'ArrangeCells', OnCellsArranged)
	Hook(AuctionHouseTableHeaderStringMixin, 'Init', TableHeader)
	Hook(AuctionHouseAuctionsSummaryLineMixin, 'Init', OnSummaryLine)
	Hook(AuctionHouseAuctionsSummaryLineMixin, 'SetSelected', Skin.SetActiveEdge)
	Hook('PanelTemplates_UpdateTabs', OnTabsUpdated)
	Hook('SetItemButtonQuality', OnItemButtonQuality)
end

context.Window('AuctionHouseFrame', { skin = SkinFrame, show = RefreshFrame, install = InstallFrame })

context.OnDisable(function()
	local frame = _G.AuctionHouseFrame
	if frame then frame.AuctionsFrame._buiTabsSkinned = nil end
end)
