local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Controls, Layout, Widget = BUILib.Controls, BUILib.Layout, BUILib.Widget
local PageKit = BUILib.PageKit

local CARD_COLUMNS = 3
local FONT_OVERRIDE_SENTINEL = BUI.C.GLOBAL_OPTION
local SETTINGS_TAB = 1

local FONT_OVERRIDES = {
	{ key = 'cdmFont',            title = 'Cooldown Manager', description = 'Keybind and cooldown text on CDM icons.' },
	{ key = 'powerFont',          title = 'Power Bar',        description = 'Primary power bar value text.' },
	{ key = 'secondaryPowerFont', title = 'Class Resources',  description = 'Secondary resource text (combo points, runes, ...).' },
	{ key = 'trackingFont',       title = 'Custom Bars',      description = 'Text on custom tracking bars.' },
}

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
end

local function MakeSectionHelpers(tab)
	local grid
	local function Section(title, description)
		if grid then grid:Flush() end
		Layout.Section(tab, title, description)
		grid = PageKit.RowGrid(tab)
	end
	local function AddRow(config) return grid:Add(config) end
	local function Finish() if grid then grid:Flush() end end
	return Section, AddRow, Finish
end

local function BuildAccent(tab)
	local db = BUI.GetDB()
	local Section, AddRow, Finish = MakeSectionHelpers(tab)

	local function RebuildForAccent()
		BUI.Nav.Apply(BUI.Nav.GetCurrentStyle())
	end

	Section('Accent Color', 'The highlight color used by every BluUI window, tab and control.')

	AddRow({
		title = 'Use Class Color',
		description = 'Use your class color as the accent.',
		checked = db.general.useClassColorTheme == true,
		callback = function(useClassColor)
			db.general.useClassColorTheme = useClassColor
			BUILib.Colors.RefreshAccent()
			RebuildForAccent()
		end,
	})

	AddRow({
		title = 'Accent Color',
		description = 'Custom accent used across the UI.',
		plain = true,
		accessoryWidth = 36,
		accessories = function(row)
			local themeColor = db.general.themeColor
			local accentSwatch = Controls.ColorSwatch(row, { r = themeColor[1], g = themeColor[2], b = themeColor[3], a = themeColor[4], tooltip = 'Accent color', callback = function(red, green, blue, alpha, _, phase)
				db.general.themeColor = { red, green, blue, alpha }
				BUILib.Colors.RefreshAccent()
				if phase == 'commit' then RebuildForAccent() end
			end })
			if db.general.useClassColorTheme == true then
				accentSwatch:SetEnabled(false)
			end
			return { accentSwatch }
		end,
	})

	Finish()
end

