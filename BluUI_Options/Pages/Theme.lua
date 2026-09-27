local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout
local Controls = BUILib.Controls
local Widget = BUILib.Widget
local Theme = BUILib.Theme

local FIRST_COLUMN = 267
local SECOND_COLUMN = 344
local DROPDOWN_WIDTH = 112
local PRESET_DROPDOWN_WIDTH = 140
local SWATCH_SIZE = 28
local OPACITY_STEPS = { 100, 98, 95, 90, 85, 80, 70, 50 }

local DIRECTIONS = {
	{ orientation = 'HORIZONTAL', label = 'Left to right' },
	{ orientation = 'VERTICAL', label = 'Top to bottom' },
}

local PRESETS = {
	{ name = 'Solid', note = 'The default color, fully solid', theme = { page = { 0.04, 0.045, 0.05, 1 } } },
	{ name = 'Glass', note = 'Default colors at 98%', theme = {} },
	{ name = 'Black', note = 'Pure black, soft divider', theme = { page = { 0, 0, 0, 1 }, sidebarEdge = { 0.12, 0.12, 0.13, 1 } } },
	{ name = 'Graphite', note = 'Soft grey all over', theme = { page = { 0.11, 0.115, 0.125, 1 }, sidebarEdge = { 0.17, 0.18, 0.2, 1 } } },
	{ name = 'Forest', note = 'Dark green all over', theme = { page = { 0.03, 0.06, 0.045, 1 }, sidebarEdge = { 0.09, 0.17, 0.125, 1 } } },
	{ name = 'Plum', note = 'Dark purple all over', theme = { page = { 0.06, 0.035, 0.075, 1 }, sidebarEdge = { 0.17, 0.1, 0.2, 1 } } },
	{ name = 'White', mode = 'light', note = 'White page, dark text', theme = {} },
}
local PRESET_ROLES = { 'page', 'bar', 'sidebar', 'sidebarEdge' }

local COLOR_SECTIONS = {
	{
		title = 'Surfaces',
		description = 'The page, the sidebar, the panels that hold each table, and the lines between rows and sections.',
		pick = 'Pick page color',
		roles = {
			{ role = 'page', name = 'Page', sub = 'Behind everything in the window', gradient = true },
			{ role = 'sidebar', name = 'Sidebar', sub = 'Behind the page list' },
			{ role = 'sidebarEdge', name = 'Sidebar edge', sub = 'The line beside the page list' },
			{ role = 'panel', name = 'Panels', sub = 'Tables and grouped settings' },
			{ role = 'rule', name = 'Lines', sub = 'Between rows and beside the rail' },
			{ role = 'dots', name = 'Dots', sub = 'Under headers, tabs and sections' },
			{ role = 'input', name = 'Inputs', sub = 'The search field' },
		},
	},
	{
		title = 'Top bar',
		description = 'The strip across the top that holds your portrait, the title and the close button.',
		pick = 'Pick bar color',
		roles = {
			{ role = 'bar', name = 'Bar', sub = 'Fill behind the title' },
			{ role = 'barText', name = 'Title', sub = 'The window name' },
		},
	},
	{
		title = 'Text',
		description = 'Three shades of text carry every page. Keep the shades apart so titles stand out from hints.',
		pick = 'Pick text color',
		roles = {
			{ role = 'text', name = 'Text', sub = 'Titles, names and values' },
			{ role = 'muted', name = 'Descriptions', sub = 'Copy under titles, like this' },
			{ role = 'faint', name = 'Hints', sub = 'Column headings and placeholders' },
		},
	},
	{
		title = 'Controls',
		description = 'Dropdowns and the grey buttons. The colored buttons follow your accent color.',
		pick = 'Pick dropdown color',
		roles = {
			{ role = 'control', name = 'Dropdowns', sub = 'Menus like Default and Custom' },
			{ role = 'secondary', name = 'Buttons', sub = 'Actions like Reset' },
		},
	},
}

local function Window()
	return BUI.PageEngine.window
end

local function Store()
	return BUI.GetDB().windowTheme
end

local function Repaint()
	Window():Repaint()
end

local function Hex(red, green, blue)
	return ('#%02X%02X%02X'):format(math.floor(red * 255 + 0.5), math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5))
end

local function Overrides(create)
	local store, mode = Store(), Window():GetMode()
	if create and not store[mode] then store[mode] = {} end
	return store[mode]
end

local function IsCustom(role)
	local overrides = Overrides()
	return overrides ~= nil and overrides[role] ~= nil
end

local function SetRole(role, color)
	Overrides(true)[role] = color
	Repaint()
end

local function ResetRoles(entries)
	local overrides = Overrides()
	if overrides then
		for _, entry in ipairs(entries) do overrides[entry.role] = nil end
	end
	Repaint()
end

local function PickRole(role, anchor)
	local previous = IsCustom(role) and Overrides()[role] or nil
	local red, green, blue, alpha = Window():Color(role)
	Controls.OpenColorPicker({
		r = red, g = green, b = blue, a = alpha, hasOpacity = true, anchorTo = anchor,
		callback = function(newRed, newGreen, newBlue, newAlpha, cancelled)
			SetRole(role, not cancelled and { newRed, newGreen, newBlue, newAlpha } or previous)
		end,
	})
