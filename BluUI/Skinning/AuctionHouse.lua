local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning
local Painter = BUI.Painter

local BACKGROUND_KEYS = { 'Background', 'NineSlice' }
local MONEY_ART = { 'MoneyFrameInset', 'MoneyFrameBorder' }
local HEADER_ART = { 'Left', 'Middle', 'Right' }
local SELL_TAB_ART = { 'CreateAuctionTabLeft', 'CreateAuctionTabMiddle', 'CreateAuctionTabRight' }
local MULTISELL_ART = { 'Fill', 'Left', 'Right', 'Middle' }
local ALIGNED_CONTROL_KEYS = { 'QuantityInput', 'PriceInput', 'SecondaryPriceInput', 'Duration', 'Deposit', 'TotalPrice', 'UnitPrice' }
local LABEL_KEYS = { 'Label', 'LabelTitle' }
local AUCTIONS_LIST_KEYS = { 'AllAuctionsList', 'BidsList', 'ItemList', 'CommoditiesList' }
local AUCTIONS_TAB_KEYS = { 'AuctionsTab', 'BidsTab' }
local DIALOG_BUTTON_KEYS = { 'BuyNowButton', 'CancelButton', 'OkayButton' }
local CELL_TEXT_KEYS = { 'Text', 'ExtraInfo', 'Prefix' }
local MONEY_DENOMINATION_KEYS = { 'GoldDisplay', 'SilverDisplay', 'CopperDisplay' }
local HOUSE_FONT_PREFIX = 'BUI_AuctionHouseFont'
local ROW_SELECTED_ALPHA = 0.12
local ROW_HOVER_ALPHA = 0.08
local NAME_SCALE = 1.2
local CATEGORY_SCALE = 12 / 11
local SEARCHING_SCALE = 1.5
local SEARCH_BAR_HEIGHT = 22
local MUTED_TEXT_THRESHOLD = 0.6

local context = Skin.Define('auctionhouse', {
	name = 'Auction House',
	description = 'Browse, buy, sell and manage auctions: card categories with a white edge on the selected one, result tables, sell forms and the buy dialog.',
	icon = 'Interface/Icons/INV_Misc_Coin_01',
	newLook = true,
})
local Hook = context.Hook
local Fade, FadeKeys, FadeRegions = context.Fade, context.FadeKeys, context.FadeRegions
local Shell, Button, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Tab, Body, Title, Face = context.ScrollBar, context.Tab, context.Body, context.Title, context.Face
local FlatTexture, SelectedTexture, CropIcon = Skin.FlatTexture, Skin.SelectedTexture, Skin.CropIcon
local houseFonts, houseFontCount = {}, 0

local function HouseFont(fontObject)
	local font = houseFonts[fontObject]
	if font then return font end
	houseFontCount = houseFontCount + 1
	font = CreateFont(HOUSE_FONT_PREFIX .. houseFontCount)
	font:CopyFontObject(fontObject)
	Face(font)
	houseFonts[fontObject], houseFonts[font] = font, font
	return font
end

local function UseHouseFont(fontString)
	local fontObject = fontString:GetFontObject()
	local font = HouseFont(fontObject)
	if font ~= fontObject then fontString:SetFontObject(font) end
end

local function HoldHouseFont(fontString)
	if not fontString._buiHouseFont then
		fontString._buiHouseFont = true
		Hook(fontString, 'SetFontObject', UseHouseFont)
	end
	UseHouseFont(fontString)
end

local function HoldMoney(display)
	for _, key in ipairs(MONEY_DENOMINATION_KEYS) do
		local denomination = display[key]
		HoldHouseFont(denomination.Text)
		denomination:UpdateWidth()
	end
end

local function ShellEdgeEnter(button)
	Skin.TipShellEdges(button, Skin.HoverColor())
end

local function ShellEdgeLeave(button)
	Skin.TipShellEdges(button, false)
end

local function SkinIconButton(button, inset)
	if not button._buiIconButton then
		button._buiIconButton = true
		Fade(button:GetNormalTexture())
		Fade(button:GetPushedTexture())
		Fade(button:GetDisabledTexture())
		Fade(button:GetHighlightTexture())
		button:HookScript('OnEnter', BUI.Profiler.Wrap('Skin.AuctionHouse button OnEnter', context.Guard(ShellEdgeEnter)))
		button:HookScript('OnLeave', BUI.Profiler.Wrap('Skin.AuctionHouse button OnLeave', context.Guard(ShellEdgeLeave)))
	end
	Shell(button, inset)
end

local function SkinBackgroundFrame(frame)
	FadeKeys(frame, BACKGROUND_KEYS)
	Shell(frame)
end

