local _, BUI = ...

local Wrap = BUI.Profiler.Wrap

local ipairs = ipairs

local Skin = BUI.Skinning

local ITEM_COUNT = 7
local PLATE_GAP = 4
local HIGHLIGHT_ALPHA = 0.12
local HIGHLIGHT_LEVEL_OFFSET = 6
local ICON_HOVER_ALPHA = 0.2
local ITEM_PREFIXES = { player = 'TradePlayerItem', recipient = 'TradeRecipientItem' }
local HIGHLIGHT_PARTS = { 'Top', 'Middle', 'Bottom' }
local PLAYER_HIGHLIGHTS = { 'TradeHighlightPlayer', 'TradeHighlightPlayerEnchant' }
local RECIPIENT_HIGHLIGHTS = { 'TradeHighlightRecipient', 'TradeHighlightRecipientEnchant' }
local PLAYER_INSETS = { 'TradePlayerItemsInset', 'TradePlayerEnchantInset' }
local RECIPIENT_INSETS = { 'TradeRecipientItemsInset', 'TradeRecipientEnchantInset' }
local MONEY_INSETS = { 'TradePlayerInputMoneyInset', 'TradeRecipientMoneyInset' }
local MONEY_BOX_KEYS = { 'Gold', 'Silver', 'Copper' }
local ENCHANT_LABELS = { 'TradeFramePlayerEnchantText', 'TradeFrameRecipientEnchantText' }
local NAME_HEADERS = { 'TradeFramePlayerNameText', 'TradeFrameRecipientNameText' }
local ACTION_BUTTONS = { 'TradeFrameTradeButton', 'TradeFrameCancelButton' }

local context = Skin.Define('trade', {
	name = 'Trade',
	description = 'The trade window: dark shell, framed item slots with quality edges, house money boxes and buttons, accent accept highlight. No preview: it only opens while trading with another player.',
	icon = 'Interface/Icons/INV_Misc_Coin_01',
})
local Enabled = context.Enabled
local Fade, FadeRegions, FadeArt = context.Fade, context.FadeRegions, context.FadeArt
local Shell, Button, EditBox = context.Shell, context.Button, context.EditBox
local Title = context.Title
local FlatTexture, AccentTexture, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.CropIcon

local function RefreshItemEdges(button)
	if not button then return end
	Skin.SetIconEdgeQuality(button.icon, button.IconBorder)
end

local function SkinItemButton(button)
	if not button then return end
	Fade(button.NormalTexture)
	Fade(button.IconBorder)
	local icon = button.icon
	if icon then
		CropIcon(icon)
		Skin.TipIconFrame(button, icon)
	end
	FlatTexture(button:GetHighlightTexture(), 1, 1, 1, ICON_HOVER_ALPHA)
	Skin.TipCount(button.Count)
	RefreshItemEdges(button)
end

local function SkinItemRow(name)
	local row = _G[name]
	if not row then return end
	local button = _G[name .. 'ItemButton']
	Fade(row.SlotTexture)
	Fade(_G[name .. 'NameFrame'])
	Skin.TipFace(_G[name .. 'Name'], 'body')
	if button and not row._buiPlate then
		local plate = CreateFrame('Frame', nil, row)
		plate:SetFrameLevel(row:GetFrameLevel())
		plate:SetPoint('TOPLEFT', button, 'TOPRIGHT', PLATE_GAP, 0)
		plate:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 0)
		row._buiPlate = plate
	end
	if row._buiPlate then Shell(row._buiPlate) end
	SkinItemButton(button)
end

local function SkinItemColumns()
	for _, prefix in pairs(ITEM_PREFIXES) do
		for itemIndex = 1, ITEM_COUNT do SkinItemRow(prefix .. itemIndex) end
	end
end

local function SkinInsets(names)
	for _, name in ipairs(names) do
		local inset = _G[name]
		if inset then
			FadeArt(inset)
			Shell(inset)
		end
	end
end

