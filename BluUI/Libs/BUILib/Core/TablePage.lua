local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Layout = BUILib.Layout
local Widget = BUILib.Widget

local PANEL_SHARE = 0.385
local LEFT_WIDTH = 300
local LEFT_GAP = 40
local AVATAR_X = 19
local NAME_X = 63
local AVATAR_SIZE = 28
local DROPDOWN_WIDTH = 112
local SECTION_PAD = 32
local STACK_PAD = 24
local STACK_GAP = 20
local TABLE_HEAD = 36
local ROW_HEIGHT = 58
local ROW_INSET = 20
local CONTROL_HEIGHT = 30
local TAB_HEIGHT = 30
local TAB_GAP = 40
local BUTTON_GAP = 10
local HEADER_GAP = 26
local BOTTOM_GAP = 24
local PREVIEW_GAP = 16
local PREVIEW_RADIUS = 8
local SEARCH_WIDTH, SEARCH_HEIGHT = 224, 34
local SOLID_HOVER = { 1, 1, 1, 0.12 }
local SWITCH_WIDTH, SWITCH_HEIGHT = 40, 22
local SLIDER_KNOB = 12
local SLIDER_TRACK = 4
local SLIDER_GAP = 6
local SLIDER_STEP = 24
local SLIDER_BOX = 52
local STEP_SIGN = 12
local TOGGLE_SIZE = 22
local TOGGLE_GAP = 14
local TOGGLE_INSET = 20
local BUTTON_STYLES = {
	primary = { fill = 'accent', text = 'onAccent', solid = true },
	control = { fill = 'control', text = 'controlText', solid = true },
	secondary = { fill = 'secondary', text = 'secondaryText' },
	danger = { fill = 'secondary', text = 'danger' },
}

Layout.TableKitExtensions = {}

local function Hex(red, green, blue)
	return ('#%02X%02X%02X'):format(math.floor(red * 255 + 0.5), math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5))
end

local function Percent(alpha)
	return ('%d%%'):format(math.floor(alpha * 100 + 0.5))
end

local Section = {}
Section.__index = Section
Layout.TableSection = Section

