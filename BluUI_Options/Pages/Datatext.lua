local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout, Modals = BUILib.Layout, BUILib.Modals
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
local MENU_WIDTH = 160
local INPUT_WIDTH = 220
local SWITCH_WIDTH = 40
local ARROW = 22
local ARROW_GAP = 4
local TOOL_GAP = 12
local ORDER_ROOM = SWITCH_WIDTH + 12 + ARROW * 2 + ARROW_GAP
local COG_ROOM = ARROW + TOOL_GAP

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
local fonts

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

local function Option(config, label, key, extra)
	local option = { label = label, get = function() return config[key] end, set = function(value) config[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Swatch(config, label, key, opacity)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = opacity,
		get = function()
			local color = config[key]
			return color.r, color.g, color.b, opacity and color.a or 1
		end,
		set = function(red, green, blue, alpha)
			config[key] = opacity and { r = red, g = green, b = blue, a = alpha } or { r = red, g = green, b = blue }
		end,
	}
end

local function Font(config)
	return { entries = fonts, width = MENU_WIDTH, get = function() return config.font end, set = function(value) config.font = value end }
end

local function PositionTool(config)
	local options = {
		{ label = 'Anchor', entries = BUI.C.ANCHOR_POINT_OPTIONS_SHORT, get = function() return config.point end, set = function(value)
			config.point, config.relPoint = value, value
			config.alignMinimap = false
		end },
		Option(config, 'Horizontal offset', 'x', { min = -1500, max = 1500, step = 1 }),
		Option(config, 'Vertical offset', 'y', { min = -1500, max = 1500, step = 1 }),
		Option(config, 'Align below the minimap', 'alignMinimap'),
		Option(config, 'Strata', 'strata', { entries = BUI.C.STRATA_OPTIONS }),
		Option(config, 'Frame level', 'frameLevel', { min = 0, max = 100, step = 1 }),
	}
	if Datatext.IsPanel(config) then table.insert(options, 5, Option(config, 'Mirror the chat window', 'mirrorChat')) end
	return { icon = 'mover', tooltip = 'Position and layering', title = 'Position', options = options }
end

local function BackgroundTools(config)
	return {
		Swatch(config, 'Background color', 'bgColor', false),
		{ tooltip = 'Opacity and border', title = 'Background', options = {
			{ label = 'Opacity', min = 0, max = 100, step = 1, get = function() return math.floor(config.bgAlpha * 100 + 0.5) end, set = function(value) config.bgAlpha = value / 100 end },
			Option(config, 'Border', 'border'),
			Swatch(config, 'Border color', 'borderColor', true),
		} },
	}
end

local function SizeOptions(config)
	return {
		Option(config, 'Width', 'width', { min = 0, max = 1200, step = 1 }),
		Option(config, 'Height', 'height', { min = 0, max = 600, step = 1 }),
	}
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
	local ruler = cell:CreateFontString(nil, 'ARTWORK')
	ruler:SetAlpha(0)
	ruler:SetPoint('LEFT')
	local note = kit.Text(cell, 'No datatexts turned on', 11, 'faint')
	note:SetPoint('LEFT')
	return function()
		local texts = Datatext.BuildSampleParts(config)
		local count = #texts
		for partIndex = count + 1, #parts do parts[partIndex]:Hide() end
		fill:SetShown(count > 0)
		edge:SetShown(count > 0 and config.border)
		note:SetShown(count == 0)
		if count == 0 then return end
		local fontPath = BUI.GetModuleFont(config)
		Pixel.ApplyFont(ruler, config.fontSize, fontPath, '')
		local widths = {}
		for partIndex = 1, count do
			ruler:SetText(texts[partIndex])
			widths[partIndex] = math.ceil(ruler:GetStringWidth())
		end
		local fixedWidth = config.width > 0 and math.min(Pixel.Scale(config.width), SAMPLE_WIDTH) or nil
		local barWidth = Datatext.LayoutRow(widths, count, Pixel.Scale(config.spacing), Pixel.Scale(Datatext.LAYOUT.rowInset), fixedWidth, config.align, 0, layout)
		local barHeight = Pixel.Scale(config.fontSize + Datatext.LAYOUT.lineExtra)
		for partIndex = 1, count do
			local part = parts[partIndex]
			if not part then
				part = cell:CreateFontString(nil, 'OVERLAY')
				part:SetWordWrap(false)
				part:SetJustifyH('LEFT')
				parts[partIndex] = part
			end
			Pixel.ApplyFont(part, config.fontSize, fontPath, '')
			part:SetText(texts[partIndex])
			part:ClearAllPoints()
			part:SetPoint('LEFT', cell, 'LEFT', math.floor(layout.textLeft[partIndex] + 1.5), 0)
			part:SetSize(widths[partIndex] + 1, barHeight)
			part:Show()
		end
		fill:ClearAllPoints()
		fill:SetPoint('LEFT', 1, 0)
		fill:SetSize(math.ceil(barWidth), barHeight)
		fill:SetColorTexture(config.bgColor.r, config.bgColor.g, config.bgColor.b, config.bgAlpha)
		edge:ClearAllPoints()
		edge:SetPoint('CENTER', fill)
		edge:SetSize(math.ceil(barWidth) + 2, barHeight + 2)
		edge:SetColorTexture(config.borderColor.r, config.borderColor.g, config.borderColor.b, config.borderColor.a)
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
	kit.IconButton(row, 'erase', 'Delete ' .. config.name, function() ConfirmDelete(index) end, 'danger'):SetPoint('RIGHT', -DELETE_INSET, 0)
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
	local newBar = kit.Button(footer, 'New bar', 'secondary', function() Create('TEXT') end, 'plus')
	newBar:SetPoint('LEFT', ROW_INSET, 0)
	kit.Button(footer, 'New panel', 'secondary', function() Create('PANEL') end, 'plus'):SetPoint('LEFT', newBar, 'RIGHT', BUTTON_GAP, 0)
end

local function BarBoard(ui, parent, width, config)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = config.name,
		description = 'A strip of datatexts. Unlock it with the eye in the header to drag it around, right-click it to lock it again.',
	})
	board:AddTools('Text', 'Font, size and the value color', {
		Swatch(config, 'Value color', 'colorValue', true),
		Font(config),
		{ tooltip = 'Size and labels', title = 'Text', options = {
			Option(config, 'Font size', 'fontSize', { min = 8, max = 24, step = 1 }),
			Option(config, 'Hide labels', 'hideLabels'),
		} },
	}, Apply)
	board:AddTools('Layout', 'How the datatexts are arranged, zero width or height fits the text', {
		{ tooltip = 'Orientation, spacing and size', title = 'Layout', options = {
			Option(config, 'Orientation', 'orientation', { entries = ORIENTATIONS }),
			Option(config, 'Align', 'align', { entries = ALIGNMENTS }),
			Option(config, 'Spacing', 'spacing', { min = 0, max = 160, step = 1 }),
			Option(config, 'Width', 'width', { min = 0, max = 1200, step = 1 }),
			Option(config, 'Height', 'height', { min = 0, max = 600, step = 1 }),
		} },
	}, Apply)
	board:AddTools('Position', 'Where it sits on the screen and how it layers', { PositionTool(config) }, Apply)
	board:AddTools('Background', 'The backdrop behind it', BackgroundTools(config), Apply)
	return board
