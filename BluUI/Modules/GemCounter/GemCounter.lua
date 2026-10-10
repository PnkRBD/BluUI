local _, BUI = ...
local PoolGet, PoolHideFrom = BUI.Tools.PoolGet, BUI.Tools.PoolHideFrom
local Pixel   = BUI.Pixel
local Painter = BUI.Painter
local Skin    = BUI.Skinning
local After   = BUI.Profiler.After

local BUILib = BluUI.BUILibClient
local Widget = BUILib.Widget
local Modals = BUILib.Modals
local FONT   = BUILib.Font

BUI.GemCounter = {}

local GEM_CLASS      = Enum.ItemClass.Gem
local PANEL_WIDTH    = 600
local COLUMN_WIDTH   = 278
local COLUMN_GAP     = 12
local COLUMN_TOP     = 92
local LABEL_TOP      = 72
local LABEL_HEIGHT   = 16
local HEADER_HEIGHT  = 30
local SOCKET_HEIGHT  = 26
local GEM_HEIGHT     = 34
local ROW_GAP        = 4
local INDENT         = 30
local ITEM_GAP       = 6
local BOTTOM_HEIGHT  = 58
local BOTTOM_OFFSET  = 76
local BUTTON_W, BUTTON_H = 72, 26
local BAGS           = { 0, 1, 2, 3, 4, 5 }
local MAX_GEM_FIELDS = 4
local QUALITY_HEADER_HEIGHT = 22
local STRIP_ICON_GAP = 28
local STRIP_MAX_ICONS = 14
local PENDING_ALPHA  = 0.12
local HOVER_ALPHA    = 0.05
local EMPTY_SOCKET_EDGE = { 0.5, 0.15, 0.15 }

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
	return Painter.Color('skinText')
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
	Skin.CropIcon(iconTexture)
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
	Skin.PaintPanelBackdrop(iconFrame)
	local icon = iconFrame:CreateTexture(nil, 'ARTWORK')
	icon:SetSize(Pixel.Scale(iconSize), Pixel.Scale(iconSize))
	icon:SetPoint('CENTER')
	Skin.CropIcon(icon)
	iconFrame.icon = icon
	return iconFrame
end

local function MakeLabel(parent, size, role, flags)
	local fontString = parent:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(fontString, size, FONT, flags or '')
	if role then Painter.Text(fontString, role) end
	return fontString
end

local function PendingKey(slotID, index) return slotID .. ':' .. index end

local function ClearAllPending()
	wipe(pendingByKey)
	selectedBagGemID = nil
end

local function ApplyMessage()
	local count, replaced = 0, 0
	for _, pending in pairs(pendingByKey) do
		count = count + 1
		if pending.replaces then replaced = replaced + 1 end
	end
	local message = 'Socket ' .. count .. ' gems?'
	if replaced > 0 then
		message = message .. '\n|cffff5555' .. replaced .. ' socketed gem(s) will be destroyed.|r'
	end
	return message
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
	if itemID == row._socketedID then
		pendingByKey[row._pendingKey] = nil
	elseif GemAvailable(itemID) > 0 then
		pendingByKey[row._pendingKey] = {
			slotID = row._slotID, socketIdx = row._socketIdx, gem = bagGemByID[itemID], replaces = row._socketedID,
		}
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
		dragGhost:SetScript('OnUpdate', BUI.Profiler.Wrap('GemCounter.GemCounter follow cursor', FollowCursor))
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
		if socketRow:IsShown() and socketRow:IsMouseOver() then
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
	After('GemCounter.GemCounter close socket', 0.2, CloseSocketInfo)
end

local function SocketCurrentGroup()
	local numSockets = C_ItemSocketInfo.GetNumSockets()
	local clicked = false
	for _, gem in ipairs(applyQueue[applyIndex].gems) do
		if gem.socketIdx <= numSockets then
			C_Container.PickupContainerItem(gem.bag, gem.slot)
			C_ItemSocketInfo.ClickSocketButton(gem.socketIdx)
			clicked = true
		end
	end
	if clicked then
		After('GemCounter.GemCounter accept sockets', 0.2, AcceptAndClose)
	else
		C_ItemSocketInfo.CloseSocketInfo()
	end
end

local function OnSocketInfoUpdate()
	if not applying or applyStep ~= 'open' then return end
	applyStep = 'socket'
	After('GemCounter.GemCounter socket group', 0.1, SocketCurrentGroup)
end

