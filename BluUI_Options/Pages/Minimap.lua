local BUI = BluUI
local BUILib = BUI.BUILibClient
local Controls, Layout, Modals = BUILib.Controls, BUILib.Layout, BUILib.Modals
local MinimapModule = BUI.Minimap
local Datatext = BUI.Datatext
local ButtonBar = BUI.MinimapButtonBar

local floor = math.floor

local PAGE_WIDTH = 960
local NAME_WIDTH = 260
local SLIDER_WIDTH = 220
local DROPDOWN_WIDTH = 200
local SWATCH_SIZE = 28
local SWATCH_ROOM = 60
local SWITCH_WIDTH = 40
local SHOWN_COLUMN = 344
local ARROW = 22
local ARROW_GAP = 4
local ORDER_ROOM = SWITCH_WIDTH + 12 + ARROW * 2 + ARROW_GAP

local RAIL_GROUPS = {
	{ title = 'Map', items = {
		{ id = 'map', label = 'Map', icon = 'minimap' },
		{ id = 'indicators', label = 'Indicators', icon = 'eye' },
		{ id = 'text', label = 'Clock and zone', icon = 'edit' },
	} },
	{ title = 'Around the map', items = {
		{ id = 'datatext', label = 'Datatext bar', icon = 'report2' },
		{ id = 'buttons', label = 'Drawer and buttons', icon = 'modules5' },
	} },
}
local PANE_IDS = { 'map', 'indicators', 'text', 'datatext', 'buttons' }
local PANE_INDEX = {}
for index, id in ipairs(PANE_IDS) do PANE_INDEX[id] = index end

local SIDES = {
	{ value = 'LEFT', text = 'Left' },
	{ value = 'RIGHT', text = 'Right' },
	{ value = 'TOP', text = 'Top' },
	{ value = 'BOTTOM', text = 'Bottom' },
}
local ALIGNS = {
	{ value = 'START', text = 'Start' },
	{ value = 'CENTER', text = 'Center' },
	{ value = 'END', text = 'End' },
}
local ANCHORS = {
	{ value = 'BOTTOM', text = 'Bottom' },
	{ value = 'TOP', text = 'Top' },
	{ value = 'LEFT', text = 'Left' },
	{ value = 'RIGHT', text = 'Right' },
	{ value = 'INSIDE_BOTTOM', text = 'Inside bottom' },
	{ value = 'INSIDE_TOP', text = 'Inside top' },
}

local INDICATORS = {
	{ key = 'queue', name = 'Queue eye', sub = 'Dungeon, raid and PvP queue status' },
	{ key = 'difficulty', name = 'Difficulty', sub = 'The instance difficulty', hide = 'minimapHideDifficulty' },
	{ key = 'mail', name = 'Mail', sub = 'New mail waiting', hide = 'minimapHideMail' },
	{ key = 'crafting', name = 'Crafting orders', sub = 'Personal crafting orders', hide = 'minimapHideCrafting' },
	{ key = 'missions', name = 'Folio', sub = 'The expansion landing page', hide = 'minimapHideGarrison' },
}

local function Window()
	return BUI.PageEngine.window
end

local function Interface()
	return BUI.GetDB().interface
end

local function Bar()
	return Datatext.GetMinimapDB()
end

local function Buttons()
	return Interface().buttonBar
end

local function Repaint()
	Window():Repaint()
end

local function Named(entries, value)
	for _, entry in ipairs(entries) do
		if entry.value == value then return entry.text end
	end
	return value
end

local function Slider(ui, row, minimum, maximum, step, get, set)
	ui.Slider(row, SLIDER_WIDTH, { min = minimum, max = maximum, step = step, get = get, set = set }):SetPoint('RIGHT', -ui.ROW_INSET, 0)
end

local function Menu(ui, row, entries, get, set)
	local dropdown = ui.Dropdown(row, DROPDOWN_WIDTH, function()
		local current = get()
		local items = {}
		for _, entry in ipairs(entries) do
			items[#items + 1] = { text = entry.text, checked = entry.value == current, callback = function()
				set(entry.value)
				Repaint()
			end }
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ui.Bind(row, function() dropdown.label:SetText(Named(entries, get())) end)
end

local function FontMenu(ui, row, get, set)
	Menu(ui, row, BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), get, set)
