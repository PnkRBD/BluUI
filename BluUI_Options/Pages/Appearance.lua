local BUI = BluUI
local BUILib = BUI.BUILibClient
local Controls, Widget = BUILib.Controls, BUILib.Widget
local sharedMedia = LibStub('LibSharedMedia-3.0')

local SETTINGS_TAB = 1
local FIRST_COLUMN = 267
local SECOND_COLUMN = 344
local DROPDOWN_WIDTH = 112
local FONT_DROPDOWN_WIDTH = 200
local SWATCH_SIZE = 28
local STAGE_HEIGHT = 118
local STAGE_PAD = 20
local BAR_HEIGHT = 16
local PREVIEW_GAP = 24

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
	Window():Repaint()
end

local function SetAccent(red, green, blue)
	local general = General()
	general.useClassColorTheme = false
	general.themeColor = { red, green, blue, 1 }
	ApplyAccent()
end

local function UseClassColor()
	General().useClassColorTheme = true
	ApplyAccent()
end

local function PickAccent(anchor)
	local color = General().themeColor
	Controls.OpenColorPicker({
		r = color[1], g = color[2], b = color[3], a = 1, hasOpacity = false, anchorTo = anchor,
		callback = function(red, green, blue, _, cancelled)
			if not cancelled then SetAccent(red, green, blue) end
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

local function Stage(ui, parent, width)
	local window = Window()
	local frame = CreateFrame('Frame', nil, parent)
	frame:SetSize(width, STAGE_HEIGHT + PREVIEW_GAP)
	local stage = CreateFrame('Frame', nil, frame)
	stage:SetPoint('TOPLEFT')
	stage:SetSize(width, STAGE_HEIGHT)
	for _, piece in ipairs(Widget.DrawRoundedRect(stage, 8, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)) do window:Paint(piece, 'input') end
	ui.Text(stage, 'PREVIEW', 9, 'faint'):SetPoint('TOPLEFT', STAGE_PAD, -14)
	local note = ui.Text(stage, '', 10, 'faint')
	note:SetPoint('TOPRIGHT', -STAGE_PAD, -14)

	local barWidth = math.floor((width - STAGE_PAD * 3) / 2)
	local function Bar(x, y, fraction, label, role)
		local track = ui.Fill(stage, 'control', 'ARTWORK')
		track:SetPoint('TOPLEFT', x, -y)
		track:SetSize(barWidth, BAR_HEIGHT)
		local fill = stage:CreateTexture(nil, 'ARTWORK', nil, 1)
		fill:SetPoint('TOPLEFT', track)
		fill:SetSize(math.floor(barWidth * fraction), BAR_HEIGHT)
		window:Paint(fill, role)
		local text = stage:CreateFontString(nil, 'OVERLAY')
		text:SetFont(window.font, 11, '')
		text:SetPoint('LEFT', track, 'LEFT', 8, 0)
		text:SetText(label)
		window:Paint(text, 'text')
		local value = stage:CreateFontString(nil, 'OVERLAY')
		value:SetFont(window.font, 11, '')
		value:SetPoint('RIGHT', track, 'RIGHT', -8, 0)
		value:SetText(('%d%%'):format(fraction * 100))
		window:Paint(value, 'text')
		return fill, text, value
	end
	local health, healthText, healthValue = Bar(STAGE_PAD, 40, 0.84, 'Health', 'accent')
	local power, powerText, powerValue = Bar(STAGE_PAD * 2 + barWidth, 40, 0.62, 'Power', 'accent')
	local cooldown = stage:CreateFontString(nil, 'OVERLAY')
	cooldown:SetFont(window.font, 18, '')
	cooldown:SetPoint('TOPLEFT', STAGE_PAD, -74)
	cooldown:SetText('12.4')
	window:Paint(cooldown, 'text')
	local cooldownLabel = ui.Text(stage, 'Cooldown text', 10, 'faint')
	cooldownLabel:SetPoint('LEFT', cooldown, 'RIGHT', 10, 0)
	local resource = stage:CreateFontString(nil, 'OVERLAY')
	resource:SetFont(window.font, 18, '')
	resource:SetPoint('TOPLEFT', STAGE_PAD * 2 + barWidth, -74)
	resource:SetText('4 / 5')
	window:Paint(resource, 'text')
	local resourceLabel = ui.Text(stage, 'Class resources', 10, 'faint')
	resourceLabel:SetPoint('LEFT', resource, 'RIGHT', 10, 0)

	ui.Bind(stage, function()
		local general = General()
		local texture = BUI.GetGlobalTexture()
		local flags = BUI.ApplySlug('OUTLINE')
		local font = BUI.GetGlobalFont()
		health:SetTexture(texture)
		power:SetTexture(texture)
		window:Paint(health, 'accent')
		window:Paint(power, 'accent')
		healthText:SetFont(font, 11, flags)
		healthValue:SetFont(font, 11, flags)
		powerText:SetFont(font, 11, flags)
		powerValue:SetFont(font, 11, flags)
		cooldown:SetFont(BUI.GetCDMFont(), 18, flags)
		resource:SetFont(BUI.GetSecondaryPowerFont(), 18, flags)
		note:SetText((general.font .. ' on ' .. general.texture):upper())
	end)
	return frame
end

local function AccentGallery(ui, parent, width)
	local tiles = {}
	local _, classFile = UnitClass('player')
	local classColor = RAID_CLASS_COLORS[classFile]
	tiles[1] = {
		label = 'Class color', sub = (UnitClass('player')),
		build = function(content)
			local swatch = content:CreateTexture(nil, 'ARTWORK')
			swatch:SetTexture(Widget.WHITE)
			swatch:SetPoint('TOPLEFT', 10, -10)
			swatch:SetPoint('BOTTOMRIGHT', -10, 4)
			swatch:SetVertexColor(classColor.r, classColor.g, classColor.b, 1)
		end,
		selected = function() return General().useClassColorTheme == true end,
		onClick = UseClassColor,
	}
	for _, entry in ipairs(PALETTE) do
		tiles[#tiles + 1] = {
			label = entry.name,
			build = function(content)
				local swatch = content:CreateTexture(nil, 'ARTWORK')
				swatch:SetTexture(Widget.WHITE)
				swatch:SetPoint('TOPLEFT', 10, -10)
				swatch:SetPoint('BOTTOMRIGHT', -10, 4)
				swatch:SetVertexColor(entry.color[1], entry.color[2], entry.color[3], 1)
			end,
			selected = function()
				local general = General()
				return general.useClassColorTheme ~= true and Same(general.themeColor[1], general.themeColor[2], general.themeColor[3], entry.color)
			end,
			onClick = function() SetAccent(entry.color[1], entry.color[2], entry.color[3]) end,
		}
	end
	tiles[#tiles + 1] = {
		label = 'Custom', sub = 'Pick any color', search = 'custom accent color',
		build = function(content, _, tile)
			local swatch = content:CreateTexture(nil, 'ARTWORK')
			swatch:SetTexture(Widget.WHITE)
			swatch:SetPoint('TOPLEFT', 10, -10)
			swatch:SetPoint('BOTTOMRIGHT', -10, 4)
			tile.swatch = swatch
			ui.Glyph(content, 'edit', 12, 'onAccent', 'OVERLAY'):SetPoint('CENTER', swatch)
		end,
		refresh = function(tile)
			local color = General().themeColor
			tile.swatch:SetVertexColor(color[1], color[2], color[3], 1)
		end,
		selected = function()
			local general = General()
			if general.useClassColorTheme == true then return false end
			for _, entry in ipairs(PALETTE) do
				if Same(general.themeColor[1], general.themeColor[2], general.themeColor[3], entry.color) then return false end
			end
			return true
		end,
		onClick = function(tile) PickAccent(tile) end,
	}
	return ui.Gallery(parent, width, {
		title = 'Accent',
		description = 'The highlight color for every BluUI window, tab and control. Class color follows the character you are on.',
		tiles = tiles,
	})
end

local function TextureGallery(ui, parent, width)
	local tiles = {}
	for _, texture in ipairs(BUI.BuildTextureDropdownItems()) do
		local path = sharedMedia:Fetch('statusbar', texture.value)
		tiles[#tiles + 1] = {
			label = texture.text,
			build = function(content)
				local track = ui.Fill(content, 'control', 'ARTWORK')
				track:SetPoint('LEFT', 10, 0)
				track:SetPoint('RIGHT', -10, 0)
				track:SetHeight(14)
				local bar = content:CreateTexture(nil, 'ARTWORK', nil, 1)
				bar:SetTexture(path)
				bar:SetPoint('TOPLEFT', track)
				bar:SetPoint('BOTTOMLEFT', track)
				bar:SetWidth(78)
				Window():Paint(bar, 'accent')
			end,
			selected = function() return General().texture == texture.value end,
			onClick = function() SetTexture(texture.value) end,
		}
	end
	return ui.Gallery(parent, width, {
		title = 'Bar texture',
		description = 'Every statusbar inherits this texture unless its page picks another.',
		tileWidth = 132,
		tiles = tiles,
	})
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

local function TextSection(ui, parent, width)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Text',
		description = 'The font every module inherits, how it renders, and the modules that use a font of their own.',
		columns = { { 'Name', ui.AVATAR_X }, { 'Font', FIRST_COLUMN } },
	})
	local fontRow = section:AddRow('Font global every module')
	ui.Initials(fontRow, SWATCH_SIZE, 'Aa'):SetPoint('LEFT', ui.AVATAR_X, 0)
	ui.RowTitle(fontRow, 'Font', 'Every module inherits this unless it picks its own', ui.NAME_X)
	local fontName = ui.Cell(fontRow, '', FIRST_COLUMN, 200)
	local fontReset = ui.IconButton(fontRow, 'reset', 'Back to the BluUI font', function() SetFont(BUI.C.DEFAULT_FONT) end)
	fontReset:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
	local fontMenu = ui.Dropdown(fontRow, FONT_DROPDOWN_WIDTH, function()
		local items = {}
		for _, font in ipairs(BUI.BuildFontDropdownItems()) do
			items[#items + 1] = { text = font.text, fontPath = font.fontPath, checked = font.value == General().font, callback = function() SetFont(font.value) end }
		end
		return items
	end)
	fontMenu:SetPoint('RIGHT', fontReset, 'LEFT', -10, 0)
	ui.Bind(fontRow, function()
		fontName:SetText(General().font)
		fontMenu.label:SetText(General().font)
		fontReset:SetActive(General().font ~= BUI.C.DEFAULT_FONT)
	end)

	local row = section:AddRow('Slug rendering thicker outline')
	ui.IconAvatar(row, SWATCH_SIZE, 'glow'):SetPoint('LEFT', ui.AVATAR_X, 0)
	ui.RowTitle(row, 'Slug rendering', 'Thicker outline on every BluUI font', ui.NAME_X)
	local slugReset = ui.IconButton(row, 'reset', 'Back to the plain outline', function()
		General().fontSlug = false
		RefreshAllVisuals()
	end)
	slugReset:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
	local slug = ui.Dropdown(row, DROPDOWN_WIDTH, OnOff(function() return General().fontSlug == true end, function(value)
		General().fontSlug = value
		RefreshAllVisuals()
	end))
	slug:SetPoint('RIGHT', slugReset, 'LEFT', -10, 0)
	ui.Bind(row, function()
		slug.label:SetText(General().fontSlug == true and 'On' or 'Off')
		slugReset:SetActive(General().fontSlug == true)
	end)

	for _, override in ipairs(FONT_OVERRIDES) do
		local fontRow = section:AddRow(override.name .. ' ' .. override.sub)
		ui.Initials(fontRow, SWATCH_SIZE, 'Aa'):SetPoint('LEFT', ui.AVATAR_X, 0)
		ui.RowTitle(fontRow, override.name, override.sub, ui.NAME_X)
		local name = ui.Cell(fontRow, '', FIRST_COLUMN, 200)
		local reset = ui.IconButton(fontRow, 'reset', 'Back to the global font', function()
			General()[override.key] = nil
			RefreshAllVisuals()
		end)
		reset:SetPoint('RIGHT', -(ui.ROW_INSET - 2), 0)
		local dropdown = ui.Dropdown(fontRow, FONT_DROPDOWN_WIDTH, function()
			local current = General()[override.key]
			local items = { { text = 'Global font', checked = current == nil, callback = function()
				General()[override.key] = nil
				RefreshAllVisuals()
			end } }
			for _, font in ipairs(BUI.BuildFontDropdownItems()) do
				items[#items + 1] = { text = font.text, fontPath = font.fontPath, checked = font.value == current, callback = function()
					General()[override.key] = font.value
					RefreshAllVisuals()
				end }
			end
			return items
		end)
		dropdown:SetPoint('RIGHT', reset, 'LEFT', -10, 0)
		ui.Bind(fontRow, function()
			local current = General()[override.key]
			name:SetText(current or General().font)
			dropdown.label:SetText(current and 'Custom' or 'Global font')
			reset:SetActive(current ~= nil)
		end)
	end
	return section
end

local function BarSection(ui, parent, width)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Bars',
		description = 'Motion and the tint the gradient texture fades through.',
		columns = { { 'Name', ui.AVATAR_X }, { 'Hex', FIRST_COLUMN }, { 'Opacity', SECOND_COLUMN } },
	})
	local row = section:AddRow('Smooth bars animate health and power')
	ui.IconAvatar(row, SWATCH_SIZE, 'play'):SetPoint('LEFT', ui.AVATAR_X, 0)
	ui.RowTitle(row, 'Smooth bars', 'Animate health and power changes on the frames', ui.NAME_X)
	local smooth = ui.Dropdown(row, DROPDOWN_WIDTH, OnOff(function() return General().smoothBars ~= false end, SetSmoothBars))
	smooth:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ui.Bind(row, function() smooth.label:SetText(General().smoothBars ~= false and 'On' or 'Off') end)

	local function PickGradient(anchor)
		local color = General().gradientColor
		Controls.OpenColorPicker({ r = color[1], g = color[2], b = color[3], a = color[4], hasOpacity = true, anchorTo = anchor, callback = function(red, green, blue, alpha, cancelled)
			if cancelled then return end
			General().gradientColor = { red, green, blue, alpha }
			RefreshAllVisuals()
		end })
	end
	local function ResetGradient()
		General().gradientColor = { 1, 1, 1, 1 }
		RefreshAllVisuals()
	end
	ui.ColorRow(section, {
		name = 'Gradient tint', sub = 'Only the ' .. BUI.C.GRADIENT_TEXTURE .. ' texture uses it', hexX = FIRST_COLUMN, opacityX = SECOND_COLUMN,
		get = function() local color = General().gradientColor return color[1], color[2], color[3], color[4] end,
		custom = function() local color = General().gradientColor return not (Same(color[1], color[2], color[3], { 1, 1, 1 }) and color[4] == 1) end,
		pick = PickGradient,
		reset = ResetGradient,
		items = function(anchor)
			return {
				{ text = 'Default', callback = ResetGradient },
				{ text = 'Custom color', callback = function() PickGradient(anchor) end },
			}
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
			Controls.OpenColorPicker({ r = red, g = green, b = blue, a = alpha, hasOpacity = true, anchorTo = anchor, callback = function(newRed, newGreen, newBlue, newAlpha, cancelled)
				if cancelled then return end
				entry.set(newRed, newGreen, newBlue, newAlpha)
				BUI.ApplyColors()
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
	local sections = { Stage(ui, parent, width) }
	sections[#sections + 1] = AccentGallery(ui, parent, width)
	sections[#sections + 1] = TextSection(ui, parent, width)
	sections[#sections + 1] = TextureGallery(ui, parent, width)
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
