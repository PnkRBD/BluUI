local BUI = BluUI
local BUILib = BUI.BUILibClient
local Controls, Layout, Modals = BUILib.Controls, BUILib.Layout, BUILib.Modals
local Datatext = BUI.Datatext
local Pixel = BUI.Pixel

local PAGE_WIDTH = 960
local TABLE_HEAD = 36
local ROW_HEIGHT = 58
local FOOTER_HEIGHT = 54
local ROW_INSET = 20
local NAME_WIDTH = 150
local SAMPLE_X = 190
local PLACE_X = 600
local PLACE_WIDTH = 150
local SHOWN_X = 780
local DELETE_INSET = 18
local MARKER_WIDTH = 2
local SAMPLE_WIDTH = PLACE_X - SAMPLE_X - 20
local PANEL_SAMPLE = 24
local PANEL_SAMPLE_MAX = 120
local BUTTON_GAP = 10
local SLIDER_WIDTH = 220
local DROPDOWN_WIDTH = 200
local INPUT_WIDTH = 220
local SWATCH_SIZE = 28
local SWATCH_ROOM = 60
local SWITCH_WIDTH = 40
local ARROW = 22
local ARROW_GAP = 4
local ORDER_ROOM = SWITCH_WIDTH + 12 + ARROW * 2 + ARROW_GAP

local COLUMNS = { { 'Name', ROW_INSET }, { 'Sample', SAMPLE_X }, { 'Place', PLACE_X }, { 'Shown', SHOWN_X } }

local ORIENTATIONS = {
	{ value = 'HORIZONTAL', text = 'Horizontal' },
	{ value = 'VERTICAL', text = 'Vertical' },
}

local ALIGNMENTS = {
	{ value = 'LEFT', text = 'Left' },
	{ value = 'CENTER', text = 'Center' },
	{ value = 'RIGHT', text = 'Right' },
	{ value = 'SPREAD', text = 'Spread evenly' },
}

local selected
local rows = {}

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function Bars()
	return Datatext.GetBars()
end

local function Current()
	local list = Bars()
	if not (selected and list[selected]) then selected = list[1] and 1 or nil end
	return selected and list[selected]
end

local function RefreshTable()
	for _, row in ipairs(rows) do row:Update() end
end

local function Apply()
	Datatext.Apply()
	RefreshTable()
end

local function RebuildPage()
	BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
end

local function Select(index)
	if selected == index then return end
	selected = index
	RebuildPage()
end

local function Create(kind)
	selected = Datatext.AddBar(kind)
	RebuildPage()
end

local function ConfirmDelete(index)
	local config = Bars()[index]
	Modals.Confirm({
		parent = Window().frame,
		title = 'Delete ' .. config.name,
		message = 'Delete "' .. config.name .. '"? This cannot be undone.',
		confirmText = 'Delete', cancelText = 'Cancel',
		onConfirm = function()
			Datatext.DeleteBar(index)
			selected = nil
			RebuildPage()
		end,
	})
end

local function Named(entries, value)
	for _, entry in ipairs(entries) do
		if entry.value == value then return entry.text end
	end
	return value
end

local function PlaceText(config)
	if config.alignMinimap then return 'Below the minimap' end
	if config.mirrorChat and Datatext.IsPanel(config) then return 'Mirrors the chat' end
	return Named(BUI.C.ANCHOR_POINT_OPTIONS_SHORT, config.point)
end

local function Switch(board, label, get, set, tip)
	board:AddSwitch(label, get, function(value)
		set(value)
		Apply()
	end, tip)
end

local function Slider(ui, row, minimum, maximum, step, get, set)
	ui.Slider(row, SLIDER_WIDTH, { min = minimum, max = maximum, step = step, get = get, set = function(value)
		set(value)
		Apply()
	end }):SetPoint('RIGHT', -ui.ROW_INSET, 0)
end

