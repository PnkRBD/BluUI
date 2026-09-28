local BUI = BluUI
local BUILib = BUI.BUILibClient
local Controls, Layout, Modals = BUILib.Controls, BUILib.Layout, BUILib.Modals
local Datatext = BUI.Datatext
local Pixel = BUI.Pixel

local PAGE_WIDTH = 960
local PREVIEW_HEIGHT = 180
local STAGE_INSET = 12
local PANEL_PREVIEW = 150
local SLIDER_WIDTH = 220
local DROPDOWN_WIDTH = 200
local INPUT_WIDTH = 220
local SWATCH_SIZE = 28
local SWATCH_ROOM = 60
local SWITCH_WIDTH = 40
local ARROW = 22
local ARROW_GAP = 4
local ORDER_ROOM = SWITCH_WIDTH + 12 + ARROW * 2 + ARROW_GAP

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

local selectedText, selectedPanel
local activeKind = 'TEXT'
local preview
local items = {}

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function Bars()
	return Datatext.GetBars()
end

local function KindOf(bar)
	return bar.kind == 'PANEL' and 'PANEL' or 'TEXT'
end

local function FirstOfKind(kind)
	for barIndex, bar in ipairs(Bars()) do
		if KindOf(bar) == kind then return barIndex end
	end
end

local function ValidIndex(index, kind)
	local list = Bars()
	if index and list[index] and KindOf(list[index]) == kind then return index end
	return FirstOfKind(kind)
end

local function CurText()
	selectedText = ValidIndex(selectedText, 'TEXT')
	return selectedText and Bars()[selectedText]
end

local function CurPanel()
	selectedPanel = ValidIndex(selectedPanel, 'PANEL')
	return selectedPanel and Bars()[selectedPanel]
end

local function ActiveCur()
	if activeKind == 'PANEL' then return CurPanel() end
	return CurText()
end

local function ActiveIndex()
	if activeKind == 'PANEL' then return selectedPanel end
	return selectedText
end

local function ActiveID()
	local current = ActiveCur()
	if not current then return 'general' end
	return (activeKind == 'PANEL' and 'panel' or 'bar') .. ActiveIndex()
end

local function RefreshPreview()
	if preview then preview:UpdatePreview() end
end

local function Apply()
	Datatext.Apply()
	RefreshPreview()
end

local function RebuildPage()
	BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
end

local function Named(entries, value)
	for _, entry in ipairs(entries) do
		if entry.value == value then return entry.text end
	end
	return value
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

local function ConfirmDelete(index)
	local config = Bars()[index]
	Modals.Confirm({
		parent = Window().frame,
		title = 'Delete ' .. config.name,
		message = 'Delete "' .. config.name .. '"? This cannot be undone.',
		confirmText = 'Delete', cancelText = 'Cancel',
		onConfirm = function()
			Datatext.DeleteBar(index)
			if KindOf(config) == 'PANEL' then selectedPanel = nil else selectedText = nil end
			RebuildPage()
		end,
	})
end