local function SkinItemButton(button)
	if button._buiItemButton then return end
	button._buiItemButton = true
	local icon = button.Icon
	Fade(button.EmptyBackground)
	Fade(button.IconBorder)
	Fade(button.IconOverlay)
	icon:RemoveMaskTexture(button.IconMask or button.CircleMask)
	CropIcon(icon)
	Skin.TipIconFrame(button, icon)
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

local function SkinMoneyInput(frame)
	if not frame then return end
	for _, child in ipairs({ frame:GetChildren() }) do
		if child:IsObjectType('EditBox') then EditBox(child) end
	end
end

local function RecolorAlignedLabels(control)
	local role = control.Label:GetTextColor() < MUTED_TEXT_THRESHOLD and 'skinLabel' or 'skinText'
	for _, key in ipairs(LABEL_KEYS) do
		if control[key] then Painter.Text(control[key], role) end
	end
end

local function SkinAlignedControl(control)
	if not control or control._buiAligned then return end
	control._buiAligned = true
	for _, key in ipairs(LABEL_KEYS) do Body(control[key]) end
	Skin.TipFont(control.Subtext, 'label')
	Skin.TipFont(control.PerItemPostfix, 'label')
	EditBox(control.InputBox)
	Button(control.MaxButton)
	SkinMoneyInput(control.MoneyInputFrame)
	Dropdown(control.Dropdown)
	if control.MoneyDisplayFrame then HoldMoney(control.MoneyDisplayFrame) end
	if control.SetLabelColor then Hook(control, 'SetLabelColor', RecolorAlignedLabels) end
end

local function SkinBidFrame(frame)
	SkinMoneyInput(frame.BidAmount)
	Button(frame.BidButton)
end

local function SkinItemList(list)
	if list._buiItemList then return end
	list._buiItemList = true
	SkinBackgroundFrame(list)
	ScrollBar(list.ScrollBar)
	Body(list.ResultsText)
	Skin.TipFont(list.LoadingSpinner.SearchingText, 'title', SEARCHING_SCALE)
	local refresh = list.RefreshFrame
	SkinIconButton(refresh.RefreshButton)
	Skin.TipFont(refresh.TotalQuantity, 'label')
end

local function BarInset(control)
	return (control:GetHeight() - SEARCH_BAR_HEIGHT) / 2
end

local function BarInsets(control)
	local inset = BarInset(control)
	return { top = inset, bottom = inset }
end

local function SkinSearchBar(bar)
	local favorites, box, filter, search = bar.FavoritesSearchButton, bar.SearchBox, bar.FilterButton, bar.SearchButton
	SkinIconButton(favorites, BarInset(favorites))
	EditBox(box, BarInsets(box))
	Skin.TipFont(box.Instructions, 'label')
	Shell(filter, BarInsets(filter))
	context.TextDropdown(filter, true)
	Shell(search, BarInsets(search))
	Button(search)
end

local function SkinSellFrame(frame)
	SkinBackgroundFrame(frame)
	FadeKeys(frame, SELL_TAB_ART)
	Title(frame.CreateAuctionLabel)
	SkinItemDisplay(frame.ItemDisplay)
	for _, key in ipairs(ALIGNED_CONTROL_KEYS) do SkinAlignedControl(frame[key]) end
	Button(frame.PostButton)
	CheckBox(frame.BuyoutModeCheckButton)
end

local function SkinItemBuy(frame)
	Button(frame.BackButton)
	SkinItemDisplay(frame.ItemDisplay)
	Button(frame.BuyoutFrame.BuyoutButton)
	SkinBidFrame(frame.BidFrame)
	SkinItemList(frame.ItemList)
end

local function SkinCommoditiesBuy(frame)
	Button(frame.BackButton)
	local display = frame.BuyDisplay
	SkinBackgroundFrame(display)
	SkinItemDisplay(display.ItemDisplay)
	for _, key in ipairs(ALIGNED_CONTROL_KEYS) do SkinAlignedControl(display[key]) end
	Button(display.BuyButton)
	SkinItemList(frame.ItemList)
end

local function SkinBuyDialog(dialog)
	Skin.FadeTree(dialog.Border)
	Shell(dialog)
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
	SkinBackgroundFrame(frame.SummaryList)
	ScrollBar(frame.SummaryList.ScrollBar)
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
	Body(frame.BuyoutLabel)
	HoldHouseFont(frame.BuyoutPrice)
	SkinItemDisplay(frame.TokenDisplay)
	Button(frame.Buyout)
end

local function SkinTokenSell(frame)
	SkinBackgroundFrame(frame)
	FadeKeys(frame, SELL_TAB_ART)
	Title(frame.CreateAuctionLabel)
	Body(frame.BuyoutPriceLabel)
	HoldHouseFont(frame.MarketPrice)
	Body(frame.EstimatedTime)
	Body(frame.TimeToSell)
	SkinItemDisplay(frame.ItemDisplay)
	Button(frame.PostButton)
	SkinBackgroundFrame(frame.DummyItemList)
	SkinIconButton(frame.DummyRefreshButton)
