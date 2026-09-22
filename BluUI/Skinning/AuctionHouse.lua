local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('AuctionHouse')

local hooksecurefunc = BUI.Prof.MakeHooker('auctionhouse')
local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Theme = BUILib.Theme

local SKIN_ID = 'auctionhouse'
local BACKGROUND_KEYS = { 'Background', 'NineSlice' }
local MAIN_ART = { 'Bg', 'TopTileStreaks', 'MoneyFrameInset', 'MoneyFrameBorder' }
local HEADER_ART = { 'Left', 'Middle', 'Right' }
local SELL_TAB_ART = { 'CreateAuctionTabLeft', 'CreateAuctionTabMiddle', 'CreateAuctionTabRight' }
local MULTISELL_ART = { 'Fill', 'Left', 'Right', 'Middle' }
local ALIGNED_CONTROL_KEYS = { 'QuantityInput', 'PriceInput', 'SecondaryPriceInput', 'Duration', 'Deposit', 'TotalPrice', 'UnitPrice' }
local LABEL_KEYS = { 'Label', 'LabelTitle', 'Subtext' }
local AUCTIONS_LIST_KEYS = { 'AllAuctionsList', 'BidsList', 'ItemList', 'CommoditiesList' }
local AUCTIONS_TAB_KEYS = { 'AuctionsTab', 'BidsTab' }
local DIALOG_BUTTON_KEYS = { 'BuyNowButton', 'CancelButton', 'OkayButton' }
local CELL_TEXT_KEYS = { 'Text', 'ExtraInfo', 'Prefix' }
local CATEGORY_SELECTED_ALPHA = 0.15
local CATEGORY_HOVER_ALPHA = 0.06
local ROW_SELECTED_ALPHA = 0.18
local ROW_HOVER_ALPHA = 0.08
local NAME_SCALE = 1.2
local SEARCHING_SCALE = 1.5
local MUTED_TEXT_THRESHOLD = 0.6
local BRIGHT_TEXT = { 0.9, 0.9, 0.93, 1 }
local BODY_TEXT = { 0.87, 0.87, 0.9, 1 }
local LABEL_TEXT = { 0.55, 0.55, 0.6, 1 }

local installed = false
local skinned = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, Dropdown, EditBox, CheckBox = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.CheckBox
local ScrollBar, Tab, Body, Title = context.ScrollBar, context.Tab, context.Body, context.Title
local FlatTexture, AccentTexture, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.CropIcon

local function SetColor(fontString, color)
	if fontString then fontString:SetTextColor(color[1], color[2], color[3], color[4]) end
end

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
		HookScript(button, 'OnEnter', IconButtonEnter)
		HookScript(button, 'OnLeave', IconButtonLeave)
	end
	Shell(button)
end

local function SkinBackgroundFrame(frame)
	if not frame then return end
	FadeKeys(frame, BACKGROUND_KEYS)
	Shell(frame)
end

local function SkinItemButton(button)
	if not button or button._buiItemButton then return end
	button._buiItemButton = true
	Fade(button:GetNormalTexture())
	Fade(button.IconOverlay)
	CropIcon(button.icon)
	Skin.TipIconFrame(button, button.icon)
	Body(button.Count)
end

local function SkinItemDisplay(display)
	if not display then return end
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
	local muted = control.Label:GetTextColor() < MUTED_TEXT_THRESHOLD
	for _, key in ipairs(LABEL_KEYS) do SetColor(control[key], muted and LABEL_TEXT or BODY_TEXT) end
end

local function SkinAlignedControl(control)
	if not control or control._buiAligned then return end
	control._buiAligned = true
	for _, key in ipairs(LABEL_KEYS) do Body(control[key]) end
	EditBox(control.InputBox)
	Button(control.MaxButton)
	SkinMoneyInput(control.MoneyInputFrame)
	Dropdown(control.Dropdown)
	if control.PerItemPostfix then Skin.TipFont(control.PerItemPostfix, 'label') end
	if control.SetLabelColor then hooksecurefunc(control, 'SetLabelColor', RecolorAlignedLabels) end
end

local function SkinBidFrame(frame)
	if not frame then return end
	SkinMoneyInput(frame.BidAmount)
	Button(frame.BidButton)
end

local function SkinBuyoutFrame(frame)
	if frame then Button(frame.BuyoutButton) end
end