local function ProcessNextItem()
	applyStep  = 'open'
	applyIndex = applyIndex + 1
	if applyIndex > #applyQueue then
		applying   = false
		applyStep  = nil
		applyQueue = nil
		ClearAllPending()
		After('GemCounter.GemCounter apply refresh', 0.5, RefreshContent)
		return
	end
	SocketInventoryItem(applyQueue[applyIndex].slotID)
end

local function OnSocketInfoClose()
	if not applying or applyStep ~= 'socket' then return end
	applyStep = 'next'
	After('GemCounter.GemCounter next item', 0.3, ProcessNextItem)
end

local function BeginApply()
	if applying then return end
	if InCombatLockdown() then
		BUI.Print('Gems cannot be socketed during combat.')
		return
	end
	local groups, dropped = BuildApplyGroups()
	if dropped > 0 then
		BUI.Print(dropped .. ' queued gem(s) are no longer in your bags and were skipped.')
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

local function ShowItemTooltip(self)
	GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
	GameTooltip:SetInventoryItem('player', self._slotID)
	GameTooltip:Show()
end

local function SocketEnter(self)
	if not self._gemItemID then return end
	GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
	GameTooltip:SetItemByID(self._gemItemID)
	GameTooltip:Show()
end

local function SocketClick(self)
	if selectedBagGemID then
		AssignGem(self, selectedBagGemID)
		selectedBagGemID = nil
	elseif pendingByKey[self._pendingKey] then
		pendingByKey[self._pendingKey] = nil
	else
		return
	end
	Redraw()
end

local function GemEnter(self)
	GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
	GameTooltip:SetItemByID(self._itemID)
	GameTooltip:Show()
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
	local row = CreateFrame('Button', nil, parent)
	row:SetHeight(Pixel.Scale(HEADER_HEIGHT))
	row:SetScript('OnEnter', BUI.Profiler.Script('GemCounter.GemCounter item OnEnter', ShowItemTooltip))
	row:SetScript('OnLeave', GameTooltip_Hide)
	Skin.CardRow(row)

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

	local slotLabel = MakeLabel(row, 10, 'skinLabel')
	slotLabel:SetPoint('RIGHT', Pixel.Scale(-8), 0)
	row.slotText = slotLabel
	return row
end

local function CreateSocketRow(parent)
	local row = CreateFrame('Button', nil, parent)
	row:SetHeight(Pixel.Scale(SOCKET_HEIGHT))
	row:SetScript('OnEnter', BUI.Profiler.Script('GemCounter.GemCounter socket OnEnter', SocketEnter))
	row:SetScript('OnLeave', GameTooltip_Hide)
	row:SetScript('OnClick', BUI.Profiler.Script('GemCounter.GemCounter socket OnClick', SocketClick))

	local hover = row:CreateTexture(nil, 'HIGHLIGHT')
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, HOVER_ALPHA)

	row.pendingTint = row:CreateTexture(nil, 'BACKGROUND')
	row.pendingTint:SetAllPoints()
	Painter.Custom(row.pendingTint, function(texture)
		local red, green, blue = Painter.Color('positive')
		texture:SetColorTexture(red, green, blue, PENDING_ALPHA)
	end)

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
	return row
end

local function CreateGemRow(parent)
	local row = CreateFrame('Button', nil, parent)
	row:SetHeight(Pixel.Scale(GEM_HEIGHT))
	row:SetScript('OnEnter', BUI.Profiler.Script('GemCounter.GemCounter gem OnEnter', GemEnter))
	row:SetScript('OnLeave', GameTooltip_Hide)
	row:SetScript('OnClick', BUI.Profiler.Script('GemCounter.GemCounter gem OnClick', GemClick))
	row:RegisterForDrag('LeftButton')
	row:SetScript('OnDragStart', BUI.Profiler.Script('GemCounter.GemCounter gem OnDragStart', GemDragStart))
	row:SetScript('OnDragStop', BUI.Profiler.Script('GemCounter.GemCounter gem OnDragStop', StopGemDrag))
	Skin.CardRow(row)

	local iconFrame = MakeIconFrame(row, 28, 24)
	iconFrame:SetPoint('LEFT', Pixel.Scale(6), 0)
	row.iconBg = iconFrame
	row.icon = iconFrame.icon

	local qualityPip = row:CreateTexture(nil, 'OVERLAY')
	qualityPip:SetSize(Pixel.Scale(14), Pixel.Scale(14))
	qualityPip:SetPoint('LEFT', iconFrame, 'RIGHT', Pixel.Scale(4), 0)
	row.qualPip = qualityPip

	local countText = MakeLabel(row, 11, 'skinLabel')
	countText:SetPoint('RIGHT', Pixel.Scale(-8), 0)
	countText:SetJustifyH('RIGHT')
	row.countText = countText

	local nameLabel = MakeLabel(row, 12)
	nameLabel:SetPoint('LEFT', qualityPip, 'RIGHT', Pixel.Scale(2), 0)
	nameLabel:SetPoint('RIGHT', countText, 'LEFT', Pixel.Scale(-4), 0)
	nameLabel:SetJustifyH('LEFT')
	nameLabel:SetWordWrap(false)
	row.nameText = nameLabel
	return row