end

local function Gradient()
	local overrides = Overrides()
	return overrides and overrides.pageGradient
end

local function DirectionLabel(orientation)
	for _, direction in ipairs(DIRECTIONS) do
		if direction.orientation == orientation then return direction.label end
	end
	return 'Off'
end

local function SetGradient(red, green, blue, alpha, orientation)
	local current = Gradient()
	Overrides(true).pageGradient = { red, green, blue, alpha, orientation = orientation or current and current.orientation or 'HORIZONTAL' }
	Repaint()
end

local function ClearGradient()
	local overrides = Overrides()
	if overrides then overrides.pageGradient = nil end
	Repaint()
end

local function SetGradientDirection(orientation)
	local current = Gradient()
	if current then
		current.orientation = orientation
		Repaint()
	else
		local red, green, blue = Theme.GetAccent()
		SetGradient(red, green, blue, 1, orientation)
	end
end

local function PickGradient(anchor)
	local gradient = Gradient()
	local red, green, blue, alpha
	if gradient then
		red, green, blue, alpha = gradient[1], gradient[2], gradient[3], gradient[4]
	else
		red, green, blue, alpha = Theme.GetAccent()
	end
	Controls.OpenColorPicker({ r = red, g = green, b = blue, a = alpha, hasOpacity = true, anchorTo = anchor, callback = function(newRed, newGreen, newBlue, newAlpha, cancelled)
		if cancelled and not gradient then return end
		SetGradient(newRed, newGreen, newBlue, newAlpha)
	end })
end

local function Opacity()
	local _, _, _, alpha = Window():Color('page')
	return math.floor(alpha * 100 + 0.5)
end

local function DefaultOpacity()
	local color = Layout.DefaultColor('page', Window():GetMode())
	return math.floor(color[4] * 100 + 0.5)
end

local function SetOpacity(percent)
	local red, green, blue = Window():Color('page')
	Overrides(true).page = { red, green, blue, percent / 100 }
	Repaint()
end

local function PresetColor(preset, role)
	local color = preset.theme[role] or Layout.DefaultColor(role, preset.mode or 'dark')
	return color[1], color[2], color[3], color[4] or 1
end

local function SameGradient(first, second)
	for index = 1, 4 do
		if math.abs(first[index] - second[index]) > 0.004 then return false end
	end
	return first.orientation == second.orientation
end

local function ActivePreset()
	local window = Window()
	local gradient = Gradient()
	for _, preset in ipairs(PRESETS) do
		local matches = (preset.mode or 'dark') == window:GetMode()
		for _, role in ipairs(PRESET_ROLES) do
			local red, green, blue, alpha = window:Color(role)
			local wantedRed, wantedGreen, wantedBlue, wantedAlpha = PresetColor(preset, role)
			if math.abs(red - wantedRed) + math.abs(green - wantedGreen) + math.abs(blue - wantedBlue) + math.abs(alpha - wantedAlpha) > 0.004 then
				matches = false
			end
		end
		local wanted = preset.theme.pageGradient
		if (wanted == nil) ~= (gradient == nil) or (wanted and not SameGradient(wanted, gradient)) then matches = false end
		if matches then return preset end
	end
end

local function ApplyPreset(preset)
	local store = Store()
	local mode = preset.mode or 'dark'
	local overrides = store[mode]
	store[mode] = { edge = overrides and overrides.edge }
	for role, value in pairs(preset.theme) do store[mode][role] = CopyTable(value) end
	Window():SetMode(mode)
end

local function ResetAll()
	local store = Store()
	store[Window():GetMode()] = nil
	store.edgeAccent = nil
	Repaint()
end

local function ColorRow(ui, section, entry)
	ui.ColorRow(section, {
		name = entry.name, sub = entry.sub, hexX = FIRST_COLUMN, opacityX = SECOND_COLUMN,
		get = function() return Window():Color(entry.role) end,
		state = function() return IsCustom(entry.role) and 'Custom' or 'Default' end,
		pick = function(anchor) PickRole(entry.role, anchor) end,
		reset = function() SetRole(entry.role, nil) end,
		items = function(anchor)
			local custom = IsCustom(entry.role)
			return {
				{ text = 'Default', checked = not custom, callback = function() SetRole(entry.role, nil) end },
				{ text = 'Custom color', checked = custom, callback = function() PickRole(entry.role, anchor) end },
			}
		end,
	})
end

