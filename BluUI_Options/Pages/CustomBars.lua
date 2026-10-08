local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Layout, Modals = BUILib.Layout, BUILib.Modals
local Section = Layout.TableSection
local CustomBars = BUI.CustomBars
local IconEngine = BUI.IconEngine
local Pixel = BUI.Pixel

local PREVIEW_INSET = 20
local PREVIEW_ROOM = 40
local MENU_WIDTH = 150
local CHARACTER_WIDTH = 260
local INPUT_WIDTH = 260
local NAME_WIDTH = 300
local LIST_ICON_X = Layout.DRAG_TITLE_X
local ERASE_SIZE = BUILib.Layout.ERASE_SIZE
local ERASE_INSET = 18
local TOOL_SIZE = 22
local TOOL_GAP = 12
local TOOLS_ROOM = ERASE_INSET + ERASE_SIZE + 3 * (TOOL_GAP + TOOL_SIZE) + TOOL_GAP
local HIDDEN_ALPHA = 0.45
local DEFAULT_ICON = 134400
local TRINKET_SLOTS = { 13, 14 }
local ID_PREFIX = 'customBar'
local NEW_ID = ID_PREFIX .. 'New'
local IMPORT_ID = ID_PREFIX .. 'Import'

local GROW_OPTIONS = { { value = 'LEFT', text = 'Grow left' }, { value = 'RIGHT', text = 'Grow right' } }
local ROW_OPTIONS = { { value = 'DOWN', text = 'Down' }, { value = 'UP', text = 'Up' } }

local selectedIndex = 1
local showingImport = false
local importCharacter
local importSkips = {}
local railIcons = {}
local preview
local fonts

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function Bars()
	return BUI.GetDB().customBars
end

