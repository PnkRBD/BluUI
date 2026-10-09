local _, BUI = ...

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Widget = BUILib.Widget
local Controls = BUILib.Controls
local FONT = BUILib.Font or STANDARD_TEXT_FONT
local Skin = BUI.Skinning
local Pixel = BUI.Pixel
local After = BUI.Profiler.After

local TAB_BUY, TAB_BUYBACK, TAB_BULK = 1, 2, 3
local ROW_HEIGHT = 40
local ROW_PAD = 2
local FRAME_WIDTH = 480
local FRAME_HEIGHT = 560
local SCROLL_PAD = 8
local MAX_QTY = 200
local ICON_SIZE = 32
local COST_ICON_SIZE = 14
local BUY_STEP = 0.2
local MONEY_KEY = 0
local NO_LIMIT = math.huge
local SHORT_COLOR = { 0.9, 0.3, 0.3 }
local COST_COLOR = { 0.8, 0.8, 0.8 }
local PRICE_COLOR = { 0.65, 0.65, 0.65 }
local BLOCKED_NAME = { 0.55, 0.55, 0.6 }
local BLOCKED_EDGE = { 0.5, 0.15, 0.15 }
local BLOCKED_CONTROLS_ALPHA = 0.4
local BLOCKED_TEXT_ALPHA = 0.6

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
local listReset = true

local buyItems = {}
local buybackItems = {}
local buyRows = {}
local buybackRows = {}
local bulkRows = {}
local visibleCurrencies = {}

local RefreshContent

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

local function Owned(cost)
	if cost.currencyID then
		local info = C_CurrencyInfo.GetCurrencyInfo(cost.currencyID)
		return info and info.quantity or 0
	end
	if cost.itemID then return C_Item.GetItemCount(cost.itemID, false, false, true) end
	return GetMoney()
end

local function MaxUnits(entry, budget)
	local units = entry.stock
	for costIndex = 1, entry.costCount do
		local cost = entry.costs[costIndex]
		local have = budget[cost.key]
		if have == nil then
			have = Owned(cost)
			budget[cost.key] = have
		end
		units = math.min(units, math.floor(have / cost.amount))
	end
	return math.max(0, units)
end

local function Spend(entry, budget, units)
	for costIndex = 1, entry.costCount do
		local cost = entry.costs[costIndex]
		budget[cost.key] = budget[cost.key] - cost.amount * units
	end
end

local function AddCost(entry, key, amount, currencyID, itemID, texture, link)
	entry.costCount = entry.costCount + 1
	local cost = entry.costs[entry.costCount] or {}
	entry.costs[entry.costCount] = cost
	cost.key, cost.amount, cost.currencyID, cost.itemID, cost.texture, cost.link = key, amount, currencyID, itemID, texture, link
end

local function ReadCosts(entry, info)
	entry.costs = entry.costs or {}
	entry.costCount = 0
	local stack = math.max(1, info.stackCount or 1)
	if info.price and info.price > 0 then AddCost(entry, MONEY_KEY, info.hasExtendedCost and info.price or info.price / stack) end
	local available = info.numAvailable or -1
	entry.stock = available < 0 and NO_LIMIT or info.hasExtendedCost and available or available * stack
	if not info.hasExtendedCost then return end
	for costIndex = 1, GetMerchantItemCostInfo(entry.idx) do
		local texture, amount, link = GetMerchantItemCostItem(entry.idx, costIndex)
		local currencyID = link and tonumber(link:match('currency:(%d+)'))
		local itemID = link and not currencyID and tonumber(link:match('item:(%d+)'))
		if amount and amount > 0 and (currencyID or itemID) then
			AddCost(entry, currencyID or -itemID, amount, currencyID, itemID, texture, link)
		end
	end
end

local function Unmet(color)
	return color and color.r > 0.9 and color.g < 0.3 and color.b < 0.3
end

local function RequirementText(merchantIndex)
	local data = C_TooltipInfo.GetMerchantItem(merchantIndex)
	local lines = data and data.lines
	for lineIndex = 2, lines and #lines or 0 do
		local line = lines[lineIndex]
		if line.leftText and line.leftText ~= '' and Unmet(line.leftColor) then return line.leftText end
	end
