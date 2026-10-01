local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local SKIN_ID = 'catalogshop'
local HEADER_ART = { 'Background', 'DisabledBackground' }
local DETAIL_TEXT_KEYS = { 'ProductType', 'QuantityOwned', 'ProductDescription' }
local DETAIL_NOTE_KEYS = { 'LegalDisclaimerText', 'HousingWarningText' }
local BUTTON_NOTE_KEYS = { 'NoPriceInGlues', 'PendingPurchasesText', 'DynamicBundleDiscountText' }
local DETAIL_TITLE_SCALE = 1.5
local DETAIL_TEXT_SCALE = 1.1

local installed = false
local skinned = false
local titleBand

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, EditBox = context.Shell, context.Button, context.Close, context.EditBox
local ScrollBar, Title = context.ScrollBar, context.Title

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
	Skin.TipPageButton(navBar.ScrollBackwards, 'previous')
	Skin.TipPageButton(navBar.ScrollForwards, 'next')
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

local function Apply()
	if not Enabled() or skinned then return end
	skinned = true
	SkinFrame(_G.CatalogShopFrame)
end

local function Install()
	if installed then return end
	local frame = _G.CatalogShopFrame
	if not frame or frame:IsForbidden() then return end
	installed = true
	frame:HookScript('OnShow', BUI.Profiler.Wrap('Skin.CatalogShop frame reskin', Apply))
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.CatalogShop') end
end

local function Deactivate()
	if not skinned then return end
	context.Restore()
	skinned = false
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.CatalogShop', TryInstall)
		elseif _G.CatalogShopFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'In-Game Shop',
	description = 'The Blizzard shop window: dark shell and title band, search box, scroll bars, house buttons and a flat details panel. Category tabs and product cards are locked by Blizzard and keep their own art.',
	icon = 'Interface/Icons/INV_Misc_Coin_02',
	legacy = 'shop',
})

BUI.Events:Once('PLAYER_LOGIN', 'Skin.CatalogShopInstall', function()
	if not Enabled() then return end
	Install()
	if not installed then BUI.Events:Register('ADDON_LOADED', 'Skin.CatalogShop', TryInstall) end
end)