function Section:AddRow(search)
	local row = CreateFrame('Frame', nil, self.panel)
	row:SetSize(self.panelWidth, ROW_HEIGHT)
	local rule = self.window:Fill(row, 'rule', 'ARTWORK')
	rule:SetPoint('TOPLEFT', ROW_INSET, 0)
	rule:SetPoint('TOPRIGHT', -ROW_INSET, 0)
	rule:SetHeight(1)
	self.rows[#self.rows + 1] = { frame = row, rule = rule, search = search:lower() }
	return row
end

function Section:Layout(y, query)
	self:Measure()
	local shown, panelHeight = 0, TABLE_HEAD
	for _, row in ipairs(self.rows) do
		local match = query == '' or row.search:find(query, 1, true) ~= nil
		row.frame:SetShown(match)
		if match then
			row.frame:ClearAllPoints()
			row.frame:SetPoint('TOPLEFT', 0, -panelHeight)
			row.rule:SetShown(shown > 0)
			shown = shown + 1
			panelHeight = panelHeight + row.frame:GetHeight()
		end
	end
	if shown == 0 and query ~= '' then
		self.frame:Hide()
		return y
	end
	return self:Place(y, panelHeight)
end

function Section:Place(y, panelHeight)
	self.panel:SetHeight(panelHeight)
	local height = self.pad * 2 + math.max(self.leftHeight, self.panelTop - self.pad + panelHeight) + 1
	self.frame:ClearAllPoints()
	self.frame:SetPoint('TOPLEFT', 0, -y)
	self.frame:SetHeight(height)
	self.frame:Show()
	return y + height
end

function Layout.TableKit(window)
	local kit = { ROW_INSET = ROW_INSET, AVATAR_X = AVATAR_X, NAME_X = NAME_X }

	function kit.Bind(region, update) return window:Bind(region, update) end

	function kit.Text(parent, text, size, role, width, fontRole)
		local label = window:Text(parent, text, size, role, fontRole)
		label:SetJustifyH('LEFT')
		if width then
			label:SetWidth(width)
			label:SetWordWrap(true)
		end
		return label
	end

	function kit.Height(label)
		return math.ceil(label:GetStringHeight())
	end

	function kit.Glyph(parent, name, size, role, layer)
		local glyph = parent:CreateTexture(nil, layer or 'ARTWORK')
		glyph:SetTexture(BUILib.GetLibMedia(name))
		glyph:SetSize(size, size)
		return window:Paint(glyph, role)
	end

	function kit.Disc(parent, size, role, layer, subLayer)
		local disc = parent:CreateTexture(nil, layer or 'ARTWORK', nil, subLayer or 0)
		disc:SetTexture(BUILib.GetLibMedia('smoothdisc'))
		disc:SetSize(size, size)
		if role then window:Paint(disc, role) end
		return disc
	end

	local function Overlay(button, solid)
		local overlay = button:CreateTexture(nil, 'BACKGROUND', nil, 1)
		overlay:SetAllPoints()
		if solid then
			overlay:SetColorTexture(SOLID_HOVER[1], SOLID_HOVER[2], SOLID_HOVER[3], SOLID_HOVER[4])
		else
			overlay:SetTexture(Widget.WHITE)
			window:Paint(overlay, 'hover')
		end
		overlay:Hide()
		button:SetScript('OnEnter', function() overlay:Show() end)
		button:SetScript('OnLeave', function() overlay:Hide() end)
	end
	kit.Hover = Overlay

	function kit.Fill(parent, role, layer, subLayer)
		return window:Fill(parent, role, layer, subLayer)
	end

	function kit.Switch(parent, get, set)
		local switch = Widget.Unwrap(Controls.SwitchToggle(parent, nil, get(), set, nil, nil, nil, SWITCH_WIDTH, SWITCH_HEIGHT))
		local function Refresh() switch:SetValue(get()) end
		window:Bind(switch, Refresh)
		switch.Refresh = Refresh
		return switch
	end

	local function Stepper(parent, plus)
		local button = CreateFrame('Button', nil, parent)
		button:SetSize(SLIDER_STEP, CONTROL_HEIGHT)
		window:Fill(button, 'secondary'):SetAllPoints()
		Overlay(button)
		kit.Glyph(button, plus and 'plus' or 'minus', STEP_SIGN, 'secondaryText'):SetPoint('CENTER')
		return button
	end

	function kit.Slider(parent, width, spec)
		local frame = CreateFrame('Frame', nil, parent)
		frame:SetSize(width, CONTROL_HEIGHT)
		local step = spec.step or 1
		local decimals, unit = 0, step
		while math.abs(unit - math.floor(unit + 0.5)) > 0.0001 and decimals < 3 do
			unit, decimals = unit * 10, decimals + 1
		end
		local pattern = '%.' .. decimals .. 'f'
		local function Snap(value)
			return math.max(spec.min, math.min(spec.max, spec.min + math.floor((value - spec.min) / step + 0.5) * step))
		end

		local box = CreateFrame('Frame', nil, frame)
		box:SetSize(SLIDER_BOX, CONTROL_HEIGHT)
		box:SetPoint('RIGHT')
		window:Fill(box, 'input'):SetAllPoints()
		local edit = CreateFrame('EditBox', nil, box)
		edit:SetAllPoints()
		edit:SetAutoFocus(false)
		edit:SetJustifyH('CENTER')
		edit:SetMaxLetters(8)
		edit:SetFont(window.font, 12, '')
		window:Paint(edit, 'text')
		window:SetFontRole(edit, 'control')

		local plus = Stepper(frame, true)
		plus:SetPoint('RIGHT', box, 'LEFT', -SLIDER_GAP, 0)
		local minus = Stepper(frame, false)
		minus:SetPoint('LEFT')

		local slider = CreateFrame('Slider', nil, frame)
		slider:SetOrientation('HORIZONTAL')
		slider:SetPoint('LEFT', minus, 'RIGHT', SLIDER_GAP, 0)
		slider:SetPoint('RIGHT', plus, 'LEFT', -SLIDER_GAP, 0)
		slider:SetHeight(CONTROL_HEIGHT)
		slider:SetMinMaxValues(spec.min, spec.max)
		slider:SetValueStep(step)
		slider:SetObeyStepOnDrag(true)
		slider:SetThumbTexture(BUILib.GetLibMedia('smoothdisc'))
		local thumb = slider:GetThumbTexture()
		thumb:SetSize(SLIDER_KNOB, SLIDER_KNOB)
		thumb:SetDrawLayer('OVERLAY')
		window:Paint(thumb, 'text')
		local track = kit.Fill(slider, 'control', 'ARTWORK')
		track:SetPoint('LEFT', SLIDER_KNOB / 2, 0)
		track:SetPoint('RIGHT', -SLIDER_KNOB / 2, 0)
		track:SetHeight(SLIDER_TRACK)
		local fill = kit.Fill(slider, 'accent', 'ARTWORK', 1)
		fill:SetPoint('LEFT', track)
		fill:SetPoint('RIGHT', thumb, 'CENTER')
		fill:SetHeight(SLIDER_TRACK)

		local function Show(value)
			edit:SetText(pattern:format(value))
		end
		local function Set(value)
			value = Snap(value)
			slider:SetValue(value)
			spec.set(value)
		end
		slider:SetScript('OnValueChanged', function(_, value, userInput)
			value = Snap(value)
			Show(value)
			if userInput then spec.set(value) end
		end)
		minus:SetScript('OnClick', function() Set(slider:GetValue() - step) end)
		plus:SetScript('OnClick', function() Set(slider:GetValue() + step) end)
		edit:SetScript('OnEnterPressed', function(self)
			local typed = tonumber(self:GetText())
			if typed then Set(typed) else Show(Snap(slider:GetValue())) end
			self:ClearFocus()
		end)
		edit:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
		edit:SetScript('OnEditFocusLost', function() Show(Snap(slider:GetValue())) end)
		window:Bind(frame, function()
			local value = Snap(spec.get())
			slider:SetValue(value)
			Show(value)
		end)
		frame.slider = slider
		return frame
	end

	function kit.Input(parent, width, spec)
		local box = CreateFrame('Frame', nil, parent)
		box:SetSize(width, CONTROL_HEIGHT)
		window:Fill(box, 'input'):SetAllPoints()
		local edit = CreateFrame('EditBox', nil, box)
		edit:SetPoint('LEFT', 12, 0)
		edit:SetPoint('RIGHT', -12, 0)
		edit:SetHeight(CONTROL_HEIGHT)
		edit:SetAutoFocus(false)
		edit:SetFont(window.font, 12, '')
		window:Paint(edit, 'text')
		window:SetFontRole(edit, 'control')
		local hint = kit.Text(edit, spec.placeholder, 12, 'faint')
		hint:SetPoint('LEFT')
		local function Show()
			local text = spec.get()
			edit:SetText(text)
			hint:SetShown(text == '')
		end
		local function Commit(self)
			hint:SetShown(self:GetText() == '')
			if self:GetText() ~= spec.get() then spec.set(self:GetText()) end
		end
		edit:SetScript('OnTextChanged', function(self) hint:SetShown(self:GetText() == '') end)
		edit:SetScript('OnEnterPressed', function(self)
			Commit(self)
			self:ClearFocus()
		end)
		edit:SetScript('OnEscapePressed', function(self)
			Show()
			self:ClearFocus()
		end)
		edit:SetScript('OnEditFocusLost', Commit)
		box:EnableMouse(true)
		box:SetScript('OnMouseDown', function() edit:SetFocus() end)
		window:Bind(box, Show)
		box.edit = edit
		return box
	end

	function kit.Button(parent, text, style, onClick, icon)
		local look = BUTTON_STYLES[style or 'secondary']
		local button = CreateFrame('Button', nil, parent)
		window:Fill(button, look.fill):SetAllPoints()
		Overlay(button, look.solid)
		local textX = 14
		if icon then
			button.glyph = kit.Glyph(button, icon, 12, look.text)
			button.glyph:SetPoint('LEFT', 12, 0)
			textX = 32
		end
		local label = kit.Text(button, text, 12, look.text)
		label:SetPoint('LEFT', textX, 0)
		button:SetHeight(CONTROL_HEIGHT)
		local function Measure()
			window:Paint(label, look.text)
			button:SetWidth(Widget.EvenSize(textX + label:GetStringWidth() + 14))
		end
		window:Bind(button, Measure)
		button:SetScript('OnClick', function() onClick() end)
		function button:SetText(newText)
			label:SetText(newText)
			Measure()
		end
		return button
	end

	function kit.Dropdown(parent, width, items)
		local button = CreateFrame('Button', nil, parent)
		button:SetSize(width, CONTROL_HEIGHT)
		window:Fill(button, 'control'):SetAllPoints()
		Overlay(button, true)
		local label = kit.Text(button, '', 12, 'controlText')
		label:SetPoint('LEFT', 12, 0)
		label:SetPoint('RIGHT', -28, 0)
		label:SetWordWrap(false)
		kit.Glyph(button, 'dropdown', 9, 'controlText'):SetPoint('RIGHT', -12, 0)
		button:SetScript('OnClick', function(self)
			Controls.ContextMenu(items(), { anchor = self, width = math.max(width, 170), offsetY = -4, window = window })
		end)
		button.label = label
		return button
	end

	function kit.IconButton(parent, icon, tooltip, onClick, hoverRole, size)
		local button = CreateFrame('Button', nil, parent)
		button:SetSize(size and math.max(22, size) or 22, 22)
		local glyph = kit.Glyph(button, icon, size or 13, 'text')
		glyph:SetPoint('CENTER')
		button:SetScript('OnEnter', function(self)
			window:Paint(glyph, hoverRole or 'accent')
			Widget.ShowTip(self, tooltip)
		end)
		button:SetScript('OnLeave', function()
			window:Paint(glyph, 'text')
			Widget.HideTip()
		end)
		button:SetScript('OnClick', function() onClick() end)
		function button:SetActive(active)
			self:SetShown(active)
		end
		return button
	end

	function kit.ArrowButton(parent, up, onClick)
		local button = CreateFrame('Button', nil, parent)
		button:SetSize(22, 22)
		local glyph = kit.Glyph(button, 'dropdown', 10, 'muted')
		glyph:SetPoint('CENTER')
		if up then glyph:SetRotation(math.pi) end
		button:SetScript('OnEnter', function() window:Paint(glyph, 'text') end)
		button:SetScript('OnLeave', function() window:Paint(glyph, 'muted') end)
		button:SetScript('OnClick', function() onClick() end)
		return button
	end

	function kit.Swatch(parent, size, onClick)
		local swatch = CreateFrame(onClick and 'Button' or 'Frame', nil, parent)
		swatch:SetSize(size, size)
		if onClick then swatch:SetScript('OnClick', onClick) end
		kit.Disc(swatch, size, 'rule', 'ARTWORK', 0):SetPoint('CENTER')
		swatch.fill = kit.Disc(swatch, size - 4, nil, 'ARTWORK', 1)
		swatch.fill:SetPoint('CENTER')
		return swatch
	end

	function kit.SplitSwatch(parent, size)
		local swatch = CreateFrame('Frame', nil, parent)
		swatch:SetSize(size, size)
		kit.Disc(swatch, size, 'rule', 'ARTWORK', 0):SetPoint('CENTER')
		local inner = size - 4
		swatch.left = kit.Disc(swatch, inner, nil, 'ARTWORK', 1)
		swatch.left:SetTexCoord(0, 0.5, 0, 1)
		swatch.left:SetSize(inner / 2, inner)
		swatch.left:SetPoint('RIGHT', swatch, 'CENTER')
		swatch.right = kit.Disc(swatch, inner, nil, 'ARTWORK', 1)
		swatch.right:SetTexCoord(0.5, 1, 0, 1)
		swatch.right:SetSize(inner / 2, inner)
		swatch.right:SetPoint('LEFT', swatch, 'CENTER')
		return swatch
	end

	function kit.IconAvatar(parent, size, icon)
		local avatar = CreateFrame('Frame', nil, parent)
		avatar:SetSize(size, size)
		kit.Disc(avatar, size, 'secondary'):SetPoint('CENTER')
		kit.Glyph(avatar, icon, 13, 'secondaryText', 'OVERLAY'):SetPoint('CENTER')
		return avatar
	end

	function kit.Initials(parent, size, text, fontRole)
		local avatar = CreateFrame('Frame', nil, parent)
		avatar:SetSize(size, size)
		kit.Disc(avatar, size, 'secondary'):SetPoint('CENTER')
		window:Text(avatar, text, 11, 'secondaryText', fontRole):SetPoint('CENTER')
		return avatar
	end

	function kit.Status(parent, text)
		local status = CreateFrame('Frame', nil, parent)
		kit.Disc(status, 7, 'accent'):SetPoint('LEFT')
		local label = kit.Text(status, text, 12, 'text')
		label:SetPoint('LEFT', 14, 0)
		window:Bind(status, function()
			window:Paint(label, 'text')
			status:SetSize(14 + math.ceil(label:GetStringWidth()), 16)
		end)
		return status
	end

	function kit.RowTitle(row, name, sub, x, width)
		local title = kit.Text(row, name, 12, 'text', width)
		title:SetPoint('LEFT', x, sub and 8 or 0)
		title:SetWordWrap(false)
		local subtitle
		if sub then
			subtitle = kit.Text(row, sub, 11, 'muted', width)
			subtitle:SetPoint('LEFT', x, -9)
			subtitle:SetWordWrap(false)
		end
		return title, subtitle
	end

	function kit.Cell(row, text, x, width)
		local cell = kit.Text(row, text, 11, 'muted', width)
		cell:SetPoint('LEFT', x, 0)
		cell:SetWordWrap(false)
		return cell
	end

	function kit.Search(parent, placeholder, onChange)
		local box = CreateFrame('Frame', nil, parent)
		box:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
		window:Fill(box, 'input'):SetAllPoints()
		local icon = box:CreateTexture(nil, 'ARTWORK')
		icon:SetTexture('Interface\\Common\\UI-Searchbox-Icon')
		icon:SetSize(14, 14)
		icon:SetPoint('LEFT', 12, -1)
		window:Paint(icon, 'faint')
		local edit = CreateFrame('EditBox', nil, box)
		edit:SetPoint('LEFT', icon, 'RIGHT', 8, 1)
		edit:SetPoint('RIGHT', -30, 0)
		edit:SetHeight(20)
		edit:SetAutoFocus(false)
		edit:SetFont(window.font, 12, '')
		window:Paint(edit, 'text')
		window:SetFontRole(edit, 'control')
		local hint = kit.Text(edit, placeholder, 12, 'faint')
		hint:SetPoint('LEFT')
		local clear = CreateFrame('Button', nil, box)
		clear:SetSize(22, 22)
		clear:SetPoint('RIGHT', -6, 0)
		local cross = kit.Glyph(clear, 'clear', 10, 'faint')
		cross:SetPoint('CENTER')
		clear:SetScript('OnEnter', function() window:Paint(cross, 'text') end)
		clear:SetScript('OnLeave', function() window:Paint(cross, 'faint') end)
		clear:Hide()
		local function Changed(self)
			local text = self:GetText()
			hint:SetShown(text == '')
			clear:SetShown(text ~= '')
			onChange(text:lower())
		end
		clear:SetScript('OnClick', function()
			edit:SetText('')
			edit:ClearFocus()
			Changed(edit)
		end)
		edit:SetScript('OnTextChanged', function(self, userInput)
			if userInput then Changed(self) end
		end)
		edit:SetScript('OnEscapePressed', function(self)
			self:SetText('')
			self:ClearFocus()
			Changed(self)
		end)
		edit:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
		box:EnableMouse(true)
		box:SetScript('OnMouseDown', function() edit:SetFocus() end)
		return box
	end

	function kit.Toggle(parent, spec)
		local toggle = Widget.Unwrap(Controls.IconToggle(parent, spec.get(), spec.set, { texture = BUILib.GetLibMedia(spec.icon), tooltip = spec.tooltip, size = TOGGLE_SIZE }))
		window:Bind(toggle, function() toggle:SetValue(spec.get()) end)
		return toggle
	end

	function kit.Header(parent, icon, title, placeholder, onSearch, tools)
		local badge = kit.Disc(parent, 30, 'text')
		badge:SetPoint('TOPLEFT', 0, -2)
		kit.Glyph(parent, icon, 14, 'page', 'OVERLAY'):SetPoint('CENTER', badge)
		kit.Text(parent, title, 22, 'text'):SetPoint('LEFT', badge, 'RIGHT', 12, 0)
		local search = onSearch and kit.Search(parent, placeholder, onSearch)
		if search then search:SetPoint('TOPRIGHT') end
		if tools then
			local anchor, gap = search, TOGGLE_INSET
			for index = #tools, 1, -1 do
				local tool = kit.Tool(parent, tools[index])
				if anchor then
					tool:SetPoint('RIGHT', anchor, 'LEFT', -gap, 0)
				else
					tool:SetPoint('RIGHT', parent, 'TOPRIGHT', 0, -SEARCH_HEIGHT / 2)
				end
				anchor, gap = tool, TOGGLE_GAP
			end
		end
		return SEARCH_HEIGHT
	end

	function kit.Tabs(parent, y, labels, onSelect)
		local rule = kit.DottedRule(parent)
		rule:SetPoint('TOPLEFT', 0, -(y + TAB_HEIGHT))
		rule:SetPoint('TOPRIGHT', 0, -(y + TAB_HEIGHT))
		local tabs, selected, x = {}, 1, 0
		local function Refresh()
			for index, tab in ipairs(tabs) do
				local active = index == selected
				window:Paint(tab.label, (active or tab:IsMouseOver()) and 'text' or 'muted')
				tab.underline:SetShown(active)
			end
		end
		local function Select(index)
			selected = index
			Refresh()
			onSelect(index)
		end
		for index, text in ipairs(labels) do
			local tab = CreateFrame('Button', nil, parent)
			tab.label = kit.Text(tab, text, 13, 'muted', nil, 'title')
			tab.label:SetPoint('TOP', 0, -4)
			tab:SetSize(math.ceil(tab.label:GetStringWidth()), TAB_HEIGHT)
			tab:SetPoint('TOPLEFT', x, -y)
			tab.underline = window:Fill(tab, 'text', 'OVERLAY')
			tab.underline:SetPoint('BOTTOMLEFT', 0, -1)
			tab.underline:SetPoint('BOTTOMRIGHT', 0, -1)
			tab.underline:SetHeight(2)
			tab:SetScript('OnEnter', Refresh)
			tab:SetScript('OnLeave', Refresh)
			tab:SetScript('OnClick', function() Select(index) end)
			tabs[index] = tab
			x = x + tab:GetWidth() + TAB_GAP
		end
		Refresh()
		return y + TAB_HEIGHT + 1, Select
	end

	function kit.DottedRule(parent, role, layer, subLayer)
		local rule = parent:CreateTexture(nil, layer or 'ARTWORK', nil, subLayer or 0)
		rule:SetHeight(1)
		return window:Bind(rule, function(region)
			if window:Separators() == 'solid' then
				region:SetTexture(Widget.WHITE)
				region:SetHorizTile(false)
			else
				region:SetTexture(BUILib.GetLibMedia('dots'), 'REPEAT', 'REPEAT', 'NEAREST')
				region:SetHorizTile(true)
			end
			region:SetVertexColor(window:Color(role or 'dots'))
		end)
	end

	function kit.Section(parent, width, spec)
		local frame = CreateFrame('Frame', nil, parent)
		frame:SetWidth(width)
		local stacked = spec.stacked
		local pad = stacked and STACK_PAD or SECTION_PAD
		local panelX = stacked and 0 or math.floor(width * PANEL_SHARE)
		local section = setmetatable({ window = window, frame = frame, rows = {}, buttons = {}, panelWidth = width - panelX, pad = pad }, Section)

		local title = kit.Text(frame, spec.title, 13, 'text')
		title:SetPoint('TOPLEFT', 0, -(pad + 2))

		for _, buttonSpec in ipairs(spec.buttons or {}) do
			section.buttons[#section.buttons + 1] = kit.Button(frame, buttonSpec.text, buttonSpec.style, buttonSpec.onClick, buttonSpec.icon)
		end
		if stacked then
			for index = #section.buttons - 1, 1, -1 do
				section.buttons[index]:SetPoint('RIGHT', section.buttons[index + 1], 'LEFT', -BUTTON_GAP, 0)
			end
		else
			for index = 2, #section.buttons do
				section.buttons[index]:SetPoint('LEFT', section.buttons[index - 1], 'RIGHT', BUTTON_GAP, 0)
			end
		end

		local description, descriptionGap
		if spec.description then
			descriptionGap = stacked and 8 or 16
			description = kit.Text(frame, spec.description, 12, 'muted')
			description:SetWordWrap(true)
			description:SetSpacing(4)
			description:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -descriptionGap)
		end

		local panel = CreateFrame('Frame', nil, frame)
		panel:SetWidth(section.panelWidth)
		window:Fill(panel, 'panel'):SetAllPoints()
		section.panel = panel

		function section:Measure()
			local buttonsWidth = 0
			if stacked then
				for _, button in ipairs(self.buttons) do buttonsWidth = buttonsWidth + button:GetWidth() + BUTTON_GAP end
			end
			local leftHeight = 2 + kit.Height(title)
			if description then
				description:SetWidth(stacked and (width - buttonsWidth - LEFT_GAP) or math.min(LEFT_WIDTH, panelX - LEFT_GAP))
				leftHeight = leftHeight + descriptionGap + kit.Height(description)
			end
			local rightmost = self.buttons[#self.buttons]
			if stacked and rightmost then
				rightmost:ClearAllPoints()
				rightmost:SetPoint('BOTTOMRIGHT', frame, 'TOPRIGHT', 0, -(pad + leftHeight))
			elseif self.buttons[1] then
				self.buttons[1]:ClearAllPoints()
				self.buttons[1]:SetPoint('TOPLEFT', 0, -(pad + leftHeight + 28))
				leftHeight = leftHeight + 28 + CONTROL_HEIGHT
			end
			self.leftHeight = leftHeight
			self.panelTop = stacked and (pad + leftHeight + STACK_GAP) or pad
			panel:ClearAllPoints()
			panel:SetPoint('TOPLEFT', panelX, -self.panelTop)
		end
		section:Measure()
		for _, column in ipairs(spec.columns or {}) do
			kit.Text(panel, column[1]:upper(), 9, 'faint'):SetPoint('TOPLEFT', column[2], -20)
		end

		local rule = kit.DottedRule(frame)
		rule:SetPoint('BOTTOMLEFT')
		rule:SetPoint('BOTTOMRIGHT')
		return section
	end

	function kit.ColorRow(section, spec)
		local row = section:AddRow(spec.name .. ' ' .. (spec.sub or ''))
		local swatch = kit.Swatch(row, AVATAR_SIZE, function(self) spec.pick(self) end)
		swatch:SetPoint('LEFT', AVATAR_X, 0)
		kit.RowTitle(row, spec.name, spec.sub, NAME_X)
		local hex = kit.Cell(row, '', spec.hexX)
		local opacity = kit.Cell(row, '', spec.opacityX)
		local reset = kit.IconButton(row, 'reset', 'Back to default', spec.reset)
		reset:SetPoint('RIGHT', -(ROW_INSET - 2), 0)
		local dropdown
		dropdown = kit.Dropdown(row, spec.dropdownWidth or DROPDOWN_WIDTH, function() return spec.items(dropdown) end)
		dropdown:SetPoint('RIGHT', reset, 'LEFT', -10, 0)
		kit.Bind(row, function()
			local red, green, blue, alpha = spec.get()
			local custom = spec.custom()
			swatch.fill:SetVertexColor(red, green, blue, alpha)
			hex:SetText(Hex(red, green, blue))
			opacity:SetText(Percent(alpha))
			dropdown.label:SetText(custom and 'Custom' or spec.defaultLabel or 'Default')
			reset:SetActive(custom)
		end)
		return row
	end

	for _, extend in ipairs(Layout.TableKitExtensions) do extend(kit, window) end
	return kit
end

function Layout.PinnedHead(tab, window, kit, spec, block, onSearch)
	local head = CreateFrame('Frame', nil, tab.pinned)
	head:SetPoint('TOPLEFT')
	head:SetSize(tab.width, 1)
	local top = kit.Header(head, spec.icon, spec.title, spec.placeholder, onSearch, spec.tools) + HEADER_GAP
	local rule = kit.DottedRule(head)
	rule:SetPoint('TOPLEFT', 0, -top)
	rule:SetPoint('TOPRIGHT', 0, -top)
	top = top + 1
	if spec.preview then
		local band = CreateFrame('Frame', nil, head)
		band:SetPoint('TOPLEFT', 0, -(top + PREVIEW_GAP))
		band:SetSize(tab.width, spec.preview.height)
		local fill, edge = Widget.DrawCardShape(band, PREVIEW_RADIUS, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
		window:Paint(fill, 'card')
		window:Paint(edge, 'cardEdge')
		spec.preview.build(band, kit)
		top = top + PREVIEW_GAP + spec.preview.height + PREVIEW_GAP
		local under = kit.DottedRule(head)
		under:SetPoint('TOPLEFT', 0, -top)
		under:SetPoint('TOPRIGHT', 0, -top)
		top = top + 1
	end
	tab:SetPinnedHeight(top)
	local function Align()
		local blockLeft, pinnedLeft = block:GetLeft(), tab.pinned:GetLeft()
		if not blockLeft or not pinnedLeft then return end
		head:SetPoint('TOPLEFT', math.floor(blockLeft - pinnedLeft + 0.5), 0)
	end
	tab.frame:HookScript('OnSizeChanged', Align)
	tab.frame:HookScript('OnShow', Align)
	return head, top, Align
end

function Layout.TablePage(tab, shell, spec)
	local kit = Layout.TableKit(shell.window)
	local block = CreateFrame('Frame', nil, tab.child)
	block:SetWidth(tab.width)
	local query, current, contentTop = '', 1, 0
	local panes, labels = {}, {}
	local page = { tabContents = {}, currentTab = 1 }
	local Resize, selectTab
	local _, _, Align = Layout.PinnedHead(tab, shell.window, kit, spec, block, function(text)
		query = text
		Resize()
	end)

	local function Place()
		local y = contentTop
		for _, section in ipairs(panes[current].sections) do y = section:Layout(y, query) end
		return y + BOTTOM_GAP
	end

	for index, pane in ipairs(spec.tabs) do labels[index] = pane.label end
	if #labels > 1 then
		contentTop, selectTab = kit.Tabs(block, 0, labels, function(index)
			panes[current].frame:Hide()
			current = index
			page.currentTab = index
			panes[current].frame:Show()
			Resize()
		end)
	end

	for index, pane in ipairs(spec.tabs) do
		local frame = CreateFrame('Frame', nil, block)
		frame:SetAllPoints()
		frame:SetShown(index == current)
		page.tabContents[index] = true
		panes[index] = { frame = frame, sections = pane.build(kit, shell, frame, tab.width, page) }
	end

	Resize = function()
		local height = Place()
		block:SetHeight(height)
		block.layoutHeight = height
		BUILib.Defer(function()
			Align()
			tab:Refresh()
		end)
	end
	function page:SetTab(index)
		if selectTab and panes[index] then selectTab(index) end
	end
	function page:Resize()
		Resize()
	end
	Resize()
	Layout.Add(tab, block, 8)
	Align()
	tab:Refresh()
	return page
end
