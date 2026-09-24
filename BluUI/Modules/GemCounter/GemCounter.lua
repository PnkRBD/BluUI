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
local GEAR_SLOTS     = 17
local MAX_GEM_FIELDS = 4
local QUALITY_HEADER_HEIGHT = 22
local STRIP_ICON_GAP = 28
local STRIP_MAX_ICONS = 14
local FALLBACK_ICON  = 134400
local BLANK          = BUI.C.FALLBACK_TEXTURE
local ICON_BACKDROP  = { bgFile = BLANK, edgeFile = BLANK, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
local TEXTURE_CROP   = { 0.08, 0.92, 0.08, 0.92 }

local SLOT_NAMES = {
	[1]  = 'Head',       [2]  = 'Neck',      [3]  = 'Shoulder',  [5]  = 'Chest',
	[6]  = 'Waist',      [7]  = 'Legs',      [8]  = 'Feet',      [9]  = 'Wrist',
	[10] = 'Hands',      [11] = 'Ring 1',    [12] = 'Ring 2',
	[13] = 'Trinket 1',  [14] = 'Trinket 2', [15] = 'Back',
	[16] = 'Main Hand',  [17] = 'Off Hand',
}


local panel
local isInitialized = false
local searchText, qualityFilter = '', 0

local equippedData = {}
local bagGemData   = {}
local bagSlotIndex = {}
local summary      = { emptySockets = 0, totalSocketed = 0, totalBagGems = 0, uniqueGemCount = 0, gemCounts = {} }

local pendingByKey     = {}
local selectedBagGemID = nil
local allSocketRows    = {}

local dragGhost, dragGemID
local applying, applyQueue, applyIndex, applyReady = false, {}, 0, false

local headerPool, socketPool, gemPool, qualityPool = {}, {}, {}, {}

local RefreshContent, CloseSlide

local function QualityColor(quality)
	if quality and quality > 1 then
		local color = ITEM_QUALITY_COLORS[quality]
		if color then return color.r, color.g, color.b end
	end
	return 0.9, 0.9, 0.9
end

local function SetQualityAtlas(pipTexture, itemID)
	local info = itemID and BUI.Lookup.CraftedQualityInfo(itemID)
	if info then
		pipTexture:SetAtlas(info.iconSmall)
		pipTexture:SetTexCoord(0, 1, 0, 1)
		pipTexture:Show()
	else
		pipTexture:Hide()
	end
end

local function SetIconTexture(iconTexture, texturePath)
	iconTexture:SetTexCoord(unpack(TEXTURE_CROP))
	iconTexture:SetTexture(texturePath or FALLBACK_ICON)
end

local function NameFromLink(link)
	return link and link:match('%[(.-)%]') or ''
end

local function IdFromLink(link)
	return tonumber(link and link:match('item:(%d+)'))
end

local function MakeIconFrame(parent, frameSize, iconSize)
	local iconFrame = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	iconFrame:SetSize(Pixel.Scale(frameSize), Pixel.Scale(frameSize))
	iconFrame:SetBackdrop(ICON_BACKDROP)
	iconFrame:SetBackdropColor(0, 0, 0, 1)
	local icon = iconFrame:CreateTexture(nil, 'ARTWORK')
	icon:SetSize(Pixel.Scale(iconSize), Pixel.Scale(iconSize))
	icon:SetPoint('CENTER')
	icon:SetTexCoord(unpack(TEXTURE_CROP))
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

local scanTooltip = CreateFrame('GameTooltip', 'BUIGemScanTip', nil, 'GameTooltipTemplate')
scanTooltip:SetOwner(WorldFrame, 'ANCHOR_NONE')

local EMPTY_SOCKET_LABELS = {}
for _, globalName in ipairs({
	'EMPTY_SOCKET_PRISMATIC', 'EMPTY_SOCKET_RED', 'EMPTY_SOCKET_YELLOW', 'EMPTY_SOCKET_BLUE',
	'EMPTY_SOCKET_META', 'EMPTY_SOCKET_COGWHEEL', 'EMPTY_SOCKET_HYDRAULIC', 'EMPTY_SOCKET_DOMINATION',
	'EMPTY_SOCKET_PRIMORDIAL', 'EMPTY_SOCKET_TINKER',
	'EMPTY_SOCKET_SINGINGTHUNDER', 'EMPTY_SOCKET_SINGINGSEA', 'EMPTY_SOCKET_SINGINGWIND',
}) do
	local label = _G[globalName]
	if label then EMPTY_SOCKET_LABELS[label] = true end
end

local function CountEmptySockets(slotID)
	scanTooltip:ClearLines()
	scanTooltip:SetInventoryItem('player', slotID)
	local count, heuristic = 0, 0
	for lineIndex = 1, scanTooltip:NumLines() do
		local line = _G['BUIGemScanTipTextLeft' .. lineIndex]
		local text = line and line:GetText()
		if text then
			if EMPTY_SOCKET_LABELS[text] then
				count = count + 1
			elseif text:find('Socket') and (text:find('Empty') or text:find('Prismatic')) then
				heuristic = heuristic + 1
			end
		end
	end

	return count + heuristic
end

local function PendingKey(slotID, index) return slotID .. ':' .. index end

local function AddPending(slotID, index, gemID, icon, name, quality)
	pendingByKey[PendingKey(slotID, index)] = {
		slotID = slotID, socketIdx = index,
		gemItemID = gemID, gemIcon = icon, gemName = name, gemQuality = quality,
	}
end

local function RemovePending(slotID, index) pendingByKey[PendingKey(slotID, index)] = nil end

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
		if pending.gemItemID == gemID then count = count + 1 end
	end
	return count
end

local function HasPending() return next(pendingByKey) ~= nil end

local function GetPendingList()
	local list = {}
	for _, entry in pairs(pendingByKey) do list[#list + 1] = entry end
	return list
end

local function FindBagGem(itemID)
	for _, gem in ipairs(bagGemData) do
		if gem.itemID == itemID then return gem end
	end
end

local function GemAvailable(itemID)
	local gem = FindBagGem(itemID)
	return gem and (gem.count - PendingCountFor(itemID)) or 0
end

local function CreateDragGhost()
	if dragGhost then return dragGhost end
	local ghost = CreateFrame('Frame', nil, UIParent)
	ghost:SetSize(Pixel.Scale(28), Pixel.Scale(28))
	ghost:SetFrameStrata('TOOLTIP')
	ghost:SetFrameLevel(999)
	ghost:EnableMouse(false)
	local ghostTexture = ghost:CreateTexture(nil, 'ARTWORK')
	ghostTexture:SetAllPoints()
	ghostTexture:SetTexCoord(unpack(TEXTURE_CROP))
	ghost.tex = ghostTexture
	ghost:Hide()
	dragGhost = ghost
	return ghost
end

local function StartGemDrag(itemID, icon)
	local ghost = CreateDragGhost()
	ghost.tex:SetTexture(icon)
	dragGemID = itemID
	selectedBagGemID = itemID
	ghost:Show()
	ghost:SetScript('OnUpdate', function(self)
		local cursorX, cursorY = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		self:ClearAllPoints()
		self:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', cursorX / scale, cursorY / scale)
	end)
end

local function StopGemDrag()
	if not dragGemID then return end
	if dragGhost then
		dragGhost:Hide()
		dragGhost:SetScript('OnUpdate', nil)
	end

	for _, socketRow in ipairs(allSocketRows) do
		if socketRow:IsShown() and socketRow._empty and socketRow:IsMouseOver() then
			local gem = FindBagGem(dragGemID)
			if gem and GemAvailable(gem.itemID) > 0 then
				AddPending(socketRow._slotID, socketRow._socketIdx, gem.itemID, gem.icon, gem.name, gem.quality)
			end
			break
		end
	end

	dragGemID = nil
	selectedBagGemID = nil
	RefreshContent()
end

local function ScanEquipped()
	wipe(equippedData)
	for slot = 1, GEAR_SLOTS do
		local link = GetInventoryItemLink('player', slot)
		if link and SLOT_NAMES[slot] then
			local filledByIndex, numFilled = {}, 0
			for gemFieldIndex = 1, MAX_GEM_FIELDS do
				local gemName, gemLink = C_Item.GetItemGem(link, gemFieldIndex)
				if gemLink then
					filledByIndex[gemFieldIndex] = { name = gemName, link = gemLink }
					numFilled = numFilled + 1
				end
			end

			local emptyCount = CountEmptySockets(slot)
			local totalSockets = numFilled + emptyCount
			for gemFieldIndex = MAX_GEM_FIELDS, 1, -1 do
				if filledByIndex[gemFieldIndex] and gemFieldIndex > totalSockets then totalSockets = gemFieldIndex end
			end

			local sockets, emptiesRemaining = {}, emptyCount
			for index = 1, totalSockets do
				local filled = filledByIndex[index]
				if filled then
					local gemID = IdFromLink(filled.link)
					local gemIcon, gemQuality
					if gemID then
						gemIcon = select(5, C_Item.GetItemInfoInstant(gemID))
						gemQuality = C_Item.GetItemQualityByID(gemID)
					end
					sockets[#sockets + 1] = {
						empty = false, index = index, gemName = filled.name, gemItemID = gemID,
						gemIcon = gemIcon, gemQuality = gemQuality,
					}
				elseif emptiesRemaining > 0 then
					emptiesRemaining = emptiesRemaining - 1
					sockets[#sockets + 1] = { empty = true, index = index }
				end
			end

			if #sockets > 0 then
				local itemID = IdFromLink(link)
				local icon, quality
				if itemID then
					icon = select(5, C_Item.GetItemInfoInstant(itemID))
					quality = C_Item.GetItemQualityByID(itemID)
				end

				table.sort(sockets, function(firstSocket, secondSocket) return firstSocket.empty and not secondSocket.empty end)
				equippedData[#equippedData + 1] = {
					slotID = slot, slotName = SLOT_NAMES[slot], itemLink = link,
					itemName = NameFromLink(link), itemIcon = icon, quality = quality,
					sockets = sockets, hasEmpty = emptyCount > 0,
				}
			end
		end
	end

	table.sort(equippedData, function(firstItem, secondItem)
		if firstItem.hasEmpty ~= secondItem.hasEmpty then return firstItem.hasEmpty end
		return firstItem.slotID < secondItem.slotID
	end)
end

local function ScanBagGems()
	local counts, order = {}, {}
	wipe(bagSlotIndex)

	for _, bag in ipairs(BAGS) do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				local _, _, _, _, icon, classID = C_Item.GetItemInfoInstant(info.itemID)
				if classID == GEM_CLASS then
					local itemID = info.itemID
					if not counts[itemID] then
						counts[itemID] = {
							itemID = itemID, icon = info.iconFileID or icon, count = 0,
							quality = C_Item.GetItemQualityByID(itemID) or 1,
							name = C_Item.GetItemInfo(itemID) or '',
						}
						order[#order + 1] = itemID
						bagSlotIndex[itemID] = {}
					end
					counts[itemID].count = counts[itemID].count + (info.stackCount or 1)
					bagSlotIndex[itemID][#bagSlotIndex[itemID] + 1] = { bag = bag, slot = slot, count = info.stackCount or 1 }
				end
			end
		end
	end

	wipe(bagGemData)
	for _, itemID in ipairs(order) do bagGemData[#bagGemData + 1] = counts[itemID] end
	table.sort(bagGemData, function(firstGem, secondGem)
		if firstGem.quality ~= secondGem.quality then return firstGem.quality > secondGem.quality end
		return firstGem.name < secondGem.name
	end)
end

local function ComputeSummary()
	summary.emptySockets   = 0
	summary.totalSocketed  = 0
	summary.totalBagGems   = 0
	summary.uniqueGemCount = 0
	summary.gemCounts      = {}

	local byName, order = {}, {}
	for _, item in ipairs(equippedData) do
		for _, socket in ipairs(item.sockets) do
			if socket.empty then
				summary.emptySockets = summary.emptySockets + 1
			else
				summary.totalSocketed = summary.totalSocketed + 1
				if socket.gemName then
					if not byName[socket.gemName] then
						byName[socket.gemName] = {
							gemName = socket.gemName, gemIcon = socket.gemIcon,
							gemQuality = socket.gemQuality, gemItemID = socket.gemItemID, count = 0,
						}
						order[#order + 1] = socket.gemName
					end
					byName[socket.gemName].count = byName[socket.gemName].count + 1
				end
			end
		end
	end
	for _, name in ipairs(order) do summary.gemCounts[#summary.gemCounts + 1] = byName[name] end
	summary.uniqueGemCount = #order

	for _, gem in ipairs(bagGemData) do summary.totalBagGems = summary.totalBagGems + gem.count end
end

local ProcessNextItem

local function FindBagSlot(gemID)
	local slots = bagSlotIndex[gemID]
	local entry = slots and slots[1]
	if not entry then return end
	entry.count = entry.count - 1
	if entry.count <= 0 then table.remove(slots, 1) end
	return { bag = entry.bag, slot = entry.slot }
end

local function BuildApplyGroups()
	local groups, order = {}, {}
	local dropped = 0
	ScanBagGems()
	for _, pending in ipairs(GetPendingList()) do
		local bagInfo = FindBagSlot(pending.gemItemID)
		if bagInfo then
			if not groups[pending.slotID] then
				groups[pending.slotID] = { slotID = pending.slotID, gems = {} }
				order[#order + 1] = pending.slotID
			end
			local gemList = groups[pending.slotID].gems
			gemList[#gemList + 1] = { socketIdx = pending.socketIdx, bagInfo = bagInfo }
		else
			dropped = dropped + 1
		end
	end
	local orderedGroups = {}
	for _, slotID in ipairs(order) do orderedGroups[#orderedGroups + 1] = groups[slotID] end
	return orderedGroups, dropped
end

local function GetOpenSocketCount()
	return C_ItemSocketInfo.GetNumSockets()
end

local function IsSocketOccupied(index)
	return C_ItemSocketInfo.GetExistingSocketInfo(index) ~= nil
end

local function OnSocketInfoUpdate()
	if not applying or not applyQueue[applyIndex] or applyReady then return end
	applyReady = true
	local group = applyQueue[applyIndex]
	C_Timer.After(0.1, function()
		local numSockets = GetOpenSocketCount()
		local clicked = false
		for _, gem in ipairs(group.gems) do
			if (not numSockets or gem.socketIdx <= numSockets) and not IsSocketOccupied(gem.socketIdx) then
				C_Container.PickupContainerItem(gem.bagInfo.bag, gem.bagInfo.slot)
				C_ItemSocketInfo.ClickSocketButton(gem.socketIdx)
				clicked = true
			end
		end
		if clicked then
			C_Timer.After(0.2, function()
				C_ItemSocketInfo.AcceptSockets()
				C_Timer.After(0.2, CloseSocketInfo)
			end)
		else
			CloseSocketInfo()
		end
	end)
end

local function OnSocketInfoClose()
	if not applying then return end
	C_Timer.After(0.3, ProcessNextItem)
end

ProcessNextItem = function()
	applyIndex = applyIndex + 1
	if applyIndex > #applyQueue then
		applying   = false
		applyReady = false
		wipe(applyQueue)
		ClearAllPending()
		C_Timer.After(0.5, RefreshContent)
		return
	end
	applyReady = false
	SocketInventoryItem(applyQueue[applyIndex].slotID)
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
		RefreshContent()
		return
	end
	applying   = true
	applyIndex = 0
	applyQueue = groups
	ProcessNextItem()
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

	row:SetScript('OnEnter', function(self)
		self:SetBackdropBorderColor(Colors.GetAccent())
		if self._slotID then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetInventoryItem('player', self._slotID)
			GameTooltip:Show()
		end
	end)
	row:SetScript('OnLeave', function(self)
		self:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
		GameTooltip:Hide()
	end)
	return row
end

local function CreateSocketRow(parent)
	local row = MakeRowButton(parent, SOCKET_HEIGHT, {0.06, 0.06, 0.06, 0.5}, {0.1, 0.1, 0.1, 0})

	local iconBorder = MakeIconFrame(row, 20, 16)
	iconBorder:SetPoint('LEFT', INDENT, 0)
	iconBorder:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
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

	row:SetScript('OnEnter', function(self)
		self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
		if self._gemItemID then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetItemByID(self._gemItemID)
			GameTooltip:Show()
		end
	end)
	row:SetScript('OnLeave', function(self)
		if self._pendingKey and pendingByKey[self._pendingKey] then
			self:SetBackdropBorderColor(0.2, 0.7, 0.2, 0.5)
		else
			self:SetBackdropBorderColor(0.1, 0.1, 0.1, 0)
		end
		GameTooltip:Hide()
	end)

	row:SetScript('OnClick', function(self)
		if not self._slotID or not self._socketIdx then return end

		if pendingByKey[PendingKey(self._slotID, self._socketIdx)] then
			RemovePending(self._slotID, self._socketIdx)
			RefreshContent()
			return
		end

		if selectedBagGemID and self._empty then
			local gem = FindBagGem(selectedBagGemID)
			if gem and GemAvailable(gem.itemID) > 0 then
				AddPending(self._slotID, self._socketIdx, gem.itemID, gem.icon, gem.name, gem.quality)
			end
			selectedBagGemID = nil
			RefreshContent()
		end
	end)

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

	row:SetScript('OnEnter', function(self)
		if self._itemID ~= selectedBagGemID then
			self:SetBackdropBorderColor(Colors.GetAccent())
		end
		if self._itemID then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetItemByID(self._itemID)
			GameTooltip:Show()
		end
	end)
	row:SetScript('OnLeave', function(self)
		if self._itemID == selectedBagGemID then
			self:SetBackdropBorderColor(Colors.GetAccent())
		else
			self:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)
		end
		GameTooltip:Hide()
	end)
	row:SetScript('OnClick', function(self)
		if not self._itemID or GemAvailable(self._itemID) <= 0 then return end
		if selectedBagGemID == self._itemID then
			selectedBagGemID = nil
		else
			selectedBagGemID = self._itemID
		end
		RefreshContent()
	end)

	row:RegisterForDrag('LeftButton')
	row:SetScript('OnDragStart', function(self)
		if not self._itemID or GemAvailable(self._itemID) <= 0 then return end
		StartGemDrag(self._itemID, self.icon:GetTexture())
	end)
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
	frame:SetScript('OnEnter', function(self)
		if self._gemName then
			Widget.ShowTip(self, self._gemName .. '  |  Socketed: ' .. (self._count or 1))
		end
	end)
	frame:SetScript('OnLeave', function() Widget.HideTip() end)
	return frame
end

local function BuildPanel()
	if panel then return end

	local panelFrame = Widget.New(UIParent, 'Frame', nil, { bg = Colors.bg.dark, border = Colors.border.light, size = { PANEL_WIDTH, 400 } }).frame
	panelFrame:SetFrameStrata('HIGH')
	panelFrame:SetFrameLevel(50)
	panelFrame:SetClampedToScreen(false)
	panelFrame:Hide()
	panel = panelFrame

	BUI.Skinning.CreateTitleBar(panelFrame, 'Gem Manager', 36, function() CloseSlide() end)
	local toolbar = CreateFrame('Frame', nil, panelFrame)
	toolbar:SetPoint('TOPLEFT', 12, -40)
	toolbar:SetPoint('TOPRIGHT', -12, -40)
	toolbar:SetHeight(Pixel.Scale(30))

	panelFrame.searchBox = BUI.Skinning.CreateSearchBox(panelFrame, 240, function(text) searchText = text; RefreshContent() end)
	panelFrame.searchBox:SetPoint('TOPLEFT', toolbar, 'TOPLEFT')

	local function RankLabel(rank)
		local color = ITEM_QUALITY_COLORS[rank]
		local name = _G['ITEM_QUALITY' .. rank .. '_DESC'] or ('Quality ' .. rank)
		return (color and color.hex or '') .. name .. '|r'
	end
	panelFrame.filterDD = BUI.Skinning.CreateDropdown(panelFrame, {
		{ label = 'All Qualities', value = 0 },
		{ label = RankLabel(1), value = 1 },
		{ label = RankLabel(2), value = 2 },
		{ label = RankLabel(3), value = 3 },
		{ label = RankLabel(4), value = 4 },
		{ label = RankLabel(5), value = 5 },
	}, function(item) qualityFilter = item.value; RefreshContent() end, 140)
	panelFrame.filterDD:SetPoint('TOPRIGHT', toolbar, 'TOPRIGHT')

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

	panelFrame.clearBtn = Controls.Button(panelFrame, 'Clear', 72, function() ClearAllPending(); RefreshContent() end)
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
	local gems = summary.gemCounts

	local shownCount = #gems > STRIP_MAX_ICONS and (STRIP_MAX_ICONS - 1) or #gems
	for gemIndex = 1, shownCount do
		local gem = gems[gemIndex]
		if not panel.gemIcons[gemIndex] then panel.gemIcons[gemIndex] = CreateGemIcon(panel.gemStrip) end
		local gemIcon = panel.gemIcons[gemIndex]
		gemIcon:ClearAllPoints()
		gemIcon:SetPoint('LEFT', (gemIndex - 1) * STRIP_ICON_GAP, 0)
		gemIcon.icon:SetTexture(gem.gemIcon or FALLBACK_ICON)
		gemIcon:SetBackdropBorderColor(QualityColor(gem.gemQuality))
		gemIcon.count:SetText(gem.count > 1 and gem.count or '')
		gemIcon._gemName = gem.gemName
		gemIcon._count   = gem.count
		gemIcon:Show()
	end
	for gemIndex = shownCount + 1, #panel.gemIcons do panel.gemIcons[gemIndex]:Hide() end

	if not panel.gemOverflowText then
		panel.gemOverflowText = MakeLabel(panel.gemStrip, 10)
		panel.gemOverflowText:SetTextColor(0.6, 0.6, 0.6)
	end
	if #gems > shownCount then
		panel.gemOverflowText:ClearAllPoints()
		panel.gemOverflowText:SetPoint('LEFT', shownCount * STRIP_ICON_GAP + Pixel.Scale(2), 0)
		panel.gemOverflowText:SetText('+' .. (#gems - shownCount))
		panel.gemOverflowText:Show()
	else
		panel.gemOverflowText:Hide()
	end

	local emptyCount = summary.emptySockets
	local emptyColor = emptyCount > 0 and 'ffee5555' or 'ff55cc55'
	local separator = '  |cff444444||  '
	panel.statsText:SetText(
		'|c' .. emptyColor .. emptyCount .. '|r |cff888888Empty|r' .. separator ..
		'|cffffffff' .. summary.totalSocketed .. '|r |cff888888Socketed|r' .. separator ..
		'|cffffffff' .. summary.uniqueGemCount .. '|r |cff888888Unique|r' .. separator ..
		'|cffffffff' .. summary.totalBagGems .. '|r |cff888888in Bags|r'
	)

	local hasPendingChanges = HasPending()
	panel.applyBtn:SetAlpha(hasPendingChanges and 1 or 0.3)
	panel.applyBtn:EnableMouse(hasPendingChanges)
	panel.clearBtn:SetAlpha(hasPendingChanges and 1 or 0.3)
	panel.clearBtn:EnableMouse(hasPendingChanges)

	if selectedBagGemID then
		local gem = FindBagGem(selectedBagGemID)
		panel.hintText:SetText('Click a socket to assign: ' .. (gem and gem.name or ''))
		panel.hintText:Show()
	else
		panel.hintText:Hide()
	end
end

local function MatchesSearch(item, search)
	local itemName = item.itemName or ''
	if itemName:lower():find(search, 1, true) then return true end
	for _, socket in ipairs(item.sockets) do
		if socket.gemName and socket.gemName:lower():find(search, 1, true) then return true end
		local pending = pendingByKey[PendingKey(item.slotID, socket.index)]
		if pending and pending.gemName:lower():find(search, 1, true) then return true end
	end
	return false
end

local function RefreshEquipped()
	local child       = panel.leftChild
	local headerIndex = 0
	local socketIndex = 0
	local cursorY     = 0
	local search      = searchText:lower()

	for _, item in ipairs(equippedData) do
		if search == '' or MatchesSearch(item, search) then
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
				local key = PendingKey(item.slotID, socket.index)
				socketRow:ClearAllPoints()
				socketRow:SetPoint('TOPLEFT', 0, -cursorY)
				socketRow:SetPoint('RIGHT')
				socketRow._slotID     = item.slotID
				socketRow._socketIdx  = socket.index
				socketRow._pendingKey = key
				socketRow._empty      = false
				socketRow._gemItemID  = nil
				allSocketRows[#allSocketRows + 1] = socketRow

				socketRow.icon:SetTexture(0)
				socketRow.icon:SetTexCoord(unpack(TEXTURE_CROP))
				socketRow.qualPip:Hide()
				socketRow:SetBackdropColor(0.06, 0.06, 0.06, 0.5)
				socketRow:SetBackdropBorderColor(0.1, 0.1, 0.1, 0)
				socketRow.iconBorder:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

				local pending = pendingByKey[key]
				if pending then
					local qualityRed, qualityGreen, qualityBlue = QualityColor(pending.gemQuality)
					SetIconTexture(socketRow.icon, pending.gemIcon)
					socketRow.nameText:SetText(pending.gemName .. ' |cff55cc55(pending)|r')
					socketRow.nameText:SetTextColor(qualityRed, qualityGreen, qualityBlue)
					socketRow:SetBackdropBorderColor(0.2, 0.7, 0.2, 0.4)
					socketRow.iconBorder:SetBackdropBorderColor(qualityRed, qualityGreen, qualityBlue, 0.8)
					SetQualityAtlas(socketRow.qualPip, pending.gemItemID)
					socketRow._gemItemID = pending.gemItemID
				elseif socket.empty then
					socketRow.icon:SetAtlas('Professions-Icon-Jewel-Empty')
					socketRow.nameText:SetText('Empty Socket')
					socketRow.nameText:SetTextColor(0.9, 0.3, 0.3)
					socketRow.iconBorder:SetBackdropBorderColor(0.5, 0.15, 0.15, 0.8)
					socketRow._empty = true
				else
					SetIconTexture(socketRow.icon, socket.gemIcon)
					socketRow.nameText:SetText(socket.gemName or '')
					local qualityRed, qualityGreen, qualityBlue = QualityColor(socket.gemQuality)
					socketRow.nameText:SetTextColor(qualityRed, qualityGreen, qualityBlue)
					socketRow.iconBorder:SetBackdropBorderColor(qualityRed, qualityGreen, qualityBlue, 0.6)
					SetQualityAtlas(socketRow.qualPip, socket.gemItemID)
					socketRow._gemItemID = socket.gemItemID
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
	local child        = panel.rightChild
	local gemIndex     = 0
	local qualityIndex = 0
	local cursorY      = 0
	local lastQuality  = nil
	local search       = searchText:lower()

	for _, gem in ipairs(bagGemData) do
		local pass = true
		if qualityFilter > 0 and gem.quality ~= qualityFilter then pass = false end
		if pass and search ~= '' and not (gem.name and gem.name:lower():find(search, 1, true)) then pass = false end

		if pass then
			if gem.quality ~= lastQuality then
				lastQuality = gem.quality
				qualityIndex = qualityIndex + 1
				local qualityHeader = PoolGet(qualityPool, qualityIndex, CreateQualityHeader, child)
				qualityHeader:ClearAllPoints()
				qualityHeader:SetPoint('TOPLEFT', 0, -cursorY)
				qualityHeader:SetPoint('RIGHT')
				local red, green, blue = QualityColor(gem.quality)
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
			local red, green, blue = QualityColor(gem.quality)
			row.nameText:SetText(gem.name or '')
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
		panel.rightEmpty:SetText(search ~= '' and 'No matching gems.' or 'No gems in bags.')
	end
end

RefreshContent = function()
	if not panel or not panel:IsShown() then return end
	wipe(allSocketRows)
	ScanEquipped()
	ScanBagGems()
	ComputeSummary()
	RefreshSummary()
	RefreshEquipped()
	RefreshInventory()
end

local ThrottledRefresh = BUI.Dispatcher.NewDelayed(function() RefreshContent() end, 0.3)

local slide = BUI.SlidePanel.New({
	skin = 'gemcounter',
	width = PANEL_WIDTH,
	hiddenX = -PANEL_WIDTH,
	panel = function() return panel end,
	build = function() BuildPanel() end,
	onOpen = function() RefreshContent() end,
})

CloseSlide = function(immediate)
	slide.Close(immediate)
end

local summaryStale = true

function BUI.GemCounter.InvalidateSummary()
	summaryStale = true
end

function BUI.GemCounter.GetEquippedSummary()
	if summaryStale then
		summaryStale = false
		ScanEquipped()
		ComputeSummary()
	end
	return summary
end

function BUI.GemCounter.Toggle()
	if not isInitialized then return end
	slide.Toggle()
end

function BUI.GemCounter.IsOpen()
	return slide.IsOpen()
end

local function OnCharacterHide()
	slide.Close(true)
	ClearAllPending()
end

local fallbackButton

local function UpdateFallbackButton()
	if not fallbackButton then return end
	local skinOn = BUI.Skinning.IsSkinEnabled('characterFrame')
	local gemOn  = BUI.Skinning.IsSkinEnabled('gemcounter')
	fallbackButton:SetShown(gemOn and not skinOn)
end

local function BuildFallbackButton()
	if fallbackButton or not CharacterFrame then return end
	fallbackButton = CreateFrame('Button', nil, CharacterFrame, 'BackdropTemplate')
	fallbackButton:SetSize(28, 28)
	fallbackButton:SetFrameLevel(CharacterFrame:GetFrameLevel() + 5)
	fallbackButton:SetBackdrop({
		bgFile   = 'Interface\\Buttons\\WHITE8x8',
		edgeFile = 'Interface\\Buttons\\WHITE8x8',
		edgeSize = 1,
	})
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

local function OnGemEvent(event)
	BUI.GemCounter.InvalidateSummary()
	if event == 'SOCKET_INFO_UPDATE' then
		OnSocketInfoUpdate()
	elseif event == 'SOCKET_INFO_CLOSE' then
		OnSocketInfoClose()
	elseif panel and panel:IsShown() and not applying then
		ThrottledRefresh()
	end
end

BUI.Events:OnLogin('GemCounter', function()
	isInitialized = true
	if CharacterFrame then
		CharacterFrame:HookScript('OnHide', OnCharacterHide)
		BuildFallbackButton()
		UpdateFallbackButton()
	end

	BUI.Events:Register('BAG_UPDATE_DELAYED',       'GemCounter', OnGemEvent)
	BUI.Events:Register('PLAYER_EQUIPMENT_CHANGED', 'GemCounter', OnGemEvent)
	BUI.Events:Register('SOCKET_INFO_UPDATE',       'GemCounter', OnGemEvent)
	BUI.Events:Register('SOCKET_INFO_CLOSE',        'GemCounter', OnGemEvent)

	BUI.Skinning.OnToggle('gemcounter', function(enabled)
		if not enabled then
			CloseSlide(true)
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
