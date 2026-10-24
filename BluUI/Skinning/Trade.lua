local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning
local BUILib = BluUI.BUILibClient

local ITEM_COUNT = 7
local PLATE_GAP = 4
local HIGHLIGHT_ALPHA = 0.1
local HIGHLIGHT_LEVEL_OFFSET = 6
local ICON_HOVER_ALPHA = 0.2
local ITEM_PREFIXES = { 'TradePlayerItem', 'TradeRecipientItem' }
local HIGHLIGHT_PARTS = { 'Top', 'Middle', 'Bottom' }
local COLUMNS = {
	{ highlights = { 'TradeHighlightPlayer', 'TradeHighlightPlayerEnchant' }, insets = { 'TradePlayerItemsInset', 'TradePlayerEnchantInset' } },
	{ highlights = { 'TradeHighlightRecipient', 'TradeHighlightRecipientEnchant' }, insets = { 'TradeRecipientItemsInset', 'TradeRecipientEnchantInset' } },
}
local RECIPIENT_MONEY_INSETS = { 'TradeRecipientMoneyInset' }
local COIN_BOXES = { { left = 11, width = 62 }, { left = 83, width = 35 }, { left = 128, width = 35 } }
local COIN_BOX_TOP, COIN_BOX_HEIGHT, COIN_CAP, COIN_RIM = -61, 20, 5, 3
local COIN_COVER_LEVEL = 10
local COIN_GOLD_WIDE = 70
local COIN_WIDE_COPPER = 1000000 * 10000
local CLEAR = { 0, 0, 0, 0 }
local ENCHANT_LABELS = { 'TradeFramePlayerEnchantText', 'TradeFrameRecipientEnchantText' }
local NAME_HEADERS = { 'TradeFramePlayerNameText', 'TradeFrameRecipientNameText' }
local ACTION_BUTTONS = { 'TradeFrameTradeButton', 'TradeFrameCancelButton' }

local context = Skin.Define('trade', {
	name = 'Trade',
	description = 'The trade window: card item rows with quality edges, framed money boxes and buttons, green edge on the side that accepted. No preview: it only opens while trading with another player.',
	icon = 'Interface/Icons/INV_Misc_Coin_01',
	newLook = true,
})
local Fade, FadeRegions, FadeArt = context.Fade, context.FadeRegions, context.FadeArt
local Shell, Button, Card = context.Shell, context.Button, context.Card
local Title, Keep = context.Title, context.Keep

local function RefreshItemEdges(button)
	Skin.SetIconEdgeQuality(button.icon, button.IconBorder)
end

local function SkinItemButton(button)
	Fade(button.NormalTexture)
	Fade(button.IconBorder)
	Skin.SquareIcon(button, button.icon)
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

local function SetColumnAccepted(column)
	local accepted = _G[column.highlights[1]]:IsShown()
	for _, name in ipairs(column.insets) do Skin.TipShellEdges(_G[name], accepted and Skin.PALETTE.positive) end
end

local function SkinHighlights(frame)
	local positive = Skin.PALETTE.positive
	for _, column in ipairs(COLUMNS) do
		for _, name in ipairs(column.highlights) do
			for _, part in ipairs(HIGHLIGHT_PARTS) do
				_G[name .. part]:SetColorTexture(positive[1], positive[2], positive[3], HIGHLIGHT_ALPHA)
			end
			_G[name]:SetFrameLevel(frame:GetFrameLevel() + HIGHLIGHT_LEVEL_OFFSET)
		end
	end
end

local function CoverStrip(cover, first, second, width, height)
	local strip = cover:CreateTexture(nil, 'BACKGROUND')
	strip:SetPoint(first)
	strip:SetPoint(second)
	if width then strip:SetWidth(width) else strip:SetHeight(height) end
	BUI.Painter.Fill(strip, 'skinBackground')
end

local function CoverCoinBox(frame, box)
	local cover = context.Own(CreateFrame('Frame', nil, frame))
	cover:SetFrameLevel(frame:GetFrameLevel() + COIN_COVER_LEVEL)
	cover:SetPoint('TOPLEFT', frame, 'TOPLEFT', box.left - COIN_CAP, COIN_BOX_TOP)
	cover:SetSize(box.width + COIN_CAP, COIN_BOX_HEIGHT)
	CoverStrip(cover, 'TOPLEFT', 'TOPRIGHT', nil, COIN_RIM)
	CoverStrip(cover, 'BOTTOMLEFT', 'BOTTOMRIGHT', nil, COIN_RIM)
	CoverStrip(cover, 'TOPLEFT', 'BOTTOMLEFT', COIN_CAP)
	CoverStrip(cover, 'TOPRIGHT', 'BOTTOMRIGHT', COIN_RIM)
	Shell(cover)
	BUILib.Skin.SetShellFill(cover, CLEAR)
	return cover
end

local coinCovers = {}

local function LayoutCoinCovers()
	if not coinCovers[1] then return end
	local wide = GetPlayerTradeMoney() >= COIN_WIDE_COPPER
	coinCovers[1]:SetWidth((wide and COIN_GOLD_WIDE or COIN_BOXES[1].width) + COIN_CAP)
	for index = 2, #coinCovers do coinCovers[index]:SetShown(not wide) end
end

local function SkinMoney(frame)
	if not coinCovers[1] then
		for index, box in ipairs(COIN_BOXES) do coinCovers[index] = CoverCoinBox(frame, box) end
	end
	FadeArt(_G.TradePlayerInputMoneyInset)
	SkinInsets(RECIPIENT_MONEY_INSETS)
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
	ForEachItemButton(SkinItemRow)
	SkinMoney(frame)
	Keep(_G.TradeFrameTradeButton.WarningIcon)
	for _, name in ipairs(ACTION_BUTTONS) do Button(_G[name]) end
	SkinHighlights(frame)
end

local function RefreshFrame()
	LayoutCoinCovers()
	for _, column in ipairs(COLUMNS) do SetColumnAccepted(column) end
	ForEachItemButton(function(name) RefreshItemEdges(_G[name .. 'ItemButton']) end)
end

local function InstallFrame()
	BUI.Events:Register('PLAYER_TRADE_MONEY', 'Skin.Trade coin covers', context.Guard(LayoutCoinCovers))
	context.Hook('TradeFrame_UpdatePlayerItem', function(slotIndex) RefreshItemEdges(_G[ITEM_PREFIXES[1] .. slotIndex .. 'ItemButton']) end)
	context.Hook('TradeFrame_UpdateTargetItem', function(slotIndex) RefreshItemEdges(_G[ITEM_PREFIXES[2] .. slotIndex .. 'ItemButton']) end)
	for _, column in ipairs(COLUMNS) do
		local refresh = context.Guard(function() SetColumnAccepted(column) end)
		_G[column.highlights[1]]:HookScript('OnShow', refresh)
		_G[column.highlights[1]]:HookScript('OnHide', refresh)
	end
end

context.Window('TradeFrame', { skin = SkinFrame, show = RefreshFrame, install = InstallFrame })
