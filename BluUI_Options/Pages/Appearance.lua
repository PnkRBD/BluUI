local BUI = BluUI
local BUILib = BUI.BUILibClient
local Controls, Widget = BUILib.Controls, BUILib.Widget

local SETTINGS_TAB = 1
local FIRST_COLUMN = 370
local SECOND_COLUMN = 450
local CONTROL_WIDTH = 200
local CONTROL_ROOM = 232
local PRESET_DROPDOWN_WIDTH = 140
local SWATCH_SIZE = 28

local PALETTE = {
	{ name = 'Magenta', color = { 0.83, 0, 0.37 } },
	{ name = 'Crimson', color = { 0.86, 0.16, 0.2 } },
	{ name = 'Ember', color = { 0.95, 0.45, 0.15 } },
	{ name = 'Amber', color = { 0.95, 0.7, 0.2 } },
	{ name = 'Lime', color = { 0.55, 0.85, 0.35 } },
	{ name = 'Emerald', color = { 0.2, 0.75, 0.5 } },
	{ name = 'Teal', color = { 0.35, 0.8, 0.8 } },
	{ name = 'Sky', color = { 0.3, 0.62, 0.95 } },
	{ name = 'Cobalt', color = { 0.25, 0.4, 0.95 } },
	{ name = 'Violet', color = { 0.6, 0.45, 0.95 } },
	{ name = 'Rose', color = { 0.92, 0.4, 0.5 } },
	{ name = 'Snow', color = { 0.92, 0.92, 0.95 } },
}

local FONT_OVERRIDES = {
	{ key = 'cdmFont', name = 'Cooldown Manager', sub = 'Keybind and cooldown text on the icons' },
	{ key = 'powerFont', name = 'Power Bar', sub = 'The primary power bar value' },
	{ key = 'secondaryPowerFont', name = 'Class Resources', sub = 'Combo points, runes and the like' },
	{ key = 'trackingFont', name = 'Custom Bars', sub = 'Text on custom tracking bars' },
}

local COLOR_GROUPS = {
	{ name = 'Power', description = 'Shared by the power bars, unit frames and group frames.' },
	{ name = 'Class Resources', description = 'Combo points, runes, holy power and the rest.' },
	{ name = 'Dispel Types', description = 'Used by unit frame and group frame dispel highlights and badges.' },
}

local function Window()
	return BUI.PageEngine.window
end

local function General()
	return BUI.GetDB().general
end

local function Hex(red, green, blue)
	return ('#%02X%02X%02X'):format(math.floor(red * 255 + 0.5), math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5))
end

local function Same(red, green, blue, color)
	return math.abs(red - color[1]) + math.abs(green - color[2]) + math.abs(blue - color[3]) < 0.01
end

local function RefreshAllVisuals()
	BUI.RefreshAllFonts()
	BUI.UnitFrames.InvalidateSettingsCache()
	BUI.UnitFrames:Refresh()
	BUI.UnitFrames.UpdatePreviews()
	BUI.CastBar.RefreshAll()
	BUI.CDM.RefreshAll()
	BUI.CustomBars.RefreshAllBars()
	BUI.Power.Primary.Apply()
	BUI.Power.Secondary.UpdateAppearance()
	BUI.Auras.Update()
	BUI.CombatTimer.ApplySettings()
	BUI.Datatext.Apply()
	BUI.Minimap.ApplySettings()
	BUI.CombatMessage.Refresh()
	BUI.GroupFrames.RefreshAll()
	BUI.BuffTracking.Display.RefreshAll()
	Window():Repaint()
end

local function ApplyAccent()
	BUILib.Colors.RefreshAccent()
	BUI.PageEngine.MarkPagesStale()
end

local function SetAccent(red, green, blue)
	local general = General()
	local color = general.themeColor
	general.useClassColorTheme = false
	color[1], color[2], color[3], color[4] = red, green, blue, 1
	ApplyAccent()
end

local function UseClassColor()
	General().useClassColorTheme = true
	ApplyAccent()
end

