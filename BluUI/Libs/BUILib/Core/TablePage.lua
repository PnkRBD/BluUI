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
local ROW_HEIGHT = 57
local ROW_INSET = 20
local CONTROL_HEIGHT = 30
local TAB_HEIGHT = 30
local TAB_GAP = 40
local BUTTON_GAP = 10
local HEADER_GAP = 26
local BOTTOM_GAP = 24
local SEARCH_WIDTH, SEARCH_HEIGHT = 224, 34
local SOLID_HOVER = { 1, 1, 1, 0.12 }
local BUTTON_STYLES = {
	primary = { fill = 'accent', text = 'onAccent', solid = true },
	control = { fill = 'control', text = 'controlText', solid = true },
	secondary = { fill = 'secondary', text = 'secondaryText' },
}

local function Hex(red, green, blue)
	return ('#%02X%02X%02X'):format(math.floor(red * 255 + 0.5), math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5))
end

local function Percent(alpha)
	return ('%d%%'):format(math.floor(alpha * 100 + 0.5))
end

local Section = {}
Section.__index = Section

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
	local shown = 0
	for _, row in ipairs(self.rows) do
		local match = query == '' or row.search:find(query, 1, true) ~= nil
		row.frame:SetShown(match)
		if match then
			row.frame:ClearAllPoints()
			row.frame:SetPoint('TOPLEFT', 0, -(TABLE_HEAD + shown * ROW_HEIGHT))
			row.rule:SetShown(shown > 0)
			shown = shown + 1
		end
	end
	if shown == 0 and query ~= '' then
		self.frame:Hide()
		return y
	end
	local panelHeight = TABLE_HEAD + shown * ROW_HEIGHT
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

	function kit.Text(parent, text, size, role, width)
		local label = window:Text(parent, text, size, role)
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

	function kit.Button(parent, text, style, onClick, icon)
		local look = BUTTON_STYLES[style or 'secondary']
		local button = CreateFrame('Button', nil, parent)
		window:Fill(button, look.fill):SetAllPoints()
		Overlay(button, look.solid)
		local textX = 14
		if icon then
			kit.Glyph(button, icon, 12, look.text):SetPoint('LEFT', 12, 0)
			textX = 32
		end
		local label = kit.Text(button, text, 12, look.text)
		label:SetPoint('LEFT', textX, 0)
		button:SetSize(Widget.EvenSize(textX + label:GetStringWidth() + 14), CONTROL_HEIGHT)
		button:SetScript('OnClick', function() onClick() end)
		function button:SetText(newText)
			label:SetText(newText)
			self:SetWidth(Widget.EvenSize(textX + label:GetStringWidth() + 14))
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
			Controls.ContextMenu(items(), { anchor = self, width = math.max(width, 170), offsetY = -4 })
		end)
		button.label = label
		return button
	end

	function kit.IconButton(parent, icon, tooltip, onClick, hoverRole)
		local button = CreateFrame('Button', nil, parent)
		button:SetSize(22, 22)
		local glyph = kit.Glyph(button, icon, 13, 'faint')
		glyph:SetPoint('CENTER')
		button:SetScript('OnEnter', function(self)
			window:Paint(glyph, hoverRole or 'text')
			Widget.ShowTip(self, tooltip)
		end)
		button:SetScript('OnLeave', function()
			window:Paint(glyph, 'faint')
			Widget.HideTip()
		end)
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

	function kit.Initials(parent, size, text)
		local avatar = CreateFrame('Frame', nil, parent)
		avatar:SetSize(size, size)
		kit.Disc(avatar, size, 'secondary'):SetPoint('CENTER')
		window:Text(avatar, text, 10, 'secondaryText'):SetPoint('CENTER')
		return avatar
	end

	function kit.Status(parent, text)
		local status = CreateFrame('Frame', nil, parent)
		kit.Disc(status, 7, 'accent'):SetPoint('LEFT')
		local label = kit.Text(status, text, 12, 'text')
		label:SetPoint('LEFT', 14, 0)
		status:SetSize(14 + math.ceil(label:GetStringWidth()), 16)
		return status
	end

	function kit.RowTitle(row, name, sub, x, width)
		local title = kit.Text(row, name, 12, 'text', width)
		title:SetPoint('LEFT', x, sub and 8 or 0)
		title:SetWordWrap(false)
		if sub then
			local subtitle = kit.Text(row, sub, 11, 'muted', width)
			subtitle:SetPoint('LEFT', x, -9)
			subtitle:SetWordWrap(false)
		end
		return title
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
		edit:SetPoint('RIGHT', -10, 0)
		edit:SetHeight(20)
		edit:SetAutoFocus(false)
		edit:SetFont(window.font, 12, '')
		window:Paint(edit, 'text')
		local hint = kit.Text(edit, placeholder, 12, 'faint')
		hint:SetPoint('LEFT')
		edit:SetScript('OnTextChanged', function(self)
			local text = self:GetText()
			hint:SetShown(text == '')
			onChange(text:lower())
		end)
		edit:SetScript('OnEscapePressed', function(self)
			self:SetText('')
			self:ClearFocus()
		end)
		edit:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
		box:EnableMouse(true)
		box:SetScript('OnMouseDown', function() edit:SetFocus() end)
		return box
	end

	function kit.Header(parent, icon, title, placeholder, onSearch)
		local badge = kit.Disc(parent, 30, 'text')
		badge:SetPoint('TOPLEFT', 0, -2)
		kit.Glyph(parent, icon, 14, 'page', 'OVERLAY'):SetPoint('CENTER', badge)
		kit.Text(parent, title, 22, 'text'):SetPoint('LEFT', badge, 'RIGHT', 12, 0)
		if onSearch then kit.Search(parent, placeholder, onSearch):SetPoint('TOPRIGHT') end
		return SEARCH_HEIGHT
	end

	function kit.Tabs(parent, y, labels, onSelect)
		local rule = window:Fill(parent, 'rule', 'ARTWORK')
		rule:SetPoint('TOPLEFT', 0, -(y + TAB_HEIGHT))
		rule:SetPoint('TOPRIGHT', 0, -(y + TAB_HEIGHT))
		rule:SetHeight(1)
		local tabs, selected, x = {}, 1, 0
		local function Refresh()
			for index, tab in ipairs(tabs) do
				local active = index == selected
				window:Paint(tab.label, (active or tab:IsMouseOver()) and 'text' or 'muted')
				tab.underline:SetShown(active)
			end
		end
		for index, text in ipairs(labels) do
			local tab = CreateFrame('Button', nil, parent)
			tab.label = kit.Text(tab, text, 13, 'muted')
			tab.label:SetPoint('TOP', 0, -4)
			tab:SetSize(math.ceil(tab.label:GetStringWidth()), TAB_HEIGHT)
			tab:SetPoint('TOPLEFT', x, -y)
			tab.underline = window:Fill(tab, 'text', 'OVERLAY')
			tab.underline:SetPoint('BOTTOMLEFT', 0, -1)
			tab.underline:SetPoint('BOTTOMRIGHT', 0, -1)
			tab.underline:SetHeight(2)
			tab:SetScript('OnEnter', Refresh)
			tab:SetScript('OnLeave', Refresh)
			tab:SetScript('OnClick', function()
				selected = index
				Refresh()
				onSelect(index)
			end)
			tabs[index] = tab
			x = x + tab:GetWidth() + TAB_GAP
		end
		Refresh()
		return y + TAB_HEIGHT + 1
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
		local leftHeight = 2 + kit.Height(title)

		for _, buttonSpec in ipairs(spec.buttons or {}) do
			section.buttons[#section.buttons + 1] = kit.Button(frame, buttonSpec.text, buttonSpec.style, buttonSpec.onClick, buttonSpec.icon)
		end
		local buttonsWidth = 0
		if stacked then
			local anchor
			for index = #section.buttons, 1, -1 do
				local button = section.buttons[index]
				if anchor then
					button:SetPoint('RIGHT', anchor, 'LEFT', -BUTTON_GAP, 0)
				else
					button:SetPoint('TOPRIGHT', 0, -(pad - 6))
				end
				buttonsWidth = buttonsWidth + button:GetWidth() + BUTTON_GAP
				anchor = button
			end
		end

		if spec.description then
			local descriptionGap = stacked and 8 or 16
			local descriptionWidth = stacked and (width - buttonsWidth - LEFT_GAP) or math.min(LEFT_WIDTH, panelX - LEFT_GAP)
			local description = kit.Text(frame, spec.description, 12, 'muted', descriptionWidth)
			description:SetSpacing(4)
			description:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -descriptionGap)
			leftHeight = leftHeight + descriptionGap + kit.Height(description)
		end

		if not stacked and section.buttons[1] then
			for index, button in ipairs(section.buttons) do
				if index == 1 then
					button:SetPoint('TOPLEFT', 0, -(pad + leftHeight + 28))
				else
					button:SetPoint('LEFT', section.buttons[index - 1], 'RIGHT', BUTTON_GAP, 0)
				end
			end
			leftHeight = leftHeight + 28 + CONTROL_HEIGHT
		end
		section.leftHeight = leftHeight
		section.panelTop = stacked and (pad + leftHeight + STACK_GAP) or pad

		local panel = CreateFrame('Frame', nil, frame)
		panel:SetPoint('TOPLEFT', panelX, -section.panelTop)
		panel:SetWidth(section.panelWidth)
		window:Fill(panel, 'panel'):SetAllPoints()
		section.panel = panel
		for _, column in ipairs(spec.columns or {}) do
			kit.Text(panel, column[1]:upper(), 9, 'faint'):SetPoint('TOPLEFT', column[2], -20)
		end

		local rule = window:Fill(frame, 'rule', 'ARTWORK')
		rule:SetPoint('BOTTOMLEFT')
		rule:SetPoint('BOTTOMRIGHT')
		rule:SetHeight(1)
		return section
	end

	function kit.ColorRow(section, spec)
		local row = section:AddRow(spec.name .. ' ' .. (spec.sub or ''))
		local swatch = kit.Swatch(row, AVATAR_SIZE, function(self) spec.pick(self) end)
		swatch:SetPoint('LEFT', AVATAR_X, 0)
		kit.RowTitle(row, spec.name, spec.sub, NAME_X)
		local hex = kit.Cell(row, '', spec.hexX)
		local opacity = kit.Cell(row, '', spec.opacityX)
		local reset = kit.IconButton(row, 'delete', 'Back to default', spec.reset, 'danger')
		reset:SetPoint('RIGHT', -(ROW_INSET - 2), 0)
		local dropdown
		dropdown = kit.Dropdown(row, spec.dropdownWidth or DROPDOWN_WIDTH, function() return spec.items(dropdown) end)
		dropdown:SetPoint('RIGHT', reset, 'LEFT', -10, 0)
		kit.Bind(row, function()
			local red, green, blue, alpha = spec.get()
			swatch.fill:SetVertexColor(red, green, blue, alpha)
			hex:SetText(Hex(red, green, blue))
			opacity:SetText(Percent(alpha))
			dropdown.label:SetText(spec.state())
		end)
		return row
	end

	return kit
