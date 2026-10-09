local _, BUI = ...

local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SLOT_ART = { 'ButtonFrame', 'EmptySlotGlow', 'IconBorder' }
local PREVIEW_KEYS = { 'LeftItemPreviewFrame', 'RightItemPreviewFrame', 'ItemHoverPreviewFrame' }
local CURRENCY_KEYS = { 'UpgradeCostFrame', 'PlayerCurrencies' }
local CARD_X, CARD_TOP, CARD_BOTTOM = 15, -30, -172
local SLOT_X, SLOT_Y = 141, -72
local SLOT_HOVER_ALPHA = 0.2
local PLUS_SIZE = 22
local MONEY_DEPTH = 2

local context = Skin.Define('itemupgrade', {
	name = 'Item Upgrade',
	description = 'The item upgrade window: dark shell over the stone panels, framed item slot and currency icons, house fonts on the upgrade previews, level dropdown and cost strip.',
	icon = 'Interface/Icons/UI_ItemUpgrade',
})
local Hook = context.Hook
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Card, Dropdown = context.Shell, context.Button, context.Card, context.Dropdown
local Body, Face = context.Body, context.Face
local FlatTexture, CropIcon = Skin.FlatTexture, Skin.CropIcon

local topCard

local function SkinPanels(frame)
	if not topCard then
		topCard = context.Own(CreateFrame('Frame', nil, frame))
		topCard:SetFrameLevel(frame:GetFrameLevel())
		topCard:SetPoint('TOPLEFT', frame, 'TOPLEFT', CARD_X, CARD_TOP)
		topCard:SetPoint('BOTTOMRIGHT', frame, 'TOPRIGHT', -CARD_X, CARD_BOTTOM)
	end
	Card(topCard)
	local slot = frame.UpgradeItemButton
	slot:ClearAllPoints()
	slot:SetPoint('TOPLEFT', frame, 'TOPLEFT', SLOT_X, SLOT_Y)
end

local function FadeState(texture)
	if texture then texture:SetAlpha(0) end
end

local function RefreshSlot(button)
	button.PulseEmptySlotGlow:Stop()
	FadeState(button:GetNormalTexture())
	FadeState(button:GetPushedTexture())
	local plus = button._buiPlus
	if plus then plus:SetShown(not _G.ItemUpgradeFrame.upgradeInfo) end
	Skin.SetIconEdgeQuality(button.icon, button.IconBorder)
end

local function SkinSlot(button)
	FadeKeys(button, SLOT_ART)
	CropIcon(button.icon)
	Skin.TipIconFrame(button, button.icon)
	FlatTexture(button:GetHighlightTexture(), 1, 1, 1, SLOT_HOVER_ALPHA)
	Skin.TipCount(button.Count)
	if not button._buiPlus then
		local plus = context.Own(button:CreateTexture(nil, 'OVERLAY'))
		BUILib.Widget.SetGlyph(plus, BUILib.GetLibMedia('plus'))
		plus:SetSize(PLUS_SIZE, PLUS_SIZE)
		plus:SetPoint('CENTER')
		BUI.Painter.Tint(plus, 'skinLabel')
		button._buiPlus = plus
	end
	RefreshSlot(button)
end

local function RefreshItemInfo(itemInfo)
	Body(itemInfo.MissingItemText)
	Face(itemInfo.ItemName)
	Body(itemInfo.UpgradeProgress)
	Skin.TipFont(itemInfo.UpgradeTo, 'label')
	Dropdown(itemInfo.Dropdown)
end

local function RefreshCurrencyFrame(currencyFrame)
	Skin.TipFont(currencyFrame.Label, 'label')
	if currencyFrame.quantityPool then
		for fontString in currencyFrame.quantityPool:EnumerateActive() do Face(fontString) end
	end
	if currencyFrame.iconPool then
		for iconFrame in currencyFrame.iconPool:EnumerateActive() do
			CropIcon(iconFrame.Icon)
			Skin.TipIconFrame(iconFrame, iconFrame.Icon)
		end
	end
	Skin.TipFaceTree(currencyFrame.MoneyCostFrame, MONEY_DEPTH)
end

local function RefreshPreviewText(preview)
	local name = preview:GetName()
	for lineIndex = 1, preview:NumLines() do
		Face(_G[name .. 'TextLeft' .. lineIndex])
		Face(_G[name .. 'TextRight' .. lineIndex])
	end
end

local function SkinPreview(preview, plate)
	Fade(preview.NineSlice)
	plate(preview)
	RefreshPreviewText(preview)
end

local function Refresh(frame)
	RefreshSlot(frame.UpgradeItemButton)
	RefreshItemInfo(frame.ItemInfo)
	for _, key in ipairs(CURRENCY_KEYS) do RefreshCurrencyFrame(frame[key]) end
	for _, key in ipairs(PREVIEW_KEYS) do RefreshPreviewText(frame[key]) end
end

local function SkinFrame(frame)
	context.Chrome(frame)
	SkinPanels(frame)
	Body(frame.MissingDescription)
	Face(frame.FrameErrorText)
	Face(frame.LeftPreviewBigText)
	Face(frame.RightPreviewBigText)
	SkinSlot(frame.UpgradeItemButton)
	Button(frame.UpgradeButton)
	Fade(frame.UpgradeCostFrame.BGTex)
	FadeRegions(frame.PlayerCurrenciesBorder)
	SkinPreview(frame.LeftItemPreviewFrame, Card)
	SkinPreview(frame.RightItemPreviewFrame, Card)
	SkinPreview(frame.ItemHoverPreviewFrame, Shell)
end

local function OnPreviewFramesPopulated(frame)
	RefreshSlot(frame.UpgradeItemButton)
	for _, key in ipairs(CURRENCY_KEYS) do RefreshCurrencyFrame(frame[key]) end
end

local function InstallFrame(frame)
	Hook(frame, 'UpdateUpgradeItemInfo', Refresh)
	Hook(frame, 'PopulatePreviewFrames', OnPreviewFramesPopulated)
	Hook(frame.ItemInfo, 'Setup', RefreshItemInfo)
	for _, key in ipairs(PREVIEW_KEYS) do Hook(frame[key], 'GeneratePreviewTooltip', RefreshPreviewText) end
end

context.Window('ItemUpgradeFrame', { skin = SkinFrame, show = Refresh, install = InstallFrame })