end

local function ColorRow(ui, board, name, sub, hasOpacity, get, set)
	local row = board:AddRow(name, sub, SWATCH_ROOM)
	local swatch = ui.Swatch(row, SWATCH_SIZE, function(self)
		local red, green, blue, alpha = get()
		Controls.OpenColorPicker({
			r = red, g = green, b = blue, a = alpha, hasOpacity = hasOpacity, anchorTo = self,
			callback = function(newRed, newGreen, newBlue, newAlpha, cancelled)
				if cancelled then set(red, green, blue, alpha) else set(newRed, newGreen, newBlue, newAlpha) end
				Repaint()
			end,
		})
	end)
	swatch:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ui.Bind(row, function()
		local red, green, blue, alpha = get()
		swatch.fill:SetVertexColor(red, green, blue, hasOpacity and alpha or 1)
	end)
end

local function OrderArrows(ui, row, onMove)
	local down = ui.ArrowButton(row, false, function() onMove(1) end)
	down:SetPoint('RIGHT', -(ui.ROW_INSET + SWITCH_WIDTH + 12), 0)
	ui.ArrowButton(row, true, function() onMove(-1) end):SetPoint('RIGHT', down, 'LEFT', -ARROW_GAP, 0)
end

local function ConfirmModule(value)
	Modals.Confirm({
		parent = Window().frame,
		title = 'Reload required',
		message = value and 'Turning the minimap module on needs a UI reload.' or 'Turning the minimap module off needs a UI reload to put everything back.',
		confirmText = 'Reload now', cancelText = 'Cancel', laterText = 'Later',
		onConfirm = function()
			Interface().minimapEnabled = value
			ReloadUI()
		end,
		onLater = function()
			Interface().minimapEnabled = value
			Repaint()
		end,
		onCancel = Repaint,
	})
end

local function MapBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Map',
		description = 'The square minimap: where it sits, how big it is and the frame around it. Unlock it to drag the map and its indicators into place on screen.',
	})
	board:AddSwitch('Minimap module', function() return Interface().minimapEnabled ~= false end, ConfirmModule, 'Needs a reload to turn on or off')
	board:AddSwitch('Unlocked', MinimapModule.IsUnlocked, MinimapModule.ToggleUnlock, 'Drag the map and its indicators, right-click the map to lock')
	board:AddSwitch('Rotate with you', function() return Interface().rotateMinimap == true end, function(value)
		Interface().rotateMinimap = value
		MinimapModule.ToggleRotation(value)
	end)
	board:AddSwitch('Hide the BluUI button', BUI.IsMinimapButtonHidden, BUI.SetMinimapButtonHidden)
	Slider(ui, board:AddRow('Scale', 'Percent of the default size', SLIDER_WIDTH), 50, 200, 1,
		function() return Interface().minimapScale end,
		function(value) MinimapModule.SetScale(value) end)
	Slider(ui, board:AddRow('Border width', 'Pixels around the map', SLIDER_WIDTH), 0, 10, 1,
		function() return Interface().minimapBorderWidth end,
		function(value) MinimapModule.SetBorderWidth(value) end)
	Slider(ui, board:AddRow('From the right edge', 'Distance from the right of the screen', SLIDER_WIDTH), 0, floor(GetScreenWidth()), 1,
		function() return -(MinimapModule.GetPosition()) end,
		function(value) MinimapModule.SetPositionX(-value) end)
	Slider(ui, board:AddRow('From the top edge', 'Distance from the top of the screen', SLIDER_WIDTH), 0, floor(GetScreenHeight()), 1,
		function() local _, y = MinimapModule.GetPosition() return -y end,
		function(value) MinimapModule.SetPositionY(-value) end)
	return board
end