local function Menu(ui, row, entries, get, set)
	local dropdown = ui.Dropdown(row, DROPDOWN_WIDTH, function()
		local current = get()
		local menu = {}
		for _, entry in ipairs(entries) do
			menu[#menu + 1] = { text = entry.text, checked = entry.value == current, callback = function()
				set(entry.value)
				Apply()
				Repaint()
			end }
		end
		return menu
	end)
	dropdown:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ui.Bind(row, function() dropdown.label:SetText(Named(entries, get())) end)
end

local function ColorRow(ui, board, name, sub, hasOpacity, get, set)
	local row = board:AddRow(name, sub, SWATCH_ROOM)
	local swatch = ui.Swatch(row, SWATCH_SIZE, function(self)
		local red, green, blue, alpha = get()
		Controls.OpenColorPicker({
			r = red, g = green, b = blue, a = alpha, hasOpacity = hasOpacity, anchorTo = self,
			callback = function(newRed, newGreen, newBlue, newAlpha, cancelled)
				if cancelled then set(red, green, blue, alpha) else set(newRed, newGreen, newBlue, newAlpha) end
				Apply()
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

local function ColorField(config, key, hasOpacity)
	return function()
		local color = config[key]
		return color.r, color.g, color.b, hasOpacity and color.a or 1
	end, function(red, green, blue, alpha)
		config[key] = hasOpacity and { r = red, g = green, b = blue, a = alpha } or { r = red, g = green, b = blue }
	end
end

local function Field(config, key)
	return function() return config[key] end, function(value) config[key] = value end
end

local function OrderArrows(ui, row, onMove)
	local down = ui.ArrowButton(row, false, function() onMove(1) end)
	down:SetPoint('RIGHT', -(ui.ROW_INSET + SWITCH_WIDTH + 12), 0)
	ui.ArrowButton(row, true, function() onMove(-1) end):SetPoint('RIGHT', down, 'LEFT', -ARROW_GAP, 0)
end

local function BarSample(kit, cell, config)
	local layout = { textLeft = {}, textWidth = {}, hitLeft = {}, hitWidth = {}, lineTop = {} }
	local edge = cell:CreateTexture(nil, 'BACKGROUND', nil, 0)
	local fill = cell:CreateTexture(nil, 'BACKGROUND', nil, 1)
	local parts = {}
	local note = kit.Text(cell, 'No datatexts turned on', 11, 'faint')
	note:SetPoint('LEFT')
	return function()
		local texts = Datatext.BuildSampleParts(config)
		local count = #texts
		for _, part in ipairs(parts) do part:Hide() end
		fill:Hide()
		edge:Hide()
		note:SetShown(count == 0)
		if count == 0 then return end
		local fontPath = BUI.GetModuleFont(config)
		local widths = {}
		for partIndex = 1, count do
			local part = parts[partIndex]
			if not part then
				part = cell:CreateFontString(nil, 'OVERLAY')
				part:SetWordWrap(false)
				parts[partIndex] = part
			end
			Pixel.ApplyFont(part, config.fontSize, fontPath, '')
			part:SetText(texts[partIndex])
			widths[partIndex] = part:GetStringWidth()
		end
		local fixedWidth = config.width > 0 and math.min(Pixel.Scale(config.width), SAMPLE_WIDTH) or nil
		local barWidth = Datatext.LayoutRow(widths, count, Pixel.Scale(config.spacing), Pixel.Scale(Datatext.LAYOUT.rowInset), fixedWidth, config.align, 0, layout)
		local barHeight = Pixel.Scale(config.fontSize + Datatext.LAYOUT.lineExtra)
		for partIndex = 1, count do
			local part = parts[partIndex]
			part:ClearAllPoints()
			part:SetPoint('LEFT', cell, 'LEFT', layout.textLeft[partIndex] + 1, 0)
			part:SetWidth(layout.textWidth[partIndex])
			part:SetHeight(0)
			part:SetJustifyH('CENTER')
			part:Show()
		end
		fill:ClearAllPoints()
		fill:SetPoint('LEFT', 1, 0)
		fill:SetSize(barWidth, barHeight)
		fill:SetColorTexture(config.bgColor.r, config.bgColor.g, config.bgColor.b, config.bgAlpha)
		fill:Show()
		if config.border then
			edge:ClearAllPoints()
			edge:SetPoint('CENTER', fill)
			edge:SetSize(barWidth + 2, barHeight + 2)
			edge:SetColorTexture(config.borderColor.r, config.borderColor.g, config.borderColor.b, config.borderColor.a)
			edge:Show()
		end
	end
end

local function PanelSample(kit, cell, config)
	local edge = cell:CreateTexture(nil, 'BACKGROUND', nil, 0)
	local fill = cell:CreateTexture(nil, 'BACKGROUND', nil, 1)
	local caption = kit.Text(cell, '', 11, 'muted')
	caption:SetPoint('LEFT', fill, 'RIGHT', 10, 0)
	caption:SetWordWrap(false)
	return function()
		local width = config.width > 0 and config.width or 200
		local height = config.height > 0 and config.height or 100
		local sampleWidth = math.max(PANEL_SAMPLE, math.min(PANEL_SAMPLE_MAX, math.floor(width * PANEL_SAMPLE / height + 0.5)))
		fill:ClearAllPoints()
		fill:SetPoint('LEFT', 1, 0)
		fill:SetSize(sampleWidth, PANEL_SAMPLE)
		fill:SetColorTexture(config.bgColor.r, config.bgColor.g, config.bgColor.b, math.max(config.bgAlpha, 0.15))
		edge:ClearAllPoints()
		edge:SetPoint('CENTER', fill)
		edge:SetSize(sampleWidth + 2, PANEL_SAMPLE + 2)
		edge:SetColorTexture(config.borderColor.r, config.borderColor.g, config.borderColor.b, config.borderColor.a)
		edge:SetShown(config.border)
		caption:SetText(width .. ' x ' .. height .. (config.title ~= '' and ('   ' .. config.title) or ''))
	end
end

local function TableRow(kit, band, config, index)
	local row = CreateFrame('Button', nil, band)
	row:SetHeight(ROW_HEIGHT)
	kit.Hover(row)
	local rule = kit.Fill(row, 'rule', 'ARTWORK')
	rule:SetPoint('TOPLEFT', ROW_INSET, 0)
	rule:SetPoint('TOPRIGHT', -ROW_INSET, 0)
	rule:SetHeight(1)
	rule:SetShown(index > 1)
	local marker = kit.Fill(row, 'accent', 'ARTWORK', 1)
	marker:SetPoint('TOPLEFT')
	marker:SetPoint('BOTTOMLEFT')
	marker:SetWidth(MARKER_WIDTH)
	local isPanel = Datatext.IsPanel(config)
	kit.RowTitle(row, config.name, isPanel and 'Panel' or 'Bar', ROW_INSET, NAME_WIDTH)
	local cell = CreateFrame('Frame', nil, row)
	cell:SetPoint('LEFT', SAMPLE_X, 0)
	cell:SetSize(SAMPLE_WIDTH, ROW_HEIGHT)
	cell:SetClipsChildren(true)
	local UpdateSample = isPanel and PanelSample(kit, cell, config) or BarSample(kit, cell, config)
	local place = kit.Cell(row, '', PLACE_X, PLACE_WIDTH)
	kit.Switch(row, function() return config.enabled == true end, function(value)
		config.enabled = value
		Datatext.Apply()
	end):SetPoint('LEFT', SHOWN_X, 0)
	kit.IconButton(row, 'delete', 'Delete ' .. config.name, function() ConfirmDelete(index) end, 'danger'):SetPoint('RIGHT', -DELETE_INSET, 0)
	row:SetScript('OnClick', function() Select(index) end)
	function row:Update()
		marker:SetShown(selected == index)
		place:SetText(PlaceText(config))
		UpdateSample()
	end
	row:Update()
	return row
end

local function TableHeight()
	return TABLE_HEAD + math.max(1, #Bars()) * ROW_HEIGHT + FOOTER_HEIGHT
end

local function BuildTable(band, kit)
	rows = {}
	for _, column in ipairs(COLUMNS) do
		kit.Text(band, column[1]:upper(), 9, 'faint'):SetPoint('TOPLEFT', column[2], -20)
	end
	local y = TABLE_HEAD
	local list = Bars()
	if #list == 0 then
		local empty = CreateFrame('Frame', nil, band)
		empty:SetPoint('TOPLEFT', 0, -y)
		empty:SetPoint('TOPRIGHT', 0, -y)
		empty:SetHeight(ROW_HEIGHT)
		kit.Text(empty, 'Nothing here yet, add a bar or a panel below', 12, 'muted'):SetPoint('LEFT', ROW_INSET, 0)
		y = y + ROW_HEIGHT
	end
	for index, config in ipairs(list) do
		local row = TableRow(kit, band, config, index)
		row:SetPoint('TOPLEFT', 0, -y)
		row:SetPoint('TOPRIGHT', 0, -y)
		rows[index] = row
		y = y + ROW_HEIGHT
	end
	local footer = CreateFrame('Frame', nil, band)
	footer:SetPoint('TOPLEFT', 0, -y)
	footer:SetPoint('TOPRIGHT', 0, -y)
	footer:SetHeight(FOOTER_HEIGHT)
	local rule = kit.Fill(footer, 'rule', 'ARTWORK')
	rule:SetPoint('TOPLEFT', ROW_INSET, 0)
	rule:SetPoint('TOPRIGHT', -ROW_INSET, 0)
	rule:SetHeight(1)
	local newBar = kit.Button(footer, 'New bar', 'secondary', function() Create('TEXT') end, 'add')
	newBar:SetPoint('LEFT', ROW_INSET, 0)
	kit.Button(footer, 'New panel', 'secondary', function() Create('PANEL') end, 'add'):SetPoint('LEFT', newBar, 'RIGHT', BUTTON_GAP, 0)
end

local function ReadoutsBoard(ui, parent, width, config, page)
	local order = Datatext.ResolveOrder(config)
	local readoutRows = {}
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Datatexts',
		description = 'What the bar shows, top to bottom here is left to right on the bar.',
		buttons = {
			{ text = 'Default order', icon = 'reset', onClick = function()
				config.order = nil
				Apply()
				RebuildPage()
			end },
		},
	})
	local function Move(id, delta)
		local position
		for candidateIndex, candidate in ipairs(order) do
			if candidate == id then position = candidateIndex end
		end
		if not order[position + delta] then return end
		order[position], order[position + delta] = order[position + delta], order[position]
		board:Move(readoutRows[id], delta)
		config.order = order
		Apply()
		page:Resize()
	end
	for _, id in ipairs(order) do
		local entry = Datatext.Get(id)
		local row = board:AddRow(entry.name, nil, ORDER_ROOM)
		readoutRows[id] = row
		ui.Switch(row, function() return config[entry.show] == true end, function(value)
			config[entry.show] = value
			Apply()
		end):SetPoint('RIGHT', -ui.ROW_INSET, 0)
		OrderArrows(ui, row, function(delta) Move(id, delta) end)
	end
	return board
end

local function ReadoutSettingsBoard(ui, parent, width, config)
	local board
	local function GetConfig() return config end
	for _, entry in ipairs(Datatext.List()) do
		if entry.options then
			board = board or ui.Board(parent, width, {
				stacked = true,
				title = 'Datatext settings',
				description = 'Extra choices some datatexts offer.',
			})
			board:AddCaption(entry.name)
			for _, option in ipairs(entry.options(GetConfig, Apply)) do
				if option.kind == 'dropdown' then
					Menu(ui, board:AddRow(option.label, nil, DROPDOWN_WIDTH), option.items, option.get, option.set)
				else
					Switch(board, option.label, function() return option.get() == true end, option.set)
				end
			end
		end
	end
	return board
end

local function StyleBoard(ui, parent, width, config)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Text',
		description = 'Font, size and how the datatexts line up.',
	})
	Switch(board, 'Hide labels', function() return config.hideLabels == true end, function(value)
		config.hideLabels = value
	end, 'Values only, no names in front of them')
	Menu(ui, board:AddRow('Font', 'Global unless you pick one', DROPDOWN_WIDTH), BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), Field(config, 'font'))
	Slider(ui, board:AddRow('Font size', nil, SLIDER_WIDTH), 8, 24, 1, Field(config, 'fontSize'))
	Slider(ui, board:AddRow('Spacing', 'Pixels between datatexts', SLIDER_WIDTH), 0, 160, 1, Field(config, 'spacing'))
	Menu(ui, board:AddRow('Orientation', 'A row or a stack', DROPDOWN_WIDTH), ORIENTATIONS, Field(config, 'orientation'))
	Menu(ui, board:AddRow('Align', 'Where the datatexts sit in a fixed width', DROPDOWN_WIDTH), ALIGNMENTS, Field(config, 'align'))
	ColorRow(ui, board, 'Value color', 'The numbers next to each label', true, ColorField(config, 'colorValue', true))
	return board
