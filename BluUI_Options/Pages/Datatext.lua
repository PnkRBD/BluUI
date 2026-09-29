local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout, Modals = BUILib.Layout, BUILib.Modals
local Datatext = BUI.Datatext
local Pixel = BUI.Pixel

local PAGE_WIDTH = 960
local SELECT_ROW = 52
local SELECT_WIDTH = 220
local ROW_HEIGHT = 58
local ROW_INSET = 20
local NAME_WIDTH = 150
local SAMPLE_X = 190
local SAMPLE_GAP = 24
local PANEL_SAMPLE = 24
local PANEL_SAMPLE_MAX = 120
local BUTTON_GAP = 10
local MENU_WIDTH = 150
local ERASE_SIZE = 32
local ARROW = 22
local ARROW_GAP = 4
local TOOL_GAP = 12
local LIST_ROOM = ERASE_SIZE + TOOL_GAP + ARROW * 2 + ARROW_GAP
local COG_ROOM = ARROW + TOOL_GAP

local CENTERED = { TOP = true, CENTER = true, BOTTOM = true }
local CENTER_POINT = { TOPLEFT = 'TOP', TOPRIGHT = 'TOP', LEFT = 'CENTER', RIGHT = 'CENTER', BOTTOMLEFT = 'BOTTOM', BOTTOMRIGHT = 'BOTTOM' }

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
local editor
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

local function Apply()
	Datatext.Apply()
	if editor then editor:Update() end
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

local function Opacity(config)
	return { label = 'Background opacity', min = 0, max = 100, step = 1, get = function() return math.floor(config.bgAlpha * 100 + 0.5) end, set = function(value) config.bgAlpha = value / 100 end }
end

local function PositionTool(config)
	local options = {
		{ label = 'Anchor', entries = BUI.C.ANCHOR_POINT_OPTIONS_SHORT, get = function() return config.point end, set = function(value)
			config.point, config.relPoint = value, value
			config.alignMinimap = false
		end },
		Option(config, 'Horizontal offset', 'x', { min = -1500, max = 1500, step = 1 }),
		Option(config, 'Vertical offset', 'y', { min = -1500, max = 1500, step = 1 }),
		{ label = 'Center horizontally', get = function() return CENTERED[config.point] == true and config.x == 0 end, set = function(value)
			if not value then return end
			config.point = CENTER_POINT[config.point] or config.point
			config.relPoint = config.point
			config.x = 0
			Repaint()
		end },
		Option(config, 'Align below the minimap', 'alignMinimap'),
		Option(config, 'Strata', 'strata', { entries = BUI.C.STRATA_OPTIONS }),
		Option(config, 'Frame level', 'frameLevel', { min = 0, max = 100, step = 1 }),
	}
	if Datatext.IsPanel(config) then table.insert(options, 6, Option(config, 'Mirror the chat window', 'mirrorChat')) end
	return { icon = 'mover', tooltip = 'Position and layering', title = 'Position', options = options }
end