local function IndicatorsSection(ui, parent, width)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Indicators',
		description = 'The small buttons that live on the map. Unlock the map to drag them, and size them here.',
		columns = { { 'Indicator', ui.ROW_INSET }, { 'Shown', SHOWN_COLUMN }, { 'Size', width - ui.ROW_INSET - SLIDER_WIDTH } },
	})
	for _, def in ipairs(INDICATORS) do
		local row = section:AddRow(def.name .. ' ' .. def.sub)
		ui.RowTitle(row, def.name, def.sub, ui.ROW_INSET, NAME_WIDTH)
		if def.hide then
			ui.Switch(row, function() return not Interface()[def.hide] end, function(value)
				Interface()[def.hide] = not value
				MinimapModule.ApplyVisibility()
				if def.key == 'difficulty' then MinimapModule.ToggleTextDifficulty(value and Interface().minimapTextDifficulty == true) end
			end):SetPoint('LEFT', SHOWN_COLUMN, 0)
		else
			ui.Cell(row, 'Always', SHOWN_COLUMN)
		end
		Slider(ui, row, 40, 160, 5,
			function() return floor(MinimapModule.GetIconScale(def.key) * 100 + 0.5) end,
			function(value) MinimapModule.SetIconScale(def.key, value / 100) end)
	end
	local textRow = section:AddRow('difficulty as text')
	ui.RowTitle(textRow, 'Difficulty as text', 'Letters instead of the skull icon', ui.ROW_INSET, NAME_WIDTH)
	ui.Switch(textRow, function() return Interface().minimapTextDifficulty == true end, function(value)
		Interface().minimapTextDifficulty = value
		MinimapModule.ToggleTextDifficulty(value)
		MinimapModule.ApplyVisibility()
	end):SetPoint('LEFT', SHOWN_COLUMN, 0)
	return section
end

local function ClockBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Clock',
		description = 'The time in the corner of the map.',
	})
	board:AddSwitch('Clock', function() return Interface().minimapClock == true end, function(value)
		Interface().minimapClock = value
		MinimapModule.ToggleClock(value)
	end)
	board:AddSwitch('24-hour', function() return Interface().minimapClock24h == true end, function(value)
		Interface().minimapClock24h = value
		MinimapModule.SetClockFormat(value)
	end)
	board:AddSwitch('Server time', function() return Interface().minimapClockServer == true end, function(value)
		Interface().minimapClockServer = value
		MinimapModule.SetClockSource(value)
	end)
	Slider(ui, board:AddRow('Size', 'Font size', SLIDER_WIDTH), 8, 24, 1,
		function() return Interface().minimapClockSize end,
		function(value) Interface().minimapClockSize = value MinimapModule.RefreshClock() end)
	Slider(ui, board:AddRow('Horizontal offset', 'From its corner', SLIDER_WIDTH), -300, 300, 1,
		function() return Interface().minimapClockX end,
		function(value) Interface().minimapClockX = value MinimapModule.RefreshClock() end)
	Slider(ui, board:AddRow('Vertical offset', 'From its corner', SLIDER_WIDTH), -300, 300, 1,
		function() return Interface().minimapClockY end,
		function(value) Interface().minimapClockY = value MinimapModule.RefreshClock() end)
	FontMenu(ui, board:AddRow('Font', 'Global unless you pick one', DROPDOWN_WIDTH),
		function() return Interface().minimapClockFont or BUI.C.GLOBAL_OPTION end,
		function(value) Interface().minimapClockFont = value MinimapModule.RefreshClock() end)
	ColorRow(ui, board, 'Color', 'Text color', false,
		function() local color = Interface().minimapClockColor return color.r, color.g, color.b end,
		function(red, green, blue) Interface().minimapClockColor = { r = red, g = green, b = blue } MinimapModule.RefreshClock() end)
	return board
end