end

local function CreateQualityHeader(parent)
	local header = CreateFrame('Frame', nil, parent)
	header:SetHeight(QUALITY_HEADER_HEIGHT)
	header.text = MakeLabel(header, 10)
	header.text:SetPoint('LEFT', Pixel.Scale(6), 0)
	return header
end

local function CreateGemIcon(parent)
	local frame = MakeIconFrame(parent, 24, 20)
	frame.count = MakeLabel(frame, 9, nil, 'OUTLINE')
	frame.count:SetPoint('BOTTOMRIGHT', Pixel.Scale(2), Pixel.Scale(-2))
	frame:EnableMouse(true)
	frame:SetScript('OnEnter', BUI.Profiler.Script('GemCounter.GemCounter strip OnEnter', StripIconEnter))
	frame:SetScript('OnLeave', BUI.Profiler.Script('GemCounter.GemCounter strip OnLeave', Widget.HideTip))
	return frame
end

local function RankLabel(rank)
	return ITEM_QUALITY_COLORS[rank].hex .. _G['ITEM_QUALITY' .. rank .. '_DESC'] .. '|r'
end

local function ColumnLabel(text, left)
	local header = Skin.CreateListHeader(panel, LABEL_HEIGHT)
	header:SetPoint('TOPLEFT', Pixel.Scale(left), Pixel.Scale(-LABEL_TOP))
	header:SetWidth(Pixel.Scale(COLUMN_WIDTH))
	header.text:SetText(text)
end

local function Column(left, rowHeight)
	local area = CreateFrame('Frame', nil, panel)
	area:SetPoint('TOPLEFT', Pixel.Scale(left), Pixel.Scale(-COLUMN_TOP))
	area:SetPoint('BOTTOMLEFT', Pixel.Scale(left), Pixel.Scale(BOTTOM_OFFSET))
	area:SetWidth(Pixel.Scale(COLUMN_WIDTH))
	local _, child = Skin.CreateScrollArea(area, rowHeight, 4)
	return area, child
end

local function Rule(texture)
	Painter.Fill(texture, 'skinBorder')
	return texture
end

local function BuildBottomBar()
	local bottomBar = CreateFrame('Frame', nil, panel)
	bottomBar:SetPoint('BOTTOMLEFT', Pixel.Scale(12), Pixel.Scale(8))
	bottomBar:SetPoint('BOTTOMRIGHT', Pixel.Scale(-12), Pixel.Scale(8))
	bottomBar:SetHeight(Pixel.Scale(BOTTOM_HEIGHT))

	panel.hintText = MakeLabel(bottomBar, 10, 'skinLabel')
	panel.hintText:SetPoint('TOP', bottomBar, 'TOP')
	panel.hintText:SetJustifyH('CENTER')
	panel.hintText:Hide()

	panel.gemStrip = CreateFrame('Frame', nil, bottomBar)
	panel.gemStrip:SetPoint('TOPLEFT', 0, Pixel.Scale(-2))
	panel.gemStrip:SetSize(Pixel.Scale(400), Pixel.Scale(24))
	panel.gemIcons = {}

	panel.gemOverflowText = MakeLabel(panel.gemStrip, 10, 'skinLabel')
	panel.gemOverflowText:SetPoint('LEFT', (STRIP_MAX_ICONS - 1) * STRIP_ICON_GAP + Pixel.Scale(2), 0)

	panel.statsText = MakeLabel(bottomBar, 10, 'skinLabel')
	panel.statsText:SetPoint('BOTTOMLEFT', 0, 0)
	panel.statsText:SetJustifyH('LEFT')

	panel.applyBtn = Skin.SmallButton(panel, BUTTON_W, BUTTON_H, 'Apply')
	panel.applyBtn:SetScript('OnClick', BUI.Profiler.Script('GemCounter.GemCounter apply OnClick', function()
		Modals.Confirm({ title = 'Apply Gem Changes', message = ApplyMessage(), parent = panel, onConfirm = BeginApply })
	end))
	panel.applyBtn:SetPoint('BOTTOMRIGHT', bottomBar, 'BOTTOMRIGHT')

	panel.clearBtn = Skin.SmallButton(panel, BUTTON_W, BUTTON_H, 'Clear')
	panel.clearBtn:SetScript('OnClick', BUI.Profiler.Script('GemCounter.GemCounter clear OnClick', function()
		ClearAllPending()
		Redraw()
	end))
	panel.clearBtn:SetPoint('RIGHT', panel.applyBtn, 'LEFT', Pixel.Scale(-8), 0)