end

local function TitleBoard(ui, parent, width, config)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Title',
		description = 'Optional text on the panel.',
	})
	ui.Input(board:AddRow('Text', 'Empty for no title', INPUT_WIDTH), INPUT_WIDTH, {
		placeholder = 'No title',
		get = function() return config.title end,
		set = function(text)
			config.title = text
			Apply()
		end,
	}):SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ColorRow(ui, board, 'Color', nil, false, ColorField(config, 'titleColor', false))
	Menu(ui, board:AddRow('Anchor', 'Which edge of the panel it hugs', DROPDOWN_WIDTH), BUI.C.ANCHOR_POINT_OPTIONS_SHORT, Field(config, 'titleAnchor'))
	Slider(ui, board:AddRow('Size', 'Font size', SLIDER_WIDTH), 8, 32, 1, Field(config, 'titleSize'))
	Slider(ui, board:AddRow('Horizontal offset', 'From its anchor', SLIDER_WIDTH), -300, 300, 1, Field(config, 'titleX'))
	Slider(ui, board:AddRow('Vertical offset', 'From its anchor', SLIDER_WIDTH), -300, 300, 1, Field(config, 'titleY'))
	return board
end

local function PositionBoard(ui, parent, width, config)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Position',
		description = 'Where it sits on the screen and how it layers with other frames. Unlock it with the eye in the header to drag it, right-click it to lock it again.',
	})
	Switch(board, 'Align below the minimap', function() return config.alignMinimap == true end, function(value)
		config.alignMinimap = value
	end, 'Hang it under the minimap instead of using the anchor and offsets')
	if Datatext.IsPanel(config) then
		Switch(board, 'Mirror the chat window', function() return config.mirrorChat == true end, function(value)
			config.mirrorChat = value
		end, 'Keep this panel sized and placed as a mirror image of the chat window')
	end
	Menu(ui, board:AddRow('Anchor', 'The screen corner or edge it measures from', DROPDOWN_WIDTH), BUI.C.ANCHOR_POINT_OPTIONS_SHORT,
		function() return config.point end,
		function(value)
			config.point, config.relPoint = value, value
			config.alignMinimap = false
		end)
	Slider(ui, board:AddRow('Horizontal offset', 'From the anchor', SLIDER_WIDTH), -1500, 1500, 1, Field(config, 'x'))
	Slider(ui, board:AddRow('Vertical offset', 'From the anchor', SLIDER_WIDTH), -1500, 1500, 1, Field(config, 'y'))
	Menu(ui, board:AddRow('Strata', 'Which layer of the screen it draws on', DROPDOWN_WIDTH), BUI.C.STRATA_OPTIONS, Field(config, 'strata'))
	Slider(ui, board:AddRow('Frame level', 'Higher draws over neighbours on the same strata', SLIDER_WIDTH), 0, 100, 1, Field(config, 'frameLevel'))
	return board
