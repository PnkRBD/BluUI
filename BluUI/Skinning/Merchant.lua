local _, BUI = ...

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Widget = BUILib.Widget
local Controls = BUILib.Controls
local Colors = BUILib.Colors
local FONT = BUILib.Font or STANDARD_TEXT_FONT
local Skin = BUI.Skinning
local Pixel = BUI.Pixel

local TAB_BUY, TAB_BUYBACK, TAB_BULK = 1, 2, 3
local ROW_HEIGHT = 40
local ROW_PAD = 2
local FRAME_WIDTH = 480
local FRAME_HEIGHT = 560
local SCROLL_PAD = 8
local MAX_QTY = 200
local ICON_SIZE = 32
local COST_ICON_SIZE = 14

local TYPE_FILTERS = {
	{ label = 'All',         classID = nil },
	{ label = 'Weapons',     classID = 2 },
	{ label = 'Armor',       classID = 4 },
	{ label = 'Consumables', classID = 0 },
	{ label = 'Bags',        classID = 1 },
	{ label = 'Gems',        classID = 3 },
	{ label = 'Recipes',     classID = 9 },
	{ label = 'Trade Goods', classID = 7 },
	{ label = 'Reagents',    classID = 5 },
	{ label = 'Mounts',      classID = 15, subclassID = 5 },
	{ label = 'Misc',        classID = 15, excludeSub = 5 },
}

local activeTab = TAB_BUY
local activeTypeFilter
local searchText = ''
local merchantFrame
local sellJunkActive = false
local listReset = true

local buyItems = {}
local buybackItems = {}
local buyRows = {}
local buybackRows = {}
local bulkRows = {}
local visibleCurrencies = {}
local currencySeen = {}

local RefreshContent

local function QueryMerchantItem(index)
	local info = C_MerchantFrame.GetItemInfo(index)
	if info then return info end
	local name, texture, price, stackCount, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(index)
	if not name then return nil end
	return {
		name = name,
		texture = texture,
		price = price or 0,
		stackCount = stackCount or 1,
		numAvailable = numAvailable or -1,
		isUsable = isUsable,
		hasExtendedCost = extendedCost,
	}
end

local function GetItemClass(merchantIndex)
	local itemID = GetMerchantItemID(merchantIndex)
	if not itemID then return nil, nil end
	local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
	return classID, subclassID
end

local function PassesTypeFilter(classID, subclassID)
	if not activeTypeFilter or not activeTypeFilter.classID then return true end
	if classID ~= activeTypeFilter.classID then return false end
	if activeTypeFilter.subclassID and subclassID ~= activeTypeFilter.subclassID then return false end
	if activeTypeFilter.excludeSub and subclassID == activeTypeFilter.excludeSub then return false end
	return true
end

local function PassesSearch(name)
	if searchText == '' then return true end
	return name:lower():find(searchText, 1, true) ~= nil
end

local function CanAffordMerchantItem(merchantIndex, goldPrice, hasExtendedCost)
	if goldPrice and goldPrice > 0 and goldPrice > GetMoney() then return false end
	if not hasExtendedCost then return true end

	local numCosts = GetMerchantItemCostInfo(merchantIndex)
	for costIndex = 1, numCosts or 0 do
		local _, quantity, link = GetMerchantItemCostItem(merchantIndex, costIndex)
		if link and quantity then
			local currencyID = tonumber(link:match('currency:(%d+)'))
			if currencyID then
				local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
				if info and info.quantity < quantity then return false end
			end
			local itemID = tonumber(link:match('item:(%d+)'))
			if itemID and C_Item.GetItemCount(itemID, true) < quantity then return false end
		end
	end
	return true
end

local function GetSellPrice(itemID)
	if not itemID then return 0 end
	return select(11, C_Item.GetItemInfo(itemID)) or 0
end

local function GetJunkValue()
	local total = 0
	for bag = 0, 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.quality == 0 and not info.hasNoValue and info.itemID then
				local price = GetSellPrice(info.itemID)
				if price > 0 then total = total + price * (info.stackCount or 1) end
			end
		end
	end
	return total
end

local function SellJunkNext()
	if not sellJunkActive then return end
	for bag = 0, 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.quality == 0 and not info.hasNoValue and info.itemID then
				C_Container.UseContainerItem(bag, slot)
				C_Timer.After(0.2, SellJunkNext)
				return
			end
		end
	end
	sellJunkActive = false
	RefreshContent()
end