local function BuildColorCards(tab, cardNames, description)
	local cards = BUI.Colors.BuildCards()
	local wanted = {}
	for _, cardName in ipairs(cardNames) do wanted[cardName] = true end

	local grids = {}
	for _, card in ipairs(cards) do
		if wanted[card.name] then
			table.sort(card.colors, function(firstColor, secondColor) return firstColor.label < secondColor.label end)
			local section = Layout.Section(tab, card.name, description)
			description = nil

			local headerFrame = Widget.Unwrap(section.header)
			local resetButton = Controls.Button(headerFrame, 'Reset', 70, function()
				BUI.Colors.ResetGroup(card.name)
				for _, grid in ipairs(grids) do grid:RefreshColors() end
				BUI.ApplyColors()
			end)
			local resetFrame = Widget.Unwrap(resetButton)
			resetFrame:ClearAllPoints()
			resetFrame:SetPoint('TOPRIGHT', headerFrame, 'TOPRIGHT', 0, 2)

			local grid = Widget.Unwrap(Controls.ColorGrid(tab.child, card.colors, {
				width = tab.width,
				columns = CARD_COLUMNS,
				cellWidth = tab.width / CARD_COLUMNS,
				onChange = function() BUI.ApplyColors() end,
			}))
			grids[#grids + 1] = grid
			Layout.Add(tab, grid, 8)
		end
	end
end

local function BuildFonts(tab)
	local db = BUI.GetDB()
	local Section, AddRow, Finish = MakeSectionHelpers(tab)

	Section('Global Font', 'Every module inherits this font unless it sets its own below or on its page.')

	AddRow({
		spanFull = true,
		title = 'Global Font',
		description = 'Font used across the UI.',
		controlWidth = 196,
		control = function(row)
			return Controls.Dropdown(row, nil, BUI.BuildFontDropdownItems(), db.general.font, function(fontName)
				db.general.font = fontName; RefreshAllVisuals()
			end, nil, 180)
		end,
	})

	AddRow({
		title = 'Slug Rendering',
		description = 'Thicker outline rendering for every BluUI font.',
		checked = db.general.fontSlug == true,
		callback = function(useSlug)
			db.general.fontSlug = useSlug; RefreshAllVisuals()
		end,
	})

	Section('Module Fonts', 'Pick a different font for one module. "Use Global Font" follows the setting above.')

	for _, override in ipairs(FONT_OVERRIDES) do
		AddRow({
			spanFull = true,
			title = override.title,
			description = override.description,
			controlWidth = 196,
			control = function(row)
				return Controls.Dropdown(row, nil, BUI.BuildFontDropdownItems(FONT_OVERRIDE_SENTINEL), db.general[override.key] or FONT_OVERRIDE_SENTINEL, function(fontName)
					db.general[override.key] = fontName ~= FONT_OVERRIDE_SENTINEL and fontName or nil
					RefreshAllVisuals()
				end, nil, 180)
			end,
		})
	end

	Finish()
end

local function BuildTextures(tab)
	local db = BUI.GetDB()
	local Section, AddRow, Finish = MakeSectionHelpers(tab)

	Section('Bar Textures', 'Every statusbar inherits this texture unless its page picks another.')

	local gradientSwatch
	AddRow({
		spanFull = true,
		title = 'Global Bar Texture',
		description = 'Statusbar texture used by every bar.',
		controlWidth = 196,
		control = function(row)
			return Controls.Dropdown(row, nil, BUI.BuildTextureDropdownItems(), db.general.texture, function(textureName)
				db.general.texture = textureName; RefreshAllVisuals()
				gradientSwatch:SetEnabled(textureName == 'BUI Gradient')
			end, nil, 180)
		end,
		accessoryWidth = 36,
		accessories = function(row)
			local gradientColor = db.general.gradientColor
			gradientSwatch = Controls.ColorSwatch(row, { r = gradientColor[1], g = gradientColor[2], b = gradientColor[3], a = gradientColor[4], tooltip = "Gradient tint (used by the 'BUI Gradient' texture)", callback = function(red, green, blue, alpha)
				db.general.gradientColor = { red, green, blue, alpha }; RefreshAllVisuals()
			end })
			gradientSwatch:SetEnabled(db.general.texture == 'BUI Gradient')
			return { gradientSwatch }
		end,
	})

	AddRow({
		title = 'Smooth Bars',
		description = 'Animate health and power changes on unit frames and group frames.',
		checked = db.general.smoothBars ~= false,
		callback = function(value)
			db.general.smoothBars = value
			local smoothing = value and Enum.StatusBarInterpolation.ExponentialEaseOut or nil
			BUI.GroupFrames.EachChild(function(child)
				if child.Health then child.Health.smoothing = smoothing end
				if child.Power then child.Power.smoothing = smoothing end
			end)
			BUI.UnitFrames.InvalidateSettingsCache()
			BUI.UnitFrames:Refresh()
		end,
	})

	Finish()
end

BUI.AppearancePage = {}

function BUI.AppearancePage.BuildTab(tab)
	BuildAccent(tab)
	BuildFonts(tab)
	BuildTextures(tab)
	BuildColorCards(tab, { 'Power', 'Class Resources' }, 'Shared by the power bars, unit frames and group frames.')
	BuildColorCards(tab, { 'Dispel Types' }, 'Used by unit frame and group frame dispel highlights and badges.')
end

function BUI.OpenAppearance()
	BUI.PageEngine.Show()
	BUI.PageEngine.NavigateToID('settings')
	local pageConfig = BUI.PageEngine.pages.settings
	local page = pageConfig and pageConfig.frame and pageConfig.frame._page
	if page and page.SetTab then page:SetTab(SETTINGS_TAB) end
end