end

local function SkinMultisell(frame)
	FadeKeys(frame, MULTISELL_ART)
	Shell(frame)
	Body(frame.ProgressBar.Text)
end

local function SkinCategories(list)
	SkinBackgroundFrame(list)
	ScrollBar(list.ScrollBar)
end

local function SkinFrame(frame)
	context.Chrome(frame)
	FadeKeys(frame, MONEY_ART)
	HoldMoney(frame.MoneyFrameBorder.MoneyFrame)
	HoldMoney(frame.DummyMoneyDisplayFrame)
	Skin.RegisterTabStrip(frame, frame.Tabs, context)
	SkinSearchBar(frame.SearchBar)
	SkinCategories(frame.CategoriesList)
	SkinItemList(frame.BrowseResultsFrame.ItemList)
	SkinTokenResults(frame.WoWTokenResults)
	SkinCommoditiesBuy(frame.CommoditiesBuyFrame)
	SkinItemBuy(frame.ItemBuyFrame)
	SkinSellFrame(frame.ItemSellFrame)
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

local function OnRowPopulated(row)
	if row._buiRow then return end
	row._buiRow = true
	local stripe = row:GetNormalTexture()
	if stripe then stripe:SetAlpha(0) end
	local selected, highlight = row.SelectedHighlight, row.HighlightTexture
	if selected then
		selected:SetBlendMode('BLEND')
		SelectedTexture(selected, ROW_SELECTED_ALPHA)
	end
	if highlight then
		highlight:SetBlendMode('BLEND')
		FlatTexture(highlight, 1, 1, 1, ROW_HOVER_ALPHA)
	end
end

local function SkinCell(cell)
	if cell._buiCell then return end
	cell._buiCell = true
	for _, key in ipairs(CELL_TEXT_KEYS) do
		local text = cell[key]
		if text then HoldHouseFont(text) end
	end
	if cell.MoneyDisplay then HoldMoney(cell.MoneyDisplay) end
	if cell.Icon and cell.IconBorder then
		cell.IconBorder:SetAlpha(0)
		CropIcon(cell.Icon)
		Skin.TipIconFrame(cell, cell.Icon)
	end
end

local function OnCellsArranged(_, row)
	if not row.GetItemList or not row.cells then return end
	for _, cell in ipairs(row.cells) do SkinCell(cell) end
end

local function OnHeaderInit(header)
	if header._buiHeader then return end
	header._buiHeader = true
	FadeKeys(header, HEADER_ART)
	Fade(header:GetHighlightTexture())
	Skin.TipFont(header.Text, 'label')
	Painter.Tint(header.Arrow, 'skinTitle')
end

local function OnSummaryLine(line)
	if line._buiSummaryLine then return end
	line._buiSummaryLine = true
	line.IconBorder:SetAlpha(0)
	CropIcon(line.Icon)
	Skin.TipIconFrame(line, line.Icon)
	line.SelectedHighlight:SetBlendMode('BLEND')
	SelectedTexture(line.SelectedHighlight, ROW_SELECTED_ALPHA)
	Face(line.Text)
end

local function OnTabsUpdated(frame)
	local auctions = _G.AuctionHouseFrame.AuctionsFrame
	if frame == auctions and auctions._buiTabsSkinned then RefreshAuctionsTabs(frame) end
end

local function RefreshFrame(frame)
	Skin.RefreshTabStrip(frame)
	RefreshAuctionsTabs(frame.AuctionsFrame)
end

local function InstallFrame(frame)
	Hook(frame.BuyDialog.Notification, 'SetNotificationText', OnNotificationText)
	Hook('AuctionHouseFilterButton_SetUp', OnCategoryButton)
	Hook(AuctionHouseItemListLineMixin, 'Populate', OnRowPopulated)
	Hook(TableBuilderMixin, 'ArrangeCells', OnCellsArranged)
	Hook(AuctionHouseTableHeaderStringMixin, 'Init', OnHeaderInit)
	Hook(AuctionHouseAuctionsSummaryLineMixin, 'Init', OnSummaryLine)
	Hook('PanelTemplates_UpdateTabs', OnTabsUpdated)
	Hook('SetItemButtonQuality', OnItemButtonQuality)
end

context.Window('AuctionHouseFrame', { skin = SkinFrame, show = RefreshFrame, install = InstallFrame })

context.OnDisable(function()
	local frame = _G.AuctionHouseFrame
	if frame then frame.AuctionsFrame._buiTabsSkinned = nil end
end)
