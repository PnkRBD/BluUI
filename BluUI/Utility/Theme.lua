local _, BUI = ...
local sharedMedia = LibStub('LibSharedMedia-3.0')

local function GetGeneral()
	local db = BUI.GetDB()
	return db and db.general
end

function BUI.GetAccentColor()
	local general = GetGeneral()
	if general and general.useClassColorTheme then
		local _, class = UnitClass('player')
		local color    = class and RAID_CLASS_COLORS[class]
		if color then return color.r, color.g, color.b, 1 end
	end
	local theme = general and general.themeColor
	if theme and theme[1] and theme[2] and theme[3] then return theme[1], theme[2], theme[3], theme[4] or 1 end
	return unpack(BUI.C.DEFAULT_ACCENT)
end

function BUI.GetGlobalTexture()
	local general     = GetGeneral()
	local textureName = general and general.texture or BUI.C.DEFAULT_TEXTURE
	return sharedMedia:Fetch('statusbar', textureName) or BUI.C.FALLBACK_TEXTURE
end

function BUI.GetGradientTint()
	local general = GetGeneral()
	if general and general.texture == BUI.C.GRADIENT_TEXTURE then
		return general.gradientColor
	end
end

function BUI.GetGlobalFont()
	local general  = GetGeneral()
	local fontName = general and general.font or BUI.C.DEFAULT_FONT
	return sharedMedia:Fetch('font', fontName) or BUI.C.FONT_PATH
end

function BUI.GetAddonFont()
	return BUI.C.BASE_MEDIA_PATH .. [[Fonts\gotham_narrow_ultra.ttf]]
end