local function BarTools(config, index)
	local isPanel = Datatext.IsPanel(config)
	local tools = {
		Swatch(config, isPanel and 'Title color' or 'Value color', isPanel and 'titleColor' or 'colorValue', not isPanel),
		Swatch(config, 'Background color', 'bgColor', false),
	}
	if isPanel then
		tools[#tools + 1] = { kind = 'input', slot = 'menu', width = MENU_WIDTH, placeholder = 'No title', get = function() return config.title end, set = function(text) config.title = text end }
		tools[#tools + 1] = { tooltip = 'Title, size, border and opacity', title = config.name, options = {
			Option(config, 'Title anchor', 'titleAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS_SHORT }),
			Option(config, 'Title size', 'titleSize', { min = 8, max = 32, step = 1 }),
			Option(config, 'Title offset X', 'titleX', { min = -300, max = 300, step = 1 }),
			Option(config, 'Title offset Y', 'titleY', { min = -300, max = 300, step = 1 }),
			Option(config, 'Width', 'width', { min = 0, max = 1200, step = 1 }),
			Option(config, 'Height', 'height', { min = 0, max = 600, step = 1 }),
			Opacity(config),
			Option(config, 'Border', 'border'),
			Swatch(config, 'Border color', 'borderColor', true),
		} }
	else
		tools[#tools + 1] = { entries = fonts, width = MENU_WIDTH, get = function() return config.font end, set = function(value) config.font = value end }
		tools[#tools + 1] = { tooltip = 'Text, layout, size and border', title = config.name, options = {
			Option(config, 'Font size', 'fontSize', { min = 8, max = 24, step = 1 }),
			Option(config, 'Hide labels', 'hideLabels'),
			Option(config, 'Orientation', 'orientation', { entries = ORIENTATIONS }),
			Option(config, 'Align', 'align', { entries = ALIGNMENTS }),
			Option(config, 'Spacing', 'spacing', { min = 0, max = 160, step = 1 }),
			Option(config, 'Width', 'width', { min = 0, max = 1200, step = 1 }),
			Option(config, 'Height', 'height', { min = 0, max = 600, step = 1 }),
			Opacity(config),
			Option(config, 'Border', 'border'),
			Swatch(config, 'Border color', 'borderColor', true),
		} }
	end
	tools[#tools + 1] = PositionTool(config)
	tools[#tools + 1] = { get = function() return config.enabled == true end, set = function(value) config.enabled = value end }
	tools[#tools + 1] = { slot = 'erase', icon = 'erase', size = ERASE_SIZE, hover = 'danger', tooltip = 'Delete ' .. config.name, onClick = function() ConfirmDelete(index) end }
	return tools
end

local function OrderArrows(ui, row, onMove)
	local down = ui.ArrowButton(row, false, function() onMove(1) end)
	down:SetPoint('RIGHT', -(ui.ROW_INSET + ERASE_SIZE + TOOL_GAP), 0)
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
	local note = kit.Text(cell, 'No datatexts on this bar', 11, 'faint')
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
		local fixedWidth = config.width > 0 and math.min(Pixel.Scale(config.width), cell:GetWidth()) or nil
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

local function EditorRow(kit, band, config, index)
	local row = CreateFrame('Frame', nil, band)
	row:SetPoint('TOPLEFT', 0, -SELECT_ROW)
	row:SetPoint('TOPRIGHT', 0, -SELECT_ROW)
	row:SetHeight(ROW_HEIGHT)
	local isPanel = Datatext.IsPanel(config)
	kit.RowTitle(row, config.name, isPanel and 'Panel' or 'Bar', ROW_INSET, NAME_WIDTH)
	local cell = CreateFrame('Frame', nil, row)
	cell:SetPoint('LEFT', SAMPLE_X, 0)
	cell:SetHeight(ROW_HEIGHT)
	cell:SetClipsChildren(true)
	local UpdateSample = isPanel and PanelSample(kit, cell, config) or BarSample(kit, cell, config)
	local placer = kit.Tools(row, BarTools(config, index), Apply)
	local used = placer.Place(placer.widths)
	cell:SetPoint('RIGHT', -(ROW_INSET + used + SAMPLE_GAP), 0)
	row.Update = UpdateSample
	UpdateSample()
	return row
end

local function Selector(kit, head)
	local dropdown = kit.Dropdown(head, SELECT_WIDTH, function()
		local items = {}
		local function Group(title, panels)
			local started = false
			for index, config in ipairs(Bars()) do
				if Datatext.IsPanel(config) == panels then
					if not started then
						items[#items + 1] = { title = title }
						started = true
					end
					items[#items + 1] = { text = config.name, checked = index == selected, callback = function() Select(index) end }
				end
			end
		end
		Group('Bars', false)
		Group('Panels', true)
		return items
	end)
	dropdown:SetPoint('LEFT', ROW_INSET, 0)
	dropdown.label:SetText(Current().name)
	return dropdown
end

local function BuildTable(band, kit)
	local head = CreateFrame('Frame', nil, band)
	head:SetPoint('TOPLEFT')
	head:SetPoint('TOPRIGHT')
	head:SetHeight(SELECT_ROW)
	local rule = kit.Fill(head, 'rule', 'ARTWORK')
	rule:SetPoint('BOTTOMLEFT', ROW_INSET, 0)
	rule:SetPoint('BOTTOMRIGHT', -ROW_INSET, 0)
	rule:SetHeight(1)
	local newPanel = kit.Button(head, 'New panel', 'secondary', function() Create('PANEL') end, 'plus')
	newPanel:SetPoint('RIGHT', -ROW_INSET, 0)
	kit.Button(head, 'New bar', 'secondary', function() Create('TEXT') end, 'plus'):SetPoint('RIGHT', newPanel, 'LEFT', -BUTTON_GAP, 0)
	local config = Current()
	if config then
		Selector(kit, head)
		editor = EditorRow(kit, band, config, selected)
	else
		editor = nil
		kit.Text(head, 'No bars or panels yet', 12, 'muted'):SetPoint('LEFT', ROW_INSET, 0)
		kit.Text(band, 'Add a bar for datatexts, or a panel for a blank backdrop', 12, 'muted'):SetPoint('TOPLEFT', ROW_INSET, -(SELECT_ROW + ROW_HEIGHT / 2 - 6))
	end
end

local function TableHeight()
	return SELECT_ROW + ROW_HEIGHT
end

local function DatatextOptions(entry, config)
	local options = {}
	for _, option in ipairs(entry.options(function() return config end, function() end)) do
		options[#options + 1] = { label = option.label, entries = option.items, get = option.get, set = option.set }
	end
	return { tooltip = entry.name .. ' settings', title = entry.name, options = options }
end

local function IndexOf(list, id)
	for position, candidate in ipairs(list) do
		if candidate == id then return position end
	end
end

local function DatatextsBoard(ui, parent, width, config, page)
	local order = Datatext.ResolveOrder(config)
	local active, off = {}, {}
	for _, id in ipairs(order) do
		local entry = Datatext.Get(id)
		if config[entry.show] then active[#active + 1] = id else off[#off + 1] = entry end
	end
	local listRows = {}
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Datatexts',
		description = 'What ' .. config.name .. ' shows, top to bottom here is left to right on the bar.',
		buttons = {
			{ text = 'Default order', icon = 'reset', onClick = function()
				config.order = nil
				Apply()
				RebuildPage()
			end },
		},
	})
	local function Move(id, delta)
		local position = IndexOf(active, id)
		local otherID = active[position + delta]
		if not otherID then return end
		local from, to = IndexOf(order, id), IndexOf(order, otherID)
		order[from], order[to] = otherID, id
		active[position], active[position + delta] = otherID, id
		board:Move(listRows[id], delta)
		config.order = order
		Apply()
		page:Resize()
	end
	for _, id in ipairs(active) do
		local entry = Datatext.Get(id)
		local row = board:AddRow(entry.name, nil, LIST_ROOM + (entry.options and COG_ROOM or 0))
		listRows[id] = row
		ui.IconButton(row, 'erase', 'Take ' .. entry.name .. ' off the bar', function()
			config[entry.show] = false
			Apply()
			RebuildPage()
		end, 'danger', ERASE_SIZE):SetPoint('RIGHT', -ui.ROW_INSET, 0)
		OrderArrows(ui, row, function(delta) Move(id, delta) end)
		if entry.options then
			ui.Tool(row, DatatextOptions(entry, config), Apply):SetPoint('RIGHT', -(ui.ROW_INSET + LIST_ROOM + TOOL_GAP), 0)
		end
	end
	if #active == 0 then
		board:AddRow('Nothing on this bar yet', 'Pick a datatext below to start it off')
	end
	if #off > 0 then
		local row = board:AddRow('Add a datatext', 'It joins the end of the bar', MENU_WIDTH)
		local dropdown = ui.Dropdown(row, MENU_WIDTH, function()
			local items = {}
			for _, entry in ipairs(off) do
				items[#items + 1] = { text = entry.name, callback = function()
					config[entry.show] = true
					table.remove(order, IndexOf(order, entry.id))
					order[#order + 1] = entry.id
					config.order = order
					Apply()
					RebuildPage()
				end }
			end
			return items
		end)
		dropdown:SetPoint('RIGHT', -ui.ROW_INSET, 0)
		dropdown.label:SetText('Pick one')
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
	if config and not Datatext.IsPanel(config) then
		sections[#sections + 1] = DatatextsBoard(ui, parent, width, config, page)
	end
	sections[#sections + 1] = TooltipsBoard(ui, parent, width)
	return sections
end

BUI.PageEngine.RegisterPage('datatext', {
	title = 'Datatext',
	buttonText = 'Datatext',
	icon = 'text',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Current()
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'text',
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