local function SellJunk()
	if sellJunkActive then return end
	sellJunkActive = true
	SellJunkNext()
end

local scanTip = CreateFrame('GameTooltip', 'BUIMerchantScanTip', nil, 'GameTooltipTemplate')
scanTip:SetOwner(WorldFrame, 'ANCHOR_NONE')

local function ScanMerchantItemStatus(merchantIndex)
	scanTip:ClearLines()
	scanTip:SetMerchantItem(merchantIndex)
	for lineIndex = 2, scanTip:NumLines() do
		local line = _G['BUIMerchantScanTipTextLeft' .. lineIndex]
		local text = line and line:GetText()
		if text == ITEM_SPELL_KNOWN then
			return 'Already known'
		elseif text and text:find('^Requires') then
			return text
		end
	end
end

local function ScanBuyItems()
	local count = 0
	for merchantIndex = 1, GetMerchantNumItems() do
		local info = QueryMerchantItem(merchantIndex)
		if info and info.name then
			local classID, subclassID = GetItemClass(merchantIndex)
			if PassesTypeFilter(classID, subclassID) and PassesSearch(info.name) then
				count = count + 1
				local entry = buyItems[count] or {}
				buyItems[count] = entry
				entry.idx = merchantIndex
				entry.name = info.name
				entry.texture = info.texture
				entry.price = info.price or 0
				entry.stackCount = info.stackCount or 1
				entry.numAvailable = info.numAvailable or -1
				entry.canAfford = CanAffordMerchantItem(merchantIndex, info.price, info.hasExtendedCost)
				entry.isUsable = info.isUsable ~= false
				entry.statusText = (info.isUsable == false) and ScanMerchantItemStatus(merchantIndex) or nil
				entry.extendedCost = info.hasExtendedCost
				entry.qualityR, entry.qualityG, entry.qualityB = Skin.QualityColor(GetMerchantItemID(merchantIndex))
			end
		end
	end
	for itemIndex = count + 1, #buyItems do buyItems[itemIndex] = nil end
end

local function ScanBuybackItems()
	local count = 0
	for buybackIndex = 1, GetNumBuybackItems() do
		local name, texture, price, stackCount = GetBuybackItemInfo(buybackIndex)
		if name and PassesSearch(name) then
			local link = GetBuybackItemLink(buybackIndex)
			local itemID = link and tonumber(link:match('item:(%d+)'))
			count = count + 1
			local entry = buybackItems[count] or {}
			buybackItems[count] = entry
			entry.idx = buybackIndex
			entry.name = name
			entry.texture = texture
			entry.price = price or 0
			entry.stackCount = stackCount or 1
			entry.qualityR, entry.qualityG, entry.qualityB = Skin.QualityColor(itemID)
		end
	end
	for itemIndex = count + 1, #buybackItems do buybackItems[itemIndex] = nil end
end

local function CollectVisibleCurrencies()
	wipe(currencySeen)
	local count = 0
	for merchantIndex = 1, GetMerchantNumItems() do
		local numCosts = GetMerchantItemCostInfo(merchantIndex)
		for costIndex = 1, numCosts or 0 do
			local texture, _, link = GetMerchantItemCostItem(merchantIndex, costIndex)
			if link then
				local currencyID = tonumber(link:match('currency:(%d+)'))
				if currencyID and not currencySeen[currencyID] then
					currencySeen[currencyID] = true
					count = count + 1
					local entry = visibleCurrencies[count] or {}
					visibleCurrencies[count] = entry
					entry.id = currencyID
					entry.texture = texture
					entry.link = link
				end
			end
		end
	end
	for currencyIndex = count + 1, #visibleCurrencies do visibleCurrencies[currencyIndex] = nil end
	table.sort(visibleCurrencies, function(leftCurrency, rightCurrency) return leftCurrency.id < rightCurrency.id end)
end

local function CreateIconLabel(parent, fontSize)
	local frame = CreateFrame('Frame', nil, parent)
	frame:SetSize(Pixel.Scale(COST_ICON_SIZE + 30), Pixel.Scale(COST_ICON_SIZE + 4))
	frame:EnableMouse(true)

	frame.icon = frame:CreateTexture(nil, 'ARTWORK')
	frame.icon:SetSize(Pixel.Scale(COST_ICON_SIZE), Pixel.Scale(COST_ICON_SIZE))
	frame.icon:SetPoint('LEFT')
	frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	frame.qtyText = frame:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(frame.qtyText, fontSize or 10, FONT, '')
	frame.qtyText:SetPoint('LEFT', frame.icon, 'RIGHT', Pixel.Scale(2), 0)
	frame.qtyText:SetTextColor(0.8, 0.8, 0.8, 1)

	frame:SetScript('OnEnter', function(self)
		if self.link then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetHyperlink(self.link)
			GameTooltip:Show()
		end
	end)
	frame:SetScript('OnLeave', function() GameTooltip:Hide() end)
	return frame