function BUI.BuildFontDropdownItems(globalOption)
	local items = {}
	if globalOption then
		items[1] = { value = globalOption, text = 'Use Global Font' }
	end
	local fonts = sharedMedia:List('font')
	table.sort(fonts)
	for _, name in ipairs(fonts) do
		items[#items + 1] = { value = name, text = name, fontPath = sharedMedia:Fetch('font', name) }
	end
	return items
end

function BUI.BuildTextureDropdownItems(globalOption)
	local items = {}
	if globalOption then
		items[1] = { value = globalOption, text = 'Use Global Texture' }
	end
	local textures = sharedMedia:List('statusbar')
	table.sort(textures)
	for _, name in ipairs(textures) do
		items[#items + 1] = { value = name, text = name }
	end
	return items
end

function BUI.BuildSoundDropdownItems()
	local items = { { value = 'None', text = 'None' } }
	local sounds = sharedMedia:List('sound')
	table.sort(sounds)
	for _, name in ipairs(sounds) do
		if name ~= 'None' then
			items[#items + 1] = { value = name, text = name }
		end
	end
	return items
end

function BUI.PlaySoundByName(name)
	if not name or name == '' or name == 'None' then return end
	local path = sharedMedia:Fetch('sound', name, true)
	if not path then return end
	local db = BUI.GetDB()
	local channel = db and db.general.soundChannel or 'Master'
	PlaySoundFile(path, channel)
end

function BUI.ResolveSpellInput(text)
	if not text or text == '' then return nil end
	local linkID = tostring(text):match('spell:(%d+)')
	if linkID then return tonumber(linkID) end
	local numericID = tonumber(text)
	if numericID then return numericID end
	local info = C_Spell.GetSpellInfo(text)
	if info and info.spellID then return info.spellID end
	return nil
end

function BUI.SpellListItems(list)
	local items = {}
	if list then
		for spellID, active in pairs(list) do
			if active then
				local name, icon
				local info = C_Spell.GetSpellInfo(spellID)
				if info then name, icon = info.name, info.iconID end
				items[#items + 1] = { icon = icon, name = name or ('Spell ' .. tostring(spellID)), id = spellID, removable = true }
			end
		end
		table.sort(items, function(itemA, itemB) return (itemA.name or '') < (itemB.name or '') end)
	end
	return items
end

function BUI.SpellListSection(tab, options)
	local Layout = BluUI.BUILibClient.Layout
	Layout.Section(tab, options.title, options.desc)
	local list
	local function Rebuild()
		if not list or not list.ClearItems then return end
		list:ClearItems()
		for _, item in ipairs(BUI.SpellListItems(options.get())) do
			list:AddItem(item.icon, item.name, item.id, true)
		end
	end
	list = Layout.ItemList(tab, {
		hint   = options.hint or 'Spell link, ID, or exact name…',
		height = options.height or 240,
		items  = BUI.SpellListItems(options.get()),
		onAdd = function(text)
			local spellID = BUI.ResolveSpellInput(text)
			if not spellID then
				local message = "Couldn't resolve to a spell ID: " .. tostring(text)
				if options.onError then options.onError(message) else BUI.Print(message) end
				return
			end
			options.get()[spellID] = true
			Rebuild()
			if options.onChange then options.onChange() end
		end,
		onRemove = function(row)
			if row and row.id then
				options.get()[row.id] = options.removeToFalse and false or nil
				if options.onChange then options.onChange() end
			end
		end,
	})
	return list
end

local function GroupSpellsByName(ids)
	local byName, order = {}, {}
	for _, spellID in ipairs(ids) do
		local name, icon
		local info = C_Spell.GetSpellInfo(spellID)
		if info then name, icon = info.name, info.iconID end
		name = name or ('Spell ' .. tostring(spellID))
		local group = byName[name]
		if not group then
			group = { name = name, ids = {} }
			byName[name] = group
			order[#order + 1] = group
		end
		group.icon = group.icon or icon
		group.ids[#group.ids + 1] = spellID
	end
	table.sort(order, function(groupA, groupB) return groupA.name < groupB.name end)
	for _, group in ipairs(order) do
		table.sort(group.ids)
		group.id = group.ids[1]
		group.label = #group.ids > 1 and (group.name .. ' |cff808080(x' .. #group.ids .. ')|r') or group.name
	end
	return order
end

local function IconStrip(tab, options)
	local lib = BluUI.BUILibClient
	local Layout, Theme = lib.Layout, lib.Theme

	local ICON, GAP, MAX = 26, 4, 12
	local LABEL_H = 15
	local stripHeight = LABEL_H + ICON
	local pickColor = options.pickColor or { 1, 0.4, 0.4 }

	local frame = CreateFrame('Frame', nil, tab.child)
	frame:SetSize(MAX * (ICON + GAP) - GAP, stripHeight)
	frame.layoutHeight = stripHeight

	local label = frame:CreateFontString(nil, 'OVERLAY')
	label:SetFont(lib.Font, 10, '')
	label:SetPoint('TOPLEFT', 0, 0)
	label:SetTextColor(unpack(Theme.text.muted))
	label:SetText(options.label or '')

	local buttons = {}
	for buttonIndex = 1, MAX do
		local button = CreateFrame('Button', nil, frame)
		button:SetSize(ICON, ICON)
		button:SetPoint('TOPLEFT', (buttonIndex - 1) * (ICON + GAP), -LABEL_H)
		local iconTexture = button:CreateTexture(nil, 'ARTWORK')
		iconTexture:SetAllPoints()
		iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		button.icon = iconTexture
		local highlight = button:CreateTexture(nil, 'HIGHLIGHT')
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.25)
		button:SetScript('OnClick', function()
			if button._sid and options.onPick then options.onPick(button._sid) end
			GameTooltip:Hide()
		end)
		button:SetScript('OnEnter', function()
			if not button._sid then return end
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetSpellByID(button._sid)
			GameTooltip:AddLine('ID: ' .. button._sid, 0.5, 0.5, 0.5)
			if options.pickText then GameTooltip:AddLine(options.pickText, pickColor[1], pickColor[2], pickColor[3]) end
			GameTooltip:Show()
		end)
		button:SetScript('OnLeave', function() GameTooltip:Hide() end)
		button:Hide()
		buttons[buttonIndex] = button
	end

	local empty
	if options.emptyText then
		empty = frame:CreateFontString(nil, 'OVERLAY')
		empty:SetFont(lib.Font, 11, '')
		empty:SetPoint('TOPLEFT', 0, -LABEL_H - 8)
		empty:SetTextColor(unpack(Theme.text.muted))
		empty:SetText(options.emptyText)
	end

	local api = { frame = frame }
	function api.Rebuild()
		local ids = options.get() or {}
		for buttonIndex = 1, MAX do
			local button, spellID = buttons[buttonIndex], ids[buttonIndex]
			if spellID then
				local info = C_Spell.GetSpellInfo(spellID)
				button.icon:SetTexture(info and info.iconID or 134400)
				button._sid = spellID
				button:Show()
			else
				button._sid = nil
				button:Hide()
			end
		end
		local isEmpty = ids[1] == nil
		if empty then
			empty:SetShown(isEmpty)
		else
			frame:SetHeight(isEmpty and 1 or stripHeight)
			frame.layoutHeight = isEmpty and 1 or stripHeight
			label:SetShown(not isEmpty)
			Layout.Refresh(tab)
		end
	end
	api.Rebuild()

	frame:SetScript('OnShow', api.Rebuild)

	Layout.PositionInTab(tab, frame, stripHeight, 8)
	return api
end

local function SpellInputRow(tab, options)
	local lib = BluUI.BUILibClient
	local Layout, Controls, Widget, Theme, fontSize = lib.Layout, lib.Controls, lib.Widget, lib.Theme, lib.FONT_SIZE

	local rowHeight = 26
	local width = tab.width
	local container = CreateFrame('Frame', nil, tab.child)
	container:SetSize(width, rowHeight)
	container.layoutHeight = rowHeight

	local boxWidget = Widget.New(container, 'Frame', nil, { bg = Theme.bg.input, border = Theme.border.input, size = { width - 52, rowHeight } })
	local box = boxWidget.frame
	box:SetPoint('LEFT', 0, 0)
	box:EnableMouse(true)
	local SetHovered = boxWidget:SetupHoverBorder(nil, Theme.border.input)

	local edit = CreateFrame('EditBox', nil, box)
	edit:SetPoint('LEFT', 10, 0)
	edit:SetPoint('RIGHT', -10, 0)
	edit:SetHeight(20)
	edit:SetAutoFocus(false)
	edit:SetFont(lib.Font, fontSize, '')
	edit:SetTextColor(unpack(Theme.text.primary))

	local placeholder = edit:CreateFontString(nil, 'OVERLAY')
	placeholder:SetFont(lib.Font, fontSize, '')
	placeholder:SetPoint('LEFT')
	placeholder:SetTextColor(unpack(Theme.text.muted))
	placeholder:SetText(options.placeholder or 'Spell link, ID, or exact name…')

	local function Submit()
		local text = edit:GetText()
		if text ~= '' then
			options.onSubmit(text)
			edit:SetText('')
			edit:ClearFocus()
		end
	end

	local function HandleDrop()
		local infoType = GetCursorInfo()
		if infoType == 'spell' then
			local spellID = select(4, GetCursorInfo())
			ClearCursor()
			if spellID then options.onSubmit('spell:' .. spellID) end
			return true
		end
		return false
	end

	edit:SetScript('OnTextChanged', function(self) placeholder:SetShown(self:GetText() == '') end)
	edit:SetScript('OnEnterPressed', Submit)
	edit:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
	edit:SetScript('OnEnter', function() SetHovered(true) end)
	edit:SetScript('OnLeave', function() if not edit:HasFocus() then SetHovered(false) end end)
	edit:SetScript('OnEditFocusGained', function() SetHovered(true) end)
	edit:SetScript('OnEditFocusLost', function() SetHovered(false) end)
	edit:SetScript('OnReceiveDrag', HandleDrop)
	edit:SetScript('OnMouseDown', function(self, mouseButton)
		if mouseButton == 'LeftButton' and not HandleDrop() then self:SetFocus() end
	end)
	box:SetScript('OnMouseDown', function(_, mouseButton)
		if mouseButton == 'LeftButton' and not HandleDrop() then edit:SetFocus() end
	end)
	box:SetScript('OnReceiveDrag', HandleDrop)

	local addButton = Controls.Button(container, 'Add', 48, Submit)
	addButton:SetHeight(rowHeight)
	addButton:SetPoint('LEFT', box, 'RIGHT', 4, 0)

	Layout.PositionInTab(tab, container, rowHeight, 10)
	return container
end

local ROW_H, ROW_STRIDE = 28, 30
local LIST_MIN_H, LIST_MAX_H = 44, 310

local function BlacklistRows(tab, options)
	local lib = BluUI.BUILibClient
	local Layout, Controls, Widget, Theme, fontSize = lib.Layout, lib.Controls, lib.Widget, lib.Theme, lib.FONT_SIZE

	local width = tab.width
	local listFrame = Widget.New(tab.child, 'Frame', nil, { bg = Theme.bg.dark, border = Theme.border.default, size = { width, LIST_MIN_H } }).frame
	listFrame.layoutHeight = LIST_MIN_H

	local scroll = Controls.ScrollFrame(listFrame, width, LIST_MIN_H, LIST_MIN_H)
	scroll:SetPoint('TOPLEFT', 0, 0)

	local empty = listFrame:CreateFontString(nil, 'OVERLAY')
	empty:SetFont(lib.Font, 11, '')
	empty:SetPoint('LEFT', 12, 0)
	empty:SetTextColor(unpack(Theme.text.muted))
	empty:SetText(options.emptyText or 'Nothing blacklisted.')

	Layout.PositionInTab(tab, listFrame, LIST_MIN_H, 10)

	local rowWidth = width - 14
	local rows = {}

	local function CreateRow()
		local row = Widget.New(scroll.child, 'Frame', nil, { bg = Theme.bg.light, borderless = true, size = { rowWidth, ROW_H } }).frame

		local icon = row:CreateTexture(nil, 'ARTWORK')
		icon:SetSize(20, 20)
		icon:SetPoint('LEFT', 6, 0)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.icon = icon

		local name = row:CreateFontString(nil, 'OVERLAY')
		name:SetFont(lib.Font, fontSize, '')
		name:SetPoint('LEFT', icon, 'RIGHT', 8, 0)
		name:SetPoint('RIGHT', row, 'RIGHT', -160, 0)
		name:SetJustifyH('LEFT')
		name:SetTextColor(unpack(Theme.text.primary))
		row.name = name

		local idText = row:CreateFontString(nil, 'OVERLAY')
		idText:SetFont(lib.Font, 10, '')
		idText:SetPoint('RIGHT', -32, 0)
		idText:SetTextColor(unpack(Theme.text.muted))
		row.id = idText

		local closeButton = Controls.Icon(row, { preset = 'close', size = 20, onClick = function()
			if row._entry and options.onDelete then options.onDelete(row._entry) end
		end })
		closeButton:SetPoint('RIGHT', -6, 0)
		row.xBtn = closeButton

		row:EnableMouse(true)
		row:SetScript('OnEnter', function()
			row:SetBackdropColor(unpack(Theme.bg.hover))
			local entry = row._entry
			if entry then
				GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
				GameTooltip:SetSpellByID(entry.id)
				GameTooltip:AddLine('ID: ' .. table.concat(entry.ids, ', '), 0.5, 0.5, 0.5)
				if entry.builtin then
					GameTooltip:AddLine('Removing a built-in only disables it.', 0.7, 0.7, 0.7)
				end
				GameTooltip:Show()
			end
		end)
		row:SetScript('OnLeave', function()
			row:SetBackdropColor(unpack(Theme.bg.light))
			GameTooltip:Hide()
		end)

		row:Hide()
		return row
	end

	local api = { frame = listFrame }

	function api.Rebuild(entries)
		for rowIndex = #rows + 1, #entries do rows[rowIndex] = CreateRow() end
		for rowIndex = 1, #rows do
			local row, entry = rows[rowIndex], entries[rowIndex]
			if entry then
				row._entry = entry
				row.icon:SetTexture(entry.icon or 134400)
				row.name:SetText(entry.label)
				local idLabel = #entry.ids > 2
					and (entry.ids[1] .. ' +' .. (#entry.ids - 1))
					or table.concat(entry.ids, ', ')
				row.id:SetText(idLabel)
				row:ClearAllPoints()
				row:SetPoint('TOPLEFT', scroll.child, 'TOPLEFT', 0, -(rowIndex - 1) * ROW_STRIDE)
				row:Show()
			else
				row._entry = nil
				row:Hide()
			end
		end

		local entryCount = #entries
		empty:SetShown(entryCount == 0)
		local contentHeight = entryCount * ROW_STRIDE
		local newHeight = math.max(LIST_MIN_H, math.min(LIST_MAX_H, contentHeight + 8))
		listFrame:SetHeight(newHeight)
		listFrame.layoutHeight = newHeight
		scroll.frame:SetSize(width, newHeight)
		scroll:SetChildHeight(math.max(contentHeight, newHeight - 8))
		Layout.Refresh(tab)
	end

	return api
end

function BUI.BlacklistSection(tab, options)
	local AB = BUI.AuraBlacklist
	local Layout = BluUI.BUILibClient.Layout
	local polarity, scope = options.polarity, options.scope

	Layout.Section(tab, options.title, options.desc)

	local recent, list, disabled
	local Rebuild

	local function Err(message)
		if options.onError then options.onError(message) else BUI.Print(message) end
	end

	local function Changed()
		AB.RefreshConsumers(scope)
		if options.onChange then options.onChange() end
	end

	local function ShownBuiltInGroups()
		if not AB.ShowsBuiltIns(scope, polarity) then return {} end
		local shown = {}
		for _, entry in ipairs(AB.BuiltInEntries(polarity)) do
			if not entry.hidden then shown[#shown + 1] = entry.id end
		end
		return GroupSpellsByName(shown)
	end

	local function CollectEntries()
		local entries = {}
		for _, group in ipairs(GroupSpellsByName(AB.UserEntries(scope, polarity))) do
			group.builtin = false
			entries[#entries + 1] = group
		end
		if AB.ShowsBuiltIns(scope, polarity) then
			local hidden = {}
			for _, entry in ipairs(AB.BuiltInEntries(polarity)) do
				if entry.hidden then hidden[#hidden + 1] = entry.id end
			end
			for _, group in ipairs(GroupSpellsByName(hidden)) do
				group.builtin = true
				entries[#entries + 1] = group
			end
		end
		table.sort(entries, function(entryA, entryB) return entryA.name < entryB.name end)
		return entries
	end

	local function AddSpell(spellID)
		AB.UserAdd(scope, polarity, spellID)
		Rebuild()
		Changed()
	end

	recent = IconStrip(tab, {
		label = 'RECENTLY SEEN',
		pickText = 'Click to blacklist',
		emptyText = 'No auras seen yet.',
		get = function() return AB.RecentEntries(scope, polarity) end,
		onPick = AddSpell,
	})

	SpellInputRow(tab, {
		onSubmit = function(text)
			local spellID = BUI.ResolveSpellInput(text)
			if not spellID then
				Err("Couldn't resolve to a spell ID: " .. tostring(text))
				return
			end
			local set = scope == 'group' and AB.GroupSet(polarity) or AB.UnitSet(polarity)
			if set[spellID] then
				Err('Already blacklisted: ' .. tostring(spellID))
				return
			end
			AddSpell(spellID)
		end,
	})

	list = BlacklistRows(tab, {
		emptyText = 'Nothing blacklisted.',
		onDelete = function(entry)
			if entry.builtin then
				for _, spellID in ipairs(entry.ids) do
					AB.SetBuiltInHidden(polarity, spellID, false)
				end
			else
				for _, spellID in ipairs(entry.ids) do
					AB.UserRemove(scope, polarity, spellID)
				end
			end
			Rebuild()
			Changed()
		end,
	})

	disabled = IconStrip(tab, {
		label = 'DISABLED BUILT-INS',
		pickText = 'Click to re-enable',
		pickColor = { 0.4, 1, 0.4 },
		get = function()
			local ids = {}
			for _, group in ipairs(ShownBuiltInGroups()) do
				ids[#ids + 1] = group.id
			end
			return ids
		end,
		onPick = function(spellID)
			for _, group in ipairs(ShownBuiltInGroups()) do
				if group.id == spellID then
					for _, groupSpellID in ipairs(group.ids) do
						AB.SetBuiltInHidden(polarity, groupSpellID, true)
					end
					break
				end
			end
			Rebuild()
			Changed()
		end,
	})

	Rebuild = function()
		list.Rebuild(CollectEntries())
		recent.Rebuild()
		disabled.Rebuild()
	end
	Rebuild()
end

local function CreateFontGetter(dbKey)
	return function()
		local general  = GetGeneral()
		local fontName = general and general[dbKey]
		if fontName then
			local path = sharedMedia:Fetch('font', fontName)
			if path then return path end
		end
		return BUI.GetGlobalFont()
	end
end

BUI.GetCDMFont            = CreateFontGetter('cdmFont')
BUI.GetTrackingFont       = CreateFontGetter('trackingFont')
BUI.GetPowerFont          = CreateFontGetter('powerFont')
BUI.GetSecondaryPowerFont = CreateFontGetter('secondaryPowerFont')

function BUI.GetModuleFont(moduleSettings)
	if not moduleSettings then return BUI.GetGlobalFont() end
	local fontName = moduleSettings.font
	if not fontName or fontName == BUI.C.GLOBAL_OPTION then return BUI.GetGlobalFont() end
	return sharedMedia:Fetch('font', fontName) or BUI.GetGlobalFont()
end

function BUI.ApplySlug(flags)
	flags = flags or ''
	local general = GetGeneral()
	if general and general.fontSlug then
		if not flags:find('SLUG') then
			flags = (flags == '') and 'SLUG' or (flags .. '|SLUG')
		end
	elseif flags:find('SLUG') then
		flags = flags:gsub('|?SLUG', '')
	end
	return flags
end

function BUI.GetFontOutline()
	return BUI.ApplySlug('OUTLINE')
end
