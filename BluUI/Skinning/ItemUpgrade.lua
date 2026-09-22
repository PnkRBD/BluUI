local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('ItemUpgrade')

local hooksecurefunc = BUI.Prof.MakeHooker('itemupgrade')
local ipairs, pairs = ipairs, pairs

local Skin = BUI.Skinning

local SKIN_ID = 'itemupgrade'
local SLOT_ART = { 'ButtonFrame', 'EmptySlotGlow', 'IconBorder' }
local PANEL_KEYS = { 'TopBG', 'BottomBG' }
local PREVIEW_KEYS = { 'LeftItemPreviewFrame', 'RightItemPreviewFrame', 'ItemHoverPreviewFrame' }
local CURRENCY_KEYS = { 'UpgradeCostFrame', 'PlayerCurrencies' }
local PANEL_INSET = 2
local COST_PADDING_X = 16
local COST_PADDING_Y = 4
local SLOT_HOVER_ALPHA = 0.2
local MONEY_DEPTH = 2

local installed = false
local skinned = false
local plates = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys, FadeArt = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt
local Shell, Button, Close, Dropdown = context.Shell, context.Button, context.Close, context.Dropdown
local Title, Body, Face = context.Title, context.Body, context.Face
local FlatTexture, CropIcon = Skin.FlatTexture, Skin.CropIcon

local function PanelPlate(parent, anchor, insetX, insetY)
	if not parent or not anchor then return end
	local plate = plates[anchor]
	if not plate then
		plate = CreateFrame('Frame', nil, parent)
		plate:SetFrameLevel(parent:GetFrameLevel())
		plate:SetPoint('TOPLEFT', anchor, 'TOPLEFT', insetX, -insetY)
		plate:SetPoint('BOTTOMRIGHT', anchor, 'BOTTOMRIGHT', -insetX, insetY)
		plates[anchor] = plate
	end
	plate:Show()
	Shell(plate)
end

local function RefreshSlot(button)
	if not button then return end
	if button.PulseEmptySlotGlow then button.PulseEmptySlotGlow:Stop() end
	if button.EmptySlotGlow then button.EmptySlotGlow:SetAlpha(0) end
	Skin.SetIconEdgeQuality(button.icon, button.IconBorder)
end

local function SkinSlot(button)
	if not button then return end
	FadeKeys(button, SLOT_ART)
	local icon = button.icon
	if icon then
		CropIcon(icon)
		Skin.TipIconFrame(button, icon)
	end
	FlatTexture(button:GetHighlightTexture(), 1, 1, 1, SLOT_HOVER_ALPHA)
	Face(button.Count)
	RefreshSlot(button)
end

local function RefreshItemInfo(itemInfo)
	if not itemInfo then return end
	Body(itemInfo.MissingItemText)
	Face(itemInfo.ItemName)
	Body(itemInfo.UpgradeProgress)
	Skin.TipFont(itemInfo.UpgradeTo, 'label')
	Dropdown(itemInfo.Dropdown)
end

local function RefreshCurrencyFrame(currencyFrame)
	if not currencyFrame then return end
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
	if not preview then return end
	local name = preview:GetName()
	if not name then return end
	for lineIndex = 1, preview:NumLines() do
		Face(_G[name .. 'TextLeft' .. lineIndex])
		Face(_G[name .. 'TextRight' .. lineIndex])
	end
end

local function SkinPreview(preview)
	if not preview then return end
	Fade(preview.NineSlice)
	Shell(preview)
	RefreshPreviewText(preview)
end

local function SkinCostFrame(costFrame)
	if not costFrame then return end
	Fade(costFrame.BGTex)
	PanelPlate(costFrame, costFrame, -COST_PADDING_X, -COST_PADDING_Y)
	RefreshCurrencyFrame(costFrame)
end

local function SkinCurrencyStrip(frame)
	local border = frame.PlayerCurrenciesBorder
	if border then
		FadeRegions(border)
		Shell(border)
	end
	RefreshCurrencyFrame(frame.PlayerCurrencies)
end

local function SkinMainFrame(frame)
	FadeArt(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Fade(_G.ItemUpgradeFramePortrait)
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
	for _, key in ipairs(PANEL_KEYS) do PanelPlate(frame, frame[key], PANEL_INSET, PANEL_INSET) end
	Body(frame.MissingDescription)
	Face(frame.FrameErrorText)
	Face(frame.LeftPreviewBigText)
	Face(frame.RightPreviewBigText)
	SkinSlot(frame.UpgradeItemButton)
	RefreshItemInfo(frame.ItemInfo)
	Button(frame.UpgradeButton)
	SkinCostFrame(frame.UpgradeCostFrame)
	SkinCurrencyStrip(frame)
	for _, key in ipairs(PREVIEW_KEYS) do SkinPreview(frame[key]) end
end

local function Refresh(frame)
	RefreshSlot(frame.UpgradeItemButton)
	RefreshItemInfo(frame.ItemInfo)
	for _, key in ipairs(CURRENCY_KEYS) do RefreshCurrencyFrame(frame[key]) end
	for _, key in ipairs(PREVIEW_KEYS) do RefreshPreviewText(frame[key]) end
end

local function Apply()
	local frame = _G.ItemUpgradeFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
		SkinMainFrame(frame)
	end
	Refresh(frame)
end

local function OnItemInfoUpdated(frame)
	if Enabled() and skinned then Refresh(frame) end
end

local function OnPreviewFramesPopulated(frame)
	if not Enabled() or not skinned then return end
	RefreshSlot(frame.UpgradeItemButton)
	for _, key in ipairs(CURRENCY_KEYS) do RefreshCurrencyFrame(frame[key]) end
end

local function OnItemInfoSetup(itemInfo)
	if Enabled() and skinned then RefreshItemInfo(itemInfo) end
end

local function OnPreviewGenerated(preview)
	if Enabled() and skinned then RefreshPreviewText(preview) end
end

local function Install()
	if installed then return end
	local frame = _G.ItemUpgradeFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	hooksecurefunc(frame, 'UpdateUpgradeItemInfo', OnItemInfoUpdated)
	hooksecurefunc(frame, 'PopulatePreviewFrames', OnPreviewFramesPopulated)
	if frame.ItemInfo then hooksecurefunc(frame.ItemInfo, 'Setup', OnItemInfoSetup) end
	for _, key in ipairs(PREVIEW_KEYS) do
		local preview = frame[key]
		if preview and preview.GeneratePreviewTooltip then
			hooksecurefunc(preview, 'GeneratePreviewTooltip', OnPreviewGenerated)
		end
	end
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.ItemUpgrade') end
end

local function Deactivate()
	context.Restore()
	for _, plate in pairs(plates) do plate:Hide() end
	skinned = false
	BUI.Print('Item Upgrade skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.ItemUpgrade', TryInstall)
		elseif _G.ItemUpgradeFrame and _G.ItemUpgradeFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Item Upgrade',
	description = 'The item upgrade window: dark shell over the stone panels, framed item slot and currency icons, house fonts on the upgrade previews, level dropdown and cost strip.',
	icon = 'Interface/Icons/UI_ItemUpgrade',
})

BUI.Events:Once('PLAYER_LOGIN', 'Skin.ItemUpgradeInstall', function()
	if not Enabled() then return end
	Install()
	if not installed then BUI.Events:Register('ADDON_LOADED', 'Skin.ItemUpgrade', TryInstall) end
end)