end

local function BackgroundBoard(ui, parent, width, config)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Background',
		description = 'The backdrop behind it. Zero width or height fits the content.',
	})
	Switch(board, 'Border', function() return config.border == true end, function(value)
		config.border = value
	end, 'A one pixel line around the edge')
	Slider(ui, board:AddRow('Opacity', 'Percent', SLIDER_WIDTH), 0, 100, 1,
		function() return math.floor(config.bgAlpha * 100 + 0.5) end,
		function(value) config.bgAlpha = value / 100 end)
	ColorRow(ui, board, 'Background color', nil, false, ColorField(config, 'bgColor', false))
	ColorRow(ui, board, 'Border color', nil, true, ColorField(config, 'borderColor', true))
	Slider(ui, board:AddRow('Width', '0 fits the content', SLIDER_WIDTH), 0, 1200, 1, Field(config, 'width'))
	Slider(ui, board:AddRow('Height', '0 fits the content', SLIDER_WIDTH), 0, 600, 1, Field(config, 'height'))
	return board
end

local function TooltipsBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Tooltips',
		description = 'Shared by every bar.',
	})
	Switch(board, 'Hide tooltips in combat', function() return BUI.GetDB().datatextHideHoversInCombat ~= false end, function(value)
		BUI.GetDB().datatextHideHoversInCombat = value
	end, 'No datatext tooltips or hover panels while fighting')
	Switch(board, 'Roster tooltips', function() return BUI.GetDB().datatextRosterTooltips ~= false end, function(value)
		BUI.GetDB().datatextRosterTooltips = value
	end, 'Member details such as keystone and score when hovering Friends and Guild rows')
	return board