local function ZoneBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Zone name',
		description = 'The zone you are in, at the top of the map.',
	})
	board:AddSwitch('Zone name', function() return Interface().minimapZone == true end, function(value)
		Interface().minimapZone = value
		MinimapModule.ToggleZoneText(value)
	end)
	board:AddSwitch('Custom color', function() return Interface().minimapZoneColorCustom == true end, function(value)
		Interface().minimapZoneColorCustom = value
		MinimapModule.RefreshZoneText()
	end, 'Off colors the name by zone type')
	Slider(ui, board:AddRow('Size', 'Font size', SLIDER_WIDTH), 8, 24, 1,
		function() return Interface().minimapZoneSize end,
		function(value) Interface().minimapZoneSize = value MinimapModule.RefreshZoneText() end)
	Slider(ui, board:AddRow('Horizontal offset', 'From its corner', SLIDER_WIDTH), -300, 300, 1,
		function() return Interface().minimapZoneX end,
		function(value) Interface().minimapZoneX = value MinimapModule.RefreshZoneText() end)
	Slider(ui, board:AddRow('Vertical offset', 'From its corner', SLIDER_WIDTH), -300, 300, 1,
		function() return Interface().minimapZoneY end,
		function(value) Interface().minimapZoneY = value MinimapModule.RefreshZoneText() end)
	FontMenu(ui, board:AddRow('Font', 'Global unless you pick one', DROPDOWN_WIDTH),
		function() return Interface().minimapZoneFont or BUI.C.GLOBAL_OPTION end,
		function(value) Interface().minimapZoneFont = value MinimapModule.RefreshZoneText() end)
	ColorRow(ui, board, 'Color', 'Used when custom color is on', false,
		function() local color = Interface().minimapZoneColor return color.r, color.g, color.b end,
		function(red, green, blue)
			Interface().minimapZoneColorCustom = true
			Interface().minimapZoneColor = { r = red, g = green, b = blue }
			MinimapModule.RefreshZoneText()
		end)
	return board
end

local function DatatextBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Datatext bar',
		description = 'A strip of readouts attached to the map.',
	})
	board:AddSwitch('Datatext bar', function() return Bar().enabled ~= false end, function(value)
		Bar().enabled = value
		Datatext.Apply()
	end)
	board:AddSwitch('Hide labels', function() return Bar().hideLabels == true end, function(value)
		Bar().hideLabels = value
		Datatext.Apply()
	end)
	board:AddSwitch('Border', function() return Bar().border == true end, function(value)
		Bar().border = value
		Datatext.Apply()
	end)
	Menu(ui, board:AddRow('Anchor', 'Which side of the map it hangs on', DROPDOWN_WIDTH), ANCHORS,
		function() return Bar().anchor end,
		function(value) Bar().anchor = value Datatext.Apply() end)
	Slider(ui, board:AddRow('Gap from the map', nil, SLIDER_WIDTH), 0, 40, 1,
		function() return Bar().gap end,
		function(value) Bar().gap = value Datatext.Apply() end)
	Slider(ui, board:AddRow('Height', nil, SLIDER_WIDTH), 10, 40, 1,
		function() return Bar().height end,
		function(value) Bar().height = value Datatext.Apply() end)
	Slider(ui, board:AddRow('Spacing', 'Pixels between readouts', SLIDER_WIDTH), 0, 40, 1,
		function() return Bar().spacing end,
		function(value)
			local config = Bar()
			config.spacing, config.spacingPx = value, true
			Datatext.Apply()
		end)
	Slider(ui, board:AddRow('Spread', 'Pushes the readouts apart to fill the bar', SLIDER_WIDTH), 0, 100, 1,
		function() return tonumber(Bar().spread) or 0 end,
		function(value) Bar().spread = value Datatext.Apply() end)
	Slider(ui, board:AddRow('Background opacity', nil, SLIDER_WIDTH), 0, 100, 1,
		function() return floor(Bar().bgAlpha * 100 + 0.5) end,
		function(value) Bar().bgAlpha = value / 100 Datatext.Apply() end)
	Slider(ui, board:AddRow('Font size', nil, SLIDER_WIDTH), 8, 24, 1,
		function() return Bar().fontSize end,
		function(value) Bar().fontSize = value Datatext.Apply() end)
	FontMenu(ui, board:AddRow('Font', 'Global unless you pick one', DROPDOWN_WIDTH),
		function() return Bar().font end,
		function(value) Bar().font = value Datatext.Apply() end)
	ColorRow(ui, board, 'Background color', nil, false,
		function() local color = Bar().bgColor return color.r, color.g, color.b end,
		function(red, green, blue) Bar().bgColor = { r = red, g = green, b = blue } Datatext.Apply() end)
	ColorRow(ui, board, 'Border color', nil, true,
		function() local color = Bar().borderColor return color.r, color.g, color.b, color.a end,
		function(red, green, blue, alpha) Bar().borderColor = { r = red, g = green, b = blue, a = alpha } Datatext.Apply() end)
	ColorRow(ui, board, 'Value color', 'The numbers next to each label', true,
		function() local color = Bar().colorValue return color.r, color.g, color.b, color.a end,
		function(red, green, blue, alpha) Bar().colorValue = { r = red, g = green, b = blue, a = alpha } Datatext.Apply() end)
	return board