end

local function PopulateCostIcons(row, merchantIndex, hasExtendedCost)
	if not row.costIcons then row.costIcons = {} end
	for _, costIcon in ipairs(row.costIcons) do costIcon:Hide() end
	if not hasExtendedCost then return end

	local numCosts = GetMerchantItemCostInfo(merchantIndex)
	if not numCosts or numCosts == 0 then return end

	local previousAnchor = row.priceText
	for costIndex = 1, numCosts do
		local texture, quantity, link = GetMerchantItemCostItem(merchantIndex, costIndex)
		if texture and quantity then
			local costIcon = row.costIcons[costIndex]
			if not costIcon then
				costIcon = CreateIconLabel(row)
				row.costIcons[costIndex] = costIcon
			end
			costIcon.icon:SetTexture(texture)
			costIcon.qtyText:SetText(quantity)
			costIcon.link = link
			costIcon:ClearAllPoints()
			if previousAnchor == row.priceText then
				local goldText = row.priceText:GetText()
				if goldText and goldText ~= '' then
					costIcon:SetPoint('LEFT', row.priceText, 'RIGHT', Pixel.Scale(6), 0)
				else
					costIcon:SetPoint('LEFT', row.iconBorder, 'RIGHT', Pixel.Scale(8), Pixel.Scale(-8))
				end
			else
				costIcon:SetPoint('LEFT', previousAnchor, 'RIGHT', Pixel.Scale(6), 0)
			end
			costIcon:Show()
			previousAnchor = costIcon
		end
	end
end

local function UpdateCurrencyBar(parentFrame)
	if not parentFrame.currencyFrames then parentFrame.currencyFrames = {} end
	for _, frame in ipairs(parentFrame.currencyFrames) do frame:Hide() end
	if activeTab == TAB_BUYBACK or #visibleCurrencies == 0 then return end

	local previousFrame
	for currencyIndex, currency in ipairs(visibleCurrencies) do
		local frame = parentFrame.currencyFrames[currencyIndex]
		if not frame then
			frame = CreateIconLabel(parentFrame, 11)
			frame:SetFrameLevel(parentFrame:GetFrameLevel() + 10)
			parentFrame.currencyFrames[currencyIndex] = frame
		end

		frame.icon:SetTexture(currency.texture)
		frame.link = currency.link

		local info = C_CurrencyInfo.GetCurrencyInfo(currency.id)
		frame.qtyText:SetText(info and info.quantity or 0)

		frame.qtyText:SetWidth(0)
		frame:SetWidth(Pixel.Scale(COST_ICON_SIZE + 3 + (frame.qtyText:GetStringWidth() or 30) + 2))

		frame:ClearAllPoints()
		if previousFrame then
			frame:SetPoint('LEFT', previousFrame, 'RIGHT', Pixel.Scale(12), 0)
		else
			frame:SetPoint('BOTTOMLEFT', parentFrame, 'BOTTOMLEFT', Pixel.Scale(16), Pixel.Scale(36))
		end
		frame:Show()
		previousFrame = frame
	end
end

local function ApplyAffordTint(row, info)
	if not info.canAfford then
		row.nameText:SetTextColor(info.qualityR * 0.5, info.qualityG * 0.5, info.qualityB * 0.5)
		row.nameText:SetAlpha(0.6)
		row.iconBorder:SetBackdropBorderColor(0.5, 0.15, 0.15, 1)
		row.priceText:SetAlpha(0.7)
		row.priceText:SetTextColor(0.7, 0.25, 0.25, 1)
	elseif not info.isUsable then
		row.nameText:SetTextColor(info.qualityR * 0.7, info.qualityG * 0.7, info.qualityB * 0.7)
		row.nameText:SetAlpha(0.8)
		row.iconBorder:SetBackdropBorderColor(info.qualityR, info.qualityG, info.qualityB, 0.5)
		row.priceText:SetAlpha(1)
		row.priceText:SetTextColor(0.65, 0.65, 0.65, 1)
	else
		row.nameText:SetTextColor(info.qualityR, info.qualityG, info.qualityB)
		row.nameText:SetAlpha(1)
		row.iconBorder:SetBackdropBorderColor(info.qualityR, info.qualityG, info.qualityB, 1)
		row.priceText:SetAlpha(1)
		row.priceText:SetTextColor(0.65, 0.65, 0.65, 1)
	end
