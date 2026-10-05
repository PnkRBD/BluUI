local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Controls, Layout, Modals = BUILib.Controls, BUILib.Layout, BUILib.Modals

local PAGE_WIDTH = 960
local PREVIEW_HEIGHT = 150
local MENU_WIDTH = 150
local SNAPSHOT_WIDTH = 220
local TEXT_RANGE = 30
local KEYBIND_RANGE = 20
local OFFSET_RANGE = 40
local MOCK_WIDTH = 620
local MOCK_HEIGHT = 140
local MOCK_MAX_ICONS = 40
local HOST_HEIGHT = 640
local HOST_PAD = 8
local WHITE = 'Interface\\Buttons\\WHITE8x8'
local DEFAULT_ICON = 134400
local MOCK_KEYS = { 'Q', 'E', 'R', 'F', 'T', 'G', 'Z', 'X', 'C', 'V' }
local MOCK_BARS = {
	{ icon = 'Interface\\Icons\\Spell_Nature_Rejuvenation', name = 'Rejuvenation', duration = '12s', fill = 0.78, stacks = '3' },
	{ icon = 'Interface\\Icons\\Ability_Warrior_BattleShout', name = 'Battle Shout', duration = '48s', fill = 0.52 },
	{ icon = 'Interface\\Icons\\Spell_Holy_PowerWordShield', name = 'Power Word: Shield', duration = '8s', fill = 0.24, stacks = '2' },
}
local POINTS = {}
for _, point in ipairs({ 'TOPLEFT', 'TOP', 'TOPRIGHT', 'LEFT', 'CENTER', 'RIGHT', 'BOTTOMLEFT', 'BOTTOM', 'BOTTOMRIGHT' }) do
	POINTS[#POINTS + 1] = { value = point, text = point:sub(1, 1) .. point:sub(2):lower():gsub('left', ' left'):gsub('right', ' right') }
end
local GROWTHS = { { value = 'DOWN', text = 'Down' }, { value = 'UP', text = 'Up' } }
local STACK_ATTACH = { { value = 'ICON', text = 'The icon' }, { value = 'BAR', text = 'The bar' } }
local VIEWERS = {
	{ key = 'essential', label = 'Essential', title = 'Essential viewer', description = 'The Blizzard Essential viewer, reskinned.', keybinds = true, frame = 'BUI_EssentialCooldownViewer' },
	{ key = 'utility', label = 'Utility', title = 'Utility viewer', description = 'Utility and defensive cooldowns from the Utility viewer.', keybinds = true, frame = 'BUI_UtilityCooldownViewer' },
	{ key = 'buffs', label = 'Buff icons', title = 'Buff icons', description = 'Tracked buff icons from the Buff viewer.', frame = 'BUI_BuffCooldownViewer' },
}
local VIEWER_BY_KEY = {}
for _, viewer in ipairs(VIEWERS) do VIEWER_BY_KEY[viewer.key] = viewer end
local TAB_IDS = { 'general', 'essential', 'utility', 'buffs', 'buffBars', 'layouts', 'icons' }
local TAB_INDEX = {}
for index, id in ipairs(TAB_IDS) do TAB_INDEX[id] = index end
local ALL_LAYOUTS = '__all__'

local selected = 'general'
local snapshot
local exportChoice = ALL_LAYOUTS
local preview
local fonts
local railPage

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function DB()
	return BUI.GetDB()
end

local function CDM()
	return BUI.CDM
end

local function RefreshPreview()
	if preview then preview:Update() end
end

local function RebuildPane(page)
	BUILib.Defer(function() page:RebuildCurrent() end)
end

local function Media(kind, key, fallback)
	if key and key ~= '' and key ~= BUI.C.GLOBAL_OPTION then
		local path = LibStub('LibSharedMedia-3.0'):Fetch(kind, key, true)
		if path then return path end
	end
	return fallback
end

local function Option(db, label, key, extra)
	local option = { label = label, get = function() return db[key] end, set = function(value) db[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Toggle(db, label, key)
	return { label = label, get = function() return db[key] == true end, set = function(value) db[key] = value end }
end

local function OnUnlessOff(db, label, key)
	return { label = label, get = function() return db[key] ~= false end, set = function(value) db[key] = value end }
end

local function Color(db, label, key, after)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = true,
		get = function()
			local color = db[key]
			return color[1], color[2], color[3], color[4]
		end,
		set = function(red, green, blue, alpha)
			db[key] = { red, green, blue, alpha }
			if after then after(db[key]) end
		end,
	}
end

local function Menu(db, key, entries, width)
	return { entries = entries, width = width or MENU_WIDTH, get = function() return db[key] end, set = function(value) db[key] = value end }
end

local function Eye(tooltip, get, set)
	return { icon = 'eye', tooltip = tooltip, get = get, set = function(value)
		set(value)
		Repaint()
	end }
end

local function HookRefreshers()
	local module = CDM()
	if module._pageMockHooked then return end
	module._pageMockHooked = true
	local function Wrap(owner, name)
		local original = owner[name]
		if not original then return end
		owner[name] = function(...)
			local first, second, third = original(...)
			RefreshPreview()
			return first, second, third
		end
	end
	Wrap(module, 'RefreshSizeSettings')
	Wrap(module, 'RefreshSkinSettings')
	Wrap(module, 'RefreshLayoutOnly')
	Wrap(module, 'RefreshBuffBarSkin')
	Wrap(module, 'RefreshCooldownStyleFlags')
	Wrap(module, 'SyncSetting')
	Wrap(module, 'SyncSettingLayout')
	Wrap(module.Keybinds, 'StyleViewer')
	Wrap(module.Keybinds, 'RefreshViewer')
end

local function ViewerSpells(viewerKey)
	local module = CDM()
	local list, count = module.GetTrackedIcons(viewerKey)
	if list and count and count > 0 then
		local results = {}
		for index = 1, count do
			local icon = list[index]
			local key = module.GetSortKey(icon)
			local info = icon.cooldownInfo
			local spellID = info and BUI.Tools.SafeNum(info.overrideSpellID or info.spellID)
			if not spellID and type(key) == 'number' then spellID = key end
			local texture = icon.Icon and icon.Icon.GetTexture and icon.Icon:GetTexture()
			if texture and BUI.Tools.IsSecretValue(texture) then texture = nil end
			texture = texture or (spellID and C_Spell.GetSpellTexture(spellID))
			if texture then results[#results + 1] = { icon = texture, spellID = spellID, key = key } end
		end
		if #results > 0 then return results end
	end
	local categories = Enum.CooldownViewerCategory
	local category = ({ essential = categories.Essential, utility = categories.Utility, buffs = categories.TrackedBuff, buffBars = categories.TrackedBar })[viewerKey]
	local cooldownIDs = category and C_CooldownViewer.GetCooldownViewerCategorySet(category)
	if not cooldownIDs then return nil end
	local results = {}
	for _, cooldownID in ipairs(cooldownIDs) do
		local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
		local spellID = info and (info.overrideSpellID or info.spellID)
		local texture = spellID and C_Spell.GetSpellTexture(spellID)
		if texture then results[#results + 1] = { icon = texture, spellID = spellID } end
	end
	if #results == 0 then return nil end
	return results
end

local function LiveIcons(viewerKey, viewerSettings)
	local module = CDM()
	local icons = module.GetViewerIcons(viewerKey)
	if #icons == 0 then return nil end
	local hiddenSlots = viewerSettings.hiddenSlots
	local hiddenIcons = module.GetHiddenIcons(viewerSettings)
	local results = {}
	for index, icon in ipairs(icons) do
		local hidden = (hiddenSlots and hiddenSlots[index]) or module.IsIconHiddenByUser(viewerKey, hiddenIcons, icon)
		if not hidden then
			local info = icon.cooldownInfo
			local spellID = info and BUI.Tools.SafeNum(info.overrideSpellID or info.spellID)
			local frameData = module.FrameData[icon]
			results[#results + 1] = {
				tex = icon.Icon:GetTexture() or (spellID and C_Spell.GetSpellTexture(spellID)) or DEFAULT_ICON,
				key = module.GetSortKey(icon),
				spellID = spellID,
				itemID = frameData and frameData.itemID,
			}
		end
	end
	if #results == 0 then return nil end
	return results
end

local function HiddenKeyLabel(key)
	if type(key) == 'number' then return C_Spell.GetSpellName(key) or ('Spell ' .. key) end
	local text = tostring(key)
	local itemID = tonumber(text:match('^item:(%d+)$'))
	if itemID then return C_Item.GetItemNameByID(itemID) or ('Item ' .. itemID) end
	local customID = tonumber(text:match('^custom:(%d+)$'))
	if customID then
		if not C_SpellBook.IsSpellKnown(customID) and C_Item.GetItemInfoInstant(customID) then
			return C_Item.GetItemNameByID(customID) or ('Item ' .. customID)
		end
		return C_Spell.GetSpellName(customID) or ('Custom ' .. customID)
	end
	local trinketSlot = text:match('^trinket:(%d)$')
	if trinketSlot then return 'Trinket slot ' .. trinketSlot end
	if text:match('^racial:') then return 'Racial' end
	return text
end

local function CreateViewerMock(stage, withKeybinds)
	local holder = CreateFrame('Frame', nil, stage)
	holder:SetPoint('CENTER')
	local cells = {}
	local dragState, ghost

	local function CellName(cell)
		local entry = cell.entry
		if not entry then return '' end
		if entry.itemID then
			local itemName = C_Item.GetItemNameByID(entry.itemID)
			if itemName then return itemName end
		end
		if entry.spellID then
			local spellName = C_Spell.GetSpellName(entry.spellID)
			if spellName then return spellName end
		end
		if entry.key ~= nil then return HiddenKeyLabel(entry.key) end
		return ''
	end

	local function Relayout()
		CDM().RefreshLayoutOnly()
	end

	local function RestoreMenu(viewerSettings, hiddenList)
		local items = { { title = true, text = 'Restore' } }
		table.sort(hiddenList, function(left, right) return HiddenKeyLabel(left) < HiddenKeyLabel(right) end)
		for _, hiddenKey in ipairs(hiddenList) do
			items[#items + 1] = { text = HiddenKeyLabel(hiddenKey), callback = function()
				CDM().SetHiddenIcon(viewerSettings, hiddenKey, false)
				Relayout()
			end }
		end
		if #hiddenList > 1 then
			items[#items + 1] = { separator = true }
			items[#items + 1] = { text = 'Restore all', callback = function()
				for _, hiddenKey in ipairs(hiddenList) do CDM().SetHiddenIcon(viewerSettings, hiddenKey, false) end
				Relayout()
			end }
		end
		Controls.ContextMenu(items, { width = 230, window = Window() })
	end

	local function CellMenu(cell)
		local module = CDM()
		local entry = cell.entry
		if not (entry and entry.key and holder.viewerSettings) then return end
		local viewerSettings = holder.viewerSettings
		local name = CellName(cell)
		local items = { { title = true, text = name ~= '' and name or 'Icon' } }
		local spellID = entry.spellID or (type(entry.key) == 'number' and entry.key or nil)
		if spellID then
			local procConfig = module.GetProcConfig(spellID)
			items[#items + 1] = { text = procConfig and 'Alert settings, active' or 'Alert settings', callback = function() BUI.ShowCDMProcModal(module, spellID, Relayout, nil, viewerSettings) end }
			local overrides = module.GetIconOverrides(viewerSettings)
			items[#items + 1] = { text = overrides and overrides[spellID] and 'Change the icon, custom' or 'Change the icon', callback = function() BUI.ShowCDMIconOverrideModal(module, spellID, viewerSettings, Relayout) end }
		end
		local potionValue, potionItemID
		local list, count = module.GetTrackedIcons(holder.viewerKey)
		if list and count then
			for index = 1, count do
				local frameData = module.FrameData[list[index]]
				if frameData and frameData.customIcon and module.GetSortKey(list[index]) == entry.key then
					if frameData.iconType == 'consumable' and module.Custom.IsPotionItem(frameData.itemID or frameData.customSpellID) then
						potionValue = frameData.storedValue
						potionItemID = frameData.itemID or frameData.customSpellID
					end
					break
				end
			end
		end
		if potionValue then
			local label = 'Potion display'
			local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(potionItemID)
			if classID == Enum.ItemClass.Consumable and subclassID == Enum.ItemConsumableSubclass.Flask then label = 'Flask display' end
			if module.GetPotionPrioFor(potionValue) then label = label .. ', custom' end
			items[#items + 1] = { text = label, callback = function() BUI.ShowCDMPotionModal(module, potionItemID, potionValue, viewerSettings, holder.viewerKey, Relayout) end }
		end
		if holder.viewerKey ~= 'buffs' then
			items[#items + 1] = { text = 'Show only on cooldown', checked = module.IsShowOnlyOnCD(viewerSettings, entry.key) == true, callback = function()
				module.SetShowOnlyOnCD(viewerSettings, entry.key, not module.IsShowOnlyOnCD(viewerSettings, entry.key))
				module.UpdateShowOnlyOnCDWatcher()
				Relayout()
			end }
		end
		items[#items + 1] = { text = '|cffff6060Remove from the viewer|r', callback = function()
			module.SetHiddenIcon(viewerSettings, entry.key, true)
			Relayout()
			BUILib.Toast.Info('Icon removed', 'Click any icon and pick Restore icons to bring it back.')
		end }
		items[#items + 1] = { separator = true }
		local hiddenList = {}
		for hiddenKey, hidden in pairs(module.GetHiddenIcons(viewerSettings)) do
			if hidden == true then hiddenList[#hiddenList + 1] = hiddenKey end
		end
		if #hiddenList > 0 then
			items[#items + 1] = { text = ('Restore icons, %d'):format(#hiddenList), callback = function()
				RestoreMenu(viewerSettings, hiddenList)
				return true
			end }
		end
		items[#items + 1] = { text = 'Manage icons', callback = function() railPage:Select('icons') end }
		Controls.ContextMenu(items, { width = 230, window = Window() })
	end

	local function Ghost()
		if ghost then return ghost end
		ghost = CreateFrame('Frame', nil, UIParent)
		ghost:SetFrameStrata(BUILib.GetPopupStrata())
		ghost:SetFrameLevel(BUILib.GetPopupLevel() + 20)
		ghost.texture = ghost:CreateTexture(nil, 'OVERLAY')
		ghost.texture:SetAllPoints()
		ghost.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ghost:Hide()
		return ghost
	end

	local function SlotUnderCursor()
		local rects = holder.slotRects
		if not rects then return nil end
		local cursorX, cursorY = GetCursorPosition()
		local scale = holder:GetEffectiveScale()
		local localX = cursorX / scale - (holder:GetLeft() or 0)
		local localY = (holder:GetTop() or 0) - cursorY / scale
		for index, rect in ipairs(rects) do
			if localX >= rect.x and localX <= rect.x + rect.w and localY >= rect.y and localY <= rect.y + rect.h then return index end
		end
	end

	local function TargetSlot(index, source, hover)
		if index == source then return hover end
		if source < hover then
			if index > source and index <= hover then return index - 1 end
		elseif source > hover then
			if index >= hover and index < source then return index + 1 end
		end
		return index
	end

	local function BeginDrag(cell)
		local entry = cell.entry
		if not (entry and entry.key and holder.viewerSettings) or not IsControlKeyDown() then return end
		dragState = { source = cell.slot, cell = cell, hover = cell.slot }
		cell.frame:SetAlpha(0)
		local ghostFrame = Ghost()
		local scale = cell.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		ghostFrame:SetSize(cell.frame:GetWidth() * scale, cell.frame:GetHeight() * scale)
		ghostFrame.texture:SetTexture(entry.tex)
		ghostFrame:Show()
		ghostFrame:SetScript('OnUpdate', function(self, elapsed)
			local cursorX, cursorY = GetCursorPosition()
			local uiScale = UIParent:GetEffectiveScale()
			self:ClearAllPoints()
			self:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', cursorX / uiScale, cursorY / uiScale)
			local state = dragState
			local rects = holder.slotRects
			if not state or not rects then return end
			local hovered = SlotUnderCursor()
			if hovered then state.hover = hovered end
			local lerp = math.min(1, (elapsed or 0.016) * 14)
			for index = 1, #rects do
				local other = cells[index]
				if other and other.frame:IsShown() then
					local target = rects[TargetSlot(index, state.source, state.hover)]
					if target then
						other.x = other.x + (target.x - other.x) * lerp
						other.y = other.y + (target.y - other.y) * lerp
						other.frame:ClearAllPoints()
						other.frame:SetPoint('TOPLEFT', holder, 'TOPLEFT', other.x, -other.y)
					end
				end
			end
		end)
	end

	local function EndDrag(cell)
		if ghost then
			ghost:Hide()
			ghost:SetScript('OnUpdate', nil)
		end
		cell.frame:SetAlpha(1)
		local state = dragState
		dragState = nil
		if not state or state.cell ~= cell then return end
		local viewerSettings, entries = holder.viewerSettings, holder.entries
		if not (viewerSettings and entries) then return end
		local target = state.hover
		if not target or target == state.source or not entries[state.source] or not entries[target] then return holder:Render(holder.viewerKey) end
		local moved = table.remove(entries, state.source)
		table.insert(entries, target, moved)
		local order = {}
		for _, entry in ipairs(entries) do
			if entry.key then order[#order + 1] = entry.key end
		end
		if #order == 0 then return holder:Render(holder.viewerKey) end
		CDM().SetIconOrder(viewerSettings, order)
		Relayout()
	end

	local function Cell(index)
		if not cells[index] then
			local cell = {}
			local button = CreateFrame('Button', nil, holder)
			button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
			button:RegisterForDrag('LeftButton')
			cell.frame = button
			cell.border = button:CreateTexture(nil, 'BACKGROUND')
			cell.border:SetTexture(WHITE)
			cell.border:SetAllPoints(button)
			cell.icon = button:CreateTexture(nil, 'ARTWORK')
			cell.swipe = button:CreateTexture(nil, 'ARTWORK', nil, 1)
			cell.swipe:SetTexture(WHITE)
			cell.cooldown = button:CreateFontString(nil, 'OVERLAY')
			cell.stack = button:CreateFontString(nil, 'OVERLAY')
			cell.keybind = button:CreateFontString(nil, 'OVERLAY')
			button:SetScript('OnClick', function() CellMenu(cell) end)
			button:SetScript('OnDragStart', function() BeginDrag(cell) end)
			button:SetScript('OnDragStop', function() EndDrag(cell) end)
			button:SetScript('OnEnter', function(self)
				local entry = cell.entry
				if not (entry and entry.key) then return end
				local name = CellName(cell)
				BUILib.Widget.ShowTip(self, (name ~= '' and name or 'Icon') .. '|n|cff888888Ctrl drag to reorder, click for options|r')
			end)
			button:SetScript('OnLeave', function() BUILib.Widget.HideTip() end)
			cells[index] = cell
		end
		return cells[index]
	end

	function holder:Render(viewerKey)
		local module = CDM()
		local viewerSettings = DB().cdm[viewerKey]
		local iconWidth = viewerSettings.iconWidth or viewerSettings.iconSize or 38
		local iconHeight = viewerSettings.iconHeight or iconWidth
		local spacing = viewerSettings.spacing
		local borderSize = viewerSettings.borderSize
		local borderColor = viewerSettings.borderColor
		local swipeColor = viewerSettings.swipeColor
		local font = BUI.GetGlobalFont()

		local list = LiveIcons(viewerKey, viewerSettings)
		if not list then
			local spells = ViewerSpells(viewerKey)
			if spells then
				local hiddenIcons = module.GetHiddenIcons(viewerSettings)
				list = {}
				for _, spell in ipairs(spells) do
					local key = spell.key or spell.spellID
					local hidden = (key ~= nil and hiddenIcons[key]) or (spell.spellID and hiddenIcons[spell.spellID])
					if not hidden then list[#list + 1] = { tex = spell.icon, spellID = spell.spellID, key = key } end
				end
				local order = module.GetIconOrder(viewerSettings)
				if order and #order > 0 then
					local rank = {}
					for index, key in ipairs(order) do rank[key] = index end
					table.sort(list, function(left, right)
						local rankLeft, rankRight = rank[left.key], rank[right.key]
						if rankLeft and rankRight then return rankLeft < rankRight end
						if rankLeft or rankRight then return rankLeft ~= nil end
						return tostring(left.key) < tostring(right.key)
					end)
				end
				if #list == 0 then list = nil end
			end
		end
		if not list then return self:Hide() end
		local count = math.min(#list, MOCK_MAX_ICONS)
		self.entries, self.viewerKey, self.viewerSettings = list, viewerKey, viewerSettings
		local slotRects = {}
		self.slotRects = slotRects

		local perRow = viewerSettings.iconsPerRow > 0 and viewerSettings.iconsPerRow or count
		local numRows, maxCols
		if viewerKey == 'buffs' then
			numRows, maxCols = module.RowMetrics(count, perRow)
		else
			numRows, maxCols = module.RowMetrics(count, perRow, viewerSettings.row2Count, viewerSettings.row3Count)
		end
		if numRows < 1 or maxCols < 1 then return self:Hide() end

		local stepX, stepY = iconWidth + spacing, iconHeight + spacing
		local totalWidth, totalHeight
		if viewerSettings.vertical then
			totalWidth = numRows * iconWidth + (numRows - 1) * spacing
			totalHeight = maxCols * iconHeight + (maxCols - 1) * spacing
		else
			totalWidth = maxCols * iconWidth + (maxCols - 1) * spacing
			totalHeight = numRows * iconHeight + (numRows - 1) * spacing
		end
		self:SetSize(totalWidth, totalHeight)
		self:SetScale(math.min(1, MOCK_WIDTH / totalWidth, MOCK_HEIGHT / totalHeight))

		local growUp = viewerSettings.rowGrowth == 'Up'
		local iconIndex, remaining = 0, count
		for row = 1, numRows do
			local rowCount
			if viewerKey == 'buffs' then
				rowCount = module.NextRowSize(row, remaining, perRow)
			else
				rowCount = module.NextRowSize(row, remaining, perRow, viewerSettings.row2Count, viewerSettings.row3Count)
			end
			if rowCount <= 0 then break end
			remaining = remaining - rowCount
			local slot = growUp and (numRows - row) or (row - 1)
			for column = 0, rowCount - 1 do
				iconIndex = iconIndex + 1
				local cell = Cell(iconIndex)
				local x, y
				if viewerSettings.vertical then
					local columnHeight = rowCount * iconHeight + (rowCount - 1) * spacing
					local within = growUp and (rowCount - 1 - column) or column
					x = (row - 1) * stepX
					y = (totalHeight - columnHeight) / 2 + within * stepY
				else
					local rowWidth = rowCount * iconWidth + (rowCount - 1) * spacing
					local rowLeft = (totalWidth - rowWidth) / 2
					if row == numRows and numRows > 1 and viewerSettings.centerLastRow == false then rowLeft = 0 end
					x = rowLeft + column * stepX
					y = slot * stepY
				end
				local button = cell.frame
				cell.slot, cell.entry, cell.x, cell.y = iconIndex, list[iconIndex], x, y
				slotRects[iconIndex] = { x = x, y = y, w = iconWidth, h = iconHeight }
				button:ClearAllPoints()
				button:SetSize(iconWidth, iconHeight)
				button:SetPoint('TOPLEFT', self, 'TOPLEFT', x, -y)
				button:SetAlpha(1)
				button:Show()
				cell.border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderSize > 0 and borderColor[4] or 0)
				cell.icon:ClearAllPoints()
				cell.icon:SetPoint('TOPLEFT', button, 'TOPLEFT', borderSize, -borderSize)
				cell.icon:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -borderSize, borderSize)
				cell.icon:SetTexture(list[iconIndex].tex)
				cell.icon:SetTexCoord(module.GetAspectTexCoords(viewerSettings.zoom, iconWidth, iconHeight, viewerSettings.keepAspectRatio))
				cell.icon:Show()
				cell.border:Show()

				if iconIndex % 3 == 2 then
					cell.swipe:ClearAllPoints()
					cell.swipe:SetSize(math.max(1, iconWidth - borderSize * 2), math.max(1, (iconHeight - borderSize * 2) * 0.55))
					local edge = viewerSettings.reverseSwipe and 'TOP' or 'BOTTOM'
					cell.swipe:SetPoint(edge, cell.icon, edge, 0, 0)
					cell.swipe:SetVertexColor(swipeColor[1], swipeColor[2], swipeColor[3], swipeColor[4])
					cell.swipe:Show()
					local cooldownColor = viewerSettings.cooldownTextColor
					BUI.Pixel.ApplyFont(cell.cooldown, viewerSettings.cooldownTextSize, font, 'OUTLINE')
					cell.cooldown:SetText(tostring(2 + iconIndex))
					cell.cooldown:ClearAllPoints()
					local point = viewerSettings.cooldownTextPosition
					local offsetY = viewerSettings.cooldownTextOffsetY
					if point == 'CENTER' and viewerSettings.cooldownTextSize > 0 then offsetY = offsetY - module.CooldownTextCenterDrop(viewerSettings.cooldownTextSize) end
					cell.cooldown:SetPoint(point, cell.icon, point, viewerSettings.cooldownTextOffsetX, offsetY)
					cell.cooldown:SetTextColor(cooldownColor[1], cooldownColor[2], cooldownColor[3], cooldownColor[4])
					cell.cooldown:Show()
				else
					cell.swipe:Hide()
					cell.cooldown:Hide()
				end

				if iconIndex % 4 == 3 then
					local stackColor = viewerSettings.textColor
					BUI.Pixel.ApplyFont(cell.stack, viewerSettings.textSize, font, 'OUTLINE')
					cell.stack:SetText('2')
					cell.stack:ClearAllPoints()
					local point = viewerSettings.textPosition
					cell.stack:SetPoint(point, cell.icon, point, viewerSettings.textOffsetX, viewerSettings.textOffsetY)
					cell.stack:SetTextColor(stackColor[1], stackColor[2], stackColor[3], stackColor[4])
					cell.stack:Show()
				else
					cell.stack:Hide()
				end

				if withKeybinds and viewerSettings.showKeybinds then
					local keybindColor = viewerSettings.keybindColor
					BUI.Pixel.ApplyFont(cell.keybind, viewerSettings.keybindFontSize, Media('font', viewerSettings.keybindFont, font), 'OUTLINE')
					cell.keybind:SetText(MOCK_KEYS[(iconIndex - 1) % #MOCK_KEYS + 1])
					cell.keybind:ClearAllPoints()
					local point = viewerSettings.keybindAnchor
					cell.keybind:SetPoint(point, cell.icon, point, viewerSettings.keybindOffsetX, viewerSettings.keybindOffsetY)
					cell.keybind:SetTextColor(keybindColor[1], keybindColor[2], keybindColor[3], keybindColor[4])
					cell.keybind:Show()
				else
					cell.keybind:Hide()
				end
			end
		end
		for index = iconIndex + 1, #cells do
			cells[index].frame:Hide()
			cells[index].entry = nil
		end
		self:Show()
	end
	return holder
end

local function CreateBuffBarMock(stage)
	local holder = CreateFrame('Frame', nil, stage)
	holder:SetPoint('CENTER')
	local bars = {}

	local function Bar(index)
		if not bars[index] then
			local bar = {}
			bar.border = holder:CreateTexture(nil, 'BACKGROUND')
			bar.border:SetTexture(WHITE)
			bar.background = holder:CreateTexture(nil, 'BORDER')
			bar.background:SetTexture(WHITE)
			bar.fill = holder:CreateTexture(nil, 'ARTWORK')
			bar.iconBorder = holder:CreateTexture(nil, 'BACKGROUND')
			bar.iconBorder:SetTexture(WHITE)
			bar.icon = holder:CreateTexture(nil, 'ARTWORK')
			bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			bar.name = holder:CreateFontString(nil, 'OVERLAY')
			bar.duration = holder:CreateFontString(nil, 'OVERLAY')
			bar.stacks = holder:CreateFontString(nil, 'OVERLAY', nil, 1)
			bar.hit = CreateFrame('Button', nil, holder)
			bar.hit:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
			bar.hit:SetScript('OnClick', function(self)
				if not self.spellID then return end
				local procConfig = CDM().GetProcConfig(self.spellID)
				Controls.ContextMenu({
					{ title = true, text = self.name or 'Buff bar' },
					{ text = procConfig and 'Alert settings, active' or 'Alert settings', callback = function() BUI.ShowCDMProcModal(CDM(), self.spellID, function() holder:Render() end) end },
				}, { width = 230, window = Window() })
			end)
			bar.hit:SetScript('OnEnter', function(self)
				if not self.spellID then return end
				BUILib.Widget.ShowTip(self, (self.name or 'Buff bar') .. '|n|cff888888Click for options|r')
			end)
			bar.hit:SetScript('OnLeave', function() BUILib.Widget.HideTip() end)
			bars[index] = bar
		end
		return bars[index]
	end

	function holder:Render()
		local config = DB().cdm.buffBars
		local barWidth, barHeight, iconSize = config.barWidth, config.barHeight, config.iconSize
		local showIcon = config.showIcon ~= false
		local spacing, borderSize = config.spacing, config.borderSize
		local borderColor, backgroundColor = config.borderColor, config.bgColor
		local fillColor = config.barColor
		if config.useClassColor then
			local _, class = UnitClass('player')
			local classColor = class and RAID_CLASS_COLORS[class]
			if classColor then fillColor = { classColor.r, classColor.g, classColor.b, 1 } end
		end
		local barTexture = Media('statusbar', config.texture, BUI.GetGlobalTexture())
		local font = BUI.GetGlobalFont()
		local live = ViewerSpells('buffBars')
		if not live or #live == 0 then return self:Hide() end
		local rowHeight = math.max(barHeight, showIcon and iconSize or 0)
		local totalWidth = barWidth + (showIcon and (iconSize + 2) or 0)
		local barCount = math.min(#live, 3)
		local totalHeight = barCount * rowHeight + (barCount - 1) * spacing
		self:SetSize(totalWidth, totalHeight)
		self:SetScale(math.min(1, MOCK_WIDTH / totalWidth, MOCK_HEIGHT / totalHeight))
		for index = 1, barCount do
			local sample = MOCK_BARS[(index - 1) % #MOCK_BARS + 1]
			local entry = live[index]
			local name = C_Spell.GetSpellName(entry.spellID) or sample.name
			local bar = Bar(index)
			local slot = config.growDirection == 'UP' and (barCount - index + 1) or index
			local y = (slot - 1) * (rowHeight + spacing)
			local x = 0
			if showIcon then
				local iconY = y + (rowHeight - iconSize) / 2
				bar.iconBorder:ClearAllPoints()
				bar.iconBorder:SetSize(iconSize + borderSize * 2, iconSize + borderSize * 2)
				bar.iconBorder:SetPoint('TOPLEFT', self, 'TOPLEFT', -borderSize, -iconY + borderSize)
				bar.iconBorder:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderSize > 0 and borderColor[4] or 0)
				bar.icon:ClearAllPoints()
				bar.icon:SetSize(iconSize, iconSize)
				bar.icon:SetPoint('TOPLEFT', self, 'TOPLEFT', 0, -iconY)
				bar.icon:SetTexture(entry.icon)
				bar.icon:Show()
				bar.iconBorder:Show()
				x = iconSize + 2
			else
				bar.icon:Hide()
				bar.iconBorder:Hide()
			end
			local barY = y + (rowHeight - barHeight) / 2
			bar.border:ClearAllPoints()
			bar.border:SetSize(barWidth + borderSize * 2, barHeight + borderSize * 2)
			bar.border:SetPoint('TOPLEFT', self, 'TOPLEFT', x - borderSize, -barY + borderSize)
			bar.border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderSize > 0 and borderColor[4] or 0)
			bar.background:ClearAllPoints()
			bar.background:SetSize(barWidth, barHeight)
			bar.background:SetPoint('TOPLEFT', self, 'TOPLEFT', x, -barY)
			bar.background:SetVertexColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
			bar.fill:SetTexture(barTexture)
			bar.fill:ClearAllPoints()
			bar.fill:SetSize(math.max(1, barWidth * sample.fill), barHeight)
			bar.fill:SetPoint('TOPLEFT', self, 'TOPLEFT', x, -barY)
			bar.fill:SetVertexColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
			bar.background:Show()
			bar.fill:Show()
			bar.border:Show()
			if config.showName ~= false then
				BUI.Pixel.ApplyFont(bar.name, config.nameSize, font)
				bar.name:SetText(name)
				bar.name:ClearAllPoints()
				bar.name:SetPoint('LEFT', bar.background, 'LEFT', 4, 0)
				bar.name:SetTextColor(1, 1, 1, 1)
				bar.name:Show()
			else
				bar.name:Hide()
			end
			if config.showDuration ~= false then
				BUI.Pixel.ApplyFont(bar.duration, config.durationSize, font)
				bar.duration:SetText(sample.duration)
				bar.duration:ClearAllPoints()
				bar.duration:SetPoint(config.durationPoint, bar.background, config.durationPoint, config.durationOffsetX, config.durationOffsetY)
				bar.duration:SetTextColor(1, 1, 1, 1)
				bar.duration:Show()
			else
				bar.duration:Hide()
			end
			if config.showStacks ~= false and sample.stacks then
				local point = config.stackPoint
				BUI.Pixel.ApplyFont(bar.stacks, config.stackSize, font, 'OUTLINE')
				bar.stacks:SetText(sample.stacks)
				bar.stacks:ClearAllPoints()
				bar.stacks:SetPoint(point, (showIcon and config.stackAttach == 'ICON') and bar.icon or bar.background, point, config.stackOffsetX, config.stackOffsetY)
				local stackColor = config.stackColor
				bar.stacks:SetTextColor(stackColor[1], stackColor[2], stackColor[3], stackColor[4])
				bar.stacks:Show()
			else
				bar.stacks:Hide()
			end
			bar.hit.spellID, bar.hit.name = entry.spellID, name
			bar.hit:ClearAllPoints()
			bar.hit:SetPoint('TOPLEFT', self, 'TOPLEFT', -borderSize, -y)
			bar.hit:SetSize(totalWidth + borderSize * 2, rowHeight)
			bar.hit:Show()
		end
		for index = barCount + 1, #bars do
			local bar = bars[index]
			for _, region in ipairs({ bar.border, bar.background, bar.fill, bar.iconBorder, bar.icon, bar.name, bar.duration, bar.stacks, bar.hit }) do region:Hide() end
		end
		self:Show()
	end
	return holder
end

local function BuildPreview(band, kit)
	local stage = CreateFrame('Frame', nil, band)
	stage:SetAllPoints()
	stage:SetClipsChildren(true)
	local mocks = {}
	for _, viewer in ipairs(VIEWERS) do mocks[viewer.key] = CreateViewerMock(stage, viewer.keybinds) end
	mocks.buffBars = CreateBuffBarMock(stage)
	local note = kit.Text(band, '', 12, 'muted')
	note:SetPoint('CENTER')
	function band:Update()
		for _, mock in pairs(mocks) do mock:Hide() end
		local mock = mocks[selected]
		if not mock then
			note:SetText('Pick a viewer from the rail to see it here')
			note:Show()
			return
		end
		if selected == 'buffBars' then mock:Render() else mock:Render(selected) end
		note:SetText('Nothing tracked in this viewer yet')
		note:SetShown(not mock:IsShown())
	end
	band:HookScript('OnShow', function(self) self:Update() end)
	return band
end

local function GeneralBoards(ui, parent, width, page)
	local db = DB()
	local module = CDM()
	local cdm = db.cdm
	local setup = ui.Board(parent, width, {
		stacked = true,
		title = 'Cooldown Manager',
		description = 'Skin, arrange and extend the Blizzard Cooldown Manager.',
	})
	setup:AddTools('Shortcuts', 'Blizzard Edit Mode and the full Cooldown Viewer settings panel', {
		{ text = 'Advanced CDM', onClick = function()
			if CooldownViewerSettings then CooldownViewerSettings:SetShown(not CooldownViewerSettings:IsShown()) end
		end },
		{ text = 'Edit Mode', onClick = BUI.ToggleEditMode },
	})
	local EditModeLock = module.EditModeLock
	local systems = Enum.EditModeCooldownViewerSystemIndices
	local settingsEnum = Enum.EditModeCooldownViewerSetting
	local viewerNames = { [systems.Essential] = 'Essential', [systems.Utility] = 'Utility', [systems.BuffIcon] = 'Buff icons' }
	if systems.BuffBar then viewerNames[systems.BuffBar] = 'Buff bars' end
	local settingNames = { [settingsEnum.VisibleSetting] = 'Always visible', [settingsEnum.ShowTimer] = 'Show timer', [settingsEnum.HideWhenInactive] = 'Hide when inactive' }
	local function EditModeStatus()
		local compliance = EditModeLock.GetCompliance()
		if not compliance.isReady then return 'Edit Mode is not loaded, reload the interface' end
		if compliance.isPreset then return 'This is a Blizzard preset layout, make a custom one first' end
		if compliance.isCompliant then return 'The viewers are configured' end
		local byViewer = {}
		for _, mismatch in ipairs(compliance.mismatches) do
			byViewer[mismatch.systemIndex] = byViewer[mismatch.systemIndex] or {}
			table.insert(byViewer[mismatch.systemIndex], settingNames[mismatch.setting])
		end
		local parts = {}
		for _, systemIndex in ipairs({ systems.Essential, systems.Utility, systems.BuffIcon, systems.BuffBar }) do
			if systemIndex and byViewer[systemIndex] then parts[#parts + 1] = viewerNames[systemIndex] .. ': ' .. table.concat(byViewer[systemIndex], ', ') end
		end
		return 'Needs fixing. ' .. table.concat(parts, '. ')
	end
	setup:AddTools('Edit Mode setup', EditModeStatus(), {
		{ text = 'Apply fix', onClick = function()
			local result = EditModeLock.ApplyRecommendedSettings()
			local messages = {
				applied = 'Viewers configured, reload to apply.',
				noop = 'Nothing to change.',
				preset = 'This is a Blizzard preset layout, make a custom one first.',
				in_combat = 'Cannot edit in combat.',
				not_ready = 'Edit Mode is not loaded, reload the interface.',
			}
			BUI.Print(messages[result] or 'Could not apply the settings.')
			module._emStatusRefresh()
		end },
	})
	module._emStatusRefresh = function()
		if selected == 'general' then RebuildPane(page) end
	end

	local behavior = ui.Board(parent, width, {
		stacked = true,
		title = 'Behavior',
		description = 'How the viewers act and what they show.',
	})
	behavior:AddSwitch('Sync settings', function() return cdm.syncViewers == true end, function(value) cdm.syncViewers = value end, 'Essential, Utility and Buff icons share one set of appearance settings')
	behavior:AddSwitch('Blizzard panel overlay', function() return cdm.showBlizzardOverlay == true end, function(value) cdm.showBlizzardOverlay = value end, 'The BluUI overlay on the Blizzard Cooldown Viewer settings panel')
	behavior:AddSwitch('Tooltips', function() return cdm.showTooltips ~= false end, function(value) cdm.showTooltips = value end, 'Spell tooltips when hovering tracked icons')
	behavior:AddSwitch('Buff duration', function() return cdm.showBuffDuration ~= false end, function(value)
		cdm.showBuffDuration = value
		module.RefreshBuffOverrideCache()
		for cooldown in pairs(module.CDMCooldowns) do
			module.ForceSpellCooldownIfBuffHidden(cooldown)
			local icon = cooldown:GetParent()
			if icon and icon.Icon then
				if value then icon.Icon:SetDesaturation(0) else module.RefreshIconDesaturation(icon.Icon) end
			end
		end
	end, 'Remaining time on tracked buff icons')
	local function SetAllViewers(key, value)
		cdm.essential[key], cdm.utility[key], cdm.buffs[key] = value, value, value
		module.RefreshCooldownStyleFlags()
	end
	behavior:AddSwitch('Cooldown flash', function() return cdm.essential.showFlash == true end, function(value) SetAllViewers('showFlash', value) end, 'Flash when a cooldown completes')
	behavior:AddSwitch('Cooldown edge', function() return cdm.essential.showEdge == true end, function(value) SetAllViewers('showEdge', value) end, 'Bright leading edge on the cooldown sweep')
	behavior:AddTools('Move icons individually', 'Drag any icon out of its grid to place it freely', {
		{ tooltip = 'Resizing and snapping', title = 'Detached icons', options = {
			Toggle(cdm, 'Resize detached icons', 'allowIndividualResize'),
			Toggle(cdm, 'Disable snapping', 'disableSnapping'),
		} },
		{ icon = 'reset', tooltip = 'Reset every icon position', onClick = function()
			module.Detached.ClearAll('essential')
			module.Detached.ClearAll('utility')
			module.RefreshAll()
		end },
		{ get = function() return cdm.allowIndividualMove == true end, set = function(value)
			cdm.allowIndividualMove = value
			module.Detached.UpdateModifierWatcher()
			module.RefreshAll()
		end },
	})
	behavior:AddTools('Font', 'Timer and stack text across the Cooldown Manager', {
		{ entries = fonts, width = MENU_WIDTH, get = function() return db.general.cdmFont or BUI.C.GLOBAL_OPTION end, set = function(value) db.general.cdmFont = value ~= BUI.C.GLOBAL_OPTION and value or nil end },
	}, module.RefreshSkinSettings)

	local effects = ui.Board(parent, width, {
		stacked = true,
		title = 'Glow and highlights',
		description = 'Procs, the assisted rotation marker and key presses.',
	})
	local glow = cdm.glow
	local glowTypes = {}
	for _, glowType in ipairs(module.GLOW_TYPES) do glowTypes[#glowTypes + 1] = { value = glowType.id, text = glowType.name } end
	effects:AddTools('Custom glows', 'A BluUI styled glow for procs and alerts, replacing the Blizzard highlight', {
		Color(glow, 'Glow color', 'color', module.RefreshGlowPreview),
		Menu(glow, 'type', glowTypes),
		{ tooltip = 'Speed, lines and thickness', title = 'Glow shape', options = {
			Option(glow, 'Speed %', 'speed', { min = 25, max = 400, step = 25 }),
			Option(glow, 'Lines, pixel style', 'lines', { min = 4, max = 16, step = 1 }),
			Option(glow, 'Thickness, pixel style', 'thickness', { min = 1, max = 5, step = 1 }),
		} },
		Eye('Preview the glow', function() return module.glowPreview ~= nil and module.glowPreview:IsShown() end, function(value)
			if value then module.ShowGlowPreview() else module.HideGlowPreview() end
		end),
		{ get = function() return glow.enabled == true end, set = function(value)
			glow.enabled = value
			module.RefreshSkinSettings()
		end },
	}, module.RefreshActiveGlows)
	effects:AddTools('Assisted highlight', 'Color for the Blizzard assisted combat highlight', {
		Color(cdm.assist, 'Highlight color', 'color'),
	}, module.RefreshAssistHighlight)
	local press = cdm.pressHighlight
	effects:AddTools('Keypress highlight', 'Flash the icon when its key is pressed', {
		Color(press, 'Tint color', 'tintColor'),
		Color(press, 'Border color', 'borderColor'),
		Menu(press, 'overlayStyle', module.PressHighlight.OVERLAY_STYLES),
		{ tooltip = 'Border', title = 'Keypress highlight', options = { Toggle(press, 'Show the border', 'showBorder') } },
		Toggle(press, nil, 'enabled'),
	}, module.PressHighlight.Refresh)
	return { setup, behavior, effects }
end

local function ViewerBoards(ui, parent, width, viewer)
	local db = DB()
	local module = CDM()
	local viewerKey = viewer.key
	local viewerSettings = db.cdm[viewerKey]
	local canSync = viewerKey ~= 'buffs'
	local function Sync(key)
		return function(value)
			if canSync and module.SyncSetting(key, value) then return end
			if module.SIZE_SETTINGS[key] then module.RefreshSizeSettings() else module.RefreshSkinSettings() end
		end
	end
	local function SyncLayout(key)
		return function(value)
			if canSync and module.SyncSettingLayout(key, value) then return end
			module.RefreshLayoutOnly()
		end
	end
	local function Synced(label, key, extra, layout)
		local option = Option(viewerSettings, label, key, extra)
		local after = layout and SyncLayout(key) or Sync(key)
		option.set = function(value)
			viewerSettings[key] = value
			after(value)
		end
		return option
	end
	local function SyncedToggle(label, key, layout)
		local after = layout and SyncLayout(key) or Sync(key)
		return { label = label, get = function() return viewerSettings[key] == true end, set = function(value)
			viewerSettings[key] = value
			after(value)
		end }
	end
	local function SyncedColor(label, key)
		return Color(viewerSettings, label, key, Sync(key))
	end

	local board = ui.Board(parent, width, {
		stacked = true,
		title = viewer.title,
		description = viewer.description .. ' Turning the skin on or off needs a reload.',
	})
	local frames = {}
	for _, entry in ipairs(BUI.C.ANCHOR_FRAMES) do
		if entry.tag ~= viewer.frame then frames[#frames + 1] = entry end
	end
	local position = setmetatable({}, {
		__index = function(_, key) return viewerSettings[key] end,
		__newindex = function(_, key, value)
			if key == 'centerHorizontally' then
				Sync('centerHorizontally')(value)
				module.OnCenterHorizontallyChanged(viewerKey, value)
			else
				viewerSettings[key] = value
			end
		end,
	})
	local tools = { BUI.PositionTool(position, { fields = { posX = 'positionX', posY = 'positionY' }, frames = frames }) }
	if viewerKey == 'buffs' then
		tools[#tools + 1] = Eye('Show a movable preview of the buff icons', function() return module.state.buffsPreview ~= nil and module.state.buffsPreview:IsShown() end, function(value)
			if value then module.ShowBuffsPreview(viewerSettings) else module.HideBuffsPreview() end
		end)
	end
	tools[#tools + 1] = { get = function() return viewerSettings.enabled == true end, set = function(value)
		Modals.Confirm({
			parent = Window().frame,
			title = viewer.title .. (value and ' skin on' or ' skin off'),
			message = 'This needs a reload of the interface to take effect.',
			confirmText = 'Reload now', laterText = 'Later', cancelText = 'Cancel',
			onConfirm = function()
				viewerSettings.enabled = value
				ReloadUI()
			end,
			onLater = function() viewerSettings.enabled = value end,
			onCancel = Repaint,
		})
	end }
	board:AddTools('Viewer', 'Position, preview and the skin on or off', tools, function()
		module.ApplyPosition(viewerKey)
		module.RefreshLayoutOnly()
	end)
	local rows = {
		Synced('Row growth', 'rowGrowth', { entries = BUI.C.ROW_GROWTH_OPTIONS }, true),
		Synced('Row 1 count', 'iconsPerRow', { min = 0, max = 20, step = 1 }, true),
		Synced('Row 2 count', 'row2Count', { min = 0, max = 20, step = 1 }, true),
	}
	if canSync then rows[#rows + 1] = Synced('Row 3 count', 'row3Count', { min = 0, max = 20, step = 1 }, true) end
	rows[#rows + 1] = SyncedToggle('Hide icons past the last row', 'capRows', true)
	if canSync then
		rows[#rows + 1] = { label = 'Center the last row', get = function() return viewerSettings.centerLastRow == true end, set = function(value)
			viewerSettings.centerLastRow = value
			module.RefreshLayoutOnly()
		end }
	end
	rows[#rows + 1] = SyncedToggle('Vertical', 'vertical', true)
	board:AddTools('Rows', 'Growth, counts and direction', {
		{ tooltip = 'Growth and row counts', title = 'Icon rows', options = rows },
	})
	board:AddTools('Icons', 'Size, spacing and zoom', {
		{ icon = 'resize', tooltip = 'Size, spacing and zoom', title = 'Icons', options = {
			{ label = 'Width', min = 20, max = 100, step = 1, get = function() return viewerSettings.iconWidth or viewerSettings.iconSize or 38 end, set = function(value)
				viewerSettings.iconWidth = value
				Sync('iconWidth')(value)
			end },
			{ label = 'Height', min = 10, max = 100, step = 1, get = function() return viewerSettings.iconHeight or (viewerSettings.iconWidth or viewerSettings.iconSize or 38) * viewerSettings.aspectRatio end, set = function(value)
				viewerSettings.iconHeight = value
				Sync('iconHeight')(value)
			end },
			Synced('Spacing', 'spacing', { min = -20, max = 20, step = 1 }, true),
			{ label = 'Zoom %', min = 0, max = 20, step = 1, get = function() return viewerSettings.zoom * 100 end, set = function(value)
				viewerSettings.zoom = value / 100
				Sync('zoom')(viewerSettings.zoom)
			end },
			{ label = 'Keep the aspect ratio', get = function() return viewerSettings.keepAspectRatio == true end, set = function(value)
				viewerSettings.keepAspectRatio = value or nil
				Sync('keepAspectRatio')(viewerSettings.keepAspectRatio)
			end },
		} },
	})
	board:AddTools('Border', 'Outline around each icon', {
		SyncedColor('Border color', 'borderColor'),
		{ tooltip = 'Thickness', title = 'Border', options = { Synced('Thickness', 'borderSize', { min = 0, max = 5, step = 1 }) } },
	})
	board:AddTools('Swipe', 'The cooldown sweep, reversed fills up instead of emptying', {
		SyncedColor('Swipe color', 'swipeColor'),
		SyncedToggle(nil, 'reverseSwipe'),
	})

	local text = ui.Board(parent, width, {
		stacked = true,
		title = 'Text',
		description = 'Countdown, stacks and keybinds on each icon.',
	})
	text:AddTools('Cooldown text', 'Remaining time on each icon', {
		SyncedColor('Text color', 'cooldownTextColor'),
		{ icon = 'text', tooltip = 'Position, size, decimals and the warning color', title = 'Cooldown text', options = {
			Synced('Position', 'cooldownTextPosition', { entries = POINTS }),
			Synced('Size', 'cooldownTextSize', { min = 0, max = 30, step = 1 }),
			Synced('Horizontal', 'cooldownTextOffsetX', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
			Synced('Vertical', 'cooldownTextOffsetY', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
			SyncedToggle('Decimals', 'showCooldownDecimals'),
			Synced('Decimals under seconds', 'cooldownDecimalThreshold', { min = 1, max = 30, step = 1 }),
			{ label = 'Warning under seconds', min = 0, max = 10, step = 1, get = function() return viewerSettings.cooldownWarnSeconds or 0 end, set = function(value)
				viewerSettings.cooldownWarnSeconds = value
				Sync('cooldownWarnSeconds')(value)
			end },
			{ kind = 'swatch', label = 'Warning color', tooltip = 'Countdown color inside the warning window', opacity = true,
				get = function()
					local color = viewerSettings.cooldownWarnColor
					return color[1], color[2], color[3], color[4]
				end,
				set = function(red, green, blue, alpha)
					viewerSettings.cooldownWarnColor = { red, green, blue, alpha }
					Sync('cooldownWarnColor')(viewerSettings.cooldownWarnColor)
				end },
		} },
	})
	text:AddTools('Stack text', 'Charge and stack counts on each icon', {
		SyncedColor('Text color', 'textColor'),
		{ icon = 'text', tooltip = 'Position and size', title = 'Stack text', options = {
			Synced('Position', 'textPosition', { entries = POINTS }),
			Synced('Size', 'textSize', { min = 0, max = 30, step = 1 }),
			Synced('Horizontal', 'textOffsetX', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
			Synced('Vertical', 'textOffsetY', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
		} },
	})
	if viewer.keybinds then
		local function Style() module.Keybinds.StyleViewer(viewerKey) end
		text:AddTools('Keybind text', 'Key labels on each icon, read from your action bars', {
			Color(viewerSettings, 'Text color', 'keybindColor'),
			{ entries = fonts, width = MENU_WIDTH, get = function() return viewerSettings.keybindFont end, set = function(value) viewerSettings.keybindFont = value end },
			{ icon = 'text', tooltip = 'Anchor, size and offset', title = 'Keybind text', options = {
				Option(viewerSettings, 'Anchor', 'keybindAnchor', { entries = POINTS }),
				Option(viewerSettings, 'Size', 'keybindFontSize', { min = 8, max = 24, step = 1 }),
				Option(viewerSettings, 'Horizontal', 'keybindOffsetX', { min = -KEYBIND_RANGE, max = KEYBIND_RANGE, step = 1 }),
				Option(viewerSettings, 'Vertical', 'keybindOffsetY', { min = -KEYBIND_RANGE, max = KEYBIND_RANGE, step = 1 }),
			} },
			{ get = function() return viewerSettings.showKeybinds == true end, set = function(value)
				viewerSettings.showKeybinds = value
				module.Keybinds.RefreshViewer(viewerKey)
			end },
		}, Style)
	end
	return { board, text }
end

local function BuffBarBoards(ui, parent, width)
	local module = CDM()
	local config = DB().cdm.buffBars
	local Refresh = module.RefreshBuffBarSkin
	local function Reposition()
		module.RepositionBuffBarRack()
		Refresh()
	end
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Buff bars',
		description = 'The Blizzard buff bar viewer, reskinned as compact bars.',
	})
	board:AddTools('Bars', 'Position, growth, preview and the skin on or off', {
		BUI.PositionTool(config, { fields = { posX = 'positionX', posY = 'positionY' }, matchWidth = true }),
		Menu(config, 'growDirection', GROWTHS),
		Eye('Show a preview of the buff bars', module.IsBuffBarPreviewShown, function(value)
			if value then module.ShowBuffBarPreview() else module.HideBuffBarPreview() end
		end),
		Toggle(config, nil, 'skinEnabled'),
	}, Reposition)
	board:AddTools('Size', 'Width, height and spacing', {
		{ icon = 'resize', tooltip = 'Width, height and spacing', title = 'Bars', options = {
			Option(config, 'Width', 'barWidth', { min = 80, max = 400, step = 1 }),
			Option(config, 'Height', 'barHeight', { min = 10, max = 50, step = 1 }),
			Option(config, 'Spacing', 'spacing', { min = 0, max = 30, step = 1 }),
		} },
	}, Refresh)
	board:AddTools('Icon', 'Buff icon beside each bar', {
		{ icon = 'resize', tooltip = 'Size', title = 'Icon', options = { Option(config, 'Icon size', 'iconSize', { min = 12, max = 64, step = 1 }) } },
		OnUnlessOff(config, nil, 'showIcon'),
	}, Reposition)
	board:AddTools('Colors', 'Bar, background and border', {
		Color(config, 'Bar color', 'barColor'),
		Color(config, 'Background', 'bgColor'),
		Color(config, 'Border', 'borderColor'),
		{ tooltip = 'Border size', title = 'Colors', options = { Option(config, 'Border size', 'borderSize', { min = 0, max = 5, step = 1 }) } },
	}, Refresh)
	board:AddSwitch('Class color bar', function() return config.useClassColor == true end, function(value)
		config.useClassColor = value
		Refresh()
	end, 'Fill the bars with your class color')

	local text = ui.Board(parent, width, {
		stacked = true,
		title = 'Text',
		description = 'Name, duration and stacks on each bar.',
	})
	text:AddTools('Name', 'Buff name on each bar', {
		{ icon = 'text', tooltip = 'Size', title = 'Name', options = { { label = 'Size', min = 6, max = 24, step = 1, get = function() return config.nameSize or 11 end, set = function(value) config.nameSize = value end } } },
		OnUnlessOff(config, nil, 'showName'),
	}, Refresh)
	text:AddTools('Duration', 'Remaining time on each bar', {
		{ icon = 'text', tooltip = 'Placement and size', title = 'Duration', options = {
			Option(config, 'Position', 'durationPoint', { entries = POINTS }),
			Option(config, 'Size', 'durationSize', { min = 6, max = 24, step = 1 }),
			Option(config, 'Horizontal', 'durationOffsetX', { min = -OFFSET_RANGE, max = OFFSET_RANGE, step = 1 }),
			Option(config, 'Vertical', 'durationOffsetY', { min = -OFFSET_RANGE, max = OFFSET_RANGE, step = 1 }),
		} },
		OnUnlessOff(config, nil, 'showDuration'),
	}, Refresh)
	text:AddTools('Stacks', 'Stack count on each bar', {
		Color(config, 'Stack color', 'stackColor'),
		{ icon = 'text', tooltip = 'Placement and size', title = 'Stacks', options = {
			Option(config, 'Attach to', 'stackAttach', { entries = STACK_ATTACH }),
			Option(config, 'Position', 'stackPoint', { entries = POINTS }),
			Option(config, 'Size', 'stackSize', { min = 6, max = 24, step = 1 }),
			Option(config, 'Horizontal', 'stackOffsetX', { min = -OFFSET_RANGE, max = OFFSET_RANGE, step = 1 }),
			Option(config, 'Vertical', 'stackOffsetY', { min = -OFFSET_RANGE, max = OFFSET_RANGE, step = 1 }),
		} },
		OnUnlessOff(config, nil, 'showStacks'),
	}, Refresh)
	return { board, text }
end

local function LayoutBoards(ui, parent, width, page)
	local Profiles = CDM().Profiles
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Layouts',
		description = 'Save, restore and share your Cooldown Manager setup.',
	})
	if not Profiles.IsAvailable() then
		board:AddRow('Not available', 'The Blizzard Cooldown Manager layout API is missing on this game version')
		return { board }
	end
	local snapshots = {}
	for _, saved in ipairs(Profiles.GetSnapshots()) do
		snapshots[#snapshots + 1] = { value = saved.name, text = saved.class and (saved.name .. ', ' .. saved.class) or saved.name }
	end
	table.sort(snapshots, function(left, right) return left.value < right.value end)
	if not snapshot or not Profiles.FindSnapshot(snapshot) then snapshot = snapshots[1] and snapshots[1].value end
	local function Save(name)
		name = name:gsub('^%s+', ''):gsub('%s+$', '')
		if name == '' then return end
		local function Commit()
			local ok, result = Profiles.SaveSnapshot(name)
			if not ok then return BUI.Print(result or 'Could not save the snapshot.') end
			snapshot = result
			RebuildPane(page)
		end
		if Profiles.FindSnapshot(name) then
			Modals.Confirm({ parent = Window().frame, title = 'Overwrite the snapshot', message = name .. ' already exists. Overwrite it with your current setup?', confirmText = 'Overwrite', cancelText = 'Cancel', onConfirm = Commit })
		else
			Commit()
		end
	end
	board:AddTools('New snapshot', 'Save your current layouts under a name, then press Enter', {
		{ kind = 'input', width = SNAPSHOT_WIDTH, placeholder = 'Snapshot name', get = function() return '' end, set = Save },
	})
	if snapshot then
		board:AddTools('Saved snapshots', 'Apply a saved snapshot, or delete it', {
			{ entries = snapshots, width = SNAPSHOT_WIDTH, get = function() return snapshot end, set = function(value) snapshot = value end },
			{ text = 'Apply', onClick = function()
				local name = snapshot
				Modals.Confirm({
					parent = Window().frame,
					title = 'Apply the snapshot',
					message = 'Replace your current Cooldown Manager layouts with ' .. name .. '? A backup snapshot of the current layouts is saved first, and a reload is needed afterwards.',
					confirmText = 'Apply', cancelText = 'Cancel',
					onConfirm = function()
						local backed, backupName = Profiles.AutoBackupSnapshot()
						local ok, err = Profiles.ApplySnapshot(name)
						if not ok then return BUI.Print(err or 'Could not apply the snapshot.') end
						RebuildPane(page)
						Modals.Confirm({
							parent = Window().frame,
							title = 'Snapshot applied',
							message = backed and (name .. ' is applied and the previous layouts were saved as ' .. backupName .. '. Reload now to finish?') or (name .. ' is applied. Reload now to finish?'),
							confirmText = 'Reload', cancelText = 'Later',
							onConfirm = ReloadUI,
						})
					end,
				})
			end },
			{ slot = 'erase', icon = 'erase', size = BUILib.Layout.ERASE_SIZE, hover = 'danger', tooltip = 'Delete this snapshot', onClick = function()
				local name = snapshot
				Modals.Confirm({
					parent = Window().frame,
					title = 'Delete the snapshot',
					message = 'Delete ' .. name .. '?',
					confirmText = 'Delete', cancelText = 'Cancel',
					onConfirm = function()
						local ok, err = Profiles.DeleteSnapshot(name)
						if not ok then return BUI.Print(err or 'Could not delete the snapshot.') end
						snapshot = nil
						RebuildPane(page)
					end,
				})
			end },
		})
	else
		board:AddRow('Saved snapshots', 'Nothing saved yet')
	end

	local share = ui.Board(parent, width, {
		stacked = true,
		title = 'Share',
		description = 'Copy your setup as a string, or import one someone sent you.',
	})
	local exports = { { value = ALL_LAYOUTS, text = 'Everything' } }
	for _, layout in ipairs(Profiles.GetBlizzardLayouts()) do
		if not layout.isDefault then exports[#exports + 1] = { value = layout.id, text = 'Only ' .. layout.name } end
	end
	local known = false
	for _, entry in ipairs(exports) do
		if entry.value == exportChoice then known = true end
	end
	if not known then exportChoice = ALL_LAYOUTS end
	share:AddTools('Export', 'Which layouts go into the string', {
		{ entries = exports, width = SNAPSHOT_WIDTH, get = function() return exportChoice end, set = function(value) exportChoice = value end },
		{ text = 'Export', onClick = function()
			local exportString, err
			if exportChoice == ALL_LAYOUTS then exportString, err = Profiles.ExportCurrent() else exportString, err = Profiles.ExportLayout(exportChoice) end
			if not exportString then return BUI.Print(err or 'Could not export.') end
			Modals.Copy({ parent = Window().frame, title = 'Layout string', text = exportString })
		end },
	})
	share:AddTools('Import', 'Paste a layout string to add its layouts, or replace your whole setup with them', {
		{ text = 'Import', onClick = function()
			Modals.Input({
				parent = Window().frame,
				title = 'Import layouts',
				message = 'Paste the layout string.',
				confirmText = 'Next',
				onConfirm = function(text)
					local valid, layoutString = Profiles.IsLayoutString(text)
					if not valid then return BUI.Print('That is not a Cooldown Manager layout string.') end
					Modals.Confirm({
						parent = Window().frame,
						title = 'Import layouts',
						message = 'Add the pasted layouts next to your current ones, or replace your whole setup with them? Replacing saves a backup snapshot first.',
						confirmText = 'Add to mine', laterText = 'Replace everything', cancelText = 'Cancel',
						onConfirm = function()
							local ok, result = Profiles.ImportLayoutString(layoutString)
							if not ok then return BUI.Print(result or 'The import failed.') end
							RebuildPane(page)
							Modals.Confirm({ parent = Window().frame, title = 'Layouts added', message = 'Added ' .. result .. ' layouts. Reload so everything picks them up?', confirmText = 'Reload', cancelText = 'Later', onConfirm = ReloadUI })
						end,
						onLater = function()
							local backed, backupName = Profiles.AutoBackupSnapshot()
							local ok, err = Profiles.ApplyLayoutData(layoutString)
							if not ok then return BUI.Print(err or 'Could not apply that string.') end
							RebuildPane(page)
							Modals.Confirm({ parent = Window().frame, title = 'Setup replaced', message = backed and ('Done, the previous layouts were saved as ' .. backupName .. '. Reload now to finish?') or 'Done. Reload now to finish?', confirmText = 'Reload', cancelText = 'Later', onConfirm = ReloadUI })
						end,
					})
				end,
			})
		end },
	})
	return { board, share }
end

local function IconManagementHost(parent, width)
	local wrapper = CreateFrame('Frame', nil, parent)
	wrapper:SetSize(width, HOST_HEIGHT)
	local host = Layout.ApplyContentMixin({ frame = wrapper, child = wrapper, width = width - Layout.DEFAULT_PADDING * 2, y = 0, topPadding = 0 })
	BUI.BuildCDMIconManagementTab(host, DB())
	wrapper:SetScript('OnSizeChanged', nil)
	wrapper:SetHeight(math.abs(host.y) + HOST_PAD)
	return wrapper
end

local function Panes(ui, _, parent, width, item, page)
	if item.id == 'general' then return GeneralBoards(ui, parent, width, page) end
	if item.id == 'buffBars' then return BuffBarBoards(ui, parent, width) end
	if item.id == 'layouts' then return LayoutBoards(ui, parent, width, page) end
	if item.id == 'icons' then return { IconManagementHost(parent, width) } end
	return ViewerBoards(ui, parent, width, VIEWER_BY_KEY[item.id])
end

local RAIL_GROUPS = {
	{ title = 'Settings', items = {
		{ id = 'general', label = 'General', icon = 'cog' },
		{ id = 'layouts', label = 'Layouts', icon = 'save' },
		{ id = 'icons', label = 'Icon management', icon = 'grabber' },
	} },
	{ title = 'Viewers', items = {
		{ id = 'essential', label = 'Essential' },
		{ id = 'utility', label = 'Utility' },
		{ id = 'buffs', label = 'Buff icons' },
		{ id = 'buffBars', label = 'Buff bars' },
	} },
}

BUI.PageEngine.RegisterPage('cdm', {
	title = 'Cooldown Manager',
	buttonText = 'CDM',
	icon = 'wheel',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local tab = page:GetTab(1)
		local enabled = BUI.IsModuleEnabled('cdm')
		if enabled then
			CDM().Initialize()
			HookRefreshers()
		end
		local rail
		rail = Layout.RailPage(tab, { window = Window() }, {
			icon = 'wheel',
			title = 'Cooldown Manager',
			placeholder = 'Search cooldown manager...',
			tools = {
				{ icon = 'enable', tooltip = 'Turn the cooldown manager module on or off, needs a reload', get = function() return BUI.IsModuleEnabled('cdm') end, set = function(value)
					BUI.ModulesPage.ConfirmReload('cdm', value, Repaint)
				end },
			},
			preview = enabled and { height = PREVIEW_HEIGHT, build = function(band, kit) preview = BuildPreview(band, kit) end } or nil,
			rail = { groups = enabled and RAIL_GROUPS or { { title = 'Settings', items = { { id = 'off', label = 'Module off' } } } }, selected = enabled and selected or 'off' },
			build = function(ui, shell, parent, width, item, handle)
				if item.id == 'off' then
					local board = ui.Board(parent, width, { stacked = true, title = 'The cooldown manager is off', description = 'The Blizzard cooldown viewer runs untouched while this is off.' })
					board:AddSwitch('Cooldown manager module', function() return BUI.IsModuleEnabled('cdm') end, function(value)
						BUI.ModulesPage.ConfirmReload('cdm', value, Repaint)
					end, 'Turning it on needs a reload')
					return { board }
				end
				return Panes(ui, shell, parent, width, item, handle)
			end,
		})
		if not enabled then
			page:AutoRefresh()
			return
		end
		railPage = rail
		local Select = rail.Select
		function rail:Select(id)
			selected = id
			Select(self, id)
			Repaint()
			RefreshPreview()
		end
		local tabs = {}
		for index = 1, #TAB_IDS do tabs[index] = tab end
		pageFrame._page = { tabContents = tabs, currentTab = TAB_INDEX[selected], SetTab = function(_, index) rail:Select(TAB_IDS[index] or 'general') end }
		local module = CDM()
		module.state.buffsPreviewButton = { SetText = Repaint }
		module._previewBtn = { SetValue = Repaint }
		if GetCVar('cooldownViewerEnabled') ~= '1' then
			Modals.Confirm({
				parent = Window().frame,
				title = 'Cooldown Manager disabled',
				message = 'The Blizzard Cooldown Manager is turned off and BluUI needs it. Enable it and reload?',
				confirmText = 'Enable and reload', laterText = 'Enable later', cancelText = 'Close',
				onConfirm = function()
					SetCVar('cooldownViewerEnabled', '1')
					ReloadUI()
				end,
				onLater = function() SetCVar('cooldownViewerEnabled', '1') end,
			})
		end
		RefreshPreview()
		page:AutoRefresh()
	end,
	OnHide = function()
		local module = BUI.CDM
		if module.state.buffsPreview and module.state.buffsPreview:IsShown() then module.HideBuffsPreview() end
		if module.glowPreview and module.glowPreview:IsShown() then module.HideGlowPreview() end
		if module.IsBuffBarPreviewShown() then module.HideBuffBarPreview() end
	end,
})

local function RefreshIfOpen()
	if BUI.PageEngine.GetCurrentPage() ~= 'cdm' then return end
	local module = BUI.CDM
	if module._emStatusRefresh then module._emStatusRefresh() end
	if not module._iconListRefreshers then return end
	for _, callback in pairs(module._iconListRefreshers) do callback() end
end

BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'CDMPage', function(_, unit)
	if unit ~= 'player' then return end
	C_Timer.After(0.3, RefreshIfOpen)
end)
BUI.Events:Register('TRAIT_CONFIG_UPDATED', 'CDMPage', function() C_Timer.After(0.3, RefreshIfOpen) end)
BUI.Events:Register('COOLDOWN_VIEWER_DATA_LOADED', 'CDMPage', function() C_Timer.After(0.3, RefreshIfOpen) end)
BUI.Events:Register('EDIT_MODE_LAYOUTS_UPDATED', 'CDMPage', RefreshIfOpen)