end

local function SellJunk()
	C_MerchantFrame.SellAllJunkItems()
end

local scanBudget = {}

local function ScanBuyItems()
	local count = 0
	wipe(scanBudget)
	for merchantIndex = 1, GetMerchantNumItems() do
		local info = C_MerchantFrame.GetItemInfo(merchantIndex)
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
				entry.numAvailable = info.numAvailable or -1
				entry.soldOut = info.numAvailable == 0
				entry.locked = info.isPurchasable == false
				entry.isUsable = info.isUsable ~= false
				entry.extendedCost = info.hasExtendedCost
				ReadCosts(entry, info)
				entry.limit = entry.locked and 0 or MaxUnits(entry, scanBudget)
				entry.canAfford = entry.limit > 0
				entry.qualityR, entry.qualityG, entry.qualityB = Skin.QualityColor(GetMerchantItemID(merchantIndex))
			end
		end
	end
	for itemIndex = count + 1, #buyItems do buyItems[itemIndex] = nil end
end

local function ScanBuybackItems()
	local count = 0
	for buybackIndex = 1, GetNumBuybackItems() do
		local name, texture, price = GetBuybackItemInfo(buybackIndex)
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
			entry.qualityR, entry.qualityG, entry.qualityB = Skin.QualityColor(itemID)
		end
	end
	for itemIndex = count + 1, #buybackItems do buybackItems[itemIndex] = nil end
end

local function CollectVisibleCurrencies()
	local ids = C_MerchantFrame.GetMerchantCurrencies()
	table.sort(ids)
	for index, currencyID in ipairs(ids) do
		local entry = visibleCurrencies[index] or {}
		visibleCurrencies[index] = entry
		entry.id = currencyID
		entry.texture = C_CurrencyInfo.GetCurrencyInfo(currencyID).iconFileID
		entry.link = C_CurrencyInfo.GetCurrencyLink(currencyID)
	end
	for index = #ids + 1, #visibleCurrencies do visibleCurrencies[index] = nil end
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

	frame:SetScript('OnEnter', BUI.Profiler.Script('Skin.Merchant frame OnEnter', function(self)
		if self.link then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetHyperlink(self.link)
			GameTooltip:Show()
		end
	end))
	frame:SetScript('OnLeave', BUI.Profiler.Script('Skin.Merchant frame OnLeave', function() GameTooltip:Hide() end))
	return frame
end

local function Short(cost)
	local have = scanBudget[cost.key]
	if have == nil then have = Owned(cost) end
	return have < cost.amount
end

local function PaintText(fontString, color)
	fontString:SetTextColor(color[1], color[2], color[3], 1)
end

local function PopulateCostIcons(row, entry)
	row.costIcons = row.costIcons or {}
	local shown, previous = 0, nil
	local alpha = entry.canAfford and 1 or BLOCKED_TEXT_ALPHA
	for costIndex = 1, entry.costCount do
		local cost = entry.costs[costIndex]
		if cost.texture then
			shown = shown + 1
			local costIcon = row.costIcons[shown]
			if not costIcon then
				costIcon = CreateIconLabel(row)
				row.costIcons[shown] = costIcon
			end
			costIcon.icon:SetTexture(cost.texture)
			costIcon.qtyText:SetText(cost.amount)
			PaintText(costIcon.qtyText, Short(cost) and SHORT_COLOR or COST_COLOR)
			costIcon.link = cost.link
			costIcon:SetAlpha(alpha)
			costIcon:ClearAllPoints()
			if previous then
				costIcon:SetPoint('LEFT', previous, 'RIGHT', Pixel.Scale(6), 0)
			elseif row.priceText:GetText() ~= '' then
				costIcon:SetPoint('LEFT', row.priceText, 'RIGHT', Pixel.Scale(6), 0)
			else
				costIcon:SetPoint('LEFT', row.iconBorder, 'RIGHT', Pixel.Scale(8), Pixel.Scale(-8))
			end
			costIcon:Show()
			previous = costIcon
		end
	end
	for costIndex = shown + 1, #row.costIcons do row.costIcons[costIndex]:Hide() end
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