end

local function CreateBuyRow(parent)
	local row = Skin.CreateListRow(parent, ROW_HEIGHT, ICON_SIZE)
	row.nameText:SetPoint('RIGHT', row, 'RIGHT', Pixel.Scale(-170), 0)

	row.stockText = row:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(row.stockText, 9, FONT, '')
	row.stockText:SetPoint('LEFT', row.nameText, 'RIGHT', Pixel.Scale(4), 0)
	row.stockText:SetTextColor(0.5, 0.5, 0.5, 1)

	row.statusText = row:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(row.statusText, 9, FONT, '')
	row.statusText:SetPoint('LEFT', row.iconBorder, 'RIGHT', Pixel.Scale(8), Pixel.Scale(-8))
	row.statusText:SetTextColor(0.6, 0.4, 0.4, 1)

	local buyButton = Skin.SmallButton(row, 48, 22, 'Buy')
	buyButton:SetPoint('RIGHT', row, 'RIGHT', Pixel.Scale(-8), 0)

	row.stepper = Controls.Stepper(row, nil, 0, 0, MAX_QTY, 1, function(value) row.qty = value end, 75, 22)
	row.stepper:ClearAllPoints()
	row.stepper:SetPoint('RIGHT', buyButton, 'LEFT', Pixel.Scale(-6), 0)

	row.qty = 0

	buyButton:SetScript('OnClick', function()
		if not row.merchantIdx or not row.canAfford then return end
		local stepperFrame = Widget.Unwrap(row.stepper)
		if stepperFrame.valueBox and stepperFrame.valueBox:HasFocus() then stepperFrame.valueBox:ClearFocus() end
		local quantity = stepperFrame.GetValue and stepperFrame:GetValue() or row.qty
		if quantity < 1 then return end
		if not row.extendedCost or quantity == 1 then
			BuyMerchantItem(row.merchantIdx, quantity)
			return
		end

		local remaining = quantity
		local function BuyOne()
			if remaining <= 0 then return end
			if not merchantFrame or not merchantFrame:IsShown() then return end
			remaining = remaining - 1
			BuyMerchantItem(row.merchantIdx, 1)
			if remaining > 0 then C_Timer.After(0.2, BuyOne) end
		end
		BuyOne()
	end)

	row:HookScript('OnClick', function(self)
		if not self.merchantIdx then return end
		if IsModifiedClick('DRESSUP') then
			local link = GetMerchantItemLink(self.merchantIdx)
			if link then DressUpLink(link) end
		elseif IsModifiedClick('CHATLINK') then
			ChatEdit_InsertLink(GetMerchantItemLink(self.merchantIdx))
		end
	end)

	row:HookScript('OnEnter', function(self)
		if self.merchantIdx then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetMerchantItem(self.merchantIdx)
			GameTooltip:Show()
		end
	end)

	return row
end

local function CreateBuybackRow(parent)
	local row = Skin.CreateListRow(parent, ROW_HEIGHT, ICON_SIZE)
	row.nameText:SetPoint('RIGHT', row, 'RIGHT', Pixel.Scale(-80), 0)

	local buybackButton = Skin.SmallButton(row, 62, 22, 'Buyback')
	buybackButton:SetPoint('RIGHT', row, 'RIGHT', Pixel.Scale(-8), 0)
	buybackButton:SetScript('OnClick', function()
		if row.buybackIdx then BuybackItem(row.buybackIdx) end
	end)

	row:HookScript('OnClick', function(self)
		if not self.buybackIdx then return end
		local link = GetBuybackItemLink(self.buybackIdx)
		if not link then return end
		if IsModifiedClick('DRESSUP') then
			DressUpLink(link)
		elseif IsModifiedClick('CHATLINK') then
			ChatEdit_InsertLink(link)
		end
	end)

	row:HookScript('OnEnter', function(self)
		if self.buybackIdx then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetBuybackItem(self.buybackIdx)
			GameTooltip:Show()
		end
	end)

	return row
end

