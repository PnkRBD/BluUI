local _, BUI = ...

local Wrap = BUI.Profiler.Wrap

local ipairs = ipairs

local Skin = BUI.Skinning

local ITEM_COUNT = 7
local PLATE_GAP = 4
local HIGHLIGHT_ALPHA = 0.12
local HIGHLIGHT_LEVEL_OFFSET = 6
local ICON_HOVER_ALPHA = 0.2
local ITEM_PREFIXES = { 'TradePlayerItem', 'TradeRecipientItem' }
local HIGHLIGHT_PARTS = { 'Top', 'Middle', 'Bottom' }
local COLUMNS = {
	{ highlights = { 'TradeHighlightPlayer', 'TradeHighlightPlayerEnchant' }, insets = { 'TradePlayerItemsInset', 'TradePlayerEnchantInset' } },
	{ highlights = { 'TradeHighlightRecipient', 'TradeHighlightRecipientEnchant' }, insets = { 'TradeRecipientItemsInset', 'TradeRecipientEnchantInset' } },
}
local MONEY_INSETS = { 'TradePlayerInputMoneyInset', 'TradeRecipientMoneyInset' }
local MONEY_BOX_KEYS = { 'Gold', 'Silver', 'Copper' }
local ENCHANT_LABELS = { 'TradeFramePlayerEnchantText', 'TradeFrameRecipientEnchantText' }
local NAME_HEADERS = { 'TradeFramePlayerNameText', 'TradeFrameRecipientNameText' }
local ACTION_BUTTONS = { 'TradeFrameTradeButton', 'TradeFrameCancelButton' }

local context = Skin.Define('trade', {
	name = 'Trade',
	description = 'The trade window: card item rows with quality edges, house money boxes and buttons, accent edge on the side that accepted. No preview: it only opens while trading with another player.',
	icon = 'Interface/Icons/INV_Misc_Coin_01',
	newLook = true,
})
local Fade, FadeRegions, FadeArt = context.Fade, context.FadeRegions, context.FadeArt
local Shell, Button, Card, EditBox = context.Shell, context.Button, context.Card, context.EditBox
local Title = context.Title
local CropIcon = Skin.CropIcon

local function RefreshItemEdges(button)
	Skin.SetIconEdgeQuality(button.icon, button.IconBorder)
end

local function SkinItemButton(button)
	Fade(button.NormalTexture)
	Fade(button.IconBorder)
	CropIcon(button.icon)
	Skin.TipIconFrame(button, button.icon)
	Skin.FlatTexture(button:GetHighlightTexture(), 1, 1, 1, ICON_HOVER_ALPHA)
	Skin.TipCount(button.Count)
	RefreshItemEdges(button)
end

local function SkinItemRow(name)
	local row = _G[name]
	local button = _G[name .. 'ItemButton']
	Fade(row.SlotTexture)
	Fade(_G[name .. 'NameFrame'])
	Skin.TipFace(_G[name .. 'Name'], 'body')
	if not row._buiPlate then
		local plate = CreateFrame('Frame', nil, row)
		plate:SetFrameLevel(row:GetFrameLevel())
		plate:SetPoint('TOPLEFT', button, 'TOPRIGHT', PLATE_GAP, 0)
		plate:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 0)
		row._buiPlate = plate
	end
	Card(row._buiPlate)
	SkinItemButton(button)
end

local function ForEachItemButton(callback)
	for _, prefix in ipairs(ITEM_PREFIXES) do
		for itemIndex = 1, ITEM_COUNT do callback(prefix .. itemIndex) end
	end
end

local function SkinInsets(names)
	for _, name in ipairs(names) do
		local inset = _G[name]
		FadeArt(inset)
		Shell(inset)
	end
end

local function SetColumnAccent(column)
	local accepted = _G[column.highlights[1]]:IsShown()
	for _, name in ipairs(column.insets) do Skin.TipShellEdges(_G[name], accepted) end
end

local function SkinHighlights(frame)
	for _, column in ipairs(COLUMNS) do
		for _, name in ipairs(column.highlights) do
			for _, part in ipairs(HIGHLIGHT_PARTS) do Skin.AccentTexture(_G[name .. part], HIGHLIGHT_ALPHA) end
			_G[name]:SetFrameLevel(frame:GetFrameLevel() + HIGHLIGHT_LEVEL_OFFSET)
		end
	end
end

local function SkinMoney()
	for _, key in ipairs(MONEY_BOX_KEYS) do
		local box = _G['TradePlayerInputMoneyFrame' .. key]
		if not box:IsForbidden() then EditBox(box) end
	end
	FadeRegions(_G.TradeRecipientMoneyBg)
	Skin.TipFaceTree(_G.TradeRecipientMoneyFrame, 2)
end

local function SkinFrame(frame)
	context.Chrome(frame)
	Fade(frame.RecipientOverlay.portrait)
	Fade(frame.RecipientOverlay.portraitFrame)
	for _, name in ipairs(NAME_HEADERS) do Title(_G[name]) end
	for _, name in ipairs(ENCHANT_LABELS) do Skin.TipFont(_G[name], 'label') end
	for _, column in ipairs(COLUMNS) do SkinInsets(column.insets) end
	SkinInsets(MONEY_INSETS)
	ForEachItemButton(SkinItemRow)
	SkinMoney()
	_G.TradeFrameTradeButton.WarningIcon.__buiSkin = true
	for _, name in ipairs(ACTION_BUTTONS) do Button(_G[name]) end
	SkinHighlights(frame)
end

local function RefreshFrame()
	for _, column in ipairs(COLUMNS) do SetColumnAccent(column) end
	ForEachItemButton(function(name) RefreshItemEdges(_G[name .. 'ItemButton']) end)
end

local function InstallFrame()
	context.Hook('TradeFrame_UpdatePlayerItem', function(slotIndex) RefreshItemEdges(_G[ITEM_PREFIXES[1] .. slotIndex .. 'ItemButton']) end)
	context.Hook('TradeFrame_UpdateTargetItem', function(slotIndex) RefreshItemEdges(_G[ITEM_PREFIXES[2] .. slotIndex .. 'ItemButton']) end)
	for _, column in ipairs(COLUMNS) do
		local refresh = Wrap('Skin.Trade column accent', context.Guard(function() SetColumnAccent(column) end))
		_G[column.highlights[1]]:HookScript('OnShow', refresh)
		_G[column.highlights[1]]:HookScript('OnHide', refresh)
	end
end

context.Window('TradeFrame', { skin = SkinFrame, show = RefreshFrame, install = InstallFrame })
