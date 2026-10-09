local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout
local Controls = BUILib.Controls
local Modals = BUILib.Modals
local Toast = BUILib.Toast

local FIRST_COLUMN = 370
local SECOND_COLUMN = 450
local COLORS_COLUMN = 267
local FONTS_COLUMN = 344
local DROPDOWN_WIDTH = 112
local PRESET_DROPDOWN_WIDTH = 140
local SWATCH_SIZE = 28
local FONT_DROPDOWN_WIDTH = 200
local OPACITY_STEPS = { 100, 98, 95, 90, 85, 80, 70, 50 }
local WINDOW_SCALE_STEPS = { 120, 110, 100, 95, 90, 85, 80, 75, 70 }

local DEFAULT_PAGE = Layout.DefaultColor('page', 'dark')
local SHELL_FILL = { unpack(Layout.DefaultColor('skinBackground', 'dark')) }
local SHELL_EDGE = { unpack(Layout.DefaultColor('skinBorder', 'dark')) }
local SHELL_TILE = { 0.03, 0.03, 0.036, 1 }
local PRESETS = {
	{ name = 'Glass', theme = {} },
	{ name = 'Solid', theme = { page = { DEFAULT_PAGE[1], DEFAULT_PAGE[2], DEFAULT_PAGE[3], 1 } } },
	{ name = 'Black', theme = { page = { 0, 0, 0, 1 }, sidebarEdge = { 0.12, 0.12, 0.13, 1 } } },
	{ name = 'Installer', theme = { page = SHELL_FILL, sidebarEdge = SHELL_EDGE, panel = SHELL_TILE, card = SHELL_TILE, cardEdge = SHELL_EDGE } },
	{ name = 'Graphite', theme = { page = { 0.11, 0.115, 0.125, 1 }, sidebarEdge = { 0.17, 0.18, 0.2, 1 } } },
	{ name = 'Forest', theme = { page = { 0.03, 0.06, 0.045, 1 }, sidebarEdge = { 0.09, 0.17, 0.125, 1 } } },
	{ name = 'Plum', theme = { page = { 0.06, 0.035, 0.075, 1 }, sidebarEdge = { 0.17, 0.1, 0.2, 1 } } },
}
local PRESET_ROLES = { 'page', 'bar', 'sidebar', 'sidebarEdge' }
local FONT_ROLES = {
	{ role = 'title', name = 'Titles', sub = 'Bold text: headings, names and the window name' },
	{ role = 'body', name = 'Descriptions', sub = 'Copy under titles and values in tables' },
	{ role = 'hint', name = 'Hints', sub = 'Column headings, captions and placeholders' },
	{ role = 'control', name = 'Controls', sub = 'Dropdowns, buttons and the search field' },
}