end

local function BuildPanel()
	panel = Skin.CreatePanelWindow('Gem Manager', function() slide.Close() end)

	local searchBox = Skin.CreateSearchBox(panel, 240, function(text) searchText = text; Redraw() end)
	searchBox:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-40))

	local filterDropdown = Skin.CreateDropdown(panel, {
		{ label = 'All Qualities', value = 0 },
		{ label = RankLabel(1), value = 1 },
		{ label = RankLabel(2), value = 2 },
		{ label = RankLabel(3), value = 3 },
		{ label = RankLabel(4), value = 4 },
		{ label = RankLabel(5), value = 5 },
	}, function(item) qualityFilter = item.value; Redraw() end, 140)
	filterDropdown:SetPoint('TOPRIGHT', Pixel.Scale(-12), Pixel.Scale(-40))

	local rightLeft = 8 + COLUMN_WIDTH + COLUMN_GAP
	ColumnLabel('Equipped sockets', 8)
	ColumnLabel('Bag gems', rightLeft)
	local leftArea, rightArea
	leftArea, panel.leftChild = Column(8, HEADER_HEIGHT)
	rightArea, panel.rightChild = Column(rightLeft, GEM_HEIGHT)

	local divider = Rule(panel:CreateTexture(nil, 'ARTWORK'))
	divider:SetWidth(Pixel.PixelSize(1))
	divider:SetPoint('TOP', Pixel.Scale(8 + COLUMN_WIDTH + COLUMN_GAP / 2), Pixel.Scale(-COLUMN_TOP))
	divider:SetPoint('BOTTOM', 0, Pixel.Scale(BOTTOM_OFFSET))

	local separator = Rule(panel:CreateTexture(nil, 'ARTWORK'))
	separator:SetHeight(Pixel.PixelSize(1))
	separator:SetPoint('BOTTOMLEFT', Pixel.Scale(8), Pixel.Scale(BOTTOM_OFFSET - 6))
	separator:SetPoint('BOTTOMRIGHT', Pixel.Scale(-8), Pixel.Scale(BOTTOM_OFFSET - 6))

	BuildBottomBar()

	panel.leftEmpty = Skin.CreateEmptyText(panel, leftArea)
	panel.leftEmpty:SetText('No socketed gear.')
	panel.rightEmpty = Skin.CreateEmptyText(panel, rightArea)
end