end

local function ReadoutsBoard(ui, parent, width, page)
	local config = Bar()
	local order = Datatext.ResolveOrder(config)
	local rows = {}
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Readouts',
		description = 'What the bar shows, top to bottom here is left to right on the bar.',
		buttons = {
			{ text = 'Default order', icon = 'reset', onClick = function()
				config.order = nil
				Datatext.Apply()
				page:Rebuild('datatext')
			end },
		},
	})
	local function Move(id, delta)
		local index
		for position, candidate in ipairs(order) do
			if candidate == id then index = position end
		end
		if not order[index + delta] then return end
		order[index], order[index + delta] = order[index + delta], order[index]
		board:Move(rows[id], delta)
		config.order = order
		Datatext.Apply()
		page:Resize()
	end
	for _, id in ipairs(order) do
		local entry = Datatext.Get(id)
		local row = board:AddRow(entry.name, nil, ORDER_ROOM)
		rows[id] = row
		ui.Switch(row, function() return config[entry.show] == true end, function(value)
			config[entry.show] = value
			Datatext.Apply()
		end):SetPoint('RIGHT', -ui.ROW_INSET, 0)
		OrderArrows(ui, row, function(delta) Move(id, delta) end)
	end
	return board
end

local function DrawerBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Addon drawer',
		description = 'Collects addon minimap buttons behind a tab on the edge of the map.',
	})
	board:AddSwitch('Drawer', function() return Interface().drawerEnabled == true end, MinimapModule.ToggleDrawer)
	Menu(ui, board:AddRow('Side', 'Which edge the tab sits on', DROPDOWN_WIDTH), SIDES,
		function() return Interface().drawerSide end,
		function(value)
			Interface().drawerSide = value
			MinimapModule.SetDrawerSide(value)
		end)
	Slider(ui, board:AddRow('Horizontal offset', 'Nudge along the edge', SLIDER_WIDTH), -300, 300, 1,
		function() return Interface().drawerX end,
		function(value) Interface().drawerX = value MinimapModule.RepositionDrawer() end)
	Slider(ui, board:AddRow('Vertical offset', 'Nudge along the edge', SLIDER_WIDTH), -300, 300, 1,
		function() return Interface().drawerY end,
		function(value) Interface().drawerY = value MinimapModule.RepositionDrawer() end)
	return board
end