local function PaintRowState(row, info)
	local blocked = not info.canAfford
	local red, green, blue = info.qualityR, info.qualityG, info.qualityB
	if blocked then
		PaintText(row.nameText, BLOCKED_NAME)
		row.iconBorder:SetBackdropBorderColor(BLOCKED_EDGE[1], BLOCKED_EDGE[2], BLOCKED_EDGE[3], 1)
	elseif not info.isUsable then
		row.nameText:SetTextColor(red * 0.7, green * 0.7, blue * 0.7, 1)
		row.iconBorder:SetBackdropBorderColor(red, green, blue, 0.5)
	else
		row.nameText:SetTextColor(red, green, blue, 1)
		row.iconBorder:SetBackdropBorderColor(red, green, blue, 1)
	end
	row.icon:SetDesaturated(blocked)
	PaintText(row.priceText, info.price > 0 and GetMoney() < info.price and SHORT_COLOR or PRICE_COLOR)
	row.priceText:SetAlpha(blocked and BLOCKED_TEXT_ALPHA or 1)
	local controlsAlpha = blocked and BLOCKED_CONTROLS_ALPHA or 1
	row.stepper:SetAlpha(controlsAlpha)
	row.buyButton:SetAlpha(controlsAlpha)
end

local purchases = {}
local purchasing = false

local function PurchaseNext()
	local step = table.remove(purchases, 1)
	if not step or not merchantFrame or not merchantFrame:IsShown() then
		wipe(purchases)
		purchasing = false
		return
	end
	BuyMerchantItem(step.idx, step.qty)
	After('Skin.Merchant buy step', BUY_STEP, PurchaseNext)
end