local function PopulateBuyRows(items, pool, parent, isBulk)
	for itemIndex, info in ipairs(items) do
		local row = Skin.GetPooledRow(pool, CreateBuyRow, parent, itemIndex)
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', 0, Pixel.Scale(-(itemIndex - 1) * (ROW_HEIGHT + ROW_PAD)))
		row:SetPoint('RIGHT')
		row.icon:SetTexture(info.texture)

		if row.merchantIdx ~= info.idx then
			row.qty = isBulk and 0 or 1
			row.stepper:SetValue(row.qty)
		end
		row.merchantIdx = info.idx
		row.canAfford = info.canAfford
		row.extendedCost = info.extendedCost
		row.nameText:SetText(info.name)
		row.icon:SetDesaturated(not info.canAfford)

		ApplyAffordTint(row, info)

		if info.statusText then
			row.statusText:SetText(info.statusText)
			row.statusText:Show()
			row.priceText:Hide()
		else
			row.statusText:Hide()
			row.priceText:Show()
		end

		local hasStock = info.numAvailable and info.numAvailable > 0
		if hasStock then row.stockText:SetText('x' .. info.numAvailable) end
		row.stockText:SetShown(hasStock)

		local goldString = info.price > 0 and GetCoinTextureString(info.price) or nil
		row.priceText:SetText(goldString or (info.extendedCost and '' or 'Free'))
		PopulateCostIcons(row, info.idx, info.extendedCost)

		if row.costIcons then
			local affordAlpha = info.canAfford and 1 or 0.5
			for _, costIcon in ipairs(row.costIcons) do
				if costIcon:IsShown() then costIcon:SetAlpha(affordAlpha) end
			end
		end
		row:Show()
	end
	for rowIndex = #items + 1, #pool do pool[rowIndex]:Hide() end
	parent:SetHeight(Pixel.Scale(math.max(1, #items * (ROW_HEIGHT + ROW_PAD))))
end

local function PopulateBuybackRows(items, pool, parent)
	for itemIndex, info in ipairs(items) do
		local row = Skin.GetPooledRow(pool, CreateBuybackRow, parent, itemIndex)
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', 0, Pixel.Scale(-(itemIndex - 1) * (ROW_HEIGHT + ROW_PAD)))
		row:SetPoint('RIGHT')
		row.icon:SetTexture(info.texture)
		row.nameText:SetText(info.name)
		row.nameText:SetTextColor(info.qualityR, info.qualityG, info.qualityB)
		row.iconBorder:SetBackdropBorderColor(info.qualityR, info.qualityG, info.qualityB, 1)
		row.buybackIdx = info.idx
		row.priceText:SetText(info.price > 0 and GetCoinTextureString(info.price) or 'Free')
		row:Show()
	end
	for rowIndex = #items + 1, #pool do pool[rowIndex]:Hide() end
	parent:SetHeight(Pixel.Scale(math.max(1, #items * (ROW_HEIGHT + ROW_PAD))))
end

local function BuildLootFilterItems()
	local items = {}
	local numSpecs = GetNumSpecializations()
	for specIndex = 1, numSpecs do
		local _, name = GetSpecializationInfo(specIndex)
		if name then items[#items + 1] = { label = name, filterIndex = specIndex } end
	end
	if numSpecs > 0 then
		items[#items + 1] = { label = 'All Specs', filterIndex = numSpecs + 1 }
	end
	items[#items + 1] = { label = 'BoE Only', filterIndex = numSpecs + 2 }
	items[#items + 1] = { label = 'All', filterIndex = LE_LOOT_FILTER_ALL }
	return items
end

local function CreatePanel(parent)
	local panel = CreateFrame('Frame', nil, parent)
	panel:SetAllPoints()
	local scroll, child = Skin.CreateScrollArea(panel, ROW_HEIGHT, SCROLL_PAD)
	return panel, scroll, child
end

local function BuildFrame()
	if merchantFrame then return end

	local frame = Widget.New(UIParent, 'Frame', nil, {
		bg = Colors.bg.dark,
		border = Colors.border.light,
		size = { FRAME_WIDTH, FRAME_HEIGHT },
	}).frame
	Skin.MakeDraggable(frame, 'merchant', 'CENTER', Pixel.Scale(-100), 0, 'MerchantFrame')
	frame:SetFrameStrata('DIALOG')
	frame:SetFrameLevel(100)
	frame:Hide()

	local titleBar = Skin.CreateTitleBar(frame, 'Merchant', 36, CloseMerchant)

	frame.countText = titleBar:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(frame.countText, 11, FONT, '')
	frame.countText:SetPoint('RIGHT', titleBar.closeBtn.frame, 'LEFT', Pixel.Scale(-12), 0)
	frame.countText:SetTextColor(0.5, 0.5, 0.5, 1)

	frame.tabBar = Controls.TabLineBar(frame, { 'Buy', 'Buyback', 'Bulk Buy' }, TAB_BUY, function(tabIndex)
		activeTab = tabIndex
		listReset = true
		RefreshContent()
	end, FRAME_WIDTH - 24)
	frame.tabBar:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-38))

	frame.searchBox = Skin.CreateSearchBox(frame, 150, function(text)
		searchText = text
		listReset = true
		RefreshContent()
	end)
	frame.searchBox:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-74))

	local filterDropdown = Skin.CreateDropdown(frame, TYPE_FILTERS, function(item)
		activeTypeFilter = item
		listReset = true
		RefreshContent()
	end, 140)
	filterDropdown:SetPoint('LEFT', frame.searchBox, 'RIGHT', Pixel.Scale(6), 0)

	local lootFilterItems = BuildLootFilterItems()
	if SetMerchantFilter and #lootFilterItems > 1 then
		local lootDropdown = Skin.CreateDropdown(frame, lootFilterItems, function(item)
			SetMerchantFilter(item.filterIndex)
			listReset = true
			RefreshContent()
		end, 140)
		lootDropdown:SetPoint('LEFT', filterDropdown, 'RIGHT', Pixel.Scale(6), 0)
		lootDropdown.label:SetText('All')
		frame.lootFilterDD = lootDropdown
	end

	local contentArea = Widget.New(frame, 'Frame', nil, { bg = Colors.bg.medium, border = Colors.border.dark }).frame
	contentArea:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-104))
	contentArea:SetPoint('BOTTOMRIGHT', Pixel.Scale(-12), Pixel.Scale(62))

	frame.buyPanel,  frame.buyScroll,  frame.buyChild  = CreatePanel(contentArea)
	frame.bbPanel,   frame.bbScroll,   frame.bbChild   = CreatePanel(contentArea)
	frame.bulkPanel, frame.bulkScroll, frame.bulkChild = CreatePanel(contentArea)
	frame.bbPanel:Hide()
	frame.bulkPanel:Hide()

	frame.buyAllBtn = Controls.Button(frame, 'Buy All', 80, function()
		local queue = {}
		for _, row in ipairs(bulkRows) do
			if row:IsShown() and row.merchantIdx and row.qty > 0 and row.canAfford then
				if row.extendedCost then
					for _ = 1, row.qty do queue[#queue + 1] = { idx = row.merchantIdx, qty = 1 } end
				else
					queue[#queue + 1] = { idx = row.merchantIdx, qty = row.qty }
				end
			end
		end
		local queueIndex = 0
		local function BuyNext()
			if not merchantFrame or not merchantFrame:IsShown() then return end
			queueIndex = queueIndex + 1
			if queue[queueIndex] then
				BuyMerchantItem(queue[queueIndex].idx, queue[queueIndex].qty)
				C_Timer.After(0.2, BuyNext)
			end
		end
		BuyNext()
	end)
	frame.buyAllBtn:SetPoint('BOTTOMRIGHT', Pixel.Scale(-12), Pixel.Scale(14))
	frame.buyAllBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.buyAllBtn:Hide()

	frame.buybackAllBtn = Controls.Button(frame, 'Buyback All', 100, function()
		local previousCount
		local function BuybackNext()
			if not merchantFrame or not merchantFrame:IsShown() then return end
			local numItems = GetNumBuybackItems()
			if numItems == 0 or not GetBuybackItemInfo(numItems) then return end
			if previousCount and numItems >= previousCount then return end
			previousCount = numItems
			BuybackItem(numItems)
			C_Timer.After(0.2, BuybackNext)
		end
		BuybackNext()
	end)
	frame.buybackAllBtn:SetPoint('BOTTOMRIGHT', Pixel.Scale(-12), Pixel.Scale(14))
	frame.buybackAllBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.buybackAllBtn:Hide()

	frame.emptyText = contentArea:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(frame.emptyText, 13, FONT, '')
	frame.emptyText:SetPoint('CENTER', 0, Pixel.Scale(20))
	frame.emptyText:SetTextColor(0.45, 0.45, 0.45, 1)
	frame.emptyText:Hide()

	frame.repairAll = Controls.Button(frame, 'Repair All', 80, function() RepairAllItems(false) end)
	frame.repairAll:SetPoint('BOTTOMRIGHT', Pixel.Scale(-12), Pixel.Scale(14))
	frame.repairAll:SetFrameLevel(frame:GetFrameLevel() + 10)

	frame.guildRepair = Controls.Button(frame, 'Guild Repair', 90, function() RepairAllItems(true) end)
	frame.guildRepair:SetPoint('RIGHT', frame.repairAll, 'LEFT', Pixel.Scale(-6), 0)
	frame.guildRepair:SetFrameLevel(frame:GetFrameLevel() + 10)

	frame.sellJunk = Controls.Button(frame, 'Sell Junk', 80, SellJunk)
	frame.sellJunk:SetFrameLevel(frame:GetFrameLevel() + 10)

	frame.moneyText = frame:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(frame.moneyText, 11, FONT, '')
	frame.moneyText:SetPoint('BOTTOMLEFT', Pixel.Scale(16), Pixel.Scale(20))
	frame.moneyText:SetTextColor(0.8, 0.8, 0.8, 1)

	merchantFrame = frame
end

local function UpdateRepairState(targetFrame)
	local canRepair = CanMerchantRepair()
	local showRepair = canRepair and activeTab == TAB_BUY
	local showGuild = showRepair and IsInGuild() and CanGuildBankRepair and CanGuildBankRepair()
	targetFrame.repairAll:SetShown(showRepair)
	targetFrame.guildRepair:SetShown(showGuild)

	local showJunk = GetJunkValue() > 0
	targetFrame.sellJunk:SetShown(showJunk)
	if not showJunk then return end

	targetFrame.sellJunk:ClearAllPoints()
	if showGuild then
		targetFrame.sellJunk:SetPoint('RIGHT', targetFrame.guildRepair, 'LEFT', Pixel.Scale(-6), 0)
	elseif showRepair then
		targetFrame.sellJunk:SetPoint('RIGHT', targetFrame.repairAll, 'LEFT', Pixel.Scale(-6), 0)
	elseif activeTab == TAB_BUYBACK then
		targetFrame.sellJunk:SetPoint('RIGHT', targetFrame.buybackAllBtn, 'LEFT', Pixel.Scale(-6), 0)
	elseif activeTab == TAB_BULK then
		targetFrame.sellJunk:SetPoint('RIGHT', targetFrame.buyAllBtn, 'LEFT', Pixel.Scale(-6), 0)
	else
		targetFrame.sellJunk:SetPoint('BOTTOMRIGHT', Pixel.Scale(-12), Pixel.Scale(14))
	end
end

RefreshContent = function()
	if not merchantFrame or not merchantFrame:IsShown() then return end

	merchantFrame.titleText:SetText(UnitName('npc') or 'Merchant')
	merchantFrame.moneyText:SetText(GetCoinTextureString(GetMoney()))

	merchantFrame.buyPanel:SetShown(activeTab == TAB_BUY)
	merchantFrame.bbPanel:SetShown(activeTab == TAB_BUYBACK)
	merchantFrame.bulkPanel:SetShown(activeTab == TAB_BULK)
	merchantFrame.buyAllBtn:SetShown(activeTab == TAB_BULK)
	merchantFrame.buybackAllBtn:SetShown(activeTab == TAB_BUYBACK)

	UpdateRepairState(merchantFrame)
	if activeTab ~= TAB_BUYBACK then CollectVisibleCurrencies() end
	UpdateCurrencyBar(merchantFrame)

	local itemCount = 0
	local resetScroll = listReset
	listReset = false
	local function RestoreScroll(scroll)
		if resetScroll then
			scroll:SetVerticalScroll(0)
			return
		end
		local previous = scroll:GetVerticalScroll()
		C_Timer.After(0, function()
			local maxScroll = math.max(0, scroll:GetScrollChild():GetHeight() - scroll:GetHeight())
			scroll:SetVerticalScroll(math.min(previous, maxScroll))
		end)
	end

	if activeTab == TAB_BUY then
		ScanBuyItems()
		PopulateBuyRows(buyItems, buyRows, merchantFrame.buyChild, false)
		itemCount = #buyItems
		RestoreScroll(merchantFrame.buyScroll)
	elseif activeTab == TAB_BUYBACK then
		ScanBuybackItems()
		PopulateBuybackRows(buybackItems, buybackRows, merchantFrame.bbChild)
		itemCount = #buybackItems
		RestoreScroll(merchantFrame.bbScroll)
	else
		ScanBuyItems()
		PopulateBuyRows(buyItems, bulkRows, merchantFrame.bulkChild, true)
		itemCount = #buyItems
		RestoreScroll(merchantFrame.bulkScroll)
	end

	merchantFrame.countText:SetText(itemCount .. ' items')
	merchantFrame.emptyText:SetShown(itemCount == 0)
	if itemCount == 0 then
		if activeTab == TAB_BUYBACK then
			merchantFrame.emptyText:SetText('No buyback items.')
		elseif searchText ~= '' or (activeTypeFilter and activeTypeFilter.classID) then
			merchantFrame.emptyText:SetText('No matching items.')
		else
			merchantFrame.emptyText:SetText('This vendor has no items.')
		end
	end
end

local function ClearRowData()
	for _, pool in ipairs({ buyRows, bulkRows }) do
		for _, row in ipairs(pool) do
			row.merchantIdx = nil
			if row.costIcons then
				for _, costIcon in ipairs(row.costIcons) do costIcon.link = nil end
			end
		end
	end
	for _, row in ipairs(buybackRows) do row.buybackIdx = nil end
end

local function OnMerchantEvent(event)
	if event == 'MERCHANT_SHOW' then
		if not Skin.IsSkinEnabled('merchant') then
			if MerchantFrame then Skin.RestoreBlizzardFrame(MerchantFrame) end
			if merchantFrame then merchantFrame:Hide() end
			return
		end
		BuildFrame()
		if MerchantFrame then
			Skin.SuppressBlizzardFrame(MerchantFrame)
			if not MerchantFrame._buiReassertHooked then
				MerchantFrame._buiReassertHooked = true
				MerchantFrame:HookScript('OnShow', function(self)
					if merchantFrame and merchantFrame:IsShown() and Skin.IsSkinEnabled('merchant') then Skin.SuppressBlizzardFrame(self) end
				end)
			end
		end
		activeTab = TAB_BUY
		listReset = true
		merchantFrame.tabBar:SetSelected(TAB_BUY)
		searchText = ''
		merchantFrame.searchBox.editBox:SetText('')
		activeTypeFilter = nil
		merchantFrame:Show()
		if merchantFrame.lootFilterDD then
			merchantFrame.lootFilterDD.label:SetText('All')
			SetMerchantFilter(LE_LOOT_FILTER_ALL)
		end
		BUI.Events:Register('BAG_UPDATE', 'Skinning.Merchant.Live', OnMerchantEvent)
		BUI.Events:Register('PLAYER_MONEY', 'Skinning.Merchant.Live', OnMerchantEvent)
		BUI.Events:Register('CURRENCY_DISPLAY_UPDATE', 'Skinning.Merchant.Live', OnMerchantEvent)
		C_Timer.After(0, RefreshContent)
	elseif event == 'MERCHANT_CLOSED' then
		sellJunkActive = false
		BUI.Events:UnregisterAll('Skinning.Merchant.Live')
		if merchantFrame then merchantFrame:Hide() end
		if MerchantFrame then Skin.RestoreBlizzardFrame(MerchantFrame) end
		wipe(buyItems)
		wipe(buybackItems)
		wipe(visibleCurrencies)
		wipe(currencySeen)
		ClearRowData()
	elseif merchantFrame and merchantFrame:IsShown() and not merchantFrame.pendingRefresh then
		merchantFrame.pendingRefresh = true
		C_Timer.After(0.1, function()
			merchantFrame.pendingRefresh = false
			RefreshContent()
		end)
	end
end

BUI.Events:Register('MERCHANT_SHOW', 'Skinning.Merchant', OnMerchantEvent)
BUI.Events:Register('MERCHANT_CLOSED', 'Skinning.Merchant', OnMerchantEvent)
BUI.Events:Register('MERCHANT_UPDATE', 'Skinning.Merchant', OnMerchantEvent)

Skin.OnToggle('merchant', function(enabled)
	if not enabled then
		if merchantFrame and merchantFrame:IsShown() then merchantFrame:Hide() end
		BUI.Events:UnregisterAll('Skinning.Merchant.Live')
		if MerchantFrame then
			Skin.RestoreBlizzardFrame(MerchantFrame)
			Skin.ReleasePanelSlot(MerchantFrame)
		end
	elseif MerchantFrame and MerchantFrame:IsShown() then
		OnMerchantEvent('MERCHANT_SHOW')
	end
end)

Skin.RegisterSkin('merchant', {
	name = 'Merchant',
	description = 'Replaces the default vendor window with a dark, searchable frame featuring bulk buy and type filters.',
	icon = 'Interface\\Icons\\INV_Misc_Coin_01',
})
