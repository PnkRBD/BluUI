local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Trade')

local hooksecurefunc = BUI.Prof.MakeHooker('trade')
local ipairs = ipairs

local Skin = BUI.Skinning

local SKIN_ID = 'trade'
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

local installed = false
local skinned = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeArt = context.Fade, context.FadeRegions, context.FadeArt
local Shell, Button, Close, EditBox = context.Shell, context.Button, context.Close, context.EditBox
local Body, Title = context.Body, context.Title
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
	Body(button.Count)
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
	if not Enabled() or not skinned then return end
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
	HookScript(highlight, 'OnShow', function() SetColumnAccent(insetNames, true) end)
	HookScript(highlight, 'OnHide', function() SetColumnAccent(insetNames, false) end)
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
	FadeArt(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	local overlay = frame.RecipientOverlay
	if overlay then
		Fade(overlay.portrait)
		Fade(overlay.portraitFrame)
	end
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
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

local function Apply()
	local frame = _G.TradeFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
		SkinMainFrame(frame)
	end
	SkinHighlights(frame)
	RefreshAllEdges()
end

local function OnPlayerItemUpdated(slotIndex)
	if Enabled() and skinned then RefreshItemEdges(_G[ITEM_PREFIXES.player .. slotIndex .. 'ItemButton']) end
end

local function OnTargetItemUpdated(slotIndex)
	if Enabled() and skinned then RefreshItemEdges(_G[ITEM_PREFIXES.recipient .. slotIndex .. 'ItemButton']) end
end

local function Install()
	if installed then return end
	local frame = _G.TradeFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	hooksecurefunc('TradeFrame_UpdatePlayerItem', OnPlayerItemUpdated)
	hooksecurefunc('TradeFrame_UpdateTargetItem', OnTargetItemUpdated)
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Trade') end
end

local function Deactivate()
	context.Restore()
	skinned = false
	BUI.Print('Trade skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.Trade', TryInstall)
		elseif _G.TradeFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Trade',
	description = 'The trade window: dark shell, framed item slots with quality edges, house money boxes and buttons, accent accept highlight. No preview: it only opens while trading with another player.',
	icon = 'Interface/Icons/INV_Misc_Coin_01',
	test = function()
		return nil
	end,
})
