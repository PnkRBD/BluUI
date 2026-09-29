local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout, Modals = BUILib.Layout, BUILib.Modals
local Section = Layout.TableSection
local Datatext = BUI.Datatext
local Pixel = BUI.Pixel

local PAGE_WIDTH = 960
local SAMPLE_HEIGHT = 56
local SAMPLE_LIMIT = PAGE_WIDTH - 40
local PANEL_SAMPLE = 24
local PANEL_SAMPLE_MAX = 120
local CAPTION_GAP = 10
local MENU_WIDTH = 150
local ERASE_SIZE = 32
local TOOL_GAP = 12
local LIST_ROOM = ERASE_SIZE
local COG_ROOM = 22 + TOOL_GAP
local GRABBER_SIZE = 12
local LIST_ROW = 44
local LIST_TITLE_X = 44
local DRAG_ALPHA = 0.35

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
local showingTooltips = false
local items = {}
local preview
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

local function IndexOf(list, value)
	for position, candidate in ipairs(list) do
		if candidate == value then return position end
	end
end

local function RefreshPreview()
	if preview then preview:Update() end
end

local function Apply()
	Datatext.Apply()
	RefreshPreview()
end

local function RebuildPage()
	BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
end

local function Create(kind)
	selected = Datatext.AddBar(kind)
	showingTooltips = false
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

local function NameOption(config)
	return { label = 'Name', kind = 'input', placeholder = 'Name', get = function() return config.name end, set = function(name)
		if name == '' then return end
		config.name = name
		RebuildPage()
	end }
end

