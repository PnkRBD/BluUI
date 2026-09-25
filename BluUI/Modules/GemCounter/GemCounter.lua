local _, BUI = ...
local PoolGet, PoolHideFrom = BUI.Tools.PoolGet, BUI.Tools.PoolHideFrom
local Pixel = BUI.Pixel

local BUILib = BluUI.BUILibClient
local Widget   = BUILib.Widget
local Controls = BUILib.Controls
local Colors   = BUILib.Colors
local Modals   = BUILib.Modals
local FONT     = BUILib.Font

BUI.GemCounter = {}

local GEM_CLASS      = Enum.ItemClass.Gem
local PANEL_WIDTH    = 600
local COLUMN_WIDTH   = 278
local COLUMN_GAP     = 12
local HEADER_HEIGHT  = 30
local SOCKET_HEIGHT  = 26
local GEM_HEIGHT     = 34
local INDENT         = 30
local ITEM_GAP       = 4
local BOTTOM_HEIGHT  = 58
local BOTTOM_OFFSET  = 76
local BAGS           = { 0, 1, 2, 3, 4, 5 }
local MAX_GEM_FIELDS = 4
local QUALITY_HEADER_HEIGHT = 22
local STRIP_ICON_GAP = 28
local STRIP_MAX_ICONS = 14
local BLANK          = BUI.C.FALLBACK_TEXTURE
local ICON_BACKDROP  = { bgFile = BLANK, edgeFile = BLANK, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

local SLOT_NAMES = {
	[1]  = 'Head',       [2]  = 'Neck',      [3]  = 'Shoulder',  [5]  = 'Chest',
	[6]  = 'Waist',      [7]  = 'Legs',      [8]  = 'Feet',      [9]  = 'Wrist',
	[10] = 'Hands',      [11] = 'Ring 1',    [12] = 'Ring 2',
	[13] = 'Trinket 1',  [14] = 'Trinket 2', [15] = 'Back',
	[16] = 'Main Hand',  [17] = 'Off Hand',
}

local panel, slide
local searchText, qualityFilter = '', 0

local equippedData = {}
local bagGemData   = {}
local bagGemByID   = {}
local bagSlotIndex = {}
local gemCounts    = {}
local emptySockets, totalSocketed, totalBagGems = 0, 0, 0

local pendingByKey     = {}
local selectedBagGemID = nil

local dragGhost, dragGemID
local applying, applyStep, applyQueue, applyIndex = false, nil, nil, 0

local headerPool, socketPool, gemPool, qualityPool = {}, {}, {}, {}

local Redraw, RefreshContent

local function QualityColor(quality)
	if quality and quality > 1 then
		local color = ITEM_QUALITY_COLORS[quality]
		return color.r, color.g, color.b
	end
	return 0.9, 0.9, 0.9
end

local function SetQualityAtlas(pipTexture, itemID)
	local info = BUI.Lookup.CraftedQualityInfo(itemID)
	if info then
		pipTexture:SetAtlas(info.iconSmall)
		pipTexture:Show()
	else
		pipTexture:Hide()
	end
end

local function SetIconTexture(iconTexture, texture)
	BUI.Skinning.CropIcon(iconTexture)
	iconTexture:SetTexture(texture)
end

local function NameFromLink(link)
	return link:match('%[(.-)%]')
end

local function IdFromLink(link)
	return tonumber(link:match('item:(%d+)'))
end

local function MakeIconFrame(parent, frameSize, iconSize)
	local iconFrame = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	iconFrame:SetSize(Pixel.Scale(frameSize), Pixel.Scale(frameSize))
	iconFrame:SetBackdrop(ICON_BACKDROP)
	iconFrame:SetBackdropColor(0, 0, 0, 1)
	local icon = iconFrame:CreateTexture(nil, 'ARTWORK')
	icon:SetSize(Pixel.Scale(iconSize), Pixel.Scale(iconSize))
	icon:SetPoint('CENTER')
	BUI.Skinning.CropIcon(icon)
	iconFrame.icon = icon
	return iconFrame
end

local function MakeRowButton(parent, height, backgroundColor, border)
	local row = CreateFrame('Button', nil, parent, 'BackdropTemplate')
	row:SetHeight(height)
	row:SetBackdrop(Widget.BACKDROP)
	row:SetBackdropColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
	row:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
	row:EnableMouse(true)
	return row
end

local function MakeLabel(parent, size, flags)
	local fontString = parent:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(fontString, size, FONT, flags or '')
	return fontString
end

local function PendingKey(slotID, index) return slotID .. ':' .. index end

local function ClearAllPending()
	wipe(pendingByKey)
	selectedBagGemID = nil
end

local function PendingCount()
	local count = 0
	for _ in pairs(pendingByKey) do count = count + 1 end
	return count
end

local function PendingCountFor(gemID)
	local count = 0
	for _, pending in pairs(pendingByKey) do
		if pending.gem.itemID == gemID then count = count + 1 end
	end
	return count
end

local function GemAvailable(itemID)
	local gem = bagGemByID[itemID]
	return gem and gem.count - PendingCountFor(itemID) or 0
end

local function AssignGem(row, itemID)
	if GemAvailable(itemID) > 0 then
		pendingByKey[row._pendingKey] = { slotID = row._slotID, socketIdx = row._socketIdx, gem = bagGemByID[itemID] }
	end
end

local function FollowCursor(ghost)
	local cursorX, cursorY = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	ghost:ClearAllPoints()
	ghost:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', cursorX / scale, cursorY / scale)
end

local function StartGemDrag(itemID, icon)
	if not dragGhost then
		dragGhost = CreateFrame('Frame', nil, UIParent)
		dragGhost:SetSize(Pixel.Scale(28), Pixel.Scale(28))
		dragGhost:SetFrameStrata('TOOLTIP')
		dragGhost:SetFrameLevel(999)
		local ghostTexture = dragGhost:CreateTexture(nil, 'ARTWORK')
		ghostTexture:SetAllPoints()
		BUI.Skinning.CropIcon(ghostTexture)
		dragGhost.tex = ghostTexture
		dragGhost:SetScript('OnUpdate', FollowCursor)
	end
	dragGhost.tex:SetTexture(icon)
	dragGemID = itemID
	selectedBagGemID = itemID
	dragGhost:Show()
end

local function StopGemDrag()
	if not dragGemID then return end
	dragGhost:Hide()
	for _, socketRow in ipairs(socketPool) do
		if socketRow:IsShown() and socketRow._empty and socketRow:IsMouseOver() then
			AssignGem(socketRow, dragGemID)
			break
		end
	end
	dragGemID = nil
	selectedBagGemID = nil
	Redraw()
end

local function SortSockets(first, second)
	return first.empty and not second.empty
end

local function SortItems(first, second)
	if first.hasEmpty ~= second.hasEmpty then return first.hasEmpty end
	return first.slotID < second.slotID
end

local function SortGems(first, second)
	if first.quality ~= second.quality then return first.quality > second.quality end
	return first.name < second.name
end

local function ScanEquipped()
	wipe(equippedData)
	for slot, slotName in pairs(SLOT_NAMES) do
		local link = GetInventoryItemLink('player', slot)
		if link then
			local sockets, total, hasEmpty = {}, C_Item.GetItemNumSockets(link), false
			for index = 1, MAX_GEM_FIELDS do
				local gemName, gemLink = C_Item.GetItemGem(link, index)
				if gemLink then
					local gemID = IdFromLink(gemLink)
					sockets[index] = {
						index = index, key = PendingKey(slot, index), gemItemID = gemID,
						gemName = gemName, searchName = gemName and gemName:lower(),
						gemIcon = C_Item.GetItemIconByID(gemID), gemQuality = C_Item.GetItemQualityByID(gemID),
					}
					if index > total then total = index end
				end
			end
			for index = 1, total do
				if not sockets[index] then
					sockets[index] = { empty = true, index = index, key = PendingKey(slot, index) }
					hasEmpty = true
				end
			end
			if total > 0 then
				table.sort(sockets, SortSockets)
				local itemName = NameFromLink(link)
				equippedData[#equippedData + 1] = {
					slotID = slot, slotName = slotName, itemName = itemName, searchName = itemName:lower(),
					itemIcon = GetInventoryItemTexture('player', slot), quality = GetInventoryItemQuality('player', slot),
					sockets = sockets, hasEmpty = hasEmpty,
				}
			end
		end
	end
	table.sort(equippedData, SortItems)
end

local function ScanBagGems()
	wipe(bagGemData)
	wipe(bagGemByID)
	wipe(bagSlotIndex)
	for _, bag in ipairs(BAGS) do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local itemID = C_Container.GetContainerItemID(bag, slot)
			if itemID and select(6, C_Item.GetItemInfoInstant(itemID)) == GEM_CLASS then
				local info = C_Container.GetContainerItemInfo(bag, slot)
				local gem = bagGemByID[itemID]
				if not gem then
					local name = C_Item.GetItemInfo(itemID) or ''
					gem = {
						itemID = itemID, icon = info.iconFileID, count = 0, quality = info.quality or 1,
						name = name, searchName = name:lower(),
					}
					bagGemByID[itemID] = gem
					bagGemData[#bagGemData + 1] = gem
					bagSlotIndex[itemID] = {}
				end
				gem.count = gem.count + info.stackCount
				local slots = bagSlotIndex[itemID]
				slots[#slots + 1] = { bag = bag, slot = slot, count = info.stackCount }
			end
		end
	end
	table.sort(bagGemData, SortGems)
end

local function ComputeSummary()
	local byName = {}
	wipe(gemCounts)
	emptySockets, totalSocketed, totalBagGems = 0, 0, 0
	for _, item in ipairs(equippedData) do
		for _, socket in ipairs(item.sockets) do
			if socket.empty then
				emptySockets = emptySockets + 1
			else
				totalSocketed = totalSocketed + 1
				local name = socket.gemName
				if name then
					local entry = byName[name]
					if not entry then
						entry = { name = name, icon = socket.gemIcon, quality = socket.gemQuality, count = 0 }
						byName[name] = entry
						gemCounts[#gemCounts + 1] = entry
					end
					entry.count = entry.count + 1
				end
			end
		end
	end
	for _, gem in ipairs(bagGemData) do totalBagGems = totalBagGems + gem.count end
end

local function TakeBagSlot(gemID)
	local slots = bagSlotIndex[gemID]
	local entry = slots and slots[1]
	if not entry then return end
	entry.count = entry.count - 1
	if entry.count <= 0 then table.remove(slots, 1) end
	return entry.bag, entry.slot
end

local function BuildApplyGroups()
	ScanBagGems()
	local groups, bySlot, dropped = {}, {}, 0
	for _, pending in pairs(pendingByKey) do
		local bag, slot = TakeBagSlot(pending.gem.itemID)
		if bag then
			local group = bySlot[pending.slotID]
			if not group then
				group = { slotID = pending.slotID, gems = {} }
				bySlot[pending.slotID] = group
				groups[#groups + 1] = group
			end
			group.gems[#group.gems + 1] = { socketIdx = pending.socketIdx, bag = bag, slot = slot }
		else
			dropped = dropped + 1
		end
	end
	return groups, dropped
end

local function CloseSocketInfo()
	C_ItemSocketInfo.CloseSocketInfo()
end

local function AcceptAndClose()
	C_ItemSocketInfo.AcceptSockets()
	C_Timer.After(0.2, CloseSocketInfo)
end

local function SocketCurrentGroup()
	local numSockets = C_ItemSocketInfo.GetNumSockets()
	local clicked = false
	for _, gem in ipairs(applyQueue[applyIndex].gems) do
		if gem.socketIdx <= numSockets and not C_ItemSocketInfo.GetExistingSocketInfo(gem.socketIdx) then
			C_Container.PickupContainerItem(gem.bag, gem.slot)
			C_ItemSocketInfo.ClickSocketButton(gem.socketIdx)
			clicked = true
		end
	end
	if clicked then
		C_Timer.After(0.2, AcceptAndClose)
	else
		C_ItemSocketInfo.CloseSocketInfo()
	end
end

local function OnSocketInfoUpdate()
	if not applying or applyStep ~= 'open' then return end
	applyStep = 'socket'
	C_Timer.After(0.1, SocketCurrentGroup)
end

local function ProcessNextItem()
	applyStep  = 'open'
	applyIndex = applyIndex + 1
	if applyIndex > #applyQueue then
		applying   = false
		applyStep  = nil
		applyQueue = nil
		ClearAllPending()
		C_Timer.After(0.5, RefreshContent)
		return
	end
	SocketInventoryItem(applyQueue[applyIndex].slotID)
end

local function OnSocketInfoClose()
	if not applying or applyStep ~= 'socket' then return end
	applyStep = 'next'
	C_Timer.After(0.3, ProcessNextItem)
end

local function BeginApply()
	if applying then return end
	if InCombatLockdown() then
		print('|cffff4444Gem Manager:|r Cannot socket gems during combat.')
		return
	end
	local groups, dropped = BuildApplyGroups()
	if dropped > 0 then
		print('|cffff4444Gem Manager:|r ' .. dropped .. ' queued gem(s) are no longer in your bags and were skipped.')
	end
	if #groups == 0 then
		ClearAllPending()
		Redraw()
		return
	end
	applying   = true
	applyIndex = 0
	applyQueue = groups
	ProcessNextItem()
end

local function HeaderEnter(self)
	self:SetBackdropBorderColor(Colors.GetAccent())
	GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
	GameTooltip:SetInventoryItem('player', self._slotID)
	GameTooltip:Show()
end

local function HeaderLeave(self)
	self:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
	GameTooltip:Hide()
end

local function SocketEnter(self)
	self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
	if self._gemItemID then
		GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
		GameTooltip:SetItemByID(self._gemItemID)
		GameTooltip:Show()
	end
end

local function SocketLeave(self)
	if pendingByKey[self._pendingKey] then
		self:SetBackdropBorderColor(0.2, 0.7, 0.2, 0.5)
	else
		self:SetBackdropBorderColor(0.1, 0.1, 0.1, 0)
	end
	GameTooltip:Hide()
end

local function SocketClick(self)
	if pendingByKey[self._pendingKey] then
		pendingByKey[self._pendingKey] = nil
		Redraw()
	elseif selectedBagGemID and self._empty then
		AssignGem(self, selectedBagGemID)
		selectedBagGemID = nil
		Redraw()
	end
end

local function GemEnter(self)
	if self._itemID ~= selectedBagGemID then
		self:SetBackdropBorderColor(Colors.GetAccent())
	end
	GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
	GameTooltip:SetItemByID(self._itemID)
	GameTooltip:Show()
end

local function GemLeave(self)
	if self._itemID == selectedBagGemID then
		self:SetBackdropBorderColor(Colors.GetAccent())
	else
		self:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)
	end
	GameTooltip:Hide()
end

local function GemClick(self)
	if GemAvailable(self._itemID) <= 0 then return end
	selectedBagGemID = selectedBagGemID ~= self._itemID and self._itemID or nil
	Redraw()
end

local function GemDragStart(self)
	if GemAvailable(self._itemID) > 0 then StartGemDrag(self._itemID, self.icon:GetTexture()) end
end

local function StripIconEnter(self)
	Widget.ShowTip(self, self._gemName .. '  |  Socketed: ' .. self._count)
end

local function CreateItemHeader(parent)
	local row = MakeRowButton(parent, HEADER_HEIGHT, {0.1, 0.1, 0.1, 0.8}, {0.15, 0.15, 0.15, 1})

	local iconFrame = MakeIconFrame(row, 24, 20)
	iconFrame:SetPoint('LEFT', Pixel.Scale(6), 0)
	row.iconBg = iconFrame
	row.icon = iconFrame.icon

	local nameLabel = MakeLabel(row, 12)
	nameLabel:SetPoint('LEFT', iconFrame, 'RIGHT', Pixel.Scale(8), 0)
	nameLabel:SetPoint('RIGHT', Pixel.Scale(-60), 0)
	nameLabel:SetJustifyH('LEFT')
	nameLabel:SetWordWrap(false)
	row.nameText = nameLabel

	local slotLabel = MakeLabel(row, 10)
	slotLabel:SetPoint('RIGHT', Pixel.Scale(-6), 0)
	slotLabel:SetTextColor(0.5, 0.5, 0.5)
	row.slotText = slotLabel

	row:SetScript('OnEnter', HeaderEnter)
	row:SetScript('OnLeave', HeaderLeave)
	return row
end

local function CreateSocketRow(parent)
	local row = MakeRowButton(parent, SOCKET_HEIGHT, {0.06, 0.06, 0.06, 0.5}, {0.1, 0.1, 0.1, 0})

	local iconBorder = MakeIconFrame(row, 20, 16)
	iconBorder:SetPoint('LEFT', INDENT, 0)
	row.iconBorder = iconBorder
	row.icon = iconBorder.icon

	local qualityPip = row:CreateTexture(nil, 'OVERLAY')
	qualityPip:SetSize(Pixel.Scale(14), Pixel.Scale(14))
	qualityPip:SetPoint('LEFT', iconBorder, 'RIGHT', Pixel.Scale(3), 0)
	row.qualPip = qualityPip

	local nameLabel = MakeLabel(row, 11)
	nameLabel:SetPoint('LEFT', qualityPip, 'RIGHT', Pixel.Scale(2), 0)
	nameLabel:SetPoint('RIGHT', Pixel.Scale(-6), 0)
	nameLabel:SetJustifyH('LEFT')
	nameLabel:SetWordWrap(false)
	row.nameText = nameLabel

	row:SetScript('OnEnter', SocketEnter)
	row:SetScript('OnLeave', SocketLeave)
	row:SetScript('OnClick', SocketClick)
	return row
end

local function CreateGemRow(parent)
	local row = MakeRowButton(parent, GEM_HEIGHT, {0.08, 0.08, 0.08, 0.8}, {0.12, 0.12, 0.12, 1})

	local iconFrame = MakeIconFrame(row, 28, 24)
	iconFrame:SetPoint('LEFT', Pixel.Scale(6), 0)
	row.iconBg = iconFrame
	row.icon = iconFrame.icon

	local qualityPip = row:CreateTexture(nil, 'OVERLAY')
	qualityPip:SetSize(Pixel.Scale(14), Pixel.Scale(14))
	qualityPip:SetPoint('LEFT', iconFrame, 'RIGHT', Pixel.Scale(4), 0)
	row.qualPip = qualityPip

	local nameLabel = MakeLabel(row, 12)
	nameLabel:SetPoint('LEFT', qualityPip, 'RIGHT', Pixel.Scale(2), 0)
	nameLabel:SetJustifyH('LEFT')
	nameLabel:SetWordWrap(false)
	row.nameText = nameLabel

	local countText = MakeLabel(row, 11)
	countText:SetPoint('RIGHT', Pixel.Scale(-6), 0)
	countText:SetJustifyH('RIGHT')
	countText:SetTextColor(0.7, 0.7, 0.7)
	row.countText = countText

	nameLabel:SetPoint('RIGHT', countText, 'LEFT', Pixel.Scale(-4), 0)

	row:SetScript('OnEnter', GemEnter)
	row:SetScript('OnLeave', GemLeave)
	row:SetScript('OnClick', GemClick)
	row:RegisterForDrag('LeftButton')
	row:SetScript('OnDragStart', GemDragStart)
	row:SetScript('OnDragStop', StopGemDrag)
	return row
end

local function CreateQualityHeader(parent)
	local header = CreateFrame('Frame', nil, parent)
	header:SetHeight(QUALITY_HEADER_HEIGHT)
	local label = MakeLabel(header, 10)
	label:SetPoint('LEFT', Pixel.Scale(6), 0)
	header.text = label
	return header
end

local function CreateGemIcon(parent)
	local frame = MakeIconFrame(parent, 24, 20)

	local countText = MakeLabel(frame, 9, 'OUTLINE')
	countText:SetPoint('BOTTOMRIGHT', Pixel.Scale(2), Pixel.Scale(-2))
	frame.count = countText

	frame:EnableMouse(true)
	frame:SetScript('OnEnter', StripIconEnter)
	frame:SetScript('OnLeave', Widget.HideTip)
	return frame
end

local function RankLabel(rank)
	return ITEM_QUALITY_COLORS[rank].hex .. _G['ITEM_QUALITY' .. rank .. '_DESC'] .. '|r'
end

local function BuildPanel()
	local panelFrame = Widget.New(UIParent, 'Frame', nil, { bg = Colors.bg.dark, border = Colors.border.light, size = { PANEL_WIDTH, 400 } }).frame
	panelFrame:SetFrameStrata('HIGH')
	panelFrame:SetFrameLevel(50)
	panelFrame:SetClampedToScreen(false)
	panelFrame:Hide()
	panel = panelFrame

	BUI.Skinning.CreateTitleBar(panelFrame, 'Gem Manager', 36, function() slide.Close() end)
	local toolbar = CreateFrame('Frame', nil, panelFrame)
	toolbar:SetPoint('TOPLEFT', 12, -40)
	toolbar:SetPoint('TOPRIGHT', -12, -40)
	toolbar:SetHeight(Pixel.Scale(30))

	local searchBox = BUI.Skinning.CreateSearchBox(panelFrame, 240, function(text) searchText = text; Redraw() end)
	searchBox:SetPoint('TOPLEFT', toolbar, 'TOPLEFT')

	local filterDropdown = BUI.Skinning.CreateDropdown(panelFrame, {
		{ label = 'All Qualities', value = 0 },
		{ label = RankLabel(1), value = 1 },
		{ label = RankLabel(2), value = 2 },
		{ label = RankLabel(3), value = 3 },
		{ label = RankLabel(4), value = 4 },
		{ label = RankLabel(5), value = 5 },
	}, function(item) qualityFilter = item.value; Redraw() end, 140)
	filterDropdown:SetPoint('TOPRIGHT', toolbar, 'TOPRIGHT')

	local leftHeader = MakeLabel(panelFrame, 10)
	leftHeader:SetPoint('TOPLEFT', 14, -76)
	leftHeader:SetText('EQUIPPED SOCKETS')
	leftHeader:SetTextColor(0.5, 0.5, 0.5)

	local rightHeader = MakeLabel(panelFrame, 10)
	rightHeader:SetPoint('TOPLEFT', 14 + COLUMN_WIDTH + COLUMN_GAP, -76)
	rightHeader:SetText('BAG GEMS')
	rightHeader:SetTextColor(0.5, 0.5, 0.5)

	local leftArea = CreateFrame('Frame', nil, panelFrame)
	leftArea:SetPoint('TOPLEFT', 8, -92)
	leftArea:SetPoint('BOTTOMLEFT', 8, BOTTOM_OFFSET)
	leftArea:SetWidth(COLUMN_WIDTH)
	panelFrame.leftChild = select(2, BUI.Skinning.CreateScrollArea(leftArea, HEADER_HEIGHT, 4))

	local rightArea = CreateFrame('Frame', nil, panelFrame)
	rightArea:SetPoint('TOPLEFT', 8 + COLUMN_WIDTH + COLUMN_GAP, -92)
	rightArea:SetPoint('BOTTOMLEFT', 8 + COLUMN_WIDTH + COLUMN_GAP, BOTTOM_OFFSET)
	rightArea:SetWidth(COLUMN_WIDTH)
	panelFrame.rightChild = select(2, BUI.Skinning.CreateScrollArea(rightArea, GEM_HEIGHT, 4))

	local divider = panelFrame:CreateTexture(nil, 'ARTWORK')
	divider:SetWidth(Pixel.PixelSize(1))
	divider:SetPoint('TOP', 8 + COLUMN_WIDTH + COLUMN_GAP / 2, -92)
	divider:SetPoint('BOTTOM', 0, BOTTOM_OFFSET)
	BUI.Tools.SetColorTex(divider, 0.15, 0.15, 0.15, 0.6)

	local separator = panelFrame:CreateTexture(nil, 'ARTWORK')
	separator:SetHeight(Pixel.PixelSize(1))
	separator:SetPoint('BOTTOMLEFT', 8, BOTTOM_OFFSET - 6)
	separator:SetPoint('BOTTOMRIGHT', -8, BOTTOM_OFFSET - 6)
	BUI.Tools.SetColorTex(separator, 0.15, 0.15, 0.15, 0.6)

	local bottomBar = CreateFrame('Frame', nil, panelFrame)
	bottomBar:SetPoint('BOTTOMLEFT', 12, 8)
	bottomBar:SetPoint('BOTTOMRIGHT', -12, 8)
	bottomBar:SetHeight(BOTTOM_HEIGHT)

	panelFrame.hintText = MakeLabel(bottomBar, 10)
	panelFrame.hintText:SetPoint('TOP', bottomBar, 'TOP')
	panelFrame.hintText:SetJustifyH('CENTER')
	panelFrame.hintText:SetTextColor(0.4, 0.4, 0.4)
	panelFrame.hintText:Hide()

	panelFrame.gemStrip = CreateFrame('Frame', nil, bottomBar)
	panelFrame.gemStrip:SetPoint('TOPLEFT', 0, Pixel.Scale(-2))
	panelFrame.gemStrip:SetSize(Pixel.Scale(400), Pixel.Scale(24))
	panelFrame.gemIcons = {}

	panelFrame.gemOverflowText = MakeLabel(panelFrame.gemStrip, 10)
	panelFrame.gemOverflowText:SetPoint('LEFT', (STRIP_MAX_ICONS - 1) * STRIP_ICON_GAP + Pixel.Scale(2), 0)
	panelFrame.gemOverflowText:SetTextColor(0.6, 0.6, 0.6)

	panelFrame.statsText = MakeLabel(bottomBar, 10)
	panelFrame.statsText:SetPoint('BOTTOMLEFT', 0, 0)
	panelFrame.statsText:SetJustifyH('LEFT')
	panelFrame.statsText:SetTextColor(0.5, 0.5, 0.5)

	panelFrame.applyBtn = Controls.Button(panelFrame, 'Apply', 72, function()
		Modals.Confirm({
			title = 'Apply Gem Changes',
			message = 'Socket ' .. PendingCount() .. ' gems?',
			parent = panelFrame,
			onConfirm = BeginApply,
		})
	end)
	panelFrame.applyBtn.frame:SetHeight(Pixel.Scale(26))
	panelFrame.applyBtn:SetPoint('BOTTOMRIGHT', bottomBar, 'BOTTOMRIGHT')
	panelFrame.applyBtn:SetFrameLevel(panelFrame:GetFrameLevel() + 10)

	panelFrame.clearBtn = Controls.Button(panelFrame, 'Clear', 72, function() ClearAllPending(); Redraw() end)
	panelFrame.clearBtn.frame:SetHeight(Pixel.Scale(26))
	panelFrame.clearBtn:SetPoint('RIGHT', panelFrame.applyBtn, 'LEFT', Pixel.Scale(-8), 0)
	panelFrame.clearBtn:SetFrameLevel(panelFrame:GetFrameLevel() + 10)

	panelFrame.leftEmpty = MakeLabel(panelFrame, 11)
	panelFrame.leftEmpty:SetPoint('CENTER', leftArea)
	panelFrame.leftEmpty:SetTextColor(0.4, 0.4, 0.4)
	panelFrame.leftEmpty:SetText('No socketed gear.')
	panelFrame.leftEmpty:Hide()

	panelFrame.rightEmpty = MakeLabel(panelFrame, 11)
	panelFrame.rightEmpty:SetPoint('CENTER', rightArea)
	panelFrame.rightEmpty:SetTextColor(0.4, 0.4, 0.4)
	panelFrame.rightEmpty:SetText('No gems in bags.')
	panelFrame.rightEmpty:Hide()
end

local function RefreshSummary()
	local shownCount = #gemCounts > STRIP_MAX_ICONS and (STRIP_MAX_ICONS - 1) or #gemCounts
	for gemIndex = 1, shownCount do
		local gem = gemCounts[gemIndex]
		local gemIcon = PoolGet(panel.gemIcons, gemIndex, CreateGemIcon, panel.gemStrip)
		gemIcon:ClearAllPoints()
		gemIcon:SetPoint('LEFT', (gemIndex - 1) * STRIP_ICON_GAP, 0)
		gemIcon.icon:SetTexture(gem.icon)
		gemIcon:SetBackdropBorderColor(QualityColor(gem.quality))
		gemIcon.count:SetText(gem.count > 1 and gem.count or '')
		gemIcon._gemName = gem.name
		gemIcon._count   = gem.count
		gemIcon:Show()
	end
	PoolHideFrom(panel.gemIcons, shownCount + 1)

	local overflow = #gemCounts - shownCount
	panel.gemOverflowText:SetText('+' .. overflow)
	panel.gemOverflowText:SetShown(overflow > 0)

	local emptyColor = emptySockets > 0 and 'ffee5555' or 'ff55cc55'
	local separator = '  |cff444444||  '
	panel.statsText:SetText(
		'|c' .. emptyColor .. emptySockets .. '|r |cff888888Empty|r' .. separator ..
		'|cffffffff' .. totalSocketed .. '|r |cff888888Socketed|r' .. separator ..
		'|cffffffff' .. #gemCounts .. '|r |cff888888Unique|r' .. separator ..
		'|cffffffff' .. totalBagGems .. '|r |cff888888in Bags|r'
	)
end

local function RefreshActions()
	local hasPending = next(pendingByKey) ~= nil
	local alpha = hasPending and 1 or 0.3
	panel.applyBtn:SetAlpha(alpha)
	panel.applyBtn:EnableMouse(hasPending)
	panel.clearBtn:SetAlpha(alpha)
	panel.clearBtn:EnableMouse(hasPending)

	if selectedBagGemID then
		local gem = bagGemByID[selectedBagGemID]
		panel.hintText:SetText('Click a socket to assign: ' .. (gem and gem.name or ''))
		panel.hintText:Show()
	else
		panel.hintText:Hide()
	end
end

local function MatchesSearch(item)
	if item.searchName:find(searchText, 1, true) then return true end
	for _, socket in ipairs(item.sockets) do
		if socket.searchName and socket.searchName:find(searchText, 1, true) then return true end
		local pending = pendingByKey[socket.key]
		if pending and pending.gem.searchName:find(searchText, 1, true) then return true end
	end
	return false
end

local function RefreshEquipped()
	local child = panel.leftChild
	local headerIndex, socketIndex, cursorY = 0, 0, 0

	for _, item in ipairs(equippedData) do
		if searchText == '' or MatchesSearch(item) then
			headerIndex = headerIndex + 1
			local header = PoolGet(headerPool, headerIndex, CreateItemHeader, child)
			header:ClearAllPoints()
			header:SetPoint('TOPLEFT', 0, -cursorY)
			header:SetPoint('RIGHT')
			header.icon:SetTexture(item.itemIcon)
			local red, green, blue = QualityColor(item.quality)
			header.nameText:SetText(item.itemName)
			header.nameText:SetTextColor(red, green, blue)
			header.iconBg:SetBackdropBorderColor(red, green, blue, 0.6)
			header.slotText:SetText(item.slotName)
			header._slotID = item.slotID
			header:Show()
			cursorY = cursorY + HEADER_HEIGHT

			for _, socket in ipairs(item.sockets) do
				socketIndex = socketIndex + 1
				local socketRow = PoolGet(socketPool, socketIndex, CreateSocketRow, child)
				socketRow:ClearAllPoints()
				socketRow:SetPoint('TOPLEFT', 0, -cursorY)
				socketRow:SetPoint('RIGHT')
				socketRow._slotID     = item.slotID
				socketRow._socketIdx  = socket.index
				socketRow._pendingKey = socket.key
				socketRow:SetBackdropBorderColor(0.1, 0.1, 0.1, 0)

				local pending = pendingByKey[socket.key]
				if pending then
					local gem = pending.gem
					local qualityRed, qualityGreen, qualityBlue = QualityColor(gem.quality)
					SetIconTexture(socketRow.icon, gem.icon)
					socketRow.nameText:SetText(gem.name .. ' |cff55cc55(pending)|r')
					socketRow.nameText:SetTextColor(qualityRed, qualityGreen, qualityBlue)
					socketRow:SetBackdropBorderColor(0.2, 0.7, 0.2, 0.4)
					socketRow.iconBorder:SetBackdropBorderColor(qualityRed, qualityGreen, qualityBlue, 0.8)
					SetQualityAtlas(socketRow.qualPip, gem.itemID)
					socketRow._empty, socketRow._gemItemID = false, gem.itemID
				elseif socket.empty then
					socketRow.icon:SetAtlas('Professions-Icon-Jewel-Empty')
					socketRow.nameText:SetText('Empty Socket')
					socketRow.nameText:SetTextColor(0.9, 0.3, 0.3)
					socketRow.iconBorder:SetBackdropBorderColor(0.5, 0.15, 0.15, 0.8)
					socketRow.qualPip:Hide()
					socketRow._empty, socketRow._gemItemID = true, nil
				else
					local qualityRed, qualityGreen, qualityBlue = QualityColor(socket.gemQuality)
					SetIconTexture(socketRow.icon, socket.gemIcon)
					socketRow.nameText:SetText(socket.gemName or '')
					socketRow.nameText:SetTextColor(qualityRed, qualityGreen, qualityBlue)
					socketRow.iconBorder:SetBackdropBorderColor(qualityRed, qualityGreen, qualityBlue, 0.6)
					SetQualityAtlas(socketRow.qualPip, socket.gemItemID)
					socketRow._empty, socketRow._gemItemID = false, socket.gemItemID
				end
				socketRow:Show()
				cursorY = cursorY + SOCKET_HEIGHT
			end
			cursorY = cursorY + ITEM_GAP
		end
	end

	PoolHideFrom(headerPool, headerIndex + 1)
	PoolHideFrom(socketPool, socketIndex + 1)
	child:SetHeight(math.max(1, cursorY))
	panel.leftEmpty:SetShown(headerIndex == 0)
end

local function RefreshInventory()
	local child = panel.rightChild
	local gemIndex, qualityIndex, cursorY, lastQuality = 0, 0, 0, nil

	for _, gem in ipairs(bagGemData) do
		if (qualityFilter == 0 or gem.quality == qualityFilter)
			and (searchText == '' or gem.searchName:find(searchText, 1, true)) then
			local red, green, blue = QualityColor(gem.quality)
			if gem.quality ~= lastQuality then
				lastQuality = gem.quality
				qualityIndex = qualityIndex + 1
				local qualityHeader = PoolGet(qualityPool, qualityIndex, CreateQualityHeader, child)
				qualityHeader:ClearAllPoints()
				qualityHeader:SetPoint('TOPLEFT', 0, -cursorY)
				qualityHeader:SetPoint('RIGHT')
				qualityHeader.text:SetText('Rank ' .. gem.quality)
				qualityHeader.text:SetTextColor(red, green, blue)
				qualityHeader:Show()
				cursorY = cursorY + QUALITY_HEADER_HEIGHT
			end

			gemIndex = gemIndex + 1
			local row = PoolGet(gemPool, gemIndex, CreateGemRow, child)
			row:ClearAllPoints()
			row:SetPoint('TOPLEFT', 0, -cursorY)
			row:SetPoint('RIGHT')
			row.icon:SetTexture(gem.icon)
			row.nameText:SetText(gem.name)
			row.nameText:SetTextColor(red, green, blue)
			row.iconBg:SetBackdropBorderColor(red, green, blue, 0.4)
			SetQualityAtlas(row.qualPip, gem.itemID)

			local used      = PendingCountFor(gem.itemID)
			local available = gem.count - used
			row.countText:SetText(used > 0
				and ('x' .. available .. ' |cff55cc55(-' .. used .. ')|r')
				or  ('x' .. gem.count))

			local selected = selectedBagGemID == gem.itemID
			if selected then
				row:SetBackdropBorderColor(Colors.GetAccent())
			else
				row:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)
			end
			row:SetAlpha((available <= 0 and not selected) and 0.35 or 1)
			row._itemID = gem.itemID
			row:Show()
			cursorY = cursorY + GEM_HEIGHT + 2
		end
	end

	PoolHideFrom(gemPool, gemIndex + 1)
	PoolHideFrom(qualityPool, qualityIndex + 1)
	child:SetHeight(math.max(1, cursorY))

	panel.rightEmpty:SetShown(gemIndex == 0)
	if gemIndex == 0 then
		panel.rightEmpty:SetText(searchText ~= '' and 'No matching gems.' or 'No gems in bags.')
	end
end

Redraw = function()
	RefreshActions()
	RefreshEquipped()
	RefreshInventory()
end

RefreshContent = function()
	if not panel or not panel:IsShown() then return end
	ScanEquipped()
	ScanBagGems()
	ComputeSummary()
	RefreshSummary()
	Redraw()
end

local ThrottledRefresh = BUI.Dispatcher.NewDelayed(RefreshContent, 0.3)

slide = BUI.SlidePanel.New({
	skin = 'gemcounter',
	width = PANEL_WIDTH,
	hiddenX = -PANEL_WIDTH,
	panel = function() return panel end,
	build = BuildPanel,
	onOpen = RefreshContent,
})

function BUI.GemCounter.Toggle()
	slide.Toggle()
end

local function OnCharacterHide()
	slide.Close(true)
	ClearAllPending()
end

local fallbackButton

local function UpdateFallbackButton()
	fallbackButton:SetShown(BUI.Skinning.IsSkinEnabled('gemcounter') and not BUI.Skinning.IsSkinEnabled('characterFrame'))
end

local function BuildFallbackButton()
	fallbackButton = CreateFrame('Button', nil, CharacterFrame, 'BackdropTemplate')
	fallbackButton:SetSize(28, 28)
	fallbackButton:SetFrameLevel(CharacterFrame:GetFrameLevel() + 5)
	fallbackButton:SetBackdrop(Widget.BACKDROP)
	fallbackButton:SetBackdropColor(0.05, 0.05, 0.06, 1)
	fallbackButton:SetBackdropBorderColor(0.2, 0.2, 0.22, 1)
	fallbackButton:SetPoint('TOPLEFT', CharacterFrame, 'TOPRIGHT', 4, -36)

	local iconTexture = fallbackButton:CreateTexture(nil, 'ARTWORK')
	iconTexture:SetAtlas('Professions-Icon-Jewel-Empty')
	iconTexture:SnapPoint('TOPLEFT', 3, -3)
	iconTexture:SnapPoint('BOTTOMRIGHT', -3, 3)

	fallbackButton:SetScript('OnEnter', function(self)
		self:SetBackdropBorderColor(Colors.GetAccent())
		GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
		GameTooltip:SetText('Gem Manager', 1, 1, 1)
		GameTooltip:Show()
	end)
	fallbackButton:SetScript('OnLeave', function(self)
		self:SetBackdropBorderColor(0.2, 0.2, 0.22, 1)
		GameTooltip:Hide()
	end)
	fallbackButton:SetScript('OnClick', BUI.GemCounter.Toggle)
end

local function OnInventoryChanged()
	if not applying and panel and panel:IsShown() then ThrottledRefresh() end
end

BUI.Events:OnLogin('GemCounter', function()
	CharacterFrame:HookScript('OnHide', OnCharacterHide)
	BuildFallbackButton()
	UpdateFallbackButton()

	BUI.Events:Register('BAG_UPDATE_DELAYED',       'GemCounter', OnInventoryChanged)
	BUI.Events:Register('PLAYER_EQUIPMENT_CHANGED', 'GemCounter', OnInventoryChanged)
	BUI.Events:Register('SOCKET_INFO_UPDATE',       'GemCounter', OnSocketInfoUpdate)
	BUI.Events:Register('SOCKET_INFO_CLOSE',        'GemCounter', OnSocketInfoClose)

	BUI.Skinning.OnToggle('gemcounter', function(enabled)
		if not enabled then
			slide.Close(true)
			ClearAllPending()
		end
		UpdateFallbackButton()
	end)
	BUI.Skinning.OnToggle('characterFrame', UpdateFallbackButton)
	BUI.Skinning.RegisterSkin('gemcounter', {
		name = 'Gem Manager',
		description = 'Two-column gem panel beside the Character frame with sandbox socketing.',
		icon = 'Interface\\Icons\\INV_Misc_Gem_01',
	})
end)
