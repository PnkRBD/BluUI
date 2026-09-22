local BUI = BluUI
local SetScript, HookScript = BUI.Prof.Scripts('Pages.CDMIconManagement')

local BUILib = BluUI.BUILibClient
local Controls, Layout, Modals, Widget = BUILib.Controls, BUILib.Layout, BUILib.Modals, BUILib.Widget
local Pixel = BUI.Pixel

local GetCooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo

local COLOR_BLUE   = '|cff5599dd'
local COLOR_GREY   = '|cff888888'
local COLOR_YELLOW = '|cffffff00'
local COLOR_GREEN  = '|cff00ff00'
local COLOR_ORANGE = '|cffff8800'
local COLOR_END    = '|r'
local FALLBACK_TEX = 134400

local function ReadTrackedSpells(CDM, viewerKey)
	local set = {}
	local list, count = CDM.GetTrackedIcons(viewerKey)
	if not list then return set end
	for iconIndex = 1, count do
		local icon = list[iconIndex]
		local cooldownInfo = icon and icon.cooldownInfo
		if cooldownInfo then
			if cooldownInfo.spellID then set[cooldownInfo.spellID] = true end
			if cooldownInfo.overrideSpellID then set[cooldownInfo.overrideSpellID] = true end
			if cooldownInfo.linkedSpellIDs then
				for _, linkedID in ipairs(cooldownInfo.linkedSpellIDs) do
					set[linkedID] = true
				end
			end
		end
	end
	return set
end

local function IsInSet(set, spellID, linkedSpellIDs)
	if set[spellID] then return true end
	if linkedSpellIDs then
		for _, linkedID in ipairs(linkedSpellIDs) do
			if set[linkedID] then return true end
		end
	end
	return false
end

local function MarkLinkedSeen(seenSet, linkedSpellIDs)
	if not linkedSpellIDs then return end
	for _, linkedID in ipairs(linkedSpellIDs) do
		seenSet[linkedID] = true
	end
end