local function PresetSection(ui, parent, width)
	local window = Window()
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Presets',
		description = 'Start from a finished look. A preset keeps your border as it is and clears the other color overrides for that mode.',
		columns = { { 'Preset', ui.AVATAR_X } },
	})
	local row = section:AddRow('Preset look')
	local swatch = ui.SplitSwatch(row, SWATCH_SIZE)
	swatch:SetPoint('LEFT', ui.AVATAR_X, 0)
	ui.RowTitle(row, 'Preset', 'A finished look for the whole window', ui.NAME_X)
	local reset = ui.IconButton(row, 'delete', 'Back to the default colors', ResetAll, 'danger')
	reset:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
	local dropdown = ui.Dropdown(row, PRESET_DROPDOWN_WIDTH, function()
		local active = ActivePreset()
		local items = {}
		for _, preset in ipairs(PRESETS) do
			items[#items + 1] = { text = preset.name, checked = preset == active, callback = function() ApplyPreset(preset) end }
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', reset, 'LEFT', -10, 0)
	ui.Bind(row, function()
		local active = ActivePreset()
		dropdown.label:SetText(active and active.name or 'Custom')
		swatch.left:SetVertexColor(window:Color('page'))
		swatch.right:SetVertexColor(window:Color('text'))
	end)
	return section
end

local function GradientSwatch(ui, row)
	local swatch = CreateFrame('Button', nil, row)
	swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
	local pieces = Widget.DrawRoundedRect(swatch, 4, { 1, 1, 1, 1 }, 'ARTWORK', 1, 0)
	Window():Paint(Widget.DrawOutline(swatch, 4, { 1, 1, 1, 1 }, 'ARTWORK', 2, 0), 'rule')
	swatch:SetScript('OnClick', function(self) PickGradient(self) end)
	ui.Bind(swatch, function()
		local from = { Window():Color('page') }
		local gradient = Gradient()
		Widget.PaintGradientRect(swatch, pieces, gradient and gradient.orientation or 'HORIZONTAL', from, gradient or from)
	end)
	return swatch
end

local function GradientRow(ui, section)
	local row = section:AddRow('Gradient fade second color')
	GradientSwatch(ui, row):SetPoint('LEFT', ui.AVATAR_X, 0)
	ui.RowTitle(row, 'Gradient', 'A second color the page fades into', ui.NAME_X)
	local hex = ui.Cell(row, '', FIRST_COLUMN)
	local direction = ui.Cell(row, '', SECOND_COLUMN)
	local reset = ui.IconButton(row, 'delete', 'Back to a solid fill', ClearGradient, 'danger')
	reset:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
	local dropdown
	dropdown = ui.Dropdown(row, DROPDOWN_WIDTH, function()
		local gradient = Gradient()
		local items = { { text = 'Off', checked = gradient == nil, callback = ClearGradient } }
		for _, entry in ipairs(DIRECTIONS) do
			items[#items + 1] = {
				text = entry.label,
				checked = gradient ~= nil and gradient.orientation == entry.orientation,
				callback = function() SetGradientDirection(entry.orientation) end,
			}
		end
		items[#items + 1] = { text = 'Pick color', callback = function() PickGradient(dropdown) end }
		return items
	end)
	dropdown:SetPoint('RIGHT', reset, 'LEFT', -10, 0)
	ui.Bind(row, function()
		local gradient = Gradient()
		hex:SetText(gradient and Hex(gradient[1], gradient[2], gradient[3]) or '')
		direction:SetText(gradient and DirectionLabel(gradient.orientation) or 'Solid')
		dropdown.label:SetText(gradient and DirectionLabel(gradient.orientation) or 'Off')
	end)
end

local function OpacityRow(ui, section)
	local row = section:AddRow('Opacity see through')
	ui.IconAvatar(row, SWATCH_SIZE, 'eye'):SetPoint('LEFT', ui.AVATAR_X, 0)
	ui.RowTitle(row, 'Opacity', 'How much of the game shows through', ui.NAME_X)
	local value = ui.Cell(row, '', SECOND_COLUMN)
	local reset = ui.IconButton(row, 'delete', 'Back to default', function() SetOpacity(DefaultOpacity()) end, 'danger')
	reset:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
	local dropdown = ui.Dropdown(row, DROPDOWN_WIDTH, function()
		local items = {}
		for _, step in ipairs(OPACITY_STEPS) do
			items[#items + 1] = { text = step .. '%', checked = Opacity() == step, callback = function() SetOpacity(step) end }
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', reset, 'LEFT', -10, 0)
	ui.Bind(row, function()
		value:SetText(Opacity() .. '%')
		dropdown.label:SetText(Opacity() .. '%')
	end)
end

local function ThemeSections(ui, _, parent, width)
	local sections = {}
	sections[#sections + 1] = PresetSection(ui, parent, width)

	for _, spec in ipairs(COLOR_SECTIONS) do
		local section
		section = ui.Section(parent, width, {
		stacked = true,
			title = spec.title,
			description = spec.description,
			columns = { { 'Name', ui.AVATAR_X }, { 'Hex', FIRST_COLUMN }, { 'Opacity', SECOND_COLUMN } },
			buttons = {
				{ text = 'Reset', icon = 'reset', onClick = function() ResetRoles(spec.roles) end },
				{ style = 'primary', text = spec.pick, onClick = function() PickRole(spec.roles[1].role, section.buttons[2]) end },
			},
		})
		for _, entry in ipairs(spec.roles) do
			ColorRow(ui, section, entry)
			if entry.gradient then
				GradientRow(ui, section)
				OpacityRow(ui, section)
			end
		end
		sections[#sections + 1] = section
	end
	return sections
end

BUI.ThemePage = { Sections = ThemeSections }
