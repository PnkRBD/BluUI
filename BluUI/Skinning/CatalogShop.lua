local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local HEADER_ART = { 'Background', 'DisabledBackground' }
local DETAIL_TEXT_KEYS = { 'ProductType', 'QuantityOwned', 'ProductDescription' }
local DETAIL_NOTE_KEYS = { 'LegalDisclaimerText', 'HousingWarningText' }
local BUTTON_NOTE_KEYS = { 'NoPriceInGlues', 'PendingPurchasesText', 'DynamicBundleDiscountText' }
local DETAIL_TITLE_SCALE = 1.5
local DETAIL_TEXT_SCALE = 1.1

local context = Skin.Define('catalogshop', {
	name = 'In-Game Shop',
	description = 'The Blizzard shop window: dark shell and title band, search box, scroll bars, library style buttons and a flat details panel. Category tabs and product cards are locked by Blizzard and keep their own art.',
	icon = 'Interface/Icons/INV_Misc_Coin_02',
	legacy = 'shop',
})
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, EditBox = context.Shell, context.Button, context.Close, context.EditBox
local ScrollBar, Title = context.ScrollBar, context.Title

local titleBand

local function SkinProductContainer(container)
	FadeRegions(container.ShadowLayer)
	ScrollBar(container.ProductsScrollBoxContainer.ScrollBar)
end

local function SkinTitleBand(frame)
	if not titleBand then
		titleBand = CreateFrame('Frame', nil, frame)
		titleBand:SetPoint('TOPLEFT', frame, 'TOPLEFT')
		titleBand:SetPoint('BOTTOMRIGHT', frame.HeaderFrame, 'BOTTOMRIGHT')
		titleBand:SetFrameLevel(frame.BackgroundContainer:GetFrameLevel() + 1)
	end
	Shell(titleBand)
end

local function SkinHeader(header)
	FadeKeys(header, HEADER_ART)
	EditBox(header.SearchBox)
	local navBar = header.CatalogShopNavBar
	Skin.TipPageButtons(navBar.ScrollBackwards, navBar.ScrollForwards)
	Fade(navBar.ScrollBackwards.Arrow)
	Fade(navBar.ScrollForwards.Arrow)
end

local function SkinDetails(details)
	Fade(details.Border)
	Shell(details)
	Skin.TipFont(details.ProductName, 'title', DETAIL_TITLE_SCALE)
	for _, key in ipairs(DETAIL_TEXT_KEYS) do Skin.TipFont(details[key], 'body', DETAIL_TEXT_SCALE) end
	for _, key in ipairs(DETAIL_NOTE_KEYS) do Skin.TipFace(details[key], 'body', DETAIL_TEXT_SCALE) end
	local buttons = details.ButtonContainer
	Button(buttons.PurchaseButton)
	Button(buttons.DetailsButton)
	for _, key in ipairs(BUTTON_NOTE_KEYS) do Skin.TipFace(buttons[key], 'body', DETAIL_TEXT_SCALE) end
	Button(details.ProductRefundContainer.RefundButton)
end

local function SkinFrame(frame)
	Fade(frame.NineSlice)
	FadeRegions(frame)
	FadeRegions(frame.PortraitContainer)
	Shell(frame)
	Title(frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
	SkinTitleBand(frame)
	SkinHeader(frame.HeaderFrame)
	SkinProductContainer(frame.ProductContainerFrame)
	local productDetails = frame.ProductDetailsContainerFrame
	Button(productDetails.BackButton)
	SkinProductContainer(productDetails.DetailsProductContainerFrame)
	SkinDetails(frame.CatalogShopDetailsFrame)
	Fade(frame.CatalogShopVCFrame.Border)
	Shell(frame.CatalogShopVCFrame)
end

context.Window('CatalogShopFrame', { skin = SkinFrame })