local function BarTools(config, index)
	local isPanel = Datatext.IsPanel(config)
	local tools = {
		Swatch(config, isPanel and 'Title color' or 'Value color', isPanel and 'titleColor' or 'colorValue', not isPanel),
		Swatch(config, 'Background color', 'bgColor', false),
	}
	if isPanel then
		tools[#tools + 1] = { icon = 'text', tooltip = 'Name, title text and placement', title = 'Title', options = {
			NameOption(config),
			Option(config, 'Title', 'title', { kind = 'input', placeholder = 'No title' }),
			Option(config, 'Anchor', 'titleAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS_SHORT }),
			Option(config, 'Size', 'titleSize', { min = 8, max = 32, step = 1 }),
			Option(config, 'Horizontal offset', 'titleX', { min = -300, max = 300, step = 1 }),
			Option(config, 'Vertical offset', 'titleY', { min = -300, max = 300, step = 1 }),
		} }
		tools[#tools + 1] = { tooltip = 'Size and backdrop', title = 'Panel', options = {
			Option(config, 'Width', 'width', { min = 0, max = 1200, step = 1 }),
			Option(config, 'Height', 'height', { min = 0, max = 600, step = 1 }),
			Opacity(config),
			Option(config, 'Border', 'border'),
			Swatch(config, 'Border color', 'borderColor', true),
		} }
	else
		tools[#tools + 1] = { entries = fonts, width = MENU_WIDTH, get = function() return config.font end, set = function(value) config.font = value end }
		tools[#tools + 1] = { icon = 'text', tooltip = 'Name, size and labels', title = 'Text', options = {
			NameOption(config),
			Option(config, 'Font size', 'fontSize', { min = 8, max = 24, step = 1 }),
			Option(config, 'Hide labels', 'hideLabels'),
		} }
		tools[#tools + 1] = { tooltip = 'Layout, size and backdrop', title = 'Layout', options = {
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

local function BarSample(kit, cell, config)
	local layout = { textLeft = {}, textWidth = {}, hitLeft = {}, hitWidth = {}, lineTop = {} }
	local edge = cell:CreateTexture(nil, 'BACKGROUND', nil, 0)
	local fill = cell:CreateTexture(nil, 'BACKGROUND', nil, 1)
	local parts = {}
	local sizer = cell:CreateFontString(nil, 'ARTWORK')
	sizer:SetAlpha(0)
	sizer:SetPoint('LEFT')
	local note = kit.Text(cell, 'No datatexts on this bar yet', 12, 'faint')
	note:SetPoint('LEFT')
	return function()
		local texts = Datatext.BuildSampleParts(config)
		local count = #texts
		for partIndex = count + 1, #parts do parts[partIndex]:Hide() end
		fill:SetShown(count > 0)
		edge:SetShown(count > 0 and config.border)
		note:SetShown(count == 0)
		if count == 0 then return math.ceil(note:GetStringWidth()) end
		local fontPath = BUI.GetModuleFont(config)
		Pixel.ApplyFont(sizer, config.fontSize, fontPath, '')
		local widths = {}
		for partIndex = 1, count do
			sizer:SetText(texts[partIndex])
			widths[partIndex] = math.ceil(sizer:GetStringWidth())
		end
		local fixedWidth = config.width > 0 and math.min(Pixel.Scale(config.width), SAMPLE_LIMIT) or nil
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
		return math.ceil(barWidth) + 2
	end
end

local function PanelSample(kit, cell, config)
	local edge = cell:CreateTexture(nil, 'BACKGROUND', nil, 0)
	local fill = cell:CreateTexture(nil, 'BACKGROUND', nil, 1)
	local caption = kit.Text(cell, '', 12, 'muted')
	caption:SetPoint('LEFT', fill, 'RIGHT', CAPTION_GAP, 0)
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
		return sampleWidth + 2 + CAPTION_GAP + math.ceil(caption:GetStringWidth())
	end
end

local function BuildPreview(band, kit)
	local samples = {}
	local note = kit.Text(band, '', 12, 'muted')
	note:SetPoint('CENTER')
	function band:Update()
		for _, sample in pairs(samples) do sample.cell:Hide() end
		local config = not showingTooltips and Current() or nil
		note:SetShown(not config)
		if not config then
			note:SetText(showingTooltips and 'Tooltips apply to every bar' or 'Nothing here yet, add a bar or a panel from the rail')
			return
		end
		local sample = samples[config]
		if not sample then
			local cell = CreateFrame('Frame', nil, self)
			cell:SetPoint('CENTER')
			cell:SetSize(1, SAMPLE_HEIGHT)
			cell:SetClipsChildren(true)
			sample = { cell = cell, Update = Datatext.IsPanel(config) and PanelSample(kit, cell, config) or BarSample(kit, cell, config) }
			samples[config] = sample
		end
		sample.cell:Show()
		sample.cell:SetWidth(math.max(1, math.min(SAMPLE_LIMIT, sample.Update())))
	end
	band:HookScript('OnShow', function(self) self:Update() end)
	return band
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
	local active, off = {}, {}
	for _, id in ipairs(order) do
		local entry = Datatext.Get(id)
		if config[entry.show] then active[#active + 1] = id else off[#off + 1] = entry end
	end
	local listRows = {}
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Datatexts',
		description = 'What the bar shows, top to bottom here is left to right on the bar. Drag a row to reorder it.',
		buttons = {
			{ text = 'Default order', icon = 'reset', onClick = function()
				config.order = nil
				Apply()
				page:RebuildCurrent()
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
		page:Resize()
	end
	local function RowUnder(cursorY)
		for _, id in ipairs(active) do
			local row = listRows[id]
			local top, bottom = row:GetTop(), row:GetBottom()
			if top and cursorY <= top and cursorY >= bottom then return id end
		end
	end
	local dragging, grabOffset, ghost
	local function Ghost()
		if ghost then return ghost end
		ghost = CreateFrame('Frame', nil, board.panel)
		ghost:SetFrameLevel(board.panel:GetFrameLevel() + 10)
		ghost:SetSize(board.panelWidth, LIST_ROW)
		ui.Fill(ghost, 'control'):SetAllPoints()
		local bar = ui.Fill(ghost, 'accent', 'ARTWORK', 1)
		bar:SetPoint('TOPLEFT')
		bar:SetPoint('BOTTOMLEFT')
		bar:SetWidth(2)
		ui.Glyph(ghost, 'grabber', GRABBER_SIZE, 'text'):SetPoint('LEFT', ui.ROW_INSET, 0)
		ghost.label = ui.Text(ghost, '', 12, 'text')
		ghost.label:SetPoint('LEFT', LIST_TITLE_X, 0)
		ghost:Hide()
		return ghost
	end
	local function Track()
		local _, cursorY = GetCursorPosition()
		cursorY = cursorY / board.frame:GetEffectiveScale()
		ghost:ClearAllPoints()
		ghost:SetPoint('TOPLEFT', board.panel, 'TOPLEFT', 0, -(board.panel:GetTop() - cursorY - grabOffset))
		local over = RowUnder(cursorY)
		if over and over ~= dragging then
			Move(dragging, IndexOf(active, over) > IndexOf(active, dragging) and 1 or -1)
		end
	end
	for _, id in ipairs(active) do
		local entry = Datatext.Get(id)
		local room = LIST_ROOM + (entry.options and COG_ROOM or 0)
		local row = Section.AddRow(board, entry.name)
		row:SetHeight(LIST_ROW)
		listRows[id] = row
		ui.Glyph(row, 'grabber', GRABBER_SIZE, 'faint'):SetPoint('LEFT', ui.ROW_INSET, 0)
		ui.RowTitle(row, entry.name, nil, LIST_TITLE_X, board.panelWidth - LIST_TITLE_X - ui.ROW_INSET - room - TOOL_GAP)
		row:EnableMouse(true)
		row:RegisterForDrag('LeftButton')
		row:SetScript('OnDragStart', function(self)
			local _, cursorY = GetCursorPosition()
			dragging = id
			grabOffset = self:GetTop() - cursorY / board.frame:GetEffectiveScale()
			self:SetAlpha(DRAG_ALPHA)
			Ghost().label:SetText(entry.name)
			ghost:Show()
			Track()
			self:SetScript('OnUpdate', Track)
		end)
		row:SetScript('OnDragStop', function(self)
			self:SetScript('OnUpdate', nil)
			self:SetAlpha(1)
			ghost:Hide()
			dragging = nil
			Apply()
		end)
		ui.IconButton(row, 'erase', 'Take ' .. entry.name .. ' off the bar', function()
			config[entry.show] = false
			Apply()
			page:RebuildCurrent()
		end, 'danger', ERASE_SIZE):SetPoint('RIGHT', -ui.ROW_INSET, 0)
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
			local menu = {}
			for _, entry in ipairs(off) do
				menu[#menu + 1] = { text = entry.name, callback = function()
					config[entry.show] = true
					table.remove(order, IndexOf(order, entry.id))
					order[#order + 1] = entry.id
					config.order = order
					Apply()
					page:RebuildCurrent()
				end }
			end
			return menu
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

local function SettingsBoard(ui, parent, width, config, index)
	local isPanel = Datatext.IsPanel(config)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = config.name,
		description = isPanel and 'A blank backdrop to tuck other frames on. Unlock it with the eye in the header to drag it around, right-click it to lock it again.'
			or 'A strip of datatexts. Unlock it with the eye in the header to drag it around, right-click it to lock it again.',
	})
	board:AddTools('Settings', isPanel and 'Colors, title, size and position' or 'Colors, text, layout and position', BarTools(config, index), Apply)
	return board
end

local function Panes(ui, _, parent, width, item, page)
	if item.id == 'newbar' or item.id == 'newpanel' then
		Create(item.id == 'newpanel' and 'PANEL' or 'TEXT')
		return {}
	end
	if item.id == 'tooltips' then return { TooltipsBoard(ui, parent, width) } end
	local config = Bars()[item.index]
	if item.kind == 'PANEL' then return { SettingsBoard(ui, parent, width, config, item.index) } end
	return { SettingsBoard(ui, parent, width, config, item.index), DatatextsBoard(ui, parent, width, config, page) }
end

local function RailGroups()
	items = {}
	local bars, panels = {}, {}
	for index, config in ipairs(Bars()) do
		local kind = Datatext.IsPanel(config) and 'PANEL' or 'TEXT'
		local item = { id = (kind == 'PANEL' and 'panel' or 'bar') .. index, label = config.name, kind = kind, index = index }
		items[item.id] = item
		local list = kind == 'PANEL' and panels or bars
		list[#list + 1] = item
	end
	bars[#bars + 1] = { id = 'newbar', label = 'New bar', icon = 'plus' }
	panels[#panels + 1] = { id = 'newpanel', label = 'New panel', icon = 'plus' }
	return {
		{ title = 'Settings', items = { { id = 'tooltips', label = 'Tooltips', icon = 'cog' } } },
		{ title = 'Bars', items = bars },
		{ title = 'Panels', items = panels },
	}
end

local function ActiveID()
	if showingTooltips or not Current() then return 'tooltips' end
	return (Datatext.IsPanel(Current()) and 'panel' or 'bar') .. selected
end

local function Activate(id)
	local item = items[id]
	if item then
		selected = item.index
		showingTooltips = false
	elseif id == 'tooltips' then
		showingTooltips = true
	end
end

BUI.PageEngine.RegisterPage('datatext', {
	title = 'Datatext',
	buttonText = 'Datatext',
	icon = 'text',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Current()
		local rail
		rail = Layout.RailPage(page:GetTab(1), { window = Window() }, {
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
			preview = { height = SAMPLE_HEIGHT, build = function(band, kit) preview = BuildPreview(band, kit) end },
			rail = { groups = RailGroups(), selected = ActiveID() },
			build = Panes,
		})
		local Select = rail.Select
		function rail:Select(id)
			Activate(id)
			Select(self, id)
			Repaint()
			RefreshPreview()
		end
		RefreshPreview()
		Datatext.SetLockCallback(Repaint)
		page:AutoRefresh()
	end,
})