local function SkinItemList(list)
	if not list or list._buiItemList then return end
	list._buiItemList = true
	SkinBackgroundFrame(list)
	ScrollBar(list.ScrollBar)
	Body(list.ResultsText)
	Skin.TipFont(list.SearchingText, 'title', SEARCHING_SCALE)
	local refresh = list.RefreshFrame
	if refresh then
		SkinIconButton(refresh.RefreshButton)
		Body(refresh.TotalQuantity)
	end
end

local function SkinSearchBar(bar)
	if not bar then return end
	SkinIconButton(bar.FavoritesSearchButton)
	EditBox(bar.SearchBox)
	Dropdown(bar.FilterButton)
	Button(bar.SearchButton)
end

local function SkinCategories(list)
	if not list then return end
	SkinBackgroundFrame(list)
	ScrollBar(list.ScrollBar)
end

local function SkinSellFrame(frame)
	if not frame then return end
	SkinBackgroundFrame(frame)
	FadeKeys(frame, SELL_TAB_ART)
	Title(frame.CreateAuctionLabel)
	SkinItemDisplay(frame.ItemDisplay)
	for _, key in ipairs(ALIGNED_CONTROL_KEYS) do SkinAlignedControl(frame[key]) end
	Button(frame.PostButton)
	CheckBox(frame.BuyoutModeCheckButton)
end

local function SkinItemBuy(frame)
	if not frame then return end
	Button(frame.BackButton)
	SkinItemDisplay(frame.ItemDisplay)
	SkinBuyoutFrame(frame.BuyoutFrame)
	SkinBidFrame(frame.BidFrame)
	SkinItemList(frame.ItemList)
end

local function SkinCommoditiesBuy(frame)
	if not frame then return end
	Button(frame.BackButton)
	local display = frame.BuyDisplay
	if display then
		SkinBackgroundFrame(display)
		SkinItemDisplay(display.ItemDisplay)
		for _, key in ipairs(ALIGNED_CONTROL_KEYS) do SkinAlignedControl(display[key]) end
		Button(display.BuyButton)
	end
	SkinItemList(frame.ItemList)
end

local function SkinBuyDialog(dialog)
	if not dialog then return end
	Skin.FadeTree(dialog.Border)
	Shell(dialog)
	if dialog.ItemDisplay then Title(dialog.ItemDisplay.ItemText) end
	for _, key in ipairs(DIALOG_BUTTON_KEYS) do Button(dialog[key]) end
	if dialog.Notification then Body(dialog.Notification.Text) end
	Skin.TipFace(dialog.TimeLeftText, 'body')
end

local function SkinAuctionsFrame(frame)
	if not frame then return end
	for _, key in ipairs(AUCTIONS_TAB_KEYS) do Tab(frame[key]) end
	Button(frame.CancelAuctionButton)
	SkinBuyoutFrame(frame.BuyoutFrame)
	SkinBidFrame(frame.BidFrame)
	local summary = frame.SummaryList
	if summary then
		SkinBackgroundFrame(summary)
		ScrollBar(summary.ScrollBar)
	end
	SkinItemDisplay(frame.ItemDisplay)
	for _, key in ipairs(AUCTIONS_LIST_KEYS) do SkinItemList(frame[key]) end
end

local function RefreshAuctionsTabs(frame)
	for _, key in ipairs(AUCTIONS_TAB_KEYS) do
		local tab = frame[key]
		if tab then Skin.TipTabSelected(tab, tab:GetID() == frame.selectedTab) end
	end
end

local function SkinTokenResults(frame)
	if not frame then return end
	SkinBackgroundFrame(frame)
	Body(frame.BuyoutLabel)
	Title(frame.BuyoutPrice)
	SkinItemDisplay(frame.TokenDisplay)
	Button(frame.Buyout)
end

local function SkinTokenSell(frame)
	if not frame then return end
	SkinBackgroundFrame(frame)
	FadeKeys(frame, SELL_TAB_ART)
	Title(frame.CreateAuctionLabel)
	Body(frame.BuyoutPriceLabel)
	Title(frame.MarketPrice)
	Body(frame.EstimatedTime)
	Body(frame.TimeToSell)
	SkinItemDisplay(frame.ItemDisplay)
	Button(frame.PostButton)
	SkinBackgroundFrame(frame.DummyItemList)
	SkinIconButton(frame.DummyRefreshButton)
end

local function SkinMultisell(frame)
	if not frame then return end
	FadeKeys(frame, MULTISELL_ART)
	Shell(frame)
end