local function SetColumnAccent(insetNames, accent)
	if not Enabled() then return end
	for _, name in ipairs(insetNames) do
		local inset = _G[name]
		if inset and inset._buiShell then Skin.TipShellEdges(inset, accent) end
	end
end

local function SkinHighlight(name, frame, insetNames)
	local highlight = _G[name]
	if not highlight then return end
	for _, part in ipairs(HIGHLIGHT_PARTS) do AccentTexture(_G[name .. part], HIGHLIGHT_ALPHA) end
	highlight:SetFrameLevel(frame:GetFrameLevel() + HIGHLIGHT_LEVEL_OFFSET)
	if highlight._buiAcceptHooked then return end
	highlight._buiAcceptHooked = true
	highlight:HookScript('OnShow', Wrap('Skin.Trade column accent', function() SetColumnAccent(insetNames, true) end))
	highlight:HookScript('OnHide', Wrap('Skin.Trade column accent', function() SetColumnAccent(insetNames, false) end))
end

local function SkinHighlights(frame)
	for _, name in ipairs(PLAYER_HIGHLIGHTS) do SkinHighlight(name, frame, PLAYER_INSETS) end
	for _, name in ipairs(RECIPIENT_HIGHLIGHTS) do SkinHighlight(name, frame, RECIPIENT_INSETS) end
	local playerHighlight = _G[PLAYER_HIGHLIGHTS[1]]
	SetColumnAccent(PLAYER_INSETS, playerHighlight and playerHighlight:IsShown())
	local recipientHighlight = _G[RECIPIENT_HIGHLIGHTS[1]]
	SetColumnAccent(RECIPIENT_INSETS, recipientHighlight and recipientHighlight:IsShown())
end

local function SkinMoney()
	local input = _G.TradePlayerInputMoneyFrame
	if input then
		for _, key in ipairs(MONEY_BOX_KEYS) do
			local box = _G['TradePlayerInputMoneyFrame' .. key]
			if box and not box:IsForbidden() then EditBox(box) end
		end
	end
	FadeRegions(_G.TradeRecipientMoneyBg)
	Skin.TipFaceTree(_G.TradeRecipientMoneyFrame, 2)
end

local function SkinActionButtons()
	local tradeButton = _G.TradeFrameTradeButton
	if tradeButton and tradeButton.WarningIcon then tradeButton.WarningIcon.__buiSkin = true end
	for _, name in ipairs(ACTION_BUTTONS) do Button(_G[name]) end
end

local function SkinMainFrame(frame)
	context.Chrome(frame)
	local overlay = frame.RecipientOverlay
	if overlay then
		Fade(overlay.portrait)
		Fade(overlay.portraitFrame)
	end
	for _, name in ipairs(NAME_HEADERS) do Title(_G[name]) end
	for _, name in ipairs(ENCHANT_LABELS) do Skin.TipFont(_G[name], 'label') end
	SkinInsets(PLAYER_INSETS)
	SkinInsets(RECIPIENT_INSETS)
	SkinInsets(MONEY_INSETS)
	SkinItemColumns()
	SkinMoney()
	SkinActionButtons()
end

local function RefreshAllEdges()
	for _, prefix in pairs(ITEM_PREFIXES) do
		for itemIndex = 1, ITEM_COUNT do RefreshItemEdges(_G[prefix .. itemIndex .. 'ItemButton']) end
	end
end

local function RefreshFrame(frame)
	SkinHighlights(frame)
	RefreshAllEdges()
end

local function OnPlayerItemUpdated(slotIndex)
	RefreshItemEdges(_G[ITEM_PREFIXES.player .. slotIndex .. 'ItemButton'])
end

local function OnTargetItemUpdated(slotIndex)
	RefreshItemEdges(_G[ITEM_PREFIXES.recipient .. slotIndex .. 'ItemButton'])
end

context.Window('TradeFrame', {
	skin = SkinMainFrame,
	show = RefreshFrame,
	install = function()
		context.Hook('TradeFrame_UpdatePlayerItem', OnPlayerItemUpdated)
		context.Hook('TradeFrame_UpdateTargetItem', OnTargetItemUpdated)
	end,
})