local function PickAccent(anchor)
	local general = General()
	local color = general.themeColor
	local red, green, blue = color[1], color[2], color[3]
	local wasClass = general.useClassColorTheme == true
	Controls.OpenColorPicker({
		r = red, g = green, b = blue, a = 1, hasOpacity = false, anchorTo = anchor,
		callback = function(newRed, newGreen, newBlue, _, cancelled, phase)
			if cancelled then
				color[1], color[2], color[3] = red, green, blue
				general.useClassColorTheme = wasClass
			else
				general.useClassColorTheme = false
				color[1], color[2], color[3], color[4] = newRed, newGreen, newBlue, 1
			end
			if phase == 'preview' then Window():Repaint() else ApplyAccent() end
		end,
	})
end

local function SetFont(name)
	General().font = name
	RefreshAllVisuals()
end

local function SetTexture(name)
	General().texture = name
	RefreshAllVisuals()
end

local function SetSmoothBars(value)
	General().smoothBars = value
	local smoothing = value and Enum.StatusBarInterpolation.ExponentialEaseOut or nil
	BUI.GroupFrames.EachChild(function(child)
		if child.Health then child.Health.smoothing = smoothing end
		if child.Power then child.Power.smoothing = smoothing end
	end)
	BUI.UnitFrames.InvalidateSettingsCache()
	BUI.UnitFrames:Refresh()
	Window():Repaint()
end

local function RaidFrames()
	return BUI.GroupFrames.GetDB().raid
end

local function ApplyDeadBackground()
	BUI.GroupFrames.RefreshColors()
	BUI.UnitFrames.RefreshLifeVisuals()
	Window():Repaint()
end

local function SetDeadBackground(value)
	RaidFrames().deadBackground = value
	ApplyDeadBackground()
end

local function ResetDeadColor()
	RaidFrames().deadBackgroundColor = CopyTable(BUI.Defaults.profile.groupFrames.raid.deadBackgroundColor)
	ApplyDeadBackground()
end

local function PickDeadColor(anchor)
	local color = RaidFrames().deadBackgroundColor
	local red, green, blue, alpha = color[1], color[2], color[3], color[4]
	Controls.OpenColorPicker({ r = red, g = green, b = blue, a = alpha, hasOpacity = true, anchorTo = anchor, callback = function(newRed, newGreen, newBlue, newAlpha, cancelled, phase)
		if cancelled then
			color[1], color[2], color[3], color[4] = red, green, blue, alpha
		else
			color[1], color[2], color[3], color[4] = newRed, newGreen, newBlue, newAlpha
		end
		if phase == 'preview' then Window():Repaint() else ApplyDeadBackground() end
	end })
end

local function DeadColorCustom()
	local color, default = RaidFrames().deadBackgroundColor, BUI.Defaults.profile.groupFrames.raid.deadBackgroundColor
	return not (Same(color[1], color[2], color[3], default) and math.abs(color[4] - default[4]) < 0.01)
end

local function AccentName()
	local general = General()
	if general.useClassColorTheme == true then return 'Class color' end
	for _, entry in ipairs(PALETTE) do
		if Same(general.themeColor[1], general.themeColor[2], general.themeColor[3], entry.color) then return entry.name end
	end
	return 'Custom'
end