local function BuildPreview(band)
	local stage = CreateFrame('Frame', nil, band)
	stage:SetPoint('TOPLEFT', STAGE_INSET, -STAGE_INSET)
	stage:SetPoint('BOTTOMRIGHT', -STAGE_INSET, STAGE_INSET)
	stage:SetClipsChildren(true)

	local note = stage:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(note, 12, BUI.C.FONT_PATH, '')
	note:SetPoint('CENTER')
	Window():Paint(note, 'muted')

	local panelTexture = stage:CreateTexture(nil, 'ARTWORK')
	local panelTitle = stage:CreateFontString(nil, 'OVERLAY')
	local cells = {}
	local layout = { textLeft = {}, textWidth = {}, hitLeft = {}, hitWidth = {}, lineTop = {} }

	local function HideAll()
		note:Hide()
		panelTexture:Hide()
		panelTitle:Hide()
		for _, cell in ipairs(cells) do cell:Hide() end
	end

	local function Note(text)
		note:SetText(text)
		note:Show()
	end

	local function ShowPanel(config)
		local panelWidth = config.width > 0 and config.width or 200
		local panelHeight = config.height > 0 and config.height or 100
		local scale = math.min(1, PANEL_PREVIEW / math.max(panelWidth, panelHeight))
		local color = config.bgColor
		panelTexture:SetColorTexture(color.r, color.g, color.b, math.max(config.bgAlpha, 0.15))
		panelTexture:ClearAllPoints()
		panelTexture:SetPoint('CENTER')
		panelTexture:SetSize(panelWidth * scale, panelHeight * scale)
		panelTexture:Show()
		if config.title == '' then return end
		Pixel.ApplyFont(panelTitle, math.max(8, math.floor(config.titleSize * scale + 0.5)), BUI.GetModuleFont(config), '')
		panelTitle:SetText(config.title)
		panelTitle:SetTextColor(config.titleColor.r, config.titleColor.g, config.titleColor.b)
		panelTitle:ClearAllPoints()
		panelTitle:SetPoint(config.titleAnchor, panelTexture, config.titleAnchor, config.titleX * scale, config.titleY * scale)
		panelTitle:Show()
	end

	local function ShowBar(config)
		local fontPath = BUI.GetModuleFont(config)
		local parts = Datatext.BuildSampleParts(config)
		local count = #parts
		if count == 0 then return Note('No readouts turned on') end
		local widths = {}
		for partIndex = 1, count do
			local cell = cells[partIndex]
			if not cell then
				cell = stage:CreateFontString(nil, 'OVERLAY')
				cells[partIndex] = cell
			end
			Pixel.ApplyFont(cell, config.fontSize, fontPath, '')
			cell:SetWordWrap(false)
			cell:SetText(parts[partIndex])
			widths[partIndex] = cell:GetStringWidth()
		end
		local spacing = Pixel.Scale(config.spacing)
		local fixedWidth = config.width > 0 and math.min(Pixel.Scale(config.width), stage:GetWidth()) or nil
		if config.orientation == 'VERTICAL' then
			local lineHeight = Pixel.Scale(config.fontSize + Datatext.LAYOUT.lineExtra)
			local barWidth, barHeight = Datatext.LayoutColumn(widths, count, spacing, Pixel.Scale(Datatext.LAYOUT.columnInset), lineHeight, fixedWidth, nil, layout)
			local justify = config.align == 'SPREAD' and 'CENTER' or config.align
			for partIndex = 1, count do
				local cell = cells[partIndex]
				cell:ClearAllPoints()
				cell:SetPoint('TOPLEFT', stage, 'CENTER', -barWidth / 2 + layout.lineLeft, barHeight / 2 - layout.lineTop[partIndex])
				cell:SetSize(layout.lineWidth, lineHeight)
				cell:SetJustifyH(justify)
				cell:SetJustifyV('MIDDLE')
				cell:Show()
			end
		else
			local barWidth = Datatext.LayoutRow(widths, count, spacing, Pixel.Scale(Datatext.LAYOUT.rowInset), fixedWidth, config.align, 0, layout)
			for partIndex = 1, count do
				local cell = cells[partIndex]
				cell:ClearAllPoints()
				cell:SetPoint('LEFT', stage, 'CENTER', -barWidth / 2 + layout.textLeft[partIndex], 0)
				cell:SetWidth(layout.textWidth[partIndex])
				cell:SetHeight(0)
				cell:SetJustifyH('CENTER')
				cell:Show()
			end
		end
	end

	function band:UpdatePreview()
		HideAll()
		local config = ActiveCur()
		if not config then return Note(activeKind == 'PANEL' and 'No panels yet' or 'No bars yet') end
		if activeKind == 'PANEL' then ShowPanel(config) else ShowBar(config) end
	end

	band:HookScript('OnShow', function(self) self:UpdatePreview() end)
	band:UpdatePreview()
	return band