local function Enqueue(entry, units)
	local chunk = entry.extendedCost and 1 or math.max(1, GetMerchantItemMaxStack(entry.idx))
	while units > 0 do
		local quantity = math.min(units, chunk)
		purchases[#purchases + 1] = { idx = entry.idx, qty = quantity }
		units = units - quantity
	end
end

local function StartPurchases()
	if purchasing or not purchases[1] then return end
	purchasing = true
	PurchaseNext()
end

local function Warn(text)
	UIErrorsFrame:AddMessage(text, RED_FONT_COLOR:GetRGB())
end

local function LimitMessage(entry)
	if entry.locked then
		Warn(RequirementText(entry.idx) or 'This item is locked.')
	elseif entry.soldOut then
		Warn('Sold out.')
	elseif entry.limit > MAX_QTY then
		Warn(('Up to %d at a time.'):format(MAX_QTY))
	elseif entry.limit < 1 then
		Warn("You can't afford this.")
	elseif entry.limit == entry.stock then
		Warn(('Only %d left.'):format(entry.limit))
	else
		Warn(('You can only afford %d.'):format(entry.limit))
	end
end

local function CreateBuyRow(parent)
	local row = Skin.CreateListRow(parent, ROW_HEIGHT, ICON_SIZE)
	row.nameText:SetPoint('RIGHT', row, 'RIGHT', Pixel.Scale(-170), 0)

	row.stockText = row:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(row.stockText, 9, FONT, '')
	row.stockText:SetPoint('LEFT', row.nameText, 'RIGHT', Pixel.Scale(4), 0)
	row.stockText:SetTextColor(0.5, 0.5, 0.5, 1)

	local buyButton = Skin.SmallButton(row, 48, 22, 'Buy')
	buyButton:SetPoint('RIGHT', row, 'RIGHT', Pixel.Scale(-8), 0)
	row.buyButton = buyButton

	row.stepper = Controls.Stepper(row, nil, 0, 0, MAX_QTY, 1, function(value) row.qty = value end, 75, 22)
	row.stepper:ClearAllPoints()
	row.stepper:SetPoint('RIGHT', buyButton, 'LEFT', Pixel.Scale(-6), 0)
	local stepperFrame = Widget.Unwrap(row.stepper)

	row.qty = 0
	row.onLimit = function() if row.entry then LimitMessage(row.entry) end end

	buyButton:SetScript('OnClick', BUI.Profiler.Script('Skin.Merchant buyButton OnClick', function()
		local entry = row.entry
		if not entry then return end
		if stepperFrame.valueBox:HasFocus() then stepperFrame.valueBox:ClearFocus() end
		entry.limit = entry.locked and 0 or MaxUnits(entry, {})
		local wanted = stepperFrame:GetValue()
		if wanted < 1 then
			if entry.limit < 1 then LimitMessage(entry) end
			return
		end
		local units = math.min(wanted, entry.limit)
		if units < wanted then LimitMessage(entry) end
		if units < 1 then return end
		Enqueue(entry, units)
		StartPurchases()
	end))

	row:HookScript('OnClick', BUI.Profiler.Wrap('Skin.Merchant row OnClick', function(self)
		if not self.merchantIdx then return end
		if IsModifiedClick('DRESSUP') then
			local link = GetMerchantItemLink(self.merchantIdx)
			if link then DressUpLink(link) end
		elseif IsModifiedClick('CHATLINK') then
			ChatEdit_InsertLink(GetMerchantItemLink(self.merchantIdx))
		end
	end))

	row:HookScript('OnEnter', BUI.Profiler.Wrap('Skin.Merchant row OnEnter', function(self)
		if self.merchantIdx then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetMerchantItem(self.merchantIdx)
			GameTooltip:Show()
		end
	end))

	return row
end

local function CreateBuybackRow(parent)
	local row = Skin.CreateListRow(parent, ROW_HEIGHT, ICON_SIZE)
	row.nameText:SetPoint('RIGHT', row, 'RIGHT', Pixel.Scale(-80), 0)

	local buybackButton = Skin.SmallButton(row, 62, 22, 'Buyback')
	buybackButton:SetPoint('RIGHT', row, 'RIGHT', Pixel.Scale(-8), 0)
	buybackButton:SetScript('OnClick', BUI.Profiler.Script('Skin.Merchant buybackButton OnClick', function()
		if row.buybackIdx then BuybackItem(row.buybackIdx) end
	end))

	row:HookScript('OnClick', BUI.Profiler.Wrap('Skin.Merchant row OnClick 2', function(self)
		if not self.buybackIdx then return end
		local link = GetBuybackItemLink(self.buybackIdx)
		if not link then return end
		if IsModifiedClick('DRESSUP') then
			DressUpLink(link)
		elseif IsModifiedClick('CHATLINK') then
			ChatEdit_InsertLink(link)
		end
	end))

	row:HookScript('OnEnter', BUI.Profiler.Wrap('Skin.Merchant row OnEnter 2', function(self)
		if self.buybackIdx then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetBuybackItem(self.buybackIdx)
			GameTooltip:Show()
		end
	end))

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
		row.entry = info
		row.stepper:SetMax(math.max(isBulk and 0 or 1, math.min(info.limit, MAX_QTY)), row.onLimit)
		row.nameText:SetText(info.name)
		PaintRowState(row, info)

		local hasStock = info.numAvailable and info.numAvailable > 0
		if hasStock then row.stockText:SetText('x' .. info.numAvailable) end
		row.stockText:SetShown(hasStock)

		local goldString = info.price > 0 and GetCoinTextureString(info.price) or nil
		row.priceText:SetText(goldString or (info.extendedCost and '' or 'Free'))
		PopulateCostIcons(row, info)
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
		if name then items[#items + 1] = { label = name, filterIndex = LE_LOOT_FILTER_SPEC1 + specIndex - 1 } end
	end
	if numSpecs > 0 then
		items[#items + 1] = { label = ALL_SPECS, filterIndex = LE_LOOT_FILTER_CLASS }
	end
	items[#items + 1] = { label = ITEM_BIND_ON_EQUIP, filterIndex = LE_LOOT_FILTER_BOE }
	items[#items + 1] = { label = ALL, filterIndex = LE_LOOT_FILTER_ALL }
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

	local frame = Skin.CreateWindow({
		width = FRAME_WIDTH, height = FRAME_HEIGHT, title = 'Merchant', onClose = CloseMerchant,
		dbKey = 'merchant', x = Pixel.Scale(-100), follow = 'MerchantFrame', contentTop = 104, contentBottom = 62,
	})
	local titleBar = frame.titleBar

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
	if #lootFilterItems > 1 then
		local lootDropdown = Skin.CreateDropdown(frame, lootFilterItems, function(item)
			SetMerchantFilter(item.filterIndex)
			listReset = true
			RefreshContent()
		end, 140)
		lootDropdown:SetPoint('LEFT', filterDropdown, 'RIGHT', Pixel.Scale(6), 0)
		lootDropdown.label:SetText(ALL)
		frame.lootFilterDD = lootDropdown
	end

	local contentArea = frame.content

	frame.buyPanel,  frame.buyScroll,  frame.buyChild  = CreatePanel(contentArea)
	frame.bbPanel,   frame.bbScroll,   frame.bbChild   = CreatePanel(contentArea)
	frame.bulkPanel, frame.bulkScroll, frame.bulkChild = CreatePanel(contentArea)
	frame.bbPanel:Hide()
	frame.bulkPanel:Hide()

	frame.buyAllBtn = Controls.Button(frame, 'Buy All', 80, function()
		local budget, short = {}, false
		for _, row in ipairs(bulkRows) do
			local entry = row:IsShown() and row.qty > 0 and row.entry
			if entry and not entry.locked then
				local units = math.min(row.qty, MaxUnits(entry, budget))
				if units < row.qty then short = true end
				if units > 0 then
					Spend(entry, budget, units)
					Enqueue(entry, units)
				end
			end
		end
		if short then Warn('Not enough for all of it, buying what you can afford.') end
		StartPurchases()
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
			After('Skin.Merchant buyback step', BUY_STEP, BuybackNext)
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
	local showRepair = CanMerchantRepair() and activeTab == TAB_BUY
	local showGuild = showRepair and IsInGuild() and CanGuildBankRepair()
	targetFrame.repairAll:SetShown(showRepair)
	targetFrame.guildRepair:SetShown(showGuild)
	if showRepair then
		local cost, needsRepair = GetRepairAllCost()
		local repairAll = Widget.Unwrap(targetFrame.repairAll)
		repairAll:SetText(needsRepair and ('Repair All  ' .. GetCoinTextureString(cost)) or 'Repair All')
		repairAll:SetEnabled(needsRepair and GetMoney() >= cost)
		if showGuild then
			local allowance = GetGuildBankWithdrawMoney()
			Widget.Unwrap(targetFrame.guildRepair):SetEnabled(needsRepair and (allowance < 0 or allowance >= cost))
		end
	end

	local showJunk = C_MerchantFrame.IsSellAllJunkEnabled() and C_MerchantFrame.GetNumJunkItems() > 0
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
		After('Skin.Merchant scroll restore', 0, function()
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
			row.merchantIdx, row.entry = nil, nil
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
				MerchantFrame:HookScript('OnShow', BUI.Profiler.Wrap('Skin.Merchant blizzard suppress', function(self)
					if merchantFrame and merchantFrame:IsShown() and Skin.IsSkinEnabled('merchant') then Skin.SuppressBlizzardFrame(self) end
				end))
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
			merchantFrame.lootFilterDD.label:SetText(ALL)
			SetMerchantFilter(LE_LOOT_FILTER_ALL)
		end
		BUI.Events:Register('BAG_UPDATE_DELAYED', 'Skinning.Merchant.Live', OnMerchantEvent)
		BUI.Events:Register('PLAYER_MONEY', 'Skinning.Merchant.Live', OnMerchantEvent)
		BUI.Events:Register('CURRENCY_DISPLAY_UPDATE', 'Skinning.Merchant.Live', OnMerchantEvent)
		After('Skin.Merchant page reskin', 0, RefreshContent)
	elseif event == 'MERCHANT_CLOSED' then
		BUI.Events:UnregisterAll('Skinning.Merchant.Live')
		if merchantFrame then merchantFrame:Hide() end
		if MerchantFrame then Skin.RestoreBlizzardFrame(MerchantFrame) end
		wipe(buyItems)
		wipe(buybackItems)
		wipe(visibleCurrencies)
		ClearRowData()
	elseif merchantFrame and merchantFrame:IsShown() and not merchantFrame.pendingRefresh then
		merchantFrame.pendingRefresh = true
		After('Skin.Merchant live refresh', 0.1, function()
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