end

function Layout.TablePage(tab, shell, spec)
	local kit = Layout.TableKit(shell.window)
	local block = CreateFrame('Frame', nil, tab.child)
	block:SetWidth(tab.width)
	local query, current, contentTop = '', 1, 0
	local panes, labels = {}, {}
	local Resize

	local function Place()
		local y = contentTop
		for _, section in ipairs(panes[current].sections) do y = section:Layout(y, query) end
		return y + BOTTOM_GAP
	end

	local function Commit(height)
		block:SetHeight(height)
		block.layoutHeight = height
	end

	local y = kit.Header(block, spec.icon, spec.title, spec.placeholder, function(text)
		query = text
		Resize()
	end)
	for index, pane in ipairs(spec.tabs) do labels[index] = pane.label end
	if #labels > 1 then
		contentTop = kit.Tabs(block, y + HEADER_GAP, labels, function(index)
			panes[current].frame:Hide()
			current = index
			panes[current].frame:Show()
			Resize()
		end)
	else
		local rule = shell.window:Fill(block, 'rule', 'ARTWORK')
		rule:SetPoint('TOPLEFT', 0, -(y + HEADER_GAP))
		rule:SetPoint('TOPRIGHT', 0, -(y + HEADER_GAP))
		rule:SetHeight(1)
		contentTop = y + HEADER_GAP + 1
	end

	for index, pane in ipairs(spec.tabs) do
		local frame = CreateFrame('Frame', nil, block)
		frame:SetAllPoints()
		frame:SetShown(index == current)
		panes[index] = { frame = frame, sections = pane.build(kit, shell, frame, tab.width) }
	end

	Commit(Place())
	Layout.Add(tab, block, 8)
	Resize = function()
		Commit(Place())
		BUILib.Defer(function() tab:Refresh() end)
	end
end