end

local function PanelBoard(ui, parent, width, config)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = config.name,
		description = 'A blank backdrop to tuck other frames on. Unlock it with the eye in the header to drag it around, right-click it to lock it again.',
	})
	board:AddTools('Title', 'Optional text on the panel', {
		Swatch(config, 'Title color', 'titleColor', false),
		{ kind = 'input', width = INPUT_WIDTH, placeholder = 'No title', get = function() return config.title end, set = function(text) config.title = text end },
		{ tooltip = 'Anchor, size and offsets', title = 'Title', options = {
			Option(config, 'Anchor', 'titleAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS_SHORT }),
			Option(config, 'Size', 'titleSize', { min = 8, max = 32, step = 1 }),
			Option(config, 'Horizontal offset', 'titleX', { min = -300, max = 300, step = 1 }),
			Option(config, 'Vertical offset', 'titleY', { min = -300, max = 300, step = 1 }),
		} },
	}, Apply)
	board:AddTools('Size', 'Width and height of the panel', {
		{ tooltip = 'Width and height', title = 'Size', options = SizeOptions(config) },
	}, Apply)
	board:AddTools('Position', 'Where it sits on the screen and how it layers', { PositionTool(config) }, Apply)
	board:AddTools('Background', 'The backdrop itself', BackgroundTools(config), Apply)
	return board
end

local function DatatextOptions(entry, config)
	local options = {}
	for _, option in ipairs(entry.options(function() return config end, function() end)) do
		options[#options + 1] = { label = option.label, entries = option.items, get = option.get, set = option.set }
	end
	return { tooltip = entry.name .. ' settings', title = entry.name, options = options }
end

local function DatatextsBoard(ui, parent, width, config, page)
	local order = Datatext.ResolveOrder(config)
	local datatextRows = {}
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
		board:Move(datatextRows[id], delta)
		config.order = order
		Apply()
		page:Resize()
	end
	for _, id in ipairs(order) do
		local entry = Datatext.Get(id)
		local row = board:AddRow(entry.name, nil, ORDER_ROOM + (entry.options and COG_ROOM or 0))
		datatextRows[id] = row
		ui.Switch(row, function() return config[entry.show] == true end, function(value)
			config[entry.show] = value
			Apply()
		end):SetPoint('RIGHT', -ui.ROW_INSET, 0)
		OrderArrows(ui, row, function(delta) Move(id, delta) end)
		if entry.options then
			ui.Tool(row, DatatextOptions(entry, config), Apply):SetPoint('RIGHT', -(ui.ROW_INSET + ORDER_ROOM + TOOL_GAP), 0)
		end
	end
	return board
end

local function TooltipsBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Tooltips',
		description = 'Shared by every bar.',
	})
	board:AddSwitch('Hide tooltips in combat', function() return BUI.GetDB().datatextHideHoversInCombat ~= false end, function(value)
		BUI.GetDB().datatextHideHoversInCombat = value
	end, 'No datatext tooltips or hover panels while fighting')
	board:AddSwitch('Roster tooltips', function() return BUI.GetDB().datatextRosterTooltips ~= false end, function(value)
		BUI.GetDB().datatextRosterTooltips = value
	end, 'Member details such as keystone and score when hovering Friends and Guild rows')
	return board
end

local function Sections(ui, _, parent, width, page)
	local config = Current()
	local sections = {}
	if config and Datatext.IsPanel(config) then
		sections[#sections + 1] = PanelBoard(ui, parent, width, config)
	elseif config then
		sections[#sections + 1] = BarBoard(ui, parent, width, config)
		sections[#sections + 1] = DatatextsBoard(ui, parent, width, config, page)
	end
	sections[#sections + 1] = TooltipsBoard(ui, parent, width)
	return sections
end

BUI.PageEngine.RegisterPage('datatext', {
	title = 'Datatext',
	buttonText = 'Datatext',
	icon = 'report2',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Current()
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'report2',
			title = 'Datatext',
			placeholder = 'Search datatext settings...',
			tools = {
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
			tabs = { { label = 'Datatext', build = Sections } },
		})
		Datatext.SetLockCallback(Repaint)
		page:AutoRefresh()
	end,
})