local function BuildTag(inOther, otherLabel, notLearned)
	local parts = {}
	if inOther then
		parts[#parts + 1] = COLOR_BLUE .. otherLabel .. COLOR_END
	end
	if notLearned then
		parts[#parts + 1] = COLOR_GREY .. 'Not Learned' .. COLOR_END
	end
	if #parts == 0 then return nil end
	return table.concat(parts, ' + ')
end

local CDM_SECTION_VIEWERS = {
	{ frameName = 'EssentialCooldownViewer', label = 'Essential' },
	{ frameName = 'UtilityCooldownViewer',   label = 'Utility' },
	{ frameName = 'BuffIconCooldownViewer',  label = 'Buffs' },
	{ frameName = 'BuffBarCooldownViewer',   label = 'Bars' },
}

local CDM_SECTION_CATEGORIES = {
	Enum.CooldownViewerCategory.Essential,
	Enum.CooldownViewerCategory.Utility,
	Enum.CooldownViewerCategory.TrackedBuff,
	Enum.CooldownViewerCategory.TrackedBar,
}

local function MapCooldownInfo(map, info, label, displayed)
	local record = map[info.spellID]
	if record then
		if label then record.labels[label] = true end
		if displayed then record.displayed = true end
	else
		record = { labels = {}, displayed = displayed or false }
		if label then record.labels[label] = true end
		map[info.spellID] = record
	end
	if info.linkedSpellIDs then
		for _, linkedID in ipairs(info.linkedSpellIDs) do
			if not map[linkedID] then map[linkedID] = record end
		end
	end
end

local function BuildCDMSectionMap()
	local map = {}
	for _, entry in ipairs(CDM_SECTION_VIEWERS) do
		local viewer = _G[entry.frameName]
		local pool = viewer and viewer.itemFramePool
		if pool and pool.EnumerateActive then
			for frame in pool:EnumerateActive() do
				local info = frame.cooldownInfo
				if info and info.spellID then
					MapCooldownInfo(map, info, entry.label, true)
				end
			end
		end
	end
	if not next(map) then return map end

	local GetCategorySet = C_CooldownViewer.GetCooldownViewerCategorySet
	for _, category in ipairs(CDM_SECTION_CATEGORIES) do
		local allIDs = GetCategorySet(category, true)
		if allIDs then
			for _, cdID in ipairs(allIDs) do
				local info = GetCooldownInfo(cdID)
				local spellID = info and info.spellID
				if spellID and not map[spellID] then
					local linkedHit = false
					if info.linkedSpellIDs then
						for _, lid in ipairs(info.linkedSpellIDs) do
							if map[lid] then linkedHit = true; break end
						end
					end
					local known = info.isKnown
					if known == nil then
						known = C_SpellBook.IsSpellKnown(spellID)
					end
					if not linkedHit and known then
						MapCooldownInfo(map, info, nil, false)
					end
				end
			end
		end
	end
	return map
end

local function CollectTrackedIcons(CDM, viewerKey, viewerSettings, icons, seen, customSeen)
	local list, count = CDM.GetTrackedIcons(viewerKey)
	if not list or not count then return end
	local overrides = CDM.GetIconOverrides(viewerSettings)

	for i = 1, count do
		local icon = list[i]
		local frameData = CDM.FrameData[icon]
		local isVisible = icon:IsShown()
		if isVisible and not (frameData and frameData.customIcon) then
			local cooldownInfo = icon.cooldownInfo
			local spellID = cooldownInfo and cooldownInfo.spellID
			if spellID and (not seen[spellID] or customSeen[spellID]) and not seen['blizz:'..spellID] then
				seen['blizz:'..spellID] = true
				local displayID = cooldownInfo.overrideSpellID or spellID
				icons[#icons + 1] = {
					id = spellID,
					name = C_Spell.GetSpellName(displayID) or C_Spell.GetSpellName(spellID) or ('Spell ' .. spellID),
					icon = overrides[spellID] or C_Spell.GetSpellTexture(displayID) or C_Spell.GetSpellTexture(spellID) or FALLBACK_TEX,
					defaultIcon = C_Spell.GetSpellTexture(displayID) or C_Spell.GetSpellTexture(spellID) or FALLBACK_TEX,
					isCustom = false,
					layoutIndex = icon.layoutIndex or 99999,
				}
			end
		end
	end
end

local function BuildRacialSlotEntry(slotNum, Custom, CDM, viewerSettings)
	local resolvedID = CDM.ResolveRacialSlot(slotNum)
	local stored = 'racial:' .. slotNum
	local slotLabel = 'Racial'
	local displayName, displayIcon
	local isBlacklisted = false
	if resolvedID then
		displayName = (C_Spell.GetSpellName(resolvedID) or ('Spell ' .. resolvedID)) .. ' [' .. slotLabel .. ']'
		displayIcon = C_Spell.GetSpellTexture(resolvedID) or FALLBACK_TEX
		if viewerSettings and CDM.IsRacialBlacklisted(viewerSettings, resolvedID) then
			isBlacklisted = true
		end
	else
		displayName = slotLabel .. ' [None]'
		displayIcon = 134400
	end
	return {
		id = stored,
		numericId = resolvedID,
		name = displayName,
		icon = displayIcon,
		defaultIcon = displayIcon,
		isCustom = true,
		isItem = false,
		isPermanent = true,
		isBlacklisted = isBlacklisted,
		unavailableTag = (not isBlacklisted) and CDM.GetUnavailableTag(stored, false) or nil,
		layoutIndex = 190009 + slotNum,
	}
end

local function BuildTrinketSlotEntry(slotNum, Custom, CDM, viewerSettings)
	local inv = slotNum == 1 and 13 or 14
	local resolvedID = GetInventoryItemID('player', inv)
	local stored = 'trinket:' .. slotNum
	local slotLabel = 'Trinket Slot ' .. slotNum
	local displayName, displayIcon
	local isBlacklisted = false
	local isHiddenPassive = false
	if resolvedID then
		local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(resolvedID)
		if not itemIcon then
			local _, _, _, _, instant = GetItemInfoInstant(resolvedID)
			itemIcon = instant
			C_Item.RequestLoadItemDataByID(resolvedID)
		end
		displayName = (itemName or 'Item ' .. resolvedID) .. ' [' .. slotLabel .. ']'
		displayIcon = itemIcon or FALLBACK_TEX
		if viewerSettings and CDM.IsTrinketBlacklisted(viewerSettings, resolvedID) then
			isBlacklisted = true
		end
		if not BUI.IconEngine.IsOnUseTrinketSlot(slotNum) then
			isHiddenPassive = true
		end
	else
		displayName = slotLabel .. ' [Empty]'
		displayIcon = 134400
	end
	return {
		id = stored,
		numericId = resolvedID,
		name = displayName,
		icon = displayIcon,
		defaultIcon = displayIcon,
		isCustom = true,
		isItem = true,
		isPermanent = true,
		isBlacklisted = isBlacklisted,
		isHiddenPassive = isHiddenPassive,
		unavailableTag = (not isBlacklisted) and CDM.GetUnavailableTag(stored, true) or nil,
		layoutIndex = 190000 + slotNum,
	}
end

local function CollectCustomIcons(CDM, viewerSettings, icons, seen, customSeen, viewerKey)
	local customSpells = CDM.GetCustomSpells(viewerSettings)
	local Custom = CDM.Custom
	local overrides = CDM.GetIconOverrides(viewerSettings)

	if viewerKey == 'essential' then
		icons[#icons + 1] = BuildTrinketSlotEntry(1, Custom, CDM, viewerSettings)
		icons[#icons + 1] = BuildTrinketSlotEntry(2, Custom, CDM, viewerSettings)
		seen['trinket:1'] = true
		seen['trinket:2'] = true
	end

	if viewerKey == 'essential' or viewerKey == 'utility' then
		icons[#icons + 1] = BuildRacialSlotEntry(1, Custom, CDM, viewerSettings)
		seen['racial:1'] = true
	end

	for i, stored in ipairs(customSpells) do
		if not seen[stored] then
			seen[stored] = true

			local numId = tonumber(tostring(stored):match('%d+'))
			if numId then customSeen[numId] = true end

			local isItemPrefix = type(stored) == 'string' and stored:match('^item:') ~= nil
			local id = isItemPrefix and tonumber(stored:match('^item:(%d+)')) or tonumber(stored)

			if id then
				local overrideIcon = overrides[stored] or overrides[id]
				local isItem = isItemPrefix
				local itemName, itemLink, itemIcon

				if isItemPrefix then
					itemName, itemLink, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(id)
					if not itemIcon then
						local _, _, _, _, instant = GetItemInfoInstant(id)
						itemIcon = instant
						C_Item.RequestLoadItemDataByID(id)
					end
				else
					local isKnownSpell = C_SpellBook.IsSpellKnown(id)
					if not isKnownSpell and viewerKey ~= "buffs" then
						itemName, itemLink, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(id)
						local count = C_Item.GetItemCount(id, true)
						isItem = itemName and (count and count > 0 or IsEquippedItem(id))
					end
				end

				local rank = itemLink and BUI.Lookup.CraftedQuality(id) or 0
				local rankTag = rank > 0 and (' R' .. rank) or ''

				local displayID = id
				if viewerKey ~= 'buffs' and not isItem then
					local activeID = BUI.Tools.GetActiveChoice(id)
					if activeID and activeID ~= id and C_SpellBook.IsSpellKnown(activeID) then
						displayID = activeID
					end
				end

				local displayName, displayIcon
				if isItem and itemName then
					displayName = itemName .. ' [Item' .. rankTag .. ']'
					displayIcon = overrideIcon or itemIcon or FALLBACK_TEX
				elseif isItem then
					displayName = 'Item ' .. id .. ' [Item' .. rankTag .. ']'
					displayIcon = overrideIcon or FALLBACK_TEX
				else
					local spellName = C_Spell.GetSpellName(displayID) or C_Spell.GetSpellName(id) or ('Spell ' .. id)
					displayName = spellName .. ' [Spell]'
					displayIcon = overrideIcon or C_Spell.GetSpellTexture(displayID) or C_Spell.GetSpellTexture(id) or FALLBACK_TEX
				end

				icons[#icons + 1] = {
					id = stored,
					numericId = id,
					name = displayName,
					icon = displayIcon,
					defaultIcon = isItem and (itemIcon or FALLBACK_TEX) or (C_Spell.GetSpellTexture(id) or FALLBACK_TEX),
					isCustom = true,
					isItem = isItem,
					unavailableTag = viewerKey ~= 'buffs' and CDM.GetUnavailableTag(stored, isItem) or nil,
					layoutIndex = 100000 + i,
				}
			end
		end
	end
end

local function CollectCooldownViewerSpells(CDM, viewerKey, icons, seen, customSeen)
	local GetCategorySet = C_CooldownViewer.GetCooldownViewerCategorySet
	local seenNumeric = {}
	for _, entry in ipairs(icons) do
		if not entry.isCustom then
			local numericID = entry.numericId or entry.id
			if type(numericID) == 'number' then seenNumeric[numericID] = true end
		end
	end

	if viewerKey == 'buffs' then
		local catSeen = {}
		for _, cat in ipairs({ Enum.CooldownViewerCategory.TrackedBuff, Enum.CooldownViewerCategory.TrackedBar }) do
			local allIDs = GetCategorySet(cat, true)
			if allIDs then
				local enabledSet = {}
				local enabledIDs = GetCategorySet(cat, false)
				if enabledIDs then for _, cdID in ipairs(enabledIDs) do enabledSet[cdID] = true end end

				for _, cdID in ipairs(allIDs) do
					local info = GetCooldownInfo(cdID)
					if info then
						local spellID = info.spellID
						local linkedCollision = false
						if info.linkedSpellIDs then
							for _, lid in ipairs(info.linkedSpellIDs) do
								if catSeen[lid] then linkedCollision = true; break end
							end
						end
						MarkLinkedSeen(catSeen, info.linkedSpellIDs)

						if not seenNumeric[spellID] and not catSeen[spellID] and not linkedCollision then
							seenNumeric[spellID] = true
							catSeen[spellID] = true
							local displayed = enabledSet[cdID]
							local known = info.isKnown
							if known == nil then
								known = C_SpellBook.IsSpellKnown(spellID)
							end
							local notLearned = not known
							local notDisplayed = known and not displayed

							icons[#icons + 1] = {
								id = spellID,
								name = C_Spell.GetSpellName(spellID) or ('Spell ' .. spellID),
								icon = C_Spell.GetSpellTexture(spellID) or FALLBACK_TEX,
								defaultIcon = C_Spell.GetSpellTexture(spellID) or FALLBACK_TEX,
								isCustom = false,
								isUnlearned = notLearned,
								isNotDisplayed = notDisplayed,
								hasCustomDuplicate = customSeen and customSeen[spellID] or false,
								isCooldownViewerExtra = true,
								unavailableTag = BuildTag(false, nil, notLearned),
								layoutIndex = 200000 + cdID,
							}
						end
					end
				end
			end
		end
		return
	end

	local otherKey, otherLabel
	if viewerKey == 'essential' then
		otherKey = 'utility'
		otherLabel = 'In Utility'
	else
		otherKey = 'essential'
		otherLabel = 'In Essentials'
	end

	local ownPool = ReadTrackedSpells(CDM, viewerKey)
	local otherPool = ReadTrackedSpells(CDM, otherKey)

	local classCdIDs = {}
	for _, cat in ipairs({ Enum.CooldownViewerCategory.Essential, Enum.CooldownViewerCategory.Utility }) do
		local ids = GetCategorySet(cat, true)
		if ids then
			for _, cdID in ipairs(ids) do
				classCdIDs[cdID] = true
			end
		end
	end

	for cdID in pairs(classCdIDs) do
		local info = GetCooldownInfo(cdID)
		if info then
			local spellID = info.spellID
			local linkedCollision = false
			if info.linkedSpellIDs then
				for _, lid in ipairs(info.linkedSpellIDs) do
					if seenNumeric[lid] then linkedCollision = true; break end
				end
			end
			MarkLinkedSeen(seenNumeric, info.linkedSpellIDs)

			if not seenNumeric[spellID] and not linkedCollision then
				seenNumeric[spellID] = true

				local known = C_SpellBook.IsSpellKnown(spellID)
				local inOwnPool = IsInSet(ownPool, spellID, info.linkedSpellIDs)
				local inOtherPool = IsInSet(otherPool, spellID, info.linkedSpellIDs)
				local inOther = inOtherPool
				local notDisplayed = known and not inOwnPool and not inOtherPool

				icons[#icons + 1] = {
					id = spellID,
					name = C_Spell.GetSpellName(spellID) or ('Spell ' .. spellID),
					icon = C_Spell.GetSpellTexture(spellID) or FALLBACK_TEX,
					defaultIcon = C_Spell.GetSpellTexture(spellID) or FALLBACK_TEX,
					isCustom = false,
					isUnlearned = not known,
					isInOtherViewer = inOther,
					isNotDisplayed = notDisplayed,
					isCooldownViewerExtra = true,
					unavailableTag = BuildTag(inOther, otherLabel, not known),
					layoutIndex = 200000 + cdID,
				}
			end
		end
	end
end

local function GetDataSortKey(data)
	if data.isCustom and not data.isPermanent then
		local numId = data.numericId or (type(data.id) == 'number' and data.id)
		if numId then return 'custom:' .. numId end
	end
	return data.id
end

local function SortIcons(CDM, viewerSettings, icons)
	local order = CDM.GetIconOrder(viewerSettings) or {}
	if #order == 0 then
		table.sort(icons, function(a, b) return (a.layoutIndex or 99999) < (b.layoutIndex or 99999) end)
		return
	end
	local pos = {}
	for i, key in ipairs(order) do pos[key] = i end
	table.sort(icons, function(a, b)
		local posA = pos[GetDataSortKey(a)] or pos[a.id] or 99999
		local posB = pos[GetDataSortKey(b)] or pos[b.id] or 99999
		if posA ~= posB then return posA < posB end
		return (a.layoutIndex or 99999) < (b.layoutIndex or 99999)
	end)
end

local function ParseDurationFromText(text)
	if not text or text == '' then return nil end
	local sec = text:match('for (%d+%.?%d*) sec')
		or text:match('lasting (%d+%.?%d*) sec')
		or text:match('(%d+%.?%d*) sec duration')
		or text:match('(%d+%.?%d*) sec%.')
	return sec and tonumber(sec) or nil
end

local function ParseDurationFromDescription(spellID)
	local raw = tostring(spellID)
	local isItem = raw:match('^item:')
	local numID = tonumber(raw:match('%d+'))
	if not numID then return nil end

	local desc = C_Spell.GetSpellDescription(numID)
	local dur = ParseDurationFromText(desc)
	if dur then return dur end

	if isItem or not C_SpellBook.IsSpellKnown(numID) then
		local _, sid = GetItemSpell(numID)
		if sid then
			desc = C_Spell.GetSpellDescription(sid)
			dur = ParseDurationFromText(desc)
			if dur then return dur end
		end
		local scanner = _G['BUI_DurScanner']
		if not scanner then
			scanner = CreateFrame('GameTooltip', 'BUI_DurScanner', nil, 'GameTooltipTemplate')
			scanner:SetOwner(UIParent, 'ANCHOR_NONE')
		end
		scanner:ClearLines()
		scanner:SetItemByID(numID)
		for i = 1, scanner:NumLines() do
			local line = _G['BUI_DurScannerTextLeft' .. i]
			local text = line and line:GetText()
			dur = ParseDurationFromText(text)
			if dur then return dur end
		end
	end

	return nil
end

local function ShowTrinketSlotModal(CDM, viewerSettings, storedValue, RefreshIconList)
	local slotNum = tonumber(storedValue:match('^trinket:(%d)$'))
	local inv = slotNum == 1 and 13 or 14
	local equippedID = GetInventoryItemID('player', inv)
	local itemName = equippedID and C_Item.GetItemNameByID(equippedID) or 'Empty'

	local overlay, dialog, Close = Modals.CreateBase(400, 360, true, BUI.PageEngine.window.frame)
	Modals.CreateTitle(dialog, 'Trinket Slot ' .. slotNum)

	local info = dialog:CreateFontString(nil, 'OVERLAY')
	info:SetFont(BUILib.Font, 12, '')
	info:SetPoint('TOPLEFT', dialog, 'TOPLEFT', Pixel.Scale(30), Pixel.Scale(-52))
	info:SetText('|cffaaaaaaCurrent:|r ' .. itemName)

	local blHeader = dialog:CreateFontString(nil, 'OVERLAY')
	blHeader:SetFont(BUILib.Font, 13, 'OUTLINE')
	blHeader:SetText('Blacklist')
	blHeader:SetPoint('TOPLEFT', info, 'BOTTOMLEFT', 0, Pixel.Scale(-16))

	local blHint = dialog:CreateFontString(nil, 'OVERLAY')
	blHint:SetFont(BUILib.Font, 10, '')
	blHint:SetTextColor(0.55, 0.55, 0.55)
	blHint:SetText('Blacklisted trinkets are ignored when equipped in this slot.')
	blHint:SetPoint('TOPLEFT', blHeader, 'BOTTOMLEFT', 0, Pixel.Scale(-4))

	local blList
	local function RebuildBlList()
		blList:ClearItems()
		local map = CDM.GetTrinketBlacklist(viewerSettings)
		for itemID in pairs(map) do
			local iName, _, _, _, _, _, _, _, _, iIcon = C_Item.GetItemInfo(itemID)
			if not iIcon then
				local _, _, _, _, instant = GetItemInfoInstant(itemID)
				iIcon = instant
				C_Item.RequestLoadItemDataByID(itemID)
			end
			blList:AddItem(iIcon or 134400, iName or ('Item ' .. itemID), itemID, true, true)
		end
	end

	local curBtnLabel = equippedID and 'Blacklist Current Trinket' or 'No Trinket Equipped'
	local curBtn = Controls.Button(dialog, curBtnLabel, 200, function()
		if not equippedID then return end
		CDM.SetTrinketBlacklisted(viewerSettings, equippedID, true)
		RebuildBlList()
		CDM.Custom.Refresh('essential')
		RefreshIconList()
	end)
	local curBtnFrame = curBtn.frame
	curBtnFrame:SetPoint('TOPLEFT', blHint, 'BOTTOMLEFT', 0, Pixel.Scale(-8))
	if not equippedID then curBtnFrame:SetEnabled(false) end

	blList = Controls.ItemList(dialog, nil, 340, 140, nil, function(row)
		if row and row.id then
			CDM.SetTrinketBlacklisted(viewerSettings, row.id, nil)
			RebuildBlList()
			CDM.Custom.Refresh('essential')
			RefreshIconList()
		end
	end, nil, nil, false, nil, true)
	local blListFrame = blList.frame
	blListFrame:SetPoint('TOPLEFT', curBtnFrame, 'BOTTOMLEFT', 0, Pixel.Scale(-8))
	RebuildBlList()

	SetScript(overlay, 'OnKeyDown', function(_, key) if key == 'ESCAPE' then Close() end end)
	Modals.LayoutButtons(dialog, {
		{ text = 'Close', color = Modals.BTN_CONFIRM, onClick = function(close)
			close()
			RefreshIconList()
		end },
	}, Close)
end

local function ShowRacialSlotModal(CDM, viewerSettings, viewerKey, storedValue, RefreshIconList)
	local slotNum = tonumber(storedValue:match('^racial:(%d)$'))
	local resolvedID = CDM.ResolveRacialSlot(slotNum)
	local spellName = resolvedID and C_Spell.GetSpellName(resolvedID) or 'None'

	local overlay, dialog, Close = Modals.CreateBase(400, 360, true, BUI.PageEngine.window.frame)
	Modals.CreateTitle(dialog, 'Racial Slot')

	local info = dialog:CreateFontString(nil, 'OVERLAY')
	info:SetFont(BUILib.Font, 12, '')
	info:SetPoint('TOPLEFT', dialog, 'TOPLEFT', Pixel.Scale(30), Pixel.Scale(-52))
	info:SetText('|cffaaaaaaCurrent:|r ' .. spellName)

	local blHeader = dialog:CreateFontString(nil, 'OVERLAY')
	blHeader:SetFont(BUILib.Font, 13, 'OUTLINE')
	blHeader:SetText('Blacklist')
	blHeader:SetPoint('TOPLEFT', info, 'BOTTOMLEFT', 0, Pixel.Scale(-16))

	local blHint = dialog:CreateFontString(nil, 'OVERLAY')
	blHint:SetFont(BUILib.Font, 10, '')
	blHint:SetTextColor(0.55, 0.55, 0.55)
	blHint:SetText('Blacklisted racials are ignored in this viewer.')
	blHint:SetPoint('TOPLEFT', blHeader, 'BOTTOMLEFT', 0, Pixel.Scale(-4))

	local blList
	local function RebuildBlList()
		blList:ClearItems()
		local map = CDM.GetRacialBlacklist(viewerSettings)
		for spellID in pairs(map) do
			local sName = C_Spell.GetSpellName(spellID) or ('Spell ' .. spellID)
			local sIcon = C_Spell.GetSpellTexture(spellID) or 134400
			blList:AddItem(sIcon, sName, spellID, true, true)
		end
	end

	local curBtnLabel = resolvedID and 'Blacklist Current Racial' or 'No Racial Known'
	local curBtn = Controls.Button(dialog, curBtnLabel, 200, function()
		if not resolvedID then return end
		CDM.SetRacialBlacklisted(viewerSettings, resolvedID, true)
		RebuildBlList()
		CDM.Custom.Refresh(viewerKey)
		RefreshIconList()
	end)
	local curBtnFrame = curBtn.frame
	curBtnFrame:SetPoint('TOPLEFT', blHint, 'BOTTOMLEFT', 0, Pixel.Scale(-8))
	if not resolvedID then curBtnFrame:SetEnabled(false) end

	blList = Controls.ItemList(dialog, nil, 340, 140, nil, function(row)
		if row and row.id then
			CDM.SetRacialBlacklisted(viewerSettings, row.id, nil)
			RebuildBlList()
			CDM.Custom.Refresh(viewerKey)
			RefreshIconList()
		end
	end, nil, nil, false, nil, true)
	local blListFrame = blList.frame
	blListFrame:SetPoint('TOPLEFT', curBtnFrame, 'BOTTOMLEFT', 0, Pixel.Scale(-8))
	RebuildBlList()

	SetScript(overlay, 'OnKeyDown', function(_, key) if key == 'ESCAPE' then Close() end end)
	Modals.LayoutButtons(dialog, {
		{ text = 'Close', color = Modals.BTN_CONFIRM, onClick = function(close)
			close()
			RefreshIconList()
		end },
	}, Close)
end

local SOUND_OPTIONS = {
	{ value = 0, text = 'None' },
	{ value = 8959, text = 'Raid Warning' },
	{ value = 12889, text = 'Alarm Clock' },
	{ value = 8960, text = 'Ready Check' },
	{ value = 8174, text = 'Flag Taken' },
	{ value = 878, text = 'Quest Complete' },
	{ value = 888, text = 'Level Up' },
	{ value = 12867, text = 'Power Aura' },
}

local function ShowManualBuffModal(CDM, viewerSettings, viewerKey, spellID, RefreshIconList, onCommit)
	local existingData, existingScope = CDM.GetManualBuffScope(viewerSettings, spellID)
	local existing = existingData or {}
	local saveGlobally = existingScope == 'global'
	local raw = tostring(spellID)
	local isItem = raw:match('^item:')
	local numID = tonumber(raw:match('%d+'))
	local spellName, defaultIcon
	if isItem and numID then
		spellName = C_Item.GetItemNameByID(numID) or C_Spell.GetSpellName(numID) or raw
		local _, _, _, _, icon = C_Item.GetItemInfoInstant(numID)
		defaultIcon = icon or C_Spell.GetSpellTexture(numID) or 134400
	else
		spellName = numID and C_Spell.GetSpellName(numID) or raw
		defaultIcon = numID and C_Spell.GetSpellTexture(numID) or 134400
	end

	local autoDur = ParseDurationFromDescription(spellID)
	local defaultDur = existing.duration or autoDur

	local overlay, dialog, Close = Modals.CreateBase(400, 500, true, BUI.PageEngine.window.frame)
	Modals.CreateTitle(dialog, 'Manual Buff')

	local PAD = 30
	local inputW = dialog:GetWidth() - PAD * 2
	local halfW = (inputW - 10) / 2
	local SECTION_GAP = 18
	local ITEM_GAP = 6
	local LABEL_GAP = 4

	local preview = dialog:CreateTexture(nil, 'ARTWORK')
	preview:SetSize(36, 36)
	preview:SetPoint('TOPLEFT', dialog, 'TOPLEFT', PAD, -52)
	preview:SetTexture(existing.icon or defaultIcon)
	preview:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	local previewBorder = CreateFrame('Frame', nil, dialog, 'BackdropTemplate')
	previewBorder:SetPoint('TOPLEFT', preview, 'TOPLEFT', -1, 1)
	previewBorder:SetPoint('BOTTOMRIGHT', preview, 'BOTTOMRIGHT', 1, -1)
	previewBorder:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 })
	previewBorder:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	local nameText = dialog:CreateFontString(nil, 'OVERLAY')
	nameText:SetFont(BUILib.Font, 14, '')
	nameText:SetPoint('TOPLEFT', preview, 'TOPRIGHT', 12, -2)
	nameText:SetText(spellName)
	nameText:SetTextColor(1, 0.82, 0)

	local idText = dialog:CreateFontString(nil, 'OVERLAY')
	idText:SetFont(BUILib.Font, 11, '')
	idText:SetPoint('TOPLEFT', nameText, 'BOTTOMLEFT', 0, -2)
	idText:SetText('|cff888888ID: ' .. tostring(spellID) .. '|r')

	local Tools = BUI.Tools
	local lastAnchor = preview
	if numID and not isItem then
		local overrideID = Tools.GetOverrideSpell(numID)
		if overrideID ~= numID then
			local ovName = C_Spell.GetSpellName(overrideID) or tostring(overrideID)
			local ovIcon = C_Spell.GetSpellTexture(overrideID)

			local ovText = dialog:CreateFontString(nil, 'OVERLAY')
			ovText:SetFont(BUILib.Font, 10, '')
			ovText:SetPoint('TOPLEFT', idText, 'BOTTOMLEFT', 0, -4)
			ovText:SetText('|cff55bbffOverrides to:|r')

			local ovPreview = dialog:CreateTexture(nil, 'ARTWORK')
			ovPreview:SetSize(20, 20)
			ovPreview:SetPoint('LEFT', ovText, 'RIGHT', 6, 0)
			ovPreview:SetTexture(ovIcon or 134400)
			ovPreview:SetTexCoord(0.07, 0.93, 0.07, 0.93)

			local ovNameText = dialog:CreateFontString(nil, 'OVERLAY')
			ovNameText:SetFont(BUILib.Font, 10, '')
			ovNameText:SetPoint('LEFT', ovPreview, 'RIGHT', 4, 0)
			ovNameText:SetText('|cffffffff' .. ovName .. '|r |cff888888(' .. overrideID .. ')|r')

			lastAnchor = ovText
		end
	end

	local durLabel = dialog:CreateFontString(nil, 'OVERLAY')
	durLabel:SetFont(BUILib.Font, 11, '')
	durLabel:SetPoint('TOPLEFT', lastAnchor == preview and preview or lastAnchor, 'BOTTOMLEFT', lastAnchor == preview and 0 or -12, lastAnchor == preview and -SECTION_GAP or -12)
	durLabel:SetText('Duration (sec)')
	durLabel:SetTextColor(0.7, 0.7, 0.7)

	local durInput = Modals.CreateInput(dialog, defaultDur and tostring(defaultDur) or '', halfW)
	durInput:SetPoint('TOPLEFT', durLabel, 'BOTTOMLEFT', 0, -LABEL_GAP)
	durInput:SetAutoFocus(true)
	durInput:SetNumeric(true)

	if autoDur and not existing.duration then
		local hint = dialog:CreateFontString(nil, 'OVERLAY')
		hint:SetFont(BUILib.Font, 9, '')
		hint:SetPoint('BOTTOMRIGHT', durInput, 'TOPRIGHT', 0, 2)
		hint:SetText('|cff00ff00auto-detected|r')
	end

	local iconLabel = dialog:CreateFontString(nil, 'OVERLAY')
	iconLabel:SetFont(BUILib.Font, 11, '')
	iconLabel:SetPoint('TOPLEFT', durLabel, 'TOPLEFT', halfW + 10, 0)
	iconLabel:SetText('Icon ID (optional)')
	iconLabel:SetTextColor(0.7, 0.7, 0.7)

	local iconInput = Modals.CreateInput(dialog, existing.icon and tostring(existing.icon) or '', halfW)
	iconInput:SetPoint('TOPLEFT', iconLabel, 'BOTTOMLEFT', 0, -LABEL_GAP)
	iconInput:SetAutoFocus(false)

	SetScript(iconInput, 'OnTextChanged', function(self)
		preview:SetTexture(tonumber(self:GetText()) or defaultIcon)
	end)

	local buffsSettings = BUI.GetDB().cdm.buffs
	local decCB = Controls.StampCheckbox(dialog, 'Show Decimals', buffsSettings and buffsSettings.showCooldownDecimals or false, function(val)
		if buffsSettings then
			buffsSettings.showCooldownDecimals = val
			CDM.RefreshSkinSettings()
		end
	end)
	local decCBFrame = decCB.frame
	decCBFrame:SetPoint('TOPLEFT', durInput, 'BOTTOMLEFT', 0, -ITEM_GAP)

	local existingGlow = existing.glow or {}
	local globalGlow = BUI.GetDB().cdm.glow
	local glowEnabled = existingGlow.enabled ~= false
	local glowMode = existingGlow.mode or 'always'
	local glowThreshold = existingGlow.threshold or 5
	local glowColor = existingGlow.color
	local glowStyle = existingGlow.style or globalGlow.type or 'pixel'

	local glowCB = Controls.StampCheckbox(dialog, 'Enable Glow', glowEnabled, function(val) glowEnabled = val end)
	local glowCBFrame = glowCB.frame
	glowCBFrame:SetPoint('TOPLEFT', decCBFrame, 'BOTTOMLEFT', 0, -SECTION_GAP)

	local cr, cg, cb, ca = 0.95, 0.95, 0.32, 1
	if glowColor then cr, cg, cb, ca = glowColor[1], glowColor[2], glowColor[3], glowColor[4] or 1 end
	local colorLabel = dialog:CreateFontString(nil, 'OVERLAY')
	colorLabel:SetFont(BUILib.Font, 10, '')
	colorLabel:SetText('Color')
	colorLabel:SetTextColor(0.5, 0.5, 0.5)
	colorLabel:SetPoint('LEFT', glowCBFrame, 'RIGHT', 10, 0)

	local colorSwatch = Controls.ColorSwatch(dialog, {
		r = cr, g = cg, b = cb, a = ca,
		callback = function(r, g, b, a)
			glowColor = { r, g, b, a }
		end,
		width = 18,
	})
	local colorSwatchFrame = colorSwatch.frame
	colorSwatchFrame:SetPoint('LEFT', colorLabel, 'RIGHT', 4, 0)

	local threshInput = Modals.CreateInput(dialog, tostring(glowThreshold), 40)
	threshInput:SetAutoFocus(false)
	threshInput:SetNumeric(true)

	local secLabel = dialog:CreateFontString(nil, 'OVERLAY')
	secLabel:SetFont(BUILib.Font, 11, '')
	secLabel:SetText('sec')
	secLabel:SetTextColor(0.5, 0.5, 0.5)

	local warnCBFrame
	local glowModeDDFrame
	local function UpdateThresholdVisibility()
		local show = glowMode ~= 'always'
		threshInput:SetShown(show)
		secLabel:SetShown(show)
		if warnCBFrame then
			warnCBFrame:ClearAllPoints()
			if show then
				warnCBFrame:SetPoint('TOPLEFT', threshInput, 'BOTTOMLEFT', 0, -SECTION_GAP)
			else
				warnCBFrame:SetPoint('TOPLEFT', glowModeDDFrame, 'BOTTOMLEFT', 0, -SECTION_GAP)
			end
		end
	end

	local glowModeDD = Controls.Dropdown(dialog, nil, {
		{ value = 'always', text = 'Whole Buff' },
		{ value = 'below', text = 'Only While Expiring' },
		{ value = 'above', text = 'Only While Fresh' },
	}, glowMode, function(val)
		glowMode = val
		UpdateThresholdVisibility()
	end, nil, halfW)
	glowModeDDFrame = glowModeDD.frame
	glowModeDDFrame:SetPoint('TOPLEFT', glowCBFrame, 'BOTTOMLEFT', 0, -ITEM_GAP)

	local glowStyleOptions = {}
	for _, def in ipairs(CDM.GLOW_TYPES) do
		table.insert(glowStyleOptions, { value = def.id, text = def.name })
	end
	local glowStyleDD = Controls.Dropdown(dialog, nil, glowStyleOptions, glowStyle, function(val)
		glowStyle = val
	end, nil, halfW)
	local glowStyleDDFrame = glowStyleDD.frame
	glowStyleDDFrame:SetPoint('LEFT', glowModeDDFrame, 'RIGHT', 10, 0)

	threshInput:SetPoint('TOPLEFT', glowModeDDFrame, 'BOTTOMLEFT', 0, -ITEM_GAP)
	secLabel:SetPoint('LEFT', threshInput, 'RIGHT', 4, 0)

	UpdateThresholdVisibility()

	local existingWarning = existingGlow.warning or {}
	local warningEnabled = existingWarning.enabled or false
	local warningText = existingWarning.text or (spellName .. ' EXPIRING!')

	local warnCB = Controls.StampCheckbox(dialog, 'Show Warning Text', warningEnabled, function(val) warningEnabled = val end)
	warnCBFrame = warnCB.frame
	UpdateThresholdVisibility()

	local warningColor = existingWarning.color
	local wcr, wcg, wcb, wca = 1, 0.2, 0.2, 1
	if warningColor then wcr, wcg, wcb, wca = warningColor[1], warningColor[2], warningColor[3], warningColor[4] or 1 end

	local warnColorLabel = dialog:CreateFontString(nil, 'OVERLAY')
	warnColorLabel:SetFont(BUILib.Font, 10, '')
	warnColorLabel:SetText('Color')
	warnColorLabel:SetTextColor(0.5, 0.5, 0.5)
	warnColorLabel:SetPoint('LEFT', warnCBFrame, 'RIGHT', 10, 0)

	local warnColorSwatch = Controls.ColorSwatch(dialog, {
		r = wcr, g = wcg, b = wcb, a = wca,
		callback = function(r, g, b, a)
			warningColor = { r, g, b, a }
		end,
		width = 18,
	})
	local warnSwatchFrame = warnColorSwatch.frame
	warnSwatchFrame:SetPoint('LEFT', warnColorLabel, 'RIGHT', 4, 0)

	local warnInput = Modals.CreateInput(dialog, warningText, inputW)
	warnInput:SetPoint('TOPLEFT', warnCBFrame, 'BOTTOMLEFT', 0, -LABEL_GAP)
	warnInput:SetAutoFocus(false)

	local hintText = dialog:CreateFontString(nil, 'OVERLAY')
	hintText:SetFont(BUILib.Font, 9, '')
	hintText:SetPoint('TOPLEFT', warnInput, 'BOTTOMLEFT', 0, -2)
	hintText:SetText('|cff888888Tags: [time] = countdown, [name] = spell name|r')

	local warningFont = existingWarning.font
	local gridTop = hintText

	local fontLabel = dialog:CreateFontString(nil, 'OVERLAY')
	fontLabel:SetFont(BUILib.Font, 10, '')
	fontLabel:SetText('Font')
	fontLabel:SetTextColor(0.5, 0.5, 0.5)
	fontLabel:SetPoint('TOPLEFT', gridTop, 'BOTTOMLEFT', 0, -12)

	local soundLabel = dialog:CreateFontString(nil, 'OVERLAY')
	soundLabel:SetFont(BUILib.Font, 10, '')
	soundLabel:SetText('Sound')
	soundLabel:SetTextColor(0.5, 0.5, 0.5)
	soundLabel:SetPoint('LEFT', fontLabel, 'LEFT', halfW + 10, 0)

	local warnFontDD = Controls.Dropdown(dialog, nil, BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), warningFont or BUI.C.GLOBAL_OPTION, function(val)
		warningFont = val ~= BUI.C.GLOBAL_OPTION and val or nil
	end, nil, halfW)
	local warnFontDDFrame = warnFontDD.frame
	warnFontDDFrame:SetPoint('TOPLEFT', fontLabel, 'BOTTOMLEFT', 0, -2)

	local warningSound = existingWarning.sound
	local warnSoundDD = Controls.Dropdown(dialog, nil, SOUND_OPTIONS, warningSound or 0, function(val)
		warningSound = val ~= 0 and val or nil
		if val and val ~= 0 then PlaySound(val, 'Master') end
	end, nil, halfW)
	local warnSoundDDFrame = warnSoundDD.frame
	warnSoundDDFrame:SetPoint('TOPLEFT', soundLabel, 'BOTTOMLEFT', 0, -2)

	local scopeDivider = dialog:CreateTexture(nil, 'BACKGROUND')
	scopeDivider:SetSize(inputW, 1)
	scopeDivider:SetColorTexture(0.3, 0.3, 0.3, 1)
	scopeDivider:SetPoint('TOPLEFT', warnFontDDFrame, 'BOTTOMLEFT', 0, -14)

	local scopeHeader = dialog:CreateFontString(nil, 'OVERLAY')
	scopeHeader:SetFont(BUILib.Font, 13, 'OUTLINE')
	scopeHeader:SetText('Save Scope')
	scopeHeader:SetTextColor(1, 1, 1)
	scopeHeader:SetPoint('TOPLEFT', scopeDivider, 'BOTTOMLEFT', 0, -8)

	local perSpecCB, globalCB
	perSpecCB = Controls.StampCheckbox(dialog, 'Per Spec', not saveGlobally, function(val)
		if val then
			saveGlobally = false
			globalCB:SetValue(false)
		else
			perSpecCB:SetValue(true)
		end
	end)
	local perSpecCBFrame = perSpecCB.frame
	perSpecCBFrame:SetPoint('TOPLEFT', scopeHeader, 'BOTTOMLEFT', 0, -6)

	globalCB = Controls.StampCheckbox(dialog, 'Global (all specs)', saveGlobally, function(val)
		if val then
			saveGlobally = true
			perSpecCB:SetValue(false)
		else
			globalCB:SetValue(true)
		end
	end)
	local globalCBFrame = globalCB.frame
	globalCBFrame:SetPoint('LEFT', perSpecCBFrame, 'RIGHT', 110, 0)

	local fired = false
	local function PerformSave()
		fired = true
		local iconID = tonumber(iconInput:GetText())
		local thresh = tonumber(threshInput:GetText()) or 5
		local warnTxt = warnInput:GetText()

		if iconID then
			CDM.SetIconOverride(viewerSettings, spellID, iconID)
		else
			local existingOverrides = CDM.GetIconOverrides(viewerSettings)
			if existingOverrides[spellID] then
				CDM.SetIconOverride(viewerSettings, spellID, nil)
			end
			local pinned = BUI.Tools.GetStableSpellTexture(spellID)
			if pinned then CDM.SetIconOverride(viewerSettings, spellID, pinned) end
		end

		CDM.SetManualBuff(viewerSettings, spellID, {
			duration = tonumber(durInput:GetText()),
			icon = iconID,
			glow = {
				enabled = glowEnabled,
				mode = glowMode,
				color = glowColor,
				style = glowStyle,
				threshold = thresh,
				warning = {
					enabled = warningEnabled,
					text = warnTxt ~= '' and warnTxt or nil,
					color = warningColor,
					font = warningFont,
					sound = warningSound,
				},
			},
		}, saveGlobally)
		Close()
		if onCommit then
			onCommit()
		else
			CDM.Custom.Refresh(viewerKey)
			RefreshIconList()
		end
	end

	local function DoConfirm()
		if fired then return end
		local dur = tonumber(durInput:GetText())
		if not dur or dur <= 0 then
			durInput:SetFocus()
			durInput:SetTextColor(1, 0.3, 0.3)
			BUI.Prof.After('Pages.CDMIconManagement', 0.8, function()
				durInput:SetTextColor(1, 1, 1)
			end)
			return
		end

		if existingScope == 'global' and not saveGlobally then
			Modals.Confirm({
				parent = dialog,
				title = 'Convert to Per Spec?',
				message = 'This buff is currently saved globally. Saving as Per Spec will remove it from all other specs.',
				confirmText = 'Convert', cancelText = 'Cancel',
				onConfirm = function()
					existingScope = 'spec'
					PerformSave()
				end,
			})
			return
		end

		PerformSave()
	end

	SetScript(durInput, 'OnEnterPressed', function() DoConfirm() end)
	SetScript(iconInput, 'OnEnterPressed', function() DoConfirm() end)
	SetScript(overlay, 'OnKeyDown', function(_, key) if key == 'ESCAPE' then Close() end end)
	Modals.LayoutButtons(dialog, {
		{ text = 'Save', color = Modals.BTN_CONFIRM, onClick = function() DoConfirm() end },
		{ text = 'Cancel', color = Modals.BTN_CANCEL, onClick = function(close) close() end },
	}, Close)
end

local function ParseIconValue(text)
	text = (text or ''):gsub('^%s+', ''):gsub('%s+$', '')
	if text == '' then return nil end
	local num = tonumber(text)
	if num then return num end
	if text:find('[\\/]') then return text end
	return 'Interface\\Icons\\' .. text
end

local function ShowIconOverrideModal(CDM, spellID, viewerSettings, onSaved)
	if not viewerSettings then return end
	local spellName = C_Spell.GetSpellName(spellID) or ('Spell ' .. tostring(spellID))
	local defaultIcon = C_Spell.GetSpellTexture(spellID) or FALLBACK_TEX
	local overrides = CDM.GetIconOverrides(viewerSettings)
	local current = overrides[spellID]

	local overlay, dialog, Close = Modals.CreateBase(560, 380, true, BUI.PageEngine.window.frame)
	Modals.CreateTitle(dialog, 'Change Icon')

	BUI.IconSearch.EnsureIndex()

	local PAD = 24
	local inputW = dialog:GetWidth() - PAD * 2

	local preview = dialog:CreateTexture(nil, 'ARTWORK')
	preview:SetSize(36, 36)
	preview:SetPoint('TOPLEFT', dialog, 'TOPLEFT', PAD, -46)
	preview:SetTexture(current or defaultIcon)
	preview:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	local previewBorder = CreateFrame('Frame', nil, dialog, 'BackdropTemplate')
	previewBorder:SetPoint('TOPLEFT', preview, 'TOPLEFT', -1, 1)
	previewBorder:SetPoint('BOTTOMRIGHT', preview, 'BOTTOMRIGHT', 1, -1)
	previewBorder:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 })
	previewBorder:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	local nameText = dialog:CreateFontString(nil, 'OVERLAY')
	nameText:SetFont(BUILib.Font, 14, '')
	nameText:SetPoint('TOPLEFT', preview, 'TOPRIGHT', 12, -2)
	nameText:SetText(spellName)
	nameText:SetTextColor(1, 0.82, 0)

	local idText = dialog:CreateFontString(nil, 'OVERLAY')
	idText:SetFont(BUILib.Font, 11, '')
	idText:SetPoint('TOPLEFT', nameText, 'BOTTOMLEFT', 0, -2)
	idText:SetText('|cff888888ID: ' .. tostring(spellID) .. '|r')

	local input, statusFS, gridHost
	local resultButtons = {}
	local GRID_COLS, GRID_MAX = 12, 24

	local function ResultButton(i)
		local btn = resultButtons[i]
		if not btn then
			btn = CreateFrame('Button', nil, gridHost, 'BackdropTemplate')
			btn:SetSize(30, 30)
			local col = (i - 1) % GRID_COLS
			local line = math.floor((i - 1) / GRID_COLS)
			btn:SetPoint('TOPLEFT', gridHost, 'TOPLEFT', col * 34, -(20 + line * 34))
			btn.tex = btn:CreateTexture(nil, 'ARTWORK')
			btn.tex:SetAllPoints()
			btn.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			btn:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 })
			btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
			SetScript(btn, 'OnEnter', function(self)
				self:SetBackdropBorderColor(1, 0.82, 0, 1)
				if self._name then Widget.ShowTip(self, self._name) end
			end)
			SetScript(btn, 'OnLeave', function(self)
				self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
				Widget.HideTip()
			end)
			SetScript(btn, 'OnClick', function(self)
				if self._tex then input:SetText(tostring(self._tex)) end
			end)
			resultButtons[i] = btn
		end
		return btn
	end

	local function ClearResults(fromIndex)
		for i = fromIndex, #resultButtons do resultButtons[i]:Hide() end
	end

	local IDLE_HINT = 'Type a spell name and click an icon, e.g. aimed'
	local pendingQuery

	local function RunSearch(text)
		local hits, seen = {}, {}
		local quick = BUI.Lookup.SearchSpellsAndItems(text, 40)
		for _, hit in ipairs(quick) do
			if hit.icon and not seen[hit.icon] then
				seen[hit.icon] = true
				hits[#hits + 1] = { icon = hit.icon, name = hit.name }
			end
		end

		local Idx = BUI.IconSearch
		if Idx.Ready() then
			local deep = Idx.Search(text, GRID_MAX) or {}
			for _, hit in ipairs(deep) do
				if #hits >= GRID_MAX then break end
				if not seen[hit.icon] then
					seen[hit.icon] = true
					hits[#hits + 1] = hit
				end
			end
			statusFS:SetText(#hits > 0 and 'Click an icon to use it' or 'No matching icons found')
		else
			statusFS:SetText(('Building icon index... %d%%'):format(Idx.Progress() * 100))
			Idx.EnsureIndex(function()
				if pendingQuery then RunSearch(pendingQuery) end
			end)
		end

		local shown = 0
		for _, hit in ipairs(hits) do
			if shown >= GRID_MAX then break end
			shown = shown + 1
			local btn = ResultButton(shown)
			btn.tex:SetTexture(hit.icon)
			btn._tex = hit.icon
			btn._name = hit.name
			btn:Show()
		end
		ClearResults(shown + 1)
	end

	local function RefreshResults(text)
		if #text < 2 or tonumber(text) or text:find('[\\/]') then
			pendingQuery = nil
			ClearResults(1)
			statusFS:SetText(#text == 1 and 'Keep typing...' or IDLE_HINT)
			return
		end
		pendingQuery = text
		BUI.Prof.After('Pages.CDMIconManagement', 0.15, function()
			if pendingQuery == text then RunSearch(text) end
		end)
	end

	local row = Controls.SettingRow(dialog, {
		width = inputW,
		title = 'Custom Icon',
		description = 'Pick a search result, or type a texture ID directly.',
		controlWidth = 210,
		control = function(r)
			input = Modals.CreateInput(r, current and tostring(current) or '', 190, 24)
			input:SetAutoFocus(false)
			return input
		end,
		extra = function(r)
			gridHost = CreateFrame('Frame', nil, r)
			gridHost:SetSize(inputW - 40, 92)
			statusFS = gridHost:CreateFontString(nil, 'OVERLAY')
			statusFS:SetFont(BUILib.Font, 10, '')
			statusFS:SetTextColor(0.55, 0.55, 0.58, 1)
			statusFS:SetPoint('TOPLEFT', 0, -2)
			statusFS:SetText(IDLE_HINT)
			return gridHost
		end,
	})
	local rowFrame = row.frame
	rowFrame:ClearAllPoints()
	rowFrame:SetPoint('TOPLEFT', dialog, 'TOPLEFT', PAD, -96)
	dialog:SetHeight(96 + (rowFrame.layoutHeight or rowFrame:GetHeight()) + 70)

	SetScript(input, 'OnTextChanged', function(self)
		local text = self:GetText():gsub('^%s+', ''):gsub('%s+$', '')
		if text == '' then
			preview:SetTexture(defaultIcon)
		elseif tonumber(text) then
			preview:SetTexture(tonumber(text))
		elseif text:find('[\\/]') then
			if not preview:SetTexture(text) then preview:SetTexture(defaultIcon) end
		end
		RefreshResults(text)
	end)

	local function DoSave()
		CDM.SetIconOverride(viewerSettings, spellID, ParseIconValue(input:GetText()))
		CDM.RefreshIconOverrideForSpell(spellID)
		CDM.Custom.Refresh()
		Close()
		if onSaved then onSaved() end
	end

	SetScript(input, 'OnEnterPressed', DoSave)
	SetScript(overlay, 'OnKeyDown', function(_, key) if key == 'ESCAPE' then Close() end end)
	Modals.LayoutButtons(dialog, {
		{ text = 'Save', color = Modals.BTN_CONFIRM, onClick = function() DoSave() end },
		{ text = 'Cancel', color = Modals.BTN_CANCEL, onClick = function(close) close() end },
	}, Close)
end

local function ShowPotionDisplayModal(CDM, itemID, storedValue, viewerSettings, viewerKey, onChanged)
	if not viewerSettings then return end
	local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID or 0)
	if not itemIcon and itemID then
		local _, _, _, _, instantIcon = C_Item.GetItemInfoInstant(itemID)
		itemIcon = instantIcon
	end
	itemName = itemName or (itemID and ('Item ' .. itemID)) or tostring(storedValue)

	local isFlask
	if itemID then
		local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
		isFlask = classID == Enum.ItemClass.Consumable and subclassID == Enum.ItemConsumableSubclass.Flask
	end
	local kindWord = isFlask and 'flask' or 'potion'

	local overlay, dialog, Close = Modals.CreateBase(560, 300, true, BUI.PageEngine.window.frame)
	Modals.CreateTitle(dialog, isFlask and 'Flask Display' or 'Potion Display')

	local PAD = 24
	local inputW = dialog:GetWidth() - PAD * 2

	local preview = dialog:CreateTexture(nil, 'ARTWORK')
	preview:SetSize(36, 36)
	preview:SetPoint('TOPLEFT', dialog, 'TOPLEFT', PAD, -46)
	preview:SetTexture(itemIcon or FALLBACK_TEX)
	preview:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	local previewBorder = CreateFrame('Frame', nil, dialog, 'BackdropTemplate')
	previewBorder:SetPoint('TOPLEFT', preview, 'TOPLEFT', -1, 1)
	previewBorder:SetPoint('BOTTOMRIGHT', preview, 'BOTTOMRIGHT', 1, -1)
	previewBorder:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 })
	previewBorder:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	local nameText = dialog:CreateFontString(nil, 'OVERLAY')
	nameText:SetFont(BUILib.Font, 14, '')
	nameText:SetPoint('TOPLEFT', preview, 'TOPRIGHT', 12, -2)
	nameText:SetText(itemName)
	nameText:SetTextColor(1, 0.82, 0)

	local idText = dialog:CreateFontString(nil, 'OVERLAY')
	idText:SetFont(BUILib.Font, 11, '')
	idText:SetPoint('TOPLEFT', nameText, 'BOTTOMLEFT', 0, -2)
	idText:SetText('|cff888888ID: ' .. tostring(itemID or storedValue) .. '|r')

	local help = dialog:CreateFontString(nil, 'OVERLAY')
	help:SetFont(BUILib.Font, 12, '')
	help:SetPoint('TOPLEFT', dialog, 'TOPLEFT', PAD, -96)
	help:SetWidth(inputW)
	help:SetJustifyH('LEFT')
	help:SetWordWrap(true)
	help:SetSpacing(2)
	help:SetTextColor(0.65, 0.65, 0.65)
	help:SetText('Drag cards to set the order - the icon shows the first version you still carry, and when it runs out the next one takes over. Untick a card to ignore that version completely.')

	local combine = false
	do
		local prio = CDM.GetPotionPrioFor(storedValue)
		combine = prio and prio.combine or false
	end

	local Theme = BUILib.Theme
	local cards, freeCards = {}, {}
	local dragIndex

	local function SaveNow()
		local order, off = {}, nil
		for _, card in ipairs(cards) do
			order[#order + 1] = card.id
			if not card.enabled then
				off = off or {}
				off[card.id] = true
			end
		end
		CDM.SetSharedPotionPrio(storedValue, { order = order, off = off, combine = combine or nil })
		CDM.Custom.Refresh()
		BUI.CustomBars.RefreshAllBars()
		if onChanged then onChanged() end
	end

	local COLS, CARD_W, CARD_H, CARD_GAP = 4, 118, 116, 13
	local RING_COLOR = { 0.20, 0.22, 0.26, 0.55 }
	local gridFrame = CreateFrame('Frame', nil, dialog)
	gridFrame:SetSize(inputW, CARD_H)

	local ghost = CreateFrame('Frame', nil, dialog)
	ghost:SetSize(CARD_W, CARD_H)
	ghost:SetFrameLevel(dialog:GetFrameLevel() + 50)
	do
		local r, g, b = Theme.GetAccent()
		Widget.DrawRoundedRect(ghost, 8, { r, g, b, 0.9 }, 'BACKGROUND', 0, 0)
		Widget.DrawRoundedRect(ghost, 7, Theme.bg.card, 'BACKGROUND', 1, 1)
	end
	ghost:SetAlpha(0.92)
	ghost:Hide()
	local ghostIcon = ghost:CreateTexture(nil, 'ARTWORK', nil, 2)
	ghostIcon:SetSize(44, 44)
	ghostIcon:SetPoint('TOP', 0, -14)
	ghostIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local ghostBadge = ghost:CreateTexture(nil, 'OVERLAY')
	ghostBadge:SetSize(20, 20)
	ghostBadge:SetPoint('TOPRIGHT', ghostIcon, 'TOPRIGHT', 7, 5)
	local ghostLabel = ghost:CreateFontString(nil, 'OVERLAY')
	ghostLabel:SetFont(BUILib.Font, 11, '')
	ghostLabel:SetPoint('TOPLEFT', 6, -64)
	ghostLabel:SetPoint('TOPRIGHT', -6, -64)
	ghostLabel:SetHeight(24)
	ghostLabel:SetJustifyH('CENTER')
	ghostLabel:SetJustifyV('TOP')
	ghostLabel:SetWordWrap(true)
	ghostLabel:SetTextColor(0.9, 0.9, 0.9)
	local ghostID = ghost:CreateFontString(nil, 'OVERLAY')
	ghostID:SetFont(BUILib.Font, 10, '')
	ghostID:SetPoint('BOTTOM', 0, 8)
	ghostID:SetTextColor(0.42, 0.42, 0.42)

	local function LayoutCards()
		local cardCount = #cards
		local xBase = 0
		if cardCount > 0 and cardCount < COLS then
			xBase = math.floor((inputW - (cardCount * (CARD_W + CARD_GAP) - CARD_GAP)) / 2)
		end
		for i, card in ipairs(cards) do
			local col = (i - 1) % COLS
			local row = math.floor((i - 1) / COLS)
			card.frame:ClearAllPoints()
			card.frame:SetPoint('TOPLEFT', gridFrame, 'TOPLEFT', xBase + col * (CARD_W + CARD_GAP), -row * (CARD_H + CARD_GAP))
			card.index = i
			card.prioText:SetText('#' .. i)
			card.frame:SetAlpha(dragIndex == i and 0.3 or 1)
		end
		local rowCount = math.max(1, math.ceil(cardCount / COLS))
		gridFrame:SetHeight(rowCount * CARD_H + (rowCount - 1) * CARD_GAP)
	end

	local function ApplyEnabledVisual(card)
		if card.enabled then
			card.icon:SetDesaturated(false)
			card.icon:SetAlpha(1)
			card.qBadge:SetDesaturated(false)
			card.qBadge:SetAlpha(1)
			card.label:SetTextColor(0.9, 0.9, 0.9)
			card.tickMark:Show()
		else
			card.icon:SetDesaturated(true)
			card.icon:SetAlpha(0.4)
			card.qBadge:SetDesaturated(true)
			card.qBadge:SetAlpha(0.4)
			card.label:SetTextColor(0.45, 0.45, 0.45)
			card.tickMark:Hide()
		end
	end

	local function CreateCard()
		local cardFrame = CreateFrame('Frame', nil, gridFrame)
		cardFrame:SetSize(CARD_W, CARD_H)
		local ring = Widget.DrawRoundedRect(cardFrame, 8, RING_COLOR, 'BACKGROUND', 0, 0)
		Widget.DrawRoundedRect(cardFrame, 7, Theme.bg.card, 'BACKGROUND', 1, 1)
		local card = { frame = cardFrame, ring = ring }

		local icon = cardFrame:CreateTexture(nil, 'ARTWORK', nil, 2)
		icon:SetSize(44, 44)
		icon:SetPoint('TOP', 0, -14)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		card.icon = icon

		local qBadge = cardFrame:CreateTexture(nil, 'OVERLAY')
		qBadge:SetSize(20, 20)
		qBadge:SetPoint('TOPRIGHT', icon, 'TOPRIGHT', 7, 5)
		card.qBadge = qBadge

		local countText = cardFrame:CreateFontString(nil, 'OVERLAY')
		countText:SetFont(BUILib.Font, 12, 'OUTLINE')
		countText:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', 5, -3)
		card.countText = countText

		local prioText = cardFrame:CreateFontString(nil, 'OVERLAY')
		prioText:SetFont(BUILib.Font, 11, '')
		prioText:SetPoint('TOPLEFT', 8, -8)
		prioText:SetTextColor(0.5, 0.5, 0.5)
		card.prioText = prioText

		local label = cardFrame:CreateFontString(nil, 'OVERLAY')
		label:SetFont(BUILib.Font, 11, '')
		label:SetPoint('TOPLEFT', 6, -64)
		label:SetPoint('TOPRIGHT', -6, -64)
		label:SetHeight(24)
		label:SetJustifyH('CENTER')
		label:SetJustifyV('TOP')
		label:SetWordWrap(true)
		card.label = label

		local idText = cardFrame:CreateFontString(nil, 'OVERLAY')
		idText:SetFont(BUILib.Font, 10, '')
		idText:SetPoint('BOTTOM', 0, 8)
		idText:SetTextColor(0.42, 0.42, 0.42)
		card.idText = idText

		local tick = Widget.New(cardFrame, 'Button', nil, { bg = Theme.bg.input, border = Theme.border.input, size = { 16, 16 } }).frame
		tick:SetPoint('TOPRIGHT', -7, -7)
		tick:SetFrameLevel(cardFrame:GetFrameLevel() + 6)
		local tickMark = Widget.Create(tick, Theme.GetAccent())
		tickMark:SetSize(10, 10)
		tickMark:SetPoint('CENTER')
		card.tickMark = tickMark
		SetScript(tick, 'OnClick', function()
			card.enabled = not card.enabled
			ApplyEnabledVisual(card)
			SaveNow()
		end)

		local function ShowHover()
			local r, g, b = Theme.GetAccent()
			Widget.SetRectColor(ring, r, g, b, 0.6)
			if card.id then
				GameTooltip:SetOwner(cardFrame, 'ANCHOR_RIGHT')
				GameTooltip:SetItemByID(card.id)
				GameTooltip:Show()
			end
		end
		local function HideHover()
			if cardFrame:IsMouseOver() then return end
			Widget.SetRectColor(ring, unpack(RING_COLOR))
			GameTooltip:Hide()
		end

		cardFrame:EnableMouse(true)
		cardFrame:RegisterForDrag('LeftButton')
		SetScript(cardFrame, 'OnEnter', ShowHover)
		SetScript(cardFrame, 'OnLeave', HideHover)
		SetScript(tick, 'OnEnter', ShowHover)
		SetScript(tick, 'OnLeave', HideHover)
		SetScript(cardFrame, 'OnDragStart', function()
			dragIndex = card.index
			ghostIcon:SetTexture(icon:GetTexture())
			ghostLabel:SetText(label:GetText())
			ghostID:SetText(idText:GetText())
			if qBadge:IsShown() and qBadge:GetAtlas() then
				ghostBadge:SetAtlas(qBadge:GetAtlas())
				ghostBadge:Show()
			else
				ghostBadge:Hide()
			end
			ghost:Show()
			SetScript(gridFrame, 'OnUpdate', function()
				local cx, cy = GetCursorPosition()
				local scale = UIParent:GetEffectiveScale()
				cx, cy = cx / scale, cy / scale
				ghost:ClearAllPoints()
				ghost:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', cx, cy)
				for i, other in ipairs(cards) do
					local l, b = other.frame:GetLeft(), other.frame:GetBottom()
					if l and b and cx >= l and cx <= l + CARD_W and cy >= b and cy <= b + CARD_H then
						if i ~= dragIndex then
							table.insert(cards, i, table.remove(cards, dragIndex))
							dragIndex = i
							LayoutCards()
						end
						break
					end
				end
			end)
		end)
		SetScript(cardFrame, 'OnDragStop', function()
			dragIndex = nil
			ghost:Hide()
			SetScript(gridFrame, 'OnUpdate', nil)
			LayoutCards()
			SaveNow()
		end)
		return card
	end

	local combineRow = Controls.SettingRow(dialog, {
		width = inputW,
		title = 'Combined Count',
		description = ('The count adds up every ticked version instead of just the %s on display.'):format(kindWord),
		checked = combine,
		callback = function(v)
			combine = v
			SaveNow()
		end,
	})
	local combineFrame = combineRow.frame
	local helpH = math.ceil(help:GetStringHeight())
	local TIER_WORD = { 'Silver', 'Gold' }

	local function Rebuild()
		local prio = CDM.GetPotionPrioFor(storedValue)
		local versions, pending = {}, nil
		if itemID then
			versions, pending = CDM.Custom.GetPotionVersions(itemID)
		end
		local countByID = {}
		for _, v in ipairs(versions) do
			countByID[v.id] = v.count
		end

		local cardIDs, added = {}, {}
		if prio and prio.order then
			for _, id in ipairs(prio.order) do
				if not added[id] then
					added[id] = true
					cardIDs[#cardIDs + 1] = id
				end
			end
		end
		for _, v in ipairs(versions) do
			if not added[v.id] then
				added[v.id] = true
				cardIDs[#cardIDs + 1] = v.id
			end
		end

		local names, qualities, badgeAtlases, rootName = {}, {}, {}, nil
		for _, id in ipairs(cardIDs) do
			local raw = C_Item.GetItemInfo(id)
			if not raw then
				pending = pending or {}
				pending[#pending + 1] = id
			else
				local name = raw:gsub('|[AT][^|]-|[at]', ''):gsub('^%s+', ''):gsub('%s+$', '')
				names[id] = name
				local tier, tierAtlas = CDM.Custom.GetCraftedQualityInfo(id)
				qualities[id] = tier
				badgeAtlases[id] = tierAtlas
				if not rootName or #name < #rootName then rootName = name end
			end
		end

		for _, card in ipairs(cards) do
			card.frame:Hide()
			freeCards[#freeCards + 1] = card
		end
		wipe(cards)

		for _, id in ipairs(cardIDs) do
			local card = table.remove(freeCards) or CreateCard()
			card.id = id
			card.enabled = not (prio and prio.off and prio.off[id])

			local _, _, _, _, iconTex = C_Item.GetItemInfoInstant(id)
			card.icon:SetTexture(iconTex or FALLBACK_TEX)

			local quality = qualities[id] or 0
			local atlas = badgeAtlases[id]
			if atlas then
				card.qBadge:SetAtlas(atlas)
				card.qBadge:Show()
			else
				card.qBadge:Hide()
			end

			local name = names[id]
			local labelText
			if name then
				local prefix = name
				if rootName then
					local pos = name:find(rootName, 1, true)
					if pos then
						prefix = (name:sub(1, pos - 1) .. name:sub(pos + #rootName)):gsub('^%s+', ''):gsub('%s+$', '')
					end
				end
				if atlas then
					labelText = prefix
				else
					local tierWord = TIER_WORD[quality] or (quality > 0 and ('Tier ' .. quality) or nil)
					if prefix == '' then
						labelText = tierWord or name
					elseif tierWord then
						labelText = prefix .. ' ' .. tierWord
					else
						labelText = prefix
					end
				end
			else
				labelText = 'Item ' .. id
			end
			card.label:SetText(labelText)
			card.idText:SetText(id)

			local count = countByID[id] or 0
			card.countText:SetText('x' .. count)
			if count > 0 then
				card.countText:SetTextColor(1, 1, 1)
			else
				card.countText:SetTextColor(0.45, 0.45, 0.45)
			end

			Widget.SetRectColor(card.ring, unpack(RING_COLOR))
			ApplyEnabledVisual(card)
			card.frame:Show()
			cards[#cards + 1] = card
		end
		LayoutCards()

		local gridTop = 96 + helpH + 14
		gridFrame:ClearAllPoints()
		gridFrame:SetPoint('TOPLEFT', dialog, 'TOPLEFT', PAD, -gridTop)
		local combineTop = gridTop + gridFrame:GetHeight() + 16
		combineFrame:ClearAllPoints()
		combineFrame:SetPoint('TOPLEFT', dialog, 'TOPLEFT', PAD, -combineTop)
		dialog:SetHeight(combineTop + (combineFrame.layoutHeight or combineFrame:GetHeight()) + 92)
		return pending
	end

	local watched = {}
	local function WatchPending(pending)
		if not pending then return end
		for _, pid in ipairs(pending) do
			if not watched[pid] then
				watched[pid] = true
				Item:CreateFromItemID(pid):ContinueOnItemLoad(function()
					if dialog:IsShown() then
						WatchPending(Rebuild())
					end
				end)
			end
		end
	end
	WatchPending(Rebuild())

	SetScript(overlay, 'OnKeyDown', function(_, key) if key == 'ESCAPE' then Close() end end)
	Modals.LayoutButtons(dialog, {
		{ text = 'Done', color = Modals.BTN_CONFIRM, onClick = function(close) close() end },
		{ text = 'Reset', color = Modals.BTN_CANCEL, onClick = function()
			CDM.SetSharedPotionPrio(storedValue, nil)
			combine = false
			combineRow:SetValue(false)
			CDM.Custom.Refresh()
			BUI.CustomBars.RefreshAllBars()
			if onChanged then onChanged() end
			WatchPending(Rebuild())
		end },
	}, Close)
end

local function ShowProcModal(CDM, spellID, RefreshIconList, backTo, viewerSettings)
	if not viewerSettings then
		CDM.ForAllIcons(function(icon, key)
			if viewerSettings then return end
			local info = icon.cooldownInfo
			if not info then return end
			if BUI.Tools.SafeNum(info.spellID) == spellID or BUI.Tools.SafeNum(info.overrideSpellID) == spellID then
				viewerSettings = BUI.GetDB().cdm[key]
			end
		end)
	end

	local existing = CDM.GetProcConfig(spellID) or {}
	local hasSaved = next(existing) ~= nil
	local spellName = C_Spell.GetSpellName(spellID) or tostring(spellID)
	local defaultIcon = C_Spell.GetSpellTexture(spellID) or FALLBACK_TEX
	local globalGlow = BUI.GetDB().cdm.glow
	local hasTTS = BUI.TTS.IsAvailable()
	local openedFromBuffs = viewerSettings ~= nil and viewerSettings == CDM.GetSettings('buffs')

	local appliesSpells, sourceSpells = {}, {}
	do
		local GetCategorySet = C_CooldownViewer.GetCooldownViewerCategorySet
		local seen = {}
		local function IsCastable(id)
			return C_SpellBook.IsSpellKnown(id)
		end
		local function AddRelated(relID, entrySaysApplies)
			if relID == spellID or seen[relID] or not C_Spell.GetSpellName(relID) then return end
			seen[relID] = true
			local selfCast = IsCastable(spellID)
			local relCast = IsCastable(relID)
			local applies
			if selfCast and not relCast then
				applies = true
			elseif relCast and not selfCast then
				applies = false
			else
				applies = entrySaysApplies
			end
			if applies then
				appliesSpells[#appliesSpells + 1] = relID
			else
				sourceSpells[#sourceSpells + 1] = relID
			end
		end
		for _, cat in ipairs({ Enum.CooldownViewerCategory.TrackedBuff, Enum.CooldownViewerCategory.TrackedBar }) do
			local ids = GetCategorySet(cat, true)
			if ids then
				for _, cdID in ipairs(ids) do
					local info = GetCooldownInfo(cdID)
					if info and info.spellID then
						if info.overrideSpellID and info.overrideSpellID ~= spellID and info.spellID == spellID then
							AddRelated(info.overrideSpellID, true)
						end
						if info.overrideSpellID == spellID and info.spellID ~= spellID then
							AddRelated(info.spellID, false)
						end
						if info.linkedSpellIDs then
							if info.spellID == spellID then
								for _, lid in ipairs(info.linkedSpellIDs) do
									AddRelated(lid, true)
								end
							else
								for _, lid in ipairs(info.linkedSpellIDs) do
									if lid == spellID then
										AddRelated(info.spellID, false)
										if info.overrideSpellID then AddRelated(info.overrideSpellID, true) end
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end
	if backTo then
		for _, list in ipairs({ appliesSpells, sourceSpells }) do
			for i = #list, 1, -1 do
				if list[i] == backTo then table.remove(list, i) end
			end
		end
	end
	local famGroups = {}
	if #appliesSpells > 0 then famGroups[#famGroups + 1] = { label = 'Applies buff:', ids = appliesSpells } end
	if #sourceSpells > 0 then famGroups[#famGroups + 1] = { label = 'Applied by:', ids = sourceSpells } end
	local famIDs = {}
	for _, id in ipairs(appliesSpells) do famIDs[#famIDs + 1] = id end
	for _, id in ipairs(sourceSpells) do famIDs[#famIDs + 1] = id end
	local famCfgCount = 0
	for _, id in ipairs(famIDs) do
		if CDM.GetProcConfig(id) then famCfgCount = famCfgCount + 1 end
	end

	local buffSource = CDM.FindTrackedBuffSource(spellID)
	local ownBuff = buffSource ~= nil and not buffSource.viaSpellID

	local trigVal, glowTargetVal, watchID, legacyRide
	if hasSaved then
		trigVal = existing.trigger or (existing.glowTargetSpell and 'appear') or 'proc'
		glowTargetVal = existing.glowTarget or ''
		if existing.watchSpell then
			trigVal = 'watch'
			watchID = existing.watchSpell
		elseif trigVal ~= 'proc' and existing.glowTargetSpell and not ownBuff then
			trigVal = 'watch'
			watchID = existing.glowTargetSpell
			legacyRide = true
		end
	else
		if ownBuff then
			trigVal = 'appear'
		elseif buffSource then
			trigVal = 'watch'
			watchID = buffSource.viaSpellID
		elseif #appliesSpells == 1 then
			trigVal = 'watch'
			watchID = appliesSpells[1]
		elseif #sourceSpells > 0 then
			trigVal = 'appear'
		else
			trigVal = 'proc'
		end
		glowTargetVal = (trigVal ~= 'proc' and not openedFromBuffs) and 'cooldown' or ''
	end
	local legacyTargetID = (not legacyRide) and existing.glowTargetSpell or nil
	local glowModeVal = existing.glowMode or 'always'
	local glowThreshVal = existing.glowThreshold or 5
	local autoDur = ParseDurationFromDescription(spellID)
	local durVal = existing.duration or autoDur or 0
	local styleVal = existing.style or ''
	local speedVal = existing.speed or globalGlow.speed
	local linesVal = existing.lines or globalGlow.lines
	local thickVal = existing.thickness or globalGlow.thickness
	local useColor = existing.color ~= nil
	local chosenColor = existing.color and { existing.color[1], existing.color[2], existing.color[3], existing.color[4] or 1 }
	local fallbackColor = globalGlow.color
	local msgOn = existing.msg and true or false
	local msgTextVal = CDM.GetProcMessageText(spellID)
	local msgAnchorVal = existing.msgAnchor or 'center'
	local msgSizeVal = existing.msgSize or 14
	local msgOffXVal = existing.msgOffsetX or 0
	local msgOffYVal = existing.msgOffsetY or 0
	local msgColorVal = existing.msgColor and { existing.msgColor[1], existing.msgColor[2], existing.msgColor[3], existing.msgColor[4] or 1 }
	local ttsOn = existing.tts and true or false
	local soundVal = existing.sound or 0

	local function DisplayText(id, name)
		return (name or C_Spell.GetSpellName(id) or 'Spell') .. ' (' .. id .. ')'
	end
	local watchText = watchID and DisplayText(watchID) or ''

	local function ParseWatchSpell()
		if watchID then return watchID end
		local text = (watchText or ''):gsub('^%s+', ''):gsub('%s+$', '')
		if text == '' then return nil end
		local id = tonumber(text) or tonumber(text:match('%((%d+)%)%s*$')) or tonumber(text:match('spell:(%d+)'))
		if not id then
			local info = C_Spell.GetSpellInfo(text)
			id = info and info.spellID
		end
		return id
	end

	local function SearchTrackedBuffs(text)
		local needle = text:lower()
		local hits, seen = {}, {}
		local GetCategorySet = C_CooldownViewer.GetCooldownViewerCategorySet
		for _, cat in ipairs({ Enum.CooldownViewerCategory.TrackedBuff, Enum.CooldownViewerCategory.TrackedBar }) do
			local ids = GetCategorySet(cat, true)
			if ids then
				for _, cdID in ipairs(ids) do
					local info = GetCooldownInfo(cdID)
					local id = info and BUI.Tools.SafeNum(info.spellID)
					if id and id ~= spellID and not seen[id] then
						local name = C_Spell.GetSpellName(id)
						if name and (name:lower():find(needle, 1, true) or tostring(id):find(needle, 1, true)) then
							seen[id] = true
							hits[#hits + 1] = { id = id, name = name, icon = C_Spell.GetSpellTexture(id) or FALLBACK_TEX }
						end
					end
				end
			end
		end
		if #hits == 0 then
			return BUI.Lookup.SearchSpells(text, nil, 'buffs')
		end
		return hits
	end

	local function EffectiveGlowColor()
		local color = useColor and (chosenColor or fallbackColor) or fallbackColor
		return color[1], color[2], color[3], color[4] or 1
	end

	local DoSave, ConfirmRemove, NavigateTo, Refresh, watchEdit
	local buttons = {
		{ text = 'Save', color = Modals.BTN_CONFIRM, width = 90, onClick = function(close) DoSave(close) end },
		{ text = 'Cancel', color = Modals.BTN_NEUTRAL, width = 90, onClick = function(close) close() end },
	}
	if hasSaved or famCfgCount > 0 then
		buttons[#buttons + 1] = { text = 'Remove Alert', color = Modals.BTN_WARNING, width = 110, onClick = function(close) ConfirmRemove(close) end }
	end

	local content, Close = Modals.Settings({
		title = 'Alert Settings',
		width = 560,
		height = 660,
		parent = BUI.PageEngine.window.frame,
		buttons = buttons,
	})
	local dialog, child = content.dialog, content.child
	local contentWidth = content.contentWidth or 510
	local ar, ag, ab = BUILib.Theme.GetAccent()

	local blocks, totalHeight = {}, 0
	local function AddBlock(frame, height, isVisible, gap)
		frame:SetWidth(contentWidth)
		frame:SetHeight(height)
		blocks[#blocks + 1] = { frame = frame, height = height, isVisible = isVisible, gap = gap or 4 }
		frame.blockIndex = #blocks
		return frame
	end
	local function Relayout()
		local y = 0
		for index = 1, #blocks do
			local block = blocks[index]
			local visible = block.isVisible
			if type(visible) == 'function' then visible = visible() end
			block.frame:ClearAllPoints()
			if visible ~= false then
				block.frame:SetPoint('TOPLEFT', child, 'TOPLEFT', 0, -y)
				block.frame:Show()
				y = y + block.height + block.gap
			else
				block.frame:Hide()
			end
		end
		totalHeight = y
		content:Refresh()
	end
	content.GetContentHeight = function() return totalHeight end

	local LABEL_W = 120
	local ROW_H = 30

	local function Section(title)
		local frame = CreateFrame('Frame', nil, child)
		local text = frame:CreateFontString(nil, 'OVERLAY')
		text:SetFont(BUILib.Font, 10, 'OUTLINE')
		text:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 0, 7)
		text:SetText(string.upper(title))
		text:SetTextColor(ar, ag, ab, 0.95)
		local line = frame:CreateTexture(nil, 'ARTWORK')
		line:SetColorTexture(1, 1, 1, 0.08)
		line:SetHeight(1)
		line:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 0, 0)
		line:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', 0, 0)
		return AddBlock(frame, 28, true, 8)
	end

	local function Row(label, isVisible)
		local frame = CreateFrame('Frame', nil, child)
		local text = frame:CreateFontString(nil, 'OVERLAY')
		text:SetFont(BUILib.Font, 11, '')
		text:SetPoint('LEFT', frame, 'LEFT', 2, 0)
		text:SetWidth(LABEL_W - 8)
		text:SetJustifyH('LEFT')
		text:SetText(label)
		text:SetTextColor(0.85, 0.85, 0.88, 1)
		frame.label = text
		frame.cursorX = LABEL_W
		function frame:Place(control, width, gap)
			local controlFrame = Widget.Unwrap(control)
			controlFrame:ClearAllPoints()
			controlFrame:SetPoint('LEFT', frame, 'LEFT', frame.cursorX, 0)
			frame.cursorX = frame.cursorX + (width or controlFrame:GetWidth() or 0) + (gap or 12)
			return control
		end
		function frame:PlaceText(str, gap)
			local inline = frame:CreateFontString(nil, 'OVERLAY')
			inline:SetFont(BUILib.Font, 10, '')
			inline:SetTextColor(0.6, 0.62, 0.66, 1)
			inline:SetText(str)
			inline:SetPoint('LEFT', frame, 'LEFT', frame.cursorX, 0)
			frame.cursorX = frame.cursorX + math.ceil(inline:GetStringWidth()) + (gap or 6)
			return inline
		end
		return AddBlock(frame, ROW_H, isVisible, 4)
	end

	local function Note(isVisible)
		local frame = CreateFrame('Frame', nil, child)
		local text = frame:CreateFontString(nil, 'OVERLAY')
		text:SetFont(BUILib.Font, 10, '')
		text:SetPoint('TOPLEFT', frame, 'TOPLEFT', LABEL_W + 2, 0)
		text:SetWidth(contentWidth - LABEL_W - 4)
		text:SetJustifyH('LEFT')
		text:SetWordWrap(true)
		text:SetSpacing(2)
		frame.text = text
		function frame:SetNote(str, isWarning)
			text:SetText(str or '')
			if isWarning then
				text:SetTextColor(1, 0.62, 0.25, 1)
			else
				text:SetTextColor(0.55, 0.58, 0.62, 1)
			end
			blocks[frame.blockIndex].height = math.max(14, math.ceil(text:GetStringHeight()))
		end
		return AddBlock(frame, 14, isVisible, 8)
	end

	local header = CreateFrame('Frame', nil, child)
	local preview = header:CreateTexture(nil, 'ARTWORK')
	preview:SetSize(40, 40)
	preview:SetPoint('TOPLEFT', header, 'TOPLEFT', 0, 0)
	preview:SetTexture(defaultIcon)
	preview:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local previewBorder = CreateFrame('Frame', nil, header, 'BackdropTemplate')
	previewBorder:SetPoint('TOPLEFT', preview, 'TOPLEFT', -1, 1)
	previewBorder:SetPoint('BOTTOMRIGHT', preview, 'BOTTOMRIGHT', 1, -1)
	previewBorder:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 })
	previewBorder:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
	local glowHost = CreateFrame('Frame', nil, header)
	glowHost:SetPoint('TOPLEFT', preview, 'TOPLEFT', 0, 0)
	glowHost:SetSize(40, 40)
	glowHost:SetFrameLevel(header:GetFrameLevel() + 5)
	glowHost.Icon = preview
	local nameText = header:CreateFontString(nil, 'OVERLAY')
	nameText:SetFont(BUILib.Font, 14, '')
	nameText:SetPoint('TOPLEFT', preview, 'TOPRIGHT', 12, -3)
	nameText:SetText(spellName)
	nameText:SetTextColor(1, 0.82, 0)
	local idText = header:CreateFontString(nil, 'OVERLAY')
	idText:SetFont(BUILib.Font, 11, '')
	idText:SetPoint('TOPLEFT', nameText, 'BOTTOMLEFT', 0, -3)
	local idLine = 'ID ' .. tostring(spellID)
	if buffSource then
		idLine = idLine .. '   \xe2\x80\xa2   Buff tracked in ' .. buffSource.label .. (buffSource.displayed and '' or ' (Not Displayed)')
	end
	idText:SetText(idLine)
	idText:SetTextColor(0.55, 0.55, 0.58, 1)

	if backTo then
		local backName = C_Spell.GetSpellName(backTo) or 'previous'
		local backBtn = Modals.CreateButton(header, '< ' .. backName, { ar, ag, ab, 1 }, 150)
		backBtn:SetPoint('TOPRIGHT', header, 'TOPRIGHT', 0, -6)
		SetScript(backBtn, 'OnClick', function() NavigateTo(backTo) end)
	end

	local msgPreviewHost = CreateFrame('Frame', nil, header)
	msgPreviewHost:SetPoint('TOPLEFT', preview, 'TOPLEFT', 0, 0)
	msgPreviewHost:SetSize(40, 40)
	msgPreviewHost:SetFrameLevel(glowHost:GetFrameLevel() + 20)
	local msgPreviewText = msgPreviewHost:CreateFontString(nil, 'OVERLAY', nil, 7)
	msgPreviewText:SetJustifyH('CENTER')

	local famY = 48
	for _, famGroup in ipairs(famGroups) do
		local stripLabel = header:CreateFontString(nil, 'OVERLAY')
		stripLabel:SetFont(BUILib.Font, 11, '')
		stripLabel:SetTextColor(0.7, 0.7, 0.74, 1)
		stripLabel:SetText(famGroup.label)
		stripLabel:SetPoint('LEFT', header, 'TOPLEFT', 0, -(famY + 12))
		local x = 90
		for _, otherID in ipairs(famGroup.ids) do
			local btn = CreateFrame('Button', nil, header, 'BackdropTemplate')
			btn:SetSize(24, 24)
			btn:SetPoint('TOPLEFT', header, 'TOPLEFT', x, -famY)
			local tex = btn:CreateTexture(nil, 'ARTWORK')
			tex:SetAllPoints()
			tex:SetTexture(C_Spell.GetSpellTexture(otherID) or FALLBACK_TEX)
			tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			btn:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 })
			local configured = CDM.GetProcConfig(otherID) ~= nil
			local br, bg, bb = 0.3, 0.3, 0.3
			if configured then br, bg, bb = ar, ag, ab end
			btn:SetBackdropBorderColor(br, bg, bb, 1)
			SetScript(btn, 'OnEnter', function(self)
				self:SetBackdropBorderColor(1, 0.82, 0, 1)
				GameTooltip:SetOwner(self, 'ANCHOR_TOP')
				GameTooltip:SetSpellByID(otherID)
				GameTooltip:AddLine(configured and '|cffffe066Has an alert. Click to edit it.|r' or '|cff888888Click to set up an alert for this spell.|r')
				GameTooltip:Show()
			end)
			SetScript(btn, 'OnLeave', function(self)
				self:SetBackdropBorderColor(br, bg, bb, 1)
				GameTooltip:Hide()
			end)
			SetScript(btn, 'OnClick', function() NavigateTo(otherID) end)
			x = x + 28
		end
		famY = famY + 28
	end
	AddBlock(header, #famGroups > 0 and famY or 44, true, 10)

	local function RefreshGlowPreview()
		CDM.StopProcGlow(glowHost)
		CDM.StartProcGlow(glowHost, {
			enabled = true,
			style = styleVal ~= '' and styleVal or nil,
			color = useColor and (chosenColor or fallbackColor) or nil,
			speed = speedVal,
			lines = linesVal,
			thickness = thickVal,
		})
	end
	HookScript(dialog, 'OnHide', function() CDM.StopProcGlow(glowHost) end)

	local function RefreshMsgPreview()
		if not msgOn then
			msgPreviewText:Hide()
			return
		end
		Pixel.ApplyFont(msgPreviewText, msgSizeVal, BUI.GetGlobalFont(), 'OUTLINE')
		local color = msgColorVal or { EffectiveGlowColor() }
		msgPreviewText:SetTextColor(color[1], color[2], color[3], 1)
		msgPreviewText:SetText(msgTextVal)
		local point, relPoint, baseY = CDM.GetProcMsgAnchor(msgAnchorVal)
		msgPreviewText:ClearAllPoints()
		msgPreviewText:SetPoint(point, preview, relPoint, Pixel.Scale(msgOffXVal), Pixel.Scale(baseY + msgOffYVal))
		msgPreviewText:Show()
	end

	Section('Trigger')

	local rowTrigger = Row('When')
	local triggerDD = Controls.Dropdown(rowTrigger, nil, {
		{ value = 'proc', text = 'It procs' },
		{ value = 'appear', text = 'Its own buff is active' },
		{ value = 'watch', text = 'Another buff is active' },
		{ value = 'both', text = 'It procs, or its own buff is active' },
	}, trigVal, function(val)
		trigVal = val
		Refresh()
		if val == 'watch' and not ParseWatchSpell() then watchEdit:SetFocus() end
	end, nil, 300)
	rowTrigger:Place(triggerDD, 300)

	local rowWatch = Row('Buff to watch', function() return trigVal == 'watch' end)
	local watchBox = Controls.TextBox(rowWatch, nil, watchText, nil, 'Only buffs shown in Buff Icons or Buff Bars can fire this alert.', 300)
	rowWatch:Place(watchBox, 300)
	watchEdit = Widget.Unwrap(watchBox).editbox

	local noteTrigger = Note(true)

	local function TriggerNote()
		if trigVal == 'proc' then
			return "Uses Blizzard's proc highlight for this spell. Nothing else to set up.", false
		end
		if trigVal == 'watch' then
			local id = ParseWatchSpell()
			if not id then
				return 'Type a buff name above and pick it from the list. Only buffs shown in Buff Icons or Buff Bars can fire this alert.', true
			end
			local name = C_Spell.GetSpellName(id) or ('Spell ' .. id)
			local source = CDM.FindTrackedBuffSource(id)
			if not source then
				return name .. " isn't tracked in Buff Icons or Buff Bars, so this alert can't fire.", true
			end
			if not source.displayed then
				return name .. ' is in ' .. source.label .. " but set to Not Displayed. Move it out of Not Displayed in /cdm or this alert can't fire.", true
			end
			return name .. ' is tracked in ' .. source.label .. '. The alert fires whenever it is shown there.', false
		end
		if not buffSource then
			return spellName .. "'s buff isn't tracked in Buff Icons or Buff Bars, so this alert can't fire. Pick \"Another buff is active\" to watch a tracked buff instead.", true
		end
		local buffName = buffSource.viaSpellID and (C_Spell.GetSpellName(buffSource.viaSpellID) or spellName) or spellName
		if not buffSource.displayed then
			return buffName .. ' is in ' .. buffSource.label .. " but set to Not Displayed. Move it out of Not Displayed in /cdm or this alert can't fire.", true
		end
		return buffName .. ' is tracked in ' .. buffSource.label .. '. The alert fires whenever it is shown there.', false
	end

	Section('Glow')

	local rowLight = Row('Light up', function() return trigVal ~= 'proc' end)
	local cooldownLabel = legacyTargetID and ((C_Spell.GetSpellName(legacyTargetID) or 'Target') .. "'s icon") or "This spell's icon"
	local lightDD = Controls.Dropdown(rowLight, nil, {
		{ value = 'cooldown', text = cooldownLabel },
		{ value = '', text = "The buff's icon" },
		{ value = 'both', text = 'Both icons' },
	}, glowTargetVal, function(val) glowTargetVal = val end, nil, 220)
	rowLight:Place(lightDD, 220)

	local rowStyle = Row('Style')
	local styleOptions = { { value = '', text = 'Global default' } }
	for _, def in ipairs(CDM.GLOW_TYPES) do
		styleOptions[#styleOptions + 1] = { value = def.id, text = def.name }
	end
	local styleDD = Controls.Dropdown(rowStyle, nil, styleOptions, styleVal, function(val)
		styleVal = val
		RefreshGlowPreview()
	end, nil, 160)
	rowStyle:Place(styleDD, 160)
	local colorCheckFrame
	local glowSwatch = Controls.ColorSwatch(rowStyle, {
		r = select(1, EffectiveGlowColor()), g = select(2, EffectiveGlowColor()),
		b = select(3, EffectiveGlowColor()), a = select(4, EffectiveGlowColor()),
		tooltip = 'Glow color. Picking one turns on the custom color.',
		callback = function(r, g, b, a, cancelled)
			if cancelled then return end
			chosenColor = { r, g, b, a }
			useColor = true
			colorCheckFrame:SetValue(true)
			RefreshGlowPreview()
			RefreshMsgPreview()
		end,
	})
	local glowSwatchFrame = Widget.Unwrap(glowSwatch)
	rowStyle:Place(glowSwatch, 18, 8)
	local colorCheck = Controls.StampCheckbox(rowStyle, 'Custom color', useColor, function(v)
		useColor = v
		glowSwatchFrame:SetColor(EffectiveGlowColor())
		RefreshGlowPreview()
		RefreshMsgPreview()
	end)
	colorCheckFrame = Widget.Unwrap(colorCheck)
	rowStyle:Place(colorCheck, colorCheckFrame:GetWidth())

	local rowSpeed = Row('Speed')
	local speedStep = Controls.Stepper(rowSpeed, nil, speedVal, 25, 400, 25, function(v)
		speedVal = v
		RefreshGlowPreview()
	end, 88, 24)
	rowSpeed:Place(speedStep, 88, 6)
	rowSpeed:PlaceText('% of normal')

	local rowPixel = Row('Pixel glow')
	rowPixel:PlaceText('Lines')
	local linesStep = Controls.Stepper(rowPixel, nil, linesVal, 4, 16, 1, function(v)
		linesVal = v
		RefreshGlowPreview()
	end, 72, 24)
	rowPixel:Place(linesStep, 72, 14)
	rowPixel:PlaceText('Thickness')
	local thickStep = Controls.Stepper(rowPixel, nil, thickVal, 1, 5, 1, function(v)
		thickVal = v
		RefreshGlowPreview()
	end, 72, 24)
	rowPixel:Place(thickStep, 72)

	local rowWhile = Row('Glow while', function() return trigVal ~= 'proc' end)
	local whileDD = Controls.Dropdown(rowWhile, nil, {
		{ value = 'always', text = 'The buff is up' },
		{ value = 'below', text = 'The buff is expiring' },
		{ value = 'above', text = 'The buff is fresh' },
	}, glowModeVal, function(val)
		glowModeVal = val
		Refresh()
	end, nil, 220)
	rowWhile:Place(whileDD, 220)

	local rowTiming = Row('Timing', function() return trigVal ~= 'proc' and glowModeVal ~= 'always' end)
	rowTiming:PlaceText('Threshold')
	local threshStep = Controls.Stepper(rowTiming, nil, glowThreshVal, 1, 30, 1, function(v) glowThreshVal = v end, 72, 24)
	rowTiming:Place(threshStep, 72, 4)
	rowTiming:PlaceText('s', 14)
	rowTiming:PlaceText('Duration')
	local durStep = Controls.Stepper(rowTiming, nil, durVal, 0, 120, 1, function(v) durVal = v end, 72, 24)
	rowTiming:Place(durStep, 72, 4)
	rowTiming:PlaceText(autoDur and ('s (auto ' .. autoDur .. ')') or 's')

	Section('Alerts')

	local rowMsg = Row('Message')
	local msgToggle = Controls.Toggle(rowMsg, nil, msgOn, function(v)
		msgOn = v
		Refresh()
	end, 0, true, 'Show this text on the icon while the alert is active.', 40)
	rowMsg:Place(msgToggle, 40, 10)
	local msgBox = Controls.TextBox(rowMsg, nil, msgTextVal, function(t) msgTextVal = t end, nil, 300)
	rowMsg:Place(msgBox, 300)
	local msgEdit = Widget.Unwrap(msgBox).editbox
	HookScript(msgEdit, 'OnTextChanged', function(box)
		msgTextVal = box:GetText() or ''
		RefreshMsgPreview()
	end)

	local rowMsgStyle = Row('Message style', function() return msgOn end)
	local posDD = Controls.Dropdown(rowMsgStyle, nil, CDM.PROC_MSG_POSITIONS, msgAnchorVal, function(val)
		msgAnchorVal = val
		RefreshMsgPreview()
	end, nil, 120)
	rowMsgStyle:Place(posDD, 120)
	rowMsgStyle:PlaceText('Size')
	local sizeStep = Controls.Stepper(rowMsgStyle, nil, msgSizeVal, 8, 32, 1, function(v)
		msgSizeVal = v
		RefreshMsgPreview()
	end, 72, 24)
	rowMsgStyle:Place(sizeStep, 72)
	local msgCheckFrame
	local initMsgColor = msgColorVal or { EffectiveGlowColor() }
	local msgSwatch = Controls.ColorSwatch(rowMsgStyle, {
		r = initMsgColor[1], g = initMsgColor[2], b = initMsgColor[3], a = initMsgColor[4] or 1,
		tooltip = 'Message color. Picking one turns on the custom color.',
		callback = function(r, g, b, a, cancelled)
			if cancelled then return end
			msgColorVal = { r, g, b, a }
			msgCheckFrame:SetValue(true)
			RefreshMsgPreview()
		end,
	})
	local msgSwatchFrame = Widget.Unwrap(msgSwatch)
	rowMsgStyle:Place(msgSwatch, 18, 8)
	local msgCheck = Controls.StampCheckbox(rowMsgStyle, 'Custom color', msgColorVal ~= nil, function(v)
		if v then
			msgColorVal = { EffectiveGlowColor() }
		else
			msgColorVal = nil
		end
		local color = msgColorVal or { EffectiveGlowColor() }
		msgSwatchFrame:SetColor(color[1], color[2], color[3], color[4] or 1)
		RefreshMsgPreview()
	end)
	msgCheckFrame = Widget.Unwrap(msgCheck)
	rowMsgStyle:Place(msgCheck, msgCheckFrame:GetWidth())

	local rowMsgOffset = Row('Message offset', function() return msgOn end)
	rowMsgOffset:PlaceText('X')
	local offXStep = Controls.Stepper(rowMsgOffset, nil, msgOffXVal, -200, 200, 1, function(v)
		msgOffXVal = v
		RefreshMsgPreview()
	end, 84, 24)
	rowMsgOffset:Place(offXStep, 84, 14)
	rowMsgOffset:PlaceText('Y')
	local offYStep = Controls.Stepper(rowMsgOffset, nil, msgOffYVal, -200, 200, 1, function(v)
		msgOffYVal = v
		RefreshMsgPreview()
	end, 84, 24)
	rowMsgOffset:Place(offYStep, 84)

	local rowTTS = Row('Text-to-speech', function() return hasTTS end)
	local ttsToggle = Controls.Toggle(rowTTS, nil, ttsOn, function(v) ttsOn = v end, 0, true, nil, 40)
	rowTTS:Place(ttsToggle, 40, 10)
	rowTTS:PlaceText('Speaks the message aloud when the alert fires.')

	local rowSound = Row('Sound')
	local soundDD = Controls.Dropdown(rowSound, nil, SOUND_OPTIONS, soundVal, function(val)
		soundVal = val
		if val and val ~= 0 then PlaySound(val, 'Master') end
	end, nil, 220)
	rowSound:Place(soundDD, 220)

	local iconEdit
	local initialIconText = ''
	if viewerSettings then
		Section('Icon')
		local overrides = CDM.GetIconOverrides(viewerSettings)
		local currentOverride = overrides[spellID]
		initialIconText = currentOverride and tostring(currentOverride) or ''
		local rowIcon = Row('Override texture')
		local iconBox = Controls.TextBox(rowIcon, nil, initialIconText, nil, nil, 300)
		rowIcon:Place(iconBox, 300)
		iconEdit = Widget.Unwrap(iconBox).editbox
		HookScript(iconEdit, 'OnTextChanged', function(self)
			local text = self:GetText():gsub('^%s+', ''):gsub('%s+$', '')
			if text == '' then
				preview:SetTexture(defaultIcon)
			elseif tonumber(text) then
				preview:SetTexture(tonumber(text))
			elseif text:find('[\\/]') then
				if not preview:SetTexture(text) then preview:SetTexture(defaultIcon) end
			end
		end)
		local noteIcon = Note(true)
		noteIcon:SetNote('Texture ID or icon name, e.g. ability_hunter_focusedaim. Leave empty for the default icon.', false)
	end

	Refresh = function()
		local note, warn = TriggerNote()
		noteTrigger:SetNote(note, warn)
		Relayout()
		RefreshGlowPreview()
		RefreshMsgPreview()
	end

	HookScript(watchEdit, 'OnTextChanged', function(box, userInput)
		if not userInput then return end
		watchText = box:GetText() or ''
		watchID = nil
		Refresh()
	end)
	Controls.AttachAutocomplete(watchEdit, SearchTrackedBuffs, function(item)
		watchID = item.id
		watchText = DisplayText(item.id, item.name)
		watchEdit:SetText(watchText)
		watchEdit:ClearFocus()
		Refresh()
	end, Widget.Unwrap(watchBox))

	local function CurrentCfg()
		local text = msgTextVal or ''
		local customText = (text ~= '' and text ~= spellName .. ' Proc!') and text or nil
		local colorToSave
		if useColor then
			colorToSave = chosenColor or { fallbackColor[1], fallbackColor[2], fallbackColor[3], fallbackColor[4] or 1 }
		end
		local buffTrigger = trigVal ~= 'proc'
		local timed = buffTrigger and glowModeVal ~= 'always'
		return {
			trigger = (trigVal == 'watch' and 'appear') or (buffTrigger and trigVal or nil),
			watchSpell = trigVal == 'watch' and ParseWatchSpell() or nil,
			glowTarget = (buffTrigger and glowTargetVal ~= '') and glowTargetVal or nil,
			glowTargetSpell = (buffTrigger and glowTargetVal ~= '') and legacyTargetID or nil,
			glowMode = timed and glowModeVal or nil,
			glowThreshold = timed and glowThreshVal or nil,
			duration = (timed and durVal > 0) and durVal or nil,
			style = styleVal ~= '' and styleVal or nil,
			color = colorToSave,
			speed = speedVal ~= globalGlow.speed and speedVal or nil,
			lines = linesVal ~= globalGlow.lines and linesVal or nil,
			thickness = thickVal ~= globalGlow.thickness and thickVal or nil,
			msg = msgOn or nil,
			msgText = customText,
			msgColor = msgColorVal,
			msgAnchor = msgAnchorVal ~= 'center' and msgAnchorVal or nil,
			msgSize = msgSizeVal ~= 14 and msgSizeVal or nil,
			msgOffsetX = msgOffXVal ~= 0 and msgOffXVal or nil,
			msgOffsetY = msgOffYVal ~= 0 and msgOffYVal or nil,
			tts = ttsOn or nil,
			sound = (soundVal and soundVal ~= 0) and soundVal or nil,
		}
	end

	local CFG_FIELDS = {
		'trigger', 'watchSpell', 'glowTarget', 'glowTargetSpell', 'glowMode', 'glowThreshold', 'duration', 'style', 'color',
		'speed', 'lines', 'thickness', 'msg', 'msgText', 'msgColor', 'msgAnchor',
		'msgSize', 'msgOffsetX', 'msgOffsetY', 'tts', 'sound',
	}
	local function CfgEquals(a, b)
		for _, field in ipairs(CFG_FIELDS) do
			local av, bv = a[field], b[field]
			if type(av) == 'table' and type(bv) == 'table' then
				if av[1] ~= bv[1] or av[2] ~= bv[2] or av[3] ~= bv[3] or (av[4] or 1) ~= (bv[4] or 1) then
					return false
				end
			elseif av ~= bv then
				return false
			end
		end
		return true
	end

	local initialCfg = CurrentCfg()

	local function SaveIconOverride()
		if not viewerSettings or not iconEdit then return end
		local text = iconEdit:GetText()
		if text == initialIconText then return end
		CDM.SetIconOverride(viewerSettings, spellID, ParseIconValue(text))
		CDM.RefreshIconOverrideForSpell(spellID)
		CDM.Custom.Refresh()
	end

	DoSave = function(close)
		CDM.SetProcConfig(spellID, CurrentCfg())
		SaveIconOverride()
		close()
		RefreshIconList()
	end

	ConfirmRemove = function(close)
		local function RemoveDone()
			close()
			RefreshIconList()
		end
		Modals.Confirm({
			parent = dialog,
			title = 'Remove Alert',
			message = famCfgCount > 0
				and ('Remove this alert, or the alerts on all ' .. (famCfgCount + (hasSaved and 1 or 0)) .. ' spells in this family?')
				or ('Remove the alert for ' .. spellName .. '?'),
			confirmText = 'Remove',
			laterText = famCfgCount > 0 and 'Remove All' or nil,
			onConfirm = function()
				CDM.SetProcConfig(spellID, nil)
				RemoveDone()
			end,
			onLater = famCfgCount > 0 and function()
				CDM.SetProcConfig(spellID, nil)
				for _, id in ipairs(famIDs) do
					CDM.SetProcConfig(id, nil)
				end
				RemoveDone()
			end or nil,
		})
	end

	NavigateTo = function(otherID)
		local function Go()
			Close()
			ShowProcModal(CDM, otherID, RefreshIconList, otherID ~= backTo and spellID or nil, viewerSettings)
		end
		if CfgEquals(CurrentCfg(), initialCfg) and (not iconEdit or iconEdit:GetText() == initialIconText) then
			Go()
			return
		end
		Modals.Confirm({
			parent = dialog,
			title = 'Unsaved Changes',
			message = 'Save your changes to ' .. spellName .. ' before switching?',
			confirmText = 'Save',
			laterText = 'Discard',
			onConfirm = function()
				CDM.SetProcConfig(spellID, CurrentCfg())
				SaveIconOverride()
				RefreshIconList()
				Go()
			end,
			onLater = Go,
		})
	end

	Refresh()
end

local function BuildIconManagementContent(container, viewerKey, viewerSettings, listH)
	local CDM = BUI.CDM
	CDM._iconListRefreshers = CDM._iconListRefreshers or {}

	local function CollectAllIcons()
		local icons, seen = {}, {}
		local customSeen = {}
		CollectCustomIcons(CDM, viewerSettings, icons, seen, customSeen, viewerKey)
		CollectTrackedIcons(CDM, viewerKey, viewerSettings, icons, seen, customSeen)
		CollectCooldownViewerSpells(CDM, viewerKey, icons, seen, customSeen)
		SortIcons(CDM, viewerSettings, icons)
		return icons
	end

	local iconList
	local disabledIDs = {}
	local RefreshIconList
	local stickyOrder = {}

	function RefreshIconList(preserveOrder)
		iconList:ClearItems()
		wipe(disabledIDs)
		local icons = CollectAllIcons()
		if preserveOrder and next(stickyOrder) then
			local idx = {}
			for i, data in ipairs(icons) do idx[data] = i end
			table.sort(icons, function(a, b)
				local posA = stickyOrder[GetDataSortKey(a)]
				local posB = stickyOrder[GetDataSortKey(b)]
				if posA and posB and posA ~= posB then return posA < posB end
				if posA and not posB then return true end
				if posB and not posA then return false end
				return idx[a] < idx[b]
			end)
		end
		wipe(stickyOrder)
		for i, data in ipairs(icons) do
			stickyOrder[GetDataSortKey(data)] = i
		end
		local hidden = CDM.GetHiddenIcons(viewerSettings)
		local manualBuffs = viewerKey == "buffs" and CDM.GetManualBuffs(viewerSettings) or {}
		local cdmSections = BuildCDMSectionMap()

		for _, data in ipairs(icons) do
			local name = data.name
			if data.isPermanent then
				name = name .. ' |cff44bbff[Auto Added]|r'
				if data.isHiddenPassive then
					name = name .. ' |cffff8844[Hidden (No Use)]|r'
				end
			end
			if data.isCustom and not data.isPermanent then
				local manualBuff = manualBuffs[data.id]
				if manualBuff and manualBuff.duration then
					name = name .. ' ' .. COLOR_GREEN .. '[' .. manualBuff.duration .. 's]' .. COLOR_END
					if manualBuff.glow and manualBuff.glow.enabled then
						local glow = manualBuff.glow
						if glow.mode == 'below' then
							name = name .. ' |cffff88ff[Glow <' .. (glow.threshold or 5) .. 's]|r'
						elseif glow.mode == 'above' then
							name = name .. ' |cffff88ff[Glow >' .. (glow.threshold or 5) .. 's]|r'
						else
							name = name .. ' |cffff88ff[Glow]|r'
						end
						if glow.warning and glow.warning.enabled then
							name = name .. ' |cffff4444[Warn]|r'
						end
					end
					if viewerKey == 'buffs' then
						local _, scope = CDM.GetManualBuffScope(viewerSettings, data.id)
						if scope == 'global' then
							name = name .. ' |cff66ccff[Global]|r'
						elseif scope == 'spec' then
							name = name .. ' |cffaaaaaa[Per Spec]|r'
						end
					end
				else
					name = name .. ' [Custom]'
				end
			end
			local sectionID
			if data.isCustom then
				if not data.isPermanent and not data.isItem then sectionID = data.numericId end
			elseif not data.isInOtherViewer then
				sectionID = data.numericId or (type(data.id) == 'number' and data.id or nil)
			end
			if sectionID then
				local section = cdmSections[sectionID]
				if section then
					if not section.displayed then
						name = name .. ' ' .. COLOR_YELLOW .. '[CDM: Not Displayed]' .. COLOR_END
					else
						local parts = {}
						for _, entry in ipairs(CDM_SECTION_VIEWERS) do
							if section.labels[entry.label] then parts[#parts + 1] = entry.label end
						end
						if #parts > 0 then
							name = name .. ' ' .. COLOR_BLUE .. '[CDM: ' .. table.concat(parts, ' + ') .. ']' .. COLOR_END
						end
					end
				end
			end
			if data.unavailableTag then
				name = name .. ' (' .. data.unavailableTag .. ')'
			elseif not data.isItem and data.numericId and CDM.IsRacialSpell(data.numericId) then
				name = name .. ' (Racial)'
			end
			if not data.isItem then
				local checkID = data.numericId or (type(data.id) == 'number' and data.id)
				if checkID then
					local alts = BUI.Tools.GetChoiceAlternatives(checkID)
					if alts and #alts > 1 then
						name = name .. ' ' .. COLOR_ORANGE .. '[Choice Node]' .. COLOR_END
					end
				end
			end

			local isAutoSlotRow = type(data.id) == 'string' and
				(data.id:match('^trinket:%d$') ~= nil or data.id:match('^racial:%d$') ~= nil)
			local hiddenKey = (not isAutoSlotRow) and data.isCustom and data.numericId and ('custom:' .. data.numericId) or data.id
			local forceShow = data.isCustom and viewerKey ~= 'buffs' and CDM.IsAlwaysShow(viewerSettings, hiddenKey)
			local unavailable = data.isCustom and data.unavailableTag and not forceShow
			local blocked = data.isUnlearned or data.isInOtherViewer or unavailable or data.isBlacklisted
			if blocked then disabledIDs[data.id] = true end

			if viewerKey ~= 'buffs' and CDM.IsShowOnlyOnCD(viewerSettings, hiddenKey) then
				name = name .. ' |cff44bbff[On CD Only]|r'
			end
			if viewerKey ~= 'buffs' and CDM.IsHideWhenZero(viewerSettings, hiddenKey) then
				name = name .. ' |cff44ddaa[Hide @ 0]|r'
			end
			local procTagID
			if not isAutoSlotRow then
				if type(data.id) == 'number' then
					procTagID = data.id
				elseif type(data.id) == 'string' then
					procTagID = tonumber(data.id:match('^%d+$'))
				end
			end
			if procTagID then
				local procCfg = CDM.GetProcConfig(procTagID)
				if procCfg then
					if procCfg.trigger == 'appear' then
						name = name .. ' |cffffe066[On Appear]|r'
					elseif procCfg.trigger == 'both' then
						name = name .. ' |cffffe066[Proc + Appear]|r'
					else
						name = name .. ' |cffffe066[Proc]|r'
					end
				end
			end
			if forceShow then
				name = name .. ' |cffffcc33[Always Show]|r'
			end
			if blocked then
				if data.isBlacklisted then
					name = name .. ' |cffc080ff[Blacklisted]|r'
				else
					name = name .. ' |cffff4040[Disabled]|r'
				end
			end
			local enabled = not blocked and not CDM.IsIconHiddenEffective(viewerKey, hidden, hiddenKey)
			local removable = data.isCustom and not data.isPermanent
			local row = iconList:AddItem(data.icon, name, data.id, removable, enabled)

			if row then
				row.data._sortKey = GetDataSortKey(data)
			end
			if blocked and row then
				row:SetLocked(true)
			end
			if row and data.isNotDisplayed then
				row.data._isNotDisplayed = true
			end
		end
	end
	CDM._iconListRefreshers[viewerKey] = function() RefreshIconList(true) end

	local function CommitAdd(store)
		CDM.AddCustomSpell(viewerSettings, store, false)
		CDM.Custom.Refresh(viewerKey)
		RefreshIconList()
	end

	local function NameFor(id, isItem)
		if isItem then return (C_Item.GetItemInfo(id)) or ('Item ' .. id) end
		return C_Spell.GetSpellName(id) or ('Spell ' .. id)
	end

	local function DoAdd(id, isItem)
		if not id then return end
		if viewerKey ~= "buffs" and not isItem and CDM.IsBlizzardCDMSpell(id, viewerKey) then
			BUILib.Toast.Error('Already tracked', NameFor(id, isItem) .. ' is in this viewer')
			return
		end

		if viewerKey ~= 'buffs' and not isItem and not (C_SpellBook.IsSpellKnown(id)) then
			local activeID = BUI.Tools.GetActiveChoice(id)
			if activeID and activeID ~= id then
				CDM.SetChoiceNode(viewerSettings, id, activeID)
			end
		end

		local spells = CDM.GetCustomSpells(viewerSettings)
		local store = isItem and ('item:' .. id) or id
		for _, existing in ipairs(spells) do
			if existing == store or (not isItem and tonumber(existing) == id) then
				BUILib.Toast.Info('Already added', NameFor(id, isItem))
				return
			end
		end

		if viewerKey == 'buffs' and not isItem then
			local existingOverrides = CDM.GetIconOverrides(viewerSettings)
			if not existingOverrides[id] then
				local pinned = BUI.Tools.GetStableSpellTexture(id)
				if pinned then CDM.SetIconOverride(viewerSettings, id, pinned) end
			end
		end

		if viewerKey == "buffs" then
			ShowManualBuffModal(CDM, viewerSettings, viewerKey, store, RefreshIconList, function()
				CDM.Custom.Refresh(viewerKey)
				RefreshIconList()
			end)
		else
			CommitAdd(store)
			BUILib.Toast.Success('Added!', NameFor(id, isItem))
		end
	end

	iconList = Layout.ItemList(container, {
		hint = 'Search spells/items, paste ID, or drag here...',
		height = listH,
		orderable = true,
		noDragPicker = viewerKey == "buffs",
		onReorder = function(newData)
			local order = {}
			for i, item in ipairs(newData) do order[i] = item._sortKey or item.id end
			CDM.SetIconOrder(viewerSettings, order)
			CDM.RefreshLayoutOnly()
		end,
		showCheckbox = true,
		searchFunc = function(q, cap) return BUI.Lookup.SearchSpellsAndItems(q, cap, viewerKey) end,
		onBindRow = function(frame, entry)
			if entry._isNotDisplayed then
				if not frame._ndIndicator then
					local indicator = Widget.Unwrap(Controls.Icon(frame, {
						size = Pixel.Scale(18),
						tooltip = 'Not Displayed \xe2\x80\x94 click for info',
						onClick = function()
							Modals.Message({
								parent = BUI.PageEngine.window.frame,
								title = 'Not Displayed',
								message = 'You have items in the Not Displayed section.\n\nMove them out of Not Displayed in /cdm to add them.',
							})
						end,
					}))
					indicator:SetPoint('RIGHT', frame.id, 'LEFT', Pixel.Scale(-4), 0)
					frame._ndIndicator = indicator
				end
				frame._ndIndicator:Show()
			elseif frame._ndIndicator then
				frame._ndIndicator:Hide()
			end

			local isBuffRow = viewerKey == 'buffs' and entry.removable
			local isTrinketRow = type(entry.id) == 'string' and entry.id:match('^trinket:%d$') ~= nil
			local isRacialRow = type(entry.id) == 'string' and entry.id:match('^racial:%d$') ~= nil
			local procRowSpellID
			if not (isBuffRow or isTrinketRow or isRacialRow) and not entry._isNotDisplayed then
				if type(entry.id) == 'number' then
					procRowSpellID = entry.id
				elseif type(entry.id) == 'string' then
					procRowSpellID = tonumber(entry.id:match('^%d+$'))
				end
			end
			if ((isBuffRow or isTrinketRow or isRacialRow) and frame.xBtn) or procRowSpellID then
				if not frame._cogBtn then
					local cogConfig = { size = Pixel.Scale(18), tooltip = 'Edit' }
					local cog = Widget.Unwrap(Controls.Icon(frame, cogConfig))
					cog:SetFrameLevel(frame:GetFrameLevel() + 5)
					frame._cogBtn = cog
					frame._cogConfig = cogConfig
				end
				if isTrinketRow then
					frame._cogBtn:ClearAllPoints()
					frame._cogBtn:SetPoint('RIGHT', frame, 'RIGHT', Pixel.Scale(-6), 0)
					frame._cogConfig.tooltip = 'Edit trinket slot'
					frame._cogBtn:SetCallback(function()
						ShowTrinketSlotModal(CDM, viewerSettings, entry.id, RefreshIconList)
					end)
				elseif isRacialRow then
					frame._cogBtn:ClearAllPoints()
					frame._cogBtn:SetPoint('RIGHT', frame, 'RIGHT', Pixel.Scale(-6), 0)
					frame._cogConfig.tooltip = 'Edit racial slot'
					frame._cogBtn:SetCallback(function()
						ShowRacialSlotModal(CDM, viewerSettings, viewerKey, entry.id, RefreshIconList)
					end)
				elseif isBuffRow then
					frame._cogBtn:ClearAllPoints()
					frame._cogBtn:SetPoint('RIGHT', frame.id, 'LEFT', Pixel.Scale(-6), 0)
					frame._cogConfig.tooltip = 'Edit manual buff'
					frame._cogBtn:SetCallback(function()
						ShowManualBuffModal(CDM, viewerSettings, viewerKey, entry.id, RefreshIconList)
					end)
				else
					frame._cogBtn:ClearAllPoints()
					frame._cogBtn:SetPoint('RIGHT', frame.id, 'LEFT', Pixel.Scale(-6), 0)
					frame._cogConfig.tooltip = 'Settings'
					frame._cogBtn:SetCallback(function()
						ShowProcModal(CDM, procRowSpellID, RefreshIconList, nil, viewerSettings)
					end)
				end
				frame._cogBtn:Show()
			elseif frame._cogBtn then
				frame._cogBtn:Hide()
			end
		end,
		onAdd = function(text)
			if not text or text:match('^%s*$') then
				BUILib.Toast.Warning('Nothing to add', 'Type a spell or item name, paste an ID, or drag from your spellbook.')
				return
			end

			local dropItem = text:match('^item:(%d+)')
			if dropItem then DoAdd(tonumber(dropItem), true); return end
			local dropSpell = text:match('^spell:(%d+)')
			if dropSpell then DoAdd(tonumber(dropSpell), false); return end

			local raw = text:match('^%s*(%d+)')
			local num = raw and tonumber(raw)
			if num and Controls.ShowDragDropPicker then
				local _, itemSpellID = GetItemSpell(num)
				Controls.ShowDragDropPicker(nil, num, itemSpellID or num,
					function(selType, selID) DoAdd(selID, selType == 'item') end,
					nil, nil, true
				)
				return
			end
			local id, isItem = BUI.Lookup.ParseSpellOrItemInput(text)
			if not id then id = BUI.Lookup.ParseSpellInput(text) end
			if not id then
				BUILib.Toast.Error('Not found', 'No spell or item matched "' .. text .. '"')
				return
			end
			DoAdd(id, isItem)
		end,
		onSearchSelect = function(item) DoAdd(item.id, item.isItem) end,
		onRemove = function(row)
			if not row.id then return end
			local isAutoSlot = type(row.id) == 'string' and
				(row.id:match('^trinket:%d$') ~= nil or row.id:match('^racial:%d$') ~= nil)
			local function DoDelete()
				CDM.RemoveCustomSpell(viewerSettings, row.id)
				CDM.SetManualBuff(viewerSettings, row.id, nil)
				if not isAutoSlot then
					local numericId = tonumber(tostring(row.id):match('%d+'))
					if numericId then
						if numericId ~= row.id then
							CDM.RemoveCustomSpell(viewerSettings, numericId)
							CDM.SetManualBuff(viewerSettings, numericId, nil)
						end
						CDM.SetBuffTracking(viewerSettings, numericId, nil)
						CDM.SetIconOverride(viewerSettings, numericId, nil)
					end
				end
				CDM.SetIconOverride(viewerSettings, row.id, nil)
				CDM.Custom.Refresh(viewerKey)
				RefreshIconList()
			end

			if viewerKey == 'buffs' then
				local _, scope = CDM.GetManualBuffScope(viewerSettings, row.id)
				if scope == 'global' then
					Modals.Confirm({
						parent = BUI.PageEngine.window.frame,
						title = 'Delete Global Buff?',
						message = 'This buff is saved globally and will be removed from all specs.',
						confirmText = 'Delete', cancelText = 'Cancel',
						onConfirm = DoDelete,
						onCancel = function() RefreshIconList() end,
					})
					return
				end
			end
			DoDelete()
		end,
		onCheckboxChange = function(spellID, enabled, row)
			if disabledIDs[spellID] then return end
			local isCustom = row and row.data and row.data.removable
			local isAutoSlot = type(spellID) == 'string' and
				(spellID:match('^trinket:%d$') ~= nil or spellID:match('^racial:%d$') ~= nil)
			local hideKey
			if isAutoSlot then
				hideKey = spellID
			elseif isCustom then
				local numId = type(spellID) == 'string' and tonumber(tostring(spellID):match('%d+')) or spellID
				hideKey = numId and ('custom:' .. numId) or spellID
			else
				hideKey = spellID
			end
			CDM.SetHiddenIcon(viewerSettings, hideKey, not enabled)
			CDM.RefreshLayoutOnly()
		end,
		onIconClick = function(spellID, row)
			if IsAltKeyDown() and viewerKey ~= 'buffs' then
				local isCustom = row and row.data and row.data.removable
				if not isCustom then return end
				local numId = type(spellID) == 'string' and tonumber(tostring(spellID):match('%d+')) or spellID
				local key = numId and ('custom:' .. numId) or spellID
				local wasOn = CDM.IsAlwaysShow(viewerSettings, key)
				CDM.SetAlwaysShow(viewerSettings, key, not wasOn)
				CDM.SetUpdatePending(true)
				RefreshIconList()
				return
			end
			if IsShiftKeyDown() and viewerKey ~= 'buffs' then
				local isCustom = row and row.data and row.data.removable
				local hideKey
				if isCustom then
					local numId = type(spellID) == 'string' and tonumber(tostring(spellID):match('%d+')) or spellID
					hideKey = numId and ('custom:' .. numId) or spellID
				else
					hideKey = spellID
				end
				local wasOn = CDM.IsShowOnlyOnCD(viewerSettings, hideKey)
				CDM.SetShowOnlyOnCD(viewerSettings, hideKey, not wasOn)
				CDM.UpdateShowOnlyOnCDWatcher()
				CDM.RefreshLayoutOnly()
				RefreshIconList()
				return
			end
			if IsControlKeyDown() and viewerKey == "buffs" then
				if row and row.data and row.data.removable then
					ShowManualBuffModal(CDM, viewerSettings, viewerKey, spellID, RefreshIconList)
				end
			end
		end,
		onRowRightClick = function(spellID, row)
			if not row or not row.data then return end
			local rowData = row.data
			local isCustom = rowData.removable == true
			local isTrinketRow = type(spellID) == 'string' and spellID:match('^trinket:%d$') ~= nil
			local isRacialRow = type(spellID) == 'string' and spellID:match('^racial:%d$') ~= nil
			local isAutoSlot = isTrinketRow or isRacialRow

			local function ComputeHideKey()
				if isAutoSlot then return spellID end
				if isCustom then
					local numId = type(spellID) == 'string' and tonumber(tostring(spellID):match('%d+')) or spellID
					return numId and ('custom:' .. numId) or spellID
				end
				return spellID
			end

			local items = {}
			items[#items + 1] = { text = rowData.name or tostring(spellID), title = true }

			if viewerKey == 'buffs' then
				local rowKey = rowData._sortKey or spellID
				local curRow = CDM.GetBuffRow(viewerSettings, rowKey)
				items[#items + 1] = { separator = true }
				items[#items + 1] = {
					text = 'Buff Row 1',
					checked = curRow == 1,
					callback = function()
						CDM.SetBuffRow(viewerSettings, rowKey, 1)
						CDM.CenterBuffsNow(true)
						RefreshIconList()
					end,
				}
				items[#items + 1] = {
					text = 'Buff Row 2',
					checked = curRow == 2,
					callback = function()
						CDM.SetBuffRow(viewerSettings, rowKey, 2)
						CDM.CenterBuffsNow(true)
						RefreshIconList()
					end,
				}
			end

			if viewerKey ~= 'buffs' then
				local hideKey = ComputeHideKey()
				items[#items + 1] = {
					text = 'Show Only On Cooldown',
					checked = CDM.IsShowOnlyOnCD(viewerSettings, hideKey) and true or false,
					callback = function()
						local wasOn = CDM.IsShowOnlyOnCD(viewerSettings, hideKey)
						CDM.SetShowOnlyOnCD(viewerSettings, hideKey, not wasOn)
						CDM.UpdateShowOnlyOnCDWatcher()
						CDM.RefreshLayoutOnly()
						RefreshIconList()
					end,
				}

				local hideZeroItemID
				if type(spellID) == 'string' then
					hideZeroItemID = tonumber(spellID:match('^item:(%d+)'))
				end
				if not hideZeroItemID and rowData.numericId then
					hideZeroItemID = rowData.numericId
				end
				local isConsumableItem = false
				if hideZeroItemID and not isAutoSlot then
					local _, _, _, equipLoc, _, itemClass = C_Item.GetItemInfoInstant(hideZeroItemID)
					isConsumableItem = itemClass ~= nil and equipLoc ~= 'INVTYPE_TRINKET'
				end
				if isConsumableItem then
					items[#items + 1] = {
						text = 'Hide When 0',
						checked = CDM.IsHideWhenZero(viewerSettings, hideKey) and true or false,
						callback = function()
							local wasOn = CDM.IsHideWhenZero(viewerSettings, hideKey)
							CDM.SetHideWhenZero(viewerSettings, hideKey, not wasOn)
							CDM.UpdateHideWhenZeroWatcher()
							CDM.RefreshLayoutOnly()
							RefreshIconList()
						end,
					}
				end
				if isCustom then
					items[#items + 1] = {
						text = 'Always Show',
						checked = CDM.IsAlwaysShow(viewerSettings, hideKey) and true or false,
						callback = function()
							local wasOn = CDM.IsAlwaysShow(viewerSettings, hideKey)
							CDM.SetAlwaysShow(viewerSettings, hideKey, not wasOn)
							CDM.SetUpdatePending(true)
							RefreshIconList()
						end,
					}
				end
			end

			local procSpellID
			if not isAutoSlot then
				if type(spellID) == 'number' then
					procSpellID = spellID
				elseif type(spellID) == 'string' then
					procSpellID = tonumber(spellID:match('^%d+$'))
				end
			end
			if procSpellID then
				local procCfg = CDM.GetProcConfig(procSpellID)
				items[#items + 1] = { separator = true }
				items[#items + 1] = {
					text = procCfg and 'Settings... |cffffe066(active)|r' or 'Settings...',
					callback = function()
						ShowProcModal(CDM, procSpellID, RefreshIconList, nil, viewerSettings)
					end,
				}
				if procCfg then
					items[#items + 1] = {
						text = '|cffff6666Remove Alert|r',
						callback = function()
							CDM.SetProcConfig(procSpellID, nil)
							RefreshIconList()
						end,
					}
				end
			end

			if isTrinketRow then
				items[#items + 1] = { separator = true }
				local slotNum = tonumber(spellID:match('^trinket:(%d)$'))
				local inv = slotNum == 1 and 13 or 14
				local resolvedItemID = GetInventoryItemID('player', inv)
				local isBl = resolvedItemID and CDM.IsTrinketBlacklisted(viewerSettings, resolvedItemID) or false
				items[#items + 1] = {
					text = isBl and 'Unblacklist Equipped Trinket' or 'Blacklist Equipped Trinket',
					disabled = not resolvedItemID,
					callback = function()
						if not resolvedItemID then return end
						CDM.SetTrinketBlacklisted(viewerSettings, resolvedItemID, not isBl and true or nil)
						CDM.Custom.Refresh(viewerKey)
						RefreshIconList()
					end,
				}
				items[#items + 1] = {
					text = 'Edit Trinket Slot...',
					callback = function() ShowTrinketSlotModal(CDM, viewerSettings, spellID, RefreshIconList) end,
				}
			elseif isRacialRow then
				items[#items + 1] = { separator = true }
				local slotNum = tonumber(spellID:match('^racial:(%d)$'))
				local resolvedSpellID = CDM.ResolveRacialSlot(slotNum)
				local isBl = resolvedSpellID and CDM.IsRacialBlacklisted(viewerSettings, resolvedSpellID) or false
				items[#items + 1] = {
					text = isBl and 'Unblacklist Current Racial' or 'Blacklist Current Racial',
					disabled = not resolvedSpellID,
					callback = function()
						if not resolvedSpellID then return end
						CDM.SetRacialBlacklisted(viewerSettings, resolvedSpellID, not isBl and true or nil)
						CDM.Custom.Refresh(viewerKey)
						RefreshIconList()
					end,
				}
				items[#items + 1] = {
					text = 'Edit Racial Slot...',
					callback = function() ShowRacialSlotModal(CDM, viewerSettings, viewerKey, spellID, RefreshIconList) end,
				}
			elseif viewerKey == 'buffs' and isCustom then
				items[#items + 1] = { separator = true }
				items[#items + 1] = {
					text = 'Set Buff Duration...',
					callback = function() ShowManualBuffModal(CDM, viewerSettings, viewerKey, spellID, RefreshIconList) end,
				}
			end

			if isCustom and not isAutoSlot then
				items[#items + 1] = { separator = true }
				items[#items + 1] = {
					text = '|cffff6060Remove|r',
					callback = function() iconList:RemoveItem(rowData) end,
				}
			end

			local actionable = 0
			for _, it in ipairs(items) do
				if not it.title and not it.separator then actionable = actionable + 1 end
			end
			if actionable == 0 then return end

			Controls.ContextMenu(items, { width = 240 })
		end,
	})

	do
		local hint = container.child:CreateFontString(nil, 'OVERLAY')
		hint:SetFont(BUILib.Font, 10, '')
		hint:SetTextColor(0.45, 0.45, 0.45)
		local parts = { 'Right-click for options' }
		if viewerKey == "buffs" then
			parts[#parts + 1] = 'Ctrl+click = set buff duration'
		else
			parts[#parts + 1] = 'Shift+click = show only on cooldown'
			parts[#parts + 1] = 'Alt+click = always show (ignore Dynamic Show/Hide)'
		end
		hint:SetText(table.concat(parts, '  |  '))
	end

	local btnContainer = CreateFrame('Frame', nil, container.child)
	btnContainer:SetSize(container.width, 26)

	local btnW = math.floor((container.width - 20) / 3)
	local saveBtn = Controls.Button(btnContainer, 'Save Order', btnW, function()
		local items = iconList:GetItems()
		local order, orderSeen = {}, {}
		for i, item in ipairs(items) do
			local key = item._sortKey or item.id
			order[i] = key
			orderSeen[key] = true
			orderSeen[item.id] = true
		end
		local old = CDM.GetIconOrder(viewerSettings)
		if old then
			for _, id in ipairs(old) do
				if not orderSeen[id] then order[#order + 1] = id end
			end
		end
		CDM.SetIconOrder(viewerSettings, order)
		CDM.RefreshLayoutOnly()
		RefreshIconList()
		local _, specName = GetSpecializationInfo(GetSpecialization() or 1)
		BUILib.Toast.Success('Order saved', ('%s spec, %d entries'):format(specName or 'current', #order))
	end)
	saveBtn:SetPoint('LEFT', 0, 0)

	local resetBtn = Controls.Button(btnContainer, 'Reset Order', btnW, function()
		CDM.SetIconOrder(viewerSettings, {})
		RefreshIconList()
		CDM.RefreshLayoutOnly()
		BUILib.Toast.Info('Order reset', 'Icons restored to default sort')
	end)
	resetBtn:SetPoint('LEFT', saveBtn, 'RIGHT', 10, 0)

	local resetAllBtn = Controls.Button(btnContainer, 'Reset All', btnW, function()
		Modals.Confirm({
			parent = BUI.PageEngine.window.frame,
			title = 'Reset All Icons',
			message = 'This will delete all custom spells (across all specs), and reset icon overrides, hidden icons, and saved order for this spec.\n\nContinue?',
			confirmText = 'Reset All',
			cancelText = 'Cancel',
			onConfirm = function()
				CDM.ClearAllCustomSpells(viewerSettings)
				CDM.SetIconOrder(viewerSettings, {})
				local buildKey = CDM.GetBuildKey()
				if viewerSettings.hiddenIcons then viewerSettings.hiddenIcons[buildKey] = nil end
				if viewerSettings.iconOverrides then viewerSettings.iconOverrides[buildKey] = nil end
				if viewerSettings.buffTracking then viewerSettings.buffTracking[buildKey] = nil end
				if viewerSettings.detachedIcons then viewerSettings.detachedIcons[buildKey] = nil end
				if viewerSettings.barColors then viewerSettings.barColors[buildKey] = nil end
				if viewerSettings.buffRows then viewerSettings.buffRows[buildKey] = nil end
				CDM.Custom.Refresh(viewerKey)
				RefreshIconList()
				CDM.RefreshLayoutOnly()
				BUILib.Toast.Success('Reset complete', 'Custom spells, overrides, and order cleared for this spec')
			end,
		})
	end)
	resetAllBtn:SetPoint('LEFT', resetBtn, 'RIGHT', 10, 0)

	Layout.PositionInTab(container, btnContainer, 26, 4)
	BUI.Prof.After('Pages.CDMIconManagement', 0.1, RefreshIconList)
	return iconList
end

local function CreateContentWrapper(parent, width)
	local wrapper = CreateFrame('Frame', nil, parent)
	wrapper:SetWidth(width)
	wrapper:SetHeight(100)
	return Layout.ApplyContentMixin({
		frame = wrapper,
		child = wrapper,
		width = width,
	})
end

function BUI.BuildCDMIconManagementTab(tab, db)
	local CDM = BUI.CDM

	local viewerKeys = { 'essential', 'utility', 'buffs' }
	local viewerItems = {
		{ value = 1, text = 'Essential' },
		{ value = 2, text = 'Utility' },
		{ value = 3, text = 'Buffs' },
	}

	local containers = {}
	local activeIdx = BUI._cdmViewerIdx or 1

	local grid = BUILib.PageKit.RowGrid(tab)
	local autosortRow
	grid:Add({
		spanFull = true,
		title = 'Viewer',
		description = 'Each viewer keeps its own icon list.',
		controlWidth = 130,
		control = function(row)
			return Controls.Dropdown(row, nil, viewerItems, activeIdx, function(val)
				activeIdx = val
				BUI._cdmViewerIdx = val
				for i, card in ipairs(containers) do
					card.frame:SetShown(i == val)
				end
				autosortRow:SetValue(db.cdm[viewerKeys[val]].noAutosort or false)
			end, nil, 120)
		end,
	})
	autosortRow = grid:Add({
		spanFull = true,
		title = 'No Autosort',
		description = 'Keep manual order; new icons are not sorted in.',
		checked = db.cdm[viewerKeys[activeIdx]].noAutosort or false,
		callback = function(v)
			local cfg = db.cdm[viewerKeys[activeIdx]]
			cfg.noAutosort = v or nil
			CDM.RefreshLayoutOnly()
		end,
	})
	grid:Flush()

	local dropdownAnchor = tab.lastControl

	local OVERHEAD = 270
	local tabVisH = tab.frame:GetHeight()
	if not tabVisH or tabVisH < 100 then tabVisH = 600 end
	local listH = math.max(200, tabVisH - OVERHEAD)

	for i, key in ipairs(viewerKeys) do
		local viewerCfg = db.cdm[key]
		local content = CreateContentWrapper(tab.child, tab.width)
		content.frame:SetPoint('TOPLEFT', dropdownAnchor, 'BOTTOMLEFT', -Layout.DEFAULT_PADDING, 0)
		content.frame:SetPoint('RIGHT', tab.child, 'RIGHT', 0, 0)
		containers[i] = content

		if i ~= activeIdx then
			content.frame:Hide()
		end

		local list = BuildIconManagementContent(content, key, viewerCfg, listH)
		content.frame:SetHeight(math.abs(content.y) + 20)
		containers[i]._iconList = list
	end

	local maxH = 0
	for _, card in ipairs(containers) do
		local containerH = math.abs(card.y) + 20
		if containerH > maxH then maxH = containerH end
	end
	tab:AddY(10 + maxH)

	local baseContentH = containers[1] and math.abs(containers[1].y) + 20 or 400
	local lastListH = listH
	HookScript(tab.frame, 'OnSizeChanged', function(_, w, h)
		local newListH = math.max(200, h - OVERHEAD)
		if math.abs(newListH - lastListH) < 5 then return end
		local delta = newListH - listH
		lastListH = newListH
		for _, card in ipairs(containers) do
			card._iconList:SetListHeight(newListH)
			card.frame:SetHeight(baseContentH + delta)
		end
	end)
end

BUI.ShowCDMProcModal = ShowProcModal
BUI.ShowCDMIconOverrideModal = ShowIconOverrideModal
BUI.ShowCDMPotionModal = ShowPotionDisplayModal