local function SkinMainFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	FadeRegions(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
	Skin.RegisterTabStrip(frame, frame.Tabs, context)
	SkinSearchBar(frame.SearchBar)
	SkinCategories(frame.CategoriesList)
	if frame.BrowseResultsFrame then SkinItemList(frame.BrowseResultsFrame.ItemList) end
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
	if not Enabled() or not button then return end
	button.NormalTexture:SetAlpha(0)
	button.Lines:SetAlpha(0)
	local selected, highlight = button.SelectedTexture, button.HighlightTexture
	selected:SetBlendMode('BLEND')
	AccentTexture(selected, CATEGORY_SELECTED_ALPHA)
	highlight:SetBlendMode('BLEND')
	FlatTexture(highlight, 1, 1, 1, CATEGORY_HOVER_ALPHA)
	local text = button.Text
	Skin.TipFace(text, 'body')
	if info.selected then
		AccentColor(text)
	elseif info.type == 'category' then
		SetColor(text, BRIGHT_TEXT)
	else
		SetColor(text, BODY_TEXT)
	end
end

local function OnRowPopulated(row)
	if not Enabled() or row._buiRow then return end
	row._buiRow = true
	local stripe = row:GetNormalTexture()
	if stripe then stripe:SetAlpha(0) end
	local selected, highlight = row.SelectedHighlight, row.HighlightTexture
	if selected then
		selected:SetBlendMode('BLEND')
		AccentTexture(selected, ROW_SELECTED_ALPHA)
	end
	if highlight then
		highlight:SetBlendMode('BLEND')
		FlatTexture(highlight, 1, 1, 1, ROW_HOVER_ALPHA)
	end
end

local function SkinCell(cell)
	if cell._buiCell then return end
	cell._buiCell = true
	for _, key in ipairs(CELL_TEXT_KEYS) do Skin.TipFace(cell[key], 'title') end
	if cell.Icon and cell.IconBorder then
		cell.IconBorder:SetAlpha(0)
		CropIcon(cell.Icon)
		Skin.TipIconFrame(cell, cell.Icon)
	end
end

local function OnCellsArranged(_, row)
	if not Enabled() or not row.GetItemList or not row.cells then return end
	for _, cell in ipairs(row.cells) do SkinCell(cell) end
end

local function OnHeaderInit(header)
	if not Enabled() or header._buiHeader then return end
	header._buiHeader = true
	FadeKeys(header, HEADER_ART)
	Fade(header:GetHighlightTexture())
	Skin.TipFont(header.Text, 'label')
	local red, green, blue = Theme.GetAccent()
	header.Arrow:SetVertexColor(red, green, blue, 1)
end

local function OnSummaryLine(line)
	if not Enabled() or line._buiSummaryLine then return end
	line._buiSummaryLine = true
	line.IconBorder:SetAlpha(0)
	CropIcon(line.Icon)
	Skin.TipIconFrame(line, line.Icon)
	line.SelectedHighlight:SetBlendMode('BLEND')
	AccentTexture(line.SelectedHighlight, ROW_SELECTED_ALPHA)
	Skin.TipFace(line.Text, 'body')
end

local function OnTabsUpdated(frame)
	local auctionHouse = _G.AuctionHouseFrame
	if Enabled() and skinned and auctionHouse and frame == auctionHouse.AuctionsFrame then RefreshAuctionsTabs(frame) end
end

local function Apply()
	local frame = _G.AuctionHouseFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
		SkinMainFrame(frame)
	end
	Skin.RefreshTabStrip(frame)
	RefreshAuctionsTabs(frame.AuctionsFrame)
end

local function HookRows()
	hooksecurefunc('AuctionHouseFilterButton_SetUp', OnCategoryButton)
	hooksecurefunc(_G.AuctionHouseItemListLineMixin, 'Populate', OnRowPopulated)
	hooksecurefunc(_G.TableBuilderMixin, 'ArrangeCells', OnCellsArranged)
	hooksecurefunc(_G.AuctionHouseTableHeaderStringMixin, 'Init', OnHeaderInit)
	hooksecurefunc(_G.AuctionHouseAuctionsSummaryLineMixin, 'Init', OnSummaryLine)
	hooksecurefunc('PanelTemplates_UpdateTabs', OnTabsUpdated)
end

local function Install()
	if installed then return end
	local frame = _G.AuctionHouseFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	HookRows()
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.AuctionHouse') end
end

local function Deactivate()
	context.Restore()
	skinned = false
	BUI.Print('Auction House skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.AuctionHouse', TryInstall)
		elseif _G.AuctionHouseFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Auction House',
	description = 'Browse, buy, sell and manage auctions in the dark panel look: categories, result tables, sell forms and the buy dialog.',
	icon = 'Interface/Icons/INV_Misc_Coin_01',
})