local COLOR_SECTIONS = {
	{
		title = 'Surfaces',
		description = 'The page, the sidebar, the panels and cards that hold content, and the lines between rows and sections.',
		separators = true,
		roles = {
			{ role = 'page', name = 'Page', sub = 'Behind everything in the window', opacity = true },
			{ role = 'sidebar', name = 'Sidebar', sub = 'Behind the page list' },
			{ role = 'sidebarEdge', name = 'Sidebar edge', sub = 'The line beside the page list' },
			{ role = 'panel', name = 'Panels', sub = 'Tables and grouped settings' },
			{ role = 'card', name = 'Cards', sub = 'Dashboard, help and profile cards' },
			{ role = 'cardEdge', name = 'Card outline', sub = 'The thin line around each card' },
			{ role = 'rule', name = 'Lines', sub = 'Between rows and beside the rail' },
			{ role = 'dots', name = 'Dots', sub = 'Under headers, tabs and sections' },
			{ role = 'input', name = 'Inputs', sub = 'The search field' },
		},
	},
	{
		title = 'Top bar',
		description = 'The strip across the top that holds your portrait, the title and the close button.',
		roles = {
			{ role = 'bar', name = 'Bar', sub = 'Fill behind the title' },
			{ role = 'barText', name = 'Title', sub = 'The window name' },
		},
	},
	{
		title = 'Text',
		description = 'Three shades of text carry every page. Keep the shades apart so titles stand out from hints.',
		roles = {
			{ role = 'text', name = 'Text', sub = 'Titles, names and values' },
			{ role = 'muted', name = 'Descriptions', sub = 'Copy under titles, like this' },
			{ role = 'faint', name = 'Hints', sub = 'Column headings and placeholders' },
		},
	},
	{
		title = 'Controls',
		description = 'Dropdowns and the grey buttons. The colored buttons follow your accent color.',
		roles = {
			{ role = 'control', name = 'Dropdowns', sub = 'Menus like Default and Custom' },
			{ role = 'secondary', name = 'Buttons', sub = 'Actions like Reset' },
		},
	},
	{
		title = 'Blizzard windows',
		description = 'Every skinned game window, like the character sheet, Adventure Guide and Group Finder. Changes show straight away.',
		roles = {
			{ role = 'skinBackground', name = 'Background', sub = 'Behind every skinned window', opacity = true },
			{ role = 'skinBorder', name = 'Borders', sub = 'Window, button and icon outlines' },
			{ role = 'skinLine', name = 'Lines', sub = 'Dividers under titles', opacity = true },
			{ role = 'skinTitle', name = 'Titles', sub = 'Headings and names' },
			{ role = 'skinText', name = 'Text', sub = 'Body text and buttons' },
			{ role = 'skinLabel', name = 'Labels', sub = 'Captions and disabled text' },
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
	BUI.Painter.Repaint()
end

local function Hex(red, green, blue)
	return ('#%02X%02X%02X'):format(math.floor(red * 255 + 0.5), math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5))
end

local function Trim(text)
	return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function ToastOptions()
	return { style = 'bar', position = 'bottom', parent = Window().frame }
end

local function Touch()
	Store().name = nil
	Repaint()
end

local function Overrides(create)
	local store, mode = Store(), Window():GetMode()
	if create and not store[mode] then store[mode] = {} end
	return store[mode]
end

local function HasOverrides()
	local overrides = Overrides()
	return (overrides ~= nil and next(overrides) ~= nil) or Store().edgeAccent ~= nil
end

local function IsCustom(role)
	local overrides = Overrides()
	return overrides ~= nil and overrides[role] ~= nil
end

local function SetRole(role, color)
	Overrides(true)[role] = color
	Touch()
end

local function ResetRoles(entries)
	local overrides = Overrides()
	if overrides then
		for _, entry in ipairs(entries) do overrides[entry.role] = nil end
	end
	Touch()
end

local function PickRole(role, anchor)
	local current = IsCustom(role) and Overrides()[role] or nil
	local previous = current and CopyTable(current) or nil
	local red, green, blue, alpha = Window():Color(role)
	Controls.OpenColorPicker({
		r = red, g = green, b = blue, a = alpha, hasOpacity = true, anchorTo = anchor,
		callback = function(newRed, newGreen, newBlue, newAlpha, cancelled)
			if cancelled then return SetRole(role, previous) end
			local color = Overrides(true)[role]
			if not color then return SetRole(role, { newRed, newGreen, newBlue, newAlpha }) end
			color[1], color[2], color[3], color[4] = newRed, newGreen, newBlue, newAlpha
			Touch()
		end,
	})
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
	Touch()
end

local function PresetColor(preset, role)
	local color = preset.theme[role] or Layout.DefaultColor(role, 'dark')
	return color[1], color[2], color[3], color[4] or 1
end

local function PresetMatches(preset)
	local window = Window()
	if window:GetMode() ~= 'dark' then return false end
	for _, role in ipairs(PRESET_ROLES) do
		local red, green, blue, alpha = window:Color(role)
		local wantedRed, wantedGreen, wantedBlue, wantedAlpha = PresetColor(preset, role)
		if math.abs(red - wantedRed) + math.abs(green - wantedGreen) + math.abs(blue - wantedBlue) + math.abs(alpha - wantedAlpha) > 0.004 then return false end
	end
	return true
end

local function ActivePreset()
	for _, preset in ipairs(PRESETS) do
		if PresetMatches(preset) then return preset end
	end
end

local function ApplyPreset(preset)
	local store = Store()
	local overrides = store.dark
	store.dark = { edge = overrides and overrides.edge }
	for role, value in pairs(preset.theme) do store.dark[role] = CopyTable(value) end
	store.name = preset.name
	Window():SetMode('dark')
end

local function ResetAll()
	local store = Store()
	store[Window():GetMode()] = nil
	store.edgeAccent = nil
	Touch()
end

local function FontName(role)
	local fonts = Store().fonts
	return fonts and fonts[role]
end

local function SetFontRole(role, name, page)
	local store = Store()
	store.fonts = store.fonts or {}
	if role == 'base' and name == BUI.C.WINDOW_FONT then name = nil end
	store.fonts[role] = name
	store.name = nil
	if role == 'base' then BUI.ApplyWindowFont() else Repaint() end
	page:Resize()
end

local function ResetFonts(page)
	local store = Store()
	store.fonts = nil
	store.name = nil
	BUI.ApplyWindowFont()
	page:Resize()
end

local function EffectiveFont(role)
	return FontName(role) or FontName('base') or BUI.C.WINDOW_FONT
end

local function SavedThemes()
	return BUI.db.global.savedThemes
end

local function FindSaved(name)
	for index, saved in ipairs(SavedThemes()) do
		if saved.name == name then return index, saved end
	end
end

local function ActiveLook()
	local store = Store()
	local name = store.name
	if name then
		for _, preset in ipairs(PRESETS) do
			if preset.name == name and PresetMatches(preset) then return preset end
		end
		local _, saved = FindSaved(name)
		if saved and BUI.SameThemeLook(saved.theme, store) then return saved end
	end
	local preset = ActivePreset()
	if preset then return preset end
	for _, saved in ipairs(SavedThemes()) do
		if BUI.SameThemeLook(saved.theme, store) then return saved end
	end
end

local function CurrentLook()
	local theme = CopyTable(Store())
	theme.name = nil
	return theme
end

local function ApplySaved(saved, page)
	local store = Store()
	wipe(store)
	for key, value in pairs(CopyTable(saved.theme)) do store[key] = value end
	store.name = saved.name
	BUI.ApplyWindowFont()
	page:Resize()
end

local function Keep(name, theme, page, adopt)
	local _, existing = FindSaved(name)
	local function Write()
		local saved = SavedThemes()
		local entry = existing or {}
		entry.name, entry.theme, entry.time = name, theme, time()
		if not existing then saved[#saved + 1] = entry end
		if adopt then Store().name = name end
		page:RebuildCurrent()
		Toast.Success(existing and 'Theme replaced' or 'Theme saved', name, ToastOptions())
	end
	if not existing then return Write() end
	Modals.Confirm({
		title = 'Replace theme',
		message = '"' .. name .. '" is already saved. Replace it with this look?',
		confirmText = 'Replace',
		onConfirm = Write,
	})
end

local function AskName(title, message, defaultName, onName)
	Modals.Input({
		title = title,
		message = message,
		defaultText = defaultName,
		confirmText = 'Save',
		onConfirm = function(text)
			local name = Trim(text)
			if name ~= '' then onName(name) end
		end,
	})
end

local function SaveCurrent(page)
	AskName('Save theme', 'Name the look you have now.', '', function(name) Keep(name, CurrentLook(), page, true) end)
end

local function ImportTheme(page)
	Modals.Input({
		title = 'Import theme',
		message = 'Paste a BluUI theme string.',
		confirmText = 'Import',
		onConfirm = function(text)
			local theme, detail = BUI.ExportImport.DecodeTheme(text)
			if not theme then
				Toast.Error('Import failed', detail, ToastOptions())
				return
			end
			AskName('Name the theme', 'It goes into your saved themes, ready to apply.', detail or 'Imported', function(name) Keep(name, theme, page) end)
		end,
	})
end

local function ExportSaved(saved)
	Modals.Copy({
		title = 'Export "' .. saved.name .. '"',
		message = 'The string is selected. Press Ctrl+C to copy it.',
		text = BUI.ExportImport.ExportTheme(saved.name, saved.theme),
	})
end

local function ExportCurrent()
	local look = ActiveLook()
	Modals.Copy({
		title = 'Export theme',
		message = 'The string is selected. Press Ctrl+C to copy it.',
		text = BUI.ExportImport.ExportTheme(look and look.name or 'Theme', Store()),
	})
end

local function ForgetSaved(index, saved, page)
	Modals.Confirm({
		title = 'Forget theme',
		message = 'Remove "' .. saved.name .. '" from your saved themes?',
		confirmText = 'Remove',
		onConfirm = function()
			table.remove(SavedThemes(), index)
			page:RebuildCurrent()
		end,
	})
end

local function Count(map)
	local count = 0
	if map then
		for _ in pairs(map) do count = count + 1 end
	end
	return count
end

local function CountText(count)
	return count > 0 and (count .. ' custom') or 'Default'
end

local function SavedColor(theme, role)
	local color = theme.dark and theme.dark[role] or Layout.DefaultColor(role, 'dark')
	return color[1], color[2], color[3], color[4] or 1
end

local function ColorRow(ui, section, entry)
	ui.ColorRow(section, {
		name = entry.name, sub = entry.sub, hexX = FIRST_COLUMN, opacityX = SECOND_COLUMN,
		get = function() return Window():Color(entry.role) end,
		custom = function() return IsCustom(entry.role) end,
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

local function WindowScale()
	return BUI.db.global.windowScale
end

local function WindowSection(ui, parent, width)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Window',
		description = 'How big this settings window is on your screen. Every page, menu and popup scales with it.',
		columns = { { 'Name', ui.AVATAR_X }, { 'Size', SECOND_COLUMN } },
	})
	local row = section:AddRow('Window size scale smaller bigger')
	ui.IconAvatar(row, SWATCH_SIZE, 'resize'):SetPoint('LEFT', ui.AVATAR_X, 0)
	ui.RowTitle(row, 'Size', 'Shrink or grow the whole window', ui.NAME_X)
	local value = ui.Cell(row, '', SECOND_COLUMN)
	local reset = ui.IconButton(row, 'reset', 'Back to full size', function() BUI.PageEngine.SetWindowScale(100) Repaint() end)
	reset:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
	local dropdown = ui.Dropdown(row, DROPDOWN_WIDTH, function()
		local items = {}
		for _, step in ipairs(WINDOW_SCALE_STEPS) do
			items[#items + 1] = { text = step .. '%', checked = WindowScale() == step, callback = function()
				BUI.PageEngine.SetWindowScale(step)
				Repaint()
			end }
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', reset, 'LEFT', -10, 0)
	ui.Bind(row, function()
		value:SetText(WindowScale() .. '%')
		dropdown.label:SetText(WindowScale() .. '%')
		reset:SetActive(WindowScale() ~= 100)
	end)
	return section
end

local function PresetSection(ui, parent, width, page)
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
	local reset = ui.IconButton(row, 'reset', 'Back to the default colors', ResetAll)
	reset:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
	local dropdown = ui.Dropdown(row, PRESET_DROPDOWN_WIDTH, function()
		local active = ActiveLook()
		local items = {}
		for _, preset in ipairs(PRESETS) do
			items[#items + 1] = { text = preset.name, checked = preset == active, callback = function() ApplyPreset(preset) end }
		end
		local saved = SavedThemes()
		if #saved > 0 then
			items[#items + 1] = { title = 'Saved' }
			for _, entry in ipairs(saved) do
				items[#items + 1] = { text = entry.name, checked = entry == active, callback = function() ApplySaved(entry, page) end }
			end
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', reset, 'LEFT', -10, 0)
	ui.Bind(row, function()
		local active = ActiveLook()
		dropdown.label:SetText(active and active.name or 'Custom')
		reset:SetActive(HasOverrides())
		swatch.left:SetVertexColor(window:Color('page'))
		swatch.right:SetVertexColor(window:Color('text'))
	end)
	return section
end

local function SavedSection(ui, parent, width, page)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Saved themes',
		description = 'Keep the look you have now under a name, bring it back later, or pass it on as a string.',
		columns = { { 'Name', ui.AVATAR_X }, { 'Colors', COLORS_COLUMN }, { 'Fonts', FONTS_COLUMN } },
		buttons = {
			{ text = 'Import', onClick = function() ImportTheme(page) end },
			{ text = 'Export', icon = 'copy', onClick = ExportCurrent },
			{ style = 'primary', text = 'Save current', icon = 'save', onClick = function() SaveCurrent(page) end },
		},
	})
	local saved = SavedThemes()
	if #saved == 0 then
		local row = section:AddRow('nothing saved yet')
		ui.RowTitle(row, 'Nothing saved yet', 'Save current keeps the look you have now', ui.AVATAR_X)
	end
	for index, entry in ipairs(saved) do
		local row = section:AddRow(entry.name)
		local swatch = ui.SplitSwatch(row, SWATCH_SIZE)
		swatch:SetPoint('LEFT', ui.AVATAR_X, 0)
		swatch.left:SetVertexColor(SavedColor(entry.theme, 'page'))
		swatch.right:SetVertexColor(SavedColor(entry.theme, 'text'))
		ui.RowTitle(row, entry.name, 'Saved ' .. date('%d %b %Y', entry.time), ui.NAME_X)
		ui.Cell(row, CountText(Count(entry.theme.dark)), COLORS_COLUMN)
		ui.Cell(row, CountText(Count(entry.theme.fonts)), FONTS_COLUMN)
		local forget = ui.IconButton(row, 'delete', 'Forget this theme', function() ForgetSaved(index, entry, page) end, 'danger')
		forget:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
		local export = ui.Button(row, 'Export', 'secondary', function() ExportSaved(entry) end, 'copy')
		export:SetPoint('RIGHT', forget, 'LEFT', -10, 0)
		local apply = ui.Button(row, 'Apply', 'primary', function() ApplySaved(entry, page) end)
		apply:SetPoint('RIGHT', export, 'LEFT', -10, 0)
		local applied = ui.Status(row, 'Applied')
		applied:SetPoint('RIGHT', export, 'LEFT', -14, 0)
		ui.Bind(row, function()
			local active = ActiveLook() == entry
			apply:SetShown(not active)
			applied:SetShown(active)
		end)
	end
	return section
end

local SEPARATORS = {
	{ value = 'dotted', text = 'Dotted' },
	{ value = 'solid', text = 'Solid' },
}

local function SeparatorName(value)
	for _, entry in ipairs(SEPARATORS) do
		if entry.value == value then return entry.text end
	end
end

local function SetSeparators(value)
	Store().separators = value ~= 'dotted' and value or nil
	Touch()
end

local function SeparatorRow(ui, section)
	local row = section:AddRow('Separators dotted solid lines')
	ui.IconAvatar(row, SWATCH_SIZE, 'more'):SetPoint('LEFT', ui.AVATAR_X, 0)
	ui.RowTitle(row, 'Separators', 'The lines under headers, tabs and sections', ui.NAME_X)
	local value = ui.Cell(row, '', SECOND_COLUMN)
	local reset = ui.IconButton(row, 'reset', 'Back to dotted', function() SetSeparators('dotted') end)
	reset:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
	local dropdown = ui.Dropdown(row, DROPDOWN_WIDTH, function()
		local current = Window():Separators()
		local items = {}
		for _, entry in ipairs(SEPARATORS) do
			items[#items + 1] = { text = entry.text, checked = entry.value == current, callback = function() SetSeparators(entry.value) end }
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', reset, 'LEFT', -10, 0)
	ui.Bind(row, function()
		local current = Window():Separators()
		value:SetText(SeparatorName(current))
		dropdown.label:SetText(SeparatorName(current))
		reset:SetActive(current ~= 'dotted')
	end)
end

local function OpacityRow(ui, section)
	local row = section:AddRow('Opacity see through')
	ui.IconAvatar(row, SWATCH_SIZE, 'eye'):SetPoint('LEFT', ui.AVATAR_X, 0)
	ui.RowTitle(row, 'Opacity', 'How much of the game shows through', ui.NAME_X)
	local value = ui.Cell(row, '', SECOND_COLUMN)
	local reset = ui.IconButton(row, 'reset', 'Back to default', function() SetOpacity(DefaultOpacity()) end)
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
		reset:SetActive(Opacity() ~= DefaultOpacity())
	end)
end

local function FontRow(ui, section, page, role, name, sub, avatar, sameAs)
	local row = section:AddRow(name .. ' ' .. sub)
	avatar(row):SetPoint('LEFT', ui.AVATAR_X, 0)
	ui.RowTitle(row, name, sub, ui.NAME_X)
	local reset = ui.IconButton(row, 'reset', sameAs and 'Back to the main font' or 'Back to the BluUI font', function() SetFontRole(role, nil, page) end)
	reset:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
	local dropdown = ui.Dropdown(row, FONT_DROPDOWN_WIDTH, function()
		local current = FontName(role)
		local items = {}
		if sameAs then
			items[1] = { text = sameAs, checked = current == nil, callback = function() SetFontRole(role, nil, page) end }
		else
			current = EffectiveFont(role)
		end
		for _, font in ipairs(BUI.BuildFontDropdownItems()) do
			items[#items + 1] = { text = font.text, fontPath = font.fontPath, checked = font.value == current, callback = function() SetFontRole(role, font.value, page) end }
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', reset, 'LEFT', -10, 0)
	ui.Bind(row, function()
		dropdown.label:SetText(EffectiveFont(role))
		reset:SetActive(FontName(role) ~= nil)
	end)
end

local function FontSection(ui, parent, width, page)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Fonts',
		description = 'Pick a font for the whole window, then give any kind of text its own face if you want.',
		columns = { { 'Name', ui.AVATAR_X } },
		buttons = { { text = 'Reset', icon = 'reset', onClick = function() ResetFonts(page) end } },
	})
	FontRow(ui, section, page, 'base', 'Font', 'Every kind of text, unless it picks its own below', function(row) return ui.IconAvatar(row, SWATCH_SIZE, 'text') end)
	for _, entry in ipairs(FONT_ROLES) do
		FontRow(ui, section, page, entry.role, entry.name, entry.sub, function(row) return ui.Initials(row, SWATCH_SIZE, 'Aa', entry.role) end, 'Same as Font')
	end
	return section
end

local function ThemeSections(ui, _, parent, width, page)
	local sections = {}
	sections[#sections + 1] = WindowSection(ui, parent, width)
	sections[#sections + 1] = PresetSection(ui, parent, width, page)
	sections[#sections + 1] = SavedSection(ui, parent, width, page)
	sections[#sections + 1] = FontSection(ui, parent, width, page)

	for _, spec in ipairs(COLOR_SECTIONS) do
		local section = ui.Section(parent, width, {
			stacked = true,
			title = spec.title,
			description = spec.description,
			columns = { { 'Name', ui.AVATAR_X }, { 'Hex', FIRST_COLUMN }, { 'Opacity', SECOND_COLUMN } },
			buttons = {
				{ text = 'Reset', icon = 'reset', onClick = function() ResetRoles(spec.roles) end },
			},
		})
		for _, entry in ipairs(spec.roles) do
			ColorRow(ui, section, entry)
			if entry.opacity then OpacityRow(ui, section) end
		end
		if spec.separators then SeparatorRow(ui, section) end
		sections[#sections + 1] = section
	end
	return sections
end

BUI.ThemePage = { Sections = ThemeSections }