local function AccentSection(ui, parent, width)
	local window = Window()
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Accent',
		description = 'The highlight color for every BluUI window, tab and control. Class color follows the character you are on.',
		columns = { { 'Name', ui.AVATAR_X }, { 'Hex', FIRST_COLUMN }, { 'Opacity', SECOND_COLUMN } },
	})
	local row = section:AddRow('Accent color class palette custom')
	local swatch = ui.Swatch(row, SWATCH_SIZE, function(self) PickAccent(self) end)
	swatch:SetPoint('LEFT', ui.AVATAR_X, 0)
	ui.RowTitle(row, 'Accent', 'Class color, a palette pick, or any color of your own', ui.NAME_X)
	local hex = ui.Cell(row, '', FIRST_COLUMN)
	local opacity = ui.Cell(row, '', SECOND_COLUMN)
	local reset = ui.IconButton(row, 'reset', 'Back to the class color', UseClassColor)
	reset:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
	local dropdown
	dropdown = ui.Dropdown(row, PRESET_DROPDOWN_WIDTH, function()
		local general = General()
		local name = AccentName()
		local items = { { text = 'Class color', checked = general.useClassColorTheme == true, callback = UseClassColor }, { title = 'Palette' } }
		for _, entry in ipairs(PALETTE) do
			items[#items + 1] = { text = entry.name, checked = name == entry.name, callback = function() SetAccent(entry.color[1], entry.color[2], entry.color[3]) end }
		end
		items[#items + 1] = { separator = true }
		items[#items + 1] = { text = 'Custom color', checked = name == 'Custom', callback = function() PickAccent(dropdown) end }
		return items
	end)
	dropdown:SetPoint('RIGHT', reset, 'LEFT', -10, 0)
	ui.Bind(row, function()
		local red, green, blue = window:Color('accent')
		swatch.fill:SetVertexColor(red, green, blue, 1)
		hex:SetText(Hex(red, green, blue))
		opacity:SetText('100%')
		dropdown.label:SetText(AccentName())
		reset:SetActive(General().useClassColorTheme ~= true)
	end)
	return section
end

local function OnOff(get, set)
	return function()
		local on = get()
		return {
			{ text = 'On', checked = on, callback = function() set(true) end },
			{ text = 'Off', checked = not on, callback = function() set(false) end },
		}
	end
end

local function OptionRow(ui, section, width, spec)
	local row = section:AddRow(spec.name .. ' ' .. spec.sub)
	spec.avatar(row):SetPoint('LEFT', ui.AVATAR_X, 0)
	ui.RowTitle(row, spec.name, spec.sub, ui.NAME_X, width - ui.ROW_INSET * 2 - CONTROL_ROOM - ui.NAME_X)
	local reset = ui.IconButton(row, 'reset', spec.resetTip, spec.reset)
	reset:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
	local dropdown
	dropdown = ui.Dropdown(row, CONTROL_WIDTH, function() return spec.items(dropdown) end)
	dropdown:SetPoint('RIGHT', reset, 'LEFT', -10, 0)
	ui.Bind(row, function()
		dropdown.label:SetText(spec.label())
		reset:SetActive(spec.custom())
	end)
	return row
end

local function FontItems(current, pick)
	local items = {}
	for _, font in ipairs(BUI.BuildFontDropdownItems()) do
		items[#items + 1] = { text = font.text, fontPath = font.fontPath, checked = font.value == current, callback = function() pick(font.value) end }
	end
	return items
end

local function TextSection(ui, parent, width)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Text',
		description = 'The font every module inherits, how it renders, and the modules that use a font of their own.',
		columns = { { 'Name', ui.AVATAR_X } },
	})
	OptionRow(ui, section, width, {
		name = 'Font', sub = 'Every module inherits this unless it picks its own',
		avatar = function(row) return ui.Initials(row, SWATCH_SIZE, 'Aa') end,
		items = function() return FontItems(General().font, SetFont) end,
		label = function() return General().font end,
		custom = function() return General().font ~= BUI.C.DEFAULT_FONT end,
		resetTip = 'Back to the BluUI font', reset = function() SetFont(BUI.C.DEFAULT_FONT) end,
	})
	OptionRow(ui, section, width, {
		name = 'Slug rendering', sub = 'Thicker outline on every BluUI font',
		avatar = function(row) return ui.IconAvatar(row, SWATCH_SIZE, 'glow') end,
		items = OnOff(function() return General().fontSlug == true end, function(value)
			General().fontSlug = value
			RefreshAllVisuals()
		end),
		label = function() return General().fontSlug == true and 'On' or 'Off' end,
		custom = function() return General().fontSlug == true end,
		resetTip = 'Back to the plain outline', reset = function()
			General().fontSlug = false
			RefreshAllVisuals()
		end,
	})
	for _, override in ipairs(FONT_OVERRIDES) do
		local function Pick(name)
			General()[override.key] = name
			RefreshAllVisuals()
		end
		OptionRow(ui, section, width, {
			name = override.name, sub = override.sub,
			avatar = function(row) return ui.Initials(row, SWATCH_SIZE, 'Aa') end,
			items = function()
				local current = General()[override.key]
				local items = FontItems(current, Pick)
				table.insert(items, 1, { text = 'Global font', checked = current == nil, callback = function() Pick(nil) end })
				return items
			end,
			label = function() return General()[override.key] or 'Global font' end,
			custom = function() return General()[override.key] ~= nil end,
			resetTip = 'Back to the global font', reset = function() Pick(nil) end,
		})
	end
	return section
end

local function BarSection(ui, parent, width)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Bars',
		description = 'The texture every statusbar inherits, motion, the tint the gradient texture fades through, and the dead color raid and unit frames share.',
		columns = { { 'Name', ui.AVATAR_X } },
	})
	local sampleBar
	OptionRow(ui, section, width, {
		name = 'Bar texture', sub = 'Every statusbar inherits it unless its page picks another',
		avatar = function(row)
			local sample = CreateFrame('Frame', nil, row)
			sample:SetSize(SWATCH_SIZE, SWATCH_SIZE)
			local track = ui.Fill(sample, 'control', 'ARTWORK')
			track:SetPoint('LEFT')
			track:SetPoint('RIGHT')
			track:SetHeight(10)
			sampleBar = sample:CreateTexture(nil, 'ARTWORK', nil, 1)
			sampleBar:SetPoint('TOPLEFT', track)
			sampleBar:SetPoint('BOTTOMLEFT', track)
			sampleBar:SetWidth(SWATCH_SIZE - 6)
			Window():Paint(sampleBar, 'accent')
			return sample
		end,
		items = function()
			local items = {}
			for _, texture in ipairs(BUI.BuildTextureDropdownItems()) do
				items[#items + 1] = { text = texture.text, checked = texture.value == General().texture, callback = function() SetTexture(texture.value) end }
			end
			return items
		end,
		label = function()
			sampleBar:SetTexture(BUI.GetGlobalTexture())
			return General().texture
		end,
		custom = function() return General().texture ~= BUI.C.DEFAULT_TEXTURE end,
		resetTip = 'Back to the BluUI texture', reset = function() SetTexture(BUI.C.DEFAULT_TEXTURE) end,
	})
	OptionRow(ui, section, width, {
		name = 'Smooth bars', sub = 'Animate health and power changes on the frames',
		avatar = function(row) return ui.IconAvatar(row, SWATCH_SIZE, 'play') end,
		items = OnOff(function() return General().smoothBars ~= false end, SetSmoothBars),
		label = function() return General().smoothBars ~= false and 'On' or 'Off' end,
		custom = function() return General().smoothBars == false end,
		resetTip = 'Back to smooth bars', reset = function() SetSmoothBars(true) end,
	})
	local function PickGradient(anchor)
		local color = General().gradientColor
		local red, green, blue, alpha = color[1], color[2], color[3], color[4]
		Controls.OpenColorPicker({ r = red, g = green, b = blue, a = alpha, hasOpacity = true, anchorTo = anchor, callback = function(newRed, newGreen, newBlue, newAlpha, cancelled, phase)
			if cancelled then
				color[1], color[2], color[3], color[4] = red, green, blue, alpha
			else
				color[1], color[2], color[3], color[4] = newRed, newGreen, newBlue, newAlpha
			end
			if phase == 'preview' then Window():Repaint() else RefreshAllVisuals() end
		end })
	end
	local function ResetGradient()
		General().gradientColor = { 1, 1, 1, 1 }
		RefreshAllVisuals()
	end
	local tintSwatch
	OptionRow(ui, section, width, {
		name = 'Gradient tint', sub = 'Only the ' .. BUI.C.GRADIENT_TEXTURE .. ' texture uses it',
		avatar = function(row)
			tintSwatch = ui.Swatch(row, SWATCH_SIZE, function(self) PickGradient(self) end)
			return tintSwatch
		end,
		items = function(anchor)
			return {
				{ text = 'Default', callback = ResetGradient },
				{ text = 'Custom color', callback = function() PickGradient(anchor) end },
			}
		end,
		label = function()
			local color = General().gradientColor
			tintSwatch.fill:SetVertexColor(color[1], color[2], color[3], color[4])
			return Hex(color[1], color[2], color[3]) .. '  ' .. math.floor(color[4] * 100 + 0.5) .. '%'
		end,
		custom = function()
			local color = General().gradientColor
			return not (Same(color[1], color[2], color[3], { 1, 1, 1 }) and color[4] == 1)
		end,
		resetTip = 'Back to white', reset = ResetGradient,
	})
	local deadSwatch
	OptionRow(ui, section, width, {
		name = 'Dead background', sub = 'Raid frames and unit frames turn this color when the unit is dead',
		avatar = function(row)
			deadSwatch = ui.Swatch(row, SWATCH_SIZE, function(self) PickDeadColor(self) end)
			return deadSwatch
		end,
		items = function(anchor)
			local on = RaidFrames().deadBackground ~= false
			local custom = DeadColorCustom()
			return {
				{ text = 'On', checked = on, callback = function() SetDeadBackground(true) end },
				{ text = 'Off', checked = not on, callback = function() SetDeadBackground(false) end },
				{ title = 'Color' },
				{ text = 'Default', checked = not custom, callback = ResetDeadColor },
				{ text = 'Custom color', checked = custom, callback = function() PickDeadColor(anchor) end },
			}
		end,
		label = function()
			local color = RaidFrames().deadBackgroundColor
			deadSwatch.fill:SetVertexColor(color[1], color[2], color[3], color[4])
			if RaidFrames().deadBackground == false then return 'Off' end
			return Hex(color[1], color[2], color[3]) .. '  ' .. math.floor(color[4] * 100 + 0.5) .. '%'
		end,
		custom = function() return RaidFrames().deadBackground == false or DeadColorCustom() end,
		resetTip = 'Back to the default red',
		reset = function()
			RaidFrames().deadBackground = true
			ResetDeadColor()
		end,
	})
	return section
end

local function ColorSection(ui, parent, width, group, card)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = group.name,
		description = group.description,
		columns = { { 'Name', ui.AVATAR_X }, { 'Hex', FIRST_COLUMN }, { 'Opacity', SECOND_COLUMN } },
		buttons = { { text = 'Reset', icon = 'reset', onClick = function()
			BUI.Colors.ResetGroup(group.name)
			BUI.ApplyColors()
			Window():Repaint()
		end } },
	})
	table.sort(card.colors, function(first, second) return first.label < second.label end)
	for _, entry in ipairs(card.colors) do
		local function Custom()
			local red, green, blue, alpha = entry.get()
			return not (Same(red, green, blue, entry.def) and math.abs(alpha - (entry.def[4] or 1)) < 0.01)
		end
		local function Pick(anchor)
			local red, green, blue, alpha = entry.get()
			Controls.OpenColorPicker({ r = red, g = green, b = blue, a = alpha, hasOpacity = true, anchorTo = anchor, callback = function(newRed, newGreen, newBlue, newAlpha, cancelled, phase)
				if cancelled then
					entry.set(red, green, blue, alpha)
				else
					entry.set(newRed, newGreen, newBlue, newAlpha)
				end
				if phase ~= 'preview' then BUI.ApplyColors() end
				Window():Repaint()
			end })
		end
		local function Reset()
			entry.reset()
			BUI.ApplyColors()
			Window():Repaint()
		end
		ui.ColorRow(section, {
			name = entry.label, sub = Hex(entry.def[1], entry.def[2], entry.def[3]) .. ' by default', hexX = FIRST_COLUMN, opacityX = SECOND_COLUMN,
			get = entry.get, custom = Custom, pick = Pick, reset = Reset,
			items = function(anchor)
				local custom = Custom()
				return {
					{ text = 'Default', checked = not custom, callback = Reset },
					{ text = 'Custom color', checked = custom, callback = function() Pick(anchor) end },
				}
			end,
		})
	end
	return section
end

local function Sections(ui, _, parent, width)
	local sections = {}
	sections[#sections + 1] = AccentSection(ui, parent, width)
	sections[#sections + 1] = TextSection(ui, parent, width)
	sections[#sections + 1] = BarSection(ui, parent, width)
	local cards = {}
	for _, card in ipairs(BUI.Colors.BuildCards()) do cards[card.name] = card end
	for _, group in ipairs(COLOR_GROUPS) do
		if cards[group.name] then sections[#sections + 1] = ColorSection(ui, parent, width, group, cards[group.name]) end
	end
	return sections
end

BUI.AppearancePage = { Sections = Sections }

function BUI.OpenAppearance()
	BUI.PageEngine.Show()
	BUI.PageEngine.NavigateToID('settings')
	local pageConfig = BUI.PageEngine.pages.settings
	local page = pageConfig and pageConfig.frame and pageConfig.frame._page
	if page and page.SetTab then page:SetTab(SETTINGS_TAB) end
end