end

local function Tab(label, build)
	return { label = label, build = function(ui, _, parent, width, page) return build(ui, parent, width, page) end }
end

local function Tabs(config)
	local tabs = {}
	if config and not Datatext.IsPanel(config) then
		tabs[#tabs + 1] = Tab('Datatexts', function(ui, parent, width, page)
			local sections = { ReadoutsBoard(ui, parent, width, config, page) }
			local settings = ReadoutSettingsBoard(ui, parent, width, config)
			if settings then sections[#sections + 1] = settings end
			return sections
		end)
		tabs[#tabs + 1] = Tab('Style', function(ui, parent, width) return { StyleBoard(ui, parent, width, config) } end)
	elseif config then
		tabs[#tabs + 1] = Tab('Title', function(ui, parent, width) return { TitleBoard(ui, parent, width, config) } end)
	end
	if config then
		tabs[#tabs + 1] = Tab('Position', function(ui, parent, width) return { PositionBoard(ui, parent, width, config) } end)
		tabs[#tabs + 1] = Tab('Background', function(ui, parent, width) return { BackgroundBoard(ui, parent, width, config) } end)
	end
	tabs[#tabs + 1] = Tab('Tooltips', function(ui, parent, width) return { TooltipsBoard(ui, parent, width) } end)
	return tabs
end

BUI.PageEngine.RegisterPage('datatext', {
	title = 'Datatext',
	buttonText = 'Datatext',
	icon = 'report2',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local config = Current()
		pageFrame._page = Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'report2',
			title = 'Datatext',
			placeholder = 'Search datatext settings...',
			toggles = {
				{ icon = 'enable', tooltip = 'Turn the datatext module on or off', get = Datatext.ModuleEnabled, set = function(value)
					BUI.GetDB().datatextEnabled = value
					Apply()
				end },
				{ icon = 'eye', tooltip = 'Unlock the selected bar or panel to drag it, right-click it to lock', get = function()
					local current = Current()
					return current and not current.lock or false
				end, set = function(value)
					local current = Current()
					if not current then return end
					current.lock = not value
					Datatext.Apply()
				end },
			},
			preview = { height = TableHeight(), build = BuildTable },
			tabs = Tabs(config),
		})
		Datatext.SetLockCallback(Repaint)
		page:AutoRefresh()
	end,
})