end

local function BarBoard(ui, parent, width, config, index)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = config.name,
		description = 'A strip of readouts. Unlock it with the eye in the header to drag it around, right-click it to lock it again.',
		buttons = { { style = 'danger', text = 'Delete', onClick = function() ConfirmDelete(index) end } },
	})
	Switch(board, 'Shown', function() return config.enabled == true end, function(value)
		config.enabled = value
	end, 'Show this bar on screen')
	Switch(board, 'Hide labels', function() return config.hideLabels == true end, function(value)
		config.hideLabels = value
	end, 'Values only, no names in front of them')
	Menu(ui, board:AddRow('Font', 'Global unless you pick one', DROPDOWN_WIDTH), BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), Field(config, 'font'))
	Slider(ui, board:AddRow('Font size', nil, SLIDER_WIDTH), 8, 24, 1, Field(config, 'fontSize'))
	Slider(ui, board:AddRow('Spacing', 'Pixels between readouts', SLIDER_WIDTH), 0, 160, 1, Field(config, 'spacing'))
	Menu(ui, board:AddRow('Orientation', 'A row or a stack', DROPDOWN_WIDTH), ORIENTATIONS, Field(config, 'orientation'))
	Menu(ui, board:AddRow('Align', 'Where the readouts sit in a fixed width', DROPDOWN_WIDTH), ALIGNMENTS, Field(config, 'align'))
	ColorRow(ui, board, 'Value color', 'The numbers next to each label', true, ColorField(config, 'colorValue', true))
	return board
end

local function PanelBoard(ui, parent, width, config, index)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = config.name,
		description = 'A blank backdrop to tuck other frames on. Unlock it with the eye in the header to drag it around, right-click it to lock it again.',
		buttons = { { style = 'danger', text = 'Delete', onClick = function() ConfirmDelete(index) end } },
	})
	Switch(board, 'Shown', function() return config.enabled == true end, function(value)
		config.enabled = value
	end, 'Show this panel on screen')
	ui.Input(board:AddRow('Title', 'Optional text on the panel, empty for none', INPUT_WIDTH), INPUT_WIDTH, {
		placeholder = 'No title',
		get = function() return config.title end,
		set = function(text)
			config.title = text
			Apply()
		end,
	}):SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ColorRow(ui, board, 'Title color', nil, false, ColorField(config, 'titleColor', false))
	Menu(ui, board:AddRow('Title anchor', 'Which edge of the panel it hugs', DROPDOWN_WIDTH), BUI.C.ANCHOR_POINT_OPTIONS_SHORT, Field(config, 'titleAnchor'))
	Slider(ui, board:AddRow('Title size', nil, SLIDER_WIDTH), 8, 32, 1, Field(config, 'titleSize'))
	Slider(ui, board:AddRow('Title offset X', 'From its anchor', SLIDER_WIDTH), -300, 300, 1, Field(config, 'titleX'))
	Slider(ui, board:AddRow('Title offset Y', 'From its anchor', SLIDER_WIDTH), -300, 300, 1, Field(config, 'titleY'))
	return board
end

local function PositionBoard(ui, parent, width, config)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Position',
		description = 'Where it sits on the screen and how it layers with other frames.',
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