local function Current()
	local list = Bars()
	if not list[selectedIndex] then selectedIndex = math.max(1, #list) end
	return list[selectedIndex]
end

local function Shown()
	if showingImport then return nil end
	return Current()
end

local function RefreshPreview()
	if preview then preview:Update() end
end

local function Apply()
	CustomBars.RefreshBar(selectedIndex)
	RefreshPreview()
end

local function RebuildPage()
	BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
end

local function RebuildPane(page)
	BUILib.Defer(function() page:RebuildCurrent() end)
end

local function IndexOf(list, value)
	for position, candidate in ipairs(list) do
		if candidate == value then return position end
	end
end

local function StoredIndex(spells, stored)
	local key = tostring(stored)
	for position, candidate in ipairs(spells) do
		if tostring(candidate) == key then return position end
	end
end

local function Option(bar, label, key, extra)
	local option = { label = label, get = function() return bar[key] end, set = function(value) bar[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Toggle(bar, label, key)
	return { label = label, get = function() return bar[key] == true end, set = function(value) bar[key] = value end }
end

local function OnUnlessOff(bar, label, key)
	return { label = label, get = function() return bar[key] ~= false end, set = function(value) bar[key] = value end }
end

local function Color(bar, label, key)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = true,
		get = function()
			local color = bar[key]
			return color[1], color[2], color[3], color[4] or 1
		end,
		set = function(red, green, blue, alpha) bar[key] = { red, green, blue, alpha } end,
	}
end

local function NameOption(bar)
	return { label = 'Name', kind = 'input', placeholder = 'Name', get = function() return bar.name end, set = function(name)
		if name == '' then return end
		bar.name = name
		RebuildPage()
	end }
end

local function ConfirmDelete(index)
	local bar = Bars()[index]
	Modals.Confirm({
		parent = Window().frame,
		title = 'Delete ' .. bar.name,
		message = 'Delete "' .. bar.name .. '"? Its tracked spells and items go with it.',
		confirmText = 'Delete', cancelText = 'Cancel',
		onConfirm = function()
			CustomBars.DeleteBar(index)
			selectedIndex = math.max(1, index - 1)
			RebuildPage()
		end,
	})
end

local function Duplicate(index)
	selectedIndex = CustomBars.DuplicateBar(index)
	RebuildPage()
end

local function Describe(id, isItem)
	local icon, name
	if isItem then icon, name = BUI.Lookup.GetItemInfo(id) else icon, name = BUI.Lookup.GetSpellInfo(id) end
	return icon or DEFAULT_ICON, name or ((isItem and 'Item ' or 'Spell ') .. id)
end

local function Entries(bar)
	local list = {}
	CustomBars.ForEachIcon(bar, function(kind, value)
		if kind == 'slot' then
			local entry = { name = 'Trinket ' .. IndexOf(TRINKET_SLOTS, value), icon = DEFAULT_ICON, sub = 'Nothing equipped', hideKey = CustomBars.SlotKey(value), slot = value }
			local itemID = GetInventoryItemID('player', value)
			if itemID then
				entry.itemID = itemID
				entry.icon, entry.sub = Describe(itemID, true)
			end
			list[#list + 1] = entry
		elseif kind == 'racial' then
			local icon, name = Describe(value, false)
			list[#list + 1] = { id = value, icon = icon, name = name, sub = 'Racial, added automatically', hideKey = CustomBars.RacialKey(value) }
		else
			local id, isItem, explicitSpell = IconEngine.ExtractSpellItemID(value)
			if not id then return end
			local icon, name = Describe(id, isItem)
			list[#list + 1] = {
				stored = value, id = id, icon = icon, name = name, sub = (isItem and 'Item ' or 'Spell ') .. id, hideKey = id, custom = true,
				consumable = IconEngine.ClassifyAsSpellOrItem(id, isItem, nil, explicitSpell) == 'consumable',
				potion = isItem and BUI.CDM.Custom.IsPotionItem(id),
			}
		end
	end)
	return list
end

local function SaveOrder(spells, entries)
	local order, listed = {}, {}
	for _, entry in ipairs(entries) do
		local key = entry.custom and entry.stored or entry.hideKey
		order[#order + 1] = key
		listed[key] = true
	end
	for _, stored in ipairs(spells) do
		if not listed[stored] then order[#order + 1] = stored end
	end
	wipe(spells)
	for position, key in ipairs(order) do spells[position] = key end
end

local function FirstIcon(bar)
	for _, entry in ipairs(Entries(bar)) do
		if entry.icon ~= DEFAULT_ICON then return entry.icon end
	end
end

local function RailIconChanged()
	return FirstIcon(Current()) ~= railIcons[selectedIndex]
end

local function RefreshList(page)
	if RailIconChanged() then RebuildPage() else RebuildPane(page) end
end

local function PotionLabel(entry)
	local _, _, _, _, _, _, subclassID = C_Item.GetItemInfoInstant(entry.id)
	local label = subclassID == Enum.ItemConsumableSubclass.Flask and 'Flask display' or 'Potion display'
	if BUI.CDM.GetPotionPrioFor(entry.stored) then label = label .. ', customized' end
	return label
end

local function SettingsBoard(ui, parent, width, bar, index, page)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = bar.name,
		description = 'A row of icons for the cooldowns, trinkets, potions and buffs you pick. Unlock it with the eye to drag it, right-click it to lock it again.',
		buttons = {
			{ text = 'Duplicate', icon = 'copy', onClick = function() Duplicate(index) end },
			{ text = 'Delete', style = 'danger', onClick = function() ConfirmDelete(index) end },
		},
	})
	board:AddTools('Bar', 'Name, position and on or off', {
		{ icon = 'text', tooltip = 'Name', title = 'Bar', options = { NameOption(bar) } },
		BUI.PositionTool(bar, { noCenter = true }),
		{ icon = 'eye', tooltip = 'Unlock to drag, right-click the bar to lock', get = function() return not bar.locked end, set = function(value)
			bar.locked = not value
			Apply()
			Repaint()
		end },
		{ get = function() return bar.enabled == true end, set = function(value)
			bar.enabled = value
			Repaint()
		end },
	}, Apply)
	board:AddSwitch('Racials', function() return bar.showRacials == true end, function(value)
		bar.showRacials = value
		Apply()
		RefreshList(page)
	end, 'Add the racial abilities you know')
	board:AddSwitch('Hide when not in bags', function() return bar.hideIfNotInBags == true end, function(value)
		bar.hideIfNotInBags = value
		Apply()
	end, 'Skip items you have none of')
	board:AddSwitch('Tooltips', function() return bar.showTooltips ~= false end, function(value)
		bar.showTooltips = value
		Apply()
	end, 'Show the tooltip when hovering an icon')
	board:AddSwitch('Hide the global cooldown', function() return bar.hideGCD == true end, function(value)
		bar.hideGCD = value
		Apply()
	end, 'No cooldown swipe while only the global cooldown is running')
	board:AddTools('Trinkets', 'Add your equipped trinkets', {
		{ tooltip = 'Which trinkets', title = 'Trinkets', options = { Toggle(bar, 'Usable trinkets only', 'trinketsUsableOnly') } },
		{ get = function() return bar.showTrinkets == true end, set = function(value)
			bar.showTrinkets = value
			RefreshList(page)
		end },
	}, Apply)
	board:AddTools('Icons', 'Size, border and opacity', {
		Color(bar, 'Border color', 'borderColor'),
		{ tooltip = 'Icon size, border and opacity', title = 'Icons', options = {
			Option(bar, 'Icon size', 'iconSize', { min = 20, max = 80, step = 1 }),
			Option(bar, 'Spacing', 'spacing', { min = -20, max = 20, step = 1 }),
			{ label = 'Zoom %', min = 0, max = 20, step = 1, get = function() return math.floor(bar.zoom * 100 + 0.5) end, set = function(value) bar.zoom = value / 100 end },
			Option(bar, 'Border size', 'borderSize', { min = 0, max = 5, step = 1 }),
			Option(bar, 'Opacity %', 'barOpacity', { min = 0, max = 100, step = 1 }),
		} },
	}, Apply)
	board:AddTools('Layout', 'Grow direction, rows and layering', {
		{ entries = GROW_OPTIONS, width = MENU_WIDTH, get = function() return bar.growDirection end, set = function(value) bar.growDirection = value end },
		{ tooltip = 'Rows and layering', title = 'Layout', options = {
			Option(bar, 'Row growth', 'growVertical', { entries = ROW_OPTIONS }),
			Option(bar, 'Icons per row, 0 for one row', 'maxPerRow', { min = 0, max = 20, step = 1 }),
			Option(bar, 'Strata', 'frameStrata', { entries = BUI.C.STRATA_OPTIONS }),
			Option(bar, 'Frame level', 'frameLevel', { min = 0, max = 100, step = 1 }),
		} },
	}, Apply)
	board:AddTools('Font', 'Cooldown and stack text on every bar', {
		{ entries = fonts, width = MENU_WIDTH, get = function() return BUI.GetDB().general.trackingFont or BUI.C.GLOBAL_OPTION end, set = function(value)
			BUI.GetDB().general.trackingFont = value ~= BUI.C.GLOBAL_OPTION and value or nil
		end },
	}, CustomBars.RefreshAllBars)
	board:AddTools('Cooldown text', 'Time left on each icon', {
		{ icon = 'text', tooltip = 'Size and placement', title = 'Cooldown text', options = {
			Option(bar, 'Size', 'cooldownTextSize', { min = 8, max = 24, step = 1 }),
			Option(bar, 'Position', 'cooldownTextPosition', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
			Option(bar, 'Horizontal offset', 'cooldownTextOffsetX', { min = -20, max = 20, step = 1 }),
			Option(bar, 'Vertical offset', 'cooldownTextOffsetY', { min = -20, max = 20, step = 1 }),
		} },
		OnUnlessOff(bar, nil, 'showCooldownText'),
	}, Apply)
	board:AddTools('Stack text', 'Charges and item counts', {
		{ icon = 'text', tooltip = 'Size and placement', title = 'Stack text', options = {
			Option(bar, 'Size', 'stackTextSize', { min = 8, max = 20, step = 1 }),
			Option(bar, 'Position', 'stackTextPosition', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
			Option(bar, 'Horizontal offset', 'stackTextOffsetX', { min = -20, max = 20, step = 1 }),
			Option(bar, 'Vertical offset', 'stackTextOffsetY', { min = -20, max = 20, step = 1 }),
		} },
		OnUnlessOff(bar, nil, 'showStackText'),
	}, Apply)
	return board
end

local function TrackedBoard(ui, parent, width, bar, page)
	local spells = bar.customSpells
	local entries = Entries(bar)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Tracked spells and items',
		description = 'Top to bottom here is first to last on the bar. Drag a row to reorder it. Type a name, paste an ID or a link, then press Enter.',
		columns = { { 'Spell or item', LIST_ICON_X } },
	})
	local function Add(id, isItem)
		local stored = (isItem and 'item:' or 'spell:') .. id
		if StoredIndex(spells, stored) then return end
		spells[#spells + 1] = stored
		Apply()
		RefreshList(page)
	end
	local addRow = Section.AddRow(board, 'add a spell or item')
	ui.RowTitle(addRow, 'Add a spell or item', 'Name, ID or link', LIST_ICON_X, NAME_WIDTH)
	BUI.SpellSearch(ui, addRow, INPUT_WIDTH, { onPick = function(hit) Add(hit.id, hit.isItem) end }):SetPoint('RIGHT', -ui.ROW_INSET, 0)

	board:DragList(function(index, delta, count)
		Layout.ShiftBlock(entries, index, delta, count)
		page:Resize()
	end, function()
		SaveOrder(spells, entries)
		Apply()
		if RailIconChanged() then RebuildPage() end
	end)
	for _, entry in ipairs(entries) do
		local row, title, subtitle = board:AddDragRow(entry.name, TOOLS_ROOM, entry.sub, entry.icon)
		local icon = row.icon
		ui.Bind(row, function()
			local hidden = bar.hiddenIcons[entry.hideKey] == true
			icon:SetDesaturated(hidden)
			title:SetAlpha(hidden and HIDDEN_ALPHA or 1)
			subtitle:SetAlpha(hidden and HIDDEN_ALPHA or 1)
		end)
		local x = ERASE_INSET
		local function Put(control, size)
			control:SetPoint('RIGHT', -x, 0)
			x = x + size + TOOL_GAP
		end
		if entry.custom then
			Put(ui.IconButton(row, 'erase', 'Remove ' .. entry.name, function()
				table.remove(spells, StoredIndex(spells, entry.stored))
				Apply()
				RefreshList(page)
			end, 'danger', ERASE_SIZE), ERASE_SIZE)
		else
			x = x + ERASE_SIZE + TOOL_GAP
		end
		Put(ui.Tool(row, { icon = 'eye', tooltip = 'Show on the bar', get = function() return bar.hiddenIcons[entry.hideKey] ~= true end, set = function(value)
			bar.hiddenIcons[entry.hideKey] = not value or nil
			Apply()
			Repaint()
		end }), TOOL_SIZE)
		if entry.potion then
			Put(ui.IconButton(row, 'cog', PotionLabel(entry), function()
				BUI.ShowCDMPotionModal(BUI.CDM, entry.id, entry.stored, bar, nil, function()
					Apply()
					page:RebuildCurrent()
				end)
			end), TOOL_SIZE)
		end
		local options = {}
		if entry.consumable then
			options[#options + 1] = { label = 'Hide when you have none', get = function() return bar.hideWhenZero ~= nil and bar.hideWhenZero[entry.id] == true end, set = function(value)
				bar.hideWhenZero = bar.hideWhenZero or {}
				bar.hideWhenZero[entry.id] = value or nil
			end }
		end
		if entry.itemID then
			ui.Bind(subtitle, function() subtitle:SetText(entry.sub .. (bar.trinketBlacklist[entry.itemID] and ', skipped' or '')) end)
			options[#options + 1] = { label = 'Skip this trinket', get = function() return bar.trinketBlacklist[entry.itemID] == true end, set = function(value)
				bar.trinketBlacklist[entry.itemID] = value or nil
			end }
		end
		if #options > 0 then
			Put(ui.Tool(row, { tooltip = entry.name .. ' options', title = entry.name, options = options }, function()
				Apply()
				Repaint()
			end), TOOL_SIZE)
		end
	end
	if #entries == 0 then
		local empty = Section.AddRow(board, 'nothing tracked yet')
		ui.RowTitle(empty, 'Nothing tracked yet', 'Search above to add a spell or an item', LIST_ICON_X, NAME_WIDTH)
	end
	return board
end

local function Import()
	local skips = importSkips[importCharacter] or {}
	local picks = {}
	for _, info in ipairs(CustomBars.GetBarInfoForCharacter(importCharacter)) do
		if not skips[info.index] then picks[#picks + 1] = info.index end
	end
	if #picks == 0 then return end
	CustomBars.CopyBarsFromCharacter(importCharacter, picks)
	selectedIndex = CustomBars.GetBarCount()
	showingImport = false
	RebuildPage()
end

local function ImportBoard(ui, parent, width, page)
	local characters = CustomBars.GetOtherCharacters()
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Import',
		description = 'Copy tracking bars from another character on this account. Copies keep their icons and settings and land at the center of the screen.',
		buttons = #characters > 0 and { { text = 'Import', icon = 'copy', style = 'primary', onClick = Import } } or nil,
	})
	if #characters == 0 then
		board:AddRow('Nothing to import', 'No other character on this account has tracking bars yet')
		return board
	end
	if not IndexOf(characters, importCharacter) then importCharacter = characters[1] end
	local entries = {}
	for _, character in ipairs(characters) do entries[#entries + 1] = { value = character, text = character } end
	board:AddTools('Character', 'Where to copy from', {
		{ entries = entries, width = CHARACTER_WIDTH, get = function() return importCharacter end, set = function(value) importCharacter = value end },
	}, function() page:RebuildCurrent() end)
	local skips = importSkips[importCharacter] or {}
	importSkips[importCharacter] = skips
	board:AddCaption('Bars to copy')
	for _, info in ipairs(CustomBars.GetBarInfoForCharacter(importCharacter)) do
		board:AddSwitch(info.name .. '  (' .. info.count .. ')', function() return not skips[info.index] end, function(value)
			skips[info.index] = not value or nil
		end, info.count .. ' tracked spells and items')
	end
	return board
end

local function BuildPreview(band, kit)
	local stage = CreateFrame('Frame', nil, band)
	stage:SetAllPoints()
	local pool = {}
	local note = kit.Text(stage, '', 12, 'muted')
	note:SetPoint('CENTER')
	function stage:Update()
		for _, frame in ipairs(pool) do frame:Hide() end
		local bar = Shown()
		local list = bar and CustomBars.ShownIcons(bar) or {}
		local count = #list
		note:SetShown(count == 0)
		if count == 0 then
			if bar and #Entries(bar) > 0 then
				note:SetText('Nothing on this bar shows for this character right now')
			elseif bar then
				note:SetText('Nothing on this bar yet, add a spell or an item below')
			elseif Current() then
				note:SetText('Pick a bar from the rail to see it here')
			else
				note:SetText('Nothing here yet, start a bar from the rail or import one')
			end
			return
		end
		local gap = bar.spacing
		local room = self:GetWidth() - PREVIEW_ROOM
		local size = math.min(bar.iconSize, self:GetHeight() - PREVIEW_INSET)
		local total = count * size + (count - 1) * gap
		if total > room then
			size = math.floor((room - (count - 1) * gap) / count)
			total = count * size + (count - 1) * gap
		end
		local startX = -total / 2 + size / 2
		local growLeft = bar.growDirection == 'LEFT'
		local zoom = bar.zoom
		local border = bar.borderColor
		for index = 1, count do
			local frame = pool[index]
			if not frame then
				frame = CreateFrame('Frame', nil, self)
				frame.texture = frame:CreateTexture(nil, 'ARTWORK')
				frame.texture:SetPoint('TOPLEFT', 1, -1)
				frame.texture:SetPoint('BOTTOMRIGHT', -1, 1)
				pool[index] = frame
			end
			frame:SetSize(size, size)
			frame:ClearAllPoints()
			frame:SetPoint('CENTER', self, 'CENTER', startX + (index - 1) * (size + gap), 0)
			frame.texture:SetTexture(list[growLeft and (count - index + 1) or index])
			frame.texture:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
			Pixel.ApplyBorder(frame, bar.borderSize, border[1], border[2], border[3], border[4] or 1)
			frame:Show()
		end
	end
	preview = stage
	return stage
end

local function Panes(ui, _, parent, width, item, page)
	if item.id == NEW_ID then
		selectedIndex = CustomBars.AddBar()
		showingImport = false
		RebuildPage()
		return {}
	end
	if item.id == IMPORT_ID then return { ImportBoard(ui, parent, width, page) } end
	local bar = Bars()[item.index]
	return { SettingsBoard(ui, parent, width, bar, item.index, page), TrackedBoard(ui, parent, width, bar, page) }
end

local function RailGroup()
	local list = {}
	wipe(railIcons)
	for index, bar in ipairs(Bars()) do
		railIcons[index] = FirstIcon(bar)
		list[index] = { id = ID_PREFIX .. index, label = bar.name, texture = railIcons[index], icon = 'capsule', index = index }
	end
	list[#list + 1] = { id = NEW_ID, label = 'New bar', icon = 'plus' }
	list[#list + 1] = { id = IMPORT_ID, label = 'Import', icon = 'copy' }
	return { title = 'Custom bars', items = list }
end

local function Owns(id)
	return id:sub(1, #ID_PREFIX) == ID_PREFIX
end

local function Select(id)
	showingImport = id == IMPORT_ID
	local index = tonumber(id:match('^' .. ID_PREFIX .. '(%d+)$'))
	if index then selectedIndex = index end
end

local function BarID()
	if Current() then return ID_PREFIX .. selectedIndex end
	return IMPORT_ID
end

local function ActiveID()
	if showingImport then return IMPORT_ID end
	return BarID()
end

local function Prepare(fontItems)
	fonts = fontItems
	CustomBars.SetLockCallback(Repaint)
end

BUI.CustomBarsPage = {
	IMPORT_ID = IMPORT_ID,
	Owns = Owns,
	RailGroup = RailGroup,
	Select = Select,
	BarID = BarID,
	ActiveID = ActiveID,
	Panes = Panes,
	BuildPreview = BuildPreview,
	Prepare = Prepare,
}