local function ButtonBarBoard(ui, parent, width)
	local function Refresh()
		MinimapModule.RefreshButtonBar()
	end
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Button bar',
		description = 'Addon buttons in a tidy row beside the map instead of scattered around it.',
	})
	board:AddSwitch('Button bar', function() return Buttons().enabled == true end, function(value)
		Buttons().enabled = value
		Refresh()
	end)
	Menu(ui, board:AddRow('Side', 'Which edge of the map', DROPDOWN_WIDTH), SIDES,
		function() return Buttons().side end,
		function(value) Buttons().side = value Refresh() end)
	Menu(ui, board:AddRow('Align', 'Along that edge', DROPDOWN_WIDTH), ALIGNS,
		function() return Buttons().align end,
		function(value) Buttons().align = value Refresh() end)
	Slider(ui, board:AddRow('Icon size', nil, SLIDER_WIDTH), 12, 40, 1,
		function() return Buttons().size end,
		function(value) Buttons().size = value Refresh() end)
	Slider(ui, board:AddRow('Spacing', 'Between icons', SLIDER_WIDTH), -1, 10, 1,
		function() return Buttons().spacing end,
		function(value) Buttons().spacing = value Refresh() end)
	Slider(ui, board:AddRow('Gap from the map', nil, SLIDER_WIDTH), 0, 10, 1,
		function() return Buttons().gap end,
		function(value) Buttons().gap = value Refresh() end)
	Slider(ui, board:AddRow('Per line', '0 keeps them on one line', SLIDER_WIDTH), 0, 20, 1,
		function() return Buttons().perLine end,
		function(value) Buttons().perLine = value Refresh() end)
	Slider(ui, board:AddRow('Horizontal offset', nil, SLIDER_WIDTH), -300, 300, 1,
		function() return Buttons().offsetX end,
		function(value) Buttons().offsetX = value Refresh() end)
	Slider(ui, board:AddRow('Vertical offset', nil, SLIDER_WIDTH), -300, 300, 1,
		function() return Buttons().offsetY end,
		function(value) Buttons().offsetY = value Refresh() end)
	ColorRow(ui, board, 'Tile background', 'Behind every icon', true,
		function() local color = Buttons().background return color[1], color[2], color[3], color[4] end,
		function(red, green, blue, alpha)
			Buttons().background = { red, green, blue, alpha }
			Refresh()
		end)
	return board
end

local function ButtonsBoard(ui, parent, width, page)
	local entries = ButtonBar.PickerEntries()
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Buttons',
		description = 'Which addon buttons sit on the bar, top to bottom here is first to last on the bar.',
	})
	if #entries == 0 then
		board:AddRow('No addon buttons yet', Buttons().enabled and 'They appear here as addons add buttons to the minimap' or 'Turn the button bar on to collect them')
		return board
	end
	local rows = {}
	local function Move(entry, delta)
		local index
		for position, candidate in ipairs(entries) do
			if candidate == entry then index = position end
		end
		if not entries[index + delta] then return end
		entries[index], entries[index + delta] = entries[index + delta], entries[index]
		board:Move(rows[entry.id], delta)
		local names = {}
		for position, candidate in ipairs(entries) do names[position] = candidate.id end
		ButtonBar.SetOrder(names)
		page:Resize()
	end
	for _, entry in ipairs(entries) do
		local row = board:AddRow(entry.label, nil, ORDER_ROOM)
		rows[entry.id] = row
		ui.Switch(row, function() return entry.included == true end, function(value)
			entry.included = value
			ButtonBar.SetIncluded(entry.id, value)
		end):SetPoint('RIGHT', -ui.ROW_INSET, 0)
		OrderArrows(ui, row, function(delta) Move(entry, delta) end)
	end
	return board
end

local function Panes(ui, _, parent, width, item, page)
	if item.id == 'map' then return { MapBoard(ui, parent, width) } end
	if item.id == 'indicators' then return { IndicatorsSection(ui, parent, width) } end
	if item.id == 'text' then return { ClockBoard(ui, parent, width), ZoneBoard(ui, parent, width) } end
	if item.id == 'datatext' then return { DatatextBoard(ui, parent, width), ReadoutsBoard(ui, parent, width, page) } end
	return { DrawerBoard(ui, parent, width), ButtonBarBoard(ui, parent, width), ButtonsBoard(ui, parent, width, page) }
end

BUI.PageEngine.RegisterPage('minimap', {
	title = 'Minimap',
	buttonText = 'Minimap',
	icon = 'minimap',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local adapter = { tabContents = {}, currentTab = 1 }
		for index in ipairs(PANE_IDS) do adapter.tabContents[index] = {} end
		local rail
		rail = Layout.RailPage(page:GetTab(1), { window = Window() }, {
			icon = 'minimap',
			title = 'Minimap',
			placeholder = 'Search minimap settings...',
			rail = { groups = RAIL_GROUPS },
			build = Panes,
		})
		local Select = rail.Select
		function rail:Select(id)
			Select(self, id)
			adapter.currentTab = PANE_INDEX[id]
		end
		function adapter:SetTab(index)
			rail:Select(PANE_IDS[index])
		end
		pageFrame._page = adapter
		MinimapModule.SetLockReleaseCallback(Repaint)
		page:AutoRefresh()
	end,
})