local function ReadoutsBoard(ui, parent, width, config, page)
	local order = Datatext.ResolveOrder(config)
	local rows = {}
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Readouts',
		description = 'What the bar shows, top to bottom here is left to right on the bar.',
		buttons = {
			{ text = 'Default order', icon = 'reset', onClick = function()
				config.order = nil
				Apply()
				page:RebuildCurrent()
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
		board:Move(rows[id], delta)
		config.order = order
		Apply()
		page:Resize()
	end
	for _, id in ipairs(order) do
		local entry = Datatext.Get(id)
		local row = board:AddRow(entry.name, nil, ORDER_ROOM)
		rows[id] = row
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
				title = 'Readout settings',
				description = 'Extra choices some readouts offer.',
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

local function GeneralBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'General',
		description = 'Settings shared by every bar.',
	})
	Switch(board, 'Hide tooltips in combat', function() return BUI.GetDB().datatextHideHoversInCombat ~= false end, function(value)
		BUI.GetDB().datatextHideHoversInCombat = value
	end, 'No readout tooltips or hover panels while fighting')
	Switch(board, 'Roster tooltips', function() return BUI.GetDB().datatextRosterTooltips ~= false end, function(value)
		BUI.GetDB().datatextRosterTooltips = value
	end, 'Member details such as keystone and score when hovering Friends and Guild rows')
	return board
end

local function Panes(ui, _, parent, width, item, page)
	if item.id == 'newbar' or item.id == 'newpanel' then
		local kind = item.id == 'newpanel' and 'PANEL' or 'TEXT'
		local index = Datatext.AddBar(kind)
		if kind == 'PANEL' then selectedPanel = index else selectedText = index end
		activeKind = kind
		RebuildPage()
		return {}
	end
	if item.id == 'general' then return { GeneralBoard(ui, parent, width) } end
	local config = Bars()[item.index]
	if item.kind == 'PANEL' then
		return { PanelBoard(ui, parent, width, config, item.index), PositionBoard(ui, parent, width, config), BackgroundBoard(ui, parent, width, config) }
	end
	local sections = { BarBoard(ui, parent, width, config, item.index), PositionBoard(ui, parent, width, config), BackgroundBoard(ui, parent, width, config), ReadoutsBoard(ui, parent, width, config, page) }
	local settings = ReadoutSettingsBoard(ui, parent, width, config)
	if settings then sections[#sections + 1] = settings end
	return sections
end

local function RailGroups()
	items = {}
	local bars, panels = {}, {}
	for barIndex, bar in ipairs(Bars()) do
		local kind = KindOf(bar)
		local item = { id = (kind == 'PANEL' and 'panel' or 'bar') .. barIndex, label = bar.name, kind = kind, index = barIndex }
		items[item.id] = item
		local list = kind == 'PANEL' and panels or bars
		list[#list + 1] = item
	end
	bars[#bars + 1] = { id = 'newbar', label = 'New bar', icon = 'add' }
	panels[#panels + 1] = { id = 'newpanel', label = 'New panel', icon = 'add' }
	return {
		{ title = 'Bars', items = bars },
		{ title = 'Panels', items = panels },
		{ title = 'Settings', items = { { id = 'general', label = 'General', icon = 'cog' } } },
	}
end

local function Activate(id)
	local item = items[id]
	if not item then return end
	activeKind = item.kind
	if item.kind == 'PANEL' then selectedPanel = item.index else selectedText = item.index end
end

BUI.PageEngine.RegisterPage('datatext', {
	title = 'Datatext',
	buttonText = 'Datatext',
	icon = 'report2',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		ActiveCur()
		local rail
		rail = Layout.RailPage(page:GetTab(1), { window = Window() }, {
			icon = 'report2',
			title = 'Datatext',
			placeholder = 'Search datatext settings...',
			toggles = {
				{ icon = 'enable', tooltip = 'Turn the datatext module on or off', get = Datatext.ModuleEnabled, set = function(value)
					BUI.GetDB().datatextEnabled = value
					Apply()
				end },
				{ icon = 'eye', tooltip = 'Unlock the selected bar or panel to drag it, right-click it to lock', get = function()
					local current = ActiveCur()
					return current and not current.lock or false
				end, set = function(value)
					local current = ActiveCur()
					if not current then return end
					current.lock = not value
					Datatext.Apply()
				end },
			},
			preview = { height = PREVIEW_HEIGHT, build = function(band) preview = BuildPreview(band) end },
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
		Datatext.SetLockCallback(Repaint)
		page:AutoRefresh()
	end,
})