local function Hex(role)
	return BUI.Hex(Painter.Color(role))
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

	local value = '|cff' .. Hex('skinText') .. '%d|r %s'
	panel.statsText:SetText(table.concat({
		('|cff%s%d|r Empty'):format(Hex(emptySockets > 0 and 'danger' or 'positive'), emptySockets),
		value:format(totalSocketed, 'Socketed'),
		value:format(#gemCounts, 'Unique'),
		value:format(totalBagGems, 'in Bags'),
	}, '  ||  '))
end

local function RefreshActions()
	local hasPending = next(pendingByKey) ~= nil
	local alpha = hasPending and 1 or 0.3
	panel.applyBtn:SetAlpha(alpha)
	panel.applyBtn:EnableMouse(hasPending)
	panel.clearBtn:SetAlpha(alpha)
	panel.clearBtn:EnableMouse(hasPending)

	local gem = selectedBagGemID and bagGemByID[selectedBagGemID]
	panel.hintText:SetShown(gem ~= nil)
	if gem then panel.hintText:SetText('Click a socket to assign: ' .. gem.name) end
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

local function Place(frame, child, cursorY)
	frame:ClearAllPoints()
	frame:SetPoint('TOPLEFT', child, 'TOPLEFT', 0, -cursorY)
	frame:SetPoint('TOPRIGHT', child, 'TOPRIGHT', 0, -cursorY)
	frame:Show()
end

local function FillSocket(socketRow, item, socket)
	socketRow._slotID     = item.slotID
	socketRow._socketIdx  = socket.index
	socketRow._pendingKey = socket.key
	socketRow._socketedID = socket.gemItemID

	local pending = pendingByKey[socket.key]
	socketRow.pendingTint:SetShown(pending ~= nil)
	if pending then
		local gem = pending.gem
		local red, green, blue = QualityColor(gem.quality)
		SetIconTexture(socketRow.icon, gem.icon)
		socketRow.nameText:SetText(('%s |cff%s(pending)|r'):format(gem.name, Hex('positive')))
		socketRow.nameText:SetTextColor(red, green, blue)
		socketRow.iconBorder:SetBackdropBorderColor(red, green, blue, 0.8)
		SetQualityAtlas(socketRow.qualPip, gem.itemID)
		socketRow._gemItemID = gem.itemID
	elseif socket.empty then
		socketRow.icon:SetAtlas('Professions-Icon-Jewel-Empty')
		socketRow.nameText:SetText('Empty Socket')
		socketRow.nameText:SetTextColor(Painter.Color('danger'))
		socketRow.iconBorder:SetBackdropBorderColor(EMPTY_SOCKET_EDGE[1], EMPTY_SOCKET_EDGE[2], EMPTY_SOCKET_EDGE[3], 0.8)
		socketRow.qualPip:Hide()
		socketRow._gemItemID = nil
	else
		local red, green, blue = QualityColor(socket.gemQuality)
		SetIconTexture(socketRow.icon, socket.gemIcon)
		socketRow.nameText:SetText(socket.gemName or '')
		socketRow.nameText:SetTextColor(red, green, blue)
		socketRow.iconBorder:SetBackdropBorderColor(red, green, blue, 0.6)
		SetQualityAtlas(socketRow.qualPip, socket.gemItemID)
		socketRow._gemItemID = socket.gemItemID
	end
end

local function RefreshEquipped()
	local child = panel.leftChild
	local headerIndex, socketIndex, cursorY = 0, 0, 0

	for _, item in ipairs(equippedData) do
		if searchText == '' or MatchesSearch(item) then
			headerIndex = headerIndex + 1
			local header = PoolGet(headerPool, headerIndex, CreateItemHeader, child)
			header.icon:SetTexture(item.itemIcon)
			local red, green, blue = QualityColor(item.quality)
			header.nameText:SetText(item.itemName)
			header.nameText:SetTextColor(red, green, blue)
			header.iconBg:SetBackdropBorderColor(red, green, blue, 0.6)
			header.slotText:SetText(item.slotName)
			header._slotID = item.slotID
			Place(header, child, cursorY)
			cursorY = cursorY + HEADER_HEIGHT + ROW_GAP

			for _, socket in ipairs(item.sockets) do
				socketIndex = socketIndex + 1
				local socketRow = PoolGet(socketPool, socketIndex, CreateSocketRow, child)
				FillSocket(socketRow, item, socket)
				Place(socketRow, child, cursorY)
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
	local usedHex = Hex('positive')

	for _, gem in ipairs(bagGemData) do
		if (qualityFilter == 0 or gem.quality == qualityFilter)
			and (searchText == '' or gem.searchName:find(searchText, 1, true)) then
			local red, green, blue = QualityColor(gem.quality)
			if gem.quality ~= lastQuality then
				lastQuality = gem.quality
				qualityIndex = qualityIndex + 1
				local qualityHeader = PoolGet(qualityPool, qualityIndex, CreateQualityHeader, child)
				qualityHeader.text:SetText('Rank ' .. gem.quality)
				qualityHeader.text:SetTextColor(red, green, blue)
				Place(qualityHeader, child, cursorY)
				cursorY = cursorY + QUALITY_HEADER_HEIGHT
			end

			gemIndex = gemIndex + 1
			local row = PoolGet(gemPool, gemIndex, CreateGemRow, child)
			row.icon:SetTexture(gem.icon)
			row.nameText:SetText(gem.name)
			row.nameText:SetTextColor(red, green, blue)
			row.iconBg:SetBackdropBorderColor(red, green, blue, 0.4)
			SetQualityAtlas(row.qualPip, gem.itemID)

			local used      = PendingCountFor(gem.itemID)
			local available = gem.count - used
			row.countText:SetText(used > 0
				and ('x%d |cff%s(-%d)|r'):format(available, usedHex, used)
				or  ('x' .. gem.count))

			local selected = selectedBagGemID == gem.itemID
			Skin.SetActiveEdge(row, selected)
			row:SetAlpha((available <= 0 and not selected) and 0.35 or 1)
			row._itemID = gem.itemID
			Place(row, child, cursorY)
			cursorY = cursorY + GEM_HEIGHT + ROW_GAP
		end
	end

	PoolHideFrom(gemPool, gemIndex + 1)
	PoolHideFrom(qualityPool, qualityIndex + 1)
	child:SetHeight(math.max(1, cursorY))

	panel.rightEmpty:SetShown(gemIndex == 0)
	panel.rightEmpty:SetText(searchText ~= '' and 'No matching gems.' or 'No gems in bags.')
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

local ThrottledRefresh = BUI.Dispatcher.NewDelayed(RefreshContent, 0.3, 'Gem counter refresh')

local function OnInventoryChanged()
	if not applying then ThrottledRefresh() end
end

local INVENTORY_EVENTS = { 'BAG_UPDATE_DELAYED', 'PLAYER_EQUIPMENT_CHANGED' }

slide = BUI.SlidePanel.New({
	skin = 'gemcounter',
	width = PANEL_WIDTH,
	hiddenX = -PANEL_WIDTH,
	panel = function() return panel end,
	build = BuildPanel,
	onOpen = function()
		for _, event in ipairs(INVENTORY_EVENTS) do BUI.Events:Register(event, 'GemCounter', OnInventoryChanged) end
		RefreshContent()
	end,
	onClose = function()
		for _, event in ipairs(INVENTORY_EVENTS) do BUI.Events:Unregister(event, 'GemCounter') end
	end,
})

function BUI.GemCounter.Toggle()
	slide.Toggle()
end

local fallbackButton

local function UpdateFallbackButton()
	fallbackButton:SetShown(Skin.IsSkinEnabled('gemcounter') and not Skin.IsSkinEnabled('characterFrame'))
end

local function BuildFallbackButton()
	fallbackButton = Skin.SmallButton(CharacterFrame, 28, 28, '')
	fallbackButton:SetFrameLevel(CharacterFrame:GetFrameLevel() + 5)
	fallbackButton:SetPoint('TOPLEFT', CharacterFrame, 'TOPRIGHT', 4, -36)

	local iconTexture = fallbackButton:CreateTexture(nil, 'ARTWORK')
	iconTexture:SetAtlas('Professions-Icon-Jewel-Empty')
	iconTexture:SetPoint('TOPLEFT', 3, -3)
	iconTexture:SetPoint('BOTTOMRIGHT', -3, 3)

	fallbackButton:HookScript('OnEnter', BUI.Profiler.Script('GemCounter.GemCounter fallbackButton OnEnter', function()
		GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
		GameTooltip:SetText('Gem Manager', 1, 1, 1)
		GameTooltip:Show()
	end))
	fallbackButton:HookScript('OnLeave', GameTooltip_Hide)
	fallbackButton:SetScript('OnClick', BUI.Profiler.Script('GemCounter.GemCounter fallbackButton OnClick', BUI.GemCounter.Toggle))
end

local function CloseAndClear()
	slide.Close(true)
	ClearAllPending()
end

BUI.Events:OnLogin('GemCounter', function()
	local context = Skin.Define('gemcounter', {
		name = 'Gem Manager',
		description = 'Two-column gem panel beside the Character frame with sandbox socketing.',
		icon = 'Interface\\Icons\\INV_Misc_Gem_01',
		newLook = true,
	})
	context.OnDisable(CloseAndClear)
	CharacterFrame:HookScript('OnHide', BUI.Profiler.Wrap('GemCounter.GemCounter character hide', CloseAndClear))
	BuildFallbackButton()
	UpdateFallbackButton()

	BUI.Events:Register('SOCKET_INFO_UPDATE', 'GemCounter', OnSocketInfoUpdate)
	BUI.Events:Register('SOCKET_INFO_CLOSE',  'GemCounter', OnSocketInfoClose)
	Skin.OnToggle('gemcounter', UpdateFallbackButton)
	Skin.OnToggle('characterFrame', UpdateFallbackButton)
end, 'gemCounter')
